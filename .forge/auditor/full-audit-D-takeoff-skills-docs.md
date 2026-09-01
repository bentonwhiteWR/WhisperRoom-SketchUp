# Full audit, lane D — take-off pipeline, the two skills, and the docs that drive them

Auditor report, 2026-09-01, against plugin **1.19.2** (commit `14197b9`). Read-only:
nothing outside `.forge/auditor/` was created or modified; every checker run used a
scratch copy under `.forge/auditor/eval-run/` so no lock file or sheet landed in
`clients/` or `eval/`. No SketchUp, no `ruby.exe`; Ruby claims are code reads
(`derived`) unless `rbparse.py` could prove them. Provenance words are the Manual's:
**observed / derived / reported / assumed**.

Scope covered: `scripts/takeoff-check.py`, `scripts/build-takeoff.rb`,
`scripts/build-room.rb` + `.html`, `scripts/eval-floorplan.py` (read, not run — it
needs SketchUp), `scripts/auto-dimension.rb` (the `:loose` path only),
`scripts/rbtest-takeoff.py`, `scripts/check-doc-paths.py`, `eval/RESULTS.md`, all 26
`eval/floorplans/*` cases, `skills/whisperroom-takeoff/SKILL.md`,
`skills/whisperroom-proposal/SKILL.md`, `reference/takeoff-format.md`,
`reference/proposal-playbook.md`, `reference/sketchup-drawing.md`,
`reference/scale-estimation.md`, `proposals/build-v2.js` + example config,
`scripts/proposal-package.rb` (manifest writer only), `clients/uic-daley-library/takeoff.json`,
`CLAUDE.md`, `README.md`, `docs/README.md`, `clients/README.md`.

## Harness results (all observed, this machine, 1 Sep 2026)

| harness | result |
|---|---|
| `python scripts/takeoff-check.py --selftest` | 25 grammar vectors, 50 cases, **0 failures**, exit 0 |
| `python scripts/rbtest-takeoff.py` | 14 checks, **0 failures**, exit 0 |
| `python scripts/rbparse.py` | **66 file(s) parse** |
| `python scripts/check-doc-paths.py` | 24 refs, **7 missing/uncheckable**, exit 1 (see D-8) |
| `node proposals/build-v2.js examples/example-client/...` | 10-page pack, no plate overflow, exit 0 |
| headless Chrome print + PyMuPDF | 10 pages, every page 612 x 792 pt, footer present on all 10 bottom-edge crops |
| review sheet for the UIC job, `--html`, no `--embed-photos` | 96,085 chars; 1 JSON block + 1 JS block; JS block `node --check` clean; **zero external script/style/font references** |
| review sheet `#autotest` in headless Chrome | `AUTOTEST OK (3 viewers)`; emitted patch applied by `--apply-patch` and re-validated exit 0 |

---

## Ranked findings

Ranking is probability x cost, silent above loud, customer-facing above internal.

### D-1 — HIGH — Both room builders write into whatever model is open; `build-takeoff.rb` also erases by name. No Untitled guard on any entry point.

- **Where:** `scripts/build-takeoff.rb:190` (`model = Sketchup.active_model`) and `:219`
  (erases every top-level group whose `wr_takeoff/room` attribute matches a room name in
  the lock, before rebuilding); `scripts/build-room.rb:353` (`model = Sketchup.active_model`);
  the dialog path `scripts/build-room.html` -> `build` callback (`build-room.rb`, `open`)
  has no check either. The only guard in the lane is `scripts/eval-floorplan.py:136-146`
  (`SCRATCH_GUARD`, injected into the bridge job) — it protects the eval suite only.
- **Trigger:** Gabe has a client `.skp` open, opens the panel, clicks "Build from take-off…"
  or "Draw floor plan…", picks a lock / types a room. Rooms land in the client file; a
  second run of the same lock erases and rebuilds any group carrying the same room name.
- **Failure:** silent contamination of live client work (one undo step, but Ctrl+S makes it
  permanent). `.forge/GOAL.md` names this a finding by rule, and Benton's standing memory
  rule is "SketchUp jobs must assert an Untitled model and refuse otherwise".
- **Provenance:** derived (code read; SketchUp not available). The absence of the guard is
  observed by grep (`Untitled|model.path` appears only in `eval-floorplan.py`).
