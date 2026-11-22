# Domain Language — go-service-template

> The ubiquitous language of this archetype. This repo has no business domain,
> so its vocabulary is the SCAFFOLD's: the words an adopter, the appkit
> framework, and a future session must mean the same thing by. Terms here are
> verified against the code that uses them — a term with no usage is a
> documented lie.

## Core terms

| Term             | Definition                                                                                                                        | Where used in code                                                 |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| Archetype        | This repo: the starting point a service is generated from, never a shared dependency                                              | `README.md:1-8`, `.config/metadata.yaml`                           |
| Adopter          | The service that clones this repo and renames it; it re-clones on refresh instead of merging                                      | `AGENTS.md` (refresh ritual), `CONTRIBUTING.md`                    |
| Scaffold         | The mechanical act of turning the archetype into an adopter (clone + rename + tidy)                                               | `internal/app/service.go:17-18`, `README.md`                       |
| Preset           | `go-appkit/preset`: the one-call composition that boots a service with the spine plus legs                                        | `internal/app/service.go:14,48` (`appkitpreset.New`)               |
| Spine            | The always-on part of the preset: lifecycle, middleware, health + dashboard, error pages, sd_notify, version stamp                | `README.md:71-80`, preset README "What joins the service"          |
| Leg              | An opt-in preset capability switched by a frozen env var (otel, realtime, security, error pages)                                  | `internal/app/service.go:48` (`//nolint:... legs stay env-driven`) |
| Env grammar      | The frozen set of preset switches and their accepted values; invalid values fail fast at `preset.New`                             | preset README grammar table; `APPKIT_*`                            |
| Composition root | The one function that wires config → preset → routes → Run; must stay small                                                       | `internal/app/service.go:43-65` (`Serve`)                          |
| Config module    | `go-appkit/config`: struct-tag config with precedence flag > env > file > default, one `Rejection` listing every bad field        | `internal/app/service.go:31-41` (`config.Load`)                    |
| Rejection        | The error family used for caller-fault boot failures (bad env value, missing origins); distinguishable from infrastructure faults | `internal/app/service.go:37` comment                               |
| Classified error | An error carrying an error-family + code, so logs and exit codes stay machine-readable                                            | `internal/api/routes.go:1-3` comment                               |
| No-leak contract | The handler/error contract that renders a classified error without exposing internals                                             | `internal/api/routes.go:2-3`; `httpx.ResultHandler`                |
| Subcommand       | A cmdguard verb (`serve`, `version`, `doctor`)                                                                                    | `cmd/app/main.go:31-50`                                            |
| Batteries        | cmdguard's `WithBatteries()`: the free `version` + `doctor` verbs and machine-readable error hints                                | `cmd/app/main.go:52`                                               |

## Lifecycle terms

| Term           | Definition                                                                                                       | Where used in code                                            |
| -------------- | ---------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| Graceful drain | The shutdown sequence that stops new traffic first, then lets in-flight requests finish                          | `internal/app/service.go:43-46` comment; preset `Run`         |
| Drain phase    | One logged stage of the drain: `ready_flip` → `drain_hooks` → `drain_wait` → `listener_close` → `shutdown_hooks` | probe output (`shutdown phase complete phase=…`), appkit core |
| Probe endpoint | `/healthz` (liveness), `/readyz` (readiness, flips to 503 while draining), `/startupz` (started)                 | preset spine; verified by probe on the built binary           |
| Dashboard      | The real-time health surface mounted at `/health`; it OWNS the probe endpoints                                   | preset `WithDashboard()`; probed 200                          |
| Error pages    | The preset's pretty 404/405 rendering, opt-out via `APPKIT_ERRORPAGES=off`                                       | preset spine                                                  |
| sd_notify      | systemd readiness/watchdog protocol; the preset installs it, and it is a no-op outside systemd                   | `systemd/app.service`, preset `systemd.Install`               |
| Watchdog       | The systemd liveness contract: `WatchdogSec=30s` in the unit, kept alive at half that interval by the app        | `systemd/app.service:14`                                      |

## Build & release terms

