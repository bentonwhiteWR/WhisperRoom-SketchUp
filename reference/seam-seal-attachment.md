# Seam seals in plan — how corner and mid-wall seals attach to the walls

Written for an agent generating **top-down (plan) artwork** of a WhisperRoom booth, with no
access to the SketchUp workspace this came from. Everything needed to draw a seal, place it,
and check that a wall closes is in this file. All dimensions are **inches**.

Scope: **Standard (`S`) variant wall assemblies only.** Enhanced (`E`) has a 4.25 wall
thickness and its panel lengths are unresolved in the layout data — do not extrapolate this
geometry to it.

**Sources, so you can weigh each number.** Part dimensions and the closure rule are
**reported** from `reference/booth-components.md`, which Benton took off his own assembled
source drawings, Aug 2026. Every plan polygon and station in this file is **observed** — read
out of `scripts/wr-booth-data.rb`, the generated layout data, and re-derived from the
generator that produced it (`scripts/gen-booth.py`, lines 44–228). The two agree exactly on
every booth checked. The one number that is **assumed** is called out in its own section at
the bottom; nothing else here is guessed.

---

## The one rule that matters

**Panels do not touch, and walls do not run corner to corner.** The seals are structural
members of the plan, not trim drawn on afterwards.

- At every joint the two panels butt into the *interior* of a **mid-wall seam seal**, whose
  2 in stem fills the gap between them.
- At every corner a **corner seam seal** makes the corner. It is the outermost element there
  — the booth's exterior corner *is* the corner seal.

So a wall's interior run is:

```
interior wall run = Σ(panel lengths) + 2 in × (number of joints)
```

Draw a wall as panels butted end to end and it will come up 2 in short per joint, and the
booth will not close.

---

## Coordinate frame used throughout

Origin at the **south-west exterior corner**, `x` east, `y` north, plan view looking down.

| Symbol | Meaning | 4872 S | 96120 S |
|---|---|---|---|
| `W` | exterior width (x) | 74 | 122 |
| `H` | exterior depth (y) | 50 | 98 |
| `t` | wall assembly thickness, Standard | **2** | 2 |
| `PANEL_T` | wall panel thickness | **1** | 1 |
| `band` = `t − PANEL_T` | outboard band the seal plates live in | **1** | 1 |

4872 S is `W = 74, H = 50`, interior `70 × 46`. 96120 S is `W = 122, H = 98`, interior
`118 × 94`. **Exterior = interior + 4** on every Standard booth: 1 in panel + 1 in seal plate
per side.

The interior clear rectangle is `x` from `t` to `W − t`, `y` from `t` to `H − t`.

---

## The three-layer wall section, in plan

Reading outward from the room on the south wall:

| `y` band | what is there |
|---|---|
| `y = 2` | **interior face.** Panel face and seal stem face are coplanar here. |
| `y = 1 … 2` | the **1 in wall panel** — and, at a joint, the seal's 2 in stem instead. |
| `y = 0 … 1` | the **outboard band**: empty except where a seal plate or a corner leg sits. |
| `y = 0` | **exterior face.** Only seals reach this plane. |

Two consequences a plan renderer will trip on:

1. **The interior outline is a clean rectangle.** Panels and seal stems are flush, so the room
   side draws as a plain `iw × ih` rectangle with no bumps. (Subject to the one assumption at
   the bottom of this file.)
2. **The exterior outline is *not* strictly a rectangle.** The panel's outer face is recessed
   1 in from the exterior plane; only the corner seals and the seal base plates reach it. The
   quoted exterior `W × H` is measured **over the seals**, which is why it is always
   interior + 4 even though most of the wall face sits an inch inside it.

At plan scales anyone actually prints (1/4 in = 1 ft-0 in puts 1 in at 1/48 in on paper) that
1 in recess is below line weight. **Drawing the exterior as a plain `W × H` rectangle is
correct to within 1 in** — but if you are drawing an exploded or large-scale detail, the
recess is real and the seals are what stand proud.

---

## Mid-wall seam seal — T-shaped in plan

One piece. Overall **7 3/4 wide × 2 deep**, made of:

- a **base plate 7 3/4 long × 1 thick**, sitting in the outboard band, flush with the
  exterior face;
- a **2 wide stem**, centred on the plate, filling the full 1 in panel depth — so
  **2 7/8 of plate shows each side of the stem** (`2 7/8 + 2 + 2 7/8 = 7 3/4`).

