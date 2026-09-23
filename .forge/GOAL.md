# GOAL

## Mission
Community Music School (Allentown PA, contact Deb Justice) — V-Ray renderings Benton will put
into a proposal. Booth per quote W-1109222607 + link `?d=b31cfb67e46d`: **MDL 96144 E** (8'x12'
Enhanced, "Drum Studio"), door L, gray foam, WDO3236 window on S1, vents N0/N1/N2/W1, caster
plate + step, 3 x 52" studio lights, bass traps, Audimute package. Host room = the classroom in
two client photos (`clients/community-music-school/plans/`), no dimensions supplied.

## Done means
1. Built in Benton's open file `Z:/Sketchup/ClientDrawings/Community Music School CP SL MDL 96144 E.skp`
   over the bridge: booth from the link (real components), host room matched to the photos
   (fixtures, finishes, windows, radiators, doors, whiteboard, lights), every room dimension on
   the drawing marked ESTIMATED with its tolerance.
2. Booth dimension images via Dimension a WhisperRoom + Rotate booth dimensions.
3. Lighting: drop-in lights + the room's own fixtures/daylight. Scenes via AUTO-SET ("auto fit").
4. V-Ray renders of every scene, read and checked; model saved.
5. Estimate + what didn't build written to `clients/community-music-school/notes.md`; committed.

## Now
Room (HANDOFF steps 1-3) DONE and approved by Benton 22 Sep: joint7 fit, EST. dims, photo-match scenes "Photo A - long view" /
"Photo B - corner view" (commit 9a6ff7c). Booth placed (18 in panel-face off Wall D), 4 Audimute
panels, radiator 2 moved per Benton's ruling; Benton added the studio lights himself. Now: lighting TEST renders (~800 px
only) + a scene plan (`.forge/builder/cms/scene-plan.md`: render/skip + text per scene) for Benton to decide. NO final
renders until he says. Renders go to `Z:/Sketchup/ClientDrawings/Community Music School - renders/`. Resume:
DEVLOG.md top entry → `.forge/builder/cms/HANDOFF.md` (steps 1-10) with `clients/community-music-school/notes.md`.
Benton decided: booth backs onto the near end wall (photo A camera wall), 18 in off it, door/window
into the room; no drum kit; 2 photos only; replicate the room as close as possible.

## Out of scope
Building the proposal PDF (Benton does it); prices anywhere; WhisperRoomQuote; editing `scripts/` EXCEPT the
Benton-approved proposal-package.rb change (16:9 both lanes, forced output size, sidecar cleanup) with VERSION bump.

## History
- Paused 22 Sep: WhisperRoom concept art (96120 E loft). Resume: `.forge/builder/concept-art/RESUME.md`.
- Parked 22 Sep: build-room redesign 1.72.0, awaiting Benton's live build (`.forge/builder/HANDOFF-build-room.md`).
