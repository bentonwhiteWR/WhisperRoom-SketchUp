# HANDOFF — People's Space revision: acoustic package, HEPA, MJP (23 Sep 2026)

When Benton types "continue", resume at **Next steps**. Everything else here is the state behind them.

## The job
Client (People's Space) asked to add the Acoustic Package (Audimute), HEPA filters, and an MJP to the
existing drawing, and asked whether there is room for the HEPAs. Lighting and everything else in the
file is already approved; change only what is inside the booth plus the HEPAs.

- File (open in SketchUp 2026, **may be unsaved**):
  `Z:/Sketchup/ClientDrawings/PeoplesSpace MDL 96120 E ADA RM VSS WDO RAISED FLOOR AP MJP HEPA.skp`
- Drive it over the bridge: `python scripts/sketchup-bridge.py run <file.rb> --su 2026`
  (`eval "<ruby>"`, `shot out.png --width 1400`). A scene change animates, so shoot twice.
- The booth is top-level **`Group#28`** (the visible one). `Group#27` is hidden and `Group241`, far off
  at x≈1145, is an older copy. Leave both alone. Booth transform: origin (100, 4.75, 1.31), local
  +x = world +y.
- The parts folder is `P:/Sketchup/NewMasterComponentList` (Audimute2x4/1x4/1x2, HEPA, SL29/SL52,
  Bass Trap, MJP).

## Done so far (observed over the bridge)
- **MJP**: interior and exterior boxes on the window wall (`46Panel3236WDO` / `ENH 41.5Panel3236WDO`),
  centred on the panel run (local x 97.0) and topped at local z 29.07 (the importer's MJP_TOP_Z).
  Both were ray-tested flush to the real wall faces (interior face local y 4.25, exterior face 1.0).
  Named `MJP interior (window wall)` / `MJP exterior (window wall)`, tag `WR-Booth-Options`.
  Scripts: `mjp.rb` (place), `mjpmove.rb` (seat), `mjpfit.rb` (verify gap = 0).
- **HEPA ×4**, one per intake VSS duct box. The intakes are the four standalone `VSS duct box`
  instances directly inside `RM96120VSS` (world y 73–122). Every fan hose runs fan→EFS, never to
  these boxes (`hose.rb`). Named `HEPA (intake)`, tag `WR-Booth-Options`. The part is 7.87 × 6.5 ×
  10.7 with the filter on its local +x face, so filter up means local x maps to world up.
  - Current state: sitting INSIDE the box end (world y ≈ 73–83.7), then rotated 180° about vertical
    (`hepaflip.rb`).
  - An earlier try butted against the OUTSIDE of the open end (y 62.3–73) and collided with three
    hoses, which is why it was moved inside.

## Update 23 Sep, after the restart (all observed over the bridge; file still UNSAVED)
- HEPA: flipped back, then butted 10.7 in outward along each box axis so the end plate touches the
  open end (`hepaout.rb`); world y 62.3-73. The part is symmetric end to end, so the 180 flip was
  never visible. **Clash** (`clash.rb`, hose vertices tested against the actual geometry): in 3 of 4
  sets the fan hose passes through the butted HEPA, 4.6 in deep on the two outer sets and a 1.6 in
  sliver on the angled one. The fourth set is 2.45 in clear. Awaiting Benton: reroute the hose or accept.
- Audimute (`audimute.rb`, then `apflip.rb`, whose fabric faces -y local, and `apseat.rb`, gap 0.00),
  tag `WR-Booth-Acoustic`, top-aligned to ceiling z 81.56, no cuts. BACK: 96 wide at y 17.75-113.75,
  band 1x4|2x4|2x4|2x4|1x4 plus 2 rows of 4 x 1x2. LEFT: foam band x 15-87 (the 2 left sheets plus 1
  from the back wall), rows below 1x4 flat + 1x2 staggered. RIGHT (far short wall): the 2 spare 1x2
  top-aligned, plus the 2nd back-wall foam sheet filling the x 39-63 gap between the existing two.
  Usable runs are limited by the corner seals: back 107.7, left 83.8.
- Next: Benton evaluates the layout and the HEPA clash; save only on his word.

## Original next steps (Benton, 23 Sep; 1 and 2 done)
1. **HEPA: flip back 180°** (run `hepaflip.rb` again, which rotates each 180° about its own
   vertical centre). **Then move each one outward along its box axis until it touches the edge of the
   duct box.** Right now it is "blended into" the box. Read "outward" off the box's own axis `a`
   in `place-hepa.rb` (from the closed end toward the open end); the angled boxes have their own
   `a`. Check clearance against the hoses again (`hose.rb` gives their extents), then screenshot and
   show Benton.
2. **Acoustic package**, placed "as best as possible", NO cut pieces. 96120 = **3 × 2'x4', 4 × 1'x4',
   12 × 1'x2'** (Benton's table). The priority walls are the ones seen **from inside the booth: the
   back wall and the left wall**, since the client wants those two walls covered full width,
   top-aligned to the ceiling. Place panels on those two walls first, top edge aligned to the
   ceiling underside. Any panels left over go wherever they fit best.
   - **Moving the existing blue `Foam` (WR-Booth-Foam, 24×48) is allowed** to make it fit.
   - Work out "back" and "left" from inside: the door and window are on the front wall
     (world x≈98, booth-local y low side). Standing inside facing away from the door, the back wall
     is the long wall at world x≈4–6 (IEP face ≈ world x 6.3). Derive "left" from that standing
     position and **confirm with a screenshot before placing panels**. The client's own image was
     mirrored relative to this model.
   - Interior clear: raised-floor top ≈ world z 4.1, IEP ceiling underside ≈ world z 82.6 (about
     78.5" clear). The back wall run is about 113" between IEP faces.
   - Measure the Audimute parts' true geometry (not definition bounds). `Audimute1x2` starts 7.9" up
     inside its own definition. Load the parts with `definitions.load` from the parts folder.
   - Do it in one undo operation per wall, on a tag such as `WR-Booth-Acoustic`. Screenshot from
     inside for Benton; he decides afterwards whether more foam is needed.
3. Then report back: the HEPA fit, the panel layout (counts per wall), and what the foam moves were.
   Do NOT save the .skp unless Benton says to.

## Settled with Benton (do not re-ask)
- HEPA goes only on the intake box (the one with no fan hose), in the opening, filter up.
- Studio light: SL52 for the 84-series and up, SL29 for the 60-series and down. The 7272 and 7296
  are still unconfirmed. The quote builder has no sizing logic, only the on/off `sl` flag.
- Audimute has no placement pattern; the importer will load the correct count for each model, and
  Benton places the panels. MDL 127 LP is ignored for now.
- The booth-link importer (`scripts/booth-from-link.rb` ~line 1127) currently skips `bt`, `ac` and
  `sl`; `hp` is the HEPA flag. The importer work comes after this client revision.
