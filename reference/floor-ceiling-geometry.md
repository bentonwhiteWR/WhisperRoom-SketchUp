# Floor and ceiling panels — measured geometry

Measured 2026-08-14 with `scripts/probe-levels.rb` against
`P:\Sketchup\NewMasterComponentList` — 25 `FL` parts and 27 `CL` parts. Every
number here is **observed**, from horizontal-face heights in each definition's
own coordinates. Nothing is inferred from a name.

Raw data: `_face-levels.tsv` in that folder.

---

## The one rule that matters

**Do not trust a panel's origin, and do not trust its name.** Both lie, in
different ways, and both lie inconsistently — the same lesson the wall panels
taught. Placement must come from the measured faces.

- The **name is not the size**. `STD9648FL CTR` measures 47.938 × 96, not 96 × 48.
- **The packing list is not the part.** It lists the component *packaged up* —
  the crate, not the panel. That is why it says `3.25` thick where the geometry
  measures **3.108**, and it is not an error in either place. Take sizes from the
  probe; take *which parts a model needs* from the packing list. Never sizes.
  (`STD6042FL SIDE L/R` measure **3.500**, alone in the set — that one is a real
  difference in the part, not packaging.)
- The **origin is not consistent**. Floors all run z 0 → 3.108. Ceilings come in
  **two authoring conventions**, below.

---

## Floors (`FL`) — one convention, and it is clean

Every floor panel measures the same way:

| z | area | what it is |
|---|---|---|
| **1.0000** | ~100% | **top of the structural deck** |
| 0.0000 | 93–100% | underside, sits on the host floor |
| 1.7500 | 9–24% | present on **SIDE panels only** |

So the deck is a **1.000″ slab from z 0 to z 1.0**, and the bounding box runs to
3.108 because something stands ~2.1″ proud of it *without a large flat top* —
i.e. vertical plates. Those are the hinge brackets.

**The 1.7500 level is the bracket tops, not a perimeter strip.** The evidence is
that it is absent from every CTR panel — `STD10218FL CTR`, `STD10242FL CTR`,
`STD9624FL CTR`, `STD9648FL CTR`, `STD8418 FL` — and present on every SIDE
panel. That matches Benton exactly: *"the center won't have any on its sides,
but the sides will since they attach to walls on their sides."*

It also settles it by contradiction: if walls sat on a 1.75 strip, a CTR panel
could not carry a wall at all, and CTR panels do meet end walls.

> **Therefore: the wall's underside sits at the floor's z = 1.0000.**
> **CONFIRMED by Benton, 2026-08-14.** Derived from the area distribution first,
> then checked — which is the right order.
>
> **The door frame sits on the deck too**, same z. Confirmed at the same time,
> so there is no threshold step to model: door and wall share a base plane.

Small `0.0312` levels (6–8% area) on some CTR panels are a 1/32″ lip on the
underside. Not structural.

---

## Ceilings (`CL`) — TWO conventions, and this is the trap

Same part family, two different origins. Anything that assumes one will place
half the library wrong.

**Convention A — slab at the TOP of the box** (`10218 CTR`, `10242 CTR/SIDE`,
`4230`, `4260`, `4284`, `4872`, `6018 SIDE R`, `6042 SIDE L/R`, `7224 SIDE R`,
`7248 SIDE L`, `8418`, `8442 CTR/SIDE`):

| z | area |
|---|---|
| 3.1094 | 100% — box top |
| 2.1094 | 100% (or 21–34% on the small ones) |
| 1.3594 | 87–94% |

**Convention B — slab at the BOTTOM of the box** (`4242`, `4848`, `4896`,
`9624 CTR`, `9648 CTR`, `9648 SIDE`):

| z | area |
|---|---|
| 1.7500 | 90–94% |
| 1.0000 | 29–45% |
| 0.0000 | 100% |

Convention B is the same shape as the floors. Convention A is that shape shifted
up by ~1.36″.

`STD127LPCL` is a third case again: z −2.358 → 1.000, with levels at 1.0, 0.0
and −1.0. **Deferred on Benton's instruction** — the 127 LP is out of scope for
now. Do not let it drive the general rule.

### B is A upside down. The heights prove it.

Mirror convention A about its own box centre (1.554) and every level lands on a
convention-B level, exactly:

| A | mirrored | B |
|---|---|---|
| 3.1094 (100%) | 0.0000 | 0.0000 (100%) |
| 2.1094 (100%) | 1.0000 | 1.0000 (29–45%) |
| 1.3594 (87–94%) | 1.7500 | 1.7500 (90–94%) |

Three heights, all matching to four decimals. That is not coincidence — the two
families are **the same part modelled the other way up**. The one difference is
the middle level's area (100% on A, 29–45% on B), which is a real difference
between parts in how much of the middle skin is solid, not a difference of
convention.

### The rule that places both

1. The **slab** is the face pair exactly 1.000″ apart.
   A: 3.1094 / 2.1094. B: 1.0000 / 0.0000.
2. The **third, minor level** is always on the ROOM side of the slab —
   below it on A (1.3594), above it on B (1.7500).
3. **The wall contacts the slab face nearest that third level.**
   A → **2.1094**. B → **1.0000**.

One rule, no per-part table, and it self-corrects if a part is re-exported the
other way up. **Derived, not confirmed** — it will be obvious on the first build
if it is wrong, because the ceiling will sit a hair over an inch out.

Never use `bounds.min.z`.

---

## Seam seals

Floor seals `STDSS FL6/7/8` — box 7.190 × (72/84/96) × 1.691, z **−1.0031 →
0.6875**. Levels at 0.6875, 0.4375, 0.0625, 0.0000, −0.9375, −1.0000. Note the
negative origin: these hang **below** their insertion point.

