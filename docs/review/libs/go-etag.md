# go-etag: utilization review (go-service-template)

| Reviewed | 2026-11-23 |
|---|---|
| Library | github.com/larsartmann/go-etag (+ submodules) |
| Version audited | v0.7.1-6-gbe01b8a (be01b8a, 2026-11-22) |
| Template pin | server v0.6.1 + entitytag v0.6.1 (indirect via go-appkit/httpx v0.2.0, and via httputil v1.8.0 behind appkit v0.12.0); client + metrics absent from graph |
| Latest tag | root v0.7.1; nested train server/entitytag/client/metrics v0.6.2 |
| Adoption score | 0/100 (low), 0 of 5 applicable capabilities leveraged |
| Verdict | Graph-only: the mediated surface (httpx.Conditional) ships inside the template's pinned httpx, but neither the template nor the preset ever wraps a handler with it, so no response this service emits carries an ETag. |

## Verdict

Not used, anywhere, at runtime. The library enters the module graph twice (httpx v0.2.0 direct require of server v0.6.1; httputil v1.8.0 behind appkit), and both entrances are dormant: httpx.Conditional (the only Go code in the whole appkit repo that imports go-etag, httpx/conditional.go:9) has zero call sites in the preset or the template, and httputil's go-etag error-template registration is never invoked by the chain the template runs. Verified negative: the template's `GET /api/status` (internal/api/routes.go:25, plain `httpx.ResultHandler`) and the templ hello page (views/views.go:13, plain `templ.Handler`) get no ETag, no 304; the preset mounts no etag middleware (preset/preset.go imports no httpx at all); the health dashboard (go-health-dashboard, a separate module) contains zero go-etag references and hand-sets only Cache-Control. "Max" here does not mean wrapping everything: body-hash validators are wrong for SSE and huge payloads, and the lib's own design is per-route opt-in. Max means (a) the one example JSON endpoint demonstrates the one-line conditional wrap every adopter will eventually want on their own endpoints, and (b) the preset carries the error-classification registration it already owns the superset for. Today the template does neither, so the entire capability is a shipped-but-untouched import.

## What the template uses today