The two panels butt into the sides of the stem. That is the whole attachment: nothing laps
over the panel face, and the seal does not stand proud of the panel on the room side.

### Plan of a joint on the south wall

Horizontal: **one character = 1/8 in**, exact. Vertical: **one text line = 1 in** of wall
depth. The two axes are not the same scale — read widths off the drawing, read depths off the
labels.

```
                   interior of the booth  (+y)  —  panel face and stem face are coplanar
y = 2    ----------------------------------------------------------------------------------------------
         #######################################================#######################################
y = 1    ---------------------------------------                ---------------------------------------
                         ==============================================================
y = 0                    --------------------------------------------------------------
                   exterior of the booth  (−y)  —  only the seal reaches this plane

                         <------- 2 7/8 -------><- 2 in stem --><------- 2 7/8 ------->
                         <----------------- 7 3/4 in seal base plate ----------------->

  #  = 1 in wall panel      =  = mid-wall seam seal      blank = void, outboard band
  A rule is drawn only where there is a real face: note that y = 1 breaks under the stem,
  because the seal is continuous through it, and that y = 0 exists only under the plate.
  The panel ends stop dead against the stem sides. They never meet each other.
```

Note what the drawing shows: in the `y = 1…2` band the panel runs right up to the stem, and
in the `y = 0…1` band there is **nothing but air** either side of the 7 3/4 plate.

### Exact vertex lists

`m` = the **joint centre station** along the wall (see next section). Eight points, in order.

| Wall | Polygon |
|---|---|
| **S** | `(m−1, 2) (m−1, 1) (m−3.875, 1) (m−3.875, 0) (m+3.875, 0) (m+3.875, 1) (m+1, 1) (m+1, 2)` |
| **N** | `(m−1, H−2) (m−1, H−1) (m−3.875, H−1) (m−3.875, H) (m+3.875, H) (m+3.875, H−1) (m+1, H−1) (m+1, H−2)` |
| **W** | `(2, m−1) (2, m+1) (1, m+1) (1, m+3.875) (0, m+3.875) (0, m−3.875) (1, m−3.875) (1, m−1)` |
| **E** | `(W−2, m−1) (W−1, m−1) (W−1, m−3.875) (W, m−3.875) (W, m+3.875) (W−1, m+3.875) (W−1, m+1) (W−2, m+1)` |

Equivalently, as two rectangles (easier to draw, identical result on the S wall):

- plate: `x` from `m−3.875` to `m+3.875`, `y` from `0` to `1`
- stem: `x` from `m−1` to `m+1`, `y` from `1` to `2`

### Where the joint centre goes

Walk the wall from the interior face of the adjacent wall, taking each panel at its true
length and each joint at 2 in.

```
m(k) = t + Σ(lengths of the first k panels) + 2 × (k − 1) + 1        # k = 1, 2, 3 …
```

`+1` because `m` is the *centre* of the 2 in gap.

On **N and S** walls slots run **west → east** and `m` is an `x`. On **E and W** walls the
slot list runs **north → south** — the booth builder's own convention, matching
`layout-render.js`'s top-down — so walk from the north end and convert:

```
m_y = H − ( t + Σ(first k panel lengths) + 2 × (k − 1) + 1 )
```

Getting that flip wrong mirrors every E/W wall end for end. It was a live bug here until
2026-08-11.

---

## Corner seam seal — L-shaped in plan

One piece, **4 7/8 × 4 7/8 overall, 1 in leg thickness**, with a small inner block. It sits
entirely in the outboard band and at the corner itself, and it **consumes none of the wall
run** — panel runs start at `x = t` / `y = t`, outboard of which the corner seal lives.

Decomposed as three rectangles, SW corner:

| Piece | Extent | What it is |
|---|---|---|
| A | `x 0 … 4.875`, `y 0 … 1` | leg along the south wall, in the outboard band |
| B | `x 0 … 1`, `y 0 … 4.875` | leg along the west wall, in that wall's outboard band |
| C | `x 1 … 2`, `y 1 … 2` | **1 × 1 inner block** — the two panel ends butt into this |

That block C is the attachment. The south wall's first panel starts at `x = 2` and dies
against the block's east face; the west wall's first panel starts at `y = 2` and dies against
its north face.

The reference's "inner faces at 2 7/8 and 1" is the same fact stated from the interior: the
leg reaches `4.875 − 2 = 2 7/8` beyond the adjacent wall's interior face, and it is 1 thick.

### Plan of the SW corner

