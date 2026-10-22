STATUS: READY

# Walsh v3 — proposal package (MDL 96168 S, corner, roof-mount) — 21 Oct 2026

Model: `Z:\Sketchup\ClientDrawings\Walsh Construction Tech Lab MDL 96168 S - Corner RM.skp` (saved after every step).
Booth untouched: N 46 win / 46 win / 22 / 46 cbl, no ADA, wide access door, elevated floor. No acoustic package. No PDF built.

## Backups (observed)
- `Z:\Sketchup\ClientDrawings\Backups\Walsh Construction Tech Lab MDL 96168 S - Corner RM - pre-package 20261021-2314.skp`
- `Z:\Sketchup\ClientDrawings\Backups\Walsh RM scenes pre-package 20261021-2314.json` (all 18 old scenes, cameras + tag states)

## Cleanup (observed)
- Deleted all 18 old scenes: 9 Ramp/Platform scenes plus 9 earlier v3 stamped scenes (`WR_AutoSet.remove`).
- Erased the wrong-swapped booth (pid 3442605). Removed the tag `Walsh RM swapped N 21 Oct`, which had 0 users left.
- Tags `Walsh Corner v2 21 Oct` and `WR-Room-New` hidden globally. Their v2 room had been showing through the v3 room.
- White triangle: this is the unpainted threshold face of the Door 2 opening (pid 3442505), which is real geometry. Both opening thresholds are now painted `0128_White` (the floor).
- The "3 items outside room" are the three dims groups: v1 3426743, v2 3427527, RM Dims 3442717. All kept.
- Old v1/v2 rooms, the old E booth, the platform booth and old dims are left in the model, HIDDEN. Deleting them was not asked for.

## Scenes (AUTO-SET 'create', renders=3) — the marks
Prefix: `Booth - MDL 96168 S RM (21 Oct link) `
| # | Scene | Mark | Hand fix |
|---|---|---|---|
| 1 | 01-angled r | Render | re-aimed (see below) |
| 2 | 01-angled | Image | re-aimed |
| 3 | 02-front r | Render | — |
| 4 | 02-front | Image | — |
| 5 | 03-high r | Render | — |
| 6 | 03-high | Image | — |
| 7 | 04-side | Image | — |
| 8 | 05-ventilation | Image | eye raised to z=200 so the roof-mount vents read |
| 9 | 06-plan | Image | ortho, eye [206,150,1500], height 470, whole room + dims |

- 01-angled re-aim: AUTO-SET put the eye at (-117,-26), outside the room, so the host door leaf filled the frame. It now uses eye [10,60,62], target [262,70,44], fov 55, the same camera as the previous v3 pass.
- Door side was READ from the WR-Booth-Door part. The vent side is ASSUMED, because the RM booth has no WR-Booth-Vent tagged part.
- WALLS: walls between the camera and the booth are hidden per plate, and none are hidden on 06-plan. The ceiling is hidden on 03-high and 06-plan.
- ANNOTATIONS: dims show on all plates (house policy, 10 Sep). Two loose old texts are hidden.

