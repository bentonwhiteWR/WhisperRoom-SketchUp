# Suites 128 & 114 — take-off notes (14 Sep 2026)

Client email (booth model not yet known when this was drawn):

> "In 128, I'd like to see how we could get it in the 13x9 room; otherwise, I'd have to put
> it in the far back room which is kind of open to the hall. In 114, I'd like to see it in
> either of the 10 x 9 rooms. I know it will fit in the far back room."

Plans: `plans/128.pdf` (portrait) and `plans/114.pdf` (landscape), both Matterport-style
real-estate plans. Both are raster images inside the PDF; 114's size labels are also vector
text. Each room carries a size label; there are no wall chains. 114 says outright "SIZES AND
DIMENSIONS ARE APPROXIMATE, ACTUAL MAY VARY". Plan page-up is taken as north.
Measured on 300 dpi PyMuPDF renders by dark/light pixel runs along scanlines. Faces are the
boundary between the last wall pixel and the first room pixel (x.5).

Take-off: `takeoff.json`. Checker: clean, 18 flagged values + 3 assumed hinges.
Built into the live SketchUp 2026 Untitled model through the bridge. Model left unsaved.
Screenshots: `.forge/builder/suites-128-114/suite-128-top.png`, `suite-114-top.png`
(not committed).

## Suite 128 — room `ROOM 13'3" x 9'3"`

**Scale anchor:** the room's own label, per axis. N-S interior 648 px = 13'3" (159") →
**4.075 px/in**; E-W interior (north part) 444 px = 9'3" (111") → **4.000 px/in**. The two
axes disagree by 1.9%, consistent with an approximate plan.

**Orientation:** the label is rotated vertical. Pixel ratio 648/444 = 1.46 against
159/111 = 1.43 (the swap would be 0.70), so 13'3" runs N-S. **Derived.**

| Dimension | Built | Provenance |
|---|---|---|
| North wall, full width | 9'3" | **reported** (plan label, `stated`) |
| East wall, full depth | 13'3" | **reported** (plan label, `stated`) |
| West wall, north part (north wall → jog) | 56 1/2" | **assumed**: 230 px ÷ 4.075 = 56.4" |
| Jog, step east (powder room intrusion) | 20 3/4" | **assumed**: 83 px ÷ 4.000 = 20.75" |
| West wall, south part (along powder room) | 102 1/2" | **derived** by closure 159 − 56.5; drawing reads 102.6" |
| South wall | 90 1/4" | **derived** by closure 111 − 20.75; drawing reads 90.25" |
| Door, east wall: north corner → near jamb | 2 3/4" | **assumed**: 11 px ÷ 4.075 = 2.7" |
| Door opening width | 35" | **assumed**: 142 px ÷ 4.075 = 34.85" |
| Door hinge | north jamb (`near`), swings in | **assumed**: from the drawn leaf and arc |
| Door height | 6'-8" | **assumed**: house default |
| Ceiling | 8'-0" | **assumed**: house default, not on plan |
| Wall thickness | 4" | house default, cosmetic |

Neighbours per plan: the 10'1" x 8'10" room to the north, hall to the east, powder room
(6'10" x 6'0") in the south-west, electrical closet to the south.

## Suite 114 — rooms `10'10" x 9'10"` (west) and `10'11" x 9'10"` (east)

**Orientation:** labels are horizontal. West room 410 × 375 px; ratio 1.09 against
130/118 = 1.10 (the swap would be 0.91), so the first number is E-W. **Derived.**

**Scale anchors:** each room's own label.
- West room: E-W 410 px = 130" → **3.154 px/in**; N-S 375 px = 118" → **3.178 px/in**.
- East room: E-W 406 px = 131" → **3.099 px/in**; N-S 375 px = 118" → **3.178 px/in**.
- The drawing makes the "10'11"" room 4 px *narrower* than the "10'10"" room. The labels are
  approximate at the 1-inch level.

| Dimension | West room | East room | Provenance |
|---|---|---|---|
| E-W (north & south walls) | 10'10" | 10'11" | **reported** (plan label, `stated`) |
| N-S (east & west walls) | 9'10" | 9'10" | **reported** (plan label, `stated`) |
| Door wall | south, to the 43'8" hall | south, to the 43'8" hall | **observed** on plan |
| Near jamb from its SW / SE corner | 9 1/2" from SW (built as `at` 86 1/4" from the SE corner) | 9 3/4" from SE | **assumed**: 30 px ÷ 3.154; 30 px ÷ 3.099 |
| Opening width | 34 1/4" | 35 1/2" | **assumed**: 108 px ÷ 3.154; 110 px ÷ 3.099 |
| Hinge | west jamb (`far`), swings in | east jamb (`near`), swings in | **assumed**: from the drawn leaf and arc |
| Door height | 6'-8" | 6'-8" | **assumed**: house default |
| Ceiling | 8'-0" | 8'-0" | **assumed**: house default, not on plan |
| Wall thickness | 3 1/2" | 3 1/2" | **assumed**: half of the partition below, cosmetic |

