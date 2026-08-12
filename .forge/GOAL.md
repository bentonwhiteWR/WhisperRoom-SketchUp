# GOAL

## Mission
Make the isometric azimuth a user-selectable dropdown in
`scripts/angled-component-art.rb`, so the angled booth art can be rendered at
38° (or any offered angle) instead of the hardcoded 45° that collapses the
near and far corner seam seals onto the same screen point.

## Done means
- New "Azimuth" dropdown in the `UI.inputbox` (`self.ask`), persisted like every
  other preference, defaulting to the current 45° so an unchanged run is
  byte-identical to today's output.
- `CAMS` and `CORNER_CAMS` derived from the chosen azimuth at runtime, not frozen
  at 45°. Elevation stays 30° (z = 0.5 always) — `iso30` filenames stay honest.
- At 45° the derived vectors equal the existing constants exactly; at 38° they
  equal the vectors in the brief exactly. Both proven by an arithmetic check.
- The console report block (~line 1053) prints the ACTUAL vectors in use, not the
  hardcoded 45° text it prints today.
- Camera NAMES keep their current relative positions. Filenames do not change.

## Now
Builder implements the dropdown and derived camera table. No render — SketchUp is
driven by Benton; the visual check is his.

## Out of scope
- The defined-lines restyle (separate delivery decision, see below).
- Any change to which components/scenes are in which batch.
- Renaming files or cameras.
- Per-model azimuth (square 7272 vs rectangle 7296) — one global choice for now.

## Carried context
- Square 7272 at 45°: near and far corner separation is exactly 0.0" — degenerate.
  Separation is 9.1" at 40°, 12.7" at 38°, 16.4" at 36". Rectangle 7296 already
  has 17.0" at 45° and was never degenerate. 38° is Benton's pick as the compromise.
- Convention: x = cos(elev)·cos(az), y = cos(elev)·sin(az), z = sin(elev), elev = 30°.
- Corner seam seal (§8c) is the highest-risk family: its instance sits ROTATED in
  the master file and is handled downstream by rotating the standard view map 180°.
  Check it first at any asymmetric azimuth.
- Interior scenes `_IntL`/`_IntR`: 25 in current use, they drive the "see inside
  the booth" feature. Not optional, easy to forget.
- Preference trap: `Sketchup.read_default` EVALs its stored string and
  `write_default` does not escape quotes. Follow the existing pipe-joined,
  quote-stripped, Exception-rescued guard.
