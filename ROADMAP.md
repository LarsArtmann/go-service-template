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
booted in CI, published, signed, and attested, with no Docker daemon anywhere
in the path.

Raw ideas:

- Multi-arch images (aarch64 alongside x86_64) so adopters targeting ARM
  hosts do not fork the flake.
- Boot-smoke as a standing check: load the image, run it, probe `/healthz` and
  `/api/status`, SIGTERM it, assert the drain lines. Belongs in
  `checks.image-smoke`, so the proof travels with the flake.
- Publish automation: registry push from CI versus a manual
  `nix run .#app-image-push`. Owner policy — it decides whether CI carries
  registry credentials.
- Image signing (cosign) and SBOM attestation, ideally produced by the same
  flake output that builds the image.
- Layer sharing and cache behavior between sibling fleet images — nix2container
  claims it; measure it against GH Actions caching before betting on it.

### 2. Deploy story

Direction: one blessed deploy path per service, documented as a decision, not
inferred from a unit file plus a container.

Raw ideas:

- ADR: "OCI images from Nix, no Dockerfile" — the decision, the rejected
  alternatives (Dockerfile, kaniko, hand-rolled tarball), and what would
  reopen it.
- systemd-versus-container: when a fleet service picks the unit, when it picks
  the image, and how the sd_notify no-op inside containers is explained to an
  operator.
- Whether the template should ship a NixOS module alongside `systemd/app.service`.

### 3. Template adoption ergonomics

Direction: the rename step is the only manual work — and it should be
impossible to do half of it.

Raw ideas:

- A `rename` helper (script or `go run` tool) that rewrites module path,
  `Name`/`Short`, `pname`, ldflags, systemd `ExecStart`, and README title in
  one pass, then proves it with a `grep` that must come back empty.
- Portable formatting: `dprint.json` currently names absolute
  `/home/lars/.local/state/...` plugin paths (a `BUILDFLOW_DPRINT_PLUGINS`
  artifact) — adopters on other machines cannot resolve them.
- Hermetic dependency sourcing: prepared-source (`deps`) instead of the
  committed `vendorHash.nix`, if the module's story matures.
- An adopter smoke script: clone → rename → build → boot → probe, runnable by
  the owner before tagging a template change.

### 4. Fleet posture propagation

Direction: a posture change made here should be observable fleet-wide, not
rediscovered service by service.

Raw ideas:

- Census for Dockerfile remnants across sibling repos after the Nix-OCI
  migration, so the posture actually lands everywhere.
- Run BuildFlow itself in CI (fleet-standard gate) rather than a subset of
  hand-wired steps.
- A positive `no-dockerfile` gate upstream: fail the build when a Dockerfile
  appears, instead of only declining to generate Docker hygiene files.
- Template versioning: how an adopter learns that the archetype moved (the
  refresh ritual says re-clone, but nothing announces a new commit).

### 5. Observability defaults for adopters

Direction: the otel/realtime security legs stay env-switched, but an adopter
should not have to guess what "on" costs.

Raw ideas:

- A documented default posture per leg (off/on) with the operational
  consequence of each choice, so flipping an env var is an informed act.
- Whether the health dashboard should be gated behind a leg too, instead of
  always-on in production-facing services.
- A first-class metrics decision (the preset passes `Config.Metrics` through
  verbatim; the template currently says nothing about it).

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
