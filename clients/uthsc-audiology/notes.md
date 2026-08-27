# UTHSC Audiology & Speech Pathology — four-room take-off

**Status: read off the client's plan, unconfirmed by tape. NO BOOTH SELECTED and none drawn.**

| | |
|---|---|
| Client | University of Tennessee Health Science Center, Dept. of Audiology & Speech Pathology |
| Contact | Saravanan Elangovan, Ph.D. |
| Rooms | Four, marked in red handwriting **1**, **2**, **3**, **4** on the suite plan |
| Source | `UTFloorLayout.png` — dimensioned suite plan, UT Conference Center, red markup (client-supplied, **not in git**) |
| Script | `scripts/uthsc-audiology-rooms.rb` (`@tab client`) |
| Read on | 2026-08-27 |
| Site visit | Tuesday |

The booth models come off the sales quote. Nothing in this file or in the script
recommends, implies, or sizes one.

---

## Scale anchor

The plan carries **its own printed dimension strings** on every room, so no scale bar was
traced and no ratio was fitted — the dimension strings *are* the anchor. Every one was
cropped from the source and upscaled 8–16× (PIL/LANCZOS) before it was trusted; nothing
was read off the image at full size.

The source is only **941 × 510 px**, so anything *not* printed as text has to be scaled off
pixels at roughly **1.5 in per pixel**. That is the dividing line between the two grades of
number below, and it is why door positions carry ±3 in and wall lengths do not.

Independent confirmation that the strings are read right: every room's printed square
footage closes on its own dimension strings (worst case 0.6 %), and the pixel geometry of
the red room outline agrees with every string to within one pixel.

---

## Per-room dimensions

Precise decimals kept here; the drawing rounds to the nearest inch per the house standard.

| Room | Run | Feet-inches | Inches | Decimal ft | Provenance |
|---|---|---|---|---|---|
| **1** | width (E–W) | 19'-11¼" | 239.25 | 19.938 | **observed** — printed string |
| | depth (N–S) | 22'-4¼" | 268.25 | 22.354 | **observed** — printed string |
| | *printed area* | | | 444.92 sf | computes 445.69 sf (0.17 % over) |
| **2** | total width (S run) | 18'-10¼" | 226.25 | 18.854 | **observed** — printed string |
| | **east** wall (long) | 22'-4¼" | 268.25 | 22.354 | **observed** — printed string |
| | **west** wall (short) | 15'-8¼" | 188.25 | 15.688 | **observed** — printed string |
| | entrance-leg width | 5'-10½" | 70.50 | 5.875 | **observed** — printed string |
| | entrance-leg depth | 6'-8" | 80.00 | 6.667 | **derived** — 268.25 − 188.25 |
| | notch (main-body N run) | 12'-11¾" | 155.75 | 12.979 | **derived** — 226.25 − 70.50 |
| | *printed area* | | | 333.45 sf | computes 334.94 sf (0.44 % over) |
| **3** | width (E–W) | 19'-3½" | 231.50 | 19.292 | **observed** — printed string |
| | depth (N–S) | 12'-11" | 155.00 | 12.917 | **observed** — printed string |
| | *printed area* | | | 249.3 sf | computes 249.18 sf (0.05 % under) |
| **4** | width (E–W) | 19'-4¾" | 232.75 | 19.396 | **observed** — printed string |
| | depth (N–S) | 12'-11¼" | 155.25 | 12.938 | **observed** — printed string |
| | *printed area* | | | 249.44 sf | computes 250.93 sf (0.6 % over) |

Suite runs used to place the rooms relative to one another:

| Run | Feet-inches | Inches | Provenance |
|---|---|---|---|
| Left block, bottom overall | 39'-7¾" | 475.75 | **observed** |
| Left block, left-side overall | **44'-¼"** | 528.25 | **observed** — see the note below |
| Unnumbered 170.87 sf room (between 3 and 2) | 12'-1¼" × 14'-1" | 145.25 × 169.00 | **observed** — not drawn, only in the chain |
| Suite top overall | 85'-4¼" | 1024.25 | **observed** — outside the four rooms, not used |

> **Correction to carry forward: that left-side overall reads `44'-¼"`, not `44'-1¼"`.**
> It was cropped and upscaled 16× to settle it — there is no whole-inch digit before the
> ¼. One inch, but it is the number the whole left-hand depth chain closes against.