- GRAPH-ONLY: `github.com/larsartmann/go-etag/server v0.6.1 // indirect` and `github.com/larsartmann/go-etag/entitytag v0.6.1 // indirect` (go-service-template go.mod:98-99). Resolved via the template's direct `go-appkit/httpx v0.2.0` (go.mod:11; httpx/v0.2.0's own go.mod line 9 requires server v0.6.1, verified with `git show httpx/v0.2.0:httpx/go.mod`) and via `httputil v1.8.0` (go.mod:119, behind appkit v0.12.0; v1.8.0's go.mod lines 8/13 pin the same v0.6.1 pair).
- TEMPLATE-DIRECT: nothing. `rg -l 'go-etag'` over all template `*.go` returns empty; none of the 7 files import it.
- PRESET-MEDIATED (surface exists, never applied): `httpx.Conditional(handler, opts...)` composes go-etag's server middleware (strong sha256 ETag, 1 MiB buffer) with an If-Modified-Since layer (appkit httpx/conditional.go:9 import, :62-84 wrapper, :88-101 config, :108-110 SetLastModified; released in httpx v0.2.0 per appkit httpx/CHANGELOG.md:21-28,46-47). The preset package itself never imports httpx (preset/go.mod has no httpx require; preset/preset.go:3-17 imports appkit, errorpages, health, otel, realtime, systemd, errorfamily, httputil only), so nothing in `appkitpreset.New` gives any route conditional semantics.
- PRESET-MEDIATED (near miss): httputil registers go-etag's error-code templates as part of a strict superset (`httputil.RegisterClassifications`, httputil/errors.go:7 import, :507-512), but the only registration the template's runtime performs is `appkit.RegisterClassifications()` (called preset/preset.go:102), which registers stdlib defaults plus `*http.MaxBytesError` and nothing else (appkit errors.go:28-31). Go-etag's codes are therefore not even registered as error templates.
- ABSENT: client and metrics submodules are not in the module graph at all. The health dashboard mounted by the preset is the separate go-health-dashboard module; it has zero go-etag references (go.mod, go.sum, no imports) and sets only Cache-Control headers (e.g. go-health-dashboard metrics.go:62, favicon.go:23, handlers.go:34, oidc_session.go:155).

## Capability inventory

| Capability | Status | Evidence | Note |
|---|---|---|---|
| Server middleware: body-hash ETag + automatic If-None-Match 304 (GET/HEAD, 2xx only) | Missed opportunity | go-etag server: `etag.New(cfg)` (server/etag.go, re-exported surface in server/config.go:157); wired only inside appkit httpx/conditional.go:71; no call site in template (routes.go:25, views.go:13) or preset | Buffer-bounded (1 MiB default) with graceful degradation: overflow, Hijack and handler Flush all fall back to untagged streaming, so the preset's realtime SSE leg would need no special casing beyond its own Flush behavior |
| Time-validator composition: Last-Modified / If-Modified-Since with RFC 9110 precedence | Missed opportunity | appkit httpx/conditional.go:62-84 (Conditional), :112-215 (imsWriter), :108-110 (SetLastModified) | IMS runs only when the client sent no If-None-Match; ships in the template's pinned httpx v0.2.0, never invoked |
| Conditional GET on JSON endpoints | Missed opportunity | Template's one handler is a bare `httpx.ResultHandler` (routes.go:25-29); httpx/result.go:48-66 contains no conditional logic (verified read) | One line from working: `httpx.Conditional(httpx.ResultHandler(...))`; the status payload is byte-stable between deploys (version field), the ideal hash-validator shape |
| ETag on server-rendered HTML (templ views, preset error pages) | Missed opportunity | views/views.go:13 plain `templ.Handler`; `rg -l 'go-etag' /home/lars/projects/go-appkit --glob '*.go'` matches only httpx/conditional.go and httpx/doc.go, so errorpages renders untagged | templ output is deterministic per binary; tags would change exactly once per deploy |
| Classified error codes + `RegisterErrorClassifications` | Missed opportunity | go-etag server/errors.go codes (`http.etag_write_failed` etc.); httputil/errors.go:507-512 registers the superset; template runtime calls only appkit.RegisterClassifications (preset/preset.go:102 → appkit errors.go:28-31, stdlib defaults + MaxBytesError) | The registration the fleet already wrote is one call away from every preset consumer |
| entitytag typed validators + `MatchesIfMatch` (If-Match / 412 lost-update prevention) | Not applicable | entitytag/entity_tag.go:91-194 (StrongEqual/WeakEqual, ParseETag(List), MatchesIfMatch) | The archetype ships no unsafe-method handlers; this is an adopter story (PUT/PATCH handlers comparing a DB revision tag), belongs in docs, not template code |
| `SkipIfPresent` (respect handler-set validators) | Not applicable | ETagConfig.SkipIfPresent (README Configuration; server/config.go:24) | No archetype handler sets an ETag today; adopter story: database revision numbers passed through as strong validators |
| Validator policy: HashFunc and Strength | Not applicable | httpx/conditional.go:88-101 already fixes strong sha256 over the lib's FNV-64a default | The policy decision is mediated inside httpx.Conditional; there is nothing for the template to choose until something is wrapped |
| Client transport: RFC 9111 conditional-GET cache (304 rebuild, no-store, unsafe-method invalidation, HEAD freshening) | Not applicable | client/transport.go:40 (`NewTransport`), client/options.go; docs/rfc9111-conformance.md (requirement-by-requirement table) | The archetype makes zero outbound HTTP calls; module is not even in the graph. Adopter story for services that poll upstream APIs |
| Observability hooks + metrics.Attach counters (Generated/NotModified/HitRatio) | Not applicable | metrics/metrics.go:38 (Attach), :87 (HitRatio); server hooks OnETagGenerated/On304/OnBufferOverflow | Counters presuppose wired middleware; the preset's metrics leg has no etag counters, and there is nothing to count today |
| ETag for health-dashboard assets | Not applicable | go-health-dashboard repo: no go-etag in go.mod/go.sum/imports; Cache-Control only (metrics.go:62, favicon.go:23) | The dashboard is a separate module with its own cache posture; not this template's surface to change |

Scoring reconciliation: 11 rows, 6 Not applicable, A = 5 applicable, all 5 Missed opportunity (0 each, no Partially used or Misused), Σ = 0, score = round(100 × 0 / 5) = 0.

## Gaps and opportunities

1. **Preset does not register go-etag's error templates it already depends on** [PRESET-UPSTREAM]. httputil ships `RegisterClassifications` as "a strict superset of go-etag's error templates and stdlib" (httputil/errors.go:507-512), but appkit's `RegisterClassifications` (errors.go:28-31) registers only stdlib defaults + MaxBytesError, and that is what the template executes via preset/preset.go:102. Impact: any etag middleware error surfacing through an adopter's error pages renders unclassified. Ease: one idempotent call inside appkit's registration. Sketch (appkit errors.go):

   ```go
   func RegisterClassifications() {
       errorfamily.RegisterStdlibDefaults(errorfamily.DefaultRegistry)
       errorfamily.RegisterClassificationType[*http.MaxBytesError](errorfamily.Rejection)
       httputil.RegisterClassifications() // superset: stdlib + go-etag codes
   }
   ```

2. **The example endpoint should demonstrate the conditional pattern** [TEMPLATE]. The archetype's job is teaching the fleet's canonical shapes; the return-(T, error) handler is demonstrated, the conditional wrap is not, and it is the same one-line shape (routes.go:25):

   ```go
   mux.Handle("GET /api/status", httpx.Conditional(httpx.ResultHandler(
       func(_ *httpx.Context) (*statusResponse, error) {
           return &statusResponse{Status: "ok", Version: deps.Version}, nil
       },
   )))
   ```

   Impact: every cloned service shows adopters where conditional GETs live before they write their real endpoints; pollers get free 304s on a byte-stable payload. Ease: one line, no new dependency (httpx v0.2.0 is already direct). This is the same teaching posture as the events skeleton, at 1/40th the weight; no build tag needed.
3. **Conditional GET as a preset leg** [PRESET-UPSTREAM]. Today an adopter must know `httpx.Conditional` exists. A preset Config knob (env-grammar opt-in, safe-method API prefixes, SSE automatically excluded) would give every adopter 304s on JSON endpoints with zero code, keeping the template thin. Design care required: byte-determinism is a handler responsibility (httpx/conditional.go:52-57 warns about map ordering, floats, timestamps), so the default should stay opt-in, never global.
4. **Client transport and metrics module** [NOT-NOW + wrong shape for a server archetype: zero outbound HTTP calls, nothing wired to count; both are adopter stories for cloned services that gain upstream dependencies]. Document a snippet in adopter-facing docs when gap 2 or 3 lands.

## Should the archetype adopt or wire more?

ETag support is HTTP correctness every real service eventually wants, but the lib's own shape (per-route opt-in, buffer bounds, streaming fallback) is correct for it, and the mediated surface already ships in the pinned httpx. So: default binary gets exactly one demonstration, the conditional wrap on `GET /api/status` (gap 2, one line, teaches the pattern, no weight); broad wiring belongs in the preset as an opt-in leg (gap 3), not in template code, because which endpoints deserve validators is adopter-specific (SSE, downloads, per-user payloads all differ). Docs should carry the two adopter stories the template must not code: If-Match lost-update prevention on future PUT handlers, and the client transport for services that poll upstream APIs. Stays out: client and metrics modules (no consumer for them in the archetype; the build-tag-gate pattern is unnecessary for a one-line wrap that adds no dependency).

## Version currency

Template resolves server v0.6.1 + entitytag v0.6.1, both indirect; latest nested tags are v0.6.2 (released 2026-11-18 in the root v0.7.1 staircase). What the gap contains (CHANGELOG [0.6.2], [0.7.1]): server's only functional delta is go-error-family v0.11.0 → v0.12.0 (nil-receiver-safe Unwrap) plus an internal file split (etag.go gained config.go, public API unchanged); entitytag v0.6.2 is an internal test-suite re-tag with zero public API change. Notably the template already resolves go-error-family v0.12.0 (go.mod:97), so the v0.6.2 tags add nothing functional for this graph; the drift is cosmetic. The bump is not the template's to make: both entry paths are indirect, and no released module in its graph requires v0.6.2 yet. The bump sits unreleased in appkit's httpx working tree (commit a2a5c49, 2026-11-18, after the httpx/v0.2.0 tag of 2026-11-08; no httpx tag exists since) and in httputil's working tree (after v1.9.0 of 2026-11-14, which still pins v0.6.1; appkit v0.13.0 of 2026-11-21 still resolves v0.6.1). It rides the next httpx and/or httputil tag and then the appkit train; the template should never pin these directly.

## Risks

- Middleware order vs compression: the ETag layer must see the final representation, beneath any compression layer, or tags silently vary with Content-Encoding (README "Cache policy: who owns which headers"). Latent today: no response-compression middleware exists in the appkit chain (grep for gzip/compress matches only writedeadline and flightrecorder, unrelated). Becomes live the day appkit adds one; the preset leg from gap 3 must place Conditional accordingly.
- Byte-determinism: body-hash validators churn on unstable serialization (map key order, floats, timestamps; httpx/conditional.go:52-57). The status payload is safe; future adopter endpoints may not be.
- Root module is a deprecated alias shim (doc.go:1-19, deprecated.go re-exports; deleted at v1.0.0). Never import `github.com/larsartmann/go-etag` root; appkit's integration module already carries an exclude block for root v0.1.1-v0.5.0 to kill the ambiguous-import class (appkit integration/go.mod:175-180).
- Client-side credential warning (default KeyFunc ignores credentials, README warning) applies only to the client module the template does not use; recorded for the adopter story.
- No misuse found in the template because there is no use; checked the mediated surface for the classic traps (weak validators for If-Match: httpx deliberately excludes unsafe-method semantics, conditional.go:59-61; 304 Content-Length stripping and HEAD framing are the lib's, pinned by its RFC compliance suites).

## How to verify

```bash
# Template: graph presence, zero usage
rg -n 'go-etag' /home/lars/projects/go-service-template/go.mod
rg -l 'go-etag' /home/lars/projects/go-service-template --glob '*.go'   # empty output

# Appkit: the only importers, and what the preset does NOT do
rg -l 'go-etag' /home/lars/projects/go-appkit --glob '*.go'             # httpx/conditional.go, httpx/doc.go
rg -n 'go-etag|httpx' /home/lars/projects/go-appkit/preset/go.mod       # go-etag indirect only, no httpx require
rg -n 'httpx' /home/lars/projects/go-appkit/preset/preset.go            # empty: preset never imports httpx
sed -n 28,31p /home/lars/projects/go-appkit/errors.go                   # RegisterClassifications: stdlib + MaxBytesError only
sed -n 505,515p /home/lars/projects/httputil/errors.go                  # httputil registers the go-etag superset (uncalled here)
sed -n 48,66p /home/lars/projects/go-appkit/httpx/result.go             # ResultHandler: no conditional logic

# Dashboard: not a consumer
rg -n 'go-etag' /home/lars/projects/go-health-dashboard/go.mod          # empty

# Version facts
git -C /home/lars/projects/go-etag describe --tags                      # v0.7.1-6-gbe01b8a
git -C /home/lars/projects/go-etag log --oneline v0.7.1..HEAD           # 6 docs/chore commits, no code
git -C /home/lars/projects/go-etag tag | rg 'v0.6.2|v0.7.1'
git -C /home/lars/projects/go-appkit show httpx/v0.2.0:httpx/go.mod | rg go-etag   # server v0.6.1
git -C /home/lars/projects/go-appkit log --format='%h %ci %s' httpx/v0.2.0..HEAD -- httpx/go.mod  # a2a5c49 v0.6.2 bump, unreleased
git -C /home/lars/projects/httputil show v1.9.0:go.mod | rg go-etag     # still v0.6.1
```

## Submodule matrix

| Module path | In template graph | How used | Latest tag | Note |
|---|---|---|---|---|
| github.com/larsartmann/go-etag (root) | No | Nothing; appkit's integration module excludes root v0.1.1-v0.5.0 as an ambiguous-import guard | v0.7.1 | Deprecated alias shim for the server package (doc.go, deprecated.go); contains zero implementation code and is deleted at v1.0.0. The root tag stays one minor ahead of the nested train by release convention: v0.7.1 is the staircase release commit for the v0.6.2 train, NOT a "v0.7 feature level". Do not read root v0.7.1 as the library's version; the consumer version plane is the nested train below |
| .../go-etag/entitytag | Indirect v0.6.1 (via httpx v0.2.0 and httputil v1.8.0) | Parsed only inside the server middleware when it runs; template never imports it | entitytag/v0.6.2 | Zero-dependency RFC 7232 §2.3 domain type; v0.6.2 is a test-suite re-tag, no API change |
| .../go-etag/server | Indirect v0.6.1 (via httpx v0.2.0 direct require; also via httputil v1.8.0) | httpx.Conditional wraps `etagserver.New` (appkit httpx/conditional.go:9,:71); httputil maps its error codes (httputil/errors.go:110-122); never applied at runtime by template or preset | server/v0.6.2 | The real version plane for consumers; v0.6.2 adds the errorfamily v0.12.0 bump (already satisfied in the template's graph) and an internal file split |
| .../go-etag/client | No | No outbound HTTP in the archetype | client/v0.6.2 | RFC 9111 conditional-GET cache transport; adopter story only |
| .../go-etag/metrics | No | Nothing to count | metrics/v0.6.2 | Counters companion for the server hooks; becomes relevant only if conditional wiring lands |
