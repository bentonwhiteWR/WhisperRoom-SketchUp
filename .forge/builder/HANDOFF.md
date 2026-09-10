# HANDOFF — Builder → Benton: per-scene ANNOTATIONS, rev 2 (hybrid), shipped as 1.20.0

2026-09-09. Spec `.forge/scoper/scene-annotations.md` rev 2, approved by Benton
("cool that works"). Every one of the spec's nine steps is shipped; step 9
(live verification) is handed back as a loadable script because there is no
bridge from the assistant's session into SketchUp.

## Produced

**New**
- `scripts/wr-scene-annotations.rb` — `WR_SceneAnnotations`, the standalone
  tool and the engine the proposal package's column calls. `inventory`,
  `apply`, `apply_selection`, `keys_for_selection`, `reveal`,
  `move_selection_to_set`, `pages_not_saving`, `fix_pages`, and its own
  `UI::HtmlDialog` mirroring wr-scene-walls'.
- `scripts/wr_tools/wr-ico-scene-annots.svg` — panel icon.
- `.forge/builder/verify-scene-annotations.rb` — the live acceptance list,
  **for Benton to run** (see Open questions).

**Changed**
- `scripts/proposal-scenes.rb` — `ANNOT_RE`, `annot_tags(model)`,
  `annot_set_name(user)`. `ANNOT_TAGS` unchanged and still the fallback.
- `scripts/proposal-package.rb` — the ANNOTATIONS column (header, row button,
  modal markup/CSS/JS, six `annots*` callbacks), `annot_tags`,
  **`annot_push` closing the Untagged client-safe hole**, `annot_pop` restoring
  both halves, `annot_reapply` on the `after_switch` hook,
  `loose_annotations`, `hidden_annot_tags`, `collect_hidden_annotations`,
  `collect_annotations` learning the 3D-text label, two `MANIFEST_NOTES`
  entries, the two new manifest row fields, the relabelled dropdown.
- `scripts/wr-mode.rb` — `snapshot` reads the live family; `to_mode` fills a
  family tag the stored snapshot never heard of at that mode's polarity.
- `scripts/wr-preflight.rb` — `check_dims` sees live `WR-Dims-*` sets.
- `scripts/rbtest-proposal.py` — st5-st8, mr6, mr7, annot5-7 + the shims.
- `scripts/rbtest-lights.py` — `WR_ProposalScenes` shim for the lifted
  `snapshot` (it broke without one; that is the harness doing its job).
- `scripts/wr_tools/icon-map.json`, `ico-labels.txt`, `VERSION` → 1.20.0.
- `DEVLOG.md` — the 1.20.0 entry, with the probe output verbatim.

## Read-first

1. `scripts/wr-scene-annotations.rb` header — the two mechanisms, and why the
   probe's one FAIL makes the tool a hybrid.
2. `scripts/proposal-package.rb` `annot_push` → "THE UNTAGGED HOLE, CLOSED" —
   the customer-facing fix and its capture-before-mutate discipline.
3. `annot_reapply` right below it — why the image lane needed a re-assert.
4. `scripts/rbtest-proposal.py` docstring "THE ANNOTATION HALF (1.20.0)" — the
   seven mutations, each run and each caught.

## Assumptions

- **observed (probe, SketchUp 26.2.243, 9 Sep 2026):** scenes save per-tag
  visibility and per-entity hidden state for screen text, leader text, linear
  dimensions and 3D-text groups; mask 384 leaves the camera identical;
  **Untagged cannot be hidden.**
- **observed (this build):** 116 checks green in `rbtest-proposal.py` under
  SketchUp's own CRuby; 13 harnesses green; 68 files parse; both dialogs'
  JavaScript parses under `node --check`.
- **derived:** the image lane's page switch undoes a per-entity hide, because
  that is the same mechanism the feature rides on — hence `annot_reapply`.
  Not observed live.
- **assumed:** `page.update(384)` and `page.set_visibility` in one Apply do not
  interfere. The probe proved each **separately**; the combination is what
  `scene.set_hidden_per_scene` in the verification script checks.
- **reported:** V-Ray ignores SketchUp Text/Dimensions and renders 3D-text
  geometry only when visible. Untested here.

## Open questions

1. **Run `.forge/builder/verify-scene-annotations.rb` in an Untitled model and
   paste the output back.** Until then the picker, the modal, the combined
   tag+entity save and the client-safe sweep are UNVERIFIED LIVE.
2. The Scoper's forks were taken at its own recommendation (Benton approved the
   design as mocked without answering them one by one): **Q1** separate
   ANNOTATIONS column; **Q3** new sets named `WR-Notes-<name>`; **Q4**
   Client-safe stays the dropdown default; **Q6** header "ANNOTATIONS", button
   "Hide notes"; **Q7** set members behind an expand arrow; **Q-CS** the
   Untagged client-safe hole closed in this build. Any of them is cheap to
   reverse — say which.
3. `DEPTH = 2`: a callout buried more than two containers deep is not listed
   and is not swept by client-safe. A set still hides it (tag visibility has no
   depth limit) and the log now says so by name. Raise DEPTH if real models
   bury callouts deeper.
4. The V-Ray lane with a hidden `label:` group is untested — worth one render
   in the acceptance run.
