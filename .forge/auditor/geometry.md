# Audit — GEOMETRY AND NUMBERS THAT ARE WRONG

Auditor pass, 10 Sep 2026. Plugin 1.48.0. Project root
`C:\Users\bento\OneDrive\Documents\Claude\Sketchup\WhisperRoom-SketchUp`.
READ-ONLY: nothing outside this file was touched, nothing was committed.

**Nothing was executed.** There is no ruby.exe on this machine outside SketchUp
and I did not open SketchUp. Every claim below is a static read of the source
plus arithmetic I ran in Python against `models.json` and `wr-booth-data.rb`.
Tags: **observed** = I read it at the cited line; **derived** = arithmetic I did
from observed values; **reported** = DEVLOG/comment says so; **assumed** = stated
as such.

## Outcome

The measurement side of this plugin is in better shape than its size suggests —
units never cross a boundary unconverted (there is not a single `.inch` or
`.to_l` in any of the nine files, because every number is already inches and
stays inches), the take-off JSON names its units in its keys (`at_in`, `h_in`),
and `dimension-whisperroom.rb` draws its strings from the same extents it prints,
so text and geometry cannot diverge. The one finding that will reach a quote is
**F1: the ceiling height a caster-plate booth needs is under-reported by about
4.75 in**, by the one line in the tool that exists to answer "will it fit". After
that the list drops steeply to labelling and tolerance issues.

===DETAIL===

## Ranked findings

### F1 — `CEILING THE ROOM MUST GIVE` ignores the caster plate: every CP booth is quoted ~4.75 in low. **HIGH**

**Where.** `C:\Users\bento\OneDrive\Documents\Claude\Sketchup\WhisperRoom-SketchUp\scripts\booth-from-link.rb:980-991`
calls `WR_RoofVent.ceiling_required(key, variant, hx, roof, vss)` and prints the
result as the room's required clearance.
`C:\Users\bento\OneDrive\Documents\Claude\Sketchup\WhisperRoom-SketchUp\scripts\wr-roof-vent.rb:316-330`
— `ceiling_required` takes **no caster argument at all**; it returns
`STD_CLEARANCE 83.0` / `ENH_CLEARANCE 85.0` (+ `HX_ADD`, + roof unit) and nothing
else. (observed)

**The failure.** A link with `cs = 1` builds a booth lifted `CP_BOOTH_LIFT = 4.75`
(`…\scripts\wr-overlays.rb:250`; `booth_lift` at :538-539 returns
`4.75 - fl_bottom`). `booth-from-link.rb:1083` and `:1096` name that same number
in the *options* block — `'casters_plate' => 'caster plate (CP set + 4.75 in
booth lift)'` — so the file knows the figure 100 lines below the line that omits
it. (observed)

