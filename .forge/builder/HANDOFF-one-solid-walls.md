# HANDOFF — one solid per wall (plugin 1.12.8)

## Produced
- `scripts/build-room.rb` — `band` replaced by `span` (one solid per
  `(z0, z1)`, untagged so it inherits the `Walls` container's `WR-Room`);
  `wall_run` lost its `sill` and `upper_tag` parameters; `DEFAULT_SILL`,
  `cfg['sill']`, the `WR-Room-Upper` tag creation and the two-band report
  lines are gone. The long header section that documented the two-band
  design is rewritten to describe one-solid walls and to say what replaced
  the banding and why.
- `scripts/build-room.html` — both "Wall split (sill)" fields (simple and
  detail panes), their sync handlers and the `sill` key in the build payload
  removed. `S` no longer carries `sill`.
- `scripts/build-takeoff.rb` — no `WR-Room-Upper` tag, no room-level
  `sill_in`, `wall_run` called with the new signature. The **window**
  `sill_in` on a feature is a different number and is untouched.
- `scripts/wr-split-walls.rb` — kept, marked **SUPERSEDED** in the header
  and in its panel title (`@title Split existing walls at sill (LEGACY,
  EDITS MODEL)...`). Not deleted: it is the only tool that can put a model
  back into the old shape.
- `scripts/wr-lower-walls.rb`, `scripts/wr-scene-walls.rb`,
  `scripts/wr-drop-lights.rb` — comment-only updates so they describe
  `WR-Room-Upper` as legacy. `wr-drop-lights.rb` KEEPS the tag in
  `ROOM_CHILD_TAGS`; a legacy model's upper bands must still read as room
  structure and never as an obstruction.
- `scripts/wr_tools/VERSION` — 1.12.8. `DEVLOG.md` — the 1.12.8 entry.
- `eval/RESULTS.md` — 24 recorded rows, timestamp `2026-08-31 21:03`.

## Read first
- `scripts/build-room.rb` header (lines ~43–68) — it now carries the whole
  rationale for removing the split and names the two tools that replaced it.
- `eval/RESULTS.md` — the 21:03 block is the regression evidence.

## Assumptions
- Existing banded models are left untouched, deliberately. A banded model
  renders as it always did; `wr-scene-walls.rb` matches `Wall 3 (upper)`
  through its `PIECE_RE`, so whole-wall scene hiding already covers them.
  **Recommendation: build no unsplit tool unless Benton asks.** Merging two
  solids back into one is a riskier operation than the split was, and there
  is nothing it would fix.
- `scripts/takeoff-check.py` still accepts a room-level `sill` and still
  defaults it in `HOUSE`. That is now a dead field: `build-takeoff.rb`
  ignores it. It is owned by another Builder — **route it**, do not edit it
  here. Same for `reference/takeoff-format.md` if it documents room `sill`.
  Note also `scripts/takeoff-check.py:1269`, which draws a window feature's
  sill falling back to `room.sill_in` — that conflates the window sill with
  the retired wall-band sill and should stop falling back.

## Open questions
- `eval/floorplans/synthetic-headroom/README.md` is stale. It records the
  case as a PROBE with two silent defects; the checks have since landed and
  the case now refuses by name (`door 0 is taller than its ceiling`,
  `bulkhead 1 has its head at or above the ceiling`). Verified this is not
  caused by the 1.12.8 change — the identical refusal fires with these edits
  stashed. The README itself says to flip the case to
  `expects: {"refusal": [...]}` when the checks land. Left alone: `eval/`
  was out of bounds for this task.
