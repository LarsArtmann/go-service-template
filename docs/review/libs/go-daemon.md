# go-daemon — utilization review (go-service-template)

| Reviewed | 2026-11-23 |
|---|---|
| Library | github.com/Larsartmann/go-daemon (no submodules) |
| Version audited | v0.4.0-39-g6b9ee1d (6b9ee1d, 2026-11-23 01:10:05 +0100) |
| Template pin | absent (not in go.mod direct or indirect, not in go.sum, zero source imports) |
| Latest tag | v0.4.0 (2026-10-03) |
| Adoption score | 0/100 (low): 0 of 0 applicable capabilities leveraged: all 17 inventory rows are Not applicable by design, so the denominator A is zero and the number is formal, not substantive (see Verdict) |
| Verdict | Do not adopt: this is a unix-socket daemon building-block library (socket lifecycle, sd_notify, negotiation, SSE parse, flight recorder), not a daemonizer, and every capability it offers is either the wrong shape for this archetype or already preset-mediated by go-appkit equivalents |

## Verdict

Not used at all, and that is correct. The name invites the wrong mental model: despite "go-daemon", the library contains no fork, no detach, no pidfiles, no signal handling (verified: `rg -ni 'pidfile|fork|setsid|detach'` over the whole repo matches only a comment about context detachment in flightrecorder.go:325); it is the extracted building-block layer for standalone daemons serving over unix domain sockets, extracted from project-discovery-daemon (README.md:3-7). Against the template's explicit two-path deployment posture, both paths are already fully owned: the systemd path by the preset's `systemd.Install` (go-appkit preset/preset.go:101) plus `systemd/app.service` (`Type=notify`, `WatchdogSec=30s`), the container path by appkit core `Run`'s `signal.NotifyContext(ctx, syscall.SIGINT, syscall.SIGTERM)` (go-appkit service.go:232) feeding the documented drain sequence. "Max" here would mean adopting a redundant second lifecycle owner that double-fires `READY=1`/`STOPPING=1` alongside the preset's spine; the honest maximum for this template is zero adoption plus at most a docs pointer. The lib itself is healthy and has 8 real fleet consumers where it IS the right tool (PapDashboard, bank-sync, go-compliance/hub, go-credentials-store, journal, media-atlas, project-discovery-daemon, nextd), so the fleet-improvement routing matters more than template wiring.

## What the template uses today

- ABSENT: `github.com/LarsArtmann/go-daemon` appears nowhere: `rg -n 'go-daemon' go.mod go.sum` exits 1 (not direct, not indirect, not graph-only), and no template source file imports it (`rg -n 'go-daemon' /home/lars/projects/go-service-template --glob '!docs/**'` exits 1). This is stronger than GRAPH-ONLY: the module is not even in the graph, so there is no "graph presence without runtime wiring" to discount.
- ABSENT at the preset layer too: `rg -rn 'go-daemon' /home/lars/projects/go-appkit --glob '*.go'` and a grep over every go.mod under go-appkit both exit 1. Nothing is preset-mediated from this lib.
- The capabilities go-daemon is known for are, however, all delivered to the template through go-appkit's own parallel implementations (verified, cited so the "already covered" claim is not vibes):
  - sd_notify spine: appkit `systemd.Install` wired by the preset (go-appkit preset/preset.go:101); sends READY post-listen, STOPPING at drain start, watchdog at WatchdogSec/2 (go-appkit systemd/hooks.go:83-133): semantics identical to go-daemon socket.go:283-289 + notify.go. Matches `systemd/app.service` (`Type=notify` + `WatchdogSec=30s`).
  - Container path (PID 1 signals): appkit core `Run` (go-appkit service.go:232) catches SIGINT/SIGTERM and runs the documented drain (service.go:248-257: ready-flip, DrainHooks, drain wait, listener close, ShutdownHooks).
  - Content negotiation: appkit httpx `Negotiate`/`RequestCodec`/`ResponseCodec` (go-appkit httpx/negotiate.go:35,213,239), built on the same family `go-codec` that go-daemon's negotiation.go uses.
  - Flight recording: appkit `flightrecorder` package "integrates github.com/larsartmann/go-flightrecorder" (go-appkit flightrecorder/doc.go:2): the exact same upstream primitive go-daemon wraps (go-daemon go.mod: `go-flightrecorder v0.2.1`).
