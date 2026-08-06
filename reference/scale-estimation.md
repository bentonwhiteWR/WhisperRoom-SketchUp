# Estimating dimensions from a client floor plan

Clients send floor plans as PDFs, screenshots, and phone photos of printouts. Usually
without dimension strings, sometimes with a scale bar, occasionally with nothing but a
door in the drawing. This is how to get a defensible number out of that.

## 1. Pick one scale anchor and name it

In descending order of trust:

| Anchor | Trust | Notes |
|---|---|---|
| Printed scale bar | High | Measure the *whole* bar, not one tick — division error compounds. |
| Labeled dimension string on the drawing | High | Best anchor there is. Use the longest one available. |
| Stated drawing scale (`1/4" = 1'-0"`) | Medium | Only valid if the image is at true print size — a screenshot or a "fit to page" print voids it. Verify against something else before trusting it. |
| Known standard object | Low | Fallback only. Always produce a range. |

Use **one** anchor for the whole read. If a second anchor is available, use it as a
**cross-check** and report the disagreement — don't average them into a number that hides
the spread.

## 2. Measure the longest run available

Pixel-per-foot error is fixed per image; measuring a 40 ft wall spreads that error over
more feet than measuring a 3 ft closet. Establish the ratio on the longest confident run,
then derive everything else from it.

## 3. Standard-object fallbacks

Only when nothing better exists. Name the object you used, and give a range:

- Interior door leaf — 30–36 in residential, 36 in typical commercial
- Exterior/entry door — 36 in
- Ceiling grid tile — 24×24 in or 24×48 in (count tiles across a run; this is the best of
  the fallbacks because it's repeated and averages out)
- Standard stair tread run — ~10–11 in
- Parking stall — 8'-6" to 9'-0" wide (site plans only)

Never use furniture. Desk, chair, and table sizes vary far too much to anchor a scale.

## 4. Photos of drawings

If it's a photo rather than a digital export:

- Check that rectangles in the drawing stay square across the frame. If the far edge of the
  page is visibly narrower, the photo is keystoned and every dimension on that axis is off.
- A keystoned photo can still be read, but the tolerance widens — call it ±6 in or worse,
  or ask for a flat scan or the PDF.
- A phone photo taken square-on and flat is usually good to ±3–4 in on a room-sized run.

## 5. Report format

Every derived dimension carries three things: the number, the tolerance, and the anchor.

> Room reads **~12'-6" × 14'-0", ±3–4 in** — scaled off the labeled 24'-0" corridor
> dimension on the plan (derived). Ceiling height is not shown anywhere on the drawing
> (observed) — need that before recommending a model.

Then, separately, what would tighten it: *"One tape measurement of the long wall would take
this to ±1 in."*

## 6. The things that kill a fit, in the order they kill it

Check these before doing any floor-area math — each one disqualifies faster than the last:

1. **Ceiling height.** Std `6'-11"`, Enhanced `7'-1"`. These already **are** the install
   clearance — the space needed to lift the tray ceiling up and onto the booth — not the
   booth's exact height, which is slightly less. So don't stack another assembly allowance on
   top; the room has to give this much. Clients almost never state their ceiling height, and
   it's the most common late surprise.
2. **Delivery path.** Doorways, corner turns, elevator car size, stairs. Panels ship flat
   and assemble in place, but they still have to physically reach the room.
3. **Obstructions in the footprint.** Columns, baseboard heat, radiators, floor outlets,
   sprinkler heads, low soffits.
4. **Clearances.** Prior WhisperRoom drawings space the booth **1" off the wall** and call
   out **door-swing clearance** on the plan. Follow the drawings; do not invent a number.
5. **Floor area.** Last, and the easiest to check.

## 7. What not to do

- Don't state a dimension without its tolerance. A bare number reads as measured.
- Don't carry an estimate into a proposal, a quote, or a SketchUp model without it staying
  flagged as estimated until confirmed with a tape.
- Don't infer a dimension from a callout you can't fully read. Leave it out.
- Don't answer "will it fit" with yes/no when the answer is "yes if the ceiling is over
  7'-6", and the plan doesn't say."
