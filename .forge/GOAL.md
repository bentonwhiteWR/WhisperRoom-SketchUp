# GOAL

## Mission
Rework the PeoplesSpace MDL 96120 E + ADA layout. Benton drew the original by hand
before the room-building pipeline existed; the client has returned the proposal marked
up and the architect has now supplied a partial plan and elevation. Draw their room
properly in SketchUp so the booth can be placed and re-rendered.

## The numbers we have (from the architect's fragment, all marked VIF)
- Alcove depth  10'-8 3/4" VIF
- Alcove width   9'-6 3/4" VIF
- Bottom of pipe        8'-3 1/4" VIF
- Acoustic cloud ceiling 9'-5"    VIF
- Concrete structure    10'-2"    VIF
- Level 01 FF 0'-0", with a RAISED FLOOR noted on the elevation
- MDL 96120 E exterior: 8'-2" x 10'-2", install height 7'-1" (models.json, observed)

## Done means
- A take-off of the alcove per the whisperroom-takeoff skill: every stated number
  transcribed, never estimated, chains closed, provenance on each.
- A clear fit verdict with the arithmetic shown: booth + ADA ramp (45.625") + vent
  clearance against 9'-6 3/4" x 10'-8 3/4", and roof-mount height against the
  8'-3 1/4" bottom of pipe.
- A to-scale dimensioned Artifact of the alcove with the booth placed, per CLAUDE.md's
  drawing conventions (chain dimensions every wall run, door centrelines, legend).
- A SketchUp Ruby script under scripts/ that builds the room to the measured interior
  faces, tagged @tab client.
- Everything the fragment does NOT tell us named explicitly, not guessed.

## Benton's answers (2026-09-09, verbatim intent)
1. East of the alcove is OPEN SPACE.
2. The "RAISED FLOOR" on the architect's elevation is the WhisperRoom raised floor -
   2.75" above the normal WhisperRoom floor. It is ours, not the building's.
3. Roof-mount on a sales quote: "Idk I thought we had it" - NOT confirmed. Draw it,
   label it unconfirmed, and get the quote link before anything ships.
4. Left/right: go with the projection as drawn (south end = left), per the Scoper's
   reading. Hinge side still unstated.
5. Assume ramp geometry exists for the Enhanced shell. THE RAMP RUNS INWARD, not east -
   on the LEFT side, opening against the GLASS WALL the booth sits next to.
6. Pipe plan position: estimate it, and say it is an estimate.

## Now
Builder: write the SketchUp room script from .forge/scoper/peoplesspace-room.md, with
the ramp re-arranged to run inward along the glass wall and the 2.75" raised floor
carried into the height stack.

## Out of scope
- Choosing or changing the booth model. It is MDL 96120 E with ADA, off the existing
  proposal. Sales owns the model.
- Building the proposal PDF (that comes after the renders exist).
- Prices, lead times, freight.

## History
- 1.19.14 shipped: roof-mount (rv) refusal now counts cable walls instead of matching
  slot ids, so a moved-cable-wall design builds.
- Ceiling lights were never missing - Draft mode hides the WR Lights tag.
- Broadcaster General Store proposal - paused.
