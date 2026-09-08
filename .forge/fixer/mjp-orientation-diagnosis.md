# MJP orientation — diagnosis (no code changed)

2026-09-08. Fixer, diagnose-only. Reproduction: `.forge/fixer/mjp-transform-repro.py`
(pure Python transcription of the chain, run this session). Probe for Benton:
`.forge/fixer/probe-mjp-faces.rb` (parses under CRuby 3.2; UNRUN — no SketchUp here).

## The finding in three sentences

`MJP_SPIN180 = true` (1.19.2) turns the part a half turn about the wall normal, which is a
proper rotation that sends the definition's +Z to world DOWN. MJP.skp is authored +Z-up with
the jack box at the top (def z 2.1..9.5) and the two cable tails hanging below (to z −8.88),
so the spun part is upside down: the box lands 10.7–18.1 in off the floor with the tails
rising to 29.07 in — which is the screenshot. The error is uniform across N/S/E/W and both
faces (det +1 everywhere, no reflection), so it is one family constant, not a wall-frame bug.

## 0. Benton's answers (reported, via the coordinator, 2026-09-08) and what they settle

1. **"Wrong how": upside down — rotated 180 in the plane of the wall, connectors pointing
   the wrong way vertically.** Not a face-side error, not a plan rotation, not a mirror. That is
   the exact move `MJP_SPIN180` makes (§3), and the exact geometry the repro predicts for it
   (§1 step 5: box at 10.69..18.06, tails up). Leading hypothesis confirmed by both ends.
   - *Is a second 180 cancelling or doubling it?* No. The only other half turn on the path is
     the exterior box's `room_flip`, which is a yaw about world **Z** (it negates nrm, and
     `rotation()` re-derives the width direction from the new nrm). A yaw about Z composed with
     the spin about the horizontal nrm is a rotation about the in-wall horizontal axis — it
     never touches the vertical, and both boxes get the spin, so both are upside down. There is
     no 180 about a horizontal axis anywhere in `rotation()`: `EVEN` parity only chooses the
     SIGN of the width vector, which keeps det +1 and never inverts Z.
   - *Is a mirror hiding behind the 180?* No. All 32 rows of the repro (4 walls × int/ext ×
     spin × FACE_ROOM sign) have det **+1**. `Transformation.axes` with `[nrm × Z, nrm, Z]` is
     right-handed by construction, and `rotation(ORIGIN, nrm, 180°)` is proper. A naive sign
     flip is therefore safe on the handedness axis: turning the spin off restores the authored
     up, it does not expose a reflection.
2. **"Which walls": unknown — one booth seen (MDL 7296 E).** From the code the transform
   **cannot** differ per side in the vertical (§2): the spin is about the wall's own normal, so
   every wall gets the same up→down swap, and the seating is span-based. The per-wall variation
   is purely the yaw the normal itself dictates. This is derived from a transcription, not
   observed in SketchUp, so the one-line check that settles it:
   **In the booth builder, drag the MJP to a window/cable panel on a different wall (it sets
   `ms`), regenerate the link, pull it in: if the box is upside down there too, the defect is
   uniform (spin); if it is right way up on that wall, the chain has a per-side term the
   transcription missed.** Same thing without a rebuild: `load ".../.forge/fixer/probe-mjp-faces.rb"`
   Part 2 prints `def+Z -> -Z (DOWN)` for every placed `MJP interior/exterior` instance today;
   any wall printing `+Z (UP)` is the per-side case.

## 1. The transform chain, concretely

Sources: `scripts/build-booth-components.rb:1572` `rotation`, `scripts/wr-overlays.rb:558-590`
`wall_transform`, `:464-473` `axes_for`, `:284` `slot_frame` (`:room`), `:899-947` the MJP
call site.

**Step 0 — the part (observed).** `P:\Sketchup\NewMasterComponentList\_component-probe.tsv`:
`MJP.skp 8.7500 x 3.0306 x 18.3839, origin_z 8.8839` (the probe writes `origin = -min`, so the
box spans z −8.8839..9.5000, x 0..8.75, y 0..3.03). `_face-levels.tsv`: horizontal faces only
between z 2.125 and 9.5 (large ones at 3.125 = 22.7 sq in and 9.0625 = 20.3 sq in) — the box;
nothing horizontal below 2.125 — the tails. Hence, in definition space:
`X = width (8.75), Y = thickness (3.03), Z = height, +Z up, box on top, tails below`.

**Step 1 — `axes_for(gx[:e], 8.39, 8.0, 3.01)`** picks `wi=0, hi=2, ti=1` (width X, height Z,
thickness Y). Correct — but see §5 candidate 2: it wins on an exact algebraic tie.

