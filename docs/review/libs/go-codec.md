# go-codec: utilization review (go-service-template)

| Reviewed | 2026-11-23 |
|---|---|
| Library | github.com/larsartmann/go-codec (single module, no submodules) |
| Version audited | v0.3.4 (8d7a274, 2026-11-23) |
| Template pin | v0.3.3 (indirect via go-appkit/httpx v0.2.0 and go-appkit/cqrs v0.9.0) |
| Latest tag | v0.3.4 (HEAD is exactly the tag; nothing unreleased beyond it) |
| Adoption score | 25/100 (low) - 2 of 4 applicable capabilities leveraged, both partially |
| Verdict | The default binary executes zero go-codec code: the JSON path (httpx.ResultHandler) serializes with stdlib encoding/json/v2 directly, and the one real consumer surface (the build-gated events skeleton, CBOR payloads via go-cqrs-lite) is off by design. |

## Verdict

Not used to the max, and it mostly cannot be: go-codec is an event-sourcing serialization core (CBOR/JSON/raw payloads for event stores, signing, snapshots), while the archetype is a JSON-first service with no domain and its events leg deliberately build-gated off. The template's actual JSON bytes never touch go-codec: `GET /api/status` returns through `httpx.ResultHandler`, whose happy path marshals with stdlib `encoding/json/v2` `json.MarshalWrite` (appkit httpx/result.go:4, 83) and hardcodes `Content-Type: application/json` (result.go:78). What the template does inherit is the compiled-in seam: httpx (imported directly, routes.go:9) ships the content-negotiation battery B5 built on go-codec (`RequestCodec`/`ResponseCodec` via `codec.ForEncoding`, appkit httpx/negotiate.go:8, 218, 325), and the build-gated events skeleton inherits CBOR payload encoding through go-cqrs-lite's `event.DefaultCodec = codec.CBORCodec{}` (go-cqrs-lite event/v4/codec.go:28). "Max" for this repo is narrow: (a) demonstrate a POST/PUT body through the blessed decode path so adopters learn the one codec-adjacent thing every service writes, and (b) leave dual-format negotiation as an appkit-level concern until an adopter needs CBOR. Neither gap is the template's fault; the layer is correctly invisible in a thin composition root.

## What the template uses today

