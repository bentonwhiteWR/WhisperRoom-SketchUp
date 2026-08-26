# HANDOFF — 2026-08-26, end of day

## Read this first

Plugin **1.6.29**. Tree clean, everything on `main`. The full story is the 2026-08-26
`SESSION CLOSE` block of `DEVLOG.md`; this is the short version.

**Nine versions shipped today.** The Enhanced inner shell now rebalances from module widths,
tiles its deck across all 25 layouts with nothing left to author, seats tray tiles by their outer
edge, measures tray orientation per part, places floor seam seals at a measured datum, and keys
the wall lift per booth. `angled-component-art.rb` writes `_dimensions.json` for the Prism Gauge.

**Two things were retracted, and the reasons matter more than the retractions:**

1. `IEP_VENT_YAW` was flipped to 0 on a report made against **pre-1.6.21 code still in memory**.
   A Ruby module keeps its constants until SketchUp restarts. Before treating an observation as
   evidence about a constant, establish the process was restarted after that constant shipped.
2. The side-wall "108 reversed walls" was **false**. The witness file was a 2026-08-07 snapshot
   of the artifact under test. Never check an artifact against a copy of itself. Both circular
   harnesses are deleted; `.forge/fixer/replay-portal-wallrun.js` now *executes* the portal's own
   `wallPanelRun()` instead of restating it.

## Next: reinstall, then one SketchUp pass

1. `git pull` → `python scripts/install-plugin.py` → **RESTART SketchUp.** VERSION lives under
   `wr_tools/`; a rescan will not do it.
2. **`scripts/probe-levels.rb` on `P:/Sketchup/NewMasterComponentList` with an EMPTY filter.**
   `_face-levels.tsv` has zero `ENH` rows, which is why the IEP tray abstains. Cheapest unblock.
3. Build **`MDL 4872 E`, Shell = Both** — must read `0.75" - MEASURED ON THIS BOOTH`, unchanged.
4. Build **`MDL 9696 E`** — must read `DEFAULT - NOT MEASURED ON THIS BOOTH`. If its IEP shell is
   1/16 low, the wall-lift default belongs at 0.6875.
5. First real `_dimensions.json`: load `angled-component-art.rb`, **ENH Extra batch**,
   **Dry run = Yes** (renders nothing) → then `node scripts/prism-audit.js --html` from
   `WhisperRoomQuote`.

## The one question that needs a real booth

**Stated without reference to the door, because the door is customer-placed:** on a 102144,
measured against the **floor and ceiling hinge slots**, does the window sit at the same end as
the hinge slots or the opposite end? And is it fixed by the model at all, or does the assembler
put it where the customer asks? The wall is 40/16/40 — symmetric — so nothing on disk can settle
it. Same question for the 96144.

## Held, not forgotten

- The **four-booth big-run flip** (6060/6084/7272/7296) — written up in
  `.forge/fixer/ROOTCAUSE-side-wall-order-2026-08-26.md`, unshipped, moves `MDL 6060 E`.
- **Do not re-extract** the portal's `booth-iso-geometry.json` until that is settled.
- Room-proud for **11.5 / 26.5 / 35.5** still unmeasured, still warns by name.
- The **width-axis family split** — a different defect from the window position.
