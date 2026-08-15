# Builder handoff — build-room: simple length/width first, take-off behind "More detail"

## Produced

- `scripts/build-room.html` — rewritten dialog. Two panes over **one** state object
  (`S = {len, wid, ceil, thick, name}` plus `runs` / `doors`, all in inches):
  - **Simple** (default): length, width, ceiling only, plus the house-default note on
    ceiling. Build works on open. No doors, no wall thickness, no room name.
  - **Detail**: the take-off exactly as before — runs table, doors table, wall
    thickness, ceiling, room name, closure card, SVG preview.
  - A shared dimension parser (`parseLen`) now backs **every** dimension field in both
    panes, so `150`, `150"`, `12'6"`, `12'-6"`, `12' 6 1/2"`, `12.5'`, `12 1/2`, `12ft 6in`
    and `12′6″` all parse. **A bare number is inches**, which is what the take-off has
    always meant. An unparseable field keeps its last good value, turns red, and disables
    Build rather than becoming a silent zero.
  - `rect(len, wid)` produces the four runs the take-off would have produced. Simple mode
    keeps `runs` in sync at every keystroke, so expanding needs no carry-over step and the
    two modes cannot use different geometry code.
  - Collapse (`#toless`) is enabled only while `asRect()` succeeds **and** there are no
    doors; otherwise the button is disabled and its label says which condition failed. No
    silent geometry loss.
- `scripts/build-room.rb` — header comment rewritten to argue the new shape (same voice);
  `@title` renamed to `Draw floor plan...` (trailing `...` kept — the panel's
  dialog-glyph convention); `PREF` constant; `last_mode` / `remember_mode` using
  `Sketchup.read_default` / `write_default`; a `ready` action callback that calls
  `WR_setMode(...)` so the last-used mode is restored; the `build` callback records the
  mode before building. `dialog_title` is now `Draw floor plan`.
  **The build path itself is untouched** — `polygon`, `mitre`, `wall_run`, `door`, the
  auto-dimension hand-off and the 8'-0" house-default text annotation are byte-identical.
- `.forge/builder/build-room-uitest.py` — generates a headless-Chrome test page from the
  live `build-room.html` and runs 70 assertions against the real DOM. Run it with:
  `python .forge/builder/build-room-uitest.py` then
  `chrome --headless=new --dump-dom file:///<the printed path>` and read `<pre id="OUT">`.

## Read first

1. The header comment block at the top of `scripts/build-room.rb` — it now records why
   simple mode reuses the take-off's runs instead of having its own geometry routine, and
   why collapsing is conditional.
2. `parseLen` in `scripts/build-room.html` — the bare-number-is-inches rule is the one
   decision that would break both modes if it were changed in only one place.
3. `.forge/builder/build-room-uitest.py` — the closure, carry-over and collapse-guard
   claims are all asserted there; extend it rather than eyeballing.

## Assumptions

- **assumed** — `Sketchup.read_default` / `write_default` persist across SketchUp sessions
  for an arbitrary key. This is standard SketchUp API behaviour but is not verified here,
  because it needs SketchUp. Both calls are wrapped in `rescue StandardError`, so a
  failure degrades to "always opens simple" rather than breaking the dialog.
- **assumed** — `HtmlDialog#execute_script` reaches the page by the time the `ready`
  callback fires. Same reason; if it does not, the dialog stays in simple mode, which is
  the intended default anyway.
- **derived** — the detail pane's default door list is now empty (was one demo door on run
  0). Simple mode has no doors, so inheriting a phantom door on expand would be a
  surprise. Flagged to Benton.
- **derived** — the demo L-shaped take-off that used to be the startup state is gone;
  detail mode now opens on the rectangle carried across from simple.

## Open questions

- Wall thickness default: confirmed **4"** (Benton via coordinator, Aug 2026). This is
  what the file already used, so the default did not actually change.
- Should simple mode offer a room name? Currently it always sends `"Room"`. Cheap to add
  if Benton wants it.
- Should simple mode offer a door? Deliberately not, per the brief. One field plus a
  "which wall" picker would cover it if asked.
