# Enhanced (ENH) booth build — spec

Scoper, 2026-08-24. Target entry point: `scripts/booth-from-link.rb`.

**Status of the numbers in this document.** Everything in the coverage tables and the
blocker list is **observed** — I listed the share and read the scripts. Everything about
what is *inside* an `ENH` part is **unknown** and is what `scripts/probe-enhanced.rb`
exists to settle. No gap dimension appears anywhere in this spec, because none has been
measured. Do not let one appear here until the probe has run.

---

## Goal

Teach the booth-building chain to build an Enhanced booth from a customer's
booth-builder share link, the same way it already builds a Standard one. Today the chain
fails at four independent points before a single Enhanced component is placed, and a
fifth is conditional on what the probe finds inside the parts. The end state is that
`scripts/booth-from-link.rb`, given a link whose payload carries `v: 'E'`, resolves every
wall, door, vent, seal and deck slot to a real `ENH` component and places it — or refuses
loudly and names the missing part, rather than silently substituting a Standard one.

---

## Deliverable 0 — the probe, which gates everything else

`scripts/probe-enhanced.rb` is written, syntax-checked and **unrun**.

- Syntax-checked with `scripts/rbparse.py` (the CRuby 3.2 library SketchUp ships):
  reports `ok probe-enhanced.rb`, 40 files parse. **Observed.**
- It has **not been executed**. There is no Ruby outside SketchUp on this machine, and
  `.skp` files are binary, so nothing in it has produced a number yet.
- Dry-run-safe by construction: it loads component *definitions*, reads their geometry,
  writes two TSVs into the component folder, and purges. It places no instances, draws
  nothing, moves nothing, deletes nothing, and never calls `save`.

**Benton runs it**, on an empty scratch model:

```
load "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/probe-enhanced.rb"
```

It writes `P:/Sketchup/NewMasterComponentList/_enhanced-probe.tsv` and
`_enhanced-nesting.tsv`, and prints a `COMBINED, OR SINGLE?` verdict block to the Ruby
Console. **That verdict decides which of two build plans below applies.** Nothing past
Step 4 should be started before it has run.

### What the probe answers

| Question | Where the answer lands |
|---|---|
| Single slab, or two shells plus foam? | `COMBINED, OR SINGLE?` block; `shells` column |
| The gap between inner and outer shell | `gap` / `all_gaps` columns, tallied in the verdict |
| Overall Enhanced part thickness vs Standard | `thickness`, `std_thickness`, `delta_thickness` |
| Nesting structure and each child's extents | `_enhanced-nesting.tsv` |
| Extents, origin, anchor corner per part | `min_*` / `max_*` / `origin_anchor` |
| Panel height, measured | `height` column and the height tally |

### Two defects in `scripts/probe-components.rb` that the new probe fixes

Both are **observed** by reading the script against its own output TSV. They matter
because anything that has been reading `_component-probe.tsv` has been reading them.

1. The old probe labels its Z column `height`. For a wall panel **Z is the width**.
   `16PanelSolid` measures `x=1.0000 y=81.0000 z=16.0000` — height is 81, on Y.
2. The old probe derives `length` and `thickness` from X and Y only, ignoring Z. On a
   vent that is wrong: `40VNT` measures `x=40 y=82 z=8.5468`, and the old probe records
   its thickness as `40.0000` when 40 is the panel's width and the thickness axis is Z.

`probe-enhanced.rb` assigns axes by extent (thickness = smallest, height = largest,
width = the third) and **prints the assignment for every row** so a wrong pick is visible
rather than silent. That rule reproduces the correct answer for every Standard panel,
vent and door checked by hand against the old TSV.

### Panel height — a discrepancy the Builder must not paper over

The assignment states Standard panel height is `83.0000` and Enhanced `84.3125`.
**Neither figure appears anywhere in the 182-part Standard measurement.** What the
measured data says (**observed**, `_component-probe.tsv`):