**Step 2 — `rotation(cls, nrm)`.** `(hi,ti,wi) = (2,1,0)` is not in `EVEN`, so `s = −1` and
`width = nrm × Z`. Columns (image of def X, Y, Z) = `[nrm × Z, nrm, Z]`. For every unit nrm in
the plan this is a proper rotation (det +1); different walls differ only by a yaw about world Z.

**Step 3 — nrm.** `room = t[:room] × (room_flip ? −1 : 1)`; `o = room × FACE_ROOM[:mjp](+1)`;
`nrm = o·naxis`. `slot_frame` gives `room = +1` on the S and W walls (room lies at +naxis),
`−1` on N and E. Interior box: nrm points INTO the room. Exterior box (`room_flip`): OUT of the
booth. So def +Y (thickness) points into the room on the interior box, outward on the exterior
box, on every wall. `FACE_ROOM[:mjp]` only negates nrm, i.e. a yaw about Z: it can never touch
the vertical.

**Step 4 — `MJP_SPIN180`.** `Geom::Transformation.rotation(ORIGIN, nrm, 180°) * rot` — applied
after `rot`, in world space, about the wall normal (`A * B` applies B first; `wall_transform`'s
own `translation * rot` depends on the same reading, and foam/desk land correctly by it —
derived). A half turn about nrm maps `Z → −Z` and `(nrm × Z) → −(nrm × Z)`, nrm unchanged.
det stays +1. Result per wall (from the repro, FACE_ROOM +1, spin ON):

| wall | face | def +X → | def +Y → | def +Z → |
|---|---|---|---|---|
| S | int | −X | +Y | **−Z (down)** |
| S | ext | +X | −Y | **−Z** |
| N | int | +X | −Y | **−Z** |
| N | ext | −X | +Y | **−Z** |
| W | int | +Y | +X | **−Z** |
| W | ext | −Y | −X | **−Z** |
| E | int | −Y | −X | **−Z** |
| E | ext | +Y | +X | **−Z** |

With spin OFF the same table has def +Z → +Z on every row and def +Y unchanged.

**Step 5 — seating.** `d_z = z_top − zs.max` with `z_top = MJP_TOP_Z = 29.07`. The rotated
part's highest point goes to 29.07. Spin ON: the highest point is the tail tips (def z −8.88),
so the box (def z 2.125..9.5) lands at world **10.69..18.06** and the tails rise to 29.07.
Spin OFF: the box top (def z 9.5) is at 29.07, box **21.70..29.07**, tails hang to 10.69.
Run centring and the face seating are span-based, so no drift either way.

**No room-level mirror reaches this part** (observed): `scaling(` occurs only in
`scripts/wr-deck.rb` (the deck tiles; 1.19.11's reflection-of-X bug lived there and never
touched overlays); the booth group gets only the caster lift translation; the link decoder's
"mirror" is the outer→inner slot copy, not a transform.

## 2. Wall-side dependent?

**No** (derived, from the table). Every row has det +1 and the identical vertical; N/S/E/W
differ only by the yaw that the wall normal itself dictates. A per-side defect would show as
one row's def +Y pointing away from its own nrm, and none does. So this is a uniform
family-constant error — the same signature as the 2026-08-28 duct-cover case.

## 3. Is `MJP_SPIN180` doing what its comment says?