- GRAPH-ONLY (default binary): `github.com/larsartmann/go-codec v0.3.3 // indirect` (go-service-template go.mod:71). Module-graph requirement edges: `go-appkit/httpx v0.2.0 -> go-codec v0.3.3` (httpx/go.mod:7, a direct require there) and `go-appkit/cqrs v0.9.0 -> go-codec v0.3.3` (cqrs/go.mod:53, indirect there through go-cqrs-lite). The code IS compiled into the default binary (package httpx, imported at routes.go:9, contains negotiate.go), but graph presence plus dead-compiled functions is not runtime usage: no template route calls it.
- TEMPLATE-DIRECT: nothing. `grep -rn 'larsartmann/go-codec'` over all template `*.go` returns empty; none of the 7 files import it.
- Trace of the /api/status response path (the question answered literally): `internal/api/routes.go:25` wraps the handler in `httpx.ResultHandler` (appkit httpx/result.go:48); nil error and no direct write goes to `writeResult` (result.go:64, 71), which sets `Content-Type: application/json` (result.go:78) and calls stdlib `json.MarshalWrite` from `encoding/json/v2` (result.go:4, 83). Plain stdlib, no go-codec, no content negotiation, no DisallowUnknownFields (it is a GET with no body). The template's own test decodes the response with stdlib `json.Unmarshal` (internal/api/routes_test.go:31).
- PRESET-MEDIATED / APPKIT-MEDIATED seam (available to every adopter, uncalled here): httpx battery B5, `Negotiate` (appkit httpx/negotiate.go:35), `RequestCodec` (negotiate.go:213, resolves `codec.ForEncoding` at :218; empty Content-Type defaults to JSON at :339-341; anything else yields `ErrUnsupportedMediaType`, a classified Rejection with HTTP 415, negotiate.go:186-198), and `ResponseCodec` (negotiate.go:239, q-ranking with tie preferring CBOR, via `codecForEncoding`/`codec.ForEncoding` at :324-333). Documented as "the encode seam built on the family go-codec" (httpx/doc.go:44; httpx/README.md:143-150, "the composition-mission ruling: build the encode boundary on the family codec"). The preset module itself never requires go-codec (preset/go.mod, root go-appkit/go.mod, realtime, security: no match; the only appkit importers are httpx/negotiate.go:8 and its test).
- TEMPLATE-DIRECT, build-gated (the one place go-codec would actually run): `internal/events/events.go:1` `//go:build events`, `:31` `cqrs.NewEventService(cqrs.EventConfig{DSN: "events.db", DLQ: ...})`. When enabled, created events encode payloads via go-cqrs-lite's `event.DefaultCodec codec.Codec = codec.CBORCodec{}` (go-cqrs-lite event/v4/codec.go:28; go-codec imported at event/v4/codec.go:7, event.go:8, options.go:7, reconstruct.go:7, asrecord.go:4, base64.go:3). Default binary: zero event-sourcing weight, zero go-codec execution.
- Request-decode helper status: httpx DOES expose one, `ResultHandlerWithValidation[B, T]` (appkit httpx/bind.go:58), with a 1 MiB body cap (bind.go:15), classified `bind.*` Rejection codes (bind.go:18-23), and an optional post-decode `Validator` hook (bind.go:31-33). It decodes with stdlib `encoding/json` v1 `json.Unmarshal` (bind.go:4, 104), not go-codec, and ignores Content-Type. The template uses none of it (GET-only example surface).
- Sibling consumer check: go-health-dashboard is ABSENT for this lib (no `larsartmann/go-codec` in its go.mod or any `*.go`; verified by grep). go-cqrs-lite is the heavy consumer (TODO_LIST.md #24: ~57 modules pin it; core consumers are event, signing, encryption, storage/pebble, kv), reached by the template only through appkit/cqrs.

## Capability inventory

| Capability | Status | Evidence | Note |
|---|---|---|---|
| Core `Codec` contract + four implementations (CBORCodec/JSONCodec/CBORCompactCodec/RawCodec) | Missed opportunity | codec.go:56; cbor.go:19; json.go:6; cbor_compact.go:31; raw.go:9 | No Encode/Decode of any go-codec codec executes in the default binary; the sanctioned seam (httpx B5) is one call away and unused |
| `ForEncoding` encoding-to-codec dispatch | Partially used | codec.go:38-53; wired in appkit httpx/negotiate.go:218 (RequestCodec) and :325 (ResponseCodec) | Compiled into every adopter binary via the direct httpx import (routes.go:9); zero executions from the template's own routes (verified negative) |
| HTTP content-negotiation seam (Negotiate/RequestCodec/ResponseCodec, 415 on undecodable Content-Type) | Missed opportunity | appkit httpx/negotiate.go:35, 186-198, 213-226, 239-276; doc.go:44 | The fleet's stated encode boundary ("composition-mission ruling", httpx/README.md:143-150); the JSON-only example teaches nothing about it |
| `JSONCodec` dual-build (encoding/json v1 default, v2 opt-in) | Not applicable | json.go:6; json_compat_v1.go; json_compat_v2.go | HTTP-layer JSON is owned by httpx's stdlib marshal (result.go:83); go-codec's JSONCodec serves event payload serialization, which the default binary has none of |
| `CBORCodec` canonical deterministic CBOR | Partially used | cbor.go:19; inherited as `event.DefaultCodec` (go-cqrs-lite event/v4/codec.go:28) behind the template's build-gated events skeleton (events.go:1, 31) | Runs only under `-tags events` once events are created; deliberate delete-if-CRUD posture, so "partially" means documented scaffold, not default runtime |
| `DeterministicCodec` signing-safety marker | Not applicable | codec.go:86-89 | Consumed by the go-cqrs-lite signing module; an archetype with no domain signs nothing |
| `CBORCompactCodec` unknown-field rejection (schema drift guard) | Not applicable | cbor_compact.go:31; doc.go:12-16 (not wire-compatible with CBORCodec) | A per-event-store decision for new stores only; adopter-specific, and the skeleton correctly leaves the CBORCodec default |
| Zero-allocation paths (`BufferEncoder`, `GetBuffer`/`PutBuffer`, `EncodePooled`) | Not applicable | codec.go:67-69; pool.go:20, 39, 66 | Hot-path batch publishing/snapshot tuning; a template has no hot path |
| Streaming (CBOR encoder/decoder, NDJSON JSON encoder/decoder) | Not applicable | streaming.go:13, 21, 32, 42 | Bulk event batches and line streaming; preset realtime leg uses go-sse, not go-codec (no import in appkit realtime) |
| `TranscodeToJSON` CBOR-to-JSON bridge | Not applicable | transcode.go:37 | Serving JSON from CBOR stores (e.g. SSE delivery); requires an event store, which is build-gated off |
| Self-describing envelopes (`WrapEncode`/`UnwrapDecode`/`DecodeEnvelopeOrLegacy`) | Not applicable | envelope.go:23, 48, 85 | Store envelope format and legacy migration; no store in the archetype |
| Format detection (`AutoDetect`/`AutoDetectDebug`) | Not applicable | autodetect.go:63, 71 | Mixed-format stream diagnostics; no streams, and httpx keys off Content-Type instead |
| Telemetry (`ObservableCodec`, `CodecMetrics`, `MetricsHook`) | Not applicable | observability.go:35, 121, 130, 139, 146 | Nothing codec-shaped executes, so there is nothing to observe; revisit only if the events leg becomes default |
| Classified error taxonomy (sentinels + errorfamily codes, docs/error-codes.md registry) | Not applicable | errors.go:7-30; codec.go:21-24; README "Error Handling" | No codec operation in the default binary can fail into template error handling; httpx defines its own 415 error at negotiate.go:186 |
| COSE Sign1/Encrypt0 structures and helpers | Not applicable | cose.go:77, 97, 168, 185, 235, 251; cose_helpers.go:95, 143 | Primitives for the go-cqrs-lite signing/encryption modules; no domain, no keys |
| Diagnostics and sizing (`Diagnose`, `Size`, shared `CBOREncMode`/`CBORDecMode`, base64-JSON helpers) | Not applicable | cbor.go:71, 76, 104; size.go:4, 17; base64_json.go | Triage and format-decision tooling plus sibling-module infrastructure; no payloads to triage |

Scoring: 16 rows, 12 Not-applicable, A = 4 applicable. Partially used = 0.5 x 2 (ForEncoding, CBORCodec), Missed opportunity = 0 x 2. Score = round(100 x 1.0 / 4) = 25.

## Gaps and opportunities

Ranked by impact x ease, highest first.

1. POST/PUT example through the blessed decode path. The lib-adjacent offer: httpx already ships the complete body path, `ResultHandlerWithValidation` (appkit httpx/bind.go:58) with body cap, `bind.*` Rejection codes, and the `Validator` hook (bind.go:31), sketched in httpx's own doc.go:22-28. The template instead demonstrates only `GET /api/status` (routes.go:25), so every adopter meets the trickiest codec-adjacent footgun (the doc's own warning: json/v2 matches field names case-sensitively, bind.go:50-53; decode with a tagged adapter type, never an untagged domain struct) with no example to copy. Impact: high (request bodies are the one serialization thing every adopter writes); ease: high (~25 lines + one test). Sketch:

   ```go
   type echoRequest struct {
       Message string `json:"message"`
   }

   func (e *echoRequest) Validate() error {
       if e.Message == "" {
           return errorfamily.Newf(errorfamily.Rejection, "api.echo_empty", "message is required")
       }
       return nil
   }

   mux.Handle("POST /api/echo", httpx.ResultHandlerWithValidation(
       func(_ *httpx.Context, in echoRequest) (*echoResponse, error) {
           return &echoResponse{Reply: in.Message}, nil
       },
   ))
   ```

   Tag [TEMPLATE]. Honest caveat: this demonstrates httpx, not go-codec; the decode path is stdlib JSON. That is itself the finding: the fleet's blessed JSON body path does not run on go-codec, and the example should teach the blessed path that exists.
