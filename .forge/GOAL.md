# GOAL

## Mission
Two importer/take-off fixes, shipped as one plugin release:
1. Studio lights (SL) mount flush on the underside of their ceiling component, never hanging below it
   (and never below an IEP beam), and their spacing avoids roof-unit rods.
2. `build-takeoff.rb` dimensions doors, and stops reporting a false "DOES NOT CLOSE" when a free-standing
   pilaster's faces fall in a chain.

## Done means
1. SL top face measured flush (to 1/32) with the ceiling tile underside on a 96120 E and an RM booth;
   none below the beam bottom; none on a roof-unit rod.
2. A take-off with doors produces door dimensions (corner -> near jamb, then opening width, per CLAUDE.md),
   and the CCU pilaster case closes correctly while a genuinely unclosed chain still fails.
3. `scripts/rbparse.py` + the relevant rbtest scripts pass; VERSION bumped; DEVLOG; committed and pushed.

## Now
1.84.0 shipped and verified live on 12 Oct: 96120 E and 96120 S rv=1 lights flush (+0.0000), above the beam,
no clash; rods proven with stand-ins (the current RM parts have none below the roof); the CCU 113 take-off
gives a 6 1/8" + 3' door and CLOSES. Open: the panel install here reads 1.79.0 (reinstall), and BoothLighting is
Benton's call.

## Out of scope
WhisperRoomQuote (read only). Daisy stamp (dropped by Benton 12 Oct). Re-saving share part files.

## History
- 12 Oct: IEP beams in the importer shipped 1.83.2; Benton confirmed all beams import correctly, including
  MDL 10284 (the "10284 ceiling bug" theory in the code comments is unconfirmed; the seal-count check passed).
- 7 Oct: CCU Sands Hall 113 walls, lights and scenes done (see DEVLOG).
