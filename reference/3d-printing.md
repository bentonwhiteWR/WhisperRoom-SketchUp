# 3D printing from SketchUp

Everything the pendant-side fixtures (`scripts/pendant-jig.rb`,
`scripts/tube-drying-stand.rb`) are designed against. Read this before changing
a fixture's geometry — most of the odd-looking features in those scripts exist
to satisfy something on this page.

---

## The printer

**Dremel DigiLab 3D45.** Verified against Dremel's spec sheet and an
independent review, Aug 2026:

| | |
|---|---|
| Build volume | **254 × 152 × 170 mm** |
| Nozzle | **0.4 mm** — line width ~0.45, which every "how many extrusion widths" figure in the scripts assumes |
| Bed | Removable glass, heated to 100 °C |
| Enclosure | Yes — good for ABS/nylon, **cuts part cooling for PLA** |
| Materials | PLA, Eco-ABS, Nylon, PETG |
| Layers | 50–300 µm |
| Slicer | Dremel DigiLab 3D Slicer, Cura-derived |

Both current fixtures fit with room to spare — the drying stand is
123.5 × 74.9 and uses under half the plate.

### Two settings that are not the defaults

- **Build plate adhesion → Brim.** Dremel's recommended settings use a
  *skirt*, which is a priming loop and does nothing for adhesion. The drying
  stand's first layer is 3 069 mm² of 2 mm-wide lattice strips on smooth
  glass; it wants a brim.
- **Run the door open for PLA.** The enclosure raises chamber temperature,
  which is the opposite of what bridging needs. The stand's 10.15 mm pocket
  bridge is the only figure in either fixture sitting at its limit.

---

## The limits these parts are designed against

Sourced, not remembered:

| Rule | Figure | Note |
|---|---|---|
| Overhang | **45° from vertical** | Generic FDM limit. The 3D45 tested clean at 40–65°, so there is real margin. |
| Bridging | **~10 mm** ideal, 5 mm always safe | Anchored at *both* ends. A one-end cantilever is a different, weaker case. |
| Cantilever / inward step | a few mm | Works because each extrusion line only overhangs the previous by one line width, not because the total is small. |
| Round holes in vertical walls | avoid | The crown exceeds 45°. Use a **diamond** — no flank steeper than its apex, and symmetric, so print orientation does not matter. |

### Design rules that follow

- **Orientation is a design input, not a slicer decision.** Both fixtures are
  drawn in *use* orientation and printed inverted, and both have a
  `FLIP_FOR_PRINT` constant that draws them the printing way up instead.
  - *Jig:* socket opening up, so the shoulder the housing registers against
    prints on top of solid material rather than drooping as a ceiling.
  - *Stand:* wall tops on the bed, which is what allows four corner feet
    instead of ribs. Right way up the plate is a 123 × 75 unsupported overhang.
- **Internal corners always get a fillet from the nozzle.** Where a part has to
  seat flat against a shoulder, cut a **corner relief groove** so that fillet
  falls outside the mating part. The jig's 0.80 × 0.80 groove does this.
- **First-layer faces get squeezed** (elephant's foot). Chamfer any bore whose
  mouth lands on the bed — the jig's 0.60 guide-mouth chamfer.
- **Overlap stacked solids by ~0.50 mm.** Coincident faces are the one thing
  slicers handle badly; overlapping bodies they union without complaint.
- **Ledge width and unsupported span are the same number.** On the stand, the
  2.00 mm ledge is both what catches the tube and what hangs over the pocket.
  A chamfer cannot separate them — the first layer is exposed either way.

---

## Clearances that have been used

`CLEARANCE = 0.25` on diameter (0.125 radial) is Benton's standing allowance
for a part that still has to press in with a little play. Everything below is
built on it and **none of it is confirmed by a print yet.**

| Fit | Value | Where |
|---|---|---|
| Housing into jig socket | +0.25 on Ø | `pendant-jig.rb` |
| Tube into jig guide | +0.25 on Ø | `pendant-jig.rb` |
| Tube into stand pocket | +0.50 on the square | `tube-drying-stand.rb` |

**Print the jig first.** It is ~18 g and about an hour, and it calibrates the
0.25 figure on this printer before 94 g and most of a day goes into the stand.
If the housing is tight or sloppy in the jig, the same correction applies to
`POCKET_CLEAR`.

---

## Material

PLA is fine for both. Two things that would change that:

- **Heat.** PLA softens at 55–60 °C. Small epoxy pours never get near it, but a
  fast-curing epoxy or a big simultaneous batch builds exotherm — use **PETG**,
  which the 3D45 handles.
- **Adhesion.** Cured epoxy bonds to PLA. The jig has a glue gutter at the
  shoulder for exactly this; the stand's ledges have no such protection, so
  treat it as a consumable or use a wax release.

---

## What the scripts check for you

Both print a self-audit to the Ruby Console on every run. Read it rather than
trusting the model looks right:

- **Naked edges — must be 0.** An edge with anything other than two faces on it
  is a crack. This is what caught the `follow_me` seam on the jig, where the
  model looked perfect and was not a solid.
- **Volume against an independent calculation.** The jig checks its mesh volume
  against Pappus's theorem; anything beyond the ~0.13% faceting error means the
  mesh is wrong. The stand reports the analytic *union* volume, because summing
  its overlapping panels would double-count every wall crossing.
- **Overhang audit**, surface by surface, in print orientation.
- **A list of every number that was chosen rather than measured.**

There is no Ruby interpreter on either machine outside SketchUp, so nothing in
`scripts/` has been syntax-checked before it reaches the Ruby Console. Geometry
is verified numerically beforehand; the API calls are not.
