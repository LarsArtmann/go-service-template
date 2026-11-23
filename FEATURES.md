# Features

**Created:** 2026-11-22 · Crush (docs-health AUDIT sweep) · basis: code read
plus a run of the Nix-built binary (`result/bin/app`: boot on `APP_ADDR=:18089`,
endpoint sweep, five-phase SIGTERM drain, `version` / `doctor`).

> Honest inventory of what this archetype ships, by status. The framework
> code lives in go-appkit and cmdguard — this repo carries only the
> composition, the examples, and the posture. A row is
> `FULLY_FUNCTIONAL` only when working code exists AND it was exercised.

## Status legend

Every label answers ONE question: does working code exist, and if not, why
not?

| Status               | Meaning                                                                                                                            |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| FULLY_FUNCTIONAL     | Code present AND working (test suite passes or exercised by a probe).                                                              |
| PARTIALLY_FUNCTIONAL | Ships but has known gaps — an unexercised edge, a missing proof, or an undecided policy.                                           |
| BROKEN               | Code exists but fails. Zero BROKEN rows is information: nothing in this repo is known-broken.                                      |
| DISABLED             | Code exists and is correct, but execution is externally switched off (build tag, env leg, not-yet-pushed CI). A switch, not a fix. |
| PLANNED              | No code yet; genuinely next on the build path (see [TODO_LIST.md](TODO_LIST.md) / [ROADMAP.md](ROADMAP.md), not this file).        |

## CLI — `cmd/app` (cmdguard v5)

| Feature        | Status           | Evidence                                                           | Notes                                                                      |
| -------------- | ---------------- | ------------------------------------------------------------------ | -------------------------------------------------------------------------- |
| `serve` verb   | FULLY_FUNCTIONAL | `cmd/app/main.go:31-50`; probed: booted and served on `:18089`     | Blocks until SIGINT/SIGTERM; `serveFlags` is empty on purpose (env-driven) |
| `version` verb | FULLY_FUNCTIONAL | `cmd/app/main.go:52` (`WithBatteries`); probed: prints the git rev | Free with `WithBatteries`; skips itself if `app.Version` were empty        |
| `doctor` verb  | FULLY_FUNCTIONAL | `cmd/app/main.go:52`; probed: `2 passed, 0 failed`                 | Validates the config struct and the flag registry                          |

## HTTP surface

| Feature                                 | Status           | Evidence                                                                                                     | Notes                                                                           |
| --------------------------------------- | ---------------- | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------- |
| `GET /api/status` JSON                  | FULLY_FUNCTIONAL | `internal/api/routes.go:24-29`; `internal/api/routes_test.go:12`; probed `{"status":"ok","version":"<rev>"}` | The httpx return-`(T, error)` example: nil error → JSON 200                     |
| `GET /` templ page                      | FULLY_FUNCTIONAL | `views/views.go:13`, `views/hello.templ:3`; probed 200 with the rev                                          | Generated `views/hello_templ.go` is committed, so `go build` needs no templ     |
| `/healthz` `/readyz` `/startupz` probes | FULLY_FUNCTIONAL | preset spine (dashboard owns the health surface); probed 200/200/200                                         | `/readyz` flips to 503 plus `shutting_down` during drain                        |
| Health dashboard at `/health`           | FULLY_FUNCTIONAL | preset `health.Mount(..., WithDashboard())`; probed 200                                                      | HTML + JSON + SSE views of the same probe state                                 |
| `GET /version` JSON                     | FULLY_FUNCTIONAL | preset version stamp (`preset.Config.Version`); probed → git rev                                             | Feeds the `appkit_build_info` metric when metrics are enabled                   |
| Pretty 404/405 pages                    | FULLY_FUNCTIONAL | preset errorpages spine; probed 404 for `/nope`                                                              | Status verified here; the rendered body is framework-owned (appkit tests)       |
| SSE hub at `/events`                    | DISABLED         | preset leg `APPKIT_REALTIME` (off when absent)                                                               | Mounted only with `APPKIT_REALTIME=on`; never exercised in this repo            |
| OTel tracing                            | DISABLED         | preset leg `APPKIT_OTEL` (off when absent)                                                                   | Enabling needs an OTLP endpoint; the template ships no collector                |
| Security profiles                       | DISABLED         | preset leg `APPKIT_SECURITY` (`none` when absent)                                                            | `standard` = headers + body limit; `strict` = + origin check (origins required) |

## Configuration

| Feature                                         | Status           | Evidence                                                              | Notes                                                                        |
| ----------------------------------------------- | ---------------- | --------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| Typed config load (`APP_ADDR`, `APP_LOG_LEVEL`) | FULLY_FUNCTIONAL | `internal/app/service.go:31-41`; probe booted on `APP_ADDR=:18089`    | Precedence flag > env > file > default; one Rejection naming every bad field |
| Framework leg env grammar                       | FULLY_FUNCTIONAL | preset README grammar table; invalid values fail fast at `preset.New` | Frozen vocabulary: `on`/`off`, `none`/`standard`/`strict`                    |

