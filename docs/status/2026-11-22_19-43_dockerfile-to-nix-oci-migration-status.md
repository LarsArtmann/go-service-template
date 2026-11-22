# Status Report — Dockerfile → Nix OCI migration (go-service-template)

**2026-11-22 19:43 CET · session scope: one task ("Dockerfile should not exist since I want my OCI images to be built from nix") + gate repair**

## Scope line — what this report VERIFIED vs NOT verified

**Verified here (fresh command/artifact, this session):**

- `trash Dockerfile` executed (first action of the session); repo-wide `[Dd]ocker` content grep + `**/Dockerfile*` glob re-run during report prep: only `.dockerignore` remains (see d1).
- `nix build .#app-image --no-link --print-out-paths` → `/nix/store/5q7sd1pi0v8zhjn282437z4kgwp52i2r-image-app.json` (build green).
- `nix build .#checks.x86_64-linux.container-structure --no-link` → green (the jq structure gate over User/Entrypoint/Cmd/Env/ExposedPorts/Volumes/Labels passed).
- `jq '."image-config"'` over `image-app.json`: `User "65532:65532"`, `Entrypoint ["/bin/app"]`, `Cmd ["serve"]`, `ExposedPorts {"8080/tcp":{}}` — posture identical to the deleted Dockerfile.
- `buildflow --build-mode dev` final run: **60 success, 0 failed** (1m01s; earlier failures were the vendor-hash FOD first build + treefmt drift, both green since).
- `internal/app/service.go:32` read: `Addr string \`default:":8080"\`` — binds all interfaces, so the container port posture is sound at runtime-config level.
- Git evidence read back: daemon commits `fb7200c` (11 files), `b617f24` (7 files), `8d8262e` (3 files), `73050b3` (2 files); `git show --stat` for each.
- BuildFlow source read: `BuildFlow/tools/providers/gitignore_provider.go:104,121` (the `hasDockerfile` gate).
- `date` → 2026-11-22 19:43 CET.

**NOT verified here (and why):**

- **Image runtime boot** — never image-loaded (`nix run .#app-image-load`), never probed `/healthz`, never SIGTERM-drained inside the container. Only the config JSON + structure check prove the image shape, not behavior.
- **`/version` stamp end-to-end** — ldflags config verified by successful build; never confirmed the binary inside the image reports the git rev instead of `"dev"`.
- **CI after action pin bumps** — `buildflow --fix` rewrote `ci.yml` (checkout v4→v7.0.1, setup-go v5→v7.1.0, new SHAs); no push, so no CI run observed.
- **Which process created `.dockerignore`** — timing matches my `buildflow --fix`, but the upstream gate (`hasDockerfile`) should have blocked it; root cause unresolved.
- **buildflow binary freshness** — WARN said a stale `~/go/bin/buildflow` may shadow the installed one; did not run `buildflow doctor`.
- **`.config/metadata.yaml` content** — was modified before session start, swept into `fb7200c` by the daemon; never read it.

---

## a) FULLY DONE

