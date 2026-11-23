# go-datastar utilization review (go-service-template)

| Reviewed | 2026-11-23 |
|---|---|
| Library | github.com/larsartmann/go-datastar (+ submodules static, broadcast, datastartest) |
| Version audited | static/v0.8.0-10-g4fca56a (4fca56a, 2026-11-23 02:00 +0100; root tag v0.7.0 is 18 commits back) |
| Template pin | root v0.6.2 (indirect, sole direct requirer is go-health-dashboard v0.13.3); static v0.8.0 (indirect via templ-components/datastar v1.27.2); broadcast + datastartest absent |
| Latest tag | v0.7.0 root (four-module lockstep, 2026-11-07); static v0.8.0 is the newest submodule tag |
| Adoption score | 67/100 (moderate), 5 of 6 applicable capabilities leveraged (3 fully, 2 partially; 1 missed) |
| Verdict | The dashboard spine runs real go-datastar patches over SSE for every adopter with zero template code, but the lib's central selling point (the pinned, embedded JS client) is linked into the binary and never served: the browser gets jsdelivr CDN datastar@1.0.3 because the preset passes no dashboard options. |

## Verdict

Not "to the max", and the gap is concentrated in one place. PRESET-MEDIATED usage is genuine and runtime-verified: every adopter's `/health` page live-updates through `dstar.ElementsFromTempl` (go-health-dashboard `pusher.go:200-202`) emitting go-datastar's golden-pinned wire format, with zero template-direct imports (correct for a domainless archetype with exactly one go.mod). "Max" here means three things: (1) the preset should flip on the dashboard's `WithEmbeddedDatastarSDK` so `/health` serves the embedded v1.0.4 bundle that is *already linked into the binary* instead of a third-party CDN runtime one minor behind; (2) the fleet's stated UI direction (cqrs-htmx v5 dropped WebSocket for SSE/Datastar and consumes `go-datastar/broadcast` directly) deserves a working same-origin datastar loop in the preset's example, not in the template; (3) the root pin drift v0.6.2 → v0.7.0 is real but is not the template's to fix, it rides the next go-health-dashboard release. Everything else (signals, scripts, inbound reads, replay stores, test helpers) is correctly absent: an archetype with no interactive surface has no call sites for them.

## What the template uses today

- **PRESET-MEDIATED, dashboard spine (ON by default, opt-out only).** The preset mounts health with `health.WithDashboard()` and no dashboard options (`/home/lars/projects/go-appkit/preset/preset.go:88-89,111,231-238`; the only switch is `Config.NoDashboard`, `preset/config.go:56-58`, no env var). The dashboard (go-health-dashboard v0.13.3, indirect in template go.mod) is the *only* module in the template's graph that imports the root go-datastar library:
  - `go-health-dashboard/pusher.go:13` `dstar "github.com/larsartmann/go-datastar"`;
  - `go-health-dashboard/pusher.go:200-202` `dstar.ElementsFromTempl(content, dstar.WithModeInner(), dstar.WithSelectorID(healthRegionID))` renders the templ dashboard body into an `ElementsPatch`;
  - `go-health-dashboard/pusher.go:205-208` `patch.Event()` becomes a raw `sse.Event` broadcast through a plain go-sse `Broadcaster` (`pusher.go:107`), with `evt.Retry` overridden from the configured client retry interval.
  - Runtime-verified: `curl -N /health/sse` streams `event: datastar-patch-elements`, `data: selector #health-region`, `data: mode inner`, `data: elements <div ...>`: go-datastar's exact wire format (`wire_golden_test.go` pins the bytes).