Derived partitions, each one what a printed overall has left over:

| Partition | Inches | Provenance |
|---|---|---|
| Room 2 \| Room 1 | 10.25 | **derived** — 475.75 − 226.25 − 239.25 |
| Room 3 \| Room 4 | 11.50 | **derived** — 475.75 − 231.50 − 232.75 |
| Room 3 \| 170.87 room, and 170.87 room \| Room 2 | 8.00 each | **derived** — (528.25 − 155 − 169 − 188.25) ÷ 2 |

---

## Room 2 is L-shaped — this is the thing that will catch you out

Room 2's printed area does not close on a bounding box, and that is not a misread digit.
**The room is an L.**

- Main body **18'-10¼" × 15'-8¼"**.
- The room then continues **up the right-hand (east) side only**, as an entrance leg
  **5'-10½"** wide.
- Leg depth = 22'-4¼" (east wall) − 15'-8¼" (west wall) = **6'-8" exactly**. A whole
  number falling out of two independently printed dimensions is good evidence the set is
  read right.
- Notch removed from the top-left = **12'-11¾" × 6'-8"**.

Area check: (226.25 × 188.25) + (70.50 × 80.00) = 48,231.6 sq in = **334.94 sf** against the
printed **333.45 sf** — 0.44 % over, right in line with Room 1 (0.17 %) and Room 4 (0.6 %).
A rectangle misses by 11 %.

Both chains close, and both are stated on the drawing:

- width: 12'-11¾" + 5'-10½" = **18'-10¼"**
- depth: 15'-8¼" + 6'-8" = **22'-4¼"**

Room 2's east wall and Room 1's west wall are both 22'-4¼" and they are adjacent. That
shared depth is the cross-check on the relative placement of the two rooms, and it holds.

### The "chain that does not close" — resolved, closed, not an open item

An earlier pass assumed Room 2 was a rectangle and, when the area would not close, went
looking for a misread digit in `15'-8¼"` (proposing `17'-8¼"`). **There is no misread
digit.** Two independent checks kill it:

1. The glyph, upscaled 8×, is unambiguously a **5**.
2. Room 2's depth measures **127.5 px** of red outline against a scale of 8.090 px/ft
   established from Room 3 — that is 15.76 ft. `17'-8¼"` would need 143 px.

With the real geometry the left-hand chain closes normally:
155.00 + 169.00 + 188.25 = **512.25 in** of interior against the **528.25 in** overall,
leaving **16.00 in** across the two intervening partitions — 8.0 in each, against 8.9 in and
7.4 in measured off the pixels. **Nothing is open here.** It was an artifact of the
rectangle assumption.

---

## Doors — all four are derived, none are dimensioned on the plan

**The plan puts no dimension on any of these four doors.** Everything below was scaled off
the wall gaps in the raster and is good to about **±3 in**. Each wants a tape on site.

| Room | Wall | Corner → near jamb | Framed opening | Hinge | Swing |
|---|---|---|---|---|---|
| 1 | north | 16¾" from the **NE** corner | 38½" | east jamb | into the room |
| 2 | north wall of the entrance leg | 13¼" from the leg's **NE** corner | 37" | east jamb | into the leg |
| 3 | south | 179½" from the **SW** corner (10½" back from the SE corner) | 41½" | east jamb | into the room |
| 4 | south | 177" from the **SW** corner (15¾" back from the SE corner) | 40" | east jamb | into the room |

Each of those closes on its own wall: 16.75 + 38.5 + 184 = 239.25; 13.25 + 37 + 20.25 =
70.50; 179.5 + 41.5 + 10.5 = 231.50; 177 + 40 + 15.75 = 232.75.

What is *solid* is the pattern — one door near the east end of the wall, hinged on its east
jamb, swinging in, in a framed opening scaling 37–42 in. Four independent reads agreeing is
why the hinge sides are stated rather than hedged. **41 in of framed opening is consistent
with a 3'-0" leaf in its frame**, which is also the only door width the plan calls out
anywhere (a `3'-0"` mid-plan, well away from these rooms). The script draws a **3'-0" leaf,
assumed**, inside the measured opening.

### What could not be read at all — say this to the client

Only **one door per room is legible** in the source. The underlying black linework is drawn
far lighter than the red markup and on most wall runs it does not survive the raster.
**This is not evidence that there are no other openings.** In particular, **no opening could
be confirmed or ruled out in the wall Room 1 and Room 2 share** — the region is covered by
dimension-line arrowheads and the wall itself does not render.

