# SPEC — Interior Lights panel (adjust a dropped rig)

14 Sep 2026 · plugin 1.69.0 · Scoper · **no code written**
Mockup (clickable): **https://claude.ai/code/artifact/b988c58a-4c81-4e91-b03a-edc2c0ac359f**
(source: `.forge/scoper/drop-lights-panel/mockup.html`)

**The real problem.** Benton has no way to see or re-tune a rig after it is dropped. The only window
the tool has is the pre-drop settings dialog, and it only appears once a room is selected. So "make it
brighter" today means re-dropping. That is a V-Ray drift lottery (DEVLOG 1.67.1), and it rebuilds
geometry he didn't want touched.

## 0. Why it "only pops up on an empty room" (observed)
- The panel button runs `load path` (`scripts/wr_tools/main.rb:1561`). The file autoruns `WR_DropLights.run` (`scripts/wr-drop-lights.rb:5891`).
- `run` reads the selection first (`:4768`, `split_selection` `:3891`). If there are no subjects it shows a messagebox and **returns** (`:4787-4819`). The dialog (`ask`, `:4824`) is never reached.
- Selecting the rig itself is refused. Each light carries `WR_DropLights/seed`, so `subject_exclusion` returns `:own` (`:3883`). That leads to "The selection holds only lights" (`:4798`).
- The dialog it does open is **modal and pre-drop** (`show_settings` `:4348`, `show_modal` `:4461`). Its only outcome is a new drop that sweeps and replaces the old rig. **No code path edits an existing rig.**

## 1. What a rig is in the model (observed)
- The lights are placed in the **active context**, not inside the room (`:4878`). Everything sits on tag `WR Lights`.
- Every light instance carries dictionary `WR_DropLights`: `seed` (label), `role`, `uuid` (one per press, shared by every room in that press, `:4929`), `plugin` (V-Ray plugin name), `lumens` (as written), `invisible` (`:5053-5069`).
- Fixture groups carry `kind=fixture` and `role=fixture_f4` and hold their emitters (`:4950-4955`). Borrowed ceilings and walls carry `kind=ceiling|wall`.
- **Not stamped:** which room a light belongs to, the press settings (`@last_settings` lives in memory only, `:4361`), Kelvin, and the 100% baseline.
- **Office rig (the default, `RIG_DEFAULT` `:779`) roles:**
  - `:panel`: visible aperture, 8% of the position's output.
  - `:plenum`: hidden emitter at the same point, carrying the other 92% (`:5317-5346`).
  - Panel positions come from `panel_grid` at a 96 in spacing, capped at 49. A 40×40 ft room gets 25 positions, a 16×12 gets 4, a 20×14 gets 6.
  - `:fill`: invisible spheres, 14 per booth (`FILL_SCATTER`), each with its own weight of 0.24-0.57. Legs with no legal standoff are skipped.
  - `:facewash`: one invisible 60×48 in panel per booth, skippable.
  - A 40×40 room with one booth has **65 emitters**, matching the DEVLOG's "65 of 65".
- The classic rig uses `:ceiling :key :pendant :sconce :rim :foam`. The UI must be driven by `LIGHT_LAYERS`, not hard-coded.
- **Lumens written per light:** `LIGHT_LAYERS[role][:lumens] × mult × room_trim × role_scale × LUMEN_GAIN(10) × cam_gain(32)` (`layer_lumens` `:1596`). Fill is also × the sphere's weight. Panel/plenum is then split by `PANEL_VISIBLE_SHARE`.
- **Audit and repair.**
  - `audit_scene` (`:3372`) classifies every V-Ray light as rig, model or GHOST. It flags DEAD (≤ 30 lm or disabled), WRONG, SEEN (visibility mismatch) and MISSING.
  - An intended 0 lm that reads 0 counts as **OFF, not a fault** (`:3320`).
  - The repair is **not in the module**. It lives only in the harness at `.forge/fixer/rank-loop/d-repair.rb`: it rewrites units, intensity, invisible, colour, directional and is_disc from the instance stamps.
  - That repair writes colour with `layer_kelvin(spec, 0)`, so it **ignores warmth offsets** (a latent bug).

## 2. How it opens
- **New panel button:** `scripts/wr-lights-panel.rb` (`@title Adjust interior lights`, `@cat V-Ray renders`). It sets `$wr_no_autorun`, loads `wr-drop-lights.rb`, then calls `WR_DropLights.show_rigs`. It never needs a selection.
- **Re-route in `run`.** With no subjects and no `given` (`:4787`): if the model holds any rig, open `show_rigs` instead of the messagebox. The same applies when the selection is only this tool's own lights, and then the panel expands the rig those lights belong to. With no rig, keep today's messagebox.
- **Modeless singleton** `@rig_dlg` (like `wr-scene-walls.rb:1217`). A second press brings the open window to front and refreshes it.
- **No rig:** an empty state explaining how to drop, plus **Drop lights in selected room…** (disabled with "Nothing is selected" when true). The button calls today's `run`, and the list refreshes when the drop commits.
- **One rig:** expanded. **Several:** one card per room, and the most recently dropped rig is expanded.