Ceiling seals split the same two ways as the ceilings: `CL5/6/7` run z 0 → 2.0;
`CL8` and `8.5CL` run z −0.75 → 1.25. Same shape, shifted.

`STDSS FL5` and `STDSS FL8.5` **do not exist** in the folder, though `CL5` and
`8.5CL` do. Either floors do not need a seal at those widths, or two parts are
missing. Worth asking before a build depends on it.

---

## What SIDE L and SIDE R actually mean

**They are not about the panel. They are about the WALL RUN underneath it.**

Every wall run on a SIDE panel is made of one large wall component (40″ or 46″)
and one small one (16″ or 22″). The panel carries hinge brackets at the
positions those two walls land — visible on `STD6042CL SIDE R` as callouts
reading *16" Wall Placement* and *40" Wall Placement* along one long edge, and
*40" Wall Placement* along the other.

Because 16 + 40 does not split the run evenly, **the bracket pattern is
asymmetric**, and which end the small wall sits at is the whole difference
between L and R. Benton's rule, in his words:

> If the small wall is further away, we use the SIDE R. If the small component
> was closer to the nearest corner seam seal to us, we would use a SIDE L.

The same applies to the 72 series.

**This does not need a per-model table.** `wr-booth-data.rb` already knows every
wall run's panel order and lengths, so it already knows which end of each run
holds the small panel. The handing follows from that.

What it *does* need is one anchor: which end of the panel's own coordinates the
small-wall bracket sits at.

### The hinge spacing IS the anchor, and it is measurable

Benton, 2026-08-14. On a 72 in panel the hinges sit either side of each wall and
the gap between a pair says which wall drops into that slot:

| gap | slot |
|---|---|
| **2′ 1/8″ (24.125)** | the **46″** wall |
| **1′ 9 1/8″ (21.125)** | the **22″** wall |

**Read the first figure carefully — it is two FEET and an eighth.** Recorded here
as 2.125 initially, which is wrong and would match nothing.

Only booths with a split wall run are affected: **6060, 6084, 7272, 7296**.

Customers get this wrong constantly, and the tell is that the hinge pockets do
not line up. So the panel carries its own orientation and the builder should
read it rather than be told.

**Both long edges carry the same pattern**, so there is one cue, not two.

### FLOOR AND CEILING HINGES ARE COPLANAR IN PLAN

Also Benton: with the floor directly below the ceiling — as if a wall stood
between them, floor hinges facing up and ceiling hinges facing down — **the
hinges land on exactly the same plan positions.**

That is an INVARIANT, and it is worth more than the rule it supports:

- Floor and ceiling of a pair take the **same rotation in plan**. The ceiling is
  the floor's orientation, turned over vertically. They are never decided
  independently — which is precisely what was being done, and why the two kept
  disagreeing with each other.
- It is a **free correctness check**. After placing a deck, the floor hinges and
  the ceiling hinges above them must share x and y. If they do not, the
  orientation is wrong and the model can say so without anyone looking at it.

### The older reading: L and R as an unmeasurable mirror pair

Measured 2026-08-14, `STD6042FL SIDE L` against `STD6042FL SIDE R`:

| | SIDE L | SIDE R |
|---|---|---|
| box | 41.969 × 60.000 × 3.500 | 41.969 × 60.000 × 3.500 |
| levels | 1.7500 / 1.0000 / 0.0000 | 1.7500 / 1.0000 / 0.0000 |
| areas | 337.0 / 2545.5 / 2473.1 | 337.0 / 2545.5 / 2473.1 |
| above-deck span | 0.875 .. 59.108 | 0.875 .. 59.108 |

**Identical to four decimals on every metric.** `STD6042CL SIDE L` and `SIDE R`
likewise. That is what a mirror image looks like: reflecting a part about the
midpoint of its long axis preserves the bounding box, every face height, every
area, and the outer extent of the brackets. Nothing short of comparing
individual bracket positions can tell them apart, and even that only works if
the brackets can be separated from the perimeter rim — which they cannot here,
because the rim runs the full length and merges with them.

So do **not** try to derive the handing from geometry. It is not in there.

### Resolve it with one named constant

    SIDE_R_SMALL_WALL_AT_LOW_END = true   # or false

Pick a value, build one booth, look at it. If the brackets miss the wall seams
they miss by the difference between the large and small panel — 24″ on the 40/16
runs — so a wrong guess is unmissable, not subtle. Flip the constant and it is
right everywhere, because every model resolves through the same rule.

This is the same shape as `FACE_OUT` in `build-booth-components.rb`: one flag,
named, with the check written next to it.

### Probe limitation, recorded so it is not re-attempted

`probe-levels.rb`'s bracket reporting merged everything into one span because
the 1.7500 rim face runs the full length of the panel and overlaps every
bracket. It also prints nothing for ceilings, because their deck is detected at
the top of the box and nothing sits above it. Neither is evidence about the
parts — it is the tool's reach. Separating brackets would need clustering by
connected geometry in 2D rather than merging 1D spans along one axis.

## Still unconfirmed
2. **`STDSS FL5` and `STDSS FL8.5` do not exist** although `CL5` and `8.5CL` do.
   Either floors need no seal at those widths, or two parts are missing.

## Settled

- Wall underside at floor **z = 1.0000**. Confirmed.
- Door frame on the same plane as the wall — no threshold step. Confirmed.
- Packing-list dimensions are the *packaged* part. Sizes come from the probe.
- 127 LP deferred.
