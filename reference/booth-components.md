# Booth component geometry — finished parts

Real, as-built dimensions for modelling. Benton's source drawings, Aug 2026.

> ⚠️ **Do not take part geometry from `components-master.json`.** Its `L / W / T` come from
> `PackingList.xlsm` and are **shipping/crated** dimensions — it lists `STDWL46` as
> 82.5 × 48 × 2.75, where the finished panel is 46" long × 1" thick. Use that file for
> weights, quantities and pallet math; use this file for geometry.

## Wall panels

**Every wall panel is 1" thick.** Not 2", not 2.75". One inch.

| Panel | Plan length | Thickness |
|---|---|---|
| Std wall 46" | 46" (3'-10") | 1" |
| Std wall 22" | 22" | 1" |
| Std door frame + door 46" | 46" | 1" |
| Std wall 46" Vnt | 46" | 1" |

Panel names are their **plan length in inches** — a "46" wall" measures 46". The `size` in
`booth-layouts.json` is the same number, so slots and panels agree directly.

**Panel height is 81".**

## Seam seals

Panels do **not** butt edge to edge. Seam seals cover every joint and every corner, and they
are what actually make the corners — walls do not run corner to corner.

**Std mid-wall seam seal** — T-shaped in plan, symmetric:

- overall 7 3/4" wide, 1" thick at the base
- stem 2" wide, centred (2 7/8" of base each side of it)
- stem projection depth not dimensioned on the drawing — ask before modelling it

**Std corner seam seal** — L-shaped in plan:

- 4 7/8" × 4 7/8" overall
- 1" leg thickness
- inner faces at 2 7/8" and 1"

## How it goes together — 4872 S, assembled top-down

Confirmed from the assembled drawing:

- **Long walls** — `46" + 22"` end to end, with a **mid-wall seam seal** over the joint.
- **Short walls** — a **single 46" panel** each. One is the vent panel, the other the door
  frame. They face each other.
- **Four corner seam seals**, one per corner, and they are the outermost element at a corner.
- The **vent assembly projects outward** from the vent panel — duct and silencer sit proud of
  the booth footprint on that side.
- The **door frame occupies the full short wall**, hardware on the frame.

## The rule — this is the one to build from

**Panels do not touch.** At every joint, the two panels butt into the *interior* of a mid-wall
seam seal, and the seal's **2" stem fills the gap between them**. So:

```
interior wall run = Σ(panel lengths) + 2" × (number of joints)
```

It closes everywhere:

| Wall | Panels | Joints | Run | Interior |
|---|---|---|---|---|
| 4872 long | 46 + 22 | 1 | 68 + 2 = **70** | 70 ✓ |
| 4872 short | 46 | 0 | **46** | 46 ✓ |
| 96120 back | 46 + 22 + 46 | 2 | 114 + 4 = **118** | 118 ✓ |
| 96120 side | 46 + 46 | 1 | 92 + 2 = **94** | 94 ✓ |

Corner seam seals sit at the corners **outboard** and consume none of the run.

Wall assembly thickness is `1"` panel + `1"` seal plate = **2" per side**, which is exactly the
`wallThickness: 2` in `booth-layouts.json` for Standard. Exterior = interior + 4".

### This is why booth-layouts.json's slot sizes are unreliable

They record the run, not the panels, and inconsistently. The 4872 calls its narrow panel `24`
(the 22" panel with its 2" seal absorbed). The 96120 sides say `47 + 47` where the real build
is `46 + seal + 46`. **Derive panels from the rule above, not from the slot sizes.**

### Panel kinds are interchangeable

Door frames, vent walls, cable walls, window walls and plain walls all swap freely into any
position. `booth-layouts.json`'s per-slot `kind` is only a default — never treat it as a
constraint, and never tell a client a panel can't move.

## Assembly, from the 4872 S exploded top-down

Long walls (interior run 70") are `46" + 22"` with a **mid-wall seam seal** over the joint.
Short walls (interior run 46") are a **single 46" panel**. **Four corner seam seals**, one per
corner.

On that drawing the **vent panel and the door frame are both on short walls**, facing each
other. `booth-layouts.json` instead puts the vent and door on the two long walls. Both are
valid arrangements — the booth builder moves door and vents — but the JSON is the spec-sheet
default and Benton's drawing is a specific layout. **Confirm which one a given job wants
rather than assuming the JSON.**

`booth-layouts.json` also lists the narrow panel on the 4872 as `24`, while the drawing and
the part name both say `22`. The 96120 entry uses `22`. Treat 22 as the panel and the 4872's
`24` as a data error worth fixing at source.

## Still needed

- panel height
- mid-wall seam-seal stem projection
- floor and ceiling component geometry
- door leaf thickness and swing geometry
- vent duct and silencer box dimensions
