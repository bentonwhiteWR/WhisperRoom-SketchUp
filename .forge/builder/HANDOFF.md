# HANDOFF — Builder: Intelligence Security Laboratories, MDL 6060 E ENV (14 Sep 2026)

## Produced
- `clients/intelligence-security-laboratories/takeoff.json`: one room, "ISL Room 452", 6 runs.
  It uses the client's email numbers (65/67 x 100, ceiling 90/114) and supersedes the
  booth-builder fields.
- `clients/intelligence-security-laboratories/notes.md`: the client block verbatim,
  provenance per dimension, the fit table, the two-door analysis and the open questions.
- Photos are in `clients/intelligence-security-laboratories/plans/` (gitignored, checked
  with `git check-ignore`). The lock file and review sheet are generated and gitignored.
- Screenshots (not committed): `.forge/builder/isl-6060/isl-room452-top.png` and
  `.forge/builder/isl-6060/isl-room452-angled.png`.
- **Tool fix, 1.71.1.** `scripts/booth-from-link.rb` `component_for` now builds a
  `STDWL<w> VNT NV` pack as the no-vent plug wall (`40NV` / `ENH 35.5NV`). Before, it built
  a vented `40VNT`.
  - Five cases were added to `scripts/rbtest-boothlink-cbl.py`: 0 failures.
  - `rbparse.py`: all 77 files parse.
  - `scripts/wr_tools/VERSION` bumped to 1.71.1.

## Built live (observed)
- **Model:** Benton's saved `Z:/Sketchup/ClientDrawings/Intelligence Security Laboratories MDL 6060 ENV.skp`
  (0 entities at start). Not saved.
- **Room:** `WR_BuildTakeoff.build_from(lock)` built 8 wall solids, 1 door and 8 dimensions.
- **Booth:** `WR_BoothLink.build_from_payload` with parts from `P:/Sketchup/NewMasterComponentList`.
  - 52 instances, ceiling required 85.00".
  - Translated (1, -63, 0) in, no rotation: shell x 1..63, y -63..-1. The booth door faces the room door.
- **Rebuild:** the first 100 x 65 room and the vented booth were erased (only this session's
  entities) and rebuilt.

## Fit (details in notes.md)
- Gaps: west 1.0, north 1.0, east 2.0 (an interior light's bounding box reaches 0.78 from
  the east wall).
- Ceiling: 5.0 in against the 85 install height, 5.69 against the drawn top.
- Room door fully open: 1.0 in clear of the booth corner seal.
- Room door closed: the booth door opens fully, 9.6 in to the handle.
- Room door at 18 in: the rule zone overlaps the client's 78 in line by 8.5 in. Geometrically,
  the leaves miss by 2.1 in at the assumed 6 in jamb offset (0.9 at 8 in).
- Sliding door: fits, with 9.5 in spare.

## Not done / gaps
- No booth-to-wall or door-to-corner dimensions. `dimension-whisperroom.rb` is a click-pick
  tool, and `dimension-room-now.rb` would stack a second chain on the build's dimensions.
- **Unexplained: the room dimensions left the model twice.**
  - Once after the first booth build.
  - Once between the placement job and the screenshot jobs.
  - Ruled out by test: tag toggles, camera changes, `shot`, `DisplayText`.
  - Restored by re-running `build_from`, with the booth transform unchanged; 8 dimensions at
    hand-off.
  - Same symptom as the Suites 128/114 loss. Cause not found.
- **Not investigated:** the booth's "Standard Light" bounding box pokes 1.22 in past the shell
  (x 64.22).
- `WR-Ceiling` and `WR-Booth-Deck` are hidden, and the camera was changed. Both are unsaved
  model state.
- The review sheet was not published (the orchestrator publishes it).

---

# HANDOFF — Builder: Wyatt Shepherd proposal packs (14 Sep 2026)

History: earlier today the Suites 128 & 114 take-off was built live and the quoted MDL 4872 S
was placed in all three rooms (commits e0056ce, 9d5e7a1). The detail is in
`clients/suites-128-114/notes.md` and in git history for this file. The AUTO-SET handoff is
still at `.forge/builder/HANDOFF-autoset.md`.

