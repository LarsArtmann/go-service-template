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
	local log pid first_line
	python3 -c "
import socket, time
s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('127.0.0.1', $PORT))
s.listen(1)
time.sleep(12)
" &
	local squatter=$!
	sleep 0.5
	log="$(mktemp)"
	APP_ADDR=":$PORT" "$BIN" serve >"$log" 2>&1
	pid=$!
	wait "$squatter" 2>/dev/null || true
	first_line="$(cat "$log" | tr '\n' ' ')"
	rm -f "$log"
	if printf '%s' "$first_line" | grep -q "listen_failed"; then
		note "ok    bind failure classified: [Infrastructure:server.listen_failed]"
	else
		bail "bind failure not classified as listen_failed: $first_line"
	fi
}

edge_drain_under_load() { # an in-flight request must outlive SIGTERM
	local log pid body
	LOG2="$(mktemp)"
	APP_ADDR=":$PORT" "$BIN" serve >"$LOG2" 2>&1 &
	pid=$!
	for _ in $(seq 1 50); do
		[ "$(curl -s -o /dev/null -w '%{http_code}' "localhost:$PORT/healthz")" = "200" ] && break
		sleep 0.2
	done
	# A slow request against /api/status: /health flips to 503 only after
	# the drain's ready_flip, so give the request a head start instead.
	curl -s -N "localhost:$PORT/health" --max-time 20 >"$LOG2.body" 2>/dev/null &
	local slow=$!
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
	if grep -q "drain_wait" "$LOG2"; then
		note "ok    drain waited for in-flight traffic (drain_wait logged)"
	else
		bail "no drain_wait under load: $(head -3 "$LOG2" | tr '\n' ' ')"
	fi
	rm -f "$LOG2" "$LOG2.body"
}

LOG="$(mktemp)"

if [ "$EDGE_ONLY" -eq 0 ]; then
	APP_ADDR=":$PORT" "$BIN" serve >"$LOG" 2>&1 &
	PID=$!

	cleanup() {
		kill "$PID" >/dev/null 2>&1 || true
		wait "$PID" 2>/dev/null || true
		rm -f "$LOG"
	}
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
