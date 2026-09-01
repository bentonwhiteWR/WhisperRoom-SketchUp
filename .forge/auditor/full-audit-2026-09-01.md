# Full audit — WhisperRoom SketchUp plugin and drawing skills

**1 Sep 2026 · plugin 1.19.2 · commit 14197b9 · read-only.** Four Auditors ran in parallel
(A plugin core, B proposal package and render lane, C booth geometry and dimensioning,
D take-off pipeline, skills and docs). This is the orchestrator's consolidation: one ranked
list across all four, the decisions Benton owns, and what was verified clean. The lane
reports carry the full evidence and are linked at the bottom; nothing here is stated more
confidently than its lane report states it.

Provenance words: **observed** (an auditor ran or read it), **derived** (traced through
code, not executed), **reported** (a handoff, DEVLOG or Benton said so), **assumed**.
No SketchUp, V-Ray or `ruby.exe` on the machine; pure Ruby was executed through
`scripts/rbparse.py` on SketchUp's own CRuby DLL. Every SketchUp-API behaviour is derived.

## State of the machine (orchestrator, observed)

- Repo clean and in sync with `origin/main` at 14197b9.
- Installed plugin was **1.12.9** against a repo at **1.19.2**. `install-plugin.py` was run;
  SketchUp 2024 and 2026 now carry 1.19.2 and both skills match the repo byte-for-byte.
  SketchUp was not running, so no restart is pending.
- Offline harnesses: all pass **except `scripts/rbtest-lights.py`** (root cause: finding 13).

| harness | result |
|---|---|
| `rbparse.py` | 66/66 parse |
| `takeoff-check.py --selftest` | 50/50 |
| `rbtest-proposal.py` | 107 checks pass |
| `rbtest-srgb.py` | 29 checks pass |
| `rbtest-takeoff.py` | 14/14 |
| `rbtest.py`, `-overlays` (27), `-boothlink-v3`, `-boothlink-cbl`, `-doorswing`, `-roofvent`, `-part-orientation` (45), `-live-booth selftest` (20) | all pass |
| `rbtest-lights.py` | **FAIL** — harness stale, not the tool |
| `check-doc-paths.py` | 7 paths missing on this machine (finding 17) |
| `proposals/build-v2.js` example → headless Chrome → PyMuPDF | 10 Letter pages, footer on every page, no overflow |
| UIC review sheet (`--html`, no photos) | zero external references, JS parses, autotest OK, emitted patch round-trips |

## Headline

The plugin is in materially better shape than at the 30 Aug audit: the render lane's
blocker is fixed, the manifest and the take-off checker are solid, and the sRGB re-encoder
is the best-engineered file in the tree. What remains is a short list of **silent,
customer-facing** defects, one **process** defect that will put client material on public
GitHub, and one **house rule** (build only into Untitled) that is still prose in every
Ruby builder. The single most consequential open item is the 27 Aug 7272 side-wall
question, which is still unanswered and now produces two different booths from two buttons.

---

## Ranked findings (all lanes)

Ranked by probability × cost; silent above loud; customer-facing above internal.
Lane report references in brackets.

### 1 — HIGH · silent · customer-facing — The two booth build paths draw mirrored side walls on the 6060 / 6084 / 7272 / 7296 [C-1]
`scripts/build-booth-components.rb:1312-1400` (`ASSIGN`), `scripts/booth-from-link.rb:1085-1089`,
`scripts/gen-booth.py:90-97,456-461`. `ASSIGN` swaps slot ids; the 28 Aug generator fix
swapped positions; the two compose into a double swap on the standalone *Build from real
components* path and no swap on the share-link path. Both builds close exactly and print
`exact`, so the window, vent and seam seal land at opposite ends of the side wall depending
on which button was pressed. The 30 Aug golden booth-matrix baseline was captured on the
`ASSIGN` path, so it holds the defect (observed data via rbparse; the 30 Aug live transcript
records it verbatim, reported). **The 27 Aug 7272 regression is STILL OPEN with no pinned
case.** Fix: one owner for E/W order (delete the E/W entries from `ASSIGN` or key it on
position), a pinned test on both paths, regenerate the baseline. The physical direction is
Benton's call (decision 1).

