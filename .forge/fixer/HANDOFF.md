# Fixer handoff — list-scenes.rb row click / Shift-click (2026-09-21)

## Produced
- `scripts/list-scenes.rb` — dialog JS only (plus header comment + footer text):
  - Plain row click now ticks the row AND calls `sketchup.activate(n)`; the existing
    Ruby `activate` callback is untouched.
  - Shift-click ticks/unticks the run from the anchor (last plain-clicked row) to the
    clicked row across the CURRENT `view` order, to the anchor's ticked state; anchor
    stays put. No camera move on Shift-click (comment explains why).
  - Ctrl/Cmd-click ticks without navigating (one condition, no extra branch).
  - `mousedown` with Shift is `preventDefault`ed on the tbody so shift-drag never
    starts a text selection; the click handler also clears any live selection.
  - The `→` button is unchanged: activates without ticking.
- `scripts/wr_tools/VERSION` 1.72.0 -> 1.72.1.

## Read-first
- `scripts/list-scenes.rb` lines ~42-58 (behaviour contract) and the row `click`
  handler inside `draw()`.

## Assumptions
- "Same ticked state" for a Shift range = the anchor row's current state. Anchor
  ticked -> range ticks; anchor unticked -> range unticks.
- Anchor filtered out of view (or none yet) -> Shift-click degrades to a plain toggle
  and becomes the anchor, no navigation.

## Verified (real)
- `python scripts/rbparse.py` (CRuby 3.2): all 77 files ok, list-scenes.rb ok.
- Heredoc body extracted, `\`->`\` and `#{}` substituted, `<script>` body passed
  `node --check`.
- Shift-range index arithmetic copied verbatim into a Node assert script: 5 cases pass
  (extend down, re-size up from same anchor, untick range, anchor filtered out, no anchor).

## Open questions / not verified
- Not run inside SketchUp (no ruby.exe, no SketchUp here). Benton must click: plain
  row -> ticks + camera moves; Shift-click -> run ticks, camera does NOT move, no blue
  text; Ctrl-click -> ticks, no camera move; arrow -> camera moves, no tick.
- Whether `sketchup.activate` firing on every plain click feels too eager when
  ticking many rows one by one (Ctrl-click is the escape hatch).