Same convention as before, and **the same caveat about the two axes**: one character = 1/8 in
across, one text line = 1 in up, so the L looks stretched. It is square — 4 7/8 each way.

```
   y                                 into the booth (+y)  ^
 4 7/8 | ########                     <- both legs stop at 4 7/8
   4   | ########
   3   | ########
   2   | ########
       | ################             <- y 1..2: the leg PLUS the 1x1 inner block (x 1..2)
   1   | #######################################
   0   +----------------------------------------
         0       1       2       3       4   4 7/8
                         ^
                         panel runs begin here (x = t = 2), butting the block

  Each text line is 1 in of y except the top one, which is the last 7/8.
  Rows y 2..4 7/8 are the west wall's leg only; row y 1..2 adds the inner block;
  row y 0..1 is the south wall's leg running the full 4 7/8.
```

### Exact vertex lists

Eight points, in order. Mirror per corner:

| Corner | Polygon |
|---|---|
| **SW** | `(0,0) (4.875,0) (4.875,1) (2,1) (2,2) (1,2) (1,4.875) (0,4.875)` |
| **SE** | `(W,0) (W−4.875,0) (W−4.875,1) (W−2,1) (W−2,2) (W−1,2) (W−1,4.875) (W,4.875)` |
| **NW** | `(0,H) (4.875,H) (4.875,H−1) (2,H−1) (2,H−2) (1,H−2) (1,H−4.875) (0,H−4.875)` |
| **NE** | `(W,H) (W−4.875,H) (W−4.875,H−1) (W−2,H−1) (W−2,H−2) (W−1,H−2) (W−1,H−4.875) (W,H−4.875)` |

### Orientation — four legal positions, never anything else

A corner seal is **always square with the walls**. There are exactly four orientations, one
per corner, and the correct one is whichever puts the L's centre of mass nearest the corner it
wraps — equivalently, whichever aims the L's mass *away* from the booth's middle. The 3D
placement code arrives at this by trying all four and keeping the best, precisely because
computing an angle from a centroid produced 45° answers that a corner seal can never have. In
plan you do not need the search: use the vertex table above.

### Does a corner seal ever collide with a mid-wall seal?

No, on any standard booth. The corner leg ends at `4.875`; the nearest seal plate begins at
`m − 3.875`, and the smallest stock panel is 7, giving `m ≥ 2 + 7 + 1 = 10` and a plate edge
at `6.125`. Clearance 1.25 in minimum (**derived**). A first panel shorter than 6 3/4 would
overlap — none is made.

---

## Worked closure — MDL 4872 S

Exterior `74 × 50`, interior `70 × 46`, `t = 2`.

**North / south walls, run 70:** panels `46 + 22`, one joint.

```
46 + 22 = 68
68 + 2 × 1 joint = 70   ✓ closes on the interior run
```

Stations on the south wall, walking from `x = 2`:

| Element | Extent in x | Extent in y |
|---|---|---|
| panel S0 (46, door frame) | 2 … 48 | 1 … 2 |
| seal stem | 48 … 50 | 1 … 2 |
| seal base plate | 45.125 … 52.875 | 0 … 1 |
| panel S1 (22) | 50 … 72 | 1 … 2 |

`72 = W − t` ✓. Joint centre `m = 2 + 46 + 1 = 49`, plate `49 ± 3.875 = 45.125 … 52.875`.
These are the exact numbers in the generated layout data — **observed**, not recomputed here.

**East / west walls, run 46:** a single 46 panel, no joint, `46 + 0 = 46` ✓. Panel W0 occupies
`x 1 … 2, y 2 … 48`; panel E0 occupies `x 72 … 73, y 2 … 48`.

**Four corner seals**, per the SW/SE/NW/NE table with `W = 74, H = 50`.

### Second check — MDL 96120 S

Exterior `122 × 98`, interior `118 × 94`.

| Wall | Panels | Joints | Arithmetic | Run |
|---|---|---|---|---|
| N / S | 46 + 22 + 46 | 2 | `114 + 4` | **118** ✓ |
| E / W | 46 + 46 | 1 | `92 + 2` | **94** ✓ |

South wall stations: panels `2…48`, `50…72`, `74…120`; joint centres `m = 49` and `m = 73`;
plates `45.125…52.875` and `69.125…76.875`. West wall (walking north → south) has its single
joint at `m_y = 98 − (2 + 46 + 1) = 49`, plate `45.125…52.875` in `y`.

---