- Standard wall panel height is **81.0000** — 33 parts at exactly that value on Y.
- HX is **91.0000** — 32 parts.
- `grep -cE "83\.0000|84\.3"` over the whole TSV returns **0**.
- The code agrees: `build-booth-components.rb` line 277 `want = hx ? 91.0 : 81.0`, and
  every booth in `wr-booth-data.rb` carries `:ph=>81.0`.

So `83.0000` / `84.3125` are measuring something the panel alone is not — plausibly panel
plus rail, or an assembly height. Their difference (1.3125) is the same as the difference
between values that *do* appear in the Standard set (82.3125 − 81.0). **Do not encode
84.3125 anywhere.** The probe's height tally settles the real Enhanced panel height, and
whichever source carries 83.0/84.3125 should then be corrected or re-labelled.

---

## Deliverable 1 — ENH ↔ STD coverage

Re-verified by direct listing of `P:/Sketchup/NewMasterComponentList` (359 files). All
counts below are **observed**, and several correct the figures I was given.

### Headline counts

| | Count | Note |
|---|---|---|
| Files in the folder | 359 | includes 4 `_*.tsv` artefacts |
| `ENH*` files | 116 | = 48 deck + 68 wall/door/seal |
| `STD*` deck files | 46 | `STD` + digits |
| `ENH` deck files | **48** | *not* 42 — see below |
| `STDSS` seam seals | 8 | ceiling/floor |
| Unprefixed Standard parts | 185 | walls, doors, vents, ceilings, furniture |

### The naming asymmetry — bigger than reported

This is the finding that reshapes the build plan. **Standard wall panels carry no prefix
at all.** The library is:

- Standard **walls / doors / vents / mid-wall seals**: bare names —
  `40PanelSolid.skp`, `7Panel.skp`, `46VNT_VSS_EFS.skp`, `Left46Door.skp`,
  `CornerSeamSeal.skp`.
- Standard **decks** (floor/ceiling): `STD`-prefixed — `STD9648FL CTR.skp`.
- Enhanced **everything**: `ENH ` + space — `ENH 41.5PanelSolid.skp`, `ENH 9648FL CTR.skp`,
  `ENH CornerSeamSeal.skp`.

So it is not one prefix problem in the deck builder. Two separate resolution paths need
teaching, and they are teaching-different-things:

- the deck path must learn a **new prefix on an existing pattern**;
- the wall path must learn a **prefix where there was none**.

### Deck coverage — complete

Every one of the **46** Standard deck parts has an exact `ENH ` counterpart. The set
difference in that direction is **empty** (verified with `comm` on the two sorted name
lists, stripped of prefix). Enhanced additionally carries two parts with no Standard twin:

| Enhanced part | Status |
|---|---|
| `ENH 423.54CL.skp` | **suspected typo — do not normalise** |
| `ENH 423.54FL.skp` | **suspected typo — do not normalise** |

Every other deck name is `<cross><along>` digits (`4230`, `9648`, `10242`). `423.54`
parses as neither — it is not `42`+`30`, not `42`+`3.5`, and has a decimal point no other
deck name has. Flag it to Benton; leave the files alone. Note also that `STD127LPCL` /
`ENH 127LPCL` contain `LP` and are already excluded from the deck pool by the current
regex on both sides — that is pre-existing, not an Enhanced problem.

### Wall width mapping — confirmed, one hole

Standard widths `7 16 19 22 28 31 40 43 46`; Enhanced `11.5 14.5 17.5 23.5 26.5 35.5 38.5 41.5`.
Every Enhanced width is its Standard counterpart **minus exactly 4.5 inches**, one-for-one.

**The one hole:** `7Panel` (and `7Panel_HX`) has no Enhanced twin. A `2.5` would be the
match and it does not exist.

**That hole is reachable from the portal, so it is not academic.** The 7" panel is the
*shrunken companion wall beside a wide-access door*: `booth-builder.html`'s `shrinkPack`
(line ~1980) emits `'STDWL7 / WL16'` for it. So any Enhanced booth with a WA door needs a
2.5" Enhanced panel that does not exist. This is the strongest single argument for
authoring one — put it to Benton before the other 65.

