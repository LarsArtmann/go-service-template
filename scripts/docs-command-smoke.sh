#!/usr/bin/env bash
# docs-command smoke check — every command the living docs name must either
# run clean or carry an explicit, machine-checked skip reason.
#
# Modes:
#   (no flag)      full local run: executes the RUN_SAFE list under timeout,
#                  asserts NEEDS_RUNTIME/MUTATING entries are documented and
#                  their prerequisites are classified (never executed here).
#   --self-test    sandbox-safe subset for `nix build` checks: syntax-check
#                  this script and verify every inventory entry still appears
#                  in the living docs (inventory rot alarm).
#
# Inventory upkeep: add a command to the docs and it lands in exactly one
# class below; remove it from the docs and --self-test fails until the
# inventory row is removed too.

set -uo pipefail

# Repo root when run from a checkout; in the nix sandbox ($0 is a bare store
# path, so dirname/.. is /) keep the derivation cwd instead — the README
# marker tells the two apart. DOCS_DIR overrides both for callers that stage
# the docs elsewhere.
_from="$(pwd)"
cd "$(dirname "$0")/.." 2>/dev/null || true
[ -f "README.md" ] || cd "$_from"
DOCS_DIR="${DOCS_DIR:-.}"

DOCS=(README.md AGENTS.md CONTRIBUTING.md FEATURES.md TODO_LIST.md ROADMAP.md CHANGELOG.md docs/DOMAIN_LANGUAGE.md)

failures=0
note() { printf '%s\n' "$*"; }
bail() {
	printf 'FAIL: %s\n' "$*" >&2
	failures=$((failures + 1))
}

run_safe() { # cmd... — executed under timeout; nonzero exit = failure
	local cmd="$*"
	if ! command -v "${cmd%% *}" >/dev/null 2>&1; then
		bail "RUN_SAFE binary missing: ${cmd%% *}"
		return
	fi
	if timeout 600 bash -c "$cmd" >/dev/null 2>&1; then
		note "ok    $cmd"
	else
		bail "RUN_SAFE command failed: $cmd"
	fi
}

classified() { # class cmd — must appear in docs; never executed
	local class="$1"
	shift
	local cmd="$*"
	local hit=0
	local doc
	for doc in "${DOCS[@]}"; do
		[ -f "$doc" ] || continue
		if grep -qF -- "$cmd" "$DOCS_DIR/$doc"; then
			hit=1
			break
		fi
	done
	if [ "$hit" -eq 1 ]; then
		note "ok    [$class] documented: $cmd"
	else
		bail "[$class] inventory row not found in living docs: $cmd"
	fi
}

if [ "${1:-}" = "--self-test" ]; then
	bash -n "$0" || bail "script has syntax errors"
	for cmd in \
		"go build ./..." \
		"go vet ./..." \
		"nix build .#app-image" \
		"docs-gates run ." \
		"docker load" \
		"scripts/image-smoke.sh" \
		"systemd-run"; do
		classified INVENTORY "$cmd"
	done
	[ "$failures" -eq 0 ] && note "self-test: clean"
	exit "$failures"
fi

# --- RUN_SAFE: executed here, under timeout --------------------------------
run_safe "go build ./..."
run_safe "go vet ./..."
run_safe "go build -tags events ./..."
run_safe "go vet -tags events ./..."
run_safe "dprint check"
run_safe "gitleaks git ."
run_safe "go tool templ --version"
run_safe "golangci-lint --version"
run_safe "nix flake show --all-systems --json"
run_safe "docs-gates run ."

# --- MUTATING: proven present, deliberately not executed --------------------
command -v dprint >/dev/null 2>&1 || bail "MUTATING binary missing: dprint (dprint fmt)"
command -v go >/dev/null 2>&1 || bail "MUTATING binary missing: go (go mod tidy, go tool templ generate)"
command -v buildflow >/dev/null 2>&1 || bail "MUTATING binary missing: buildflow (buildflow --fix)"

# --- NEEDS_RUNTIME: classified skips, each with its documented reason -------
if command -v docker >/dev/null 2>&1 || command -v podman >/dev/null 2>&1; then
	note "note  container runtime present; image boot runs via scripts/image-smoke.sh, not here"
else
	note "skip  docker load / docker run: no container runtime on this host (documented: README, AGENTS)"
fi
classified NEEDS_RUNTIME "docker load"
classified NEEDS_RUNTIME "docker run --rm -p 8080:8080"
classified NEEDS_RUNTIME "scripts/image-smoke.sh"
classified NEEDS_RUNTIME "nix run .#app-image-push"
classified NEEDS_RUNTIME "systemd-run"

if [ "$failures" -eq 0 ]; then
	note "docs-command smoke: clean"
	exit 0
fi
printf 'docs-command smoke: %d failure(s)\n' "$failures" >&2
exit 1
