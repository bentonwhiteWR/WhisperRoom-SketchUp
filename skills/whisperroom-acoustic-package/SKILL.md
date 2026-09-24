---
name: whisperroom-acoustic-package
description: Load the WhisperRoom Acoustic Package (AP, Audimute 2x4 / 1x4 / 1x2 panels) into a booth in Benton's live SketchUp model and lay it out on the interior walls "as best as possible", interleaved with the blue studio foam. Invoke when the quote carries an "AP <model>" line or the booth link has ac=1, when Benton says "add the acoustic package", "place the Audimute", "AP panels", "acoustic panels in the booth", or asks to rearrange foam and Audimute for a render. Covers the per-model counts, the parts, the wall survey, the layout rules, the 1/2 in minimum gap, seating flush with the fabric facing into the room, and the verification pass. Not for bass traps, studio lights or HEPA (booth-from-link places those).
---

# WhisperRoom acoustic package: Audimute panels in a booth

**Worked example: People's Space, 96120 E (Sept 2026).** Its scripts are in
`.forge/builder/peoplesspace-ap/` and the story is in that folder's `HANDOFF.md` and in
the DEVLOG entry dated 2026-09-23. Those scripts are one-offs with that booth's wall
coordinates hard-coded, so copy their method rather than rerunning them. The layout they
produced is the reference result: every wall carries a 1x2 row on top, a 48 in band of
panels and foam, and a bottom row, with 1 in gaps.

All model work runs over the bridge in Benton's open file:
`python scripts/sketchup-bridge.py run <job.rb> --su 2026` (also `eval "<ruby>"` and
`shot out.png --width 1400`). A scene change animates, so take the screenshot twice.

## What goes in: the counts

The model comes from the quote's AP line (`AP 96120`) or the booth link's model. The source
is `AP_PACKAGES` in `WhisperRoomQuote/lib/ap-packages.js`, the table the Audimute purchase
orders use. That repo is **read-only** from here. Re-read the table with node before a job
(`node -e "console.log(require('./lib/ap-packages.js').AP_PACKAGES)"` run in that repo),
and never copy its `cost` column anywhere, because those are internal wholesale prices.

| Model | 2x4 | 1x4 | 1x2 | | Model | 2x4 | 1x4 | 1x2 |
|---|---|---|---|---|---|---|---|---|
| 4230 | 0 | 2 | 3 | | 84102 | 3 | 2 | 9 |
| 4242 | 0 | 2 | 5 | | 84126 | 3 | 5 | 7 |
| 4260 | 0 | 2 | 5 | | 96120 | 3 | 4 | 12 |
| 4284 | 1 | 2 | 5 | | 96144 | 4 | 3 | 12 |
| 4848 | 0 | 2 | 6 | | 96168 | 5 | 2 | 14 |
| 4872 | 1 | 0 | 10 | | 96192 | 6 | 3 | 14 |
| 4896 | 1 | 4 | 6 | | 102102 | 3 | 2 | 11 |
| 6060 | 0 | 3 | 7 | | 102126 | 4 | 3 | 11 |
| 6084 | 2 | 2 | 7 | | 102144 | 4 | 3 | 13 |
| 7272 | 0 | 6 | 10 | | 102168 | 5 | 3 | 13 |
| 7296 | 1 | 6 | 8 | | 102186 | 6 | 3 | 13 |
| 8484 | 2 | 4 | 7 | | 127 (MDL 127 LP) | 0 | 2 | 5 |
| 9696 | 3 | 0 | 10 | | | | | |
| 10284 | 3 | 2 | 9 | | | | | |

Copied 24 Sep 2026. **MDL 127 LP** has a row, but Benton excludes that booth from every
other accessory. Ask him before placing its panels.

## The parts

- `P:/Sketchup/NewMasterComponentList/Audimute2x4.skp`, `Audimute1x4.skp` and
  `Audimute1x2.skp`. Load them with `m.definitions.load`. The 2x4 stands 24 wide by 48
  tall. The 1x4 stands 12 by 48, or lies 48 by 12. The 1x2 lies 24 wide by 12 tall.
- The blue studio foam is already in the booth. Its definition is `Foam`, it sits on the
  tag `WR-Booth-Foam`, and each sheet is 24 x 48 standing. The same part is in the parts
  folder as `Foam.skp`.

## The stages, in order

