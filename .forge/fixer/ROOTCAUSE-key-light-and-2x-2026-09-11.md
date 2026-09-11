# Root cause — the two blockers in front of rank cycle 1 (11 Sep 2026, desktop)

Provenance tags: **observed** (ran it / read it), **derived** (follows from
observations), **reported** (a doc said so), **assumed**.

Every live number below came over `scripts/sketchup-bridge.py` against the
SketchUp 2026 session on the desktop. The scripts that produced them are in
`.forge/fixer/rank-loop/` (A-setup, B-drop, C-export, D-redrop, E-rollback,
F-abort, G-ghosts, H-fixed, Z-cleanup, measure.py) with the console
transcripts (`*.stdout.txt`) and the six render measurements
(`renders-r1-r6.txt`).

## First finding: the cycle model is not on this machine

**observed.** The desktop's bridge log has no job between 10 Sep 23:35 and
11 Sep 17:55; c1..ctl were written to `Z:\Sketchup\Proposals` at 16:23-16:58.
The model open here is `MDL 96120 S` in a 40x40 room, 11"/13" off two walls,
no scenes, no rig. The cycle frames are `MDL 96144 E`, 4"/6" off two walls.
Both are unsaved (title/path blank in every manifest). So the laptop session
holds the cycle model, and nothing in c1..ctl can be re-measured in place.
Everything here is the SAME PIPELINE on a same-size room, not the same model.

## Blocker 1 — `KEY SKIPPED`: a rule defect, fixed in the rule

**Root cause (observed on the live model, `probe-key.rb`).** The rig aimed
the key along the line BOOTH CENTRE -> DOOR-PANEL CENTRE and walked out
along it. A door that is not centred on its face makes that line diagonal.
Here the door sits at the north end of the west face: the line is
(-0.772, 0.635); at 96" out it lands OUTSIDE the floor, 90/84/78/72" are
all outside, 66-54" are inside but within the 12" body margin, and the
walk-back stops at 48" — pulled in and off-axis. On the cycle model the same
line runs into the wall the booth is parked 4-6" from at every standoff
from 96 to 42, which is the recorded log line. The perpendicular from the
same door face reaches the full 96" with 44" of clearance.

**Fix (`scripts/wr-drop-lights.rb`, 1.66.0).**
- `door_face_normal(booth_box, door_box)` — PURE — the door faces the booth
  side its panel box lies against (ties at a corner go to the side the panel
  is thinner across). Replaces the centre-to-centre line for the key, the
  rim and the foam graze; `dlen` becomes the centre-to-door distance along
  that normal.
