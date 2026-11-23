# go-error-family — utilization review (go-service-template)

| Reviewed | 2026-11-23 |
|---|---|
| Library | github.com/larsartmann/go-error-family (+ submodules) |
| Version audited | v0.12.0-13-g01d155e (01d155e, 2026-11-23) |
| Template pin | v0.12.0 (indirect via the go-appkit chain) |
| Latest tag | v0.12.0 |
| Adoption score | 59/100 (moderate) — 6.5 of 11 applicable capabilities leveraged |
| Verdict | The template's entire error story runs on this library at runtime, with zero template-direct imports: correct archetype posture, but the producer side is untaught and two seam capabilities (family exit codes, classified logging) silently die at boundaries. |

## Verdict

Not TEMPLATE-DIRECT anywhere, and that is the right call for an archetype: every production behavior is PRESET-MEDIATED through go-appkit (httpx renders, core classifies boot failures, config rejects bad env, errorpages 404s), all cited below. "Max" here does NOT mean importing more; it means three things that are currently missing: (1) the archetype never shows an adopter how to CREATE a classified error, so the advertised "classified error → no-leak rendering" contract has no producer-side example and no test of its rendered shape, (2) the family→BSD exit-code mapping (Infrastructure→69, Transient→75) is dropped at the cmdguard boundary because `(*Error).ExitCode()` returns 0 for "unset" and cmdguard's duck-typed fallback turns that into exit 1, and (3) `LogError` is re-exported by appkit core but has zero runtime call sites, so classified context (family/code/hook_index) never reaches logs. Fixing (2) in the lib fixes it for every fleet consumer at once.

## What the template uses today

