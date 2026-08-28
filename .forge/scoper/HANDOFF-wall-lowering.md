# HANDOFF — Scoper, scene wall-lowering (2026-08-27)

## Produced

- `.forge/scoper/scene-wall-lowering.md` — the findings, four options with revert
  stories, and the recommendation: **no new code**. The mechanism Benton asked about
  already exists — `build-room.rb`'s two-band walls plus the `WR-Room-Upper` tag,
  `wr-split-walls.rb` as the retrofit for existing models, and per-scene tag
  visibility that `proposal-package.rb` already honors by activating each page before
  export/render. The deliverable includes the three-step per-scene workflow, a
  per-wall hidden-object escape hatch, and a deliberately deferred ~60-line v2 helper
  sketch (`scripts/scene-lower-walls.rb`) to build only if the manual scene-update
  step proves error-prone.
- **No mockup** — there is no UI to settle; making one would have implied a build
  this scoping argues against.
- This file. `.forge/scoper/HANDOFF.md` (proposal package) is untouched.

## Read-first

- `.forge/scoper/scene-wall-lowering.md` (the deliverable).
- `scripts/build-room.rb` — file header + `band()`: the two-band split and its own
  statement that hiding `WR-Room-Upper` "lowers" walls with nothing to put back.
- `scripts/wr-split-walls.rb` — the one-time retrofit; dry-run default, skip-and-name
  recognizer scoped to build-room-shaped walls.
- `.forge/builder/HANDOFF-c.md` — provenance of the two-band work, including that
  none of it has ever run in SketchUp.
- `scripts/proposal-package.rb` (~line 495) and `scripts/export-scenes.rb`
  (~lines 170–191) — both lanes activate the scene before capture, which is why the
  proposal package needs no change.
- `scripts/proposal-scenes.rb` (~line 221, `use_hidden_layers = true`; DIM_TAGS
  ~line 51) — the repo's reliance on Page-persisted tag visibility, and proof
  `WR_Mode` never touches `WR-Room-Upper`.

## Assumptions

- **V-Ray omits geometry on tags a scene hides** (assumed — V-Ray renders the
  visible viewport; every V-Ray behaviour in this repo is reported-not-observed).
  Gate: one manual render of a lowered-wall scene during the proposal-package
  acceptance run.
- SketchUp's Scenes-tray update dialog lets you update only *Visible Tags* without
  re-saving the camera, and pages persist hidden-object state for the per-wall hatch
  (both reported — standard product behaviour, not exercised in this repo).
- `Page#update(flags)` with a layer-visibility flag exists for the deferred helper
  (reported — verify against the live API before ever building it).
- Benton's manual "lower" lands near the 48" sill default (assumed — his simulation
  image never arrived; what to check in it is listed in the deliverable).

## Open-questions

1. Does a V-Ray render of a scene with `WR-Room-Upper` hidden actually drop those
   walls? (First live run answers it.)
2. Is 4'-0" the right lowered height, and is it fixed across jobs or per room?
   Note: changing the sill on an already-split model means rebuilding or hand-moving
   the cut — the splitter cannot re-split.
3. All host walls lowered vs only the wall behind the booth — decides whether the
   per-group hidden-object hatch matters early.
4. Old client models (`csusb-rooms.rb`, hand-drawn) fall outside the splitter's
   recognizer by design — regroup by hand or accept full-height walls there. Is that
   acceptable for the models Benton actually re-renders?
5. The two-band wall code itself has never been seen on screen; this recommendation
   inherits that unverified base.
