# Security Policy

## Supported Versions

| Version        | Supported  |
| -------------- | ---------- |
| Latest release | ✅ Current |

Only the latest release receives security fixes. Please update to the latest
version before reporting issues found in older releases.

## Reporting a Vulnerability

Please do **not** open public issues for security problems. Report privately instead:

- **GitHub Security Advisory**: https://github.com/LarsArtmann/go-service-template/security/advisories/new

### What to include

- Vulnerability type and severity
- Steps to reproduce
- Potential impact
- Proof of concept (if available)

### Response commitments

| Phase            | Timeline                    |
| ---------------- | --------------------------- |
| Initial response | Within 48 hours             |
| Triage           | Within 72 hours             |
| Disclosure       | Coordinated, within 90 days |

## Security Practices

- Every change passes the owner's gate (`buildflow --build-mode dev`: build,
  race tests, golangci-lint, Nix build, formatter, docs gates). This is a
  solo-owner archetype — there is no external review step, and the policy
  says so rather than implying one.
- Dependency updates ride Dependabot (gomod + GitHub Actions) once the repo
  is pushed; Nix flake inputs ride the appkit train ritual.
- No secret is committed; `.gitignore` carries the fleet's secret patterns
  (`*.pem`, `*.key`, `.env*`). A CI secret scanner is planned, not present —
  tracked in `TODO_LIST.md` row 12 rather than claimed here.

---

_Maintained with [securitymd](https://github.com/LarsArtmann/securitymd). Last updated: 2026-11-22._
