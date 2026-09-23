# Community Music School (Allentown, PA) — MDL 96144 E drum studio renders

**Status: 22 Sep 2026, 19:27 — room, booth, lights, scenes and booth dimension images built and saved on the desktop (HANDOFF steps 1–8). V-Ray renders (step 9) are ON HOLD until Benton says go; he is adding his last features first. The 3 x 52 in studio lights are Benton's to load himself.** Every host-room dimension is ESTIMATED
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
  - Two cream cast-iron radiators (38 in and 37 in) with supply risers and valves.
  - **Radiator 2 (under window 2) is at Y 43.5–80.5 by BENTON'S RULING, 22 Sep: "about 1 ft to the right" as seen facing the window wall. This OVERRIDES the photo measurement.** History, all 22 Sep:
    1. Built at Y 57–101.5 (44.5 in); its north end ran 6.5 in past the niche's north jamb (Y 95).
    2. Re-triangulated to Y 55–95.
    3. Re-measured by its relationship to the niche. Photo B: centre 8.5 in north of the niche centre, 2.2 in inset from the N jamb. Photo A: 6.6 in north, −0.6 in. Both read it as about 37 in long. Moved to Y 55.5–92.5.
    4. Benton then ruled a further 12 in south, to 43.5–80.5 at 37 in long. Its S end is 5.5 in clear of the S niche jamb (Y 38); the supply riser moved with it.
  - The window 2 niche (Y 38–95) was not moved: the two photos put its N jamb at 94.3 and 97.6, and the model sits between them.
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
- **Renders:** not started. They are on hold for Benton's go-ahead (step 9).

## Booth, lights, scenes, dimension images (HANDOFF steps 4–8, 22 Sep 2026, desktop, observed over the bridge)

**Booth (built).**
- Source: MDL 96144 E from `?d=b31cfb67e46d`. The payload was the portal's own answer to `GET /api/booth-design/b31cfb67e46d`, and it matches the quote facts above. It was built headless with `booth-from-link.rb` (`.forge/builder/cms/jobs/booth.rb`).
- Parts: real components only. 79 instances: both shells, door L on S0, WDO3236 on S1, vents on N0/N1/N2/W1, foam and duct covers, the CP9648 caster plate (booth lifted 4.75 in) and the step.
- Builder flags (13, reported, not errors):
  - The ENH inner panels read +0.125 to +0.234 in against their slots.
  - IEP wall lift and vent drop are house defaults; this booth has never been measured.
  - The caster plates measure 5.37 / 5.44 in against the 5.50 in stack.
- **NOT built: bass traps (bt).** No `.skp` exists.
- **Audimute (ac): partly added by hand.** Benton added a 2 x 4 Audimute panel component ("Component#11", 24 x 48 x 1.62 in, [Formica Blue]); the definition is unmodified. His original instance stands in the corridor west of Wall C.
  - Four copies were added inside the booth group, hangers against the IEP inner wall faces, vertical, in the 24 in foam gaps: back (N) wall x2, E wall x1, W wall x1.
  - The S door wall has no gap wide enough.
  - Each N panel touches the duct covers at two corners (0.8 x 0.41 in): the covers straddle every N foam gap and leave 47.2 in for a 48 in panel. Benton accepted the contact.
  - Whether these four are the full AP 96144 package is not known.
- **Studio lights (sl): Benton's.** He loaded 3 x "Component#127" (55.2 x 22.3 in) into the booth himself.
  - The builder refuses `sl`, and this run never searched for the part.
  - They glow in the V-Ray tests, visible through the booth windows (observed).
  - Their LED spheres use definition "Sphere Light#8". Its plugin read intensity 243,200, invisible = true, which exactly matches one of this rig's fill values: a possible name collision with a test sphere deleted minutes earlier. **Not edited; Benton to check it in the Asset Editor.**
- **Foam:** `[Color_I06]` (used only by the Foam definition, checked) is set to neutral gray RGB 96,96,98, because the stock foam renders blue.

