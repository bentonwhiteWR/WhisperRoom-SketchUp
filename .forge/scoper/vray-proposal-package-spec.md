# Spec — V-Ray proposal package skill ("Proposal package…")

2026-08-27, Scoper. Mockup: `.forge/scoper/vray-proposal-mockup.html` (open it in a
browser — it is clickable and is the design of record for the dialog).

## The problem in one sentence

Producing a proposal's image set today means hand-driving V-Ray per scene and
hand-exporting the rest; Benton wants **one button** that lists every scene, lets him mark
each one *V-Ray render* / *plain image* / *skip*, pick a folder, define draft→render
material swaps for the V-Ray pass only, and writes `<Scene Name>.png` /
`<Scene Name> render.png` into that folder — leaving the model exactly as it was.

## What already exists and is REUSED, not rebuilt

All paths project-root-relative. Provenance: everything in this table is **observed** (read
in full during scoping) unless noted.

| Existing thing | What this feature takes from it |
|---|---|
| `scripts/list-scenes.rb` | The UI model Benton named: searchable/sortable scene table in a `UI::HtmlDialog` built with `set_html`, the CSS token set (`--accent:#ee6216` etc.), the multi-word AND search + `1-40`-style number filter, the "All shown / Clear" bulk pattern. |
| `scripts/wr-materials-swap.rb` (`WR_MaterialsSwap`) | The whole material-swap mechanism: three named slots (`WR-Floor-Render`, `WR-Wall-Render`, `WR-Door-Render`), fills stored per model in attribute dict `WR_MaterialsSwap`, `to_render`/`to_draft` atomic swaps, `fill`/`set_fill`/`fills`, unmapped-surface reporting. **Do not duplicate any of it.** |
| `scripts/wr-mode.rb` (`WR_Mode`) | `to_render`/`to_draft`/`to_mode`/`current` — materials + dimension tags + style + shadows move together, snapshots per model in dict `WR_Mode`. This is the ONLY way this feature changes model state, so the revert path is the one that already exists. |
| `scripts/export-scenes.rb` (`WR_ExportScenes`) | `export_pages(model, plan, cfg)` — the single `view.write_image` code path in the toolset (pulled out for exactly this kind of caller), plus the `FORBIDDEN` filename-sanitising rule and the `select_pages` semantics. |
| `scripts/wr-pack-export.rb` (`WR_PackExport`) | The HtmlDialog-command pattern (callbacks, `renderPlates`-style re-render), the preflight-gate flow, the overwrite Yes/No/Cancel prompt, the save-mode/restore-in-ensure discipline, and the per-page attribute-dict marking precedent (`page.set_attribute`). This new tool supersedes its V-Ray *stub* lane for the general case; `wr-pack-export.rb` itself is NOT modified. |
| `scripts/wr-preflight.rb` (`WR_Preflight`) | `check(model)` rows shown before export, Continue/Cancel is the operator's call. |
| `scripts/wr-folder.rb` (`WR_Folder`) | Folder history (`read_list`/`remember`) under a new key `'package'`. The dropdown+Browse workaround exists because `UI.inputbox` has no Browse button — an HtmlDialog **does not have that limitation**, so here the folder field is a text input + real Browse button whose callback calls `UI.select_directory` directly, and `WR_Folder.remember`/`read_list` keep the history shared. |
| `scripts/probe-vray.rb` | The gate for the V-Ray lane. See "The V-Ray call — load-bearing and unverified" below. |
| `reference/vray-ruby-api.md` | The documented batch-render surface (reported, see below). |

## New files

