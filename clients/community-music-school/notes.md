# Community Music School (Allentown, PA) — MDL 96144 E drum studio renders

**Status: 22 Sep 2026 — room (HANDOFF steps 1–3) built and saved on the desktop; booth next. Every host-room dimension is ESTIMATED
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

**Status 22 Sep 2026 (desktop Builder): room built to HANDOFF steps 1–3 with the `joint7` fit.**

**Fit decision (derived, measured overlay error in full-res photo px).** Neither candidate
lined up with both photos on both kinds of evidence, so the same picks + ties were refit jointly
(`fit/joint7.py`, plain box, B's grazing-edge corner line down-weighted 0.25). Scores on
identical evidence:

| Fit | Room lines A (rms) | Room lines B (rms) | Wall-pinned feature ties (rms) | Render-measured room lines A / B |
|---|---|---|---|---|
| `fit.json` (built 17:07) | 11.1 | 26.1 | 12.7 | 8.5 / 24.7 |
| `fit/final_fit.json` (17:19) | 12.9 | 37.5 | **4.6** | 9.8 / 40.1 |
| **`joint7` (adopted)** | **7.0** | **18.6** | 8.5 | **6.2 / 16.7** |

The render-measured column is the actual SketchUp render scored against the photo picks. B's rms
is dominated by one line, the B/C corner at the far right edge of the ultrawide frame (53–128 px
under every fit, with or without a lens-distortion term). final_fit's 8.7 in wall-A setback (`s1`)
was tested and not adopted: only one floor line in B's corner supports it, and a joint refit
shrinks it to 2.5–4.4 in.

**Scale:** one anchor, the surface fluorescent run (two 4-ft wraparounds end to end) = **97 in**.
joint7 gives h = 58.25 in per unit.
**Cross-checks (derived):** entry-door head 85.0 in (standard 7'-0" + ~1 in); switch plate 4.5 in
tall; photo A and photo B place the closet and whiteboard within 2 in of each other.

| Dimension | Model now (`joint7`) | Tolerance (assumed) | Earlier fits |
|---|---|---|---|
| Length, Wall D → Wall B | **270.7 in (22'-7" on the drawing)** | ±1 ft | 269.1 / 263.8 |
| Width, Wall C → Wall A | **182.6 in (15'-3")** | ±1 ft | 182.4 / 184.4 |
| Ceiling height | **125.4 in (10'-5")** | ±6 in | 123.8 / 126.0 |
| Green stripe centre above floor | 58.3 in | ±3 in | 58.0 / 59.8 |
| Wall C: corner B/C → entry door opening | 85.5 in (7'-1"), opening 37.5 in (3'-2"), then 147.7 in (12'-4") to corner C/D | ±1 ft | |
| Entry door opening head / transom top / casing top | 85.0 / 104.0 / 110 in | ±6 in | |
| Wall B: corner B/C → closet opening | 144.2 in (12'-0"), opening 31.7 in (2'-8"), then 6.7 in (0'-7") to corner A/B | ±1 ft | |
| Closet opening head | 86.3 in | ±6 in | |
| Wall A: corner A/B → window 2 | 38.0 in (3'-2"), window 57.0 in (4'-9") | ±1 ft | |
| Wall A: window 2 → pilaster | 39.0 in (3'-3"), pilaster 21.0 in (1'-9") wide, 7 in proud | ±1 ft (depth ±3 in) | |
| Wall A: pilaster → window 1 | 24.0 in (2'-0"), window 55.5 in (4'-8"), then 36.2 in (3'-0") to corner A/D | ±1 ft | |
| Windows: sill / head | 34.0 / 105.5 in; reveal 16 in to the glass; radiator niches 4 in deep | ±6 in | |
| Whiteboard: X 49.3–134.0 from Wall C, top 79.6 in, tray top 32.2 in | | ±6 in | |
| Closet depth | ~26 in | **assumed**, not visible | |

Every chain on the drawing closes. The printed segments are rounded by largest remainder, so each
chain sums to its printed overall: A 271 = 22'-7", B 183 = 15'-3", C 271 = 22'-7".

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

## Built vs. not built (HANDOFF steps 1–3, 22 Sep 2026, observed over the bridge after save)

**Built** (`.forge/builder/cms/room.rb` + `features.rb`; positions from ray casts or two-photo
triangulation, materials from photo hue):
- **Shell:** walls cut around real openings. Wall A is 20 in exterior masonry. Tan lower wall,
  teal stripe, cream upper wall, cream ceiling. Blue-gray loop carpet with a fleck texture (the
  tile's colours come from photo A).
- **Wall A:**
  - Two steel windows, 6 × 6 lights, with a heavier centre mullion, an operable centre vent and a
    sash lock. Frames are dark green-gray.
  - 16 in white reveals, oak stools with aprons, and 4 in radiator niches.
  - Pilaster, 21 in wide and 7 in proud.
  - Two cream cast-iron radiators (38 in and 44.5 in) with supply risers and valves.
  - 26 paint-splatter decals, recast with joint7 (5 detections that were really the plaque were dropped).
  - Rainbow plaque on the chair rail.
  - Duplex outlet on the pilaster.
  - A window backdrop: photo B's view through each window, mullions inpainted.
- **Wall B:**
  - Oak-cased closet opening. The oak two-panel door stands open, square to the wall, on the east hinge.
  - Inside the closet: white shelves on the west side and a white PVC stack on the east.
  - Oak-framed whiteboard with two tackboards and a deep tray.
  - Duplex outlet on the baseboard.
- **Wall C:**
  - Oak entry door with a heavy casing and cap, a transom bar and a frosted transom sash.
  - The leaf is swung back into the corridor, as in photo A.
  - Switch plate and duplex outlet.
  - White pipe riser with a coupling and three brackets.
  - An unlit corridor volume beyond the door.
- **Wall D:** aluminum tack strip with three clips.
- **All walls:** oak baseboards with a cap, including in the niches and around the pilaster.
- **Ceiling:**
  - Run 1: two lensed 4-ft wraparounds (the scale anchor).
  - Run 2: two 4-ft surface fixtures with a **parabolic egg-crate louver**. Photo B shows a louver,
    not a lens, so the earlier note calling both runs "lensed wraparounds" was wrong (observed).
  - Smoke detector.
- **Drawing:**
  - 23 dimensions on tag `CMS Room Dims (EST)`, every string ending `EST.`: chains, openings off
    named corners, overalls, pilaster depth and ceiling height.
  - Corner and wall labels, plus the plan note.
- **Scenes:** "Photo A - long view" and "Photo B - corner view". They store camera only, with
  the fit's fov and aspect, and are for photo matching (keep them; consider them for renders).

**Not built / deviations:**
- **Blue wall lettering on Wall C:** omitted (Benton's decision).
- **Papers under the Wall D clips:** omitted (unreadable; the booth covers that wall).
- **Window 2 light count:** its north third is hidden by the reveal in both photos, so it is
  assumed to be the same 6 × 6 as window 1.
- **Closet depth and interior layout:** assumed.
- **Hall/corridor beyond the door:** only a plausible unlit volume.
- **Wall A face offsets of 2–6 in between sections:** triangulation hints at them, but they are
  not modelled. Wall A is a single plane plus the pilaster and niches.
- **Tack strip west end:** out of frame, assumed at 60 in from Wall C.
- **Colours:** photo hue lifted to plausible reflectances. They are estimates, not paint matches.
- **Lights, booth, AUTO-SET, renders:** not started. That is HANDOFF steps 4–10.
