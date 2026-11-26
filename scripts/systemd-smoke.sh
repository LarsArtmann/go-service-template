#!/usr/bin/env bash
# Systemd smoke: run the Nix-built binary as a transient unit under the
# user's systemd manager and prove the sd_notify deploy path end to end:
# READY=1, the watchdog keepalive, the endpoint matrix, STOPPING=1 and the
# five-phase drain on `systemctl stop`. The systemd sibling of
# scripts/probe.sh and scripts/image-smoke.sh: "the same binary runs under
# systemd" as a repeatable execution, not a doc claim.
#
# It proves the notify contract (Type=notify, WatchdogSec, SIGTERM drain)
# against a real manager, not systemd/app.service as a whole: a user manager
# refuses DynamicUser=, so the unit runs as the calling user and without the
# shipped hardening.
#
# Usage:
#   scripts/systemd-smoke.sh [expected-version]
#
# Builds the flake binary first (`nix build .`), so the unit under test is
# derived from the tree under test. Without an expected version the script
# uses `git rev-parse HEAD`: the flake stamps the binary from the git rev,
# so a stale artifact (or a dirty tree, stamped <rev>-dirty) fails here
# loudly.
#
# Environment:
#   SMOKE_PORT          port for APP_ADDR (default 18400, walks upward)
#   SMOKE_WATCHDOG_SEC  unit WatchdogSec in whole seconds (default 3; 0
#                       disarms it and the run reports FAIL)
#
# Requires: nix, systemd-run, systemctl, journalctl, curl, jq, python3 (the
# control unit's datagram sender) and a running user manager. No root.
#
# The manager logs its notify receipts (READY=1, WATCHDOG=1, STOPPING=1)
# only at debug level, so the script raises the user manager's log level
# for the app unit's lifetime and restores it on exit; a timer restores it
# even when the script is killed with SIGKILL. Log level and the unit sweep
# are manager-wide: never run two of these at once.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXPECT="${1:-}"

failures=0
note() { printf '%s\n' "$*"; }
bail() {
	printf 'FAIL: %s\n' "$*" >&2
	failures=$((failures + 1))
}
expect() { # want actual what
	if [ "$2" = "$1" ]; then note "ok    $3 = $2"; else bail "$3 = $2 (want $1)"; fi
}

for tool in nix systemd-run systemctl journalctl curl jq python3; do
	command -v "$tool" >/dev/null 2>&1 || {
		bail "missing tool: $tool"
		exit 1
	}
done
systemctl --user show -p Version --value >/dev/null 2>&1 || {
	bail "no user manager: systemctl --user does not answer (needs a systemd user session)"
	exit 1
}
WD_SEC="${SMOKE_WATCHDOG_SEC:-3}"
case "$WD_SEC" in
'' | *[!0-9]*)
	bail "SMOKE_WATCHDOG_SEC must be a whole number of seconds, got '$WD_SEC'"
	exit 1
	;;
esac

if [ -z "$EXPECT" ]; then
	EXPECT="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null)"
	[ -n "$EXPECT" ] || {
		bail "no expected version given and not a git repo"
		exit 1
	}
fi

note "build  nix build ."
(cd "$REPO_ROOT" && nix build . --no-write-lock-file) >&2 || {
	bail "nix build . failed"
	exit 1
}
BIN="$REPO_ROOT/result/bin/app"
[ -x "$BIN" ] || {
	bail "flake binary missing: $BIN"
	exit 1
}
note "binary $BIN"
note "expect $EXPECT"

PORT="${SMOKE_PORT:-18400}"
port_busy() { curl -s -o /dev/null --connect-timeout 1 "127.0.0.1:$1" >/dev/null 2>&1; }
while port_busy "$PORT"; do PORT=$((PORT + 1)); done
note "port   $PORT"

SLEEP_BIN="$(command -v sleep)"
PY_BIN="$(command -v python3)"
SYSTEMCTL="$(command -v systemctl)"
FAMILY="app-systemd-smoke"
RUN="$FAMILY-$$"
UNIT="$RUN.service"
CTL_SILENT_START="$RUN-ctl-silent-start.service"
CTL_SILENT_WATCHDOG="$RUN-ctl-silent-watchdog.service"
DESC="app systemd smoke ($$)"

