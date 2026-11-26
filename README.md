# go-service-template

The fleet's service archetype: clone, rename, ship. Scaffolds everything
AROUND the code so a new service's first hour is one clone — the go-appkit
preset spine (graceful drain, health + dashboard, error pages, sd_notify,
env-switched otel/security/realtime legs) pre-wired into a cmdguard CLI,
with the fleet's nix/BuildFlow/CI/systemd posture included — OCI images
build straight from the flake, no Dockerfile.

## Start (one command)

```bash
git clone git@github.com:LarsArtmann/go-service-template.git <your-service> && cd <your-service>
```

Then rename (the only mechanical step). Every place the template name lives:

1. **Module path** — `go.mod` plus every import:

   ```bash
   grep -rl 'github.com/example/go-service-template' --exclude-dir=.git --exclude-dir=result . \
     | xargs perl -pi -e 's|github.com/example/go-service-template|github.com/you/your-service|g'
   ```

   That set is `go.mod`, `cmd/app/main.go`, `internal/app/service.go`,
   `internal/api/routes_test.go`, `flake.nix` (the `ldflags -X` path) and
   this README.
2. **Names** — the `internal/app` `Name`/`Short` consts, the `cmd/app`
   doc comment (it carries a `<name>` placeholder too), the
   `systemd/app.service` `Description` and `ExecStart`, the `flake.nix`
   `pname` and `description` fields, and the `<name>` placeholders in
   `flake.nix` and `systemd/app.service`.
3. **Image name** — the OCI image is `container.registry` (`ghcr.io/larsartmann`
   by default) + the package name, so `pname` renames the repository too. Set
   `container.registry` when the project's remote is not GitHub.
4. `go mod tidy && go build ./...` — green by construction.
5. **Prove it:** re-run the `grep -rl` from step 1 — it must print nothing —
   then `go build ./... && go test ./... -race -count=1`. Verified on a copy
   of this commit: the rewrite leaves zero old-path matches and the suite
   passes under the new module path.

## Install

Prerequisites: Go ≥ 1.27.4 (or Nix with flakes — the devShell carries the
exact toolchain). BuildFlow comes from a checkout of its repo (fleet-private,
Nix-first — see its README):

```bash
nix develop                 # toolchain + golangci-lint/gopls/govulncheck, no local installs (`nix fmt` is treefmt; the templ generator is `go tool templ`)
buildflow --build-mode dev  # the full gate: build, race tests, lint, nix, docs
```

## What's inside

