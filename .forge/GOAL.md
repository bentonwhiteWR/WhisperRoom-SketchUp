# GOAL

## Mission

Produce a printable STL of the TMG pottery stamp at the 14 mm mark size, matching the
approved design artifact exactly (artifact f1b6983f "TMG Pottery Stamp"). The artifact
carries the full parametric model but has no STL export, so the geometry has to be
reproduced from its own data and written out as a watertight binary STL.

## Done means

- `exports/tmg-stamp-14mm.stl` exists, binary STL, millimetre units.
- Geometry matches the artifact at SIZE=14: lathed body from the `PROF` profile
  (11 points, revolved about the vertical axis, top face at y=15.5), plus the artwork
  from `LOGO["14"].polys` extruded 1.2 mm of relief on top, overall height 16.7 mm,
  head diameter 16 mm, base 15 mm, waist 9.2 mm.
- Artwork sits on the top face, standing proud (raised relief), oriented so the mark
  reads correctly when pressed — i.e. MIRRORED on the stamp if the artifact's 3D view
  shows it un-mirrored; state which was done and why.
- Handle-down orientation: the wide flat base sits at z=0 on the printer bed.
- Watertight and manifold, verified numerically — every edge used exactly twice,
  consistent winding, positive enclosed volume that matches the artifact's own volume
  figure within a couple percent.

## Now

One Builder: extract the geometry data out of the saved artifact HTML and write the STL,
with a verification pass on manifoldness and volume.

## Out of scope

- Changing the design. The artwork, profile, relief height and line dilation are settled
  in the artifact — reproduce, do not redesign.
- The other mark sizes (16 / 18 / 22 mm). 14 mm only unless asked.
- Slicing, or any claim about how it prints. No printer here.

## History

- Render-prep toolkit for the SketchUp plugin (mode switch, sun aim, two-band walls,
  preflight, pack export) — shipped, commits 306a467 / 66a6384.
