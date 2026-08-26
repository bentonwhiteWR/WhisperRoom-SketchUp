# DEVLOG

## 2026-08-26

### Added - `angled-component-art.rb` writes `_dimensions.json` beside `_diagnostics.txt`

Built to `WhisperRoomQuote\.forge\scoper\BRIEF-sketchup-dimensions-export.md`. The Prism
Gauge (`scripts/prism-audit.js`, shipped v2.380.0) has an ingest for this file that has never
run, because the file did not exist. `loadDimensionsJson` prefers it over the text diagnostics
automatically, so nothing on the JavaScript side changes.

`_diagnostics.txt` is untouched - same format, same content, still written first.

The substantive part was not the JSON, it was **what gets measured**. `e.bounds` is the box
round everything in a component, including hidden entities, geometry on tags that are off, and
the loose arcs that draw a door's swing: the 2026-08-21 sweep measured doors declaring 29.5-61.9
in of depth against a delivered silhouette that fits a 1-in prism to 3%. The new walk grows the
box from **faces only** - a loose edge draws a hairline the JavaScript alpha bbox discards as
dust, so skipping loose edges kills the swing without having to know which entity is the swing -
and honours `hidden?` and tag visibility. Anything short of a clean walk gets a `bbox_kind`
that is **not** the literal `"visible"`, plus a note, because a missing row is recoverable and
a wrong row is not.

Two design decisions came from reading the ingest rather than the prose, as the brief instructs:

- `out.set(r.scene, ...)` keys on `scene`, so two rows sharing a scene name silently overwrite
  each other. Rule 3 ("one row per PART even when one scene holds two") is therefore carried as
  a `parts` array on the one row, each part with its own bbox and `z_base`.
- `parseDiagnostics` strips a leading `"ENH "` from the scene label to reach the PNG stem;
  `loadDimensionsJson` does no such thing. So `scene` is emitted as the **PNG stem** (the
  sanitised definition name, which is what the exporter actually names files from) and the
  SketchUp scene label rides along as `scene_name`. No scene was renamed.

`facing` is attempted: front-face projected area per camera, accumulated during the same face
walk. It assumes front-face-out modelling, so it ships as an object carrying its basis and the
margin it won by, not a bare camera name.

`body` and `proud` are **not** emitted. Which nested entity is a door lever or a duct elbow is
not labelled anywhere in the model, and `body` is required whenever `proud` is present.

**UNRUN IN SKETCHUP** - it has never produced a real file. What was run: `scripts/rbparse.py`
(real CRuby 3.2, 52 files, all parse) and a new harness pair,
`.forge/builder/emit-dimensions-fixture.py` + `.forge/builder/check-dimensions-ingest.js`,
which builds a fixture in the emitted shape and runs it through `loadDimensionsJson` copied
verbatim out of `prism-audit.js` - 25 assertions, all passing. The fixture generator
cross-checks its own JSON keys against the ones in the `.rb`, so a drifted transcription fails
loudly. `WhisperRoomQuote` was read only; nothing in it was changed.

VERSION was already at 1.6.28 from another agent's change in the same session and was left
alone rather than fought over.

### Changed - `IEP_WALL_LIFT` is a per-booth table, and an unmeasured booth says so (v1.6.28)

Three booths have now had their inner-shell vertical looked at and they do not agree, so the
single global constant was the wrong shape:

| booth | lift | how |
|---|---|---|
| **MDL 4872 E** | **0.7500** | Benton's eye 2026-08-25 - *"all of the IEP components need to go up .75"* - then a probe of his corrected full booth agreeing with the build to 0.0001 (v1.6.17). The only probe-backed figure here. |
| **MDL 6060 E** | **0.6875** | Benton's eye 2026-08-26 - *"The IEP inner shell just needs to drop 1/16" and its perfect."* No probe. |
| **MDL 102144 E** | **0.7500** | Benton 2026-08-26, asked which booth the 1/16 report was about: *"This was only for the 102144 E. Im not sure about any others. But the IEP shell was 1/16" too low."* Built at 0.6875, so 0.6875 + 1/16. No probe. |

**UNRUN IN SKETCHUP.** No Ruby on this machine outside it. What WAS run: `scripts/rbparse.py`
(52 files, real CRuby 3.2 - all parse), `.forge/builder/replay-iep-deck.py` (still passes, 31
assertions, unchanged), and a new `.forge/builder/replay-iep-wall-lift.py` (**105 checks**)
which parses the table out of the real `.rb` rather than restating it.

**NO RULE WAS DERIVED.** Three points and two values are not a rule, and Benton's own words on
scope are *"Im not sure about any others."* `IEP_WALL_LIFT_DEFAULT = 0.7500` because two of the
three measure it and one of those two is the probe-backed one - but the other **22** Enhanced
layouts have never been looked at, and the build now names the booth in its warning block when
it uses the default. That is the `IEP_ROOM_PROUD` idiom, copied deliberately: a figure that was
not measured for the thing being built must not be able to pass as one that was.

**The plumbing: an argument, not module state.** `part_top_z(part, hx)` did not know which booth
it was building. It now takes the lift as a third **required** argument; `build_booth` resolves
it once from the layout key it is already handed (`lift = iep_wall_lift(key)`) and passes it to
the one call site. It is not stashed on the module, and that is the whole reason for the shape -
SketchUp is long-lived, this module outlives a build, and a "current booth" left on it would be
silently inherited by the next build in the same session. A required argument cannot go stale.

**Also.** The build-report line no longer claims one global figure measured on the 6060 E; it
prints this booth's number and whether it was measured or defaulted. The warning-block header
now says *"item(s) flagged"* rather than *"part(s) do not measure their slot"*, which was already
untrue of the room-proud lines living there. `build-booth.rb`'s `IEP_LIFT = 0.3125` was **not**
changed - only its comment, which claimed to be kept in step with a constant that no longer
exists in that form.

**What is still a guess:** the 0.7500 default on 22 booths, and the 6060 E / 102144 E figures,
which are an eye and not a probe. **The booth that would falsify the default is any Enhanced
booth other than those three** - build one on a restarted SketchUp and read the inner shell. A
fourth reading of 0.6875 would say the 4872 E's probe measured a hand placement that was itself
1/16 out, and the default belongs at 0.6875 instead.

Nothing else moved: `IEP_VENT_YAW` (180.0), `IEP_TRAY_DROP`, `SEAL_FL_DATUM_LIFT` (-1.1250),
`IEP_CL_UPSIDE_DOWN` / `iep_upside_down?`, the tray-lip seat rule and the room-proud figures are
all untouched, and an outer wall's lift is still 0.0 on every path.

### Fixed - the inner tray's orientation is now MEASURED per part, not declared (v1.6.25)

Benton, off a freshly built **MDL 102144 E**: *"the IEP ceiling needs to be flipped upside down.
The tray part was pointing up, it needs to point down."*

**UNRUN IN SKETCHUP.** There is still no Ruby on this machine outside it, so nothing below has
been executed against real geometry. What WAS run: `scripts/rbparse.py` (52 files, real CRuby
3.2) and `.forge/builder/replay-iep-deck.py`, now **31 assertions** against the real 370-file
component folder, up from 25. All pass.

**Root cause, one line.** `iep_deck` passed a global boolean - `IEP_CL_UPSIDE_DOWN = false` -
straight into `flat_placement` as its `flip` argument. Every inner tray therefore went in
exactly as authored, and the code had no per-part opinion at all. The Standard deck has never
had this bug: `WR_Deck.build` calls `contact_z(defn, kind)` and takes the orientation from its
second return value, which exists because *"all ceilings are upside down on MDL 96168 S"*.
The IEP path was the last deck path still placing parts on faith.

**SETTING THE GLOBAL TO TRUE WOULD HAVE BEEN WRONG, and the reason is three part families.**

```
ENH 4872CL                            MDL 4872 E    closed, tray ACCEPTED
ENH 9648CL SIDE / CTR, 9624CL CTR     MDL 96144 E   scrutinised, tray NOT reported
ENH 10242CL SIDE / CTR, 10218CL CTR   MDL 102144 E  tray REPORTED opening upward
```

At least one of those is authored right and at least one is not. A single boolean cannot say
so, and flipping it trades the closed 4872 for the 102144.

**THE TABLE THAT WOULD SETTLE IT DOES NOT EXIST, and that is the honest finding.** Harness
section 9 goes looking for the face-level profile of every `ENH` CL part and comes back empty:

- **`_face-levels.tsv` carries ZERO `ENH` rows.** Checked over all 4544 of them and asserted.
  It is dated 2026-08-14 and holds the 183 wall panels plus the 44 STD deck parts and the
  seam seals - not one Enhanced part of any kind. No ENH deck part has ever been face-level
  probed. (This is a second trap in the same area as the `_component-probe.tsv` one: that file
  has no deck parts, this one has no Enhanced parts.)
- **`_enhanced-probe.tsv` cannot answer it either, by construction.** Every ENH deck part
  reads as exactly ONE shell band - asserted - because `probe-enhanced.rb`'s `profile()`
  classifies a depth bin by EXTENT, not by area, and a tray spans its whole footprint at
  every depth whichever way up it is. Ten faces and 34 top entities on every tiled CL part is
  four walls inside and out plus one plate; the probe just cannot see which end the plate is
  at.

So the orientation is measured **at build time**, where the geometry actually is.

**`IEP_CL_UPSIDE_DOWN` is now `nil` = MEASURE.** `true` and `false` still force, so the
pre-v1.6.25 behaviour is one word away. New `iep_upside_down?(defn, kind, forced)` asks two
questions in order:

1. **`WR_Deck.contact_z(defn, 'CL')` first** - the fit-tested Standard rule, called read-only.
   **`wr-deck.rb` is NOT edited**; that path is live and cannot be run here.
2. **Then a tray's own tell, when contact_z has nothing to say.** contact_z hunts a face pair
   1.0000 apart - the Standard slab - and a minor level outside it. An ENH deck part is built
   nothing like a Standard one (`box_z` 3.1080 STD against 1.7500 ENH CL and 0.3125 ENH FL),
   so when there is no such pair contact_z falls back to [lowest, highest], finds nothing
   outside it and returns **false - which is its NO-CUE answer, not a measurement.** A tray is
   closed at one end and open at the other, so the end holding the big PLATE face is which way
   the mouth points; the rim end is a thin ring. Plate high is right, plate low is upside down,
   per Benton's own sentence: *"the tray faces downwards, and it sits on top of the standard
   ceiling, completely engulfing it."* Levels come from `WR_Deck.flat_levels`, not a second
   face walker, and only the two EXTREME levels are compared - so the trap that turned every
   floor CTR panel over, a 1/32 lip read as the room-side tell because it sat INSIDE the slab,
   cannot arise here.

**THE HARNESS CAUGHT THE MOUTH TELL MISFIRING AND THE GATE IS LOAD-BEARING.** Run over the real
`_face-levels.tsv`, the tell fires *"mouth UP"* on **17 of the 22 Standard FLOOR panels** -
`STD4896FL` reads 4608 sq in low against 632 high - because a floor panel is a field face at the
bottom with a thin perimeter strip on top, the same area shape as an upside-down tray and nothing
to do with orientation. Ungated it would stand every floor on its head. It is gated to `CL`, and
the harness asserts **both** halves: it abstains on all 16 Standard ceilings, and it misfires on
the floors. That is also why **`IEP_FL_UPSIDE_DOWN` stays a declared `false`** - an ENH FL part
is a 0.3125 flat sheet with no mouth to point, and no floor mat has ever been reported wrong.

**Nothing moves that was not already wrong.** The flip is a 180 about X, so a tile's vertical
ENVELOPE is unchanged and `IEP_TRAY_DROP`, the tray-lip seat rule, `IEP_WALL_LIFT`,
`IEP_VENT_YAW` and the room-proud figures are all untouched. A part the detector reads as
right-way-up is placed exactly where v1.6.24 placed it.

**Every tile now prints which way it went in and on what evidence** - `FLIPPED - tray mouth
reads UP (plate 4472 sq in low, rim 147 high)`, or `as authored - tray mouth reads DOWN`, or
`NO ORIENTATION CUE ... CHECK IT`. The old code printed nothing because it had nothing per-part
to print, which is the whole of why this shipped unnoticed.

**Residual risk, named.** If `ENH 4872CL` turns out to be authored mouth-up, the detector will
flip the closed 4872 E. Nothing on this machine can rule that out. The console line says what it
decided; `IEP_CL_UPSIDE_DOWN = false` reverts.

**To fill the empty table in:** run `scripts/probe-levels.rb` on
`P:/Sketchup/NewMasterComponentList` with an **EMPTY filter** - it OVERWRITES `_face-levels.tsv`,
so a `CL` filter would throw the wall panels and the FL rows away - then re-run the harness and
section 9 prints the real per-family answer.

### Fixed - the IEP tray tiles overlapped by 1 in, and the floor seam seals now get placed (v1.6.23)

Two reports off Benton's built **MDL 6060 E**. **Neither has been run in SketchUp** - there is
still no Ruby on this machine outside it. What WAS run: `scripts/rbparse.py` (52 files, real
CRuby 3.2) and `.forge/builder/replay-iep-deck.py`, now **25 assertions** against the real
370-file component folder, the real generated layouts and the real part probes, up from 8.

**1. The tray lip. Each CL tile pushes out 1/2 - and the 1/2 is derived, not dialled in.**

Benton: *"the 6042 ceiling needs to push out 1/2", and the 6018 needs to push out as well ...
same 1/2"."* The floor was NOT reported wrong, and that turns out to be the tell.

**Every ENH ceiling part is bigger than its name and every ENH floor part is not.** Measured off
`P:\Sketchup\NewMasterComponentList\_enhanced-probe.tsv`:

```
ENH 6042FL SIDE L   42.0000 x 60.0000   nominal
ENH 6042CL SIDE L   43.0000 x 62.0000   +1 along the run, +2 across it
ENH 6018CL SIDE R   19.0000 x 62.0000   +1 / +2
ENH 10242CL CTR     42.0000 x 104.000   +0 / +2
ENH 10242CL SIDE    43.0000 x 104.000   +1 / +2
ENH 8418  CL        18.0000 x  86.000   +0 / +2   (a middle tile, despite the name)
ENH 4230CL          32.0000 x  44.000   +2 / +2   (a whole deck)
```

**ONE RULE COVERS ALL 44 PARTS: the tray carries a 1 in lip on every edge that faces OUT of the
booth**, because it "sits on top of the standard ceiling, completely engulfing it". A SIDE tile
has one outer edge along the run, a CTR tile none, a single-piece tray two; across the run every
tile has two. Asserted part by part in the harness.

The old code centred each tile on its NOMINAL slot, so a 43 in part on a 42 in slot hung 1/2 off
**each** end - half a lip outward and half an inch **on top of its neighbour**. Seating the outer
edge on the slot's outer edge instead gives the outer end its full inch and leaves the inner face
flush. On the 6060 E, in real edges:

```
                     was                     now              moved
ENH 6042CL SIDE L    0.500 .. 43.500    0.000 .. 43.000       -0.500
ENH 6018CL SIDE R   42.500 .. 61.500   43.000 .. 62.000       +0.500
joint                overlap 1.000      flush 0.000
run                  61.000             62.000  = 60 + 1 lip each end
```

Benton's 1/2 exactly, in both directions, from the parts' own measurements.

- **Not a 6060 constant.** It is `flat_placement` taking a per-axis seat (`:centre` / `:min` /
  `:max`) and `iep_deck` choosing `:max` at the low end, `:min` at the high end and `:centre`
  everywhere else. It covers all 18 tiled booths at once.
- **Across the run stays centred and that is correct** - both cross edges are outer, so splitting
  the +2 gives each its inch.
- **A single-tile deck is centred on both axes**, which is why the closed **MDL 4872 E cannot
  move**. 14 of them asserted unmoved.
- **The floor does not move at all**, on any of the 25 layouts, because ENH FL parts carry no
  lip. That is why Benton saw the ceiling and not the mat.

**THE STANDARD DECK WAS CHECKED FIRST AND HAS NO LIP.** If `WR_Deck.build` already solved this,
the fix would have been to call it rather than write a second rule. It does not: all 21 STD
ceiling parts measure their nominal name to 0.0001. The source is `_face-levels.tsv`, **not**
`_component-probe.tsv` - the component probe carries the 183 wall panels and not one deck part,
which is why an earlier attempt to read Standard deck widths out of it found nothing. **The
Standard path is untouched.**

Two things the parts made us say out loud rather than assume: `ENH 8418 FL` measures 17.9375,
1/16 UNDER its name (its Standard twin does the same), and it is a middle tile on both booths
that use it, so it is centred either way and leaves a 1/32 gap that this change neither causes
nor fixes; and the single-piece 42xx / 48xx trays are authored with X ACROSS the run while the
tiled parts have X along it, so nothing reads a span off a named axis.

**2. Floor seam seals.** Benton: *"We also need to start pulling in the floor seam seal."*

`STDSS FL5 / FL6 / FL7 / FL8 / STDSS 8.5FL` have been in the library all along and were never
placed - `SEAL_NAME` matched `STDSS CL<n>` and nothing else. `WR_Deck.seals` now takes a `kind`
and both decks get their seals.

- **A second pattern, `SEAL_FL_NAME`, not a loosened first one.** `SEAL_NAME` and `NAME` both
  carry capitalised comments about keeping the seals out of the panel pool; two named patterns
  cost one line and cannot drift. Asserted disjoint, and asserted that no seal of either family
  reaches either deck pool.
- **The two families are NOT the same length.** `SEAL_LEN_INSET`: a ceiling seal is cross - 2
  (CL5 58, CL6 70, CL7 82, CL8 94, 8.5CL 100) and **a floor seal is the full cross** (FL6 72,
  FL7 84, FL8 96). Two inches is not a rounding difference and one shared rule would have called
  every floor seal wrong by exactly that. `STDSS FL5` and `STDSS 8.5FL` are not in the probe, so
  the FL figure is measured on three of five and assumed for two; the length tripwire catches it.
- **THE FLOOR SEAL'S VERTICAL DATUM IS NOT MEASURED, and `SEAL_FL_DATUM_LIFT` is `nil` to say
  so.** While it is nil the build derives the ceiling rule's own sentence - top face flush with
  the deck's contact plane - from the part's own geometry, places the seals, and **warns by name
  on every build**. Set it from a fit test and the warning stops.
  **The ceiling's `-1.75` was NOT reused and must not be**: that is Benton's 2026-08-17 hand fit,
  tied to the re-cut that made the CL seals 1.750 tall, and the floor part is a different
  profile - 7.1897 across the joint against 6.500, 1.6906 tall, largest face at its BOTTOM
  (-1.0000) where the ceiling's is at its datum. The three candidate datums are written out at
  the constant so the fit test is a one-line edit.
- **Deck seam seals are a Standard-deck feature.** The only `ENH` seals in the folder are
  `ENH MidWallSeamSeal` and `ENH CornerSeamSeal`, which are WALL seals. Observed off the real
  listing. The inner deck's joints get nothing, and whether they should is Benton's call.
- Every jointed deck on all 50 layouts finds both its seals; FL and CL joint stations agree on
  all 50, so one implementation serves both.

**Still not established, and named rather than papered over:** whether ENH deck parts carry a
bracket line at all (the end-for-end turn); the floor seal's seating height; the 11.5 and 35.5
room-prouds; and the global-vs-per-booth `IEP_WALL_LIFT` question, which is still Benton's 4872 E
re-check.

### Added - the IEP deck tiles, and the inner shell drops 1/16 (v1.6.22)

Two reports off Benton's built and hand-corrected **MDL 6060 E inner shell**, both closed here.
**Neither has been run in SketchUp** - there is no Ruby on this machine outside it. What was
run is `scripts/rbparse.py` (52 files parse, real CRuby 3.2) and a Python replay of the
catalogue and tiling solver against the real component folder and the real generated layouts,
`.forge/builder/replay-iep-deck.py`.

**1. `IEP_WALL_LIFT` 0.75 -> 0.6875.** Benton: *"The IEP inner shell just needs to drop 1/16
and its perfect."* One constant, one word to revert.

The tension is recorded in the comment rather than resolved, because nothing here can resolve
it. `IEP_WALL_LIFT` is global, and 0.75 was itself measured - off the corrected **4872 E** on
2026-08-25 (*"all of the IEP components need to go up .75"*), with the v1.6.17 probe agreeing
to 0.0001. But that probe measured Benton's CORRECTED model, so it proves the code matched his
hand placement, not that his hand placement was right. So either 0.6875 is right for every
booth and the 4872 E has been 1/16 high since it was closed, or the lift is per booth, or
something 6060-specific is absorbing a sixteenth elsewhere. **No per-booth table was invented.**
**The 4872 E's vertical needs a re-check** - that is the open item.

What it costs: the even 0.75/0.75 split of the 1.5 between the two lips is gone. An inner wall
now runs 0.6875 to 80.1875 in an 81 nominal, leaving 0.8125 at the top. `IEP_TRAY_DROP` is
unchanged at 0.75 - it is measured against the standard ceiling, not the walls - so the gap
between the inner wall top and the tray widens by the same sixteenth.

**2. The IEP floor and ceiling now tile.** `iep_deck` composed one name, `ENH <digits>FL/CL`,
and refused everything else because *"how those tile is a layout question this file has no
answer for."* It had an answer all along, in `wr-deck.rb`.

- **The `ENH` deck library has exact parity with Standard.** Re-verified off the real folder:
  **44 STD deck codes, 44 ENH deck codes, identical sets, nothing in either direction.**
  (A pre-brief count said 42 each; the two extra are the space-form `8418 FL` / `8418 CL`.
  Parity holds either way.)
- So the job was reuse, not invention. `WR_Deck.catalogue` takes a `family` argument
  (`'STD'` default, `'ENH'`), and `iep_deck` calls `WR_Deck.plan` with the ENH catalogue.
  Which widths tile the run, where the odd tile goes, which hand sits at which end - all of it
  is the fit-tested Standard solver, unchanged.
- **`WR_Deck.build` was not touched.** The Standard deck path resolves and places exactly as
  before: same glob, same regex, same defaults. The replay asserts the STD pool is
  byte-identical to the pre-change pattern, and that STD and ENH resolve the same arrangement
  on all 25 E layouts.
- **All 25 Enhanced layouts now resolve a full inner deck. None refuse.** The 6060 comes out
  `ENH 6042FL/CL SIDE L` low and `ENH 6018FL/CL SIDE R` high, which is what `wr-deck.rb`'s own
  comment says the Standard 6060 does. Asserted in the harness.