| Path                 | What it carries                                                                  |
| -------------------- | -------------------------------------------------------------------------------- |
| `cmd/app/main.go`    | cmdguard v5 CLI: `serve` verb + free `version`/`doctor` (WithBatteries)          |
| `internal/app/`      | Composition root: config.Load → preset.New → routes → Run. Whole file ~60 lines. |
| `internal/api/`      | httpx handler example (return-(T, error), classified no-leak errors)             |
| `internal/events/`   | cqrs EventService skeleton — build-tag gated (`-tags events`), delete if CRUD    |
| `views/`             | One templ page (generated `.go` committed — no templ install needed to build)    |
| `flake.nix`          | go-nix-helpers go-standard: build + devShell + treefmt + OCI image               |
| `.buildflow.yml`     | BuildFlow policy (GOWORK off, GOTOOLCHAIN pinned to the go.mod floor)            |
| `.github/workflows/` | build/vet/test + golangci-lint + `nix-image` (image build + structure check)     |
| `systemd/`           | `Type=notify` + `WatchdogSec` unit (pairs with the preset's sd_notify spine)     |
| `docs/`              | `DOMAIN_LANGUAGE.md` plus timestamped `status/` snapshots                        |
| `FEATURES.md`        | Honest inventory: what works, what is partial, what is switched off              |
| `TODO_LIST.md`       | Open work only; completed items move to `CHANGELOG.md`                           |
| `ROADMAP.md`         | Long-term direction and raw ideas, not tasks                                     |
| `CONTRIBUTING.md`    | Owner workflow + the dogfood contract every scaffold change must honour          |
| `SECURITY.md`        | Private vulnerability reporting path                                             |
| `LICENSE`            | PROPRIETARY (fleet posture)                                                      |

## The framework surface you inherited

- `GET /healthz /readyz /startupz` — the probes; the real-time dashboard at
  `/health` owns them (preset spine)
- `GET /version` + `appkit_build_info` metric (preset `Version` stamp)
- Pretty classified 404/405 error pages (preset spine, opt-out `APPKIT_ERRORPAGES=off`)
- Legs: `APPKIT_OTEL=on|off`, `APPKIT_REALTIME=on|off` (SSE hub at `/events`),
  `APPKIT_SECURITY=none|standard|strict` (frozen env grammar; explicit code wins)
- SIGINT/SIGTERM → full graceful drain with one grep-able log line per phase
- sd_notify READY/STOPPING/watchdog when running under the systemd unit

## Verify

```bash
go build ./... && go test ./... -race -count=1   # the suite
go run ./cmd/app serve &                          # boots on :8080
curl -s localhost:8080/api/status && curl -s localhost:8080/healthz
kill -TERM %1                                     # watch the drain phase lines
```

The OCI image (built from the flake, no Dockerfile):

```bash
nix build .#app-image                             # the image (packages shorthand)
nix build .#checks.<system>.container-structure   # posture gate: user, ports, entrypoint
nix build .#checks.<system>.image-smoke-archive   # daemonless: OCI layout at result/layout
bash scripts/image-smoke.sh result/layout         # boot + endpoint matrix + SIGTERM drain (docker or podman)
skopeo copy oci:result/layout docker-archive:/tmp/app.tar:app:latest   # docker tags only a docker archive
docker load -i /tmp/app.tar                       # manual load
docker run --rm -p 8080:8080 app:latest           # manual boot once loaded
curl -s localhost:8080/version                    # the git rev, stamped via flake ldflags
```

`<system>` is your Nix system (`x86_64-linux`, `aarch64-linux`, …). `checks`
is a per-system attrset, so the `.#name` shorthand that works for
`packages`/`apps` does not reach it.

Port note: the container's `ExposedPorts` is fixed at `8080/tcp` in
`flake.nix`, while the app's listen address comes from `APP_ADDR`
(default `:8080`). Keep `:8080` inside containers, or update
`container.exposedPorts` alongside any `APP_ADDR` change.

## Docs in this repo

Each doc has one job, and a fact lives in exactly one of them:

| File                      | Owns                                          |
| ------------------------- | --------------------------------------------- |
| `README.md`               | What this is, why, how to start (this file)   |
| `AGENTS.md`               | Non-obvious context for AI sessions           |
| `FEATURES.md`             | What ships + honest status per feature        |
| `TODO_LIST.md`            | Open, bounded, short-term work                |
| `ROADMAP.md`              | Long-term direction, raw ideas                |
| `CHANGELOG.md`            | What changed, per date                        |
| `docs/DOMAIN_LANGUAGE.md` | The archetype's vocabulary                    |
| `docs/status/`            | Point-in-time reports (annotated, not edited) |

Run the docs gates with `docs-gates run .` (freshness, annotate, routing,
cadence).

## Version stamp + refresh ritual (drift control)

`AGENTS.md` carries the stamp block: the appkit pins this template was
generated against, the go floor, and the generated date. Per the fleet
ritual, every preset/core-touching appkit train bumps the stamp and re-runs
the dogfood probe (boot + graceful-stop). Do NOT hand-edit the pinned
versions between stamps — bump via the ritual so drift stays loud.
Posture-only changes (docs, CI, packaging) deliberately do not bump the
stamp, so the `Generated` date tracks the last appkit train, not the last
commit.

## License

PROPRIETARY — same posture as the fleet.
