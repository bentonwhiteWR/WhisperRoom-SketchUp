# Ceiling seam seals — spec

Scoped 2026-08-17. Builder implements; this file is the plan.

Companion probe: `C:\Users\bento\Documents\Claude\Sketchup\scripts\probe-seam-seal.rb`
— **unrun**. One number in this spec (`SEAL_Z`) stays blank until it comes back.

---

## Goal

`WR_Deck` places the CL and FL deck panels and leaves the joints between ceiling
panels bare. Add a pass that selects, orients and places a ceiling seam seal into
every ceiling joint, driven by the booth's measured cross dimension and the seal
library rather than a per-model table, without touching the panel path that was
confirmed working on 2026-08-17.

---

## What is already measured, and what is not

`P:\Sketchup\NewMasterComponentList\_face-levels.tsv` — written by
`scripts\probe-levels.rb` on 2026-08-14 — survived and still holds the seal rows.
Everything in this section is **observed** from it, not inferred from a name.

| part | box X | box Y | box Z | flat levels, top down |
|---|---|---|---|---|
| `STDSS CL5` | 6.500 | 58.000 | 2.000 | 2.0000 / 1.2500 / 1.0000 / 0.0000 |
| `STDSS CL6` | 6.500 | 70.000 | 2.000 | 2.0000 / 1.2500 / 1.0000 / 0.0000 |
| `STDSS CL7` | 6.500 | 82.000 | 2.000 | 2.0000 / 1.2500 / 1.0000 / 0.0000 |
| `STDSS CL8` | 6.500 | 94.000 | 2.000 | 1.2500 / 0.5000 / 0.2500 / −0.7500 |
| `STDSS 8.5CL` | 6.500 | 100.000 | 2.000 | 1.2500 / 0.5000 / 0.2500 / −0.7500 |

Three things follow, all **derived** from that table:

**1. The digit is a length in feet and the part is two inches short of it.**
5 → 58, 6 → 70, 7 → 82, 8 → 94, 8.5 → 100. Five for five, exact. `feet × 12` is
the booth's **cross** dimension, so the rule is `seal length = cross − 2` and the
seal a booth takes is the one whose `feet × 12` equals its cross. That is what
makes selection general instead of tabulated, and it is the mapping the
orchestrator flagged as an unconfirmed guess — it is now confirmed against five
parts. Floor seals follow a *different* mapping (`FL6/7/8` measure 72/84/96, the
full `feet × 12`), which is one more reason not to fold floors into this.

**2. The seals are not upside down relative to each other — only shifted.**
Read the gaps upward from each part's largest-area level and all five agree:
`+1.0000, +0.2500, +0.7500`. `CL8` and `8.5CL` are `CL5/6/7` translated down
0.75 in, a pure translation. The ceiling *panels* split into two conventions that
are genuine mirror images, and the obvious move is to assume the seals do too.
They do not. **Nothing in the seal path may flip a part**, and no `contact_z`-style
up/down detection belongs here.

**3. The library has a seal for exactly the crosses that produce a joint.**
Crosses in `wr-booth-data.rb` are 42, 48, 60, 72, 84, 96, 102. There is no
`STDSS CL4` and no `STDSS 3.5CL`, and 42 and 48 are precisely the crosses whose
ceilings are single parts (`STD4230CL`, `STD4242CL`, `STD4260CL`, `STD4284CL`,
`STD4848CL`, `STD4872CL`, `STD4896CL`) — one tile, no joint, no seal. Every
multi-tile cross has its seal. That is a prediction as much as an observation and
the acceptance criteria test it.

**What is not measured, and cannot be from here.** Which way up the seal goes
physically; where the slot is in the ceiling panel; and therefore the single
number `SEAL_Z` — the booth height the seal's datum face lands on. The probe
answers it. Do not implement a guess for it; the build must refuse to place
rather than place at an invented height.

---

## Approach

