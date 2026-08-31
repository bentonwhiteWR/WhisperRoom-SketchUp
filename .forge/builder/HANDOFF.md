# Builder HANDOFF — proposal-package manifest + doc-path checker (2026-08-31)

Goal reconfirmed against `.forge/GOAL.md` before writing this: this is the
proposal-speed half of the mission (GOAL "Speed" / Done-means 4), built to the
Researcher's ranked cuts in `.forge/researcher/proposal-image-step-timing.md`
§6 — item 1 (manifest + dimension sidecar at export time) and the reporting
half of item 3 (the path table). Plugin at **1.10.7**.

**SketchUp was closed for this whole session. The manifest has NEVER been
written by a real export.** The pure half is proven offline (101/101 in
`scripts/rbtest-proposal.py`, mutation-checked); the impure half is parse-
checked only. The checklist below is the missing proof — run it when Benton
opens SketchUp.

## Produced

| file | what |
|---|---|
| `scripts/proposal-package.rb` | Writes `manifest.json` beside the images on every batch exit (done / cancelled / failed). Pure half: `booth_name?`, `dim_display`, `shown_annot_tags`, `manifest_rows` (+ `MANIFEST_FORMAT`, `MANIFEST_NOTES`). Impure half: `dim_anchor`, `dim_span`, `ent_tag`, `collect_annotations`, `page_hidden_tags`, `booth_groups`, `write_manifest`, called from `finish` after the restores. `@results` ok-rows now carry `:width`/`:height`; `start_run` captures `@manifest_plan`. |
| `scripts/rbtest-proposal.py` | +21 checks (bn1-7, dd1-6, st1-4, mr1-4) over the four pure methods, lifted verbatim. Mutation-checked: lost→ok, width-default, client-safe-ignored each make a named check FAIL (run, 31 Aug). |
| `scripts/check-doc-paths.py` | Read-only: which documented external paths resolve on THIS machine. Fixes nothing by design. |
| `scripts/wr_tools/VERSION` | 1.10.6 → **1.10.7** (any change under `scripts/` bumps it). |
| `DEVLOG.md` | 1.10.7 entry under 2026-08-31. |

Prior mission's handoff preserved at `.forge/builder/HANDOFF-bridge-190.md`.

## Manifest shape (format 1)

Same serialisation/name/placement as `scripts/export-component-art.rb:465` and
`scripts/orbit-export.rb:226`: `JSON.pretty_generate` → `manifest.json` beside
the PNGs. Header: `format`, `tool`, `generated`, `model`, `model_path`,
`booth_groups`, `width`/`height`, `size_source`,
`annotations_hidden_in_images`, `annotation_scope`, `field_notes`. `images[]`:
`file`, `scene`, `scene_index` (scene-tab position), `lane`, `status`
(`ok`/`failed`/`skipped`/`cancelled`/`lost`), `detail`, `width`/`height`
(null = not recorded), `annotation_tags_shown` (+`annotation_note`).
`annotations[]`: `kind` (`linear_dimension`/`radial_dimension`/`text`), `tag`,
`text` (verbatim; `<>` is SketchUp's auto-value placeholder), and for linear
dims `measured`/`measured_in`/`display` — or null + `note` when anchors are
unreadable. **Nothing invents a number; absence fails by name.**

## Live-verification checklist (run against an open SketchUp, scratch model)

1. Open a scratch model that has proposal scenes (`proposal-scenes.rb`) and
   room dimensions (`auto-dimension.rb`), plus a booth group. Ruby Console:
   `load "C:/.../scripts/proposal-package.rb"` (forward slashes).
2. Mark 2–3 scenes Image (include 02-dimensioned), pick a scratch output
   folder (NOT `C:\Users\bento\Desktop\ProposalFiles`), Export.
3. Confirm `manifest.json` appears beside the PNGs and the run window logs
   "manifest.json written - N image row(s), M annotation(s)".
4. **Dimension text round-trip (the point of the whole change):** open the
   manifest, take three `linear_dimension` rows' `display` values, and compare
   each against the same callout read off the exported 02-dimensioned PNG at
   zoom. They must match character-for-character. If a chain dimension
   disagrees, the `measured` straight-line-distance assumption is wrong for
   that dim type — record the discrepancy, do not patch it silently.
5. **`Page#layers` semantics (assumption A2 below):** on the 02-dimensioned
   row, `annotation_tags_shown` must be `["WR-Dims", "WR-Dims-Doors"]`-ish
   (what the scene actually shows) when the batch ran with Annotations=draft;
   on the clean plates it must be `[]` or absent tags only. If the lists read
   INVERTED, `page_hidden_tags` is returning shown-not-hidden — fix there.
6. Run once with the default client-safe annotations: manifest says
   `annotations_hidden_in_images: true` and every image row's
   `annotation_tags_shown` is `[]` with the client-safe note.
7. Cancel a batch mid-run: manifest still written; the un-run rows read
   `cancelled`/`lost`, never `ok`.
8. `booth_groups` names the booth group(s) actually in the model, verbatim.
9. A render-lane row (when V-Ray is trusted): `width`/`height` equal the
   actual file's pixels (`python scripts/image-qa.py <dir>` prints them).
10. Feed the manifest to the assembly flow once: captions drafted from
    `annotations[].display`, then SPOT-CHECKED against the renders (the
    caption discipline stays; only its input changed).

## Assumptions (every one unverified live)

- **A1** `DimensionLinear#start`/`#end` yield something `dim_anchor` can read
  (a `Point3d` directly, in an array, or via `.position`). If not, rows come
  out `measured: null` with the unreadable note — honest, but the sidecar's
  value is gone; fix `dim_anchor` against the real return shape.
- **A2** `Sketchup::Page#layers` returns the page's HIDDEN layers (API doc
  wording). Checklist step 5 settles it.
- **A3** Straight-line anchor distance equals the displayed value for the
  axis-aligned dimensions the WR tools draw. Step 4 settles it; angled/aligned
  hand-drawn dims may differ — the manifest's `field_notes` say so.
- **A4** Model-space top level (`model.entities`) is where all proposal-
  relevant callouts live (it is where auto-dimension, dimension-booth,
  dimension-selection and build-room's notes draw). Nested annotations are
  out of scope and `annotation_scope` says so.
- **A5** `Sketchup.format_length` is safe to call during `finish` (no model
  write). It only reads unit options.

## Open-questions

1. Researcher's §6 items 2 (committed reference pack), 4 (flatten/trim/resize
   script), 5 (overflow pre-check) — **untouched, deliberately out of scope.**
2. `skills/whisperroom-proposal/SKILL.md` and `reference/proposal-playbook.md`
   still mandate full pixel transcription; once the manifest is live-proven,
   the GOAL item-5 rewrite should change §6 caption steps to "draft from
   `manifest.json`, spot-check against the render" and add the manifest to
   the playbook's inputs. Not edited here, per instructions.
3. `check-doc-paths.py` findings worth a Benton decision (report, not edits):
   `CLAUDE.md:50` (`...\WhisperRoom Proposals\build-v2.js`) — the generator
   demonstrably lives in-repo at `proposals/build-v2.js` now, so that row
   looks genuinely superseded, not merely on-the-other-machine;
   `reference/booth-models.md:3` and `reference/sketchup-drawing.md:123`
   hard-code the laptop `C:\Users\bento\Documents\Claude\...` root in docs
   that otherwise obey the `<CLAUDE>` rule; and three docs still name three
   different client-config destinations (researcher §4).
4. Whether the render lane is trusted enough for step 9 remains the parked
   look-dev mission's question, not this one's.
