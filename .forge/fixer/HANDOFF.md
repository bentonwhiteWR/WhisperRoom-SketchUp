# Fixer HANDOFF — the door swing arc drew on the wrong side (2026-08-31)

Goal reconfirmed against `.forge/GOAL.md` before writing this: the mission is
the floor-plan intake pipeline, and this is a defect in what that pipeline
draws — `scripts/build-takeoff.rb` calls the same `WR_BuildRoom.door`, so
every take-off room built since the winding convention landed had its swings
backwards. The **Untitled-model rule** was enforced in code on every live job.
Plugin `scripts/wr_tools/VERSION` 1.12.9 → **1.12.10**.

## Produced

| file | what |
|---|---|
| `scripts/build-room.rb` | The fix, in `self.door`. The arc's sweep sign now comes from the leaf's own tip (`cz = vec.x*tipv.y - vec.y*tipv.x`) instead of the hinge side, so the arc ends at the leaf tip by construction, for both windings and both hinge sides. |
| `scripts/rbtest-doorswing.py` | New offline reproduction and regression test. Lifts `signed_area`, `outward` and `door` verbatim from `build-room.rb`, runs them on a stubbed Geom, 18 assertions over 2 windings x 2 hinge sides. Mutation-checked: restore the old sign and the 4 clockwise assertions fail. |
| `.forge/fixer/door-swing-arc.md` | Symptom, root cause, how to re-trigger it, blast radius. |
| `DEVLOG.md`, `scripts/wr_tools/VERSION` | 1.12.10. |

## Read-first

1. `.forge/fixer/door-swing-arc.md` — the whole thing in one page.
2. The comment above the arc block in `scripts/build-room.rb` `self.door`. It
   says why a flipped sign was the wrong fix.

## Assumptions

- **observed:** the bug is winding-dependent, not hinge-dependent. Both
  clockwise cases fail and both counter-clockwise cases pass on the old code
  (`python scripts/rbtest-doorswing.py` on the pre-fix file, 4 failures).
- **observed:** nothing else in the tree draws a swing arc from a fixed sign.
  `scripts/takeoff-check.py`'s plan SVG and 3D review view draw the opening
  but neither leaf nor arc; `scripts/auto-dimension.rb` and
  `scripts/wr-overlays.rb` draw neither; `scripts/csusb-rooms.rb`,
  `scripts/csusb-106.rb` and `scripts/dowaly-kuwait-tv.rb` carry an explicit
  measured `:swing => :in/:out` per door.
- **observed:** the scratch model was left exactly as found — 172 entities and
  the same ten pre-existing eval groups, read back after the last job.
- **reported, not verified:** those ten groups are somebody else's debris. I
  did not touch them.

## Open questions

1. **Existing SketchUp files already carry wrong arcs.** Anything built before
   1.12.10 has its swings outside the wall and rebuilding is the only fix
   shipped here. A retrofit tool that finds `Swing n` groups on `WR-Doors-Leaf`
   and re-draws them against their leaf would close that; nobody asked for one.
2. **The eval suite still has not been built and scored since the 1.12.9
   format change** — the gap the Builder flagged. I did not close it: the
   active model flipped to Benton's `Master Component List.skp` repeatedly
   while I worked (my guard refused three separate jobs), and a 26-case suite
   needs a longer clear window than I had. The commands are in
   `.forge/builder/HANDOFF.md` and they are still the right ones.
3. Model safety, learned the hard way and worth carrying: do build, photograph
   and erase in **one** Ruby job. Three jobs was tried first and the model
   changed between the shot and the cleanup, which shot the wrong window and
   left eight entities behind.
