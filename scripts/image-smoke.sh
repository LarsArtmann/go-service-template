#!/usr/bin/env bash
# Image smoke: boot the OCI image and probe it end to end. The container
# sibling of scripts/probe.sh — TODO row 1's repeatable proof that the
# Nix-built image actually runs, serves, and drains.
#
# Usage:
#   scripts/image-smoke.sh <oci-layout-dir | docker-archive.tar> [expected-version]
#
# The layout dir is what `nix build
# .#checks.x86_64-linux.image-smoke-archive` produces (result/layout).
# Without an expected version the script uses `git rev-parse HEAD` — the
# flake stamps the image from the git rev, so a stale artifact fails here
# loudly.
#
# Environment:
#   SMOKE_PORT     host port to publish 8080 onto (default 18199, walks upward)
#   SMOKE_RUNTIME  docker | podman (default: docker if a daemon answers, else podman)
#
# Requires: curl, jq, tar; docker (CI) or podman (dev machine, rootless).
# skopeo as well when the runtime is docker and the input is a layout dir.

set -uo pipefail

failures=0
note() { printf '%s\n' "$*"; }
bail() {
	printf 'FAIL: %s\n' "$*" >&2
	failures=$((failures + 1))
}
expect() { # want actual what
	if [ "$2" = "$1" ]; then note "ok    $3 = $2"; else bail "$3 = $2 (want $1)"; fi
}

LAYOUT=""
ARCHIVE="${1:-}"
EXPECT="${2:-}"

if [ -z "$ARCHIVE" ]; then
	bail "usage: image-smoke.sh <docker-archive.tar | oci-layout-dir> [expected-version]"
	exit 1
fi
if [ -d "$ARCHIVE" ]; then
	# OCI layout dir (checks.x86_64-linux.image-smoke-archive output). It is
	# turned into a tar below, once the runtime is known.
	[ -f "$ARCHIVE/index.json" ] || {
		bail "not an OCI layout (no index.json): $ARCHIVE"
		exit 1
	}
	LAYOUT="$ARCHIVE"
elif [ ! -f "$ARCHIVE" ]; then
	bail "archive not found: $ARCHIVE"
	exit 1
fi

if [ -z "$EXPECT" ]; then
	EXPECT="$(git rev-parse HEAD 2>/dev/null)"
	if [ -z "$EXPECT" ]; then
		bail "no expected version given and not a git repo"
		exit 1
	fi
fi

detect_runtime() {
	if [ -n "${SMOKE_RUNTIME:-}" ]; then
		printf '%s' "$SMOKE_RUNTIME"
		return 0
	fi
	if docker info >/dev/null 2>&1; then
		printf 'docker'
	elif podman info >/dev/null 2>&1; then
		printf 'podman'
	else
		return 1
	fi
}

RT="$(detect_runtime)" || {
	# Dev machine convenience: podman is not on PATH but nix can provide it.
	# One re-exec; the guard prevents a loop if nix cannot help either.
	if ! command -v podman >/dev/null 2>&1 && command -v nix >/dev/null 2>&1 && [ -z "${SMOKE_NIX_REEXEC:-}" ]; then
		exec env SMOKE_NIX_REEXEC=1 nix shell nixpkgs#podman -c bash "$0" "$@"
	fi
	bail "no container runtime: docker daemon unreachable and podman unavailable"
	exit 1
}

