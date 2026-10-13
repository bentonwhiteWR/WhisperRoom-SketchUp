# GOAL

## Mission
Walsh Construction (Sarah's request, 12 Oct 2026): build the Tech Lab (room 13) from the PHAME code-study
plan via the take-off pipeline, place the quoted 8' x 14' Enhanced (Recording Studio package) from the booth
link, and set up two ramp options with the ADA door in the same spot, then lighting and scenes, ready for
Benton to render.

## Done means
1. Tech Lab drawn via `whisperroom-takeoff` from the vector PDF (1/8" = 1'-0" at native 34x22 size), every
   wall run chain-dimensioned and closing, both 3'-0" x 6'-8" doors dimensioned off their corners. Ceiling
   height 8'-0" ASSUMED, unconfirmed (Benton).
2. Booth placed from the link at the plan's dashed location, 1" off the wall, model read from the link.
3. Recording Studio extras: every bass trap on the link plus the acoustic package (Audimute) placed well,
   per the `whisperroom-acoustic-package` skill; studio lights per the importer.
4. Option 2 = the booth exactly as the link imports it (standard ADA ramp included). Option 1 = a second,
   identical scene series; Benton duplicates the room, adds the side ramp + platform, sets visibility.
5. Lighting set for V-Ray; scenes for both options named to the scene-export conventions; each checked by
   screenshot; model saved under the client name, not over anything.

## Now
12 Oct evening (desktop): Benton APPROVED layout v8 = S1 + E1 (`.forge/builder/walsh/ap9/layout-v8.json`,
review https://claude.ai/artifact/5P796spUWJ1CXnFYPH2Jeh). Builder is applying it wall by wall in the Walsh file
(remove the 2 S1i squares, add 3 foam copies), saving after each wall, then verifying gaps/counts and the 16 scenes.

## Out of scope
The extra platform / side ramp (Benton adds it). Rendering (Benton). Proposal PDF (later). Prices.
WhisperRoomQuote. Standard BoothLighting 1.36 in drop (Benton undecided).

## History
- 12 Oct: 1.84.0 (studio light height, take-off door dims/closure) verified live. IEP beams 1.83.2 done.