| Term             | Definition                                                                                                              | Where used in code                                        |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| Version stamp    | The build-time `internal/app.Version` value, injected via `ldflags` and served at `/version`                            | `internal/app/service.go:24-27`, `flake.nix:44-50`        |
| Drift stamp      | The AGENTS.md table of pinned component versions and the Go floor; bumped only by the refresh ritual                    | `AGENTS.md` version stamp table                           |
| Refresh ritual   | The required drill after an appkit train: bump the stamp and re-run the dogfood probe                                   | `AGENTS.md`, `CONTRIBUTING.md`                            |
| Dogfood probe    | Exercising a scaffolded copy end-to-end: build, boot, probe `/healthz` + `/api/status` + `/version`, SIGTERM drain      | `CONTRIBUTING.md`; performed by this doc sweep            |
| vendorHash       | The fixed-output hash of the Go module graph; a wrong value fails the first Nix build, which prints the right one       | `vendorHash.nix`, `flake.nix:37-39`                       |
| app-image        | The OCI image built by the flake's `container` option (nix2container) — no Dockerfile involved                          | `flake.nix:52-61`; `.#app-image` outputs                  |
| Image posture    | The container facts the structure check asserts: non-root `65532:65532`, `/bin/app serve`, `8080/tcp`, cacert, hash tag | `flake.nix` container block; `checks.container-structure` |
| Content-hash tag | The image tag is the store content hash, so identical inputs produce an identical tag                                   | `.#app-image`; reproducibility proof in `CHANGELOG.md`    |
| Build-tag gate   | Compiling a package only under an explicit tag (`events`), so the default binary carries no weight for it               | `internal/events/events.go:1`                             |

## Documentation terms

| Term           | Definition                                                                                                             | Where used in code / docs          |
| -------------- | ---------------------------------------------------------------------------------------------------------------------- | ---------------------------------- |
| Living doc     | A doc rewritten in place as reality changes (README, AGENTS, FEATURES, TODO_LIST, ROADMAP, DOMAIN_LANGUAGE, CHANGELOG) | this file, `docs-health` skill     |
| Snapshot       | A point-in-time report under `docs/status/`; annotated, never rewritten                                                | `docs/status/2026-11-22_19-43_…md` |
| Harvest        | Pulling forward-looking items from a snapshot into TODO_LIST / ROADMAP so they do not die with the report              | `docs-gates freshness`; this sweep |
| Battery        | The five docs gates run as one command: freshness, audit-all, annotate, routing, cadence                               | `docs-gates run .`                 |
| Routed item    | An open snapshot item represented in the living docs by an arrow naming the TODO_LIST / ROADMAP row, left unstruck     | `docs-gates routing` (strict)      |
| Feature status | The FEATURES vocabulary: `FULLY_FUNCTIONAL`, `PARTIALLY_FUNCTIONAL`, `BROKEN`, `DISABLED`, `PLANNED`                   | `FEATURES.md` legend               |
| Work status    | The TODO_LIST vocabulary: `TODO`, `IN_PROGRESS`, `BLOCKED`; completed work leaves the file for CHANGELOG               | `TODO_LIST.md` legend              |

## Bounded contexts

Terms that mean different things depending on where you stand:

| Term     | Context A                                                         | Context B                                                            |
| -------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- |
| stamp    | **Version stamp** — the ldflags-injected rev served at `/version` | **Drift stamp** — the AGENTS.md table of pinned versions             |
| probe    | **Health probe** — `/healthz` / `/readyz` / `/startupz`           | **Dogfood probe** — exercising a whole scaffolded service end-to-end |
| gate     | **Quality gate** — `buildflow` (build, tests, lint, nix, format)  | **Docs gate** — `docs-gates` (freshness, annotate, routing, cadence) |
| template | **The archetype** — this repo                                     | **An adopter's service** — scaffolded FROM this repo                 |
| serve    | **CLI verb** — `app serve`                                        | **Composition root** — `app.Serve(ctx, cfg)` in `internal/app`       |
| status   | **Feature status** — does working code exist (FEATURES)           | **Work status** — is the task open (TODO_LIST)                       |

## Deprecated terms

| Old term                                            | Current term                        | Why changed                                                                        |
| --------------------------------------------------- | ----------------------------------- | ---------------------------------------------------------------------------------- |
| Dockerfile / Docker build arg                       | flake `container` option, `ldflags` | OCI images must come from Nix (2026-11-22); a Dockerfile is a posture regression   |
| `.dockerignore`                                     | (none)                              | Inert without a Dockerfile; only a BuildFlow regeneration artifact (open upstream) |
| "ROADMAP.md: none — this template keeps no roadmap" | `ROADMAP.md`                        | Long-term fuel was rotting inside a timestamped report; the file now exists        |
| "Generate a service"                                | Scaffold a service / adopter        | The verb is the mechanical rename flow, not codegen                                |
