# HANDOFF — lights harness + shading contract (1.19.3, 1 Sep 2026)

Fixer for the two findings Benton picked from the 1 Sep full audit
(`.forge/auditor/full-audit-2026-09-01.md` entries 13 and 3; lane B findings 1 and 2 in
`.forge/auditor/full-audit-B-proposal-render.md`). Base commit 523dad1 (plugin 1.19.2).

## Produced

Version bump: `scripts/wr_tools/VERSION` 1.19.2 → 1.19.3 (one bump).

**Fix 1 — `scripts/rbtest-lights.py` was red because the harness was stale.**
- `scripts/rbtest-lights.py` — `LUMEN_GAIN` added to `SCALARS` (it was introduced in
  wr-drop-lights.rb at 1.10.0, the list was last touched at 1.9.9); the `lm` expectation
  re-pinned at the values the tool actually writes (`20000,40000,10000,7000,5000,8000`,
  i.e. LUMEN_GAIN × the product figures), with a comment saying why it is not divided out.
- `scripts/rbparse.py` — `rb_eval` now reads `$!` after a failed protected eval and raises
  `RuntimeError("the check harness itself raised inside Ruby -- <Class>: <message>\n  at
  <first backtrace line>")`. Class name is parsed from `inspect` because the bare VM has
  no `Object#class`. Still a `RuntimeError`, so no caller's handling changes (grep: none
  catches it by type anyway).

**Fix 2 — the image lane's shading contract was undone by every scene switch.**
- `scripts/export-scenes.rb` `export_pages` — after `pages.selected_page = p[:page]`,
  after the tag re-hide and the Transparent-only key re-force, and before `view.refresh`
  / `write_image`, calls `cfg['after_switch'].call(model, page)` when present (rescued,
  message to console). `run()`'s own path passes none, so the standalone tool is
  unchanged. Header comment documents the key.
- `scripts/proposal-package.rb` — new `shade_reapply(model, dlg, page)`: no-op unless
  `@shade_saved` (SHADING unticked → nothing changes); otherwise `WR_Shading.apply`
  (NOT `push` — push would re-snapshot the contracted state and pop would then restore
  the contract instead of the model), then logs
  `shading re-applied after switching to <scene>: shadows off, AO off` per row, with any
  stuck keys. New `image_cfg(hide, dlg)` builds the export config for an image row and
  hangs the hook on it; `unit_image` now calls it (one-line rewire). Header bullet
  updated so the file's own claim about the contract is true again. Render lane untouched.
- `scripts/rbtest-proposal.py` — four new checks `shade1..shade4` running the REAL
  `export_pages`, the REAL `WR_Shading.push/apply/pop` (lifted from wr-shading.rb) and
  the REAL `image_cfg`/`shade_reapply`, with SketchUp faked: `FakePage` re-applies its
  stored rendering options and shadow info on `selected_page=`, `FakeView.write_image`
  records the model's shading at the moment of the write. `log` now records lines so
  shade4 can assert the read-back. `Integer#to_i` shimmed (absent in the bare VM;
  `dark_value` calls it). `const_block` gained an optional `src` argument.

Workspace: `.forge/fixer/repro-shading-contract.py` re-triggers all three red states
from `git show 523dad1:` copies and then runs the real tree green.

## Read-first (the evidence)

Harness before, observed:
```
$ python scripts/rbtest-lights.py
RuntimeError: the check harness itself raised inside Ruby
```
Same 1.19.2 harness with the new `rbparse.py`, observed — the stale constant names itself:
```
RuntimeError: the check harness itself raised inside Ruby -- NameError: uninitialized constant WR_DropLights::LUMEN_GAIN
  at eval:466:in `layer_lumens'
```
After, observed:
```
wr-drop-lights pure placement: ...   PASS  (43 checks in one transcript)
wr-mode snapshot pins: ...           PASS  (10 checks in one transcript)
```

`rbtest-proposal.py` against the 1.19.2 `export-scenes.rb` (new harness, new
proposal-package.rb), observed:
```
shade1 FAIL a scene that stores shadow info won over the contract at write_image: {:shadows=>true, :ao=>true, :light=>60, :dark=>30}
shade2 FAIL the non-storing scene was written with {:shadows=>true, :ao=>true, :light=>60, :dark=>30}
shade3 ok
shade4 FAIL no per-row read-back in the log: []
```
That is the audited failure exactly: `write_image` saw the scene's own shadows ON, AO
ON, Light 60 / Dark 45 → 30 while the contract wanted off/off/80/45. shade3 ok on the old
code is right — `pop` was never the defect. Against the 1.19.2 `proposal-package.rb` the
lift fails by name (`no method self.shade_reapply`). On the new tree: all 107 checks
`ok` (103 existing + shade1..4), exit 0.

Every other offline harness after the `rb_eval` change, observed: `rbparse.py` 66 files
parse; `rbtest.py`, `rbtest-boothlink-cbl.py`, `rbtest-boothlink-v3.py`,
`rbtest-doorswing.py`, `rbtest-overlays.py`, `rbtest-part-orientation.py`,
`rbtest-roofvent.py`, `rbtest-srgb.py`, `rbtest-takeoff.py` exit 0;
`takeoff-check.py --selftest` 0 failures. `rbtest-live-booth.py` exits 2 with a usage
message both before and after (it needs a running SketchUp and arguments; not mine).

Push/pop snapshot safety, derived from `wr-shading.rb`: `push` snapshots then applies;
`apply` only writes + reads back and never touches the snapshot; `pop` writes the
snapshot back. Calling `apply` per row therefore cannot corrupt what `pop` restores —
and shade3 observes exactly that round trip through two switches and two re-applies.

## Assumptions

- **assumed (unverifiable offline):** a real SketchUp `Page` with `use_shadow_info` /
  `use_rendering_options` re-applies those on `selected_page=`. This is the documented
  Page contract and the same mechanism observed live for tags at 1.9.12; the fake models
  it. If SketchUp did NOT do this, the fix is a harmless extra write per row.
- **assumed:** `view.refresh` after the re-apply is enough for `write_image` to pick up
  the new shadow state — the same ordering the tag re-hide already relies on.
- The choice to pin lumens at the written values (10×) rather than divide the gain out
  is mine: the harness's job is to say what the tool writes, and a calibration change
  should show up by name.

## Open-questions

- **Benton's five-minute check (the one thing not proven):** one scene with shadows ON,
  SHADING ticked in the proposal package, export it as Image, look for shadows. Expect
  none, and expect a log line `shading re-applied after switching to <scene>: shadows
  off, AO off` per row. If shadows are still there, the read-back line is the first
  thing to read — it says what the model held at the write.
- Out of scope, noted for the ranking: the DRAFT-mode "flat" pin in `wr-mode.rb` is
  beaten by the same page re-apply on the model itself (lane B finding 2 mentions it);
  nothing here touches it.
- `.forge/GOAL.md` carries the orchestrator's uncommitted edit (the Now section) and
  `.forge/auditor/eval-run/`, `.forge/auditor/proposal-run/` are untracked; not mine, not
  committed here.
- Documenter: DEVLOG entry for 1.19.3 is yours per GOAL.