- **PRESET-MEDIATED, JS client: served from the CDN, not from the library.** The dashboard HTML pins the deprecated alias `datastar.DatastarVersion1_0_3` (`go-health-dashboard/view.templ:122`, still true at dashboard HEAD 19af9cf) because `Config.DatastarSrc` is empty by default; the preset's `WithDashboard()` call passes nothing that would change it. Runtime-verified: `/health` loads `jsdelivr.net/gh/starfederation/datastar@1.0.3/bundles/datastar.js`; `/health/datastar.js` returns 404. The embedded bundle *is* in the binary (`go version -m` shows `go-datastar/static v0.8.0`; the dashboard links `dstarstatic.Bytes()` at `go-health-dashboard/handlers.go:11,359`) but the serving handler (`embeddedSDKHandler`, `handlers.go:350-362`) is only registered behind `WithEmbeddedDatastarSDK` (`dashboard.go:159-160`, default off).
- **PRESET-MEDIATED, realtime leg (APPKIT_REALTIME=on, OFF by default): speaks datastar-shaped SSE without importing go-datastar.** `preset/preset.go:120-121,194-210` mounts `GET /events` with a `realtime.Hub`; `Hub.BroadcastPatch` takes a `PatchLike` interface (`realtime/hub.go:112-127`, any type with `Event() sse.Event`) precisely so realtime never links go-datastar (`realtime/doc.go:18-27`). Runtime-verified: with `APPKIT_REALTIME=on`, `/events` holds a 200 SSE stream; with it absent, 404. So the realtime leg contributes *zero* go-datastar code to the binary; a datastar adopter pushes patches through it structurally.
- **TEMPLATE-DIRECT: nothing.** `rg 'go-datastar'` over the template's 7 Go files returns no matches; both graph entries sit in go.mod's indirect block (`go.mod:170-171`). Graph presence without the dashboard would be zero usage; here the dashboard is the runtime wiring.
- **ABSENT: broadcast and datastartest submodules.** Neither is in the template's module graph at all. Their fleet consumer is cqrs-htmx, not the template/appkit chain (see inventory).

## Capability inventory

| Capability | Status | Evidence | Note |
|---|---|---|---|
| ElementsPatch + template adapters (ElementsFromTempl, modes, selectors) | Fully leveraged | `go-health-dashboard/pusher.go:200-202`; runtime `/health/sse` probe | Every adopter's dashboard live-updates ride the core patch value; verified on the wire |
| Functional options surface (modes, namespaces, view transitions, event IDs, retry) | Partially used | 2 of ~20 options used: `WithModeInner`, `WithSelectorID` (`pusher.go:201-202`) | The rest (namespaces, view transitions, `WithElementsEventID`) has no spine call site; adopter UIs would use them |
| SignalsPatch (reactive signal updates, MarshalSignals) | Not applicable | No `SignalsPatch` producer anywhere in appkit or dashboard (repo-wide grep) | The default binary has no client-side reactive state; signals are the first thing an adopter UI brings (cqrs-htmx asserts on them, `cqrs-htmx/datastar/signals_assert_test.go`) |
| ScriptPatch family (ExecuteScript, Redirect, ConsoleLog/Error, ReplaceURL, Prefetch, DispatchCustomEvent) | Not applicable | Zero call sites in appkit, dashboard, template | Script execution patches belong to interactive app UIs; the spine only patches DOM elements |
| Response fluent builder + ErrorResponse(Notification)FromError | Not applicable | Dashboard builds patch values and broadcasts raw (`pusher.go:205-208`); no `datastar.NewResponse` anywhere in the graph | Single-connection response objects are adopter-handler shape; the dashboard's pattern (values + broadcaster) is the lib's other documented mode |
| Inbound ReadSignals + LastEventID | Not applicable | No `ReadSignals` call in appkit/dashboard/template; the template's inbound contract is `httpx.ResultHandler` JSON (`internal/api/routes.go:13`) | Inbound signals ride adopter forms; Last-Event-ID replay is unused because the dashboard re-renders full state per tick instead of replaying |
| static submodule: embedded pinned JS client (Bytes, Version = 1.0.4) | Partially used | Linked into the binary (`go-health-dashboard/handlers.go:11,359`; `go version -m`: static v0.8.0) but `/health/datastar.js` = 404 at runtime | The pinned, checksum-audited bundle sits unused in every adopter binary while the page loads CDN 1.0.3; one preset option flips it (gap 1) |
| ScriptHandler (ETag/304/HEAD) + ScriptTagVersioned cache-busting + ETagFor | Missed opportunity | Zero call sites in the whole template graph; the dashboard hand-rolls `embeddedSDKHandler` with Cache-Control but no ETag and no versioned URL (`handlers.go:355-361`) | go-datastar v0.7.0 built exactly this to kill the 24h-stale-client risk (CHANGELOG [0.7.0], `ScriptTagVersioned` entry); nobody in the graph serves the client through it |
| broadcast submodule (fan-out endpoint, replay capacity, hub sharing, heartbeat disable) | Not applicable | Absent from template graph (`go.mod` grep); dashboard fans out on raw go-sse (`pusher.go:107`), preset realtime leg has its own Hub | For the archetype the realtime Hub already owns the endpoint; the fleet adopter story is real: cqrs-htmx v5 uses `broadcast v0.7.0` directly (`cqrs-htmx/setup/go.mod:27`, `setup/sse.go:60` `broadcast.NewBroadcasterFromHub`) |
| MemoryStore / EventStore reconnection replay | Not applicable | No `MemoryStore` or `sse.EventStore` wiring in appkit/dashboard | The dashboard is a state snapshot (full-region patch, `PushOnChangeTTL` self-heal, `pusher.go:216-243`), so replay has nothing to add; event-sourced feeds are adopter territory (see internal/events skeleton) |
| datastartest E2E helpers (Collect, RequireElements, FindSignals, ...) | Not applicable | Not in template graph; template's one handler test is JSON (`internal/api/routes_test.go`) | Nothing in the default binary emits patches an adopter of the *template* needs to assert; the dashboard and go-datastar itself carry their own SSE tests |
| Typed error classification (codes, families, sentinels) | Not applicable | No consumer of `datastar.*` codes in appkit/dashboard/template; the dashboard discards render errors (`pusher.go:203-206` returns ok=false silently) | No template-owned call sites means no error-handling surface; the silent drop is a dashboard-repo observation, noted under Risks |
| HTTP action attribute helpers (GetSSE, PostSSE, ...) | Not applicable | Zero call sites | Attribute strings for authored interactive HTML; the archetype authors no such HTML |
| Wire-format parity (golden-pinned datalines, upstream SDK byte equality) | Fully leveraged | `wire_golden_test.go`; runtime `/health/sse` output matches the pinned format exactly | Inherited correctness: every fleet dashboard patch is format-pinned by the lib's goldens |
| Zero-dep static module (import JS bytes without the protocol library) | Fully leveraged | `templ-components/datastar/go.mod:7` requires *only* `go-datastar/static v0.8.0` (no root); its `version.go` derives the CDN pin from `static.Version1_0_4` | The module split's stated purpose (v0.1.0 changelog) working in production: templ-components vendors the bytes/version with zero protocol-lib weight |

