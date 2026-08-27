# Scoper HANDOFF — V-Ray proposal-package skill

2026-08-27. Supersedes the 2026-08-24 Enhanced-booth handoff (that mission is parked —
see `.forge/GOAL-prev-iep-mission.md`; its spec `enhanced-booth-build.md` stays in this
folder for the record).

## Produced

- `.forge/scoper/vray-proposal-package-spec.md` — the buildable spec: one new tool
  script `scripts/proposal-package.rb` (module `WR_ProposalPackage`), reusing
  `WR_MaterialsSwap` / `WR_Mode` / `WR_ExportScenes.export_pages` / `WR_Preflight` /
  `WR_Folder` unchanged; scene-mode marks stored on each `Sketchup::Page`; exact
  filename/collision rules; two-pass batch (draft images, then V-Ray renders) driven by
  a `UI.start_timer` state machine with a single FINISH exit that restores the model;
  acceptance checklist at the end.
- `.forge/scoper/vray-proposal-mockup.html` — standalone clickable mockup, styled with
  the same CSS tokens as the `list-scenes.rb` dialog. **Design of record** for the UI:
  search, three-state Skip/Image/Render per row, live FILE column (shows the ` render`
  suffix and collision `(2)` numbering), materials-slot section, folder/width/overwrite
  row, simulated run with progress, one deliberate failure, and cancel. Open it in a
  browser; this is what Benton reviews first.

No production code written or changed. `wr-pack-export.rb` is deliberately untouched.

## Read-first (Builder)

1. `.forge/scoper/vray-proposal-package-spec.md` — start at "The V-Ray call —
   load-bearing and unverified". **Step 0 of the build is getting `probe-vray.rb`
   output from Benton's live SketchUp**; the render lane's shape forks on it.
2. `scripts/wr-materials-swap.rb` and `scripts/wr-mode.rb` — the swap/revert machinery
   you must call, never copy. Both carry "THIS FILE HAS NOT BEEN RUN" banners; your
   feature will be the first live exercise of them.
3. `scripts/export-scenes.rb` `export_pages` — the one `write_image` path; drive it,
   don't fork it.
4. `scripts/list-scenes.rb` — lift its search/highlight/range JS and CSS tokens.
5. `scripts/wr-pack-export.rb` — the HtmlDialog-command, preflight-gate, overwrite-ask
   and restore-in-ensure patterns to copy.

## Assumptions (all marked in the spec too)

- **V-Ray API surface** (`Context.active`, `start`/`wait`/`in_process?`,
  `save_vfb_image`, `stop`) — *reported* from `reference/vray-ruby-api.md`; the Chaos
  docs are not on this desktop (checked — no `C:\Program Files\Chaos`), and probe-vray
  has never run. Gate the render lane on the probe.
- V-Ray renders the **active scene's camera** after `pages.selected_page=` +
  `view.refresh` — *assumed*; confirm on first manual test.
- "Normal images" = **draft mode** (drafting materials, scene's own tags) — *derived*
  from Benton's "the floor might be just white" phrasing.
- V-Ray output resolution stays whatever the Asset Editor holds in v1 — decided the
  conservative way because setting it needs an unverified `/SettingsOutput` write.
- Skip is the default state for an unmarked scene; marks live on the page attribute
  dict `WR_ProposalPackage` so they survive save/reorder.

## Open questions (decided in the spec, cheap to reverse; ask Benton when he's back)

1. Plain images in **draft** mode always — or "as the model currently sits"? (Spec:
   always draft.)
2. V-Ray resolution from the dialog (v2) — wanted, and at what default size?
3. Should the tool also run `wr-flatten-trim.py` on the outputs, or does that stay in
   the five-plate pack exporter? (Spec: stays there; this tool writes opaque PNGs.)
4. Per-scene material swaps (different floor per scene) — out of scope v1; confirm.
5. Icon: reuse `scenes-proposal` sprite or draw a dedicated one?