**Whether that 4.5 is the double-wall gap remains a hypothesis.** It is used in the probe
only to *pair* parts for side-by-side measurement, and the probe prints the name it paired
so a wrong pairing is visible. The `delta_thickness` column tests the hypothesis; do not
assume it.

### Missing Enhanced parts — the definitive list

**66 Standard wall-family parts have no Enhanced counterpart**, computed by mapping every
Enhanced name back through the −4.5 rule and diffing against the 132 Standard
wall/door/vent/seal parts. Grouped:

| Group | Count | Parts |
|---|---:|---|
| 7" panel | 2 | `7Panel`, `7Panel_HX` |
| ADA ramp doors | 4 | `LeftWADoorWithRamp`(+`_HX`), `RightWADoorWithRamp`(+`_HX`) |
| 40" vent options | 14 | every `40VNT_*` / `40Vnt_*` with `EFS`, `VSS` and/or `CP` |
| 46" vent options | 14 | every `46VNT_*` / `46Vnt*` with `EFS`, `VSS` and/or `CP` |
| Left side vent | 16 | `LeftSideVent` and all 15 `_VSS`/`_EFS`/`_CP`/`_HX` combinations |
| Right side vent | 16 | `RightSideVent` and all 15 combinations |
| **Total** | **66** | |

Plus, separately: **all 8 `STDSS` ceiling/floor seam seals** (`STDSS 8.5CL`, `STDSS CL5`–`CL8`,
`STDSS FL6`–`FL8`) have no Enhanced counterpart. Enhanced carries only the two *wall*
seals, `ENH CornerSeamSeal` and `ENH MidWallSeamSeal` (each with `_HX`).

**What Enhanced *does* have** on the vent side: base vents only —
`ENH 35.5VNT`, `ENH 35.5VNT_HX`, `ENH 41.5VNT`, `ENH 41.5VNT_HX`, and the no-vent blanks
`ENH 35.5NV`, `ENH 41.5NV` (+`_HX`). So the "vent coverage looks thin" impression is
correct and now precise: **the base vent panels exist; every VSS, EFS and caster-package
variant is missing, and both side vents are missing entirely.**

Consequence for the build: a customer link with `vs`, `ef` or `cs` set on an Enhanced
booth **cannot be built today** — the component does not exist. That must be a loud
refusal naming the file, never a silent fallback to the base vent.

### One Enhanced part with no Standard twin, that is probably not a typo

`ENH 26.5Panel11.548WDO` (+`_HX`) maps to `31Panel11.548WDO`, which does not exist.
`ENH 26.5Panel1648WDO` (+`_HX`) also exists and maps correctly to `31Panel1648WDO`.

So the 26.5 panel ships with **two** window variants: a 16×48 opening and an 11.5×48 one.
Reading is that the −4.5 was deliberately applied to the *opening* width as well in this
one case, giving a genuinely narrower window — but it is the only place in the set where
an opening dimension changed, every other `WDO` keeping its Standard opening (`2630`,
`2636`, `2642`, `2648`, `3230`, `3236`, `3242`, `3248`). **Open question for Benton**, in
the handoff. Do not rename either file.

---

## Deliverable 2 — the blockers, all confirmed by reading

Five, in the order the chain hits them. Each is **observed** at the line cited.

### B1 — `scripts/booth-from-link.rb`: the translator ignores the variant

`component_for(pack, o)` (lines ~116–133) is the whole portal-pack → filename layer, and
it is Standard-only in three independent ways:

- Every branch is anchored on `\ASTDWL(\d+)` — literal `STDWL`, and `\d+` cannot match
  `41.5` even if the portal emitted `ENHWL41.5`.
- Every value it returns is a bare Standard name (`"#{w}PanelSolid"`, `"#{hand}#{w}Door"`,
  `"#{w}VNT"` + options). No `ENH ` prefix is ever produced.
- **`payload['v']` is never passed in.** It goes only into `key` (`"MDL 7272 E"`), so the
  translator cannot know it is building Enhanced even in principle.

