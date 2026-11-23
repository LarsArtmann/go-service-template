# Status Report — Tooling hygiene + verification-loop closure

- `date` → 2026-11-23 02:43 CET.
- Session type: "fix it all" follow-up to the 2026-11-22 Dockerfile→OCI report.
- Auto-commit daemon active throughout; every file landed via heuristic commits.

**Scope of this report — what was VERIFIED here (fresh command output, this session):**

| Claim                  | Evidence                                                                                                                                                                                                           |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Final gate green       | `buildflow --build-mode dev` → exit 0, "60 success, 0 failed"                                                                                                                                                      |
| Docs battery green     | `docs-gates run .` → 5/5 PASS (freshness, audit-all, annotate, routing, cadence)                                                                                                                                   |
| Doctor warnings 4 → 2  | `buildflow doctor` after rebuild: Passed 74, Warnings 2                                                                                                                                                            |
| Go layer clean         | `go build`, `go test -race`, `golangci-lint run ./...` (0 issues), `erraudit` (0 violations)                                                                                                                       |
| Nix layer green        | `nix build`, `nix build .#app-image`, `nix flake check` ("all checks passed")                                                                                                                                      |
| Image reproducible     | two consecutive `nix build .#app-image` → identical store path `g5djzypbkhry…`                                                                                                                                     |
| Image posture          | `jq` over `result` (`image-app.json`): User 65532:65532, 8080/tcp, SSL_CERT_FILE cacert, Entrypoint /bin/app + Cmd serve, rev in labels                                                                            |
| Runtime probe (binary) | booted Nix-built binary on APP_ADDR=:18089; curl /healthz, /api/status, /version all JSON 200 with rev `afeda84…`; SIGTERM via pkill → five drain phase lines + "graceful shutdown complete" in /tmp/app-probe.log |
| Rename dogfood         | fresh clone → module sed → `go build` + `go vet` + `go test` green ("RENAME+BUILD GREEN"); booted, /api/status JSON 200 (version "dev" — correct: no ldflags in `go run`)                                          |
| Darwin eval safe       | `nix eval .#packages.aarch64-darwin.app.drvPath` → drv path produced                                                                                                                                               |

**NOT verified here (and why):**

- **Image boot** — no docker/podman/skopeo exists on this machine (checked `which`); the image was never loaded or run anywhere.
- **CI execution** — no push happened this session; the new `nix-image` job and the tool-bumped pins have zero run evidence.
- **`nix-hash-fix` cure** — the 14/14-failure WARN did not reappear in post-rebuild gate output (I read the tails), but I did not run the step in isolation to claim it is fixed.
- **Vulnix advisories** — 23 findings (binutils, bison, brotli, cargo drvs) reported in the gate; not triaged, not assessed for reachability. Fleet-global nixpkgs noise by first impression only.
- **systemd deploy path** — `systemd/app.service` (Type=notify, watchdog) never probed via systemd-run; "same binary runs in both" rests on preset docs, not execution.
- **/readyz, /startupz, /health dashboard, `/`, 404 pages in MY probe** — the 2026-11-22 session verified that fuller endpoint matrix; my probe covered /healthz + /api/status + /version only.
- **buildflow state DB** — VACUUM ran; size stayed ~1.06 GB (real data, not free pages). No purge/GC attempted.

## a) FULLY DONE

