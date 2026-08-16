# Fixer handoff — auto-dimension container transforms

## Produced
- `scripts/auto-dimension.rb` — fixed. `collect` threads a `Geom::Transformation` down the
  recursion and stores `[face, tr]` pairs; `floor_face` returns a pair and filters on world
  normal/area/z; new `world_z` and `bounds_of` helpers; `runs_of(face, tr)` transforms each
  vertex; `dimension_face(face, opts)` reads `opts[:transform]` (default identity) and takes
  the overall from `bounds_of(runs)` instead of `face.bounds`; both entry points destructure
  the pair.
- `.forge/fixer/root-cause-transform.md` — the confirmation, the API citations, the
  derivation, the residual limitations, and the verification status.
- `.forge/fixer/transform_repro.py` — re-runnable proof. `python .forge/fixer/transform_repro.py`,
  exit 0 = pass. Fails loudly if the identity case ever stops being a no-op.
- `DEVLOG.md` — entry dated 2026-08-16.

## Read first
`.forge/fixer/root-cause-transform.md`. It carries the two residual limitations, which are
the only live decisions left here.

## Assumptions
- `Sketchup::Face#area(transform)` is accepted by every SketchUp version Benton runs
  (documented in the official API; unexercised on this machine). If it were not, it would
  raise inside `floor_face` and surface as a visible "Auto dimension failed" dialog, not a
  silent wrong drawing.
- `Geom::Transformation#*` composes parent-then-child in the conventional column-vector
  order. Derived from the documented `transformation * point` behaviour and corroborated by
  three sibling scripts in `scripts/` that already rely on it.
- `normal.transform(tr)` is used to test horizontality. Exact for rotation, translation and
  axis-aligned scale; it would misjudge only under a shear, which the SketchUp UI cannot
  produce.
- Nothing in this change has been executed in SketchUp. The arithmetic is proven in Python;
  the Ruby is unrun.

## Open questions (for Benton, via the orchestrator)
1. **A rotated room's overalls.** Right now the two overall dimensions are the world
   axis-aligned extent of the rotated room (a 12' × 14' room at 30° reads 17'-4.7" ×
   15'-1.5"), which is geometrically true but is not the room's own length and width. The
   segment chain is correct either way and `closure` correctly reports the runs as skew and
   refuses to certify closure. Should a rotated room instead be dimensioned in its own axes?
   That changes what the plate shows, so it is not a call to make silently.
2. **Doors inside the room group are never dimensioned.** `doors_on` scans only top-level
   `model.entities`, and `build-room.rb` puts its doors in a `Doors` group inside the room
   group — so the door dimensions have never appeared on a build-room room, before or after
   this fix. Worth a follow-up pass; it needs a decision on whether a door nested anywhere in
   the model counts, or only one nested under the room being dimensioned.
