# Status — Pareto plan execution sweep (2026-11-24, 20:27 CET)

Session: one continuous run executing
[the fleet-hardening Pareto plan](../planning/2026-11-24_09-05_fleet-hardening-pareto-plan.md)
in rank order. Basis: the plan itself (T-31.x first), TODO_LIST rows 1-31,
go-appkit local checkout `5897476` (origin/master), CI runs 45467001984,
45467980927, 45468380181, 45469274135.

## Verdict in one line

Eleven plan tasks fully executed with evidence, one in progress (T-1.1),
the CI posture moved from 3 to 5 green jobs, both preset defects are now
runtime-reproduced AND filed upstream (#84, #85) — and the auto-commit
daemon cost more debugging time than any single technical problem.

## a) FULLY DONE (with evidence)

| Task   | What landed                                                                                                                                                                                                                                                                                                             | Evidence                                                                                                                                                                                                            |
| ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| T-31.1 | One atomic dprint pass over 23 files (21 audits + fleet status report + AGENTS.md — the plan's file list missed AGENTS.md, caught by `dprint check`)                                                                                                                                                                    | 813 lines reflowed; per-file alphanumerics-only hash comparison vs HEAD: zero content drift                                                                                                                         |
| T-31.2 | Two reflow artifacts repaired at root cause: go-sse.md now quotes the go-get command inside the NOT-NOW tag (nested backticks never rendered as code and were unformattable by dprint — proven with idempotency experiments); go-appkit.md keeps the literal Go struct tag behind the gate's own `format:allow` opt-out | `dprint check` clean; docs-gates annotate PASS                                                                                                                                                                      |
| T-31.3 | Full `buildflow --build-mode full` gate green for the first time since the audit corpus landed                                                                                                                                                                                                                          | 63 steps, 0 failed, EXIT:0 (Dry Run: false)                                                                                                                                                                         |
| T-23.1 | Both preset defects re-verified at go-appkit HEAD; preset/ byte-identical between pinned v0.1.1 and origin/master `5897476`                                                                                                                                                                                             | file:line trace in the scratch evidence note                                                                                                                                                                        |
| T-23.2 | BOTH defects reproduced at runtime against the template's pinned tuple                                                                                                                                                                                                                                                  | strict-env: cross-origin GET → 200 (degraded) vs strict-cfg → 403 ORIGIN_REJECTED; NoDashboard panic captured at go-health v0.10.0 handlers.go:160 with tuple sensitivity (v0.8.1 has no Version route, boots fine) |
| T-23.3 | Both issues filed upstream and verified landed                                                                                                                                                                                                                                                                          | go-appkit #84 (env strict degradation), #85 (NoDashboard panic)                                                                                                                                                     |
| T-12.1 | gitleaks job: full-history scan, pinned v8.30.1 (module path `zricethezav/gitleaks/v8` — the org path is not a module), GOPATH/bin exported                                                                                                                                                                             | 63 commits scanned locally in ~70 ms, zero findings; CI job green                                                                                                                                                   |
| T-13.1 | golangci-lint binary cache (actions/cache v6.1.0, SHA-pinned `55cc834…`), keyed on the pin                                                                                                                                                                                                                              | lint job green                                                                                                                                                                                                      |
| T-18.1 | `-tags events` build + vet in the build job                                                                                                                                                                                                                                                                             | both proven locally first; CI green                                                                                                                                                                                 |
| T-18.2 | templ regen drift check: pinned v0.3.1118 (v0.3.1123 ships only as a binary — proxy-verified), gofmt mirror, stamp line masked from the diff                                                                                                                                                                            | CI green = emitted shape identical between 0.3.1118 and the committed 0.3.1123 output                                                                                                                               |
| T-3.1  | `nix-eval-all-systems` job: `nix flake show --all-systems` evaluates darwin outputs on Linux (~0.3 s, no macOS runner)                                                                                                                                                                                                  | green in CI                                                                                                                                                                                                         |
| T-16.1 | Every command the living docs name inventoried (67 raw hits → classified)                                                                                                                                                                                                                                               | 10 runnable / 4 documented skips / mutating-proven-present                                                                                                                                                          |
| T-16.2 | `scripts/docs-command-smoke.sh` + `checks.<system>.docs-command-smoke` flake check; drift-failure proof (stripping a documented command flips it red)                                                                                                                                                                   | local full run clean; sandbox check green; drift proof exit 1→0 restored                                                                                                                                            |
| T-26.1 | SIX display-replace typos fixed (the snapshot said five; go-daemon.md had two)                                                                                                                                                                                                                                          | fixed commands replay with the documented exit codes; `grep -rn` usages untouched                                                                                                                                   |
| T-2.1  | Rename flow executed exactly per README on a `git archive` copy: zero old-path matches after rewrite                                                                                                                                                                                                                    | `/tmp/dogfood-*`; found one docs gap (cmd/app doc comment `<name>`) → README step 2 fixed                                                                                                                           |
| T-2.2  | Renamed copy: tidy + race suite green, boot probe 7×200 + 404 + drain, OCI image builds as `packages.your-service-image` (attr follows pname; vendorHash unchanged)                                                                                                                                                     | image build EXIT:0                                                                                                                                                                                                  |
| T-17.1 | `scripts/probe.sh`: free-port walk, version-stamp gate, full endpoint matrix, SIGTERM drain with phase assertions                                                                                                                                                                                                       | stamp gate proven twice (stale flake binary; wrong expected rev both fail)                                                                                                                                          |
| T-17.2 | Edge cases: squatted port → `[Infrastructure:server.listen_failed]`; in-flight request → `drain_wait` logged                                                                                                                                                                                                            | both green against result/bin/app; documented in CONTRIBUTING                                                                                                                                                       |
| T-22.1 | `preset/v0.1.2` checked: not tagged (latest v0.1.1, already pinned)                                                                                                                                                                                                                                                     | tag list query                                                                                                                                                                                                      |

Closed TODO rows this session: 2, 16, 17, 23, 31 (row 4 closed earlier
today). TODO_LIST now 28 rows. All closures carry CHANGELOG entries; all
five docs-gates runs this session were 10/10 PASS.

## b) PARTIALLY DONE

- **T-1.1 (image-run path)**: podman 6.1.4 from nixpkgs verified working
  rootless (overlay driver, pasta networking, `podman info` clean). The
  image builds as a nix2container JSON spec (`image-app.json`), and
  `apps.app-image-load` resolves to a `copy-to-docker-daemon` binary —
  this machine has no docker daemon, so the load path needs either
  `skopeo copy` (in nixpkgs) reading the spec or `podman load` on a
  converted tarball. Decision not yet recorded in the living docs.
- **CI hardening batch**: functionally complete (5/5 jobs green), but the
  run history shows two failed pushes before green: gitleaks module path,
  then `gitleaks: command not found` (no setup-go ⇒ GOPATH/bin not on
  PATH), then one transient proxy.golang.org stream error (rerun passed).
- **TODO row 26**: T-26.1 (typos) done; T-26.2 (cqrs-htmx schema) and
  T-26.3 (index errata + provenance stamps) still open, so the row stays.

## c) NOT STARTED

- T-1.2 (boot the image), T-1.3 (`checks.image-smoke` + CI wiring)
- T-19.1/T-19.2 (systemd transient-unit probe + watchdog assertions)
- T-24.1-T-24.3 (upstream preset option passthroughs — now armed with the
  #84/#85 evidence; the probe's POST-200 note flips to 405 when the
  method-guard passthrough lands)
- T-15.1-T-15.3 (tests for cmd/app, internal/app, views — still 0% stmt)
- T-25.1-T-25.4 (README routing box, POST validation example, comment
  drift, pkg/version stamping)
- T-26.2, T-26.3 (row 26 remainder)
- T-27.1-T-27.3 (audit-series mechanical gates), T-28.1-T-28.3 (QC),
  T-29.1/T-29.2 (discoverability), T-30.1-T-30.3 (upstream intake)
- T-5.x, T-6.x (owner decisions), T-7.x-T-9.1 (BuildFlow upstream),
  T-10.x (dprint.json form), T-11.1 (ADR), T-14.1 (precommit),
  T-20.x (doctor/erraudit issues), T-21.x (small debts), T-22.2 (blocked
  on the preset tag)

## d) TOTALLY FUCKED UP (honest list)

1. **The daemon committed a 38 MB binary blob** (`app`, commit af039a1)
   because I built `-o app` into the repo root and a daemon tick swept it.
   Folded away via `git reset --soft` before push — remote history is
   clean, but the blob still lives in local objects and `.gitignore`
   still lacks build artifacts. This is the single worst artifact of the
   session.
2. **Four daemon-absorption folds** (`bf78c83`+`ec36518`→`5b28360`,
   af039a1→`53e6f28`): coherent-work commits had to be re-cut twice,
   once AFTER verification had already passed, burning ~15 minutes.
3. **`nix build --no-link` self-own**: probed `result/bin/app` twice
   believing the flake stamped a wrong rev — `--no-link` never relinks
   `result`; the binary was simply stale. Cost ~10 minutes and one false
   "the stamp gate is broken" moment (it worked perfectly, twice).
4. **Pipe-swallowed exit codes** twice (`nix build | tail; echo $?` reads
   tail's status). Both were caught, but only after confusing output.
5. **docs-command-smoke sandbox took five iterations**: cd into
   /nix/store via dirname($0)/.., then multi-arg `cp` keeping hash-
   prefixed store basenames, then `|| {` at line start breaking the
   structured-attrs parse. Each was found empirically, not predicted.
6. **Repro-first-pass errors**: guessed header names for OriginCheck
   (had to read the source), forgot `SecurityConfig.Enabled` (zero value
   silently disarms the leg — itself a real upstream finding, folded
   into #84), tried POST-405 as an assertion before checking reality
   (probe endpoints are unguarded).
7. **The templ regen drift got daemon-committed raw** (5297176); I
   chased it as breakage before recognizing the output is gofmt-stable
   and canonical. Net effect fine (that commit IS the canonical form),
   but the diagnosis path was lucky, not rigorous.

## e) WHAT WE SHOULD IMPROVE

- **Commit before long verification.** The daemon's tick is minutes; any
  10+ minute verification window risks an absorption fold. This session
  adopted that pattern only after the second fold.
- **Add `.gitignore` entries for build artifacts** (`/app`, `result`,
  `result-*`) — the repo relies on daemon discipline, which just failed.
- **Mechanical counts beat narrative counts**: the snapshot said five
  typos, execution found six; the plan's T-31.1 file list missed
  AGENTS.md. Re-derive every stamped number at execution time (the
  audit runbook already says this — it applies to plans too).
- **Verify assertions against reality before encoding them** (the POST
  405 assumption) — verify-before-filing's spirit applies to test
  expectations.
- **Prefer explicit exit capture over pipes** for any gate command.
- **Record the nix-sandbox cp gotcha in AGENTS.md** (store basenames on
  multi-arg cp; `|| {` line-start parse failure under structured attrs)
  — five iterations of rediscovery is four too many. Not yet written.
- **The daemon should never own provenance-critical commits.** Guardrail
  5 exists and worked, but it cost real time; a pre-verification commit
  makes the guardrail cheap instead of reactive.

## f) NEXT (ranked, ~50)

1. Record the T-1.1 decision (podman-from-nix + skopeo copy path) in AGENTS + TODO row 1
2. T-1.2: convert/load the nix2container JSON into podman (`skopeo copy` from the spec or a docker-archive derivation), boot, probe matrix, SIGTERM drain
3. T-1.3: `checks.image-smoke` flake check + CI job wiring
4. Purge the 38 MB blob from local objects (`git gc --prune` after confirming ref independence) + add `/app`, `/result*` to .gitignore
5. T-26.2: bring cqrs-htmx.md back to the series schema (heading 2, canonical status tokens, no body em dashes)
6. T-26.3: index errata (finding-2 Fix callout = WithVersion stamp, finding 4, Method sentence) + provenance stamps → close row 26
7. T-19.1: systemd-run transient unit from the Nix binary; record READY in journal
8. T-19.2: watchdog pings + STOPPING assertions → close row 19
9. T-15.1: cmd/app CLI test (verbs registered, serve documented)
10. T-15.2: internal/app config test (defaults, env override, Rejection path)
11. T-15.3: views test (version interpolated, mounted at / only)
12. T-25.1: README "service or web app?" routing box + adopter pointers
13. T-25.2: POST validation example + rendered-error-shape test
14. T-25.3: events/nolint comment drift + cmdguard contract test
15. T-25.4: pkg/version vs ldflags decision + test
16. T-24.1: upstream HealthOptions passthrough + the #85 WithVersion stamp fix + NoDashboard boot test
17. T-24.2: DashboardOptions passthrough (+ embedded SDK test)
18. T-24.3: HubOptions + settle the SSE/WriteTimeout pairing
19. Flip probe.sh POST /healthz expectation to 405 once the method-guard passthrough lands
20. T-27.1: score reconciliation script (inventory vs score tables)
21. T-27.2: citation sweep over the ~1,116 path:line tokens
22. T-27.3: verify-block conformance lints (the rg trap class becomes mechanical)
23. T-28.1-T-28.3: independent QC batches over all 21 reports
24. T-29.1: markdown index from report headers + applicable-row counts
25. T-29.2: glossary entries + CHANGELOG line + screenshot
26. T-30.1: group upstream findings by owning repo
27. T-30.2/T-30.3: verify + file upstream batches A/B
28. T-5.1/T-5.2: publish-path owner decision + wiring
29. T-6.1/T-6.2: Go-floor owner ruling + application
30. T-7.1/T-7.2: reproduce `.dockerignore` regeneration, file the BuildFlow issue
31. T-8.1: positive `no-dockerfile` gate proposal upstream
32. T-9.1: BuildFlow's analyzer Go pin vs workspace floor (the doctor warning is live: binary go1.27.3 vs floor 1.27.4)
33. T-10.1/T-10.2: dprint.json committed form (remote URLs vs bundle) + regeneration-proof
34. T-11.1: Nix-OCI ADR (decision + reopen conditions)
35. T-14.1: pre-commit hook story for fresh clones
36. T-20.1: doctor-scoping issue (28 checks for a Go-only repo)
37. T-20.2: erraudit vocabulary issue
38. T-21.1: isolate `nix-hash-fix` (it failed 14/14 AGAIN in this session's full gate — the exclusion decision is overdue)
39. T-21.2: the buildflow state DB (1.10 GB in this session's gate log, up from 1.06)
40. T-21.3: small debts (APP_LOG_LEVEL probe, buildflow upgrade — binary-freshness warning says HEAD is ahead, one --profile-io pass)
41. T-22.2: stamp ritual the day preset/v0.1.2 tags
42. AGENTS gotcha: nix-sandbox store-path cp basenames (from this session)
43. AGENTS gotcha: never `go build -o <binary>` into the repo root (daemon blob risk)
44. AGENTS gotcha: `nix build --no-link` does not relink `result/`
45. Consider wiring probe.sh into docs-command-smoke's RUN_SAFE list or the gate
46. FlakeHub auth annotation on nix-image (advisory, observed twice) — decide investigate/ignore and record
47. templ generator/runtime alignment note: committed views carry 0.3.1123 shape while go.mod pins the runtime at v0.3.1100 — next appkit train should move both
48. Extend the README rename proof (step 5) with "run scripts/probe.sh on the renamed copy"
49. Re-run the library-deep-dive Fleet-Runs runbook compliance note into the audit index once T-27.x gates land
50. Close the session-loop item: the two failed CI pushes deserve a CHANGELOG line recording the failure classes (module path, PATH) so the next CI change has the pattern

## g) Questions for the owner

1. **Publish path (T-5.1):** should the template push `app-image` to
   `ghcr.io/larsartmann/app` from CI on master, keep a manual
   skopeo/podman flow, or treat the image as build-only (no registry)
   until the first real adopter? This gates T-5.2 and part of the
   publish story in ROADMAP.
2. **Go floor ruling (T-6.1):** the floor is 1.27.4 while nixpkgs'
   go_1_27 is 1.27.3 and the BuildFlow binary itself is compiled with
   1.27.3 (doctor warns every run). Keep the floor above nixpkgs (the
   flake builds the tarball toolchain — current posture), or drop the
   floor to match nixpkgs and quiet three warnings?
3. **Audit-series QC depth (T-28.x):** run the per-report QC as
   dispatched subagents per the Fleet-Runs runbook (heavier, more
   independent), or inline this session (faster, less independent)? The
   2026-11-23 run skipped the runbook and paid for it, so I default to
   the runbook unless you want speed over independence here.
