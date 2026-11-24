# Status — templ decision landed, CI repair in flight, gates green

> Session scope: 2026-11-25 00:00-00:45 CET, continuing the arc whose last
> snapshot is `2026-11-24_23-56_image-boot-proof-ci-red-status.md`. This
> session fixed the two blocked items from that snapshot (docs-gates red on
> the report, buildflow exit 69), confirmed both CI failure modes from the
> run logs, root-caused the templ provenance question, DECIDED the templ
> standardization, and got exactly one step into the CI repair before the
> buildflow templ-generate conflict and the auto-daemon interleaved. The
> report itself now gates 11/11 green and is committed; everything else
> below is status.

## a) FULLY DONE this session

| Item | Evidence |
| ---- | -------- |
| docs-gates red → 11/11 green on the status report | Read `/tmp/dg4.txt`: two unharvested §f items — T-10.2 (generic-token overlap: `prove`/`buildflow` matched 8+ accidental lines) and T-28.2 (missing tokens `t-28.2 8-14`). Added the two documented `<!-- fresh:skip: routed to TODO_LIST row N -->` markers (row 10, row 28). Re-run: freshness + audit-all PASS, full matrix green, rc=0 (`/tmp/dg5.txt`). |
| buildflow `--fix` exit 69 diagnosed and cleared | `/tmp/fix4.txt` tail: `govalid` failed with "go: updates to go.mod needed; to update it: go mod tidy". `go mod tidy` was a NO-OP on the current tree — the 23:57 failure was mid-edit tree state, not real drift. Full dev gate re-ran rc=0 (`/tmp/bf1.txt`). The exit-69-means-step-failure reading is now confirmed; the earlier "unknown command" theory was wrong. |
| Report committed with proper attribution | Folded the daemon's heuristic `99fa162` (which had swallowed the untracked report) plus the marker fix into `7065458` — "docs: status report - image boot-proof, CI red, T-26.2 shipped", Crush footer, clean tree after. |
| Both CI failure modes confirmed verbatim | `gh run view 45478490139 --log-failed`: (a) templ drift — committed `views/hello_templ.go` has the gofmt-grouped import block, 1118 regen emits two separate `import` lines → diff exit 1; (b) `docker load` on the OCI-layout tar printed the ref but did NOT tag it → `Unable to find image 'app:latest'` → "pull access denied for app". Exactly the two blockers diagnosed last session; no surprises. |
| templ v0.3.1123 provenance RESOLVED | `nix-store -q --deriver` + binding queries: `templ-0.3.1123` is a `buildGoModule` build from an untagged source snapshot (`/nix/store/hyzbmjhx4a13z6m2m19jwyaj790kwfsn-source`), version binding literally `0.3.1123`, installed via `/run/current-system/sw`. It is NOT from this flake's nixpkgs pin (0.3.1020), NOT from upstream tags (none exist), and NOT pinnable from this repo — it is system-environment state. This closes §g Q1's factual half: there is no fleet input to name. |
| templ standardization DECIDED and STARTED | Decision: standardize everything on the go-installable, tagged **v0.3.1118** (the only reproducibly installable generator). Executed the regen: `go run github.com/a-h/templ/cmd/templ@v0.3.1118 generate` + gofmt → 8-line diff to the committed 1123-shaped file (grouped import block → two separate imports). That shape is now what `views/hello_templ.go` contains at HEAD (`1b9eef3`), i.e. the committed views are 1118-shaped — the state CI's drift check expects. |
| The buildflow templ-generate re-drift trap DISCOVERED and documented | Ran `buildflow --fix` WITHOUT first excluding `templ-generate`. Its step detected the LOCAL templ v0.3.1123 (`templ> v0.3.1123` in `/tmp/bf2.txt`) and silently regenerated `views/hello_templ.go` back to 1123-shape mid-run, overwriting my 1118 output; the nix step then saw a dirty views file; rc=69 again. The auto-daemon then committed the (net-correct) 1118-shaped file as heuristic `1b9eef3`. Lesson locked: in this repo, buildflow's templ-generate must be excluded before any formatter run until the local binary is repinned. |

