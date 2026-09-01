# The door swing arc was drawn on the wrong side of the wall (31 Aug 2026)

## Symptom, as reported
Benton, looking at real rooms in SketchUp: *"all of the door swings are the
wrong way. The door is mostly shown inside the room, but the swing outline is
on the outside."* The leaf was right; the arc was on the opposite side.

## Root cause (one sentence)
`WR_BuildRoom.door` in `scripts/build-room.rb` built the leaf toward
`-outward(pts, i, ccw)` — which knows where the room is — but rotated the arc
by a sign that depended only on the hinge side, and that rotation always lands
on the **left-hand normal of the run**, which is the interior only when the
polygon winds counter-clockwise.

## Why it became universal today
Room winding used to be arbitrary, so the arc was right in some rooms and wrong
in others. Plugin 1.12.9 landed the clockwise-from-northwest convention and
`scripts/takeoff-check.py` enforces it, so every room now winds clockwise and
every door is wrong. Confirmed, not assumed: the offline reproduction below
fails on both clockwise cases and passes on both counter-clockwise ones.

## Reproduction
`scripts/rbtest-doorswing.py` — run it. It boots SketchUp's own CRuby through
`scripts/rbparse.py`, lifts `signed_area`, `outward` and `door` VERBATIM out of
`scripts/build-room.rb`, and runs them against a stubbed Geom that records what
was drawn. For both windings x both hinge sides it asserts:

1. the arc's far endpoint coincides with the leaf's tip
2. the arc's first point is the closed jamb
3. the arc's midpoint is on the interior side of the wall plane
4. the leaf tip is on the interior side

On the buggy code: `4 failure(s)` — both clockwise cases fail 1 and 3, with the
arc endpoint 36" outside the wall (y=156) while the leaf tip is 36" inside
(y=84), on a wall at y=120. On the fixed code: `0 failure(s)`, 18 assertions.

To re-trigger the original bug, restore in `self.door`:

    ang = (Math::PI / 2.0) * k / steps * ((hinge == 'far') ? -1.0 : 1.0)

## Fix
The arc's sweep sign now comes from the leaf's own tip:

    tipv = tip - pivot
    cz = (vec.x * tipv.y) - (vec.y * tipv.x)
    sweep = cz < 0 ? -1.0 : 1.0

so the arc ends at the leaf tip by construction, for either winding and either
hinge side. A flipped constant would have fixed clockwise rooms and broken
counter-clockwise ones — and room 3190J in
`clients/uic-daley-library/takeoff.json` legitimately declares
`"winding": {"order": "ccw", ...}`.

## Visual check
`swingshot.py` (scratch, at
`C:\Users\bento\AppData\Local\Temp\claude\C--Users-bento-OneDrive-Documents-Claude-Sketchup\87da3f21-6f6b-4dcc-8750-75cbeb1a22ca\scratchpad\swingshot.py`)
builds a four-run room with a door on every wall and hinges alternating
near/far, photographs it top-down and erases it — **all in one Ruby job**, so
nothing can happen between the build and the erase. It was three jobs at first
and the active model changed to Benton's `Master Component List.skp` between
the shot and the cleanup: the guard refused the cleanup and eight entities were
left behind (erased afterwards under a model-GUID guard, read back gone). One
atomic job is the lesson.

## Blast radius checked
`scripts/build-takeoff.rb` calls the same `WR_BuildRoom.door`, so the take-off
pipeline is fixed by the same change. Nothing else draws a swing arc from a
fixed sign: the review sheet's plan SVG and 3D view in
`scripts/takeoff-check.py` draw the opening but no arc or leaf;
`scripts/auto-dimension.rb` and `scripts/wr-overlays.rb` draw neither; and
`scripts/csusb-rooms.rb`, `scripts/csusb-106.rb` and
`scripts/dowaly-kuwait-tv.rb` carry an explicit measured `:swing => :in/:out`
per door rather than deriving one from the winding.