| Item                                                                                             | Evidence                                                                                                                                                                                                                          |
| ------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Stale buildflow binary diagnosed and rebuilt: binary was be700ae vs HEAD, compiled with go1.27.3 | `nix build && nix run .#reinstall` in /home/lars/projects/BuildFlow → "REINSTALL-OK … buildflow version 769b3a4"; PATH precedence verified (`which -a` → nix-profile first, no ~/go/bin shadow)                                   |
| binary-freshness doctor WARN cleared                                                             | post-rebuild `buildflow doctor` output                                                                                                                                                                                            |
| flake.lock duplicate `flake-parts` pin deduped                                                   | `inputs.flake-parts.follows = "flake-parts"` in flake.nix; `nix flake lock` → "Removed input 'go-nix-helpers/flake-parts/nixpkgs-lib'"; doctor dup WARN cleared                                                                   |
| Image reproducibility proven                                                                     | two builds → identical out-path (first NOT-REPRODUCIBLE reading was a race with my own in-flight `nix flake lock`, re-run clean)                                                                                                  |
| Image posture verified in the artifact                                                           | jq over image-app.json (see scope table)                                                                                                                                                                                          |
| Version stamp end-to-end                                                                         | `/version` + `/api/status` on the Nix-built binary both return the git rev `afeda84839c…`; flake label carries the same rev                                                                                                       |
| Dogfood probe (AGENTS ritual) passed on the Nix binary                                           | boot → 3× JSON 200 → SIGTERM → ready_flip → drain_hooks → drain_wait(5.003s) → listener_close → shutdown_hooks → "graceful shutdown complete result=ok"                                                                           |
| Rename-flow dogfood passed                                                                       | /tmp clone, sed module + Name/Short consts, build/vet/test green, boot + probe 200                                                                                                                                                |
| docs-gates annotate F/spacing repaired                                                           | status doc line rephrased; `docs-gates annotate` → CLEAN, dprint check agrees                                                                                                                                                     |
| docs-gates freshness red cleared                                                                 | §f items 18 + 31 of the previous report: four structure files created + dependabot verdict; `docs-gates freshness` → FRESH, 0 unharvested                                                                                         |
| docs battery fully green                                                                         | `docs-gates run .` → 5/5 PASS                                                                                                                                                                                                     |
| LICENSE added                                                                                    | fleet-standard proprietary text (matches README claim, matches InboxClean/monitor365/1ATemplate posture)                                                                                                                          |
| CI image gate added                                                                              | `nix-image` job: nix-installer + magic-nix-cache + `nix build .#app-image` + container-structure check                                                                                                                            |
| README/AGENTS/CHANGELOG/TODO_LIST updated                                                        | README: image verify + Install + APP_ADDR-vs-ExposedPorts footgun; AGENTS: buildflow-first, systemd-vs-container, templ/treefmt gotcha, 8080-squatter gotcha; CHANGELOG: two dated entries; TODO_LIST: full harvest with verdicts |
| Previous report's erraudit claim corrected                                                       | direct run: "Total Violations: 0"; samber/oops absent from go.mod — fleet posture here is fmt.Errorf/go-error-family, allowed by wrapcheck ignore-sigs                                                                            |

## b) PARTIALLY DONE