A **separate pass**, `WR_Deck.seals`, called after the FL/CL loop in
`build-booth-components.rb`. It re-runs `catalogue` and `plan(spec, cat, 'CL')`
itself rather than being threaded through `WR_Deck.build`.

Re-running costs one folder glob and some arithmetic. What it buys is that
`WR_Deck.build` is left **byte-identical**, which is the out-of-scope fence in
`.forge\GOAL.md` stated as code rather than as an intention. `plan` is pure —
same folder, same spec, same tiles — so the joints the seal pass computes are the
joints the panels were actually placed at.

Placement mirrors the panel rule where it can and diverges where the measurement
says to:

- **Same** quarter turn: the seal's box is `6.5 × length × 2.0`, so its own X runs
  across the joint and its Y along it — the identical convention the panels use
  (definition X along the tiling run, Y across it). It takes the same
  `turn = !along_is_x` and nothing else.
- **No flip and no half turn.** Justified by finding 2 above, and re-checked by
  the probe's cross-check 1.
- **Height from a measured face, not from the origin.** The datum is the
  largest-area flat level from `WR_Deck.flat_levels` — z 0.0000 on `CL5/6/7` and
  −0.7500 on `CL8`/`8.5CL`, i.e. the same physical face on both families. Same
  discipline as `contact_z`: measure the face, never trust the origin.
- **Station from the tile arithmetic, not from a re-measurement.** The joint is at
  `INSET + cumulative sum of cuts`, which is exactly where `build` seated the
  panels' `deck_extent` edges. Re-measuring the placed instances would be a second
  source of truth that can disagree with the first.

---

## Steps

Every step is in `C:\Users\bento\Documents\Claude\Sketchup\scripts\wr-deck.rb`
except step 6.

### 1. Seal name regex and catalogue

Add to the `remove_const` list at `wr-deck.rb:60`: `SEAL_NAME`, `SEAL_Z`,
`SEAL_ACROSS_TOL`.

```ruby
# STDSS CL5 / CL6 / CL7 / CL8, and STDSS 8.5CL — the digit changes sides at 8.5
# and the naming gives no reason for it, so match both spellings rather than
# trusting whoever names the next one to pick a side.
SEAL_NAME = /\ASTDSS\s*(?:CL\s*(\d+(?:\.\d+)?)|(\d+(?:\.\d+)?)\s*CL)\z/i.freeze

def self.seal_catalogue(dir)
  out = []
  Dir.glob(File.join(dir, 'STDSS*.skp')).each do |path|
    base = File.basename(path, '.skp')
    m = SEAL_NAME.match(base.strip)
    next if m.nil?
    ft = (m[1] || m[2]).to_f
    out << { :file => base, :path => path, :feet => ft, :cross => ft * 12.0 }
  end
  out
rescue StandardError => e
  puts "  seal catalogue failed: #{e.class}: #{e.message}"
  []
end
```

Note it globs `STDSS*` and the panel catalogue globs `STD*` with a regex
requiring `STD` + digits (`wr-deck.rb:282`), so the two pools stay disjoint with
no change to the panel regex. That is the reason seals need their own path at all
and it must not be "fixed" by loosening `NAME`.

### 2. Selection

```ruby
# The seal for a deck of this cross dimension. nil when the library has none,
# which is a normal answer for a single-tile cross and an error for a joint.
def self.pick_seal(seals, cross)
  seals.find { |s| (s[:cross] - cross).abs < TOL }
end
```

`TOL` is 0.35, already defined. Selection is by the **name's** feet-to-cross
mapping; the measured length is then verified in step 5 and a mismatch is warned
rather than silently accepted. Two independent checks, because finding 1 is
derived from five parts and a sixth could break it.

### 3. Joint stations

