# httputil utilization review (go-service-template)

| Reviewed | 2026-11-23 |
|---|---|
| Library | github.com/larsartmann/httputil (+ submodules server_timing, endpoints) |
| Version audited | v1.9.0-24-g34dbf05 (34dbf05, 2026-11-21) |
| Template pin | httputil v1.8.0 + server_timing v1.0.3, both indirect via the go-appkit chain; endpoints absent from the graph |
| Latest tag | v1.9.0 (root) / server_timing v1.0.3 / endpoints v0.1.0 (new submodule, 2026-11-06) |
| Adoption score | 50/100 (moderate), 8.5 of 17 applicable capabilities leveraged |
| Verdict | The always-on spine the preset builds on httputil is superb and live-verified; roughly half the surface (compression, body limits, rate limiting, CSRF, sub-phase timings, /endpoints) is unwired anywhere in the appkit chain, and the right fix for almost all of it is preset legs, not template code. |

## Verdict

Used superbly at the one layer an archetype should use it: the template imports httputil zero times, yet every adopter gets the full appkit default stack built from it (Server-Timing, Recovery, RequestID, Logging, Timeout, SecurityHeaders, the delegated server loop with graceful drain), verified live by booting the template and reading response headers. "Max" here does not mean importing more httputil in the template's 7 files; it means the preset wiring more of the library's production surface on behalf of all adopters. The concrete max-gap is response compression: nothing in the entire go-appkit chain wires `httputil.Compression`, so every adopter's JSON and HTML ships uncompressed, and the notable v1.9.0 correctness fix (Content-Type sniffing under compression, issue #49) cannot even reach the template because the feature is absent upstream of it. Secondary gaps: no middleware passthrough or Server-Timing switch on `preset.Config`, and the brand-new `/endpoints` listing whose correct home is the preset (a template-local registry would under-report the preset's own mounted routes).

## What the template uses today

The repo has exactly ONE go.mod (`github.com/example/go-service-template`, go 1.27.4), no submodules, so all httputil presence is through the go-appkit chain: go.mod:119-120 (indirect block, via `go-appkit v0.12.0`, `preset v0.1.1`, `security v0.2.0`, `otel v0.4.0`, and their go.sum entries at go.sum:333-336).

- PRESET-MEDIATED, middleware spine: `defaultMiddlewareStack` builds ServerTiming → Recovery → RequestID → Logging → [Timeout unless NoTimeout] → SecurityHeaders from httputil constructors (/home/lars/projects/go-appkit/middleware.go:32-46, imports at :6-7).
- PRESET-MEDIATED, W3C Server-Timing on by default: `servertiming.ServerTimingMiddleware()` outermost, nil `ServerTiming` config means on (/home/lars/projects/go-appkit/middleware.go:32-34, config.go:88-99, default `&t` at config.go:195). Live-verified: `curl -D -` on the booted template returns `Server-Timing: total;desc="Total request";dur=0.099577` on both `/api/status` and `/readyz`, alongside `X-Request-Id` and the security headers.
- PRESET-MEDIATED, request logging and request IDs: `httputil.Logging(logger)` and `httputil.RequestID(DefaultRequestIDConfig())` (middleware.go:38-39); the live request log line carries method/path/status/duration/client_ip/request_id.
- PRESET-MEDIATED, server lifecycle and graceful drain: `httputil.ServerConfig` timeouts mapping and `httputil.NewServerListener` own the serve loop; appkit binds and classifies (/home/lars/projects/go-appkit/service.go:122-131 and :156, single-serve ownership honored via fresh `activeServe` per start, service.go:19-32).
- PRESET-MEDIATED, middleware composition: `httputil.Chain(mux, mws...)` (service.go:111) over `[]httputil.Middleware` config seams `Middlewares`/`ExtraMiddlewares`/`OuterMiddlewares` (config.go:75-86); the otel leg injects `appkitotel.Middleware()` as an outer middleware (preset/preset.go:91-93, otel/middleware.go:122).
- PRESET-MEDIATED, panic recovery plus the OnPanic observability hook: base `httputil.Recovery` on the stack (middleware.go:37); when `APPKIT_OTEL=on`, `appkitotel.Recovery` delegates to `httputil.RecoveryWithConfig` with an `OnPanic` hook that records span exception events (otel/exceptions.go:38-47).
- PRESET-MEDIATED, health handlers: `httputil.HealthHandler/LiveHandler/ReadyHandlerWithProbe` wire the core `/health` family with the drain probe (service.go:80-84). With the default preset the dashboard owns `/health` so the core family is disabled (preset.go:88-89) and `/healthz` `/readyz` `/startupz` come from go-health; live `/readyz` returned the go-health `{"status":"pass",...}` vocabulary.
- PRESET-MEDIATED, opt-in security leg (`APPKIT_SECURITY=none` by default, preset README grammar :32): `security.SecurityHeaders` delegates to `httputil.SecurityHeaders` with a Production HSTS tier (security/headers.go:38-56) plus `BodyLimit` and `OriginCheck` (preset/security.go:41-52). Note `BodyLimit` calls `http.MaxBytesReader` directly, not `httputil.MaxBodySize` (security/bodylimit.go:21).
- AVAILABLE-BUT-UNWIRED in appkit modules (not preset legs): `security.CSRF` wraps `httputil.CSRFMiddleware` (security/csrf.go:25,38), `security.RateLimit` wraps `httputil.KeyedRateLimiterMiddleware` (security/ratelimit.go:105-106), flightrecorder wraps writers in `httputil.NewResponseRecorder` (flightrecorder/middleware.go:100).
- GRAPH-ONLY from the template's own perspective: zero `httputil` references in the template's 7 source files (`grep -rn 'httputil' --include='*.go' .` returns nothing); internal/api/routes.go:25-29 uses `httpx.ResultHandler`, and go-appkit/httpx itself has no httputil dependency.
- ABSENT: `endpoints` submodule (not in go.mod or go.sum); no appkit module imports it (grep over /home/lars/projects/go-appkit found zero non-go.mod references).

