# go-business-rules — utilization review (go-service-template)

| Reviewed | 2026-11-23 |
|---|---|
| Library | github.com/Larsartmann/go-business-rules/v2 (+ submodules adapters/cqrslite, listeners/otel, examples/sse) |
| Version audited | v2.2.1-7-g75a1a8c (75a1a8c, 2026-11-23) |
| Template pin | ABSENT (not in go.mod at all: no direct require, no indirect entry, not even go-finding transitively; zero template imports; zero go-appkit references, `rg -l businessrules /home/lars/projects/go-appkit` matches nothing) |
| Latest tag | v2.2.1 (2026-11-04) |
| Adoption score | 0/100 (low), 0 of 1 applicable capabilities leveraged |
| Verdict | Do not adopt: a severity-aware business-rules layer is domain machinery, and this archetype deliberately has no domain; absence is the correct posture, not an oversight. |

This is an ADOPTION ANALYSIS, not a utilization audit: the library is entirely absent from the template's module graph, so the score measures the (near-empty) set of applicable capabilities for a domainless archetype, while the adopt/don't-adopt judgment below carries the real weight.

## Verdict

Not used at all, and that is correct for this repo. go-business-rules is severity-aware validation: rules return the *degree* of failure (Info/Warning/Error/Critical) instead of pass/fail, which only means something once a repo has domain types with domain rules. The template's 322 lines contain one status handler, one templ page, and env-driven config whose validation is already owned by go-appkit/config's binary `Rejection` contract (`internal/app/service.go:31-41`); there is nothing to severity-grade. "Max" here would mean: keep the default binary free of it (achieved), route cloners to it in docs when their domain appears (one small miss, see gaps), and resist inventing a speculative rules skeleton next to `internal/events` (correctly resisted). The library itself is healthy and fleet-proven: 7 fleet repos pin it directly on v2.2.x, all with production (non-test) usage.

## What the template uses today