Scoring: 15 rows, 9 Not applicable, A = 6. Fully 3 × 1 + Partially 2 × 0.5 + Missed 1 × 0 = 4.0 → round(100 × 4.0/6) = 67 (moderate).

## Gaps and opportunities

1. **The embedded JS client is in the binary but the dashboard loads the CDN.** What the lib offers: a pinned, sha256-audited DataStar client (`static/static.go:21` Version 1.0.4; `docs/static-js.md`: "Serving whatever CDN a browser page points at reintroduces drift"), already resolved at v0.8.0 in the template graph via templ-components. What the preset does instead: `preset/preset.go:237` returns `[]health.MountOption{health.WithDashboard()}` with zero dashboard options, so `DatastarSrc` stays empty and `view.templ:122` pins the deprecated 1.0.3 CDN alias. Impact: high (every fleet service's `/health` page depends on jsdelivr availability, is CSP-hostile, and runs a client one minor behind the pinned one) × trivial ease (one option, zero new dependencies). Sketch:
   ```go
   // /home/lars/projects/go-appkit/preset/preset.go:232
   func dashboardOpts(noDashboard bool) []health.MountOption {
       if noDashboard {
           return nil
       }
       // dashboard.WithEmbeddedDatastarSDK (go-health-dashboard/options.go:574)
       // serves the pinned bundle at /health/datastar.js and points the
       // page at it: same-origin, no jsdelivr, CSP 'self' + 'unsafe-eval'.
       return []health.MountOption{
           health.WithDashboard(dashboard.WithEmbeddedDatastarSDK()),
       }
   }
   ```
   Routing: **[PRESET-UPSTREAM]**. Paired follow-up that belongs in the go-health-dashboard repo (not this template): its hand-rolled `embeddedSDKHandler` (`handlers.go:350-362`) sets `Cache-Control: max-age=86400` with no ETag/304 and an unversioned URL, the exact 24h-stale-client risk go-datastar v0.7.0's `ScriptHandler` ETag + `ScriptTagVersioned` were built to eliminate (CHANGELOG [0.7.0]); the dashboard should delegate serving to `datastar.ScriptHandler()` (it already imports the root module) or add `ETagFor` + a versioned src.
2. **No working same-origin datastar loop anywhere in the appkit example.** What the lib offers: the full pattern is three moving parts the fleet has already standardized on: `ScriptHandler()` for the client, patches as values, and a broadcast hub. The realtime module documents the datastar seam (`/home/lars/projects/go-appkit/realtime/README.md:48-55` shows `hub.BroadcastPatch(datastar.NewElementsPatch(...))`), and the template's realtime leg ships the endpoint (`GET /events`), but `preset/example/main.go` demonstrates none of it, and go-datastar's own `example/activity-feed/` (CHANGELOG [Unreleased]) is the only runnable reference, living in the lib repo. What the template does instead: nothing, correctly. Impact: medium (this is the fleet's stated direction: cqrs-htmx v5 removed its entire WebSocket surface for SSE/Datastar, CHANGELOG ~line 879 / ADR-0046, and consumes `go-datastar/broadcast v0.7.0` at `setup/sse.go:60`) × high ease (an example page + one mux line + a ticker). Sketch: extend `preset/example/main.go` with `mux.Handle("GET /datastar.js", datastar.ScriptHandler())`, a templ page embedding `datastar.ScriptTagVersioned("/datastar.js")`, and a goroutine doing `hub.BroadcastPatch(datastar.NewElementsPatch(...))`. Routing: **[PRESET-UPSTREAM]**: all adopters copy it, the template stays thin.
3. **Should the template itself demonstrate a datastar endpoint (hello page)?** No. The templ-components review routed the hello-page rewrite NOT-NOW pending a CSS pipeline (`docs/review/libs/templ-components.md`, gap 4); datastar does *not* change that calculus. It is true that datastar mechanics are cheaper than templ-components styling: `ScriptHandler` + a plain-HTML patch target need zero CSS tooling, so a minimal demo would render fine where a templ-components page renders unstyled. But the reason the rewrite was deferred was never CSS alone: the hello page is delete-me scaffold, and a datastar hello endpoint has the same fate plus it puts an interactive UI surface into a domainless archetype, pre-deciding the UI stack for every adopter (the graph deliberately carries both `templ-components/htmx` and the datastar runtime). The preset's realtime leg already provides the transport and gap 2 provides the copyable loop. Routing: **[NOT-NOW + wrong shape for an archetype: no domain to push, scaffold adopters delete, transport already preset-mediated]**.
4. **Root pin drift v0.6.2 → v0.7.0.** See Version currency: the bump is not the template's to make and nothing the dashboard calls changed. Routing: **[NOT-NOW + rides the next go-health-dashboard release, the only direct requirer in the graph]**.

## Should the archetype adopt or wire more?

Default binary: no template-direct adoption, and the one preset-mediated gap is a preset option, not template code. What belongs where: (a) in the default binary, exactly what runs today, dashboard patches over SSE, plus (after gap 1) the self-hosted JS client it should have been serving all along; (b) in appkit's example/docs, the datastar loop (gap 2), because "reactive UI without a JS build step" is the fleet's stated consumer direction and the example is where adopters look first; (c) out of the template: signals, script patches, inbound reads, replay stores, datastartest. All of these acquire call sites only when an adopter's own domain UI exists, at which point they are the adopter's code, not the archetype's. If the owner ever wants an in-template taste without default-binary weight, the established pattern is the `//go:build events` skeleton (`internal/events/events.go`): a `//go:build realtime` handler showing one `hub.BroadcastPatch` call would be the datastar equivalent, but gap 2 makes it redundant, so the honest route is to skip it. The realtime leg itself (APPKIT_REALTIME=on) is already the right shape: opt-in, env-driven, and deliberately zero-coupled to go-datastar through `PatchLike`.

## Version currency

Root: template resolves `go-datastar v0.6.2` (indirect; `go.mod:170`), latest tag v0.7.0 (2026-11-07). The drift contains (CHANGELOG [0.7.0]): `ScriptTagVersioned` cache-busting script tag, exported `ETagFor`, broadcast `WithHeartbeatDisabled` + `NewBroadcasterFromHub` variadic options, datastartest `RequireScriptTagVersion`/`RequireETagForBundle`, the `broadcast/storecontract` package, the embedded JS client bump 1.0.3 → 1.0.4, go-sse v0.6.2 → v0.7.0 across the train, and one BREAKING change (`ScriptHandlerWith(bundle)` drops its dead second parameter). None of it is callable by the dashboard differently today: its entire root-module usage is `ElementsFromTempl` + two options (unchanged), and it never calls `ScriptHandlerWith`. Who pins it: `go-health-dashboard/go.mod:10` is the graph's only direct require of the root (pinned v0.6.2; appkit preset/health/integration carry it as indirect v0.6.2); templ-components requires *only* static (`templ-components/datastar/go.mod:7`), so it can never pull the root forward. The bump therefore rides the next go-health-dashboard release, dragging go-sse v0.7.0 with it (the template currently resolves go-sse v0.6.2). Does v0.7.0 change the dashboard story? No: the browser-visible runtime is decided by `view.templ:122` (deprecated 1.0.3 CDN alias, still pinned at dashboard HEAD) and by the preset passing no dashboard options, not by the root-module version; the JS-1.0.4 half of v0.7.0 is already effectively present in the template's graph via static v0.8.0. static: v0.8.0, current (its sole delta over v0.7.0's static is `f909928`, named version constants + `VersionIsValid`, which templ-components consumed same-day as its #98). `[Unreleased]` at HEAD: the `example/activity-feed/` showcase and a bookkeeping line recording the static v0.8.0 pin; no consumer API change, nothing to pick up. broadcast + datastartest: absent from the graph entirely; latest v0.7.0 each.

## Risks

- **Mixed lockstep generation in the template's graph** (verified, benign today): root v0.6.2 (authored against static v0.6.1, per `git show v0.6.2:go.mod`) resolves with static v0.8.0 because templ-components lifts it. The APIs root touches (`static.Version`, `static.Bytes`) are unchanged in v0.8.0; the template builds, `/health` and `/health/sse` verified working. Still, it is a combination the lib's four-module lockstep discipline (CHANGELOG [0.7.0]; the v0.6.3 root-only cut defect) never tested as a unit; it disappears when the dashboard bumps to v0.7.0.
- **CDN dependency on `/health`** (runtime-verified): jsdelivr for datastar@1.0.3 plus `cdn.tailwindcss.com` for styles; shared finding with `docs/review/libs/templ-components.md` (its Risks section), which deferred the datastar half to this report. Gap 1 removes the jsdelivr half; the Tailwind half needs `WithCSSPath` and is the preset/dashboard's CSS story, out of scope here.
- **Stale-client risk if the embedded SDK is enabled naively**: the dashboard's `embeddedSDKHandler` serves an unversioned URL under `max-age=86400` with no ETag; go-datastar v0.7.0 documents exactly this old-client/new-server skew as the motivation for `ScriptTagVersioned` (CHANGELOG [0.7.0]). Currently moot (option off), becomes live the moment gap 1 lands without the paired dashboard fix.
- **Dashboard swallows patch render errors**: `pusher.go:203-206` drops a failed `ElementsFromTempl` silently (returns ok=false; `broadcast()` ignores it), so a `datastar.templ_render_failed` (Orchestration family) error is never observed anywhere. Not the template's call; noted for the dashboard repo.
- **Deprecated API usage in the graph**: the dashboard pins the deprecated `DatastarVersion1_0_3` alias (templ-components `version.go:36-45`, "renders the 1.0.3 CDN runtime, deliberately NOT the pinned bytes"). No consumer calls go-datastar's own deprecated `DatastarJSVersion` constant. No misuse found beyond that.
- Nothing else: no security-relevant surface in the lib's graph usage (the served JS is the audited upstream bundle; `ScriptHandler`'s nosniff/ETag/HEAD contract is uncalled), and the template itself invokes nothing directly, so template-side misuse risk is structurally zero.

## How to verify

```bash
# Version facts
git -C /home/lars/projects/go-datastar describe --tags        # static/v0.8.0-10-g4fca56a
git -C /home/lars/projects/go-datastar log -1 --format='%h %ci'
git -C /home/lars/projects/go-datastar tag | sort -V | tail -4 # v0.6.1, v0.6.2, v0.6.3, v0.7.0 (static/v0.8.0 sorts earlier)

# Pins in the template graph (both indirect; broadcast/datastartest absent)
rg -n 'go-datastar' /home/lars/projects/go-service-template/go.mod
rg -n 'go-datastar' /home/lars/projects/go-service-template -g '*.go'   # no output: zero template-direct usage

# Who requires what (root's only direct requirer; templ-components pulls static only)
rg -n 'go-datastar' /home/lars/projects/go-health-dashboard/go.mod      # v0.6.2 + static v0.6.1
rg -n 'go-datastar' /home/lars/projects/templ-components/datastar/go.mod # static v0.8.0 only
rg -n 'go-datastar' /home/lars/projects/go-appkit/preset/go.mod         # indirect v0.6.2 + static v0.6.1

# The runtime wiring (preset-mediated)
rg -n 'WithDashboard|NoDashboard' /home/lars/projects/go-appkit/preset/preset.go /home/lars/projects/go-appkit/preset/config.go
rg -n 'dstar\.' /home/lars/projects/go-health-dashboard/pusher.go       # ElementsFromTempl:200, WithModeInner:201, WithSelectorID:202
rg -n 'DatastarVersion1_0_3|DatastarSrc' /home/lars/projects/go-health-dashboard/view.templ  # :122 CDN pin
rg -n 'PatchLike|BroadcastPatch' /home/lars/projects/go-appkit/realtime/hub.go               # structural seam, no import

# Realtime leg is env-gated, off by default
rg -n 'APPKIT_REALTIME' /home/lars/projects/go-appkit/preset/env.go /home/lars/projects/go-appkit/preset/preset.go

# Adopter story: cqrs-htmx v5 is SSE/Datastar-only, consumes broadcast directly
rg -n 'go-datastar' /home/lars/projects/cqrs-htmx/setup/go.mod
rg -n 'NewBroadcasterFromHub' /home/lars/projects/cqrs-htmx/setup/sse.go

# Runtime proof: resolved versions + the CDN-not-embed finding
cd /home/lars/projects/go-service-template && go build -o /tmp/gst-ds ./cmd/app &&
  go version -m /tmp/gst-ds | grep -E 'go-datastar|go-health-dashboard|go-sse'
(APP_ADDR=127.0.0.1:18123 /tmp/gst-ds serve &) ; sleep 2
curl -s http://127.0.0.1:18123/health | grep -o 'jsdelivr[^"]*datastar[^"]*'   # @1.0.3 CDN
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:18123/health/datastar.js  # 404: embed not served
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:18123/events              # 404: realtime off
timeout 5 curl -s -N http://127.0.0.1:18123/health/sse | head -c 200                 # datastar-patch-elements wire format
pkill -f gst-ds
(APP_ADDR=127.0.0.1:18124 APPKIT_REALTIME=on /tmp/gst-ds serve &) ; sleep 2
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:18124/events              # 200 with realtime on
pkill -f gst-ds
```

## Submodule matrix

| Module path | In template graph | How used | Latest tag | Note |
|---|---|---|---|---|
| github.com/larsartmann/go-datastar (root) | yes, indirect v0.6.2 | PRESET-MEDIATED: dashboard `pusher.go:200-202` (`ElementsFromTempl` + 2 options) → SSE patch stream on `/health/sse` | v0.7.0 | Sole direct requirer in the graph is go-health-dashboard; v0.7.0's additions (ScriptTagVersioned, ETagFor, broadcast/storecontract) have zero call sites fleet-graph-wide |
| …/go-datastar/static | yes, indirect v0.8.0 (MVS max over dashboard's v0.6.1, root v0.6.2's v0.6.1, templ-components' v0.8.0) | Bytes linked into every binary via dashboard `handlers.go:359` but never served by default (404); templ-components/datastar uses only the Version constants | v0.8.0 (current) | Zero-dep embed of DataStar client 1.0.4; the module split's purpose (v0.1.0 changelog) is exercised for real by templ-components |
| …/go-datastar/broadcast | no (absent from go.mod) | Fleet adopter instead: cqrs-htmx v5 `setup/sse.go:60` (`NewBroadcasterFromHub`), pinned v0.7.0 | v0.7.0 | Fan-out + replay + heartbeat endpoint; appkit's realtime Hub covers the endpoint role for the template, without replay |
| …/go-datastar/datastartest | no (absent from go.mod) | No consumer in the template graph; go-datastar dogfoods it (`datastartest/e2e_test.go`) | v0.7.0 | Becomes relevant the moment an adopter authors datastar handlers; the template's example handler is JSON and tested with plain httptest |