- **Fix direction:** in `WR_BuildTakeoff.build_from` and `WR_BuildRoom.build`, before
  `start_operation`, refuse by name when `model.path` is non-empty (same message shape as
  `SCRATCH_GUARD`, naming the model title and path). Keep an explicit override for the
  bridge if the eval ever needs it.

### D-2 — HIGH, customer-facing — The proposal skill tells the agent to commit client configs and renders into this PUBLIC repo.

- **Where:** `skills/whisperroom-proposal/SKILL.md:27-28` — "save it under
  `proposals/examples/<client-slug>/` (with a `renders-web\` copy of the images) so the next
  job starts warm". `.gitignore` excludes client assets only under `clients/**`;
  `proposals/examples/**` is tracked (observed: `git ls-files proposals` lists 10 example JPEGs).
  `CLAUDE.md:339-340` says client renders and per-client configs live in the private
  `whisperroom-proposals` repo; `reference/proposal-playbook.md:320` says
  `WhisperRoom Proposals\examples\<client-slug>\`; playbook `:390-391` says copy
  `WhisperRoom Proposals\examples\peoplespace\proposal-v2.json` (parent folder exists here;
  file not checked). Three documents, three destinations; the skill's is the one loaded first.
- **Trigger:** any proposal job, followed by the standing "always push" rule.
- **Failure:** a real customer's name, room dimensions and rendered rooms on public GitHub.
  Silent — nothing warns.
- **Provenance:** observed (skill text, gitignore, ls-files); consequence derived.
- **Fix direction:** make the skill and playbook agree on ONE private destination (the
  `whisperroom-proposals` repo, or a gitignored `proposals/clients/`); add
  `proposals/examples/*` minus `example-client` to `.gitignore` as belt-and-braces.

### D-3 — HIGH — `CLAUDE.md`'s headline contract tells a fresh session to hand-build the artifact the take-off skill forbids.

- **Where:** `CLAUDE.md:23-24` "Default deliverable for a floor-plan message is an estimate
  plus a to-scale Artifact"; `CLAUDE.md:142` "Use the Artifact tool. A layout Artifact
  should be …" versus `skills/whisperroom-takeoff/SKILL.md:8-25` (STOP block: "NEVER
  hand-build … a 'here is what I read off the plan' artifact … if you are about to write
  HTML for a take-off, you are doing it wrong"). The carve-out (`CLAUDE.md:64-68`) lives
  inside the estimation section and does not qualify the "default deliverable" line.
- **Trigger:** every new session reads `CLAUDE.md` before any skill fires; a floor-plan
  message with pen numbers arrives.
- **Failure:** the 1.14.1 incident again (DEVLOG 2026-09-01: an agent with the rules in
  context still hand-built a review page) — a dead-end artifact with no patch path. The
  STOP block was added precisely because context alone did not prevent it, and `CLAUDE.md`
  is the context that pushes the other way.
- **Provenance:** observed (text).
- **Fix direction:** put the two-path rule at the top of `CLAUDE.md`: stated numbers ->
  `takeoff-check.py --html` and publish that file; no numbers -> estimate + layout artifact.
  Make line 23 conditional.

### D-4 — HIGH, silent — 1.17.0 turned in-model notes off; the docs, the review sheet and the eval scorer still depend on them.

- **Where:** `scripts/build-takeoff.rb:385` and `scripts/build-room.rb:77`
  (`NOTES_IN_MODEL = false`). Still promising the note: `skills/whisperroom-takeoff/SKILL.md:53,77,171`;
  `reference/takeoff-format.md:21,226`; the sheet itself, `scripts/takeoff-check.py:2427`
  ("Each of these builds with an ASSUMED note placed in the model at the feature itself"
  — observed in the generated UIC sheet). Still requiring the note:
  `scripts/wr-bridge-lib.rb:223` reads notes as `Sketchup::Text`, and
  `scripts/eval-floorplan.py:291-299` fails any door whose truth carries `expect_flag`
  when that text is absent.
- **Trigger:** next `eval-floorplan.py` run on `s609-3190gh` (2 assumed doors),
  `s609-3190f`, `blind-d-workshop`.
- **Failure:** the mission's own before/after pair (`s609-3190gh-baseline` FAIL vs
  `s609-3190gh` PASS) becomes FAIL/FAIL; the never-invent rule is no longer measurable;
  Gabe reads a promise on the sheet the build does not keep. `eval/RESULTS.md:237` already
  records that no row has been re-scored since 1.12.9 — the ledger is now 14 versions stale.
- **Provenance:** docs and sheet text observed; scorer consequence derived (needs SketchUp).
- **Fix direction:** decide the provenance channel — e.g. stamp `wr_takeoff/assumed`
  attributes on the door/feature groups and have `takeoff_readback` read those, so the model
  carries provenance without text; then correct the three docs and the sheet sentence, and
  re-run the suite against an Untitled model.

### D-5 — MEDIUM — Physically impossible headroom is checker-clean; the refusal comes only after Gabe has reviewed and approved.

- **Where:** `scripts/takeoff-check.py` `check_room` has no door-height-vs-ceiling
  (`:632ff`) or bulkhead-head / window-sill-vs-ceiling (`:681ff`) rule; those live only in
  `scripts/build-takeoff.rb lock_errors`. `eval/floorplans/synthetic-headroom/case.json`
  is still `{"probe": true}` and its README (`:18`) says to flip it when the checks land.
- **Trigger (observed):** `synthetic-headroom/takeoff.json` (8'6" leaf in an 8'0" room,
  bulkhead head 9'0") exits 0, writes the lock, and would write a sheet whose 3D view shows
  the leaf through the ceiling with no warning.
- **Failure:** the pipeline diagram says "fails BY NAME" at step 2; here it fails at step 4,
  in SketchUp, after the review round-trip — wasted review, and a headroom misread reaches
  Gabe as a normal-looking room.
- **Provenance:** checker exit observed; builder refusal derived (`rbtest-takeoff.py` le6-le8
  prove `lock_errors` offline).
- **Fix direction:** port the three `lock_errors` rules into `check_room`; flip the case to
  `expects.refusal`.

### D-6 — MEDIUM — Recorded non-numeric guesses (assumed hinge, declared winding) never reach the review sheet's inventory or the build report.

- **Where:** `reference/takeoff-format.md:100` says "They print on the console report and
  the review sheet"; `html_report` never reads `flag_inventory` / `ck.nonnum` (no reference
  after `takeoff-check.py:840`); the inventory block iterates `ck.assumed` only
  (`:2420ff`). `scripts/build-takeoff.rb:434` prints `assumed_inventory` only, while
  `SKILL.md:171` says assumptions are "flagged … in the build report".
- **Trigger (observed):** a probe take-off with `"hinge": {"assumed": "near", "reason": ...}`
  prints `RECORDED NON-NUMERIC GUESSES` on the console, but in the generated sheet the
  reason string appears only inside the embedded lock JSON — nowhere visible. (A declared
  winding does reach the sheet, via the `ok` line "CCW from the NE corner … (declared
  exception)"; the hinge does not.)
- **Failure:** a guessed swing direction passes review looking measured; the door is built
  on that guess and no report says so.
- **Provenance:** observed.
- **Fix direction:** append `flag_inventory` to the sheet's inventory block and door labels
  ("hinge ASSUMED"); print it in `WR_BuildTakeoff.report`.

### D-7 — MEDIUM — The `:loose` dimension count is computed and then dropped by every report.

- **Where:** `scripts/auto-dimension.rb:411-415,460` counts unattached dimension points and
  returns `:loose`; `WR_AutoDimension.report` (`:589-623`) never prints it;
  `scripts/build-takeoff.rb:308` collects `floors << [name, dims]` and `:317` calls
  `report(data, built)` without it. DEVLOG 2026-09-01 (1.17.0) claims the count exists "so a
  silent regression cannot look like success" and Next-step 1 says "If the console reports
  dimensions as `loose`" — no console path can.
- **Trigger:** `ATTACH_TOL` too tight on a real room; every dimension falls back to bare points.
- **Failure:** the exact silent regression 1.17.0 says it prevents — dimensions "not connected
  to the walls" again, reported as success.
- **Provenance:** observed by code read (pure Ruby; not executed).
- **Fix direction:** print `loose` in `report`; per-room line in build-takeoff's report;
  non-zero gets a loud line.

### D-8 — MEDIUM — `CLAUDE.md` / `README.md` / `reference/sketchup-drawing.md` / `clients/README.md` describe a repo that no longer exists.

All observed. `check-doc-paths.py`: 7 missing on this machine.

- `CLAUDE.md:7` and `README.md:7` — "There is **no application code here**." The repo holds
  66 Ruby files, the `wr_tools` plugin, a 3,122-line checker, the eval suite and `proposals/build-v2.js`.
- `CLAUDE.md:50` — generator at `...\WhisperRoom Proposals\build-v2.js`: MISSING, and
  contradicted by `CLAUDE.md:192` (`proposals/build-v2.js`, which is correct). `:51` prior
  configs in the sibling folder vs `:339` "private repo" (see D-2).
- `CLAUDE.md:280` — "`scripts/csusb-rooms.rb` is the working example": a one-off the GOAL
  puts out of scope; `build-room.rb` / `build-takeoff.rb` are the maintained examples.
- `CLAUDE.md:53-54` — Desktop `WhisperRoom\WR Proposals and Drawings\` and the brand PDF:
  MISSING on this (desktop) machine.
- `README.md:43` recommends `rbcheck.py` ("run this before handing a script over") — `CLAUDE.md:298`
  says that is how a syntax error shipped; `rbparse.py` is the check. `README.md:67` calls
  `PROPOSAL-GUIDELINES.md` the "authoritative brand spec"; `CLAUDE.md:196` says superseded.
  `README.md:73` cites a `cross-machine-handoff` skill — not installed (`~/.claude/skills/`:
  `launch`, `whisperroom-proposal`, `whisperroom-takeoff`). `README.md:91` "everything else
  in `scripts/` is read live" — true only on `CANDIDATES` machines. The script table lists
  none of the take-off tools.
- `reference/sketchup-drawing.md:6` routes "take-off" to `scale-estimation.md` (should be
  `takeoff-format.md`); `:28` laptop load path; `:35` "SketchUp 2023 and 2024 are installed"
  (2024 and 2026 per GOAL); `:37` "no Ruby interpreter … cannot run or syntax-check" (stale
  since `rbparse.py`); `:52` tag list omits `WR-Doors-Leaf`, `WR-Ceiling`, `WR-Obstruction`;
  `:123` laptop path to the scene exporter, MISSING here.
- `clients/README.md:7-8` prescribes `notes.md` + `layout.html` and never mentions
  `takeoff.json` / lock / review sheet — the actual per-client pipeline.
- Two-machine table vs code: `scripts/wr_tools/main.rb:41-48` `CANDIDATES` covers both
  layouts on both roots (a superset of the table) — **agrees**.
- **Fix direction:** one pass over the four files against the tree; delete the "no
  application code" sentence; make `README.md` point at `CLAUDE.md` for anything contested.

### D-9 — MEDIUM — The proposal skill never mentions `manifest.json`; it still sends the agent to read callouts off pixels.

- **Where:** `scripts/proposal-package.rb:11-14` writes every dimension/callout string into
  `manifest.json` "so the proposal-assembly step reads facts instead of re-deriving them
  from pixels at 300-700 dpi" (live-verified per `.forge/builder/HANDOFF-proposal-manifest.md`,
  whose open question 2 is exactly this rewrite). Grep of `skills/whisperroom-proposal/SKILL.md`,
  `reference/proposal-playbook.md`, `reference/proposal-brand.md`, `CLAUDE.md` for
  "manifest": zero hits (the one hit is the installer's skills manifest). `SKILL.md`,
  playbook `:244` and `CLAUDE.md:225` still say "Crop and zoom to 300–700 dpi".
- **Trigger:** every proposal job.
- **Failure:** the 45 minutes the 31 Aug diagnosis attributed to pixel-reading are still spent;
  the manifest is written and never read.
- **Provenance:** observed.
- **Fix direction:** skill step: "if `manifest.json` sits beside the renders, draft captions
  from its `display` strings and spot-check against the plate; if absent, fall back to
  pixels and say so in the invented-lines list".

### D-10 — LOW/MEDIUM — Take-off skill drift, small but on the critical path.

- `SKILL.md:8-14` STOP command omits `--embed-photos`; followed literally it produces a sheet
  with an empty photo panel, defeating the photo-beside-ledger comparison the sheet exists
  for. The flag is mentioned only at `:203` as a per-client decision without telling the
  agent to ask Benton. (observed)
- `SKILL.md:168` closed vocabulary lists `pen / plan-vector / stated / assumed / default` —
  omits `derived`, which `SRC_KINDS` (`takeoff-check.py:81`) contains and the skill itself
  uses 30 lines later. (observed)
- The skill's "one permitted edit" (keep from `<title>` onward) leaves `</head><body>` inside
  the published body (`takeoff-check.py:2402`); browsers tolerate it, but it is not the
  clean strip the skill describes. (observed, cosmetic)

### D-11 — LOW — The builder's "distrust the caller" is incomplete for a hand-edited lock.

- `scripts/build-takeoff.rb:169` (and `build_feature`) default a missing `sill_in` to 0.0;
  `:280` `d['hinge'].to_s` -> `''` -> treated as `near`; `:269` a missing `h_in` -> 80.0.
  The checker always emits these, so only a forced lock hits it — but the header (`:22-24`)
  promises a forced lock fails by name. (derived)
- **Fix direction:** `lock_errors` names a missing sill / hinge / h.

### D-12 — LOW, quality

- `scripts/takeoff-check.py:712` — `ok = req and False or ok if not req else False` is
  dead, unreadable logic; the next two lines do the work. (observed)
- `proposals/build-v2.js` injects `section.lead`, `pricing.lead`, `pricing.note` unescaped
  (intentional for `<b>`); the config is agent-authored so no trust boundary is crossed —
  note only. (observed)

---

## Every eval case and its checker result (observed, scratch copies, 1 Sep 2026)

"Expected" is the case README / `case.json`; "Result" is `takeoff-check.py` alone (no build).

| case | expected | checker result | verdict |
|---|---|---|---|
| blind-a-office | validates | exit 0, 1 flagged | as expected |
| blind-b-annex | validates | exit 0, 2 flagged | as expected |
| blind-c-storage | validates | exit 0, 1 flagged | as expected |
| blind-d-workshop | validates, door ASSUMED | exit 0, `door 0 at ASSUMED 8'-4"` | as expected (scorer will now FAIL — D-4) |
| blind-e-studio | validates | exit 0, run 2 ASSUMED by closure | as expected |
| blind-f-mech | validates, walls ASSUMED with chain | exit 0, 5 flagged | as expected |
| blind-g-lounge | REFUSE "not close" | exit 1, `parts … sum to 15'-9" but the value is 15'-11" — the chain does not close` | as expected |
| s609-3190f / 3190gh / 3190j (via `clients/uic-daley-library/takeoff.json`) | validates | exit 0, 3 rooms, 4 doors, 10 flagged, 1 non-numeric (3190J declared ccw) | as expected (gh/f scorer will now FAIL — D-4) |
| s609-3190gh-baseline | validates (wrongness is its job) | exit 0, 3 flagged | as expected |
| synthetic-clean | validates, no flags | exit 0, none | as expected |
| synthetic-clearwidth | validates | exit 0, none | as expected |
| synthetic-clearwidth-trap | validates (scorer catches) | exit 0, none | as expected — residual risk by design |
| synthetic-cornerdoor | REFUSE corner + overlap | exit 1, 3 named failures | as expected |
| synthetic-headroom | probe; README says checker should refuse | **exit 0, lock written** | **D-5** |
| synthetic-jog | validates | exit 0 | as expected |
| synthetic-missing | REFUSE door pos + ceiling | exit 1, both named | as expected |
| synthetic-nasty | validates | exit 0 | as expected |
| synthetic-nasty/takeoff-t2 | validates | exit 0 | as expected |
| synthetic-nonclosing | REFUSE closure | exit 1, `out by 0'-4" east-west` | as expected |
| synthetic-selfcross | REFUSE self-touch | exit 1, `revisits the corner at (0'-0", 5'-0")` | as expected |
| synthetic-sliver | validates | exit 0 | as expected |
| synthetic-unflagged | validates (scorer catches) | exit 0 | as expected |
| synthetic-units | validates | exit 0 | as expected |

No case whose README expects a refusal validates clean. The one case whose README asks for
a checker refusal that has not landed is `synthetic-headroom` (D-5).

## Skill-vs-code checklist (takeoff), both directions

Verified against `takeoff-check.py` / `build-takeoff.rb` as they exist now:

| claim | status |
|---|---|
| `--html [out]`, `--embed-photos`, `--apply-patch`, `--selftest` | observed, all four work as documented |
| `winding` object; bare `"ccw"` refused; contradiction refused; wrong start corner refused | observed (selftest + UIC 3190J) |
| `hinge` mandatory, three legal forms | observed |
| `parts` on `{assumed}` values, summed to `PART_TOL` | observed |
| `derived closure` flags; two on one axis refused | observed |
| room-level `sill` refused by name | observed |
| window `sill` required | observed |
| door `at` corner rule 0.02", overlap rule | observed |
| omitted `h` -> 80" flagged DEFAULT | observed |
| `src` vocabulary = `SRC_KINDS` | observed (skill text omits `derived` — D-10) |
| patch `src` stamp `"stated corrected on the review sheet"` | observed (`EDIT_SRC`, JS :1210) |
| `notes` key echoed, never applied | observed (hand patch) |
| stale `old` refused at display precision; sourceless `new` refused; unknown field refused; wrong job refused | observed (selftest) + hand patch reopening a polygon refused after apply |
| unit toggle re-renders from `data-in`; `old` fixed at generation so the toggle cannot desync a patch | observed (JS :1375-1404, :1494) |
| zoom, floating popover, Esc / click-outside | present in JS (:1405-1481); not clicked by a person |
| closure warning: N vs S, E vs W from edited values; parts re-summed | observed (JS :1275-1300) |
| `NOTES_IN_MODEL` | **code false, docs/sheet/scorer say true — D-4** |
| non-numeric guesses on the sheet and build report | **not there — D-6** |
| massing constants 24" / 4" slab / 1" window; 48" room gap; house 4" thick | observed in `build-takeoff.rb` |
| `eval-floorplan.py` refuses unless Untitled | observed (`SCRATCH_GUARD`) — but the builders themselves do not (D-1) |

What the code enforces that the docs never mention: door-taller-than-ceiling and
head/sill-at-or-above-ceiling refusals in `lock_errors` (builder only, D-5); mixed door
heights on one run refused (`build-takeoff.rb:135-140`) — neither the skill nor the format
doc says one cut height per run.

## What is solid (observed unless noted)

- The checker's refusal surface is real and named: 22 fixtures behave exactly as their
  READMEs say, the selftest's 50 cases pass, and every refusal phrase the scorer pins
  (`not close`, `touches the corner`, `overlap`, `no position on run 0`, `noceil ceiling`,
  `runs do not close`, `revisits the corner`, `self-touches`) is present verbatim.
- The review sheet is Artifact-safe: no CDN script, no external stylesheet or font; the
  lock JSON is `</`-escaped so a reason containing `</script>` cannot break the page
  (probed); the one JS block parses; `#autotest` builds three WebGL viewers and emits a
  patch that `--apply-patch` accepts — the 1.14.2 newline-in-string class is covered by
  the selftest's `node --check` and did not recur.
- The patch round-trip holds under three real cases: the observed autotest patch applies;
  a hand patch with `notes` + `needs-changes` applies, echoes the notes, and the full
  re-check catches a bad heater length and withholds the lock; a run edit that reopens the
  polygon is applied then refused by name with no lock written.
- The dialog's invented `at:36"` is gone: `build-room.html:476-481` seeds `at:null`, the
  field goes red and Build stays disabled.
- Grammar parity: 25 shared vectors pass; the sheet embeds the dialog's own `parseLen`.
- `proposals/build-v2.js`: the example builds to 10 Letter pages, every footer present, no
  overflow; the generator and example contain no left/right spatial claims, no STC, no
  "soundproof", no prices; the pricing sheet does no arithmetic by design.
- The UIC worked example is a good one: declared `ccw` with a reason on 3190J, every
  unmeasured value `assumed` with a reason, `pen` / `plan-vector` / `assumed` sources only.
- `CANDIDATES` in `main.rb` agrees with the two-machine table.

## Limits of this audit

- Nothing was executed in SketchUp: D-1, D-4's scorer consequence, D-7 and D-11 are code
  reads, though the pure-Ruby files parse under `rbparse.py`.
- `eval-floorplan.py` was not run (needs the bridge); the eval table above is the checker
  half only.
- The sheet's zoom, popover, unit toggle and notes box were exercised only through
  `#autotest` and code reading, not by a person clicking — DEVLOG's Next-step 3 stands.
- Prior artifacts under `.forge/researcher/`, `.forge/scoper/`, `.forge/builder/` are
  treated as **reported**.
