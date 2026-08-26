# FIXER HANDOFF — side-wall flip, 96144 E / 102144 E — 2026-08-26

## Produced

- `.forge/fixer/replay-side-wall-order.py` — offline harness. Diffs
  `scripts/wr-booth-data.rb` against `WhisperRoomQuote/lib/pl-data/booth-layouts.json`
  per model / per shell / per wall: slot ids, along-wall extents, default component,
  which Enhanced half-turn rule fires, AGREE/MIRRORED, and whether the portal's own
  big-run-at-the-door-end flip fires. Takes model keys as argv; defaults to the four
  `96144`/`102144` S+E keys.
- `.forge/fixer/side-wall-order-all-E.txt` — its output over all 25 `E` layouts.
- `.forge/fixer/DEFECT-side-wall-flip-2026-08-26.md` — rewritten with the findings,
  the two surviving hypotheses, the blast-radius answer, and the exact ask for Benton.

## No code changed

`scripts/wr_tools/VERSION` stays **1.6.26**. No `.rb` edited, no `DEVLOG.md` entry (the
DEVLOG records shipped changes; nothing shipped). `python scripts/rbparse.py` — **52/52
parse** (run 2026-08-26; the tree is as it was).

## Read first

1. `.forge/fixer/DEFECT-side-wall-flip-2026-08-26.md` — the whole finding.
2. `scripts/build-booth-components.rb` lines **19-40** (the "two families, no flag to tell
   them apart" measurement — this is the load-bearing quote), **1224-1245** (`rotation`,
   where the family handedness turns into an along-wall direction), **1272-1284**
   (`FACE_OUT` / `REVERSED` and their warning), **166-195** (`IEP_VENT_YAW` and the
   unrestarted-SketchUp lesson), **2016-2027** (where the vent half turn is applied and
   the window is not).
3. `WhisperRoomQuote/assets/layout-render.js` `wallPanelRun()` — the portal's slot-order
   and big-run-flip conventions, in its own words.

## Assumptions

- **assumed** — that Benton's "flipped" is a 180° yaw of individual panels, not a swap of
  which wall is which. Rests on: the slot mapping being provably un-mirrored, and no other
  mechanism in the code being able to mirror a run. Not proven against a build.
- **assumed** — that the portal's SVG plan order is what Benton compared against. He
  supplied a portal 3D view; the two are drawn from the same `booth-layouts.json` slots.
- **derived** — the `EVEN`/handedness arithmetic putting the WDO+VNT family and the
  panel/door/seal family on opposite along-wall width directions. Derived from the source,
  using the header's own measurement of which axis is width per family. The ENH library's
  axes have **never been measured**; the header's figure covers 182 Standard parts only.

## Open questions

1. Which shell's window is flipped — outer (Standard, shared code, big blast radius) or
   inner (IEP, safe to fix)? **Decides whether anything may be touched at all.**
2. Is the half turn a property of the X-width authoring family (→ windows need it too), or
   of the ENH family / the global convention (→ `IEP_VENT_YAW` is itself the wrong shape of
   fix)? A `Probe Component Files` run answers it.
3. Does a **Standard** 96144 / 102144 build its side walls correctly today? Still unasked-
   and-unanswered from the first pass.
4. Should the `ASSIGN` E/W swap be applied on the share-link path for
   6060/6084/7272/7296? It is a real live mirror on the customer path — Standard and
   Enhanced both — and the fix lands in shared Standard code, so it is a decision, not a
   patch.