This is the *first* thing that fails, and it fails silently in the worst way: an Enhanced
link resolves to a full set of **Standard** component names, which all exist and all load.

### B2 — `scripts/wr-booth-data.rb`: no Enhanced layouts exist

The file is generated, and its own header lists **all 25** Enhanced models as skipped,
each with the reason `panel lengths unresolved` (lines 6–30). `BOOTHS` contains
`'MDL … S'` keys only. So `build_booth('MDL 7272 E', …)` finds no layout to resolve slots
against, and there is nothing to place even once B1 is fixed.

### B3 — `scripts/gen-booth.py`: the generator refuses Enhanced

The upstream of B2.

- Line 53: `STOCK = [46.0, 43.0, 40.0, 31.0, 28.0, 22.0, 19.0, 16.0, 7.0]` — Standard
  widths only.
- Line 46: `SEAL_W = 2.0` — the mid-wall seam-seal stem, i.e. the joint allowance in the
  run rule. The Enhanced equivalent is unmeasured (`ENH MidWallSeamSeal`).
- Lines ~367–373: iterates `for variant in ('S', 'E')`, and any wall whose panel lengths
  came out `(scaled)` is skipped with `'panel lengths unresolved'`.
- Lines ~449–451: prints that the run rule `interior = sum(panels) + 2" per joint` is
  confirmed for the 46" module in Standard only, and that *"Enhanced is a double-wall
  build the rule does not describe"*.

### B4 — `scripts/wr-deck.rb`: Enhanced deck parts cannot enter the pool

Line 283:

```ruby
NAME = /\ASTD(\d{2,3})(\d{2})\s*(FL|CL)\s*(CTR|SIDE)?\s*([LR])?\z/i.freeze
```

Line 287: `Dir.glob(File.join(dir, 'STD*.skp'))`.

Enhanced deck parts are `ENH ` + digits — different prefix **and** an inserted space — so
not one of the 48 can be seen. Note what the current anchored pattern buys for free: it
keeps the 8 `STDSS` seam seals out of the deck pool, because `SS` fails `(\d{2,3})(\d{2})`.
Any widening must preserve that, and must also keep `ENH CornerSeamSeal` /
`ENH MidWallSeamSeal` out. It must additionally not swallow `ENH 423.54CL`, whose decimal
point would slip through a careless `[\d.]+`.

### B5 — `scripts/build-booth-components.rb`: conditional, decided by the probe

Two sites.

**`guess_component` (lines ~171–181)** hardcodes Standard naming, including the
irregularity that `7 19 28 31 43` are `nPanel` while `16 22 40 46` are `nPanelSolid`. The
Enhanced set has its own split — `ENH 14.5Panel`, `ENH 23.5Panel`, `ENH 26.5Panel`,
`ENH 38.5Panel` versus `ENH 11.5PanelSolid`, `ENH 17.5PanelSolid`, `ENH 35.5PanelSolid`,
`ENH 41.5PanelSolid` — which is exactly the Standard split shifted by −4.5, so the same
irregularity carries over and must be re-tabulated, not re-derived.

**`wall_slab` (lines ~433–496)** is the live-bug candidate. It selects every face spanning
≥ 0.8 of the wall height, keeps the widest cluster, then spans `t0..t1` across **all** of
them and bails:

```ruby
return nil if (t1 - t0) > 3.0        # caught something that is not a panel
```

On a combined two-shell part, **both** shells span the height and both are full width, so
both land in that cluster and `t1 - t0` becomes the entire part thickness. Two failure
modes, and the measured thickness picks which:

- thickness **> 3.0** → returns `nil` → the part falls back to bounding-box placement.
  That is the same failure that once shoved the 102126's vent panels sideways into the
  neighbouring wall.
- thickness **≤ 3.0** → returns a span covering both shells, and the `use_slab` test at
  line ~529 (`(cls[:t] - band_depth) > 0.2`) plus the bulk/floor facing vote downstream are
  then reasoning about the wrong slab.