- Template lifecycle facts this review leans on: `internal/app/service.go:48` builds `appkitpreset.New(...)`, `:64` returns `svc.Run(ctx)`; signals and drain are the framework's, never template code.

## Capability inventory

| Capability | Status | Evidence | Note |
|---|---|---|---|
| Unix-socket server lifecycle (`SocketServer`: stale cleanup, dir creation, 0600 mode, unlink on exit) | Not applicable | go-daemon socket.go:183,237-339 | Template serves TCP `:8080` via the preset listener (internal/app/service.go:48); unix-socket daemons are a fleet shape (8 consumers), not an archetype default |
| Listener-agnostic lifecycle (`NewServer(network, addr)`, `WithListener`) | Not applicable | go-daemon socket.go:150,158 | Would install a second `http.Server` lifecycle owner beside appkit `Service.Start/Run` (go-appkit service.go:226), competing over drain ordering |
| Server options (socket/dir modes, header/idle timeouts, grace period, health path, probe timeout) | Not applicable | go-daemon socket.go:94-156 | Preset `ServiceConfig` owns the equivalents (ShutdownTimeout, DrainDelay; core service.go:242,285) |
| Lifecycle hook contract (`Startup` → `OnListen` → `OnShutdown`) | Not applicable | go-daemon socket.go:213-235 | Appkit spine already provides StartHooks/DrainHooks/ShutdownHooks with test-enforced ordering (core service.go:282-283 and the *hooks_test.go battery) |
| sd_notify readiness/stopping (`NotifyReady`/`NotifyStopping`) | Not applicable | go-daemon notify.go:59,66; socket.go:284,306 | Preset-mediated twin already active: `systemd.Install` (go-appkit preset/preset.go:101); adding go-daemon would double-send READY/STOPPING to the same NOTIFY_SOCKET |
| systemd watchdog (`Watchdog`, `WatchdogInterval`, WatchdogSec/2) | Not applicable | go-daemon notify.go:75,102 | Identical WatchdogSec/2 keepalive shipped by appkit systemd/hooks.go:83-126, paired with `WatchdogSec=30s` in systemd/app.service |
| sd_notify observability (`ReadNotifyCounters`) | Not applicable | go-daemon notify.go:28-57 | Appkit exports the same process-global counters (`systemd.Counters`, go-appkit systemd/notify.go:48) but does not yet register them as metrics (see Gaps #3) |
| Graceful drain with grace period | Not applicable | go-daemon socket.go:304-324 | Core `Shutdown` is strictly richer for this template's shape (ready-flip → DrainHooks → DrainDelay → close → ShutdownHooks, each phase logged; go-appkit service.go:248-297) |
| systemd supervision guidance (docs/supervision.md: unit shape, resource priority, NixOS, hardening) | Not applicable | go-daemon docs/supervision.md:10-113 | Template already ships the convergent unit (systemd/app.service: Type=notify, WatchdogSec=30s, Restart=on-failure, same hardening block) via the preset spine |
| Unix-socket HTTP clients (`NewHTTPClient`/`NewHTTPClientNoTimeout`) | Not applicable | go-daemon transport.go:25,41 | Only needed by processes that CALL a fleet socket daemon (nextd/client.go, pdd); an HTTP service archetype has no such client by default |
| Socket liveness/stale probes (`IsSocketAlive`, `CleanStaleSocket`, `WithHealthPath`) | Not applicable | go-daemon socket.go:394-430 | No unix socket exists in the template to probe |
| JSON/CBOR content negotiation (`ResolveRequestCodec`/`ResolveResponseCodec`/`CodecForContentType`/`ContentTypeFor`) | Not applicable | go-daemon negotiation.go:73-243 | Encode seam belongs to appkit httpx, which ships its own Accept engine on the same go-codec (httpx/negotiate.go:35,213,239): and appkit's can express 406, which go-daemon's ROADMAP lists as an open question its signature cannot express (ROADMAP.md:54-57) |
| Pooled response writers + `Vary: Accept` (`WriteEncoded`/`WriteJSON`/`WriteErrorf`) | Not applicable | go-daemon write.go:29-70 | Handler output contract is `httpx.ResultHandler` (internal/api/routes.go), which writes `application/json` via encoding/json/v2 (go-appkit httpx/result.go:78-83); error rendering is the classified-error/error-pages spine |
| JSONv2Codec + injectable codecs (`WithJSONCodec`/`WithCBORCodec`): unreleased | Not applicable | go-daemon jsonv2.go:30-70; CHANGELOG [Unreleased]:10-20 | Marginal even fleet-wide: httpx already writes through encoding/json/v2 natively (result.go:4) |
| WHATWG SSE framing (`ParseSSEData`, conformance-corpus-pinned) | Not applicable | go-daemon sse.go:42-99 | Client-side framing parser for CONSUMING SSE streams (media-atlas syncstream); the template's realtime leg is server-push and preset-owned, and the default binary has no SSE consumer |
| FlightRecorder (slow-request auto-trigger, Prometheus metrics, rate-limited TraceHandler) | Not applicable | go-daemon flightrecorder.go:165-410 | Available to adopters through appkit/flightrecorder wrapping the same upstream go-flightrecorder (go-appkit flightrecorder/doc.go:2), mounted on `svc.Mux`: no reason to take it via go-daemon |
| Testing utilities (lifecycle contract tests, negotiation golden matrix + fuzz, WPT conformance corpus, runnable godoc examples) | Not applicable | go-daemon CHANGELOG 0.2.0:157-183, 0.3.0:80-83 | These are the lib's own gates, not exported testkit for consumers; the template's test surface is httpxtest/testkit via the preset |

All 17 rows Not applicable, therefore A = 17 − 17 = 0, Σ = 0, and the rubric's `round(100 × Σ / A)` has a zero denominator. Recorded as 0/100 (low) for schema compliance with this derivation stated explicitly.

## Gaps and opportunities

Ranked by impact × ease.

1. **Converge the duplicated sd_notify engine (go-daemon notify.go vs go-appkit systemd/notify.go + hooks.go).** Both wrap `coreos/go-systemd/v22`, both send READY/STOPPING, both keep the watchdog at WatchdogSec/2, both maintain process-global atomic counters (go-daemon notify.go:19-57 vs go-appkit systemd/notify.go:19-55,39-44). The owner's collective-improvement constraint is directly violated by this pair: a fix like go-daemon's open "Deferrable READY" item (TODO_LIST.md:59, consumer feedback F3) must be implemented twice, and appkit's fixed post-listen READY (hooks.go:98) has the same limitation. What the template does instead: nothing, it inherits the appkit side via preset.go:101. Impact high (every preset adopter plus 8 go-daemon consumers), ease M. Routing: [LIB-UPSTREAM]: pick one owner for the notify primitive (or extract into a shared base) and have the other consume it; the template stays thin either way.
2. **Converge the duplicated Accept-negotiation engine (go-daemon negotiation.go vs go-appkit httpx/negotiate.go).** Two q-value/Accept parsers over the same `go-codec` family module. go-daemon's own ROADMAP pre-agreed the trigger: "extracting the pure media-type ↔ codec mapping into go-codec when a second transport consumer appears" (ROADMAP.md:41-43): that second consumer now exists (appkit httpx), so the trigger has fired. Note the appkit variant is ahead on one axis: it can answer 406 on unsatisfiable Accept (httpx/negotiate.go:28-31) while go-daemon's ROADMAP lists that as an open question its current signature cannot express (ROADMAP.md:54-57). What the template does instead: handlers get JSON-only output through `httpx.ResultHandler` (internal/api/routes.go). Impact high (fleet-wide codec correctness lands once), ease M. Routing: [LIB-UPSTREAM].
3. **Surface the sd_notify counters the template already collects.** Appkit exports `systemd.Counters()` (systemd/notify.go:48) but nothing in appkit or the preset registers them as Prometheus metrics (verified: the only preset reference to the systemd package is `Install` at preset.go:101). go-daemon's `ReadNotifyCounters` exists precisely for this and its first consumer uses it for `bank_sync_sd_notify_*` metrics (CHANGELOG 0.4.0:51-54). Impact medium (operability of the watchdog spine every bare-metal adopter already runs; a frozen WatchdogPings counter is the "process stopped making progress" alarm, per appkit systemd/notify.go:16-18), ease S. Routing: [PRESET-UPSTREAM]: register a small collector in the preset's metrics registry; the template stays thin and all adopters benefit.
4. **Docs pointer for daemon-shaped adopters.** An adopter who clones this template to build a fleet-style companion daemon (unix socket, `sd_notify`, negotiated JSON/CBOR, SSE consumption) should be told in one paragraph that go-daemon plus its docs/supervision.md unit recipe is the fleet answer, the same way internal/events documents the events skeleton without wiring it. Impact low-medium (only daemon-shaped adopters), ease XS. Routing: [TEMPLATE] (documentation only, no binary weight, no second lifecycle owner).

Deliberate non-adoption of everything else: [NOT-NOW]: SocketServer/NewServer would create a competing `http.Server` lifecycle beside appkit `Service.Run` (double READY/STOPPING, two drain sequencers); `Start` installs no signal handlers of its own (socket.go:304-324, context-driven), so it adds nothing on the container PID 1 path that core `Run`'s NotifyContext does not already own; negotiation belongs to the httpx encode seam; SSE parse and unix clients are adopter-specific; flight recording is already reachable through appkit/flightrecorder on the same upstream primitive.

## Should the archetype adopt or wire more?

No. Default binary: nothing from this library, now or later; the deployment posture is explicitly two-path and both paths are contractual (systemd unit `Type=notify` + preset sd_notify spine; OCI container + preset signal/drain spine), leaving no lifecycle surface for a second owner. Docs/examples: the one-paragraph pointer from Gaps #4 is the entire justified footprint. Must stay out of the default binary: `SocketServer`/`NewServer`/`WithListener` (lifecycle conflict), the negotiation/writer family (httpx seam), `ParseSSEData` (no SSE consumer in the default build), `FlightRecorder` (reachable via appkit's wrapper over the same upstream). Even the build-tag-gate pattern (internal/events) has no role here: that pattern is for optional in-process weight, whereas go-daemon's value is an alternative process shape (standalone socket daemon), which is a different repo, not a gated leg. The 8 fleet consumers (PapDashboard, bank-sync, go-compliance/hub, go-credentials-store, journal, media-atlas, project-discovery-daemon, nextd) are exactly that shape and validate the library on its home turf; the template is not that shape.

## Version currency

Template pin: absent, so there is no bump to make and nothing rides the next preset train. For the record: latest tag v0.4.0 (2026-10-03); HEAD is 39 commits ahead, of which exactly two are substantive: c9bcc7d (2026-10-04, "Add json/v2-native write path with injectable codecs", the CHANGELOG [Unreleased] section: JSONv2Codec + WithJSONCodec/WithCBORCodec) and e2187e7 (docs: bank-sync as first v0.4.0 consumer); the remaining 37 are auto-commit chores, dependency bumps, and flake syncs through 2026-11-23. Commit cadence is alive but maintenance-shaped (one substantive commit in the seven weeks past v0.4.0); two consumers already track post-v0.4.0 pseudo-versions (PapDashboard and go-compliance/hub at v0.4.1-0.20261103232705-e8e1a1fff502). The lib's own TODO_LIST schedules a v0.4.1 re-tag to fix the Go directive floor (published v0.4.0 `.mod` serves `go 1.27.1` while HEAD's go.mod requires `go 1.27.2`; TODO_LIST.md:47): irrelevant to this template either way, since it builds with Go 1.27.4.