All usage is PRESET-MEDIATED (the template's 7 Go files contain zero references to errorfamily; `rg -n 'errorfamily' /home/lars/projects/go-service-template --glob '*.go'` is empty). The runtime chain, hop by hop:

- HTTP handler error → status + safe JSON: `httpx.ResultHandler` (go-appkit/httpx/result.go:48) calls `WriteError(w, r, err)` on non-nil error (result.go:55). `WriteError` (httpx/errors.go:32-57) classifies via `errorfamily.Classify` (errors.go:37), extracts `errorfamily.Code` (:41), builds `{family, code, message, why, fix}` (errors.go:18-24), why/fix via `errors.AsType[errorfamily.Classified]` (:45-48), and writes the status from `errorfamily.HTTPStatus(err)` (:52). No-leak gate: `SanitizeErrorMessage` (httpx/sanitize.go:43-62) — `Public()` escape hatch; Rejection/Conflict keep scrubbed own text; every server-side family gets `family.DefaultMessage()`, plus a regex scrub for paths/SQL/stacks (sanitize.go:13-21). The template's example handler plugs in at internal/api/routes.go:27-29.
- Boot failure classification: listen failure → `errorfamily.WrapInfrastructuref(err, "server.listen_failed", ...)` (go-appkit/service.go:147 — the exact code AGENTS.md names); serve/shutdown failures → `server.serve_failed`/`server.shutdown_failed` (service.go:207,215,307); lifecycle hook failures → `WrapOnce(err, Infrastructure, phaseCode, msg)` with `hook_index` context (service.go:379-386).
- Boot → exit codes: main.go:22 `os.Exit(v5.ExitCode(run(...)))`. cmdguard does NOT import go-error-family (its go.mod carries it indirect; the only mention is a comment at /home/lars/projects/cmdguard/pkg/cmdguard/v5/cli_errors_json.go:44). It duck-types its own `ExitCoder` (pkg/cmdguard/v5/errors.go:202-207); errorfamily's `(*Error).ExitCode()` returns 0 unless `WithExitCode` was used (lib error.go:324), so cmdguard's "0 means no override" fallback (cli_errors_json.go:39-53) exits 1. Family exit codes never reach `os.Exit` through this path (verified; see Gaps G1).
- Config boot failure: `config.Load` returns ONE Rejection, code `config.invalid`, wrapping one `FieldError` per bad field (go-appkit/config/config.go:339, doc at :51-54 and :86-87; per-field Rejections at config.go:234,269,301, parse.go:120, file.go:39). Matches service.go:37 comment and DOMAIN_LANGUAGE "Rejection" exactly.
- Preset boot registration: `appkit.RegisterClassifications()` at preset/preset.go:102 installs stdlib defaults + `*http.MaxBytesError`→Rejection into the default registry (core errors.go:28-31).
- Pretty 404/405: errorpages constructs `errorfamily.NewRejection("http.not_found", ...)` (errorpages/errorpages.go:163) and `Newf(Rejection, "http.method_not_allowed", ...)` (:180-184); preset mounts it at preset/preset.go:248. templ-components/errorpage carries the same family enum (FamilyRejection, FamilyConflict, ...), so routes.go's "same taxonomy" claim is real.
- Spine breadth: env-grammar violations → Rejection (preset/env.go:33,51); bad log level/format → Rejection `log.level_invalid`/`log.format_invalid` (core logger.go:39,50); write-deadline wiring bug → Infrastructure + `WithHTTPStatus(500)` override (httpx/writedeadline.go:49-53); request bind failure → Rejection (httpx/bind.go:44); content negotiation → Rejection (httpx/negotiate.go:194,220-222); probe misuse → Rejection (health/mount.go:62-94,165-166); sd_notify failures → Infrastructure (systemd/notify.go:78,103); realtime/otel boot failures → Infrastructure (preset/preset.go:160,186).
- cmdguard's machine-readable error hints (DOMAIN_LANGUAGE "Batteries", main.go:52) are cmdguard's OWN sentinel taxonomy (`ErrorCode`/`ErrorHint` walk its facts table, pkg/cmdguard/v5/errors_facts.go:400-427), NOT errorfamily's. The two taxonomies meet only at the duck-typed `ExitCoder` seam.

## Capability inventory

| Capability | Status | Evidence | Note |
|---|---|---|---|
| Family taxonomy + `Classify` pipeline | Fully leveraged | preset/preset.go:102; httpx/errors.go:37; httpx/sanitize.go:54 | Every boundary classifies; six families, worst-severity for joined errors |
| Six-interface protocol (`Coded`, `Classified`, `Contextual`, `Retryable`, `ExitCoder`, `HTTPStatuser`) | Fully leveraged | httpx/errors.go:45 (`AsType[Classified]`); httpx/bind.go:44; negotiate.go:194 | appkit's own types implement `ErrorFamily()`; protocol-first design works as intended |
| Constructors (`New*`/`Wrap*`/`WrapOnce`) + builders (`WithHTTPStatus`, `WithContext`) | Fully leveraged | service.go:147,382; errorpages.go:163; writedeadline.go:49-53 | Spine uses the full surface incl. `WrapOnce` idempotent re-wrap and status override; zero template-authored use (see row 11) |
| HTTP status mapping (`HTTPStatus`, `Family.HTTPStatus`) | Fully leveraged | httpx/errors.go:52; result.go:42-44 | Lib's own `HTTPHandler` intentionally replaced by httpx's richer no-leak renderer |
| Registry + stdlib/classification-type registration | Fully leveraged | preset/preset.go:102 → core errors.go:29-30 | `RegisterStdlibDefaults` + `RegisterClassificationType[*http.MaxBytesError]` on every preset boot; scoped `NewRegistry`/`Clone` unused, fine for an app |
| Exit codes (`ExitCode`, `ExitCoder`, `WithExitCode`) | Partially used | cmdguard cli_errors_json.go:39-53; lib error.go:324, classify.go:78-92 | BSD sysexits mapping (69/75/65/70) computed by the lib is unreachable at the template's CLI boundary: cmdguard sees 0 and exits 1 (G1) |
| Structured logging (`LogError`/`LogErrorContext`) | Partially used | core errors.go:43-44 (re-export only) | Zero runtime call sites in appkit non-test code (grep verified); classified fields never hit logs (G3) |
| Error context (`WithContext`/`ErrorContext`) | Partially used | service.go:385 (`hook_index`) | Attached by core, consumed by nothing on the request path (kept off the wire by design; not emitted to logs either) |
| Code-level message templates (`RegisterTemplate`, `TemplateForCode`) | Missed opportunity | httpx/errors.go:46-47 uses family defaults only | Why/Fix come from `Family.DefaultWhy/DefaultFix`; no code-specific templates anywhere in the chain (G4) |
| `errorfamilytest` assertion helpers | Missed opportunity | used by appkit tests (hookclassification_test.go, systemd/notify_test.go, cqrs, otel); absent from template | Template's routes_test.go could assert the rendered shape with these or plain JSON checks (G2) |
| Template-authored classified error (producer side of the no-leak contract) | Missed opportunity | internal/api/routes.go:27-29 returns only nil | The contract the archetype advertises has no producing example and no test (G2, task 3 judgment) |
| Retry signals (`IsRetryable`, `RetryPolicy`) | Not applicable | no call sites in template or appkit runtime | The archetype has no retry loop; fleet go-retry/failsafe-go own that concern when a leg needs it |
| `Error.JSON()` canonical view | Not applicable | httpx/errors.go:18-24 builds its own parity struct | The preset owns the wire shape (field parity with errorpages, httpx/errors.go:11-17); lib JSON view is for direct consumers |
| CLI boundary (`HandleError`, `HandleErrorDetailed`, templates) | Not applicable | main.go:22 uses cmdguard's runner | cmdguard owns top-of-main printing (print-exactly-once contract); a second CLI handler would double-render |
| Diagnostics (`diagnose` rules, `HandleConfig.DiagnosticFunc`) | Not applicable | not referenced by preset or template | A service reports liveness via health endpoints; CLI auto-diagnosis is the wrong shape for a long-running server |

N = 15, N/A = 4, A = 11. Score = round(100 × (5×1 + 3×0.5 + 0×3) / 11) = round(59.09) = 59.

## Gaps and opportunities

Ranked by impact × ease, highest first.

1. **G1 — Family exit codes die at the cmdguard seam** `[LIB-UPSTREAM]`. The lib computes BSD sysexits codes (Infrastructure→69, Transient→75, Corruption→65, Orchestration→70; family.go table) and `errorfamily.ExitCode(err)` applies them (classify.go:78-92), but `(*Error).ExitCode()` returns 0 when unset (error.go:324, "0 means fall back to family default"), and cmdguard's duck-typed `ExitCoder` treats 0 as "no override" → exit 1 (cli_errors_json.go:47-52, with an explicit comment naming go-error-family). Net effect: `[Infrastructure:server.listen_failed]` (service.go:147) reaches the template's main.go:22 and the process exits 1, never 69; scripts and systemd units cannot distinguish boot-failure classes. Fix in the lib: make `(*Error).ExitCode()` return the EFFECTIVE code (family default when unset), or add `EffectiveExitCode()`. The package-level `errorfamily.ExitCode` stays correct either way (its non-zero override check is idempotent under this change), and every duck-typed CLI consumer (cmdguard, any fleet tool) starts surfacing family codes with zero consumer changes. Impact: high (machine-readable exits are a core lib promise). Ease: high (one method + test; doc-contract change, minor version).
2. **G2 — No producer-side example or rendered-shape test of the no-leak contract** `[TEMPLATE]`. What the lib offers: one-line classified errors (`NewRejection(code, msg)`, `WithHTTPStatus(404)`) that httpx renders as status + `{family, code, message, why, fix}` (httpx/errors.go:18-24,32-57). What the template does instead: the example handler returns only nil (routes.go:27-29) and routes_test.go (read in full) has two tests — happy-path JSON (TestRegister_StatusRouteServesJSON) and unmatched-path 404 status-only (TestRegister_UnmatchedPathFallsThrough, which asserts no body shape at all). Judgment: this is a Missed opportunity, NOT correctly minimal. The archetype's stated contract (routes.go:2-3, DOMAIN_LANGUAGE "No-leak contract") is precisely "classified error → no-leak rendering"; an adopter rewriting handlers must currently discover the taxonomy from appkit docs with zero in-repo precedent. The right minimal shape is TEST-ONLY, leaving the always-ok status handler alone: add one test that mounts `httpx.ResultHandler(func(...) (*statusResponse, error) { return nil, errorfamily.NewRejection("example.not_found", "demo missing").WithHTTPStatus(404) })`, asserts status 404 and body `{family: "rejection", code: "example.not_found"}`, and a second assertion that an `errorfamily.NewInfrastructure("demo.boom", "secret /home/lars/key.pem detail")` renders 503-family default text with the path absent. That moves go-error-family from indirect to direct-in-test in go.mod (one require), which is acceptable for a scaffold teaching its own contract. Impact: high (every adopter's handlers). Ease: high (~25 lines in routes_test.go).
3. **G3 — `LogError` re-exported but never called** `[PRESET-UPSTREAM]`. The lib offers family-aware logging (Transient→Warn, others→Error, fields family/code/retryable/context.*, README "Structured Logging"); appkit re-exports it (core errors.go:40-45) but no non-test appkit code calls it (grep verified; httpx.WriteError renders but does not log). Every preset adopter's server-side request errors therefore lose classification in logs. Fix: httpx/preset logs the classified error at the WriteError boundary (or a preset middleware does), keeping the no-leak contract (log the full error server-side, render the sanitized one). Impact: medium (observability is a spine promise). Ease: medium (preset change, one call site + tests).
4. **G4 — Code-level message templates unused** `[PRESET-UPSTREAM]`. The lib offers `RegisterTemplate`/`TemplateForCode` (handle.go:402-418) so an adopter's code (`order.duplicate`) gets a tailored What/Why/Fix; the chain surfaces only family defaults (httpx/errors.go:46-47). A preset option that accepts template maps (or httpx consulting `TemplateForCode(code)` before family defaults) would let adopters enrich client messages without touching renderers. Impact: medium. Ease: medium.

