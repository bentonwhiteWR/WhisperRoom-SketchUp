# HANDOFF — Researcher (portal part placement) → Builders, 2026-08-27

(This file replaces an older HANDOFF for the panel-reorg mission; that mission's reports —
`script-inventory.md`, `panel-problems.md`, `proposed-structure.md` — still stand in this
folder. The lighting stream has its own `HANDOFF-lighting.md`.)

## Produced

- `.forge/researcher/portal-part-placement.md` — THE deliverable. Per part (foam, duct
  covers, desks, MJP, elevated floor / EFP, caster plate, plus the full anything-else
  enumeration): the portal's wall rule stated evaluably, the face, offsets in inches,
  Standard vs Enhanced difference, whether a `.skp` exists (exact filename), and a
  provenance word on every number. Ends with a one-table build spec.
- `.forge/researcher/HANDOFF.md` — this file.

Nothing outside `.forge/researcher/` was created or modified.

## Read first

1. `portal-part-placement.md` section 0 (vocabulary): **"bench wall" is not a portal term
   — it is the VNT (vent) wall**; "IEP wall" = the Enhanced inner panel whose room face is
   **2.25" roomward** of the standard interior face (1.25" air gap + 1" panel).
2. Sections 1-2: Benton's foam and duct-cover rules are **verified**, with three portal
   rules he did not state: (a) foam only on **40"/46"** SOLID/VNT/CBL/NV panels — never on
   doors, windows, or any narrow companion including the 43"; (b) **no duct covers on an
   HX booth** (product fact — they don't ship); (c) foam layers **in front of** the duct
   covers.
3. Section 7's table before touching `scripts/booth-from-link.rb` — it lists exactly which
   payload keys are handled, which are named-ignored, and which are **silently dropped**
   today (`f`, `ep`, `ad`, `ac`, `dl`, `ds`, `ms`, `dox`, and the caster PLATE half of
   `cs`). "No silent fallback" (GOAL) means the silent ones must at least become named.

## Key numbers (all sourced in the main report)

- Foam sheet: nominal 24 x 48 x 2"; centered on its panel horizontally AND vertically
  (ph 81" / 91" HX); interior face, proud; one per qualifying panel; color = payload `f`.
- Duct covers: pair per vent wall, centered on ports — 40": hi [13.9", 71.1"],
  lo [27.7", 9.1"]; 46": hi [16.15", 71.45"], lo [29.9", 9.45"]; x from the panel's left
  edge **as seen from inside**; cover ~11.94 x 14.76/13.78 x 3.14".
- Enhanced move for both: +2.25" roomward onto the IEP room face — a move, never a copy.
- Desk: surface 32.5"; small 30 x 14 (may mount outside, +14" clearance), large 42 x 17
  interior-only; centered on host panel; host selection rule in section 3.
- MJP ("Multi jack panel"): pass-through, boxes on BOTH faces, plate center 27.25" high,
  centered on a WDO/CBL panel (fallback rules in section 4).
- EFP slab: ~2.83-2.89" tall, centered in plan (flush to IEP walls on Enhanced; ~2-2.4"
  gap per side on Standard, filled by perimeter strips that have NO art and NO .skp).
- Caster plate: replaces the 5/16" mat, footprint = published exterior, floor sits 0.739"
  into its tray, net booth lift exactly 5"; step (12") only with casters.

## Assumptions (labelled)

- "Bench wall" = vent wall — **derived** from rule-matching; no portal text defines the
  word. If Benton meant something else, sections 1-2 still stand (they are stated in
  portal vocabulary).
- `Foam.skp`, `Duct Cover.skp`, `MJP.skp`, desk and EFP `.skp` internal geometry is
  **assumed** to match the portal art — none were opened; Builders must measure each on
  first load (SketchUp side, not from here).
- The Enhanced ceiling tray being covered (or not) by our existing deck code is
  **assumed unresolved** — `wr-deck.rb` shows no tray/EFP/CP terms.

## Open questions (Benton is away — evidence-leaning answers recorded)

1. **Desk/MJP on Enhanced: which face?** The portal disagrees with itself (top-down = IEP
   face; iso = standard face, buried). Evidence leans IEP room face — same "wall the
   customer can touch" reasoning Benton gave for foam. Build on the IEP face, cheap to
   move.
2. **EFP exact position**: the portal draws it centered and admits it's authored, not
   measured ("Benton is asked on the proof sheet"). Evidence leans: centered = pressed to
   the IEP walls on Enhanced; centered with perimeter-strip fill on Standard. Build
   centered.
3. **`EFP96192.skp` is missing; `EFP96196.skp` matches no catalogue size** — almost
   certainly a misnamed file. Benton must confirm/rename; until then a 96192 EFP cannot
   resolve. This is an author-the-component (well, rename) item for Benton.
4. **`Duct Cover.skp` internal spacing**: the portal measured the cover-set export at 66"
   apart vs the real 62.0". If the .skp mirrors the export, placing it whole puts the low
   cover ~4" wrong. Evidence leans: place each cover independently at its port center.
5. **Which end of the vent panel the duct x is measured from** is stated ("left edge seen
   from inside") from `assets/layout-render.js:3369-3374`; worth one visual check against
   a portal render before the numbers ship.
6. **Parts Benton must author (no .skp exists)**: EFP perimeter strips (Standard+EFP),
   IEP floor pad (5/16" rubber, Enhanced), bass traps, Audimute panels, studio-light
   fixture, isolation mat (if not already inside the floor components). Report, don't
   fake — per GOAL.