---

## Ceiling height — not measured, and it is the big one

**The plan states no ceiling height anywhere, for any room.** All four are drawn at the
**8'-0" house default** and labelled as such on the model and in the console summary.

Ceiling height disqualifies a booth faster than floor area does and it is the number
clients forget. Nothing here should be quoted as fitting until all four are taped.

---

## What is measured / derived / assumed, in one list

**Observed** (printed on the plan, cropped and upscaled to read): every room dimension in
the table above; the 39'-7¾" and 44'-¼" overalls; the 170.87 sf room's 12'-1¼" × 14'-1";
the four printed areas.

**Derived** (arithmetic on observed numbers, or scaled off pixels): Room 2's 6'-8" leg depth
and 12'-11¾" notch; the three partition thicknesses; every door position and every framed
opening width (±3 in).

**Assumed** (house defaults, on the drawing but not from the plan): 8'-0" ceilings; 6'-8"
door height; 3'-0" door leaf; 4" wall thickness — cosmetic, built outward from the interior
face so it never moves an interior dimension.

**Unresolved:** Rooms 3 and 4 print depths 1/4 in apart (12'-11" vs 12'-11¼") while sharing
a north face. Both are drawn as printed, so their south faces land 1/4 in apart. The raster
cannot resolve a quarter inch either way. That jog is the plan's, not the model's, and it
does not matter to anything.

---

## Site-visit checklist — Tuesday

**1. Ceiling heights, all four rooms. First, before anything else.**
The plan gives none, so every one of them is an 8'-0" assumption right now. Measure floor
to the **lowest** obstruction, not to the nominal ceiling — duct, sprinkler, light, grid.
Note whether each room is a lay-in tile grid or open structure.

**2. Room 2's shape and its entrance leg.**
The wall dimensions all close, but Room 2 is the only non-rectangular room and the leg
depth (6'-8") and notch (12'-11¾") are derived rather than printed. One tape across the
notch confirms the whole L.

**3. Every door — width and position.**
None of the four is dimensioned on the plan. For each: clear opening width, corner to near
jamb, hinge side, and which way it swings. Then check for **doors the raster could not
show** — especially any opening between Rooms 1 and 2.

**4. Delivery path.** Booth wall panels ship flat and assemble in place, so the path is a
real constraint, not a formality. Measure and note:
   - The **suite entrance** (marked at the top of the plan) — clear width with the door
     open, and whether the leaf can be removed.
   - Every **corridor width** and, more importantly, every **corner** the panels have to be
     turned through. Corners kill more deliveries than straight runs do.
   - **Elevator**: car width, depth, door opening, and interior diagonal — or confirm the
     rooms are all on the entry level.
   - **Stairs**: the plan notes *"stairs lead to attic for storage use"*, so at minimum
     confirm nothing on the delivery path routes through them.
   - Threshold heights, floor transitions, and anything fixed in the path.

   Panel widths to check clearances against: **7 / 16 / 19 / 22 / 28 / 31 / 40 / 43 / 46 in**,
   and the wide-access / ADA door frame at **49 in**. Those are the numbers that decide
   whether panels make it down a corridor.

**5. In-room services.** Electrical outlet positions and available circuits, and where any
ventilation could exit. Neither is on the plan and neither is mine to invent.

---

## Deliverable

`scripts/uthsc-audiology-rooms.rb` builds all four rooms in **true relative position** as
one suite group — floors, mitred walls, real door openings with headers and swing arcs,
all four sides dimensioned on every room, all six runs dimensioned on Room 2 with both
chain closures stated, every door dimensioned corner-to-near-jamb, and the two printed suite
overalls drawn outside the room chains. It prints the full not-measured list to the console
on every build so the caveats travel with the model.

Load it with:

```
load "C:/Users/bento/Documents/Claude/Sketchup/scripts/uthsc-audiology-rooms.rb"
```

**The script has never been run.** There is no Ruby interpreter on this machine outside
SketchUp. It passes a real syntax check (`scripts/rbparse.py`, which drives the CRuby 3.2
library SketchUp ships) and the build is wrapped so it aborts the operation and prints one
`FAILED:` line rather than leaving a half-built model — but nothing has executed it.