## Should the archetype adopt or wire more?

For a template whose adopters re-clone: the DEFAULT BINARY should gain nothing (the spine already runs the full classification surface; any new import thickens the composition root against its own stated posture). DOCS/TESTS is where the remaining value lives: the single rendered-shape test from G2 teaches the contract every adopter will exercise, and it is the only place a direct import is justified. What must stay OUT: `HandleError`/`HandleErrorDetailed` (cmdguard owns the CLI boundary), `diagnose`/`agent`/`bridge` (CLI/auto-diagnosis/AI shapes, wrong for a server), and any retry loop wiring (no demand; fleet go-retry exists for that). The build-tag-gate pattern (internal/events) is not needed here: go-error-family is already inside the default binary via the preset, weighs nothing (zero third-party deps, ~9 ns Classify), and has no optional heavy leg to hide.

## Version currency

Pin v0.12.0 is the LATEST tag and the template's copy is current. It is an indirect pin (go.mod:97), so bumps ride the next go-appkit train, not the template's own `go mod tidy` (tidy only re-resolves when appkit moves). What the 13 commits past v0.12.0 contain (CHANGELOG `[Unreleased]` + `git log v0.12.0..HEAD`, all read): release-engineering only — golangci-lint-action pins v2.13.2→v2.15.0 across ci.yml/release.yml, and wrapcheck `ignore-sigs` gained six errorfamily signatures (`WithContext(`, `WithContextAny(`, `WithContextf(`, `WithCause(`, `WrapRejection(`, `WrapTransient(`) that v2.15's signature detection false-flags as unwrapped externals. No API changes, no behavior changes coming. Forward-looking items live in TODO_LIST/ROADMAP (bridge-guide announcement, art-dupl CI gate enforcement, `HTTPHandler`/`LogError` discoverability push) — none are code. Nothing for the template to act on.

