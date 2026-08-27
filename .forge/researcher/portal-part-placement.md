# Portal part placement — foam, duct covers, desks, MJP, elevated floor, caster plate

Researcher findings, 2026-08-27. Every claim cites the portal source it was read from.
Provenance words: **observed** (I read/ran it), **derived** (follows by shown steps),
**reported** (a doc/comment/Benton quote inside the portal source), **assumed** (unchecked).

Portal repo root: `C:\Users\bento\OneDrive\Documents\Claude\WhisperRoomQuote` (read-only).
Component library: `P:\Sketchup\NewMasterComponentList` (387 `.skp` files, listed 2026-08-27 — observed).

The three portal renderers, and which questions each answers:

| view | file | draws which of our parts |
|---|---|---|
| top-down floor plan | `assets/layout-render.js` `renderLayoutSvg` | foam strip, desk, MJP (both plates), seals, vents, ramp, step |
| walk-around elevation | `assets/layout-render.js` `renderElevationSvg` | foam sheet + duct covers (through-window pass), desk, MJP, caster lift |
| angled iso ("Iso30") | `assets/iso-render.js` | foam, duct covers, desk, MJP, EFP, caster plate, Enhanced inner shell |

Where two views disagree on a number, both numbers are given below with their source.

---

## 0. Vocabulary — "bench wall" and "IEP wall"

- **"Bench wall" does not exist in the portal.** Grepped the whole repo (`bench` — every hit
  is "benchmark"/"workbench"; zero hits in `booth-builder.html`, `layout-render.js`,
  `iso-render.js`, `booth-layout-viewer.js`, `SCHEMA.md`) — **observed**. The portal's wall
  kinds, from `assets/layout-render.js:15` `classifyWall(pack)` — **observed**:
  `DRFRM` (door frame), `WDO` (window), `CBL` (cable wall), `VNT` (vent wall),
  `SOLID` (everything else — note a `STDWL40 NV` no-vent plug wall classifies as SOLID
  because the regex only knows VNT/CBL/WDO/DRFRM).
  **The wall Benton calls the "bench wall" is the portal's VNT (vent) wall** — the wall the
  duct covers attach to (see section 2). Derived from his duct-cover rule matching the
  portal's vent-wall rule exactly; the way the evidence leans, "bench wall" = vent wall.
- **"IEP wall" = the Enhanced inner-shell panel.** The iso renderer calls these the
  `inner-*` families ("enhSep" path, `assets/iso-render.js:682-940`) — a complete second
  wall set standing inside the standard shell. Geometry (**observed**,
  `assets/iso-render.js:806, 885-941`): inner panel back face sits **1.25"**
  (`ENH_SEP_GAP_IN`) roomward of the standard wall's interior face; the inner panel itself
  is **1.00"** deep; so the IEP room face is **2.25"** roomward of the standard interior
  face per side, and `E.interior === S.interior - 4.5"` on all 25 sizes (**reported** in
  `assets/iso-render.js:783-796`, cross-checked by the generator against
  `lib/pl-data/booth-layouts.json`).
  Inner panels are 41.5" wide (46-series) / 35.5" (40-series), 79.5" tall (89.5" with HX)
  (**observed**: manifest family `inner-46` = 41.5 x 79.5 x 1.0;
  `scripts/booth-from-link.rb` ENH_WIDTH table agrees).

---

## 1. Acoustic foam ("FOAM", the customer's StudioFoam sheet)

**Benton's rule as given: VERIFIED, with sharpening.**