## b) PARTIALLY DONE

**CI repair (the arc's current blocker, G1 red since `a310619`).**
Decision + regen are in; execution is ~40%:

1. **DONE:** failure modes confirmed from run logs; templ generator pinned-by-decision to v0.3.1118; committed views regenerated to the 1118 shape (at HEAD via `1b9eef3`).
2. **NOT DONE (ordered):**
   - Fold `1b9eef3` (daemon heuristic message, correct content) into a properly-messaged templ-standardization commit.
   - Exclude `templ-generate` in `.buildflow.yml` (the file is `.buildflow.yml`, not `.yaml`) so the local 0.3.1123 binary stops re-drifting committed views on every `buildflow --fix`.
   - Add the `skopeo copy oci:result/layout docker-archive:/tmp/app.tar:app:latest` step to `ci.yml`'s nix-image job (nix shell stock skopeo; reading `oci:` needs no nix transport; /var/tmp staging is fine on runners) and point the smoke step at the tar.
   - Add the `inspect --type image` existence guard to `scripts/image-smoke.sh` right after REF parse, so "printed but not tagged" fails with a one-glance diagnosis instead of pull-denied.
   - Local re-proofs: CI drift sequence zero-diff at HEAD; archive check rebuild; smoke on layout (podman); converted-tar load (podman accepts docker-archive); stamp-drift proof.
   - Push; watch the successor of run 45478490139 go green.

## c) NOT STARTED

Everything past CI repair — untouched this session by design (report first,
then the owner's halt): blob purge, T-26.3 index errata, T-19.x systemd probe,
T-15.x tests, T-25.x README batch, T-24.x upstream passthroughs, T-27.x-29.x
series gates/QC/extras, T-30.x upstream intake, the T-5/6/10/14 decision rows,
T-7/8/9/20 BuildFlow+doctor issues, T-11/21 ADR+debts. The full ordered queue
is §f below — identical in substance to the previous report's §f, updated only
where this session changed the facts.

## d) TOTALLY FUCKED UP this session

1. **Ran `buildflow --fix` mid-templ-work without excluding templ-generate first.**
   The conflict was predictable (I had just proven the local binary is 0.3.1123
   and CI pins 0.3.1118) and it cost a second rc=69, tree churn, and — worse —
   the auto-daemon tick landing inside the churn window, swallowing the regen as
   `1b9eef3` with a garbage message. That is the fifth-plus daemon swallow in
   this arc and the second one that landed INSIDE a formatter run I chose to
   start. The order should have been: exclude templ-generate in config → commit
   → then any formatter.
2. **Master CI is still red while local commits stack on top.** `a310619` broke
   G1 last session; this session added `7065458` + `1b9eef3` on top without a
   push. Nothing new is broken, but the fix latency grows: every hour the repair
   is not pushed, the red run's successor gets more stale-clone risk. The right
   call was: land the two-line CI fixes (skip + skopeo step + guard) BEFORE the
   report polish, not after.
3. **Provenance query spilled megabytes of binary garbage into the session.**
   The `nix derivation show | jq` pipe assumed an object shape and errored
   (`keys cannot be applied to: null`), then a bare dump of the .drv emitted the
   whole binary ATt mapping into output before the targeted
   `nix-store -q --binding src/version` form worked. Wasted context, zero
   information gain from the garbage. One `--binding` query would have sufficed
   from the start.
4. **The freshness-marker ritual needed manual gate-output archaeology again.**
   Two §f items (T-10.2, T-28.2) went unmarked in the previous report and only
   surfaced as gate failures — the pattern has now bitten in three consecutive
   reports. The durable fix (marker every §f item at write time) was applied to
   the previous report's rewrite of this file and is the rule going forward.

## e) WHAT WE SHOULD IMPROVE

1. **Config-first for tool-version conflicts:** before ANY buildflow run in this
   repo, `.buildflow.yml` must exclude templ-generate until the fleet's templ
   binary is pinnable. A version-conflicting generator on PATH is a loaded trap;
   CI is the only version-of-record for generated code.
2. **Commit at every regen boundary:** generated-file changes get committed the
   moment they are verified, before gates or formatters run. The daemon's tick
   is minutes, not hours.
3. **Marker §f items at write time:** every forward-looking item gets its
   `fresh:skip` routing comment (or provable token match) in the same edit that
   writes it. Post-hoc gate repair is the third-time loser.
4. **Fold daemon commits on sight:** `git reset --soft <last-good>` + recommit,
   immediately, every time. Five folded accumulations is history soup.
5. **Targeted nix-store queries:** `--binding`/`--deriver` over derivation
   dumps; jq only on the actual JSON shape, verified with a 1-line sample first.
6. **Read every saved failure output before acting on any of them:** this
   session eventually read dg4/fix4/bf2 before fixing, but only after one
   redundant no-op tidy in between. Batch-read first, then one fix pass.

## f) NEXT 50 (ordered: blockers first, then plan rank)

Unchanged in substance from the previous report's §f (same TODO/ROADMAP
routing), with item 1 updated to this session's facts. Items carry their
routing markers where they were needed for the freshness gate.

1. Finish the templ drift fix: fold the daemon's `1b9eef3` into a proper
   templ-standardization commit; add the `.buildflow.yml` templ-generate skip;
   verify the CI drift sequence zero-diffs at HEAD. (Decision this session:
   standardize on go-installable v0.3.1118; provenance of the local 0.3.1123
   resolved as an unpinnable system snapshot.)
2. Fix nix-image boot step: skopeo `oci: → docker-archive` in CI (nix shell
   stock skopeo), load the tar.
3. Add the existence guard (`inspect --type image`) to image-smoke.sh.
4. Re-prove both fixes locally (layout + tar paths), re-run docs battery.
5. Push; watch run 45478490139's successor go green (G1 restored).
6. Blob purge decision (§g Q2) → surgical `reflog expire` + `gc --prune=now`.
7. T-26.3: fix index.html finding 2 Fix callout (WithVersion stamp, not floor
   bump) and finding 4.
8. T-26.3: correct the Method sentence numbers.
9. T-26.3: stamp consumer HEAD + auditor provenance in all 21 report headers.
10. Close TODO row 26 (26.1 + 26.2 + 26.3 all landed) with CHANGELOG entry.
11. T-19.1: transient systemd unit from the Nix binary, READY in journal.
12. T-19.2: watchdog pings ×2 intervals, SIGTERM → STOPPING + clean exit.
13. T-15.1: `cmd/app` CLI wiring test (three verbs registered).
14. T-15.2: `internal/app` config Load() defaults/env/Rejection tests.
15. T-15.3: views render + version interpolation + `/`-only mount test.
16. T-25.1: README "service or web app?" routing box + adopter pointers.
17. T-25.2: POST validation example + rendered-error-shape test.
18. T-25.3: events skeleton + false exhaustruct nolint comment drift + cmdguard
    contract test.
19. T-25.4: `pkg/version` vs ldflags decision for `app version` + test.
20. T-24.1 upstream: HealthOptions passthrough + stamp the probe (fixes #85).
21. T-24.2 upstream: DashboardOptions (embedded SDK vs custom CSS).
22. T-24.3 upstream: HubOptions + settle SSE-vs-WriteTimeout.
23. File go-nix-helpers issue: `apps.app-image-load` broken with stock skopeo
    (nix transport not compiled in) — include the proven error + fix options.
24. Add `CONTAINERS_IMAGE_TMP`/sandbox-staging gotcha to that issue or the ADR.
25. T-5.1: record the publish-path decision in ROADMAP open questions (§g Q3).
26. T-5.2: wire the chosen path (GHCR via GITHUB_TOKEN `packages:write` is the
    no-secret option) and prove one image push.
27. T-6.1/6.2: Go floor ruling → apply to go.mod/buildflow/stamp, re-run gate.
28. T-10.1: dprint.json committed form decision (remote URLs vs bundle) on a
    fresh clone.
29. T-10.2: implement + prove BuildFlow regeneration does not undo it. <!-- fresh:skip: routed to TODO_LIST row 10 -->
30. T-14.1: pre-commit hook story into CONTRIBUTING.
31. T-27.1: score reconciliation script (inventory ↔ score, fail on mismatch).
32. T-27.2: citation sweep script (~1,116 path:line tokens, existence + range).
33. T-27.3: verify-block lint (display-replace flags) + H1/front-matter lint +
    mechanize the em-dash-zone/status-token rules proven in T-26.2.
34. Wire T-27.x scripts as a flake check (`checks.audit-series`).
35. T-28.1: QC subagents reports 1-7 (10 citations each + score recount).
36. T-28.2: QC reports 8-14. <!-- fresh:skip: routed to TODO_LIST row 28 -->
37. T-28.3: QC reports 15-21 + cross-report contradiction pass.
38. T-29.1: markdown index + applicable-row counts beside every score.
39. T-29.2: glossary entries, CHANGELOG line, index screenshot.
40. T-30.1: group findings by owning repo from routing tags; rank severity.
41. T-30.2: file upstream batch A (go-appkit / go-health confirmed defects).
42. T-30.3: file upstream batch B (capability gaps + routing tags).
43. T-7.1/7.2: reproduce `.dockerignore` regeneration, file BuildFlow issue.
44. T-8.1: positive no-Dockerfile gate proposal (same upstream thread).
45. T-9.1: BuildFlow analyzer Go-pin mismatch check + file/amend.
46. T-20.1: doctor scoping issue (28-check list on a Go-only repo).
47. T-20.2: erraudit vocabulary issue.
48. T-21.1: isolate `nix-hash-fix`, record verdict. T-21.2: triage the 1.06 GB
    state DB. T-21.3: APP_LOG_LEVEL / upgrade / profile-io / token debts.
49. T-11.1: Nix-OCI ADR (decision + rejected alternatives + reopen condition).
50. T-22.2: the appkit stamp ritual when `preset/v0.1.2` finally tags.

## g) QUESTIONS FOR THE OWNER (not self-answerable)

1. **templ fleet pin — confirm the standardization I just executed:** this
   session proved the local templ v0.3.1123 is a buildGoModule from an untagged
   system-level source snapshot (`/nix/store/hyzbmjhx4a13z6m2m19jwyaj790kwfsn-source`
   via `/run/current-system/sw`) — not from this flake, not upstream-tagged,
   not pinnable from this repo. I standardized the committed views + CI on the
   go-installable v0.3.1118 and will exclude buildflow's templ-generate here.
   Confirm, or tell me the templ binary lives in a fleet input you control and
   should be repinned there instead (that fix is outside this repo).
2. **Blob purge risk tolerance (unchanged from last report):** the folded
   daemon commit's 38 MB `app` blob is only locally reachable (via reflog to
   the folded `af039a1`); remote history is clean. OK to
   `git reflog expire --expire=1.hour --all && git gc --prune=now` (drops
   today's local recovery net), or keep reflogs?
3. **Image publish path (T-5, unanswered twice now):** CI-push to
   `ghcr.io/larsartmann/app` with the built-in `GITHUB_TOKEN`
   (`permissions: packages: write`, no secrets needed), or build-only plus the
   documented manual load? My lean stays CI-push — a one-line job after the
   smoke step, and it makes the image actually consumable.
