# HANDOFF — Builder: Interior Lights panel (14 Sep 2026, plugin 1.70.0)

History: earlier today the Wyatt Shepherd two-option proposal pack was built (see git history of this
file, commit 62d698e); before that, the Suites 128 & 114 take-off (e0056ce, 9d5e7a1). AUTO-SET handoff:
`.forge/builder/HANDOFF-autoset.md`.

## Produced
- `scripts/wr-lights-panel.rb` (new panel button "Adjust interior lights...").
- `scripts/wr-drop-lights.rb`: pure panel maths (clamp_pct .. repairable), drop-time stamps
  (lumens_base, kelvin, kelvin_base, room_pid, room_name), the empty-selection reroute in `run`,
  and the panel section (rig_scan, panel_state, apply_rig!, live_rig!, repair_rig!, remove_room_rig!,
  check_rigs!, booth light, observers, show_rigs, RIGS_HTML).
- `scripts/rbtest-lights.py`: 9 new rows, all green. `fill` / `fillsmall` still red (pre-existing).
- VERSION 1.70.0. DEVLOG 1.70.0. SPEC §7 answers recorded.

## Verified
- rbparse clean (76 files). Read-only bridge runs on the open client model: grouping, booth light,
  chips, fence (auto 0 / forced 7), model not modified. Dialog rendered in headless Chrome.

## NOT verified (no live write path has run)
Apply, live drag, Kelvin, remove, booth write, module repair, Drop in lights from the panel, the undo
observer, batched live scene.change, the dialog in CEF. The active model was a saved client file.

## Benton's manual test (Untitled model, V-Ray open)
1. Build a room, select it, Drop the interior lights (defaults). Then Esc to clear the selection.
2. Press "Adjust interior lights" (or press Drop the lights again with nothing selected): one card.
3. Drag the whole-rig slider to about 50% and release; chip goes Writing, then Matches V-Ray about 4 s later.
   Console: `WR_DropLights.audit_scene(Sketchup.active_model)['ok']` should be true.
4. Switch Fill spheres off, then on. Type 3500 in a Kelvin box. Reset to dropped.
5. Ctrl+Z once; console should print "undo seen — reconciling", chip back to Matches V-Ray.
6. Drag the booth light slider; render or check the Asset Editor's Standard Light intensity.
7. Remove this rig... then Remove; lights gone, card gone.
8. With a room selected, Drop in lights... opens the usual settings; the card list refreshes after.

## Open for Benton
- On the Wyatt Shepherd model, V-Ray holds 1% of the stamped plenum lumens (hand edit?). The panel will
  not overwrite that except on Check & repair, but its 100% is the stamped value, per his Q1 rule.