- **Which walls (rule a script can evaluate):**
  `wearsFoam(panel) := (kind in {SOLID, VNT, CBL, NV}) AND (panelWidth in {40, 46})`
  — one sheet per qualifying panel. Doors and windows get none; narrow companion panels
  (7/16/19/22/28/31/43") get none, **including the 43"**.
  **observed** three independent places, all agreeing:
  - top-down: `assets/layout-render.js:3252-3255` `FOAM_KINDS = {SOLID, VNT, CBL}` + width
    40/46 (NV classifies as SOLID, so NV walls qualify);
  - elevation: `assets/layout-render.js:4359` same test;
  - iso: `assets/iso-render.js:5026` `OV_FOAM_ART` regex = plain/`-cbl`/`-vnt(-vss|-efs)`/
    `-hx` 40/46 walls, with the comment (**reported**, Benton's rule) "foam on any 40/46"
    wall that is not a door and not a window — solid, vent, cable and NV walls".
  - Vent walls DO wear foam: "the ducts are exterior, the interior face is clear"
    (`assets/layout-render.js:3253`, **reported**). So yes — bench (vent) walls and
    non-bench walls alike.
- **Which face:** the **interior face** of the wall, sheet standing proud into the room by
  its own thickness. No sink, no inset (`assets/iso-render.js:2311` — foam is exempt from
  the duct sink; **observed**).
- **Position on the wall:** **centered both ways on its panel.**
  - Horizontally: `(panelWidth - sheetWidth)/2` (`assets/iso-render.js:2337`, top-down
    `assets/layout-render.js:1573` "one true-24-inch piece, centered on the panel") —
    **observed**.
  - Vertically: centered on the wall height: `z = (ph - sheetHeight)/2`, ph = 81" standard,
    91" with height extension (`assets/iso-render.js:2334-2338`, `OV_FOAM_DROP_IN = 0` —
    Benton proposed a 2" drop, measurement rejected it, knob shipped at 0; **observed**).
    At 81" that is 16.5-16.6" of margin top and bottom.
- **Sheet size** (the delivered art disagrees with itself by a fraction of an inch — all
  **observed**, pick per source): nominal 24 x 48 x 2"; iso manifest family `foam` =
  22.97 W x 47.88 H x 2.13 D; elevation `ST_FOAM_W_IN/H_IN` = 24.12 x 48.06
  (`assets/layout-render.js:3368`); top-down art 24.04 W x 2.06 D (`TD_ART.foam`,
  `assets/layout-render.js:567`).
- **Foam color:** payload key `f`, one of Gray/Orange/Blue/Purple/Burgundy
  (`booth-builder.html:2471` FOAMS); Gray is the default. Color is a re-tint of the same
  geometry — **observed** (`assets/iso-render.js:5084` FOAM_COLORS, gen-foam-tints.js
  mechanism).
- **Standard vs Enhanced — VERIFIED, exactly Benton's rule:** on an Enhanced booth the foam
  moves to the **room face of the IEP inner panel**, i.e. shifts roomward by
  `innerOff = ENH_SEP_GAP_IN (1.25") + innerPanelDepth (1.00") = 2.25"` — derived per host
  panel by the renderer, never hard-coded (`assets/iso-render.js:868-887, 2306-2320` and
  Benton verbatim inside that comment: "The duct covers and foam will now be on the
  interior of the enhanced walls for enhanced booths, not the standard, so they need to be
  moved" — **reported**). It is a MOVE, not a duplicate: one sheet per wall, never on both
  shells. The top-down gets the same answer automatically because it draws foam at the
  interior face of the composite wall band (`assets/layout-render.js:1560-1568`) —
  **observed**.
  WARNING — exception, **observed** (`assets/iso-render.js:884-887`): a host wall that grew
  **no inner twin** keeps its overlays on the standard face ("on the partly-covered models
  the 22"/16" fillers have no inner family") — those fillers are under 40" so they carry no
  foam anyway; the case only matters if an HX inner twin is ever missing.
  The foam-qualifying width test stays keyed on the STANDARD host panel width (40/46),
  not the inner panel's 35.5/41.5 — **observed** (`assets/iso-render.js:2282` runs on the
  host panel).
- **`.skp` component: `Foam.skp` EXISTS** (P: library, **observed**). One file, no color or
  size variants; its actual modeled dimensions are unmeasured from here (**assumed** to be
  the nominal 24 x 48 x 2 sheet — Builder should measure on first load).

## 2. Duct covers (the hinge duct-cover pair on the vent wall)

**Benton's rule as given: VERIFIED with the vocabulary correction (vent wall, not "bench"),
plus two portal rules he did not state.**

- **Which walls:**
  `wearsDuctCovers(panel) := (kind == VNT) AND (panelWidth in {40, 46}) AND NOT heightExt`
  — the pair (one HIGH, one LOW) on **every vent wall**, silencer variants (VSS/EFS)
  included ("the -vss/-efs interior faces still show the same bare ports — the silencer
  hardware is all on the exterior side", `assets/iso-render.js:5010-5016`, **observed**).
  NOT on cable walls, NOT on solid walls.
  - **NO duct covers on an HX (height-extension) booth** — a PRODUCT fact, not a drawing
    choice: "the 10-inch height-extension panels do not ship with the hinge duct covers"
    (`assets/iso-render.js:5028-5040`, Benton **reported**). Foam is unaffected — HX walls
    still wear foam.
- **Which face:** the **interior face** of the vent wall, back face of the cover on the
  wall plane, the cover's ~3.14" body standing proud into the room. (The iso view sinks it
  half its depth into the wall — `OV_DUCT_SINK = 0.5`, `assets/iso-render.js:5210` — but
  that is an explicit parallel-projection legibility trade, **observed**; the physical
  placement is back-face-on-wall.)
- **Position — centered on its duct port.** Port centers, wall-local inches
  **measured off the delivered vent-wall interior renders** (`assets/iso-render.js:
  5160-5207`, `OV_DUCT_POS`, re-measured four times; **observed**):

  | panel | HIGH cover center [x, z] | LOW cover center [x, z] |
  |---|---|---|
  | 40" vent | [13.9", 71.1"] | [27.7", 9.1"] |
  | 46" vent | [16.15", 71.45"] | [29.9", 9.45"] |

  x is measured **on the interior face** — i.e. from the panel's left edge as seen from
  INSIDE the booth (`assets/layout-render.js:3369-3374` says exactly this and mirrors to
  `wIn - x` when drawing from outside; **observed**). z is the port center height off the
  booth floor, ABSOLUTE — HX keeps the ports at the same heights (**observed**,
  ports3hx.js result quoted at `assets/iso-render.js:2341`). The two covers sit diagonal,
  62.0" apart vertically.
  - The elevation uses its own slightly different z pair (`ST_DUCT_Z` hi 72.88 / lo 7.45,
    `assets/layout-render.js:3375`, anchored on the delivered Duct Cover export's own
    frame — **observed**). Prefer the port-center table; it was measured against the booth
    art, and `assets/iso-render.js:5178-5190` explicitly rules that "the cover-set art
    never enters placement".
- **Cover size** (**observed**, iso manifest): 11.94" wide; HIGH 14.76" tall, LOW 13.78"
  tall; 3.14" deep. Elevation uses 11.97 x 14.94 (`ST_DUCT_W_IN/H_IN`).
- **Layering rule** (**reported**, Benton via `assets/iso-render.js:4081-4096`): "the foam
  should be ahead of the duct covers" — foam sheet in FRONT of the covers where they
  overlap.
- **Standard vs Enhanced — VERIFIED:** same 2.25" roomward move as the foam, onto the IEP
  vent wall's room face; applied to foam and covers ALIKE so their relative depth is
  untouched (`assets/iso-render.js:2313-2321`, **observed**).
- **`.skp` component: `Duct Cover.skp` EXISTS** (P: library, **observed**). WARNING: it is
  the cover-SET scene (the iso art was cut from `Duct Cover_Iso30_IntL.png [top]`/
  `[bottom]` — one export holding both covers). The portal measured that set's internal
  separation as **66"**, while the real port separation is **62.0"**
  (`assets/iso-render.js:5178-5190`, **observed**). **Do not place the .skp as one unit** —
  split it (or place it twice, cropped) and anchor each cover on its port center from the
  table above.

## 3. Desks (Office desk — the portal's only desk family, two sizes)

Option: `whisperroom-catalog/data/options.json` id `office-desk`, "Red oak fold-down desk…
installs inside or outside the booth… available in 30" or 42" widths" (**observed**).
Payload keys: `dk` (on), `dl` (=1 means Large), `ds` (chosen slot id), `dox` (=1 means
mounts outside).

- **Variants** (**observed**): Small ~30 x 14" plan (art 30.06 x 14.78 top-down;
  iso 30.45 W x 13.36 D); Large ~42 x 17" (art 42.05 x 16.79; iso 42.16 x 15.55).
  **The Large desk is interior-only** — enforced in all three renderers and the pricer
  (`assets/layout-render.js:2247-2258`, **observed**).
- **Host wall — acceptance rule** (`assets/layout-render.js:2219-2223` deskAccepts,
  mirrored at `assets/iso-render.js:3432-3437`; **observed**):
  `SOLID|VNT|CBL AND width >= 40 -> mounts INSIDE; WDO AND width >= 40 -> mounts OUTSIDE
  (under the window); door wall never.`
- **Host wall — selection** (`assets/layout-render.js:2243-2272` deskPlacement;
  **observed**): the customer's chosen slot (`ds`) if it still accepts; else auto:
  1) a 46/40" inside wall, preferring the wall opposite the door, then SOLID over VNT,
  then wider; 2) a >=40" window (outside); 3) the widest inside wall.
