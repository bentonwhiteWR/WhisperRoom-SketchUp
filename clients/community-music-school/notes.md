# Community Music School (Allentown, PA) — MDL 96144 E drum studio renders

**Status: PAUSED 22 Sep 2026 with the room shell built. Every host-room dimension is ESTIMATED
from two phone photos and has not been confirmed with a tape measure.** Resume from the
2026-09-22 "Community Music School" entry at the top of `DEVLOG.md`.

| | |
|---|---|
| SketchUp file | `P:\Sketchup\ClientDrawings\Community Music School CP SL MDL 96144 E.skp` (pCloud; on the laptop `Z:\` is a `subst` of `P:\`) |
| Client photos | `P:\Sketchup\ClientDrawings\Community Music School - client photos\` (pCloud copy); on the laptop also `clients/community-music-school/plans/` (gitignored) |
| Quote | W-1109222607 ("Drum Studio"). Benton has the link. No prices belong in this file. |
| Booth link | `https://sales.whisperroom.com/booth-builder?d=b31cfb67e46d` |
| Deliverable | V-Ray renders; Benton builds the proposal himself |

## The booth (observed: the quote page and the link payload, read 22 Sep; they agree)

- **Model:** MDL 96144 E (8'x12' Enhanced), door hinge L, gray foam.
- **Wall slots:**
  - Door on S0 (`STDWL46 DRFRM L`).
  - Window on S1 (`STDWL46 WDO3236`).
  - Vents on N0, N1, N2 and W1 (`STDWL46 VNT`).
  - Plain panels on S2, E0, E1 and W0.
- **Options:**
  - caster plate (`cs`) and step (`sp`)
  - studio light (`sl`): the quote's SL 96144 is 3 × 52 in studio lights
  - bass traps (`bt`)
  - Audimute package (`ac`): AP 96144 ships separately
  - no ADA, height extension, desk, EFS or VSS
- **Quote line options:**
  - Door Window 16x30
  - standard ventilation (4)
  - lights (4) 18in LED
  - cable passages (8)
  - StudioFoam (8)
  - WDO 3236 E window
- **Parts that won't build:**
  - Bass traps and Audimute have no `.skp`; leave them off. Benton confirms the Audimute panels won't load.
  - `booth-from-link.rb` refuses the studio light (`sl`). Benton believes the 52 in light is in the master list. `P:\Sketchup\NewMasterComponentList\BoothLighting.skp` exists, but whether it is that light has **not been checked**.

## Decisions (Benton, 22 Sep 2026)

- **Placement:** the booth backs onto the **near end wall** (the wall photo A was taken from; "Wall D"). Its north/vent face sits **18 in** off that wall, centred on it, with the door and window facing into the room. Keep 18 in off any side wall it comes near.
- **Furniture:** none, and no drum kit. The room stays as empty as it is in the photos.
- **Photos:** only two. The third file Benton sent was a byte-identical duplicate, and `11040.heic` was 0 bytes.
- **Fidelity:** "Replicate the room as CLOSE as possible." Every feature in the photos gets modelled, except the partly out-of-frame blue wall lettering, which is left out because it can't be read in full.
- **Drawing labels:** every room dimension on the drawing reads `EST.`, and a plan note says the dimensions were estimated from client photos and not field measured.

## Host room estimate — ESTIMATED FROM PHOTOS, NOT FIELD MEASURED

**Method (reported by the Builder; its fit files are in `.forge/builder/cms/fit/`).**
- **Fit:** a two-camera line fit of both photos (the joint `f` is shared).
- **Scale:** set from **one anchor**, the surface fluorescent run: two 4-ft wraparounds end to end, taken as **97 in**.
- **Cross-checks:**
  - The entry-door head reads 83.9 in, against a standard 7'-0".
  - The switch plate reads 4.46 in, against the standard 4.5 in.
- **Door width:** rejected as an anchor, because the casing edge and the jamb edge can't be told apart in the photos.

| Dimension | In the model now (`fit.json`, 17:07) | Latest fit (`fit/final_fit.json`, 17:19, **not applied**) |
|---|---|---|
| Length, Wall D → Wall B | 269.1 in (22'-5") | 263.8 in (21'-11¾") |
| Width, Wall C → Wall A | 182.4 in (15'-2⅜") | 184.4 in (15'-4⅜") |
| Ceiling height | 123.8 in (10'-3¾") | 126.0 in (10'-6") |
| Green stripe centre above floor | 58.0 in | 59.8 in |

**Tolerance.**
- **Between the two fits (derived):** they disagree by up to 5.3 in on length.
- **Scale risk:** the whole scale rides on the fixture length. Real 4-ft wraparounds with end caps run about 96–100 in for a pair, which is ±2–3 % on every dimension.
- **Working tolerance (assumed):** ±1 ft on length and width, ±6 in on height. Ask the client for tape figures (length, width, ceiling height) before any dimension goes into the proposal as fact.

**Wall frame used in the model (inches).**
- X runs west to east and Y south to north.
- Wall 1 (north) = **D**, the booth wall.
- Wall 2 (east) = **A**, exterior, with two steel windows.
- Wall 3 (south) = **B**, with the closet and the whiteboard.
- Wall 4 (west) = **C**, with the entry door, transom and pipe riser.

## Features to reproduce (Benton wants all of them)

- **Wall A:**
  - Two tall steel-framed multi-pane windows with dark green-gray frames. Count the panes from the full-res photos, including the operable sash.
  - Deep painted reveals and oak stools with aprons.
  - A pilaster between the windows.
  - Two cast-iron radiators of different lengths, painted cream, with supply pipes.
  - Multicolour paint-splatter decals on the upper wall; decal positions are in `fit/decals.json`.
  - A small rainbow plaque on the chair rail.
- **Wall B:**
  - An open oak closet door with white shelving and white PVC pipe inside.
  - A centred oak-framed whiteboard with two tackboards and a tray.
- **Wall C:**
  - An oak entry door with heavy casing and a frosted transom.
  - A switch plate.
  - A white vertical pipe riser with brackets.
  - The blue lettering is omitted (see Decisions).
- **Wall D:** plain, with a tack strip and clips.
- **All walls:**
  - Tan lower wall, cream upper wall.
  - A dark teal-green stripe.
  - Tall oak baseboards with a cap.
  - Duplex outlets.
- **Floor and ceiling:**
  - Blue-gray loop carpet with a fleck.
  - Flat cream ceiling.
  - Two surface fluorescent runs, each two 4-ft lensed wraparounds.
  - A smoke detector.
- **Outside the windows:** a stone building with slate and green-copper roofs. Crop the view from the photos onto a backdrop if that helps.

## Progress (observed 22 Sep 17:21 over the bridge)

- **In the model:** the file holds one group, `CMS Classroom`: floor, walls with wainscot and stripe, and ceiling. It was saved at 17:10 and has 0 dimensions.
- **Camera matches:** both photos were matched by overlay (reported by the Builder). `WR_CMS.match!(:A)` or `(:B)` puts the viewport on the matched camera.
- **Not started:**
  - openings and fixtures
  - room dimensions
  - booth, placement and the studio-light check
  - lights, AUTO-SET and the booth dimension images
  - renders
