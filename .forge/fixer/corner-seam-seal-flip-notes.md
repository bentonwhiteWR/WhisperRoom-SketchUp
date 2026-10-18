# Corner seam seal flip — fixer notes (18 Oct 2026, 1.84.4)

Tags: **[obs]** observed with a tool this session · **[der]** derived from observed numbers ·
**[rep]** reported (Benton / orchestrator) · **[asm]** assumed.

## Symptom
- [rep] Benton, 18 Oct: "the standard corner seam seals all need to be rotated 180 degrees. I modified them
  and now they are loading in flipped."
- [obs] Screenshot `capture-2026-10-18_120854.png`: the outer corner seal sits elbow-IN, with the 1x1 block
  facing out.
- [obs] Master model at 12:02, booth "MDL 96144 S (components)", built from a link. All four `CornerSeamSeal`
  instances are elbow-in. Their local transforms are SW −I at (4.875,4.875), SE −90° at (141.125,4.875),
  NE identity at (141.125,93.125), NW +90° at (4.875,93.125).

## How it was read (no SketchUp, no bridge)
- [obs] SketchUp 2026 `SketchUpAPI.dll` (C SDK), driven via ctypes, opens .skp/.skb offline. The tools are in
  `corner-seam-seal-flip/`:
  - `skprobe.py`: the walker, plus edge-endpoint centroid and box;
  - `loopdump.py`: the full geometry with face loops kept apart;
  - `treeprobe.py`: every instance of a definition in a model, with its world box and which way the L faces;
  - `replay_corner.py`: OLD (git HEAD) versus NEW `corner_yaw`, run verbatim in CRuby on that geometry.
- The sources read were all copies; nothing was opened in place:
  - the share parts, `P:/Sketchup/NewMasterComponentList/CornerSeamSeal{,_HX}.skp`, mtime 12:07:19 and
    unchanged at fix time;
  - the master model's `.skb` at 11:59, the save at 12:02 and the autosave at 12:11;
  - the 23 Sep master (MCL);
  - the client models for Walsh (12 Oct) and ISL 7296 (16 Oct).

## Timeline
| when | what | tag |
|---|---|---|
| up to 18 Oct | The plain L is SW-authored: box 0..4.875, elbow at (0,0), 216 edges / 18 faces, with an HX twin. Walsh and ISL instances are elbow-OUT (SW identity, SE +90 at (W,0), NE 180 at (W,H), NW −90 at (0,H)). | obs |
| before 11:59 | Benton adds 3/8 in chamfers on the three outside corners (elbow + both leg tips). The definition goes to 227 edges / 22 faces, still SW frame. | obs |
| 12:02 | Booth built from the link: all four corners elbow-IN. | obs |
| 12:02–12:07 | Both corner defs are re-axed 180° about (2,2). The box becomes −0.875..4.0 and the elbow sits at (4,4). All four seam seals are exported to the share at 12:07:19. | obs |
| 12:08:54 | Screenshot: still flipped. | obs |

## Root cause (one sentence)
`corner_yaw` aimed the plain average of the part's edge END POINTS at the booth's middle. That average sits
only thousandths of an inch off centre, so Benton's chamfers flipped its sign and turned every corner 180°.
Because the method tries all four turns itself, no re-axing of the part could undo it.

### Numbers, from the replay summary
These are per-axis leans from the box centre; the replay file prints the same thing along the diagonal (×√2).

| part | edge-endpoint mean (old input) | plan-area centroid (new input) |
|---|---|---|
| plain L | 0.0035 toward NOTCH | 0.866 toward elbow |
| plain L HX | 0.0216 toward notch | 0.866 toward elbow |
| chamfered (SW frame or share frame) | 0.0446 toward ELBOW | 0.874 toward elbow |
| chamfered HX | 0.0126 toward elbow | 0.867 toward elbow |