```ruby
# Where the joints fall along the tiling axis, in DECK coordinates (0 at the
# deck's low edge). One per interior joint: an MDL 7272 S tiles 48 + 24 and has
# one at 48; an MDL 96168 S tiles 48 + 48 + 24 + 48 and has three.
#
# Taken from the cut list rather than from the placed panels. `build` seats each
# panel's measured deck_extent at INSET + the running sum, so these ARE the
# stations the deck edges landed on, and re-measuring would be a second source
# of truth free to disagree with the first.
def self.joint_stations(tiles)
  return [] if tiles.length < 2
  st = []
  pos = 0.0
  tiles[0..-2].each { |t| pos += t[:along].to_f; st << pos }
  st
end
```

### 4. The pending constant

```ruby
# THE BOOTH HEIGHT THE SEAL'S DATUM FACE LANDS ON.
#
# The datum is the seal's largest-area flat level — z 0.0000 on CL5/6/7 and
# -0.7500 on CL8 and 8.5CL, the same physical face on both. Which booth height
# that face sits at is the one number no reading of the library can produce: it
# depends on where the slot is cut in the ceiling panel, and a slot is bounded by
# vertical faces that neither probe-levels.rb nor probe-components.rb can see.
#
# scripts/probe-seam-seal.rb sections both parts and answers it. Until it has
# been run, nil, and the seal pass reports that it cannot place rather than
# placing at a number somebody made up. Two constants in this file were each
# flipped four times across an evening for exactly that reason and the comment at
# line 93 is what they cost.
SEAL_Z = nil
```

### 5. The pass

```ruby
# Ceiling seam seals. Returns [placed, [warnings], note].
#
# Deliberately NOT part of build: that path was confirmed correct on 2026-08-17
# and re-running plan here costs one folder glob to leave it untouched.
def self.seals(model, parent, spec, dir, wall_h = WALL_H)
```

Body, in order:

1. `cat = catalogue(dir)`; `tiles, note = plan(spec, cat, 'CL')`. Return
   `[0, [], 'no CL plan']` when `tiles` is nil — the CL pass already reported it
   and a second copy of the same complaint is noise.
2. `stations = joint_stations(tiles)`. Return `[0, [], 'single tile — no joint']`
   when empty. **No warning**: a one-tile ceiling with no seal is correct.
3. `cross = tiles.first[:cross]`, `along_is_x = tiles.first[:along_is_x]`.
4. `seal = pick_seal(seal_catalogue(dir), cross)`. When nil, return
   `[0, ["no ceiling seam seal for a #{cross} in cross — #{stations.length} joint(s) left bare"], nil]`.
   Loud, in the same voice as the hand-substitution warning at `wr-deck.rb:704`.
5. When `SEAL_Z.nil?`, return
   `[0, ["SEAL_Z is not set — run scripts/probe-seam-seal.rb and fill it in. #{stations.length} joint(s) left bare."], nil]`.
   This is the fail-loud wrapper; it must come before any `add_instance`.
6. Load the definition. Measure: `bb = defn.bounds`;
   `datum = flat_levels(defn).max_by { |_z, a| a }[0]`; `len = [dx, dy].max`.
   Warn — and still place — when `(len - (cross - 2.0)).abs > 0.05`: the name said
   this seal fits and the geometry disagrees, which is the finding-1 tripwire.
7. For each station, build the transform:
   ```ruby
   tr = Geom::Transformation.new
   tr = Geom::Transformation.rotation(ORIGIN, Z_AXIS, 90.degrees) * tr unless along_is_x
   now = Geom::Point3d.new(0, 0, datum).transform(tr).z.to_f
   tr = Geom::Transformation.translation(Geom::Vector3d.new(0, 0, SEAL_Z - now)) * tr
   got = Geom::BoundingBox.new
   8.times { |k| got.add(bb.corner(k).transform(tr)) }
   # Centre across the joint on the joint station; centre along the joint on the
   # deck's cross span. All eight corners, not bb.min — a quarter turn swaps the
   # axes and bb.min transformed is not the transformed minimum.
   want_a = INSET + station          # across-joint centre, tiling axis
   want_c = INSET + cross / 2.0      # along-joint centre, cross axis
   wx, wy = along_is_x ? [want_a, want_c] : [want_c, want_a]
   ctr = Geom::Point3d.new((got.min.x.to_f + got.max.x.to_f) / 2.0,
                           (got.min.y.to_f + got.max.y.to_f) / 2.0, 0)
   tr = Geom::Transformation.translation(
          Geom::Vector3d.new(wx - ctr.x.to_f, wy - ctr.y.to_f, 0)) * tr
   ```