| Item                                                                                                                                                                                                                                       | Evidence                                                                                                |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------- |
| Dockerfile removed (trashed, not rm)                                                                                                                                                                                                       | glob `**/Dockerfile*` → zero matches; repo-wide grep → no live references except CHANGELOG history line |
| OCI image from flake: `container.enable` + `cmd=["serve"]` + `exposedPorts=["8080/tcp"]` wired via the go-standard module (nix2container auto-wired by the composite flakeModule, no new flake inputs)                                     | `flake.nix:51-59`; `nix build .#app-image` green                                                        |
| Version stamp moved from Docker build arg to flake `ldflags` (`-X .../internal/app.Version=${self.rev or self.dirtyRev or "dev"}`), `self` destructured in outputs lambda (fleet precedent bank-sync `flake.nix:263`)                      | `flake.nix:23,44-48`; app drv built clean                                                               |
| Image posture parity confirmed: non-root `65532:65532`, `/bin/app serve`, `8080/tcp`, cacert (module default), content-hash tag                                                                                                            | jq over `image-app.json`; module defaults in `go-standard.nix:836-851`                                  |
| README updated: posture line ("OCI images build straight from the flake, no Dockerfile"), rename checklist item now "the flake.nix `-X` flag", What's-inside table row `flake.nix … + OCI image`, Dockerfile row removed                   | `README.md:7-9,19-20,33`; dprint/treefmt green                                                          |
| AGENTS.md: new "OCI image (no Dockerfile, by policy)" section + `nix build .#app-image` in Build & verify                                                                                                                                  | `AGENTS.md:31-43`                                                                                       |
| CHANGELOG entry under `[Unreleased] → Changed` (2026-11-22, full output list)                                                                                                                                                              | `CHANGELOG.md:7-14`                                                                                     |
| Pre-existing gate blocker fixed: `GOTOOLCHAIN: "go1.27.4"` pinned in `.buildflow.yml` (BuildFlow's derived floor 1.27.3 < go.mod floor 1.27.4; pim-sync precedent) — unblocks govalid-generate                                             | `.buildflow.yml:9-13`; govalid green in final run                                                       |
| Pre-existing gate blocker fixed: `TODO_LIST.md` created (docs-gates cadence was FATAL: "reading TODO_LIST.md: no such file")                                                                                                               | docs-gates cadence → PURGE-HEALTHY / ARCHIVE-HEALTHY; findings gate green                               |
| Formatter drift repaired via `buildflow --fix` (detect→repair→verify): `views/hello_templ.go` import block (pre-existing treefmt red), `flake.nix` interpolation wrap, `SECURITY.md` table, `dependabot.yml` quote style, `routes_test.go` | treefmt-check green; `b617f24` stat                                                                     |
| BuildFlow dev gate fully green at session end                                                                                                                                                                                              | final run: 60 success / 0 failed / 0 error findings above gate                                          |

## b) PARTIALLY DONE

| Item                             | Works                                                                      | Open                                                                                                                                    | Effort                      |
| -------------------------------- | -------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | --------------------------- |
| OCI image as a _usable_ artifact | builds, structure-gated, config verified                                   | never booted; `/version` stamp unconfirmed inside image; no publish path exercised                                                      | S (boot smoke), M (publish) |
| `.dockerignore` removal          | discovered during report prep                                              | left in place deliberately — it is buildflow-managed and `--fix` may regenerate it; real fix is upstream (see d1)                       | M (upstream investigation)  |
| Docker→Nix posture doc set       | README/AGENTS/CHANGELOG updated                                            | systemd-unit-vs-container relationship (sd_notify no-op in container) undocumented; no `image-load` example in README Verify section    | S                           |
| Gate hygiene                     | dev mode green                                                             | `nix-hash-fix` WARN "failed 14/14 times (100%)" never investigated; buildflow binary staleness WARN never checked via doctor            | S–M                         |
| CI pin bumps (tool-made)         | `ci.yml` diff read, pins are real SHA-pinned actions with version comments | zero CI execution evidence (no push); also `728228f`'s golangci-lint v2 install step untouched but not re-validated against setup-go v7 | S (push/observe)            |

## c) NOT STARTED

- Image publish CI (ghcr or otherwise) — no workflow builds or pushes `app-image`; the old Dockerfile had none either, so this is posture completion, not regression.
- Image boot-smoke as an automated flake check (e.g. `checks.image-smoke` via podman).
- ROADMAP.md — does not exist; my first TODO_LIST draft pointed at it (fixed to remove the pointer during report prep).
- Multi-arch (aarch64/linux-arm64) image — unexamined.
- erraudit findings in `internal/app/service.go` (3 warnings: bare `error` return on `Serve`, two `fmt.Errorf` where the project enforces samber/oops) — pre-existing, out of session scope, untouched.
- go-structure-linter repo-shape files: CONTRIBUTING.md, .editorconfig, .gitattributes, LICENSE (README claims PROPRIETARY but no LICENSE file exists), README installation section.
- go-version floor policy question: `go.mod:3` declares `go 1.27.4` (patch-pinned); `go-version-auto-configure` warns floors should be major.minor-only — direct tension with the fleet's Go-floor drift-control ritual (AGENTS stamp + flake tarball pin 1.27.4). Needs a policy call, not a silent fix.
- flake.lock duplicate pin cleanup: `flake-parts` locked twice (`flake-parts` + `go-nix-helpers/flake-parts`, same rev) — WARN only.
- Full-mode gate (`--build-mode full` with coverage) — only dev mode was run.
- docs-health HARVEST of this report's section (f) into TODO_LIST.md.

## d) TOTALLY FUCKED UP

1. **`.dockerignore` ghost artifact (832 B, buildflow-managed) — I shipped an "OCI from Nix" migration and left a Docker-hygiene file behind.** Severity: cosmetic/policy, not functional (nothing consumes it; no Dockerfile exists). Root cause: **unresolved** — it appeared mid-session (mtime 19:16, committed in `fb7200c` 19:16:49) although upstream `hasDockerfile()` (`gitignore_provider.go:121-131`) stats the repo root and repair is gated on it (`:104`); with the Dockerfile already trashed, the gate should have returned false. Either my `--fix` run raced something, another process created it, or the gate has a real bug. Workaround: file is inert; deleting it risks `--fix` whack-a-mole. Correct next step: verify-before-filing investigation + upstream BuildFlow issue.
2. **I introduced a dangling doc reference:** first TODO_LIST.md draft pointed at `ROADMAP.md`, which does not exist in this repo. Severity: minor doc lie, caught during report prep, pointer removed 19:44. Lesson: never reference a file I haven't `ls`'d.
3. **Daemon commit `fb7200c` mixed my work with foreign changes** (pre-session `.config/metadata.yaml` + 72-line `.dockerignore` + `.gitignore` + `.golangci.yml` rewrite + SECURITY.md + dependabot additions swept into one "auto-commit 11 files"). No data loss, but history attribution is muddy. Mitigation: commit my own work promptly instead of letting the daemon batch it with unknowns (BuildFlow anti-pattern list says exactly this; I read the skill and still relied on the daemon).
4. **I accepted tool-made changes without full verification:** `buildflow --fix` also rewrote `ci.yml` action pins (checkout v4→v7.0.1, setup-go v5→v7.1.0). I read the diff but did not run CI. That violates "challenge tool output" — read-but-not-executed verification.
5. **I verified the artifact's config, not its behavior.** The entire verification story for the flagship deliverable ("images from nix") is JSON + jq + a structure check. Nothing booted. The old Dockerfile was never boot-tested by me either — but "same posture as before" is an untested claim until one image runs.

## e) WHAT WE SHOULD IMPROVE

1. **Verify by execution, not by inspection, for artifacts.** A built derivation ≠ a working image. Add a boot-smoke (load → run → probe → drain) to the template's ritual; ideally mechanize as a flake check.
2. **Read hidden files at discovery.** My discovery pass used content-grep + `Dockerfile*` glob; `ls -la` at the start would have surfaced `.dockerignore` immediately. Docker posture lives in _pairs_ (Dockerfile + .dockerignore) — delete them as a unit.
3. **Treat managed files as policy decisions.** A buildflow-managed file contradicting repo policy needs a skip-with-rationale or an upstream fix, not a silent delete-and-regenerate loop.
4. **Commit own work promptly in daemon-run repos** — otherwise unrelated working-tree changes get attributed to your commit.
5. **Session-start inventory should include `git log -5` + `ls -la`,** not just `git status` — `fb7200c`'s foreign content would have been visible earlier.
6. **Managed-tool warnings are findings, not noise:** the `nix-hash-fix 14/14` and stale-binary WARNs were visible in run output and left uninvestigated — both are close-the-loop obligations.
7. **When deleting a posture, grep for the _ecosystem_, not just the filename:** `docker` content-grep missed `.dockerignore` because its _content_ contains no "docker" word. Filename-set grep (`ls -a | grep -i docker`) is the right primitive.

## f) NEXT — up to 50 things (ranked; Impact/Effort/Category)

**Critical / High first:**

1. Boot-smoke the image: `nix run .#app-image-load | podman load` → run → `curl /healthz` + `/api/status` → SIGTERM drain. — Critical/S/Quality
2. Confirm `/version` + `appkit_build_info` inside the image report the git rev (stamp end-to-end). — High/S/Quality
3. Run CI after the `ci.yml` pin bumps; verify build/vet/test + golangci-lint jobs stay green on setup-go v7. — High/S/Quality
4. Dogfood probe: fresh clone of this commit → rename flow (README steps) → build → boot → image build. Validates the whole template post-change. — High/M/Quality
5. Add PR-CI step: `nix build .#app-image` + `nix build .#checks.container-structure` so image regressions gate merges. — High/S/Feature
6. Decide + wire image publishing: CI job to ghcr.io vs manual `nix run .#app-image-push`. — High/M/Feature (needs Q2)
7. Verify `nix flake check` behavior on darwin (container outputs are Linux-only; the template must not fail eval on macOS). — High/S/Quality
8. Investigate `.dockerignore` creation despite the `hasDockerfile` gate; verify-before-filing → BuildFlow upstream issue. — Medium/M/Bug-upstream
9. Investigate `nix-hash-fix` 14/14 failures (log a run, triage stale-binary vs real bug; file upstream or skip with rationale). — Medium/M/Quality
10. `buildflow doctor` + rebuild/reinstall the possibly-shadowed buildflow binary. — Medium/S/Cleanup

**Policy / docs:**

11. Policy call: keep patch-pinned `go 1.27.4` in go.mod (fleet floor ritual) or switch to major.minor (BuildFlow's warning). — Medium/S/Policy (needs Q3)
12. Add LICENSE file (README says PROPRIETARY; linter flags it missing). — Medium/S/Documentation
13. README: add installation/quickstart section (clone → nix build → serve). — Medium/S/Documentation
14. README Verify section: add the image-load/push commands. — Low/S/Documentation
15. AGENTS.md: document systemd-unit vs container relationship (sd_notify no-op in container). — Low/S/Documentation
16. AGENTS.md Build & verify: align with fleet doctrine (buildflow commands as primary, raw commands as fallback). — Low/S/Documentation
17. AGENTS.md gotcha: templ regen ↔ treefmt interplay (committed generated files get formatter-fixed; regen may re-drift). — Low/S/Documentation
18. CONTRIBUTING.md, .editorconfig, .gitattributes (LF), README installation section — the four go-structure-linter gaps. — Low/S/Documentation
19. Create ROADMAP.md (multi-arch images, publish automation, smoke checks) or explicitly decide the template keeps none. — Low/S/Documentation
20. Run docs-health HARVEST: route section (f) items into TODO_LIST.md / ROADMAP.md. — Medium/S/Process

**Quality / cleanup:**

21. Fix the 3 erraudit findings in `internal/app/service.go` (bare `error` return; 2× `fmt.Errorf` → samber/oops per project rule). — Medium/S/Quality
22. flake.lock dedupe: `go-nix-helpers.inputs.flake-parts.follows = "flake-parts"` → relock. — Low/S/Cleanup
23. Reproducibility proof: build `.#app-image` twice, assert identical out-path (content-hash tag claim). — Medium/S/Quality
24. Confirm image `Env` carries `SSL_CERT_FILE` (cacert default) via image-config jq. — Low/S/Quality
25. Multi-arch: try `nix build .#packages.aarch64-linux.app-image` (or flake-parts systems) for arm64. — Medium/M/Feature
26. Add `checks.image-smoke` flake check (podman load + curl probe) so boot coverage is automated. — Medium/M/Feature
27. Verify `.gitignore` covers `result`/`result-*` (the `result` symlink in the tree is currently ignored — confirm it's the buildflow-managed block, not luck). — Low/S/Cleanup
28. Decide `APP_PORT` footgun: if APP_ADDR env changes the port, ExposedPorts stays 8080 — document or lock. — Low/S/Quality
29. Run `buildflow --build-mode full` (race + coverage) once post-migration. — Medium/M/Quality
30. CI: cache the `go install golangci-lint` step (from 728228f). — Low/S/Quality
31. Dependabot: add github-actions/flake ecosystems coverage beyond the existing group. — Low/S/Quality
32. Pre-commit hook: confirm `buildflow precommit install` state for adopters cloning fresh. — Low/S/Quality
33. Read `.config/metadata.yaml` (swept into `fb7200c`); confirm content + intent. — Low/S/Cleanup (needs Q1)
34. Verify the rename checklist end-to-end updates everything image-related (pname → image name `ghcr.io/larsartmann/<new>`). — Low/S/Documentation
35. Confirm daemon commit hygiene improvement: next session, commit own work before the daemon's 2–3 min tick. — Low/S/Process
36. Check whether `no-dockerfile` buildflow step (saw it in dry-run) should assert the no-Dockerfile policy (a positive gate: fail if a Dockerfile ever appears). — Low/S/Quality
37. Sweep `SECURITY.md`, `dprint.json`, `.golangci.yml` (all rewritten mid-session by tooling) for content correctness — read them once as owner. — Low/S/Cleanup
38. Template stamp block: decide whether the 2026-11-21 "Generated" stamp needs a bump note for this posture change (ritual says bump on appkit trains; this was posture, not preset). — Low/S/Policy
39. Ensure `checks.container-structure` also runs in CI (currently only local). — Low/S/Feature
40. Explore nix2container `maxLayers`/layer-sharing benefits vs the fleet registry (the module header claims cross-image layer sharing — confirm in practice). — Low/M/Quality

**Roadmap fuel (bigger, later):**

41. OCI image signing (cosign) for published images. — Low/L/Feature
42. Image SBOM attestation step. — Low/L/Feature
43. Deploy story: systemd unit vs container — pick the blessed path per service and document. — Medium/L/Feature
44. Template CI: run `buildflow` itself in CI (fleet-standard gate posture). — Medium/M/Feature
45. prepared-source (`deps`) migration instead of vendorHash (module supports it; vendorHash.nix is the current posture). — Low/M/Cleanup
46. Evaluate `nix build .#app-image` cache behavior in CI (nix2container layers vs GH cache). — Low/M/Quality
47. Add `doctor`-style self-check verb coverage in cmdguard CLI (version/doctor exist — confirm they cover image posture). — Low/S/Feature
48. Fleet check: does any other template/adopter still carry a Dockerfile (census sweep) so this posture lands everywhere. — Medium/M/Cleanup
49. Write the ADR: "OCI images from Nix, no Dockerfile" (decision + rejected alternatives) in `docs/decisions/`. — Low/S/Documentation
50. Re-run this report's verification block after items 1–5 land (closing the loop on the runtime claims). — Medium/S/Process

## g) Questions I cannot answer myself

1. **Was the `.config/metadata.yaml` change (present before this session, swept into daemon commit `fb7200c` with my work) yours/intentional?** I can read the diff (+2 lines) but not its provenance or intent — and it now sits attributed to a commit that is mostly my Dockerfile removal.
2. **For services scaffolded from this template: should OCI images be published from CI to `ghcr.io/larsartmann/<name>`, or is pushing manual (`nix run .#app-image-push`) by policy?** This decides item 6 and whether CI needs registry credentials — a fleet/infra decision I cannot derive from the repo.
3. **Which wins for `go.mod`: the fleet's patch-pinned Go floor ritual (`go 1.27.4`, mirrored by the flake tarball pin and AGENTS stamp) or BuildFlow's `go-version-auto-configure` rule that floors must be major.minor only?** The two fleet standards contradict each other in this repo; I need the owner's policy call before touching go.mod.

---

_Per the status-report doctrine: section (f) is HARVEST input — it should land in TODO_LIST.md/ROADMAP.md rather than die in this timestamped file. Awaiting instructions._
