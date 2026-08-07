# The design sheet — the standard format for anything we design

Benton asked for this after the drying-stand and jig pages: **every part we design
from here on gets one of these.** Not a chat summary, not a wall of prose — a drawing
sheet that can be read on its own, months later, by someone who wasn't in the
conversation.

Two finished examples, and they are the spec:

| Sheet | Part |
|---|---|
| `docs/tube-drying-stand.html` | flat lattice part, two-up in a tray |
| `docs/pendant-jig.html` | revolved solid with internal bores |

Copy the newer one and edit it. Do not start a sheet from scratch.

---

## What a sheet is for

A part exists in three places and they drift apart: the Ruby script, the SketchUp
model, and whatever was said in chat. The sheet is the one artefact that reconciles
them — it carries the drawing, the numbers, **and where each number came from**, so
a figure can never quietly become a commitment without saying so.

If the sheet and the script disagree, the script is right and the sheet is stale.
Regenerate it.

---

## Structure

In this order. Skip a section only if the part genuinely has nothing to put in it.

1. **Titlebar** — part name, revision, one-paragraph what-and-why. Revision chip
   on the right (`Rev C`, `Fit-tested`).
2. **Spec strip** — six figures at most, the ones someone would ask for first.
   Show a superseded value struck through next to the new one (`<s>9.90</s> +0.20`);
   that is how a revision reads at a glance.
3. **The primary drawing.** For a flat part, the plan. For a revolved part, the
   section on the axis. To scale, dimensioned, with a closed chain.
4. **The live 3D view** — WebGL, orbitable. See below.
5. **Any flag** — if the revision broke an invariant, it gets its own block
   immediately after the drawing, not a footnote.
6. **Supporting drawings** — elevation, section, detail.
7. **Trade-off tables** — what a chosen number costs, with the neighbouring
   options either side of it so the choice is visible as a choice.
8. **Printability audit** — surface by surface against the published limits.
9. **Where every number came from** — the provenance table. Never optional.
10. **What changed from the last revision** — and on what evidence.
11. **Block footer** — part, script, units, build, orientation, status.

---

## Provenance, which is the whole point

Every number on the sheet carries one of these tags, and the ranking is real:

| Tag | Means | Trust |
|---|---|---|
| `fit-tested` | a printed part was tried against the real mating part | **highest** — includes what this printer actually does |
| `measured` | caliper on a real part | high, but nominal |
| `derived` | computed from other constants; name the formula | as good as its inputs |
| `reported` | Benton or a doc gave me the figure, unverified | flag it |
| `chosen` | I picked it; say what the trade-off was | lowest |
| `assumed` | needed to proceed, never checked | say so loudly |

A fit test outranks a measurement. That is not obvious and it is why the tag exists:
a caliper on the mating part tells you the part, while a fit test tells you the part
*and* the printer *and* the clearance, all at once.

**The status line in the footer never lies.** If the script has not been run since
the change, it says so.

---

## The drawing rules

Straight from `CLAUDE.md`, and they apply on these sheets too:

- To scale, with the scale stated. Chain-dimension every run and **state that the
  chain closes** in the figcaption.
- A chain line means segment lengths, never running totals.
- Tolerance goes **on the drawing**, not only in the prose.
- Reference parts (a ghost tube, a mating housing) are drawn distinctly and labelled
  as reference. Adjacent parts that are not the subject get a **phantom line**
  (`stroke-dasharray: 6 2 1 2`) — that is the drafting convention and it reads
  correctly to anyone who has seen a drawing.
- Sectioned material gets **hatching**, not flat fill.

---

## The house visual language

It is an engineering drawing sheet, and the restraint is deliberate — this is a
working document, not the client-facing proposal. That polish belongs in the
proposal pack, never here.

- **Type:** `ui-monospace` throughout. Uppercase, letter-spaced labels.
- **Ground:** `--paper` behind, `--sheet` for the sheet itself. Both themes are
  defined token-level; see the three-block pattern at the top of either page.
- **Accent:** `--accent`, a burnt orange (`#c44f16` light / `#f07a3e` dark).
  Dimensions, extension lines and the revision chip only.
- **Reference teal:** `--tube`, for ghost parts.
- Wide content scrolls inside `.frame` / `.tw`; the page body never scrolls sideways.

The full token block and every component class live at the top of both example
pages. Lift it wholesale. Page-specific additions go in a **second** `<style>`
block after it, so the shared sheet stays identical between parts.

---

## The 3D view

WebGL with a real depth buffer. This was learned the hard way: a painter's-algorithm
canvas renderer drew far-side detail through near-side walls and made openings look
paper-thin, and Benton spotted it against the SketchUp model immediately.

Non-negotiables:

- **Depth buffer.** Sorting faces is not good enough on any part whose pieces
  interpenetrate.
- **Openings get their reveals.** A hole is a hole *plus* the surfaces inside it.
  Without them the part looks like foil.
- **Edges are depth-tested** against the solid, so hidden lines stay hidden.
- **Edges come from real boundaries only** — never from the triangulation, and never
  from a seam that exists only because of how the mesh was built. Drawing a line the
  part does not have is a lie about the part.
- **Normals per triangle**, and light both sides via `gl_FrontFacing`, so a winding
  slip can never render as a black face.
- Read colours from the CSS tokens at runtime and re-read on theme change.
- Fall back to a plain message when WebGL is off, pointing at the 2D drawings.

Useful toggles, when the part has them: cutaway, reference parts, print orientation,
reset view. **Print orientation is worth a button on any printed part** — it is
consistently the thing easiest to get wrong.

---

## Mechanics

Artifacts are wrapped in `<head>`/`<body>` at publish time, so the published file
holds `<title>`, `<style>`, content, `<script>` and no document skeleton. The repo
copy under `docs/` is the same content wrapped into a standalone page. Generate the
repo copy from the published source rather than maintaining two files.

Add every new sheet to `docs/README.md`.
