# HANDOFF — Scoper → Builder: Interior Lights panel (adjust a dropped rig)

14 Sep 2026 · plugin 1.69.0. The previous handoff (proposal AUTO-SET) is preserved verbatim at
`.forge/scoper/HANDOFF-proposal-autoset.md`.

**Blocked on Benton for Q1 and Q7** in SPEC §7. Q1 decides what 100% writes. Everything in SPEC §2-§5
that doesn't depend on Q1 can start: stamps, grouping, the window, apply-on-release, and the repair.

## Produced
- `.forge/scoper/drop-lights-panel/SPEC.md`: the spec.
- `.forge/scoper/drop-lights-panel/mockup.html`, published at
  https://claude.ai/code/artifact/b988c58a-4c81-4e91-b03a-edc2c0ac359f. Republish the same path to keep the URL.
- Nothing under `scripts/` was touched. VERSION is untouched.

## Read-first
1. SPEC §0-§1. Every claim there cites `scripts/wr-drop-lights.rb` lines at 1.69.0.
2. `write_params` (`:3514`) and the transaction note above it. An un-transacted write is discarded.
3. `audit_verdict` / `audit_scene` (`:3300-3418`), especially the intended-0 = OFF rule.
4. `.forge/fixer/rank-loop/d-repair.rb`. Promote it to `WR_DropLights.repair_rig!`, and fix its Kelvin (it uses offset 0).
5. DEVLOG 1.66.0 findings 6-7 and 1.67.1: drift, and never `Sketchup.undo`.
6. The modeless dialog pattern in `scripts/wr-scene-walls.rb:1217`, and the `load_quietly` / `$wr_no_autorun` pattern in `scripts/wr_tools/main.rb:1404`.

## Assumptions (not checked)
- `Sketchup::ModelObserver#onTransactionUndo` is usable for reconcile-after-undo. Verify it in the API docs, or fall back to reconcile on Refresh or focus.
- Batching many plugins' writes inside one `scene.change` behaves like the per-light calls. Only per-light transactions have been observed.
- A 4 s settle is enough for V-Ray's deferred re-sync to show. The observed drift appeared "between one job and the next"; the timing was never measured.
- Fill "each" figures in the mockup are averages. The Room B and Break room counts are illustrative, derived from `panel_grid` and `grid_count`.

## Open questions
SPEC §7 Q1-Q7. The one that changes numbers is **Q1**: shipped `default_settings` is all ×1.0, but the
scored 8.2 rig was panel ×0.70 / fill ×0.10 / facewash ×1.00.