8. `inst = parent.entities.add_instance(defn, tr)`; `inst.name = seal[:file]`.
   The part's own name and nothing else — the panel path learned at
   `wr-deck.rb:805` that diagnostic suffixes end up in exported models.
9. One console line per seal in the same shape as the panel line at
   `wr-deck.rb:824`: file, station, datum, and the placed instance's real bounds
   read back from `inst.bounds`, not from `got` (which is one translation stale).

### 6. Wiring

In `C:\Users\bento\Documents\Claude\Sketchup\scripts\build-booth-components.rb`,
after the `%w[FL CL].each` loop closes at line 1011 and before
`puts "  deck     #{deck_note}"` at line 1012:

```ruby
before = booth.entities.length
n, swarn, snote = WR_Deck.seals(model, booth, spec, cfg['dir'], wall_h)
booth.entities.to_a[before..-1].to_a.each { |e| (e.layer = t_deck) rescue nil }
deck_note = "#{deck_note}; seals #{n}#{snote ? " (#{snote})" : ''}"
placed += n
(swarn || []).each { |w| puts "  DECK SEAL: #{w}" }
```

Same `t_deck` tag as the panels: a seal is part of the deck and splitting it onto
its own tag makes the Outliner claim two things where there is one. If Benton
later wants to hide seals alone, adding a tag is a one-line change with no
placement consequences.

### 7. Documentation

Extend the **Seam seals** section of
`C:\Users\bento\Documents\Claude\Sketchup\reference\floor-ceiling-geometry.md`
with the ceiling table above, the `feet × 12 − 2` mapping, the "shifted not
flipped" finding, and whatever the probe returns for `SEAL_Z`. Mark the FL/CL
mapping difference explicitly — a future reader will otherwise assume one rule
covers both, which is the same shape of error the two ceiling conventions caused.

---

## Acceptance criteria

Every one is a check the Builder can run. Stations are in booth coordinates,
where the deck occupies `INSET` to `INSET + span` on both axes and `INSET` is 1.0.

1. **No regression.** Build `MDL 7272 S`, `MDL 7296 S`, `MDL 96168 S` and
   `MDL 4872 S` with seals **off**, and the FL/CL console lines are identical to a
   build from the current `wr-deck.rb`. `WR_Deck.build` is unchanged in the diff —
   `git diff scripts/wr-deck.rb` shows additions only, no edits inside `build`,
   `plan`, `pick`, `tile`, `order_cuts`, `contact_z` or `deck_extent`.
2. **MDL 7272 S — the off-centre test.** Exactly **one** seal, `STDSS CL6`.
   Its placed bounds centre on **x = 49.000** (`INSET` 1 + joint at 48), not on
   37.000 (the deck midpoint). A seal at 37 is the bug this booth was chosen to
   expose. Bounds x 45.750 .. 52.250; bounds y 2.000 .. 72.000 (70.000 long,
   centred on the 1.000 .. 73.000 cross span, 1 in clear at each end).
3. **MDL 7296 S.** One seal, `STDSS CL6`, centred x = 49.000 (tiles 48 + 48).
4. **MDL 6084 S.** One seal, `STDSS CL5`, centred x = 43.000 (tiles 42 + 42),
   bounds y 2.000 .. 60.000 on a 1.000 .. 61.000 cross span.
