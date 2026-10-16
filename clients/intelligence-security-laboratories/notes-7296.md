# Intelligence Security Laboratories — office for MDL 7296 E + 24" expansion + second door

16 Oct 2026. Inputs:
- The client's hand sketch, `plans/isl-7296-sketch-2026-10-15.png` (gitignored). It carries **no dimensions**.
- Gregory Shelby, 15 Oct: "This is the shape of the room. As you'll see, there is a space in the back left (marked in blue) that would be inaccessible without a second door (doors marked in red)."
- Quote W-1110152608, ship to Washington, DC (line items only; no prices here):
  - MDL 7296 E: door window 16x30, 2 standard vent systems, 2 x 18in LED lights, 4 cable passages, 5 foam sheets.
  - EXP 7224 E: "Includes 2 Sheets of Foam".
  - ADD ENHDOOR 30.
- Booth link `https://sales.whisperroom.com/booth-builder?d=0411290978ec`. Payload re-fetched 16 Oct (observed): MDL 7296, variant E, hand L, `E0 STDWL46 DRFRM L`, `N0`/`N1 STDWL46 VNT`, `S0`/`S1`/`W0 STDWL46`, `E1`/`W1 STDWL22`.
- Benton's brief: split the two sections by 2', add a new series of mid-wall seam seals and 22" walls (17.5" for the IEP), make the 72 x 24 floor and ceiling centre pieces from the 9624 CL/FL CTR parts, and add the second door where the sketch shows it.

The model is `Z:\Sketchup\ClientDrawings\Intelligence Security Laboratories MDL 7296 E EXP 2ft.skp`. It is a new file, saved after every step; the last save was 16 Oct 16:23. It is **not rendered and not exported**.

Take-off: `takeoff-7296.json` in this folder. `python scripts/takeoff-check.py clients/intelligence-security-laboratories/takeoff-7296.json` exits 0. It reports 1 room and 1 door, the 8 runs as DERIVED, 4 ASSUMED values (ceiling, door width, door offset, door height) and 1 assumed hinge.

## How the room was read

- **Scale (derived, ESTIMATE).** The sketch has no numbers. The only anchor is the client's own booth outline, the dark-blue rectangle (140 x 249.5 px between line centres). It was read as the quoted booth's expanded exterior, 74 x 122".
  - The scale is per axis: 1.892 px/in across and 2.045 px/in down. The hand-drawn booth is about 8% off true proportion, and a single scale would push the booth out of its drawn place in the room.
  - On the other axis's scale the room reads 114–123" wide and 180–195" long. Hand-sketch error comes on top of that.
- **Marks (reported by the client).** The red marks are the booth's two doors. The cyan fill is the back-left alcove.
- **The jog in the left wall** is read as a solid wall return standing 36" into the room, 24" long (derived). What it is in the building (a pier, a closet corner) is not known.
- **Plan up = the top of the sketch = model +y.** This is **not** true north; the sketch carries no north.
- **The room's entry door is not on the sketch.** It is **assumed** in the bottom wall at its right end, the only open floor the sketch leaves for an entry.
- **Not modelled:** windows, furniture, columns and services. None are drawn.

## Room dimensions and provenance

| Item | Value | Provenance |
|---|---|---|
| Top and bottom walls (width) | 123" (range 114–123") | derived — 233 px / 1.892 px/in, scaled off the sketch |
| Right wall (length) | 180" (range 180–195") | derived — 369 px / 2.045 px/in |
| Left wall below the jog | 83" | derived — 169 px / 2.045 |
| Jog end face | 24" | derived — 50 px / 2.045 |
| Left wall above the jog (alcove back wall) | 73" | derived — 150 px / 2.045 |
| Jog depth (both faces) | 36" | derived — 68.5 px / 1.892 |
| Jog position | y 83..107 from the bottom wall | derived |
| Ceiling | 96" (8'-0") | **assumed** — house default; the client gave no height |
| Room door | 3'-0" x 6'-8", bottom wall, 4" from the SE corner to the near jamb, hinged on that jamb, swinging in toward the right wall | **assumed** — not on the sketch |
| Wall thickness | 4", built outward | assumed — house default, cosmetic |