**Shared partition:** 22 px ≈ 7". The north and south interior faces sit on the same pixel
rows in both rooms. The rooms are built with that true offset: east origin = west origin +
130" + 7". Walls are 3 1/2" each so they meet inside the partition instead of overlapping.
The partition thickness is **assumed** (scaled).

## Model placement

- Suite 128 is at origin x=420", Suite 114 west at x=700", Suite 114 east at x=837"
  (all y=0 at the north wall).
- The spacing between the two suites is arbitrary: they are different buildings.
- Both suites are clear of a pre-existing group named "Room" (x −184..304", y −364..124")
  that was already in the Untitled model. It was not touched.
- The `WR-Ceiling` tag was hidden for the top-down shots.
- `build-takeoff.rb` puts no text in the model (`NOTES_IN_MODEL = false`, Benton's 1 Sep
  2026 rule). The assumptions live in the build report, the lock and the review sheet, not
  as in-model notes.

## Open questions — ask before quoting

1. **Ceiling heights in both suites.** Nothing is stated; 8'-0" is drawn as the default.
   This disqualifies a booth faster than floor area does.
2. **Suite 128 jog.** Get the real distance from the north wall to the powder-room corner
   (~56 1/2") and the step (~20 3/4"). It decides the usable width of the south part
   (~90 1/4").
3. **Door hinges and swings.** All three are read off the plan symbols. Confirm them, and
   confirm the door widths (~34–35") and positions.
4. **Stated sizes vs the drawing.** In 114 the "10'11"" room draws narrower than the
   "10'10"" room. Tape both E-W widths; any booth fit near 130" has no margin to spare.
5. **Which room is the "far back room"** in each suite? Not drawn.
   - 128 is probably the 7'7" x 13'10" room at the north end, which has an exterior door,
     or the 15'0" x 19'3" hall area. The email says it is "open to the hall".
   - 114 is probably the 17'1" x 19'11" or the 15'10" x 19'11" room.
   - This is **assumed**; ask the client.

## Booth placement — the quoted MDL 4872 S (added 14 Sep 2026, same session)

**Source.** Link `sales portal /booth-builder#3=AQUkM4VkAQUHBAoBAAYA`, decoded by
`WR_BoothLink.v3_payload` (**observed**):

| Wall (booth-local) | Pack | Part built |
|---|---|---|
| N0 | WA STDDRFRM R | RightWADoorWithRamp |
| N1 | STDWL19 | 19Panel |
| S0 | STDWL46 VNT | 46VNT_VSS_EFS |
| S1 | STDWL22 | 22PanelSolid |
| E0 | STDWL46 WDO3236 | 46Panel3236WDO, with the small desk outside |
| W0 | STDWL46 | 46PanelSolid |

Options: ramp, VSS, EFS, outside desk, MJP jack panel, elevated floor. Package
"Audiology Basic Plus". Built headlessly from `P:/Sketchup/NewMasterComponentList`
with every part present: 23 instances.

**Ceiling the room must give: 83.00" (6'-11").** Printed by the build. Both suites are
drawn at the 8'-0" default, which leaves 13" — but that ceiling is **assumed**.

### Which walls carry what — this corrects the brief's 129.6 × 65 footprint

- The 4872's **N and S walls are the 74" long walls**; E and W are the 50" ends.
  **Observed** from `WR_BOOTH_DATA` (w=74 along x, N0/S0 span x 2..48) and from the
  built parts.
- The door with its ramp (N0) and the vent with its EFS (S0) are therefore on
  **opposite long walls**. The desk (E0) is on a short end.

Clearances, per CLAUDE.md / `layout-render.js` `clrIn`:

| Side | Rule | Built part reaches |
|---|---|---|
| Door wall with ramp | 45.625" | 45.6" (**observed**) |
| Vent wall with EFS | 10" | 10.0" |
| Outside-desk wall | 14" | 13.75" |
| Plain wall | 1" | — |

Footprint with clearances (**derived**):
- Across the booth, door side to vent side: **105.625"** (45.625 + 50 + 10).
- Along the booth: **89"** (14 + 74 + 1).
- The brief's 129.6 × 65 assumed the door and vent sat on the short ends. With the
  real walls, Suite 128 cannot take the booth long-axis N-S: that needs 105.6" E-W
  and the narrow part is 90.25". Suite 114 is not a zero-margin fit.

### Placement rule used

In each room the door and ramp face open floor toward that room's entry. Per axis the
booth hugs the wall with the lower clearance and opens toward the higher one — the
`layout-render.js` corner rule. Every clearance zone sits inside the room, and every
booth part was checked against the entry door's swing box.

Margins below are **observed** from model bounds after placement. Wall gap = booth shell
to the interior face; spare = gap minus that side's clearance.

**Suite 128 — 13'3 x 9'3 room.** Rotation 0: long axis E-W, door faces north (the entry
end). Shell x 441.75..515.75, y −149..−99 (model).

| Side | Faces | Wall gap | Rule | Spare |
|---|---|---|---|---|
| W | jog wall (narrow part) | 1.0" | 1 | 0 |
| E | desk | 15.25" (desk tip 1.5" off the wall) | 14 | 1.25" |
| S | EFS | 10.0" (EFS touches the wall) | 10 | 0 |
| N | ramp | 99.0" (ramp tip 53.4" off the north wall) | 45.625 | 53.375" |

