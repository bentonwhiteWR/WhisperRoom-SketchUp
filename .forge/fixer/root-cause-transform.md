# auto-dimension.rb drew in the wrong coordinate space

Fixer, 2026-08-16. Nothing here was executed in SketchUp — there is no `ruby.exe` on this
machine. Provenance is labelled on every claim: **observed / derived / reported / assumed**.

## Verdict

The reported root cause is **confirmed**, and it is slightly worse than reported: the local
coordinates reach *five* consumers, not four, and one of them (`floor_face`'s own horizontal
test) can make the tool fail to find the room at all rather than merely misplace the numbers.

## The API facts the diagnosis turns on

Checked against the official SketchUp Ruby API documentation, not recall (**observed**,
fetched 2026-08-16):

- `Sketchup::Drawingelement#bounds` — "the boundingbox follows the coordinate system the
  drawing element is placed in." A face placed inside a group definition is therefore
  bounded in *that definition's* space, not the model's.
- `Sketchup::Face#area` — "You can pass in an optional Transformation … **to correct for a
  parent group's transformation**." This is the decisive one. An area argument that corrects
  for a parent transform would be meaningless if the face's geometry were already world.
- `Geom::Vector3d#transform` applies a `Geom::Transformation` to a vector; `#parallel?` is
  true "if there exists a scalar multiple between them", so it is insensitive to magnitude
  and to sign.
- `Geom::Transformation#*` applies the transformation to a point (`transformation * point2`
  yields the transformed point). Composition order is therefore **parent * child** — in
  `(parent * child) * p` the child applies first (**derived** from the documented point
  behaviour plus matrix associativity; the docs do not state composition order in words).
  Independently corroborated: `probe-levels.rb:110-112`, `wr-deck.rb:653-654` and
  `build-booth-components.rb:367-369` in this same folder already walk nested containers with
  exactly `tr * e.transformation` (**observed** in source).
- `Sketchup::Face#normal` is not documented as to space, but it must be local for the same
  reason `area` is: it is a property of geometry stored in the definition (**derived**).

## What was wrong, precisely

`collect` (was `scripts/auto-dimension.rb:76-84`) descended into `Group#entities` and
`ComponentInstance#definition.entities` and pushed the faces raw, never touching
`e.transformation` (**observed**). Every read below therefore saw container-local numbers
while treating them as world:

| Consumer | Local read | Consequence |
|---|---|---|
| `floor_face` horizontal test | `f.normal.parallel?(Z_AXIS)` | A room group rotated about X or Y hides its floor entirely — "No floor face found" |
| `floor_face` size test | `f.area` | A scaled group is measured at its unscaled area; a shrunk floor can fall under the 100 sq in threshold |
| `floor_face` lowest test | `f.bounds.min.z` | Wrong level picked; a ceiling can win once a container translates in Z |
| `runs_of` | `outer_loop.vertices.map(&:position)` | The whole chain is drawn at the room's *pre-transform* location |
| `dimension_face` overall | `face.bounds` | Both overalls drawn at the pre-transform corner, at the pre-transform size |
| `door_on_run` | `door.bounds.center` | Doors are top-level so their bounds ARE world — mixed against local runs, so no door ever matches the 24" proximity test |

The dimensions are created into `model.entities`, which is world space
(`auto-dimension.rb`, `ents = model.entities`), so local points land wherever those same
numbers happen to fall in the model — typically hundreds of inches away from the room, on
nothing.

It is silent rather than loud for the reason Benton's daily case works: `build-room.rb:300-353`
creates `room = model.entities.add_group`, then `fg = room.entities.add_group`, draws the floor
into `fg`, and calls `WR_AutoDimension.dimension_face(floor)` before anything is moved
(**observed**). A freshly created group's transformation is identity, so local and world
coincide and the bug is invisible. It only appears on a **re-run** over a room that has since
been moved, rotated or scaled.

## The fix

Smallest change that is actually correct, all in `scripts/auto-dimension.rb`:

1. `collect` takes an accumulating `tr` and pushes `[face, tr]` pairs, composing
   `tr * e.transformation` on each descent. Nested containers compound correctly because the
   product carries the whole chain from the root down.
2. `floor_face` filters on `f.normal.transform(tr)` and `f.area(tr)`, picks the lowest face by
   a new `world_z(face, tr)` helper (one transformed vertex — for a face already known
   horizontal in world, every vertex shares that height, and a rotated container's bounding
   box no longer has its min corner as its minimum). It now returns `[face, transform]`.
3. `runs_of(face, tr)` transforms each vertex position as it reads it. Every run, and so every
   segment dimension, door hit and closure figure, is world from that point on.
4. `dimension_face(face, opts)` reads `opts[:transform]`, and takes the overall from a new
   `bounds_of(runs)` — the world bounding box of the traced perimeter — instead of the local
   `face.bounds`.
5. The two entry points (`ability_on`, `run`) destructure the pair and pass the transform.

`opts[:transform]` defaults to identity, so `build-room.rb:353`'s `dimension_face(floor)` call
is untouched and still correct — it hands over a face whose group transform genuinely is
identity.

## Proof, given that no Ruby can run here

