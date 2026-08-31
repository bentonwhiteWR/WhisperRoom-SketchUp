# Builder HANDOFF — proposal-package manifest, LIVE-VERIFIED (2026-08-31, evening)

Goal reconfirmed against `.forge/GOAL.md`: proposal-speed half of the mission
(Researcher's §6 item 1 + reporting half of item 3). Plugin at **1.10.8**
(1.10.7 built the manifest; 1.10.8 is comment-only: assumptions upgraded to
observations after the live run).

**The morning gap is closed.** SketchUp 2026 opened at ~18:30; the manifest
was exercised through the real batch path (`start_run` → timer `step` →
`unit_image` → `finish` → `write_manifest`) on a scratch fixture, three times.
A real `manifest.json` was written, read back, and checked against the
exported pixels. What follows is OBSERVED unless labelled.

## What was run and what it showed

Fixture (scratch, untitled model — left in place, never saved): 48x72 face, a
group named `MDL 4872 S`, four `DimensionLinear` (two axis-aligned on WR-Dims,
one diagonal on WR-Dims-Booth, one text-override `CLEAR OPENING` on
WR-Dims-Doors), one WR-Notes `Text`, two scenes with different saved tag
states. Driven via `scripts/sketchup-bridge.py` with `UI.messagebox` muzzled
to IDYES (the 30 Aug scripted-caller pattern).

- **Batches 1–2 (annot=draft)**: 2 PNGs + `manifest.json` per run. Rows carry
  scene name, scene-tab index, lane, `ok`, actual 1600x900 (size honoured from
  V-Ray's /SettingsOutput even on an image-only batch, and `size_source` says
  so). `annotation_tags_shown`: `[]` on 01-exterior, `["WR-Dims",
  "WR-Dims-Doors"]` on 02-dimensioned — matching both the scenes' saved states
  and the exported pixels.
- **Round-trip (the point)**: 02-dimensioned.png shows `6'`, `4'`,
  `CLEAR OPENING` — character-for-character the manifest's `display` values.
  The hidden-tag callouts (diagonal, note) are absent from the plate and
  present in the manifest as data.
- **Batch 3 (annot=client)**: `annotations_hidden_in_images: true`, every
  row `[]` + the client-safe note, the PNG carries zero callouts, and all 5
  annotation strings still ride in the manifest as data.
- **Restore**: after every batch `@running` false, mode back to `draft`,
  `UI.messagebox` restored (verified by alias round-trip; muzzle log showed
  exactly the preflight confirm + the finish summary).

## Assumptions settled (all OBSERVED, SketchUp 2026)

- **A1** `DimensionLinear#start/#end` → `[nil, Point3d]`; `dim_anchor` reads
  it. `measured_in` came out exact: 48.0 / 72.0 / 24.0 / 86.533.
- **A2** `Page#layers` = the page's HIDDEN layers. Confirmed both directions
  (all-hidden scene listed all four; two-hidden scene listed those two).
- **A3** Straight-line span matches the displayed value for axis-aligned dims.
  Discovery: `Dimension#text` returns the RENDERED string (`"4'"`), never a
  `<>` placeholder, so `text` is authoritative on its own; and
  `Sketchup.format_length` prefixes `~ ` on non-exact lengths (diagonal:
  `measured` `"~ 7' 2 9/16\""` vs drawn `"7' 2 9/16\""`) — use `text`/`display`
  for captions, `measured_in` for arithmetic.

## Not exercised (honest gaps)

- **Cancel-path manifest** (checklist step 7): a 2-image batch finishes in
  ~1 s; there was no window to cancel into. The code path is the same
  `finish` → `write_manifest` that ran three times; the `cancelled`/`lost`
  statuses themselves are covered by the offline mr-tests. UNRUN live.
- **Render-lane row** (step 9): V-Ray lane untrusted and parked with the
  look-dev mission; no render row was run.
- **Manifest-fed assembly** (step 10): the downstream procedure change is the
  GOAL item-5 rewrite's job.

## For the next scripted driver (learned the hard way)

Muzzle `UI.messagebox` in the SAME job that calls `start_run`, and poll with
`--modal allow` evals. A plain eval's modal patch/unpatch RESTORES the true
messagebox mid-batch, and the next box (preflight confirm, finish summary) is
then a REAL Qt modal that blocks the job queue — observed; it had to be
answered by sending keystrokes to the Qt window (`SetForegroundWindow` + `y`).
Restore the muzzle from its `wr_pp_true_messagebox` alias in a final
`--modal allow` job, and check the muzzle log it returns.

## Open-questions (unchanged from the morning, minus the assumptions)

1. Researcher §6 items 2/4/5 — untouched, out of scope.
2. SKILL/playbook rewrite to "draft captions from manifest.json, spot-check
   against the render" — GOAL item-5 job; the manifest is now proven input.
3. check-doc-paths.py findings for Benton: CLAUDE.md:50 (build-v2.js moved
   in-repo to `proposals/build-v2.js`), booth-models.md:3 and
   sketchup-drawing.md:123 hard-code the laptop root, three docs name three
   client-config destinations.
