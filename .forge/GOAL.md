# GOAL

## Mission
Build a **SketchUp bridge**: a resident Ruby listener inside SketchUp plus an outside client,
so an agent can run WhisperRoom tools in the live application, read the console output, query
the model geometry, and capture viewport images — without a human driving the mouse. The
target is turning the pending test checklists into automated, repeatable assertions instead
of hand-walked eyeball checks.

## Done means
1. **A resident bridge** installed with the plugin (loads on SketchUp start, no per-run
   restart). It polls an inbox directory, `load`s a submitted job `.rb` inside SketchUp,
   captures `$stdout`, the return value, and any exception **with backtrace**, and writes a
   result file the outside caller can read.
2. **An outside client** (Python, matching `scripts/*.py` house style) that submits a job and
   returns its result, with a timeout and a clear "SketchUp did not answer" failure — never a
   silent hang.
3. **Modal-dialog safety.** Jobs run with the prompt-suppression globals the codebase already
   uses (`$wr_no_autorun`, `$wr_suppress_autorun`) set. A job blocked on a modal is reported
   as a timeout naming the likely cause — it does not look like a pass.
4. **Proven live in SketchUp**, not just reasoned about. At minimum: a job that reads model
   state, a job that runs a real WR tool end to end, a job that writes a viewport PNG via
   `model.active_view.write_image`, and a job that raises — whose backtrace comes back intact.
5. **Safe by construction.** Scratch models only. The bridge must not save over an open model
   or write into `C:\Users\bento\Desktop\ProposalFiles\`.

## Now
**Bridge shipped at plugin 1.9.0** (`scripts/wr_tools/wr_bridge.rb`, `scripts/sketchup-bridge.py`),
all 12 acceptance criteria passing live on SketchUp 2026. Two lanes are running against it:

- **Phase 2 — lights.** The 1.8.0 `wr-drop-lights.rb` rebuild has never been run in SketchUp.
  Running the six-item checklist in `.forge/builder/HANDOFF-lights-api.md` live. **SketchUp
  2026.** No V-Ray renders — every item is checkable from geometry, light properties, console
  strings and viewport shots.
- **Phase 0 — booth-matrix harness.** Enabling and validating the **SketchUp 2024** bridge
  (never exercised), then building a harness that drives
  `WR_BuildBoothComponents.build_booth` over all 50 keys and captures a per-key manifest of
  placed parts, landed bounds, and named refusals. Dry runs for all 50; real builds for
  `MDL 6060 S/E`, `MDL 96192 E`, `MDL 102186 E` only.

**SketchUp 2026 ONLY — 2024 lane cancelled 30 Aug 2026 (Benton).** 2026 is the version he
works in, and a golden baseline captured on 2024 would produce spurious diffs against every
later 2026 run, defeating the point of the baseline. The earlier two-instance split traded
environment fidelity for parallelism; that was the wrong trade.

**Consequence: the two lanes SERIALIZE on one SketchUp.** One instance shares one model, so a
booth build's `file_new` would destroy a lights test mid-run. Lights holds 2026 now; the
harness lane writes code and waits for an explicit hand-off before any live run. Version
numbers pre-assigned to avoid collision: lights 1.9.1, harness 1.9.2.

**SketchUp 2024's bridge remains unvalidated** and is now out of scope.

**`EFP96192.skp` EXISTS on the share as of 30 Aug 2026** (426,135 bytes, verified;
`EFP96196.skp` is gone). Benton renamed it. The refusal at `scripts/wr-overlays.rb:901-905`
should no longer fire — the harness confirms that.

**The golden-manifest plan:** build every model once, capture every part with its landed
bounds and every refusal by name, review that baseline once, then freeze it. Every later
change becomes a diff instead of an eyeball job. The landed-bounds print already exists at
`scripts/wr-deck.rb:1130-1139` and is re-measured post-placement — capture it, do not
reimplement it.

**Still unowned, and no code fixes it: EXPOSURE.** The V-Ray default sits near EV 14.2; an
interior wants roughly EV 8. Until someone owns it, every interior renders dark regardless of
the lights or the render lane. Name it; do not build around it.

## Rules that still bind this work
- Plugin edits land under `scripts/wr_tools/`; bump `VERSION`; a restart reloads.
- `WhisperRoomQuote` and the `P:` share are **read only**.
- No silent fallback: a job that cannot run fails **by name**.
- Never run bridge jobs against live client work — scratch models only.
- Commit and push every change.

## Out of scope
- Driving the V-Ray VFB, the asset editor, or any HtmlDialog by simulated keystrokes.
- Actually running V-Ray renders through the bridge. The bridge must not *preclude* it, but
  renders are a later use of the tool, not part of building it.
- Any change to booth geometry, lighting, or the proposal package itself.

## History
2026-08-30 — Portal-parity / proposal-package mission parked at plugin 1.8.0 to build this
test harness first. Full text preserved at `.forge/GOAL-prev-portal-vray-mission.md`; its
five-step resume list is the first customer for the bridge.
2026-08-27 — Enhanced/IEP two-shell mission parked at 1.6.32, see
`.forge/GOAL-prev-iep-mission.md`.
