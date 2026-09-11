# GOAL

## Mission
Benton corrected a number he gave us earlier: the caster plate raises the booth
**4 3/4"**, not 3 3/4". His stated outcome, and the anchor for this work:
**an Enhanced booth on a CP measures 7'-5 1/16" (89.0625")**.
Make that true in the dimension tools and everywhere else the CP lift is used or
asserted, and say what had to change to get there.

## The arithmetic (observed 10 Sep 2026)
- 89.0625 = 84.3125 (HEIGHT_ENH, the DRAWN enhanced height, dimension-whisperroom.rb:123)
  + 4.75. So his figure is drawn-enhanced + a full 4.75 plate contribution.
- scripts/wr-overlays.rb:250 `CP_BOOTH_LIFT = 4.75` is ALREADY 4.75 and is described
  in-file as "Benton's 4.75 datum". The constant is not the problem.
- scripts/rbtest-boothdims.py pins THREE different plate contributions today:
  4.75 under the standard floor, 4.4375 under the mat (total 88.75 = 7'-4 3/4"),
  and 3.75 under the mat (total 88.0625 = 7'-4 1/16", labelled "Benton's figure").
  That last one encodes the number he has just retracted.
- scripts/wr-roof-vent.rb `ceiling_required` takes NO caster argument at all and
  returns a flat 83/85, so the "ceiling the room must give" line ignores the plate
  entirely. Audit finding, rank 02, still open.

## Done means
- An Enhanced booth on a CP reads 7'-5 1/16" wherever the toolset states it.
- Every stale 3.75 / 7'-4 1/16" assertion updated or removed, with the reason recorded.
- The ceiling-required figure accounts for the plate, or it is explicitly named as
  out of scope with a reason.
- The datum story is left coherent and documented, not three numbers in a comment.
- Verified offline, live-check script for the rest, committed and pushed.

## Now
Fixer reconciling the CP lift across scripts/ and the harnesses.

## Out of scope
- WhisperRoomQuote (booth-builder.html) — read-only from here; Benton has another
  agent on its toast removal.
- The other 53 audit findings.

## History
- AUTO-SET shipped 1.48.0, empty-model fix 1.48.1, both verified live 10 Sep 2026.
- Codebase audit 10 Sep 2026: .forge/auditor/*.md, artifact 2cf74938.