The DEVLOG files this as a *future* "prefer-outermost-slab tweak once two same-width tall
slabs exist in one part". **If the probe reports two shells, that condition is met and it
is a bug today.** The probe's verdict block says so explicitly and prints how many parts
exceed the 3.0 guard.

---

## Approach

Two plans. **The probe's verdict selects between them**, and they diverge at Step 5.

- **Plan A — parts are COMBINED** (two shells + foam baked into one component). Enhanced
  becomes a naming + stock-width + slab-finder problem. One part per wall slot, same as
  Standard. This is the plan the DEVLOG anticipated and the cheaper of the two.
- **Plan B — parts are SINGLE narrow shells.** The gap lives in the layout, not the part,
  so `wr-booth-data.rb` must carry two wall rings per Enhanced booth and the run rule needs
  a second dimension it does not have. Materially more work; escalate to Benton before
  starting rather than absorbing it into this spec.

Steps 1–4 are common to both and are safe to start **only after** the probe has run,
because Step 3's numbers come out of it.

---

## Steps

### Step 1 — record the probe's findings (no code)

**Files:** `.forge/scoper/enhanced-booth-build.md` (this file), new section "Measured".

Paste the `COMBINED, OR SINGLE?` verdict, the gap tally, the thickness tally, the height
tally and the anchor tally. State plainly which plan is selected and why. Nothing below
this line gets written until this section has real numbers in it.

### Step 2 — one shared place that knows Enhanced naming

**File:** new `scripts/wr-enh.rb` (module `WR_Enh`), loaded by the others the way
`wr-folder.rb` already is.

Because three scripts need the same mapping, it goes in one place. It must carry:

- `PREFIX = 'ENH '` (with the trailing space — the space is part of the real filenames).
- `WIDTHS` — the Enhanced stock list `[41.5, 38.5, 35.5, 26.5, 23.5, 17.5, 14.5, 11.5]`,
  descending, mirroring `gen-booth.py`'s `STOCK`. **No 2.5** (see B-hole above).
- `PLAIN` / `SOLID` split for panel naming: `%w[14.5 23.5 26.5 38.5]` are `Panel`,
  `%w[11.5 17.5 35.5 41.5]` are `PanelSolid`. Tabulate; do not derive.
- `std_to_enh(name)` and `enh_to_std(name)`, the −4.5 / +4.5 pair, used for the coverage
  check — **not** as a runtime fallback.
- `MISSING` — the 66 + 8 names above, as data, so a build can refuse by name.

**Acceptance:** `python scripts/rbparse.py` reports `ok wr-enh.rb`.

### Step 3 — teach `booth-from-link.rb` the variant (fixes B1)

**File:** `scripts/booth-from-link.rb`, `component_for` and `build_from_payload`.

- Thread the variant through: `component_for(pack, o, variant)`, called with
  `(payload['v'] || 'S')`.
- For `variant == 'E'`: map the pack's Standard width to its Enhanced width via
  `WR_Enh`, then prefix. `STDWL46` → `ENH 41.5PanelSolid`; `STDWL46 DRFRM R` →
  `ENH Right41.5Door`; `WA STDDRFRM L` → `ENH LeftWADoor`.
- **The portal emits `STDWL<n>` for Enhanced too — verified, not assumed.** Every pack
  builder in `WhisperRoomQuote/booth-builder.html` (lines ~1976–1997) is a literal
  `'STDWL' + realSize(...)`, and the string `ENHWL` does not occur anywhere in that file
  (`grep -c` returns 0). The variant is carried *only* in `payload['v']`. So the mapping
  is unambiguously **Standard pack + `v=='E'` → Enhanced component**, and there is no
  native Enhanced pack form to parse. Widening the regex to `(\d+(?:\.\d+)?)` is still
  worth doing defensively, but nothing depends on it today.
- **Handle the WA-door companion pack `'STDWL7 / WL16'`** (`shrinkPack`,
  booth-builder.html line ~1980). `component_for`'s `\ASTDWL(\d+)\z` cannot match it — the
  ` / WL16` suffix fails the anchor — so it already takes the `odd` fallback **for Standard
  today**. For Enhanced it is worse: the 7" panel is the one width with no Enhanced twin,
  so this pack is unbuildable in Enhanced and must refuse by name.