## Capability inventory

| Capability | Status | Evidence | Note |
|---|---|---|---|
| Middleware composition core (Chain, Compose, MiddlewareStack, MiddlewareFunc.Then) | Fully leveraged | appkit service.go:111, config.go:75-86, otel/middleware.go:122 | The spine's assembly mechanism; README.md:124-136, 808-822 |
| Panic recovery + OnPanic hook (Recovery/RecoveryWithConfig) | Fully leveraged | appkit middleware.go:37; otel leg exceptions.go:38-47 | Hook feeds otel exception events when `APPKIT_OTEL=on` |
| Request ID propagation (RequestID, RequestIDFromContext) | Fully leveraged | appkit middleware.go:38; live `X-Request-Id` header observed | Incoming-header echo plus time-ordered generation |
| Structured request logging (Logging, LoggingFromContext) | Fully leveraged | appkit middleware.go:39; live request log line | `LoggingFromContext` (per-request logger scoping) unwired; appkit's LogHandler seam covers the custom-backend need instead |
| Request timeout enforcement (Timeout) | Fully leveraged | appkit middleware.go:42-43 | Correctly omitted for `WriteTimeout = NoTimeout` SSE streams |
| Security headers (SecurityHeaders, HSTS/CSP tiers) | Partially used | appkit middleware.go:46 (dev-tier defaults always on); Production tier only behind opt-in `APPKIT_SECURITY` (preset/security.go:41-48, default `none` per preset README :32) | Default posture ships nosniff/X-Frame-Options/Referrer-Policy but no HSTS and no CSP; one env flip upgrades |
| HTTP server lifecycle (NewServerListener, ServerConfig, graceful drain, ListenerAddr) | Fully leveraged | appkit service.go:122-131, :156 | v1.7.0 listener-injection seam is the preset's drain backbone |
| Standard health handlers (HealthHandler, LiveHandler, ReadyHandlerWithProbe, RegisterHealth) | Partially used | appkit service.go:80-84; preset.go:88-89 disables them when the dashboard mounts | Spine seam plus deliberate dashboard substitution; NoDashboard mode uses them fully |
| Server-Timing auto total (server_timing middleware) | Fully leveraged | appkit middleware.go:32-34; live header on every response verified | On by default, outermost, SSE-safe (stamp-on-commit) |
| Server-Timing sub-phases (MeasureServerTiming, RecordServerTiming, ServerTimingFromContext) | Missed opportunity | Zero runtime callers in appkit (only the doc comment middleware.go:16-23); template handlers none | Handler-side capability; header carries only `total` today |
| Response compression (Compression, WriterFactory plugins) | Missed opportunity | No wiring anywhere in go-appkit (`rg Compression` hits only flightrecorder snapshot gzip) | Every adopter ships uncompressed; v1.9.0 issue #49 sniff fix unreachable until wired |
| Request body limits + decompression (MaxBodySize, Decompression bomb guard) | Missed opportunity | appkit reimplemented limiting with raw `http.MaxBytesReader` (security/bodylimit.go:21), opt-in leg only; Decompression unwired | Compressed request bodies unhandled chain-wide |
| Keyed rate limiting + trusted-proxy keying | Missed opportunity | Wrapped in appkit/security (ratelimit.go:38, 105-106) but no preset leg; template default has none | Adopter-specific values (limit, CIDRs) argue for a preset leg with env grammar, not template code |
| CSRF protection (nosurf, HTMX helpers, QUERY safe-listing) | Missed opportunity | Wrapped in appkit/security (csrf.go:25,38), no preset leg | Template is browser-facing (views/) but has no state-changing routes; matters the moment adopters add POSTs |
| CORS middleware | Not applicable | Not wired in appkit or template | Same-origin archetype (JSON API + templ page on one origin); a permissive CORS default would be a security regression, cross-origin needs are deployment-specific |
| Content-language negotiation (Language) | Partially used | Not wired in appkit or template; httputil ROADMAP.md:45 records the appkit i18n lane as parked pending real demand (N=1 consumer at ruling time) | Deliberate exclusion with library-side ruling; revisit only when a real locale requirement exists |
| /endpoints self-describing listing (endpoints submodule) | Missed opportunity | Absent from graph; endpoints/v0.1.0 is 17 days old; first consumer is the CV repo (endpoints/README.md:97) | Analysis and routing in Gaps #3 |
| Error classification surface (CodeOf, DomainOf, InDomain, sentinels, RegisterErrorClassifications) | Partially used | Families/codes flow through appkit re-exports (errors.go:33-44) and error pages; `httputil.RegisterErrorClassifications()` has zero callers in the chain (grep over both repos) | The what/why/fix/escape message templates (README.md:763-799) never get registered, so error pages cannot render them for httputil-origin errors |
| Testing utilities (httpspec suite, ExpectNotModifiedDynamic) | Missed opportunity | appkit runs httpspec on its own surface (httpspec_test.go at appkit root); template's routes_test.go uses none; no testkit re-export | Would require a direct httputil require for one example handler |