### 2 — HIGH · silent · customer-facing — The proposal skill sends client renders and configs into this PUBLIC repo [D-2]
`skills/whisperroom-proposal/SKILL.md:27-28` says save the client's `proposal-v2.json` and a
`renders-web\` copy under `proposals/examples/<client-slug>/`. That path is tracked
(`git ls-files` lists the example JPEGs, observed); `.gitignore` excludes client assets only
under `clients/**`. `CLAUDE.md:339` says the private repo; the playbook names a third
folder. With the standing "always push" rule, the next proposal job publishes a customer's
name, room and renders. Fix: one private destination in skill and playbook; gitignore
`proposals/examples/*` except `example-client`.

### 3 — HIGH · silent · customer-facing — The image lane's "even shading" checkbox is undone by every proposal-scene switch [B-2]
`scripts/proposal-package.rb:1093,1575,1629`, `scripts/export-scenes.rb:256-269`,
`scripts/proposal-scenes.rb:236-237`. The shading contract (shadows off, AO off, Light 80 /
Dark 45) is pushed once; every scene made by `proposal-scenes.rb` stores its own shadow and
rendering options and re-applies them on `selected_page=`, after the push. Tags got this fix
in 1.9.12; shadow/rendering options did not. The plain image ships with the scene's shadows
while the log says the contract is on (derived; five-minute live check in the lane report).
Fix: re-apply the contract after every page switch, as `hide_tags` already is.

### 4 — HIGH · silent · persists in the client file — An image-only batch rewrites a never-toggled saved model, then reports "Model restored" [B-3]
`scripts/proposal-package.rb:1090-1101,1145,2426-2441`, `scripts/wr-mode.rb:135-151,303-345`.
On a saved model that has never seen the Toggle button, the batch flips to draft using
`DEFAULT` and flips "back" to `MODE_FALLBACK = 'draft'`, which is the same `DEFAULT`. Result:
all annotation tags on, shadows and AO off, `WR Lights` stamped hidden into every scene, a
`WR_Mode` dictionary written. The 30 Aug readiness step "run on a never-toggled model and
inspect it afterwards" has still never happened (reported). Fix: seed both snapshots from
the as-found state, or refuse on a saved never-toggled model with a Yes/No listing the
four changes.

### 5 — HIGH · house rule — No Ruby build script asserts an Untitled model before writing [A10, C-4, D-1]
Every lane found the same thing. `scripts/build-takeoff.rb:190,219` (also **erases** any
top-level group carrying a matching room name before rebuilding), `scripts/build-room.rb:353`,
`scripts/build-booth-components.rb:2167`, `scripts/build-booth.rb:104`, plus the eleven
mutating tool scripts listed in C-4. The guard exists only on the Python side
(`eval-floorplan.py:136-146`, `rbtest-live-booth.py:176-179`) and in `WRB.scratch!`; the
bridge itself (`wr_bridge.rb:587-592`) explicitly allows named models and `WRB.tool()`
loads guard-less builders into whatever is open (observed by grep; consequence derived).
The GOAL and Benton's memory rule say the guard must live inside the Ruby job. Tension:
these are also panel tools Benton runs deliberately into client rooms. Fix direction that
keeps both: one `WRB.assert_untitled!` in `wr-bridge-lib.rb`, called at the top of every
mutating entry point when running under the bridge (a global the bridge sets), and
unconditional for `build-takeoff.rb` / `build-room.rb`, which never have a reason to
write into a saved file. Decision 4.

### 6 — HIGH · silent — Door dimensions are never drawn on any room this workspace builds [C-2, C-3, D-7]
`scripts/auto-dimension.rb:322-329` walks `model.entities` only; both room builders nest
`WR-Doors` openings two groups deep (`build-room.rb:393,413`, `build-takeoff.rb:248,275`).
`doors_on` returns `[]`, the report prints "0 door(s) dimensioned" among healthy numbers,
and the corner-to-jamb dimension the drawing standard calls "not optional" is absent.
Long-standing, not a 1.17.0 regression (derived; nesting observed). On top of it, the 1.17.0
attachment code is unrun: a nested Vertex is attached with no InstancePath
(`:249-262`), the `:loose` count the DEVLOG promises "so a silent regression cannot look
like success" is returned and **printed by no report** (`:574-600`, `build-takeoff.rb:308,317`),
and jamb ConstructionPoints are never cleared. Fix: reuse the transform-carrying `collect`
walk to find doors at depth, pass an InstancePath from every caller, print `loose` as a
warning line, erase ConstructionPoints in `clear_dims`.

### 7 — HIGH · silent — 1.17.0 turned in-model notes off; docs, review sheet and eval scorer still depend on them [D-4]
`build-takeoff.rb:385`, `build-room.rb:77` (`NOTES_IN_MODEL = false`) versus
`skills/whisperroom-takeoff/SKILL.md:53,77,171`, `reference/takeoff-format.md:21,226`, the
sheet sentence at `takeoff-check.py:2427`, and the scorer (`wr-bridge-lib.rb:223`,
`eval-floorplan.py:291-299`) which reads notes as `Sketchup::Text` and fails any assumed
door without one. The mission's own before/after pair becomes FAIL/FAIL and
`eval/RESULTS.md` is 14 versions stale (docs observed; scorer effect derived). Fix: pick a
provenance channel (attribute dictionaries on the feature groups) and update the three docs,
the sheet sentence and the scorer. Decision 3.

### 8 — HIGH · process — `CLAUDE.md`'s headline tells a fresh session to hand-build the artifact the take-off skill forbids [D-3]
`CLAUDE.md:23-24,142` ("default deliverable is an estimate plus a to-scale Artifact") versus
the STOP block at `SKILL.md:8-25`. The carve-out lives inside the estimation section and
does not qualify the headline. This is the exact context that produced the 1.14.1 incident
(observed text). Fix: put the two-path rule at the top of `CLAUDE.md`.

### 9 — HIGH-latent · silent · customer-facing — The sRGB re-encoder's only double-correct guard is a chunk V-Ray does not write [B-4]
`scripts/wr-png-srgb.rb:56,259-274`, `scripts/proposal-package.rb:2039-2062`. The refusal
list is excellent (16-bit, palette, greyscale, interlaced, bad CRC, truncated, declared
colour space; 29 checks, original never touched). But the day V-Ray saves corrected pixels
without a gAMA/sRGB chunk (an update, a VFB preference, a curve or LUT now baked by
`:apply_color_corrections => true`), a correct render is curved twice and ships `ok`. The
DEVLOG's "before mean near 0.35" tripwire is a log number, not a refusal (observed in code).
Fix: refuse by name above a stated before-mean threshold; run `probe-vray-color.rb` once.

### 10 — HIGH · root cause of the 1.12.9 gap — The update check runs once per process, never retries, compares a memoised version, and never looks at the local checkout [A1]
`scripts/wr_tools/main.rb:264-266` (comment says per panel open) vs `:298-300` (code says
per session, flag set before the request), `:271` (memoised), `:318` (`rescue → nil`).
Timeline from `%TEMP%\wr_update.log`, the bridge heartbeat and the reflog (observed): the
last install here was the panel's own Update-now click at 21:30 on 31 Aug at 1.12.9;
SketchUp was never restarted after it; four more versions were committed from this machine
(whose scripts come live from the checkout, so nothing looked stale); SketchUp was closed
for all fourteen pushes on 1 Sep. Fix: check on every `ready`/`rescan` with a throttle, set
the flag only after a 200, read VERSION from disk, and add a zero-network "checkout is newer
than the installed plugin — reinstall" comparison.

### 11 — MEDIUM-HIGH · silent · customer-facing — Deck orientation is two measured rules under three exception layers; 1.19.2 makes the 7296 contradict the reference's own invariant [C-5]
`scripts/wr-deck.rb:789-790,836-839,982-993,1012-1160`. Hand-letter mirror, per-file 180
(4260, 4872), per-footprint mirror (7272 FL+CL, 7296 FL). `MIRROR_DECK_KINDS[[98,74]]`
mirrors the 7296 floor but not the ceiling, while the ceiling's half turn is read off that
floor, so floor and ceiling hinges are on opposite sides by construction, against
`reference/floor-ceiling-geometry.md`'s "coplanar hinges" invariant (derived). Never
inspected by anyone: 4230, 4242, 4284, 4848, 8484, 9696, 10284, 84102, 96144, 102102,
102126, 102168, 102186 S. Fix: the per-part ceiling measurement the Fixer handoff describes;
until then print floor/ceiling hinge positions side by side on every deck build.

### 12 — MEDIUM · customer plate — The Enhanced booth label shows the drawn 7'-0 5/16", not the catalogue 7'-1"; HX and caster-plate booths get the Standard height silently [C-7]
`scripts/dimension-booth.rb:86,395-402,594-598,697-701`. `CLAUDE.md:121-125` says quote the
catalogue figure for fit. Standard follows it (83.0); Enhanced draws 84.3125. Now reachable:
25 Enhanced keys in the data (observed). HX gets a console warning; caster-plate lift is
not detected at all. Fix: catalogue height table by variant; detect `_HX` / `_CP` and refuse
or label the measured extent.

### 13 — MEDIUM · internal — `rbtest-lights.py` has been red since 1.10.0 because the harness is stale, not the tool [B-1]
Real exception (observed by re-running under a rescue): `uninitialized constant
WR_DropLights::LUMEN_GAIN`. `LUMEN_GAIN` was added in 1.10.0; the harness's constant list
was last touched at 1.9.9. Lifting the constant makes 43/44 pass; the last is the pinned
lumen expectation exactly 10× stale. Three DEVLOG entries say "left alone". Fix: add the
constant, re-pin at 10×, and make `rbparse.rb_eval` surface `$!.message` so the next stale
constant names itself.

### 14 — MEDIUM · silent — Two one-line bugs in the plugin core [A2, A3]
- The bundled copy cannot run the room tools: `install-plugin.py:106-111` copies `.rb`
  only, and `build-room.rb:503` needs `build-room.html` beside it. Installed
  `wr_tools/scripts/` holds zero non-`.rb` files (observed). Bites any machine without a
  checkout, which is the case the installer's docstring exists for.
- SAVE AS SHOP DEFAULT never ships per-script settings: `main.rb:646-654` reads
  `sc['settings']` and `sc['id']` from `scan`, which emits neither (observed; shipped
  `defaults.json` holds only `slots`, `slot_icons`, `pinned`).

### 15 — MEDIUM · unverified foundation — The whole shop-defaults feature rests on `Sketchup.read_default` accepting a NUL-bearing sentinel [A5]
`main.rb:618-631`. If it raises, the rescue writes the code fallback into the registry and
every key reads as "set" forever, on every machine, silently (assumed; no record it was
verified on empty prefs). One Ruby Console line settles it:
`Sketchup.read_default('WR_Tools', 'zz_never_set', " wr-unset")` must return the sentinel.
Also A4: the shop default pre-empts the old `pinned → slots` migration (`main.rb:770-777`),
the one path where an update replaces someone's layout (derived, low probability today).

### 16 — MEDIUM — Take-off pipeline: three gaps between what the docs promise and what reaches Gabe [D-5, D-6, D-9]
- Physically impossible headroom (door taller than ceiling, bulkhead above ceiling) is
  checker-clean: `synthetic-headroom` exits 0 and writes a lock (observed); the refusal
  lives only in the builder, after the review round-trip. Port the three `lock_errors`
  rules into `check_room`.
- An assumed `hinge` reaches neither the sheet's inventory nor the build report
  (observed by probe); a guessed swing passes review looking measured.
- The proposal skill and playbook never mention `manifest.json`; they still say crop and
  zoom pixels at 300–700 dpi. The manifest is written and never read, so the 45 minutes
  the 31 Aug diagnosis found are still spent (observed).

### 17 — MEDIUM — The docs describe a repo that no longer exists [D-8, A11]
`CLAUDE.md:7` and `README.md:7` "no application code here" (66 Ruby files, a 3,122-line
checker, an eval suite); `CLAUDE.md:50` generator path missing and contradicted by `:192`;
`:280` names a one-off client script as the working example; `README.md:43` recommends
`rbcheck.py`, which `CLAUDE.md` says shipped a syntax error; `README.md:73` cites a
`cross-machine-handoff` skill that does not exist; `reference/sketchup-drawing.md:6,35,37,52`
stale on take-off routing, SketchUp versions, Ruby availability and the tag list;
`clients/README.md` never mentions `takeoff.json`. `CANDIDATES` in `main.rb` does agree
with the two-machine table (observed). Fix: one pass over the four files against the tree.

### 18 — MEDIUM — Standard-path booth link quietly substitutes tool-chosen defaults [C-8, C-9, A6]
`booth-from-link.rb:850` (missing variant → S), `:868-871,972-976` (untranslatable pack →
layout default, console only; only Enhanced refuses), `:396` (every `#3=` 7-in companion
falls to the default), `wr-overlays.rb:394-455` (desk/MJP hosts relocated). It never picks a
booth model (observed: `#3=` refuses unknown indices, 146 checks). A malformed `#d=` is
reported as "no design id" rather than "damaged link" (`:196-204`). The panel's paste-a-link
regex (`panel.html:888`) does not recognise `#3=` at all. Fix: treat `odd` on Standard as
Enhanced does; require `v`; distinguish malformed from absent; add `#3=` to the regex.

### 19 — MEDIUM — Proposal package audit-trail and state leftovers [B-5, B-6, B-7, B-8, B-13]
Still open from 30 Aug: `warn_output_size` logs a size and a write that do not happen
(`:1654-1685`); `reset_stale_batch` restores from a previous batch's snapshot because
`finish` never clears four instance variables (`:2675-2691`). New: the EV log ignores ISO,
which the lights tool now writes (EV 14.23 reported on a model at EV 9.23); the WIDTH field
label says the opposite of what the code does; the Hide-walls picker can write to a scene
other than the one it names if a tab is clicked mid-dialog.

### 20 — MEDIUM — The MJP still hands `axes_for` a guessed 8.0 height, the exact defect that stood the desk on edge [C-6]
`scripts/wr-overlays.rb:910` vs the desk fix at `:858` (`nil`). The 1.19.2 half-turn was
tuned on top of the guessed axes. Fix: pass `nil`; re-check `MJP_SPIN180` afterwards.

### 21 — LOW-MEDIUM — Bridge hygiene [A10]
The `enabled` marker has existed since 31 Aug, so the "off by default" listener auto-starts
on every SketchUp 2026 launch; `run/` holds 3,953 files and `out/` 1,971, never swept
(observed). `update_now` runs a bare `git pull` on the live checkout (`main.rb:378`); a
conflict would put markers into `.rb` files every button loads. Use `--ff-only`.

### 22 — LOW — Everything else, one line each
`WR_Mode` still nests operations (`wr-mode.rb:297` / `wr-materials-swap.rb:248,292`; third
audit to say so). Lighting panel displays pre-gain lumens (2,000 shown, 20,000 written) and
still prints "1.9.9". A scene named `</script>` kills the proposal dialog (observed).
`arch()` prints `11'-12"` (observed). 24 of 56 panel scripts draw the default icon; "V-Ray
renders" is missing from the panel's category order. `installed_versions()` misses 2026's
nested exe when no APPDATA profile exists. Skills installer merges but never removes files
renamed inside a skill. `build-booth.rb` IEP lift is a documented-stale 0.3125. Take-off
skill's STOP command omits `--embed-photos` and its `src` list omits `derived`. Three stale
comments in `proposal-package.rb` still claim it writes V-Ray settings. Dead logic at
`takeoff-check.py:712`. Nothing in the button path looks at a pixel.

---

## Decisions Benton owns

1. **7272 / 7296 side wall.** On a real booth, taking the door wall as reference, does the
   46" window panel sit at the door end or the far end? Every fix to finding 1 depends on it.
   It has been asked since 27 Aug.
2. **Where client proposal configs and renders live.** The private `whisperroom-proposals`
   repo, or a gitignored folder here. Finding 2 cannot be fixed until one is named.
3. **How an assumed value is carried in the model now that text is off.** Attribute
   dictionaries on the feature group is the suggested channel; the scorer, the sheet
   sentence and three docs follow from it (finding 7).
4. **Untitled guard scope.** Universal in `build-takeoff` / `build-room`, and bridge-only for
   the panel tools you deliberately run into client rooms? That is the recommendation.
5. **Run `probe-vray-color.rb` once** so the sRGB post-step is either retired or provably
   permanent (finding 9).

Two five-minute checks at the desk would turn derived findings into observed ones: one
scene with shadows ON, SHADING ticked, exported as Image (finding 3); the `read_default`
sentinel line (finding 15).

## Prior audits, re-checked

| audit | fixed | still open | regressed / new state |
|---|---|---|---|
| 15 Aug script audit (7 + 2 notes) | 4 (dims tag erase, plate tags, explode compounding, range off-by-one) | 3 (`arch()` 12", `to_f` standoffs, dedupe by name) | Enhanced-height note now live (finding 12) |
| 30 Aug proposal-package audit (13) | 5 (render gate, annot leak, lost rows, busy guards, restore box) | 5 (stale reset, size log, nested ops, no pixel gate, dead comments) | 3 dormant |
| 28 Aug render lane F1–F10 | 7 | 2 (F6, F8) | F9 half |
| 28 Aug lighting C1–C10 | C2, C3, C5, C7, C8 fixed | C6, C9 by design | C1 tag half fixed; **shadow half moved into finding 3** |
| panel audit | 1 (rename dots) | 3 | "no script falls to default icon" regressed (24 do) |

## What is solid (verified clean)

- All 66 Ruby files parse; every harness but one passes; the sRGB encoder ran end to end in
  SketchUp's CRuby with every byte re-verified.
- `panel.html` JS parses, ES5-only, every sink escaped, every attribute double-quoted; the
  proposal dialog's real `html()` evaluates and its 18 KB script parses; the review sheet
  has zero external references and its patch round-trips through `--apply-patch`.
- The take-off checker's refusal surface: 22 eval fixtures behave exactly as their READMEs
  say; no refusal case validates clean; the invented `at:36"` seed is gone.
- The `#3=` link decoder: complete-or-refuse, never picks a model.
- `wr-booth-data.rb` is byte-identical to a fresh generator run against the live pl-data.
- The proposal package's launch order, re-entrancy, lost-row accounting and manifest; the
  batch's restore path reaches `finish` exactly once on every exit.
- The lighting tool's V-Ray discipline: transacted writes, read-back, one sanctioned ISO
  write with a printed undo. Brightness and warmth are real now.
- Installed plugin and both skills byte-identical to the repo; committed SketchUp prefs
  carry no credentials; the bridge's atomic-result and deny-list properties.

## Lane reports

- `.forge/auditor/full-audit-A-plugin-core.md` · `HANDOFF-A.md`
- `.forge/auditor/full-audit-B-proposal-render.md` · `HANDOFF-B.md`
- `.forge/auditor/full-audit-C-booth-geometry.md` · `HANDOFF-C.md`
- `.forge/auditor/full-audit-D-takeoff-skills-docs.md` · `HANDOFF-D.md`
- Scratch evidence (not committed): `.forge/auditor/eval-run/`, `.forge/auditor/proposal-run/`
