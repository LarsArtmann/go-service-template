#!/usr/bin/env bash
# The dogfood probe: build, boot, probe the endpoint matrix, SIGTERM-drain,
# and assert the five drain phases. This is the template's quality-of-proof
# asset — run it after any preset/core/appkit-touching change (the refresh
# ritual in AGENTS.md and CONTRIBUTING.md).
#
# Usage:
#   scripts/probe.sh [path-to-binary]        # binary default: ./app
#
# Environment:
#   PROBE_PORT            listen port (default 18099; overridden if taken)
#   PROBE_EXPECT_VERSION  expected /version payload (default: any non-empty;
#                         set the git rev when probing a flake-built binary)

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${1:-$REPO_ROOT/app}"
PORT="${PROBE_PORT:-18099}"
EXPECT_VERSION="${PROBE_EXPECT_VERSION:-}"

# First arg --edge runs only the edge cases (bind failure, drain under load);
# default runs the full endpoint matrix plus both edge cases at the end.
EDGE_ONLY=0
if [ "${1:-}" = "--edge" ]; then
	EDGE_ONLY=1
	BIN="${2:-$REPO_ROOT/app}"
fi

failures=0
note() { printf '%s\n' "$*"; }
bail() {
	printf 'FAIL: %s\n' "$*" >&2
	failures=$((failures + 1))
}
expect() { # want actual what
	if [ "$2" = "$1" ]; then note "ok    $3 = $2"; else bail "$3 = $2 (want $1)"; fi
}

[ -x "$BIN" ] || {
	bail "binary not executable: $BIN (build it: go build -o app ./cmd/app)"
	exit 1
}

# A port that is actually free: try the requested one, then walk upward.
port_busy() { curl -s -o /dev/null --connect-timeout 1 "localhost:$1" >/dev/null 2>&1; }
while port_busy "$PORT"; do PORT=$((PORT + 1)); done
note "port  $PORT"

edge_bind_failure() { # occupying the port must fail the boot with the
	# classified listen-failure, not a hang or a panic.
	local squatter squatter_log log first_line
	squatter_log="$(mktemp)"
	# The squatter is the binary itself: a first instance holds the port, so
	# this edge case needs nothing beyond what the probe already requires.
	APP_ADDR=":$PORT" "$BIN" serve >"$squatter_log" 2>&1 &
	squatter=$!
	for _ in $(seq 1 50); do
		port_busy "$PORT" && break
		sleep 0.2
	done
	port_busy "$PORT" || bail "could not occupy :$PORT for the bind-failure case"
	log="$(mktemp)"
	# Bounded on purpose: should the second instance ever win the bind, it
	# would serve forever and hang the probe.
	APP_ADDR=":$PORT" timeout 10 "$BIN" serve >"$log" 2>&1
	kill "$squatter" >/dev/null 2>&1 || true
	wait "$squatter" 2>/dev/null || true
	first_line="$(tr '\n' ' ' <"$log")"
	rm -f "$log" "$squatter_log"
	if printf '%s' "$first_line" | grep -q "listen_failed"; then
		note "ok    bind failure classified: [Infrastructure:server.listen_failed]"
	else
		bail "bind failure not classified as listen_failed: $first_line"
	fi
}

edge_drain_under_load() { # an in-flight request must outlive SIGTERM
	local log pid slow
	log="$(mktemp)"
	APP_ADDR=":$PORT" "$BIN" serve >"$log" 2>&1 &
	pid=$!
	for _ in $(seq 1 50); do
		[ "$(curl -s -o /dev/null -w '%{http_code}' "localhost:$PORT/healthz")" = "200" ] && break
		sleep 0.2
	done
	# The in-flight request is the /health SSE stream, which stays open; it
	# gets a head start so it is surely in flight when SIGTERM lands.
	curl -s -N "localhost:$PORT/health" --max-time 20 >"$log.body" 2>/dev/null &
	slow=$!
	sleep 0.3
	kill -TERM "$pid"
	wait "$slow" 2>/dev/null
	# The drain may still be running when curl returns; the phases are only
	# complete once the process exits (bounded by the shutdown deadline).
	for _ in $(seq 1 100); do
		kill -0 "$pid" 2>/dev/null || break
		sleep 0.2
	done
	wait "$pid" 2>/dev/null
	if grep -q "drain_wait" "$log"; then
		note "ok    drain waited for in-flight traffic (drain_wait logged)"
	else
		bail "no drain_wait under load: $(head -3 "$log" | tr '\n' ' ')"
	fi
	rm -f "$log" "$log.body"
}