5. **MDL 96168 S.** **Three** seals, all `STDSS CL8`, centred at x = 49.000,
   97.000 and 121.000 (tiles 48 + 48 + 24 + 48 after `order_cuts`). Three, not
   one — the count must come from the tiling, not from an assumption of a single
   joint.
6. **MDL 4872 S and MDL 4230 S.** **Zero** seals and **zero** warnings. A
   single-tile ceiling has no joint and a clean build must not complain about one.
7. **Rotation — MDL 10284 S.** Its exterior is 86 × 104, so `h > w` and `plan`
   chooses `along_is_x == false`: it tiles 42 + 42 + 18 along booth **Y** across a
   cross of 84 on booth X. **Two** seals, both `STDSS CL7` (82.000 long), centred
   at y = 43.000 and y = 85.000, each with bounds x 2.000 .. 84.000 and a 6.5 in
   extent in Y. That is the quarter turn taken correctly; a seal whose long axis
   still runs along X here means `turn` was not applied.
8. **Height.** The seal's datum face lands at `SEAL_Z` to within 0.005 in on both
   `CL5/6/7` and `CL8`/`8.5CL` parts, i.e. build one booth from each family
   (`MDL 7272 S` for the first, `MDL 96168 S` for the second) and confirm the two
   agree. If they disagree by 0.75 in, the "shifted not flipped" finding is wrong
   and the datum rule must be revisited before anything ships.
9. **Missing seal.** Temporarily rename `STDSS CL6` and build `MDL 7272 S`: the
   console says the joint was left bare and names the cross dimension. It does not
   substitute a different length and it does not fail silently.
10. **`SEAL_Z` unset.** With `SEAL_Z = nil`, every booth builds its panels
    normally and reports that seals were skipped pending the probe. Nothing is
    placed at a guessed height.

---

## Risks and out of scope

**The one real risk is `SEAL_Z`.** It is the only number here that is not
measured, and step 5's nil guard exists so that it cannot become a placed
instance by accident. The failure this repo keeps re-learning is a stand-in
constant hardening into a fact; `wr-deck.rb:93` is that lesson written down.

**Second risk: the seal may not be symmetric across the joint.** If the probe's
cross-check 4 comes back NO, the seal has a front and a back, the centring in
step 7 is not sufficient, and a further rule is needed for which way it faces.
Nothing else in the spec changes — the extra rule lands inside step 7.

**Third: the joint may not be exactly at the nominal station.** `deck_extent`
exists because brackets project past the deck; if a CL panel's measured deck
extent along the tiling axis is not its nominal `along`, adjacent panels leave a
hairline gap and the nominal station is the joint's centre rather than its face.
The probe reports each panel's deck extent so this is visible before it matters.
Mitigation if it appears: keep the nominal station (it is the midpoint of the gap)
and record the gap.

**The Yes/No fork — recommended: ride on the existing control.** Seals take the
existing "Floor and ceiling: Yes/No" at
`C:\Users\bento\Documents\Claude\Sketchup\scripts\build-booth-components.rb:206-221`
rather than getting their own. A deck without its seam seals is not a state
anyone has asked for, and `UI.inputbox` already carries five rows. Cost to change
later is genuinely low: one more row in the inputbox, one more key in
`write_pref`, one boolean threaded into the `WR_Deck.seals` call — the placement
code does not move. The reversible choice is to ride on it now, so that is the
recommendation, and it is Benton's to overrule.

**Out of scope**, per `.forge\GOAL.md` and confirmed here:

- Floor seam seals. `STDSS FL6/7/8` follow a *different* length mapping
  (`feet × 12`, not `feet × 12 − 2`) and the missing `FL5`/`FL8.5` question is
  unresolved. Nothing in this spec generalizes to them and nothing should try.
- Wall seals (`MidWallSeamSeal`, `CornerSeamSeal`), which
  `build-booth-components.rb` already places at line 828.
- Any change to CL/FL panel selection or orientation, including the `NAME` regex
  at `wr-deck.rb:282`.
- `STD127LPCL`, still deferred.
