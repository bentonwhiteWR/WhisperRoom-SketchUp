# FIXER HANDOFF — side-wall panel ORDER, 2026-08-26

## Produced
- `.forge/fixer/ROOTCAUSE-side-wall-order-2026-08-26.md` — the full diagnosis, the exact
  four-line fix, blast radius, and the regression table. **Read this one.**
- `.forge/fixer/replay-side-wall-order.py` — **rewritten.** The old verdict was circular and
  reported 200/200 clean on a broken model. It now compares against an independent witness
  (`booth-iso-geometry.json`, the pre-flip extract) and fails loudly:
  `--all --summary` → `300 walls checked: 108 REVERSED`, exit 1.

**Nothing under `scripts/` was changed. `VERSION` is untouched at 1.6.29. Nothing committed.**

## Read first
1. `.forge/fixer/ROOTCAUSE-side-wall-order-2026-08-26.md`
2. `scripts/gen-booth.py` lines **259, 268-269, 411, 423-424** — the four flip sites.
3. `reference/seam-seal-attachment.md:317` — the hinge-slot evidence that E/W slot 0 belongs
   at the door end.
4. `WhisperRoomQuote/assets/layout-render.js:156-278` (`wallPanelRun`) — **read only.**

## The answer in one line
`scripts/gen-booth.py` was changed on 2026-08-11 to walk E/W walls N→S to match the portal's
*drawing* order; the regenerated `scripts/wr-booth-data.rb` landed in commit `92dc59b`, and it
puts slot 0 (the window) at the far end of the side wall from the door on 18 of the 25 models.

## Assumptions
- The **pre-flip** order is the correct one. Rests on the hinge-slot evidence (measured on
  4 models only), the portal's angled view, and Benton's render comparison. **Derived, not
  measured, on the other 14 models.**
- All 25 doors are on `S` (observed), so "walk E/W from low y" == "slot 0 at the door end".
  A future N-door model would need the door-anchored form instead.
- `booth-iso-geometry.json` has not been regenerated since 2026-08-07 (its own `generated`
  stamp says so), so it is a genuine independent snapshot and not a copy of today's data.

## Open questions for Benton
1. **Confirm the door-end rule on a 3-slot side wall.** The hinge-slot evidence covers only
   6060/6084/7272/7296. On a real 102144 or 102186, is slot 0 at the door end?
2. **The portal's own 2D top-down plan is wrong the same way** on the 14 models the
   `wallPanelRun()` flip cannot detect. After the SketchUp fix, SketchUp and the portal's
   angled view will agree and the portal's 2D plan will be the odd one out. That is a
   `WhisperRoomQuote` change and I did not touch that repo.
3. **Drawings already sent to customers.** Every Standard booth with a side-wall window built
   since 2026-08-11 has it at the wrong end. Whether any go back out is Benton's call.
4. **The width-axis family split is still open and untouched** — `40Panel2636WDO` runs X while
   `16PanelSolid` / `40PanelSolid` run Y. Separate defect, turns a panel end-for-end in place.
   Do not let the order fix be read as closing it.
