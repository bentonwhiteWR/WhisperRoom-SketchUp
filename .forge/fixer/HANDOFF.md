# Fixer handoff — "Dimension the room does nothing at all", 2026-08-15

## Produced

- `scripts/rbparse.py` — **a real Ruby syntax checker on this machine.** Drives the CRuby
  3.2 shared library SketchUp ships (`C:\Program Files\SketchUp\SketchUp 2024\x64-ucrt-ruby320.dll`)
  through ctypes and calls `RubyVM::InstructionSequence.compile`. All 34 `.rb` files in
  `scripts/` parse clean (observed). This supersedes `rbcheck.py` for syntax questions.
- `scripts/wr_tools/main.rb` — `toggle` now rescues `Exception`, not `StandardError`, so a
  SyntaxError in a loaded ability script raises a message box instead of vanishing. It also
  prints `ABILITY <id> — switching ON/OFF` to the console before doing anything.
- `scripts/auto-dimension.rb` — `tag()` forces a tag visible before drawing on it, and says
  so on the console when it had to.
- `scripts/rbcheck.py`, `CLAUDE.md` — docstring/rule updated to stop "rbcheck says balanced"
  being reported as "the file parses".

## Read first

- The leading hypothesis handed to me — a SyntaxError in `auto-dimension.rb` from commit
  `353d47c` — is **disproven**, not unconfirmed. Run `python scripts/rbparse.py` to see it.
  Do not spend time there again.
- The strongest surviving candidate is **not in my scope**: `scripts/wr_tools/panel.html`.
  An ability row (`abilityRow`, ~line 1090) is emitted with `data-ab` and never `data-i`,
  and `wire()` (~line 1287) attaches the run-on-click handler only to `.row[data-i]`. So the
  body of an ability row is completely inert — only the small switch at the far right does
  anything. Today's panel redesign (`14a31c4`) merged each ability script's action row into
  its ability row, so five scripts, "Dimension the room" among them, stopped responding to a
  click on their name. That is an exact match for "nothing at all happened" and it is a
  today-regression. Someone who owns `panel.html` should decide whether the row body should
  `run()` the script.

## Assumptions

- Benton flipped or clicked the row in the **panel**, not the menu or a toolbar slot. The
  menu and toolbar both go through `run()`, which already rescued `Exception` and shows a
  box, so neither could have been silent.
- The installed plugin at `%APPDATA%\SketchUp\SketchUp 2024\SketchUp\Plugins\wr_tools\` was
  byte-identical to the repo when I started (observed). **`main.rb` is NOT hot-reloaded** —
  my change to it does nothing until `install-plugin.py` runs and SketchUp restarts. I was
  told not to run it. `auto-dimension.rb` IS re-read on every toggle, so that half is live
  as soon as the file is saved.

## Open questions

1. Which was it — an inert row body, or dimensions drawn onto a hidden tag? Both produce the
   reported symptom and I could not separate them without the live app. The console
   breadcrumb added to `toggle` settles it in one look next time: if `ABILITY
   auto-dimension.rb — switching ON` appears in the Ruby Console, the click reached Ruby and
   the cause is downstream; if nothing appears, the click never left the panel.
2. `floor_face` reads `f.bounds` off faces that may live inside groups, so it mixes
   group-local and world Z when picking the lowest face, and `dimension_face` then draws
   into `model.entities` using group-local coordinates. On a room group with a non-identity
   transform the dimensions would land somewhere else entirely. Not touched — it is a
   separate defect and did not match the report ("drew the wrong thing" was offered and
   rejected). Worth a look.
3. `ability_off` has no rescue of its own and opens an operation inside `clear_dims`. It is
   covered by `toggle` now, but an aborted erase could leave an operation open.
