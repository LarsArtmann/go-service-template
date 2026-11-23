# cmdguard — utilization review (go-service-template)

| Reviewed | 2026-11-23 |
|---|---|
| Library | github.com/larsartmann/cmdguard/v5 (+ 7 submodules) |
| Version audited | lint/v0.4.0-37-gf36c61b (f36c61b, 2026-11-23) |
| Template pin | v5.1.0 (direct) |
| Latest tag | v5.1.0 (root module) |
| Adoption score | 50/100 (moderate) — 6.5 of 13 applicable capabilities leveraged |
| Verdict | The thin slice used is used flawlessly (exit codes, batteries, signals all verified live); the breadth is deliberately near-zero because the archetype routes config and lifecycle through go-appkit, which leaves the flagship typed-flag grammar, middleware, and contract-pinning testutil unexercised. |

## Verdict

Not "to the max", and mostly by design. The template uses cmdguard exactly as a service archetype should: one `NewApp` call, one `serve` verb, batteries on, `ExitCode` in `main`, nothing else (all in `/home/lars/projects/go-service-template/cmd/app/main.go`, 66 lines total). Everything it touches was verified live and is correct: doctor prints "2 passed, 0 failed", `version` answers, every error path exits 1 with the error printed exactly once, SIGTERM drains gracefully through cmdguard's default signal handling into the preset's five-phase shutdown. "Max" for this repo would not mean more features (prompts, spinners, output tables are wrong shape for a service); it would mean (a) pinning the machine contract with `testutil.AssertDescribeContract` so scaffold renames cannot silently break the CLI, (b) using `pkg/version` so plain `go build` binaries print a git rev instead of "dev", and (c) documenting the cmdguard-flags-to-appkit-config bridge (`config.WithValues`) that the fleet's own config README designates but the template never builds. cmdguard is purely TEMPLATE-DIRECT here: go-appkit never imports it (comment mentions only, `/home/lars/projects/go-appkit/config/config.go:139`), so nothing rides the preset.

## What the template uses today

- TEMPLATE-DIRECT: `NewApp` one-call construction with a build callback (`cmd/app/main.go:26-53`; implementation `pkg/cmdguard/v5/cli_batteries.go:22-41`, never returns a half-built CLI).
- TEMPLATE-DIRECT: `serve` verb via `NewCommand` + per-command F struct `serveFlags struct{}` (empty on purpose, `cmd/app/main.go:31-44,63-66`), `WithShort` (satisfies v5 strict validation), `WithNoArgs` (verified live: `serve extra-arg` exits 1 with "Unknown command \"extra-arg\" for \"app serve\"").
- TEMPLATE-DIRECT: `WithCLIVersion(app.Version)` (`cmd/app/main.go:51`); auto-registers `version` (`pkg/cmdguard/v5/cli_batteries.go:51-61`). Verified: `app version` prints "app dev" on a plain `go build`, exit 0.
- TEMPLATE-DIRECT: `WithBatteries()` (`cmd/app/main.go:52`), the explicit re-affirm of v5 defaults (README:228-231 calls it a no-op kept for v4-flavored call sites); auto-registers `doctor` (`pkg/cmdguard/v5/cli_batteries.go:63-73`). Verified: "2 passed, 0 failed", exit 0; the two checks are the auto-provided DI services `*internal/app.Config` and `*FlagRegistry`.
- TEMPLATE-DIRECT: exit-code contract. Single `os.Exit(v5.ExitCode(run(...)))` in `main` (`cmd/app/main.go:22`); `ExitCode` maps nil to 0 and honors `ExitCoder` (`pkg/cmdguard/v5/cli_errors_json.go:73-79`). Verified live: exit 1 on unknown command, unknown flag (`serve --addr=:9999`), extra positional, and config rejection (`APP_LOG_LEVEL=bogus` prints "Build service: [rejection:log.level_invalid] ..." once, exits 1). `ExecuteWithArgs` (`cmd/app/main.go:60`) is the README-blessed shape when work wraps the exit (`README.md:166-173`).
- TEMPLATE-DIRECT: default signal handling. cmdguard cancels the handler ctx on SIGINT/SIGTERM; the runFn passes it into `app.Serve` (`cmd/app/main.go:40`, `internal/app/service.go:64`). Verified live: SIGTERM produced the full preset drain log (ready_flip, drain_hooks, drain_wait 5s, listener_close, shutdown_hooks, "graceful shutdown complete ... result=ok"). Note: the raw child exit code was masked by `timeout`'s own 124; result=ok means the handler returned nil, so `ExitCode` is 0, verified by logs, not by direct observation.
- TEMPLATE-DIRECT: hidden `describe` machine contract (free with v5). Verified live: full JSON tree with serve/doctor/version/completion/describe/man; correct pre-transform text (no ANSI).
- TEMPLATE-DIRECT: construction-error path. `NewApp` failures are printed by the template itself (`cmd/app/main.go:54-58`), which is correct: cmdguard owns error display only from `Execute` onward (same pattern as the README Quick Start).
- PRESET-MEDIATED: none. `rg 'cmdguard' /home/lars/projects/go-appkit --glob '*.go'` matches only a comment (`config/config.go:139`, "cmdguard-style flags"); no appkit go.mod requires any cmdguard module.
- GRAPH-ONLY: none beyond the root module. No cmdguard submodule appears anywhere in the template's go.mod. (The indirect `github.com/larsartmann/go-flightrecorder v0.2.1` is a different module from `cmdguard/flightrecorder`, pulled by the appkit cqrs/preset chain.)

