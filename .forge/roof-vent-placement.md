# Roof-mount ventilation — placement, from Benton

**Source: Benton, 31 Aug 2026, in conversation.** These are stated field/design figures, not
derived from any file. Treat them the way a take-off treats a pen callout: exact where stated,
and **never extended by inference to the cases he did not state.**

## Stated, verbatim in substance

> "from the 'front' of the booth, all of them (except the 84 series) would be 4" off the front
> edge. Also 4" off of the back edge. 3.125" off the left edge for most, and most are 3.125"
> off the right edge, unless they have an EFS which might directly be on the right edge.
> 84 series are 3" off the front and back"

| Edge | Offset | Applies to |
|---|---|---|
| Front | 4" | all except the 84 series |
| Back | 4" | all except the 84 series |
| Front | 3" | 84 series |
| Back | 3" | 84 series |
| Left | 3.125" | "most" — exceptions **not enumerated** |
| Right | 3.125" | "most" — except EFS, see below |

## What is NOT settled — do not invent any of it

1. **"most" (left and right).** Benton said *most* are 3.125" on each side and did not name the
   exceptions. There is at least an implied exception set and it is unknown. A part that does
   not fit 3.125"/3.125" is an exception — find them by measurement, list them, and ask.
2. **EFS on the right.** *"unless they have an EFS which **might** be directly on the right
   edge."* "Might" is his word. Whether an EFS booth's roof unit sits at 0" on the right is
   **unconfirmed**. Do not build it either way without asking.
3. **The reference face.** He was asked whether offsets are measured from the roof panel's
   edge, the wall's outer face, or the booth's interior face — those differ by wall thickness —
   and did not answer. **Unresolved.**
4. **Which models are "the 84 series."** Presumably `8484`, `84102`, `84126`; unconfirmed.
5. **HX booths.** No `RM*_HX.skp` exists on disk. Whether the same part sits 10" higher, or the
   height extension changes it, is unanswered.

## The numbers over-determine the geometry — use that

Front and back offsets are **both** stated, so the part's depth is fixed by arithmetic:
`booth depth − 8"` (or `− 6"` for the 84 series). Left and right likewise give
`booth width − 6.25"`.

So **measure a real `RM<model>.skp` bounding box and check it against that arithmetic.** If they
agree, the offsets and the reference face are confirmed empirically rather than assumed, and
gap (3) is closed without another round trip. If they disagree, that is a finding for Benton —
report it, do not adjust the numbers to fit.

Do the same across all 22 models with parts. Any model whose box does not satisfy 3.125" per
side is a candidate exception for gap (1); collect that list for him rather than guessing.

## Standing rule this sits under

`CLAUDE.md`: clearance, ventilation routing and placement are **not** things to invent. A number
that cannot be sourced from the catalog, a prior drawing, or Benton is asked for, not assumed —
and anything assumed is marked assumed all the way into the model.

## Also from Benton, same conversation

- Each `RM<model>.skp` is **one complete roof assembly** — both boxes, ducts, everything. It
  needs seating, not assembling.
- An RM booth's ceiling requirement is **booth + unit height**: catalog install clearance plus
  10" flat, or 16.5" with VSS stacked. The portal's fit card checks only `standingHeight + 2`
  and never adds this — it under-reports on RM booths. That is in `WhisperRoomQuote`
  (read-only here); routed to Benton, not fixed by us.
- Ship the cable-wall fix ahead of the roof geometry.
