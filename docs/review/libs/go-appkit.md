# go-appkit — utilization review (go-service-template)

| Reviewed | 2026-11-23 |
|---|---|
| Library | github.com/larsartmann/go-appkit (+ submodules) |
| Version audited | cqrs/v0.10.0-7-g74e4d80 (74e4d80, 2026-11-23 02:57 +0100) |
| Template pin | core v0.12.0, preset v0.1.1, cqrs v0.9.0, httpx v0.2.0, config v0.1.1 (all direct); errorpages v0.1.3, health v0.3.2, otel v0.4.0, realtime v0.2.0, security v0.2.0, systemd v0.2.0 (indirect via preset) |
| Latest tag | core v0.13.0, cqrs v0.10.0, security v0.3.0 (drift); preset v0.1.1, httpx v0.2.0, config v0.1.1, errorpages v0.1.3, health v0.3.2, otel v0.4.0, realtime v0.2.0, systemd v0.2.0 (current) |
| Adoption score | 53/100 (moderate) — 9 of 17 applicable capabilities leveraged |
| Verdict | Canonical preset consumer in shape, drifted in pins and thin in test/doc posture; one refresh train plus a few lines of docs separate it from max. |

## Verdict

Used SUPERBLY in shape: the composition root (`internal/app/service.go:47-64`) is byte-for-byte the documented canonical pattern (preset README quick start `preset/README.md:49-65`, root README "Start here" `README.md:115-128`, `preset/example/main.go:21-40`), and the template duplicates none of the framework. It is NOT used to the max on three axes: the pins lag two released trains (core v0.12.0 vs v0.13.0, cqrs v0.9.0 vs v0.10.0, security v0.2.0 vs v0.3.0), the route test bypasses the middleware chain through a raw mux even though the framework's own doctrine says that class of test "misses the bugs" (`README.md:230-236`, testkit), and two advertised env legs carry undocumented sharp edges found in this audit (APPKIT_SECURITY=strict silently degrades to standard; APPKIT_REALTIME=on with default `WriteTimeout: 30s` kills streams at 30s). "Max" for this archetype means: run the refresh ritual onto core v0.13.0 + cqrs v0.10.0, add one testkit full-chain test, and document the leg caveats; everything heavier (flightrecorder, docs module, cqrs in the default binary) correctly stays out.

## What the template uses today