## Capability inventory

| Capability | Status | Evidence | Note |
|---|---|---|---|
| Core construction (`NewApp`, `CLI[T]`, atomic registration) | Fully leveraged | `cmd/app/main.go:26-53`; `pkg/cmdguard/v5/cli_batteries.go:22` | Canonical one-call shape, build callback returns first error |
| Per-command F structs + 13-tag flag grammar | Partially used | `cmd/app/main.go:31-44,63-66` | Pattern demonstrated with zero flags; no `flag:` tag exists in the repo (`rg 'flag:"'` finds nothing). Deliberate env-first posture |
| Production batteries (version/doctor/describe/man, strict validation) | Fully leveraged | `cmd/app/main.go:51-52`; verified `doctor` 2/2, `version`, `describe` JSON | `WithBatteries()` is an explicit re-affirm; consumer overrides unused (none needed) |
| Exit-code + print-once error contract | Fully leveraged | `cmd/app/main.go:22,60`; `pkg/cmdguard/v5/cli_errors_json.go:73` | Verified 0/1 on six paths, single fang ERROR box, no CG006 re-print |
| Default signal handling (ctx cancel on SIGINT/SIGTERM) | Fully leveraged | `cmd/app/main.go:40`; verified drain logs | cmdguard cancels, preset drains; no `WithoutSignalHandling` anywhere |
| `describe` machine-readable contract | Partially used | verified live JSON; no test pins it | Works free, but the empty flag grammar means `APP_ADDR`/`APP_LOG_LEVEL` are invisible to the contract; no `testutil.AssertDescribeContract` golden |
| Config file layer (`WithConfigFile`, strict keys, `config explain`, `ConfigKeys`) | Not applicable | `internal/app/service.go:39-41` | Fleet doctrine assigns env+file+default to appkit/config (`go-appkit/config/README.md:53`: "cmdguard stays the flag engine"); cmdguard config files feed root-T flags only and root T registers zero flags. Using both loaders would be drift, not adoption |
| DI scope (`Provide`/`Invoke`/`Shutdown`, doctor health checks) | Partially used | doctor output lists exactly the 2 auto-provided services | Scope is alive and doctor exercises it; no app services registered because the preset owns service lifecycle (`internal/app/service.go:47-65`) |
| Middleware (`Timing`, `Recovery`, `Timeout`, `Context`, `Audit`) | Missed opportunity | `FEATURES.md:226-232`; absent from template | Nothing wraps the serve handler; see gaps for why most of it stays out |
| `Builder` registration (`NewBuilder`/`Add`/`Try`/`Check`) | Missed opportunity | `cmd/app/main.go:45-49` uses `AddCommand` + manual err check | Pays off at N commands; template has 1. Fine today, worth scaffolding only in docs |
| Value types + validate registry (`LogLevel`, `Port`, `Enum`, 10 rules) | Missed opportunity | README:431-511; `internal/app/service.go:33` uses plain string | `APP_LOG_LEVEL` is validated downstream by the preset (rejection seen live); parse-time validation would need flags the template does not declare |
| Rich output (`OutputTable`, 16 formats) | Not applicable | no data-printing command exists | A service speaks HTTP; its handlers own response encoding (`internal/api/routes.go`) |
| Env tags + `WithEnvPrefix` | Not applicable | `internal/app/service.go:32-33` uses appkit grammar | cmdguard env fallback binds only to `flag:`-tagged fields; there are none, so the two env systems cannot collide |
| `testutil` contract harness (`AssertDescribeContract`, `DescribeContractFromBinary`) | Missed opportunity | README:723-735; template tests cover only `internal/api/routes_test.go` | Highest-value unused capability for an archetype (renames) |
| `pkg/version` VCS stamping | Missed opportunity | `pkg/version/version.go:1-40`; `internal/app/service.go:27` | Plain `go build` prints "app dev" (verified); pkg/version reads `debug.BuildInfo` vcs.revision for free, same module, zero new deps |
| Positional-args policy (`WithNoArgs` family) | Fully leveraged | `cmd/app/main.go:43`; verified exit 1 on extra arg | The v5.1.0 strict variants (`WithStrictPositionalArgs`) unneeded with `WithNoArgs` |

