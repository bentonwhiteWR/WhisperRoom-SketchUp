STATUS: READY 67ecec9

# Builder handoff: Intelligence Security Laboratories, MDL 7296 E + EXP 7224 E + ADD ENHDOOR 30 (16 Oct 2026)

## Produced

- **Model:** `Z:\Sketchup\ClientDrawings\Intelligence Security Laboratories MDL 7296 E EXP 2ft.skp`.
  - New file; nothing was overwritten.
  - Last saved 16 Oct 16:23; not modified after the save (observed).
  - Open in SketchUp 2026. Not rendered and not exported.
- **Notes:** `clients/intelligence-security-laboratories/notes-7296.md`. It holds the full provenance table, construction, checks, scenes, lights and open questions.
- **Take-off:** `clients/intelligence-security-laboratories/takeoff-7296.json`. `scripts/takeoff-check.py` exits 0.
- **Job scripts:** `.forge/builder/isl-7296/s0..s18*.rb` and `save.rb` (untracked). Every one passed `scripts/rbparse.py`.
- **Custom parts:** `.forge/builder/isl-7296/components/`, 4 .skp files (untracked; not on the parts share).
- **Screenshots:** `.forge/builder/isl-7296/shots/isl-final-*.png` (untracked; client imagery).

Done-means, with evidence (all observed from the model unless marked):

1. **Room.**
   - 123 x 180 interior, jog 36 x 24 at y 83..107; ESTIMATED, scaled per axis off the booth outline.
   - Chains close: left 73 + 24 + 83 = 180 = right; bottom 83 + 36 + 4 = 123 = top.
   - ESTIMATED / ASSUMED are carried by the floor note and by `wr_isl/provenance` attributes on the room, Walls, Ceiling and Doors, plus the leaf name "Door leaf 3 - room door ASSUMED (...)".
   - Ceiling 96" assumed; room door 3'-0" assumed.
2. **Booth.**
   - Built from `?d=0411290978ec` (payload re-fetched): E0 `STDWL46 DRFRM L`, vents N0/N1.
   - Split at the mid seam, +24.
   - New panels on N and S: 22PanelSolid outer + ENH 17.5PanelSolid inner, and a new 6-part seam series at booth x 72..74.
   - 4 custom 7224 CTR strips, stretched by vertex moves, not scaled.
   - Shell measured **122.0 x 74.0**.
3. **Second door:** S0 = `STDWL46 DRFRM L`, the same part as E0. Frame opening model y 137.125..170.875, at the W end facing the alcove. Hand L is ASSUMED.
4. **Placement.**
   - Vents to the right wall: shell 7.422 off it, vent hardware 1.0 off it.
   - W shell 1.0 off the top wall.
   - E0 faces the open floor, with the E shell 57 off the bottom wall.
   - S0 opens into the alcove (41.578 deep). Its swing reaches x 11.432 and clears the jog by 31.893.
   - E0 swing to the room-door swing: 22.263 clear.
   - Booth top 84.3125, 11.688 under the assumed ceiling.
5. **Saved after every step; screenshots taken.** Notes are committed in the commit named on line 1.
6. **Dimensions:** 17 number-only dims, **0 off z 0** (WR-Dims 9, WR-Dims-Doors 2, WR-Dims-Booth 6), plus one two-line floor note on WR-Notes.
7. **Scenes from AUTO-SET**, headless, popover defaults, fresh aspect-0 camera first:
   - 01-angled r **Render**, 01-angled **Image**, 02-front r **Render**, 02-front **Image**, 03-high r **Render**, 03-high **Image**, 04-side **Image**, 05-ventilation **Image**, 06-plan **Image**;
   - plus the hand-made extra **08-second-door, Image**, on the last tab. It is kept because no plate shows S0 as a door.
   - No Skip marks.
   - WR-Ceiling and WR-Notes are hidden in all 10 scenes. The 6 earlier hand-made scenes were deleted.
   - Every scene's screenshot was viewed.