Yes, exactly: a proper half turn in the plane of the wall, plate flat on its face, up/down and
left/right swapped, no reflection sneaking in (a reflection would need det −1, and
`rotation()`'s parity trick plus a pure rotation cannot produce one). The comment's premise —
"as authored, MJP.skp lands upside down on the wall" — is what is false: the part is authored
right way up (Step 0), so the "fix" is what turned it upside down. The 1.19.2 commit says it was
verified only by harnesses that do not reach `wall_transform` (`rbtest-overlays.py` stops at the
pure-logic line; both harnesses re-run green this session and neither exercises the chain).

What Benton most plausibly meant on 1 Sep by "MJP needs to be flipped 180": with spin OFF the
vertical is right (box top at 29.07, plate centre ≈ 25.4 vs the QA 27.25), so the thing left
to be 180° wrong is the FACING — jacks buried in the wall, closed back to the room, on both
boxes. That is a yaw, i.e. `FACE_ROOM[:mjp]`, and it is the same words he used for the duct
covers ("ALL duct covers need to be flipped 180 degrees"), which were fixed by
`FACE_ROOM[:duct] = −1`. **This is a reported/derived reading, not observed** — see §4.

## 4. What the correct orientation is, and where it is recorded

- **Vertical — box up, tails down.** Observed in three places: the portal's own art
  `WhisperRoomQuote/assets/booth-art/mjp.webp` (jack box on top, blue and black tails hanging
  below); `WhisperRoomQuote/assets/iso-render.js:3939-3945` ("the rest of that render's 18.4"
  is the two cable tails hanging below it"); and MJP.skp's own authoring (Step 0). Plate centre
  27.25 (`iso-render.js:3932`, Benton QA 2026-06-27) — the box belongs just under the 32.5 desk
  surface, not at 10–18 in.
- **Facing — ports face out of the wall on BOTH boxes.** Observed, `iso-render.js:2808-2828`
  (Benton, v2.474.1: "No the MJP is flipped the incorrect way … The ports need to face the
  camera"; "it carries a PORT FIELD ON BOTH FACES"). The interior box shows its jack field to
  the room; the exterior box is the same part yawed 180 to show its field outward. The code
  already yaws the exterior box (`room_flip`); what is NOT recorded anywhere in the repo is
  **which authored Y face of MJP.skp carries the jack field**, so whether `FACE_ROOM[:mjp]`
  should be +1 or −1 is genuinely unknown — the probe answers it.
- Height note, out of scope: the box measures ~7.4 in tall in the .skp (def z 2.125..9.5), not
  the 3.64 the portal solved off a sprite, so `MJP_TOP_Z` centres the box at ~25.4 rather than
  27.25. Not the reported defect; flagged only.

## 5. Ranked candidates and the one-line experiment for each

1. **`MJP_SPIN180 = true` is the defect** (the vertical). Confidence high — derived from
   observed part geometry through a transcribed chain that reproduces the screenshot to the
   inch, and now matched by Benton's own description ("upside down, in the plane of the
   wall"). Experiment: rebuild with `MJP_SPIN180 = false`; the box must sit 21.7–29.07 in up
   with the tails hanging. If it still reads upside down, Step 0 is wrong and the probe's
   z-band will say so.
2. **`FACE_ROOM[:mjp]` sign is what 1 Sep was actually about** (the facing). Confidence
   medium — the reading in §3, unverified, and Benton did NOT report a facing error today
   (he may not have looked, with the part upside down). Experiment: run `probe-mjp-faces.rb`
   Part 1; if the jack field (many small faces, XLR/USB materials) is on the `y = MIN` plane,
   +1 is backwards and the constant wants −1; if on `y = MAX`, +1 is right and the 1 Sep
   report was something else (or a build older than it looked).
3. **`axes_for`'s guessed 8.0 (audit C-6)** — latent, not the cause today. The two candidate
   permutations `(0,2,1)` and `(2,0,1)` score an EXACT algebraic tie for any part with
   width ≥ 8.39 and height ≥ 8.39 (`|x−8.39|+|z−8| = |z−8.39|+|x−8|`); iteration order and a
   strict `<` break it in favour of the right one today, by float summation order only. A
   re-export that changes the face-only extents by an ulp could lay the part on its side
   along the wall. With `nil` the winner leads by 9.6 in. Experiment: `python
   .forge/fixer/mjp-transform-repro.py` prints both scores and the tie.
4. **A wall-frame / per-side basis error.** Ruled out (§2): det +1 and the same vertical on
   all eight rows; nothing per-side to fix.
5. **A room-level mirror on this series.** Ruled out (§1): no `scaling(` outside wr-deck.rb.
6. **The screenshot predates 1.19.2.** Cheap to exclude: the spin-OFF chain puts the box high
   with tails down, which does not match "low near the floor with an arm rising"; still,
   confirm the panel VERSION on the machine that built it is ≥ 1.19.2.

## 6. APPLIED — 2026-09-08, greenlit, on Benton's second report (uncommitted)

Benton, off the UNMODIFIED code (he believed a fix had shipped; none had): "still incorrect.
The needs to rotate 180 degrees, as well as flip upside down." The screenshot (coordinator's
description: box under the desk, tails entering its top and rising, plain black face, no jack
field) is the §1 step-5 spun geometry, and the second half of his sentence names the yaw
separately — so BOTH constants were wrong: `MJP_SPIN180` (the upside-down) and
`FACE_ROOM[:mjp]` (the "rotate 180"; the jack field is on def −Y and +1 was burying it).

**Composition, shown not asserted** (S wall interior box, columns = image of def X,Y,Z):
1.19.2 = `[−X, +Y, −Z]`; 1.19.13 = `[−X, −Y, +Z]`; net `M = new·oldᵀ = diag(1, −1, −1)` —
one 180 about the in-wall horizontal axis, det +1. Benton's two turns compose the same way:
`Rz(180)·Ry(180) = diag(−1,−1,1)·diag(−1,1,−1) = diag(1,−1,−1)`. Not identity, not a mirror.
−1 does not overshoot: spin OFF + face +1 leaves the jacks in the wall; spin ON + face −1 is
still upside down; only the pair reaches `def +Z → up, def −Y → room`. Det +1 on all eight
(wall × face) cases under the new settings — repro §3 and the harness both print it.

**Changed (`scripts/wr-overlays.rb`):** `MJP_SPIN180 = false` (:158, comment rewritten to
say why the 1 Sep axis was wrong); `FACE_ROOM[:mjp] = -1` (:212, with the reasoning);
`axes_for(gx[:e], MJP_W, nil, MJP_T)` (:933). `scripts/wr_tools/VERSION` 1.19.12 → 1.19.13.
`DEVLOG.md` entry at the top. `scripts/rbtest-part-orientation.py`: `test_mjp_chain` — the
whole chain transcribed, constants read from the source, 8 cases × (det, up, field, seating)
plus the 1.19.2 settings reproducing the screenshot; the old `FACE_ROOM[:mjp] == 1` pin
removed. Foam/duct/desk/EFP untouched: observed by grep — `MJP_SPIN180` and `FACE_ROOM[:mjp]`
are read only at :963/:966; foam :741/:757, duct :812–826, desk :876/:904 keep their calls;
the elevated floor never calls `axes_for`, `wall_transform` or reads `FACE_ROOM`.

**Verified offline:** `rbparse.py` 66 files parse; `rbtest-part-orientation.py` 94 checks
pass; `rbtest-overlays.py` 27 pass; red-injection of the 1.19.2 settings → 33 failures,
file restored. **Not run in SketchUp.**

**Expected on Benton's next import (booth-local z, off the booth floor; +4.75 with casters):**
box 21.70..29.07 (top at `MJP_TOP_Z`), jack field to the room inside / outward outside,
tails hanging 21.70 → 10.69. Every wall, both faces. If the box is still upside down, the
`Transformation.axes` / `*`-order transcription is wrong, not the part; if it is right way up
but the jack field faces the wall, the field is on def +Y and only `FACE_ROOM[:mjp]` goes back.

## 7. Folded into the same release — the desk drops 3/32 in (Benton, 8 Sep 2026)

`DESK_SURFACE_Z = 32.5 - 3.0 / 32.0` (32.40625). **Coupling: baked, not live.** `MJP_TOP_Z =
27.25 + MJP_BOX_H / 2.0` — the "32.5 minus 5.25" is a comment; the code holds the literal. The
MJP is a wall-mounted pass-through with its own QA'd datum (portal `iso-render.js:3932`
`MJP_PLATE_CENTER_IN = 27.25`, an independent constant), and Benton's report names the desk
only, so it does not follow. **The MJP figures given to Benton are unchanged.** `DESK_SURFACE_Z`
is read on exactly two code lines (seating :888, console :910); foam (`ph/2`), duct
(`DUCT_PORTS`), EFP (deck), and the host pickers (name/width) never read a desk height; no
collision or clearance check exists on this path. Pinned: `test_desk_height` and the
`MJP_TOP_Z`-independence check; red-injecting a bare 32.40625 or `DESK_SURFACE_Z - 5.25`
into `MJP_TOP_Z` each fails the harness.

## Proposed minimal fix (as written before the greenlight; now applied above)

`scripts/wr-overlays.rb`: `MJP_SPIN180 = false` (or delete the flag and its two call-site
arguments), and `axes_for(gx[:e], MJP_W, nil, MJP_T)` at `:910`. `FACE_ROOM[:mjp]` changes only
if the probe puts the jack field on `y = MIN`. Foam, duct and desk never read any of these
three lines (`MJP_SPIN180` has two call sites, both MJP; `FACE_ROOM[:mjp]` is read only there;
the `axes_for` change is the MJP call). Then extend `rbtest-part-orientation.py` to pin
`MJP_SPIN180 == false`, the `axes_for` nil call, and the decided `FACE_ROOM[:mjp]` sign, read
from the source like the duct pin.

## What was not executed

No SketchUp, no `ruby.exe`: the chain was run as a Python transcription, not the plugin. The
P: share was reachable and both probe TSVs were read directly. `rbtest-part-orientation.py`
(46 checks) and `rbtest-overlays.py` (27) pass on the untouched tree and neither reaches
`wall_transform`. The probe `.rb` parses but has not been run.
