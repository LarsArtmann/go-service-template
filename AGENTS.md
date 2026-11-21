# Agent Notes

Production posture: go-appkit preset spine + cmdguard CLI. Module truth lives
in the appkit READMEs (this repo contains no framework code).

## Version stamp (drift control — bump via the ritual, not by hand)

| Component        | Value                                    |
| ---------------- | ---------------------------------------- |
| Template source  | github.com/LarsArtmann/go-service-template |
| Generated        | 2026-11-21                               |
| go-appkit preset | v0.1.1 (core v0.12.0, httpx v0.2.0, cqrs v0.9.0, config v0.1.1) |
| cmdguard         | v5.1.0                                   |
| templ (runtime)  | v0.3.1100 (the fleet-migrated pairing: templ-components v1.27.2 + go-health-dashboard v0.13.3; cmdguard v5.1.0 requires ≥ v0.3.1100) |
| Go floor         | 1.27.4                                   |

Refresh ritual: every preset/core-touching appkit train bumps this stamp and
re-runs the dogfood probe (build, boot, `/healthz` + `/api/status` probe,
SIGTERM graceful-stop). An appkit adopter refreshing from the template
re-clones rather than merging — the template is a starting point, not a
shared module.

## Build & verify

```bash
go build ./...
go test ./... -race -count=1
golangci-lint run ./...        # config copied from the appkit fleet standard
nix build                      # after filling vendorHash.nix with the real hash
```

## Gotchas

- `internal/events/` is behind the `events` build tag; `go mod tidy` keeps
  the cqrs require alive because tidy considers all build configurations.
- `views/*_templ.go` files are COMMITTED so plain `go build` works without a
  templ install; regenerate with `templ generate` after editing `.templ` files.
- Signal handling is the framework's (core `Run`); do not add a second
  NotifyContext.
