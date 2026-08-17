# Builder handoff — ceiling seam seals

**Status: feature complete and fit-tested on an MDL 7272 S.** The vertical is no
longer an open question — `SEAL_DATUM_LIFT = -1.75`, measured.

## Produced

- `C:\Users\bento\Documents\Claude\Sketchup\scripts\wr-deck.rb`
  New section `------ ceiling seam seals ------`, appended before the
  `ORIGIN` / `Z_AXIS` / `X_AXIS` block. Adds `SEAL_NAME`, `SEAL_DATUM_LIFT`,
  `SEAL_LEN_TOL` (all three in the `remove_const` list at the top, so they
  re-assign on every reload), plus `seal_catalogue`, `pick_seal`,
  `joint_stations` and `seals`. **240 added lines, zero deleted** — `build`,
  `plan`, `pick`, `tile`, `order_cuts`, `contact_z` and `deck_extent` are
  byte-identical.
- `C:\Users\bento\Documents\Claude\Sketchup\scripts\build-booth-components.rb`
  13 added lines after the `%w[FL CL].each` loop and before
  `puts "  deck     #{deck_note}"`. Calls `WR_Deck.seals`, tags with the same
  `t_deck`, appends `; seals N (…)` to `deck_note`, prints warnings as
  `DECK SEAL: …`.
- `C:\Users\bento\Documents\Claude\Sketchup\scripts\probe-seam-seal.rb`
  Clears the Ruby Console before its banner. `WR_ProbeSeal.clear_console`
  calls `SKETCHUP_CONSOLE.clear`, guarded by `defined?` + `respond_to?` and
  rescued, so a context without the console cannot take the probe down.
- `C:\Users\bento\Documents\Claude\Sketchup\.forge\builder\seal_placement_proof.py`
  Re-runnable proof. `python .forge\builder\seal_placement_proof.py` → PASS.
- `C:\Users\bento\Documents\Claude\Sketchup\reference\floor-ceiling-geometry.md`
  New seal dimensions (1.750 tall, both families' level tables), the
  `feet × 12 − 2` mapping, the FL/CL asymmetry, the ±2.4375 registration, the
  height rule, and a stale-data warning on the old 2.000 figures.
- `C:\Users\bento\Documents\Claude\Sketchup\DEVLOG.md` — newest-first entry.

Nothing committed, nothing pushed.

## The height, settled

**The rule: the seal's top face lands on the panels' contact plane** (booth
z 81.000 standard). `SEAL_DATUM_LIFT = -1.75` is that rule as the one number the
placement uses.

Measured, not derived: Benton built the 7272 with this pass on 2026-08-17, moved
the placed `STDSS CL6` by hand until it seated, and reported it needed to come
down 1 3/4. That is exact rather than an eyeball figure —

- Datum-to-top is **1.750 on both seal families** (`CL5/6/7` datum 0.000 → top
  1.750; `CL8`/`8.5CL` datum −0.750 → top 1.000). One constant therefore covers
  all five sizes and the 0.750 family shift needs **no special case**.
- At −1.75 the datum lands at 79.250, the top at exactly 81.000, and the seal's
  0.750 top section drops into the panel slot at 80.249 → 81.000, 0.750 deep.

**The mismatch was fixed in the part, not in the code.** The seals were 2.000
tall with a 0.250 step at z 1.250 and met the 0.750 slot with a 1.000 section.
Benton re-cut all four CL seals to 1.750 with that step removed. No compensating
offset was added anywhere, and there is still exactly one vertical constant in
`wr-deck.rb`. **That constant is tied to the re-cut parts** — a library still
holding 2.000-tall seals wants −2.00, and that is the first thing to check if a
seal ever lands 1/4 in proud.

## What is verified, and how

`python .forge\builder\seal_placement_proof.py` — **PASS**. Ground truth defined
independently of the code, from the probe output, `wr-booth-data.rb` and the fit
test. It checks:

- `feet × 12 − 2` on all five seals, and the name regex on both spellings.
- Ribs ±2.4375 vs both panels' slot centres (2.4375 / 2.4365).
- **Height, section 4** — for every seal: datum-to-top is 1.750,
  `SEAL_DATUM_LIFT == −(datum-to-top)`, the placed top face is on 81.000, the
  datum on 79.250, and the top section lands in the slot. **Verified to fail
  loudly**: forcing the constant to 0.0 and to −1.0 both exit 1 with a named
  failure.
- **MDL 7272 S**: one `STDSS CL6` centred booth **x 49.000** (not the 37.000
  midpoint — an explicit failure), bounds
  `45.750 2.000 79.250 → 52.250 72.000 81.000`, ribs at 46.5625 / 51.4375,
  1.000 clear at each end. Its cut list is cross-checked against the observed
  placed panel spans, not taken on trust.
- 7296 → one CL6 at 49; 6084 → one CL5 at 43; **96168 → three CL8s** at
  49 / 97 / 121; **10284 → two CL7s** on booth Y at 43 / 85 with the long axis
  across the joint and 6.5 in extent in Y (the quarter turn).
- 4872 and 4230 → zero seals, zero warnings.
- Missing seal → nothing selected, nothing substituted.
- `STDSS*` and the panel `NAME` regex stay disjoint in both directions.

`python scripts\rbparse.py` — 35 files parse, real CRuby 3.2.

**In SketchUp:** the MDL 7272 S has been built with this code and the seal
seats. **Nothing else in the acceptance set has been built** — the 7296, 6084,
96168 (three seals, CL8 family), 10284 (the quarter turn), 4872 and 4230 (zero
seals, zero warnings) are all still unrun, and so is the missing-seal case. The
console-clear in the probe is also unrun.

## Assumptions

- **observed:** seal boxes and level tables as re-cut, rib stations, slot
  stations and depth, the panels' contact plane, the 7272's joint at booth
  x 49.000, and the 1 3/4 drop from the fit test.
- **reported:** the per-booth cut lists other than the 7272's, from the confirmed
  FL/CL panel path. This change does not touch that path.
- **assumed:** the rib x stations (±2.4375) were measured on the pre-recut CL8.
  The re-cut changed z only, and the fit test seating corroborates that x did not
  move — but it was not re-measured.
- **assumed:** the seal is centred along the joint on the deck's cross span,
  1 in clear at each end. Nothing measured says the reveal is symmetric; it is
  what a 70 in seal on a 72 in cross produces.

## Open questions

1. **Nothing blocking.** The height is settled and the arithmetic is proven for
   every booth in the acceptance set. What remains is running them.
2. **The Yes/No fork.** Seals ride on the existing "Floor and ceiling: Yes/No" at
   `scripts\build-booth-components.rb:206-221`. Splitting them onto their own
   control is one inputbox row, one `write_pref` key and one boolean threaded
   into the `WR_Deck.seals` call — the placement code does not move. Same for a
   separate tag: one line.
3. **The console clear elsewhere — reported, not done.** See the report; it is a
   clean copy into `probe-levels.rb` and `probe-components.rb` and a bad idea in
   the two builders.
4. **Not mine, flagged:** `scripts\export-component-art.rb` carries an unrelated
   uncommitted edit (`@title` → "Scene PIctures..."), present before this work,
   with what looks like a typo in it.
