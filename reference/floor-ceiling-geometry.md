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

**The unifying rule proposed first**, which works for convention A and not for
B: find the full-area face pair 1.000″ apart — the slab — and use its **lower**
face. On A that is 3.1094/2.1094, both 100%, giving contact at **2.1094**. On B
the only 1.000″-apart pair is 1.0/0.0 at 45%/100%, which is not the same shape,
so the rule does not transfer. **Which face carries the wall on a convention-B
ceiling is still open** — see below. Whatever the answer, never use
`bounds.min.z`.

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

## Still unconfirmed

1. **Which ceiling face the wall top meets.** The only open geometry question.
   Convention A says 2.1094 by the face-pair rule; convention B has no
   equivalent pair, and its 1.7500 level holds 90–94% of the area where the
   floors' 1.7500 holds only 9–24%. So the two families are not the same part
   flipped — B's 1.75 is a real surface, not bracket tops.
2. **Panel order across the booth.** SIDE at the ends, CTR in the middle, per
   Benton — the packing-list counts give how many of each — but the L/R handing
   has not been checked against a real booth.
3. **`STDSS FL5` and `STDSS FL8.5` do not exist** although `CL5` and `8.5CL` do.
   Either floors need no seal at those widths, or two parts are missing.

## Settled

- Wall underside at floor **z = 1.0000**. Confirmed.
- Door frame on the same plane as the wall — no threshold step. Confirmed.
- Packing-list dimensions are the *packaged* part. Sizes come from the probe.
- 127 LP deferred.
