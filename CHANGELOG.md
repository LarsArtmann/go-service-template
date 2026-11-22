# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

### Changed

- 2026-11-22: removed the Dockerfile — OCI images build from the flake
  (go-standard `container` option, nix2container). Same posture, no daemon:
  non-root `65532:65532`, `/bin/app serve`, `8080/tcp`, cacert included,
  content-hash tag. Outputs: `app-image`, `app-image-load`/`app-image-push`,
  `checks.container-structure`. The version stamp moved from the Docker
  build arg into the flake's `ldflags` (`internal/app.Version`).

### Added

- Initial scaffold from go-service-template (generated 2026-11-21): cmdguard
  `serve` CLI, preset spine, httpx example route, templ page, cqrs stub
  (`-tags events`), flake/BuildFlow/CI/systemd posture.

### Dogfood probe (2026-11-21, recorded friction)

One real app scaffolded from THIS commit: build green, booted, probed
(`/healthz` JSON, `/api/status`, templ `/` page, pretty 404), SIGTERM
graceful-stop with the full five-phase drain lines, exit clean. Friction
found and already absorbed: the first `go get` picks the LATEST templ, which
collides with the pre-1100-generated dashboard/templ-components the preset
spine pins — the committed go.mod carries the ALIGNED pairing (templ
v0.3.1100 + templ-components v1.27.2 + go-health-dashboard v0.13.3), so
consumers never see it; regenerate views only with a v0.3.1100 templ binary
(generator and runtime move in lockstep). Second note: `:8080` was occupied
by an unrelated dev server during the probe — `APP_ADDR` env (config module)
made that a non-event; the config seam earned its keep on day one.