if [ -n "$LAYOUT" ]; then
	# podman tags an OCI-layout tarball itself. docker prints "Loaded image:
	# <ref>" for one but never applies the tag, so the run that follows falls
	# through to a pull ("pull access denied"); for docker the layout becomes
	# a docker archive first, which is the only tar form docker tags.
	ARCHIVE="$(mktemp /tmp/image-smoke-XXXXXX.tar)"
	if [ "$RT" = podman ]; then
		tar -C "$LAYOUT" -cf "$ARCHIVE" .
	else
		# Same re-exec convenience as podman above: nix provides skopeo.
		if ! command -v skopeo >/dev/null 2>&1 && command -v nix >/dev/null 2>&1 && [ -z "${SMOKE_SKOPEO_REEXEC:-}" ]; then
			exec env SMOKE_SKOPEO_REEXEC=1 SMOKE_RUNTIME=docker nix shell nixpkgs#skopeo -c bash "$0" "$@"
		fi
		command -v skopeo >/dev/null 2>&1 || {
			bail "docker needs skopeo to turn an OCI layout into a docker archive: put skopeo on PATH, or pass a docker archive (skopeo copy oci:<layout> docker-archive:<tar>:<ref>)"
			exit 1
		}
		# The layout's own ref name (what packaged it) is the tag to load.
		REF_NAME="$(jq -r '.manifests[0].annotations["org.opencontainers.image.ref.name"] // empty' "$LAYOUT/index.json")"
		skopeo copy --insecure-policy "oci:$LAYOUT" "docker-archive:$ARCHIVE:${REF_NAME:-app:latest}" || {
			bail "skopeo could not convert the layout to a docker archive: $LAYOUT"
			exit 1
		}
	fi
fi

PORT="${SMOKE_PORT:-18199}"
port_busy() { curl -s -o /dev/null --connect-timeout 1 "localhost:$1" >/dev/null 2>&1; }
while port_busy "$PORT"; do PORT=$((PORT + 1)); done

NAME="image-smoke-$$"
REF=""
cleanup() { "$RT" rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

note "runtime $RT, archive $ARCHIVE"
LOADOUT="$("$RT" load -i "$ARCHIVE" 2>&1)"
# "Loaded image: app:latest" (docker), "Loaded image(s): …" (podman),
# "Loaded image ID: sha256:…" (unnamed OCI loads) — one pattern strips all.
REF="$(printf '%s' "$LOADOUT" | grep -m1 'Loaded image' | sed 's/^Loaded image[^:]*: //')"
[ -n "$REF" ] || {
	bail "could not parse loaded image from: $(printf '%s' "$LOADOUT" | tail -2)"
	exit 1
}
note "image  $REF"
# A printed ref is not a loaded ref: docker reports "Loaded image: app:latest"
# for a tarred OCI layout and still cannot run it. Ask the runtime itself.
if ! "$RT" image inspect "$REF" >/dev/null 2>&1; then
	bail "$RT reported '$REF' but cannot resolve it: the archive was loaded without its tag. Pass the OCI layout directory itself (it is converted for docker) or a docker archive, not a tarred layout"
	exit 1
fi

"$RT" run -d --name "$NAME" -p "127.0.0.1:$PORT:8080" "$REF" >/dev/null || {
	bail "container failed to start"
	exit 1
}

BASE="http://127.0.0.1:$PORT"
ready=""
for _ in $(seq 1 30); do
	[ "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/startupz")" = "200" ] && ready=1 && break
	sleep 0.5
done
[ -n "$ready" ] || {
	bail "container never reached /startupz 200"
	"$RT" logs "$NAME" >&2 || true
	exit 1
}
note "ok    container ready on port $PORT"

for ep in healthz readyz startupz api/status version health; do
	expect 200 "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/$ep")" "/$ep"
done
expect 200 "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/")" "/ (views page)"
expect 404 "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/nope")" "/nope"

VERSION="$(curl -s "$BASE/version" | jq -r '.version')"
expect "$EXPECT" "$VERSION" "/version stamp (rev-identical image)"

phases="ready_flip drain_hooks drain_wait listener_close shutdown_hooks"
"$RT" stop -t 20 "$NAME" >/dev/null || bail "SIGTERM stop failed"
LOG="$("$RT" logs "$NAME" 2>&1)"
for phase in $phases; do
	printf '%s' "$LOG" | grep -q "phase=$phase" || bail "drain phase missing: $phase"
done
printf '%s' "$LOG" | grep -q "phase=ready_flip" && note "ok    drain phases present (SIGTERM)"

if [ "$failures" -gt 0 ]; then
	printf 'FAIL  image-smoke: %d failure(s)\n' "$failures" >&2
	exit 1
fi
note "PASS  image-smoke"
