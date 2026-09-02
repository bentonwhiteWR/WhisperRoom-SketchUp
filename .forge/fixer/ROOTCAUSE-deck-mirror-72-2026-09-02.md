# Root cause: 72-series standard deck hinges in the center (1.19.10 -> 1.19.11)

**Symptom (reported, Benton 2026-09-02, off 1.19.10 builds in SketchUp).** MDL 7272:
floor and ceiling both flipped, hinges in the center, should be on the sides. MDL 7296:
ceiling right, floor flipped the same way. 6060 and 6084 right.

**Root cause, one sentence.** `MIRROR_DECK_KINDS` applied `scaling(ORIGIN, -1, 1, 1)` — a
reflection of X — to decks that tile along X, so it reflected every SIDE tile across the
tiling axis and moved its bracket (hinge) line from the outer wall to the seam.

## The axis argument (derived; every link named)

1. **Both decks tile along X.** `plan` tries `[w, h, along_is_x=true]` first: 7272 is
   72 x 72 after the 1 in inset and tiles 48 + 24 from the 72-cross family; 7296 is 96 x 72
   and tiles 48 + 48. — derived from `wr-deck.rb plan()` (observed source) and the
   catalogue names (observed on the P: share).
2. **The tiling axis is each SIDE part's short axis, and that is where the bracket line is
   measured.** `_face-levels.tsv` (observed on `P:\Sketchup\NewMasterComponentList`):
   `short_axis X` for STD7248FL SIDE L/R (bracket_edge 0.2612) and STD7224FL SIDE R
   (0.7823). The `bracket_edge` fraction runs from bb.min.x, so 0.26 at the low end of the
   run is toward the low-X outer wall, and 0.78 at the high end is toward the high-X outer
   wall. The half-turn rule leaves both 7272 tiles unturned (0.2612 > 0.5 is false at the
   low end; 0.7823 < 0.5 is false at the high end) and turns only the 7296's high tile
   (SIDE R reads 0.2612); in every case the bracket line lands at the outer wall.
   — derived; the numbers are observed, the runtime `bracket_edge` agreeing with the TSV is
   **reported** by `scripts/rbtest-part-orientation.py`, whose fixture cross-checks the
   share (18 values agree today).
3. **A reflection of X on a tile whose short axis is X is a reflection across the tiling
   axis.** It sends 0.2612 to 0.7388 on the low tile and the high tile's bracket back toward
   the seam. Y is untouched. — derived, elementary.
4. **That reproduces all four verdicts.** The three mirrored decks (7272 FL, 7272 CL,
   7296 FL) get every bracket line at the seam = "hinges in the center"; the one unmirrored
   deck (7296 CL) keeps them at the walls = "correct". — derived from 1–3 + the reported
   verdicts.
5. **Removing the mirror moves the hinge run from the seam to the outer wall, and nothing
   else moves** (the mirror never touched Y, the yaw rule is unchanged). — derived.

Weakest link: the ceiling. `bracket_edge` on a convention-A ceiling measures nothing, so
the ceiling tiles take the floor twin's fraction (handed parts: unmirrored). That the
ceiling's bracket line sits in plan where the floor twin's does is the standing "coplanar"
**assumption** this file has always carried; Benton's "7296 ceiling right" with no mirror
and "7272 ceiling wrong" with the mirror is consistent with it (the 7272 CL low tile is
the same part, same end, same transform as the 7296 CL low tile, differing only by the
mirror).

## Why "the other mirror" is NOT wanted (the pre-registered alternative)

The comment at 1.19.2 said: if the 7296 ceiling comes out mirrored the other way rather
than right, the fix is the other mirror. Benton says it came out **right**. The other
mirror (Y) would move hinge stations along the long edge, i.e. which end the 24.125 in
(46 in wall) gap sits at. That is what his 2026-08-31 "mirror it, not 180" was about:
every 72-series floor part is authored with the big gap at 33% along = LOW half of Y
(`reference/floor-ceiling-geometry.md`, measured on STD7248FL SIDE L and STD7224FL
SIDE R), and the layout then put the 46 in side panel on the HIGH half (recorded in the
`layout_big_on_low?` comment, `wr-deck.rb:258-263`). 1.10.5 answered a Y mismatch with an
X mirror. 1.19.10 then fixed Y from the other side: wide panel at the door end, which on
the 7272 and 7296 is E0/W0 = 46 in at y 2..48 — the LOW half (observed in
`scripts/wr-booth-data.rb` and `.forge/fixer/side-wall-order-AFTER.txt`). Panels and walls
now agree on Y with no transform. So: table empty, not table-with-Y.

## Residual (not fixed here, out of scope)

The 7296's high floor tile is `STD7248FL SIDE R`, which the probe cannot tell from SIDE L
(same box, same face levels, same 0.2612). The half-turn rule yaws it, which is right for
the bracket line but reverses its long-edge pattern; if that file is a plain duplicate of
SIDE L (rather than its Y mirror) the east tile's 24.125 gap lands at the north end while
the E0 46 in panel is at the south. Only SketchUp can tell (measure `hinge_runs` on that
part, or look). Benton did not report it and it is the yaw rule, which this mission fenced
off. Listed in HANDOFF.md.

## Repro reasoning (no SketchUp here)

The reproduction is the derivation above run forward: with the 1.19.10 table, tile by tile,
where does `bracket_edge` land after `scaling(-1,1,1)`? Seam, seam, seam, seam, seam —
and for the 7296 CL (untouched) wall, wall. Pinned offline in
`scripts/rbtest-part-orientation.py` section 4 (table empty; mirror line still X so the
comment's alternative stays true; 7272/7296 E0/W0 on the low half).
