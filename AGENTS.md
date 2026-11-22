# Agent Notes

Production posture: go-appkit preset spine + cmdguard CLI. Module truth lives
in the appkit READMEs (this repo contains no framework code).

## Docs map — each doc owns one thing

| File                      | Owns                                                     |
| ------------------------- | -------------------------------------------------------- |
| `README.md`               | Why the archetype exists, install, rename, how to verify |
| `FEATURES.md`             | What ships, with honest per-feature status + evidence    |
| `TODO_LIST.md`            | Open bounded work only (never completed items)           |
| `ROADMAP.md`              | Long-term direction and raw ideas, not tasks             |
| `CHANGELOG.md`            | Dated history of what changed                            |
| `docs/DOMAIN_LANGUAGE.md` | The archetype's vocabulary (verify terms against code)   |
| `docs/status/`            | Timestamped reports — annotate, never rewrite            |

Doctrine: a completed TODO leaves `TODO_LIST.md` for `CHANGELOG.md`; a fact
lives in exactly one doc; `docs-gates run .` is the gate over all of it.

## Version stamp (drift control — bump via the ritual, not by hand)

| Component        | Value                                                                                                                                |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Template source  | github.com/LarsArtmann/go-service-template                                                                                           |
| Generated        | 2026-11-21                                                                                                                           |
| go-appkit preset | v0.1.1 (core v0.12.0, httpx v0.2.0, cqrs v0.9.0, config v0.1.1)                                                                      |
| cmdguard         | v5.1.0                                                                                                                               |
| templ (runtime)  | v0.3.1100 (the fleet-migrated pairing: templ-components v1.27.2 + go-health-dashboard v0.13.3; cmdguard v5.1.0 requires ≥ v0.3.1100) |
| Go floor         | 1.27.4                                                                                                                               |

Refresh ritual: every preset/core-touching appkit train bumps this stamp and
re-runs the dogfood probe (build, boot, `/healthz` + `/api/status` probe,
SIGTERM graceful-stop). An appkit adopter refreshing from the template
re-clones rather than merging — the template is a starting point, not a
shared module.

**Posture-only changes do NOT bump this stamp.** Docs, CI, flake packaging and
the Dockerfile→Nix-OCI migration changed the repo without moving the appkit
pins, so `Generated` still reads 2026-11-21. The ritual exists to make
dependency drift loud, not to date-stamp every commit.

## Build & verify

```bash
buildflow --build-mode dev     # the gate: build, race tests, golangci-lint, nix, treefmt, docs-gates
buildflow doctor               # environment/binary triage
docs-gates run .               # the docs battery alone (freshness, audit-all, annotate, routing, cadence)
nix build .#app-image          # OCI image (packages shorthand)
nix build .#checks.<system>.container-structure  # posture gate (per-system attrset)

# raw fallbacks (what the gate wraps):
go build ./...
go test ./... -race -count=1
golangci-lint run ./...        # config copied from the appkit fleet standard
nix build                      # vendorHash.nix + goTarballHash.nix are filled; a floor bump prints the new hash
```

Verified 2026-11-22 on the Nix-built binary (`result/bin/app`): boot via
`APP_ADDR=:18089`, `/healthz` + `/readyz` + `/startupz` + `/api/status` +
`/version` + `/health` + `/` all 200, `/nope` 404, five-phase SIGTERM drain,
`version` prints the git rev, `doctor` 2/2. There is no container runtime on
the dev machine — the IMAGE itself has never been booted (TODO_LIST row 1).

## OCI image (no Dockerfile, by policy)

The image is assembled by the go-standard `container` option (nix2container,
auto-wired by the composite flakeModule) directly from the flake — the
Dockerfile was deleted because OCI images must come from Nix. Equivalent
posture to the old Dockerfile: non-root `65532:65532`, cacert included,
`app serve` entrypoint, `8080/tcp` exposed, content-hash tag. Outputs
(Linux only): `packages.app-image`, `apps.app-image-load` (pipe into a local
docker/podman), `apps.app-image-push` (skopeo to `ghcr.io/larsartmann/app`),
`checks.<system>.container-structure`. The `Version` stamp rides the flake's `ldflags`
(`-X .../internal/app.Version=${self.rev...}`), not a Docker build arg.

**systemd vs container deploy paths.** `systemd/app.service` (`Type=notify` +
watchdog) pairs with the preset's sd_notify spine for bare-metal/systemd
hosts. Inside the OCI container there is no systemd — the preset detects the
missing `NOTIFY_SOCKET` and the sd_notify calls degrade to no-ops, so the
same binary runs in both without flags. Pick one path per deploy target;
they are not layered.

## Gotchas

- **The rename is not confined to Go files.** `go.mod`, the `flake.nix`
  `ldflags -X` path, and `pname` (which names the image repository:
  `container.registry` + package name) all carry the template identity. The
  README's rename section has the `grep -rl | xargs perl -pi` command and
  the proof step; run the proof, not just the rename.
- **`dprint.json` names absolute plugin paths**
  (`/home/lars/.local/state/buildflow/dprint-plugins/...`) whenever
  `BUILDFLOW_DPRINT_PLUGINS` is set, which is the owner machine's default.
  BuildFlow regenerates that form, so hand-editing it is whack-a-mole; an
  adopter on another machine resolves the committed absolute paths to nothing.
  Tracked as TODO_LIST row 10.
- `.dockerignore` is a BuildFlow regeneration artifact kept despite the
  `hasDockerfile` gate. It is inert (no Dockerfile by policy); do not treat
  its presence as Docker posture. Upstream investigation: TODO_LIST row 7.
- **`nix-checker` warns "goTarballHash is inlined in goTarballHash.nix"** —
  a self-referential false positive: the hash IS in that file because the
  checker asked for it to move out of `flake.nix`. Do not "fix" it again by
  extracting a third file.
- `internal/events/` is behind the `events` build tag; `go mod tidy` keeps
  the cqrs require alive because tidy considers all build configurations.
- `views/*_templ.go` files are COMMITTED so plain `go build` works without a
  templ install; regenerate with `templ generate` after editing `.templ`
  files, then run the formatter (`buildflow --fix`) — regen output can
  re-drift from the treefmt-fixed committed copy.
- Signal handling is the framework's (core `Run`); do not add a second
  NotifyContext.
- Probe boot on a non-8080 port (`APP_ADDR=:18089`) — dev machines commonly
  have other services squatting 8080; the app classifies the bind failure
  as `[Infrastructure:server.listen_failed]`.
- **An auto-git daemon commits the working tree every few minutes.** Commit
  coherent work yourself before its next tick; otherwise it batches your
  changes with unrelated ones and history attribution blurs (observed
  2026-11-22, commit `fb7200c`: eleven files from three different authors).
