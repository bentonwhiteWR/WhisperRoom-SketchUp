# HANDOFF — Builder: proposal packs (14 Sep 2026)

History: earlier today the Suites 128 & 114 take-off was built live and the quoted MDL 4872 S
was placed in all three rooms (commits e0056ce, 9d5e7a1). The detail is in
`clients/suites-128-114/notes.md` and in git history for this file. The AUTO-SET handoff is
still at `.forge/builder/HANDOFF-autoset.md`.

## Current — Intelligence Security Laboratories, MDL 6060 ENV (No Ventilation)

### Produced
- **PDF:** `C:\Users\bento\Desktop\ProposalFiles\Intelligence Security Laboratories\Intelligence Security Laboratories-Booth-Renderings.pdf`.
  New folder. 5 pages, 1,640,311 bytes (1.64 MB).
- **Size:** under the 2.5–3.6 MB band. The playbook allows that; there are only five plates.
- **Config:** `WhisperRoom Proposals\examples\intelligence-security-laboratories\proposal-v2.json`.
- **Web plates:** `renders-web\` beside the config (5 JPEGs). Not committed.
- **Scratch:** `scratchpad\isl\`. Check rasters: `check\` (first build), `check\v2\`, and
  `check\v3\` (final).

### Source and structure
- Manifest generated 16:25. All plates are opaque RGB, so nothing was flattened.
- Every plate was trimmed, the hero included, because Benton said "margins only".
- **Cover hero:** plate 1. It is cropped tight to the room top and bottom, and trimmed at
  the sides to a 2.15:1 frame so it fills the cover slot. The grey render background is
  kept.
- **Pages 2–5:** plate 3 (Front Elevation), plate 4 (Side Elevation), plate 5 (Rear View),
  plate 6 (Top-Down Floor Plan).
- **Plate 2 dropped:** same camera as the hero.
- **Section:** "MDL 6060 ENV", booth 1 of 1, descriptor "No Ventilation" (read off the
  plate label).
- **No ventilation claims:** none on any page.
- **Closing band:** adapted to drop "ventilation" from the standard closing sentence.

### Verified (observed)
- The generator's fit table has no overflow.
- PyMuPDF check:
  - 5 pages, all 612×792.
  - I looked at every page and at a crop of every bottom edge.
  - Pages 2–5 of the final build are pixel-identical to the rasters I checked.
- **Two cover fixes before the final build:**
  - The first hero, a tight trim, rendered at only 344×367 px. I re-cropped it wider.
  - The client name wraps, so the headline is four lines. With a three-line budget, the
    callout sat on the footer rule. `headlineLines` is now 4, and the gap is clear.
- **Plan callouts:** booth 5' 2" × 5' 2", room 8' 4" × 5' 5". Each callout's extension lines
  match those edges. The manifest confirms 8' 4" and 5' 5".

### Open for Benton
- **Hidden "Std door frame 40" adaptor (bottom)":** no gap is visible at the booth door base
  on plates 1–3 at 4× zoom.
- **Preflight "3 items outside the room"** — candidates, none captioned:
  - a short dark vertical stub above the plan's 5' 2" dimension, beside the 8' 4"
    extension line (plate 6, page 5);
  - on plate 5, dimension lines drawn outside the room with no legible text.
  - Otherwise nothing out of place is visible.
- **Room door:** "the room door and its swing" on the plan is derived. The arc is centred
  on the room's corner and the leaf ends at the booth face. There is no label.
- **Omitted from the copy:**
  - "Room 452", which appears in scene names only;
  - "Enhanced", which is on no plate;
  - the desk and hinge side, which no plate clearly shows;
  - glass: the room's front reads as translucent, but its material isn't clear.

## Earlier packs today (all uncommitted in the private repo)
- **Wyatt Shepherd, Audiology Compact (MDL 4848 S, RM 128):**
  `Desktop\ProposalFiles\Wyatt Shepherd\Wyatt Shepherd-Audiology-Compact-Booth-Renderings.pdf`,
  5 pages, 1.34 MB. Config in `examples\wyatt-shepherd-compact\`.
  - Open: an unidentified edge line on plate 4.
- **Wyatt Shepherd, MDL 4872 S (Audiology Basic Plus), RM 114 and RM 128:**
  `Desktop\ProposalFiles\Wyatt Shepherd\Wyatt Shepherd-Booth-Renderings.pdf`, 10 pages,
  2.96 MB. Config in `examples\wyatt-shepherd\`.
  - Open: the invented RM 128 layout note, and the "Recommended / Alternate layout"
    labels.