**Closure:** left chain 83 + 24 + 73 = 180 = right wall. Bottom chain 83 + 36 + 4 = 123 = top wall. The jog runs 36 out and 36 back.

## Axes

- Model axes: x right from the left wall's interior face, y up from the bottom wall's interior face, z up from the room floor. The room interior is x 0..123, y 0..180, and the jog is x 0..36, y 83..107.
- Booth-local x is the long axis, with W at 0; it maps to model −y from 179. Booth-local y runs S (0) to N (74); it maps to model +x from 41.578.
- **On the plan:** the top is the booth's W side, the right is N (the vents), the bottom is E (the main door) and the left is S (the alcove and the second door).
- **Shell in the model:** x 41.578..115.578, y 57..179.

## The booth: construction

**Import.** The booth was built from the link payload by `booth-from-link.rb`, with `S0` changed to `STDWL46 DRFRM L`. That is the ADD ENHDOOR 30 second door, in the same door part as E0. Its hand, L, is **assumed**.

**Expansion (job script s4d).**
- **Split.** The booth was split at the existing mid seam (booth x 49/50). The W half stays put. Every part whose centre is past x 50 moves +24. That covers walls, vents, the E door, seals, corners, the deck's SIDE R tiles, lights, foam and covers.
- **Bridge panels, x 50..74 on N and S.** Outer `22PanelSolid` (the W1/E1 definition) and inner `ENH 17.5PanelSolid` (the W1i/E1i definition). They are oriented by the importer's own wall rule.
- **New seam series at x 72..74.** It carries copies of all 6 parts the existing mid seam carries: N-seal0, S-seal0, N-seal0i, S-seal0i, STDSS FL6 and STDSS CL6.
- **Result.** The long walls now match the MDL 96120 E layout (46 | seal | 22 | seal | 46) on a 74" wide booth.

**The four custom 72 x 24 centre strips (job script s4a).**
- Each strip is a unique copy of the 96-series CTR part, **stretched, never scaled**: the far-end geometry was moved 24" along the long axis. Ends, hinges and pads are unchanged.

| Custom part | Made from | Change |
|---|---|---|
| STD7224FL CTR | STD9624FL CTR | y < 0 moved +24 |
| STD7224CL CTR | STD9624CL CTR | seam-seal screw holes at y 78 and 90 removed, then y > 92 moved −24. That leaves holes at 6..66, matching the 72-series SIDE parts |
| ENH 7224FL CTR | ENH 9624FL CTR | y < 0 moved +24; spans −24..48, like ENH 7248FL SIDE L |
| ENH 7224CL CTR | ENH 9624CL CTR | y < 0 moved +24; spans 0..74, like ENH 7248CL SIDE L |

- **Placement.** The strips sit in the deck gap at booth x 49..73, using the transforms the repo's deck code uses for a 9624 CTR on a MDL 96120 E. The ENH CL CTR is not symmetric, so that tool's transform was copied rather than worked out fresh.
- **Saved files.** Each part is its own .skp in the local job folder `.forge/builder/isl-7296/components/` (untracked, **not** on the parts share). The 96-series templates were removed from the model.

**Measured (job script s7, observed from model bounds).**

