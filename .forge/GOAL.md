# GOAL

## Mission
Booth-link importer (`scripts/booth-from-link.rb`) places the accessories a quote carries: studio lights,
HEPA filters, bass traps and the Audimute acoustic package. Today it refuses `sl` / `ac` / `bt` by name
(~line 1127) and has no `hp` (HEPA) handling.

## Done means
1. **SL:** the booth's blank `Standard Light` fixtures are replaced by the studio lights from
   `sl_by_model` in `WhisperRoomQuote/lib/pl-data/feature-rules.json` (T07 = SL29, T08 = SL52), with the exact count per model.
2. **HEPA:** one per vent set, on each INTAKE duct box (the box the fan hose does NOT connect to), in the open end,
   filter side up — the geometry proven in `.forge/builder/peoplesspace-ap/hepaout.rb`.
3. **Bass traps:** 2 per BASS TRAPS pack, standing in the upper interior corners by default.
   Pack counts: Practice/Recording = 3 packs, Drum Booth/Studio = 4 packs, otherwise the line qty (default 1).
4. **Audimute:** laid out on the interior walls by the `whisperroom-acoustic-package` skill (1.77.1), which the
   photo-job and takeoff skills run automatically when the link carries AP (1.77.3).
5. Parts come from `P:/Sketchup/NewMasterComponentList` (SL29, SL52, HEPA, Audimute2x4/1x4/1x2, Bass Trap).
6. `scripts/rbparse.py` is clean, VERSION bumped, DEVLOG entry written, committed and pushed. Live verification
   in Benton's SketchUp (over the bridge if it is up) or clearly reported as unrun.

## Now
Shipped 1.77.0–1.77.4 on 24 Sep; NONE of the importer accessory placement has been built live yet.
Next: Benton sends a Drum Booth link and leaves SketchUp on an empty model -> build it over the bridge and check
studio-light direction/spacing, Bass Trap.skp orientation, and the AP skill running after the import.

## Out of scope
MDL 127 LP (excluded from accessories); prices; writing to WhisperRoomQuote (read-only);
the People's Space open fixes; the hidden-tag warning (separate follow-up).

## History
- Done 23 Sep: People's Space AP/HEPA/MJP revision + Rev4 proposal (DEVLOG 2026-09-23).
- Paused 23 Sep: Community Music School 96144 E, at lighting TEST renders. Resume: `.forge/builder/cms/HANDOFF.md`.
- Paused 22 Sep: concept art (96120 E loft). Resume: `.forge/builder/concept-art/RESUME.md`.
- Parked 22 Sep: build-room redesign 1.72.0, awaiting Benton's live build (`.forge/builder/HANDOFF-build-room.md`).