- **The vertical rules are untouched**, and they stay in `build-booth-components.rb` because
  they are the part the IEP does differently: the FL mat's TOP meets the standard floor's
  underside, the CL tray's BOTTOM sits `IEP_TRAY_DROP` below the standard ceiling's TOP. Both
  read off the placed standard deck's own bounding box, so no z constant is re-derived. One z
  per deck, shared by its tiles.
- **Refuse-by-name survives.** A tiling wr-deck cannot solve is reported with its reason and
  with the single-piece name that would have covered it; a part that will not load leaves its
  tile EMPTY and says so; a hand substitution is warned. Nothing falls back to a Standard part.
- **The widened pattern still refuses what it must.** The anchored `\d{2,3}\d{2}` is what keeps
  the 18 `STDSS` / SeamSeal parts out of the deck pool - and, on the ENH side, the 68 wall
  panels, whose names carry a decimal point (`ENH 41.5VNT`, `ENH 17.5PanelSolid`) that the
  pattern cannot cross. `127LP` is excluded from both families, in step. All verified against
  the real listing.

**What is NOT established:** whether the end-for-end turn transfers to `ENH` deck parts. The
rule is a measurement - `bracket_edge` walks the geometry proud of the part's own rim - so it
measures the ENH part, not the Standard twin, and where an ENH part is symmetric it returns nil
and the positional fallback applies. But nobody has opened an ENH deck part to see whether it
carries a bracket line at all. **A single-tile deck never turns**, so the closed 4872 E cannot
move; the harness proves every single-tile inner deck still centres on the booth centre exactly
as the old code put it.

**Not done:** the 11.5 and 35.5 room-prouds are still unmeasured and still fall through to
`IEP_ROOM_PROUD_DEFAULT` with a warning. That is the next measurement.

### Fixed - the 6060 E's floating panel: rebalance was re-walking walls from PACKAGING (v1.6.21)

Benton built MDL 6060 E, inner shell only, and probed it: *"Its quite broken. Easy fixes, the
vent walls need to rotate 180 degrees."* One panel was outside the booth entirely, at booth
y **-7.875**.

**Root cause, and it is one line.** `rebalance_walls` re-walks a wall from each part's real
width. For an `ENH` part `wall_slab` finds no panel inside the definition, so the only width
left was the whole definition's bounding box - and that box is the part PLUS its trim and
void: `ENH 35.5VNT` measures 35.750 on a 35.5 module, `ENH 35.5PanelSolid` 35.625. Re-walking
the 6060 E's E inner wall from those gives 4.25 + 35.750 + 6.5 + 11.5 = 58.000 against a wall
that ends at 57.75. That is 0.250 out, past the 0.15 closure tolerance, so the wall bailed out
and kept its stale slot polygons. `place()` then centred the 35.75-long vent on the 11.5 slot -
10.0 - 17.875 = **-7.875**, the probe's number exactly. The W wall overran only 0.125, squeaked
under the tolerance, and rebalanced an eighth long instead, which is the whole of why
`W-seal0i` sat at 37.0 rather than 36.875.

**The outer shell of the same booth was never affected**, and that is the tell: a Standard part
has a findable slab, so the re-walk uses the exact panel widths 40 + 2 + 16 and closes to
+0.0000. The inner shell was the only one working from packaging.

**`iep_nominal_width` is the fix** - the module width the part's name declares, on the same
regex `iep_room_proud` already uses - and `pw_of` prefers it over the bounding box when there
is no slab. The FIT column still reports the raw packaging, so nothing is hidden.

**Not in the generated data, and not in `ASSIGN`.** `wr-booth-data.rb` is generated and a hand
edit dies at the next `gen-booth.py --all`; `ASSIGN` carries Benton's intent (the 40/35.5 part
and the vent both at the door end) and is right. The code's own design already names
`rebalance_walls` as the thing that makes the geometry follow `ASSIGN`. It worked on the outer
shell. Now it works on the inner one.

**`IEP_VENT_YAW = 180.0`** - Benton's second instruction, an inner vent turned end for end,
about its slot polygon's centre like the seal and the door before it. It is a FACING change and
nothing else: the room-proud block re-seats the box afterwards, so the bounding box lands
exactly where it already did. That means the 4872 E's `N0i` gets the same flip, and it means
the 4872's 0.0001 probe agreement was never evidence about facing in the first place - a probe
compares boxes and a box cannot see a half turn. Benton's eye is the only instrument for it.

**Two of the five reported defects were re-derived and are not defects.** `W-seal0i` at 37.0 is
the 0.125 stretch above and goes to 36.875 on its own. The thin-box `ENH 11.5PanelSolid` is
seated IDENTICALLY on N and S once its real 1.1563 box thickness is used instead of the nominal
1.125 - both 1/16 into the room, both landing on the probe to four places. Whether 1/16 is the
right figure for a thin box in a 2.0 band is Defect 5's missing measurement, not a sign error.

**Unrun in SketchUp.** Verified by `.forge/fixer/replay-rebalance.py`, a Python replay of
`rebalance_walls` + `place()`'s along-wall arithmetic against the real layout data. It
reproduces all 16 of Benton's probed inner positions exactly under the old rule, including the
-7.875; under the new rule the 6060/6084/7272/7296 E inner walls all close +0.0000 and **the
4872 E and the Standard path come out byte-identical**. `python scripts/rbparse.py`: 52 files
parse. Full write-up in `.forge/fixer/ROOTCAUSE-6060E-2026-08-26.md`.

## 2026-08-25

### Session close - 4872 E is complete; 6060 E is next

Benton: *"I'd say the 4872 E is complete."* Every part of an Enhanced 4872 - both shells, both
decks, the door - is placed from a measured number, and the last full-booth probe agreed with
the builder to 0.0001 on every inner part. Plugin is at **1.6.18**.

**Next: MDL 6060 E, which Benton says is "still pretty botched".** What is different about it
from the 4872, and therefore what to expect:

- **Panel widths 11.5 and 35.5** on every wall (35.5 + 6.5 + 11.5 = 53.5 both axes). Neither
  width has a measured room-proud; both take the 41.5's 1/16 by default and the build warns
  about it. Expect a 1/32-ish across-wall correction on each - `IEP_ROOM_PROUD` in
  `build-booth-components.rb`, keyed on the width string.
- **Split runs on E and W as well as N and S**, so all four walls carry a mid-wall seal and the
  E/W seals run at yaws the 4872 never exercised. The `ASSIGN` row `'MDL 6060 E'` also carries
  the E/W big-wall reversal (16/40 outer, 11.5/35.5 inner) and has never been built.
- **The ENH 11.5PanelSolid is one of the four thin-box parts** (1.125 thick where its siblings
  are 2.0625), so its box may sit differently across the wall than the family rule assumes.
- **Its deck is `ENH 6060FL` / `ENH 6060CL`, which do NOT exist.** The library has 6018 and
  6042 SIDE L / SIDE R pieces for both floor and ceiling. The builder refuses by name and skips
  the IEP deck, so the 6060 is the first booth that needs the tiling rule for CTR/SIDE pieces.

**Next steps, in order:**

1. `git pull` on whichever machine. Nothing under `wr_tools/` changed this session, so no
   reinstall; Rescan the panel.
2. Build **MDL 6060 E, Shell = Inner (IEP) only**. Read the warning block: it will name the
   two unmeasured widths.
3. Correct it by hand - the whole inner shell, as Benton did for the 4872 - and probe it. The
   probe on `P:` plus "X needs to go Y" is what closes it; screenshots do not.
4. Ask Benton how the 6042 / 6018 SIDE L / SIDE R deck pieces lay out against the standard
   6060 deck. That is the only piece of the 6060 with no rule at all.

**Open decisions:**

- `ENH CornerSeamSeal` is placed with a direct 0/90/180/270 on the assumption it is authored
  as the SW corner. The 4872 confirmed all four; nothing further to decide unless a booth shows
  otherwise.
- HX Enhanced is untested; 89.5 wall height and the 0.75 lift are assumed to carry.

### Done - the deck contact face is the true face, not its 1/64 bucket (v1.6.18)

Benton: *"the standard ceiling is just SLIGHTLY too low. Like maybe 1/128."* He is right, and
it has a mechanism. `wr-deck.rb` rounds every horizontal face's z to the nearest 1/64 so that
the faces of one plane land in one bucket - necessary for grouping - and then placed the deck
AT THE BUCKET KEY. A contact face at 2.1016 is filed under 2.1094 and the ceiling sits 1/128
low. `flat_levels_with_exact` now keeps the area-weighted mean of the true z in each bucket and
`contact_z` hands back that, on every path. Grouping still rounds; placement no longer does.

The build report's `contact` column will show the change - it read 2.1094 for `STD4872CL` and
should now read the face's real height. The IEP tray is placed off the ceiling's placed bounds,
so it follows without a change.

Benton also reports the inner door was untouched in his corrected probe - the builder's
placement stood. That closes the last unverified part of the inner shell.

### Done - the whole inner shell verified against a corrected full-booth probe (v1.6.17)

Benton built the complete 4872 E - both shells, both decks - corrected it by hand, and probed
all 28 instances. Converted to builder coordinates (y less 15.0831 for the door's swung leaf,
z less 1.3125 for the mat) and compared part by part against what v1.6.16 produces:

| part | worst axis |
|---|---|
| W0i, E0i, N0i, N1i, S1i | 0.0001 |
| N-seal0i, S-seal0i | 0.0000 |
| all four inner corners | 0.0000 |
| FLi mat | 0.0000 |
| **CLi tray** | **z +2.3580** |

**Every inner wall part, every seal, every corner and the floor mat are right to four places.**
That is the room-proud table, the one-ended trim, the direct corner transform, the seal plate
outboard, the 0.75 lift and the mat-under-the-floor rule, all confirmed at once against an
assembly Benton seated himself.

**The tray was the one miss, and it is a rule, not a nudge.** Its bottom had been put at the
standard ceiling's underside; Benton has it at the standard ceiling's TOP less 0.7500 - to four
places - so it caps the ceiling rather than hanging under it. `IEP_TRAY_DROP = 0.75`.

The door is the one part this comparison cannot check: it is placed off its internal slab and
the slab's position inside the door's box is not recorded anywhere, so a box-to-box comparison
says nothing. Benton's probe has the door box at booth y 2.7253..5.2656 on the S wall. Whether
the builder lands there is a question for the next build, not this table.

### Done - IEP shell up 0.75, and the IEP floor and ceiling are placed (v1.6.16)

Benton: *"all of the IEP components need to go up .75. You still haven't listed the IEP
ceiling. So go ahead and add it to the builder now. Same with IEP floor."*

**`IEP_WALL_LIFT = 0.75`.** 0.3125 was a derivation, 0.0 was a guess checked by eye, 0.75 is
what the eye said. The 1.5 an Enhanced wall gives up splits evenly.

**The IEP deck is in**, on the rule Benton gave two rounds ago: the floor is *"the 5/16 black
rubber mat that sits under the standard floor"*, the ceiling *"the tray faces downwards, and it
sits on top of the standard ceiling, completely engulfing it"*. Both are placed AGAINST THE
STANDARD DECK THAT WAS JUST PLACED - the mat's top at the standard floor's underside, the
tray's bottom at the standard ceiling's underside - read off the placed instances' own bounds,
so no z constant and no re-derivation of wr-deck's fit-tested datums. Each part is turned a
quarter if its footprint is the other way round (`ENH 4872CL` is 50 x 74 on a 74 x 50 booth)
and centred on the booth. `IEP_CL_UPSIDE_DOWN` / `IEP_FL_UPSIDE_DOWN` flip a part that comes
in the wrong way up; both default false and are one word to change.

**One piece per deck, the rest refused by name.** 4230 through 4896 ship a single `ENH <n>FL`
and `ENH <n>CL`. Everything larger tiles across CTR / SIDE pieces and that tiling is not
solved; a booth whose single-piece parts are not in the library says so and skips its inner
deck rather than guessing where a ceiling panel goes.

**Inner-only builds now place the standard deck, measure it, and erase it**, so the IEP deck
has something to sit against and the model still ends up holding only the inner shell.

Unrun. `rbparse` only - the deck placement uses the SketchUp API end to end and the harness
cannot reach it. The build report prints each IEP deck part's z so the first run is checkable.

### Done - room-proud is per panel width: 17.5 at 3/32, 41.5 at 1/16 (v1.6.15)

The test from the last entry came back: *"both the 17.5 panels need to go inwards 1/32"*. So
the 17.5 really is 3/32 and the 41.5 really is 1/16 - same 2.0625 box, different room-side
trim. `IEP_ROOM_PROUD` is now keyed on the width in the part name, with the vent family at
1/8. The six IEP widths not yet measured (11.5, 14.5, 23.5, 26.5, 35.5, 38.5) take the 41.5's
1/16 and are named in the build's warning list so a default never passes as a measurement.

### Done - the E and W walls: one-ended box trim, and the panel family at 1/16 (v1.6.13)

First measurement of an E/W wall, given as instructions rather than a probe: *"East wall
needs to go north 1/16, east 1/32. West wall needs to go south 1/16, west 1/32."*

**Along the wall, north-on-E and south-on-W are the same move.** Both walls hold a
41.5PanelSolid turned 180 in plan, and working it through `place()` and `rotation()` - out
sign, FACE_OUT, the EVEN parity - the part's +width axis points south on E and north on W.
So both walls want 1/16 toward the part's LOW-width end. That is the signature of a bounding
box whose 0.125 overshoot sits entirely at one end: centring the box puts the panel 1/16 off,
toward the other end. `iep_trim_end` returns `:lo` for the panel family and `:sym` for the
vent family (its centring landed to four places, so its trim is symmetric), and a slab-less
panel with a one-ended trim is shifted half its overshoot toward that end along the part's own
width axis in world.

**Across the wall, both want 1/32 outboard**, so the panel family's room-proud is 1/16, not
3/32. That contradicts the 17.5 measurement by exactly the 1/32 Benton's first hand placement
of that panel was "not exact" by. One number for the family and a test: the next N probe
should read the 17.5 at 2.8125. If it truly wants 2.7812, the figure splits by panel width.

Then Benton, off the S wall: *"the door should push inwards 1/2"*. `IEP_DOOR_IN = 0.5`, applied
toward the room after the door's half turn (v1.6.14). Still unmeasured: the rest of the S wall, and the
ceiling and floor datums for the inner deck.

### Done - the room-proud figure is per family: vent 1/8, panel 3/32 (v1.6.12)

Fifth probe. The vent landed at 2.7500 as predicted. The 17.5 landed at 2.7500 and Benton:
*"exactly 1/32 too far in"* - which puts it at 2.7812, the figure his hand assembly had all
along and the one the last entry flagged as the test of whether one number was enough. It was
not. `IEP_ROOM_PROUD` is now `{ :vent => 0.125, :panel => 0.09375 }`, keyed on the part name
(`VNT` / `NV` against everything else). The 2.375-thick vent family stands 1/8 proud of the
band's room face, the 2.0625-thick panel family 3/32. Both measured, neither derived.

Benton also reports the E and W walls are still well off. Those are a single 41.5 between two
corners at yaws 0 and 90 - the two the N wall cannot exercise - and no measurement of them
exists yet. Asked for one.

### Done - inner panels stand 1/8 proud of the band's room face (v1.6.11)

Fourth probe. **Every along-wall prediction from the last entry hit to four places**: corners
0.0000 and 65.1250, vent 2.3831, seal 41.1250, 17.5 at 50.4999. The direct corner transform
and the box-centring are both right.

What was left is across the wall, and it is the two Benton called out: *"the [vent] needs to
push out 1/16"* - probe y0 2.6875 against his 2.7500 - and *"the 17.5 needs to push inwards
1/16~, not exact"* - 2.8281 against his 2.7812.

`place()` centres a slab-less box in its 2.0 band, and these boxes are not symmetric about
the panel: `ENH 41.5VNT` is 2.375 thick with 0.125 of trim on the room side and 0.25 behind.
**One rule - the box's room face sits 1/8 into the room past the band's room face** - lands
the vent at 2.7500 exactly and the 17.5 at 2.7500 against his approximate 2.7812. `IEP_ROOM_PROUD
= 0.125`, applied only to inner panels whose slab was not found, and applied AFTER the door
and seal half-turns because a turn about the polygon centre swaps which box face is the room
face. The door has a slab and is untouched.

Prediction for the next probe: vent y0 2.7500, 17.5 y0 2.7500, everything else unchanged. If
the 17.5 wants 2.7812 rather than 2.7500 the rule is per-family, not one number, and that is
the next measurement to take.

### Done - inner corners placed directly, trimmed boxes centred (v1.6.10)

Third probe of the same wall. The seal fix landed exactly (y0 2.8750 = the hand assembly).
Two residuals were left, and this round takes both because the probe tells them apart - the
corner shows on the corner rows, the vent on its own row.

**Inner corners are now placed with no heuristic at all.** `corner_yaw` aims the L's mass at
the booth middle and the IEP quarter turn went on top of that; on the probed 4872 E each
corner still sat 0.25 outboard on one axis. The cause was underneath both: the slab search
finds a 4.875 leg inside the 5.375 part and `place()` centred the LEG in the slot, so the part
was a quarter inch off its own footprint before any rotation happened. `ENH CornerSeamSeal`
is authored AS the SW corner - its box is 1.7500..7.1250 on both axes, which is exactly the SW
polygon in booth coordinates - so SW is the identity and SE / NE / NW are 90 / 180 / 270 about
the polygon's centre. The box is square, so the turn keeps it on its footprint. Those yaws are
the ones the hand assembly left in place (NW 270, NE 180). `IEP_CORNER_YAW` is deleted.

**A bounding box wider than its slot is centred, not flushed.** `ENH 41.5VNT` measures
41.7337 on a 41.5 slot with no findable slab; flushing the BOX to the corner put the PANEL
0.1169 short. The hand assembly has the panel edge on the slot edge, so the trim is symmetric
and centring lands it. Anything whose box measures its slot flushes exactly as before.

Prediction for the next probe, so it can be checked without me: corners at x0 0.0000 / y0
0.0000 and x0 65.1250, vent at x0 2.3831, seal at 41.1250 / 2.8750 - the hand assembly to
four places. If the corners are on their footprint but turned wrong, the part is not authored
as the SW corner and the yaw table shifts by one quarter; that is a four-number change.

### Done - the inner seal plate laps outboard, not into the room (v1.6.9)

Second measurement of the same N wall, this time comparing the BUILD against the hand
assembly part by part in both axes. The 2.5 corner error is gone. Three residuals remain and
each has a cause rather than a fudge:

| part | dx | dy | cause |
|---|---|---|---|
| N-seal0i | 0.0000 | **-0.5000** | the plate was lapping the wrong face |
| N0i vent | +0.1169 | -0.0625 | bounding box aligned to the slot instead of the panel |
| corner seals | +0.2500 on one axis each | | the corner rotation, still open |

**The seal is fixed and it was a sign, not a guess.** Benton's wall has the seal spanning
booth y **45.75 to 48.25** while the panel spans 45.75 to 47.75 - so the seal starts flush
with the room face and finishes half an inch PAST the panel's back, out into the gap toward
the Standard shell. It was being drawn 45.25 to 47.75, lapping half an inch into the room.
The generated N seal now reads 45.7500..48.2500, which is the measurement exactly. All 126
inner seals across the 25 Enhanced booths check out; the Standard layouts are untouched.

**Worth recording: the first validation of that fix FAILED, and the check was wrong, not the
data.** The expected span had been written as (H-6.75, H-4.25) - the old inboard position -
so 63 of 126 seals were reported off while the S and W ones, whose formula happened to be
right, passed. A check that disagrees with a measurement you trust is a check to re-read
first.

#### Still open, with the numbers

**The vent sits 0.1169 too far along the wall.** `ENH 41.5VNT`'s bounding box is 41.7337
against a 41.5 panel, 0.1169 proud each side, and the placement puts the BOX at the slot edge
where the hand assembly puts the PANEL there. `wall_slab` cannot find the panel inside an ENH
part, so there is nothing to align to today. Centring the box in the slot would land it right
whenever the trim is symmetric, which it is on this part.

**Each corner seal is 0.25 outboard on one of its two axes** - NW in y, NE in x, both away from
the room - while the other axis is exact. The polygons are right; `corner_yaw`'s aim-at-the-
middle heuristic plus the added quarter turn is not landing the L on its own footprint. The
real fix is to stop guessing the yaw: the part is authored AS the SW corner, its L corner at
(1.75, 1.75) opening toward +x +y, so the four corners want a deterministic 0 / 90 / 180 / 270
and a direct transform rather than a heuristic. Written up, not written - one change per round
while there is a measurement to check against.

### Done - the corner seal was 2.5 in into the room, and a measurement settled it (v1.6.8)

Four rounds of nudging constants off screenshots got nowhere. Benton exploded the built booth,
deleted everything but one N wall, moved the five parts into their correct positions by hand
and ran `probe-placement.rb`. That one measurement ended it.

**What his wall says, and every one of these closes exactly:**

* the vent panel butts the mid-wall seal's 6.5 stem to **0.0000**
* the 17.5 panel leaves the other side of that stem to **0.0000**
* the panel run measures **65.5001** - the inner interior width
* the run starts **2.5000** inside one corner seal and ends **2.4999** inside the other

Put the run back where it is known to be, 4.25 to 69.75 in booth coordinates, and the corner
seal lands at **1.7500 .. 7.1250**. That is EXACTLY where `ENH CornerSeamSeal` sits in the
component library's own authored frame, read off `_enhanced-probe.tsv` weeks ago and never
used. Two completely independent sources, the same two numbers.

**The corner seal was being drawn at 4.25** - its outer face on the room face, a full 2.5 in
into the room, standing in front of the panels instead of lapping behind them. That single
error is what "the corners are wildly off" and "the walls should be touching each other" both
were. 1.75 also falls straight out of the build-up: the panel's back face is at 2.25 and the
seal stands 0.5 proud of it.

**The panels and the mid-wall seal were already right.** Nothing else moved.

**Verified part by part against the hand assembly**, not asserted: regenerated the layout,
converted every inner N-wall part into the same datum his probe used, and compared. All five
match to better than two thousandths of an inch, the vent compared panel-to-panel after
subtracting its 0.1169 bounding-box overshoot per side. All 25 Enhanced booths still close on
the 6.5 rule and all 100 inner corner seals now sit at 1.75 from their booth face. The 25
Standard layouts are unchanged.