| Item                           | Works                                                                                   | Open                                                                                                                                                                                       | Effort                                                            |
| ------------------------------ | --------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------- |
| OCI image as a usable artifact | builds green, bit-reproducible, posture verified in JSON, CI gate written               | never loaded/run anywhere; no image-smoke check; publish path undecided                                                                                                                    | S (smoke in CI where docker exists), M (mechanize as flake check) |
| Doctor hygiene                 | binary-freshness cleared, dup-pin cleared, VACUUM run                                   | analyzer-go-version WARN remains (BuildFlow's own flake builds with go1.27.3 vs repo floor 1.27.4; mitigated by GOTOOLCHAIN pin in .buildflow.yml); db-size 1.06 GB unchanged after VACUUM | S–M (both are BuildFlow-repo / global-state work)                 |
| CI readiness                   | nix-image job + tool-bumped pins in ci.yml                                              | zero CI runs (no push); golangci-lint v2 install step still unvalidated against setup-go v7                                                                                                | S (push + observe)                                                |
| §f harvest                     | previous report fully harvested (gate green); TODO_LIST carries this session's verdicts | THIS report's §f below is fresh harvest input                                                                                                                                              | S                                                                 |

## c) NOT STARTED

| Item                                                                                           | Why                                                                                   | Priority |
| ---------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- | -------- |
| Image boot-smoke mechanization (checks.image-smoke or CI step with docker load + curl + drain) | needs a runtime; dev machine has none                                                 | High     |
| Image publish path (CI → ghcr vs manual app-image-push)                                        | owner policy decision                                                                 | High     |
| go.mod floor shape (patch-pin 1.27.4 vs major.minor-only rule)                                 | direct fleet-standard conflict; needs owner call                                      | Medium   |
| `.dockerignore` ghost artifact upstream investigation                                          | verify-before-filing required; file inert                                             | Medium   |
| BuildFlow analyzer-go-version upstream fix                                                     | root fix lives in BuildFlow's flake                                                   | Medium   |
| systemd path probe (systemd-run + sd_notify + watchdog)                                        | untested claim; machine has systemd available                                         | Medium   |
| Multi-arch (aarch64-linux) image; signing; SBOM; ADR for OCI-from-Nix                          | roadmap fuel, deliberately not TODO                                                   | Low      |
| ROADMAP.md                                                                                     | explicitly decided: template keeps none; fuel lives in timestamped reports until ripe | decided  |

## d) TOTALLY FUCKED UP

1. **My CHANGELOG edit silently deleted the previous session's Dockerfile-removal entry.** Severity: doc regression (history loss). Root cause: I anchored the edit on the section header plus the old bullet and replaced the whole block instead of appending. Mitigation: caught on read-back seconds later, restored verbatim. Lesson: after restructuring any doc edit, diff against the pre-edit content — the read-back rule is not optional.
2. **I shipped a fabricated install command.** I wrote `nix profile install github:LarsArtmann/BuildFlow` into README's new Install section from memory. BuildFlow's README explicitly documents the opposite: the repo is private, there is no such install path (flake input + `nix build .#buildflow`, or `buildflow upgrade`). Severity: a doc lie in the template's front door for ~minutes. Caught by the verify-external-claims reflex, corrected. Lesson: verify BEFORE writing, not after.
3. **My first reproducibility check reported a false NOT REPRODUCIBLE.** Two builds raced my own in-flight `nix flake lock` (flake.nix/lock were mutating between them), producing different store paths; I surfaced "NOT REPRODUCIBLE" before diagnosing. Re-run clean: REPRODUCIBLE. Severity: I almost recorded a real defect that was my own measurement error. Lesson: never run verification while the thing verified is mutating; assert tree/lock stability first.
4. **My first runtime probe was entirely invalid, and I nearly used it as evidence.** :8080 was squatted by an unrelated SigNoz UI on this machine; curl returned ITS HTML for /healthz, /api/status, /version while my app had failed to boot (bind failed — correctly classified as Infrastructure:server.listen_failed in its log). Additionally the harness shell's `kill` builtin is unsupported, so my SIGTERM silently never executed. Only the second probe (APP_ADDR=:18089, external kill binary, exact-pattern pkill) produced real evidence. Severity: verification integrity — the first output block looked plausible. Lesson: assert the probe target's identity (version stamp in the response) before recording any endpoint evidence.
5. **pkill self-match killed my own shell mid-verification.** The pattern `gst-dogfood/bin/app` matched my own compound command line; the shell died with "exit status 1" and took the app down without drain lines. Severity: the renamed clone's drain evidence is therefore only indirect (identical framework binary to the main probe, which did show all five phases). Lesson: probe scripts must use patterns that cannot match the invoking command, or a PID file.
6. **Daemon attribution blur continues — by my own inaction.** All my work landed via auto-commit heuristic batches (e.g. be774c2 mixes AGENTS + CHANGELOG + LICENSE + TODO_LIST). The previous report's lesson (commit own work before the daemon tick) was known and still not applied. Severity: history attribution stays muddy. Root cause: I keep deprioritizing manual commits because the daemon "will get it anyway".

## e) WHAT WE SHOULD IMPROVE

1. **Mechanize the dogfood probe into a script** (build → boot on a dedicated port → assert the version stamp IN the response before probing → endpoint matrix → SIGTERM → grep the five drain lines → assert exit). This session proved the manual version is fragile (wrong-port curl, unsupported kill, self-matching pkill, $! expansion quirks). Impact: every future train re-earns the same friction.
2. **Verify claims at write time, not at review time.** The BuildFlow install-command fabrication survived into the tree because verification happened as a later step. Fix: rule — no external command/URL enters a doc before its source is read.
3. **Never verify against a mutating tree.** Serialize lock mutation and build verification; or hash flake.lock before/after a reproducibility check and fail the check if it moved.
4. **Read-back after doc restructure.** A CHANGELOG block replacement dropped an entry; only a re-read caught it. Fix: after any edit that replaces a section, `git diff` the file and eyeball deletions.
5. **assert-version-in-response as the first probe step.** :8080 served someone else's UI and curl made it look like evidence. The version stamp in the JSON is the cheap identity check.
6. **BuildFlow upstream: scope doctor's tool inventory to the project stack** — 28 "failed" checks are Python/Rust/JS/Docker tools a Go-only repo will never use (hadolint is moot post-Dockerfile-removal). The signal-to-noise hides real warnings.
7. **BuildFlow upstream: erraudit's "N findings reported" vocabulary collides with findings-gate semantics** — it prints "Total Errors Found: 17 … Total Violations: 0"; a report reader sees "3 findings" and alarms. Below-gate metrics need a different word.
8. **Commit own work before the daemon tick.** Known lesson, twice ignored. The fix is behavioral: commit at each milestone.

## f) NEXT — up to 50 (ranked; Impact/Effort/Category)

**Critical / High first:**

1. Push and observe CI: build/vet/test + lint + the new nix-image job; validate golangci-lint v2 install against setup-go v7. — Critical/S/Quality `<!-- fresh:skip: routed to TODO_LIST row 4 -->`
2. Image boot-smoke where a runtime exists: CI job `nix run .#app-image-load \| docker load` → run → probe endpoint matrix → SIGTERM drain. — High/S/Quality `<!-- fresh:skip: routed to TODO_LIST row 1 -->`
3. Probe script (see e1) committed as the template's probe ritual, dogfood probe = run it. — High/M/Quality `<!-- fresh:skip: routed to TODO_LIST row 17 -->`
4. Assert version stamp ≠ "dev" inside the image probe (catches a silently unstamped build). — High/S/Quality `<!-- fresh:skip: routed to TODO_LIST row 17 -->`
5. `checks.image-smoke` flake check (or documented CI-only alternative if the sandbox forbuds runtimes). — High/M/Feature `<!-- fresh:skip: routed to TODO_LIST row 1 -->`
6. Build the events tag in CI: `go build -tags events ./...` + `go vet -tags events ./...` — nothing currently proves internal/events compiles. — High/S/Quality (new gap found this session) `<!-- fresh:skip: routed to TODO_LIST row 18 -->`
7. Templ regen drift check: `templ generate` → `git diff --exit-code views/` in CI (the committed-generated-files gotcha, currently policed only by prose). — High/S/Quality `<!-- fresh:skip: routed to TODO_LIST row 18 -->`
8. systemd path probe: systemd-run a transient unit from the binary, assert sd_notify READY + watchdog pings + STOPPING on drain. — High/M/Quality `<!-- fresh:skip: routed to TODO_LIST row 19 -->`

**Policy / docs:**

9. Owner decision: image publish path (CI→ghcr vs manual app-image-push); wire the chosen one. — High/M/Feature (needs Q2) `<!-- fresh:skip: routed to TODO_LIST row 5 -->`
10. Owner decision: go.mod floor patch-pin vs major.minor-only; document the ritual either way. — Medium/S/Policy (needs Q3) `<!-- fresh:skip: routed to TODO_LIST row 6 -->`
11. ADR: "OCI images from Nix, no Dockerfile" in docs/decisions/ (decision + rejected alternatives). — Low/S/Documentation `<!-- fresh:skip: routed to TODO_LIST row 11 -->`
12. README rename checklist → tested script (scripts/rename.sh) or scaffolder verb; the sed flow has zero execution guardrails. — Medium/M/Feature `<!-- fresh:skip: routed to ROADMAP theme 3 -->`
13. metadata.yaml: bump updated_at on posture trains (currently 2026-11-21; drifts silently). — Low/S/Cleanup `<!-- fresh:skip: resolved by the concurrent audit sweep (metadata.yaml refreshed) -->`
14. Extend probe matrix to /readyz, /startupz, /health dashboard, /, 404/405 pages (match the 2026-11-22 matrix). — Medium/S/Quality `<!-- fresh:skip: routed to TODO_LIST row 17 -->`
15. Drain-under-load probe: hold an in-flight request during SIGTERM and assert the drain waits then completes (current drain evidence is idle-only). — Medium/M/Quality `<!-- fresh:skip: routed to TODO_LIST row 17 -->`

**Tooling / hygiene:**

16. File BuildFlow upstream issues (verify-before-filing): hasDockerfile/.dockerignore ghost artifact; analyzer-go-version go1.27.3-vs-1.27.4; doctor per-stack scoping; erraudit vocabulary. — Medium/M/Bug-upstream `<!-- fresh:skip: routed to TODO_LIST rows 7-9 and 20 -->`
17. Investigate buildflow state DB growth (1.06 GB post-VACUUM; find the post-purge GC trigger or a retention config). — Medium/M/Cleanup `<!-- fresh:skip: routed to TODO_LIST row 21 -->`
18. Triage the 23 vulnix advisories (binutils/bison/brotli/cargo): nixpkgs bump or documented ignore; decide whether the template carries a vulnix policy at all. — Medium/M/Quality `<!-- fresh:skip: routed to ROADMAP theme 4 -->`
19. io-history-ratchet WARN (3 files vs median 1) — run once with --profile-io, confirm benign. — Low/S/Cleanup `<!-- fresh:skip: routed to TODO_LIST row 21 -->`
20. CI: cache the golangci-lint install step. — Low/S/Quality `<!-- fresh:skip: routed to TODO_LIST row 13 -->`
21. CI: `nix flake check --all-systems` (or explicit darwin eval job) so macOS eval breakage cannot merge. — Medium/S/Quality `<!-- fresh:skip: routed to TODO_LIST row 3 -->`
22. CI: pre-commit hook install state for adopters cloning fresh (`buildflow precommit install` posture). — Low/S/Quality `<!-- fresh:skip: routed to TODO_LIST row 14 -->`
23. Dependabot flake ecosystem — decided: not a Dependabot ecosystem; document that flake input bumps ride the appkit train ritual (done in TODO_LIST; carry the note into the ADR). — Low/S/Documentation `<!-- fresh:skip: resolved (dependabot verdict recorded; CHANGELOG + audit sweep) -->`
24. Full-mode gate once post-changes (`buildflow --build-mode full`, race + coverage) — this session ran dev mode only. — Medium/M/Quality `<!-- fresh:skip: resolved (full-mode gate ran green in the concurrent audit sweep) -->`
25. Probe APP_LOG_LEVEL env leg (config module's second field is untested). — Low/S/Quality `<!-- fresh:skip: routed to TODO_LIST row 21 -->`

**Template surface:**

26. Multi-arch: `nix build .#packages.aarch64-linux.app-image` on an arm64 builder; document system matrix. — Medium/M/Feature `<!-- fresh:skip: routed to ROADMAP theme 1 -->`
27. Image label drift: assert image version label == git rev at HEAD during smoke (matched this session only because the daemon had committed). — Low/S/Quality `<!-- fresh:skip: routed to TODO_LIST row 17 -->`
28. `app doctor` verb: extend cmdguard batteries with image/system posture checks (version/doctor exist; image facts live only in flake checks). — Low/S/Feature `<!-- fresh:skip: routed to ROADMAP theme 5 -->`
29. nix2container maxLayers / cross-image layer sharing: confirm the fleet registry benefit claim in practice. — Low/M/Quality `<!-- fresh:skip: routed to ROADMAP theme 1 -->`
30. preparedSrc (deps) migration instead of vendorHash — fleet direction; evaluate and decide. — Low/M/Cleanup `<!-- fresh:skip: routed to ROADMAP theme 3 -->`
31. OCI image signing (cosign) + SBOM attestation — roadmap fuel. — Low/L/Feature `<!-- fresh:skip: routed to ROADMAP theme 1 -->`
32. Deploy story ADR: systemd unit vs container per service class; template documents both paths today (done this session); pick the blessed default. — Medium/L/Feature `<!-- fresh:skip: routed to ROADMAP theme 2 -->`
33. Fleet census: sweep other templates/adopters for Dockerfile remnants so this posture lands everywhere. — Medium/M/Cleanup `<!-- fresh:skip: routed to ROADMAP theme 4 -->`
34. dprint dockerfile plugin entry (inert, buildflow-managed): fold into the .dockerignore upstream issue as one Docker-posture-remnant item. — Low/S/Cleanup `<!-- fresh:skip: routed to TODO_LIST row 10 -->`
35. Consider a `.docs-gates.json` for this repo only if a fleet default ever needs overriding (currently zero config, healthy). — Low/S/Documentation `<!-- fresh:skip: not wanted (zero-config docs-gates posture is healthy) -->`

**Verification debt from this session:**

36. Re-run `nix-hash-fix` in isolation to convert "absent from output" into "fixed". — Low/S/Quality `<!-- fresh:skip: routed to TODO_LIST row 21 -->`
37. Re-run the doctor battery after BuildFlow's next release to confirm analyzer-go-version clears. — Low/S/Quality `<!-- fresh:skip: routed to TODO_LIST row 21 -->`
38. Capture `nix flake check --all-systems` output locally for the darwin-eval claim (my evidence is a drvPath eval, not a full check). — Low/S/Quality `<!-- fresh:skip: routed to TODO_LIST row 3 -->`
39. Run the full endpoint matrix probe once on the OCI image (when a runtime is available) to close items 1+2+14 in a single pass. — Medium/M/Quality `<!-- fresh:skip: routed to TODO_LIST row 1 -->`
40. Rename-dogfood with flake rename included (my clone test covered the Go layer; pname/-X/unit rename + `nix build` on the renamed flake is untested — vendorHash changes with the module path, so the ritual needs a re-fill step documented). — Medium/M/Quality `<!-- fresh:skip: routed to TODO_LIST row 2 -->`
41. Verify `buildflow upgrade` path works from this repo (documented in BuildFlow README; never exercised here). — Low/S/Quality `<!-- fresh:skip: routed to TODO_LIST row 21 -->`
42. `git log` hygiene: next session, commit at milestones (d6) and verify attribution diff-vs-daemon. — Low/S/Process `<!-- fresh:skip: recorded in AGENTS.md gotchas by the concurrent audit sweep -->`
43. Check whether `no-dockerfile` buildflow step can become a positive gate (fail if a Dockerfile ever appears) — carry from previous report, still unexamined. — Low/S/Quality `<!-- fresh:skip: routed to TODO_LIST row 8 -->`
44. Probe script should assert the 8080-squatter failure path too (bind failure → classified Infrastructure:server.listen_failed → non-zero exit) — turn this session's accident into a test. — Low/S/Quality `<!-- fresh:skip: routed to TODO_LIST row 17 -->`
45. Review `internal/api/routes_test.go` coverage against the error-pages/no-leak claims (untouched this session; only ran). — Low/M/Quality `<!-- fresh:skip: routed to TODO_LIST row 15 -->`
46. Keep `checks.container-structure` green in CI (written, unobserved — same push as item 1). — Medium/S/Quality `<!-- fresh:skip: routed to TODO_LIST row 4 -->`
47. Consider GITHUB_TOKEN export for lychee private-link checks (doctor notes they are skipped, not verified). — Low/S/Quality `<!-- fresh:skip: routed to TODO_LIST row 21 -->`
48. `.gitattributes` more entries if docs grow (currently one linguist-documentation line). — Low/S/Cleanup `<!-- fresh:skip: not wanted (one linguist line suffices for now) -->`
49. After harvest of THIS §f, re-run `docs-gates run .` to keep the battery green (do it in this session, see harvest note below). — Medium/S/Process `<!-- fresh:skip: done in this session (rows 17-21 added; battery re-run below) -->`
50. Re-run this report's verification block after items 1–8 land (closing the loop on runtime/CI claims). — Medium/S/Process `<!-- fresh:skip: routed to TODO_LIST row 1 -->`

**Harvest note:** items 1–15 are the actionable core and belong in TODO_LIST.md now; 16–35 are ripening fuel; 36–50 are this report's own verification debt. TODO_LIST rows 1–7 (written earlier this session) already cover items 1–6, 9–10, 16 in spirit — the freshness gate is the referee.

## g) Questions I cannot answer myself

1. **Should the OCI image be published from CI to ghcr.io, or is pushing manual (`nix run .#app-image-push`) by policy?** This decides whether ci.yml grows a registry-credentials job and whether `apps.app-image-push` stays the blessed path. I cannot derive fleet intent from this repo, and both postures are wired-ready.
2. **Which fleet standard wins for go.mod: the patch-pinned floor ritual (`go 1.27.4`, mirrored by the flake tarball pin and AGENTS stamp) or BuildFlow's major.minor-only rule?** They contradict directly; BuildFlow warns on every run, the AGENTS stamp enforces the pin. A policy call, not a code fix.
3. **Is there an arm64 (or any non-x86_64) build host in the fleet** I should target for multi-arch image verification, or is x86_64-linux the only blessed image platform for now? This decides whether item 26 is a real task or a documented non-goal.

---

_Per the status-report doctrine: section (f) is HARVEST input. The actionable core (items 1–15) was harvested into TODO_LIST.md in this session immediately after writing this report, and the docs battery was re-run green — the loop is closed, not deferred._
