# go-health-dashboard utilization review (go-service-template)

| Reviewed | 2026-11-23 |
|---|---|
| Library | github.com/larsartmann/go-health-dashboard (single module, no submodules) |
| Version audited | v0.13.3-79-g19af9cf (19af9cf, 2026-11-20 17:59:34 +0100) |
| Template pin | v0.13.3 (indirect, `go.mod:102`; the template's own require is the graph floor, see Version currency) |
| Latest tag | v0.13.3 (2026-11-12), so current on tag; HEAD is 79 commits past it |
| Adoption score | 50/100 (moderate), 6 of 11 applicable capabilities leveraged (5 fully, 1 partially, 5 missed) |
| Verdict | The preset-mediated spine is wired flawlessly and runtime-verified end to end, but the preset passes zero of the lib's ~35 options, so the flagship page runs on two third-party CDNs, its SSE stream is cut every 30s, and its Version card says "unknown". |

## Verdict

Used SUPERBLY in shape, far from the max in surface. Everything that runs, runs perfectly with zero template code (verified live on a booted binary: HTML dashboard, JSON content negotiation, Datastar SSE patches, favicon, probe endpoints, the drain-phase banner and readiness flip), which is exactly what a thin composition root over the preset should do. "Max" here means the preset closing its option gap: `dashboardOpts` (`/home/lars/projects/go-appkit/preset/preset.go:231-238`) returns `health.WithDashboard()` with no dashboard options, so every adopter gets the library's bare defaults: Tailwind via the `cdn.tailwindcss.com` Play CDN (`view.templ:125-141`), the Datastar SDK via jsdelivr at the deprecated 1.0.3 pin while the embedded 1.0.4 bundle sits unserved in the binary (`view.templ:114-124`, `handlers.go:350-362`), a 30s-capped live stream (appkit's `defaultWriteTimeout`, measured at 30.007s), a "Version: unknown" stat card because `health.NewProbe(cfg.HealthChecks)` (`preset.go:109`) never receives `health.WithVersion(cfg.Version)`, and trend/metrics/auth each exactly one option away with no preset Config field to pass them through. The lib itself is excellent; the utilization ceiling is set entirely by the mediator.

## What the template uses today

