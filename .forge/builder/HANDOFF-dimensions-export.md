# HANDOFF — `_dimensions.json` export from `angled-component-art.rb`

**Builder, 2026-08-26.** Built to
`C:\Users\bento\Documents\Claude\WhisperRoomQuote\.forge\scoper\BRIEF-sketchup-dimensions-export.md`.

**This is NOT part of `.forge/GOAL.md`.** That goal is the Enhanced (IEP) booth build — 6060 E,
inner shells, `IEP_WALL_LIFT`. This task is the component-art export feeding the Prism Gauge in
the `WhisperRoomQuote` repo. Different mission; the tree is dirty with both because another
agent is working the GOAL at the same time.

**The export is UNRUN. It has never produced a real `_dimensions.json`.** There is no Ruby on
this machine outside SketchUp and I cannot open SketchUp.

---

## Produced

| file | what |
|---|---|
| `scripts/angled-component-art.rb` | **+404 lines, 0 removed.** Strictly additive. |
| `DEVLOG.md` | one `### Added` entry under the existing `## 2026-08-26` heading. Nobody else's text touched. |
| `.forge/builder/emit-dimensions-fixture.py` | builds a fixture `_dimensions.json` in the exact emitted shape; cross-checks its JSON keys against the ones in the `.rb`. |
| `.forge/builder/check-dimensions-ingest.js` | runs that fixture through `loadDimensionsJson` **copied verbatim** from `prism-audit.js:127-148`. 25 assertions. |
| `.forge/builder/fixture/_dimensions.json` | the generated fixture (regenerate, don't hand-edit). |

**Not touched:** `scripts/wr_tools/VERSION` — already at **1.6.28** from the other agent's
change in this session, so it was left alone as instructed. `WhisperRoomQuote` — read only.
`_diagnostics.txt`'s format and content. Any scene name. The `@tab` header (there isn't one;
the script stays in TOOLS).

## What was added, in the `.rb`

Three blocks, all inside `module WR_AngledArt`:

1. **Visible-geometry walk** (after `needed`, before the file-naming section):
   `VIS_MAX_DEPTH`, `VIS_MAX_NODES`, `vis_skip?`, `vis_facing`, `vis_walk`, `visible_box`,
   `facing_of`, `sub_parts`, `sub_part_name`.
2. **The emitter** (after `dump_diagnostics`): `jstr`, `j3`, `jbox`, `jfacing`, `ZERO_BOX`,
   `dump_dimensions`.
3. **The call** in `run`, immediately after the `dump_diagnostics` call — so it is written on a
   **dry run** too, because measuring is all it needs.

## Read-first, if you pick this up

- `scripts/prism-audit.js:127-148` in `WhisperRoomQuote` — **the contract**, and it disagrees
  with the prose in two places that changed the design (see Assumptions).
- The header comment on the visible-geometry block in `angled-component-art.rb` — it carries
  the whole argument for why faces-only is the rule.
- `.forge/researcher/declared-vs-prism.md` §3 (the original spec) and
  `.forge/scoper/masking-tool-spec.md` §11, both in `WhisperRoomQuote`.

## Assumptions — every one of these is unverified against the real model

1. **A silhouette is made of faces.** Only faces and placed images grow the box; loose edges,
   construction geometry, text and dimensions do not. This is what kills the door swing. It is
   *derived* from the researcher's measurement (raw bounds 29.5–61.9 in vs a silhouette inside a
   1-in prism at ≤3%), not observed in the model. If a door's leaf turns out to be a real solid
   drawn open, the render shows it too and the audit will agree with the export anyway — but the
   number will be the swung box, not the slot.
2. **Model z = 0 is the booth floor plane**, so `z_base` is `bbox.min.z`.
3. **Front-face-out modelling**, for `facing` only. Nothing else depends on it.
4. **`scene` must be the PNG stem, not `page.name`.** `parseDiagnostics` strips a leading
   `"ENH "` from the scene label to reach the stem; `loadDimensionsJson` does no normalising at
   all. So `scene` is emitted as `safe_name(definition name)` — what the exporter actually names
   files from — and the scene label rides along as `scene_name`. Without this the ENH batches
   would join on the text path and silently fail to join on the JSON path.
5. **Rule 3 is carried as `parts`, not as duplicate rows.** `out.set(r.scene, …)` keys on
   `scene`, so two rows sharing a scene name overwrite each other silently. The multi-part test
   is narrow on purpose: the subject draws no faces of its own and holds ≥2 visible
   instances/groups.
6. **Tag visibility divergence.** The walk honours tag visibility (the spec says "skip … layers
   off"); pass 2 forces every tag visible before rendering. A part with geometry on an off tag
   would render it and this file would not report it. Not known to exist in the library.

## Open questions

- **`body` / `proud` are not emitted.** Nothing in the model labels which nested entity is a
  lever, a duct elbow or a ramp. `body` is required whenever `proud` is, so emitting neither
  keeps that promise. Closing this needs either a naming convention in the master file or a
  hand-authored table — Benton's call.
- **Is `facing` right?** Untested. It ships as an object with its basis and margin so a wrong
  answer is legible rather than authoritative. Nothing consumes it yet.
- **Does anything downstream honour `bbox_kind`?** Today, no — `prism-audit.js` carries `kind`
  through but never branches on it. Whoever owns `assets/iso-render.js` needs to refuse a mask
  built from a row whose kind is not `"visible"`.
- **The `-hx` family and `floor-7224`** are the two the brief expects to move. Nobody has seen
  a real number yet.

## What Benton runs

1. SketchUp → open the master component file → **Extensions → Developer → Ruby Console**
2. `load "C:/Users/bento/Documents/Claude/Sketchup/scripts/angled-component-art.rb"`
   (or the panel's **Component art — Iso30 angles** button)
3. Pick the batch, set **Dry run = Yes**, run. A dry run writes both `_diagnostics.txt` and
   `_dimensions.json` and renders nothing — start there.
4. Console should print `DIMENSIONS  WRITTEN TO …` and a per-kind tally. **If the tally shows
   anything other than `visible`, read the notes in the file before trusting it.**

Then, from the `WhisperRoomQuote` repo with the art root mounted:

```
node scripts/prism-audit.js --html
```

Incremental order, per the brief: **ENH Extra batch first**, then the vent / EFS / ramp
families, then everything else.
