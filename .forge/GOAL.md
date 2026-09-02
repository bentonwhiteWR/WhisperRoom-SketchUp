# GOAL

## Mission
**Fix the standard deck (floor + ceiling) orientation on the 72-series.** Benton,
2 Sep 2026, checking 1.19.10 builds in SketchUp:

> The 6060, 6084 are correct. The 7272 has both of its floor components and ceiling
> components flipped the wrong ways. The hinges are all in the center, they should be
> on the sides. The 7296 ceilings are correct, but the floors need to be flipped since
> hinges are in the center, just like the 7272.

This is NOT the side-wall panel-order bug shipped in 1.19.10 — that commit never touched
`scripts/wr-deck.rb` (verified: `git log -- scripts/wr-deck.rb` stops at 1.19.2). It is
the per-model deck mirror, `MIRROR_DECK_KINDS` in `scripts/wr-deck.rb:836-841`.

## The state of the table today
```
MIRROR_DECK_KINDS = {
  [74.0, 74.0] => %w[FL CL],   # MDL 7272 S/E
  [98.0, 74.0] => %w[FL]       # MDL 7296 S/E — ceiling excluded
}
```
Line up Benton's three verdicts against it:

| model | kind | mirrored today? | Benton says |
|---|---|---|---|
| 7272 | FL | yes | wrong |
| 7272 | CL | yes | wrong |
| 7296 | FL | yes | wrong |
| 7296 | CL | **no** | **right** |

**Every mirrored entry is wrong and the one unmirrored entry is right.** The leading
hypothesis is therefore that the mirror is doing harm wherever it is applied and the
table should be empty. It is a hypothesis, not a finding — see below.

## Done means
1. The axis question is settled before the table is edited. `wr-deck.rb:798-801` is
   explicit that a mirror is not a rotation and that the two land differently, and it
   names the alternative outcome directly: "IF THE 7296 CEILING NOW COMES OUT MIRRORED
   THE OTHER WAY rather than right, this reading was wrong and the fix is the other
   mirror, not none." Benton's tell — hinges land in the CENTER, they belong on the
   SIDES — is a single-axis reflection about the deck seam. Show from the tile plan and
   the hinge geometry (`hinge_runs`, `wr-deck.rb:162`) that removing the current mirror
   moves the hinge run from the seam to the outer wall, rather than assuming it.
2. `MIRROR_DECK_KINDS` carries whatever the evidence supports, with the losing
   alternative left documented in the comment the way the file already does it. This
   file has been flipped four times in an evening before; the comment is what stops a
   fifth.
3. The offline harnesses stay green: `scripts/rbparse.py`, `scripts/rbtest-*.py`,
   `.forge/builder/replay-iep-deck.py` if it still runs.
4. `scripts/wr_tools/VERSION` bumped, DEVLOG entry, committed and pushed.

## Now — 2 Sep 2026
Fixer on fable owns the change. Nothing else in flight.

## Rules that bind this work
- No SketchUp and no `ruby.exe` here. `scripts/rbparse.py` boots SketchUp's own CRuby
  DLL and gives a real syntax check; run it before any commit touching `.rb`.
  `scripts/rbcheck.py` is a bracket counter, not a parser — a clean run there is not
  evidence.
- Only SketchUp can confirm this one. Say plainly what is unverified and hand Benton a
  short check list per model and per kind.
- **Read `WhisperRoomQuote`, never write it.**
- Never invent a placement number. Never recommend a booth model.
- Push to `bentonwhiteWR/WhisperRoom-SketchUp` as part of finishing, not batched later.

## Out of scope
- The side-wall panel order shipped in 1.19.10. Benton has confirmed 6060 and 6084 read
  correctly; his 7272/7296 report is about the deck, not the walls.
- `YAW_180_FILES` and the measured-yaw rule. The mirror sits on top of them and the two
  are deliberately separable — do not retune the yaw to chase this.
- The 19 open booth-builder audit findings; Benton has not picked a batch.
- The other 20 plugin audit findings at `.forge/auditor/full-audit-2026-09-01.md`.
- The two owed batches: the take-off docs slice and the six panel cleanups.

## History
2026-09-02 — 72-series deck hinges-in-the-center fixed and shipped as 1.19.11: the
per-model mirror was a reflection of X on decks that tile along X, so it moved every
SIDE bracket line to the seam; `MIRROR_DECK_KINDS` emptied, no mirror of any axis needed
now that 1.19.10 put the 46 in side panel on the low half where the parts are authored.
Unverified in SketchUp; check list in `.forge/fixer/HANDOFF.md`.
2026-09-02 — Audit finding 1 (mirrored side walls) fixed and shipped as 1.19.10. One
owner for panel order, wide panel at the door end on all four split-run models; pinned
both-paths test at `scripts/rbtest-side-wall-order.py`. Benton confirmed 6060/6084 in
SketchUp. The 50-key golden booth-matrix baseline still records the old behaviour —
8 `dry/` + 2 `build/` keys will report CHANGED, see
`.forge/builder/booth-matrix/STALE-1.19.10-side-wall-order.md`.
2026-09-02 — Read-only audit of the booth builder (desktop + mobile) delivered as an
artifact; 19 findings in six batches at `.forge/auditor/booth-builder/`. Awaiting
Benton's pick.
2026-09-01 — Full read-only audit of the plugin and skills; 22 findings at
`.forge/auditor/full-audit-2026-09-01.md`.
2026-09-01 — Floor-plan intake mission parked at `.forge/GOAL-prev-floorplan-intake.md`.
2026-08-31 — Render look-development mission parked at `.forge/GOAL-prev-render-lookdev.md`.
2026-08-30 — Portal-parity / proposal-package mission parked at `.forge/GOAL-prev-portal-vray-mission.md`.
2026-08-27 — Enhanced/IEP two-shell mission parked at `.forge/GOAL-prev-iep-mission.md`.