- **PRESET-MEDIATED, dashboard spine (ON by default, opt-out only).** The preset mounts the dashboard and hands it route ownership:
  - `preset/preset.go:88-89` sets `registerHealth := cfg.NoDashboard` (core's default `/health` family is disabled because "the dashboard owns /health" and the mux would panic on the duplicate);
  - `preset/preset.go:109` builds the probe (`health.NewProbe(cfg.HealthChecks)`, nil map by default, no options);
  - `preset/preset.go:111` `health.Mount(svc.Mux, probe, dashboardOpts(cfg.NoDashboard)...)`;
  - `preset/preset.go:231-238` `dashboardOpts` returns `[]health.MountOption{health.WithDashboard()}` with no dashboard options: that is the complete option set the dashboard ever receives;
  - `preset/config.go:56-58` `NoDashboard bool` is the only switch (no env var);
  - `go-appkit/health/mount.go:31-36` `WithDashboard(opts ...dashboard.Option)` is a clean passthrough that the preset simply does not use, and `mount.go:81-83` constructs `dashboard.New(probe, cfg.dashboardOptions...)`.
- **What that renders in the template binary (all runtime-verified on `APP_ADDR=127.0.0.1:18311 ./app serve`):**
  - `GET /health` (200, `text/html`): full templ-components document, "All Systems Operational" banner, stat cards (Version: `unknown`, Uptime, Latency), empty-state card ("No services" wording, because the probe boots with nil checks), Updated stamp, dark-mode toggle persisted in localStorage, connection pill (live/reconnecting/offline), and a `datastar.LiveRegion` (`#health-region`, `data-init` pointing at `/health/sse`), all per `view.templ:38-102`.
  - `GET /health` with `Accept: application/json` (200): the go-health JSON document (`{"status":"pass","uptime":"2s","shutting_down":false,...,"checks":{}}`; RFC 7231 q-value negotiation, `handlers.go:23` + `wantsJSON`.
  - `GET /health/sse` (200, `text/event-stream`): initial full-state `event: datastar-patch-elements` patch (`selector #health-region`, `mode inner`), heartbeat every 15s (`options.go:22`), PushOnChange mode; the stream is cut by appkit's default 30s `WriteTimeout` (measured: connection died at 30.007s; browser reconnects via `RetryAlways`, `view.templ:87-93`).
  - `GET /healthz` `/readyz` `/startupz` (200 JSON): the dashboard registers the probe endpoints itself (`routes.go:8-10`, `dashboard.go` `RegisterRoutes` via appkit `mount.go:115-123`), matching `docs/DOMAIN_LANGUAGE.md:181-183`.
  - `GET /favicon.svg` (200, embedded green-heart SVG).
  - Graceful drain (runtime-verified with SIGTERM plus one open SSE connection): `preset/preset.go:75-79` DrainHooks → `drainMounted` (`preset.go:137-143`) → `Mounted.Drain` (`health/mount.go:205-223`) → `probe.MarkShuttingDown()`: `/readyz` flips 503, `/healthz` stays 200, and the HTML banner switches to the shutting-down/draining wording (`status.go:296-299`) for the whole 5s drain window, while the refresh loop keeps running so the page stays live during drain.
- **Everything else the lib ships is 404 in the template binary** (all probed): `/health/datastar.js`, `/health/metrics`, `/health/trend`, `/health/export`, `/health/introspect`, `/health/oidc/login`; each is registered only behind its option, and the preset passes none.
- **TEMPLATE-DIRECT: nothing.** `rg 'go-health-dashboard'` over the template's 7 Go files returns no matches; `go.mod:102` carries it in the indirect block. `go mod why -m` resolves `internal/app → preset → health → go-health-dashboard`, i.e. fully mediated (correct: a domainless archetype should not own health UI).
- **ABSENT: the `health-hub` federation binary and `example/` demo** are main packages in the lib repo, not importable surface; nothing else ships.

## Capability inventory

| Capability | Status | Evidence | Note |
|---|---|---|---|
| Core mount + route ownership (`New`, `RegisterRoutes`, `Routes`, `WithBasePath` resolution) | Fully leveraged | `preset/preset.go:111`; `health/mount.go:115-123`; runtime 200s on all six default routes | The dashboard owns `/health` plus the three kubelet probes from its own route table (`routes.go:30-45`), exactly the DOMAIN_LANGUAGE contract |
| Real-time SSE view (pusher, PushOnChange fingerprint, heartbeat, retry field, initial state, connection pill, dark mode) | Fully leveraged | `pusher.go` (patch render `:200-208`, heartbeat `:316`); runtime SSE capture | Live patch stream verified on the wire; full-state patches make drops self-healing (no replay needed) |
| `/health` content negotiation (HTML vs JSON q-values) | Fully leveraged | `handlers.go:23`; runtime `-H 'Accept: application/json'` | JSON returns 503 when critical services fail; kubelet probes stay JSON-only |
| Check-state rendering (severity groups, badges, since/duration metadata, evidence strip, empty state, jump-to-problems) | Fully leveraged | `status.go` grouping; SSE body renders the full group markup | Machinery runs on every patch; tables stay empty in a fresh clone only because the probe has no checks yet (adopter fills `preset Config.HealthChecks`, `preset/config.go:51-54`) |
| Graceful-drain integration (`Mounted.Drain`, shutting-down banner, readiness flip, `WithShutdownDrain`) | Fully leveraged | `preset/preset.go:75-79`; `status.go:296-299`; runtime SIGTERM test | Banner + 503 readiness verified live; `WithShutdownDrain` itself stays 0 (no SSE drain wait), harmless under the 30s cut |
| Dashboard self-observability (`HealthCheck` sentinels, `SubscriberCount`, SSE opened/closed counters + watchdog gauge at HEAD) | Partially used | `dashboard.go:324`, `handlers.go:149`; new counters in CHANGELOG `[Unreleased]` | Lifecycle is wired via appkit; no preset surface exposes pusher health, subscriber counts, or the sentinel family (`ErrPusherStale` etc.) |
| Version/instance metadata display (probe `WithVersion`, `WithInstanceID` stat cards) | Missed opportunity | Runtime Version card reads `unknown`; `preset/preset.go:109` passes no options | `appkitpreset.Config.Version` exists and the template stamps it (`internal/app/service.go:27,51`), it just never reaches the probe |
| Trend + history + export (`WithTrend`, `/health/trend`, `/health/export` CSV/NDJSON, timeline, `Observe` probe-cadence hook) | Missed opportunity | 404 at runtime; `routes.go:57-65` gate on `TrendSamples > 0` | One int option; appkit's own health doc quick start shows `WithTrend(300)` (`go-appkit/health/doc.go:27-30`) |
| Prometheus metrics (`WithMetrics(true)`, `/health/metrics`, `deploy/prometheus.yml` recipes) | Missed opportunity | 404 at runtime; `routes.go:67-75` | One bool; complements (not duplicates) the otel leg's `appkit_build_info`; metric families documented in `docs/metrics.md` |
| Self-hosted assets (`WithCSSPath`, `WithDatastarSrc`, `WithEmbeddedDatastarSDK` at `Routes.DatastarJS`) | Missed opportunity | Runtime HTML pins `cdn.tailwindcss.com` + jsdelivr `datastar@1.0.3`; `/health/datastar.js` 404; options at `options.go:448,457,574`, serving at `dashboard.go:159-161` + `handlers.go:350-362` | The pinned SDK bundle is already linked into every template binary (`go version -m`: `go-datastar/static v0.8.0`) and never served; shared finding with `docs/review/libs/templ-components.md` and `go-datastar.md` |
| Auth / exposure control (`WithMiddleware`, `WithPublicMode`, native OIDC at HEAD) | Missed opportunity | No middleware passed (`preset/preset.go:237`); OIDC only in `[Unreleased]` (CHANGELOG, `oidc.go:195`) | Default posture serves check names and raw error strings unauthenticated on the bound address; `WithPublicMode` anonymizes for untrusted audiences |
| CSP nonce integration (`WithNonce`, `WithNonceExtractor`, `RecommendedCSP(Strict)`, root `data-nonce`) | Not applicable | Preset security leg off by default; appkit stack emits no CSP | N/A reason: nothing to nonce today; the pairing ask (`security.NonceFromContext` bridge) is already routed PRESET-UPSTREAM in `docs/review/libs/templ-components.md` gap 5 |
| Rate limiting + request logging (`WithRateLimit`, `WithPerIPRateLimit`, `WithRequestLogging`, the latter two at HEAD) | Not applicable | Not passed; probe endpoints exempt by design (`options.go:122-140`) | N/A reason: the lib's own hardened-preset doc places rate limiting "in the chain in front of the mux" (`go-appkit/health/mount.go:275-277`); proxy/preset-layer concern, and RemoteAddr keying misfits proxied fleets |
| Webhook push (`WithWebhook`, `WithWebhookHeaders`, `WithWebhookHMAC`) | Not applicable | Zero wiring anywhere in template or preset | N/A reason: needs a receiving endpoint and an alerting policy, adopter-specific by definition; no domain, no ingest |
| Federation / aggregate (`Prober` interface, `GroupBySource`, `health-hub` binary, NixOS module) | Not applicable | Single-process archetype, one probe | N/A reason: federation is an ops-side deployment (the hub is a standalone binary); in-process aggregates need >1 probe, which an archetype never has |
| Route / base-path customization (`WithRoutes`, `WithBasePath`, appkit `DashboardHardenedPreset`) | Not applicable | Root mounting is the preset's deliberate spine posture | N/A reason: `mount.go:289-294` ships the `/ops` + nonce bundle for embedders who need it; the archetype mounts at root and inherits |

Scoring: 16 rows, 5 Not applicable, A = 11. Fully = 5 × 1, Partially = 1 × 0.5, Missed = 5 × 0. Σ = 5.5 → round(100 × 5.5 / 11) = 50 (moderate).

## Gaps and opportunities

1. **The preset has no dashboard-option passthrough at all (the umbrella gap).** What the lib offers: ~35 functional options (`options.go:179-597`) covering title, trend, metrics, CSS, SDK hosting, auth, rate limits, webhooks, OIDC. What the mediator does instead: `preset/config.go` exposes exactly `HealthChecks` and `NoDashboard` (`:51-58`), and `dashboardOpts` (`preset/preset.go:231-238`) passes nothing, so every option is unreachable without abandoning `appkitpreset.New` for direct `health.Mount`. Impact: high (it is the precondition for gaps 2-4 and 6) × medium ease (one Config field). Sketch:
   ```go
   // go-appkit/preset/config.go
   type Config struct {
       // ...
       DashboardOptions []dashboard.Option // forwarded to health.WithDashboard
   }
   // preset/preset.go dashboardOpts:
   return []health.MountOption{health.WithDashboard(append(defaultDashboardOpts(cfg), cfg.DashboardOptions...)...)}
   ```
   Routing: **[PRESET-UPSTREAM]**.
2. **Embedded Datastar SDK off: jsdelivr CDN 1.0.3 runs the page while the pinned 1.0.4 bundle sits in the binary.** What the lib offers: `WithEmbeddedDatastarSDK()` (`options.go:574`) flips `DatastarSrc` to `Routes.DatastarJS` (`dashboard.go:159-161`) and serves `dstarstatic.Bytes()` same-origin (`handlers.go:350-362`). What the mediator does instead: nothing, so `view.templ:122` pins the deprecated `datastar.DatastarVersion1_0_3` CDN alias. Runtime-verified: HTML loads `jsdelivr.net/.../datastar@1.0.3`, `/health/datastar.js` 404. Impact: high (third-party availability, CSP hostility, one-minor-behind client, on every fleet service's `/health`) × trivial ease (one option, zero new deps). Cross-cite: this is gap 1 of `docs/review/libs/go-datastar.md`, confirmed from this side. Routing: **[PRESET-UPSTREAM]**. Paired follow-up that belongs HERE: `embeddedSDKHandler` serves an unversioned URL under `max-age=86400` with no ETag/304, the exact stale-client skew go-datastar v0.7.0's `ScriptHandler`/`ScriptTagVersioned` were built to kill; the dashboard should delegate or add ETag + versioned src. Routing: **[LIB-UPSTREAM]**.
3. **Tailwind Play CDN styles the page.** What the lib offers: `WithCSSPath` (`options.go:448`) swaps the Play CDN `<script>` for a compiled stylesheet `<link>`. What the mediator does instead: nothing, so the `data.CSSPath == ""` fallback at `view.templ:125-141` emits `https://cdn.tailwindcss.com` plus an inline `tailwind.config` script (runtime-verified once in the served HTML). Impact: high (Tailwind labels the Play CDN a dev tool; production `/health` depends on a third party and is CSP-hostile) × hard ease at the preset layer: somebody must compile the CSS, and the consumer-scanning rule makes that genuinely non-trivial (README "The two integration failure signatures"; `docs/gotchas.md` "Consumer MVS drift"). The structural fix is lib-side: ship/embed a compiled baseline stylesheet so the zero-config default is CDN-free, the same way the SDK bundle is embedded. Cross-cite: shared finding with `docs/review/libs/templ-components.md` (its gap 3/Risks). Routing: **[LIB-UPSTREAM]** for the embedded baseline CSS, **[PRESET-UPSTREAM]** for wiring `WithCSSPath` once an artifact exists.
4. **`/health/sse` is cut every 30s by the appkit default WriteTimeout.** Mechanism from this side (runtime-verified): the stream died at exactly 30.007s; the dashboard cannot fix it (it never owns the `http.Server`) and already does everything right: 15s heartbeats (`options.go:22`), SSE retry field, initial full state on reconnect (`pusher.go` `sseHandler`), and `RetryAlways` so a graceful-restart EOF reconnects (`view.templ:87-93`). appkit itself documents the degradation (`go-appkit/health/doc.go:124-129`: "browsers reconnect, so it degrades but works") and owns the fix (`NoTimeout`, `go-appkit/config.go:23-30`; template leaves `Timeouts` zero, `internal/app/service.go:48-53`). Cross-cite: `docs/review/libs/go-sse.md` gap 1 and `go-appkit.md` gap 6 agree. Routing: **[PRESET-UPSTREAM]** (pair the realtime leg and/or the dashboard spine with `NoTimeout`, or a per-route deadline exemption). Nothing further for this repo: the dashboard's resilience already covers the reconnect.
5. **The Version stat card says "unknown".** What the lib offers: the card renders `resp.Version` (`status.go:308`), fed by go-health's `WithVersion`; the README quick start shows it. What the mediator does instead: `health.NewProbe(cfg.HealthChecks)` (`preset/preset.go:109`) passes no options even though `NewProbe` accepts them (`go-appkit/health/probe.go:63`) and `appkitpreset.Config.Version` already exists and is ldflags-stamped by the template (`internal/app/service.go:27,51`). Impact: low-medium (every fleet service's status page hides which build it is, right next to a `/version` endpoint that knows) × trivial ease. Sketch: `probe := health.NewProbe(cfg.HealthChecks, health.WithVersion(cfg.Version))`. Routing: **[PRESET-UPSTREAM]**. (`WithTitle` deserves the same treatment once the preset learns a service name.)
6. **Trend and metrics are dark.** One int and one bool (`WithTrend(300)`, `WithMetrics(true)`) light up the sparkline, the timeline, `/health/trend`, `/health/export`, and `/health/metrics`; appkit's own health doc uses exactly these two in its quick start (`go-appkit/health/doc.go:27-30`). Weight is minimal (ring buffer + a text-exposition route, already compiled into the binary). Routing: default-flipping belongs to the preset's opt-in-leg philosophy, so **[NOT-NOW + preset posture: legs are env-driven opt-ins; the honest move is gap 1's passthrough plus one preset-README line, not a silent default change]**. The archetype itself should stay out: a template cannot know whether adopters run their own Prometheus.

## Should the archetype adopt or wire more?

Default-ON dashboard: right call, already decided by the preset and inherited cleanly (the mux-ownership collision is even handled for the template, `preset/preset.go:88-89`). No template code should ever touch this library, and none does. What belongs where:

- **Default binary:** exactly what runs today, plus (once the preset lands gaps 1-3) the same-origin SDK and CDN-free CSS it should have been serving all along.
- **Docs the archetype owes adopters (cheap, one paragraph):** the template README already names the surface ("the real-time dashboard at `/health` owns them", `README.md:75-76`, and `FEATURES.md:39-40` lists "HTML + JSON + SSE views of the same probe state"), so the live features are NOT unmentioned; the only honest polish is adding `/health` to the Verify block's curl line (`README.md:89` curls `/healthz` only) and one sentence on the adopter path: checks go into `appkitpreset.Config.HealthChecks`, per-check since/duration light up for free, and post-construction dashboard options (webhooks, middleware, `/ops` base path via `DashboardHardenedPreset`, `go-appkit/health/mount.go:262-294`) are reachable through `Mounted.Dashboard()` without abandoning the preset. Routing: **[TEMPLATE, docs-only]**.
- **Must stay out of the template:** any dashboard option wiring (that is the preset's seam, gap 1), the events-style build-tag skeleton treatment (the dashboard is not optional weight, it is the spine), webhooks/OIDC/rate limits (adopter policy), and the federation hub (ops deployment, not archetype code).

## Version currency

- Pin: `go.mod:102` `github.com/larsartmann/go-health-dashboard v0.13.3 // indirect`. Latest tag v0.13.3 (2026-11-12): **current on tag**. HEAD is 79 commits past it (`v0.13.3-79-g19af9cf`).
- **Who pins v0.13.3: the template's own go.mod, not appkit.** `go mod graph` shows the main-module edge `github.com/example/go-service-template → go-health-dashboard@v0.13.3` while `go-appkit/health@v0.3.2` and `go-appkit/preset@v0.1.1` (the tags the template resolves) both require **v0.12.2**, and appkit's health module still pins v0.12.2 at its own HEAD (verified `git diff health/v0.3.2..HEAD -- health/go.mod`, no dashboard change). The same MVS-floor-ahead-of-the-train pattern the templ-components report found for v1.27.2: the template's indirect require is what lifts every adopter past the v0.12.2 → v0.13.3 delta (webhook HMAC + compatibility policy, `RecommendedCSPStrict`, the connection-pill fix #31, the root `data-nonce` fix #23, the NixOS module).
- **The 79 unreleased commits do NOT fix any of the three cross-report findings.** Verified by diff: `view.templ`'s `dashboardHead` (the DatastarSrc/CDN branch and the Tailwind fallback) is byte-identical since v0.13.3, and `handlers.go`'s `embeddedSDKHandler` is unchanged (still no ETag, unversioned URL). What `[Unreleased]` actually stages for v0.13.4+: native OIDC login (`WithOIDC`, `ValidateOIDC`, hub env family, NixOS submodule), SSE lifecycle metrics (opened/closed counters, pusher watchdog gauge), rate-limit observability (429 counter + Retry-After histogram), `WithPerIPRateLimit`, `WithRequestLogging`, lifetime jitter, `Retry-After` on connection-limit 503s, plus NixOS/docs/CI chores and an internal dedup pass. Of these, OIDC is the story-changer: it gives the preset a real answer to the exposure gap (inventory row 11) the moment it ships.
- Bump ownership: nothing for the template to do while v0.13.3 is the tag. The next dashboard release rides either the template's own floor bump (the pattern already in place) or, better, the next appkit health/preset tag finally moving off v0.12.2.

## Risks

- **CDN dependency on the flagship page** (runtime-verified): `cdn.tailwindcss.com` (Play CDN, dev-tool labeling, injects a runtime `<style>`, needs `style-src 'unsafe-inline'` under CSP) plus jsdelivr `datastar@1.0.3` (deprecated alias, one minor behind the embedded 1.0.4). Both vanish behind gaps 2-3. Not the template's risk to own; preset/lib routing as above.
- **30s stream cut** (runtime-verified, 30.007s): degrades, does not break (reconnect + full-state patch), but every NOC monitor reconnects twice a minute and the window between cut and retry is blind. Preset fix (gap 4).
- **Unauthenticated internals by default:** the dashboard serves check names and raw dependency error strings to anyone who can reach the bound address; the template's `APP_ADDR` default is `:8080` (all interfaces). Today the probe is empty so nothing leaks, but the first adopter check (a Postgres DSN error, an upstream host in a message) renders publicly. Mitigations exist (`WithMiddleware`, `WithPublicMode`, OIDC next release) and none are surfaced by the preset. Deployments behind an authenticated ingress are fine; the archetype's docs say nothing either way.
- **Pusher render errors are swallowed** (`pusher.go:203-206` per the go-datastar report): a failed patch render is silently dropped; self-heals on the next change/tick. Lib-side observation, unchanged at HEAD.
- **No deprecated or misused APIs from this consumer:** the template imports nothing; the deprecated surface in play (`DatastarVersion1_0_3`) is pinned by the lib's own template, not by consumer code. GOEXPERIMENT/jsonv2 is a non-issue on the template's Go 1.27.4 (json/v2 default-on, `go-appkit/health/doc.go:117-122`; the template built and ran plain).

## How to verify

```bash
# Version facts
git -C /home/lars/projects/go-health-dashboard describe --tags        # v0.13.3-79-g19af9cf
git -C /home/lars/projects/go-health-dashboard log -1 --format='%h %ci' # 19af9cf 2026-11-20 17:59:34 +0100
git -C /home/lars/projects/go-health-dashboard status --short          # clean: working tree == HEAD

# Pin + mediation chain
rg -n 'go-health-dashboard' /home/lars/projects/go-service-template/go.mod  # :102 v0.13.3 indirect
cd /home/lars/projects/go-service-template && go mod why -m github.com/larsartmann/go-health-dashboard # internal/app -> preset -> health -> dashboard
cd /home/lars/projects/go-service-template && go mod graph | grep 'go-health-dashboard@' | head -3      # template->v0.13.3, health@v0.3.2->v0.12.2, preset@v0.1.1->v0.12.2
rg -n 'go-health-dashboard' /home/lars/projects/go-appkit/health/go.mod   # :10 v0.12.2 (unchanged at appkit HEAD)

# Preset wiring (zero options passed)
rg -n 'registerHealth|NewProbe|health.Mount|dashboardOpts' /home/lars/projects/go-appkit/preset/preset.go # :88,:109,:111,:231-238
sed -n '231,238p' /home/lars/projects/go-appkit/preset/preset.go          # returns []health.MountOption{health.WithDashboard()}
rg -n 'NoDashboard|HealthChecks' /home/lars/projects/go-appkit/preset/config.go # :51-58 the only health fields

# The three cross-findings, from this repo
sed -n '104,141p' /home/lars/projects/go-health-dashboard/view.templ      # :122 DatastarVersion1_0_3 CDN pin; :125-141 Tailwind Play CDN fallback
rg -n 'WithEmbeddedDatastarSDK|WithCSSPath' /home/lars/projects/go-health-dashboard/options.go  # :574,:448 exist, unused by preset
sed -n '350,362p' /home/lars/projects/go-health-dashboard/handlers.go    # embeddedSDKHandler: no ETag, unversioned URL
git -C /home/lars/projects/go-health-dashboard diff v0.13.3..HEAD -- view.templ | grep -c 'tailwindcss\|DatastarVersion' || echo 0  # 0: not fixed at HEAD
rg -n 'defaultWriteTimeout|NoTimeout' /home/lars/projects/go-appkit/config.go  # :17 30s; :23-30 sentinel
sed -n '124,129p' /home/lars/projects/go-appkit/health/doc.go             # appkit documents the 30s /health/sse cut

# Runtime proof
cd /home/lars/projects/go-service-template && go build -o /tmp/gst-hd ./cmd/app
go version -m /tmp/gst-hd | grep -E 'go-health-dashboard|go-datastar/static'    # v0.13.3 + static v0.8.0 linked
(APP_ADDR=127.0.0.1:18311 /tmp/gst-hd serve &) ; sleep 2
curl -s http://127.0.0.1:18311/health | grep -o 'cdn.tailwindcss.com\|datastar@[^/"]*'   # both CDNs
curl -s http://127.0.0.1:18311/health | grep -o 'unknown'                               # Version card
curl -s -H 'Accept: application/json' http://127.0.0.1:18311/health | head -c 120       # JSON negotiation
for p in /healthz /readyz /startupz /favicon.svg /health/datastar.js /health/metrics /health/trend; do curl -s -o /dev/null -w "$p %{http_code}\n" http://127.0.0.1:18311$p; done
time timeout 40 curl -s -N http://127.0.0.1:18311/health/sse > /dev/null                # dies at ~30s (WriteTimeout)
# Drain: SIGTERM under an open SSE connection -> /readyz 503, /healthz 200, shutting-down banner
(timeout 12 curl -s -N http://127.0.0.1:18311/health/sse > /dev/null &) ; sleep 1 ; pkill -TERM -f 'gst-hd serve'
curl -s http://127.0.0.1:18311/health | grep -o 'Shutting Down[^<]*' ; curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:18311/readyz
pkill -f gst-hd

# Unreleased surface staged for v0.13.4+
sed -n '16,60p' /home/lars/projects/go-health-dashboard/CHANGELOG.md     # OIDC, SSE metrics, per-IP rate limit, request logging
rg -n 'func WithOIDC|func ValidateOIDC' /home/lars/projects/go-health-dashboard/oidc.go  # :195,:210
```

## Submodule matrix

| Module path | In template graph | How used | Latest tag | Note |
|---|---|---|---|---|
| github.com/larsartmann/go-health-dashboard (root, only module) | Yes, v0.13.3 indirect (`go.mod:102`) | PRESET-MEDIATED spine: the always-on `/health` HTML + JSON + `/health/sse` surface and the `/healthz` `/readyz` `/startupz` probe routes, wired by `go-appkit/preset` + `go-appkit/health` with zero template code | v0.13.3 | Current on tag; the template's own require is the MVS floor (appkit tags still at v0.12.2); HEAD stages OIDC + observability for v0.13.4+ and fixes none of the three cross-report findings |