## Gaps and opportunities

1. **Pin the CLI contract with the describe golden harness** [TEMPLATE]. cmdguard ships `testutil.AssertDescribeContract(t, cli, "testdata/describe.json")` exactly for pinning the surface agents drive (README:723-735; SKILL.md "Machine-readable contract"). The template has zero tests over its CLI (`internal/api/routes_test.go` is the only test file), so a scaffold rename that breaks `serve` or drops `WithShort` fails nothing. Impact high (this is the archetype's whole job), ease high. Sketch: extract construction from `run` and pin:

   ```go
   // cmd/app/main_test.go
   func init() { testutil.RegisterUpdateGoldensFlag() }

   func TestDescribeContract(t *testing.T) {
       cli, err := newCLI() // extracted from run(): the NewApp call verbatim
       require.NoError(t, err)
       testutil.AssertDescribeContract(t, cli, "testdata/describe.json")
   }
   ```

2. **Fix the misleading `nolint` comment and document the WithValues bridge** [TEMPLATE]. `cmd/app/main.go:29` says `//nolint:exhaustruct_v5 // env+defaults fill the rest`, but cmdguard fills nothing: `app.Config` carries no `flag:` tags, so the `*app.Config` handed to the handler stays zero-valued and is discarded (`_ *app.Config`, main.go:34). The real filler is `app.Load()` on a different instance (`internal/app/service.go:39-41`). The fleet's designated bridge for the day flags appear is `config.WithValues(map[string]string{"Addr": *addrFlag})` (`go-appkit/config/README.md:53`), and neither `main.go:63-66` ("Add typed flags here when the CLI needs them") nor `Load`'s doc mentions it. An adopter following the comment today gets a flag that parses and silently never reaches the service. Impact medium-high (drift trap for every adopter), ease trivial: one corrected comment in main.go and one line in `Load`'s doc.

3. **Ship the flags-to-WithValues bridge once, for the whole fleet** [PRESET-UPSTREAM]. Every future fleet service pairing cmdguard F structs with appkit/config needs the same reflection loop: walk the F struct, emit `map[string]string{FieldName: value}` for set fields, feed `config.WithValues`. appkit/config already owns the receiving end and the doctrine ("cmdguard stays the flag engine"); a `config.WithStructFlags(v any)`-style helper there (reading `flag:` tags by reflection, no cmdguard import needed) removes gap 2's trap structurally instead of per-adopter. Impact high across the fleet, ease medium. Sketch on the appkit side:

   ```go
   // config: WithStructValues reads cmdguard-style F structs (flag:"name" tags,
   // non-zero fields only) into the flag layer: flag > env > file > default.
   cfg, err := config.Load[Config](config.WithStructValues(serveFlags))
   ```

4. **Use `pkg/version` so plain builds self-identify** [TEMPLATE]. `internal/app/service.go:27` is `var Version = "dev"` plus flake ldflags. cmdguard's `pkg/version` (same root module, zero new deps) resolves ldflags, then `debug.BuildInfo` vcs.revision ("10bd9ac", "10bd9ac-dirty"), then "dev" (`pkg/version/version.go:1-40`). Today AGENTS.md's "version prints the git rev" is true only for the Nix-built binary; a plain `go build ./cmd/app && ./app version` prints "app dev" (verified). Impact medium (adopters debugging non-Nix builds), ease high: `var Version = cgversion.Version` and retarget the flake's `-X` to `github.com/larsartmann/cmdguard/v5/pkg/version.injected`.

5. **Declare real serve flags (e.g. `--addr`)** [NOT-NOW]. Reasons: env-first is the archetype's stated posture (`cmd/app/main.go:63-65`, `internal/app/service.go:36-38`); the WithValues bridge does not exist yet (gap 3), so flags would be dead until it does; and duplicating `APP_ADDR` into two precedence engines invites divergence. Revisit when gap 3 lands.

6. **Adopt cmdguard-lint inside golangci** [NOT-NOW]. cmdguard-lint does not ship as a golangci plugin at all: it is a go-finding/go-linter-sdk tool distributed as a standalone CLI, a library, and a BuildFlow provider (`lint/README.md`). The template's `.golangci.yml` (fleet standard, ~100 linters, no custom-plugin block) therefore cannot run it, and the template does not need it to: the actual gate is `buildflow --build-mode dev` (AGENTS.md), and BuildFlow compiles the provider in via a blank import (`/home/lars/projects/BuildFlow/tools/providers/sdk_imports.go:54`). Verified: standalone `cmdguard-lint lint --dir` over the template exits 0 with zero findings (CG001-CG008 all clean). A golangci plugin would additionally require [LIB-UPSTREAM] work and plugin builds are version-fragile; the BuildFlow route already covers every fleet repo. If non-BuildFlow users ever matter, a one-line CI job `go run github.com/larsartmann/cmdguard/lint/cmd/cmdguard-lint@v0.4.0 lint --dir .` suffices without touching go.mod.

7. **Middleware (Recovery, Timeout) on serve** [NOT-NOW]. TimeoutMiddleware would kill a command designed to block for the process lifetime; RecoveryMiddleware adds little because the handler body is two calls (`app.Load`, `app.Serve`) that return errors, and the preset owns the runtime. Revisit only for future finite verbs (migrate, seed).

8. **CLI-side telemetry/flightrecorder submodules** [NOT-NOW]. A per-command OTel span or a slow-command trace snapshot is the wrong unit for a multi-hour `serve`; HTTP-side tracing and runtime snapshots are the preset's otel leg (env-switched) and appkit's own flightrecorder package respectively. Fits future ops verbs, not this verb.

Minor [LIB-UPSTREAM] note, no template action: `schema/README.md` still shows a `v4` import path in its example while the module is at `schema/v0.1.0`; stale-doc drift worth a fix in the cmdguard repo.

## Should the archetype adopt or wire more?

Default binary: keep exactly what is there, plus gaps 1, 2, and 4 (contract test, comment fix, pkg/version). All three touch files every adopter edits anyway (main.go, service.go, the one test dir), which is the brief's bar for [TEMPLATE]. The config split itself (item 2's ruling): canonical, not misuse. cmdguard's README presents `WithConfigFile` feeding root T (README:613-627), but the fleet's own appkit/config README designates the division of labor for services: "cmdguard stays the flag engine ... pass `config.WithValues`" (`go-appkit/config/README.md:53`). The template is the degenerate case of that pattern (zero flags, so no bridge needed yet); `NewApp` receiving `app.Config{}` violates no contract because fields without `flag:` tags register nothing. The only defect is the comment claiming cmdguard-side filling. Docs/examples: the WithValues bridge snippet belongs in `Load`'s doc comment or the README's scaffold notes once gap 3 exists. Must stay out (weight): prompts, spinner, glamour, telemetry, flightrecorder submodules, rich output, and the events-style build-tag trick is unnecessary here because nothing optional is being added. If the archetype ever grows ops verbs (the taskctl shape: Builder + DI + doctor surfacing real health checks), that is a new scaffold decision, not this template's.