- The key walks out from the door FACE (the booth box's side), not from the
  panel box centre (which sits inside the booth by half a swung leaf).
- `accent_place(...)` — PURE — walks the perpendicular first; if nothing
  from 96 to 42" fits, sweeps the aim line 15° either side, then 30, 45, 60
  (`ACCENT_FAN_STEP`, `ACCENT_FAN_MAX`), nearest-perpendicular first, and
  logs `KEY SWUNG +/-N deg`. Only past the whole fan does it log
  `KEY SKIPPED`, and that message now says the fan was tried.
- Pinned in `scripts/rbtest-lights.py` (`dfn`, `ap` transcripts) and
  mutation-checked: fan order inverted -> red; tie-break inverted -> red.

**Proof (observed, `H.stdout.txt`, render r6).** Same model, rig removed
and re-dropped with the patched rule: `key — 4480000 lm at 3200K,
(253.5", 435.3", 96.0"), STANDOFF 96 in (8.0 ft) from the door face` —
that is x = 349.5 - 96, square to the west face. `audit_scene` ok.
face/floor moved 0.816 (r1, key at 48" diagonal) -> 0.904 (r6).

**Adjacent, not fixed.** The rim ("opposite the door, RIM_OUT=30 beyond
the centre") now reports `lands outside the floor — skipped` on this corner
booth. The old diagonal put it 4" from the east wall, inside the 12" body
margin, i.e. half in the wall; the rule has no margin test and no walk-back.
A corner booth has nowhere behind it for a rim; if D3's "lighter far edge"
is wanted there, the rim needs its own fan or a flank position.

**Decision.** Rule fix, not a drag and not a one-off. The rule was wrong for
any off-centre door and would have hit the next client's room.

## Blocker 2 — the c1b -> c3 "2.4x": what is and is not established

### Established on this machine (observed)

| render | change | mean | med | face/floor | ceil R/B | linear mean | linear median |
|---|---|---|---|---|---|---|---|
| r1 | rig, defaults (drums 3,200,000 lm — c3's figure) | 0.5735 | 148.29 | 0.816 | 1.964 | 0.35492 | 0.31737 |
| r2 | NOTHING changed | 0.5735 | 148.30 | 0.816 | 1.964 | 0.35491 | 0.31739 |
| r3 | remove_rig!, re-drop at mult 0.5 | 0.4209 | 108.64 | 0.839 | 2.083 | 0.18517 | 0.16133 |
| r4 | drop, `Sketchup.undo`, drop (replace path) | 0.5683 | 146.58 | 0.824 | 1.978 | 0.34879 | 0.30934 |
| r5 | drop with forced abort_operation, then render | 0.5735 | 148.30 | 0.816 | 1.964 | 0.35494 | 0.31741 |
| r6 | remove_rig!, drop with the FIXED key rule | 0.5971 | 157.66 | 0.904 | 1.935 | 0.38657 | 0.36190 |

1. **Deterministic in every rubric statistic** (r1 = r2 = r5 to the third
   decimal; pixels differ by Monte Carlo noise: max 29/255, mean 1.0, 41%
   identical — the same signature as c3 vs ctl: max 34, mean 1.18, 39%).
2. **Linear in lumens.** Halving every rig light halved the LINEAR mean
   (0.522x) and median (0.508x); the 2% excess is r1's 0.8% clipped pixels
   plus the constant booth light and sun. The ENCODED median went
   148 -> 109, not 148 -> 74: the loop must reason in linear space.
3. **The transfer is linear, the file is linear+one sRGB encode.**
   `/SettingsColorMapping` type 6 (Reinhard) burn 1.0 = linear, mode 2 (no
   gamma in the buffer), no clamp, no subpixel mapping; camera f/8 @ 1/300
   @ ISO 100 = EV 14.23, exactly as every cycle manifest logs. Decoding each
   cycle PNG back to linear reproduces the exporter's logged pre-encode
   mean to 3 decimals (c3 0.0763 vs 0.076; c1b 0.3568 vs 0.357). sRGB is
   ruled OUT as the cause: one encode, applied uniformly. The sun is ON at
   1.0 in this scene; with the room sealed it contributes nothing.
4. **The same nominal lumens give the c1b level, not the c3 level.** r1
   (3,200,000 lm per drum, c3's figure) landed at linear 0.355 / median
   148 — c1b's numbers — on a same-size room with a smaller booth. c3
   (0.076) is the outlier, not c1b.
5. **c1b -> c3 is not a scalar.** In linear space the ratio is 5-6x almost
   everywhere (rows of a 6x8 grid: 4.9-6.6), 8-10x on the left wall and the
   right wall's glow, 1.2x on the blue foam window; ceiling LINEAR R/B moved
   3.25 -> 4.63. One factor on all lights cannot do that; a different SET
   of contributing lights can. (`ratio-c1b-over-c3.png`.)
6. **Lights can silently be at V-Ray's factory default (30 lm).** After
   drop -> `Sketchup.undo` -> drop, four sconce spheres read 30.0 where the
   rig had written and read back 480,000 (`E.stdout.txt` line 139); r4 came
   out 1.7% dimmer (0.3488 vs 0.3549 — far outside the 0.0001 noise) with
   nothing on the SketchUp side saying so. Two further replace-path drops
   (`G.stdout.txt`) did NOT reproduce it: intermittent, one press in three.
7. **Neither `Sketchup.undo` nor a rolled-back press removes the rig here.**
   After a forced raise in `reap_lights` (the last call before commit) the
   tool printed "The SketchUp side rolled back" and yet all 36 rig entities
   and 19 plugins were still in the model and the scene (`F.stdout.txt`,
   `G.stdout.txt` NOW line). V-Ray's `scene.change` transaction closes the
   SketchUp operation underneath the rig. r5 == r1 is simply the same rig
   again; the "ghost rig" reading I held for one turn is withdrawn.
   Consequence: "reset" in the loop must be `remove_rig!` + verification,
   never undo, and the tool's "Ctrl+Z removes the lights" line is untrue.
8. **`remove_rig!` is clean**: `plugins_deleted=19 plugins_left=0`, scene
   back to the booth's light + sun, every time (B/D/E/F/H/Z).

### What this says about c1b -> c3 (derived, not observed on the laptop)

The pipeline, at fixed state, is deterministic and linear. The c3 frame is
5x darker than the same lumens produce here, non-uniformly, with a colour
shift, and the trend c1b 0.357 -> c2 0.105 -> c3 0.076 -> ctl 0.076 is
monotone with cycle count, not with the settings changed. The one mechanism
observed here that silently removes light from a rig the model still shows
is (6): lights left at 30 lm. The record's "3,840,000 -> 3,200,000 measured
directly" is a read of ONE plugin's intensity and says nothing about the
other eighteen. The c3 frame's sky-leak parallelogram at the ceiling/right
wall junction (absent in c1b) says the tool-owned enclosure differed too.
I cannot prove which lights were dead in c3 — that session is gone — and I
say so. What I can say: the 2.4x is not a property of the renderer, and the
loop can make it impossible to happen unnoticed.

**A consequence the record should absorb.** DEVLOG 1.65.0's c2 conclusion
("5000 K made the room dimmer ... the peach cast is the orange FLOOR") and
the rubric's Reversal 2 ("do not touch Kelvin again") rest on c2 being a
clean Kelvin-only change. c2's darkening (0.357 -> 0.105 linear, 3.4x) is
the same unexplained class as c3's and is confounded. Kelvin may still be
the wrong lever, but that has not been shown.

### The rule the loop may rely on

- Same rig state -> same rubric statistics to +/-0.001 (mean, med,
  face/floor, R/B). Pixel-level comparison is noise; never diff pixels.
- Linear mean/median scale 1:1 with rig lumens while clipping stays under
  ~1%. Predict in linear (decode sRGB first, or read the exporter's
  "mean X -> Y" line: X is the linear mean); measure every frame anyway.
- Before EVERY render: `WR_DropLights.audit_scene(Sketchup.active_model)`
  must return `'ok' => true`. It fails on a ghost (a light plugin no entity
  owns), a dead light (<= 30 lm or disabled), a wrong intensity (not what
  the rig stamped in `lumens`), or a missing plugin. A failed audit voids
  the cycle. It runs in ~10 ms over the bridge.
- Reset = `WR_DropLights.remove_rig!(model)` with `plugins_left == 0` and
  the audit reporting `rig == 0`. Never `Sketchup.undo`.
- One render per cycle, ~68-76 s at 800x450 here.