1. **`scripts/proposal-package.rb`** — the whole feature. Module `WR_ProposalPackage`.
   Header:

   ```
   # @title Proposal package...
   # @cat V-Ray renders
   # @rank 0
   ```

   `@rank 0` sorts it first in the V-Ray renders category without renumbering the five
   scripts already ranked 1–5 (observed: `main.rb` line ~160 accepts any integer,
   `-?\d+`; lower sorts first). Autorun guarded with
   `WR_ProposalPackage.run unless $wr_no_autorun`, constants guarded with the
   `remove_const` reload pattern, dependencies loaded under the `$wr_no_autorun` save/
   restore exactly as `wr-pack-export.rb` does:
   `wr-preflight.rb` (pulls in `wr-mode.rb` → `wr-materials-swap.rb`, `wr-shading.rb`,
   `proposal-scenes.rb`), `export-scenes.rb`, `wr-folder.rb`.

2. **`scripts/wr_tools/icon-map.json`** — add `"proposal-package.rb": "scenes-proposal"`.
   Reusing an existing sprite id is established practice (observed:
   `name-selection-after-scene.rb` reuses `names-replace`). A dedicated
   `wr-ico-package.svg` is a nice-to-have the Builder should NOT block on.

3. **`scripts/wr_tools/VERSION`** — bump (house rule: any change under `scripts/`).

Deployment reality (observed in `main.rb` `CANDIDATES` + CLAUDE.md): the tool script
itself loads live from a repo checkout — `git pull` is enough there. The `icon-map.json`
edit is inside `wr_tools/` and needs `install-plugin.py` + a SketchUp restart; until then
the tool appears with the generic icon, which is cosmetic. So the feature is testable
without a restart on Benton's machine; the restart is only for the icon and the version
banner.

---

## The dialog

`UI::HtmlDialog`, `set_html` (no second file to install — same reasoning as
`list-scenes.rb`), `preferences_key 'com.whisperroom.proposalpackage'`, resizable,
~700×760 default. Layout top to bottom (see the mockup, which is authoritative for look
and interaction):

1. **Header** — model title, live counts ("18 scenes · 4 render · 6 image").
2. **Search box** — reuse `list-scenes.rb`'s semantics verbatim: every whitespace term
   must match scene name (AND, substring, case-fold); a query with `,` or `-` filters to
   scene numbers; a bare number is both at once. (No component column here — search is
   over scene names only.)
3. **Bulk strip** — `Shown → Render`, `Shown → Image`, `Shown → Skip`. Bulk acts on the
   *filtered view*, same as list-scenes' "All shown".
