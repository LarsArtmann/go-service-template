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

Then rename (the only mechanical step):

1. **Module path:** `github.com/example/go-service-template` → your module
   (`gofmt -w -r` is overkill; `grep -rl` + `sed -i` across `cmd/ internal/ views/`).
2. **Names:** `internal/app` `Name`/`Short` consts, `systemd/app.service`,
   `flake.nix` `pname`, the flake.nix `-X` flag.
3. `go mod tidy && go build ./...` — green by construction.

## Install

Prerequisites: Go ≥ 1.27.4 (or Nix with flakes — the devShell carries the
exact toolchain). BuildFlow comes from a checkout of its repo (fleet-private,
Nix-first — see its README):

```bash
nix develop                 # toolchain + treefmt + templ, no local installs
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
| `.buildflow.yml`     | BuildFlow policy (GOWORK off)                                                    |
| `.github/workflows/` | build/vet/test + golangci-lint                                                   |
| `systemd/`           | `Type=notify` + `WatchdogSec` unit (pairs with the preset's sd_notify spine)     |

## The framework surface you inherited

- `GET /healthz /readyz /startupz` + the real-time health dashboard (preset spine)
- `GET /version` + `appkit_build_info` metric (preset `Version` stamp)
- Pretty classified 404/405 error pages (preset spine, opt-out `APPKIT_ERRORPAGES=off`)
- Legs: `APPKIT_OTEL=on|off`, `APPKIT_REALTIME=on|off`, `APPKIT_SECURITY=none|standard|strict`
  (frozen env grammar; explicit code wins)
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
nix build .#app-image                             # image + structure check
nix run .#app-image-load | docker load            # or podman load
docker images                                     # tag = the store-path content hash
docker run --rm -p 8080:8080 <tag-from-above>
curl -s localhost:8080/version                    # the git rev, stamped via flake ldflags
```

Port note: the container's `ExposedPorts` is fixed at `8080/tcp` in
`flake.nix`, while the app's listen address comes from `APP_ADDR`
(default `:8080`). Keep `:8080` inside containers, or update
`container.exposedPorts` alongside any `APP_ADDR` change.

## Version stamp + refresh ritual (drift control)

`AGENTS.md` carries the stamp block: the appkit pins this template was
generated against, the go floor, and the generated date. Per the fleet
ritual, every preset/core-touching appkit train bumps the stamp and re-runs
the dogfood probe (boot + graceful-stop). Do NOT hand-edit the pinned
versions between stamps — bump via the ritual so drift stays loud.

## License

PROPRIETARY — same posture as the fleet.