## Lifecycle

| Feature                             | Status           | Evidence                                                                                                                                          | Notes                                                                            |
| ----------------------------------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| Graceful drain, five phases         | FULLY_FUNCTIONAL | probe SIGTERM log: `ready_flip` → `drain_hooks` → `drain_wait` → `listener_close` → `shutdown_hooks`, then `graceful shutdown complete result=ok` | Signal handling belongs to core `Run` — never add a second NotifyContext         |
| sd_notify (READY/STOPPING/watchdog) | DISABLED         | preset `systemd.Install`; `systemd/app.service` (`Type=notify`, `WatchdogSec=30s`)                                                                | Activates only under systemd (`NOTIFY_SOCKET` present); a silent no-op elsewhere |

## Packaging & deploy

| Feature                          | Status               | Evidence                                                                         | Notes                                                                         |
| -------------------------------- | -------------------- | -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Nix-built Go binary              | FULLY_FUNCTIONAL     | `flake.nix:27-51`; `result/bin/app` probed end-to-end                            | `internal/app.Version` stamped from `self.rev` via `ldflags`                  |
| OCI image from the flake         | PARTIALLY_FUNCTIONAL | `flake.nix:58-62`; `.#app-image` + `.#checks.<system>.container-structure` green | Image never loaded/run — no container runtime on the dev machine (TODO row 1) |
| Image publish (`app-image-push`) | PARTIALLY_FUNCTIONAL | go-standard module output (skopeo → `ghcr.io/larsartmann/app`)                   | Never exercised; publish policy is an open owner decision                     |
| systemd unit                     | PARTIALLY_FUNCTIONAL | `systemd/app.service`                                                            | Ships with hardening directives; never booted under systemd in this repo      |

## Event sourcing skeleton

| Feature                  | Status   | Evidence                                            | Notes                                                                                             |
| ------------------------ | -------- | --------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| cqrs `EventService` stub | DISABLED | `internal/events/events.go:1` (`//go:build events`) | Enable with `-tags events`; not wired into `app.Serve`. Delete the file if the service stays CRUD |

## Automation & quality

| Feature                                           | Status           | Evidence                                                                     | Notes                                                                                                                                                |
| ------------------------------------------------- | ---------------- | ---------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| CI: build / vet / race-test                       | DISABLED         | `.github/workflows/ci.yml:12-28`                                             | Zero runs observed — nothing pushed since the action pins landed (TODO row 4)                                                                        |
| CI: golangci-lint (v2 via `go install`)           | DISABLED         | `.github/workflows/ci.yml:30-45`; local run: `0 issues`                      | `golangci-lint-action` v6 cannot run a v2 binary, hence `go install`                                                                                 |
| CI: `nix-image` (image + structure check)         | DISABLED         | `.github/workflows/ci.yml:47-65`                                             | Same push blocker; the same commands pass locally                                                                                                    |
| Dependabot (gomod + github-actions)               | DISABLED         | `.github/dependabot.yml`                                                     | Config-only until the repo is pushed; flake inputs ride the appkit train                                                                             |
| docs-gates battery                                | FULLY_FUNCTIONAL | `docs-gates run .` → PASS (freshness, audit-all, annotate, routing, cadence) | The ritual that keeps this doc set honest                                                                                                            |
| golangci-lint fleet config                        | FULLY_FUNCTIONAL | `.golangci.yml`; `golangci-lint run ./...` → `0 issues`                      | Copied from the appkit fleet standard                                                                                                                |
| Route tests                                       | FULLY_FUNCTIONAL | `internal/api/routes_test.go` (2 tests, race-clean)                          | Covers the JSON route and the unmatched-path fall-through; 100% statement coverage in `internal/api`, none yet in `cmd/app`, `internal/app`, `views` |
| Full quality gate (`buildflow --build-mode full`) | FULLY_FUNCTIONAL | 0 failed, 62 steps (2026-11-22)                                              | The real gate; dev mode is a subset. Advisory findings are env/tool noise, not failures                                                              |

**Row count:** 29 rows — 17 `FULLY_FUNCTIONAL`, 3 `PARTIALLY_FUNCTIONAL`,
0 `BROKEN`, 9 `DISABLED`, 0 `PLANNED`.

## Deliberately not here

- **Framework code.** Lifecycle, middleware, health, error pages, security,
  otel, realtime, cqrs, config: all in
  `github.com/larsartmann/go-appkit`. This repo must stay a thin consumer.
- **Dockerfiles.** OCI images come from the flake (nix2container). A
  Dockerfile would be a posture regression, not a feature.
- **Business domain.** The archetype ships no entities, storage, or auth flows
  — adopters bring those.