## Risks

- Name-collision confusion is the top footgun: sevlyar/go-daemon (MIT, 2.3k stars, active) IS a fork/detach/pidfile daemonizer and dominates search results for "go-daemon"; this library is not (verified: no fork/pidfile/setsid/signal code anywhere in the repo; only context-detachment comments in flightrecorder.go:325,338). The lib's own TODO_LIST records this as an unresolved owner decision (TODO_LIST.md:32). Anyone "adopting go-daemon for daemonization" grabs the wrong tool; conversely, reviewers expecting daemonization from THIS lib mis-judge it.
- Pre-1.0 with no API stability promise: the v0.x-no-promises vs v1-freeze policy is still a BLOCKED owner decision (TODO_LIST.md:31). Not a template risk while absent, a real one for the 8 consumers.
- Misuse hazard if ever adopted alongside the preset: two sd_notify senders on one NOTIFY_SOCKET and two drain sequencers on one listener. The correct pairing for go-daemon is a repo that does NOT use the appkit service spine.
- Release hygiene: the go-directive floor poisoning documented above (v0.4.0 `.mod` floor vs master) is a fleet-wide pin-drift irritant, tracked as a TODO.
- No CVE/deprecation check was performed beyond the repo's own SECURITY.md (supported-versions policy, private reporting channel) and the v0.3.0 full-history trust scan (CHANGELOG 0.3.0:140-151, zero findings). Nothing else UNVERIFIED in this report.

