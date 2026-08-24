# Builder handoff — TMG pottery stamp STL (14 mm)

## Produced
- `C:\Users\bento\Documents\Claude\Sketchup\exports\tmg-stamp-14mm.stl`
  Binary STL, millimetres, Z-up, handle-down. 26,582 triangles / 13,293 vertices,
  1,329,184 bytes. Manifold, positive volume, written only after the audit passed.
- `C:\Users\bento\Documents\Claude\Sketchup\scripts\tmg-stamp-stl.js`
  The generator. Node, no dependencies. `node scripts/tmg-stamp-stl.js --svg`.
- `C:\Users\bento\Documents\Claude\Sketchup\.forge\builder\tmg-stamp-14mm-check.svg`
  (+ `.png`) — the mirroring eyeball check, both panes.

## Read-first
- The generator reads the artifact HTML at
  `C:\Users\bento\.claude\projects\C--Users-bento-Documents-Claude-Sketchup\28e6a9e7-0bff-44ac-9475-ea99bda58ca6\tool-results\artifact-f1b6983f-1787441161-c136.html`
  and lifts `LOGO`, `PROF`, `Y_FACE`, `RELIEF`, `BASE_D`, `ringArea()` and
  `faceQuads()` out of it. Nothing is retyped. Override with `--src`.
- MIRRORING: relief is `X = -u`, i.e. the mirror of the drawn mark, so the clay
  reads correctly. Evidence: the page's `paintFlat(faceCv, /*mirror*/ true)` vs
  `paintFlat(clayCv, /*mirror*/ false)`, and its `toXZ = (u,v) => [-u,-v]` under
  the `face` camera. The check PNG shows the face as a mirrored `ƏMT`.
- `faceQuads` conserves area but NOT topology — it leaves T-junctions at band
  boundaries. `fixTJunctions()` repairs them. Do not remove it.
- Lathe y values from `Math.sin` land ~1e-16 apart at mirror angles; the y-cluster
  pass canonicalises them or the scanline skips those bands and orphans vertices.

## Assumptions
- Lathe resolution 256 segments (not from the artifact — its renderer uses 64,
  which is a preview figure, not a print one). 256 divides by 4, so the bbox comes
  out exactly 16.000 mm rather than an inscribed-polygon undershoot.
- `exports/` is not gitignored; the STL is committable. Left uncommitted per brief.
- `scripts/wr_tools/VERSION` NOT bumped: precedent (38dca08, 30dc5bc) is that
  standalone STL generators under `scripts/` do not move the plugin version.

## Open questions
- Whether Benton wants the other mark sizes cut. `--size 16|18|22` already works
  off the same code; only 14 was written.
- No printer here, so nothing is said about how it prints. Overhang, the artifact's
  own figure, is 38 degrees.