1. **Orient.** Run `git pull`, read the top of `DEVLOG.md`, and find the booth. A client
   file can hold several copies of it. People's Space had the visible `Group#28`, a hidden
   right-door option `Group#27`, and an old copy far off. Work in the one Benton names,
   then ask whether the other options get the same layout.
2. **Measure the parts' true geometry.** Use `WR_Overlays.geom_extents(defn)` (load
   `scripts/build-booth-components.rb` and `scripts/wr-overlays.rb` with
   `$wr_no_autorun = true`). Do not trust the insertion point or the definition bounds.
3. **Survey the interior** (method: `survey2.rb` and `walls.rb`). Ray-test every wall face,
   the floor top, and the underside of the lowest ceiling part. On People's Space that part
   was the ceiling seam seals, not the ceiling tile. Then list the keep-outs with their
   world boxes: the door frame and leaf, windows, the MJP, cable passages and their plugs,
   interior vent grilles and silencers, studio lights, and the corner and ceiling seals.
   The usable run of each wall runs between its corner seals. That was 107.7 in on the
   People's Space back wall, against 113 in between the panel faces.
4. **Name the walls from inside the booth.** Stand inside facing away from the door. The
   wall ahead is the BACK wall, and "left" and "right" follow from that position.
   **Confirm with a screenshot before placing anything**, because the client's images are
   often mirrored against the model.
5. **Plan the layout on paper first** (rules below). Print it per wall: the part, the run
   span and the top z. Then check it against the keep-outs and the counts before any
   geometry moves.
6. **Place it** (method: `ap-v2.rb`). Each wall is one undo operation. Everything goes on
   the tag `WR-Booth-Acoustic`, and each instance is named `<part> <wall>`, for example
   `Audimute2x4 back`. The verification and the copy steps select pieces by that name.
7. **Seat it flush** (method: `ap-press.rb`). Press each panel's BODY onto the wall face
   found by ray test. The hang clips then sit about 0.12 in into the wall, which is
   expected. Where a panel crosses a vertical seam seal, it rests on the seal.
8. **Space it** (methods: `ap-spread.rb` for the gaps along each row, `vgap-light.rb` for the
   gaps between rows). Keep at least 1/2 in between any two pieces. Spread each row about
   its own centre, and refuse any row that would run past its wall's usable span.
9. **Verify** (next section), take a screenshot from inside, and report.
10. **Other booth options.** Copy the finished pieces with identical local transforms
    (`g27copy.rb`). Do this only after confirming that the two booths' local wall frames
    match. Seat-check the copy by ray test. Deleting foam in the copy is a foam move, so
    report it.

## Layout rules (generalised from People's Space)

- **Wall priority.** Place the back wall (opposite the door) first, then the two side
  walls, then the door wall last or not at all. Pieces on the door wall go only on solid
  runs, clear of the frame, the window and the MJP.
- **The stack, from the top down.** A row of 1x2s (or 1x4s laid flat), then a 48 in band
  that alternates panels and foam, then a bottom row of small panels. Top-align the stack
  about 1 in below the lowest ceiling part. On People's Space (78.5 in clear) the rows sat
  at z 68.56–80.56 (top row), 19.56–67.56 (band) and 6.56–18.56 (bottom row), with the
  raised floor at 4.06.
  If the booth is too short for all three rows, drop the bottom row and move those pieces
  to another wall. Never squeeze the gaps below 1/2 in.
- **Interleave with the foam.** People's Space used `1x4 | foam | 2x4 | foam | 1x4` on the
  back band and `foam | 2x4 | foam` on each side. **You may move foam** anywhere on the
  interior walls to make the pattern work, including across walls, and you may spin a sheet
  90° to do it. **Never delete foam without saying so.**
- **Make the side walls mirror each other.** Line up the side bands with the back band's
  height.
- **Never cut a panel.** If a piece does not fit whole, it goes somewhere else or it is a
  leftover.
- **Gaps.** At least 1/2 in between any two pieces, panel or foam, in both directions.
  Larger is better when the wall has room. People's Space used 1 in everywhere and it
  rendered cleanly.
- **Seating.** The body sits flush on the wall face and the fabric faces into the room.
- **Leftovers ("in and around the booth").** Pieces that do not fit inside are staged
  neatly on the floor beside the booth, outside the door clearance. Put them on
  `WR-Booth-Acoustic`, name each `<part> NOT PLACED`, and list them in the report.
  **Do not invent exterior wall mounting.** Ask Benton where they go.

## Verify before reporting