## Export — NEW folder (observed)
`Z:\Sketchup\Proposals\Walsh Construction Tech Lab MDL 96168 S - Corner RM - Package\`
- `1_…01-angled r.png` … `9_…06-plan.png` (prefix as above), plus `manifest.json` and `claude-prompt.txt`.
- All 9 rows have status ok. Each file is 1920x1080, RGB, opaque.
- The old folder `…\Walsh Construction Tech Lab MDL 96168 S - Corner RM\` was not touched and is no longer used.
- Preflight raised 2 warnings, both forced past:
  - "Floor off drafting white": the v3 floor is intentionally 0128_White.
  - "3 items outside room": these are the dims groups listed above.

## Render status (observed)
- All 3 V-Ray renders completed: 01-angled r, 02-front r, 03-high r.
- V-Ray was forced to 1920x1080 for the run (from its 1600x900) and then restored.
- EV 14.23. The sRGB encode was applied.

## Washed-out cause + fix (observed, reproduced)
**Cause:** a group was left open for editing (`model.active_path` non-empty). SketchUp fades everything outside the open group (InactiveFade), and `write_image` bakes that fade into every export.

**Fix:** `scripts/proposal-package.rb` `start_run` now closes any open edit before gathering rows and logs it. If an edit cannot be closed, the run aborts with a box. On this run `active_path` was nil, and none of the 9 PNGs is washed out.
- `scripts/wr_tools/VERSION` bumped from 1.84.4 to 1.84.5.
- `scripts/rbparse.py`: all 82 files parse.

## Every PNG checked by eye (observed)
1. 01-angled r: good hero. The floor is a V-Ray wood/tile texture. Sky shows above, and V-Ray's grey ground shows beyond the room at the right.
2. 01-angled: good. The `25' 1…` dim string is clipped at the right edge.
3. 02-front r: OK. A large grey V-Ray ground band fills the foreground because the south wall is hidden. Sky shows above.
4. 02-front: good, and the dims are legible.
5. 03-high r: dark and moody, with a grey void around the room (the known dark-high-render trap). Candidate to drop.
6. 03-high: good.
7. 04-side: good elevation (window face, 14' 2" overall). The far side is open white and the 32'/19' 11" chains run off the left edge.
8. 05-ventilation: good. The four roof-mount vent units read clearly. A stray 1"/1' pair overlaps at the bottom corner.
9. 06-plan: good, with the whole room and booth framed. Some dims overlap: "2"" at the door corner, "11' 11 15/16"" against the wall line, and "1'"/"1"" at the SE door. This dim set predates this job.

## Gaps
- The renders show sky and ground voids where walls and the ceiling are hidden. There is no environment backdrop.
- 03-high r is dark; Benton may drop it or re-light it.
- Plan and image dim overlaps and clipping (above) are not fixed. They need a dim-placement pass if Benton wants them cleaner.
- The vent side is ASSUMED.
- All room dims are still from the v3 build (reported/derived). Nothing was re-measured here.
- Next step is the PDF (not done).

## Repo files changed (not committed — orchestrator commits)
- `scripts/proposal-package.rb` (open-group guard)
- `scripts/wr_tools/VERSION` (1.84.5)
- New job scripts in `.forge/builder/walsh/pkg/`: s1-cleanup.rb, s2-autoset.rb, s3-fix.rb, s4-export.rb, and read-only checks q7–q14.
- Client renders stay on Z:, out of the repo.

---

# Package 2 (22 Oct 2026): fix, then re-export

**Folder:** `Z:\Sketchup\Proposals\Walsh Construction Tech Lab MDL 96168 S - Corner RM - Package 2\`

It holds 8 PNGs plus `manifest.json` and `claude-prompt.txt` (09:38–09:49). Every PNG is 1920x1080 and opaque (observed).

The first Package 1 folder is left untouched, as instructed.

The PDF was NOT built.

## Scenes and marks (observed, q28 recheck before export)

| # | Scene | Mark | File |
|---|---|---|---|
| 1 | 01-angled r | Render | 1_… 01-angled r.png (hero) |
| 2 | 01-angled | Image | 2_… |
| 3 | 02-front r | Render | 3_… 02-front r.png |
| 4 | 02-front | Image | 4_… |
| 5 | 03-high r | **Skip (dropped)** | none |
| 6 | 03-high | Image | 6_… |
| 7 | 04-side | Image | 7_… |
| 8 | 05-ventilation | Image | 8_… |
| 9 | 06-plan | Image | 9_… |

The booth is unchanged: N 46 win / 46 win / 22 / 46 cbl, no ADA, wide access door, elevated floor. No acoustic package.

## What changed in the model

All of these changes are in the saved `.skp`. The file was saved at 00:09:23, and q28 confirmed the state after the reopen.

### Lights (s5)
- 12 V-Ray rect lights.
- 4000 lm × 320, 5000 K, invisible.
- Camera EV 14.23.

### Render pages (s6)
- Ceiling (WR-Ceiling), WR Lights and all walls are shown, so the room is closed.
- 02-front r camera: eye [22,−2,60], target [218,18,44], fov 45. This is a 3/4 view from inside the SW corner. A true head-on view does not fit inside the room.

### Render backdrop (s12)
- Top-level group "Door 2 render backdrop" on tag "Walsh Render Backdrop".
- It is a 5-face box behind the Door 2 opening: x 256–305, y −25.88 to −60, z 0–84.
- Materials: floor 0128_White, the rest 0099_LightSteelBlue.
- **The size is ASSUMED.** It is cosmetic and only fills the opening.
- It is visible only on 01-angled r and 02-front r.

### Per-scene dims via tags (s9, s10)
The 17 dim VALUES are unchanged (verified, q28). Only tags and the per-page visibility changed.

| Tag | Dims | Hidden on |
|---|---|---|
| WR-Dims-Long | 19'11", 32', 18'11", 13'8 7/8" | 01-angled, 02-front, 03-high, 04-side, 05-ventilation |
| WR-Dims-South | 4", 3', 3', 1', 25'10 7/16" | 01-angled, 02-front, 03-high, 04-side |
| WR-Dims-W1-Corner | 3'11" (W1) | 02-front, 04-side |
| WR-Dims-W1-Far | 11'11 15/16", 8'2" | 01-angled, 02-front, 03-high |

- Render rows and 06-plan show every set.
- The manifest's `annotation_tags_hidden` matches this table (observed).

### Trap: per-entity dim hiding
Hiding a single DimensionLinear (`hidden=`) is NOT restored per scene on this model (q25). Use tags plus `page.set_visibility` instead (s8 was the failed attempt).

## Every PNG checked by eye (observed)

1. **01-angled r (hero):**
   - Closed room: ceiling, walls, wood floor.
   - No sky and no grey ground.
   - Door 2 opening crop: the backdrop fills it with blue-grey.
2. **01-angled:** all dims in frame (1", 14'2", 3'11", 4'1", 2"). The `25' 1…` clip is gone.
3. **02-front r:**
   - Closed room, no sky and no ground.
   - The far opening shows a SaddleBrown door leaf against a lit wall.
4. **02-front:** the dims are legible. The "1"" at the booth's left corner is partly occluded by the booth (minor).
5. **03-high:** good. The 3'11" sits just clear of the wall line.
6. **04-side:**
   - Dims in frame: 8'2", 1", 14'2", 3'11", 4'1", 2".
   - The long chains are gone.
   - The 3'11" text is partly clipped by the wall plane (minor).
7. **05-ventilation:**
   - Roof-mount vents read clearly.
   - The bottom-corner overlap is gone.
   - The 3' / small 1' pair at the far door is cramped (minor).
8. **06-plan:** whole room with all dims, no overlaps.

## Leftovers (flag only, not fixed)
- **Salmon ceiling in both renders:** colour bleed from the wood floor. The ceiling group has no material (q22, q23). Fix by giving the ceiling a white material with a low-GI-bleed override if Benton wants it.
- Minor occlusions on 02-front, 04-side and 05 (listed above).
- **Preflight warnings, forced past:**
  - The floor is 0128_White (intentional).
  - 4 items sit outside the room: the 3 dims groups and the backdrop.
- **Bridge:** it can no longer save over the open model. Changes need Benton to press Ctrl+S. Nothing changed this phase after the 00:09:23 save. q28 showed `modified=false`; the export itself was not checked for dirtying the model.
- The vent side is still ASSUMED. Room dims are still from the v3 build (reported/derived).

## Scratch (session scratchpad, not deleted)
- `pkg2-try1\`: first Package 2 output (before the backdrop).
- `pkg2-try2\`: 6 image PNGs plus the 08:28 manifest/prompt from the interrupted run.
- `chk3\`: copies and door crops used for this check.
- `test1\`, `prev2\`: test renders and previews.

## Job files to commit (orchestrator)
All in `.forge/builder/walsh/pkg/`:
- s5-lights, s6-scenes, s7-front-dim, s8-dimsets, s9-dimtags, s10-w1far, s11-export2, s12-backdrop.
- s13-export3 (the export with the save removed).
- t1-testrender, t1-restore, t1-poll.
- q15–q28.

No change under `scripts/` this phase, so there was no VERSION bump. Next step: the PDF, when Benton asks.
