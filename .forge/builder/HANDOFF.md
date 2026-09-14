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
