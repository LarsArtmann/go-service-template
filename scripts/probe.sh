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

failures=0
note() { printf '%s\n' "$*"; }
bail() { printf 'FAIL: %s\n' "$*" >&2; failures=$((failures + 1)); }
expect() { # want actual what
	if [ "$2" = "$1" ]; then note "ok    $3 = $2"; else bail "$3 = $2 (want $1)"; fi
}

[ -x "$BIN" ] || { bail "binary not executable: $BIN (build it: go build -o app ./cmd/app)"; exit 1; }

# A port that is actually free: try the requested one, then walk upward.
port_busy() { curl -s -o /dev/null --connect-timeout 1 "localhost:$1" >/dev/null 2>&1; }
while port_busy "$PORT"; do PORT=$((PORT + 1)); done
note "port  $PORT"

LOG="$(mktemp)"
APP_ADDR=":$PORT" "$BIN" serve >"$LOG" 2>&1 &
PID=$!

cleanup() { kill "$PID" >/dev/null 2>&1 || true; wait "$PID" 2>/dev/null || true; rm -f "$LOG"; }
trap cleanup EXIT

# Wait for readiness by polling /healthz (the probe endpoint itself).
up=0
for _ in $(seq 1 50); do
	[ "$(curl -s -o /dev/null -w '%{http_code}' "localhost:$PORT/healthz")" = "200" ] && { up=1; break; }
	sleep 0.2
done
[ "$up" -eq 1 ] || { bail "server never became healthy on :$PORT (log: $LOG)"; exit 1; }

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

if [ "$failures" -eq 0 ]; then
	note "probe: clean"
	exit 0
fi
printf 'probe: %d failure(s)\n' "$failures" >&2
exit 1