4. **Scene table** — columns:
   - `#` — position in `model.pages`, 1-based, never re-sorted out of pages order on
     load; sorting is a view (list-scenes rule).
   - `SCENE` — name, with search-term `<mark>` highlighting (reuse list-scenes' `hl`).
   - `MODE` — a three-state segmented control per row: **Skip / Image / Render**.
     Skip is the default for an unmarked scene.
   - `FILE` — live preview of the exact output filename (after sanitising, suffixing and
     collision numbering), so the naming rule is visible before anything is written.
     Blank for Skip rows.
   - `→` — activate-scene arrow, exactly as list-scenes (callback `activate`).
5. **Materials for the V-Ray pass** — collapsible section, three rows, one per
   `WR_MaterialsSwap` slot:
   `Floor (0128_White) → WR-Floor-Render: [dropdown]`, likewise Wall and Door. The
   dropdown lists `(unset)` + every material name in the model
   (`model.materials.map(&:name).sort`), current value from `WR_MaterialsSwap.fill`.
   Changing it calls `WR_MaterialsSwap.set_fill` immediately (per-model persistence is
   free — that dict already survives save/reopen). A one-line note in the section:
   *"Applied only while the V-Ray scenes render; reverted before this window says done.
   A slot left (unset) leaves those surfaces drafting and is reported by name."* This is
   the same slot model as the draft-to-render button because it IS the same code.
6. **Output row** — folder text field + **Browse** button (callback →
   `UI.select_directory`, seeded from `WR_Folder.read_list('package').first`), image
   width field (plain lane only, default 2400, clamp 200–6000 as `export_pages` does),
   and an **If a file already exists** dropdown: `Ask` (default) / `Overwrite` /
   `Skip existing`.
7. **Footer bar** — status/progress strip (current scene, n of m, per-row results
   appended to a small log), **Cancel** (visible only during a run), **Close**,
   **Export package** (primary, orange).

Persistence of dialog state:

| What | Where | Survives restart? |
|---|---|---|
| Per-scene mode | On the `Sketchup::Page`: dict `WR_ProposalPackage`, key `mode`, value `'render'`/`'image'` (key absent ⇒ skip) | Yes — saved in the model, travels with the file, immune to scene reordering because it rides the page object, not the index. Precedent: `wr-pack-export.rb`'s `vray` flag. |
| Slot fills | `WR_MaterialsSwap`'s own model dict — unchanged | Yes (already built) |
| Folder, width, overwrite policy | `Sketchup.write_default('WR_ProposalPackage', …)` + `WR_Folder.remember('package', dir)` | Yes — plugin settings, per machine (a folder path is machine-specific, so per-model storage would be wrong). Follow `wr-folder.rb`'s storage warnings: strip `"` before writing, rescue `Exception` on read. |

Mode writes happen on click (a `mark` callback with `{n, mode}` payload → resolve
`model.pages.to_a[n-1]`, `set_attribute`), not batched at export time — closing the
dialog must not lose a marking session.

---

## Filename rule — exact

Given scene name `S` and lane:

1. `base = S.strip.gsub(FORBIDDEN, '-').sub(/[. ]+\z/, '')` where
   `FORBIDDEN = /[<>:"\/\\|?*\x00-\x1f]/` — the rule `export-scenes.rb` already uses:
   only what Windows genuinely refuses is replaced with `-`; spaces, brackets,
   ampersands survive verbatim; trailing dots/spaces stripped (Windows drops them
   silently).
2. If `base` is empty after that: `base = "scene-<n>"` (n = scene number).
3. V-Ray lane: `base += " render"` — appended **after** sanitising (the suffix contains
   no forbidden characters), space included, exactly as Benton phrased it:
   `01-exterior.png` vs `01-exterior render.png`.
4. **Collision within one run**: one `used` map across BOTH lanes (export-scenes'
   pattern): second and later occurrences become `base (2)`, `base (3)`. This also
   covers the corner where a scene literally named `X render` (image lane) collides
   with scene `X` (render lane) — both feed the same map, the second gets `(2)`, and
   the FILE column shows it before export.
5. **Collision with a file already on disk**: per the overwrite policy. `Ask` = one
   upfront `MB_YESNOCANCEL` listing the existing names (wr-pack-export's wording: Yes
   overwrites, No skips just those and keeps going, Cancel stops). Skipped-because-
   existing rows are reported as `skipped`, never silent.

All output is `.png`. Plain lane background is **Opaque** (fixed, not an option): the
proposal playbook forbids transparent PNGs reaching a pack, and this tool's output IS
the pack input.

---

## The batch — two passes, one mode swap each way

Model state is changed only through `WR_Mode`, and exactly twice per run:

```
plan      = ordered rows {page, n, base, lane} for every non-skip scene
saved     = WR_Mode.current(model)         # 'draft' | 'render' | 'unknown (never toggled)'
prev_page = model.pages.selected_page
prev_cam  = view.camera.clone

PASS 1 (image rows, if any):   WR_Mode.to_draft(model)
    each row → WR_ExportScenes.export_pages(model, [row],
               {'dir'=>dir, 'width'=>width, 'bg'=>'Opaque', 'over'=>'Yes'})
    (export_pages already zeroes TransitionTime, selects the page, restores
     rendering options; 'over' is 'Yes' because the on-disk policy was already
     resolved upstream — rows the user declined are not in the plan)

PASS 2 (render rows, if any):  WR_Mode.to_render(model)
    → surfaces with an unfilled slot come back in :unmapped; append them to the
      log BEFORE the first render so "floor still white" is named, not discovered
      in the image
    each row → pages.selected_page = page; view.refresh; V-Ray render; save PNG

FINISH (always — success, failure, cancel):
    WR_Mode.to_mode(model, saved) if saved is 'draft' or 'render'
    pages.selected_page = prev_page; view.camera = prev_cam
    summary to console + dialog log
```

Why two passes and not per-scene flipping: each `to_render`/`to_draft` sweeps the whole
model and commits an operation; wr-pack-export pays that per plate because plate 02 needs
draft *between* render plates. Here the lanes are separable, so one swap each way is both
faster and halves the exposure of the risky step.

### Draft is the plain-image state — a decision made on Benton's behalf

Benton: "If I'm just taking the screenshot of the basic SketchUp layout, like the floor,
it might be just white." That is the draft state, so the image lane forces
`WR_Mode.to_draft` rather than exporting whatever mode the model happens to be in.
Derived from his words, but it IS a decision — logged in Open-questions. (If a model has
never been toggled, `to_draft` on an already-draft model is a near-no-op: the swap finds
nothing on render fills.)

### Progress and cancel — timer-driven, never a blocking loop

SketchUp runs Ruby on the UI thread; a long `each` loop would freeze the dialog, so no
progress would paint and Cancel could never be clicked. The batch is therefore a **state
machine stepped by `UI.start_timer(0.1, true)`**: each tick does at most one unit of work
(export one image row / start one render / poll one running render), posts progress to
the dialog with `execute_script`, checks a `@cancel` flag, and on the last row (or on
cancel, or on any raise) runs the FINISH block and `UI.stop_timer`. The FINISH block is
the single exit — there is no path out of the batch that skips the mode restore. Cancel
semantics: takes effect between units; if a V-Ray render is in flight, call
`renderer.stop` (reported API) and then finish. The Export button is disabled while a
run is live; Close during a run behaves as Cancel first.

### One scene fails → the batch continues

House rule (GOAL.md: "No silent fallback"): a failed row is recorded
`{status:'failed', detail:…}` with the reason (`write_image returned false`,
`save_vfb_image raised …`, `render did not finish`), the loop moves on, and the final
summary names every failure as prominently as the successes — messagebox + console +
dialog log. The batch stops early only for: Cancel, preflight Cancel, or the mode swap
itself raising (at which point nothing has been half-exported: `WR_MaterialsSwap` swaps
are atomic per operation — observed, `start_operation`/`abort_operation` in
`to_render`/`to_draft`).

### Preflight

If any rows are planned, run `WR_Preflight.check(model)` first, show failing rows,
Continue/Cancel is the operator's call — verbatim the wr-pack-export flow.

---

## The V-Ray call — load-bearing and UNVERIFIED. Treat this as the risk.

Everything below is **reported** from `reference/vray-ruby-api.md`, which transcribed the
YARD docs shipped at
`C:\Program Files\Chaos\V-Ray\V-Ray for SketchUp\extension\documentation\` on 19 Aug 2026.
Those docs are not on this (desktop) machine — I checked (observed: the
`C:\Program Files\Chaos` path does not exist here), so I could not re-read signatures.
`scripts/probe-vray.rb` exists precisely to close this gap and **has never been run**.

The documented calls the render lane is built on (all `VRayRenderer` unless noted):

- `VRay::Context.active` → context; `.renderer`, `.scene`, `.model`
- `renderer.start`, `renderer.stop`, `renderer.wait`
- `renderer.in_process?`, `renderer.state` — completion polling for the timer loop
- `renderer.save_vfb_image` — write the finished frame to the target path
- `renderer.subscribe` / `unsubscribe` — progress callbacks (optional upgrade over polling)

**Builder gate — do not write the render lane blind.** Step 0 of the build is: Benton
runs `probe-vray.rb` in a live SketchUp (cold, then after one manual render) and pastes
the console output. That answers, in order of how much design hangs on each:

1. Is `VRay::Context.active` non-nil cold? → decides whether the tool can start a render
   pass in a fresh session or must refuse with instructions.
2. Is `start` blocking or async? → decides whether the timer polls `in_process?` or the
   whole pass is synchronous (in which case progress is per-scene, not per-frame, and
   mid-render cancel is impossible — say so in the UI).
3. `save_vfb_image` arity/behaviour → the actual write call.
4. Does the render honour the ACTIVE SCENE's camera once `pages.selected_page` is set
   and the view refreshed? (**assumed** — V-Ray renders the viewport camera; probe/first
   manual test must confirm before the lane is called done.)

**Runtime precondition in the shipped tool**: when the plan contains render rows, check
`defined?(VRay)` and `VRay::Context.active` before starting. On failure, a named message
— *"V-Ray is not available in this session (no active context). Render one frame by hand
in V-Ray, then run this again — or export the image rows only."* — with buttons
`Images only` / `Cancel`. Never a half-run that dies mid-pass.

### Render resolution and preset — where they come from (v1)

- **Plain lane**: `width` field × viewport aspect (`view.vpheight/vpwidth`), the
  `export_pages` contract. Same "size the window to the aspect you want" note as
  `export-scenes.rb`, shown in the dialog footer.
- **V-Ray lane**: v1 does **not** touch V-Ray output settings — resolution, quality
  preset and denoiser are whatever the V-Ray Asset Editor holds, and the dialog says so
  next to the render count. Rationale (derived): the documented route to set them
  (`scene.change` on a `/SettingsOutput` plugin) is doubly unverified — unprobed API *and*
  an assumed plugin name — and a wrong write into V-Ray settings persists in the model.
  Pinning resolution from the dialog is the first v2 item, gated on the probe. Logged in
  Open-questions.

---

## The revert — highest-risk part, handled like it

The only mutation this tool makes to the model is `WR_Mode.to_render` (materials via the
slot fills, dimension tags off, style/shadows), and the guarantees, in layers:

1. **Single exit**: the FINISH block (mode restore + page/camera restore + summary) runs
   on completion, on cancel, on any raised error — the timer step is wrapped in
   begin/rescue that routes every outcome there. No code path returns from the batch
   without passing through it.
2. **Atomicity below**: each swap is one `start_operation`/`commit_operation`; a raise
   mid-sweep aborts the operation (observed in `wr-materials-swap.rb`), so the model is
   never left half-swapped.
3. **Restore failure is loud**: if `WR_Mode.to_mode(saved)` itself raises in FINISH,
   print the `*** could not restore original mode` console line AND a messagebox naming
   the state the model was left in and the recovery ("press Toggle Draft/Render mode") —
   wr-pack-export's pattern, promoted to a messagebox because here it can follow a long
   unattended run.
4. **Crash/quit survivability**: `WR_Mode` records `current` in the model's own
   attribute dict, so even if SketchUp dies mid-pass, the existing
   *Toggle Draft / Render mode* button reads the true state and flips it back. The
   dialog's materials section carries one line saying exactly that.
5. **What "reverted" means for materials**: `to_draft` only touches surfaces whose
   material is a configured slot fill (observed) — a hand-painted feature wall is never
   dragged to drafting blue. Symmetrically: a surface the operator painted with a slot's
   fill material *by hand, meaning it to be permanent*, WOULD be reverted; that is the
   existing, documented behaviour of the shared machinery, not a new hazard, and it is
   the price of "by name, not by object".

Undo: the run commits several operations (two swaps + tag/style writes inside them), so
it is not one Ctrl+Z — the restore-by-construction above is the guarantee, and the
dialog does not claim otherwise.

---

## Report at the end of a run

Console + messagebox + dialog log, wr-pack-export's shape:

```
PROPOSAL PACKAGE — <n> exported, <k> skipped, <f> FAILED
  <dir>
  ok      01-exterior render.png        (V-Ray)
  ok      02-dimensioned.png            (image, 2400x1500)
  skip    05-plan.png                   (already existed, overwrite declined)
  FAILED  Interior Desk render.png      (save_vfb_image raised …)
  unmapped: Booth > Floor  (0128_White -> WR-Floor-Render: no fill set)
```

Failures and unmapped surfaces are never summarised away — every one is named.

---

## Out of scope for v1 (name them so nobody half-builds them)

- Setting V-Ray resolution/preset from the dialog (v2, gated on probe).
- Flatten/trim post-processing (`wr-flatten-trim.py`) — stays in `wr-pack-export.rb`'s
  five-plate pipeline; this tool writes opaque PNGs, which do not need flattening.
- Interior lighting (GOAL stream 5), sun aiming, scene creation (that is
  `proposal-scenes.rb`'s job), and any change to `wr-pack-export.rb`.
- Per-scene material swaps (different fills for different scenes) — the slot model is
  per-model, one set per run.

## Acceptance checklist

Syntax: every touched `.rb` passes `scripts/rbparse.py` (rbcheck.py does not count).
Behaviour — in a live SketchUp on a model with ≥6 scenes:

- [ ] Panel shows "Proposal package…" first in *V-Ray renders*; button opens the dialog;
      every scene listed in tab order with correct numbers.
- [ ] Search: multi-word AND works; `1-4,7` filters to numbers; bare number keeps both
      behaviours (list-scenes parity).
- [ ] Mode marks persist: mark scenes, close dialog, reopen → marks intact; save model,
      reopen SketchUp → marks intact; reorder scene tabs → marks follow the scenes.
- [ ] FILE column shows the exact final name, including ` render` suffix, `-` for
      forbidden characters, and `(2)` on a deliberate collision (rename a scene to
      collide and watch the column).
- [ ] Browse opens a real folder browser; chosen folder survives restart; width and
      overwrite policy survive restart.
- [ ] Materials section shows the three slots with current fills; setting a fill here is
      visible in the old draft-to-render inputbox and vice versa (same dict).
- [ ] Run with only image rows: model flips to draft, PNGs land opaque at width ×
      viewport aspect, named `<Scene Name>.png`, model back in its starting mode,
      original scene + camera restored.
- [ ] Run with render rows and V-Ray unavailable: named refusal, `Images only` path
      works, nothing half-runs.
- [ ] Run with render rows and V-Ray available: each marked scene renders from ITS
      camera, lands as `<Scene Name> render.png`, slot materials visible in the render,
      model back in starting mode afterwards with drafting materials on the floor/walls.
- [ ] A slot left unset: run proceeds, unmapped surfaces named in log and summary.
- [ ] One scene made to fail (e.g. lock one target file with it open in a viewer,
      policy=Overwrite): its row reports FAILED with a reason, the rest complete, summary
      names it.
- [ ] Cancel mid-batch: run stops at the next unit, FINISH restores mode/scene/camera,
      partial results reported honestly.
- [ ] Existing files + policy Ask: Yes/No/Cancel behave per spec; No skips exactly those
      rows and reports them.
- [ ] `scripts/wr_tools/VERSION` bumped; change committed and pushed.

## Provenance summary

- **observed** — every script and reference file named above was read in full during this
  scoping; the panel registration mechanics (`@cat`/`@rank`/`icon-map.json`/`SKIP`),
  `export_pages`' contract, `WR_MaterialsSwap`'s atomicity, `WR_Mode`'s snapshot dicts.
- **reported** — the entire V-Ray API surface (`reference/vray-ruby-api.md`, itself
  transcribed from docs; twice removed from a live call). Also: several reused scripts
  (`wr-mode.rb`, `wr-materials-swap.rb`, `wr-pack-export.rb`, `wr-preflight.rb`) carry
  their own "THIS FILE HAS NOT BEEN RUN" banners — the machinery this spec reuses is
  parsed, not proven.
- **assumed** — that V-Ray renders the active scene's camera after
  `pages.selected_page=` + `view.refresh` (gate: probe + first manual test); that draft
  mode is what Benton means by "normal images".