**Placement (built, Benton's decision).**
- Booth-local X 0–146 runs along the door wall; the door and window face south into the room.
- **Rule (Benton, corrected 22 Sep): 18 in from the booth's STRUCTURE, i.e. the wall-panel exterior faces. Hoods, silencers and seam seals don't count.**
- North panel face is **18.0 in** off Wall D (before the correction it was 19.0 in; the seam seal was then at 18.0). Seal to Wall D is 17.0 in, and the vent-hood assembly 10.6 in.
- Panel faces are **19.3 in** off Walls A and C, centred at X 91.3: a 144 in panel span cannot be 18 in from both walls of a 182.6 in room. The W vent hood is 11.9 in off Wall C, and the E seal is 13.3 in from radiator 1's front.
- The booth is placed by measuring its parts, not the group origin: the group origin was found reset to (0, 0, 6.06) after the dimension tools wrote into it.
- Top of booth 89.1 in. Ceiling 125.4 in EST, so fixture run 2 clears it by about 32 in.
- Door swing (29.5 in) plus the step (12 in): the step front is at about Y 144.7 and the floor in front of it is open to Wall B.
- The tack strip on Wall D is behind the booth.

**Lights (built, and tuned on one hero scene with 800 px V-Ray tests, 22 Sep).**
- Built by `.forge/builder/cms/lights.rb` using the house tool's own V-Ray primitives (WR_DropLights `create_light` / `create_sphere` / `write_params`). Every figure is product lumens x 320, the tool's calibration.
- **Render settings the rig was tuned at: EV 14.73 and the V-Ray sun OFF.** `.forge/builder/cms/rt.py --ev 14.73 --sunmult 0` writes both on every frame.
  - The sun is off because the camera sees through AUTO-SET's hidden walls, which let in a sun wedge the real room cannot get.
  - The proposal package would render at EV 12 by default and would not turn the sun off (see `.forge/builder/cms/scene-plan.md`).
- **Room fixtures:** the four existing 4-ft fluorescents. Each has a visible emitter on its lens face at 8% plus an invisible one below it at 92%: 4,000 lm per fixture, 5000 K. The tool's Kelvin conversion reads warm; at 4000 K the foam went brown. No new visible fixtures were added.
- **Daylight:** per window, an invisible 6500 K panel just inside the glass facing into the room (9,000 lm), and one between the glass and the backdrop lighting the outside view (6,000 lm). The V-Ray sun is not used, because the backdrops sit outside the windows and block it.
- **Fill:** 8 invisible spheres, 10 in diameter, 5000 K, placed irregularly 43–65 in in front of the door face at heights of 20–88 in. None is closer than 43 in to any wall. Outputs vary per sphere, 600–1,480 lm.
- **Wall C bounce stand-in:** an invisible 104 x 135 in panel inside Wall C's own thickness (X −2), facing into the room, 3,000 lm.
  - It stands in for the wall's bounce when a scene hides Wall C; it is sealed in the solid when the wall is shown.
  - Without it the booth's vent end went black once the sun was off.
- **Not used from the house tool, and why:**
  - The office rig's panel grid would add new ceiling fixtures.
  - Its fill scatter placed 0 of 14 spheres in this room ("nowhere legal").
  - The key / rim / face-wash roles are photo-studio lighting.

**Scenes (built).** 20 in total:
- The 2 photo-match scenes, kept. Photo A's camera now stands inside the booth and Photo B's behind it, so neither shows the booth usefully (expected).
- The proposal package's legacy five (`01-exterior` … `05-plan`, WR_ProposalScenes). Those cameras stand outside the room, so the walls they look through (and the ceiling from above) were hidden per plate so the booth shows.
- AUTO-SET's 13: `MDL 96144 E (components) 01-angled` … `06-plan`, each as an image plate and an `r` render plate, plus `07-interior`.
- `CMS Room Dims (EST)` is **shown** in the three top-down scenes (`05-plan`, AUTO-SET `06-plan` and `06-plan r`) and hidden in the other 15 non-photo scenes. The state is stored in each scene.
- The plan cameras were reframed so every dimension row is in frame; an AUTO-SET "update" with re-aim would undo this, so rerun `jobs/plan-scenes.rb` after one.
- **Plan note (Benton, verbatim):** "HOST ROOM DIMENSIONS NOT PROVIDED. ALL ROOM DIMENSIONS ARE ESTIMATED FROM CLIENT PHOTOS (±1 FT) AND MUST BE CONFIRMED ON SITE." It sits on clear floor south of the booth.
- The CORNER name labels were removed (Benton). All 23 EST dims are unchanged; 5 labels remain (4 walls plus the note).
- Known issue: in `03-high` (ceiling hidden) the visible fixture lens emitters show their black backs from above. Fix proposed in the scene plan, not applied.

**Booth dimension images (built).**
- Dimension a WhisperRoom, then Rotate once (FR → FL), which puts the set on the west side. The angled, high, side and ventilation cameras all see that side.
- Measured 12'-7 1/2" x 8'-7 1/2" x 7'-5 1/16", which agrees with the catalogue within 1/4 in (height includes the 4 3/4 in plate).
- Six viewport exports (not V-Ray), 2400 x 1800, in `Z:\Sketchup\ClientDrawings\Community Music School - renders\dimension-images\`.
- Known flaw: on `01-angled` the height string is clipped at the left frame edge. The same figure reads in full on `03-high` and `04-side`.


## Evening fixes, 22 Sep 2026 (desktop, observed over the bridge; saved 21:14:48, check! green)

- **Scene zoom fixed.**
  - Cause: the AUTO-SET scenes had stored a 14.24 deg lens, which is their intended 35 deg re-expressed across the 2.525:1 SketchUp window. The interior plate stored 31 deg, its 70 deg squeezed the same way.
  - Effect: clicking a scene showed a close-up, and the package would have captured one.
  - Fix: AUTO-SET's own update and re-aim, run from a clean camera. All plates now store 35 / 70 deg as height lenses.
  - The same conversion keeps hitting the two photo-match scenes, so they are restored before every save.
- **Window backdrop lights halved** (Benton): V-Ray "Rectangle Light#9" and "#11" (daylight on the w1/w2 backdrops) went from 1,920,000 to 960,000. The window view now holds detail in the hero test.
- **Plan labels and note are now floor text** (3D, sized in inches), so they never run over the dimensions at any output size. The CORNER labels stay removed.
- **New scene "08-interior corner"** (Benton): the camera is in the booth's NW back corner, 57.7 in above the booth floor, with photo B's heading 133.9, pitch −11.07, roll −0.34 and lens (85.93 deg height). The 800 px test shows the classroom readable through the window and the door window, and the Audimute panels and foam read. Benton's studio lights glow lavender and clip the ceiling near them.
- **Scenes: 21**, none deleted.