# A run killed with SIGKILL cannot run its trap, so every run sweeps what an
# earlier one left behind: its units, and its dead man's switch, whose unit
# name still carries the log level it was meant to restore.
for stale in $(systemctl --user list-units --all --no-legend --plain "$FAMILY-*.timer" 2>/dev/null | awk '{print $1}'); do
	note "sweep  disarming a dead man's switch an earlier run left behind: $stale"
	stale_level="${stale##*-restore-log-level-}"
	systemctl --user stop "$stale" >/dev/null 2>&1 || true
	systemctl --user log-level "${stale_level%.timer}" >/dev/null 2>&1 || true
done
# --plain: a failed unit's bullet would otherwise hide its name.
for stale in $(systemctl --user list-units --all --no-legend --plain "$FAMILY-*.service" 2>/dev/null | awk '{print $1}'); do
	note "sweep  stopping a unit an earlier run left behind: $stale"
	systemctl --user stop "$stale" >/dev/null 2>&1 || true
done
systemctl --user reset-failed "$FAMILY-*.service" >/dev/null 2>&1 || true

LOG_LEVEL="$(systemctl --user log-level 2>/dev/null)"
case "$LOG_LEVEL" in
'' | *[!a-z0-9]*)
	bail "cannot read the manager log level (got '$LOG_LEVEL'): the notify receipts are debug lines and stay invisible without it"
	exit 1
	;;
esac
RESTORE_TIMER="$RUN-restore-log-level-${LOG_LEVEL}.timer"

# Every journal read starts at this run's start: a PID (so a unit name) can
# be recycled, and an old entry must never answer for this run.
SINCE="@$(date +%s)"

# The greps below pin the manager's log wording as of systemd 262. A
# reworded manager fails them loudly; it never lets them pass vacuously.
prop() { systemctl --user show "$1" -p "$2" --value 2>/dev/null; }
# This run's slice of a unit's journal, in the given output format.
ujournal() { journalctl --user -u "$1" --since "$SINCE" --no-pager -o "$2" 2>/dev/null; }
# The unit's journal, message text only.
ulog() { ujournal "$1" cat | grep -v '^-- ' || true; }
# Epoch time of the unit's first journal line holding the literal.
ts_of() { ujournal "$1" short-unix | grep -m1 -F -- "$2" | cut -d' ' -f1; }
# Journal lines reach readers a moment after they happen: poll, never assume.
wait_log() { # unit literal [tries]: true once the unit's journal holds the literal
	for _ in $(seq 1 "${3:-40}"); do
		ulog "$1" | grep -qF -- "$2" && return 0
		sleep 0.25
	done
	return 1
}
wait_prop() { # unit property want tries: true once the property holds the value
	for _ in $(seq 1 "$4"); do
		[ "$(prop "$1" "$2")" = "$3" ] && return 0
		sleep 0.25
	done
	return 1
}
show_log() { # unit literal: the first matching journal line, printed as evidence
	ujournal "$1" short-precise |
		grep -m1 -F -- "$2" | cut -d' ' -f3,5- | sed -e "s/: $1: /: /" -e 's/^/      journal /' || true
}

cleanup() {
	systemctl --user stop "$UNIT" >/dev/null 2>&1 || true
	systemctl --user stop "$RUN-*" >/dev/null 2>&1 || true
	systemctl --user reset-failed "$FAMILY-*.service" >/dev/null 2>&1 || true
	systemctl --user log-level "$LOG_LEVEL" >/dev/null 2>&1 || true
}
trap cleanup EXIT
trap 'exit 143' TERM # a caught signal leaves through the EXIT trap too
trap 'exit 130' INT
trap 'exit 129' HUP

# READY=1 from the main PID over $NOTIFY_SOCKET, then sleep: alive, silent.
SILENT_AFTER_READY='import os, socket, time
s = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
addr = os.environ["NOTIFY_SOCKET"]
if addr.startswith("@"):
	addr = "\0" + addr[1:]
s.sendto(b"READY=1", addr)
time.sleep(120)'