8. **Drop-in lights** from `wr-drop-lights.rb`, tool defaults, pressed after AUTO-SET:
   - 4 fixture groups "WR Fixture F4 flush aperture" with **8 V-Ray emitters**, all on tag **WR Lights**;
   - the room ceiling was borrowed, 0 walls borrowed;
   - fill 0 of 14 placed and the face wash skipped, because the room is too tight.
   - AUTO-SET was not re-run: its header does not read the rig. All pages were checked: WR Lights shown, ceiling and notes hidden.

**Preflight (read only):** 4 PASS and 2 FAIL. The FAILs are dimension tags on and the floor on drafting white; `WR_Mode.to_render` clears both. Not pressed — that is Benton's call.

## Read first

- `clients/intelligence-security-laboratories/notes-7296.md`
- `.forge/builder/isl-7296/s4a-ctr-defs.rb` (the custom strips) and `s4d-expand.rb` (the expansion). Their headers carry the transforms.
- `s6d-floor-dims.rb`: every dimension, with its key and points.

## Assumptions

- **Room:** every dimension is estimated from the hand sketch; it may be off by a foot or more. Ranges: 114–123 wide, 180–195 long.
- **Ceiling:** 8'-0", the house default.
- **Room door:** 3'-0" x 6'-8", in the bottom wall 4" off the SE corner, hinged on the near jamb and swinging in. It is not on the sketch.
- **Second door:** hand L, to match E0.
- **Plan up:** model +y, which is not north.
- **Walls:** 4", cosmetic, built outward.
- **Placement:** the vent hardware is placed 1" off the right wall. The shell's 7.422" satisfies the 6" vented-wall rule.

## Open questions

1. What are the real room dimensions, ceiling height and entry door (position, hand, swing)?
2. Which hand and swing does the S0 second door take?
3. Foam: 4 sheets placed (N0i, N1i, S1i, W0i) against 7 quoted (5 + 2). The other 3 are out of scope.
4. Where do the 4 quoted cable passages go? None are placed.
5. What is the delivery path to the DC site?
6. The IEP wall lift was not measured; the importer's z was kept.
7. STD9624FL CTR carries a duplicate top-level Hinge as authored; it was kept in the copy.
8. The ENH CL CTR is asymmetric; the 96120 E transform was reused. Eyeball its orientation.
9. 06-plan's AUTO-SET framing crops the lower part of the room. 01/03/04 sit on the vent side.

## Gotchas

- **Bridge state.**
  - The bridge evaluates in ONE persistent binding. Use block-local names in lambdas: a stray top-level `bb` once made a check report the wrong part. Never use `CONST unless defined?` tables that go stale.
  - A bare `m.save` is refused; use `save.rb` with `--write-root`. The model reads "modified" again between calls, so save immediately before a guarded step.
- **AUTO-SET.**
  - It aims by mutating the view camera. Give the view a fresh perspective camera with aspect 0 first, or plates open zoomed in.
  - There is no headless entry; run the `autosetapply` callback body, as in s12.
  - Its header's "five scenes" is stale: the defaults give 9.
- **`WR_DropLights.run(given, subjects)`** passes `given` through `opts_from`. Pass `default_settings` (the settings shape), not the opts shape the header suggests, or `ceiling` and `layers` are lost.
- **The room's door container must be named `Doors`.** Renaming it (s10 did) made drop-lights treat the door group as a booth-sized keep-out. s14 fixed the name and moved the label onto the leaf.
- **Scene order.** SketchUp has no page reorder API, and export prefixes follow tab order. To move a page, re-capture it with `pages.add(name, PAGE_USE_ALL, index)` after selecting it (transition 0), copy its attribute dictionaries, then erase the old page (s16).
- **Dimension tools.**
  - The take-off build's vertex-anchored dimensions were lost on save; s6d uses plain points.
  - `WR_RoomDimsNow`'s fixed 40" offset puts the jog dimensions inside the room.
- **Light rectangles** show in viewport screenshots. The proposal package's image lane hides WR Lights on export.
