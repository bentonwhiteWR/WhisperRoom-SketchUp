# Intelligence Security Laboratories — Room 452, MDL 6060 E ENV

14 Sep 2026. Inputs:
- Five room photos, `plans/IMG_3801.JPG`–`IMG_3805.JPG`. These are gitignored and carry no measurements.
- The booth-builder link `https://sales.whisperroom.com/booth-builder?d=187bf0c5c898`.
- The client's email of 14 Sep, which supersedes the room fields typed into the builder.

The model is Benton's saved file `Z:/Sketchup/ClientDrawings/Intelligence Security Laboratories MDL 6060 ENV.skp`. It was built through the bridge and **not saved**.

## Client measurements (email 14 Sep, verbatim)

> Width: 65", expanding to 67" for about 1/3 of the room
> Length: 96" due to the door handle, 100" at its longest. If we cannot switch to a sliding door this is reduced. The door itself is 36" but we would be ok with not being able to open the door all the way to get in. We measures a door opening at 18" as sufficient to enter comfortably, meaning that in this case the max length would be approx 78".
> Ceiling: Lowest is 90", the first third of the room is 114"

These replace the booth-builder room fields: width 100", length 65", ceiling 7'6".

## How the room was read

- **Short wall.** The glass front is the short wall, and 100" runs away from it (observed).
  - IMG_3801/3802, taken from the doorway, look down a deep, narrow room.
  - IMG_3805, from inside, shows the front as one door leaf plus a sidelight roughly 21" wide.
- **Orientation (assumed; the photos carry no north).**
  - The glass front is drawn as south.
  - From inside looking out, the door is at the left end, so the solid hinge-side wall is east.
  - The desk and glass-return side is west.
- **The door swings in** (observed and reported).
  - IMG_3805 shows the hinge knuckles on the east jamb from inside.
  - IMG_3801 shows the leaf standing open inside the room.
  - The client's wording confirms it.
- **The 67" third (assumed) sits at the front, with the 2" step in the west wall, 33" from the glass front.** Reasons:
  - The glass partition returns north along the west wall for about that far.
  - In IMG_3801 the glass-to-drywall junction shows a black end member facing the doorway, which reads as the drywall standing proud of the glass.
  - It is the same "first third" as the 114" ceiling, where IMG_3802 shows open deck above the doorway.
  - The client did not say which third or which side.
- **Ceiling.**
  - Built at 90", the lowest and governing figure; a take-off room carries one ceiling.
  - The 114" zone over the first third is **not built**. Its edge is assumed at the same 33" line, 67" from the back wall.
  - A suspended cloud with a linear pendant light hangs over the 90" zone (observed, IMG_3801/3802). How far the pendant drops is unknown.
- **Not modelled:** the client's furniture (desk, chair, bin along the west wall).

## Dimensions and provenance

| Item | Value | Provenance |
|---|---|---|
| Back (N) wall | 65" | reported — client email |
| East wall | 100" | reported — client email ("100\" at its longest") |
| Clear length to the closed door's handle | 96" | reported — client email; the handle projects 4" |
| Front (S) glass wall | 67" | reported — client email; that it is the front third is assumed |
| West wall, glass return (front) | 33" | **assumed** — "about 1/3" of 100" |
| West wall step | 2" | derived — 67 − 65 |
| West wall, drywall (back) | 67" | derived — 100 − 33 |
| Ceiling | 90" built; 114" over the first third | reported — client email; the zone edge is **assumed** at 33" |
| Room door width | 36" | reported — client email |
| Room door jamb offset, east wall to hinge jamb | 6" (range 3–8") | **assumed** — scaled off the 36" leaf in IMG_3805 |
| Room door height | 84" | **assumed** — commercial 80–84" range |
| Room door hinge | east (near) jamb | **assumed** — read off IMG_3805 and IMG_3801/3802 |
| Booth | MDL 6060 E, 62 × 62" exterior, 85" install height | reported — link payload and `models.json` |
| Booth as drawn | top 84.31" | observed — model bounds |

Checker: `python scripts/takeoff-check.py clients/intelligence-security-laboratories/takeoff.json --html` exit 0. It flags 5 values (3 assumed, 2 derived closure) and 1 assumed hinge.

## The booth link (observed, re-fetched from `/api/booth-design/187bf0c5c898`)

- `MDL 6060`, variant `E`, `nv 1` (no ventilation).
- Door `S0` = `STDWL40 DRFRM L`.
- `N0` and `E0` = `STDWL40 VNT NV`.
- Desk inside on `W0` (`dk 1`, `dox 0`).
- `fc S`.

**Tool defect found and fixed (1.71.1).** `booth-from-link.rb`'s `component_for` matched `STDWL40 VNT NV` as a vent wall. It built `40VNT`, which carries 6.4" of exterior vent housing, on a booth quoted with no ventilation. The quote tool's renderer treats `VNT NV` as a no-vent plug wall. The fix builds `40NV` / `ENH 35.5NV`; both are on the parts share. The first build was erased, and the booth was rebuilt with the plug walls.