- **Placement on the wall** (**observed**): **centered on its panel**. Interior: back
  (carpet strip) flush to the **interior wall face**, extending 14"/17" into the room.
  Exterior (small only): back flush to the **outer wall face**, extending 14" outward —
  and it claims **14" of exterior clearance** on that side
  (`assets/layout-render.js:1145, 2485-2493`).
- **Height** (**observed**, `assets/iso-render.js:3397-3410`): work surface at **32.5"**
  (30" + Benton's 2.5" QA lift). The elevation drops a desk under a window to
  `clamp(sill - 4, 22, 31) + 2.5`; the iso view does NOT (named simplification —
  `ISO_DRAWS.desk` stays 'partial' for exactly this, `booth-builder.html:8119-8135`).
  The desk's carpeted back strip stands 4.84" above the surface (measured,
  `DESK_STRIP_PROUD_IN`).
- **Standard vs Enhanced — PORTAL IS INTERNALLY INCONSISTENT, first-class finding:**
  the top-down places the desk at the interior face of the composite wall band, which on
  an Enhanced booth IS the IEP room face (**derived** from `assets/layout-render.js:
  2303-2306` place table using total thickness `t`); but the iso furniture pass
  (`assets/iso-render.js:2478-2481` fnAdd) does **not** apply `innerOff` — the interior
  overlays got the Enhanced move (v2.413.5), furniture (v2.473.0) did not. On an Enhanced
  booth the iso desk/MJP sit 2.25" inside the IEP panel (buried). No Benton ruling found
  either way — **observed** code, open question flagged. For SketchUp: mount on the IEP
  room face (the wall the customer can touch — same reasoning Benton gave for foam),
  32.5" surface height.
