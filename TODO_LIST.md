# TODO List

> Short-term, actionable, bounded work for go-service-template. For shipped
> changes, see [CHANGELOG.md](CHANGELOG.md) and git history. Last docs-health
> sweep: 2026-11-22 (Dockerfile removed — OCI images build from the flake via
> the go-standard `container` option). Follow-up session same day closed the
> open verification loop: see "Closed" below.

## Status legend

| Status      | Meaning                                                 |
| ----------- | ------------------------------------------------------- |
| TODO        | Not started. Needs doing.                               |
| IN_PROGRESS | Actively being worked on.                               |
| BLOCKED     | Cannot proceed, external dependency or decision needed. |

## Open items

1. **TODO — Image boot-smoke inside a real container runtime.** The binary
   probe passes (boot, `/healthz`, `/api/status`, `/version` git rev,
   full SIGTERM drain), but no docker/podman exists on the dev machine, so
   the image itself has never been loaded/run. Needs `nix run
   .#app-image-load | docker load` → run → probe → drain, ideally mechanized
   as a flake check (`checks.image-smoke`).
2. **BLOCKED (needs push) — CI execution evidence.** `ci.yml` now carries the
   tool-bumped action pins plus a new `nix-image` job (`.#app-image` +
   `.#checks.container-structure`). Zero CI runs observed; push and watch.
3. **BLOCKED (owner policy) — image publish path.** CI job to
   `ghcr.io/larsartmann/<name>` vs manual `nix run .#app-image-push`.
4. **BLOCKED (owner policy) — go.mod floor shape.** Patch-pinned `go 1.27.4`
   (fleet floor ritual, mirrored by flake tarball pin + AGENTS stamp) vs
   BuildFlow's major.minor-only rule. Direct tension; needs a call, not a
   silent fix.
5. **TODO — Upstream BuildFlow: `.dockerignore` ghost artifact.** File is
   inert (no Dockerfile by policy) but regenerated mid-session despite the
   `hasDockerfile` gate. verify-before-filing, then an upstream issue.
6. **TODO — Upstream BuildFlow: analyzer-go-version.** buildflow binary is
   compiled with go1.27.3 while the workspace floor is 1.27.4. Mitigated here
   by the `GOTOOLCHAIN: "go1.27.4"` pin in `.buildflow.yml`; root fix is a
   newer Go pin in BuildFlow's flake.
7. **TODO (decided) — ROADMAP.md: none.** This template keeps no roadmap
   file; long-term fuel (multi-arch images, signing, SBOM, deploy story)
   lives in the timestamped status report until it ripens into a bounded
   task above.

## Closed (evidence-verified 2026-11-22)

- flake.lock duplicate `flake-parts` pin → `follows` deduped; doctor WARN
  cleared.
- buildflow stale binary (be700ae) → rebuilt + reinstalled (769b3a4);
  binary-freshness WARN cleared; `nix-hash-fix` 14/14 failures absent from
  the post-rebuild dev gate run.
- `.#app-image` reproducibility: two consecutive builds → identical
  store path (the earlier mismatch raced an in-flight `nix flake lock`).
- Image posture verified in `image-app.json`: `65532:65532` user,
  `8080/tcp`, `SSL_CERT_FILE` cacert env, `/bin/app serve`, rev in labels.
- Version stamp end-to-end: `go run` + Nix-built binary both report the git
  rev on `/version` and `/api/status`; SIGTERM drain shows all five phases.
- docs-gates annotate F/spacing in the migration status report → repaired;
  gate CLEAN (and dprint-stable).
- erraudit "3 findings" from the previous report → do not reproduce; 0
  violations; samber/oops was never a dependency (fleet posture here is
  `fmt.Errorf`/go-error-family, which the lint config explicitly allows).
- LICENSE added — the fleet-standard proprietary text (matches README).
- README: image verify commands + `APP_ADDR` vs `ExposedPorts` footgun;
  AGENTS.md: buildflow-first commands, systemd-vs-container deploy paths,
  templ-regen/treefmt gotcha, 8080-squatter probe gotcha.
