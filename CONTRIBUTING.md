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

The probe is a script now; run it instead of hand-walking the matrix:

```bash
go build -o app ./cmd/app
scripts/probe.sh ./app                    # endpoint matrix + drain + edge cases
PROBE_EXPECT_VERSION="{\"version\":\"$(git rev-parse HEAD)\"}" \
  nix build . && scripts/probe.sh result/bin/app   # flake binary: exact stamp
scripts/probe.sh --edge result/bin/app    # just bind-failure + drain-under-load
```

A `/version` stamp mismatch fails the probe - that is the point: a binary
whose stamp does not name the commit under test is not evidence.