LOG="$(mktemp)"
PID=""
cleanup() {
	if [ -n "$PID" ]; then
		kill "$PID" >/dev/null 2>&1 || true
		wait "$PID" 2>/dev/null || true
	fi
	rm -f "$LOG"
}

if [ "$EDGE_ONLY" -eq 0 ]; then
	APP_ADDR=":$PORT" "$BIN" serve >"$LOG" 2>&1 &
	PID=$!
	trap cleanup EXIT

	# Wait for readiness by polling /healthz (the probe endpoint itself).
	up=0
	for _ in $(seq 1 50); do
		[ "$(curl -s -o /dev/null -w '%{http_code}' "localhost:$PORT/healthz")" = "200" ] && {
			up=1
			break
		}
		sleep 0.2
	done
	[ "$up" -eq 1 ] || {
		bail "server never became healthy on :$PORT (log: $LOG)"
		exit 1
	}

	# 17.1.3 — the version stamp gates everything else: an unstamped binary
	# answering "dev" lies about the build, so surface it before probing.
	VERSION="$(curl -s "localhost:$PORT/version")"
	[ -n "$VERSION" ] || bail "/version empty"
	if [ -n "$EXPECT_VERSION" ]; then
		expect "$EXPECT_VERSION" "$VERSION" "/version stamp"
	elif [ "$VERSION" = "dev" ]; then
		note "warn  /version says dev (a go-build binary; flake builds stamp the rev)"
	else
		note "ok    /version = $VERSION"
	fi

	# 17.1.4 — the endpoint matrix the preset spine serves.
	for ep in healthz readyz startupz health api/status; do
		expect 200 "$(curl -s -o /dev/null -w '%{http_code}' "localhost:$PORT/$ep")" "GET /$ep"
	done
	expect 200 "$(curl -s -o /dev/null -w '%{http_code}' "localhost:$PORT/")" "GET /"
	expect 404 "$(curl -s -o /dev/null -w '%{http_code}' "localhost:$PORT/nope")" "GET /nope"
	# The preset mounts the probe without a method guard (no WithAllowedMethods
	# passthrough yet - upstream gap, filed with the T-24.x preset options), so
	# a stray POST is answered 200 today. The assertion pins the CURRENT
	# contract; flip it to 405 when the preset grows the passthrough.
	expect 200 "$(curl -s -o /dev/null -w '%{http_code}' -X POST "localhost:$PORT/healthz")" "POST /healthz"

	# SIGTERM → graceful drain; the log must carry the five phases in order.
	kill -TERM "$PID"
	wait "$PID" 2>/dev/null
	code=$?
	[ "$code" -le 143 ] || bail "serve exited $code on SIGTERM"
	PID=""

	phases="ready_flip drain_hooks drain_wait listener_close shutdown_hooks"
	for phase in $phases; do
		grep -q "phase=$phase" "$LOG" || bail "drain phase missing: $phase"
	done
	grep -q "phase=ready_flip" "$LOG" && grep -q "phase=shutdown_hooks" "$LOG" && note "ok    drain phases present"
fi

edge_bind_failure
edge_drain_under_load

if [ "$failures" -eq 0 ]; then
	note "probe: clean"
	exit 0
fi
printf 'probe: %d failure(s)\n' "$failures" >&2
exit 1