Worked case, the one the DEVLOG already has numbers for: an **MDL 7296 E on a CP**
measures **88.75 in** overall (DEVLOG 1.42.0: "a link-built 7296 E on a CP will
read `7' 4 3/4"` (88.75)" = 84.3125 drawn + 4.4375 of plate). (reported)
`ceiling_required('MDL 7296 E','E',false,false,false)` returns **85.00**.
(derived) So the console tells the salesperson the room needs 7'-1" for a booth
that is 7'-4 3/4" tall. **The booth does not fit the ceiling the tool says it
needs** — it is not merely a missing allowance, the stated figure is below the
object.

**Why it is silent.** The line prints unconditionally and reads as authoritative:
`CEILING THE ROOM MUST GIVE: 7'-1.0" (85.00 in) install clearance.` Nothing on
that line or near it mentions casters. The same file goes to great lengths to say
the portal under-reports RM booths — this is the same class of error, in the same
sentence, uncaught.

**How I know it is not tested.**
`C:\Users\bento\OneDrive\Documents\Claude\Sketchup\WhisperRoom-SketchUp\scripts\rbtest-roofvent.py:154-192`
pins `ceiling_required` across Standard / Enhanced / HX / roof / VSS / no-part —
**no caster case exists in the harness**, and the function has no parameter that
could carry one. (observed)

**Also possibly missing from the same figure**, lower confidence: the elevated
floor (`ep` / the `ad` ADA bundle, `EFP_T_MIN 2.5 .. EFP_T_MAX 3.3`,
`wr-overlays.rb:182-183`) raises the *interior* floor and so eats interior head
height. Whether it belongs in a room-clearance figure is a product question, not
a code one — flagging, not asserting. (assumed)

---

### F2 — The line labelled "catalogue" prints the builder's drawn datum, not the catalogue figure. **MEDIUM-HIGH**

**Where.** `…\scripts\dimension-whisperroom.rb:122-123`:

```ruby
HEIGHT_STD = 83.0
HEIGHT_ENH = 84.3125
```

with the comment "Derived from **the builder's datums** (spec §1)". These feed
`catalogue_extent` (:529-539) and are printed at :1124-1128 as
`catalogue MDL 9696 E: … x … x 7' 0 5/16"  (…)`. (observed)

**The failure.** `models.json` `enhDims` for every model is `7' 1"` = **85.0 in**;
`stdDims` is `6' 11"` = **83.0**. (observed, parsed from
`C:\Users\bento\OneDrive\Documents\Claude\WhisperRoomQuote\whisperroom-catalog\data\models.json`.)
`CLAUDE.md:118-124` is explicit that those are the **install clearance** and are
"the figure[s] WhisperRoom markets and the height a room has to give", and that
the drawn height is "slightly less — a 96120 E measures `7'-0 5/16"`".

So on Standard the two coincide (83 = 83, by accident of the datum), and on
**Enhanced the word "catalogue" is attached to 84.3125 — 11/16 in below the
catalogue's own 85**. A reader who lifts that line as the catalogue clearance,
which is what its label invites, quotes a room 11/16 in short. `CAT_TOL = 0.25`
(:113) is tighter than the 0.6875 gap, so if the constant were the real catalogue
figure the Z axis would flag on every Enhanced booth — which is presumably why it
is the drawn datum instead. The number is right for what it does (checking the
drawing against the builder); the **label is wrong**, and the label is what gets
read.

Same block, related and already handled honestly: `VENT_PROUD = 5.5` is
documented as the **no-EFS** figure (:117); with EFS the expected extent is
systematically low and the run prints a caveat at :1134 rather than adjusting.
Noting it only so it is not mistaken for a second defect.

---

### F3 — `dimension-selection.rb` labels a world AABB "LENGTH / WIDTH" with no check that the object is axis-aligned. **MEDIUM**

**Where.** `…\scripts\dimension-selection.rb:64-84` (`subject_bounds`) and
`:253-256`:

```ruby
puts format('  length (X)  %s', arch(bb.max.x - bb.min.x))
puts format('  width  (Y)  %s', arch(bb.max.y - bb.min.y))
```

`bb` is a `Geom::BoundingBox` union of `e.bounds` in **world** space. (observed)

**The failure.** A booth placed at an angle in a room — the entire premise of
`peoplesspace-alcove.rb`, `fvrl-podcast-alcove.rb`, `dowaly-kuwait-tv.rb` — has a
world AABB strictly larger than itself on both ground axes. An MDL 96168
(170 × 98 exterior) rotated 45° gives an AABB of `(170+98)/√2 ≈ 189.5` on **both**
X and Y. (derived) The tool then draws and prints
`length 15'-9 1/2"  width 15'-9 1/2"` for a 14'-2" × 8'-2" booth, with no warning,
and the strings land in the model where a plate can pick them up.

The header at :23-29 defends world bounds against *definition* bounds — correct,
and the right call — but it never addresses yaw. The disclaimer at :258-260
("ESTIMATED until a tape says otherwise") covers imprecision, not a number that is
a different quantity.

`dimension-whisperroom.rb` is immune by construction: it measures in the booth's
own frame and draws inside the booth's entities (:1080-1090, ownership note at
:727-745). The two tools are therefore not interchangeable, and nothing on screen
says so. (observed)

---

### F4 — Nothing pins `LengthPrecision`; an architectural dimension can silently round to the inch. **MEDIUM**