- **Preset one-call composition** (TEMPLATE-DIRECT): `appkitpreset.New(appkitpreset.Config{Addr, LogLevel, Version})` + `defer svc.Close()` + routes on `svc.Mux` + `svc.Run(ctx)` (`/home/lars/projects/go-service-template/internal/app/service.go:48-64`). Matches the preset README quick start, the root README "Start here" recipe, and `preset/example/main.go`; the `defer svc.Close()` matches the core README quick start (`go-appkit/README.md:47`).
- **Env-first typed config** (TEMPLATE-DIRECT): `config.Load[Config]()` over `Addr`/`LogLevel` tags (`internal/app/service.go:31-41`); the shape is literally the config module's canonical example (`go-appkit/config/README.md:20-26`, same field names, same `APP_ADDR`/`APP_LOG_LEVEL` keys).
- **Core lifecycle** (TEMPLATE-DIRECT): `appkit.LogLevel` conversion (`internal/app/service.go:12,50`), `svc.Run(ctx)` blocking on signals (`:64`); five-phase drain and hook execution are core-owned (`go-appkit/README.md:390-411`).
- **httpx return-(T, error)** (TEMPLATE-DIRECT): one `httpx.ResultHandler` GET (`internal/api/routes.go:25-29`).
- **cqrs event service** (TEMPLATE-DIRECT, but build-tag gated, not wired into `Serve`): `cqrs.NewEventService(cqrs.EventConfig{DSN, DLQ})` (`internal/events/events.go:1,31-34`).
- **Health probe + real-time dashboard** (PRESET-MEDIATED): `health.NewProbe` + `health.Mount(..., WithDashboard())` (`go-appkit/preset/preset.go:109-114`, dashboard opts `:232-238`); dashboard owns `/health` + `/healthz` `/readyz` `/startupz` (`preset/README.md:9-15`).
- **Pretty error pages** (PRESET-MEDIATED): `errorpages.Mount` behind the env opt-out (`go-appkit/preset/preset.go:116-118,242-249`).
- **systemd sd_notify** (PRESET-MEDIATED): `systemd.Install(&svcConfig)` always on the spine (`go-appkit/preset/preset.go:101`); pairs with the template's shipped unit (`systemd/app.service`, `AGENTS.md:80-85`).
- **Fleet error classifications** (PRESET-MEDIATED): `appkit.RegisterClassifications()` called by the preset (`go-appkit/preset/preset.go:102`), so the template correctly does not duplicate it.
- **Version stamp** (TEMPLATE-DIRECT): `Version` passed to preset (`internal/app/service.go:51`), ldflags-stamped from the flake (`AGENTS.md:76-78`), serving `GET /version` + `appkit_build_info`.
- **OTel leg** (PRESET-MEDIATED, OFF by default): provider Setup + outermost middleware + shutdown flush only when `APPKIT_OTEL=on` (`go-appkit/preset/preset.go:42,91-93,169-175`; `preset/env.go:12,74-80`). Absent env means off.
- **Security leg** (PRESET-MEDIATED, `none` by default): `SecurityHeaders(Production)` + `BodyLimit(1 MiB)` when standard, `+OriginCheck` when strict via code (`go-appkit/preset/preset.go:95-99`, `preset/security.go:11-53`). See Risks: env-driven strict degrades.
- **Realtime SSE leg** (PRESET-MEDIATED, OFF by default): hub mounted at `GET /events`, drained in DrainHooks (`go-appkit/preset/preset.go:120-122,194-214,154-164`).
- **testkit / httpx bind+validation / conditional GET / negotiation / metrics surface / flightrecorder / flightrecorderhealth / docs module** (ABSENT): not imported anywhere in the template's 7 files. `go-flightrecorder v0.2.1` appears in the indirect block (`go.mod:100`) only as a transitive dep of cqrs/dashboard; the appkit `flightrecorder` wrapper modules are not in the graph at all. Graph presence with zero wiring is not usage.

## Capability inventory

