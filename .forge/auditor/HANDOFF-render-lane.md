# Auditor handoff — render lane — 2026-08-28

## Produced
- `.forge/auditor/render-lane-audit-2026-08-28.md` — ten ranked findings (F1–F10)
  on the V-Ray render lane at plugin 1.7.9, with a <5-minute live SketchUp check
  for each. No code was changed (read-only audit).

## Read first
- The audit file above — especially F1 (`:fatalError` classified RUNNING → 30-min
  burn per row), F2 (cold-session start no-op: documented candidates
  `VRay::Command.render_production(context:)` and `renderer.start(sync: true)`),
  and F3/F5 (the two silent leaked-mutation paths that survive 1.7.9).
- On-disk V-Ray YARD docs (29 Apr 2026 build):
  `C:\Program Files\Chaos\V-Ray\V-Ray for SketchUp\extension\documentation\VRay\`
  — `Command.html`, `VRayRenderer.html` (state lists TEN values; `start` takes
  `sync:`; `save_vfb_image(path, options) => Boolean` with `:skip_alpha` /
  `:no_alpha` / `:apply_color_corrections`).

## Assumptions
- The two 1.7.9 fixes (idleDone-only latch, settled camera) work as designed —
  per assignment, not re-derived.
- Doc text describes this build's binding (same docs whose entry points the
  27 Aug probe confirmed) — but documented ≠ working; nothing was executed here.
- SketchUp operations do not nest (F6) — reported API behaviour, medium
  confidence, live check given (one toggle + one Ctrl+Z).
- `Object#clone` on `view.camera` may alias the live camera (F8) — assumed,
  two-line console check given.

## Open questions
- Does `VRay::Command.render_production` drive the SAME renderer/state machine
  the poll loop reads, and does it engage on a cold session? (F2's console check
  decides the whole cold-start design.)
- Does `renderer.start(sync: true)` engage cold where bare `start` no-ops?
- Can a batch single-frame render terminate at `:idleFrameDone` instead of
  `:idleDone`? (Would discard a finished render after 10 s — F7.)
- Why did 1600 set in the Asset Editor not reach the output (2400×1350 observed)?
  Read-back check in F9; a documented WRITE mechanism exists
  (`scene.change` + `/SettingsOutput`), param names still unverified.
- Licence seat consumption by scripted renders — still open; the DR raise keeps
  F1's `:fatalError` scenario plausible on this machine.