## Risks

- **Fail-open classification default**: an unclassified error (bare `fmt.Errorf` returned from an httpx handler) classifies Transient → HTTP 503 + retryable. Adopters who do not classify their domain errors will serve 503s for what are really 500-class bugs, with a generic reassurance message. Deliberate lib design (classify.go default), but the archetype currently teaches no counter-move (see G2). Verified from lib classify pipeline order.
- **Sanitizer scope**: Rejection/Conflict echo the error's own text (scrubbed for paths/SQL/goroutines only, httpx/sanitize.go:13-21,56-58). An adopter who wraps internal details into a Rejection can still leak non-matching internals (hostnames, user IDs, partial SQL above the 200-char window). `Public()` is the intended escape hatch, not `Message()`.
- **Exit-code seam** (G1): today every boot failure of this template exits 1 regardless of family; any adopter scripting on BSD sysexits codes will be wrong. Not a misuse by the template; a latent cross-repo contract gap.
- No deprecated APIs in use; the v0.10.3 retracted tags (v0.5.0/v0.5.1/v0.6.0, proxy-breaking replaces) are irrelevant at pin v0.12.0. Checked lib CHANGELOG retract notes and the template's go.sum (single clean v0.12.0 pair).

## How to verify

```bash
# Version facts
git -C /home/lars/projects/go-error-family describe --tags   # v0.12.0-13-g01d155e
git -C /home/lars/projects/go-error-family log --oneline v0.12.0..HEAD | wc -l  # 13, all chore
# Template: indirect-only, zero template-direct usage
rg -n 'go-error-family' /home/lars/projects/go-service-template/go.mod          # line 97, // indirect
rg -n 'errorfamily' /home/lars/projects/go-service-template --glob '*.go'       # no matches
# HTTP hop
rg -n 'errorfamily\.' /home/lars/projects/go-appkit/httpx/errors.go             # :37 :41 :52
rg -n 'ResultHandler|WriteError' /home/lars/projects/go-appkit/httpx/result.go  # :48 :55
sed -n '43,62p' /home/lars/projects/go-appkit/httpx/sanitize.go
# Boot hop + preset registration
rg -n 'server.listen_failed' /home/lars/projects/go-appkit/service.go           # :147
rg -n 'RegisterClassifications' /home/lars/projects/go-appkit/preset/preset.go  # :102
rg -n 'config.invalid' /home/lars/projects/go-appkit/config/config.go           # :339
rg -n 'NewRejection' /home/lars/projects/go-appkit/errorpages/errorpages.go     # :163
# cmdguard: structural participation only, exit-code fallback
rg -n 'go-error-family' /home/lars/projects/cmdguard --glob '*.go'              # one comment, cli_errors_json.go:44
sed -n '39,53p' /home/lars/projects/cmdguard/pkg/cmdguard/v5/cli_errors_json.go
rg -n 'errorfamily|go-error-family' /home/lars/projects/cmdguard/go.mod         # indirect only
# Lib side of the seam
rg -n 'func \(e \*Error\) ExitCode' /home/lars/projects/go-error-family/error.go          # :324, returns 0 when unset
sed -n '78,92p' /home/lars/projects/go-error-family/classify.go                            # package-level fallback
# Unreleased content
sed -n '1,12p' /home/lars/projects/go-error-family/CHANGELOG.md                            # [Unreleased]: lint pins + wrapcheck sigs
```

