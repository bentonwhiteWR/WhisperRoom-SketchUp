# Iso30 coverage audit — P:\Sketchup\BoothBuilderViews\AngledISOViews

Run audited: 2026-08-18, 7:36:46–7:40:59 PM. Source of truth for the expected
set: the 189-scene list exported from *Master Component List for Assembly
Manuals REFINEMENT*, cross-checked against the run's own `_diagnostics.txt`
sitting in the output folder.

**Verdict: the folder is complete.** 179 components x 4 cameras = 716 PNGs.
Every component has all four of ExtL / ExtR / IntL / IntR. No partial sets, no
orphan images, no failures reported by the exporter. One scene rendered nothing,
and fourteen scenes rendered a component whose name is not the scene's name.

## 1. The one true miss — fix this first

**Scene #120 `7Panel_HX` resolves to an unnamed component**, so it rendered
nothing. `safe_name` turns an empty definition name into the literal `unnamed`,
and there is no `unnamed_Iso30_*.png` on disk.

Compounding it: **scene #38, named plain `7Panel`, resolves to `7Panel_HX`** and
did render. So the HX art exists but was produced by the wrong scene, and the
standard-height 7Panel has no art at all.

Fix: name the component that scene #120 looks at, confirm scene #38's camera is
parked on the standard-height 7Panel rather than its HX neighbour, then re-run
those two scenes.

## 2. Scenes aimed at a differently-named component

The exporter names files after the **component definition**, never the scene, so
each row below collapses two or three catalogue entries onto one image set. A
scene aimed at the wrong part yields a correct-looking image of the wrong thing,
which is why these need eyes rather than a re-run.

| Scene | Renders as | What to check |
| --- | --- | --- |
| #33 `40VNT_EFS` | `40Vnt_EFS_CP` | the non-CP variant may have no art at all |
| #38 `7Panel` | `7Panel_HX` | see section 1 |
| #47 `CP144`, #48 `CP168` | `CP192` | CP144 and CP168 have no art of their own |
| #51 `CP126` | `CP186` | CP126 has no art of its own |
| #69 `RMVentilationExhaustBox`, #70 `RMVentilationIntakeBox` | `RMVentilationVSSLeftSideView` | both boxes share one image set |
| #71 `RM60`, #72 `RM60_VSS` | `RM72_VSS` | no RM60 art |
| #75 `RM84` | `RM84_BACK` | a back view standing in for the part |
| #78 `RM144` | `RM144_BACK` | same |
| #120 `7Panel_HX` | *(unnamed)* | see section 1 |
| #148 `STD6042CL SIDE L` | `STD6042CL SIDE R` | no left-hand art |
| #149 `STD6042FL SIDE L` | `STD6042FL SIDE R` | no left-hand art |

Two readings, and which one applies is per-row:

- **Genuinely shared definition.** Identical geometry placed twice; one image set
  is correct and the importer just needs to map both names to it. Plausible for
  the CP and RM size families.
- **Camera parked on the neighbour.** The exporter resolves a scene by finding
  the component nearest the scene's stored camera target. In the master file
  every component sits in one long row, all visible at once, so a target a few
  inches off lands on the adjacent part. This is the likely story for the
  `SIDE L` / `SIDE R` mirror pairs — check those first.

## 3. Run health

From `_diagnostics.txt` in the output folder:

- batch 4 (every scene, all four images), style **Interior**, frame **part
  centred**
- 2400 px square, view height **128 in**, azimuth **45**, elevation 30
- Shadow Dark **45** (Light 80), `active_path` nil, SketchUp 24.0.594
- all 189 scenes resolved to a component; none failed

Smallest file is 38 KB (`STDSS FL6_Iso30_IntL.png`) — thin-strip sized, not
black-frame sized, so no obvious camera-inside-the-model failures. Sizes only;
the images were not viewed. The `Extra` subfolder is empty.

## 4. Two settings worth a second look

- **Azimuth 45** flattens the 7272 booth's near and far corner seam seals to the
  same screen point — zero separation, a flat diamond with nothing to read. Fine
  for flat panels; worth re-shooting `CornerSeamSeal` at 40 or 38.
- Batch 4 shot the corner seal with the **standard four cameras**, not the
  `ExtNear / ExtL / ExtR / IntFar` set the script reserves for it in section 8c.
  That is batch 4 behaving as designed, not a bug, but the corner family art in
  the catalogue is therefore the generic rig.

## Re-running the check

`python scripts/check-iso-coverage.py` re-runs the whole comparison against the
live folder. Paths are at the top of the file.
