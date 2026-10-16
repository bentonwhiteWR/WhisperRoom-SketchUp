# GOAL

## Mission
Intelligence Security Laboratories (Gregory Shelby, via Jill, 16 Oct 2026): draw the client's office
from their hand sketch (no dimensions) and build the quoted custom booth, MDL 7296 E + EXP 7224 E
(24 in expansion) + ADD ENHDOOR 30 (second door), in the empty SketchUp 2026 file, saved under the
company name.

## Done means
1. Room built from the sketch, scaled off the booth outline (74 x 122 exterior), every wall run
   chain-dimensioned and closing, including the left-wall notch. Every figure marked ESTIMATED in the
   model. Ceiling 8'-0" and the room's entry door are ASSUMED and labelled so.
2. Booth imported from link `?d=0411290978ec` (MDL 7296 E, door E0 left hand, vents N0/N1), then
   split between its two 46 in sections by 24 in: a new 22 in outer / 17.5 in IEP panel on each long
   wall, a new series of mid-wall seam seals, and 72 x 24 floor and ceiling centre pieces made from the
   9624 CL / FL CTR parts, shortened (not scaled) to 72. Exterior 74 x 122 confirmed by measurement.
3. Second door replaces the solid 46 panel S0 (the long wall facing the client's blue alcove, at the
   W end), same door part as the main door.
4. Booth placed as the sketch shows: vent wall to the right wall, main door facing the open floor,
   second door into the alcove; door swings checked against the room.
5. Saved to `Z:\Sketchup\ClientDrawings\Intelligence Security Laboratories MDL 7296 E EXP 2ft.skp`
   (new file, nothing overwritten); screenshots taken; notes in
   `clients/intelligence-security-laboratories/notes-7296.md`, committed and pushed.
6. All dimensions lie on the floor plane only (Benton, 16 Oct).
7. Scenes set with AUTO-SET in the proposal package (not by hand), plus one marked extra only for a
   view the plates miss (the second door); room ceiling hidden in every one (Benton, 16 Oct).
8. Drop-in interior lights from `wr-drop-lights.rb` (the plugin's tool, no hand-placed lights) (Benton, 16 Oct).

## Now
Builder sub-agent building room + custom booth through the bridge (16 Oct). Room ceiling tag
(WR-Ceiling) hidden at Benton's request.

## Out of scope
Rendering and export (Benton). Proposal PDF. Prices. Changes to plugin/tool code or the
parts share. WhisperRoomQuote. Placing the 2 extra expansion foam sheets beyond what the importer does
(report the count instead).

## History
- 12 Oct: Walsh Construction Tech Lab MDL 96168 E DONE (Benton): room take-off, booth + ramp/platform options,
  acoustics v8 (9 foam, AP 5/2/14), dims on the floor, 9 scenes, proposal PDF on the Desktop. See DEVLOG.
- 12 Oct: 1.84.0 (studio light height, take-off door dims/closure) verified live. IEP beams 1.83.2 done.
