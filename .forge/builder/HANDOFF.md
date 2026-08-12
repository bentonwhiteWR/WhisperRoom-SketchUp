# HANDOFF — selectable isometric azimuth

## Produced
- `scripts/angled-component-art.rb` — only file changed.
  - `CAMS` / `CORNER_CAMS` frozen constants replaced by `ELEV` (30.0),
    `DEF_AZIM` (45.0), `cam_vec`, `build_cams`, `build_corner_cams`,
    `azimuth` / `azimuth=`, memoised `cams` / `corner_cams`, plus the
    reporting helpers `azim_label` and `cam_labels`.
  - New `azim` field in `DEFAULTS` (`'45'`) and in `self.ask` — keys, prompts
    and lists all 12 entries, positionally aligned, with the list column
    commented per field.
  - `self.azimuth = cfg['azim']` set in `run` immediately after `ask`, before
    any measuring or rendering.
  - Azimuth + the live camera vectors now printed in the run settings dump,
    in `report`, and in `_diagnostics.txt`.

## Read-first
- The `lists` array in `self.ask` is positional against `prompts`. It is now
  commented field-by-field. One missing `''` silently shifts every dropdown.
- Elevation must stay 30. `z = 0.5` is what makes the `Iso30` filenames honest.
- `build_cams` puts `ExtR` on the chosen azimuth A; `ExtL` = A+90,
  `IntL` = A+180, `IntR` = A+270. `ExtNear` = A+45, `IntFar` = A+225.

## Assumptions
- Rotating `ExtNear`/`IntFar` rigidly with the rig (A+45 / A+225) rather than
  leaving them pinned at 90/270 was the orchestrator's call, not Benton's.
- Vectors are rounded to 4 dp so azimuth 45 reproduces the old frozen table
  digit for digit. Length is therefore 1.00003 rather than exactly 1.
- Azimuth choices offered: 45 (default), 40, 38, 36, 35.

## Open questions
- Is the A+45 corner-camera offset what Benton wants, or should `ExtNear`
  stay at a true 90 so it keeps facing the seam square-on?
- Per-model azimuth (square 7272 vs rectangle 7296) is still one global value.
- Nothing resembling a "defined lines" style exists in this script or anywhere
  in this repo; the model's own style list is only readable inside SketchUp.