## Pack 2 (current) — Audiology Compact, MDL 4848 S, RM 128

### Produced
- **PDF:** `C:\Users\bento\Desktop\ProposalFiles\Wyatt Shepherd\Wyatt Shepherd-Audiology-Compact-Booth-Renderings.pdf`.
  5 pages, 1,339,284 bytes (1.34 MB).
- **Size:** under the 2.5–3.6 MB band. The playbook allows that; there are only five plates.
- **Config:** `WhisperRoom Proposals\examples\wyatt-shepherd-compact\proposal-v2.json`.
- **Web plates:** `WhisperRoom Proposals\examples\wyatt-shepherd-compact\renders-web\` (5 JPEGs).
  Not committed.
- **Scratch:** `scratchpad\wyatt-compact\`, with check rasters in `check\`.

### Source and restart
- Built from Benton's re-export: plates timestamped 12:53–12:54, manifest generated 12:55.
- The stopped attempt's scratch folder (the transparent-plate flatten output) was deleted
  before starting. No config from it had been written.
- Manifest and file headers confirm every plate is opaque RGB, so nothing was flattened.
  Plates 3–6 were trimmed; the hero, plate 1, was not.
- The first pack, `Wyatt Shepherd-Booth-Renderings.pdf`, has the same SHA-256 before and
  after (d58c5005…7ffe).

### Structure
- Cover hero: plate 1 (render).
- One section, "Audiology Compact", booth 1 of 1, section descriptor "MDL 4848 S · RM 128".
- Pages 2–5: plates 3 (dimensioned view), 4 (window side), 5 (rear and ventilation),
  6 (plan).
- **Plate 2 dropped:** same camera as the hero, so it would have repeated the hero on page 2.
- **No ramp** is in any plate (observed). No Basic Plus options and no RM 128 layout note.
- Captions follow the plates, not the file names. The names still say
  "in Suite 114 — 10'11 x 9'10 room (2)", which is wrong.

### Verified (observed)
- The generator's fit table has no overflow; the plan is `free 0px`.
- PyMuPDF check:
  - 5 pages, all 612×792.
  - I looked at every page and at a stacked crop of all five bottom edges.
  - The footer is on pages 1–4, and page 5 ends in the closing band.
- The room runs match manifest `measured` values.
- The booth label "Audiology Compact / MDL 4848 S" is legible on plates 2–6 and matches
  the manifest text entity.

### Open for Benton
- **Preflight "11 items outside the room":** plate 4 has an unidentified short dark
  vertical line at its right frame edge, about y 328–358 px, outside the room. It is
  visible on page 3 at the plate's right edge. It is not captioned. It is the only
  candidate stray geometry in the six frames.
- **Cut-off callouts, left out of the captions:** "…8 1/2"" behind the door leaf on
  plate 2 (not used), and "…/2"" at the frame edge on plate 3.
- **Clipped callouts, transcribed anyway:** plate 6 shows "4' 7 1/2" clipped by the work
  surface and "4' 8 1/2" with no inch mark. Both are transcribed, because plate 3 shows
  them in full and the manifest has 4' 8 1/2".
- **Not captioned:** the grey box with a round opening at the booth base.
- **Cover card wrap:** the third card's sub-line
  ("Exterior · dimensioned · side · rear · plan") wraps to two lines. Nothing overflows.

## Pack 1 — MDL 4872 S (Audiology Basic Plus), RM 114 and RM 128

- **PDF:** `C:\Users\bento\Desktop\ProposalFiles\Wyatt Shepherd\Wyatt Shepherd-Booth-Renderings.pdf`,
  10 pages, 2.96 MB.
- **Config:** `WhisperRoom Proposals\examples\wyatt-shepherd\`, uncommitted.
- **Structure:** cover hero is plate 01; Option 1 (RM 114) is plates 03–06; Option 2
  (RM 128) is plates 07 and 09–12. Plates 02 and 08 were dropped as same-camera repeats.
- **Invented wording still open for Benton:**
  - the RM 128 note, "Layout note: RM 128 is a tight room for this booth, and in this
    position the booth window would not be easily accessible.";
  - the section labels "Recommended layout" / "Alternate layout".
- **Preflight:** no stray geometry was seen in that pack's 12 plates.