# Both controls fail on purpose. The app unit's evidence is only evidence
# when this manager enforces what it relies on: one that ignored Type=notify
# or WatchdogSec on transient user units would make the app assertions pass
# vacuously.
control_silent_start() { # no READY=1: the start job must time out
	local out rc=0
	out="$(systemd-run --user --unit="$CTL_SILENT_START" --description="systemd smoke control: silent start" \
		-p Type=notify -p TimeoutStartSec=3s "$SLEEP_BIN" 60 2>&1)" || rc=$?
	if [ "$rc" -ne 0 ] && [ "$(prop "$CTL_SILENT_START" Result)" = timeout ] &&
		wait_log "$CTL_SILENT_START" "start operation timed out"; then
		note "ok    control: Type=notify without READY=1 fails its start (Result=timeout)"
		show_log "$CTL_SILENT_START" "start operation timed out"
	else
		bail "control (silent start) did not time out: rc=$rc Result=$(prop "$CTL_SILENT_START" Result): $out"
	fi
}

control_silent_watchdog() { # READY=1, then alive but silent: the watchdog must kill it
	local rc=0
	# SIGKILL instead of the default SIGABRT: an abort would park a python
	# core dump in the host's coredump storage.
	systemd-run --user --unit="$CTL_SILENT_WATCHDOG" --description="systemd smoke control: silent watchdog" \
		-p Type=notify -p "WatchdogSec=${WD_SEC}s" -p WatchdogSignal=SIGKILL "$PY_BIN" -c "$SILENT_AFTER_READY" >/dev/null 2>&1 || rc=$?
	wait_prop "$CTL_SILENT_WATCHDOG" ActiveState failed $((WD_SEC * 8 + 8)) || true
	if [ "$rc" -eq 0 ] && [ "$(prop "$CTL_SILENT_WATCHDOG" Result)" = watchdog ] &&
		wait_log "$CTL_SILENT_WATCHDOG" "Watchdog timeout (limit ${WD_SEC}s)!"; then
		note "ok    control: alive but silent after READY=1 is killed by the watchdog (Result=watchdog)"
		show_log "$CTL_SILENT_WATCHDOG" "Watchdog timeout (limit ${WD_SEC}s)!"
	else
		bail "control (silent watchdog) was not watchdog-killed: start rc=$rc ActiveState=$(prop "$CTL_SILENT_WATCHDOG" ActiveState) Result=$(prop "$CTL_SILENT_WATCHDOG" Result)"
	fi
}

control_silent_start
control_silent_watchdog

# Dead man's switch first: SIGKILL skips the trap, the timer does not.
systemd-run --user --quiet --unit="$RESTORE_TIMER" --on-active=10min \
	"$SYSTEMCTL" --user log-level "$LOG_LEVEL" >/dev/null 2>&1 ||
	note "note  no dead man's switch: could not arm the log-level restore timer"
systemctl --user log-level debug >/dev/null 2>&1 || {
	bail "cannot set the manager log level to debug: the notify receipts are invisible without it"
	exit 1
}

# RuntimeMaxSec is the orphan guard: with the script gone (SIGKILL) the unit
# stops itself instead of holding the port until the manager exits.
START_OUT="$(systemd-run --user --unit="$UNIT" --description="$DESC" \
	-p Type=notify -p "WatchdogSec=${WD_SEC}s" -p TimeoutStartSec=20s -p RuntimeMaxSec=5min \
	--setenv="APP_ADDR=127.0.0.1:$PORT" "$BIN" serve 2>&1)" || {
	bail "start job failed (no READY=1 in 20s, or the process died): $(printf '%s' "$START_OUT" | head -3 | tr '\n' ' ')"
	ulog "$UNIT" | tail -15 >&2
	exit 1
}
# systemd-run returns only once the start job is done, which for Type=notify
# is the READY=1 receipt: this line exists because the app announced itself.
note "unit   $UNIT on 127.0.0.1:$PORT (Type=notify WatchdogSec=${WD_SEC}s TimeoutStartSec=20s)"
MAIN_PID="$(prop "$UNIT" MainPID)"

expect "active running notify main" \
	"$(prop "$UNIT" ActiveState) $(prop "$UNIT" SubState) $(prop "$UNIT" Type) $(prop "$UNIT" NotifyAccess)" \
	"ActiveState SubState Type NotifyAccess"
note "      MainPID=$MAIN_PID WatchdogUSec=$(prop "$UNIT" WatchdogUSec) TimeoutStartUSec=$(prop "$UNIT" TimeoutStartUSec)"
t_ready=""
t_running=""
if wait_log "$UNIT" "from PID $MAIN_PID: READY=1" && wait_log "$UNIT" "Changed start -> running"; then
	t_ready="$(ts_of "$UNIT" "from PID $MAIN_PID: READY=1")"
	t_running="$(ts_of "$UNIT" "Changed start -> running")"