- **Refuse, don't substitute.** If the resolved name is in `WR_Enh::MISSING` or the file is
  absent, print the exact filename that would be needed and abort the build. The existing
  `odd` fallback path ("falls back to the slot's default part") must **not** be reused for
  Enhanced — falling back there means silently building a Standard part into an Enhanced
  booth, which is exactly the failure B1 causes today.
- The raw-pack echo already at line ~193 (`%-6s %-24s <- %s`) stays; it is the only thing
  that makes a mistranslation visible.

**Acceptance:** a dry run (`Dry run — report only` = Yes) on an Enhanced link prints every
slot resolved to a name beginning `ENH `, and every one of those files exists on the share.

### Step 4 — teach `wr-deck.rb` the Enhanced deck parts (fixes B4)

**File:** `scripts/wr-deck.rb`, lines 283 and 287.

- Widen `NAME` to accept an optional `ENH ` prefix alongside `STD`, capturing which, e.g.
  `/\A(STD|ENH\s+)(\d{2,3})(\d{2})\s*(FL|CL)\s*(CTR|SIDE)?\s*([LR])?\z/i` — all group
  indices downstream shift by one, so update the `catalogue` hash build with them.
- Widen the glob to cover both prefixes; a single `*.skp` glob filtered by `NAME` is
  simpler and equivalent, since `NAME` is what actually decides membership.
- Carry a `:variant` field on each catalogue entry and **filter the pool by the booth's
  variant**. Mixing Standard and Enhanced deck parts in one pool would let the tiler solve
  a run with a mixture, which is a wrong floor that looks right.
- **Regression guard, explicit:** the pattern must still reject all 8 `STDSS*`, both
  `ENH *SeamSeal`, `STD127LPCL`/`ENH 127LPCL`, and `ENH 423.54CL`/`FL`. The anchored
  `(\d{2,3})(\d{2})` does all four for free; a `[\d.]+` would break the last one.

**Acceptance:** with the folder pointed at the share, the deck catalogue returns 46 entries
for variant S and 46 for variant E, and 0 entries whose name contains `SS`, `LP`, `SeamSeal`
or `423.54`.

### Step 5 — the fork

**If Plan A (combined):**

**5A.1 — fix `wall_slab` (fixes B5).** **File:** `scripts/build-booth-components.rb`.
Replace the single `t0..t1` span with a **banded** scan: bin along the thickness axis,
classify each bin as shell / fill / void by how much of the part's width and height the
geometry in it spans, merge runs into bands, and return the band list. Then pick the
outermost shell band as the mounting reference, keeping the whole part's placement
relative to it. `probe-enhanced.rb`'s `profile` and `shell_summary` are that algorithm
already, written and syntax-checked — **lift them, do not re-derive them.** Raise or
remove the `> 3.0` guard, which exists only to reject non-panels and must not reject a
legitimately thick combined part.

**5A.2 — `guess_component` for Enhanced.** Same file, lines ~171–181. Route through
`WR_Enh`'s `PLAIN`/`SOLID` table when the variant is E.

**5A.3 — generate Enhanced layouts (fixes B3, then B2).** **File:** `scripts/gen-booth.py`.
Give `STOCK` a per-variant form, Enhanced using `WR_Enh`'s widths. Re-derive `SEAL_W` for
Enhanced from the probe's measurement of `ENH MidWallSeamSeal` — **do not assume it is
still 2.0.** Then re-run `--all` and let it regenerate `wr-booth-data.rb`. The existing
refusal at line ~446 is correct behaviour and stays: any Enhanced wall whose panel lengths
still come out `(scaled)` must remain skipped with its reason, not forced.

**If Plan B (single narrow shells):** stop and escalate. `wr-booth-data.rb` would need two
concentric wall rings per booth and the run rule would need the gap as a second input.
That is a re-scope, not a step.

### Step 6 — the missing-parts gate

**File:** `scripts/booth-from-link.rb` (the refusal path from Step 3).