Measure each of these over the bridge on true geometry, not by eye:

- **Gaps.** Check every pair of pieces on the same wall, Audimute and foam alike. Build each
  piece's world box from `geom_extents` pushed through the full transform chain. The gap
  between two pieces is their separation along the run or along z, whichever is larger. Any
  pair under 0.50 in fails the check, and so does any overlap.
- **Clashes.** Check every piece against every keep-out box from stage 3. People's Space
  still had an open question about whether a panel covered the cable-passage plugs, so
  check those by name.
- **Counts.** Tally the placed pieces by definition, then add the leftovers, and compare
  the result with the table row. Report any mismatch. Do not fix it silently.
- **Fabric direction.** For each piece, the fabric normal (local -y) pushed through its
  transform must point into the room. This means it must point away from the wall face that
  the ray hit.
- **Seating.** Hide the pieces, cast a ray from each piece's centre toward its wall, and
  compare the result with the back of the body. The expected result is 0.00.
- **The look.** Take a screenshot from inside the booth. The render scene is
  `InteriorAcousticRender` (`scene-interior.rb`: an eye in the corner opposite the back
  wall, fov 70, tags hidden as in the overview render). Add it if the file does not have
  one.

Then **report to Benton**: the counts per wall, the leftovers, **every foam move** (from
where to where, and any spin), and every failed or unchecked item. **Save the .skp only
when Benton says to.**

## Traps we already paid for

- **The fabric faced the wall.** *Symptom:* on the first pass every panel showed its back
  to the room. *Cause:* the Audimute parts carry their fabric on local **-y**, so the
  obvious mapping (local y = into the room) mounts them backwards. The moved foam needed
  the same half turn. *Fix:* build the rotation from the reversed normal (`ap-v2.rb`):
  ```ruby
  ya = n.reverse                       # n = wall normal INTO the room; fabric is local -y
  if horizontal then xa = up; za = xa * ya else za = up; xa = ya * za end
  rot = Geom::Transformation.axes(ORIGIN, xa, ya, za)
  ```
- **The 1x2 would land 7.9 in high.** *Cause:* `Audimute1x2`'s geometry starts about
  7.9 in up inside its own definition (measured on People's Space). Placing it by its
  insertion point, or by an assumed corner, puts it too high. *Fix:* take the extents from
  `WR_Overlays.geom_extents(defn)`, rotate the 8 corners, then translate so the rotated
  extents hit the target run, face and top.
- **"Flush" was 0.12 to 0.23 in off the wall.** *Cause:* the panel was seated against an
  assumed face coordinate using its whole bounding box. The hang clips stick out past the
  body. *Fix:* hide the panels, ray-test the real wall face from each panel's centre, and
  move the BODY (the largest child instance) onto that face (`ap-press.rb`):
  ```ruby
  aud.each { |e| e.hidden = true }          # or the ray hits the panel itself
  hit = m.raytest([body_centre, n.reverse], true)
  d   = face_coord(hit[0]) - body_back      # then translate along n by d
  ```
- **The stack hit the ceiling seals.** *Cause:* it was top-aligned to the ceiling tile's
  underside, but the seam seals hang lower. *Fix:* the datum is the lowest ceiling part
  found by ray test, then 1 in below it (`ap-lower.rb`).
- **The run was shorter than the wall.** *Cause:* the corner seals take up part of every
  wall. *Fix:* measure the usable span between the corner seals before planning the band
  (stage 3).
- **The wrong wall was called "left".** *Cause:* the client's image was mirrored against the
  model. *Fix:* take left and right from standing inside, and confirm with a screenshot.
- **Brightening the interior render.** People's Space raised the booth `Standard Light`
  from 25 to 35. That change is written inside `scene.change` so that it persists, and it is
  read back in a later job (`vgap-light.rb`). The light definition is shared by every copy of
  the booth. Make this change only when Benton asks for it.

## Related tools

- **`scripts/booth-from-link.rb`** (1.77.0 and later) builds the booth and its studio
  lights, HEPA filters and bass traps from the quote link. It **refuses `ac` by name**:
  this skill is how the acoustic package gets placed after the booth is built.
- **whisperroom-photo-job** covers the whole job from client photos. Its stage 8 (extras
  such as Audimute) is where this skill runs.
- **whisperroom-proposal** covers the PDF. An interior acoustic plate
  (`InteriorAcousticRender`) gets captions that describe only what the image shows. Never
  write "soundproof" or an STC figure.
