# The window is at the WRONG END of its wall — MDL 102144 E

Benton, 2026-08-26 on v1.6.29: *"windows still in wrong place"*, with a portal render and a
SketchUp render **at comparable viewing angles, both showing the door on the same face.** The
door anchors the comparison, so this is not a left/right inference off a mirrored render.

## The observation, stated without any left/right claim

In **both** images the wide-access door is on the face toward the viewer's right, near the
front corner. Relative to that door:

- **Portal:** the window sits at the end of its wall **ADJACENT to the door corner.**
- **SketchUp:** the window sits at the end of its wall **FARTHEST from the door corner.**

A small dark fitting low on the same wall has swapped ends with it. So **the W wall's panel run
is reversed** relative to what the portal draws. This is an ORDER problem, not a facing problem.

## This CONTRADICTS the earlier harness result, and the harness is what must be wrong

`.forge/fixer/replay-side-wall-order.py` reported **200 walls, 0 mirrored** — slot 0 on the same
physical end in `wr-booth-data.rb` and the portal's `booth-layouts.json`, across all 25 `E`
layouts. **The pictures win.** Find the flaw in the comparison rather than re-running it and
believing it again.

**A concrete hypothesis to test first**, from the data already on disk:

- RAW PACK (`.forge/fixer/CONSOLE-102144E-2026-08-26.md`): `W0 = 40Panel2636WDO`, and the
  portal's own summary line says **`Window  Left (W0)`**. So both sides agree the window is W0.
- The 102144 E layout puts **`W0i` at the HIGH y end** (the harness printed
  `W0i ... 64.250..99.750`, `W1i 46.250..57.750`, `W2i 4.250..39.750`).
- The **door is on S, the LOW y end**.
- Therefore the builder places W0 **away from the door** — which is what SketchUp shows — while
  the portal draws index 0 **at the door end**.

If that holds, the disagreement is about **where index 0 starts on the W wall**, and the harness
either compared a field that does not carry that, or applied the portal's
*"aIn grows DOWNWARD → high aIn is the S end"* rule with the wrong sign on this wall. Check the
E wall too: E and W may not walk the same way, and a bug that cancels on one wall would explain
a clean 200/200.

## Do not repeat these two mistakes

1. **`FACING` is the thickness sense; `RUNS` is the width axis.** Neither is panel ORDER. An
   earlier round conflated `FACING` with the width-axis family and drew a wrong conclusion
   (see `.forge/fixer/PROBE-COMPONENT-FILES-2026-08-26.md`).
2. The width-axis family split IS real and measured — `40Panel2636WDO` runs X while
   `16PanelSolid` and `40PanelSolid` run Y — but **that is a separate defect from this one.**
   It would turn a panel end-for-end in place; it would not move it to the other end of the
   wall. Do not let one fix mask the other. Say which of the two you are fixing.

## Blast radius

`40Panel2636WDO` is the **outer** Standard panel. Benton, asked whether Standard builds these
side walls correctly: *"No neither 96144 or 102144 have the correct side wall positions from the
link."* **If the fix moves shared Standard geometry, stop and report before shipping** — that
path is live and real customer drawings depend on it.

## What would settle it beyond doubt

The two share links, and the portal's `booth-layouts.json` entry for `102144` read directly
rather than through the harness's parse.
