# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

### Changed

- 2026-11-24 (Pareto plan, T-16.1-T-16.2): TODO row 16 (docs-command smoke
  check) is closed. Every command the living docs name is inventoried
  (T-16.1) and classified: ten runnable commands execute under timeout in
  `scripts/docs-command-smoke.sh`, four container/registry/systemd commands
  carry documented skip reasons, mutating commands are proven present but
  not executed. The inventory half runs sandboxed as
  `checks.<system>.docs-command-smoke` (flake) and fails when a documented
  command disappears (proven). `go vet ./...` is now named in AGENTS' raw
  fallbacks — the smoke check caught it missing.
- 2026-11-24 (Pareto plan, T-23.1-T-23.3): TODO row 23 (upstream preset
  defects) is closed. Both defects re-verified against appkit origin/master
  `5897476` (`preset/` identical to the audit's HEAD), then reproduced at
  runtime: `APPKIT_SECURITY=strict` via env boots the standard profile
  (cross-origin request: 200 degraded vs 403 `ORIGIN_REJECTED` on the config
  path), and `NoDashboard: true` panics at `preset.New` when go-health
  >= v0.9 rides the graph (tuple-traced: v0.8.1 has no Version route; the
  template gets v0.10.0 from go-health-dashboard v0.13.3). Filed upstream as
  go-appkit issues #84 and #85 with the full evidence tables.
- 2026-11-24 (Pareto plan, T-31.1-T-31.3): TODO row 31 (formatter gate) is
  closed. One atomic `dprint fmt` pass over the 21 `docs/review/libs/*.md`
  audits, the 2026-11-23 fleet status report, and `AGENTS.md` (813 lines
  reflowed, zero alphanumeric content drift, verified per file against HEAD).
  The two reflow artifacts were repaired for the annotate gate: `go-sse.md`
  now quotes the go-get command inside the NOT-NOW tag (nested backticks
  never rendered as code and were unformattable), and `go-appkit.md` keeps
  the literal Go struct tag with the gate's `format:allow` opt-out. The full
  `buildflow --build-mode full` gate is green again (63 steps, 0 failed) —
  the first time since the audit corpus landed.
- 2026-11-24 (Pareto plan, T-4.1): TODO row 4 (CI execution evidence) is
  closed. Push `ebca772` ran as CI run 45375102476 with all three jobs green
  (build-vet-test, lint, nix-image); two earlier runs on 2026-11-23
  (45099511327, 45121169253) had already exercised the same three jobs after
  the 2026-11-22 `checks.<system>.container-structure` fix, so the row's
  "zero runs observed" evidence was stale when written. The Pareto plan's
  "never executed" sentence was corrected in the same pass.
- 2026-11-22 (docs-health audit): `buildflow --build-mode full` was run for
  the first time (the dev lane had masked it). Final runs report 0 failed
  (60 steps on the first run, 62 once optional steps joined; the count moves,
  the zero is the invariant). Advisory findings are env/tool noise: nixpkgs
  CVE feed, `go-humanize` availability, the self-referential
  `goTarballHash` hint. Coverage is honest rather than flattering:
  `internal/api` is at 100% of statements, while `cmd/app`, `internal/app` and
  `views` carry no tests at all.
- 2026-11-22 (docs-health audit): the doc set now covers every file the
  fleet expects. New `FEATURES.md` (29-row honest inventory, each row with
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
  auto-commit daemon note. The 2026-11-22 status report's 50 §f items were
  harvested: each one is now a TODO row, a ROADMAP theme, a CHANGELOG entry,
  or an explicit not-do/non-goal, and the report itself stays untouched.
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