## Submodule matrix

The template repo itself has exactly ONE go.mod (no submodules of its own); every row below is a separately versioned module of the lib.

| Module path | In template graph | How used | Latest tag | Note |
|---|---|---|---|---|
| github.com/larsartmann/go-error-family | Yes (indirect, go.mod:97) | Classification core of the entire appkit spine (see What the template uses today) | v0.12.0 | The only row with runtime relevance |
| .../go-error-family/agent | No | None anywhere in the chain | agent/v0.2.5 | N/A: AI root-cause analysis over diagnostic context; a service archetype has no AI flow and nothing in preset/template calls `agent.New` |
| .../go-error-family/bridge | No | None | bridge/v0.3.4 | N/A: samber/oops interop; neither appkit nor the template uses oops (enrichment is appkit logger + otel's job) |
| .../go-error-family/diagnose | No | None | diagnose/v0.2.6 | N/A: rules framework for CLI auto-diagnosis (`HandleConfig.DiagnosticFunc`); a server reports via health endpoints, and the template never invokes `HandleError` |
| .../go-error-family/diagnose/git | No | None | diagnose/git/v0.5.4 | N/A: repo-state/merge-conflict/remote rules; meaningless for an HTTP service |
| .../go-error-family/diagnose/postgres | No | None | diagnose/postgres/v0.5.4 | N/A for the template (no postgres; the cqrs skeleton uses sqlite behind the `events` tag). Adopters who add postgres MAY want it in their own ops CLI, adopter-specific, never preset spine |
| .../go-error-family/examples | No | None | examples/v0.3.2 | N/A: runnable demo programs (CLI/HTTP/custom-rule/bridge), a documentation module, not a dependency |