## Version currency

Pin v5.1.0 equals the latest root-module tag, so the template is current. HEAD (f36c61b, 2026-11-23) sits 37 commits past the `lint/v0.4.0` tag and carries, per CHANGELOG `[Unreleased]`: the pristine-help fix (describe/docs now serve the author's original Long/Example instead of transform-styled bytes; the template is unaffected since its help text is plain, verified no ANSI in live describe output), removal of five dead sentinels (`ErrEditorRead/Run/TempFile/Write`, `ErrNilValue`; no runtime behavior change, no caller could have matched them), and repo tooling/docs work (drift tripwires, release gate, website guards). No new consumer-facing core API is unreleased. When a v5.2.0 ships, the bump is the template's to make (direct pin, single line in go.mod); today there is nothing to bump to.

## Risks

No misuse found. Checked and clean: single error print on all failure paths (CG006 clean, verified visually once per error), exit codes 0/1 correct across success, unknown command, unknown flag, extra positional, and config rejection; no stale major (v5); no constructor panics; `WithShort` and `WithCLIVersion` present (CG007/CG008 clean, 0 lint findings). Footguns to know: (a) the `//nolint:exhaustruct_v5 // env+defaults fill the rest` comment on `app.Config{}` (`cmd/app/main.go:29`) is false as written: cmdguard populates nothing, appkit/config populates a different instance, and the handler discards the cmdguard copy; (b) adopters adding flags to `serveFlags` without the `config.WithValues` bridge get flags that parse but never reach the service (silent dead flags); (c) `version` prints "dev" on non-ldflags builds (verified), so "prints the git rev" is build-path-dependent until gap 4; (d) doctor's "2/2" are the auto-provided scaffolding services (`*app.Config`, `*FlagRegistry`), not real health checks: fine for a config-less CLI, but operators should read readiness from the preset's health endpoints, not doctor; (e) the direct SIGTERM exit code was not observed raw (masked by `timeout`'s 124); the drain log's "result=ok" implies nil error and exit 0, marked verified-by-logs.

## How to verify

```bash
# Version facts
git -C /home/lars/projects/cmdguard describe --tags        # lint/v0.4.0-37-gf36c61b
git -C /home/lars/projects/cmdguard log -1 --format='%h %ci' # f36c61b 2026-11-23 ...
git -C /home/lars/projects/cmdguard tag --sort=-creatordate | head -3 # lint/v0.4.0, v5.1.0, v4.3.1

# Usage surface
rg -n 'cmdguard' /home/lars/projects/go-service-template/go.mod       # one direct line, v5.1.0
rg -n 'flag:"' /home/lars/projects/go-service-template --glob '*.go' # no matches (zero cmdguard flag tags)
rg -n 'cmdguard' /home/lars/projects/go-appkit --glob '*.go'         # comment-only (config/config.go:139)
rg -c 'cmdguard' /home/lars/projects/go-service-template/.golangci.yml # no matches (no plugin block)
rg -n 'cmdguard/lint/provider' /home/lars/projects/BuildFlow/tools/providers/sdk_imports.go # line 54

# Live behavior
cd /home/lars/projects/go-service-template && go build -o /tmp/app-audit ./cmd/app
/tmp/app-audit doctor; echo $?          # "2 passed, 0 failed", 0
/tmp/app-audit version; echo $?         # "app dev", 0
/tmp/app-audit frobnicate; echo $?      # styled ERROR once, 1
/tmp/app-audit serve extra-arg; echo $? # 1
/tmp/app-audit serve --addr=:1; echo $? # Unknown flag, 1
APP_LOG_LEVEL=bogus timeout 5 /tmp/app-audit serve; echo $? # rejection log.level_invalid, 1
/tmp/app-audit describe | head -20      # JSON contract incl. serve/doctor/version
APP_ADDR=:18098 timeout -s TERM 8 /tmp/app-audit serve; echo $? # drain logs, "result=ok"; 124 is timeout's own code

# Lint rules (standalone; first run may fetch modules)
cd /home/lars/projects/cmdguard/lint && GOWORK=off go run ./cmd/cmdguard-lint lint --dir /home/lars/projects/go-service-template; echo $? # 0 findings
```

## Submodule matrix

| Module path | In template graph | How used | Latest tag | Note |
|---|---|---|---|---|
| github.com/larsartmann/cmdguard/v5 (root) | yes, direct v5.1.0 | `cmd/app/main.go` only: NewApp, NewCommand, AddCommand, WithShort, WithNoArgs, WithCLIVersion, WithBatteries, ExitCode, ExecuteWithArgs | v5.1.0 | Pin equals latest tag |
| github.com/larsartmann/cmdguard/lint | no (template graph) | Rules run via the BuildFlow gate's compiled-in provider (BuildFlow `tools/providers/sdk_imports.go:54`); standalone run over the template: 0 findings | lint/v0.4.0 | Covered without a template dependency; no golangci-plugin form exists |
| github.com/larsartmann/cmdguard/flightrecorder | no | Absent. The template's indirect `go-flightrecorder v0.2.1` is larsartmann/go-flightrecorder via appkit cqrs/preset, a different module | flightrecorder/v0.2.0 | Slow/error-command snapshots fit finite verbs; the serve verb blocks for the process lifetime; HTTP-side is appkit's flightrecorder package |
| github.com/larsartmann/cmdguard/glamour | no | Absent | glamour/v0.3.0 | Four-line help needs no markdown rendering; relevant to adopters with long docs |
| github.com/larsartmann/cmdguard/prompts | no | Absent | prompts/v0.3.0 | Interactive prompts, wrong shape for a service binary |
| github.com/larsartmann/cmdguard/spinner | no | Absent | spinner/v0.3.0 | Spinner for a blocking serve would spin forever; fits finite verbs |
| github.com/larsartmann/cmdguard/telemetry | no | Absent; service tracing is the preset's env-switched otel leg | telemetry/v0.3.0 | Per-command span is the wrong unit for a multi-hour serve |
| github.com/larsartmann/cmdguard/schema | no | Absent | schema/v0.1.0 | Emits from cmdguard tag grammar; `app.Config` uses appkit/config tags, so FromConfig would emit a near-empty document |