2. A negotiated result handler for dual-format APIs. Offer: `ResponseCodec` picks JSON vs CBOR from Accept (negotiate.go:239-276) but nothing in httpx composes it with `ResultHandler`, whose happy path is hardcoded JSON (result.go:78-83). Adopters wanting CBOR APIs must hand-roll the write and lose the (T, error) contract. A `NegotiatedResultHandler` (or a ResultHandler option) that routes `writeResult` through `ResponseCodec(r, reqCodec)` and sets `Vary: Accept` (the documented contract, negotiate.go:234-235) would make the go-codec seam reachable from the same one-liner. Impact: moderate (only services that actually serve CBOR); ease: moderate (appkit change plus tests). Tag [PRESET-UPSTREAM]: all adopters benefit, template stays thin, and it is where the composition-mission ruling already lives.
3. Version bump v0.3.3 to v0.3.4. The drift is 8 chore commits, 8 files, zero `.go` changes (`git diff --stat v0.3.3 v0.3.4`: ci.yml, release.yml, .golangci.yml, CHANGELOG.md, flake.lock, flake.nix, go.mod, go.sum). The only graph-visible moves are `fxamacker/cbor/v2 v2.9.6 -> v2.10.0` (already satisfied: the template resolves cbor v2.10.0 via `go-appkit/cqrs v0.9.0`, `go mod graph` edge `go-appkit/cqrs@v0.9.0 github.com/fxamacker/cbor/v2@v2.10.0`, while go-codec v0.3.3 itself requires v2.9.6) and the go directive floor `1.27.2 -> 1.27` (below the template's 1.27.4, so no effect). Tag [NOT-NOW: the pin is indirect, owned by appkit httpx (httpx/go.mod:7) and appkit cqrs (cqrs/go.mod:53); the local go-cqrs-lite checkout already requires v0.3.4 (event/v4/go.mod:8, system/v4/go.mod:10), so the next appkit train carries it with zero runtime delta for this template].
4. Codec telemetry on the events leg. Offer: `ObserveCodec` + `WithMetricsHook` (observability.go:146, 121) with documented Prometheus/OTel hook intent. Today nothing codec-shaped runs by default, so there is nothing to observe; if the events leg ever becomes a documented default-on posture, the wiring belongs in appkit cqrs next to its existing `EventConfig.Metrics` (eventservice.go:113-120), not in the template. Tag [NOT-NOW: no codec execution in the default binary; premature until events are real].

## Should the archetype adopt or wire more?

No for the default binary, and that is the correct architectural answer. `httpx.ResultHandler` encapsulates HTTP JSON serialization so completely (marshal, status, no-leak errors, 204-for-nil, direct-write escape hatch, result.go:39-84) that template-local codec code would duplicate the framework and violate the thin-composition-root posture; the brief's own bias says template-local code that the preset could own is a finding against the template. Three buckets:

- Default binary: nothing new. go-codec stays a transitive dependency. The single justified addition is the POST example above, and it is justified precisely because request decoding is something every adopter's own code touches anyway (the same criterion that keeps the GET example in routes.go).
- Docs/examples: one sentence in the template's README or docs pointing at the dual-format seam (`httpx.RequestCodec`/`ResponseCodec`, appkit httpx/README.md:139-150) so adopters who need CBOR know the blessed path exists. Code stays out.
- Must stay out (weight): CBOR tags (`toarray`/`keyasint`), streaming, envelopes, COSE, pooling, transcoding. These are event-sourcing internals; the build-tag-gate pattern (internal/events) is already the correct tool for the one piece that matters, CBOR event payloads, and it is already in place.

## Version currency

Pin v0.3.3 indirect (go.mod:71); latest tag v0.3.4; audited HEAD is exactly v0.3.4 (8d7a274, 2026-11-23 01:08:43 +0100; `git log v0.3.4..HEAD` empty), so there is no unreleased code beyond the tag. What the drift contains: CI workflow sync (golangci-lint raised to v2.15.0 with a wrapcheck exemption matching `- go-error-family.` import paths), flake/lock churn, dependency bumps (cbor v2.9.6 to v2.10.0, go-snaps, sjson, yaml, x/net), and a go.mod floor lowered to two-part `1.27` (the known automated-sweep regression pattern this repo documents in TODO_LIST.md #25). The CHANGELOG documents this work only under a mangled `[Unreleased]` heading (CHANGELOG.md:8-14, the "### Changed" entry run onto one line by the auto-commit daemon); there is no v0.3.4 section, and [Unreleased] holds no code-facing release intent ("Added: Nothing yet", "Fixed: Nothing yet"). Does the template feel any of it: no. Zero Go-file changes, the cbor bump is already outranked by appkit/cqrs, and the floor lowering is below the template's toolchain. The bump is not the template's to make: both requirement edges are appkit-owned (httpx direct, cqrs via go-cqrs-lite), and go-cqrs-lite locally already pins v0.3.4, so the next appkit release train carries it. If current, say so plainly: for runtime purposes the template is current; nothing shipped since v0.3.3 affects it.

## Risks

- No misuse found: the template calls none of the API, so there is nothing to misuse (verified by grep over template `*.go`).
- Adopter footgun when enabling the events leg: `CBORCodec` and `CBORCompactCodec` are not wire-compatible and must not be swapped on an existing store (doc.go:12-16; README "CBOR Compact (Strict)"). The skeleton leaves the safe default (`event.DefaultCodec = codec.CBORCodec{}`).
- `event.DefaultCodec` is a mutable package variable with a set-once-at-startup concurrency contract (go-cqrs-lite event/v4/codec.go:21-28); adopters who swap it must do so before any goroutine creates events.
- `AutoDetect` is explicitly a heuristic for diagnostics, not a security boundary (doc.go:173-175); the v0.3.4 go.mod's two-part `go 1.27` directive and the mangled CHANGELOG heading are repo-hygiene smells on the library side, with no consumer impact (floor is satisfiable by the template's 1.27.4).
- Observed in the mediator, not this lib: httpx binds request bodies with `encoding/json` v1 (bind.go:104) while marshaling responses with `encoding/json/v2` (result.go:83); noted as an appkit asymmetry, no template impact.

## How to verify

```bash
git -C /home/lars/projects/go-codec describe --tags          # v0.3.4
git -C /home/lars/projects/go-codec log -1 --format='%h %ci' # 8d7a274 2026-11-23 01:08:43 +0100
git -C /home/lars/projects/go-codec log --oneline v0.3.4..HEAD         # empty: HEAD is the tag
git -C /home/lars/projects/go-codec diff --stat v0.3.3 v0.3.4          # 8 files, no .go source
find /home/lars/projects/go-codec -name go.mod -not -path '*/.git/*'   # exactly one: single module
grep -n 'larsartmann/go-codec' /home/lars/projects/go-service-template/go.mod   # :71 indirect v0.3.3
grep -rn 'larsartmann/go-codec' /home/lars/projects/go-service-template --include='*.go'  # no matches
grep -rn 'larsartmann/go-codec' /home/lars/projects/go-appkit --include='*.go' | grep -v _test  # only httpx/negotiate.go:8
grep -n 'json.MarshalWrite\|Content-Type' /home/lars/projects/go-appkit/httpx/result.go        # :78, :83 stdlib, not go-codec
grep -n 'ResultHandlerWithValidation\|json.Unmarshal\|maxBindBody' /home/lars/projects/go-appkit/httpx/bind.go  # :58, :104, :15
grep -n 'ForEncoding' /home/lars/projects/go-appkit/httpx/negotiate.go  # :218, :325
grep -n 'DefaultCodec' /home/lars/projects/go-cqrs-lite/event/v4/codec.go  # :28 = codec.CBORCodec{}
grep -n 'go-codec' /home/lars/projects/go-cqrs-lite/event/v4/go.mod /home/lars/projects/go-cqrs-lite/system/v4/go.mod  # both v0.3.4 (local train ahead of appkit pin)
grep -rn 'go-codec' /home/lars/projects/go-health-dashboard/go.mod      # no matches: dashboard absent
cd /home/lars/projects/go-service-template && go mod graph | grep 'larsartmann/go-codec@'  # edges from httpx@v0.2.0 and cqrs@v0.9.0, both v0.3.3
cd /home/lars/projects/go-service-template && go mod graph | grep 'go-appkit/cqrs@v0.9.0 github.com/fxamacker/cbor/v2@'  # v2.10.0 already via cqrs
```

## Submodule matrix

The lib repo is single-module: exactly one go.mod at the repo root (verified by `find`), so the matrix is one row.

| Module path | In template graph | How used | Latest tag | Note |
|---|---|---|---|---|
| github.com/larsartmann/go-codec | Yes, indirect (go.mod:71, via go-appkit/httpx v0.2.0 direct-require and go-appkit/cqrs v0.9.0) | Compiled into the default binary through httpx's negotiation battery (negotiate.go:8), executed nowhere; CBOR payload codec for the build-gated events skeleton via go-cqrs-lite | v0.3.4 | No submodules, no tag prefixes; single semantic version line (v0.1.0 to v0.3.4) |