## Panel lengths — do not read them off `booth-layouts.json`

If you are pulling from `booth-layouts.json` in `WhisperRoomQuote`, its per-slot `size` values
are **not panel lengths**. They record the run, inconsistently:

- the 4872 lists its narrow panel as `24` — that is the 22 panel with its 2 in seal absorbed;
- the 96120 lists its sides as `47 + 47` — the real build is `46 + seal + 46`.

Panels are only ever made in these lengths: **7, 16, 19, 22, 28, 31, 40, 43, 46**. Solve panel
lengths from the run instead — take the slot sizes as the *order*, then snap to stock lengths
totalling `run − 2 × joints`. The 4872's `24` is a data error worth fixing at source.

Two more from the same file, both **reported** from `reference/booth-components.md`:

- **Per-slot `kind` is a default, not a constraint.** Door frames, vent walls, cable walls,
  window walls and plain walls swap freely into any position.
- The 4872's own assembly drawing puts vent and door on the **short** walls facing each other,
  while the JSON puts them on the long walls. Both are valid; confirm per job.

---

## Two things that move a seal along a wall

Both change where you draw the joint. Neither changes the seal itself.

**Wide-access door frames.** A WA frame is 49 wide, wider than the 46 or 40 module the layout
reserves. The companion panel shrinks to keep the run (`46+22 → 49+19`, `40+40 → 49+31`), so
the seal shifts **3 in on a 46-series wall and 9 in on a 40-series**. Re-walk the wall from
real part widths; the run still closes because `short + 2 + big` sums the same as
`big + 2 + short`.

**The big-run-at-the-door-end convention.** On the four split-run booths — 6060, 6084, 7272,
7296 — WhisperRoom's own build puts the **big** run on each E/W wall at the **door end**,
which is the reverse of what the generated layout data says. The floor and ceiling panels'
hinge slots confirm it. The seal shifts **24 in** on all four (46/22 on the 7272 and 7296,
40/16 on the 6060 and 6084). Every other model is symmetric on E and W — the 96168 is 46+46,
the 102126 is 40+16+40 — so nothing reverses. This is a build convention, not a data fact:
**verify against the job** before redrawing a plan on it.

---

## What is not known — do not fill these in

**The mid-wall seal's stem projection depth is not dimensioned** on Benton's source drawing.
`reference/booth-components.md` lists it under "still needed". Everything in this file models
the stem as exactly 1 in deep — flush with the panel on both faces — which is what the layout
generator assumes and what the 3D build places. That is **assumed**, not measured.

**For a pure top-down plan this almost certainly does not matter, and here is why.** If the
stem is flush, the interior wall line is straight. If the real stem projects into the room by
some depth `d`, every joint gains a 2 in wide × `d` bump on the interior line. For that bump
to be visible at 1/4 in = 1 ft-0 in it would have to be several inches deep — a stem that
proud would be a visible feature of the booth interior, and the drawing would have dimensioned
it. **Draw it flush; label the assumption if the drawing is a detail rather than a plan.** Do
not invent a projection number.

Also still undimensioned in `reference/booth-components.md`, and two of these *will* bite a
top-down renderer:

- **Door leaf thickness and swing geometry.** You cannot draw a correct swing arc without it.
  In the 3D build the door leaf is modelled standing open, ~32 in of leaf depth on a 49 in
  frame — that is the modelled part, not a dimensioned swing. Get the real number before
  drawing an arc.
- **Vent duct and silencer box dimensions.** The vent assembly **projects outward beyond the
  booth footprint** on its wall. A plan that stops at the exterior rectangle is missing it,
  and the room-clearance rules (6 in at a vented wall, 10 in with exterior fan silencers) exist
  because of it.
- Floor and ceiling component geometry — irrelevant to a wall plan.
- The list also still says "panel height", but that is now settled: **81 in**, stated in the
  same file. Treat that line as stale.

---

## Checklist before shipping a plan

1. Every wall: `Σ panels + 2 × joints` equals the interior run exactly. Say the closure.
2. A mid-wall seal at every joint; four corner seals; no wall drawn corner to corner.
3. Seal plates and corner legs in the outboard band, flush to the exterior plane; panels
   recessed 1 in behind it.
4. E/W walls walked north → south, not south → north.
5. Panel lengths snapped to stock, never taken from `booth-layouts.json` slot sizes.
6. Anything you could not source — swing arc, vent projection, stem depth — flagged on the
   drawing rather than drawn from a guess.
