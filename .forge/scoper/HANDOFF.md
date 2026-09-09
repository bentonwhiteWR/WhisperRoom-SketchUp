# HANDOFF — Scoper → Builder (PeoplesSpace alcove rework)

## Produced
- `clients/peoplesspace/takeoff.json` — stated-measurement take-off, validates clean
  (`python scripts/takeoff-check.py clients/peoplesspace/takeoff.json --html`); lock and
  review sheet regenerate from it (gitignored). Four flagged values, all named.
- `clients/peoplesspace/NOTES.md` — fit arithmetic, the five old callouts reconciled,
  what the fragment does not tell us, flags, the batched questions for Benton.
- `.forge/scoper/peoplesspace-room.md` — the Builder spec (geometry, tags, materials,
  anchors, dimensions, scenes, acceptance criteria).
- `.forge/scoper/peoplesspace-alcove.mockup.html` — the approved drawing, published at
  https://claude.ai/code/artifact/90d9a19d-5ac9-44eb-95c2-07f2d08fba94
- `clients/peoplesspace/plans/` — architect fragments + the marked-up PDF (gitignored).

## Read-first
1. `clients/peoplesspace/NOTES.md` (10 min) — then the spec.
2. `clients/peoplesspace/takeoff.json` — the numbers, with sources.
3. `scripts/wr-roof-vent.rb` header and `scripts/booth-from-link.rb` ~line 620 (the
   Enhanced shell has no ramp component).

## Assumptions
- Page top of the architect's plan is north; east side is open. Read from linework and
  the p.3 photo, not stated by anyone.
- LEVEL 01 FF 0'-0" is the top of the raised floor; heights are measured from it.
- Pipe band 0–21" off the concrete wall; grille bottom ~103.7"; cloud starts ~22" off
  the concrete — all pixel reads of the elevation, ±2".
- "Left/right" = door end along the booth's front as seen from the open east side.
- Hinge on the corner-side jamb in both options; leaf 32" in a 49" frame.
- Booth is MDL 96120 E + ADA off the existing proposal; roof-mount is a client request
  not yet confirmed with sales.

## Open questions (Benton — one batch, in NOTES.md)
1. What is east of the alcove line (ramp toe and door stand 1½–2½ ft past it)?
2. Raised floor thickness / datum / does the booth sit on it?
3. Is roof-mount agreed with sales — is there a link with rv=1?
4. Confirm the left/right reading and the hinge side.
5. Ramp rise and slope source; ramp geometry for an Enhanced shell.
6. Pipe plan position and grille projection — can the architect supply them?
Also flagged: pages 2–6 of the proposal that went out carry the subtitle "FORT
VANCOUVER REGIONAL LIBRARY". Not fixed; the rework must not inherit it.
