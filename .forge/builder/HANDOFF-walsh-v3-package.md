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
