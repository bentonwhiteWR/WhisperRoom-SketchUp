# Roof-mount ventilation — placement, from Benton

**Source: Benton, 31 Aug 2026, in conversation.** Stated field/design figures, not derived
from any file — except where marked measured, which is measured live off the parts.

**Status: RESOLVED and SHIPPED (plugin 1.14.0).** The roof unit is seated by
`scripts/wr-overlays.rb`'s `place_roof_unit` on any `rv = 1` link, using the rule in
`scripts/wr-roof-vent.rb`. What is still refused by name is at the bottom.

---

## The rule, as Benton settled it

**1. Default — centre the unit on the booth's NOMINAL footprint.** ("Yes on almost all.")
The nominal footprint is the model number in inches; it sits **1" inboard of the exterior
face per side**, so a booth whose exterior is `w × h` carries its nominal rectangle from
`(1, 1)` to `(w − 1, h − 1)` in booth-local coordinates.

**2. Exception — the four 84-inch-WIDE models go FLUSH RIGHT:** `4284`, `6084`, `8484`,
`10284`. Benton, verbatim: *"Shift those to the right. The left side should have the gap of
3.25, and no gap on the right side."* His reason: on those booths the EFS is tight, so the
unit sits on the right edge. Front and back stay centred.

The arithmetic closes exactly, which is why the exception is believable rather than a
rounding: each of those four flat parts **measures 80.750" wide against an 84" nominal**, so
`3.250 + 80.750 + 0 = 84.000`. Centring split that same slack into the 1.625" a side that
made the parts look wrong against his earlier stated 3.125".

**3. VSS parts are correct as authored.** The stack fits the envelope. So a booth's ceiling
requirement is quoted from the **measured per-part height**, never from the stated 16.5" —
which is a drawing figure for the tallest case. Sixteen of the 22 VSS parts measure the same
10.3125" as their flat twin and are quoted at that; the six that measure taller (`4260`,
`4284`, `4872`, `4896`, `6060`, `7272`) are simply taller and say so. Quoting 16.5" for all
of them over-reported the ceiling, which disqualifies booths that fit.

**4. HX booths take the SAME part.** Benton: *"No HX components for RM. These RM components
just sit on the ceiling. Albeit, 10" higher since the roof is 10" higher."* The absent
`RM<model>_HX.skp` was never a gap. Nothing in the code adds 10 anywhere: the unit is seated
on the booth's **measured** roof plane, and an HX booth raises that plane by being built from
91" panels instead of 81" (`build-booth-components.rb`), which agrees with `HX_ADD`.
`ceiling_required` adds the same `HX_ADD` to the install clearance, so an HX roof-mount
booth's ceiling figure follows the booth up (103.31" on an 8484, observed live).

## Which side is "right" — the convention, stated

`CLAUDE.md` forbids unanchored left/right claims, so this is anchored twice.

**From the code:** `scripts/booth-from-link.rb`'s `WALL_WORD` — the portal's own words for
each wall, identical on all 25 catalogue layouts — reads `N => Back, S => Front, E => Right,
W => Left`. `scripts/wr-booth-data.rb` places those slots: S panels at low y, N at high y, W
at low x, E at high x (observed). Therefore, in booth-local coordinates:

| Direction | Meaning |
|---|---|
| **+x** | the booth's **RIGHT** — the E wall the booth builder labels "Right" |
| −x | LEFT (W) |
| −y | FRONT (S, the door wall) |
| +y | BACK (N) |

"Right" is your right when you **stand in front of the booth and look at it**. That is also
the vocabulary Benton is reading when he says "right", because it is what the booth builder's
"YOUR BOOTH" panel prints.

**From the viewport,** because a geometric assertion cannot catch a mirrored convention:
`.forge/builder/roof-vent/seat-shot.py` builds the booths live and photographs them. Measured
off the front elevation of an `8484` (12.22 px/in): booth exterior 86.0", nominal footprint
84.0", `RM8484` 80.75", **gap LEFT 3.27", gap RIGHT 0.00"**. The `7272` control gives 3.27"
on both sides. The door (hand R on the front wall) is on the left of every front elevation
and at the bottom of every top view, which fixes the orientation in the same frame.

## Measured, all 22 models

The full table is `MEASURED` in `scripts/wr-roof-vent.rb`; re-run
`.forge/builder/roof-vent/measure-rm.py` to reproduce it. What it settled:

- **Front and back land on the nominal footprint exactly on all 22** — 4" a side, or 3" on
  `4284` / `8484` / `84102` / `84126`. Those are **consequences of centring**, not inputs,
  and they are what confirmed the reference face Benton had not settled: it is neither the
  exterior nor the interior, it is **nominal**.
- **`RM102186.skp` corroborates it.** Twenty-one of the 22 files are authored recentred on
  the origin; that one is not. It sits at `(3.250, 4.000, 0)` in its own file, exactly its
  own centred per-side offsets.
- Left/right slack is **not** the uniform 3.125" originally stated. Exactly one model
  (`9696`) measures 3.125 a side; fourteen measure 3.250; the four 84-wide measure 1.625 if
  centred (which is why they are shifted instead); `4260`/`6060` measure 2.943 and `84102`
  3.000. Centring absorbs all of that without needing a per-model number.

---

## Still refused, by name

1. **`rv = 1` on `4230` / `4242` / `4848` / `127 LP`.** No `RM<model>.skp` exists and the
   portal does not offer roof-mounted ventilation on those sizes. Such a link cannot describe
   a real booth, and it is not harmless: its vent walls arrive already swapped to cable walls,
   so building it would produce a booth with **no ventilation at all**.
2. **A part that does not fit its booth's nominal footprint.** `seat` refuses rather than
   hanging the unit over an edge. Nothing on the share does this today; the guard exists so a
   re-exported part that grew is caught instead of drawn.

## The one thing left for Benton to correct

The flush-right shift is implemented **by model width — those four models, always** — and is
**not** conditional on the EFS flag. Benton gave EFS as the reason but named all four models
unconditionally, and hedged with *"I think those are the 84 size booths for the most part."*
So a `6084` with **no** EFS is shifted too. Every roof-mounted build prints this in the
console, in those words, so it is visible rather than silent. If a `6084` without EFS should
in fact be centred, that is a one-line change to `FLUSH_RIGHT_MODELS` plus a condition.

## Standing rule this sits under

`CLAUDE.md`: clearance, ventilation routing and placement are **not** things to invent. A
number that cannot be sourced from the catalogue, a prior drawing, or Benton is asked for,
not assumed — and anything assumed is marked assumed all the way into the model.

## Also from Benton, same conversation

- Each `RM<model>.skp` is **one complete roof assembly** — both boxes, ducts, everything. It
  needs seating, not assembling.
- An RM booth's ceiling requirement is **booth + unit height**. The portal's fit card checks
  only `standingHeight + 2` and never adds this, so it under-reports on RM booths. That is in
  `WhisperRoomQuote` (read-only here); routed to Benton, not fixed by us.
