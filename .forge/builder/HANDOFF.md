# Builder handoff — dimension-booth.rb label rewrite (2026-08-15)

## Produced
- `scripts/dimension-booth.rb` — always-three-line label (`MDL …` / `Ext dims:` /
  `Int dims:`), new `LABEL_RISE = 36.0` and `INTERIOR_HEIGHT` constants, a `rise`
  setting, and an expanded console block. Only production file touched.

## Revision, same day
Benton overruled the fourth `incl. vent …` line — always three lines now — and
supplied the interior clear height, 6' 8". Consequences:
- The console is now the ONLY place reconciling the drawn extent with the
  catalogue box. It prints box, faces, +5 1/2" per face, then extent. Do not
  thin that print out; the comment above `label_for` says why.
- `INTERIOR_HEIGHT = { 'Standard' => 80.0 }` — **Enhanced entry deliberately
  absent**, awaiting Benton. An Enhanced booth shows interior w x d only and the
  console states that it is not an oversight. Adding Enhanced is one line.
- The height dimension **stays on the near-left corner**, offset `(-g, 0, 0)`.
  A mid-west-face anchor was built and then reverted: Benton chose the corner
  explicitly on 2026-08-15. In a three-quarter view screen-across is roughly
  `0.707 * (x + y)`, so a mid-face anchor slides the string over the booth
  (96120: +20 against a silhouette spanning 0..163) while the corner clears it
  (-17). It also keeps this file agreeing with `scripts/dimension-selection.rb`,
  which places its height the same way. The reasoning is in the comment above
  `draw`. Do not re-derive the mid-wall version.

## Read first
- The long comment above `label_for` in `scripts/dimension-booth.rb`. It records
  why "Ext dims" is the vent-inclusive **extent** rather than the catalogue box,
  and why the interior line carries two figures and not three. Both are the kind
  of thing that gets "simplified" into a wrong number.
- `scripts/wr-booth-data.rb` supplies `:iw` / `:ih`. All 25 models have them.

## Assumptions
- `:ph = 81.0` is the wall **panel** height (hard-coded by `gen-booth.py`, used
  by `build-booth.rb` to pushpull the wall face), **not** a published interior
  clear height. Interior height is therefore omitted from the label.
- The rendered labels were produced by a Python reimplementation of `arch()`,
  not by SketchUp's own `format_length`. Figures are right; exact spacing is my
  reading of SketchUp's Architectural format.

## Open questions
- Is there a published interior clear height for a Standard booth? If Benton
  supplies it, add `:ich` to the data and a third term in `label_for`.
- Vent faces print alphabetically (`E N`, not `N E`) in both the label and the
  console. Left as-is for consistency; a compass-order sort is a one-line change
  if Benton prefers it.
- 36 in of rise is a judgement, unverified in the viewport. Adjustable via the
  new "Label above booth (in)" setting.

---

# Builder handoff — dimension-selection.rb height placement (2026-08-15)

Appended by the second builder on this pair. Everything above belongs to the
`dimension-booth.rb` builder and was left untouched.

## Produced
- `scripts/dimension-selection.rb` — the height dimension moved from the
  front-right corner with a 45 degree `(0.7g, -0.7g, 0)` offset to the
  front-left corner with a single-axis `(-g, 0, 0)` offset, plus the long
  comment above `draw` that states the placement rule and shows the clearance
  arithmetic. Only production file touched. Committed as `8ca3392` and pushed.

## Read first
- The comment block above `WR_DimensionSelection.draw`. It carries the rule
  (every dimension pushes straight out of the face it belongs to), the two
  rejected single-axis alternatives at the front-right corner and why extra
  standoff does not rescue either, and the screen-projection argument for
  staying on the corner rather than sliding to the face midpoint.

## Assumptions
- The three-quarter view is a front-right camera, which is what the file's own
  pre-existing comment asserts. The screen-across projection `0.707 * (x + y)`
  follows from that and is derived, not observed in the viewport.
- `dimension-booth.rb`'s note above says its height moved to the **midpoint of
  the west face**; its code as I read it is on the near-left corner, same -X
  offset. Mine is deliberately the corner — the midpoint projects on top of the
  booth in a three-quarter view (+26.2 against a 0..155.6 booth span). Worth
  reconciling between the two tools before either goes to Benton.

## Open questions
- Unrun in SketchUp. No Ruby interpreter here; the geometry was checked in
  Python and `rbcheck.py` only balances brackets.
- Whether the height should read up the left of the FRONT elevation (what I
  did) or the left of the LEFT elevation is a taste call Benton has not made.