**Where.** Eight call sites set the *format* and never the *precision*:
`dimension-whisperroom.rb:1003`, `build-booth-components.rb:2300`,
`build-room.rb:379`, `build-takeoff.rb:192`, `build-booth.rb:106`,
`dimension-booth.rb:615`, `booth-4260-s.rb:46`, `booth-96168-s.rb:52` — all
`model.options['UnitsOptions']['LengthFormat'] = Length::Architectural`.
A repo-wide grep finds `LengthPrecision` set in exactly two files, and both set it
to `2` alongside **millimetres and decimal format**:
`…\scripts\pendant-jig.rb:383-385` and `…\scripts\tube-drying-stand.rb:309-311`.
(observed)

**The failure.** SketchUp's architectural precision index runs 0 = 1", 1 = 1/2",
2 = 1/4" … The booth tools reset the format but inherit whatever precision the
model (or a previously-run tool in the same session) left behind. At index 0 a
part measuring 97.75 in draws as `8' 2"`, not `8' 1 3/4"` — the exact string in
the brief. The `arch()` helpers (`dimension-whisperroom.rb:559-563`,
`dimension-selection.rb:217-221`) call the same `Sketchup.format_length`, so the
console agrees with the plate and there is no second opinion anywhere.

**Mitigation that exists (why MEDIUM, not HIGH):** SketchUp prefixes a non-exact
architectural length with `~`, and `proposal-package.rb:2935-2937` records having
observed exactly that, while `dim_display` (:683-688) preserves the raw string
rather than stripping it. So the degradation leaves a mark — a tilde, on a plate,
at plate-text size. It is not a second number and nothing asserts on it.

---

### F5 — `wr-deck.rb` buckets face heights on a hard 1/64 grid instead of clustering, so one level can split in two. **MEDIUM-LOW**

**Where.** `…\scripts\wr-deck.rb:748-763`:

```ruby
zt = f.vertices.first.position.transform(tr).z.to_f
z = (zt * 64).round / 64.0
tally[z] += a
zsum[z]  += a * zt
```

(observed)

**The failure.** The key is a grid snap, not a cluster. Two faces that are the
*same* physical level but straddle a 1/64 boundary — 2.10936 and 2.10940, four
hundred-thousandths of an inch apart — land in **different buckets**, each with
half the area. Downstream the bucket is chosen by area (`contact_z` and the
callers of `flat_levels_with_exact`), so a level that should win on 1800 sq in can
lose to a rim on 900. The result is a deck or tray seated at a wrong level —
silently, because the rounded key and the area-weighted exact mean both look
reasonable.

**The fix is already in this repo, in the other file.**
`dimension-whisperroom.rb:215-225` (`level_totals`) solves the same problem the
right way: sort by level, merge into the previous bucket when within `LEVEL_TOL`,
which cannot split a cluster at an arbitrary boundary. Two files, same job, two
algorithms, one boundary-sensitive.

The 1/128 defect this code was written to fix (comment at :735-739, Benton
2026-08-25, "the standard ceiling is just SLIGHTLY too low") was the *keys being
used as positions*; that half is fixed. The bucketing half was not changed.
I have **not** observed a real part whose faces straddle a boundary — this is a
mechanism finding, not a reproduction. (derived + assumed)

---

### F6 — `build-takeoff.rb`: a door with no `h_in` walls itself shut, and the `|| 80.0` fallback cannot fire. **MEDIUM-LOW**

**Where.** `…\scripts\build-takeoff.rb:268-269`:

```ruby
door_h = (room['doors'] || []).select { |d| d['run'].to_i == i }
                              .map { |d| d['h_in'].to_f }.first || 80.0
```

(observed)

**The failure.** If a door object has no `h_in` key, `nil.to_f` is `0.0`. In Ruby
`0.0` is truthy, so `|| 80.0` **never runs** — that fallback is dead for the case
it was written for. `door_h` becomes `0.0`, and `WR_BuildRoom.wall_run`
(`build-room.rb:206-240`) builds the opening span over `[door_h, ceil]` =
`[0.0, ceil]` — a **solid wall floor-to-ceiling where the doorway should be**.
`WR_BuildRoom.door` then draws a zero-height marker and leaf. The room builds,
reports, dimensions and zooms to extents with no error at all.

