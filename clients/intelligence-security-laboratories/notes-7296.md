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

## Room revised 19 Oct 2026 to the client's stated dimensions

The room is no longer scaled off the sketch. Gregory Shelby emailed Jill the real dimensions (19 Oct). The room was rebuilt from them through the take-off (`takeoff-7296.json`, which closes with no error) and the floor-plan dimensions were redrawn. No scene was updated except to put back each scene's hidden room walls on the rebuilt pieces.

| Item | Value | Provenance |
|---|---|---|
| Top (back) and bottom (entrance) walls | 115.5" | stated — "the widest part of the room is 115.5"" |
| Right wall (length) | 177" | stated — "the total length of the room is 177"" |
| Left wall, bottom wall to the beam | 78" | stated — "the entrance to the beam is 78"" |
| Beam end face | 28" | stated — "the wall where the support beam is enclosed is 28"" |
| Left wall, beam to the top wall (alcove) | 71" | stated — "the back wall to the beam is 71"" |
| Beam depth (both faces) | 27.5" | stated — "the support beam juts out 27.5"" |
| Narrowest width | 88" | stated; matches 115.5 − 27.5 (derived) |
| Ceiling | 96" | stated — "the height of the room is 96"" |
| Room door | 3'-0" x 6'-8", bottom wall, 4" from the SE corner, hinged on that jamb | **assumed**; still not given |
| Wall thickness | 4", built outward | assumed, cosmetic |

**Closure (observed in the model, read back off the floor face):** runs 115.5 / 71 / 27.5 / 28 / 27.5 / 78 / 115.5 / 177. The left chain is 71 + 28 + 78 = 177 = the right wall, and the narrow width is 115.5 − 27.5 = 88.

**How the email was read (assumed).**
- "Back wall" is taken as the top of the sketch (the alcove end) and "entrance" as the bottom. If the client meant it the other way round, the beam moves 7" along the left wall and nothing else changes.
- One width (115.5) is used for both the top and bottom walls, so the room is taken as square-cornered.

**Placement.** The take-off origin is [7.5, 180], so the top wall (y 180) and the right wall (x 123) stay exactly where the 16 Oct estimate had them. The booth, its dimensions and every scene camera did not move; the script checked that the booth bounds were unchanged. In model coordinates the room interior is x 7.5..123, y 3..180, and the beam is x 7.5..35, y 81..109.

**Clearances, measured in the model after the revision (observed):**

| Gap | Value |
|---|---|
| Booth W shell → top wall | 1" |
| Booth vent-side shell → right wall | 7.422" (vent hardware 1" off the wall) |
| Booth S-side shell → beam end face | 6.578" |
| Booth S-side shell → left wall (alcove depth) | 34.078" |
| S0 (second door) swing → left wall | 3.93" clear; the arc reaches x 11.43 |
| Booth E shell (main door side) → bottom wall | 54" |
| E0 (main door) swing → bottom wall | 23.85" clear; the arc reaches y 26.85 |
| Ceiling 96" vs install clearance 85" (Enhanced, catalog) | 11" spare |

**Backup before the revision:** `Z:\Sketchup\ClientDrawings\Intelligence Security Laboratories MDL 7296 E EXP 2ft - backup 2026-10-19 1535 pre-room-revision.skp` and its `scenes.json`.

**Superseded:** the 16 Oct estimate scaled the room off the client's booth outline: 123 x 180, a jog 36 deep x 24 long at y 83..107, and an assumed 8'-0" ceiling.

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

## Dimensions

**As of 19 Oct.** Before the revision the model no longer carried the 16 Oct set of 17 dimensions. It held a shorter hand set (observed 19 Oct), which the revision kept:
- **Booth:** width 6'-7½" (to the vent hardware), length 10'-2" and height 7'-0 5/16". These sit on Layer0 and are anchored to the booth. They were not touched.
- **Room:** the left chain plus its overall and the bottom overall, all on Layer0, and the beam depth on WR-Dims. These were redrawn with the new numbers, on the same tags and at the same offsets off the wall face:
  - left chain 5'-11" / 2'-4" / 6'-6", overall 14'-9";
  - bottom 9'-7½";
  - beam depth 2'-3½".
- **Removed:** the 12 dimensions the take-off rebuild added (anchored to vertices, which are lost on save) and its 2 construction points.
- **Floor note** (WR-Notes, edited in place): "Room dims from client email (Gregory Shelby), 19 Oct. Ceiling 96" stated. Room door assumed." / "MDL 7296 E + 24" expansion + 2nd door".
- **Provenance attributes** (`wr_isl/provenance`): room, Walls and Ceiling are STATED; Doors is ASSUMED. The leaf is still named "Door leaf 3 - room door ASSUMED (3-0, 4 in off SE corner)" and the container is still named `Doors`.

**Jamb definition (unchanged).** Each booth door is dimensioned from the booth corner to the near edge of the frame opening. The opening is 33.75" (E0 x 49.703..83.453; S0 y 137.125..170.875).

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

**Re-pressed 19 Oct on the revised room (observed):** 4 F4 fixtures and 8 emitters, all on WR Lights, with no ceilings and no walls borrowed.
- The first re-press used the default walls setting, "open". Because the selected scene hides Wall 2 and Wall 3, it borrowed 2 walls, which the saved scenes do not hide and which would block the cameras.
- It was pressed again with walls "none", which gives the same rig shape as 16 Oct.

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

- **Room (19 Oct).** The dimensions and the 96" ceiling are now stated. Still open: the entry door's position, width, hand and swing; and whether "back wall" and "entrance" are read the right way round (a 7" beam shift).
- **Renders and the proposal PDF** (`Intelligence Security Laboratories-Booth-Renderings.pdf`) still show the 16 Oct room and need re-rendering.
- **Client questions (Gregory, 19 Oct).** Door widths and swing, answered from the model: each booth door's leaf is 30.373" wide in a 33.75" clear frame opening (46" frame panel), and the E0 swing reaches about 30.2–30.4" out from the booth face. Time for the expansion goes to sales.
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
