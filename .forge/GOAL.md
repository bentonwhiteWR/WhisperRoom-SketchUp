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
**Spec is written and approved:** `.forge/scoper/sketchup-bridge.md` (protocol, error
semantics, modal diagnosis, fences, acceptance criteria A1-A12). **Builder implements it.**

**Benton's four decisions, 30 Aug 2026 — these override the spec where they differ:**
1. **Off by default.** No marker file, no timer, nothing resident until enabled. (As specced.)
2. **A modal prompt raises** and fails by name. No auto-answer. (As specced.)
3. **Named models ARE allowed** — jobs may run against a saved drawing he has open.
   **CHANGES THE SPEC.** The pre-flight refusal on named models is dropped. Every *write*
   fence stays: no `save`/`save_copy` over any model, and the absolute deny list
   (`ProposalFiles`, `P:`, `WhisperRoomQuote`) still governs `write_image` and every
   bridge-mediated write. Running against a real drawing is fine; overwriting one is not.
4. **The client defaults to SketchUp 2026** when both are listening. **CHANGES THE SPEC** —
   the spec refused and made the caller pick. `--version` still overrides.

Benton must launch SketchUp and restart it once after `python scripts/install-plugin.py`
before A1-A12 can run. It was not running as of 30 Aug 2026 (observed).

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