## Placement

- **Position.** The booth is at the back of the room, in the 65" part. The shell spans x 1..63 and y −63..−1 (the back wall is y 0; the glass front is y −100).
- **Orientation.** No rotation. The booth door faces south, toward the room door.
- **Booth door.** It is in the west half of the booth's front face. The hinges are at its west edge (observed from the part, x 8.75–13.17). The ~24" leaf swings out toward the room door.
- **Why only this position.** The door wall needs 62 + 23.5 + 1 = 86.5" along one axis. Across the room that is 65/67", so it cannot fit. The booth door therefore has to face the length of the room, and the booth has to sit against the back wall, because against the front it would block the room door.

### Margins (observed from model bounds unless marked)

| Side | Gap | Rule | Note |
|---|---|---|---|
| West | 1.0" | 1" | shell to the drywall |
| East | 2.0" to the shell | 1" | a booth interior light's bounding box reaches 0.78" from the wall; see open items |
| North (back) | 1.0" | 1" | |
| Front | booth door bulk 35.16" from the glass front; shell face 37.0" | 23.5" door swing | |
| Ceiling | booth drawn top 84.31", **5.69"** under 90"; catalog install height 85", **5.0"** | | the whole booth sits under the 90" zone; its front is 2.16" behind the assumed edge of the 114" zone |

### The two doors

- **Room door fully open, booth door shut.** The leaf lies along the east wall and reaches 36" into the room. The nearest booth part (the SE corner seal) is **1.0" outside** the room door's full swing circle (observed). The room door opens all the way, with 1" to spare, provided the assumed 6" jamb offset and a pivot at the wall face hold.
- **Room door closed, booth door opening.** The booth door's swing reaches y −86.4, 13.6" from the glass (derived from the part). The closed door's handle stands 4" off the glass. The booth door **opens fully, with 9.6" to the handle** (9.5" by the 23.5" rule).
- **Room door opened to 18" (the client's entry case).**
  - By the clearance rule, the booth door needs 86.5" from the back wall. The client's "max length approx 78"" leaves an **8.5" overlap** between the booth-door clearance and the room door's restricted swing.
  - Geometry (derived): at an 18" opening the room leaf is at 29°. Its tip is 17.4" off the glass and its handle about 19.7".
  - The booth door pivots at the other end of its face, so the two leaves' paths miss each other: the room leaf tip clears the booth door's swept arc by **2.1"** at the assumed 6" jamb offset.
  - That clearance falls to **0.9"** at an 8" offset and rises to 4.1" at 3". It is only as good as that assumed offset.
  - People cannot use both doors at once. In practice: enter through 18", close the room door, then open the booth door.
- **Sliding-door case (reported by the client as an option).** 1 + 62 + 23.5 = 86.5 ≤ 96, which leaves 9.5" spare to the 96" handle line and 13.5" to the 100" wall.

## Open questions

- Tape-confirm the room: 65 / 67 × 100 × 90". The booth-builder fields (100 × 65 × 7'6") are superseded.
- Which third is 67" wide and on which side, and where exactly the width steps (assumed: the front third, west side, 33").
- The room door's jamb offset from the east wall (assumed 6"; the 18" case turns on it), its hinge side (assumed east), and its height.
- The pendant light's drop, and anything under the cloud or duct below 85". Where the 114" zone ends.
- Delivery path: panels have to come through a 36" door in a glass front. The booth's 40" wall panels are wider than the opening, so check the panel height against the door height and whether anything blocks tilting them through.
- Whether the client moves to a sliding door; that gives the full 96–100".

## Model state

- **Top-level contents:** the group `ISL Room 452`, 8 room dimensions, and the group `MDL 6060 E (components) — in ISL Room 452`. The booth group carries `wr_booth_place/room` and `wr_booth_place/link`.
- **Hidden for the shots:** `WR-Ceiling` and `WR-Booth-Deck`. The camera was changed.
- **Not saved.**
- **Gaps:** no booth-to-wall gap dimensions and no door-to-corner dimensions. Neither tool draws these cleanly here.
- **Unexplained: the room dimensions left the model twice.**
  - First, the 100 × 65 room's 6 dimensions were gone before that room was erased.
  - Second, the rebuilt room's 8 dimensions survived the booth build (8 before, 8 after), then were gone by the next dimension count. Only these ran in between: a read-only door-part dump, a job that hid `WR-Ceiling` / `WR-Booth-Deck`, set the camera and set `DisplayText`, and two viewport shots.
  - Ruled out by test (observed): toggling both tags, setting the camera, taking a shot, and setting `DisplayText` each left the count at 8.
  - Cause not found. A human action in the live window is not ruled out.
  - Restored by re-running `build_from` on the lock, which leaves the booth's transform unchanged (observed). 8 dimensions on `WR-Dims` at hand-off.