## How to verify

```bash
# Version facts
git -C /home/lars/projects/go-daemon describe --tags        # v0.4.0-39-g6b9ee1d
git -C /home/lars/projects/go-daemon log -1 --format='%h %ci' # 6b9ee1d 2026-11-23 01:10:05 +0100
git -C /home/lars/projects/go-daemon log --oneline v0.4.0..HEAD | wc -l # 39

# Absence from the template (all must exit 1 / no matches)
rg -n 'go-daemon' /home/lars/projects/go-service-template/go.mod /home/lars/projects/go-service-template/go.sum
rg -n 'go-daemon' /home/lars/projects/go-service-template --glob '!docs/**'
rg -rn 'go-daemon' /home/lars/projects/go-appkit --glob '*.go'

# Preset owns the deployment spine
rg -n 'systemd.Install' /home/lars/projects/go-appkit/preset/preset.go            # :101
rg -n 'signal.NotifyContext' /home/lars/projects/go-appkit/service.go             # :232 (SIGINT, SIGTERM)
rg -n 'Counters' /home/lars/projects/go-appkit/systemd/notify.go                  # :48 exported, never metric-registered

# Not a daemonizer (expect zero hits)
rg -ni 'pidfile|fork|setsid|reexec' /home/lars/projects/go-daemon --glob '*.go'
rg -n 'signal\.|NotifyContext' /home/lars/projects/go-daemon --glob '*.go' --glob '!*_test.go'

# Fleet consumers (8, excluding the lib repo itself)
rg -l 'go-daemon' /home/lars/projects --glob go.mod | rg -v '/go-daemon/'

# Single module (expect exactly one path)
find /home/lars/projects/go-daemon -name go.mod -not -path '*/.git/*'
```

## Submodule matrix

| Module path | In template graph | How used | Latest tag | Note |
|---|---|---|---|---|
| github.com/LarsArtmann/go-daemon | No (absent from direct, indirect, and go.sum) | Not used; deployment posture owned by systemd/app.service + preset spine | v0.4.0 | Single module: the only go.mod in the repo is the root one; downstream deps (go-codec, go-flightrecorder, go-sse/sseparse, coreos/go-systemd/v22) are separate repos, not submodules |