- No overlap with the entry door swing: the ramp tip clears the swing box by 15.65" N-S.
- The whole booth stands in the narrow south part, x ≥ the jog.
- **Tight axis: E-W, 1.25" spare** against a scaled 90.25" width.

**Suite 114 — 10'10 x 9'10 room.** Rotation 180: long axis E-W, door faces south (the
entry wall). Shell x 755..829, y −60..−10.

| Side | Faces | Wall gap | Rule | Spare |
|---|---|---|---|---|
| E | plain, to the partition | 1.0" | 1 | 0 |
| W | desk | 55.0" | 14 | 41.0" |
| N | EFS | 10.0" (EFS touches the wall) | 10 | 0 |
| S | ramp | 58.0" | 45.625 | 12.375" |

No overlap with the entry swing: the ramp part clears it by 34.25" E-W, the desk by
33.75" N-S.

**Suite 114 — 10'11 x 9'10 room.** Rotation −90: long axis N-S, door faces **east**
(toward the entry end). Shell x 847..897, y −75..−1.

| Side | Faces | Wall gap | Rule | Spare |
|---|---|---|---|---|
| W | EFS, to the partition | 10.0" | 10 | 0 |
| E | ramp | 71.0" | 45.625 | 25.375" |
| N | plain | 1.0" | 1 | 0 |
| S | desk | 43.0" | 14 | 29.0" |

- No overlap with the entry swing: the ramp clears it by 30.5" N-S, the desk by
  35.75" E-W.
- **Not placed — the alternative, rotation 180 (door facing the south entry wall):**
  the ramp lands on the entry door's swing whichever wall it hugs. Hugging west, the
  ramp's clearance band overlaps the swing box by 2.25" × 23.1" and the ramp part
  itself by 0.25". Hugging east, the overlap is far larger. **Derived**, not built.
  That is why this room differs from its neighbour. Choosing between the two is
  Benton's call.

### Model state

- The booth groups are named `MDL 4872 S (components) — in <room>` and carry
  `wr_booth_place/room` and `/link`.
- The rooms were rebuilt once after placement to restore their dimensions (see below);
  the booth transforms were confirmed unchanged.
- `WR-Ceiling` and `WR-Booth-Deck` are hidden for the plan shots.
- Model unsaved.

**Unexplained loss — read this.** Between the room screenshots (10:06) and the booth
placement readback (10:14), the Untitled model lost its pre-existing "Room" group (its
definition went too) **and** all 20 room dimensions.
- None of this session's bridge jobs erases at model level.
- The bridge does not wrap jobs in undo operations.
- The booth chain calls no dimensioner.
- No plugin observers are registered.
- The cause is not found. An action in the live SketchUp window is the remaining
  possibility and was not checked.
- The dimensions were restored by re-running `build_from`. **The "Room" group was not
  restored** (it was not ours, and undo is off-limits).
