# Roadmap — go-service-template

> Long-term direction and raw ideas, not tasks. When an idea is refined into
> bounded work it moves to [TODO_LIST.md](TODO_LIST.md). What the archetype
> ships today is in [FEATURES.md](FEATURES.md); the vocabulary is in
> [docs/DOMAIN_LANGUAGE.md](docs/DOMAIN_LANGUAGE.md).
>
> **Updated:** 2026-11-22 (docs-health AUDIT sweep — first roadmap for this
> repo; the earlier "the template keeps no roadmap" decision is reversed so
> long-term fuel stops rotting inside a timestamped status report).

## North star

A new fleet service should reach production posture in one clone: `git clone`,
mechanical rename, `buildflow --build-mode dev`, deploy. The archetype owns
everything AROUND the code — lifecycle, health, error contract, telemetry
seams, packaging, CI, systemd — so an adopter writes only their domain. Two
rules keep it honest: no framework code lands here (it belongs in go-appkit or
cmdguard), and every posture claim is proven by an execution, not by a config
file.

## Themes

### 1. OCI artifact lifecycle

Direction: an image is a first-class release artifact — built hermetically,
published, signed, and attested, with no Docker daemon anywhere in the path.
The near-term pieces (boot-smoke, publish wiring) are already bounded in
[TODO_LIST.md](TODO_LIST.md) rows 1 and 5; what remains here is direction.

Raw ideas:

- Multi-arch images (aarch64 alongside x86_64) so adopters targeting ARM
  hosts do not fork the flake.
- Image signing (cosign) and SBOM attestation, ideally produced by the same
  flake output that builds the image.
- Layer sharing and cache behavior between sibling fleet images — nix2container
  claims it; measure it against GH Actions caching before betting on it.

### 2. Deploy story

Direction: one blessed deploy path per service, documented as a decision, not
inferred from a unit file plus a container. The ADR that records the Nix-OCI
decision is TODO_LIST row 11; what follows it is direction.

Raw ideas:

- systemd-versus-container: when a fleet service picks the unit, when it picks
  the image, and how the sd_notify no-op inside containers is explained to an
  operator.
- Whether the template should ship a NixOS module alongside `systemd/app.service`.

### 3. Template adoption ergonomics

Direction: the rename step is the only manual work — and it should be
impossible to do half of it. The portable-`dprint.json` decision is TODO_LIST
row 10; the ideas below are the larger shape of the problem.

Raw ideas:

- A `rename` helper (script or `go run` tool) that rewrites module path,
  `Name`/`Short`, `pname`, ldflags, systemd `ExecStart`, and README title in
  one pass, then proves it with a `grep` that must come back empty.
- Hermetic dependency sourcing: prepared-source (`deps`) instead of the
  committed `vendorHash.nix`, if the module's story matures.
- An adopter smoke script: clone → rename → build → boot → probe, runnable by
  the owner before tagging a template change.
- Archetype routing signposts: a "which starting point?" box (service on the
  preset spine vs cqrs-htmx web app vs go-daemon socket daemon) plus one
  adopter pointer per correctly-absent library, so a team clones the right
  repo first (TODO_LIST row 25; from the 2026-11-23 library audit).

### 4. Fleet posture propagation

Direction: a posture change made here should be observable fleet-wide, not
rediscovered service by service. The positive `no-dockerfile` gate is TODO_LIST
row 8; the rest is fleet-level direction.

Raw ideas:

- Census for Dockerfile remnants across sibling repos after the Nix-OCI
  migration, so the posture actually lands everywhere.
- Run BuildFlow itself in CI (fleet-standard gate) rather than a subset of
  hand-wired steps.
- Template versioning: how an adopter learns that the archetype moved (the
  refresh ritual says re-clone, but nothing announces a new commit).
- A repeating fleet library audit: the 21-report series under
  `docs/review/libs/` is the first run; upstream-routed findings should land
  in the owning repos (TODO_LIST row 30) and a later run re-measures. A
  cross-repo roll-up would show fleet-wide utilization in one place.
- A preset production-profile switch so the audited maximum (strict
  security, compression, embedded assets, critical health checks) is one env
  flip for every adopter instead of N passthrough fields (raw idea,
  preset-owned; TODO_LIST row 24 is the near-term slice).

### 5. Observability defaults for adopters

Direction: the otel, realtime and security legs stay env-switched, but an
adopter should not have to guess what "on" costs.

Raw ideas:

- A documented default posture per leg (off/on) with the operational
  consequence of each choice, so flipping an env var is an informed act.
- Whether the health dashboard should be gated behind a leg too, instead of
  always-on in production-facing services.
- A first-class metrics decision (the preset passes `Config.Metrics` through
  verbatim; the template currently says nothing about it).

## Open questions (owner decisions)

Five fleet-level calls are blocked on the owner, not on work. They are tracked
as rows so they cannot disappear, but the question belongs here:

1. **Image publishing:** CI pushes to `ghcr.io/larsartmann/<name>` (needs
   registry credentials in CI) or publishing stays a manual
   `nix run .#app-image-push`? Decides [TODO_LIST.md](TODO_LIST.md) row 5.
2. **Go floor shape:** keep the patch-pinned `go 1.27.4` (fleet floor ritual,
   mirrored by the flake tarball pin) or adopt BuildFlow's major.minor-only
   rule? Two fleet standards disagree here. Decides
   [TODO_LIST.md](TODO_LIST.md) row 6.
3. **Commit policy under Crush:** the project AGENTS.md says "commit coherent
   work yourself before the daemon tick"; Crush's harness rule and the
   status-report skill say never commit manually, the auto-commit daemon picks
   it up. Three sessions have now blurred attribution in this repo (last:
   the 2026-11-23 library audit, 22 files in 17 heuristic commits). Which
   rule wins? Decides whether the AGENTS.md gotcha is rewritten.
4. **Upstream intake form:** the library audit's upstream findings (issues vs
   TODO_LIST rows in each library repo vs direct fixes). Decides
   [TODO_LIST.md](TODO_LIST.md) row 30.
5. **Fleet rollout of the library audit:** run the same 21-library audit on
   other repos (same `docs/review/libs/` convention), and should the procedure
   become a standing skill? If yes, which repos first?

## Non-goals

- **Framework code in this repo.** Lifecycle, middleware, health, error pages,
  security, otel, realtime, cqrs all live in appkit. Duplicating one here
  would create a second source of truth.
- **Dockerfiles / Docker builds.** OCI images come from the flake; a Dockerfile
  is a posture regression, not a feature.
- **Makefile or justfile task running.** `flake.nix` plus BuildFlow own
  automation.
- **Multi-module (`go.work`) layout.** The archetype is one module; adopters
  who outgrow it should reach for the go-modularize skill, not inherit a
  split-brain skeleton.
- **Auth, storage, and business entities.** Adopters bring their domain; the
  template ships an event-sourcing stub and nothing else.
- **Extending cmdguard's `doctor` to assert image posture.** Image posture is
  already proven by `.#checks.<system>.container-structure`; a second proof surface would
  drift from the first.