Verify the gate fires on a real configuration: an Enhanced link with `vs`/`ef`/`cs` set
must refuse and name the missing vent file, because none of the 28 Enhanced vent-option
parts exist. Same for an Enhanced booth needing a ceiling or floor seam seal, since all 8
`STDSS` parts lack an Enhanced twin.

---

## Acceptance criteria

Each is a check the Builder can actually run.

1. `python scripts/rbparse.py` reports `ok` for every file it touches, including
   `probe-enhanced.rb` and the new `wr-enh.rb`.
2. `probe-enhanced.rb` has been run by Benton and its verdict is pasted into Step 1 of this
   file. **No step past 4 is begun before this.**
3. `booth-from-link.rb` dry run on an Enhanced link resolves 100% of slots to names
   beginning `ENH `, and every resolved file exists on the share. Zero slots take the
   `odd` fallback.
4. The same dry run on a **Standard** link produces byte-identical output to what it
   produces today. Enhanced support must cost Standard nothing.
5. `wr-deck.rb`'s catalogue returns 46 entries for S, 46 for E, and rejects every `SS`,
   `LP`, `SeamSeal` and `423.54` name.
6. An Enhanced link with a VSS, EFS or caster option **refuses by name** and does not
   place a base vent in its place.
7. If Plan A: for every combined `ENH` part, `wall_slab` returns a band list with ≥ 2 shell
   bands and a non-nil outermost reference — no `nil` returns, i.e. no bounding-box
   fallbacks — checked over the whole `ENH` set, not a sample.
8. If `gen-booth.py` is re-run: every Enhanced model either appears in `wr-booth-data.rb`
   or is listed in its skip header with a reason. None is force-written.

---

## Risks

- **The whole plan pivots on the probe.** Plan A and Plan B differ in cost by a large
  factor and nothing distinguishes them from outside the `.skp` files. This is the single
  assumption that invalidates the most downstream work, which is why the probe is
  Deliverable 0 and why Step 1 is "write down what it said".
- **B1 fails silently and dangerously.** An Enhanced link today resolves to a complete set
  of Standard components, all of which exist and load. A build can therefore *succeed*
  while being entirely the wrong booth. Any Builder testing Enhanced before Step 3 lands
  will see a booth appear and may read that as progress.
- **`84.3125` is in circulation and is not in the measured data.** If it gets encoded as
  the Enhanced panel height before the probe runs, every Enhanced part will be placed
  against a wrong wall height and the error will be uniform, consistent, and therefore
  hard to spot.
- **The −4.5 rule is a naming observation, not a geometric one.** It maps filenames
  correctly, one-for-one, across the whole set. Whether 4.5 is the double-wall gap, twice
  a shell thickness, or a coincidence of the module maths is exactly what
  `delta_thickness` tests. Nothing should compute a gap from it.
- **28 vent variants and 8 seam seals do not exist.** A meaningful fraction of real
  customer configurations cannot be built at all until Benton authors them. That is a
  component-authoring blocker no script change can route around.

## Out of scope

- Authoring any component. This spec says precisely which 74 parts are missing; making
  them is Benton's work in SketchUp.
- Renaming or "normalising" `ENH 423.54CL` / `ENH 423.54FL`, or either
  `26.5Panel11.548WDO`. Flagged, untouched.
- Furniture and accessories (desk, MJP, step, bass traps, studio light) and the
  roof-mounted vent — already out of scope in `booth-from-link.rb` for Standard, and this
  spec does not widen it.
- The component-art image exports.
- Anything in the `WhisperRoomQuote` repo, which is read-only. No `models.json` content and
  no prices appear here or in any artifact this spec produces.
- Fixing `probe-components.rb`'s two labelling defects in place. They are documented in
  `probe-enhanced.rb`'s header and corrected in the new probe; changing the old one would
  invalidate the `_component-probe.tsv` currently on the share without a plan for what
  reads it.
- No visual or UI dimension to this work, so no mockup: the deliverable is Ruby and Python
  behaviour, verified in the Ruby Console.