## Gaps and opportunities

Ranked by impact × ease.

1. **[PRESET-UPSTREAM] Wire response compression as a preset leg.** The library offers negotiated gzip/deflate with a 512-byte floor, incompressible-type deny-list, and pluggable WriterFactory encodings (README.md:266-288, 851-865); v1.9.0 fixed Content-Type stripping under compression (CHANGELOG.md:48, issue #49, first hit live in quotaboard). The template does nothing instead, because nothing upstream of it wires the middleware (grep: no `httputil.Compression` in go-appkit). Impact: every adopter's JSON/HTML/templ responses ship uncompressed; the correctness fix also stays unreachable. Sketch (go-appkit preset):
   ```go
   // preset/compression.go
   func compressionMiddleware() ([]httputil.Middleware, error) {
       cfg := httputil.DefaultCompressionConfig() // gzip+deflate, MinSize 512
       return []httputil.Middleware{httputil.Compression(cfg)}, nil
   }
   // preset.go, after applySecurity: legs.hasCompression -> svcConfig.ExtraMiddlewares
   ```
   with an `APPKIT_COMPRESSION=on|off` grammar row (default on; opt-out mirrors APPKIT_ERRORPAGES). Consider folding request Decompression into the same leg later, it is the natural companion (bomb guard, README.md:288-309).
2. **[PRESET-UPSTREAM] Expose middleware passthrough and a Server-Timing switch on preset.Config.** Today `preset.Config` (preset/config.go:30-73) has no `ExtraMiddlewares`, no `Middlewares`, and no `ServerTiming` field, so a preset consumer cannot add rate limiting, CSRF, or compression, nor turn Server-Timing off, without abandoning the preset for core `appkit.NewService` (core seams exist at config.go:75-99). Impact: the preset's thinness currently blocks every other gap here; this one field unblocks adopters incrementally. Sketch: add `ExtraMiddlewares []httputil.Middleware` and `ServerTiming *bool` to preset.Config, map them in preset.go's `svcConfig` literal (two lines).
3. **[PRESET-UPSTREAM, preconditioned] Route the /endpoints listing through the preset, not the template.** VERIFIED SHAPE: endpoints is NOT typed endpoint registration; it is a `Registry` (`Handle`/`HandleFunc` mount a handler on the mux AND record `Route{Method, Pattern, Summary}`) plus a content-negotiated `GET /endpoints` listing (JSON default, HTML for browsers, never 406s, `Vary: Accept` + `Cache-Control: no-store`, 405 otherwise), stdlib-only with zero dependencies (endpoints/doc.go, endpoints.go:16-191, README.md:7-11). `httpx.ResultHandler` already owns the handler ergonomics (return-(T, error), routes.go:25-29) and composes unchanged, since `ResultHandler` returns an `http.Handler` that `Registry.Handle` accepts. What endpoints adds for adopters' real services: wiring errors as values (duplicate/malformed pattern becomes a classified error instead of a mux panic, endpoints.go:111-143) and a drift-free self-description of the attack surface. Why preset, not template: the preset mounts `/health` (dashboard), `/version`, `/events`, and the error-pages catch-all on `svc.Mux` inside `preset.New` (preset.go:88-122); a template-local registry would list only `api` + `views` and silently omit those, breaking the module's own cannot-drift premise. Sketch of the end state:
   ```go
   // go-appkit preset: create the registry, route every preset mount through it
   routes := endpoints.NewRegistry()
   svcConfig.Endpoints = routes // out-field, mirroring the realtime hub pattern
   // routes.Handle(mux, "GET /version", versionHandler(v), "Build version") etc.

   // template internal/api/routes.go in the new shape:
   func Register(mux *http.ServeMux, routes *endpoints.Registry, deps Deps) error {
       return routes.Handle(mux, "GET /api/status", httpx.ResultHandler(
           func(_ *httpx.Context) (*statusResponse, error) {
               return &statusResponse{Status: "ok", Version: deps.Version}, nil
           }), "Service status and build version")
   }
   ```
   Preconditions that make this "next train", not "today": (a) the multi-Accept-header-line negotiation fix is UNRELEASED, commit b785f40, CHANGELOG.md:21-32, so tagged endpoints/v0.1.0 still negotiates the first line only, wait for the v0.2 cut; (b) per-route hiding for admin-only routes is on the v0.2 candidate batch (ROADMAP.md:47) and the README's own security note says to mount deliberately on internet-facing services (endpoints/README.md:85-88), so the preset should gate it behind an env leg or hide-by-default, exactly the dashboard/metrics posture it already uses.
4. **[PRESET-UPSTREAM] Register httputil's error templates in the chain.** `appkit.RegisterClassifications()` (called at preset.go:102) registers stdlib defaults plus `*http.MaxBytesError` only (errors.go:28-31). Adding the one-liner `httputil.RegisterErrorClassifications()` there (httputil is already a direct dep of appkit root, go.mod:8) lights up user-facing what/why/fix/escape templates for every httputil-origin code (README.md:798), which the error-pages leg could render for CSRF/rate-limit rejections once those legs exist. Low impact, trivial ease.
5. **[NOT-NOW + reason] Server-Timing sub-phases in template handlers.** The seam is real and preset-owned (`servertiming.MeasureServerTiming(r.Context(), "db")`, appkit middleware.go:16-23), but the archetype's example handler performs no measurable work; a synthetic phase would teach cargo-cult instrumentation. Belongs in a docs snippet and in real adopter handlers doing I/O.
6. **[NOT-NOW + reason] httpspec in the template's routes_test.go.** The behavioral suite (19 specs, README.md:138-163) is a strong adopter pattern, but wiring it into the template adds a direct httputil require for one trivial handler, against the thin-composition-root posture; appkit already runs httpspec over its own surface (appkit httpspec_test.go). Better as a documented snippet, or a future appkit testkit re-export so adopters get it without a new dep edge.
7. **[NOT-NOW + reason] CSRF and rate limiting at template level.** Adopter-specific by nature (origins, limits, trusted proxies); the appkit security module already wraps both correctly (csrf.go:25-38, ratelimit.go:105-106 with the trusted-CIDR key extractor available). Gap #2 (ExtraMiddlewares passthrough) is the unlock; the values never belonged in an archetype.

## Should the archetype adopt or wire more?

Default binary: nothing. The template's 30-line routes.go should keep importing only `go-appkit/httpx`; every httputil capability an archetype needs unconditionally (recovery, IDs, logging, timeout, headers, timing total, drain) is already preset-mediated, and template-local middleware wiring would duplicate what the preset could own, a finding against the template per the brief's bias. Docs/examples: three snippets earn their place, the `MeasureServerTiming` sub-phase recipe (with the record-before-first-write caveat), an endpoints/routes.go sketch like Gap #3 for adopters who want the listing before the preset train, and an httpspec snippet for real services. Build-tag-gate pattern: if the owner wants template visibility for `/endpoints` ahead of the preset, a `//go:build endpoints` skeleton mirroring internal/events/events.go is the right shape, default-off both for weight and because a template-local registry under-reports the preset's own mounts. Must stay out: CSRF, rate limiting, CORS, Language, compression config, all adopter-specific or preset-owned; nothing here justifies per-adopter divergence from the fleet default.

## Version currency

- Root httputil: pin v1.8.0 indirect (go.mod:119, via `go-appkit v0.12.0` / `preset v0.1.1` / `security v0.2.0` / `otel v0.4.0`), latest tag v1.9.0, HEAD 24 commits past it. The v1.8.0→v1.9.0 gap (CHANGELOG.md:34-58): Pusher delegation through the writer wrappers (#47, relevant to ResponseRecorder consumers like flightrecorder, which the preset does not wire), `KeyedRateLimiterConfig.Now` clock injection (#45, rate limiting unwired), `httpspec.ExpectNotModifiedDynamic` (#46, test-only), the Compression Content-Type sniff fix (#49, Compression unwired), CSRF QUERY safe-listing (#48, behavior change, CSRF unwired), plus CI/docs work. Verdict: nothing in the gap changes the template's default binary behavior; the bump is appkit's to make and rides the next preset train. appkit's integration module already pins v1.9.0 (integration/go.mod:36), so the upstream bump is in flight. [Unreleased] at HEAD (CHANGELOG.md:7-32): go1.27.4 toolchain pins for GO-2026-6859 / CVE-2026-97054 (an `http.MaxBytesReader` HTTP/1 crash; guidance: build on go1.27.4+), and the endpoints multi-Accept-line fix (commit b785f40). The template already declares `go 1.27.4` (go.mod:3), which is the actual mitigation; note the exposed code path in the chain is appkit's own `BodyLimit` (security/bodylimit.go:21), not httputil's `MaxBodySize`, and the fix is toolchain-level, not version-level.
- server_timing: pin v1.0.3 (go.mod:120) equals the latest tag, current; `git diff v1.9.0..HEAD --stat` shows no server_timing changes at HEAD.
- endpoints: absent from the graph; latest tag endpoints/v0.1.0 (2026-11-06). If adopted before the next tag, the pin would miss the unreleased Accept-lines fix, one more reason to wait for the v0.2 cut (Gap #3 preconditions).

## Risks

- Server-Timing is on for every response of every adopter by default and `preset.Config` exposes no off-switch (preset/config.go:30-73; core seam exists at appkit config.go:99). Exposure is only coarse durations (W3C-standard practice, DevTools/APM consumption), but security-conscious internet deployments have no env knob today (Gap #2). The health dashboard does not consume or display the header, that was explicitly declined upstream (go-health-dashboard archived decision 2026-08-09: "not worth a dependency, dashboard already displays latency").
- endpoints/v0.1.0: the tagged release negotiates `Accept` on the first header line only (fix unreleased at HEAD), and it has no per-route hiding yet, so a default-on internet-facing mount would publish the full attack surface (endpoints/README.md:85-88, ROADMAP.md:47). Both are Preconditions in Gap #3, not adopt-now blockers for internal services.
- `httputil.ClientIP` trusts `X-Forwarded-For`/`X-Real-IP` verbatim (README.md:92); harmless today (unwired in the chain except inside Logging's log line), a footgun if adopters hand-roll keying behind an appending proxy, the library ships `KeyExtractorFromTrustedClientIP`/`ParseTrustedProxies` for exactly that (README.md:497-517).
- GO-2026-6859 / CVE-2026-97054 (`http.MaxBytesReader` HTTP/1 crash): applies to appkit's BodyLimit path via the build toolchain; the template's `go 1.27.4` directive (go.mod:3) is the floor that fixes it, verified against httputil's [Unreleased] guidance (CHANGELOG.md:11-19).
- No misuse found in the template: zero httputil imports means zero template-side misuse surface; the deprecated/none list was checked against the README API table (README.md:572-644) and the v1-stability frozen-surface docs. Nothing verified as deprecated in the pinned surface.

## How to verify

```bash
# Version facts
git -C /home/lars/projects/httputil describe --tags          # v1.9.0-24-g34dbf05
git -C /home/lars/projects/httputil log -1 --format='%h %ci' # 34dbf05 2026-11-21...
git -C /home/lars/projects/httputil tag -l 'server_timing/*' 'endpoints/*'
grep -n 'larsartmann/httputil' /home/lars/projects/go-service-template/go.mod   # :119 v1.8.0, :120 server_timing v1.0.3, both // indirect
grep -c 'httputil/endpoints' /home/lars/projects/go-service-template/go.mod || true    # 0 (absent)

# Template-side usage is zero (graph-only)
grep -rn 'httputil' --include='*.go' /home/lars/projects/go-service-template | wc -l   # 0

# Preset-mediated spine (appkit repo)
grep -n 'httputil\.\|servertiming\.' /home/lars/projects/go-appkit/middleware.go        # stack lines 32-46
grep -n 'NewServerListener\|httputil.Chain\|ServerConfig{' /home/lars/projects/go-appkit/service.go
grep -n 'ServerTiming' /home/lars/projects/go-appkit/config.go                           # :88-99, :195
grep -rn 'MaxBytesReader' /home/lars/projects/go-appkit/security/bodylimit.go            # :21 (own impl, not httputil.MaxBodySize)
grep -rn 'RegisterErrorClassifications' /home/lars/projects/go-appkit --include='*.go' | wc -l   # 0 (templates unregistered in code)
grep -rn 'httputil.Compression\|httputil.Decompression' /home/lars/projects/go-appkit --include='*.go' | wc -l  # 0 (unwired)
grep -rn 'MeasureServerTiming' /home/lars/projects/go-appkit --include='*.go' | wc -l    # 1 (doc comment only)

# Server-Timing live check on the booted template
cd /home/lars/projects/go-service-template && APP_ADDR=:18099 timeout 15 go run ./cmd/app serve >/tmp/verify.log 2>&1 & sleep 7; curl -s -D - -o /dev/null http://127.0.0.1:18099/api/status | grep -i '^server-timing'
# -> Server-Timing: total;desc="Total request";dur=...

# Unreleased endpoints fix exists only at HEAD
git -C /home/lars/projects/httputil log --oneline v1.9.0..HEAD -- endpoints/ | head -3   # b785f40 fix: negotiate ... all Accept header lines
```

## Submodule matrix

| Module path | In template graph | How used | Latest tag | Note |
|---|---|---|---|---|
| github.com/larsartmann/httputil | Yes (indirect, go.mod:119) | Preset-mediated spine: default middleware stack, server lifecycle/drain, health handler family, security-header delegation | v1.9.0 | Pin v1.8.0 is drift with zero runtime effect on the template's default binary; rides next appkit train |
| github.com/larsartmann/httputil/server_timing | Yes (indirect, go.mod:120) | Outermost middleware of the appkit default stack, on by default; auto `total` metric only | v1.0.3 | Current; sub-phase API (Measure/Record/FromContext) has zero callers chain-wide |
| github.com/larsartmann/httputil/endpoints | No | Absent; brand-new submodule (2026-11-06), first consumer is the CV repo | endpoints/v0.1.0 | PRESET-UPSTREAM candidate after v0.2 (per-route hiding, unreleased Accept-lines fix); template-local wiring would under-report preset mounts |
| github.com/larsartmann/httputil/testdata/otelinterop | No | Fixture module proving the otel interop docs compile against real SDK middlewares; "nothing here ships to consumers" (its go.mod comment) | none (never tagged) | Not a distribution surface; excluded from capability scoring |