- **`.skp` components: `DeskSmall.skp` and `DeskLarge.skp` EXIST** (P: library,
  **observed**).

## 4. MJP — "Multi jack panel (MJP)"

Expansion **observed** in `whisperroom-catalog/data/options.json:20`:
**"Multi jack panel (MJP)"** — "2 USB jacks, 4 XLR jacks, and 6 quarter-inch stereo phono
jacks. Connect cables through a passage to the interior box." Payload keys: `jp` (on),
`ms` (chosen slot id). "$795 each", "can be added after assembly". (Do not put the price in
any artifact.)

- **It is a PASS-THROUGH with hardware on BOTH faces of one wall** (**observed**,
  `assets/layout-render.js:2333-2337` + `assets/iso-render.js:2405-2419`, Benton quotes
  inside): the interior face carries the jack-field box, the exterior face the closed
  latched box with two cable tails; the exterior box is the interior box turned 180
  degrees in plan ("the ports need to face the camera" — Benton, v2.474.1).
- **Host wall — selection** (`assets/layout-render.js:2277-2287` mjpPlacement;
  **observed**): the chosen slot (`ms`) if it is still a **window (WDO) or cable (CBL)
  wall**; else the **widest WDO/CBL wall**; if the booth has neither, the widest
  desk-accepting wall (SOLID/VNT >= 40) so the plate still shows. Draggable to any
  window/cable panel.
- **Placement on the wall** (**observed**): **centered on its panel**, both faces.
  Plan plate 8.25" x 2.5" (`assets/layout-render.js:2338`); iso box 8.39" W x 3.01" D,
  jack box 3.64" tall with cable tails hanging below (manifest + `MJP_BOX_H_IN`).
- **Height** (**observed**, `assets/iso-render.js:3411` `MJP_PLATE_CENTER_IN`): plate
  **center at 27.25"** off the floor = desk surface 32.5" minus 5.25" (Benton QA
  2026-06-27). The plate sits 5.25" under the desk surface and they routinely share a
  wall; draw order is MJP first, desk in front (`FURN_DRAW_ORDER`, **observed**).