- [der] The old rule was "nearest the booth middle". It worked only while the mean leaned toward the notch.
- [der] Re-axing 180° turns the part's geometry and the instance transform together. `corner_yaw` re-picks from
  all four turns, so the world result is the same.

## Fix
`scripts/build-booth-components.rb`:
- `corner_yaw` now takes the L's plan centre of mass from the new `plan_mass`. That is every face loop projected
  to plan, area-weighted, with inner loops subtracted, recursing through groups and components like
  `collect_points`.
- It keeps the turn that puts the mass FURTHEST from the booth middle, which leaves the elbow outboard. This is
  the rule `reference/seam-seal-attachment.md` already states.
- If no plan area is found, it prints a loud `***` line and leaves the corner at place()'s turn. That cannot
  happen for a real seal.
- The comments at the IEP orientation block (~l.335) and the corner block were updated.
- `collect_points` is now unused and was left in place, to keep the change minimal.

Why area and not a constant or frame rule: the brief preferred placement predictable from the authored frame.
But Benton re-axed this very part today, so the frame has already changed once (SW → NE). Any frame-based yaw
table or constant would have broken at 12:07 and will break on the next re-axe. A corner seal has exactly one
legal turn per corner, and its mass decides it with a margin of 0.87 in per axis, about 20× the 0.045 that
flipped the old rule. Its input is purely physical. Inner corners keep their direct, frame-based table: that
part's frame is documented, and it was not touched.

## Verification
- [obs] `replay-before-after.txt`: the real OLD and NEW methods run on the real full geometry, 146×98 booth, all
  four corners, each from all four starting turns.
  - OLD reproduces both observed builds transform for transform: Walsh/ISL plain gives SW 0/SE 90/NE 180/NW −90,
    and the 12:02 chamfered gives SW 180/SE −90/NE 0/NW 90.
  - NEW gives elbow-OUT on every case, with the box exactly on its polygon (0.0000 off).
- Per corner, for today's share part (`CornerSeamSeal.skp` 12:07; `_HX` is identical):

  | corner | 1.84.3 (before) | 1.84.4 (after) |
  |---|---|---|
  | SW | elbow IN, 6.89 in from the outer corner; frame yaw 0 | elbow OUT at (0,0); frame yaw 180 |
  | SE | elbow IN; yaw 90 | elbow OUT at (W,0); yaw −90 |
  | NE | elbow IN; yaw 180 | elbow OUT at (W,H); yaw 0 |
  | NW | elbow IN; yaw −90 | elbow OUT at (0,H); yaw 90 |

- [obs] `scripts/rbtest-corner-seal.py` covers 128 cases, all passing; its built-in mutant ("nearest") fails all
  128.
- [obs] `rbparse.py` is clean (82 files). `rbtest.py`, part-orientation (100), side-wall-order (437), overlays,
  wall-part and boothlink-cbl all pass.
- [asm] place() hands corner_yaw a box centred on the corner polygon. This was observed in the 12:02 and
  Walsh/ISL builds, where every box sat exactly on its polygon. It is not re-run offline, because place() needs
  the API. A rotation about the polygon centre keeps a square box on its footprint.
- [asm] `Face#loops`, `Loop#outer?` and `Loop#vertices` behave as documented in the SketchUp Ruby API. They are
  stubbed offline.

## Only a live build can confirm
- That the corners look right in SketchUp: elbow at the outside corner, legs and 1x1 block against the panels,
  on Standard and Enhanced/HX.
- That the inner `ENH CornerSeamSeal` corners are unchanged. Their code path was not edited.

## Residuals
- The mid-wall seals were also re-exported at 12:07, with their frame unchanged. They are placed by `place()`
  and the `REVERSED` list, not by `corner_yaw`. Out of scope and not re-checked live.
- There are stray 0.07 sq in floor triangles at the chamfer cuts on the bottom face: one on `CornerSeamSeal`,
  three on `_HX`. They do not affect placement.
- Benton's 12:07 re-axe can stay or be reverted. The builder no longer cares.
