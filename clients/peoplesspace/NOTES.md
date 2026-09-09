# PeoplesSpace — alcove rework, MDL 96120 E + ADA (Sep 2026)

Working notes for the rework Benton asked for ("draw up their room now that we have
more context"). The transcription itself is `takeoff.json` beside this file; it
validates clean (`python scripts/takeoff-check.py clients/peoplesspace/takeoff.json --html`)
and the review sheet / lock are regenerated from it. Client assets live in `plans/`
and are gitignored.

Layout artifact (both handednesses, height stack, chains, provenance):
https://claude.ai/code/artifact/90d9a19d-5ac9-44eb-95c2-07f2d08fba94

Provenance words used throughout: **observed** (read it myself), **derived**
(arithmetic I can show), **reported** (a document or person says so), **assumed**
(needed it, did not check).

## What we were sent

1. The client's marked-up copy of the August proposal, 6 pages (`plans/EST54168-markups-9.4.pdf`).
   All red markup is on page 3 — eleven FreeText balloons (observed via PyMuPDF annots):
   - Include acoustic cloud ceiling in rendering
   - Show ideal location for power/outlet (ceiling) or concrete wall — most accessible
   - Include glass wall
   - Shift exterior ventilation ducting and silencer boxes to the ceiling/top of booth;
     cutouts toward the perimeter/front for service access
   - Include dimensions (width, depth, total height, slope) of ramp
   - Include dimensions of clear floor space of interior of booth
   - Include 2 options: 1) door/ramp on left side, 2) door/ramp on right side
   - Include recommended "CeaseFire CFP 640LP" fire suppression kit and location
   - Existing Conditions / White Box Rendering labels, and the three height callouts
     (concrete structure 10'-2", acoustic cloud 9'-5", bottom of pipe 8'-3 1/4")
2. The architect's partial plan and elevation (`plans/architect-plan.png`,
   `plans/architect-elevation.png`), sent in reply to "what's the other dimension of
   your space?".

## Stated numbers (transcribed, all VIF per the architect)

| Number | What it is | Source |
|---|---|---|
| 10'-8 3/4" VIF | alcove clear depth, N–S, storefront line to concrete face | architect-plan.png, dimensioned on the west side |
| 9'-6 3/4" VIF | alcove clear width, E–W, partition face to the concrete wall's east corner | architect-plan.png, dimensioned below the concrete wall |
| 8'-3 1/4" VIF | bottom of pipe | architect-elevation.png |
| 9'-5" VIF | acoustic cloud ceiling | architect-elevation.png |
| 10'-2" VIF | concrete structure | architect-elevation.png |
| 0'-0" | LEVEL 01 FF, drawn at the TOP of a band labelled RAISED FLOOR | architect-elevation.png |

Compass (interpretation, observed from the linework + the p.3 photo): page top = north.
South = cast concrete (hatched), west = thin partition (the yellow slat wall in the
photo), north = glass storefront with mullions, **east = open — nothing drawn above the
concrete wall's east corner**. The photo is taken from the east looking west: concrete
left, glass right, slat wall at the back. The elevation is the same view.

## The five callouts on the old proposal's plan (p.6), reconciled

Derived by pixel measurement of the p.6 top-down at 400 dpi (9.2 px/in), ±1":

| Callout | Measures | Arithmetic |
|---|---|---|
| 10'-8 3/4" | alcove depth — **identical to the architect's** | — |
| 9'-6 3/4" | alcove width — **identical to the architect's** | — |
| 3'-9 5/8" | ADA ramp projection off the door wall | 45.625" = `RAMP_PROT` in layout-render.js (observed) |
| 11' | booth long side + wall-mounted silencer boxes | 122 + 10 = 132, exact |
| 9' | booth short side + the gap WR drew to the back wall | 98 + 10 = 108, exact |

So the two room numbers agree with the architect and nothing disagrees. But the 11'
overall was already 3 1/4" **longer than the 10'-8 3/4" alcove** on the original drawing —
the silencers overhung the alcove line on the side the original left open, which in the
architect's frame is the glass wall. The original layout did not fit with wall vents; the
client's roof-mount request is what makes it fit.

Frame mapping (derived): the original's blue N and E walls are the architect's S concrete
and W partition — the same layout rotated 180°. The original's door (W wall, N end) is the
architect's door on the E wall, S end. Option 1 = as drawn.

## Fit arithmetic (derived from observed constants)

Booth 96120 E exterior 98 × 122 (models.json: `8' 2" x 10' 2" x 7' 1"`, observed).
Clearances from layout-render.js `clrIn` (observed): 1" nominal, 6"/10" vent wall,
34.5" swing for a 49" frame, 45.625" ramp; roof-mount reserves no vent clearance.