**The lesson is about method, not geometry.** A screenshot shows that something is wrong and
never by how much; I changed constants four times off pictures and it did not converge once.
Fifteen minutes of Benton's time with a probe produced a number that closed to the
ten-thousandth on the first try. When a thing can be measured, measure it - and build the tool
that measures it before the fourth guess, not after.

Also worth recording, because it cost a round: the first probe he ran WAS already the correct
hand assembly, and it was read as "the numbers are identical, nothing moved". They were
identical to the previous run because he had assembled it before the first probe too. The tell
was there to be seen - my polygons could not have produced a panel starting 2.3831 into a
corner seal - and it was not looked for.

### Done - build one shell at a time, and the inner door turns (v1.6.5)

Benton, off the build: *"wall placement and mid wall seam seal and corners are still wildly
off. Start by just placing the IEP wall sections, so add a filter or something for this until
we get this cleaned up."* Right call - an Enhanced booth is 24 parts in two interleaved
shells, and looking at a wrong inner corner through a complete outer shell is most of the
difficulty.

**A Shell row on the dialog: Both / Inner (IEP) only / Outer (Standard) only.** Inner places
the IEP parts and nothing else - no outer walls, no deck - so what is left in the model is
exactly the thing being fixed. It defaults to Both and `build_booth` defaults `cfg['shell']`
to `'all'`, so `booth-from-link` and every existing caller behave exactly as before.

The dialog is now FOUR rows. `UI.inputbox` matches its three arrays by position and says
nothing when they disagree - it reads the wrong field into the wrong variable - so the count
was checked by parsing the call back out of the file: 5, 5, 5.

**`IEP_DOOR_YAW = 180.0`.** The dry run had already flagged it: `S0i ENH Right41.5Door` came
out `Y- OUT` where the outer `S0 Right46Door` of the same hand came out `Y+ IN`, and every
other inner part came out IN. Benton confirmed it off the build. **A half turn, not a mirror** -
the `REVERSED` list would also flip it, but a mirror turns a right-hand door into a left-hand
one, and the hand is a customer choice that arrives from the quote.

#### The assembly rule Benton gave, which is what the walls have to satisfy

> Corner seam seal first. Then 17.5" IEP wall, right into its corner so it's flush. Then
> mid wall seam seal - this will go snugly and flush into the bottom of the "T". 6.5" later
> (since that's the dimension of the bottom of the mid wall seam seal "T"), put the 41.5"
> wall. It will fit snugly in the same spot. Then corner.

**The 6.5 is confirmed from the part itself** - it is the bottom of the T - which is the third
independent confirmation of the inner run rule, after the BOM closure on all 25 models and the
12.25 plate less the Standard 2.875 flange each side.

What this says that the current data does not is about **flush**: each piece butts hard into
the one before it, and the wall panel seats into the T's bottom rather than merely stopping
2.25 in short of it. The generated polygons put the panels in the right places to a hundredth;
what is off is placement against those polygons.

#### Held back deliberately

The IEP deck pass is written and NOT committed. Benton has now given its rule - the floor is a
5/16 mat under the standard floor, the ceiling is a tray facing down that sits on top of the
standard ceiling and engulfs it, and both are placed off the standard deck's own placed bounds
rather than a z constant - but adding untested deck code while the walls are being isolated is
the opposite of what the filter is for. It goes in once the inner walls are clean.

### Done - four fixes off the first real Enhanced build (v1.6.4)

Benton built a 4872 E and sent screenshots. Four things, one of which is a regression I
introduced and would not have found without the picture.

**THE FLOOR FLIP IS THE ONE WORTH READING.** `wr-deck.rb` answers two questions by walking
`spec[:parts]` - which end of the booth the big wall run sits at (`layout_big_on_low?`) and
where the short wall's midpoint is (`short_wall_mid`). Nothing in wr-deck changed. **The list
it reads got longer.** An Enhanced layout carries the twelve IEP inner panels as well as the
twelve outer ones, at different lengths and different positions, and they changed both
answers - so the deck came in mirrored. The deck belongs to the outer shell, so it now walks
`outer_parts(spec)`, which rejects `:sh=>'in'`. `:sh` is `'out'` on every part of a Standard
layout, so the Standard deck is bit-for-bit untouched.

**The lesson, and it generalises:** adding rows to a shared data structure is not additive.
Anything downstream that *aggregates* over that structure silently changes its answer.
`dimension-booth.rb` walks the same list to find the vent walls; it de-duplicates by wall
letter so the answer happens to be the same, and it is filtered anyway, because a label
derived from both shells is a label waiting to disagree with itself.

**Inner seam seals are not the Standard ones turned around.** A Standard seal wraps a CONVEX
corner from outside the booth; an IEP seal sits in a CONCAVE corner and is fitted from inside
the room. `corner_yaw` aims the L at the booth's middle, which is right outside and a quarter
turn short inside. Two named constants, applied to inner parts only and printed in the build
report: `IEP_CORNER_YAW = 90.0` (Benton chose counter-clockwise from a plan sketch) and
`IEP_SEAL_YAW = 180.0` for the mid-wall seal end for end. One number each, deliberately - if a
build shows them still off, change the number rather than reasoning about part origins.

**`IEP_WALL_LIFT` is 0.0 now, and the old reasoning is dead.** It was 0.3125, taken from the
measured thickness of every ENH floor part on the reading that the inner wall stands on that
sheet. Benton: the ENH floor part is *"the 5/16 black rubber mat that sits UNDER the standard
floor."* The inner wall does not stand on it, so the number had no reason left. 0.0 puts the
inner wall's underside flush with the outer wall's and drops the whole 1.5 at the top. Still a
guess - but one that can be checked by eye, which 0.3125 could not.

#### Still open, and blocked on one number

**The IEP floor and ceiling are still not placed.** The floor is now understood: `ENH <n>FL` is
a 5/16 rubber mat under the standard floor, and the ENH parts measure 48 x 72 on a 4872 whose
exterior is 74 x 50 - an inch inset all round, which fits a mat under the deck. **The ceiling
datum is what is missing.** `ENH 4872CL` measures 1.75 thick and 50 x 74, exactly the booth
exterior, but nothing says where its underside sits relative to the standard ceiling. Not
inventing it.

**The corner gap may already be fixed.** Benton's close-up shows an open inner corner, and the
inner corner polygons butt exactly in plan - the N wall's run starts at x = 4.25, which is the
W wall's panel room face. A corner seal rotated a quarter turn away leaves exactly that
appearance. If the 90 degree fix closes it, the two reports were one bug.

### Done - the first Enhanced booth resolved 24 parts, and the width bug it exposed (v1.6.3)

`MDL 4872 E` ran end to end in SketchUp for the first time. **24 parts, every name resolved,
zero missing components** - 12 Standard outer, 12 IEP inner, the ENH door and vent and seals
all found on `P:`. The two-shell layout and the double translation are sound.

The dry run also showed a real defect, and it is a good one to keep on the record because the
symptom was invisible on three walls out of four.

**`wall_slab` finds no panel inside most ENH parts.** An IEP panel is 4 to 15 nested
containers with a fill / shell / trim / void band profile, and the search does not recognise
it. The fallback then used the whole definition's bounding box as the part's width - which on
an ENH part includes trim and void standing proud of the panel. Measured on this run:
**41.625 against a 41.500 slot** on `ENH 41.5PanelSolid`, **41.734** on `ENH 41.5VNT`.

An eighth to a quarter inch of packaging, and here is what it did:

* On the **N wall**, which has a joint, the re-walk landed 0.234 long, failed the 0.15 closure
  test, and the wall was left alone with a warning. Loud and harmless.
* On the **E and W walls, which have no joint, there was nothing to fail.** The re-walk landed
  0.125 long - inside the closure tolerance - so it passed and **silently stretched both inner
  walls by an eighth of an inch.** `rebalanced E0i ... 4.250..45.875 (slot was 4.250..45.750)`.

**The fix is a rule about evidence, not a tolerance bump.** Without a slab, a part's width is
an *estimate*, and an estimate must not be allowed to move a wall. The substitution
`rebalance_walls` exists to catch - a wide-access door - changes a panel by **three inches or
more**; ENH trim noise is a quarter inch. They are nowhere near each other, so with no slab a
discrepancy under `SLAB_NOISE` (1.0 in) is read as measurement noise and the slot is trusted.
The FIT column still prints the raw difference, so nothing is hidden - it just stops moving
geometry.

**Mutation-checked against the real numbers.** `scripts/rbtest.py` grew a second case: a
jointless inner wall with a 41.625 bounding box on a 41.500 slot. Put the raw bbox fallback
back and it reproduces `4.250..45.875` exactly - the stretch from the console - and the fix
gives `4.250..45.750`. Both were run. The first case (wide-access door on both shells,
inner run closing only on a 6.5 joint) still passes, so a real substitution still rebalances.

#### Two things the run flagged that are NOT fixed, because they want eyes on a real build

* **The inner door may be back to front.** `S0i ENH Right41.5Door` reported `Y- OUT`, where the
  outer `S0 Right46Door` of the same hand reported `Y+ IN`. Every other inner part reported IN.
  Both were oriented by measured bulk, so the two definitions appear to carry their leaf on
  opposite sides - which would swing the inner door into the wall cavity instead of the room.
  There is already a mechanism for a part authored the other way round, the `REVERSED` list,
  and this is one line in it. **Not added blind:** it was a dry run, nothing was placed, and
  flipping a part that is actually correct is the same class of error in the other direction.
  Build one for real and look at the inner door.
* **The ENH corner seal's drawn leg is 5.375 where the part's own leg is 4.875.** `IEP_CORNER`
  took the bounding box; the slab search reports the leg as 2.250..7.125. Cosmetic - corners
  fit `n/a` and place by `corner_yaw` off their own geometry - but the generated polygon should
  match the part. Regenerating `wr-booth-data.rb` is the whole change.

Unchanged and pre-existing: the outer `46VNT` still reports `floor hangs 0.863`, which is the
Standard vent housing and nothing to do with Enhanced.

### Fixed - the NameError that stopped the first Enhanced build (v1.6.2)

First run of `MDL 4872 E` in SketchUp got all the way through resolution - correct ENH names
on all 12 inner slots, no missing parts - and then died in `rebalance_walls` with
`undefined local variable or method 'inn'`.

**The cause was mine and it is worth recording, because it is a process failure rather than
a coding one.** The edit that keyed `rebalance_walls` on `[wall, shell]` was applied by a
script that asserted its way through four replacements and **aborted on the fourth**, before
writing. Three of them had already printed OK, so the transcript read as though they had
landed. They had not. A separate follow-up edit then added the `inn ? 'inner' : 'outer'`
message on its own - so the file ended up referencing `inn` without ever binding it. The
lesson: **after an aborted edit, read the file back. Do not trust the log of what was
attempted.**

The fix is the change that was meant to land the first time: group by `[w, inner?(p)]`,
destructure it, and take the joint per shell.

#### `scripts/rbtest.py` - and this is the durable part

`rbparse.py` proves a file PARSES. It cannot prove a method RUNS, and Ruby resolves a bare
identifier to a method call when no local of that name is in scope - so an unbound local is
a clean parse and a crash on the first real booth. That is precisely the gap this bug fell
through.

`rbtest.py` boots the same CRuby 3.2 VM out of SketchUp 2024, **lifts the method verbatim
out of the .rb file by text**, drops it into a stub module and executes it. The source is
not copied into the test, so the test cannot drift from the code.

The fixture is one wall of a 4872 E with a wide-access door on both shells - the only
condition under which `rebalance_walls` does anything at all. The inner run closes **only**
on a 6.5 joint (4.25 + 44.5 + 6.5 + 14.5 = 69.75); re-walk it with the Standard 2.0 and it
lands 3.5 in short and bails.

**Mutation-checked, so it is not a test that cannot fail.** Reintroduce either bug and it
reports FAIL - `w, inn = key` -> `w = key[0]` gives back the exact NameError from the
SketchUp console, and hardcoding the joint to 2.0 leaves the inner run short. Both were run.

The VM comes up minimal and lacks a few core methods; `Float#to_f` and `Integer#to_f` are
shimmed in the harness rather than worked around in the fixture, so the method under test
still runs exactly as written.

**This is the first Ruby in this repo that has been executed outside SketchUp.** Only
data-in/data-out methods can go through it - `place`, `load_def` and the deck pass all need
a real model.

### Done - the standalone "Build a booth from real parts" path, same day (v1.6.1)

Benton: *"This should also work for build booth with real components."* It picks the booth
from a dropdown fed by `BOOTHS.keys`, so all 25 Enhanced keys appeared there the moment the
data file was regenerated - but two things behind that dropdown were still Standard-only,
and one of them would have corrupted geometry rather than failing.

**`rebalance_walls` was keyed on the wall, not the wall and the shell.** It groups parts by
the first character of the slot id, so an Enhanced booth's `N0` and `N0i` landed in the same
list. Sorted along the wall the two shells interleave, the re-walk sums both shells' panel
widths into one run, and the joint was a hardcoded 2.0 where an inner joint is 6.5. It only
fires when a part differs from its slot by more than 0.1 in - a wide-access door is the
normal trigger - so a plain Enhanced build would have passed straight over it and a WA
Enhanced build would have rewritten both shells from a nonsense cursor. Now keyed on
`[wall, inner?]`, with the joint taken per shell.

**`ASSIGN` had no Enhanced rows,** so the E/W reversal the 6060/6084/7272/7296 need was
silently skipped on their Enhanced twins. The swap is a property of the layout, not the
variant - the generated data puts the big run on the high half of E and W on both shells -
so those four booths would have had their walls disagreeing with the deck hinges exactly as
the Standard ones once did. Four ` E` rows added, each naming both shells; the inner names
are written out rather than derived, so there is no second copy of the Standard-to-ENH rule
drifting away from the one in `booth-from-link.rb`. Checked: all 8 ASSIGN rows, every slot
id exists in the layout data and every component name exists on `P:`.

**The IEP inner floor and ceiling are still not placed, and the build now says so** on every
Enhanced run rather than leaving a silent hole. `ENH <size>FL` / `ENH <size>CL` exist in the
library; their z datum does not, and guessing it puts a floor through a wall.

### Done - Enhanced is unblocked: the inner shell has a rule, and both shells now build

The blocker at the bottom of yesterday's entry - *"the air gap between the outer and inner
shell is unknown, and no Enhanced layout work can proceed without it"* - is closed. All 25
Enhanced booths are in `scripts/wr-booth-data.rb` for the first time; the file went from 25
layouts to 50 and the skip list is empty.

**The premise that blocked it was wrong, and that is the whole entry if you read one
paragraph.** Every attempt so far treated an Enhanced booth as a Standard booth whose walls
had been swapped for narrower ones. It is not. `base-bom.json` settles it outright:
`MDL 4872 E` ships the entire Standard wall set (C101/C102/C111/C114) **and** a full IEP
inner set (K101/K102/K112/K116), with IEP corner and mid-wall seam seals (N01/O01) beside
the Standard ones (D01/D02). **An Enhanced booth is two shells.** The 4.5 in every E
interior was never a per-panel shrink - it is one whole inner shell standing 2.25 in inboard
of the Standard interior face on all four sides.

#### The inner run rule

    inner run = sum(IEP panel widths) + 6.5" per joint

6.5, where Standard is 2. Derived twice, independently, and the two agree:

* **All 25 Enhanced BOMs close on it exactly.** Sum the IEP walls a model ships and it equals
  that model's E interior perimeter less 6.5 per joint. 25 of 25, no residue (observed,
  computed from `base-bom.json` + `components-master.json` + `booth-layouts.json`).
* **ENH MidWallSeamSeal measures 12.25 across the wall** against the Standard seal's 7.75
  (observed, `_enhanced-probe.tsv` / `_component-probe.tsv`). The Standard plate laps 2.875
  past its 2 in stem on each side; 12.25 - 2 x 2.875 = **6.5** - the same flange on a wider
  stem.