- ABSENT: `go.mod` has no `go-business-rules` entry in either require block (verified: `rg -n 'go-business-rules' go.mod` finds nothing; the indirect block's larsartmann modules are appkit, cqrs-lite, codec, etc., not businessrules or its go-finding dependency).
- ABSENT: no template source imports it (`rg -l 'businessrules' .` excluding docs matches nothing; the only mentions are this review series itself).
- ABSENT (preset check): go-appkit does not reference it either, so there is no PRESET-MEDIATED usage; `rg -l 'businessrules' /home/lars/projects/go-appkit` exits with no matches across all of go-appkit including its `cqrs` wrapper.
- The two surfaces a rules engine might temptingly attach to are correctly served elsewhere: config validation by `config.Load[Config]` + `Rejection` (`internal/app/service.go`), and request errors by the `httpx.ResultHandler` classified no-leak error contract (`internal/api/routes.go`).

## Capability inventory

| Capability | Status | Evidence | Note |
|---|---|---|---|
| Core API: `Rule` interface, `ValidatorBuilder` fluent `Build()`, `ValidationResultError` | Not applicable | lib `rule.go`, `validator.go`, `doc.go:18-28`; template has no domain types carrying `Rules()` | needs domain state to validate; the archetype defines none by design (docs/DOMAIN_LANGUAGE.md: "This repo has no business domain") |
| Severity model (Info/Warning/Error/Critical, aliased from go-finding) | Not applicable | lib `severity.go`, README:134-147 | a severity ladder requires outcomes with degrees of failure; template outcomes are binary (classified error or success) |
| ~50 prebuilt builders (numeric, string, collection, time, network/ID, precision, format, generic) | Not applicable | lib `builders*.go`, README:285-358 | zero domain inputs exist to check; `statusResponse` carries no rules |
| Composite rules (`All`/`Any`/`When`/`Not`/`Or`/`Xor`) | Not applicable | lib `builders_composite.go`, doc.go:79-84 | nothing to compose |
| Listener hooks: `WithListener`, sealed `RuleEvaluated`/`ValidationCompleted` events | Not applicable | lib `events.go:8-10,79-82` | hooks fire per validation run; no runs exist to observe |
| Concurrent evaluation: `Stream(ctx)`, `ContextRule`, `WithConcurrency(n)` | Not applicable | lib doc.go:108-131, CHANGELOG 2.1.0 | performance shape for I/O-bound rules; there are no rules, let alone slow ones |
| Rule metadata (`WithDescription`/`WithTags`, surfaced on events) | Not applicable | lib doc.go:86-87, CHANGELOG 2.2.0 | metadata exists to feed observability of runs; no runs |
| Error handling shape: result implements `error`, `Merge`, `ForEach`, `First*`, JSON marshal | Not applicable | lib `validation_result.go`, `errors.go` | template's error contract is httpx classified errors, already owned and binary by design |
| Type safety / DX: generic builders (`OneOf[T]`, `Equals[T]`), immutable rules, sealed event union | Not applicable | lib doc.go:128, README:402-404 | library-internal quality; no consumer code exists to benefit |
| Observability: `listeners/otel` (spans + 5 metric instruments incl. `businessrules.violations`) | Not applicable | lib `listeners/otel/adapter.go:31-51` | the preset's otel leg exists, but a listener with zero validation runs emits nothing; also this submodule is unpublished (see below) |
| Integration: `adapters/cqrslite` (validation events onto a go-cqrs-lite bus) | Not applicable | lib `adapters/cqrslite/doc.go:12-33` | the template's cqrs entry point is the build-tag-gated `internal/events` skeleton; publishing validation runs as domain events is a domain-owner decision, and the module cannot even be `go get`-ed today |
| Integration: `examples/sse` Datastar live feed; govalid structural+business pairing | Not applicable | lib `examples/sse/main.go`, README:99-129 | demo/educational surface, nothing to mirror in an archetype |
| Testing utilities: injectable "now", example tests, gopter property tests | Not applicable | lib `builders_time.go`, `property_test.go` | no rules to test |
| Adopter routing: point cloners at the fleet's business-validation library in docs | Missed opportunity | `rg -ci 'business.?rule\|validation' README.md docs/DOMAIN_LANGUAGE.md` finds nothing | the one capability applicable to a domainless archetype: a zero-weight docs pointer so adopters know where severity-aware validation lives when their domain appears (this review series itself is the partial start) |

Row count 14; Not applicable 13; applicable A = 1; Σ = 0 (one Missed opportunity scores 0); score = round(100 × 0/1) = 0, band low.

## Gaps and opportunities

Ranked by impact × ease. The honest headline: there is exactly one actionable gap, and it is a sentence of documentation.

1. **Adopter-routing docs pointer** [TEMPLATE]. What the lib offers: a public, documented, pkg.go.dev-indexed library (README quick start, doc.go overview) positioned as the business layer above structural validators (README:99-106). What the template does instead: nothing; README and docs/DOMAIN_LANGUAGE.md never mention business validation (verified, 0 matches), so a cloner's discovery of the fleet rules library is luck. Impact: low-moderate (every adopter with a domain hits this decision in week one); ease: trivial. Sketch: one line in `internal/events/events.go`'s doc block or the README "What's inside" table: "Domain validation: when your types grow rules, use github.com/LarsArtmann/go-business-rules/v2 (severity-aware; see docs/review/libs/go-business-rules.md), not hand-rolled if-chains." Optionally a `docs/fleet-libraries.md` stub.
2. **Publish the nested modules** [LIB-UPSTREAM]. All three submodules carry `replace github.com/LarsArtmann/go-business-rules/v2 => ../..` (verified in each go.mod) and no tags exist outside the root module (`git tag -l` shows only root tags), so no fleet consumer can depend on `adapters/cqrslite` or `listeners/otel` without replace hacks; this is the lib's own open question (ROADMAP.md, question 4). Impact: fleet-wide (the cqrs bridge is exactly what an adopter service with an events skeleton would want); ease: medium (drop replaces, tag `adapters/cqrslite/v2.x.y` style, add the missing tag-push CI from TODO_LIST.md "Run CI on tag pushes"). The template cannot route around this; it is upstream's to fix.
3. **Version-signal hygiene** [LIB-UPSTREAM]. `doc.go:135` still says `const Version = "2.2.0"` at v2.2.1/HEAD, and v2.2.1 shipped CI/chore work with no CHANGELOG section (verified: CHANGELOG jumps 2.2.0 → Unreleased; the cqrs-htmx sibling review flagged the same). Impact: small but it degrades the trust signals adopters check before pinning; ease: trivial.
4. **Build-tag-gated rules skeleton (mirroring `internal/events`)** [NOT-NOW + speculative]. The events skeleton is justified because it wires a real framework leg (`go-appkit/cqrs v0.9.0` is a direct require and `internal/events/events.go` instantiates it). A rules skeleton would have no preset surface behind it: dead code that pre-decides *where* validation lives (handler edge vs domain type vs command mapper), which is precisely the domain-owner decision an archetype refuses to make. Fleet evidence: consumers integrate it inside domain types (Polish-Customs `pkg/types/money.go` 13 sites, `item.go` 16, `weight.go` 12), not in infrastructure a template could own. Revisit only if go-appkit ever grows a validation leg.
5. **Preset / appkit-cqrs integration** [NOT-NOW + wrong shape + hard constraint]. The appkit cqrs facade is decider-based and binary by design (`go-appkit/cqrs/commands.go`: `RegisterDecider`, accept-and-emit vs reject). Wiring severity-graded validation into it would (a) couple every adopter to a domain decision, and (b) force `GOEXPERIMENT=jsonv2` on all preset consumers, since importing businessrules requires it (README:19, ADR-0004; the template today builds with no experiment set, per the templ-components review's empirical check). The fleet's cqrs showcase, cqrs-htmx, independently adjudicated the same verdict on 2026-11-22 (`cqrs-htmx/docs/review/libs/go-business-rules.md`): deciders ARE the rules; flip conditions are a severity-tier outcome need, rule reuse as data, or validation-run audit as domain events. None exists anywhere in the fleet today.

## Should the archetype adopt or wire more?

No. Default binary: nothing, unchanged; a rules engine's weight (go-finding dependency, jsonv2 build constraint) buys zero in a domainless service and the template's delete-if-CRUD posture would only be diluted. Docs/examples: the one-sentence pointer from gap 1 is the entire warranted footprint; the events skeleton's doc comment is the natural home since domain rules and domain events arrive together. Must stay out: any rules skeleton, any preset ask, any direct require. Where business-rules belongs in the fleet stack: adopter-local, in domain types, exactly as Polish-Customs does (`BusinessRules()` methods on Money/Weight/Item, with `pkg/types/validation.go` explicitly documenting the split between imperative constructor guards and the severity-aware rule machinery). The cqrs path (cqrs-htmx or an adopter's events skeleton) becomes relevant only under the audit-trail flip condition, and only after [LIB-UPSTREAM] publishing makes `adapters/cqrslite` consumable.

## Version currency

Not applicable in the usual sense: there is no pin to bump, and none is warranted. Facts for the day an adopter adds it: latest tag is v2.2.1 (2026-11-04); HEAD is 7 commits past it, all chore/docs (Anti-Language docs section, flake sync), no API change; `[Unreleased]` in CHANGELOG is only the Go toolchain floor raise to 1.27 (2026-09-23), which the template's Go 1.27.4 satisfies. Fleet pin spread: 4 of 7 consumers on v2.2.1, 3 on v2.2.0, so v2.2.1 is the fresh pin. The v1→v2 break (v2.0.0, 2026-07-26): type renames (`Violation`→`ViolationError`, `ValidationResult`→`ValidationResultError`), `Severity` became an alias of go-finding's (comparison via `.GreaterThanOrEqual()`, not numeric operators), and the hard `encoding/json/v2`/`GOEXPERIMENT=jsonv2` requirement; v2.1.0 then moved the module path to `/v2` (the suffix-less `v2.0.0` tag only ever resolved `+incompatible`). Any adopter pin must also set `GOEXPERIMENT=jsonv2` in its build environment (the template's plain `go build` promise would need a note).

## Risks

For the template itself: none, nothing is imported (verified). For adopters the template should document:

- `GOEXPERIMENT=jsonv2` is a hard build constraint until encoding/json/v2 graduates (README:19; TODO_LIST re-verified 2026-10-04). An adopter adding the lib inherits it.
- Nested modules are unpublished (local `replace` directives, no submodule tags): `go get` of `adapters/cqrslite`/`listeners/otel` fails today.
- Listener contract is trusted-code: listeners must not panic (`events.go:79-82`); the cqrslite adapter silently swallows publish errors unless `WithPublishErrorHandler` is set ("always set one in production", `adapters/cqrslite/doc.go:29-32`).
- `Stream` must be drained or its context canceled or the internal goroutine leaks (`doc.go:130-131`).
- Supply-chain signal: tags run no CI yet (TODO_LIST "Run CI on tag pushes"), so v2.2.1 was never CI-verified as a tag; `doc.go:135`'s `Version` constant is stale at 2.2.0.
- Misuse shape: recruiting it for structural validation (format/required) duplicates what govalid-class validators do; the README itself positions it strictly as the business layer above them (README:99-106).

## How to verify

```bash
rg -n 'go-business-rules' /home/lars/projects/go-service-template/go.mod | wc -l                 # 0 (absent from both require blocks)
rg -l 'businessrules' /home/lars/projects/go-service-template -g '!docs/**' | wc -l              # 0 (no imports; docs/ holds this report only)
rg -l 'businessrules' /home/lars/projects/go-appkit | wc -l                                      # 0 (no preset mediation)
git -C /home/lars/projects/go-business-rules describe --tags                                     # v2.2.1-7-g75a1a8c
git -C /home/lars/projects/go-business-rules log -1 --format='%h %ci'                            # 75a1a8c 2026-11-23 01:25:09 +0100
git -C /home/lars/projects/go-business-rules tag -l | sort -V | tail -1                          # v2.2.1
rg -l 'go-business-rules' /home/lars/projects --glob go.mod | wc -l                              # 11 (7 fleet consumers + 4 modules inside the lib repo)
rg -n 'replace' /home/lars/projects/go-business-rules/adapters/cqrslite/go.mod                   # replace ... => ../.. (unpublished submodule proof)
rg -n 'Version = ' /home/lars/projects/go-business-rules/doc.go                                  # const Version = "2.2.0" (stale at v2.2.1)
rg -c 'businessrules\.' /home/lars/projects/Polish-Customs/pkg/types/money.go                    # 13 (live consumer, domain-type integration)
rg -ci 'business.?rule|validation' /home/lars/projects/go-service-template/README.md; echo ok    # 0 matches (the docs-pointer gap)
```

## Submodule matrix

| Module path | In template graph | How used | Latest tag | Note |
|---|---|---|---|---|
| github.com/LarsArtmann/go-business-rules/v2 (root) | No | Nothing (absent) | v2.2.1 | the severity-aware validation core; correct home is adopter domain types, not the archetype |
| github.com/LarsArtmann/go-business-rules/adapters/cqrslite | No | Nothing | none (unpublished, local replace) | publishes validation events onto a go-cqrs-lite bus; the bridge an events-skeleton adopter would use for validation audit trails, if it ever gets published |
| github.com/LarsArtmann/go-business-rules/listeners/otel | No | Nothing | none (unpublished, local replace) | OTel spans/metrics for validation runs; nothing to instrument in a repo with no runs |
| github.com/LarsArtmann/go-business-rules/examples/sse | No | Nothing | none (unpublished, local replace) | Datastar live-feed demo of validation events; educational only, no adopter-relevance for a template |
