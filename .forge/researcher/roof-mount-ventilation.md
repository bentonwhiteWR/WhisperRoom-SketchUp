# Roof-Mounted Ventilation (RM) — what exists, what is missing, what the work is

Researcher, 2026-08-31. Read-only. Nothing was built, no model was opened or queried.

Provenance words are the Manual's: **observed / derived / reported / assumed**.

---

## Question

Benton wants roof-mounted ventilation (RM) implemented in the "build booth" scripts and in
the booth-builder copy-link path. Establish what exists, what is missing, and what the work
actually is. In particular: (1) do the RM components exist as usable assets, and (2) what
does the "RM turns vent walls into cable walls" rule really touch.

---

## Answer, short

1. **The components exist as `.skp` files on disk, today.** 76 `RM*.skp` files sit in
   `P:\Sketchup\NewMasterComponentList` — not just as scenes in Benton's open model
   (**observed**, directory listing). Most carry a 2026-08-31 22:42 timestamp, so this is
   fresh work of his, but it is *exported* work, not work still trapped in a model.
   The elevation **art already exists too**, in `WhisperRoomQuote\assets\booth-art\`
   (32 `rm-*.webp` files, **observed**). Nothing needs re-exporting to start.

2. **The VNT→CBL substitution is already implemented — in the portal, not in Ruby.**
   `booth-builder.html`'s `applyRoofVent()` rewrites every `... VNT` pack to `... CBL`
   *before* the payload is serialized. So a share link from an RM design already carries
   `STDWL46 CBL` in its `a` map. Our Ruby does not have to perform the substitution
   (**observed**, `WhisperRoomQuote\booth-builder.html:3180-3188`, `:2884-2890`).

3. **There is a live, silent, wrong-booth defect on that exact path.**
   `scripts/booth-from-link.rb`'s `component_for` has **no `CBL` branch**. A `STDWL46 CBL`
   pack returns `nil`, the slot is left unassigned, and `build-booth-components.rb` then
   fills it from the layout's own `:sk`, which for that slot is `'VNT'` — composing
   `46VNT`. **An RM link builds a booth with vent walls today**, while printing
   "rv: roof-mounted vent (out of scope per GOAL)" as if nothing else happened. That is
   precisely the "half-applied RM" failure, and it is reachable from the portal now.

This is closer to a **day or two** of work than a week: the pack fix is small and
well-fenced; the genuinely open part is the roof *placement* geometry, which is not
sourced anywhere and is Benton's to answer.

---

## 1. What already exists, and where

### 1a. The `.skp` components (observed — `ls P:\Sketchup\NewMasterComponentList`)

Two clearly distinct families, and the distinction matters:

**Family A — per-MODEL roof sets.** `RM<model>.skp` and `RM<model>VSS.skp` (no underscore),
22 models × 2 = 44 files:

```
RM4260 RM4284 RM4872 RM4896 RM6060 RM6084 RM7272 RM7296 RM8484 RM84102 RM84126
RM9696 RM96120 RM96144 RM96168 RM96192 RM102102 RM102126 RM102144 RM102168
RM102186 RM10284           (each also with a ...VSS twin)
```

`scripts/wr-booth-data.rb` carries 25 model sizes. The three it has that this set does
**not** are `4230`, `4242`, `4848` — and `assets/layout-render.js:3103` declares
`RM_NO_SIZES = new Set(['4230','4242','4848','127 LP'])`, the sizes on which the portal
refuses to offer RM at all (**observed**). The per-model RM files therefore cover exactly
the RM-supported catalogue, one part per model, with a VSS variant (**derived**, from the
exact set match — very strong).

**Family B — per-WALL-LENGTH art subjects.** `RM60 RM72 RM84 RM96 RM102 RM120 RM126 RM144
RM168 RM186 RM192`, plus `_BACK` on `60 72 84 96 102 120 126 144` and `_VSS` /
`_VSS_BACK` on `60 72` only. These match the portal's art tables **character for
character**:

- `RM_FRONT_SIZES = [60,72,84,96,102,120,126,144,168,186,192]` (`layout-render.js:3096`)
- `RM_BACK_SET = {60,72,84,96,102,120,126,144}` — "168/186/192 reuse front" (`:3097`)
- `RM_VSS_SET = {60,72}` — "only 60/72 have stacked-EFS (-vss) renders" (`:3098`)

So Family B is **art scenery, not build parts**: the subjects the elevation renders were
shot from (**derived**, from the three exact set matches). Also present: the two boxes
(`RMVentilationIntakeBox.skp`, `RMVentilationExhaustBox.skp`), four side composites
(`RMVentilationLeftSideView`, `RightSideView`, `VSSLeftSideView`, `VSSRightSideView`) and
two VSS stacks (`RMVSS_Stack_LeftSideView`, `RMVSS_Stack_RightSideView`).

**Dates (observed):** `_BACK` and the side views are 2026-08-18; `RM72_VSS` and
`RMVentilationIntakeBox` are 2026-08-25; **everything else, including all 44 per-model
files, is 2026-08-31 22:42.** The per-model family is brand new — it did not exist when
the earlier `rv` scoping decisions were made.

Benton's scene names (`RM60`, `RM60_VSS`, `RM72_VSS`, … `RMVentilationExhaustBox`) map to
**Family B plus the two boxes** — i.e. the art set. His `_VSS` suffix guess is confirmed:
it is the vent-silencer convention, and on the art family it exists only on 60/72
(**observed**). On the per-model family the suffix is `VSS` with no underscore and exists
on all 22 (**observed**).

### 1b. The art (observed — `ls WhisperRoomQuote\assets\booth-art\`)

All 32 files the portal preloader asks for are present: `rm-front-<size>.webp` ×11,
`rm-back-<size>.webp` ×8, `rm-front/back-60/72-vss.webp` ×4, six side composites, plus
`rm-intake.webp` and `rm-exhaust.webp`. **No RM top-down art exists** in
`assets\topdown\` and none is wanted — the top-down draws the roof boxes as vector
(`layout-render.js:1810-1842`, function `roofDuct`). **So no art-export run is needed for
the portal.** Whether the SketchUp *proposal* path wants RM art is a separate question
nobody has raised.

`scripts/angled-component-art.rb:55` still says "ROOF-MOUNT COMPONENTS ARE OUT OF SCOPE
for now, on Benton's instruction" (**observed**), and `.forge/auditor/iso30-coverage-2026-08-18.md`
records that the 18 Aug Iso30 run produced no RM60 art and had both boxes collapsed onto
`RMVentilationVSSLeftSideView`. Those are stale relative to the 31 Aug exports; treat the
auditor's RM rows as describing the *old* state.

### 1c. The existing vent pattern in the scripts (the one RM should follow)

- **Pack → component name:** `scripts/booth-from-link.rb:196-211` — `component_for`. A
  `STDWL<n> VNT` pack becomes `<n>VNT`, then `_VSS` / `_EFS` / `_CP` are appended from the
  option flags `vs` / `ef` / `cs`. Enhanced deliberately takes no variant suffixes
  ("the 35.5 VNT wall fits them all", Benton 2026-08-24, quoted in the source).
- **Name → real file:** `resolve_part` / `library_index` / `norm_name`
  (`booth-from-link.rb:230-265`) — case- and separator-insensitive lookup against the
  actual folder, because the library mixes `40VNT_VSS`, `40Vnt_CP`, `46VntCP`.
- **Missing file:** named loudly; Enhanced refuses the whole build (`ENH_MISSING_ABORTS`).
- **Slot placement:** `scripts/build-booth-components.rb:2226` places one part per layout
  slot from `wr-booth-data.rb`'s per-model `:parts` polygons. Roof units are **not** wall
  slots, so they cannot ride that loop.
- **Non-slot parts (the right home for RM):** `scripts/wr-overlays.rb` — the overlay pass
  that places foam, duct covers, desk, MJP, elevated floor and the caster plate. Its
  header states the governing rule: *"Every placement number here is PORTAL-SOURCED… where
  a figure could not be sourced, the part is refused BY NAME rather than approximated."*
  The step (`sp`) is refused today for exactly that reason. **RM belongs in this file and
  under this rule.**

### 1d. Precedent for an option that *changes other parts*

RM would not be the first. `nv` (no-vent) does the same thing: the portal swaps the vent
packs for `STDWL40 NV` packs, and `booth-from-link.rb:208-210` translates them to `<w>NV`.
The `cs` caster flag also mutates other parts — it appends `_CP` to vent art *and* lifts
the whole booth 4.75 in as one group transform (`wr-overlays.rb` header). And `hx` appends
`_HX` to every wall part. So "an option that rewrites other parts' names" is an
established pattern here, not a new one (**observed**).

The important structural fact is that **for RM the swap already happened upstream**. Unlike
`hx` and `cs`, our Ruby receives the substituted result, not the flag-plus-original.

---

## 2. Does the VNT→CBL rule live anywhere already? Yes — in the portal

`WhisperRoomQuote\booth-builder.html:3180-3188` (**observed**):

```js
// Roof-mounted vent: same swap the production RM BOM does — every vent wall
// becomes a cable wall (the ducts move to the roof), reversed when toggled off.
function applyRoofVent(layout) {
  ...
  if (state.roofVent && k === 'VNT') state.assign[slot.id] = line(String(l.pack).replace(/\sVNT\b/i, ' CBL'));
  else if (!state.roofVent && k === 'CBL') state.assign[slot.id] = line(String(l.pack).replace(/\sCBL\b/i, ' VNT'));
}
```

Note the comment: **"same swap the production RM BOM does"** — this is a real bill-of-
materials rule, not a drawing convenience. It runs inside `rebuild()` (`:3203`) and again
on link decode (`:2884-2890`), so both a live design and a shared link converge on the same
`a` map.

**What the swap touches, traced (observed unless noted):**

| Touched | Where | Behaviour under RM |
|---|---|---|
| Pack strings | `booth-builder.html:3186` | `STDWL46 VNT` → `STDWL46 CBL` |
| Per-side clearance | `booth-builder.html:4904-4917` `sideClearanceB` | the 6″/10″ branch keys on `classifyWall(...)==='VNT'`; a CBL wall never matches, so the side drops to the nominal 1″ **automatically, as a consequence of the swap** |
| EFS | `booth-builder.html:2994`, `:5478` | `efs: state.efs && !state.roofVent` — RM *includes* EFS on the roof, so the wall-side EFS is suppressed; the UI disables the EFS checkbox and labels it "Included with roof-mounted ventilation" (`:7452`) |
| No-vent interlock | `booth-builder.html:2847`, `:8622` | `noVent` and `roofVent` are mutually exclusive, both directions |
| Model gating | `booth-builder.html:8045`, `:8317`; `layout-render.js:3104` | `rmSupported()` — RM is force-cleared on `4230/4242/4848/127 LP` |
| Top-down art | `layout-render.js:931-941` | a VNT slot on an RM booth resolves to the **SOLID** wall render |
| Top-down vector | `layout-render.js:2068-2069`, `:1810-1842` | wall vent ducts suppressed; two boxes + a `ROOF VENT` caption drawn on each former vent panel |
| Elevation | `layout-render.js:4434-4478` | per-size rooftop render, bottom-anchored on the roof cap, inset 5″ from each ceiling end |
| Overall height dim | `layout-render.js:4785-4790` | `rmH` = **10″** flat, **16.5″** when VSS-stacked, added to the total-height label |
| Quote/spec text | `booth-builder.html:4550`, `:10149`, `:7284` | "Roof-mounted ventilation (exterior fan silencer included)"; "vent on the roof — nothing sticks out" |
| ISO drawing | `booth-builder.html:8813` | `roofVent: 'partial'` — the vents visibly leave the walls, the roof hardware is not drawn |

The clearance consequence is worth stating plainly, because it is what CLAUDE.md's table
implies but does not say: **under RM the ex-vent wall reverts to the nominal 1″, and no
10″ EFS band is reserved anywhere.** The renderer does that for free once the pack says
CBL. Nothing in our Ruby computes clearances, so nothing there needs changing.

**What is NOT in the repo, anywhere:** a required **ceiling height** for RM. The portal
adds `rmH` to the *drawn* total-height dimension and reserves `roofPad = 21 * PX2`
of drawing headroom (`layout-render.js:3645`, comment: "~19″ for the VSS-stacked front, +
margin"), but the fit card's ceiling warning (`booth-builder.html:4954`) still compares the
room ceiling against `standingHeight(layout) + 2`, which is **83″ or 85″ + HX + casters and
does not include `rmH` at all** (**observed**). So a booth with RM tells the shopper it
needs ~7′1″ of ceiling when the roof unit adds another 10″–16.5″ on top. That looks like a
real portal bug, it is outside our repo, and it is worth telling Benton about since
CLAUDE.md says ceiling height disqualifies faster than anything else. **I did not verify
this against a running page — it is read off the source (derived).**

---

## 3. What the `rv` payload key carries

**A bare `0|1`.** `booth-builder.html:2790` (**observed**):

```js
vs: state.vss ? 1 : 0, ef: state.efs ? 1 : 0, rv: state.roofVent ? 1 : 0,
```

decoded at `:2839` as `state.roofVent = !!d.rv`. No size, no variant, no side. Everything
else about the RM set is **derivable from the payload without `rv`**:

- which model → `m`
- which walls carry it → the `CBL` packs in `a` (the ones that would have been `VNT`)
- VSS or not → `vs`
- EFS → implied, always on under RM
- height extension → `hx`

`rv` is therefore mostly a *confirmation* flag. It is still load-bearing for one thing: a
booth can legitimately have a CBL wall without RM (a cable wall is a normal product), so
`rv` is what distinguishes "cable wall because roof vent" from "cable wall because the
customer wanted a cable wall". **A builder must not infer RM from CBL packs alone.**

---

## 4. Intake and exhaust — two boxes

What the repo and the portal actually say (**observed**):

- `RMVentilationIntakeBox.skp` and `RMVentilationExhaustBox.skp` exist as separate parts,
  and `rm-intake.webp` / `rm-exhaust.webp` exist as separate art.
- The top-down draws **a pair per former vent panel**: `layout-render.js:1819` loops
  `for (const k of [-1, 1])`, drawing two boxes straddling the panel centre, separated by
  a gap, one carrying a fan circle (exhaust) and one plain (intake). Both sit **inboard of
  the wall line, on the roof**, projecting about 10″ deep into the plan.
- The elevation places the units on **the roof cap**, inset **5″ from each ceiling end**,
  and where there is more than one vent set they are evenly spaced between those 5″
  margins (`layout-render.js:4443-4463`).
- Count comes from `layout.ventSets`, and `booth-builder.html:2873` records the invariant
  `(VNT + CBL) === ventSets` — i.e. **one RM set per former vent wall**.

**But none of that is a placement source for SketchUp.** The top-down box sizes are
proportional (`B2 = clamp(panelLen*0.26, 16, 36)`, `D2 = min(10*PX, 56)`), explicitly
drawing-scaled rather than measured. The elevation is a bitmap scaled by its own aspect.
Under `wr-overlays.rb`'s own rule ("portal-sourced or refused by name"), **the intake/
exhaust placement is not sourced** and a Builder must not invent it.

The most likely resolution, and it is cheap: the **per-model `RM<model>.skp` is a single
pre-composed roof assembly** that already contains both boxes in their correct relative
positions, so placement collapses to "seat this one part on the roof, aligned to the booth
origin". That is **assumed** — it follows from there being exactly one file per model and
from Family B being art — and it is question 1 for Benton below. If it is right, the work
is small. If each model file is instead just a duct run and the boxes place separately, the
placement geometry has to be measured and the job grows.

The vertical datum a Builder would seat against is already established:
`reference/floor-ceiling-geometry.md` puts the standard booth's contact plane at **booth
z 81.000** (`DECK_TOP_Z + wall_h`), with the ceiling slab above it; `wr-deck.rb`'s
`contact_z` resolves the real face per part (**observed**). The portal's `rmH` of 10″ / 16.5″
is the height the RM unit adds above the roof (**observed**, `layout-render.js:4786`) and is
a good cross-check on whatever a placed part actually measures.

---

## 5. Clearances and the room

What the repo states (**observed**):

- `CLAUDE.md` per-side table: nominal 1″, vented wall 6″, vented wall with EFS 10″, door
  swing 23.5/29.5/34.5″ by frame width, ADA ramp 45.625″, step 12″, outside desk 14″. Its
  cited authority is `WhisperRoomQuote\assets\layout-render.js`.
- `booth-builder.html:4904-4917` `sideClearanceB` is the implementation. Under RM the
  vent branch cannot fire (the wall is CBL) and `layout.efs` is false, so **every ex-vent
  side falls to 1″**.
- `layout-render.js:1128-1142` says the same in the renderer: *"Vent clearance only when a
  vent ACTUALLY protrudes on this wall … a no-vent (SNV/ENV) or roof-mounted booth doesn't
  reserve phantom clearance."*

What the repo does **not** state, and should be flagged rather than inferred:

- **No RM ceiling-height requirement anywhere.** Not in `CLAUDE.md`, not in
  `reference/booth-models.md`, not in `models.json`/`options.json` (the only "roof" hit in
  the catalog is Fireguard). The portal's `rmH` 10″/16.5″ is a *drawing* figure taken off
  the renders; whether service access on top needs more than the unit's own height is
  unknown.
- **No service clearance for the roof unit.** Someone has to reach the fan and the EFS box.
  The wall-mounted equivalent claims 10″; nothing states the roof equivalent.
- **No RM entry in `options.json`.** Roof-mounted ventilation is not in the catalog options
  file at all (**observed**), so there is no price, no description and no compatibility row
  for it there. `compatibility.json` has zero roof/RM hits.

---

## 6. What breaks if this is done naively — ranked

**R1 — Already broken, silent, ships the wrong product (highest).**
`component_for` has no `CBL` case (`booth-from-link.rb:186-217`, **observed**: the case
statement handles `WA STDDRFRM`, `STDWL<n> DRFRM`, `STDWL<n> WDO`, `STDWL<n> VNT`,
`STDWL<n> NV`, and bare `STDWL<n>` anchored with `\z` — nothing else). Consequences
(**derived**, traced through the code, not run):

- Standard booth: the pack lands in `odd`, prints "pack(s) not translatable — those slots
  fall back to the layout default", the slot is left unassigned, and
  `build-booth-components.rb:2226` calls `guess_component('VNT', run)` → `46VNT`. **A
  vented wall is built on a roof-vent booth**, and the console's own "rv: not built" line
  makes it read as though RM was merely omitted.
- Enhanced booth: `ENH_MISSING_ABORTS` refuses the build entirely, with a messagebox naming
  the untranslatable packs. Loud, and therefore the safer of the two.

The fix is two lines — `when /\ASTDWL(\d+)\s+CBL\b/i` returning `"#{p}#{w}PanelCBL"` — and
the parts exist: `40PanelCBL`, `46PanelCBL`, `ENH 35.5PanelCBL`, `ENH 41.5PanelCBL`, each
with an `_HX` twin (**observed**, directory listing). `build-booth-components.rb:1420` and
`:1431` already know the `'CBL'` kind. **This fix is worth shipping on its own, before any
RM roof geometry, because it stops a wrong booth today.**

**R2 — Ordering: the swap must not be re-applied in Ruby.**
The payload arrives already swapped. A Builder who reads `rv == 1` and *also* rewrites VNT
packs would be doing it twice — harmless for the VNT→CBL direction (idempotent), but a
Builder who instead implements the *reverse* mapping, or who keys the RM part off "slots
that are VNT", will find **zero VNT slots on an RM booth** and place nothing. The correct
Ruby-side rule is: **the CBL packs in `a` that sit on layout slots whose `:sk` is `'VNT'`
are the former vent walls, and those are where the roof sets go.** That comparison is
available — `wr-booth-data.rb` carries `:sk=>'VNT'` per slot and the payload carries the
pack — and it is also the honest cross-check that the swap really happened.

**R3 — The half-apply, both directions.** Two states must be impossible:
- CBL walls placed, no roof unit → a booth with no ventilation at all. Reachable today the
  moment R1 is fixed without also placing the RM part.
- Roof unit placed, VNT walls still there → double ventilation. Reachable today if someone
  adds RM placement without fixing R1.
Both are silent in a render. The fence is a single assertion in the build: **if `rv == 1`,
then the count of CBL slots on VNT-kind layout slots must equal `ventSets`, and an RM part
must have been placed for each — otherwise refuse by name**, in the same style as
`ENH_MISSING_ABORTS`.

**R4 — Model gating.** `4230`, `4242`, `4848` (and `127 LP`, which our layout data does not
carry) have no RM part and the portal will not emit `rv` for them. Ruby should still refuse
by name rather than compose a filename that cannot exist.

**R5 — VSS naming trap.** Two different VSS rules coexist. Art: `_VSS` only on 60/72
(`RM_VSS_SET`). Per-model parts: `VSS` (no underscore) on all 22 models. A Builder who
reuses `RM_VSS_SET` to decide whether a *part* has a VSS variant will wrongly skip 20 of
them. `resolve_part`'s `norm_name` already forgives the underscore difference, so the
lookup is safe; the *decision* is what must not borrow the art rule.

**R6 — HX interaction, unverified.** No `RM*_HX.skp` exists (**observed**). The builder
appends `_HX` to wall parts; if it did that to an RM part it would find nothing.
Whether an HX booth's roof unit is the same part (just placed 10″ higher) is
**unknown** — question 4 below.

**R7 — Ceiling-height honesty.** Covered in §5. The portal under-reports required ceiling
by 10″–16.5″ on RM booths. Not our repo, but it is the class of error CLAUDE.md singles out.

---

## Confidence and gaps

**Solid (observed):** the `.skp` inventory and its timestamps; the art inventory; the
absence of a `CBL` branch in `component_for`; the presence of `CBL` in
`guess_component`; the portal's `applyRoofVent`, `rmSupported`, `RM_*` size tables,
clearance function, and `rv` payload shape; the absence of any RM entry in the catalog
JSON; the absence of any RM ceiling-height rule in this repo.

**Derived, traced but not executed:** the R1 failure chain (nil → `odd` → unassigned →
`guess_component('VNT')` → `46VNT`). There is no `ruby.exe` on this machine and running it
would need SketchUp, so this is read off the code, not observed in a build. It should be
confirmed by a dry run of `booth-from-link.rb` against a real RM link before anyone quotes
it as a bug report.

**Assumed, and the biggest lever on the size of this job:** that `RM<model>.skp` is one
pre-composed roof assembly. Everything about "how hard is placement" turns on it.

**Not checked, on purpose:** I ran no bridge query and opened no model — Benton has files
open and the constraint is binding. The RM parts' actual bounding boxes, insertion points
and internal arrangement are therefore unmeasured. A Builder can get all of them safely by
loading the `.skp` into an **Untitled** model under the GOAL's own guard, which is the
right first step of the build.

---

## Questions only Benton can answer

1. **Is `RM<model>.skp` (e.g. `RM7272.skp`) the complete roof set for that booth — both
   boxes, ducts, everything — as one part that just needs seating on the roof?** Or does
   it need the intake and exhaust boxes placed separately? *(This one decides whether this
   is a day or a week.)*
2. **Where does it seat?** Sitting flat on the top face of the ceiling slab, aligned to the
   booth footprint — or inset, or centred on the former vent wall? And is there an
   orientation rule (exhaust toward a particular wall)?
3. **What ceiling height does an RM booth actually need?** The portal's drawing adds 10″
   (16.5″ VSS-stacked) but the fit card still checks only ~7′1″. Is the real requirement
   booth height + unit height, or booth height + unit + service access?
4. **HX booths:** is the RM part the same file, just 10″ higher? There is no `RM*_HX.skp`.
5. **Should the `_BACK` and side-view files (`RM60_BACK`, `RMVentilationLeftSideView`,
   `RMVSS_Stack_*`) be treated as art-only scenery and excluded from the build library?**
   Confirming that stops a builder ever composing one of those names.
6. **Do you want the `CBL` pack fix shipped now, ahead of the roof geometry?** It is small
   and it stops a booth that is quietly wrong today.
