# Fixer handoff — MDL 6060 E inner shell, 2026-08-26

## Produced

- `scripts/build-booth-components.rb` — two changes:
  - `self.iep_nominal_width(name)` (new), and `rebalance_walls`'s `pw_of` now prefers
    it over the packaged bounding box when there is no slab. **This is the root-cause
    fix** for the panel at booth y −7.875, and it also removes the 0.125 stretch on the
    W inner wall (the reported Defect 2).
  - `IEP_VENT_YAW = 180.0` and the block that applies it to inner vent panels, next to
    the existing seal and door yaw blocks. Benton's explicit instruction.
- `scripts/wr_tools/VERSION` — 1.6.20 → **1.6.21**.
- `DEVLOG.md` — 2026-08-26 entry.
- `.forge/fixer/replay-rebalance.py` — the reproduction harness. Python replay of
  `rebalance_walls` + `place()`'s along-wall arithmetic against the real layout data.
  `python .forge/fixer/replay-rebalance.py "MDL 6060 E"` prints both rules side by side.
- `.forge/fixer/ROOTCAUSE-6060E-2026-08-26.md` — the full write-up with the evidence.

Nothing committed. Tree left dirty for review.

## Read first

1. `.forge/fixer/ROOTCAUSE-6060E-2026-08-26.md` — the one-sentence cause, the
   reproduction table, and why the fix is in the Ruby and not in the generated data.
2. `.forge/fixer/PROBE-6060E-2026-08-26.md` — the prior probe analysis. Defects 1, 3 and
   5 stand. **Defects 2 and 4 do not** — 2 falls out of 1, and 4 was an arithmetic slip
   (it used the nominal 1.125 box where the probe's own RUN says 1.1563). Both re-derived
   in the root-cause note.
3. `.forge/GOAL.md` — mission reconfirmed: Enhanced booths closed model by model, each by
   a measured probe, no silent Standard fallback, no Standard regression. This change
   stays inside all four.

## Assumptions

- **`ENH` module widths are the names' numbers.** `ENH 35.5VNT` really is a 35.5 module
  in a 35.5 slot, with 0.250 of packaging. Derived from the layout polygons and from the
  Standard slab on the same wall agreeing; not measured on the part.
- **The vent flip does not move a bounding box.** Derived: the turn is about the slot
  polygon's centre and the room-proud block re-seats the box afterwards. Not observed.
- Harness box widths for `ENH 17.5PanelSolid` and `ENH 41.5Panel3236WDO` are **assumed**
  at the panel family's +0.125. They touch only the 7272/7296 "before" columns.
- The probe is taken to be the builder's raw output, not Benton's hand corrections —
  supported by all 16 positions matching the harness's replay of the unfixed code.

## Open questions

1. **Which way should an inner vent face?** `IEP_VENT_YAW` is applied globally, so it
   flips the 4872 E's `N0i` too, and no probe can see it. Benton's eye only.
2. **Room-proud for the 11.5 and 35.5 widths** — still `IEP_ROOM_PROUD_DEFAULT`, still
   warned. Expect ~1/8 out on both axes on `N0i` again until measured.
3. **`ENH 11.5PanelSolid` is 1.1563 thick in a 2.0 band.** It is pinned to the room face
   and leaves ~0.9 of air behind it. Correct, or should a thin box centre in its band?
4. **The 6060's IEP deck** — untouched. `ENH 6060FL/CL` do not exist; the tiling rule for
   6042 + 6018 SIDE L/R is still unanswered.

## What Benton should build and probe next

**The fix is UNRUN in SketchUp.** It has a real syntax check (`rbparse`, 52 files) and a
replay of the maths, and nothing more.

1. `git pull`, then `install-plugin.py` and restart (the VERSION bump is under
   `scripts/wr_tools/`, so the panel needs the installer; the tool scripts themselves are
   read live from the repo).
2. Build **MDL 6060 E, Shell = Inner (IEP) only**. In the console, check the rebalance
   lines say **`E inner wall closes +0.0000`** and **`W inner wall closes +0.0000`** and
   that no `*** ... does not close` line appears. If either still bails, stop there — the
   width table is wrong and nothing downstream is worth reading.
3. **Look at the four vent walls first.** That is the one change no measurement can check.
4. Correct the inner shell by hand and probe it. Expect the residual to be the two
   unmeasured room-prouds only — roughly 1/8 on `N0i`/`E1i` on both axes, and whatever the
   thin 11.5 wants across its wall.
5. **Also rebuild a 4872 E inner shell and eyeball its N vent**, because that is the one
   part of the closed booth this change can have moved.