| Check | Value | Rule |
|---|---|---|
| Shell | 122.0 x 74.0 | quote: 98 + 24 by 74 |
| Booth top | 84.3125" | 11.688" under the assumed 96" ceiling; catalog install clearance 7'-1" (85") |
| W shell to top wall | 1.0" | 1" nominal |
| N shell to right wall | 7.422" | vented wall 6" |
| Vent hardware to right wall | 1.0" | placement choice: hardware 1" off the wall |
| E shell to bottom wall | 57" | door wall, 46 frame: 29.5" |
| S shell to left wall (alcove depth) | 41.578" | door wall, 46 frame: 29.5" |
| S shell to the jog's end face | 5.578" | |
| S0 frame to left wall | 40.304" | |
| E0 swing reaches | y 26.853 | |
| Room door swing to the E0 swing | 22.263" clear | |
| S0 swing reaches | x 11.432, 31.893" clear of the jog | |
| Door leaf width | 30.373" | |
| Booth children | 66; 5 custom definitions | |

**Foam.** The importer placed **4** sheets, on N0i, N1i, S1i and W0i: one per 46" solid or vent panel that is not a door. The quote gives 5 + 2 = **7**. Placing the other 3 is out of scope; this is the count.

**Booth lights.** The booth carries its own **2** interior lights (`/Standard Light`), placed by the importer. The quote lists 2 x 18in LED.

## Dimensions (all on the floor plane, z 0)

There are 17 number-only dimensions, with 0 off the floor (observed):

| Tag | Count | Dimensions |
|---|---|---|
| WR-Dims | 9 | room walls: left 83 / 24 / 73 + 180; jog 36; top 123; right 180; bottom 83 + 123 |
| WR-Dims-Doors | 2 | the room door in the bottom chain: opening 36, and 4 off the SE corner |
| WR-Dims-Booth | 6 | booth 74 and 122; 1 to the top wall; 7.422 to the right wall; E0 8.125 from corner A (41.578, 57) and S0 8.125 from corner B (41.578, 179) |

- **Jamb definition.** Each booth door is dimensioned from the booth corner to the near edge of the frame opening. The opening is 33.75" (E0 x 49.703..83.453; S0 y 137.125..170.875).
- **Floor note.** One floor note on WR-Notes, two lines: "Room dims estimated from client sketch, confirm on site. Ceiling 8'-0" assumed." / "MDL 7296 E + 24" expansion + 2nd door".
- **Provenance in the model** is kept as attributes rather than drawing text, under `wr_isl/provenance`:
  - the room: ESTIMATED;
  - Walls: ESTIMATED, 4" cosmetic;
  - Ceiling: ASSUMED 8'-0";
  - Doors: room door ASSUMED.
- **The ASSUMED label in the Outliner** sits on the leaf: "Door leaf 3 - room door ASSUMED (3-0, 4 in off SE corner)". The container stays named `Doors` because the plugin recognises the room's door container by name; see the open questions.

## Scenes (AUTO-SET from the proposal package, headless)

| Tab | Plate | Mark |
|---|---|---|
| 1 | 01-angled r | Render |
| 2 | 01-angled | Image |
| 3 | 02-front r | Render |
| 4 | 02-front | Image |
| 5 | 03-high r | Render |
| 6 | 03-high | Image |
| 7 | 04-side | Image |
| 8 | 05-ventilation | Image |
| 9 | 06-plan | Image |
| 10 | 08-second-door | Image — **hand-made extra** |

Names are prefixed `Booth - MDL 7296 E EXP 2ft (custom) `. Nothing is marked Skip.

- **How AUTO-SET was run.** It ran with a fresh aspect-0 perspective camera and its popover defaults (mode create, default renders, no interior).
- **Hidden in every scene:** WR-Ceiling and WR-Notes. Every scene shows WR Lights and all WR-Dims tags.
- **The six earlier hand-made scenes were deleted.**
- **Why 08-second-door was kept.** No AUTO-SET plate shows the S0 door as a door. 01/03/04 look at the vent side, and 06-plan shows only its swing arc.
  - It is numbered 08 because 07-interior is AUTO-SET's own id.
  - It was moved to the last tab, since export prefixes follow tab order. A before/after check of its camera, tags and hidden objects came back equal.
  - The first plate is selected, and the transition is 0.5 s.
- **Screenshots** of every plate, viewed, are in `.forge/builder/isl-7296/shots/isl-final-*.png` (untracked).

## Drop-in interior lights (`wr-drop-lights.rb`, tool defaults)

- **How it ran.** Headless, as `WR_DropLights.run(WR_DropLights.default_settings, [room])`, after AUTO-SET. The defaults: brightness x1.00, warmth 0 K, density soft, rig office, ceiling yes, walls open.
- **Result (observed, measured independently of the tool's console):**
  - 4 fixture groups "WR Fixture F4 flush aperture", role fixture_f4, all on tag **WR Lights**;
  - **8 V-Ray emitters**, 2 per fixture, at z 95.25 / 95.75;
  - an F4 24x24 grid of 2 x 2 at 61.5 x 90.0 o.c., with centres at (30.7, 45), (30.7, 135), (92.2, 45) and (92.2, 135); 4200 K.
- **Tool console:**
  - room ceiling borrowed, none added; 0 walls borrowed;
  - fill scatter 0 of 14 placed and the face wash skipped, because the room is too tight for the standoffs;
  - camera exposure read, not written;
  - the replaced rig's 8 V-Ray plugins were swept and none were left.
- **Pressed twice.** The first press read the room's door group as a booth-sized keep-out, because of a name change I had made (see below). After the fix the second press replaced the rig cleanly.
- **Not re-run: AUTO-SET.** Its header does not say it reads the rig, and the rig changed none of its inputs. The page tags were checked instead.
- **In images:** the light rectangles show in the viewport and in scene screenshots. The proposal package's image lane hides WR Lights on export.

## Preflight (`WR_Preflight.check`, read only)

| Check | Result |
|---|---|
| Dimension tags off | FAIL — WR-Dims, WR-Dims-Doors and WR-Dims-Booth are visible |
| Floor off drafting white | FAIL — WR-Floor is on 0128_White |
| Camera on a saved scene | PASS |
| No geometry outside walls | PASS |
| Clear line of sight to the booth | PASS |
| Booth has every part | PASS |

The two FAILs are what the draft-to-render toggle (`WR_Mode.to_render`) clears. It was **not pressed**; that is Benton's call before rendering.

## Open questions

- **Room.** The real dimensions, the ceiling height and the entry door's position, width, hand and swing. All are estimated or assumed, and the room could be off by a foot or more.
- **Ceiling.** It is the figure that disqualifies fastest: the booth needs 85" install clearance.
- **Second door (S0).** Its hand, L, is assumed to match E0. Which way should it swing into the alcove?
- **Foam.** 4 sheets placed, 7 quoted.
- **Cable passages.** The 4 quoted cable passages are not placed; there is no position for them.
- **Delivery path to DC.** Doors, elevator and stairs. The 46" panels and the custom 72 x 24 strips have to come in flat.
- **IEP wall lift.** Not measured on this booth; the importer's z was kept.
- **STD9624FL CTR.** It carries a top-level Hinge that duplicates one inside its body, as authored. It was kept in the custom copy.
- **ENH CL CTR.** It is not symmetric. The 96120 E transform was reused; check the custom strip's orientation in SketchUp.
- **Vent side.** The vent hardware sits 1" off the right wall, which leaves the shell 7 7/16" off it. Confirm that the 6" vented-wall rule is meant to be met by the shell, not by the hardware.
- **06-plan.** AUTO-SET's framing crops the lower part of the room. 01/03/04 sit on the vent side.
- **Tool findings (not fixed; `scripts/` was not changed):**
  - The drop-lights header says to pass opts_from-shaped opts, but `run()` re-reads `given` through `opts_from`. Passing that shape would lose the ceiling setting.
  - The room's door container is recognised only by the name `Doors`, so renaming it breaks the lights tool.
  - AUTO-SET has no headless entry, and its header's "five scenes" is out of date: the defaults give 9.
  - The take-off build's dimensions were lost on save, because they were anchored to vertices.
  - `WR_RoomDimsNow`'s fixed 40" offset lands the jog dimensions inside the room.
