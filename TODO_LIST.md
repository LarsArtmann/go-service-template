# TODO List

> Short-term, actionable, bounded work for go-service-template. For shipped
> changes, see [CHANGELOG.md](CHANGELOG.md) and git history. Last docs-health
> sweep: 2026-11-22 (Dockerfile removed — OCI images build from the flake via
> the go-standard `container` option; no open items found).

## Status legend

| Status      | Meaning                                                 |
| ----------- | ------------------------------------------------------- |
| TODO        | Not started. Needs doing.                               |
| IN_PROGRESS | Actively being worked on.                               |
| BLOCKED     | Cannot proceed, external dependency or decision needed. |

## Open items

None. The scaffold is green as of 2026-11-22: `buildflow --build-mode dev`
(build, race tests, golangci-lint, nix build + treefmt + docs-gates) and
`nix build .#app-image` (OCI image + structure check) all pass.
