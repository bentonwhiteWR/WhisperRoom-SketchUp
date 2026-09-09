# GOAL

## Mission
Fix booth-from-link.rb's roof-mounted (rv = 1) half-apply refusal: it wrongly aborts
when the user has MOVED the cable walls off the layout's default vent-slot positions
in the booth builder. Benton hit this on MDL 96120 E, ADA, RM + VSS.

## Done means
- The RM check no longer refuses a payload that carries the correct NUMBER of CBL
  packs (layout ventSets), regardless of which slots they sit on.
- It STILL refuses the real failure it exists to catch: a genuinely half-applied
  swap (fewer CBL packs than ventSets, i.e. leftover VNT walls or missing vents).
- Rule matches the portal's own invariant in booth-builder.html: (VNT + CBL) === ventSets.
- Console/messagebox text updated so it names the real complaint, not "slot N0
  expected a CBL pack here".
- scripts/rbparse.py clean on every .rb changed.
- scripts/wr_tools/VERSION bumped; committed and pushed to main.

## Now
Fixer: root-cause confirmed in roof_vent_complaints (booth-from-link.rb:752-773) —
it compares CBL packs against the layout's DEFAULT VNT slot ids, an identity check
where the product rule is a count. Make the minimal fix and prove it.

## Out of scope
- Any change to the WhisperRoomQuote repo (read-only from here).
- The roof-unit seating / wr-roof-vent.rb geometry.
- The Broadcaster General Store proposal (paused).

## History
- Broadcaster General Store proposal pack — paused for this bug.
- UT Health Sciences rev 2 proposal delivered and confirmed by Benton.