**Why it is not caught upstream:** `lock_errors` (:96-178) validates `h_in` only
against the ceiling (`h > ceil + TOL`, :141-146). There is no `h_in > 0` test,
while `runs`, `ceiling`, and door width and position all have one. The file's own
stated purpose for re-validating (:92-94 — "re-checking here is what makes 'force
it past the checker' fail by name instead of building wrong geometry") is
precisely the case that leaks.

**Live likelihood is low:** `takeoff-check.py:666` does emit `h_in` for every
door, so a lock from the normal pipeline is safe. The exposure is a hand-edited or
hand-authored lock — which is the scenario `lock_errors` exists for.

---

### F7 — `wr-preflight.rb` "stray geometry" check has no Z test. **LOW**

**Where.** `…\scripts\wr-preflight.rb:117-130`. `lo` and `hi` are built with a Z
margin (`Geom::Vector3d.new(-margin, -margin, -margin)`), and then:

```ruby
inside = eb.min.x >= lo.x && eb.min.y >= lo.y && eb.max.x <= hi.x && eb.max.y <= hi.y
```

**Z is computed and then not used.** (observed)

**The failure.** A group left a hundred feet above or below the room — the usual
residue of a paste-in-place or an import — is inside the XY footprint and so reads
`pass`: "Nothing sits outside the room by more than 24 in." That is a false clean
bill on a check whose whole job is to catch leftovers, and it is exactly the
geometry that then wrecks `zoom_extents` and the plate framing. Loud consequence,
silent check.

---

### F8 — `MDL 4230` is the one booth whose footprint axes run opposite to the rest of the family. **LOW (data correct; a trap for any new consumer)**

**Where.** `…\scripts\wr-booth-data.rb`, `'MDL 4230 S'`: `:w=>44.0, :h=>32.0`.
(observed)

Across all 24 other models the convention is exact: **`:w` = second model number
+ 2, `:h` = first + 2** (96120 → w 122 / h 98; 102186 → w 188 / h 104; 4260 →
w 62 / h 44). `MDL 4230` inverts it: w 44 (= 42+2), h 32 (= 30+2). The polygons
agree with the table — I summed the part polys and the 4230 footprint really is
X 0..44, Y 0..32. (derived)

**Why it is defensible and still worth recording.** The 4230's door panel is 40 in
wide (`S0 DRFRM` poly `[[2,1],[42,1],…]`, identical to every other model's), and a
40 in door cannot stand on a 30 in wall — so the booth is authored with its 42 in
face as the door wall, which forces the transposition. It is correct geometry. The
hazard is that **any cross-check that derives a footprint from the model number
instead of from this table will be transposed on exactly this one model**, and it
is the only model where such a bug would show. Every consumer I read (`v3_slots`,
`identify`, `catalogue_extent`, `seat`) goes through the table and is fine.
(observed)

Against `models.json` I found **no other disagreement**: all 25 shared models
match `stdDims`/`enhDims` exactly (w↔h transposed as above), `iw`/`ih` = w−4 /
h−4, `eiw`/`eih` = iw−4.5 / ih−4.5 throughout. The catalogue's 26th entry,
`127 LP`, is absent from `wr-booth-data.rb` — and the file's own
"Skipped, and why:" header list is **empty**, so the reason was never written
down. (observed)

---

### F9 — `DECK_RE` / `NAME` greedy-digit parse is one filename away from a silent misread. **LOW (latent)**

**Where.** `dimension-whisperroom.rb:682`
`DECK_RE = /\A(?:STD|ENH\s*)(\d{2,3})(\d{2})\s*FL/i`, and the identical shape in
`wr-deck.rb:318` / `:346`. (observed)

I ran the pattern against real and hypothetical names (Python, same semantics):

```
'STD9648FL SIDE'  -> ('96','48')   correct
'STD10242FL'      -> ('102','42')  correct
'STD 9648FL'      -> NO MATCH      (DECK_RE has \s* after ENH but not after STD;
                                    FLOOR_RE at :134 allows the space. They disagree.)
'STD96120FL'      -> ('961','20')  SILENT MISPARSE
'STD102126FL'     -> NO MATCH
```

**Today this is harmless**: deck panels are `<cross 2-3 digits><along 2 digits>`
and no along-width is three digits, so no name with a 3-digit tail exists. But
`\d{2,3}` greedy followed by `\d{2}` has no separator and no validation — the
moment a 3-digit along-width is authored, `wr-deck.rb:350-368` files it in the
catalogue at a fabricated size (961 × 20) with no error, and `identify` returns
"the deck parts match no model", so the **catalogue cross-check silently switches
off** rather than failing loudly. The `STD ` vs `STD` space inconsistency between
`DECK_RE` and `FLOOR_RE` is a second, smaller instance of the same fragility.

---

### F10 — Tolerances that are looser than they look. **LOW / informational**

Each observed; none has a reproduction. Recorded because a tolerance you cannot
justify is one that will eventually absorb a real error.

| Where | Value | Note |
|---|---|---|
| `build-booth-components.rb:2155` | `(pos - last).abs > 0.15` | `rebalance_walls` *triggers* at 0.1 and *accepts* at 0.15 — a wall can close 0.149 in short and print only "rebalanced" lines, no residual figure. The corner seal hides it. |
| `build-booth-components.rb:255` | `SLAB_NOISE = 1.0` | Up to 1 in of part-vs-slot disagreement is read as packaging and does not move geometry. Documented and reasoned (the substitution it guards against is 3 in) — but it is 1 in. |
| `wr-deck.rb:112` | `TOL = 0.35` | `tile()` accepts a remainder within 0.35 in as an exact panel match. Safe only because deck widths are ≥6 in apart. |
| `dimension-whisperroom.rb:113` | `CAT_TOL = 0.25` | Fine for the cross-check, but see F2 — it is tight enough that the Enhanced height constant had to be the *drawn* datum rather than the catalogue one to avoid tripping on every booth. |
| `build-room.rb:206-240`, `:327-348` | — | Two overlapping doors on one run are not rejected (`door_errors` checks corners and width, not overlap); `wall_run`'s cursor then walks backwards and builds overlapping solids. Loud, not silent. |
| `build-room.html:206-211` | `arch()` | The read-back echo the user verifies against the plan rounds to 1/10 in, so a 1/16 in typo is invisible in the confirmation. The built value is unaffected. |

---

## What I checked and found sound

Stated so the absence of a finding is informative rather than an omission.

- **Units.** Zero `.inch`, `.to_l`, `.feet`, `.mm`, `.cm` in any of the nine
  assigned files. Everything is inches end to end, which is SketchUp's internal
  unit — there is no conversion to get wrong. (observed, grep)
- **The JSON boundary.** The take-off lock names its units in its keys (`in`,
  `at_in`, `w_in`, `h_in`, `head_in`, `sill_in`); the string forms (`8'10"`,
  `8.833'`, `9′2″`) are parsed once in `takeoff-check.py` / `build-room.html` and
  never reach Ruby. `build-takeoff.rb:229` converts `r['in']` → `'v'` correctly
  before handing runs to `WR_BuildRoom.polygon`. Closure is checked at
  `TOL = 0.02` in both files. (observed)
- **`parseLen`** (`build-room.html:184-204`) handles feet/inches/fractions/unicode
  primes correctly, and a bare number is inches in both modes. I traced
  `12' 6 1/2"`, `12.5'`, `12 1/2`, `150"` by hand. (derived)
- **Text vs geometry in `dimension-whisperroom.rb`.** `ATTACH_NESTED_VERTICES` is
  `false` (:97), so both endpoints are `ConstructionPoint`s placed at the computed
  extent; `d.text = ''` forces auto text (:1030-1032); and a post-check at
  `CHECK_TOL = 0.001` reports any endpoint that did not land (:1037-1044). The
  string cannot diverge from the extent. This is the right design.
- **Transforms and orientation.** No `definition.bounds` anywhere in
  `scripts/*.rb` — the one occurrence is a comment warning against it
  (`dimension-whisperroom.rb:606`). `face_levels` and `collect_faces` both compose
  `tr * e.transformation` correctly on descent. `layout()` (:480-503) I verified by
  hand for `front = S` and `front = N` at corner `FR`: it reproduces the documented
  reference image, and it is rotation-safe because it works entirely in the booth's
  own frame. The inner corner-seal placement
  (`build-booth-components.rb:2610-2632`) rotates about the polygon's own square
  centre, so the quarter turns cannot walk the part off its footprint. The 1.42.0
  and 1.41.1 orientation fixes both generalise — they are geometry rules, not
  per-part tables.
- **`v3_slots`** (`booth-from-link.rb:363-382`) derives slot order by sorting on
  the numeric id rather than trusting `wr-booth-data.rb`'s listing order, and names
  the two models (6060/6084) where the listing order is wrong. Correct defensive
  choice.
- **Vent-name regexes.** `iep_vent_part?` (`/VNT|NV\b/i`) does not match the
  library's `LeftSideVent_VSS_EFS_CP` / `RightSideVent_…` parts, while
  `dimension-whisperroom.rb`'s `VENT_RE` (`/v(?:e)?nt/i`) does. I chased this and
  it is **not** live: `component_for` (`booth-from-link.rb:621-700`) only ever
  composes `<width>VNT…` names, so a side-vent part never reaches the builder.
  Recorded because the two files disagree about what a vent is, and one of them is
  wrong about the library.
- **The caster plate in the measured height is handled correctly** (which is what
  makes F1 stand out): `classify` returns `:caster` ahead of `EXCLUDE_RE`
  (`dimension-whisperroom.rb:158-168`), the plate votes on the bottom only
  (:378-390), `ext[:plate]` records how much of the string is plate, and the
  catalogue comparison adds it back (:974). The instance name written by
  `wr-overlays.rb:1601` (`"…  caster plate"`) matches `CASTER_RE`. The 1.42.0 fix
  generalises properly. The *measuring* tool knows about the plate; the *fitting*
  line does not.
- **The vent-box-vs-assembly-box fix (1.42.0) generalises too:** it is a
  face-level rule with no product constant, it only ever moves a bound *inward*
  (`vent_box_bound` :659-665, with the reason stated), and parts whose faces
  cannot be read are named with `***` rather than silently falling back to the box.

## What I did NOT cover

- **`scripts/proposal-package.rb`** — read two snippets only (`dim_display`,
  `collect_annotations`) and treated them as possibly stale, per the brief.
  Another agent is editing it. The path from a drawn dimension into a client PDF is
  therefore **unaudited past `collect_annotations`**.
- **`scripts/takeoff-check.py` (164 KB)** — the string→inches parser and the
  closure/geometry validation that produce the `.lock.json` live here and are the
  real unit boundary. I read only the `h_in` emission. **This is the largest single
  gap in this audit.**
- **`scripts/angled-component-art.rb`** — opened and outlined; its numbers are
  camera azimuth/elevation and pixel ratios, not product dimensions, so the budget
  went elsewhere. Not read line by line.
- **`scripts/gen-booth.py`** — the generator that produces `wr-booth-data.rb`. I
  audited the generated data against `models.json` but not the rule that produced
  it, so F8's "why is 4230 transposed" is inferred from the door width, not read
  from the generator.
- `wr-overlays.rb` (1619 lines) beyond the caster/step/EFP constants;
  `wr-drop-lights.rb`; `auto-dimension.rb`; `dimension-booth.rb` (retired); the
  per-client scripts (`csusb-*`, `uthsc-*`, `peoplesspace-alcove.rb`) —
  `csusb-rooms.rb:55` carries its own `RAMP_PROT = 45.625` ADA constant that I did
  not reconcile against anything.
- **`scripts/wr-boothlink.rb` does not exist.** The brief named it; the file is
  `scripts/booth-from-link.rb`, which is what I read.
- Nothing was run. No SketchUp, no Ruby, no harness. Every "the code does X" above
  is a read, not an observation of behaviour.
