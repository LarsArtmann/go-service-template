# TODO List

> Short-term, actionable, bounded work for go-service-template. Open items
> only — completed work is recorded in [CHANGELOG.md](CHANGELOG.md) and git
> history, never kept here as a "Closed" section.
>
> Long-term direction lives in [ROADMAP.md](ROADMAP.md); what already works is
> in [FEATURES.md](FEATURES.md).
>
> **Last sweep:** 2026-11-22 · Crush (docs-health AUDIT) · basis: full code
> read, Nix-built binary probe (boot, endpoint sweep, five-phase SIGTERM
> drain), `docs-gates run .` PASS, and a harvest of
> `docs/status/2026-11-22_19-43_dockerfile-to-nix-oci-migration-status.md` §f
> plus the previous list's open rows (re-verified, not carried on trust).

## Status legend

| Status      | Meaning                                                       |
| ----------- | ------------------------------------------------------------- |
| TODO        | Not started. Needs doing.                                     |
| IN_PROGRESS | Actively being worked on.                                     |
| BLOCKED     | Cannot proceed: external dependency, push, or owner decision. |

## Open items

Impact and effort are S/M/L. Evidence is the file/line or the command that
proves the item is still open — every row was checked this sweep.

| ID | Task                                                                                                                                                                                                                 | Status  | Impact | Effort | Evidence                                                                                                                                                                           |
| -- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | ------ | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1  | Image boot-smoke: load `.#app-image`, run it, probe `/healthz` + `/api/status` + `/version`, SIGTERM-drain it; then mechanize as a `checks.image-smoke` flake check so the proof travels with the flake.             | TODO    | High   | M      | `flake.nix:58-62`. The image builds and `.#checks.<system>.container-structure` passes, but nothing has ever booted it (no docker/podman on the dev machine). §f1, §f2, §f26, §f50 |
| 2  | Dogfood probe of the post-migration skeleton: fresh clone → rename flow per the (just-corrected) README → build → boot → image build.                                                                                | TODO    | High   | M      | The rename checklist itself changed this sweep (it omitted `go.mod`), so the flow is unproven end-to-end. §f4                                                                      |
| 3  | Verify `nix flake check` / eval on a darwin (and aarch64) host — the container outputs are Linux-only and must not break eval elsewhere.                                                                             | TODO    | High   | S      | `flake.nix:52-61` (`container` option). A template that fails eval on a macOS adopter's machine is unusable. §f7                                                                   |
| 4  | CI execution evidence: push and watch the pin-bumped `ci.yml` (build/vet/test + lint + `nix-image`) stay green.                                                                                                      | BLOCKED | High   | S      | `.github/workflows/ci.yml:12-65`; zero runs observed since the action pins landed. §f3                                                                                             |
| 5  | Image publish path: decide CI-to-`ghcr.io` versus manual `nix run .#app-image-push`, then wire whichever wins (credentials decision included).                                                                       | BLOCKED | High   | M      | The push app exists and is unexercised; the policy question is owner-level. §f6, §g2                                                                                               |
| 6  | go.mod floor shape: keep the patch-pinned `go 1.27.4` (fleet floor ritual, mirrored by the flake tarball pin and the AGENTS stamp) or follow BuildFlow's major.minor-only rule.                                      | BLOCKED | Medium | S      | `go.mod:3`, `.buildflow.yml:12`, `flake.nix:32-37`, AGENTS stamp. Direct tension between two fleet standards. §f11, §g3                                                            |
| 7  | Upstream BuildFlow: `.dockerignore` reappears despite the `hasDockerfile` gate. Verify the reproduction, then file an issue.                                                                                         | TODO    | Medium | M      | `.dockerignore` exists, no Dockerfile does; it is inert but regenerated. Run `verify-before-filing` first. §d1, §f8                                                                |
| 8  | Upstream BuildFlow: a positive `no-dockerfile` gate (fail when a Dockerfile appears) so the posture is enforced, not merely un-generated.                                                                            | TODO    | Low    | M      | No such step exists; the current gate only declines to generate Docker hygiene. §f36                                                                                               |
| 9  | Upstream BuildFlow: analyzer-go-version — the buildflow binary is compiled with go1.27.3 while the workspace floor is 1.27.4.                                                                                        | TODO    | Low    | S      | Mitigated here by `GOTOOLCHAIN: "go1.27.4"` (`.buildflow.yml:12`); the root fix is a newer Go pin in BuildFlow's flake.                                                            |
| 10 | Template portability: `dprint.json` names absolute `/home/lars/.local/state/buildflow/…` plugin paths and a `dockerfile` plugin for a no-Dockerfile repo. Decide the committed form (remote URLs vs shipped bundle). | TODO    | Medium | S      | `dprint.json:4-7`. BuildFlow regenerates the local form whenever `BUILDFLOW_DPRINT_PLUGINS` is set, so a one-off edit is whack-a-mole — the fix is a documented decision.          |
| 11 | Write the ADR "OCI images from Nix, no Dockerfile" (decision, rejected alternatives, what would reopen it) under `docs/decisions/`.                                                                                  | TODO    | Low    | S      | The decision lives only in CHANGELOG prose and a status report today. §f49                                                                                                         |
| 12 | Add a CI security-scanning step (gitleaks) — `SECURITY.md` no longer claims scanning exists, so the gap is visible and should be closed.                                                                             | TODO    | Low    | S      | `.github/workflows/ci.yml` carries no scanner; the false claim was removed this sweep.                                                                                             |
| 13 | Run `buildflow --build-mode full` once (race + coverage lane) and refresh `reports/coverage.out`.                                                                                                                    | TODO    | Low    | M      | Only dev mode was run; `reports/coverage.out` is git-ignored and stale. §f29                                                                                                       |
| 14 | CI: cache the `go install golangci-lint` step.                                                                                                                                                                       | TODO    | Low    | S      | `.github/workflows/ci.yml:41-42` reinstalls the pinned binary on every run. §f30                                                                                                   |
| 15 | Pre-commit hook state for fresh clones: decide whether adopters must run `buildflow precommit install`, and say so in CONTRIBUTING.                                                                                  | TODO    | Low    | S      | `CONTRIBUTING.md` calls the gate the merge bar; a freshly cloned repo has no hook installed.                                                                                       |

## Not in this list

- **Long-term direction** (multi-arch images, signing, SBOM, publish automation,
  the deploy-story ADR set, fleet census, prepared-source migration): see
  [ROADMAP.md](ROADMAP.md).
- **Closed this sweep** (evidence in [CHANGELOG.md](CHANGELOG.md)):
  LICENSE/README/CONTRIBUTING/editorconfig/gitattributes gaps, flake.lock
  dedupe, image reproducibility + posture, version-stamp end-to-end, the
  `nix-image` CI job, `APP_ADDR`-vs-`ExposedPorts` documentation, dependabot
  ecosystem coverage, erraudit findings (0 violations; samber/oops is not a
  dependency), and the docs-gates annotate repair.
