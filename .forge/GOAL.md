# GOAL

## Mission
Concept art for WhisperRoom: build the booth from Benton's share link (MDL 96120 E, R-hand
wide-access ADA door + ramp, elevated floor, height extension, 3 windows, desk, roof-mounted
vent, purple foam) in the live SketchUp 2026 session over the bridge, inside a genuinely
beautiful host room, lit with V-Ray, and render hero images good enough to be WhisperRoom
concept art. Benton: "just playing around but let's see what you can do."

## Done means
1. The booth is built from the link with the real components (`scripts/booth-from-link.rb`),
   in an Untitled model — nothing hand-modelled in place of a real part.
2. A designed host room around it (architecture, materials, furniture/props, windows/daylight)
   plus a deliberate V-Ray lighting setup.
3. At least three finished V-Ray renders (hero exterior, a second angle, one mood/detail shot),
   each looked at and critiqued, iterated until they read as marketing-grade.
4. Renders + a contact sheet on Benton's Desktop; the scene-build Ruby kept so it can be rerun.

## Now
PAUSED 22 Sep 15:34 by Benton (CPU needed); resume 23 Sep. State, all observed:
- Model saved: `Desktop\WhisperRoom Concept Art\96120-studio\WR-96120-concept-studio.skp` (15:34:31).
  Booth in the NW corner, raytested 18.0 in off the west and north walls. Foam over the desk trimmed.
  Loft + Cosmos furniture placed, drop-in lights rig re-dropped after the move, 13 AUTO-SET scenes.
- 3 test renders in `...\96120-studio\work\` (t02-angled-final.png is the good one). ZERO finals,
  no `review\` folder yet. A render was mid-flight at pause and was stopped (`:idleStopped`).
- Pipeline the Builder left: `.forge\builder\concept-art\shots.json` (7 AUTO-SET + concept shots),
  `batch.py ID ... --w 2560 --h 1440` renders, `finish.py` display-encodes, `scene-build.rb`
  (`WR_Concept.run!(:all)`) rebuilds room/props. No HANDOFF.md was written before the stop.
- NEXT: reopen the .skp in SketchUp 2026, spawn an opus Builder to read these files and render the
  finals (consider 1920x1080 at ~12 min each vs 2560x1440 at ~20 — ask Benton), write `review\`
  JPEGs + manifest.json, then the orchestrator publishes the review gallery artifact.
- Bridge saves outside temp need `--write-root "<folder>"`.

## Out of scope
Changing tool scripts under `scripts/` or the plugin (a bug found gets reported, not fixed);
the WhisperRoomQuote repo; client proposals; prices anywhere in the images.

## History
- Parked 22 Sep, not finished: build-room redesign 1.72.0 (built and pushed 18 Sep), waiting on
  Benton's one live build. State in `.forge/builder/HANDOFF-build-room.md` / `HANDOFF.md`.
- 15 Sep: UTHSC V3 revision pack delivered; awaiting Benton's caption review.
- 14 Sep: lights panel 1.70.0, Dimension selected room 1.71.0, no-vent wall fix 1.71.1.
