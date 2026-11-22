# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

### Changed

- 2026-11-22 (docs-health audit): the doc set now covers every file the
  fleet expects. New `FEATURES.md` (28-row honest inventory, each row with
  code or probe evidence), new `ROADMAP.md` (long-term direction — this
  reverses the earlier "the template keeps no roadmap" decision, which had
  been pushing long-term fuel into a timestamped report), and new
  `docs/DOMAIN_LANGUAGE.md` (the archetype's vocabulary, with the bounded
  contexts: stamp, probe, gate, template, serve, status). `TODO_LIST.md` was
  rebuilt as an open-only ranked table; the old "Closed" section is gone
  because completed work belongs in this file. README's rename checklist was
  wrong: it listed only `cmd/ internal/ views/`, omitting `go.mod` and the
  `flake.nix` `ldflags` path, and said nothing about `pname` naming the image
  repository. It now carries the `grep -rl | xargs perl -pi` command and a
  proof step. The README repo map gained `docs/`, the doc set, `CONTRIBUTING.md`,
  `SECURITY.md`, `LICENSE`, and the `nix-image` CI job; the framework-surface
  list now names the dashboard at `/health` and the SSE hub at `/events`.
  AGENTS.md gained a docs map, the rename-coverage contract, the
  absolute-`dprint.json` gotcha, the `.dockerignore` artifact note, the
  `docs-gates run .` command, the ruling that posture-only changes do NOT bump
  the version stamp (so `Generated` still reads 2026-11-21), and the
  auto-commit daemon note.
- 2026-11-22: `goTarballHash` moved out of `flake.nix` into
  `goTarballHash.nix` (a `nix-checker` finding). A Go floor bump is now a
  version line plus a hash file, matching the `vendorHash.nix` shape, and
  `nix-update`-style tooling can read the hash without parsing the flake.
- 2026-11-22: removed the Dockerfile — OCI images build from the flake
  (go-standard `container` option, nix2container). Same posture, no daemon:
  non-root `65532:65532`, `/bin/app serve`, `8080/tcp`, cacert included,
  content-hash tag. Outputs: `app-image`, `app-image-load`/`app-image-push`,
  `checks.container-structure`. The version stamp moved from the Docker
  build arg into the flake's `ldflags` (`internal/app.Version`).
- 2026-11-22 (verification loop closed): Nix-built binary dogfood probe
  passed (boot, `/healthz`, `/api/status`, `/version` reporting the git rev,
  full five-phase SIGTERM drain); `.#app-image` proven bit-reproducible;
  image posture verified in the image JSON (user, ports, cacert env,
  entrypoint). `flake.lock` duplicate `flake-parts` pin deduped via
  `follows`. README gained image verify commands and the `APP_ADDR` vs
  `ExposedPorts` footgun note; AGENTS.md gained buildflow-first commands,
  systemd-vs-container deploy paths, and templ/treefmt gotchas.

### Fixed

- 2026-11-22 (docs-health audit): the `nix-image` CI job ran
  `nix build .#checks.container-structure`, which does not resolve — `checks`
  is a per-system attrset and the `.#name` shorthand only reaches
  `packages`/`apps`. It is now `.#checks.x86_64-linux.container-structure`,
  and every doc that named the bare attr says `checks.<system>` instead.
  Verified locally: the check builds and passes under that path.
- 2026-11-22 (docs-health audit): `SECURITY.md` claimed "Automated security
  scanning runs in CI" while `ci.yml` carries no scanner. The claim is gone
  and the gap is now TODO_LIST row 12 (gitleaks step). `.config/metadata.yaml`
  `updated_at` bumped to the last change date.

### Added

- 2026-11-22: `nix-image` CI job (builds `.#app-image` +
  `.#checks.container-structure` on every push/PR) and the fleet-standard
  proprietary LICENSE file.
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