- Orientation: 122 across 114.75 fails outright, so the long axis is N–S and the door is on
  the east (open) long wall. Only the door's end is a choice.
- N–S: 128.75 − (1 + 122 + 1) = **4.75" float**. A wall vent on either short wall: 122 + 6 + 1
  = 129 > 128.75 (¼" over; 4¼" over with EFS). Vents on the west long wall would fit
  dimensionally (98 + 10 + 1 = 109 < 114.75) — stated as a fact, not a recommendation.
- E–W: booth 1" off the west wall reaches 99". Swing to 133.5", ramp toe to 144.625":
  **29 7/8" past the alcove's 9'-6 3/4" line** in either option.
- Height: RM96120 unit 10.3125" tall (measured off the .skp, VSS twin identical —
  wr-roof-vent.rb, observed). Rule: 85 + 10.3125 = 95.3125" vs 99.25" → **3.94"**.
  Physical: 84.3125 + 10.3125 = 94.625" → **4.63"**. Cloud 113" and structure 122" are
  not the constraint. Everything assumes the 0'-0" datum is the top of the raised floor.
- The unit is centred on the nominal footprint: it starts 5.25" from the concrete wall,
  so it is under the assumed 21" pipe band for its first ~16".
- Grille on the west wall reads ~103.7" to its underside (pixel read of the elevation,
  ±1.5"); ~8" above the unit if its projection reaches that far. VIF.

Option 1 (door south end): door frame 3"–52" from the concrete face, centreline 27.5"
(2'-3 1/2"). Option 2 (door north end): frame 72"–121", centreline 96.5" (8'-0 1/2"),
i.e. 32.25" from the glass line; the ramp lands in front of the storefront's east end.

## What the fragment does NOT tell us

- What is east of the alcove line. Ramp toe and open door stand there in every option.
- Raised floor: thickness; whether the 0'-0" datum is its top or the slab; whether the
  3,100 lb booth sits on it (models.json enhLbs, observed).
- The pipes' plan position, count and diameter (three by the photo; 21" band is a
  pixel read).
- The west-wall grille: bottom height, projection, supply or return.
- Whether the glass wall has a door at its east end and where it swings (matters for
  option 2).
- Wall thicknesses; the concrete wall's east return; the storefront's mullion spacing.
- Power location, fire-suppression kit placement, how the roof unit exhausts — none of
  which I am allowed to invent.
- Ramp rise and slope (the client asked): not in models.json, options.json or
  layout-render.js. The ramp's plan footprint is (46" at the door, 36" at the foot,
  45.625" deep — layout-render.js, "Benton's measured ramp").

## Flags

- **Every content page (2–6) of the proposal that went to the client is subtitled
  "FORT VANCOUVER REGIONAL LIBRARY"; the cover says PeoplesSpace.** Confirmed by text
  extraction on all six pages. Copy-paste from a prior job. Not fixed here — the old PDF
  stays as sent; the rework must not inherit it.
- `booth-from-link.rb` (observed, line ~620): Benton, 24 Aug 2026 — "Ramp only attached
  to standard. There's not a separate one that uses it for enhanced." The Enhanced door
  component has no ramp variant, so the Builder must add ramp geometry separately.
- options.json says the ADA package "includes 32" wide door, no-threshold entry, ramp,
  and raised floor" — the booth's own raised floor, distinct from the building's.
- The 96120 E stock layout (wr-booth-data.rb, observed) has VNT panels on the back (N0,
  N2) and right (E0) walls; roof-mount rewrites them to CBL. Door slot S0 at the low-x
  end of the front wall = the viewer's left when facing the front = the south end here.

## Questions for Benton (one batch)

1. What closes the alcove on the east? Open floor, a column, a low wall? The ramp and the
   open door stand 1½–2½ ft past the 9'-6 3/4" line in both options.
2. Raised floor: how thick, is the architect's 0'-0" its top, and does the booth sit on it?
   The roof-unit-to-pipe margin is under 4" before any of that is subtracted.
3. Is the roof-mount change agreed with sales (a new quote / link with rv=1), or only a
   client request? I draw what is on the quote.
4. "Left/right": I read it as the door's end along the booth's front as seen from the open
   east side (south end = left = as drawn). Confirm, and confirm hinge side (L/R pack).
5. Ramp rise and slope for the callout the client asked for — where do those numbers come
   from? And is there ramp geometry for an Enhanced shell, given the 24 Aug note?
6. Is the pipe band really the three pipes along the concrete wall (photo), and does the
   architect have their plan position? Same for the west-wall grille's projection.
