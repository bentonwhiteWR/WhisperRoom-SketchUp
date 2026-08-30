# Builder HANDOFF — SketchUp bridge (2026-08-30)

Goal reconfirmed against `.forge/GOAL.md` before writing this: the Mission and all
five Done-means are met, and Benton's four decisions were applied as overrides to
the spec. No divergence to flag. Plugin shipped at **1.9.0**.

## Produced

- `scripts/wr_tools/wr_bridge.rb` — the resident listener. New. Costs
  `install-plugin.py` + a SketchUp restart to change.
- `scripts/wr_tools/main.rb` — edited: a guarded `load` of the bridge and its two
  menu items in `build_ui`, and `wr-bridge-lib.rb` added to `SKIP`.
- `scripts/wr_tools/VERSION` — 1.8.0 -> **1.9.0**.
- `scripts/wr-bridge-lib.rb` — job-side helpers, read LIVE from the repo. New.
  This is where test logic belongs; editing it needs no reinstall.
- `scripts/sketchup-bridge.py` — the client, and an importable `submit()`. New.
- `.forge/scoper/sketchup-bridge.md` — edited, not rewritten: A4 and A10 record
  what the live runs settled, and A11 is restated for Benton's decision 3.
- `DEVLOG.md` — the 1.9.0 entry, with the real output.
- `scripts/install-plugin.py` — **unchanged**, as the spec predicted. Confirmed by
  running it and finding `wr_bridge.rb` and `VERSION` 1.9.0 in both plugin folders.

## Read first

1. `scripts/wr_tools/wr_bridge.rb`'s header — the protocol, the three properties
   every decision serves, and the honest limit of the fence.
2. `scripts/sketchup-bridge.py`'s docstring — the exit codes, which are the point
   of the tool; then `diagnose()` and the `MODAL_KEEPS_TIMERS` note above it.
3. `DEVLOG.md`, the 1.9.0 entry — what A4 and A10 actually settled.
4. `scripts/wr-bridge-lib.rb` — `WRB.check`/`WRB.verdict` are the shape a
   converted checklist should take.

## How to use it in one line

    python scripts/sketchup-bridge.py ping
    python scripts/sketchup-bridge.py eval "Sketchup.active_model.entities.length"

Off by default. `enable` writes the marker; the listener reads it **at load**, so
a marker written while SketchUp is shut means the bridge is live the moment it
next starts — no human clicks anything. Mid-session, Extensions > WhisperRoom >
Bridge: enable.

## Assumptions

- **observed:** all twelve acceptance criteria pass live against SketchUp 2026
  (26.2.243, Ruby 3.2.2, plugin 1.9.0). Every claim in the DEVLOG entry is from a
  run whose output is quoted there.
- **observed:** `UI.start_timer` keeps firing while a native modal is up
  (heartbeat never aged past 0.08 s across 11 s). The spec assumed the opposite.
  The diagnosis table is inverted from the spec accordingly, and both directions
  were run. `MODAL_KEEPS_TIMERS` in the client records it.
- **observed:** SketchUp's console honours the `$stdout` swap, including
  SketchUp's own API-side deprecation warnings.
- **observed:** plugins do not finish loading while the Welcome screen is up. The
  listener started only once a model was opened, ~4 minutes after process start.
- **assumed, NOT verified:** everything above was measured on **SketchUp 2026
  only**. 2024 has the plugin installed and the same code, but its bridge was
  never enabled and no job has ever run there. A9 used 2024 precisely as the
  "nothing listening" case. If 2024 is ever wanted, enable it and re-run A1-A12
  rather than assuming they carry over — `Sketchup.version.to_i` mapping to the
  root name is the one thing that would differ, and it is untested there.
- **assumed:** the fence covers the SketchUp APIs a job realistically uses. It is
  a guardrail against accident, not a sandbox, and does not cover a bare
  `File.write`. Said plainly in `wr_bridge.rb`'s header; do not let a later
  reading promote it to a security boundary.

## Open questions — for Benton, none blocking

1. **`build-room.rb`, `build-booth.rb` and `csusb-rooms.rb` do not honour the
   autorun-suppression globals** — their last line runs unconditionally, so
   loading them opens a dialog or builds geometry. `explode-view.rb` and
   `auto-dimension.rb` do guard. `WRB.tool` muzzles `UI::HtmlDialog#show` during
   the load to work round it, which is a workaround, not a fix. Should the three
   scripts get the `unless $wr_no_autorun` guard the other two have? It is a
   one-line change each, but it changes how they behave when run from the panel,
   so it was left alone.
2. **A named scratch file was left at `%TEMP%\wr-bridge-a11.skp`** by the A11
   fence test, and the open model is currently that file rather than Untitled.
   Harmless and deletable; mentioned only so it is not a surprise.
3. **The 256 KB per-stream capture cap** is enough for every checklist in sight —
   A12's 2 MB job truncated cleanly with a byte count in the text. Raise it if a
   real job ever needs more; it is one constant in `wr_bridge.rb`.
4. **2024 is installed and untested** (see Assumptions). Leave it off, or enable
   and re-run the criteria — but not assume.

## Blockers

None. The bridge is live and enabled on SketchUp 2026 right now.