- **Standard vs Enhanced:** same inconsistency as the desk (section 3) — top-down
  effectively on the IEP faces, iso not moved. Same recommendation: interior box on the
  IEP room face, exterior box on the standard exterior face (it is a pass-through — on an
  Enhanced booth the passage crosses BOTH shells; nothing in the portal models that
  explicitly — **observed** absence, open question).
- **`.skp` component: `MJP.skp` EXISTS** (P: library, **observed**). WARNING: the portal's
  top-down deliberately refuses its own MJP art because the export carries a SketchUp
  dimension annotation fused to the plate (`assets/layout-render.js:2341-2346`,
  **observed**) — the .skp may carry the same annotation; Builder should check and hide
  that layer.

## 5. Elevated floor (EFP — Elevated Floor Package)

Payload keys: `ep` (standalone), `ad` (ADA bundle = wide door + ramp + elevated floor;
sets the same draw flag). Product record `EFP <size> <S|E>`; sold sizes
`EFP_SIZES = {4872, 7272, 7296, 9696, 96120, 96144, 96168, 96192}`
(`lib/booth-price-map.js:269`, **observed**). Catalog option `ada-package` note: "32" wide
door, no-threshold entry, ramp, and raised floor" (**observed**).

- **What it is** (**reported**, Benton verbatim in `assets/iso-render.js:1295-1301` /
  `4341-4346`): "the EFP slab is placed inside the standard floor recess. The IEP walls
  sit on the lip of that recess, so generally the EFP slab presses up against the IEP
  walls. That's why we have perimeter strips — to fill the small gap if they only get a
  standard booth. The perimeter strips cover the black hinges on one side, and touch the
  elevated floor on the other."
- **Geometry** (**observed**, iso manifest + `assets/iso-render.js` pass 2fe):
  a tile slab lying ON the carpet floor, **~2.83-2.89" tall** (`et` per size: 4872 is
  2.829, 7296 is 2.887), plan e.g. 4872 = 65.95 x 41.34", 7296 = 89.26 x 66.05".
- **Placement — CENTERED in the interior, and the portal admits this is authored, not
  measured** (`booth-builder.html:8040-8046`, **observed**): "WHERE IT SITS IS AUTHORED,
  NOT MEASURED… the delivered tile field is ~4 in narrower and ~4.5 in shallower than the
  walls' interior faces… It is drawn CENTRED. Benton is asked on the proof sheet."
  The arithmetic consequence (**observed**, `assets/iso-render.js:4344-4363`):
  - **Enhanced:** centered = flush against the IEP room faces to within 0.12-0.28" — the
    art is cut for the Enhanced room.
  - **Standard:** ~2.0-2.4" of carpet shows on every side; the portal fills it with a
    **vector perimeter strip** ring from the standard interior faces up to slab height
    (a stated approximation — no strip art exists; Benton: "I may have made an error, as I
    didn't include perimeter strips for the 'standard' booths but it should be barely
    noticeable" — **reported**). Enhanced needs no strip and gets none.
- **The raised floor raises nothing else** — desk, MJP and door threshold stay at their
  un-raised heights in every portal view; stated simplification
  (`booth-builder.html:8043-8046`, **observed**). A SketchUp build inherits this open
  question.
- **Walk-around and floor plan draw NO EFP at all** — `assets/layout-render.js` has no EFP
  path (**reported** by `booth-builder.html:8179`, grepped by the portal team 2026-08-27;
  my own grep agrees — **observed**).
- **`.skp` components:** `EFP4872 / EFP4896 / EFP7272 / EFP7296 / EFP9696 / EFP96120 /
  EFP96144 / EFP96168 / EFP96196 .skp` EXIST (**observed**).
  **`EFP96192.skp` DOES NOT EXIST — the library has `EFP96196.skp`, which matches no
  catalogue size.** Portal iso art has `efp-96192` and `EFP_SIZES` sells 96192; 96196 is
  almost certainly a misnamed 96192 (**derived** — Benton must confirm/rename).
  Also note `EFP4896` exists as art + .skp but 4896 is NOT in `EFP_SIZES` (not sold
  standalone) — harmless.

## 6. Caster plate

Payload key `cs`. Catalog option `caster-plate`: "raises booth height by nearly 5""
(**observed**, `whisperroom-catalog/data/options.json:11`). `step` (payload `sp`) "pairs
with the caster plate".

- **What it is** (**observed**, `assets/iso-render.js:1722-1751` + manifest CP note at
  `assets/layout-render.js:2922`): a wheeled tray UNDER the booth that **replaces the
  5/16" isolation mat** (`MAT_T_IN = 5/16`). The plate set is per-floor-section (the
  delivered plates: CP30…CP192 strips plus two-axis plates CP4848/CP4872/… and SIDE/CTR
  pieces — 17 delivered scenes); each plate **laps out to the seal perimeter** on its
  boundary edges, so the union footprint is the full published exterior — 1" beyond the
  wall panels on every side (**observed**, measured fit <= 0.24% noted in the CP block).
