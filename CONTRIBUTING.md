# Contributing to go-service-template

This is the fleet's service archetype — PROPRIETARY (see
[LICENSE](LICENSE)). It has no external contributor flow: changes come from
the owner's sessions and from appkit train adopters reporting friction.

## The workflow

1. Read [AGENTS.md](AGENTS.md) first — the version stamp, the refresh
   ritual, and the gotchas are the contract every change must respect.
2. Make the change.
3. Run the gate:

   ```bash
   buildflow --build-mode dev
   ```

   It wraps build, race tests, golangci-lint, the Nix build (including the
   OCI image), treefmt, and the docs gates. Green is the merge bar.

## Template changes

A change that touches the scaffold (preset pins, CLI wiring, flake posture)
must re-run the dogfood probe: fresh clone of the commit, full rename flow
per the README, build, boot, `/healthz` + `/api/status` + `/version` probe,
SIGTERM graceful drain. The stamp block in AGENTS.md records the last
verified posture — preset/core-touching trains bump it.