| Capability | Status | Evidence | Note |
|---|---|---|---|
| One-call preset composition root | Fully leveraged | `internal/app/service.go:48-52`; `preset/README.md:49-65` | Canonical shape incl. error handling on `New` |
| Core lifecycle (Run/Close, 5-phase graceful drain, signals) | Fully leveraged | `internal/app/service.go:56,64`; `go-appkit/README.md:390-411` | Signal handling deliberately left to core (`AGENTS.md:113-114`) |
| Lifecycle hook passthrough (consumer-first Start/Drain/Shutdown) | Partially used | `preset/config.go:64-66`, `preset/preset.go:72-82`; template passes zero hooks, referenced only in comment `internal/events/events.go:16` | Plumbing verified real; the one skeleton that should use it (cqrs Shutdown) does not sketch it |
| config module env-first typed loading | Fully leveraged | `internal/app/service.go:31-41`; `config/README.md:20-26` | Template Config IS the module's canonical example |
| httpx ResultHandler classified no-leak error contract | Fully leveraged | `internal/api/routes.go:25-29`; `httpx/README.md:24-58` | Parity with errorpages taxonomy pinned upstream |
| httpx bind + validation (`ResultHandlerWithValidation`) | Missed opportunity | `httpx/result.go:58`, `httpx/README.md:33-58`; unused in template | A POST example would teach the second-most common handler shape |
| httpx advanced batteries (Conditional/ETag, Negotiate, WriteDeadline, httpxtest) | Missed opportunity | `httpx/conditional.go:62`, `httpx/negotiate.go:35`, `httpx/writedeadline.go:38`, `httpx/httpxtest/assert.go:94` | Zero references; a README pointer would suffice for an archetype |
| Health probes + real-time dashboard | Fully leveraged | `preset/preset.go:109-114`; probed 200s per `FEATURES.md:39-40` | HTML + JSON + SSE views; `/readyz` flips 503 during drain |
| Pretty error pages spine | Fully leveraged | `preset/preset.go:116-118`; opt-out documented `README.md:78` (template) | Env opt-out `APPKIT_ERRORPAGES=off` |
| sd_notify spine (systemd module) | Fully leveraged | `preset/preset.go:101`; unit shipped `systemd/app.service` | No-op outside systemd, correct for containers |
| OTel leg (`APPKIT_OTEL`) | Partially used | `preset/preset.go:42,91-93`; `FEATURES.md:44` DISABLED | Documented, never exercised; needs OTLP endpoint the template ships without (fine) |
| Security leg (`APPKIT_SECURITY`) | Missed opportunity | `preset/security.go:11-53`; template `README.md:79-80` documents values but no posture recommendation | Standard (headers + 1 MiB body limit) suits every deploy; nothing recommends it; env-strict is broken upstream (Risks) |
| Realtime SSE leg (`APPKIT_REALTIME`) | Partially used | `preset/preset.go:120-122,154-164`; `FEATURES.md:43` | Off-by-default is right for an archetype; the 30s WriteTimeout interaction is undocumented anywhere the template points to |
| cqrs event-sourcing skeleton | Partially used | `internal/events/events.go:30-40` | Build-tag gate is the right pattern; skeleton comment drifts from its own signature and skips Logger/ReadyCheck/Shutdown wiring |
| Metrics surface (`MetricsConfig` passthrough) | Missed opportunity | `preset/config.go:41-43`, `go-appkit/README.md:203-262` | Nil-disabled in template, and never mentioned in template README/FEATURES |
| testkit full-chain testing | Missed opportunity | `go-appkit/testkit/testkit.go:102,136`; template test `internal/api/routes_test.go:15-16` uses raw mux + `httptest` | Core README: "Never `httptest.NewServer(svc.Mux)`... raw-mux tests miss the bugs" (`README.md:230-236`) |
| Core v0.13.0 seams (`Listener` injection, `LogHandler`) | Missed opportunity | `go-appkit/CHANGELOG.md:11-34`, `README.md:285-319` | Absent only because the pin is v0.12.0; inherited on the refresh train |
| flightrecorder / flightrecorderhealth modules | Not applicable | Not in graph; not preset-wired | N/A reason: on-demand trace capture is ops weight, one active recorder per process (`flightrecorder/README.md:15-17`), and the preset does not mediate it; adopter-specific |
| docs module (OpenAPI/AsyncAPI/D2) | Not applicable | `go-appkit/docs/README.md:1-5`; not in graph | N/A reason: needs a registered command/event catalog; a domainless archetype deliberately has nothing to document (natural companion of the events skeleton) |

## Gaps and opportunities