**This also dissolves the contradiction recorded yesterday** ("a constant gap and a
one-for-one -4.5 substitution are mutually exclusive"). They are not, because the seal grew
too: a run of n panels shrinks by 4.5n - 4.5(n-1) = **4.5, for every n**. The wider stem
absorbs the excess exactly. Checked directly: for all 25 models, on every wall, the widths
that `booth-from-link`'s -4.5 name rule composes are **identical** to the widths solved
independently from the BOM. Zero disagreements. The link path and the layout data cannot
drift apart.

#### Which panel goes where is solved, not guessed

The BOM fixes the multiset of IEP widths a model ships. `solve_inner` enumerates the
partitions of that multiset across the four walls and keeps only those satisfying every
wall's run equation. **For all 25 models exactly one partition survives** - no ties, no
fallback, no scaling. Within a wall the widest inner panel takes the widest Standard slot,
which is what keeps the inner door and vent on the same wall as the outer ones.

#### What changed

* `scripts/gen-booth.py` - the outer shell of an E booth now reads the **S** variant's
  thickness and interior. Feeding E's own 4.25 wall and 65.5 run into a solver holding
  Standard 46/22/16 stock is precisely what produced "panel lengths unresolved" on all 25.
  Adds `IEP_*` constants, `iep_widths`, `solve_inner`, `inner_parts`.
* `scripts/wr-booth-data.rb` - regenerated. Every part now carries `:sh`, `out` or `in`; an
  E key also carries `:eiw`/`:eih` (the room inside the inner shell) and `:phi` (79.5).
  **The 25 Standard layouts are byte-identical to the previous file** apart from the added
  `:sh` tag - verified by parsing both and diffing entry by entry.
* `scripts/booth-from-link.rb` - **the real correction on the customer path.** It was
  translating an Enhanced link into ENH parts and handing them to the OUTER slots, which
  builds a single shell of inner parts: a booth that exists in no catalogue. Every slot is
  now translated twice, Standard for `<slot>` and ENH for `<slot>i`.
* `scripts/build-booth-components.rb` - switches component family on `:sh` alone, refuses by
  name if an inner slot is ever handed a Standard part, and takes the height nominal **per
  part** (79.5/89.5 inner, 81/91 outer) instead of one per booth. `classify` takes the
  expected height as an argument; it was a hardcoded 81/91, and a 79.5 part passed the +/-6
  test while every figure leaning on `:want` came out 1.5 wrong.
* `scripts/build-booth.rb` - the block-out extrudes the inner shell at its own height.
* `scripts/wr_tools/VERSION` -> **1.6.0**.

#### Replayed, in full

Every catalogue Enhanced slot, x5 option sets, x HX and non-HX, x both shells: **4,520
component-name lookups, 0 unresolved** against the real `P:` folder. Plus a geometry pass
over the generated data: all 25 E booths have their inner panels in the 2.25-4.25 depth
band, every wall run closes on the 6.5 rule, and every inner panel maps to a file that
exists. All 49 Ruby files pass `rbparse.py`.

#### The one number still assumed - and it wants a one-line answer

**How the 1.5 an Enhanced wall gives up splits between the floor lip and the ceiling lip is
still not measured.** It lives in exactly one named constant, `IEP_WALL_LIFT` in
`build-booth-components.rb` (mirrored as `IEP_LIFT` in `build-booth.rb`), it is printed in
the build report, and it currently reads **0.3125** - the measured thickness of every ENH
floor part in the library, on the reading that the inner wall stands on that sheet. That is
a derivation from a related part, **not a dimensioned detail**. If the real lip is something
else, it is a two-file, one-value change.

Also still open, and unrelated to the above: **four ENH panel definitions measure 1.125
thick where their siblings measure 2.0625** - `ENH 11.5PanelSolid`, `ENH 14.5Panel`,
`ENH 23.5Panel`, `ENH 26.5Panel`. Their band profiles are missing the 0.9375 outboard layer
every other ENH panel has (observed, `_enhanced-probe.tsv`). They share the inboard face at
4.3125 with the rest, so placement still lands them correctly, but they look under-built.
Worth a look in SketchUp before a render goes out on a 35.5-module booth.

**Nothing here has been run in SketchUp.** The Ruby is syntax-checked with `rbparse.py` and
nothing more; every geometry and BOM figure above is computed from the data files and the
library probe on this machine. The first thing to do is open a booth-builder link for an
Enhanced model and press build.

## 2026-08-24

### Done — TMG pottery stamp, 14mm and 16mm STLs cut from the design artifact

Benton asked for "the STL for the 3d printed 14mm diameter stamp for pottery" and pointed
at artifact `f1b6983f` ("TMG Pottery Stamp"). **There was no STL** — not in the repo, not
in the full git history across all branches. The artifact is a design-review page: it
carries the complete parametric model in JavaScript but has no export, no download button,
no facet writer. So the geometry had to be reproduced and written out.

**The generator reads the artifact rather than reimplementing it.** `scripts/tmg-stamp-stl.js`
extracts `LOGO`, `PROF`, `Y_FACE`, `RELIEF`, `BASE_D` and evaluates the page's own
`ringArea()` and `faceQuads()` verbatim. Nothing is retyped. That is the whole reason it is
Node and not Python like `spray-guide-stl.py` and `pendant-jig-stl.py` — the design data IS
JavaScript, and there are thousands of traced coordinates where a transcription typo would
be silent. House style lost to transcription risk, deliberately; the file otherwise matches
the Python two (same docstring shape, provenance comments, refuse-to-write self-audit).

Solid = lathe of `PROF` (256 segments) about Z, face at z=15.5 tessellated as disc-minus-
artwork, relief extruded 1.2mm to z=16.7 with side walls on outer and hole rings. Handle
down, wide base flat on z=0, which is the bed.

**Mirroring was the one irreversible decision.** The relief is mirrored, `X = -u`, so the
impression pressed into clay reads TMG the right way round. Three independent sources in
the artifact agree: `paintBoth()` passes `mirror=true` for the face and `false` for the
clay; `buildMesh()` maps artwork through `toXZ = (u,v) => [-u,-v]`, which under the page's
face camera negates x; and the rendered check shows a reversed G on the face, correct in
the impression. Check images are in `.forge/builder/` for both sizes — **look at one before
committing a print**, a backwards maker's mark is unfixable after the fact.

**Two defects in the artifact's own tessellation had to be repaired** to make it printable,
and both are worth knowing if that page is ever used as a mesh source again:

- `faceQuads` conserves area but not topology. At every band boundary where the crossing
  set changes, the quad below spans a horizontal edge the quads above split in two — 195
  unpaired directed edges at 14mm. Fixed by re-fanning affected triangles from their own
  centroid (an apex corner gives collinear slivers). The surface does not move, only its
  subdivision.
- Lathe ring y-values come out of `Math.sin`, so mirror-image angles land ~1e-16 apart.
  `faceQuads` skips sub-1e-7 bands and orphans those vertices — 102 collisions. Fixed by
  clustering y within a micron, preferring an artwork y so the mark's coordinates never move.

**Verified against the written files, not the in-memory mesh.** 14mm: 26 582 tris,
1 329 184 bytes = 84 + 50 x 26 582, bbox 16.000 x 16.000 x 16.700, 79 746 directed edges,
zero used twice, zero without a reverse, zero degenerate, volume 2262.79 mm3 against the
artifact's own 2263.01 (-0.010%). Re-read at float32 to confirm no vertex collapse. Two
runs byte-identical, md5 `b104323dcdae4339ddd293f07e4c4432`. 16mm: 28 936 tris, 86 808
edges, same zero/zero/zero, volume 3370.79 against 3371.12 (-0.010%).

**"16mm" is the mark, and the whole stamp scales with it** — k=1.1429, so the body comes out
18.29 across the head and 19.09 tall, not 16. Worth saying out loud because the filename
implies otherwise. The upside is line weight: dilation drops from 0.0835mm per side at 14mm
to 0.0522mm at 16mm, so the mark is closer to Terry's drawing. The artifact says 22mm
removes the fattening entirely.

`--size 18` and `--size 22` work off the same code and come out manifold at the identical
-0.010% volume error — structural evidence the pipeline is right rather than accidentally
passing at one size. Only 14 and 16 were written.

**Not checked by anyone: how these actually print.** No printer, no slicer on this machine.
Nothing about supports, overhangs, or the artifact's reported 38 degree steepest overhang
has been recomputed. The manifold verdict is our own audit code run twice on two
representations — strong, but not a third-party opinion from PrusaSlicer or Meshmixer.

`scripts/wr_tools/VERSION` deliberately NOT bumped. CLAUDE.md says any change under
`scripts/` warrants it, but precedent is against it — 38dca08 and 30dc5bc both added and
changed `scripts/spray-guide-stl.py` without a bump — and a Node STL generator never appears
on the panel, so bumping would make the update banner lie in the other direction. Flagged
for Benton; reversible in one commit if he wants the letter of the rule.

`.forge/GOAL.md` was still carrying the finished render-prep toolkit mission (shipped,
306a467 / 66a6384). Replaced with the stamp mission, old one summarized under History.

### Next steps

1. Load `exports/tmg-stamp-14mm.stl` in a slicer and confirm it reads as watertight there —
   that is the one check no tool on this machine can do.
2. Look at `.forge/builder/tmg-stamp-14mm-check.png` and confirm the mirroring is what you
   want before anything goes on a bed.
3. Print one at each size before printing four, and compare the mark against Terry's logo.
   Fit-tested beats measured; if the lines come out too fine at 14mm, 18 or 22 are one
   command away: `node scripts/tmg-stamp-stl.js --size 22 --svg`.

### Open decisions

- Whether to bump `scripts/wr_tools/VERSION` for non-plugin scripts under `scripts/`. Current
  call follows precedent and does not bump. CLAUDE.md's letter says otherwise.
- Whether 18mm and 22mm files are wanted in `exports/`. Both generate clean; neither written.


### Done — Enhanced booth on the share-link path, and the exporter stops guessing

Benton authored and loaded the `ENH` component library into
`P:\Sketchup\NewMasterComponentList`, which unblocked work that had been stalled on missing
parts. Two threads ran together all evening: teaching the customer path to build Enhanced, and
fixing an exporter that had been writing **wrong geometry into right filenames**. The second
thread is the one with the durable lesson in it.

**THE LESSON, because it will save someone a night: a heuristic that infers which component a
scene means was wrong twice and corrupted files both times. Naming the thing explicitly and
matching on the name was right immediately.** Prefer the explicit link over the clever
inference. That is the whole entry if you only read one paragraph of it.

#### The exporter resolved scenes by geometry, and geometry was hopeless on this model

`scripts/save-scene-components.rb` picked a scene's subject by taking the top-level instance
whose bounding-box centre sat nearest `cam.target`. A 112-scene dry run showed what that
actually bought: every scene resolving by distance alone, deck scenes landing 137–236 in from
the component they were assigned, and **13 scenes colliding** onto a component another scene had
already claimed — mostly `CL`/`FL` twins stacked in Z, whose centres are near-equidistant from a
single target point. The damage had already shipped: `ENH 10242FL CTR` held ceiling geometry, and
the `4896` pair held `4872` geometry.

**The raycast rewrite FAILED, and it stays in the record so nobody re-explores it.** v1.5.5
(`8ea6a7d`) cast a ray from `cam.eye` along the view direction through `Sketchup::Model#raytest`
and took the first top-level instance in the returned path — sound reasoning, since two parts
stacked in Z cannot both be the first face a ray strikes. Over the same 112 scenes it gave 45 ray
hits, 67 fallbacks and **14 collisions — one worse than the 13 it replaced.** The run's own
numbers explain why: every ray hit reports ~21,500 in, because these scenes are **parallel
projection with the eye effectively at infinity**. At an 1,800-foot lever arm a fractional angular
error becomes inches of positional error, and these parts sit inches apart. Geometry cannot be
made reliable at that distance — and better geometry would not have helped anyway, because 15 of
the 112 wanted definitions were not in the model at all.

What worked was abandoning geometry. v1.5.6 (`72b84ab`) resolves by **exact definition-name
match** — a name index built once per run, multiple instances of a name reported and picked
deterministically rather than silently first-in-order, and a `#N` suffix **refused by name**,
because a uniquified duplicate is precisely how a wrong part gets a right filename. Unmatched
scenes are reported as MODEL GAP and **skipped rather than written**. The raycast and its
fallback tiers survive verbatim as `geometry_subject_for` and run only when no component carries
the name, so a model whose definitions are not named after its scenes still resolves as it always
did.

That left 17 scenes with no matching definition, so Benton got a tool for it:
`scripts/name-selection-after-scene.rb` (v1.5.7, `78dc2ff`) names the selected definition after
the active scene, one click at a time. **It reads the name back after assignment and aborts if
the model hands back a `#n` suffix** — `ComponentDefinition#name=` uniquifies silently instead of
raising, so trusting the setter is how you end up with `Foo#2` and never know. No bulk rename, and
no inference about which component belongs to which scene; that inference is the thing that had
just failed twice.

**Final state, measured** (observed, from `P:\Sketchup\NewMasterComponentList\_enhanced-probe.tsv`,
re-counted directly for this entry): **112 of 112 parts single-shell**, every `FL` part at
**0.3125** (23 of them, no exceptions), names matching components one-for-one, **zero collisions,
zero model gaps.** Benton ran the probe and both exporter passes himself in SketchUp.

#### Enhanced on the share-link path

`scripts/booth-from-link.rb` was resolving an Enhanced link to **Standard** component names and
saying nothing about it. `component_for` never received the payload's variant flag, so every
branch composed a Standard name — names that all exist and all load. Nothing errored. **The
silence was the defect.** It now maps Standard widths to Standard − 4.5, prefixes `ENH ` (with the
space), checks every composed name against the real folder *before* building, and **refuses by
name** rather than substituting. `ENH_MISSING_ABORTS = true`. Aborting is not paranoia:
`build_booth` fills any unassigned slot via `guess_component`, which composes **Standard** names —
so "leave it out" silently becomes "put a Standard part there" one function later. Vanishing was
never on the menu.

**A live Standard bug went out in the same commit** (`1c84103`), and that one was hurting real
customers: `46VntCP.skp` has **no underscore**, so the composed `46VNT_CP` never resolved and
casters-only 46-inch vents failed. Confirmed on disk — the CP family is inconsistently cased and
separated (`46VntCP`, `46Vnt_EFS_CP`, `46vnt_VSS_CP`). Name matching now ignores case *and*
separators; safe here, checked: all 353 `.skp` files still produce 353 distinct normalised keys.

`scripts/probe-enhanced.rb` is new, and it settled the gating question. **`ENH` parts are single
shells, not the combined exterior+interior+foam parts this DEVLOG had planned for.** They are
internally nested — 4 to 15 containers each, with a `fill / shell / trim / void` band profile
through the thickness — but that is one wall's internal construction, not two shells. **So the
inner/outer gap lives in the LAYOUT, not in the part**, and the assembler has to place both shells
and solve the offset itself. One piece of good news out of it: `wall_slab`'s single-tall-slab
premise holds, because every part really does contain exactly one slab.

#### Two corrections to the earlier record

**`24.4375` IS NOT THE GAP.** An intermediate probe run reported 5 parts with 2 shells and a
24.4375 gap, and the probe's own output announced it as *"the number the Enhanced build has been
waiting for."* It was wrong. Those 5 files were the corrupted ones, each holding a whole booth
assembly — the exporter bug above, measured back as if it were a design fact. The current TSV
contains no `24.4375` anywhere and no part with 2 shells. **The real inner/outer air gap remains
unknown.**

**The `83.0000` / `84.3125` panel heights carried elsewhere in this DEVLOG are wrong.**
Measurement says **Standard 81.0000 / 91.0000 `HX`** and **Enhanced 79.5000 / 89.5000 `HX`** —
Enhanced is 1.5000 SHORTER. Neither 83.0000 nor 84.3125 appears anywhere in the 182-part Standard
measurement; both counts are literally zero (observed, `_component-probe.tsv`). `84.3125` shows up
only on `ENH 127LPCL` / `127LPFL`, which are a different animal. Recorded here as a correction
rather than edited into the old entry, so the mistake stays findable.

The 1.5 is not a discrepancy to reconcile — Benton ruled where it goes: **Enhanced walls sit on
the floor panel lip and squeeze under the ceiling lip.** An Enhanced wall is *captured between the
two lips*, not stood on the deck surface the way a Standard wall is. **Do not reuse the Standard
wall's z-datum for Enhanced** — it drops every Enhanced wall 1.5 too low, and it will look almost
right, which is the dangerous kind of wrong.

#### Benton's rulings, which no measurement can recover

- **Enhanced vents need no `_VSS`/`_EFS`/`_CP` variants.** *"The 35.5 VNT wall fits them all for
  the inner walls."* The 28 composed combination files earlier listed as missing are **not to be
  authored**, and the code must stop appending those suffixes on the Enhanced path.
- **Side vents are front-view art only**, not build components. The `LeftSideVent` /
  `RightSideVent` families are to be ignored by every booth-building script. No builder has ever
  referenced them.
- **Ramp doors are Standard-only.** *"Ramp only attached to standard."* No `ENH …WADoorWithRamp` is
  to be authored, and `component_for` ignores `o[:ramp]` on the Enhanced path. That removed 32
  Enhanced coverage misses outright — Standard and Enhanced now both replay at **928/960**,
  identical, and the only remaining miss on either path is the deliberate skip below.
- **The 7-inch wall is skipped deliberately.** It is *"actually a modified mid wall seam seal but I
  don't have that item created… it's kinda rare."* No 2.5" Enhanced panel is to be created; a booth
  needing it aborts by name, which is the correct outcome for a rare unbuilt part.
- **Abort-on-missing is the right default.** `ENH_MISSING_ABORTS` stays true.

Plugin is at **VERSION 1.5.7**. Getting `wr_tools/` changes onto another machine still takes all
three steps — `git pull`, `python scripts/install-plugin.py`, restart SketchUp. The tool scripts in
`scripts/` are read live from a repo checkout, so a `git pull` alone covers those.

**Provenance, precisely.** Every geometry figure above is **observed**, from `_enhanced-probe.tsv`
and `_component-probe.tsv`, re-counted directly for this entry. The scripts were **syntax-checked
only** with `scripts/rbparse.py` and never executed outside SketchUp — *except* the probe and both
exporter passes, which Benton ran himself. Nothing here is called "verified" that was only parsed.

### Still blocked — the Enhanced layout, and it gates everything downstream

**The air gap between the outer and inner shell is unknown, and no Enhanced layout work can
proceed without it.** The −4.5 rule names the right parts but cannot *locate* the inner shell.
Measured from the 25 Standard layouts (`.forge/builder/analyse-layouts.py`): panel counts per wall
run **1 to 5**, and differ between the two axes of the same booth. A one-for-one −4.5 substitution
therefore shrinks a wall by 4.5n and forces a gap of 2.25n per side — **2.25 to 11.25 in across the
set, and different on each axis of one booth.** A constant gap needs each panel to narrow by
(2+2G)/n, which cannot be 4.5 for every n. **A constant gap and a one-for-one −4.5 substitution are
mutually exclusive.** Independently, a concentric inner shell puts 10 of 25 inner doors partly
outside their outer door opening.

Also open:

- **How the 1.5 splits between floor lip and ceiling lip is unmeasured.** The total is derived from
  wall heights (81.0000 − 79.5000), not from deck geometry. Measure it off the `CL` and `FL` parts
  before writing a datum constant — **do not assume 0.75/0.75.**
- **`scripts/angled-component-art.rb` still carries the old nearest-to-target resolution** (its
  own header, line 24: *"the scene's CAMERA TARGET → nearest component instance = the subject"*).
  That is the exact rule that mixed up 13 scenes in the exporter, so the PNG component art may
  carry the same mix-ups. Unchecked.
- **The 8 `STDSS` ceiling/floor seam seals are the only components still genuinely absent.** The
  ramp doors, the 2.5" panel and the vent option variants were all cancelled by ruling — the
  authoring queue is down from 74 to 8.


## 2026-08-21 (Rev D)

### Done — spray guide feet raised to 19.50, STL cut

Benton: "the feet are too low, they need to be 19.5mm deep total." One constant.
`FOOT_Z` 12.0 -> 19.5 in `scripts/spray-guide-stl.py`, sheet regenerated, file cut to
`exports/spray-guide-revD.stl`.

**The reading was the only real decision.** "Deep total" is ambiguous on its face, but
"too LOW" settles it: it is the vertical extent, and "total" means from the underside
rather than what stands proud. The other reading — front-to-back depth — is already
20.10, and a 0.60 change is not something anyone describes as too low. The sheet states
that reasoning at the top rather than burying the assumption, and the section dimensions
the foot twice, 19.50 total and 14.50 proud, so neither reading can be misread off it.

Plate is 5.00, so the foot stands 14.50 proud and 19.50 is now the whole part's height.
**The foot is now the tallest feature**, where the step used to be.

Printability is untouched, and that is worth stating because it is mildly
counter-intuitive: taller feet are prismatic columns standing ON the bed, not features
hanging off it. Flat face down, zero overhang, no supports, no brim, bed contact
unchanged at 8 149 mm2. (That figure corrects the 8 175 quoted at Rev C — plate underside
7 104 plus two 522.6 pads. Nothing depended on the old number.)

**Verified against the written file, not the in-memory mesh:** 200 triangles, 10 084 bytes
= 84 + 50 x 200, bbox 150.00 x 85.10 x 19.50, zero edges used twice, zero without a
reverse, volume by the divergence theorem 66 877.1 mm3 matching the analytic column sum.
Every X, Y and Z level in the file is a dimension off the drawing and there are no others
— Z is exactly {0, 5.0, 11.0, 19.5}. Rendered from the parsed STL through a z-buffer
rasteriser and eyeballed against the plan.

Still assumed and named on the sheet: the step's 6.00 proud, and its photo-scaled
82.40 x 22.20 footprint (+/-1.5). Unprinted, so nothing is fit-tested.

The Rev A-C artifact was deleted, so the sheet is republished at a new URL:
https://claude.ai/code/artifact/4dc3300f-5ff6-41ec-ad7c-701f575df903


## 2026-08-21 (later still)

### Done — prefix-scenes.rb, "ENH" on the front of every scene name

Benton wanted ENH prefixed onto literally every scene. `find-replace-names.rb` could
technically do it with a regex `^`, but a job asked for by name deserves a button.

`scripts/prefix-scenes.rb` — Tidy up the model. Opens a window listing every scene and
what it would become, with the prefix as an editable field defaulted to `ENH `. Nothing
changes until Apply, and Apply is one undo step.

**The trap this exists to avoid is the second press.** Run a naive prefixer twice and
every scene reads "ENH ENH 01". A scene whose name already starts with the prefix is
skipped, and the window shows it on its own SKIP row rather than dropping it from the
list — the difference between a button you can press without remembering its state and
one you cannot. The check is case-sensitive on purpose: "ENH " and "enh " are different
prefixes and picking one is not the tool's decision to make.

**Collisions refuse the whole run**, same rule as find-replace: if "04 Rear" would become
"ENH 04 Rear" and a scene by that name already exists, SketchUp would quietly append
" (2)". Apply greys out until the collision is gone.

**The preview is computed in Ruby, not JavaScript.** The window could derive it in one
line of JS from the name list; it does not, because that would be two implementations of
"what does this prefix do" and they drift. The panel already learned this with toolbar
slot faces. Every keystroke calls back into Ruby and Ruby answers with the same method
Apply uses.

**Verified:** `rbparse.py` parses it. The heredoc's escaping was extracted and checked
with `node --check`, because `\u00b7` and `\\"` inside an interpolating Ruby heredoc
are exactly the kind of thing that silently produces broken JS. Both dialog states
rendered in headless Chrome — the clean case with Apply live, and the collision case with
Apply greyed and the warning banner up. The plan/skip/collide algorithm was ported to
Python and run against six edge cases including the double-press, which is a test of the
algorithm and not of the Ruby.

**Not verified:** it has not run in SketchUp. No Ruby outside SketchUp on this machine, so
every `Sketchup::Page` call in it is unrun.


## 2026-08-21 (later)

### Done — three toolbars instead of one, 18 slots

Benton asked for "another row of favourites", V-Ray buttons separate from the rest.
**SketchUp has no notion of a row inside a toolbar** — it wraps wherever you drag it,
and there is no API for it. What it does allow is several named `UI::Toolbar` objects,
each docked, positioned and shown independently from View > Toolbars. So the answer is
three toolbars, which is better than a row: the V-Ray bar can be switched off outright
on a day with no rendering in it.

- **WhisperRoom** — keeps its name, so its saved screen position survives, and it keeps
  the Panel / Scripts Folder / Ruby Console buttons. Those are not repeated on the other
  two bars; three buttons doing one job is clutter.
- **WhisperRoom V-Ray**
- **WhisperRoom Tech**

Six slots each, 18 total, up from 8.

**The migration is free, and that is a design choice not a coincidence.** Slots are one
flat pipe-joined list where index `b * PIN_N + i` is slot i of bar b. Padding an old
8-entry list out to 18 therefore lands entries 7 and 8 on bar 2 — exactly where they
belong — with no migration branch to get wrong. Verified against a simulated upgrade:
all 8 existing favourites survive, six on WhisperRoom and two on V-Ray.

Eighteen new fallback faces, `icon-fav-w1..w6`, `v1..v6`, `t1..t6`, so no two slots wear
the same star. A slot is named "V-Ray 3" everywhere a human reads it — the toolbar
tooltip, the empty-slot messagebox, and the panel editor all call `slot_label`.

**Verified before shipping:** `rbparse.py` parses all 47 scripts including `main.rb`;
`node --check` on the panel's script block; and the panel rendered in headless Chrome
against a simulated 18-slot payload — three labelled rows, correct per-bar seat numbers,
distinct faces, pending-state dashes landing on the right tiles.

**Not verified:** none of this has run in SketchUp. Three toolbars is the documented API
and other extensions do it, but that it works on Benton's build is reported, not observed.
A new bar appears only after a restart, and where SketchUp first parks it is out of our
hands — the panel now says so, and names each bar so a missing one can be found in
View > Toolbars.


## 2026-08-21

### Done — Studio Light spray guide, STL cut and audited

A mask that keeps spray adhesive off the parts of a Studio Light that must stay clean.
Benton sent eight caliper photos of the existing hand-made one; the deliverable is a
printable replacement at 150 mm instead of 126.8.

- **`docs/spray-guide.html`** — the design sheet, Rev C. Plan, centreline section, live
  WebGL view, printability audit, full provenance.
- **`scripts/spray-guide-stl.py`** — the generator. Writes
  `exports/spray-guide-revC.stl`, 200 triangles, binary, millimetres.

**The part is a pure height field**, so the generator describes it as `h(x, y)` over a
rectangular partition of the plan rather than unioning overlapping boxes. That is the
whole reason the mesh comes out exactly watertight: no coincident faces to reconcile,
no overlap fudge to pick. The house 0.50 overlap rule does not apply here and the
sheet says so.

**The self-audit earned its keep on the first run.** It refused to write the file over
12 unpaired edges — T-junctions where the plate's 5.00 side wall butts into the foot's
12.00 side wall partway up. The part looked closed and was not. Fix is to split every
wall at the union of all column heights, so two walls meeting on one vertical line get
cut identically. Second run: 0 duplicate edges, 0 unpaired, mesh volume by the
divergence theorem matching the analytic column sum at 59 038.1 mm³.

**Rev A got the part wrong in a way a photo could not settle.** The frosted rectangle
was drawn as a through slot; it is a piece of acrylic sitting on the plate, making a
step. Benton corrected it and it became solid, 6.00 proud. That correction is on the
sheet as its own block rather than quietly folded in — the sheet is meant to carry why
a number is what it is, and "we thought this was a hole" is exactly that.

Three figures are still assumed, and the sheet says which: the step's 6.00 datum, its
photo-scaled 82.40 × 22.20 footprint (±1.5), and whether the feet are 12.00 total or
12.00 proud. They are constants at the top of the generator; if any moves, it re-cuts
in a second.

**Unprinted.** Nothing here has touched a printer, so nothing is fit-tested.


## 2026-08-20

### Done — the render-prep toolkit, built but NOT YET RUN

Seven new scripts and two changed files. **None of this has executed.** There is no
`ruby.exe` on this machine, so every file was syntax-checked with `scripts/rbparse.py`
(the real CRuby 3.2 parser) and nothing more. First load in the Ruby Console is what
turns "parses" into "works".

The premise: a model has two jobs — being MEASURED (white floor, dimensions on) and
being PHOTOGRAPHED (imported floor, lit, dimensions off) — and every change between
those states was done by hand from memory. That is where the mistakes came from.

- **`scripts/wr-materials-swap.rb`** — the primitive. Maps drafting -> render materials
  BY NAME, never by material object, so it survives saves and merges. Ships empty named
  slots (`WR-Floor-Render`, `WR-Wall-Render`) filled per job with whatever V-Ray material
  was imported, so the script never has to know what the floor *is*. Atomic apply/revert.
  **Names every surface it could not map** — that reporting is the reason it exists.
- **`scripts/wr-mode.rb`** — Draft <-> Render toggle. Calls the swap for materials and
  nothing else, then flips proposal-scenes' DIM_TAGS, the style and the shadow settings.
  Stores both states in the model. The layering is deliberate: an exporter that swapped
  materials directly would produce a render-material model with dimensions still on.
- **`scripts/wr-preflight.rb`** — read-only checklist in an HtmlDialog, every failing row
  carrying the fix that clears it. No "lighting rig present" row: rig placement was
  deferred and a checklist must not claim to verify something nothing maintains.
- **`scripts/wr-pack-export.rb`** — the one-button export. Marks scenes for V-Ray on the
  Page itself, routes each scene to the right lane, switches mode per scene (02-dimensioned
  wants DRAFTING, the other four want RENDER). **Viewport lane live, V-Ray lane a stub that
  calls nothing under `VRay::`.** Never overwrites the client folder without asking.
- **`scripts/wr-flatten-trim.py`** — flatten-onto-white and trim, because SketchUp exports
  transparent PNGs and a transparent PNG must never reach a pack. Needs Pillow (11.3.0
  present here).
- **`scripts/wr-sun-aim.rb`** — "Light it from here". Sun snaps to the camera azimuth plus
  a ~30 deg offset; the model never moves. The offset is deliberate — dead-behind-camera
  light is flat and the booth reads as a panel.
- **`scripts/wr-split-walls.rb`** — one-time retrofit for existing one-piece-wall models.
  The only script here that edits geometry: loud title, dry-run default, second
  confirmation naming the count, skips-and-names anything it cannot positively identify.
- **`scripts/build-room.rb` + `.html`** — walls and door headers now build in two bands
  split at a configurable sill (default 48"), upper band on tag `WR-Room-Upper`. Hiding
  that tag lowers the walls for a ventilation shot. Scenes already save tag visibility,
  so putting them back is not a step — nothing was ever changed.
- **`scripts/export-scenes.rb`** — the write_image loop extracted as
  `export_pages(model, plan, cfg)` so the new exporter reuses it instead of
  reimplementing it, plus the `$wr_no_autorun` guard every other loadable script had.
  Pure extraction; the moved block is byte-identical.

### 1.4.1 — first real load, first real bug

Benton loaded 1.4.0 in SketchUp. Two things came back, both now fixed:

- **`Sketchup::AttributeDictionaries` has no `#add`.** Both `wr-mode.rb` and
  `wr-materials-swap.rb` did `attribute_dictionaries[D] || attribute_dictionaries.add(D)`,
  which raised `NoMethodError` the moment you pressed Toggle Draft / Render. The
  dictionary is created on demand by `model.set_attribute(dict, key, value)`, which is
  what every other script in this toolset already used — `wr-pack-export.rb` had it
  right on a Page three files away. A parse check cannot catch this; only running it can.
- **The seven new tools were scattered across four categories** — "Tidy up the model",
  "Scenes and images", "Draw the room" and a one-script "Render prep" — so the panel
  looked like only a couple had arrived. They are now all under **V-Ray renders**,
  `@rank`ed in workflow order: mode toggle, sun aim, material swap, preflight, pack
  export, wall splitter, then the V-Ray probe on the dev shelf.

### Two corrections worth remembering

- **The sill/door-head rule runs the opposite way to intuition.** A header spans
  `door_h..ceil`. So a sill BELOW the door head puts the whole header on the upper band
  and it vanishes cleanly; a sill AT OR ABOVE the door head splits the header and leaves
  a shard permanently visible. The build brief stated it backwards and the geometry
  settled it.
- **`rbcheck.py` is not a parser.** Only `scripts/rbparse.py` is. This is now load-bearing
  for a seven-script batch that nobody can run.

### Next steps - START HERE on the next machine

Everything below is pushed to `main` at 1.4.1. Nothing is uncommitted.

**Nothing in the render-prep chain has run clean yet.** 1.4.0 crashed on the first
button pressed; 1.4.1 fixes that one bug. Expect to find more the same way - a parse
check cannot catch a wrong API call, only a live session can. Work down the chain in
order and fix what surfaces.

1. **Get the plugin current.** On the desktop the repo is at
   `C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/`.
   `git pull`, then `python scripts/install-plugin.py`, then restart SketchUp. (Tool
   scripts read live from a checkout, but `wr_tools/` does not, so the installer is
   needed after a VERSION bump.)
2. **Press Toggle Draft / Render** on a real room. That is the one that crashed with
   `NoMethodError` on 1.4.0. Confirm it gets past that, then confirm flipping BACK
   restores the drawing exactly - the whole design rests on both snapshots
   round-tripping.
3. **Light It From Here.** Orbit to a three-quarter view and press it. If the lit face
   is the wrong one, flip `SUN_BEHIND_CAMERA` at `scripts/wr-sun-aim.rb:141` - one line,
   nothing else changes. Watch for a red LOW CONFIDENCE flag in the dialog; that means
   the NorthAngle calibration did not come back linear and the result is not trustworthy.
4. **Swap draft / render materials.** Fill the `WR-Floor-Render` slot with a real
   imported V-Ray floor and check the unmapped-surface report actually names things.
5. **Pre-render checklist**, then **Export the client pack** (viewport lane only - the
   V-Ray lane is a deliberate stub and will say so).
6. **Build a room and check the two-band walls.** Confirm the room comes out
   dimensionally identical to before, the mitred corners are clean, and hiding tag
   `WR-Room-Upper` lowers the walls. Sill defaults to 48" at `scripts/build-room.rb:95`.
7. **Run `probe-vray.rb`** (dev shelf - switch on "Show developer & workshop tools"). It
   is read-only and renders nothing. It still gates the export's V-Ray lane and the
   question of whether V-Ray's sun follows SketchUp's `shadow_info`.

The scoping artifact shared with Gabe, if it needs updating:
https://claude.ai/code/artifact/6109a445-02b9-4bc9-bf9b-068ac0ab75a3

### Open decisions

- **Sill height defaults to 48"** (`scripts/build-room.rb:95`) and is a guess. Benton said
  "lower the walls like 8ft or so", which in an 8'-0" room removes them entirely — so it is
  unclear whether 8'-0" is the height walls are lowered TO and these are taller commercial
  rooms.
- **`SUN_BEHIND_CAMERA = true`** (`scripts/wr-sun-aim.rb:141`) — whether "from here" means
  the sun stands where you stand or over what you are looking at. One line to flip once a
  real render shows which.
- **Preflight's ceiling check** leans on `model.raytest`, whose signature is from the docs
  and never exercised. It degrades to a skip row rather than a false pass.
- **`probe-vray.rb` still has not been run.** It gates the export's V-Ray lane and the
  question of whether V-Ray's sun follows SketchUp's `shadow_info`.

### Deliberately not built

Light rig placement (`wr-lightrig.rb`), pinned render settings, `.vrscene` archive,
lighting contact sheet, rig presets. Rig placement was deferred by Benton on 20 Aug 2026;
the geometry is easy but the ratios that make it worth having come from use, not guesswork.


## 2026-08-19

### Done

- **Plugin versioning and one-click update, working end to end.** `VERSION` is
  one file, shipped by `install-plugin.py` and compared against GitHub. Now at
  1.3.1. The Update button works; Benton confirmed it.
- **Two tabs in the panel** — TOOLS and CLIENT DRAWINGS. `# @tab client` files a
  script on the second one; no header means TOOLS. Search spans both.
- **The installer was deleting people's own scripts.** `copy_scripts()` opened
  with `shutil.rmtree()` on the plugin's scripts folder, so anything a teammate
  had written there was destroyed, permanently and silently. Gabe lost a script
  to it. It now keeps a manifest and removes only what it installed; anything
  else is left alone and named in the output.
- **Panel always opens on-screen.** `open_panel` sets the position before
  showing. An off-screen HtmlDialog still reports `visible?` true, so the old
  code raised a window nobody could see and the toolbar button looked dead.
- **Proposal system consolidated into this repo** under `proposals/`, with the
  playbook at `reference/proposal-playbook.md`. A clean clone builds a correct
  pack with no other input — verified.

### Three bugs worth remembering

- **Backticks return "" in SketchUp's Ruby on Windows.** `git --version` -> "".
  The process spawns; the PIPE does not work. Output has to go to a file.
- **`system('cmd /c cd /d "..." && git pull')` runs git in the WRONG DIRECTORY.**
  Ruby sees the metacharacters and wraps the string in a second cmd; the nesting
  rebinds the `&&` so the cd happens in a child that exits. A batch file has
  neither problem and is what the update uses now.
- **`raw.githubusercontent.com` served a five-minute-stale file.** The version
  check now reads the GitHub API with `Accept: application/vnd.github.raw`.

### Next steps — V-RAY IS SCRIPTABLE, and that is tomorrow's job

V-Ray for SketchUp ships a full YARD-documented Ruby API and the docs are
already on the machine at
`C:\Program Files\Chaos\V-Ray\V-Ray for SketchUp\extension\documentation\index.html`.
Findings written up in `reference/vray-ruby-api.md`.

`VRayRenderer` exposes 61 methods including `start`, `stop`, `wait`, `export`,
`save_vfb_image`, `denoise` and the VFB settings. `Scene` manages materials and
lights as plugins. `ModelExporter#subscribe` hooks the moment after the model is
exported and before the render starts.

1. **Run `probe-vray.rb`** (dev shelf, Tidy up the model). Read-only, renders
   nothing. It answers the question everything else depends on: is
   `VRay::Context.active` non-nil COLD, or only after someone has rendered once
   by hand in that session?
2. Take the probe output and settle the other four questions listed at the
   bottom of `reference/vray-ruby-api.md` — is `start` blocking or async, what
   `save_vfb_image` actually takes, whether a render can run with the VFB
   hidden, and whether a scripted render consumes a licence seat.
3. Then scope the real prize: **batch the proposal renders.** Walk the proposal
   scene list, render each at one pinned resolution, `save_vfb_image` straight
   into `ProposalFiles\<Client>\` with the names the proposal config expects.
   That closes the last manual step in the proposal pipeline.

### Open decisions

- Iso30 `Frame on`: part-centred or insertion point? Still unresolved, and 200
  scenes ride on it.
- PeopleSpace: the alcove WIDTH has never been supplied and blocks a real fit
  answer. Also 10'-8 3/4" on the architect's plan vs 10'-7 1/2" in Peter's email.
- Kuwait TV: booth-to-booth acoustic spacing is not a number WhisperRoom
  publishes. The 12" drawn is a working aisle only. Engineering has to answer it.


## 2026-08-18

### Done

- **Booth-from-link door bug, found and fixed.** The placer decided "is this a
  door?" from `p[:sk]`, the layout's STATIC slot kind, so a customer who moved
  the door in the booth builder got a door that took the vent rule — bulk out,
  leaf pointing away from the room. On the 96120 the door landed in E1, a slot
  the layout calls SOLID, and built inside-out. It now reads the component that
  was actually assigned (`/Door/i` on the resolved name). Verified against a
  real link: the door went from `X+ OUT` to `X- IN`, matching all 19 other
  parts. The standalone path never showed this because ASSIGN only ever puts a
  door in a DRFRM slot.
- **booth-from-link now prints the RAW PACK** beside each translated component
  and a placement summary in the portal's own words (Front/Back/Left/Right), so
  a build can be diffed against the builder's "YOUR BOOTH" panel as text
  instead of by comparing renders. That is what proved the translation correct.
- **elevation-export**: added `Left + Top` and `Left + Right + Top` view sets.
- **reorient-model.rb** (new): rotates geometry, EVERY scene camera and the
  north angle together, so SketchUp's Front view can be made to mean front
  without re-aiming a single scene and without shifting the shading. Unrun.
- **csusb-106.rb** (new): CSUSB Chaparral room 106, 575 sq ft. Read from the
  A-1 vector pdf at an exact 5.000 in/pt scale, cross-checked by a 1200 dpi
  flood fill. Ceiling is the 8'-0" house default and is NOT measured.
- **smith-studio.rb** (new): David Smith's studio from a hand sketch.
- **fvrl-podcast-alcove.rb** (new): Fort Vancouver library alcove fit study.
- **PeoplesSpace proposal shipped** — 6 pages to
  `Desktop\ProposalFiles\PeoplesSpace\PeoplesSpace-Booth-Renderings.pdf`.
  Config kept at `WhisperRoom Proposals\examples\peoplespace\`.

### Settled this session

- **Carpet texture tile: 9 inches.** Measured against a flat-on photo of a real
  booth by comparing matched 6in x 6in patches at the same scale. 2 ft is about
  four times too coarse; 6 in matches the fleck size but repeats 7.2 x 13.5
  times across a 43 x 81 panel, which reads as a pattern. 9 in halves the
  repeat for 0.02 in of extra fleck. NOTE: standard deviation measures speckle
  AMPLITUDE, not SIZE — using it to pick a tile is what gave two wrong answers
  before the matched-patch test settled it.
- **Component art view height: 128 at a 2400 canvas = 18.75 px/in.** One scale
  for all 208 components across Iso30, elevations and top-downs. 104 clips 62
  parts; the binding constraint is `RampSideView_HX` at 118.1 in projected at
  azimuth 38. The 8 `RM*` room mockups need 188 and should be a SEPARATE run —
  folding them in costs every wall panel 32% of its resolution.
- **Style must be pinned by name.** `export-component-art.rb` activates each
  scene, and a scene restores its own saved style, so "leave the style alone"
  gives a MIX in that exporter even if nobody touches anything. The Iso30 and
  elevation exporters do not activate scenes, so they are safe either way.

### Next steps

1. **Re-run the top-down set at view height 128** (was 108) so all three
   exporters share 18.75 px/in. `elevation-export.rb`, View = `Top`, canvas
   2400, Frame on = Part centred, scenes:
   `1-55,70-85,185,187,189,191,193,195,197,199,202,204,206,208,210,212,214,216,218,220,222,224,226,228,231,233,235,237-239`
   (99 scenes, HX/CL/CP/RM dropped). Dry run first.
2. **Iso30 chunks**: azimuth 38, view height 128, canvas 2400, Dark 45, AO Yes.
   Pin the Style by name and use the SAME one for every chunk.
3. **Confirm `Frame on` for the Iso30 set.** `angled-component-art.rb`'s header
   says the web page's contract is "insertion point at centre"; the dialog is
   currently on "Part centred". One of those is wrong and 200 scenes ride on it.
4. **Run `reorient-model.rb`** with Dry run = Yes first. The scene-camera write
   is the one call that could not be tested outside SketchUp — it reads every
   camera back and names any that did not take.
5. **Ask Peter (PeopleSpace) the alcove WIDTH.** It has never been supplied and
   it blocks a real fit answer. Also reconcile 10'-8 3/4" on the architect's
   plan against 10'-7 1/2" in his email.

### Open decisions

- Angled set: frame on the part or on the insertion point? Still unresolved,
  now with 200 scenes waiting on it.
- 108 doorway recess in room 106 is flattened to a plain 41 in opening.
- David Smith: north wall chain is 10 in short of the stated 7'-4", and the
  ceiling at 7'-0 3/4" clears Standard by 1 3/4 in but is 1/4 in SHORT of
  Enhanced. Both need David to answer before anything is quoted.


## 2026-08-17 — session handoff: two dialogs that have never been opened

End of day, switching machines. Three pieces of work landed today and **the riskiest thing in
the repo right now is the one that parses cleanly.**

**1. Ceiling seam seals — committed, `c9ed74e`.** Selection off the booth's cross dimension
(`seal length = feet × 12 − 2`), one seal per ceiling joint, centred on the joint station, no
handing. `SEAL_DATUM_LIFT = -1.75` is measured by fit test, not derived, and puts the seal's
top face on the panels' contact plane. Built and confirmed in SketchUp on **MDL 7272 S, 9696 S,
96120 S and 102186 S** — the commit message says only the 7272 because the other three were
built after it. `STDSS CL5` and `STDSS CL7` are still unbuilt, the 10284-class **quarter turn
has never run**, and neither has the zero-seal case (4872 / 4230).

**2. The floor/ceiling toggle removal — NOT committed, and NOT run.** The row is out of
`scripts\build-booth-components.rb` and `scripts\booth-from-link.rb`; deck and seals are
unconditional. `rbparse.py` is green and that proves nothing that matters here: both dialogs
pass **three parallel arrays to `UI.inputbox`, matched by index**, and a length or index
mismatch is silent — SketchUp reads the wrong field into the wrong variable and says so
nowhere. A parse cannot catch it. **Opening each dialog once is the first job of the next
session.**

**3. `reference\seam-seal-attachment.md` — new, uncommitted, not yet handed over.** Plan-view
spec of the corner and mid-wall seam seals for the `WhisperRoomQuote` agent building top-down
art: exact vertex lists, joint-centre stations, the closure rule worked on the 4872 S and
checked on the 96120 S. Written to be read cold, with no access to this repo.

Three smaller things, all Benton's hands rather than the code's: the `STD7224 CL/FL SIDE R`
flip was **the master component files saved out of alignment, not a code defect** — re-saved
and confirmed. `STD7248CL/FL SIDE R` did not exist in the library; he authored them and
`wr-deck.rb` picked them up with **no code change**. And the four CL seals plus `STDSS 8.5CL`
were **re-cut to 1.750 tall so the seal suits the slot**, rather than the code growing a
constant to compensate for the mismatch.

### Next session, in order

1. **Open both booth tools in SketchUp** and confirm each dialog reads correctly now the toggle
   row is gone. Nothing else should be trusted until this is done.
2. Build a **6084-class** booth (exercises `STDSS CL5`) and a **10284-class** booth (exercises
   `STDSS CL7` *and* the quarter turn — the largest untested branch in the seal work).
3. Hand `reference\seam-seal-attachment.md` to the `WhisperRoomQuote` agent.
4. `auto-dimension.rb`'s container-transform fix (`e90321d`, 2026-08-16) is **still unrun in
   SketchUp**, with two open questions in `.forge\fixer\root-cause-transform.md`: a rotated
   room's overall dimensions, and doors nested inside the room group never getting dimensioned.

### Waiting on Benton

- **Door leaf thickness and swing geometry are undimensioned anywhere in this repo.** This
  blocks the quote-tool agent's top-down views — no swing arc is drawable without it.
- **Vent duct and silencer box dimensions**, same situation, and the vent projects past the
  booth footprint, so a plan that stops at the exterior rectangle is incomplete.
- The two `auto-dimension` questions above.
- `scripts\export-component-art.rb` carries an **uncommitted one-line `@title` change** to
  `Scene PIctures...` — capital I mid-word, which reads as a typo. Not our edit; left
  uncommitted deliberately. Fix and commit it, or revert it.

## 2026-08-17 — the floor/ceiling toggle is gone from both builders

"Floor and ceiling: Yes/No" is removed from **Build Booth from Components** and from
**Build Booth from Link**. The deck pass and the seam-seal pass now always run.

**This is a behaviour change and it costs something.** A user who previously answered No to
build the walls without a floor and ceiling has no way to do that any more. Benton asked for
it and accepted that tradeoff — a booth without its deck is not a thing anyone was actually
producing, and the row had to be answered on every single build to get the answer it already
had. Restoring it is one dialog row in each tool plus one guard; nothing about the placement
moved.

What made it clean: `build_booth`'s third argument is a **config hash**, not a positional
parameter list, so `'deck'` simply stops being a key. No signature change, and — the thing
worth avoiding — **no dead always-true boolean left threaded through the call** pretending a
decision is still being made. Grepped for other callers before touching it: there are exactly
two, `booth-from-link.rb:170` and `build-booth-components.rb`'s own `run`. `csusb-rooms.rb`
has a `build_booth` of its own, in a different module, unrelated.

Both dialogs pass **three parallel arrays** to `UI.inputbox` — prompts, defaults, dropdown
lists — matched by index, and a mismatch there is silent: SketchUp does not complain, it just
reads the wrong field into the wrong variable. So the row came out of all three arrays
together in both files and the remaining `res[i]` indices were re-walked. Checked
mechanically afterwards rather than by eye: every literal-array `UI.inputbox` in `scripts\`
has three arrays of equal length, `build-booth-components.rb` at 4/4/4 and
`booth-from-link.rb` at 3/3/3.

The stored `deck` preference is **left in the registry**, unread and unwritten. Migration
code for a preference nobody will ever see again is more risk than the tidiness is worth.

Unrun in SketchUp — `python scripts/rbparse.py` reports 35 files parsing, which is a real
CRuby parse and not a claim that either dialog was opened.

## 2026-08-17 — the ceiling joints get their seals, and the seal got re-cut rather than the code

`WR_Deck` tiled the ceiling and left the joint between the panels bare. It places the
seam seal now — `WR_Deck.seals`, a separate pass wired in after the `%w[FL CL]` loop in
`build-booth-components.rb`, riding on the existing **Floor and ceiling: Yes/No** control
and the same `WR-Booth-Deck` tag.

Separate on purpose. `git diff scripts/wr-deck.rb` is **240 added lines and not one
deleted** — `build`, `plan`, `pick`, `tile`, `order_cuts`, `contact_z` and `deck_extent`
are byte-identical, which is the out-of-scope fence written as code rather than as an
intention. `seals` re-runs `catalogue` and `plan(spec, cat, 'CL')` itself; `plan` is pure,
so the joints it computes are the joints the panels were seated at, and the cost is one
folder glob.

Selection is general, not tabulated. Benton ran `probe-seam-seal.rb` on a built MDL 7272 S
and the numbers came back: every ceiling seal is 6.5 across and 2.0 tall, and its length is
exactly `feet × 12 − 2` — 58 / 70 / 82 / 94 / 100 for CL5 / CL6 / CL7 / CL8 / 8.5CL. So the
seal a booth takes is the one whose `feet × 12` equals the deck's cross, the measured length
is then re-checked against `cross − 2` as an independent tripwire, and a mismatch is warned
rather than swallowed. No per-model table, no name-based exception — this file's header
already records what four rounds of per-part constants cost.

The registration is the good part, because two parts measured separately agree. `STDSS CL8`
carries its ribs at part x 0.6875–0.9375 and 5.5625–5.8125 on a 6.500 part, a pair **±2.4375
from its own centreline**. The slot in `STD7248CL SIDE L` sits centred 2.4378 from its joint
edge and in `STD7224CL SIDE R` 2.4368 from its own. **Centre the seal on the joint station
and the ribs land in the slots** — one rule, no handing, no front and back. And the seals are
*shifted, never flipped*: the gap signature above the datum face is `+1.000, +0.250, +0.750`
on all of them, so CL8 is CL5/6/7 translated down 0.75, not turned over. Nothing in the seal
path flips a part.

The MDL 7272 S is the flagship because its joint is at 48 from the low end, not at the
midpoint. It gets one `STDSS CL6` centred at booth **x 49.000**, not at 37.000. A bug that
defaults to the deck midpoint is visible there and invisible on the 7296.

**The vertical was the one number nobody had measured, and it is measured now.** It shipped
as a single constant, `SEAL_DATUM_LIFT`, defaulted to a stated guess, and Benton built the
7272 and dragged the placed `STDSS CL6` by hand until it seated: down 1 3/4. So it is
**−1.75**, and the rule it expresses is **the seal's top face lands on the panels' contact
plane** — datum at booth z 79.250, top at exactly 81.000.

1 3/4 is not an eyeball figure and the reason matters. Datum-to-top is **1.750 on both seal
families** — CL8's datum sits 0.750 lower and so does its top — so one constant places all
five sizes with no special case for the family shift, and at −1.75 the seal's 0.750 top
section drops into the panel's 0.750 slot at booth z 80.249 → 81.000. The proof asserts
`SEAL_DATUM_LIFT == −(datum-to-top)` for every seal and fails loudly if a later edit breaks it.

**And here is the durable part: the mismatch got fixed in the part, not in the code.** The
old seals were 2.000 tall with an extra 0.250 step at z 1.250, and the section that met the
slot was 1.000 against a 0.750 slot — a part that could not seat. The tempting fix is a
compensating offset in the placement, and that is how a file grows a second vertical constant
that nobody can later explain. Benton re-cut all four CL seals to 1.750 with the step removed
instead. **The part now suits the slot, and there is still exactly one vertical number in
`wr-deck.rb`.** The corollary is written next to it: that number is tied to the parts it was
measured against, and a library still holding the old 2.000-tall seals would want −2.00.

Proof, since there is still no `ruby.exe` here: `.forge/builder/seal_placement_proof.py`
re-implements `joint_stations`, `pick_seal` and the `seals` transform in Python and checks
them against the probe's numbers held as independent ground truth — the 7272's single
`STDSS CL6` at x 49.000 with ribs at 46.5625 and 51.4375, the 96168's **three** CL8s at 49 /
97 / 121, the 10284's quarter turn (two CL7s along booth Y at y 43 and 85, 6.5 across in Y),
zero seals and zero warnings on the single-tile 4872 and 4230, every seal landing its top face
on 81.000 despite the 0.75 family shift, and the two catalogues staying disjoint so a seal can
never enter the panel pool. It passes, and it was checked to fail on both 0.0 and −1.0.
`python scripts/rbparse.py` reports 35 files parsing.

**Built in SketchUp and confirmed correct, four booths, three of the five seal sizes:**

| booth | cross | seal | what it exercises |
|---|---|---|---|
| MDL 7272 S | 72 | `STDSS CL6` | the off-centre single joint, at 48 from the low end |
| MDL 9696 S | 96 | `STDSS CL8` | the CL8 family — the −0.750 datum, placing to the same plane |
| MDL 96120 S | 96 | `STDSS CL8` | **the first multi-joint booth built** — three tiles, two seals |
| MDL 102186 S | 102 | `STDSS 8.5CL` | the 8.5 spelling, where the digit changes sides in the name |

Benton: *"I tested a bunch and they all look great."* The 102186 S matters more than it
looks. `STDSS 8.5CL` was **still the old 2.000-tall part when this feature was first
built** — he re-cut it at 13:45 on 2026-08-17, after the other four — so that booth is the
proof the re-cut part places correctly and not just the ones that were current on the day.
That closes the gap the first draft of this entry flagged.

**Still unbuilt, and worth saying rather than implying it is all covered:** `STDSS CL5`
(a 6084-class booth) and `STDSS CL7` (a 10284-class booth, which is also the only booth in
the set that tiles along booth **Y** and so is the only real test of the quarter turn), and
the zero-seal case — a single-tile ceiling on an MDL 4872 S or 4230 S, which must place
nothing and warn about nothing. All four are proven in arithmetic only.

`probe-seam-seal.rb` now clears the Ruby Console before it prints its banner, so where a run
begins is unmistakable. `SKETCHUP_CONSOLE.clear` — the name checked against
`ruby.sketchup.com/Sketchup/Console.html`, SketchUp 2014 and later — guarded behind
`defined?` and `respond_to?` and rescued, because a probe that raises because it could not
tidy the screen is a worse outcome than a messy screen.

## 2026-08-16 — auto-dimension read the room in one coordinate space and drew in another

Dimensioning a room that had been **moved, rotated or scaled after it was drawn** put the
whole chain somewhere else in the model — 54 feet away for a plain translation, in the
reproduction — or reported "No floor face found" and did nothing at all.

Root cause, one sentence: a face that lives inside a group stores its vertices in that
group's own coordinate system, and `collect` (`scripts/auto-dimension.rb`) descended into
groups and component definitions and appended the faces raw, never applying
`e.transformation` — while the dimensions it drew went into `model.entities`, which is
world space. SketchUp says as much in its own API: `Face#area` takes an optional
transformation "to correct for a parent group's transformation", an argument that would
mean nothing if the geometry were already world.

Five consumers were reading those local numbers as world: `floor_face`'s horizontal test
(so a rotated room hid its floor entirely), its area test, its lowest-level test,
`runs_of`'s perimeter walk, and the `face.bounds` the two overalls are hung off. The door
finder was the mirror image — doors are top-level so *their* bounds were already world,
mixed against local runs, so no door could ever match the 24" proximity test.

The fix threads a `Geom::Transformation` down the recursion, composing `tr *
e.transformation` on each descent — the same idiom `probe-levels.rb`, `wr-deck.rb` and
`build-booth-components.rb` already use — and stores `[face, transform]` pairs.
`floor_face` returns that pair, `runs_of(face, tr)` transforms each vertex as it reads it,
and the overall now comes off a world bounding box of the traced perimeter instead of the
local `face.bounds`.

`dimension_face`'s new `opts[:transform]` defaults to identity, so **`build-room.rb`'s call
is untouched**: it hands over a face in a group it created moments earlier, whose transform
genuinely is identity. That identity case is a proven no-op, not an assumed one — the
reproduction reports the new code producing the byte-identical list of dimension triples.

A scaled room group now dimensions to its **scaled, real size** (144" × 168" at 1.5×/0.75×
reads 216" × 126"). That is deliberate: the drawing must state what the model measures.

Two things deliberately left, both written up in
`.forge/fixer/root-cause-transform.md`: a *rotated* room's two overalls are world axis
extents rather than the room's own length and width (the segment chain is right, and
closure correctly refuses to claim it closes — dimensioning a rotated room in its own axes
is a design call, not a bug fix); and `doors_on` scans only top-level `model.entities`, so
the doors `build-room.rb` puts inside the room group have never been reachable at all. That
second one is a separate pre-existing defect worth its own pass.

Proof, since there is still no `ruby.exe` here: `.forge/fixer/transform_repro.py` is a
line-faithful Python reimplementation of the coordinate math run on an L-shaped room under
identity, translation, rotation, non-uniform scale and a three-deep nested transform,
checked against ground truth defined independently. Old fails four of five, new passes all
five, identity byte-identical. `python scripts/rbparse.py` still reports 34 files parsing.
**None of this has been run in SketchUp.**

## 2026-08-15 — the ability row was dead space; the whole row is the switch now

Clicking **Dimension the room** did nothing at all — no dialog, no error, no
dimensions. Same for Dimensioned booth, Dimensioned selection, Exploded and
Proposal scenes. All five are abilities, and the redesign merged each one's
action row into its ability row without extending the click wiring to it.

Root cause, one line: `abilityRow()` emits `<div class="row ab" data-ab="…">`,
and `wire()` only ever selected `.row[data-i]`, which is what an *action* row
carries. An ability row matched nothing, so its body was inert; only the small
switch at the far right responded, and `.row.ab { cursor: default }` even told
the user so. The name Benton had been clicking for weeks was decoration.

The fix keeps the design rule the spec set — an ability has exactly one control,
no separate RUN that could bypass the switch — by making the row body *be* the
switch. Both entry points call one `flipAbility(sw)`, so the row can never
disagree with its own switch, and the switch's own handler stops propagation so
a click on it does not also fire the row (a double flip would toggle on and
straight back off, which presents as "nothing happened" all over again). Gear,
star, pencil and settings fields already stopped propagation and keep working
without toggling anything.

Regression test: `.forge/fixer/panel-abilityrow-uitest.py` builds a standalone
page from `panel.html` with the SketchUp bridge stubbed and drives it in
headless Chrome. 33 assertions. Against the pre-fix file it fails 10 of them;
after, all 33 pass. It also walks every other control the renderers emit —
action rows, toolbar slots, section headers, state chips, the rename pencil —
because a control emitted by one function and selected by a mismatched selector
is the bug class, not a one-off.

## 2026-08-15 — the panel is rebuilt, and flipping a switch no longer opened a dialog

**`scripts/wr_tools/panel.html`** rewritten, **`scripts/wr_tools/main.rb`** extended,
29 purpose-built icons added, and header lines touched across `scripts/*.rb`.
Steps 1–5 of `.forge/scoper/panel-redesign.md`; 6 and 7 were deliberately
left. **Nothing here has been run in SketchUp** — see the last section, which is
as much of this entry as the wins are.

### The defect that gated the whole thing

`main.rb#toggle` did `load` on the ability's file and then evaluated its `@on`
expression. Every ability script also ends in a top-level autorun — the line that
makes `load "…/explode-view.rb"` in the Ruby Console actually do something — and
`toggle` set **neither** suppression global. So flipping a switch ran the
script's normal entry point first, modal dialog and all, and then did the work a
second time with whatever the dialog returned. `explode-view.rb`'s own header
says the ability path exists precisely so a modal never gets in the way of a
toggle.

Two of the five ability scripts had no guard at all to set (`explode-view.rb`,
`proposal-scenes.rb`; they have one now), and the three that did had drifted into
two spellings — `auto-dimension.rb` reads `$wr_suppress_autorun`, the other four
read `$wr_no_autorun`.

`load_quietly` sets **both**, so neither script has to change and an ability
written to either spelling is already covered — and **restores the previous
values afterwards**, which is the part worth recording. Leaving them set silences
the autorun for the next script *run* from the list, and a script that loads and
then does nothing presents as a dead button. `booth-from-link.rb` and
`build-room.rb` already save-and-restore for the same reason; this is that
pattern, not a new one.

### Three new header directives, all optional

The property that matters is not what they do, it is that **a script declaring
none of them renders exactly as it did before**. That was an acceptance
criterion, not a happy accident — the redesign had to be worth zero edits across
40 script files, so every one of these is additive and parsed beside `@cat` in
`meta_of`:

| Directive | Grammar | What it does |
|---|---|---|
| `# @icon <id>` | one token | Names a symbol in the sprite. Resolution is `@icon` → `icon-map.json` → `wr-default`. |
| `# @shelf dev\|workshop\|archive` | one keyword | Keeps the script off the default list, behind the footer switch. |
| `# @rank <n>` | signed integer only | Sorts within a category; lower first, unranked sinks below every ranked row. |

`@rank` parses integers only and leaves anything else as *no rank* rather than
letting it become 0, because a typo sorting to the top is worse than a typo doing
nothing. The icon fallback is deliberately loose at both ends: `wr-icons.svg` and
`icon-map.json` may both be missing and every row still draws the house glyph,
because a missing sprite must never blank the list.

### Why two categories are ranked and the rest are not

Alphabetical is right for a set and wrong for a sequence. *Build the booth* is
three ways in, best first, and by title alphabetical opened with
**Block-out booth (plain boxes, fast)** and buried
**Build the customer's booth (share link)** at the bottom. The eye lands on the
first row, so that order did not merely fail to help — it recommended the fast
low-detail block-out to someone who had a customer's actual configuration in
hand. Same class of error in *Scenes and images*: **Set up the five proposal
plates** sorted last, behind the two exporters that consume the plates it makes.

Everything else is left alphabetical on purpose. *Add dimensions* holds three
different subjects rather than a sequence, so nothing is misread by sorting them
by name, and *Pinned* keeps toolbar-slot order because that order is its meaning.

### The icon rules, and what enforces them

24-unit grid with a 20-unit live area, 1.8 centred stroke (1.4 / 1.2 for
deliberately recessive context marks — extension lines, ghosts, level rules), two
inks only: graphite for context, and `#ee6216` on **exactly one element, the
thing the tool creates or changes**. The house motifs are the booth (solid rect +
door return), the room (open rect + door swing arc), and the dimension string
(oblique drafting ticks, never arrowheads — Benton's own drawing convention). The
failure test is the useful half: **an icon serving two tools is rejected**, which
caught three real collisions in the mockup (`i-scenes` served two scripts,
`i-scenecomp` four, `i-probe` three).

`.forge/builder-icons/gen-icons.py` is the source of truth — it emits all 29
standalone `wr-ico-*.svg` files, the sprite, `icon-map.json` and the contact sheet
in one pass, and exits non-zero on a duplicate id, a wrong `viewBox`, an
off-contract stroke width or geometry outside the live area. Hand-editing any one
of the four outputs makes them drift, so don't.

The library glob now takes `wr-ico-*.svg` **beside** `ico-*.svg` and resolves a
saved slot id through both, so the ids already sitting in preferences keep
working.

### What was deliberately not done

Both of these are cheap to re-propose and expensive to get wrong, so the reasons
are here rather than in a commit message.

- **The pre-run settings sheet** (spec step 6) touches `meta_of`, which every
  panel render runs. A regression there does not degrade the list, it blanks it.
  It is a separate round on its own.
- **Deleting the legacy `ico-*.svg` library** (spec step 7). Saved `slot_icons`
  prefs still reference those ids; deleting them regresses the toolbar to
  numbered faces.
- **`booth-4260-s.rb`, `booth-96168-s.rb` and `csusb-rooms.rb` were shelved, not
  retired.** Deleting them was proposed and refused: it is the one irreversible
  call in the set and it is Benton's. `csusb-rooms.rb` is additionally cited in
  `CLAUDE.md` as the worked example, so shelving keeps that reference true. They
  sit on a third shelf, "One-off & superseded".

### Unverified — the honest half

**Nothing was run in SketchUp.** The checks that exist are headless render
assertions over a real payload plus desktop Chrome at 330 px and 640 px, and they
say nothing about the following, all of which need a live session:

- The autorun fix, across all five ability scripts.
- The toolbar pending state clearing across a SketchUp restart.
- Whether SketchUp's embedded Chromium honours `prefers-color-scheme` at all. The
  tokens also answer to `:root[data-theme]`, so if it does not, a manual theme
  pref is one line of JS and no restyling.
- Collapse state and the developer-tools switch surviving a panel reopen.
- **Icon legibility at 20 px was never rendered by anyone.** Every geometric claim
  about the set is parsed, not seen. `.forge/builder-icons/contact-sheet.html` is
  the instrument — open it in a browser. The `wr-dim-booth` / `wr-dim-selection`
  pair and the two `booth-preset-*` icons are the ones to look at first.

### One open question for Benton

Six scripts carry a proposed title in the Researcher's tree that was **not** among
the 14 approved renames, so their old titles are untouched and the list now reads
inconsistently against its neighbours: `list-scenes.rb`, `orbit-export.rb`,
`explode-view.rb`, `save-scene-components.rb`, `find-replace-names.rb`,
`merge-materials.rb`.

## 2026-08-14 — a booth-specific dimension tool

**`scripts/dimension-booth.rb`** (new). The three figures that go on a
WhisperRoom drawing, taken from the catalogue rather than measured.

`dimension-selection.rb` already measures a bounding box, and that is exactly why
this is a second tool rather than a setting on that one. A built booth's box also
contains the door leaf modelled standing open, a VSS silencer stack, a
condensate pan below the floor and any ADA ramp. A 7296 measures over ten feet
long that way, and the number would go in front of a customer. So the model
NAMES the booth and the size comes from `wr-booth-data.rb` plus one rule.

### The rule, and why it is not a guess

A vented face adds **5.5 in to the dimension on its own axis** — per FACE, not
per vent. It reproduces both worked examples exactly:

| booth | vented | dimensioned |
|---|---|---|
| MDL 7296 S | N only | **8'2" x 6'7 1/2"** |
| MDL 96120 S | N and E | **10'7 1/2" x 8'7 1/2"** |

The first is Benton's own worked example; the second is read straight off a
dimensioned render he made before this script existed. Two independent
confirmations of one rule.

Per-face is what makes the 7296 work: it carries two vent sets and both sit on
N, so N projects once and the booth gains 5.5 in, not 11.

Heights are `Standard 6'11"` (83.0000) and `Enhanced 7'-0 5/16"` (84.3125). The
standard figure is also what the built model comes to — floor underside −1.0,
wall 0 to 81, ceiling top 82.0 — which is a free check on the deck work above
rather than a coincidence.

### The one thing deliberately left open

**5.5 in is the NO-EFS figure.** An EFS wall stands further out and that distance
has never been measured, so `VENT_PROUD` is a dial with the reasoning written
beside it rather than a constant. It specifically must not be confused with the
10 in EFS figure in `CLAUDE.md`, which is a *clearance to leave around* the
booth, not the booth's own projection.

### It identifies the booth — there is no dropdown, deliberately

A dropdown is a second place for the answer to live, and the two drift apart the
moment a booth is rebuilt as a different model. Select the booth; it works out
which one, by two routes, and the console always says which one answered:

1. **The group name.** `build-booth-components.rb` names its group
   `MDL 96120 S (components)`, so the key is sitting there. Exact, and normal.
2. **The deck part names.** `wr-deck.rb` names each panel after its file, so
   `STD9648FL SIDE` + `STD9624FL CTR` + `STD9648FL SIDE` is 96 across by 120
   along, and the exterior is that plus the 1 in inset per side.

Every model resolves uniquely by route 2 — verified against the deck plan for
all 25. **`MDL 10284 S` and `MDL 84102 S` are the same 86 × 104 rectangle turned
90°** and even share a deck (84 × 102), so the tiling *direction* is measured
from where the panels actually sit to separate them. If it cannot, both
candidates are reported rather than one being picked.

No route means no answer: it says so and stops, because the alternative is a
plausible model name on a drawing.

**Vents come off the placed parts, not the layout data** — the layout says what
kind of slot a wall has, the placed part says what actually went in it, so a
booth whose vent was moved for a customer dimensions as built. It falls back to
the layout when parts are not named per slot, and says when the two disagree.
EFS and HX parts are both detected and reported, never guessed at: the EFS
projection is unmeasured and there is no agreed drawing height for HX.

Own tag, `WR-Dims-Booth`, separate from `dimension-selection.rb`'s so both can be
on at once — and it counts that tool's dimensions if they are present, because a
booth carrying both shows two different footprints with nothing saying which is
which. That has already happened once: a 96120 reading 10' 8 7/16" x 9' 11 1/2"
off a bounding box against its catalogue 10' 7 1/2" x 8' 7 1/2".

## 2026-08-14 — the deck orientation is measured now, and the 96 series is the odd one out

Three defects reported on the MDL 96120 S. All three are fixed, and none of them
needed a constant to be guessed at.

### The 96 series carries its bracket line at the opposite end

The turn was positional — turn the high-end tile, leave the low one. That made
the MDL 7272 S correct (confirmed by Benton) and the MDL 96120 S wrong at **both**
ends, which is only possible if the parts differ rather than the rule. The full
237-part probe says exactly that, measuring the bracket line as a fraction across
the panel's short axis:

```
STD7224FL SIDE R   0.218      STD9648FL SIDE   0.737
STD7248FL SIDE L   0.261      STD9648CL SIDE   0.737
STD10242FL SIDE    0.240      STD6018FL SIDE R 0.216
STD8442FL SIDE     0.266      every CTR        0.500
```

`wr-deck.rb` now turns each SIDE panel so its bracket line faces out. Simulated
across the decks: the 7272, 6060, 6084 and 102102 are **unchanged**, and only the
96 series flips — both of its SIDE panels, at once, which is precisely the report.

This retires the `SIDE_R_SMALL_WALL_AT_LOW_END` plan in
`reference/floor-ceiling-geometry.md`. That was written when the only measurement
being attempted ran *along* the long axis, where L and R are genuinely
indistinguishable — the 6042 pair still reads 0.430 for both. Measuring *across*
the short axis is a different question and it does have an answer.

**Orientation is read off the FL part for both decks.** A convention-A ceiling
has nothing above its rim to measure and yields no cue; its floor twin always
does. That is the coplanar-hinges invariant used as a rule rather than a check.

### The other two were already fixed by the contact_z work

Confirmed against the real probe numbers rather than the doc's summary:

- **`STD9624CL CTR`** (1.7500 / 1.0000 / 0.0000, all over half the peak) fell
  into the `minor.empty?` branch, which returns `flip = false` unconditionally —
  so the part stayed as modelled, upside down. It now reads minor = 1.7500 above
  the slab and flips. **Fixed.**
- **`STD9648CL SIDE`** has its 1.0000 face at 45% of peak, under the old 50%
  threshold, so the slab came out as 0.0000/1.7500 and contact as 1.7500 instead
  of 1.0000 — 0.75 in high. **Fixed.**
- **`STD9624FL CTR`** carries a 6% lip at 0.0312 inside its slab, read as the
  room-side tell, flipping every floor centre panel. **Fixed.**

Worth noting the two ceiling parts also disagreed with each other: the SIDE
landed 79.64–82.75 and the CTR 81.00–84.11. That is the mismatch visible in the
screenshot, and both now land 78.89–82.00.

## 2026-08-14 — the narrow deck panel goes over the short wall, not at the end

Benton on the MDL 96120 S: *"It should have two 9648 side pieces, and then the
center piece. However, in all situations, the smaller ceiling would crossover in
one of the middle sections, on top of the 22 in wall."* Both halves of that are
now implemented, and the second half turned out to be derivable rather than a
preference.

`tile` is greedy — as many full-width panels as fit, remainder last — so the
96120 came out `48 + 48 + 24` with the narrow strip standing on the end wall and
only ONE 9648 SIDE panel in the deck. It should be `48 + 24 + 48`: two SIDE
panels with the 9624 CTR between them.

### The position is read off the wall layout, not chosen

Every booth in this group has exactly one short run in its long walls, and the
narrow deck panel bridges it:

```
96120   walls  46 | 22 | 46          short wall  50..72
        deck   48 | 24 | 48          odd tile    49..73   covers it
96168   walls  46 | 46 | 22 | 46     short wall  98..120
        deck   48 | 48 | 24 | 48     odd tile    97..121   covers it
```

So `order_cuts` places the odd tile at whichever index centres it on the short
wall run, and `short_wall_mid` reads that run out of the layout data. One rule,
nothing to tune.

**It reproduces both decks already confirmed correct.** The MDL 7272 S (48 + 24)
and MDL 6060 S (42 + 18) have their short wall at the high end, so the odd tile
stays exactly where greedy tiling already put it. Neither moves. That is the
check that the rule is right rather than merely convenient.

### Simulated across all 25 models against the real library

Seven reorder, and in every one the odd tile spans the short wall:

| Booth | Was | Now |
|---|---|---|
| MDL 96120 S | 48 / 48 / **24** | 48 / **24** / 48 |
| MDL 96168 S | 48 / 48 / 48 / **24** | 48 / 48 / **24** / 48 |
| MDL 102102 S | 42 / 42 / **18** | 42 / **18** / 42 |
| MDL 102144 S | 42 / 42 / 42 / **18** | 42 / 42 / **18** / 42 |
| MDL 102186 S | 42 / 42 / 42 / 42 / **18** | 42 / 42 / **18** / 42 / 42 |
| MDL 10284 S | 42 / 42 / **18** | 42 / **18** / 42 |
| MDL 84102 S | 42 / 42 / **18** | 42 / **18** / 42 |

The other 18 are unchanged — either a single tile, all one width, or the two
confirmed booths above. The 96120 now plans
`STD9648FL SIDE | STD9624FL CTR | STD9648FL SIDE`, which is what Benton asked for.

A knock-on worth noting: the end tiles now both ask for SIDE and get it. Before,
the 24 in end asked for SIDE, found none at that width, and silently fell back to
CTR — so the deck was short a SIDE panel as well as having it in the wrong place.

## 2026-08-14 — deck hand selection, and one part that needs exporting

> ### FOR BENTON, MONDAY
>
> **Export `STD7248FL SIDE R.skp` and `STD7248CL SIDE R.skp` into
> `P:\Sketchup\NewMasterComponentList`.** They are the only two files missing,
> and the MDL 7296 S is the only booth that needs them.
>
> A right-hand 7248 floor already exists in the old library —
> `P:\Sketchup\MasterComponentFolder\History\Floor component (7248 side right) as shipped.skp`
> and `…(7248 side right)  all hinges.skp` — so this is probably a re-export
> under the STD naming scheme rather than new modelling. There is no equivalent
> right-hand ceiling in History; that one may need making.
>
> Nothing else is needed. The code side is done and pushed.

**The bug Benton reported: the 7296 pulls SIDE L at both ends.** Confirmed, and
the cause is not what it looked like.

`WR_Deck.pick` took `handed.first` and ignored which end the tile was at — the
`at_low_end` argument was literally named `_at_low_end` and unused. The comment
justified it: the 72 series ships one hand per size, so there is no choice to
make. That is true of an **MDL 7272 S**, which tiles 48 + 24 and therefore draws
`STD7248 SIDE L` low and `STD7224 SIDE R` high no matter what `pick` does. It is
why the 7272 has always looked right, and it is why the dead code went unnoticed.

It is false for the **MDL 7296 S**, which tiles **48 + 48**. Both ends ask for a
7248, and only `STD7248 SIDE L` exists — so both ends got a left-hand panel, and
`substituted` was reported as `false` because there was only one hand to choose
from. A silently wrong deck that read as a clean build.

### The fix, and what it does and does not touch

`pick` now chooses **L at the low end, R at the high end**. That rule is read off
the two booths already confirmed correct, not chosen: the 7272 has SIDE L low and
SIDE R high, and the 6060 does the same with `STD6042 SIDE L` and
`STD6018 SIDE R`. Where only one hand exists, nothing changes.

**Orientation is untouched.** The half turn on the high-end panel stays exactly
as it was — that is the state confirmed on the 7272, and picking the file by end
and turning the panel by end are two independent rules that both happen to key
off position. Tangling them is the mistake that cost an evening; this does not
re-tangle them.

`substituted` now means what its name says — this end wanted a hand the folder
does not have — and it is pushed to the deck warnings so it prints.

### Simulated across all 25 models against the real library

| Booth | Was | Now |
|---|---|---|
| MDL 6084 S | `6042 SIDE L` \| `6042 SIDE L` | `6042 SIDE L` \| **`6042 SIDE R`** ✅ fixed |
| MDL 7296 S | `7248 SIDE L` \| `7248 SIDE L` | unchanged, now **reported** as a substitution ⚠ needs the file |
| MDL 7272 S | `7248 SIDE L` \| `7224 SIDE R` | identical — the confirmed booth does not move |
| MDL 6060 S | `6042 SIDE L` \| `6018 SIDE R` | identical |
| all other 21 | — | identical; their SIDE parts are unhanded |

So **6084 was the same bug but not the same fix**: `STD6042` ships both hands, so
the code change alone corrects it. **7296 is the only booth in the catalogue that
needs a part that does not exist.**

### Next

1. Benton: export the two `STD7248 … SIDE R` files (top of this entry).
2. Build `MDL 6084 S` — it should now come out with a genuine right-hand panel at
   the high end, and it is the check that the L-low/R-high rule is right.
3. Then 6060, 7296 and 96168 as already planned.

## 2026-08-14 — the E/W wall order is fixed, in ASSIGN rather than gen-booth.py

The big wall now sits at the door end on all four split-run booths. **7272 is
confirmed built correctly by Benton**; 6060, 6084 and 7296 are the same change,
unbuilt.

This closes the open item below, and it was done in `ASSIGN` in
`build-booth-components.rb` — **not** in `gen-booth.py` as that item proposed.
Swapping the two component names end-for-end leaves the generated layout
untouched and lets `rebalance_walls` do the work it already existed for: it
re-walks each wall from the real part widths, and `short + 2 + big` sums to the
same interior run as `big + 2 + short`. Simulated against the layout data, all
eight walls close on their original end with **0.00 in** error and the seam seal
shifts **+24 in** on every one of them — 46/22 on the 7272 and 7296, 40/16 on
the 6060 and 6084.

Two things worth keeping:

- **The tag has to follow the component, not the slot's `:sk`.** The swap puts a
  vent in a slot the layout data calls SOLID, so slot-kind tagging landed the
  vent on `WR-Booth-Walls` and a plain panel on `WR-Booth-Vent` — hiding the
  vent tag would have hidden the wrong part. Adding `:sk` as a *fallback* does
  not help either; it re-tags the very slots the swap emptied. The component
  name is always informative, because `guess_component` builds `<w>VNT` and
  `Right<w>Door` from the kind.
- **An unspecified vent stays unspecified.** 6060's relocated vent is written as
  `40VNT` — the exact name the guess already produced — not `40VNT_VSS`.
  Choosing VSS while moving a slot would be inventing a customer's choice.

6060 and 6084 list only their E/W slots; N and S fall through to
`guess_component`, which resolves to `40VNT`, `Right40Door` and `40PanelSolid`,
all confirmed present in `P:/Sketchup/NewMasterComponentList`.

### Next

1. Build `MDL 96168 S` — the deck confirmation still owed, and a useful control:
   its E/W is a symmetric 46+46, so the swap is a no-op there.
2. Build 6060, 6084 and 7296 to confirm the swap the way 7272 was confirmed.
3. `MDL 102126 S` is the EFS-vent regression check.

## 2026-08-14 — floors and ceilings, and a long detour

Floors and ceilings now build. `scripts/wr-deck.rb` reads the catalogue from the
folder, tiles each booth's footprint, and places the panels; all 25 Standard
models plan, and the three the quote repo's golden packing list confirms come
out identical. `reference/floor-ceiling-geometry.md` holds every measurement.

Getting there took far longer than it should have, and the reasons are worth
keeping.

### Two bugs that made everything else look inconsistent

**`unless defined?` froze every tuning constant.** Added in the morning to
silence "already initialized constant" warnings on reload. A constant IS defined
after the first load, so the guard skipped the assignment on every load after
it. Four separate constant changes were edited, committed, reloaded and had **no
effect whatsoever** — only a SketchUp restart would have applied them. Every
report that came back during those rounds was describing a build made with
values nobody chose, which is why the picture looked genuinely contradictory:
the same panel was "correct" and then "wrong" with nothing changing between.

Fixed with `remove_const` before each assignment, which updates on reload and
still avoids the warning. **`unless defined?` is only for something that must
never change in a session.**

**A `SyntaxError` made a script do nothing at all.** `Tools.run` rescued
`StandardError`; `SyntaxError` descends from `ScriptError`, so it escaped the
action callback, SketchUp swallowed it, and clicking the script was silent. Now
rescues `Exception` and says plainly when the failure is a syntax error. This is
the second time that distinction has bitten this plugin.

### Editing Ruby with a script broke three files

Twice by cutting at the wrong `end` — a non-greedy regex stopping at an inner
`if`'s `end` rather than the method's — and once by matching only the last line
of a three-line statement. The rule is not "write a better regex". **Do not edit
Ruby with a script.** Use the editor, one statement at a time, and read it back.

### What is actually measured

- Footprint `(exterior_w - 2) x (exterior_h - 2)`; the deck runs under the walls.
- Wall and door frame both sit on the floor's deck top, `z = 1.0`.
- Panel names are not sizes, and the packing list is the **packaged** part —
  3.25 there against 3.108 measured. Sizes come from the probe, never the list.
- `STD7224FL SIDE R` has a bounding box **13.938 in wider than its panel**, the
  only such part. Seating by the box put it 1' 1-15/16" out — the same "find the
  panel inside the part" lesson the wall builder already learned.
- Hinge gaps name the walls: **24.125** for the 46 in, **21.125** for the 22 in.
  Measured above the RIM, not the deck — measuring above the deck sweeps in the
  rim, which runs the panel's full length and merges every hinge into one span.

### The finding that matters, still unfixed

Every panel's 24.125 slot sits on its **low** half. The layout puts the big wall
on the **high** half for all four split-run booths — 6060, 6084, 7272, 7296.
**The panels are right and the layout is backwards**, which is what Benton
reported independently: the window belongs nearer the door.

That is a `gen-booth.py` fix and it moves walls, so it was left for its own
change. `big_wall_fraction` and `layout_big_on_low?` are in `wr-deck.rb`,
deliberately unused, and become the check that proves it once the layout moves.

### Where the deck stands

`7248` at the low end not turned, `7224` at the high end turned, ceilings
flipped by `contact_z`. That is the state Benton called "almost perfect". I broke
it by answering a report about three panels with a blanket change that also
undid the one already confirmed correct — restored in `b6aa682`.

### Next

1. Confirm the restored deck on `MDL 7272 S`, then `MDL 96168 S`.
2. ~~Reverse the E/W wall run order for the four split-run booths in
   `gen-booth.py`, so the big wall sits against the door end.~~ **Done** in
   `ASSIGN` instead — see the entry at the top of this file. Do not redo it in
   `gen-booth.py`, or the two reversals would cancel out.
3. `DECK_TOP_Z` is 0.0, so the floor hangs below the wall base rather than the
   walls rising to sit on it. Physically the walls should rise — one commit,
   both changes, or they float.

## 2026-08-13 — material merge, script renaming, and where to pick up

**`scripts/merge-materials.rb`** (new). Imported components arrived carrying
their own copy of the fabric material, so a colour change would have had to be
made twice. This points every face front, face back, edge, instance and group —
at any nesting depth — from one material onto another and deletes the emptied
one, in a single undoable operation, verifying by re-counting afterwards rather
than trusting its own tally.

It took three passes to get right, and the two failures are the useful part:

1. *"Nothing matches Carpet Plush Charcoal"* while the tray had exactly that
   selected. A material has **two** names — `Material#name` and
   `Material#display_name` — and they diverge for imported materials. The tray
   shows one; the API was matching the other.
2. *`TypeError: reference to deleted Material`*, which rolled back a merge that
   had already correctly repainted **39,918** assignments. A `Material` is a
   live handle, not a copy: the instant `materials.remove` succeeds, every
   reader on it raises. The removal loop logged `m.name` *after* the remove, the
   rescue raised again building its own error string, and the outer handler
   aborted the operation over a bookkeeping message.

Both fixed, and the dialog was then rebuilt around **dropdowns populated from
the model** — each entry showing its live use count, most-used first — so a name
can no longer be got wrong in either direction. "Also merge others whose name
starts the same" replaces the wildcard, which is exactly how SketchUp
uniquifies an imported duplicate.

**`save-scene-components.rb`** gained an off-by-default, undoable option to
rename each component in the model to match its saved file, so a file named
after a scene stops containing "Component#41". Stated plainly in the header:
SketchUp offers **no two-way sync** for external components in either
direction. What renaming buys is right-click → Save As offering the correct
filename.

**The plugin** got mappable toolbar slots (script + icon chosen separately from
a 47-icon library), in-panel script renaming, and a fix for the panel's slot row
disagreeing with the real toolbar — two different fallback rules for one slot,
now resolved once in Ruby and shipped to the panel.

### Where to pick up

1. **Re-shoot the component library.** The material lift means every previously
   exported image reads dark beside a new one. Settings that worked: scenes
   `1-5,40`, view height **104**, style **Interior**, Dark **45**, Recover
   **Yes** — the same style and Dark in *both* exporters.
2. **`merge-materials.rb` has still never completed a real run.** The dropdown
   rebuild is unrun; first run should be a dry run.
3. **`selector2._domainkey.whisperroom.com` has no key.** Microsoft signs with
   selector1 so mail is fine, but the standby rotation key is missing — Defender
   portal → Email authentication settings → DKIM, rotate once. Same action
   upgrades the 1024-bit key to 2048. HubSpot is fully authenticated and
   verified; nothing to do there.
4. **DMARC `rua` goes to two personal mailboxes as raw XML.** Point it at a free
   aggregator, then move `p=quarantine` to `p=reject` once the reports are clean.
5. Still open from before: floors and ceilings (components not exported yet),
   Enhanced walls (all 25 E variants skip with "panel lengths unresolved"),
   furniture, and `.rbz` packaging for the team.

## 2026-08-12 — the fabric material was lightened ~1.47x

Benton's call, and the right one. The component library rendered at a mean luma
of **48.8 / 255** — 19% of full scale — so every downstream use (assembly manual
covers, proposals, the booth builder) needed a rescue lift, and the flat set
already carried a hand-applied gamma correction of unknown size.

Lightening the **texture bitmap** fixes every consumer at once, with no post-pass
and no risk of double correction, and it is visible while working in SketchUp.

Measured before and after, same part, both exporters:

| | before | after |
|---|---|---|
| overall mean luma | 48.8 | **72.3** |
| p99 | 120 | 144 |
| max | 238 | **216** — nothing clipped |
| flat shading (`blur_std`) | 7.5 | **14.1** |
| flat shading ÷ grain | 0.43 | **0.97** |

The lift came out uniform — flat ×1.47, angled ×1.44–1.48 — so the two sets kept
their relationship. Shading improved *more* than proportionally, because
multiplying luma multiplies the differences between faces too; that is what the
jump in legibility actually is.

**Headroom left:** another ×1.25 would still clip nothing. Stopping at 72 is
deliberate — real charcoal fabric photographed in a lit room sits around 60–90,
so this is close to accurate, and going further reads as medium grey rather than
charcoal, which is a product-appearance question rather than a technical one.

**A trap that turned out not to be one**, recorded so nobody re-raises it:
`fix-angled-alpha.py` only recovers a file whose `rgb_max <= 70`, which looks
like it could start silently skipping as the material gets brighter. It cannot.
The composite is `out = 0.25 * src` and `src <= 255`, so `out <= 63.75` no matter
how bright the source is. The threshold is safe at any material brightness.

**Consequence:** every previously exported image in the library is now out of
date and reads dark beside a new one. The whole set needs re-shooting.

## 2026-08-12 — one shading contract for both component-art exporters

The flat walk-around set and the angled Iso30 set are shown side by side in the
booth builder, and the flat set came out visibly lighter. Three causes, two of
them fixable in code:

1. `export-component-art.rb` **activates** each scene, so each scene's stored
   style applies; `angled-component-art.rb` never activates a scene, so it
   renders under whatever style the viewport holds. Same model, two styles, no
   warning — the same root cause as the missing-edge-lines batch.
2. The angled exporter ran the brightness recovery pass. The flat one had **no
   recovery step at all**.
3. Face-normal shading. A flat elevation puts the face perpendicular to the
   camera; an Iso30 puts every visible face oblique. That one is geometry, not
   a bug, and lightening the material would fix the iso and blow out the
   elevation — the material is shared.

`scripts/wr-shading.rb` is now the single contract both `load`: the
transparency keys, a named-style selection, and `DisplayShadows` /
`UseSunForAllShading` / `Light` / `Dark`, every one written and **read back**.
Both scripts gained a **Style** and a **Shadow Dark** field defaulting to the
same value, and both print `WR_Shading.describe` so a mismatch is a diff of two
console blocks rather than a judgement about which image looks lighter. The
flat exporter now runs `fix-angled-alpha.py` too.

`Dark` is the lever for cause 3: it lifts unlit faces toward lit ones without
touching the material. Both default to 45 (SketchUp's own), so turning the
contract on makes the two exporters **identical first**; raise Dark toward 70 in
both to close the remaining gap. The Light/Dark values are a starting point, not
a measurement — none of this has been rendered.

## 2026-08-12 — mappable toolbar slots and a 47-icon library

The toolbar's eight buttons were eight identical numbered stars. They are now
customisable slots, Word-ribbon style: each holds a script AND an icon, chosen
independently in the panel's new TOOLBAR row.

**Why the previous attempt failed, which is the useful part.** `FAV_ICONS`
already mapped five scripts to their own faces, and `refresh_fav_labels`
assigned `cmd.small_icon` at load — yet every button still showed a star.
`UI::Command` uploads its bitmap to the native toolbar when the command is
*created*; assigning `small_icon` after `UI::Toolbar#add_item` does not
reliably repaint. So the icon is now read from preferences and set **before**
the command is constructed. The consequence is honest and stated on screen: a
re-pointed slot runs the new script immediately, but a new *face* appears at
the next SketchUp launch.

- `scripts/make-icons.py` writes 47 `wr_tools/ico-*.svg` — booth, door, window,
  vent, wall, floor, ceiling, ramp, seal, link, cube, dimension, elevation,
  camera, export, gear and so on — from one shared frame, so stroke width and
  colour cannot drift between them. It also writes `ico-labels.txt`.
- The plugin **globs** `ico-*.svg`. Adding an icon is dropping a file in; no
  edit to `main.rb` and none to `panel.html`.
- Storage: two pipe-joined lists of exactly `PIN_N` entries, `slots` and
  `slot_icons`, positionally aligned with `-` for an empty slot — `read_list`
  drops empty strings, so a real blank needs a placeholder or every later slot
  shifts up one. The old flat `pinned` list migrates on first read.
- The panel's star still works: it means "first free slot", no icon chosen.

## 2026-08-11 — booths from real components, booths from links, plugin redesign

**The headline: paste a booth-builder share link, get that customer's exact
booth built from real components.** Both link forms work — `?d=<id>` fetches
`/api/booth-design/<id>` from the link's own host, `#d=<base64>` decodes
locally — verified byte-identical on a real pair. Furniture (desk, MJP) and
roof vents are reported as out of scope rather than dropped.

**`build-booth-components.rb`** places the actual `.skp` components from
`P:/Sketchup/NewMasterComponentList` into the layout slots. Every rule is
measured per part, never tabulated, and each was earned the hard way:

- *Orientation*: axes classified by extent — height ≈ 81/91, width larger of
  the rest — with a retry that swaps width/thickness when the panel search
  fails (the WA ramp door projects 60" out of a 49" frame and fooled the guess).
- *Placement*: by the WALL PANEL found inside each part (tall faces, widest
  cluster), never the bounding box — an EFS silencer widens a part sideways by
  10"+ and a leaf swings 32" out. Panels flush to corners; thin parts centred
  in their band (HX's 1.125" H-strip stays symmetric); seals centred; parts
  top-aligned so vent fans hang below the wall line.
- *Facing*: the floor rule (below-the-wall geometry stands on the host floor,
  which is outside) outranks a bulk vote, which outranks the convention. Doors
  point their leaf inward; WA doors and everything with below-wall geometry
  self-orient. VSS/EFS vents carry bulk on BOTH sides, so only the fan is a
  reliable witness.
- *Wide access*: walls re-derive from real part widths when they disagree with
  the layout slots — the seal beside a 49" WA frame shifts 3" (46-series) or
  9" (40-series), emerging from the walk rather than hard-coded.
- The console table prints slot/part/fit/panel/facing plus raw facing votes
  per thick part. FIT shows the signed number, not a pass mark.

**`gen-booth.py`: E/W walls now run north→south**, matching the portal's own
renderer (`layout-render.js`) — they ran south→north, mirroring every E/W wall
in the catalogue. `wr-booth-data.rb` regenerated (also picks up the upstream
"96168 never had a 28-inch vent" fix). All 25 Standard booths resolve every
slot against the component folder, standard and HX.

**The measurement pass that made it possible:** `probe-components.rb` loads
all 182 component files and measures extents, origins, anchors. Findings that
drove the design: origins are inconsistent (73/182 at a corner) so placement
must use bounding geometry; `_HX` = 91" panels (+10", not the Enhanced
variant); panels measure their names to 0.02"; vent fan drop is identical
between standard and HX.

**New tools:** `elevation-export.rb` (axis views at ONE shared scale per run —
auto is per-run-consistent, typed survives re-runs), `list-scenes.rb`
(numbered scene table), `find-replace-names.rb` (preview-first rename across
scenes/definitions/tags/materials, collision-refusing, one undo),
`save-scene-components.rb` (each scene's component → its own .skp),
`booth-from-link.rb`, `combine-ao.py`.

**Angled Component Art:** batch 4 (all four cameras, every scene); style
selectable BY NAME from the model's styles (the exporter never activates
scenes, so scene styles never applied — that was the missing-edges mystery);
"Bold edges" override; and a two-pass **Viewport shading (AO)** option —
transparent shot for alpha, opaque AO shot for colour, married by
`combine-ao.py`. Interior edges are engine-fixed at 1px; judge exports at 100%.

**wr_tools redesigned:** one surface, one search over scripts AND abilities,
favourites as pills, scripts grouped by `# @cat` headers (untagged one-offs
sink to MORE SCRIPTS), per-script SVG icons on toolbar and pills, and the
command bar accepts a pasted booth-builder link directly.

**The trap that started the day:** `Sketchup.read_default` EVALS its stored
string and `write_default` doesn't escape quotes — a JSON favourites list
raised SyntaxError (not a StandardError!) at load and took the extension down.
Preference lists are now pipe-joined, quotes stripped on write, Exception
rescued with self-healing. Every new script carries the same guard.

### Next steps (tonight, desktop)

1. `git pull`, then `python scripts/install-plugin.py`, restart SketchUp.
   Desktop repo path differs (see CLAUDE.md); the plugin resolves it.
   Components live on `P:` — confirm the desktop sees that share.
2. **Floors and ceilings**: export the components (save-scene-components),
   probe them, then wire the datum shift — walls up by the floor lip, fans
   stay at host-floor zero (documented in build-booth-components.rb).
3. **Enhanced walls**: Benton authors combined components (exterior + interior
   wall + foam grouped, relationship baked in). Separately: solve the E run
   rule in gen-booth.py — all 25 E variants still skip. Panel finder needs a
   prefer-outermost-slab tweak once two same-width tall slabs exist in one part.
4. If any facing still misbehaves: the console votes table is the data —
   paste it rather than iterating by screenshot.
5. Team hand-off: .rbz packaging decision pending (Python dependency, P: path,
   personal defaults). Pilot with one teammate first.

### Open decisions

- Angled art style for batch 3+ (named style vs Bold edges vs AO two-pass) —
  test batch 0 first; the viewer team must be told if the look changes.
- Panel category names/splits are one-line edits if the taxonomy feels wrong.

## 2026-08-06 (night) — the room tools, exploded views, and docs in the repo

**`auto-dimension.rb`** chain-dimensions a room off its **interior floor face**,
so the dimensions can never disagree with the geometry. Three things it refuses
to get wrong, all three of which are in `reference/sketchup-drawing.md` as
having cost time already: winding is **computed** from the signed area rather
than assumed; chains must close, reported per axis, and it prints
`DOES NOT CLOSE` instead of drawing a plausible wrong number; chain lines carry
segment lengths only, never running totals. Doors come off the `WR-Doors` tag —
a gap in a wall might be a modelling mistake, a tagged door is a stated fact.

**`build-room.rb`** is the take-off editor. Direction-and-length runs, live
polygon and closure, and **Build stays disabled until it closes**. Walls build
outward from the interior polygon and mitre by intersecting adjacent offset
edges. Doors split the run with a header over the gap and the leaf drawn open
90 degrees.

One non-obvious detail: the opening marker sits in the wall plane on
`WR-Doors`, and the leaf and swing go on `WR-Doors-Leaf`. A leaf swung 90
degrees has bounds reaching into the room, and `auto-dimension` reads bounds to
find the jambs — on one tag it would have produced wrong jamb dimensions.

It finishes by calling `auto-dimension`, which is why that was built first.

**`proposal-scenes.rb`** creates the five plates in order, each holding its own
camera, tag visibility and style, so `02-dimensioned` shows `WR-Dims` and the
other four hide it. Door and vent sides are **read** from the `WR-Booth-Door`
and `WR-Booth-Vent` tags `build-booth.rb` already writes. The angles are
defaults, and the script says so — framing is a taste call, the ordering and
per-scene tag state are the parts worth automating.

**`explode-view.rb`** pulls an assembly apart and puts it back. Each part
records its home the first time it moves, so a re-explode measures from home
rather than compounding, Reset is exact, and the homes save with the model.
Default is **one axis per part** — whichever it is already furthest along — so
panels come straight off their walls. Radial drift looks acceptable in a
viewport and wrong on a printed page, which is the only place it matters.

**Plugin:** scripts can now be **starred to pin** them to the toolbar. Buttons
appear next launch, not immediately, because `UI::Toolbar#add_item` has a known
severe slowdown on Windows when the toolbar was docked in a previous session
(api-issue-tracker #628). The panel says so on screen. For an instant shortcut,
Window > Preferences > Shortcuts binds a key to any script's menu item.

**`docs/` is new.** The four design pages that were living only as Artifacts are
now in the repo, wrapped as standalone documents that open straight off disk.
They hold reasoning that is not recoverable from the code — why the jig prints
socket-up, why chains must close before anything is built — in a form you can
poke at rather than read.

**Still unrun.** Nothing in `scripts/` has executed. `rbcheck.py` says all 14
Ruby files balance and the two dialogs' JavaScript parses; that is the whole of
what is verified.

## 2026-08-06 (late) — orbit exporter, and what the manual actually is

Benton's target for the assembly manual is now clear and it is bigger than a
generic manual: **a manual generated from a customer's own Booth Planner
configuration.** Press a button, pull that design into SketchUp exactly as the
customer specified it, and produce step-by-step assembly for that booth.

**Most of the front half already exists and nobody wrote it down.**
`booth-builder.html` encodes a design as base64 JSON in a `#d=` URL fragment,
and `gen-booth.py --design "<link>"` already decodes it and solves the panel
geometry. So the path is:

```
booth-builder #d= link
  -> gen-booth.py --design      EXISTS
  -> wr-booth-data.rb           EXISTS
  -> build-booth.rb             EXISTS  (25 Standard booths build today)
  -> orbit-export.rb            NEW, below
  -> manifest.json              NEW, written by the exporter
  -> the manual                 not built
```

**`scripts/orbit-export.rb`** is the new piece. It photographs a part — or every
part of an assembly, isolated one at a time — from every angle in one run, and
writes a `manifest.json` describing what came out.

The design decision that matters is **constant scale**. `zoom_extents` reframes
every shot, so a part would change size as it turns and two parts on facing
pages would not match. The camera instead uses parallel projection with a view
height computed once for the whole run from the largest part's bounding
diagonal — the diagonal rather than the width, because a part's widest
silhouette as it turns is its diagonal. "Each part fills the frame" is offered
as an alternative, and the console says plainly that it is wrong for any step
showing two parts together.

Style is deliberately left alone. Set edges, shading and hidden-line in
SketchUp before running; the script only forces ground, horizon and fog off so
transparency works, and restores them. Guessing at rendering-option keys was
not worth the risk.

The manifest is the contract: part, slug, size, and every frame with its
azimuth and elevation, plus a null `step` to fill in for assembly order.
Nothing downstream needs to know SketchUp exists.

### Also fixed: the generators were laptop-only

`gen-booth.py` and `gen-booth-models.py` hard-coded
`C:\Users\bento\Documents\Claude\...`, which does not exist on the desktop —
the same redirection problem the plugin had. Both now resolve the workspace
root, with `WR_CLAUDE_ROOT` as an override, and write relative to their own
location. Verified: all four paths land on real files here. Without this,
`gen-booth.py --design` — the front half of the button — could not run on this
machine at all.

## 2026-08-06 (late) — the plugin gets a panel

**The menu could never have worked the way it was meant to.** SketchUp has no
API for removing or rebuilding a menu item once added, so "Reload Scripts" was
only ever able to pop a message box explaining that a restart was needed. For a
folder we add scripts to constantly, that is backwards.

`wr_tools` now opens a **`UI::HtmlDialog` panel** instead. It rescans `scripts/`
every time it opens or you hit Rescan, so a new file is one click away with no
restart and no reinstall.

- **Newest first.** Sorted on file mtime, with a NEW pill on anything touched in
  the last 24 hours. The script being worked on is nearly always the one to run.
- **Type to filter**, arrow keys to move, Enter to run. Matches on title, file
  name and blurb.
- **Recent chips** across the top, five deep, persisted in `Sketchup.write_default`.
- Each row shows the script's `@title`, the comment paragraph under it as a
  blurb, the file name and how long ago it changed — all parsed from the header,
  so a script documents itself in the launcher by being commented normally.
- Toolbar cut from seven buttons to three (Panel, Folder, Console) with **SVG
  icons**, which stay crisp at any toolbar size. The old PNGs remain as a
  fallback so a partial install shows buttons rather than blanks.
- The menu is kept, still frozen at load time, as a fallback.

**`scripts/rbcheck.py` is new.** There is no Ruby interpreter on either machine
outside SketchUp, so nothing in `scripts/` gets syntax-checked before it reaches
the Ruby Console. It is not a parser — it strips strings, heredocs and comments
and matches block openers against `end`, which catches the one error that
actually happens when hand-editing a long file. Run `python rbcheck.py` in
`scripts/`. All 9 files currently balance.

Worth knowing about it: the first version flagged `build-booth.rb` and
`tube-drying-stand.rb`, and both were **false positives** — it did not know that
`dir = case axis` opens a block. Fixed. A checker that cries wolf is worse than
no checker.

### Next, for the dynamic assembly manual

Benton's direction for this workspace is mass component photography at many
angles, feeding a rebuilt assembly manual. Nothing below is built yet:

1. **Orbit exporter.** `export-scenes.rb` only exports scenes that already
   exist. The manual needs N angles per component without hand-making N scenes:
   drive `Sketchup::Camera` round a component's bounding box at a set azimuth
   and elevation step, `write_image` each stop, name them predictably.
2. **Exploded views** driven off the tag structure the fixtures already use.
3. **A manifest** — a JSON sidecar naming every image with its component,
   azimuth and elevation, so the manual can be generated from data rather than
   by hand-placing pictures. This is the piece that makes it *dynamic*.

## 2026-08-06 (evening) — pendant fixtures

A side project, not WhisperRoom: 3D-printed fixtures for the pendant line.
Both are parametric, both print without supports, and both self-audit to the
Ruby Console on every run.

**`scripts/pendant-jig.rb`** — holds the metal housing square and centres the
polycarbonate tube in it while the adhesive cures. Ø15.29 socket × 18 deep,
Ø9.90 tube guide × 36, one lathed solid, 57.50 tall, ~18 g. Holds the tube to
0.40° / 0.375 mm over its length.

Two things went wrong on the way and are worth remembering:

- **`follow_me` left the rims cracked.** A revolve has to close back on itself
  and SketchUp does not reliably weld that seam. Rebuilt as an explicit
  `Geom::PolygonMesh` whose last column of quads wraps to column 0 by index, so
  there is no seam to fail. **Every solid now reports its naked-edge count** —
  that check is what should have caught it, and it costs nothing.
- **The first version printed the wrong way up.** Flange-down made the shoulder
  the housing registers against an unsupported ceiling over the socket, which
  is the one surface whose flatness decides whether the housing sits square.
  It prints socket-up. That drove the 45° flange underside, the lead-in, and
  the guide-mouth chamfer.

**`scripts/tube-drying-stand.rb`** — 60 tubes upright while epoxy cures. 10 × 6
pockets, 123.50 × 74.90 × 31.50, ~94 g. Rev B added 136 diamond openings and
dropped the seven under-ribs for four corner pads once it was clear the thing
prints inverted. Worst-case lean 1.62°, which is a ceiling rather than an
expectation — a 54 mm tube on a 9.65 mm base self-rights, and would need 10.1°
to topple. **Cut-end squareness is the likelier dominant error**; measure a
tube against a square before spending print time on a deeper pocket.

**`reference/3d-printing.md`** is new and carries the printer (Dremel 3D45),
the sourced overhang and bridging limits, the two slicer settings that are not
the defaults, and the design rules that follow. Read it before changing either
fixture's geometry.

**Nothing here has been printed yet, and no script has been run.** Clearances
are all built on the 0.25 mm allowance and are unconfirmed. Print the jig
first — an hour and 18 g calibrates that figure before the stand's 94 g.

## 2026-08-06 (later) — desktop brought online

**Repo cloned to the home desktop** at
`C:\Users\bento\OneDrive\Documents\Claude\Sketchup\WhisperRoom-SketchUp\`. Documents is
redirected into OneDrive on this machine, so the laptop's `C:\Users\bento\Documents\Claude\`
does not exist here.

**Plugin made machine-independent.** `wr_tools/main.rb` hard-coded
`C:/Users/bento/Documents/Claude/Sketchup/scripts`, which resolves to nothing on the desktop.
It now walks a `CANDIDATES` list (both Documents roots × both repo layouts) and takes the first
that exists, with a `WR_SCRIPTS_DIR` environment-variable override for a new machine.
`install-plugin.py` likewise no longer requires `%APPDATA%\SketchUp` to already exist — a
SketchUp that has never been launched has no profile folder, so the installer now detects
installed versions from Program Files and creates the Plugins folder itself.

**Installed and verified on the desktop.** SketchUp 2024, `wr_tools.rb` + `wr_tools\` in
`%APPDATA%\SketchUp\SketchUp 2024\SketchUp\Plugins\`. The resolver was run against this
machine's filesystem and picks the OneDrive clone; 4 scripts will appear on the menu
(`booth-4260-s`, `build-booth`, `csusb-rooms`, `export-scenes`). The menu itself is unverified
until SketchUp is launched.

**Sibling repos on the desktop.** `WhisperRoomQuote` was already present. `whisperroom-proposals`
cloned to `<CLAUDE>\WhisperRoom Proposals\`.

### Still missing on the desktop — needs a push from the laptop

These are referenced by `CLAUDE.md` but are not in any branch of any repo on GitHub, so they
exist only on the laptop:

- `WhisperRoom Proposals\build-v2.js` and `examples\<client>\proposal-v2.json` — the
  `whisperroom-proposals` repo on GitHub is still the single-commit **v1** system (`build.js`).
- `WhisperRoomQuote\tools\sketchup-scene-export\` — never committed on any branch.
- `Desktop\ProposalFiles\` and `Desktop\WhisperRoom\` (brand guideline, historical drawings) —
  local-only by design; copy them across manually.

## 2026-08-06

### Done

**Workspace set up.** Repo created and pushed — `bentonwhiteWR/WhisperRoom-SketchUp`,
private (it carries internal pricing). `CLAUDE.md` plus `reference/` hold the rules;
`scripts/` holds the working tools.

**CSUSB job, start to finish.**

- Took off both rooms from the client's PDFs: Chaparral **117 = 51'-4" × 48'-3"** (2,013 sq ft
  net) and University Hall **056 = 25'-3" × 13'-4"** (274 sq ft), every in-line wall run
  dimensioned, all chains closing within ¼".
- Found **Room 117's printed scale is wrong** — the sheet says 1" = 30'-0" but the scale bar
  works out to 1" = 30'-10½". The bar is right; the sheet was reduced on export.
- Read the site photos: 117 is an **active dance studio on a raised sprung floor** (weight
  question for a 1,798–3,100 lb booth) and 056 has a **suspended lay-in ceiling in a basement**,
  which is the likeliest dealbreaker on that room.
- Delivered **`Desktop\ProposalFiles\CSUSB\CSUSB-Booth-Renderings.pdf`** — 23 pages, four
  configurations, 3.09 MB, verified page by page.

**Proposal rules corrected.** The shipped format is **US Letter portrait**, not the landscape
layout `PROPOSAL-GUIDELINES.md` describes. That doc is superseded; `reference/proposal-brand.md`
now matches the David Smith pack, which is the standard.

**SketchUp automation built.**

- `wr_tools` plugin — **Extensions > WhisperRoom** menu and toolbar, auto-discovering every
  script in `scripts/`.
- `csusb-rooms.rb` — both rooms to the measured interiors, mitred corners, doors with swings,
  dimensions on all four sides.
- `export-scenes.rb` — batch scene → PNG into `Desktop\ProposalFiles\ImageExports`.
- `build-booth.rb` + `gen-booth.py` — **all 25 Standard booths** from a dropdown. Panels 1"×81",
  mid-wall seam seals as single T solids, corner seals as single L-with-notch solids including
  the 1"×1" inside block, finished in Carpet Plush Charcoal.

**The assembly rule, confirmed and implemented:**

```
interior wall run = sum(panel lengths) + 2" per joint
```

The 2" is the mid-wall seam-seal stem. It also explains both errors in
`booth-layouts.json` — the 4872's "24" is a 22 with its seal absorbed, the 96120's "47+47" is
really 46+seal+46. `components-master.json` holds **shipping** sizes, never finished geometry.

### Next steps

1. **Settle instance-vs-model.** Open `BoothBuilderV2.skp`, run in the Ruby Console:
   ```ruby
   Sketchup.active_model.definitions.map { |d| "#{d.name}  (#{d.count_instances} used)" }.sort.each { |s| puts s }
   ```
   If real component definitions exist, we instance them instead of modelling doors, vents and
   windows — and the booth-builder share link goes live immediately. If not, we model those
   three features ourselves. **This decides the next chunk of work; do it first.**
2. **Ceiling panels** — need finished dimensions from Benton, same as the wall panels.
3. **Booth-in-room placement** — put a built booth inside a built room against the clearance
   rules (1" nominal, 10" vented with silencers, 45.625" ADA ramp). Produces the dimensioned
   top-down plate.
4. **Scenes and cameras** — five standard views named in plate order, feeding `export-scenes.rb`
   and then `proposal-v2.json`.
5. **Enhanced variants** — 25 more booths. Booth-inside-a-booth with a gap; only needs the gap
   dimension.

### Open decisions

- **"Inside dimension" — clear or panel-face?** Benton's 4260 note says the 40" side has a 38"
  inside dimension. The data says 40. The corner seals' 1"×1" blocks intrude 1" at each end,
  which is exactly the 2". If clear-between-corners is the number that matters, say so and both
  figures get reported.
- **`models.json` 4260 depth** lists 5'-8" (68") where `booth-layouts.json` says 62", and 62 is
  what the model number implies. One of them is wrong, and `models.json` is what the quote tool
  prices from.
- **CSUSB, with the client:** ceiling height in both rooms, the ADA raised-floor height (adds on
  top of the 7'-1"), and which wall in 117 the booth goes on — Maxine named it by photo, not
  compass.
- Two Enhanced renders disagree on the vertical callout — 7' 5/16" vs 7' 1". Resolved as
  exact-vs-marketed, but worth knowing the pack shows the exact figure.

### On another machine

```
git pull
python scripts/install-plugin.py     # then restart SketchUp
```

Only `wr_tools` needs installing. Everything else in `scripts/` is read live from the repo, so
edits take effect on the next click with no restart.

---

## 2026-08-07

### Done

**Plugin rebuilt around abilities and favourites.** The panel now has two tabs.
**Abilities** are on/off toggles that undo what they do — Exploded, Dimensioned,
Proposal scenes, and a built-in Reference geometry tag toggle. They are declared
in each script's own header (`@ability`, `@setting`, `@on`, `@off`), so a new one
needs no plugin edit. State lives on the model, so it survives save and reopen.
**Favourites** now appear both as a strip in the panel and as eight numbered
toolbar buttons. The toolbar slots are created once at load and resolve the pin
list at click time, so starring rebinds a slot immediately — the old behaviour
needed a restart and read as broken.

**Five exporters, each with a dialog and a scene/component selector**
(`all` / `current` / `1-7,12` / text):

- `export-scenes.rb` — proposal plates, opaque, folder browser
- `export-component-art.rb` — every scene, transparent, manifest, HX suffixing
- `export-this-view.rb` — one-off, settings seeded from the batch exporter
- `angled-component-art.rb` — the Iso30 library, four parallel cameras
- `merge-scenes.rb` — import a .skp and rebuild its scenes at the new offset

Filenames are now the scene name **verbatim**; only characters Windows forbids
are replaced. They used to fold spaces to hyphens.

**Design sheets are now the standard deliverable** for anything we design.
`reference/design-sheet.md` is the spec; `docs/tube-drying-stand.html` and
`docs/pendant-jig.html` are the exemplars. Both carry a live WebGL view.

- Drying stand → two 5x6 stands, 60 tubes, fits a 92x135 silicone tray.
- Pendant jig Rev B → tube bore Ø10.10, socket 6.50, flange 3.50, total 46.00.
  Hand-held: 9.00 of housing left proud to grip.

**Bohn Music Academy** take-off and proposal. Room 635¼ x 336½, ~27 ft ceiling.
8-page PDF delivered to `Desktop\ProposalFiles\Bohn Music Academy\`.

### The one that cost the most time

`view.write_image` came back dark with a broken alpha channel. Four confident
explanations were wrong (ambient occlusion, watermark, shading, an open editing
context). The cause, proven from pixel values rather than reasoning:

**SketchUp 24.0.553's new graphics engine composites a uniform 75% black layer
over everything write_image produces, in colour AND alpha.**

    out_rgb   = 0.25 * src_rgb
    out_alpha = 191.25 + 0.25 * src_alpha

A wireframe export contains only the values {0, 4, 8 ... 64} — multiples of four
capped at 255 x 0.25. The Classic engine exports correctly but renders chrome as
flat black, which is worse because it is not recoverable. So: keep the new
engine and undo the composite. `scripts/fix-angled-alpha.py` does it, and the
angled exporter runs it automatically.

**`rbcheck.py` cannot catch a syntax error or an undefined variable.** It counts
block keywords. It reported "balanced" on a file with a `rescue` modifier inside
a subscript assignment (which never parsed) and on one referencing a deleted
variable. Treat a clean run as "blocks balance", nothing more.

### Next steps

1. `python scripts/install-plugin.py`, then **restart SketchUp** — the eight
   favourite toolbar slots only appear at load.
2. **Nothing in `scripts/` has a confirmed run except `tube-drying-stand.rb`.**
   The abilities, the four exporters and `merge-scenes.rb` are all unrun.
   Cheapest first: open the panel, toggle **Reference geometry** (no script, no
   selection — it isolates the ability framework from the scripts).
3. Angled library: run Batch 1 as a **dry run**. The diagnostics file lists every
   scene label against the component it resolved to. That table is what is needed
   to write the scene-label → `Component_…` mapping, which is still missing —
   files currently come out `LeftWADoorWithRamp_…`, the importer wants
   `Component_WADoorWithRamp_…`.
4. Pendant jig and drying stand are both **unprinted and the scripts unrun since
   the last edits**.

### Open decisions

- Angled set: frame on the part (fills the canvas) or on the insertion point
  (clean registration, half the canvas)? Currently part-centred.
- Bohn: booth model still not chosen — waiting on the quote link. The column on
  the door wall has no dimension at all and sits where a booth would go.
