# Builder HANDOFF — floor-plan intake slice 1 (2026-08-31)

Goal reconfirmed against `.forge/GOAL.md` before writing this: the accuracy
half of the mission (Done-means 2, 3, and most of 4), built to
`.forge/scoper/floorplan-intake.md` **steps 1–6** with Benton's Q1–Q5
answers applied. Plugin at **1.11.0**. Prior handoff preserved at
`.forge/builder/HANDOFF-proposal-manifest.md` (its live checklist may still
be in flight — a second Builder was running it concurrently in the same
SketchUp).

**SketchUp 2026 was OPEN with the bridge listening for most of this
session, so unlike the sibling task this one is largely live-proven:** the
UIC take-off built all three rooms through the bridge in 0.34 s, the scorer
read them back at 0.00" error, the baseline reproduction of the 31 Aug
failure scored 20.00"/9.00"/2-unflagged against the same truth
(`eval/RESULTS.md` rows 1–2), and both corner-door refusals fired live with
the model census-verified unchanged. What is NOT live-proven is listed
under Open-questions.

## Produced

| file | what |
|---|---|
| `scripts/takeoff-check.py` | Validator: `{v,src}` grammar (ported from parseLen), parts-sum EXACT, polygon closure, door-position/ceiling fail-by-name, corner-door refusal, ASSUMED inventory, `takeoff.lock.json` emit (deleted on failure), `--html` review sheet, `--selftest` (15 fixture cases + 25 grammar vectors, mutation-checked). |
| `scripts/takeoff-vectors.json` / `.html` | The 25 shared grammar vectors and a browser harness that extracts parseLen live from build-room.html. |
| `scripts/build-takeoff.rb` | Lock file -> every room: WR_BuildRoom geometry reused (polygon/mitre/wall_run/door/band), per-room ceiling slab (WR-Ceiling), heater/bulkhead/window massing (WR-Obstruction), ASSUMED text notes at the features (WR-Notes), auto-dimensioned, idempotent by room name, `Refused` errors by name (`lock_errors` re-validates so a forced lock still refuses). |
| `scripts/eval-floorplan.py` | The scorer: checker -> bridge build -> `WRB.takeoff_readback` -> vs `truth.json`, inches table, exit code, `--record` appends to `eval/RESULTS.md`. |
| `scripts/build-room.rb` | Autorun guard (`unless $wr_suppress_autorun \|\| $wr_no_autorun`); new pure `door_errors`; `build` refuses corner doors by messagebox BEFORE building (was silent leaf-in-solid-wall). |
| `scripts/build-room.html` | "+ door" seeds `at:null` -> empty red field, placeholder "from corner — measure it", Build blocked, hint names the door; door-height field (80" labeled standard-not-measured) now travels in the payload. |
| `scripts/wr-bridge-lib.rb` | `WRB.takeoff_readback` — per room-group floor vertices, openings, leaf/opening counts, ceiling z, obstructions, notes, in the room's own frame. |
| `scripts/rbtest-takeoff.py` | Offline: `door_errors` + `lock_errors` lifted verbatim into the CRuby VM, 10 checks, mutation-checked (corner test weakened -> de1/de2 FAIL — run, 31 Aug). |
| `reference/takeoff-format.md` | Normative schema. |
| `clients/uic-daley-library/` | `takeoff.json` (worked example, from MY OWN read of the photos), `notes.md`, `plans/` copies (gitignored — verified by `git check-ignore` before commit). |
| `eval/` | `RESULTS.md` ledger (baseline FAIL row + 4 PASS rows), `floorplans/derive-s609.py` (PDF-vector truth derivation, byte-identical re-runs), cases `s609-3190gh`, `s609-3190gh-baseline`, `s609-3190j`, `s609-3190f`, `synthetic-clean`. |
| `scripts/wr_tools/VERSION` | 1.10.7 -> **1.11.0**. |
| `DEVLOG.md` | 1.11.0 entry. |
| `.gitignore` | + `*.lock.json`, `*.review.html` (generated). |

## Read-first

1. `reference/takeoff-format.md`, then `clients/uic-daley-library/takeoff.json`.
2. `eval/RESULTS.md` — the measured before/after.
3. `eval/floorplans/s609-3190gh-baseline/README.md` — why a deliberately
   wrong fixture is committed.

## Assumptions

- **observed:** IMG_7594/5/6 re-read personally. Two divergences from the
  Scoper's illustrative mockup, both recorded in the takeoff's
  `interpretations`: (a) J's 8'10" is a VERTICAL corner->jamb chain on the
  door wall (so J's door position IS measured, and the mockup's
  "8'10" vs 8'1" disagree" panel was a misread); (b) J's depth and ceiling
  are stated nowhere -> recorded as `assumed` with reasons, which is why the
  ASSUMED inventory has 10 entries, not the 5 the spec's AC-1 predicted.
- **derived:** all PDF truth numbers, from one pen anchor (18'11" across
  x 245.46..289.14 pt -> 5.1969 in/pt); `derive-s609.py` re-derives and
  cross-checks them (G width 111.0" = pen 9'3"; partition center 113.5" vs
  pen 9'5"; band depth PDF 174.6" vs pen 172" — pen governs, tol 2").
- **assumed (flagged in truth/READMEs):** J's 172" depth (band carry); F's
  jogged 6-run polygon resolving the 9'3"/9'6" pair — Gabe should confirm.
- **assumed:** heater massing height 24", ceiling slab 4", window 1" deep —
  representation constants, documented in takeoff-format.md, not flagged.

## Open-questions / not live-proven

1. **Dialog click-through (AC-11/12/13)** — needs a human: open Draw floor
   plan -> More detail -> + door: expect empty RED position field, Build
   disabled, hint "door 1 has no position — measure corner -> near jamb";
   Door height field pre-filled 80" with the note; type `at 0` -> Build,
   expect the corner-door messagebox and nothing built. The JS compiles
   (cscript) and the refusal path ran live via the bridge; only the
   pointer-and-keyboard layer is unverified.
2. **Review sheet in light mode / by Gabe.** Dark-mode render verified via
   headless Chrome against the approved mockup; nobody has shown it to Gabe
   (the Scoper's Q1 assumption still stands).
3. **Spec steps 7–9 untouched by design:** panel "Build from take-off…"
   button (until then: load build-takeoff.rb from the Ruby Console, or
   ENV WR_TAKEOFF via bridge), `eval/gen-plans.py` + the
   nonclosing/missing/nasty synthetic cases + tier-2 transcription runs
   (AC-15/16's fresh-transcription half), and the `reference/floorplan-intake.md`
   protocol rewrite + scale-estimation pointer + skill update (AC-17).
4. **Field truth.** Every ASSUMED value in the UIC job (4 door
   positions/heights, J depth + ceiling, F's jog) awaits a tape measure;
   the model carries the notes.
5. The rooms built during scoring are still in the open scratch model
   (3190G+H, 3190J, 3190F side by side, plus `clean` at the origin area) —
   left for Benton to eyeball; safe to delete, the scorer rebuilds them.
