# Builder handoff — dimension-booth.rb label rewrite (2026-08-15)

## Produced
- `scripts/dimension-booth.rb` — three/four-line label (`MDL …` / `Ext dims:` /
  `Int dims:` / optional `incl. vent …`), new `LABEL_RISE = 36.0` constant and
  matching `rise` setting, one new console line for the catalogue interior.
  This is the only production file touched.

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