1. **Version refresh train (highest impact, ritual exists).** cqrs v0.10.0 ships the sqliteengine `EnforceCap` deadlock fix (concurrent cap enforcement could deadlock the journal writer) and the SSE reconnect-cursor hardening (malformed Last-Event-ID now answers 400 instead of silently replaying the whole journal), plus the `system.Standard` three-tier default topology (`go-appkit/cqrs/CHANGELOG.md:5-31`). core v0.13.0 adds the Listener-injection seam and the LogHandler seam (`go-appkit/CHANGELOG.md:11-34`). Template instead pins v0.9.0/v0.12.0 (`go.mod:8,10`). Impact: high (real deadlock fix on the path every events-skeleton adopter takes). Sketch: run the template's own ritual, bump `go.mod` + the AGENTS.md stamp table + re-run the dogfood probe (build, boot, `/healthz` + `/api/status`, SIGTERM graceful-stop). `[TEMPLATE]`
2. **`APPKIT_SECURITY=strict` via env silently degrades to standard.** `resolveLegs` records strict (`preset/env.go:98-102`) but `applySecurity` is handed `cfg.Security` (nil when env-driven), and `securityMiddlewares(nil)` defaults the profile to Standard (`preset/preset.go:95-99`, `preset/security.go:24-32`): the consumer gets headers + body limit, never OriginCheck, and never the documented boot rejection (`preset/README.md:44-45`). No test pins env-strict end-to-end (only `resolveLegs` unit tests, `preset/env_test.go:42`; all composition tests go through code config, `preset/security_test.go:145-191`). Impact: security-relevant false assurance for every env-driven consumer. Fix: pass the resolved `legs.security` into the middleware resolution and reject strict-without-origins at `New`. `[LIB-UPSTREAM]`
3. **No full-chain test (testkit).** The framework's testing doctrine is explicit: `testkit.NewService(t, cfg)` + `testkit.Serve(t, svc)` boots the REAL chain with leak-checked teardown; the README documents three production bugs only visible through the full chain (`go-appkit/README.md:230-248`). Template instead tests a bare mux (`internal/api/routes_test.go:15-16`). Impact: the archetype's example test teaches adopters the wrong pattern. Sketch:
   ```go
   svc := testkit.NewService(t, appkit.ServiceConfig{Version: "test"})
   testkit.Serve(t, svc)
   api.Register(svc.Mux, api.Deps{Version: "test"})
   resp := testkit.HTTPGetURL(t, "http://"+svc.Addr().String()+"/api/status")
   ```
   Zero new pins (testkit is a sub-package of the already-direct root module). `[TEMPLATE]`
4. **No recommended security posture.** README documents the values (`README.md:79-80`) but never says "run standard in production". The preset's standard profile is documented as the production posture (`preset/README.md:42-43`). Impact: every cloned service ships with `none` and no nudge. Sketch: `Environment=APPKIT_SECURITY=standard` with a comment in `systemd/app.service` (env semantics stay overridable per deploy; note HSTS rides the Production tier, flag for TLS-terminating proxies) plus one README line. Do NOT hard-code `Config.Security{...}` in Go: explicit code wins over env in both directions and would freeze the leg. `[TEMPLATE]`
5. **Events skeleton comment drift + missing wiring sketch.** Package doc promises `events.New(cfg.LogLevel)` (`internal/events/events.go:11`) but the real signature is `New(_ context.Context)` (`:30`); the cqrs README says wire the same logger you hand the service (`cqrs/eventservice.go:63-65` "Wire the same logger...") and the skeleton sets no `Logger`. It also omits the `ReadyCheck`/`ShutdownHooks` integration the hook passthrough exists for (`cqrs/eventservice.go:636` `ReadyCheck()`; hook plumbing `preset/config.go:64-66`, consumer-first order `preset/preset.go:72-82`). Impact: the skeleton is the template's teaching artifact for the one heavy path. Sketch: `New(ctx, logger *slog.Logger)` setting `Logger: logger`, and a comment block showing `ShutdownHooks: []appkit.Hook{es.Shutdown}` + `ReadyCheck: es.ReadyCheck` via the preset Config. `[TEMPLATE]`
6. **Realtime leg vs default `WriteTimeout`.** Core documents that a fixed WriteTimeout (default 30s) kills SSE streams and the fix is the `NoTimeout` sentinel (`go-appkit/README.md:454-463`); every appkit SSE integration test sets `NoTimeout` (e.g. `integration/integration_test.go:25,38-39`); the preset maps `Timeouts.WriteTimeout` verbatim and does not neutralize it when the realtime leg resolves on (`preset/preset.go:61,120-122`). Impact: `APPKIT_REALTIME=on` on any default-configured preset service produces 30s-dying streams. Fix: preset applies `NoTimeout` when the realtime leg is on, or the preset README documents the pairing. `[PRESET-UPSTREAM]`
7. **Metrics surface undocumented.** `preset.Config.Metrics` passes through verbatim (`preset/config.go:41-43`, `preset/README.md:73-74`); the template never mentions `/metrics`, the stable metric names, or the mandatory auth (`go-appkit/README.md:203-267`). Impact: adopters rediscover a zero-dependency Prometheus surface by accident. Sketch: one FEATURES.md row + README snippet `Metrics: &appkit.MetricsConfig{Path: "/metrics", BasicAuthUser: ..., BasicAuthPass: ...}`. `[TEMPLATE]`
8. **`LogFormat` passthrough unused.** Preset models it (`preset/config.go:36`); the template's Config carries Addr + LogLevel only. One more tagged field (`LogFormat string `default:"auto" env:"APP_LOG_FORMAT"``) makes JSON-mode deploy a one-env-var operation (core maps auto = JSON when not a TTY). Minor. `[TEMPLATE]`
9. **Stale version comment upstream.** `preset/security.go:11` still says "shipped security v0.2.0 batteries" while HEAD pins security v0.3.0. Cosmetic. `[LIB-UPSTREAM]`