- **Vertical stack** (**observed**): plate silhouette thickness ~2.75" (`CP_T_IN`
  fallback; per-booth `cpt` from the manifest); the plate has a **0.739" tray lip** and
  the booth's 1" floor slab sits DOWN INSIDE the tray ("the floor sits in the tray" —
  Benton, `CP_TRAY_LIP_IN`, measured off the art). Net **booth lift = exactly 5"** in the
  portal's height rule (`assets/layout-render.js:3553` boothHeightIn:
  `lift = casters ? 5 : 0`, **observed**; the elevation art comment says the visual lift
  is ~4.6").
- **Side effects** (**observed**): vent-wall exterior art swaps to the `_CP` variants (fan
  and EFS hang ~5" lower so they still reach the floor) — our `scripts/booth-from-link.rb`
  already does this suffix swap; the STEP (12" deep, `StepFront.skp`) goes in front of the
  door, only sold with casters.
- **Standard vs Enhanced:** no variant difference found in the portal — the plate is under
  the standard shell either way (**observed** absence of any `enh` test in the CP paths).
- **`.skp` components:** the full CP set EXISTS — `CP30…CP192`, `CP4230, CP4242, CP4848,
  CP4872, CP102…`, `CP6018 SIDE`, `CP8442 CTR`, etc. (48 CP*.skp files, **observed**),
  plus every `_CP` vent-wall variant and `StepFront.skp`.

---

## 7. Everything else the portal can emit that our scripts do not draw

Share-link payload contract: `booth-builder.html:2545-2580` designPayload() (**observed**).
Our parser: `scripts/booth-from-link.rb:282-400` build_from_payload (**observed**) reads
ONLY `m, v, hx, vs, ef, cs, rp, a` and prints a NOT-built line for `dk, sp, jp, bt, sl,
rv`.

| payload key | meaning | booth-from-link.rb today | `.skp` exists? |
|---|---|---|---|
| `m`, `v`, `hx`, `a` | model, S/E, height ext, per-slot packs | handled | — |
| `vs`, `ef`, `cs` | VSS / EFS / casters, as vent-art suffix | handled (suffix only) | yes |
| `rp` (+`wd` via pack) | ADA ramp on the WA door | handled (fused door part) | yes |
| `h` | order-level hinge | not read — redundant, hand rides the DRFRM pack | — |
| `f` | **foam color** | **dropped SILENTLY** (foam not built at all) | `Foam.skp` (no color variants) |
| `dk` | office desk | named as ignored | `DeskSmall.skp`, `DeskLarge.skp` |
| `dl` / `ds` / `dox` | desk Large / chosen slot / outside | **dropped SILENTLY** | (same) |
| `jp` / `ms` | MJP / chosen slot | `jp` named ignored; `ms` silent | `MJP.skp` |
| `sp` | step (with casters) | named as ignored | `StepFront.skp` |
| `cs` (rest of it) | the caster PLATE itself + 5" lift | **dropped SILENTLY** (only vent art swaps) | CP*.skp set |
| `ep` | **Elevated Floor Package** | **dropped SILENTLY** — not even in the ignored list | EFP*.skp (96192 MISSING — section 5) |
| `ad` | ADA bundle (door+ramp+floor) | **dropped SILENTLY** (door+ramp arrive via wd/rp; the floor is lost) | (same) |
| `rv` | roof-mounted vent | named as ignored | RM*.skp set EXISTS (RM60…RM192, _BACK, _VSS) — GOAL says out of scope |
| `sl` | studio light | named as ignored | **NO .skp** (portal draws only a window glow, no fixture) |
| `bt` | bass traps | named as ignored | **NO .skp**; portal doesn't draw them either (`ISO_DRAWS.bassTraps: false`) |
| `ac` | Audimute acoustic panel package | **dropped SILENTLY**; portal doesn't draw (`ISO_DRAWS.ap: false`) | **NO .skp** |
| `nv` | no-vent (NV plug walls) | handled via the NV packs in `a` | yes |
| `pk`, `fc`, `rm`, `rc`, `re`, `ver` | package origin, facing, room dims, meta | not geometry — safe to drop | — |

**Implied parts never in the payload at all** (the portal derives them from the walls):
- **Foam sheets** (section 1) and **duct covers** (section 2) — our scripts build neither.
  `Foam.skp` and `Duct Cover.skp` exist.
- **Isolation mat** — 5/16" under the whole Standard booth (`MAT_T_IN`, iso-render) — we
  don't build it; no dedicated .skp seen (**observed** absence; may be part of floor
  components — unverified).
- **Enhanced-only parts with NO portal art and no .skp**: the IEP FLOOR pad (5/16" black
  rubber the whole booth sits on — option `iep-floor` in options.json, "included on
  Enhanced models"). The Enhanced ceiling TRAY does now draw in iso (v2.431.0: 2" larger
  on each plan axis than the standard cap, ~1.8" thick, sits on the seam seals, REPLACES
  the standard ceiling entirely, no quarter-inch lift applied — `assets/iso-render.js:
  490-519`, **observed**) — whether our ENH deck already covers the tray is unverified
  from here (**assumed** gap; `scripts/wr-deck.rb` has zero foam/EFP/CP hits).
- **EFP perimeter strips** (Standard + EFP only, section 5) — a real product part with no
  art and no .skp; the portal fakes it with a vector prism.

---

## Build rules in one table (for the two Builders)

| part | wall rule | face | offsets (inches) | Standard | Enhanced |
|---|---|---|---|---|---|
| Foam sheet | each SOLID/VNT/CBL/NV panel of width 40 or 46 | interior, proud | centered: x=(w-24)/2, z=(ph-48)/2; ph 81/91 | on standard interior face | on IEP room face = +2.25" roomward; never both |
| Duct cover HIGH | each VNT 40/46 panel, NOT HX | interior, proud (3.14") | center [13.9, 71.1] (40) / [16.15, 71.45] (46); x from left edge seen from inside | standard interior face | IEP room face (+2.25") |
| Duct cover LOW | same | same | center [27.7, 9.1] (40) / [29.9, 9.45] (46) | same | same |
| Desk (S 30x14 / L 42x17) | chosen slot else auto (section 3); SOLID/VNT/CBL >=40 in; WDO >=40 out (S only) | interior flush (or exterior flush, S only) | centered on panel; surface 32.5" | interior face | IEP face (top-down); iso unmoved — open q |
| MJP | chosen slot else widest WDO/CBL else widest >=40 | BOTH faces, centered | plate center z 27.25"; plate 8.25 x 2.5 | both faces of the wall | interior box on IEP face — open q |
| EFP slab | one per booth, sizes in EFP_SIZES | on the carpet floor | centered in plan; 2.83-2.89" tall | + perimeter strips to the walls | flush to IEP walls (centered = flush) |
| Caster plate | one set per booth | under the floor, replaces 5/16" mat | footprint = published exterior; floor sits 0.739" into the tray; booth +5" | same | same (no variant test) |

## Confidence & gaps

- Foam and duct-cover rules: **high** — three renderers agree and Benton's own quoted
  rulings are embedded at the code sites. Weakest links: the exact sheet size (three art
  measurements disagree by <= 1.2") and which panel edge the duct x is measured from
  (stated as "left edge seen from inside", from `assets/layout-render.js:3369-3374`;
  sanity-check against one portal render before shipping).
- Desk/MJP: rules **high**; the Enhanced face question is genuinely open (portal
  self-inconsistent).
- EFP: geometry **high**, placement authored-not-measured by the portal's own admission;
  the 96192/96196 filename must be resolved by Benton.
- Caster plate: **high** for stack-up; per-size plate SET composition (which CP pieces per
  model) was NOT extracted — it lives in the manifest `fc[booth].cp` rows and
  `scripts/gen-iso-placeholders.js` CP block in the portal repo; the stream-3 Builder
  should read it there, or measure the .skp plates directly.
- Nothing here was executed — all placement numbers are read from portal source and its
  embedded measurements, none re-derived from pixels by me.
