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

Height is not dimensioned on these drawings. Working value 82.5"; confirm before relying on it.

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

**Open arithmetic.** The long wall's panels total `46 + 22 = 68"`, but the Standard interior
run is `70"`. Two corner seam seals contributing 1" each at the ends would close that exactly
— but the same logic gives `46 + 2 = 48"` on the short wall against a 46" interior run, which
does not work. So the corner seal does not simply add 1" per end on both axes, and the real
rule is still unknown. **Do not model corners until this is settled.**

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