fi
if [ -n "$t_ready" ] && [ -n "$t_running" ] &&
	awk -v a="$t_ready" -v b="$t_running" 'BEGIN { exit !(b >= a) }'; then
	note "ok    READY=1: the manager logged the receipt from the main PID, then moved the unit start -> running"
	show_log "$UNIT" "from PID $MAIN_PID: READY=1"
	show_log "$UNIT" "Changed start -> running"
else
	bail "READY=1: no receipt from PID $MAIN_PID before 'Changed start -> running' in the manager journal"
fi

BASE="http://127.0.0.1:$PORT"
up=""
for _ in $(seq 1 30); do
	[ "$(curl -s -o /dev/null --max-time 5 -w '%{http_code}' "$BASE/startupz")" = "200" ] && up=1 && break
	sleep 0.5
done
[ -n "$up" ] || bail "unit never answered /startupz 200 on port $PORT"

VERSION="$(curl -s --max-time 5 "$BASE/version" | jq -r '.version')"
expect "$EXPECT" "$VERSION" "/version stamp (binary built from the tree under test)"
if [ "$VERSION" = "$EXPECT-dirty" ]; then
	note "note  the tree was dirty at build time: commit, then rerun"
fi
for ep in healthz readyz startupz api/status version health; do
	expect 200 "$(curl -s -o /dev/null --max-time 5 -w '%{http_code}' "$BASE/$ep")" "/$ep"
done
expect 200 "$(curl -s -o /dev/null --max-time 5 -w '%{http_code}' "$BASE/")" "/ (views page)"
expect 404 "$(curl -s -o /dev/null --max-time 5 -w '%{http_code}' "$BASE/nope")" "/nope"

# Pings land every WatchdogSec/2, so the fourth arrives two full intervals
# after READY: that is the window watched here (minus a quarter interval of
# journal-timestamp slack).
PING_WANT=4
wd0="$(prop "$UNIT" WatchdogTimestampMonotonic)"
pings=0
for _ in $(seq 1 $((WD_SEC * 8 + 24))); do
	pings="$(ulog "$UNIT" | grep -cF "from PID $MAIN_PID: WATCHDOG=1")"
	[ "$pings" -ge "$PING_WANT" ] && break
	sleep 0.25
done
times="$(ujournal "$UNIT" short-unix | grep -F "from PID $MAIN_PID: WATCHDOG=1" | cut -d' ' -f1)"
last="$(printf '%s\n' "$times" | tail -n1)"
span=0
if [ -n "$last" ] && [ -n "$t_ready" ]; then
	span="$(awk -v a="$t_ready" -v z="$last" 'BEGIN { printf "%.2f", z - a }')"
fi
gaps="$(printf '%s\n' "$times" | awk 'NR > 1 { printf "%s%.2f", sep, $1 - prev; sep = " " } { prev = $1 }')"
want_span="$(awk -v w="$WD_SEC" 'BEGIN { printf "%.2f", 2 * w - w / 4 }')"
if [ "$pings" -ge "$PING_WANT" ] &&
	awk -v s="$span" -v w="$want_span" 'BEGIN { exit !(s >= w) }' &&
	[ "$(prop "$UNIT" ActiveState)" = active ] &&
	! ulog "$UNIT" | grep -qF "Watchdog timeout"; then
	note "ok    watchdog: $pings WATCHDOG=1 receipts from the main PID, the last one ${span}s after READY (WatchdogSec=${WD_SEC}s: two intervals), unit still active, no expiry"
else
	bail "watchdog: $pings pings, the last ${span}s after READY (want >= $PING_WANT pings and a span >= ${want_span}s, two WatchdogSec intervals), ActiveState=$(prop "$UNIT" ActiveState)"
fi
show_log "$UNIT" "from PID $MAIN_PID: WATCHDOG=1"
note "      ping gaps in seconds: ${gaps:-(none)} (design: WatchdogSec/2)"
wd1="$(prop "$UNIT" WatchdogTimestampMonotonic)"
if [ -n "$wd0" ] && [ -n "$wd1" ]; then
	note "      manager WatchdogTimestamp advanced $(((wd1 - wd0) / 1000000))s over the window (last-ping property, monotonic us: $wd0 -> $wd1)"