## 3. What it lists
- **List unit = room.** Group by a new stamp `room_pid` (the room's `persistent_id`) and `room_name`, written at drop.
- **Legacy rigs** (no stamp): group by `uuid`, and name the rig by the `room_group?` (`:3969`) whose world bounds contain the lights' world origins. Use the "Press of <date>" label from the uuid epoch only if nothing contains them.
- **Each card shows:** room, booth name, light count, drop time, master %, and a status chip (Matches V-Ray / Changed / Writing / Repaired N / Doesn't match).
- **Types are grouped for people, not code:**
  - **Ceiling panels** = `panel` + `plenum`, scaled together so the 8% share holds. Counted in positions.
  - **Fill spheres** (placed of 14).
  - **Booth face wash.**
  - Classic roles map 1:1 by `LIGHT_LAYERS[:label]`.
  - A type the drop skipped shows as a disabled row saying why.

## 4. Brightness semantics (recommended)
- **Stamp `lumens_base` on every light at drop.** It is the value written at 100%, including trim, gain and the fill weight.
- **Store per-rig state in the model:** `model` attr `WR_DropLights` key `rig:<room_pid>` = JSON `{master, roles:{panel:{pct,on},…}}`.
- **The write, per light:** `lumens = lumens_base × master × role_pct` (0 if off). Update the instance's `lumens` attribute to that same number, so `audit_scene` keeps working unchanged. OFF writes 0, which the audit already treats as OFF.
- **Slider:** log scale, 10%-300%, with a detent at 100%. Equal travel means equal stops.
- **Readout:** %, ±stops (`log2`), total V-Ray lm and the product-figure lm (÷320), clearly labelled.
  - DEVLOG 1.66.0 (observed) found the linear mean moves 1:1 with lumens, but the *encoded* image does not (half the lumens: median 148 → 109, not 74). Stops is the honest unit; % alone overstates the change.
- **Above 100%:** say "above tuned is unscored; ceiling clips first." DEVLOG 09-11 dead end: raising the panels trades D1 against D2.
- **Legacy rigs:** `lumens_base := current lumens` on first open, stamped, with a "Dropped before 1.70" chip.
- **Reset to tuned:** master and every role back to 100%, all on. **Revert:** back to the values the window opened with.

## 5. Writes, undo, drift
- **Apply on release.** `input` moves the readout in JS only; `change` sends one callback, and Ruby writes every affected light inside **one** `scene.change` (`write_params` `:3514`, batched rather than one per light). Live-while-dragging is Q3.
- **Never `Sketchup.undo`, and never promise Ctrl+Z.**
  - `scene.change` closes the SketchUp operation underneath the rig (DEVLOG 1.66.0 #7, observed).
  - Attribute writes go in one `start_operation('Adjust Interior Lights', true)`.
  - **The attributes are the truth.** After any Ctrl+Z, the panel reconciles plugins from attributes on refresh or focus.
  - A `ModelObserver#onTransactionUndo` hook to do this automatically is **assumed to exist**. The Builder must verify it in the SketchUp API before relying on it.
- **Drift:** after each apply, `UI.start_timer(4, false)`, then `audit_scene`. On DEAD, WRONG or SEEN, run `repair_rig!` and re-audit, then show the result on the chip. Also a **Check & repair** button.
  - Promote `d-repair.rb` into the module as `repair_rig!(model)`.
  - It restores from the stamps plus a new per-light `kelvin` stamp, which fixes the warmth bug.
  - It never touches lights the rig doesn't own. GHOSTs are reported, not deleted.
- **Visibility:** each type's ON switch writes 0 lm. That is cheap and already audit-safe. Hiding entities is out: whether V-Ray honours a hidden instance has not been checked.

## 6. Acceptance
1. With nothing selected, the panel button opens the window, on 0, 1 and 3 rigs.
2. On a 65-light rig, a release at 50% leaves every `lumens` attribute = `lumens_base × 0.5` and `audit_scene['ok']`, and 4 s later the same.
3. Force a drift (write 30 lm to two fills outside `scene.change`). **Check & repair** restores them and the audit is ok.
4. Fill OFF leaves the audit ok with 14 OFF lines. ON restores the previous values.
5. **Reset to tuned** gives written lumens equal to the drop's own.
6. After Ctrl+Z of an adjust, Refresh makes the plugins match the attributes, and the audit is ok.
7. `rbparse.py` is clean. New pure helpers (grouping, pct→lumens, log slider maths) are pinned in `rbtest-lights.py`. VERSION is bumped.

## 7. Benton's decisions (recommended answer first)
1. **What is 100%?** Recommended: make the office defaults panel ×0.70 / fill ×0.10 / facewash ×1.00, so a fresh drop *is* the 8.2 rig and 100% means that.
   - Today `default_settings` (`:4224`) is all ×1.0. The 8.2 rig was scored at ×0.70 / ×0.10 (DEVLOG `:907`, `:1067`), so today a default drop is **not** the scored rig.
   - Alternative: 100% = whatever this drop wrote.
2. **Slider range.** Recommended 10-300%, log scale. Or 0-200% linear?
3. **Write timing.** Recommended on release only. Live while dragging would need IPR running and costs a `scene.change` per step on 65 lights.
4. **Per-type Kelvin in this panel?** Recommended not now. It stays in the drop dialog.
5. **Per-rig "Remove this rig" button?** Recommended not in v1. Remove-all already exists, and a per-room removal needs a verified path of its own.
6. **Should the booth's own BoothLighting light be listed (read-only)?** Recommended yes, greyed, "not this rig", so the interior isn't mistaken for unlit.
7. **Should an empty selection reroute to the panel** (§2), or should the new button be the only way in? Recommended both.

## 8. Out of scope
Re-placing, adding or moving lights. Changing counts or grid spacing. The camera or ISO (`NEVER_WRITE`). Sun. Floor. Presets (they stay in the drop dialog). Classic-rig tuning figures. Fixing the flush aperture having no geometry (DEVLOG 09-11 #2). Any render or rank run.
