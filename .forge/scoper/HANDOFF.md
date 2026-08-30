# Scoper HANDOFF — SketchUp bridge (2026-08-30)

## Produced

- `.forge/scoper/sketchup-bridge.md` — the full build contract: protocol, job/result JSON
  with worked examples, error semantics, timeout and modal diagnosis table, output capture,
  install/enablement, safety fences, and twelve acceptance criteria (A1-A12) mapped to the
  five Done-means in `.forge/GOAL.md`.

No mockup: the deliverable has no graphical UI. The worked job/result JSON in the spec is the
equivalent artifact, per the assignment.

## Read first

1. `.forge/GOAL.md` — Mission, Done-means, Out of scope.
2. `.forge/scoper/sketchup-bridge.md` — this contract.
3. `scripts/wr_tools/main.rb` lines 1026-1056 (`load_quietly`, the autorun-suppression model)
   and lines 1057-1080 (why `rescue Exception`, not `StandardError`).
4. `scripts/proposal-package.rb` lines 578-600 — the `UI.start_timer(0.1, true)` +
   `@in_step` reentrancy idiom the listener copies.
5. `scripts/install-plugin.py` — confirm it copies every file in `scripts/wr_tools/`
   (it does, per its `main()`), so no installer edit is needed.
6. `scripts/rbtest-lights.py` header — the harness house style the live tests should grow into.

## Assumptions

- **observed:** a duck-typed object with a `write` method captures `Kernel#puts` in
  SketchUp's own CRuby 3.2, and `File.rename` over an existing file succeeds on NTFS. Both
  probed against `C:\Program Files\SketchUp\SketchUp 2024\x64-ucrt-ruby320.dll` via
  `scripts/rbparse.py`'s VM. These are the two load-bearing mechanisms in the protocol.
- **observed:** SketchUp 2024 and 2026 are both installed and both have profiles under
  `%APPDATA%\SketchUp\`. Hence the per-version bridge root.
- **assumed, must be settled live (A4):** that SketchUp's own console output honours a
  `$stdout` swap. Only Ruby-level `puts` was provable outside SketchUp. Mitigated by teeing
  rather than replacing, so an unverified path costs a missing record, not a missing line.
- **assumed, must be settled live (A10):** that `UI.start_timer` stops firing while a modal
  dialog is up — this is what makes the stale heartbeat the wedge signal. The spec names the
  fallback signal if it turns out false.
- **assumed:** `require 'json'` is available in the plugin context (`main.rb` already does it,
  observed). The minimal rbparse VM could not load it, which is a property of that VM, not of
  SketchUp.
- **derived:** `eval` rather than `load` for the job body, because `load` returns `true` and
  discards the job's return value. Deliberate deviation from the Done-means wording, justified
  in the spec.

## Open questions — for Benton, none blocking the Builder's start

1. **Opt-in confirmed?** The spec makes the bridge **off by default**: no marker file, no
   timer, nothing resident in his daily-driver SketchUp. Enabled by a menu item or by the
   client. Is that the trade he wants, or would he rather it just be on?
2. **Bridge root.** `%LOCALAPPDATA%\WhisperRoom\bridge\<version>\` — deliberately out of
   OneDrive (sync would race the protocol's core read) and out of the repo. Fine, or does he
   want it somewhere he can see it in Explorer?
3. **`UI.messagebox` inside a job:** the spec makes it **raise** by default, so a prompting
   tool fails by name instead of freezing SketchUp. The alternative is auto-answering with the
   default button and logging it. Raising is safer; auto-answering is more useful for driving
   tools that prompt as part of their normal path. Which does he want as the default?
4. **Named models:** the spec refuses to run against any saved model unless the job explicitly
   sets `allow_named_model`. Is Untitled-only acceptable, or does he expect to run jobs against
   a real drawing he has open?
5. **Default SketchUp version** for the client when both are listening — the spec refuses and
   makes you pick. Should 2026 be the default instead?

## Blockers

None. SketchUp is not running (observed 30 Aug 2026); the Builder will need Benton to start it
and restart it once after `install-plugin.py`, before A1-A12 can be run.
