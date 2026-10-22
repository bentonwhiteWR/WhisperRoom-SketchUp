STATUS: READY 3d33cfa

# 1.85.0: bridge safe with two SketchUp files open

## Produced

Code commit `3d33cfa` on main:
- `scripts/wr_tools/wr_bridge.rb`: per-process slot `inst-<pid>/` (alive, model.json, stopped, in/ run/ out/), `target_refusal` guard before any job code, shared-inbox serving for old clients only while alone, peer-slot sweep after 24 h. Header documents the layout.
- `scripts/sketchup-bridge.py`: slot survey (states listening / busy / stalled / stopped / gone; liveness from a Windows pid check, never from heartbeat alone), `--model`, `submit(model=)`, `WR_BRIDGE_MODEL`, `resolve()`, `ping` lists slots and sweeps exited ones. Docstring documents the usage.
- `scripts/rbtest-bridge-slots.py`: new, pure tests (36 checks).
- `scripts/wr_tools/VERSION` 1.84.7 -> 1.85.0. `DEVLOG.md` entry. A short `--model` note in `skills/whisperroom-acoustic-package/SKILL.md`, `skills/whisperroom-photo-job/SKILL.md` and `skills/whisperroom-client-job/reference/render-recipe.md`.

Done-means, with evidence:
1. **Each process polls its own slot; two files never race.** Code is in place. The listener only globs `inst-<pid>/in` plus the shared inbox, and the shared inbox refuses untargeted jobs when a peer is live. Parsed by `python scripts/rbparse.py` (all 82 files ok). The guard was run verbatim in SketchUp's CRuby by the test (observed). **Two real processes: not verified**, because SketchUp was not running.
2. **`--model`, refusal, ping lists files.** Observed in `rbtest-bridge-slots.py`:
   - exact path, whole name or title, fragment and `pid:N` matching all work;
   - ambiguous, unmatched and two-windows-without-`--model` cases are refused with exit 6, the files are listed, and no job file is written;
   - `ping` against the real empty tree runs and exits 3 (observed). Ping's slot listing against a live slot is not verified.
3. **One window, no `--model`, unchanged.** submit() goes end to end through a fake listener thread into the single slot and returns (observed). Back-compat with an old listener (no slots, fresh root `alive`) routes to the shared `in/` with no target (observed in test). A real SketchUp is not verified.
4. **Listener re-checks the open file.** `target_refusal` was lifted verbatim and passes 10 cases: a different path and a File > New on an untitled model are refused `wrong-model`; the same path in another case or with other slashes runs (observed in CRuby). It is wired into `run_job` before the job is staged (read). Live: not verified.
5. **rbparse clean (observed). Pure tests (observed, and mutation-checked):** breaking the guard, the two-window refusal or the pid exit-code check each turns tests red. VERSION is bumped. It is pushed and installed (see the report). DEVLOG is written. **The live single-window check is NOT done.** It needs SketchUp; run the procedure below.

Also ran `scripts/rbtest.py`, `rbtest-autoset.py` and `rbtest-proposal.py`: all exit 0. In passing, the DEVLOG fix also repaired an older entry's `WhisperRoom<backspace>ridge` path typo.

## Read-first
- `scripts/wr_tools/wr_bridge.rb` header (the slot layout) and `target_refusal`.
- `scripts/sketchup-bridge.py` docstring "TWO FILES OPEN AT ONCE", plus `slot_info` and `resolve`.

## Assumptions
- **assumed:** SketchUp 2026 on Windows runs each open file as its own process. If it is one process, a slot still only has one `active_model` and the guard refuses a job for the file that is not active, so it stays safe. But the client would show one slot, not two.
- **assumed:** Ruby's `File.rename` replaces an existing `model.json` on Windows. There is a delete-then-rename fallback.
- **assumed:** `Sketchup::Model#guid` is stable for an untitled model between resolve and run (under 1 s). If it changes on edit, the cost is a rare spurious `wrong-model` refusal on an untitled scratch model, which is safe.
- **Design choice:** liveness comes from the Windows pid check (OpenProcess + image name contains "sketchup"), because a busy listener cannot heartbeat. Treating stale as gone would let a second job slip onto the other window.
- **Design choice:** the Ruby side deliberately never calls `Process.kill`.

## Open-questions
- None blocking. `WR_BRIDGE_MODEL` was added beyond the brief, so that `render/*.py` and `rbtest-live-*` (which call `submit()` without a model) can be pointed at one file per session.

## Supervised two-window test (Benton, about 10 minutes)
Do these after `install-plugin.py` (already run) and a full SketchUp restart.

1. Open SketchUp 2026 with file A (any saved .skp, or a copy). Run `python scripts/sketchup-bridge.py ping`.
   - Expect one slot: `pid N listening A-title A-path`.
2. Run `python scripts/sketchup-bridge.py eval "Sketchup.active_model.title"`.
   - Expect A's title and exit 0, with no `--model`. That is the single-window back-compat check.
3. Open file B in a **second window**. Use File > Open from the Windows Start menu / a new SketchUp, not File > Open inside window A. Run `ping`.
   - Expect two slots with different pids, each with its own file. If only one slot shows and its title flipped to B, SketchUp is one process: report that.
4. Run `eval "1"` with no `--model`.
   - Expect REFUSED, exit 6, both files listed, and nothing in either Ruby Console.
5. Run `eval "Sketchup.active_model.title" --model <fragment of A>`, then the same with `--model <fragment of B>`.
   - Each must return its own title. Then try `--model pid:<A's pid>`.
6. Guard check: in window A, File > Open file C (same window). Within a second, run `eval "Sketchup.active_model.title" --model <A fragment>`.
   - Expect either a refusal "matches none" (the card already updated) or `REFUSED (wrong-model)`. Never C's title.
7. Busy check: in window A, run `eval "sleep 15; 1" --model <A> --timeout 30`. After about 5 s (while it is still running), from a second terminal, run `eval "1"` with no `--model`.
   - Expect REFUSED, listing A as `busy`. It must not go to B.
8. Close window B and run `ping`.
   - Expect B's slot gone, swept once its pid has exited (it may show `gone` until 60 s have passed).