fi

# `systemctl stop` queues the stop job (SIGTERM) and returns only when the
# drain is over, so it runs in the background while the drain window is
# probed: readiness is already down, traffic is still served.
systemctl --user stop "$UNIT" &
stop_job=$!
readyz=""
for _ in $(seq 1 50); do
	readyz="$(curl -s -o /dev/null --max-time 2 -w '%{http_code}' "$BASE/readyz")"
	[ "$readyz" = "503" ] && break
	sleep 0.1
done
expect stop-sigterm "$(prop "$UNIT" SubState)" "SubState while the drain is served"
expect 503 "$readyz" "/readyz during the drain window"
expect 200 "$(curl -s -o /dev/null --max-time 2 -w '%{http_code}' "$BASE/healthz")" "/healthz during the drain window"
wait "$stop_job" || bail "systemctl stop returned non-zero"
wait_log "$UNIT" "Stopped $DESC." || bail "stop: no Stopped line in the manager journal"

# STOPPING=1 belongs at drain start, while traffic is still served: its
# receipt must precede the process exit by the drain window, not trail it.
t_stopping="$(ts_of "$UNIT" "from PID $MAIN_PID: STOPPING=1")"
t_exit="$(ts_of "$UNIT" "Main process exited")"
ahead=""
if [ -n "$t_stopping" ] && [ -n "$t_exit" ]; then
	ahead="$(awk -v a="$t_stopping" -v b="$t_exit" 'BEGIN { printf "%.2f", b - a }')"
fi
if [ -n "$ahead" ] && awk -v x="$ahead" 'BEGIN { exit !(x > 0) }'; then
	note "ok    STOPPING=1: the manager logged the receipt from the main PID, ${ahead}s before the process exit"
	show_log "$UNIT" "Stopping $DESC..."
	show_log "$UNIT" "from PID $MAIN_PID: STOPPING=1"
else
	bail "STOPPING=1: receipt missing or not before the process exit (receipt=${t_stopping:-none} exit=${t_exit:-none})"
fi

order="$(ulog "$UNIT" | grep -F 'shutdown phase complete' | grep -o 'phase=[a-z_]*' |
	sed 's/^phase=//' | paste -sd' ' -)"
expect "ready_flip drain_hooks drain_wait listener_close shutdown_hooks" "$order" "drain phases in the journal, in order"
if ulog "$UNIT" | grep -F 'graceful shutdown complete' | grep -qF 'result=ok'; then
	note "ok    graceful shutdown: 'graceful shutdown complete ... result=ok' in the journal"
	show_log "$UNIT" "graceful shutdown complete"
else
	bail "no 'graceful shutdown complete ... result=ok' line in the journal"
fi

if wait_log "$UNIT" "Main process exited, code=exited, status=0/SUCCESS" &&
	wait_log "$UNIT" "Deactivated successfully." &&
	! ulog "$UNIT" | grep -qF "Failed with result"; then
	note "ok    clean end: the main process exited 0 by itself (not killed) and the unit deactivated successfully"
	show_log "$UNIT" "Main process exited, code=exited, status=0/SUCCESS"
	show_log "$UNIT" "Deactivated successfully."
else
	bail "clean end: no 'Main process exited, code=exited, status=0/SUCCESS' line, or a 'Failed with result' line: $(ulog "$UNIT" | grep -m1 -E 'Main process exited|Failed with result')"
fi
# A failed unit stays loaded, so an unloaded one answers inactive here for
# the right reason: it did not fail.
expect inactive "$(systemctl --user is-failed "$UNIT" 2>/dev/null)" "is-failed after stop"

cleanup
expect "$LOG_LEVEL" "$(systemctl --user log-level)" "manager log level restored"
left=1
for _ in $(seq 1 20); do
	left="$(systemctl --user list-units --all --no-legend "$UNIT" "$RUN-*" 2>/dev/null | grep -c .)"
	[ "$left" -eq 0 ] && break
	sleep 0.1
done
expect 0 "$left" "units of this run left loaded (failed or not)"

if [ "$failures" -gt 0 ]; then
	printf 'FAIL  systemd-smoke: %d failure(s)\n' "$failures" >&2
	exit 1
fi
note "PASS  systemd-smoke"
exit 0
