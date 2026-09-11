# HANDOFF — booth dimensions stop at the vent box on an EFS wall

**Outcome: root-caused and fixed offline; UNRUN in SketchUp.** The 1.42.0
vent-box rule discarded the EFS silencer's face as "a fitting" because it has
less area than the duct faces. An `_EFS` wall part is now measured to its
assembly's outboard edge; every other wall part keeps the 1.42.0 trim. No
VERSION bump, no push (orchestrator's call).

## Produced

- `C:\Users\bento\Documents\Claude\Sketchup\scripts\dimension-whisperroom.rb` —
  `EFS_RE`, `EFS_PROUD`, `efs_part?`, `efs_faces_from_names`, `measure_to`
  (pure section); `catalogue_extent` takes an optional per-face EFS list;
  `vent_box_bound` records `:level` / `:rule`; `dimension()` prints an `EFS:`
  line per part with the vent-box level and the assembly edge, and the
  catalogue line names the 10 in faces.
- `C:\Users\bento\Documents\Claude\Sketchup\scripts\rbtest-boothdims.py` — 148
  checks (was 127). The CP fixture feeds raw assembly boxes through
  `measure_to`; the fault is pinned by name ("THE FAULT: the vent-box rule on
  an EFS part picks the duct face"); the 1.42.0 trim stays pinned on non-EFS
  parts; the 1.42.0 record (6 7/16) is pinned as a named cross-check mismatch.
- `C:\Users\bento\Documents\Claude\Sketchup\.forge\builder\verify-efs-dims.rb` —
  the live check. Load it in SketchUp with a link-built CP+EFS booth selected.
  It reads every vent part's faces, reports the reach past the corner seals by
  name, draws the set, reads the strings back, and JSON-summarises. Ctrl+Z
  removes the set it drew.
- `C:\Users\bento\Documents\Claude\Sketchup\.forge\fixer\efs-dims\` —
  `NOTES.md` (root cause, the three readings of "10", the open number),
  `repro-efs-trim.py` with `repro-BEFORE.txt` / `repro-AFTER.txt`,
  `suite-AFTER.txt`, `mutants.txt`, and Benton's screenshot.
- `DEVLOG.md` — entry under 2026-09-11.

## Read first

1. `.forge/fixer/efs-dims/NOTES.md` — especially "What the part actually
   measures (the open number)".
2. `scripts/dimension-whisperroom.rb` — the header paragraph "A WALL PART IS
   MEASURED TO ITS VENT BOX FACE, OR TO ITS EFS ASSEMBLY" and `measure_to`.
3. DEVLOG 1.42.0 and 1.40.0 entries — the two prior field runs this reverses
   for EFS parts and builds on, respectively.
4. Read-only authority, untouched:
   `C:\Users\bento\Documents\Claude\WhisperRoomQuote\assets\layout-render.js`
   (`EPROT = EFS ? 10 : VPROT`, `clrIn`) and
   `Z:\Sketchup\NewMasterComponentList\_component-probe.tsv` (part thickness).

## Assumptions

- **assumed** — Benton's "10 total from the booth corner" means the EFS face
  lands 10 past the shell corner in place of the vent box's 5.5, not +10 on
  the run and not 5 at each end. Matches the quote tool's EPROT and his word
  "total"; he has not confirmed the reading.
- **derived, not observed** — the EFS part reaches 10 1/8 past the seals
  (12.125 thick − 1 in panel − 1 in seal). Holds only if all of the extra
  bulk is outboard of the panel; the builder's own note says a VSS/EFS part
  "carries bulk on BOTH sides". The probe TSVs carry z levels only, so the
  thickness-axis faces of an EFS part have never been read offline.
- **assumed** — the screenshot booth's outer-shell vent parts carry `_EFS` in
  their names (booth-from-link composes it on the Standard shell; an
  Enhanced booth's outer shell is Standard parts). If Benton placed the vent
  parts by hand under another name, the tool has no way to know an EFS is
  there and the fix does nothing — the console would show `rule vent_box`.
- **assumed** — the 1.42.0 statement ("should be 8'7.5" x 6'7.5"" on an EFS
  booth) is superseded by today's, not a different product case.
- Values in the fix that are not measured: `EFS_PROUD = 10.0` (cross-check
  only, never drawn); the fixture's 108.125 / 84.125 (derived as above).

## Open questions

- **What does the placed EFS part actually reach past the seals?** 10 1/8
  (probe-derived), ~6 7/16 (the 1.42.0 record), or something else. The live
  verifier prints it; if it is not within 10 ± 1/4 the string reads the
  part and the console flags `*** ACROSS`, and the question goes to Benton:
  is the part wrong, or is 10 a product figure the part does not carry?
- Whether Benton wants the 7296 E of 1.42.0 (`8' 7 1/2"`) re-read under this
  rule — it would now draw the silencer reach on both vented walls.
- Should the EFS console line be client-safe-stripped in proposals? It is
  console text only; nothing new is drawn as a label.
- `dimension-booth.rb` (shelved, `# @shelf archive`) still carries the old
  `VENT_PROUD` dial and its EFS warning; untouched, due for deletion.
