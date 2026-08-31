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
**Render look development.** The bridge (1.9.0), the booth matrix (50/50 clean) and the lights
(1.9.1, two silent defects fixed) are done. The open work is that **the renders still look bad**,
and the reason progress was slow is that we were art-directing blind at ~6 minutes a frame.
The fix is the feedback loop: a **thumbnail look matrix** at ~400x225, three stages —
environment/sun, then the light-rig balance, then an exposure ladder. Benton picks from a
contact sheet; no agent picks the look.

**Benton's decisions, 30 Aug 2026:**
1. **The tool HONOURS the V-Ray settings he has set — it does not write them.** His Asset Editor
   is **1600x900, 16:9, Quality Medium, Progressive on**. `scripts/proposal-package.rb:1213`
   was writing `/SettingsOutput` and `:1488` `/CameraPhysical` (observed). Overrides become
   explicit, opt-in and logged; a missing setting **fails by name**, never gets a substitute.
   This is the same rule as "never invent a placement number", applied to render settings.
2. **BALANCE THE LIGHT RIG rather than keep per-scene exposure.** The room rig is ~8x the booth
   rig, which is the only reason one EV could not serve both an interior and a room view.
   Balancing it is the real fix; the per-scene EV override was a workaround. Target: **one
   exposure, Benton's own, serves both**, and the package never writes `/CameraPhysical` on a
   normal run. If no single EV works even after balancing, that is a finding to state plainly.
3. **Safe Frame ON.** It was off, so the viewport showed one shape while V-Ray rendered 16:9 —
   composing blind. It is a preview aid and changes no output.

**The blue panel is BLUE ACOUSTIC FOAM, a real product.** An earlier report called it a
placeholder defect; that was wrong and is corrected. Open question: it renders flat where the
SketchUp export shows its diamond pattern, so the wedge geometry or material may not survive
into the render.

**Report artifact:** https://claude.ai/code/artifact/4e498801-9e28-4dc1-9ac5-1f51755aefb0

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