`.forge/fixer/transform_repro.py` is a line-faithful Python reimplementation of the coordinate
math — `collect`, `dedupe`, `runs_of`, `signed_area`, `outward`, `bounds_of`, the overall, and
the actual `(start, end, offset)` triples that go to `add_dimension_linear`. It runs an
L-shaped 144" × 168" room (L-shaped so a winding or run-merge error cannot hide) under five
container transforms and checks the drawn endpoints against ground truth defined independently
as *T applied to the local polygon* — the room as it actually appears in the model.

Result (**observed**, `python .forge/fixer/transform_repro.py`, exit 0):

```
a identity                        old-on-room=True   new-on-room=True   new-lengths=True   identical=True
b translation                     old-on-room=False  new-on-room=True   new-lengths=True   identical=False
      worst old chain endpoint is 650.00" from any real room corner
c rotation 30                     old-on-room=False  new-on-room=True   new-lengths=True   identical=False
      overall  old 144.00 x 168.00   new 208.71 x 181.49   (real extent 208.71 x 181.49)
d scale 1.5x/0.75y                old-on-room=False  new-on-room=True   new-lengths=True   identical=False
      overall  old 144.00 x 168.00   new 216.00 x 126.00   (real extent 216.00 x 126.00)
e nested (move o rotate o move)   old-on-room=False  new-on-room=True   new-lengths=True   identical=False
```

Two things to read off it. The old code's chain landed **650 inches** — 54 feet — from the
room under a plain translation, which is the reported symptom reproduced. And case (a) reports
`identical=True`: under an identity transform the new code produces the byte-identical list of
dimension triples, which is the no-op guarantee for Benton's daily case, demonstrated rather
than asserted.

The derivation behind that no-op, independent of the harness: with `tr = IDENTITY`,
`position.transform(tr) == position`, `normal.transform(tr) == normal`, `area(tr) == area`, and
`bounds_of(runs)` over the untransformed outer loop is exactly `face.bounds` — a floor face's
extent *is* its outer loop's extent. Every changed expression reduces to the expression it
replaced.

## Scaling — a deliberate decision, not an accident

A scaled room group now dimensions to the **scaled, real-world size**: the 144" × 168" room
under a 1.5×/0.75× scale reads 216" × 126" (**observed**, case d). That is correct and it is
the only defensible answer — the drawing must state what the model actually measures, and
`add_dimension_linear` given two world points measures the world distance between them, so the
drawn entity and the console table agree by construction. `Face#area(tr)` scales the same way,
so the 100 sq in floor threshold is also applied to the real area.

Non-uniform scale is a modelling hazard in its own right (it scales wall thickness differently
on each axis), but that is a drawing problem for Benton to see, and reporting the true size is
how he sees it. Suppressing it would be the tool lying about the model.

Caveat, stated because it is the one place the math is approximate: `normal.transform(tr)` is
not the mathematically correct way to transform a *normal* under non-uniform scale (that needs
the inverse transpose). For axis-aligned scaling of a Z-facing floor it gives `(0, 0, sz)`,
still parallel to `Z_AXIS`, so the horizontal test is right; it would only misjudge under a
**shear**, which SketchUp's own UI cannot produce and only an API caller could
(**derived**, not tested).

## Residual limitations — not fixed, deliberately

1. **A rotated room's two "overall" dimensions are world axis extents, not the room's own
   length and width.** Case (c): a 144 × 168 room rotated 30° reports an overall of
   208.71 × 181.49. That is the honest axis-aligned extent of a rotated room and it is
   consistent with the geometry, but it is not the number a plan wants, and `closure` will
   correctly report every run as `skew` and refuse to claim the chain closes. The segment
   chain itself is exactly right in this case — it follows the real walls with correctly
   derived outward offsets. Dimensioning a rotated room *in its own axes* is a design decision
   (it needs the dimensions drawn in the group's space, or the overalls taken along the run
   directions), and it is Benton's call, not a bug fix.
2. **`doors_on` only scans top-level `model.entities`, non-recursively**
   (`scripts/auto-dimension.rb:240-247`, **observed**). `build-room.rb:320-327` puts its doors
   in a `Doors` group *inside* the room group (**observed**), so those doors have never been
   reachable by this test — before or after this change. This is a separate, pre-existing
   defect, unrelated to the transform bug and not introduced by it; it is left alone because
   fixing it means changing which entities the tool considers a door, which is a behaviour
   change with its own risk. Flagged for a follow-up.

## Verification status, plainly

- `python scripts/rbparse.py` — 34 files parse, unchanged from before (**observed**). This is
  a real CRuby 3.2 compile, not `rbcheck.py`'s bracket counter.
- `python .forge/fixer/transform_repro.py` — passes (**observed**).
- **Nothing has been run in SketchUp.** The Ruby is unexecuted. The arithmetic is proven; the
  API calls it makes (`Face#area(tr)`, `Vector3d#transform`, `Transformation#*`) are
  documented but unexercised on this machine (**reported**, from the API docs). The one worth
  watching on first run is `f.area(tr)` — if any shipped SketchUp version rejects the
  argument it would raise inside `floor_face`, which `ability_on` catches and reports as
  "Auto dimension failed", i.e. loudly rather than silently.
