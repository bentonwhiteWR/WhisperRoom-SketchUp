# HANDOFF — Scoper → Builder: AUTO-SET the proposal package from a selected booth

10 Sep 2026. Plugin 1.47.0. Prior mission's handoff (booth-dimensions rev 2) preserved verbatim
as `.forge/scoper/HANDOFF-booth-dimensions.md`; its spec and mockup are untouched at
`.forge/scoper/booth-dimensions-spec.md` / `booth-dimensions-mockup.html`.

**BLOCKED ON APPROVAL. No Ruby is to be written until Benton answers the artifact.** Five of
the design's decisions are genuinely his (Q1–Q5, §10 of the spec) and two of them — how many
renders per booth, and whether plate 3 becomes a front elevation — change the output.

## Produced
- `.forge/scoper/proposal-autoset.md` — the spec. §1 booth identity + the stored booth token;
  §2 the six plates, the render ladder and the evidence from both `proposal-v2.json` examples;
  §3 the annotation **allowlist** and the wall **camera-cone** rule (highest risk, read first);
  §4 where it lives + why `proposal-scenes.rb` is kept + why the WALLS/ANNOTATIONS columns must
  gain state; §5 the stamp, the containment rule and five re-run cases; §6 ten ordered build
  steps; §7 acceptance incl. three mutants and the D5 export check; §8 edge cases; §9 out of
  scope; §10 open questions; §11 the ranking record.
- Review artifact: **https://claude.ai/code/artifact/a800433f-5b61-44d7-b147-9b522b2c6bd2**
  — the grid pre-filled for two booths, live Skip/Image/Render controls, the five decisions as
  controls, approve/changes/hold, and a copy-back box. Source in the session scratchpad
  (`autoset-review.html`); republish that same path to keep the URL.
- Nothing under `scripts/` touched. `scripts/wr_tools/VERSION` untouched at 1.47.0. Nothing
  committed, nothing pushed, nothing emailed.

## Read-first (Builder)
1. Spec §3 in full, twice. It is the only thing standing between an auto-set and a customer
   image carrying the `Ceiling 8'-0" - HOUSE DEFAULT` banner.
2. `scripts/wr-scene-annotations.rb` — `inventory` (260), `apply` (499), `write_scene` (531),
   `state_hash` (317). Note the picks polarity: **ticked = hidden**.
3. `scripts/wr-scene-walls.rb` — `scan` (138), `wall_units` (154), `object_units` (231),
   `side_of` (109, and its room-local caveat), `apply` (341), `write_scene` (376),
   `apply_all` (418, and why it is the wrong call here).
4. `scripts/proposal-scenes.rb` 34-130 — `PLATES`, `DIM_TAGS`, `NOTE_TAGS`, `ANNOT_RE`,
   `annot_tags`, `SHOWN_ON_DIMENSIONED`, and `aim`/`heading_to`/`subject_bounds` (169-190).
   This file is a **library**; do not delete or restructure it.
5. `scripts/proposal-package.rb` — `booth_name?` (667), `booth_groups` (3024), `mode_of` /
   `set_mode` (274-293), `gather` / `state` / `push_state` (913-1005), `plan_names` (562),
   `scene_prefix` (546), `walls_payload` (3531), the `wallsopen`/`annotsopen` callbacks
   (4073, 4227), the CSS `:root` and `.seg` rules (4464, 4631), `draw()` (4959).
6. `proposals/examples/example-client/proposal-v2.json` and
   `proposals/examples/peoplesspace/proposal-v2.json` — the only real evidence for which shots
   a proposal needs and which of them are renders.
7. DEVLOG top entry (1.47.0) — what was removed and, more importantly, what stayed and why.
8. Benton's answers to Q1–Q5 when they arrive. Q1 and Q2 change the shipped defaults.

## Assumptions
- **observed (code, this session):** everything cited with a file and line above; the two
  example packs' plate lists and their `boothOf` fields; that the WALLS and ANNOTATIONS columns
  render stateless buttons today; that `booth_groups`/`booth_name?` already exist; that the
  package already loads both scene pickers; that VERSION is 1.47.0.
- **derived:** the render ladder and the default of 2; the camera-cone wall rule; that
  `05-plan` needs no walls hidden; that scene names should lead with the booth; the 1"
  booth-moved threshold; that the grid needs per-row state for the review to be a review.
- **reported:** Benton's ask, verbatim in `.forge/GOAL.md`; the "a few of them as renders"
  phrasing that Q1 turns on.
- **assumed, and flagged as such in the spec:** that entity ids are not reliable enough to be
  the booth token; that reading true per-row walls/annotations state on Rescan is fast enough —
  **unmeasured**, measure before optimising (§4.3).
- **Not run, and must not be claimed as run:** nothing in this spec has executed in SketchUp.
  Build steps 5–8 can only be proven live.

## Open questions
- **Q1** Renders per booth — 2 (default), 1, or 3? Your two packs disagree.
- **Q2** Plate 3: front elevation (both packs want one) or the side elevation the tool makes
  today? Default: switch to front.
- **Q3** Interior plate on by default? Default: off.
- **Q4** Preset the sun per scene? Default: no (§3.3).
- **Q5** Hide the other booth on each booth's plates? Default: no.
- Coordinator: the artifact link still needs emailing to bentonwhite92@gmail.com — the Scoper
  was told not to send it.