## Should the archetype adopt or wire more?

Default binary: keep exactly the current spine. The template's judgment to inherit everything production-shaped from the preset and carry only a CLI shell, one JSON example, one templ page, and a gated cqrs skeleton is the correct archetype shape; the appkit README itself markets this repo as the third "Start here" door (`go-appkit/README.md:133-136`). The Addr/LogLevel duplication in `Config` is NOT drift: it is the config module's own documented canonical example, verbatim (`config/README.md:20-26`), and the alternative (embedding `appkit.ServiceConfig`, blessed safe at `config/README.md:70-71`) would couple the template to core's field set instead of the preset seam.

Docs (cheap, every adopter reads them): the env grammar is already in README:78-80 and FEATURES.md rows 43-45/52, which is good; add the missing posture lines (security standard recommendation, `OTEL_EXPORTER_OTLP_ENDPOINT` pairing shown in `preset/README.md:70`, metrics recipe, realtime-vs-timeout caveat once upstream documents it). Build-tag gate: `internal/events` is the right mechanism for optional weight and should stay, with the fixes in gap 5. Stay out: flightrecorder/flightrecorderhealth (ops weight, one recorder per process, not preset-mediated; if demand appears it belongs behind a preset leg first), the docs module (needs a domain catalog; revisit alongside the events skeleton), cqrs in the default binary (zero event-sourcing weight until the domain needs it, the skeleton's own stated posture), and httpx batteries beyond ResultHandler (adopter-specific; a README pointer covers it).

## Version currency

- **core: v0.12.0 pinned, v0.13.0 latest (DRIFTED, direct pin).** Gap = Listener-injection seam (`ServiceConfig.Listener`, unix sockets / socket activation, demanded by two independent adoption reviews) + LogHandler seam (bring-your-own slog handler, fleet log-lane prep) + README adoption surfaces (`CHANGELOG.md:11-47`). Additive only; no breaking API.
- **cqrs: v0.9.0 pinned, v0.10.0 latest (DRIFTED, direct pin).** Gap = 2026-11-22 go-cqrs-lite train (sqliteengine EnforceCap deadlock fix, SSE Last-Event-ID hardening) + `system.Standard` three-tier default deployment (ADR-0165) (`cqrs/CHANGELOG.md:5-31`). The template's indirect block still resolves system v4.16.0 / metaengine v4.20.0 / sqliteengine v4.6.0; the bump raises those floors to v4.19.0 / v4.26.0 / v4.9.1.
- **security: v0.2.0 pinned, v0.3.0 latest (indirect DRIFT via preset).** Gap = samber/lo runtime refactor, documented behavior-identical (`security/CHANGELOG.md:3-12`). Low stakes; rides the preset train.
- **preset v0.1.1, httpx v0.2.0, config v0.1.1, errorpages v0.1.3, health v0.3.2, otel v0.4.0, realtime v0.2.0, systemd v0.2.0: current.** The template already carries preset v0.1.1's headline fix (realtime hub drain moved from ShutdownHooks to DrainHooks, the graceful-shutdown deadlock fix; `preset/CHANGELOG.md` [0.1.1]).
- **Can core+cqrs bump independently of a preset train? Mechanically yes.** cqrs has zero appkit requires (verified: no `larsartmann/go-appkit` lines in `cqrs/go.mod`), so its pin is fully the template's own. preset v0.1.1's tagged go.mod requires core v0.12.0 / security v0.2.0 (verified via `git show preset/v0.1.1:preset/go.mod`); since core v0.13.0 is additive, MVS picks v0.13.0 over the preset's v0.12.0 floor without conflict. BUT: a pin train is already staged upstream, preset/go.mod at HEAD requires core v0.13.0 + security v0.3.0 (diff vs tag touches only go.mod/go.sum/lint config; no preset/v0.1.2 tag yet and no [Unreleased] entry in `preset/CHANGELOG.md`), and the template's own ritual forbids the hand-edit: "Do NOT hand-edit the pinned versions between stamps, bump via the ritual so drift stays loud" (`README.md:131-140`). The refresh, per `AGENTS.md:32-36`: bump the pins AND the AGENTS.md stamp table (currently `preset v0.1.1 (core v0.12.0, httpx v0.2.0, cqrs v0.9.0, config v0.1.1)`, stamped 2026-11-21, the same day core v0.13.0 tagged) AND re-run the dogfood probe (build, boot, `/healthz` + `/api/status` probe, SIGTERM graceful-stop). Cheapest correct move: wait for the staged preset tag and stamp the whole tuple in one ritual.

## Risks

- **APPKIT_SECURITY=strict via env silently mounts only the standard batteries** (no OriginCheck, no boot rejection), contradicting the preset README's fail-fast claim. Detail in Gaps #2. Until the upstream fix, the template README should say strict requires code config.
- **APPKIT_REALTIME=on under default `WriteTimeout: 30s` kills every SSE stream at 30s.** Core documents the NoTimeout sentinel; the preset does not apply it for the leg and neither preset nor realtime README mentions the interaction. Detail in Gaps #6.
- **Pin lag is not cosmetic**: cqrs v0.9.0's dependency set lacks the sqliteengine EnforceCap deadlock fix, so any adopter who enables the events skeleton today inherits a known deadlock class on the default deployment path.
- **Events skeleton doc-comment drift** (`events.New(cfg.LogLevel)` vs `New(_ context.Context)`) will not compile for an adopter following it; also the unwired `Logger` contradicts the package doc's "wired into the service's logger".
- Checked and clean: no deprecated API usage found at the pinned versions (v0.13.0 is additive over the pinned surface); the template does not duplicate `RegisterClassifications` (preset does it); the exhaustruct nolint at `service.go:48` is appropriate because preset zero values are deliberate env-driven legs.
- UNVERIFIED: I did not run the template's binary or its test suite; runtime behavior claims are taken from the template's own probe logs (AGENTS.md "Verified 2026-11-22" block) and the appkit test suite references.

## How to verify

```bash
# version facts
git -C /home/lars/projects/go-appkit describe --tags        # cqrs/v0.10.0-7-g74e4d80
git -C /home/lars/projects/go-appkit log -1 --format='%h %ci'
git -C /home/lars/projects/go-appkit tag | sort | grep -E '^(v0\.1[23]|preset/|cqrs/|security/|httpx/|config/)'
git -C /home/lars/projects/go-appkit show preset/v0.1.1:preset/go.mod | grep larsartmann/go-appkit   # core v0.12.0, security v0.2.0
grep -n 'larsartmann/go-appkit' /home/lars/projects/go-service-template/go.mod                        # pins incl. indirect legs

# canonical composition root + hook passthrough
sed -n '47,64p' /home/lars/projects/go-service-template/internal/app/service.go
sed -n '49,65p' /home/lars/projects/go-appkit/preset/README.md
grep -n 'StartHooks\|DrainHooks\|ShutdownHooks' /home/lars/projects/go-appkit/preset/config.go /home/lars/projects/go-appkit/preset/preset.go

# env grammar + the strict-degradation path
sed -n '11,16p' /home/lars/projects/go-appkit/preset/env.go
grep -n 'APPKIT_' /home/lars/projects/go-service-template/README.md
grep -n 'hasSecurity\|applySecurity' /home/lars/projects/go-appkit/preset/preset.go
sed -n '24,32p' /home/lars/projects/go-appkit/preset/security.go        # nil cfg defaults profile to Standard

# drift evidence
grep -n 'sqliteengine\|EnforceCap' /home/lars/projects/go-appkit/cqrs/CHANGELOG.md | head -5
grep -n 'Listener\|LogHandler' /home/lars/projects/go-appkit/CHANGELOG.md | head -5
grep -n 'go-appkit preset' /home/lars/projects/go-service-template/AGENTS.md

# skeleton drift + raw-mux test
grep -n 'events.New' /home/lars/projects/go-service-template/internal/events/events.go
grep -n 'httptest.NewServeMux\|http.NewServeMux\|httptest.NewRecorder' /home/lars/projects/go-service-template/internal/api/routes_test.go
grep -rn 'testkit' /home/lars/projects/go-service-template --include='*.go' | wc -l   # 0 = unused
```

## Submodule matrix

| Module path | In template graph | How used | Latest tag | Note |
|---|---|---|---|---|
| github.com/larsartmann/go-appkit (core) | Direct v0.12.0 | LogLevel type + preset builds ServiceConfig; lifecycle via preset | v0.13.0 | DRIFTED: Listener + LogHandler seams, additive |
| .../go-appkit/config | Direct v0.1.1 | `config.Load[Config]()` in composition root | v0.1.1 | Current; template Config is the module's canonical example |
| .../go-appkit/cqrs | Direct v0.9.0 | Events skeleton behind `-tags events`, unwired | v0.10.0 | DRIFTED: EnforceCap deadlock fix, SSE replay hardening, system.Standard topology |
| .../go-appkit/httpx | Direct v0.2.0 | One `ResultHandler` example route | v0.2.0 | Current; bind/conditional/negotiate/WriteDeadline/httpxtest unused |
| .../go-appkit/preset | Direct v0.1.1 | The composition root itself | v0.1.1 | Current tag; HEAD stages core v0.13.0 + security v0.3.0 pins (unreleased train) |
| .../go-appkit/errorpages | Indirect v0.1.3 | Preset spine (env opt-out) | v0.1.3 | Current |
| .../go-appkit/health | Indirect v0.3.2 | Preset spine: probe + dashboard owns /health family | v0.3.2 | Current |
| .../go-appkit/otel | Indirect v0.4.0 | Preset leg, OFF by default (`APPKIT_OTEL`) | v0.4.0 | Current; never exercised by template |
| .../go-appkit/realtime | Indirect v0.2.0 | Preset leg, OFF by default (`APPKIT_REALTIME`) | v0.2.0 | Current; WriteTimeout interaction undocumented (Gaps #6) |
| .../go-appkit/security | Indirect v0.2.0 | Preset leg, none by default (`APPKIT_SECURITY`) | v0.3.0 | Indirect DRIFT: lo refactor, behavior-identical; env-strict bug (Gaps #2) |
| .../go-appkit/systemd | Indirect v0.2.0 | Preset spine `systemd.Install` + template unit | v0.2.0 | Current |
| .../go-appkit/flightrecorder | Absent | Not preset-wired, not imported | v0.2.0 | Ops weight, one recorder per process; preset leg would precede adoption |
| .../go-appkit/flightrecorderhealth | Absent | Not preset-wired, not imported | v0.1.7 | Same posture as flightrecorder |
| .../go-appkit/integration | Absent | Appkit-internal E2E suite; pins published tags, never a consumer dependency | untagged | By design (root README Development section) |
| .../go-appkit/docs | Absent | Would need a command/event catalog; archetype has no domain | v0.3.4 | Revisit alongside the events skeleton |
