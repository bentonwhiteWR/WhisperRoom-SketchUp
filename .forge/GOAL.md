# GOAL

## Mission
Make `auto-dimension.rb` dimension a room correctly no matter where that room's group or
component sits in the model. Today it only works when the containing group has an identity
transform, which happens to be the common case, so the failure is silent rather than loud.

## Done means
- `collect` (scripts/auto-dimension.rb:76-84) carries a transformation down the recursion, so
  every face's geometry is expressed in world coordinates by the time a caller uses it.
- Every consumer of that pool — `floor_face`, the wall-run tracer, the door finder, the
  bounding box that positions the chains — reads world coordinates.
- Demonstrated on a room group that is moved AND rotated, not just moved.
- Behaviour on an untransformed room (today's working case) is provably unchanged.

## Now
One Fixer on `scripts/auto-dimension.rb`. Nothing else in the tree is in scope.

Confirmed before delegating (observed in source, 2026-08-16): `collect` recurses into
`Sketchup::Group#entities` and `ComponentInstance#definition.entities` and appends the faces
raw. No `e.transformation` is applied anywhere on that path.

## Out of scope
- The five low-severity findings still open in `.forge/auditor/script-audit.md` (the
  `11'-12"` console rounding, the `to_f` standoff fields, the `list-scenes` escaping gaps,
  the two workshop scripts advertising dialogs, the dedupe-by-name in angled-component-art).
- `dimension-booth.rb` and `dimension-selection.rb` — they read a selection, not a traced
  floor face, and are not implicated.
- Spec steps 6 and 7 from the panel redesign (pre-run settings sheet; deleting the legacy
  `ico-*.svg` library).
- The `WhisperRoomQuote` repo — read only, never write.
- Prices. Nothing from `models.json` goes into any artifact.

## History
2026-08-15/16 — Panel redesign shipped: new `panel.html`, 29 icons, `@icon`/`@shelf`/`@rank`
headers, 14 renames, the autorun guard, the four-tag ownership fix, the three-line booth
label, the corner-anchored height dimensions, the exploded-view fan, and the scene-range
guard. Closed out by Benton confirming "Dimension the room" works after restart.
