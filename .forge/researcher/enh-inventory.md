# ENH library inventory — present/missing vs Standard

Source: full directory listing of `P:\Sketchup\NewMasterComponentList` taken 2026-08-24.
Method: filename analysis only — `ls` plus mechanical set arithmetic (Standard width → width − 4.5).
Every claim is marked `observed` (file listed directly) or `derived` (set difference on listings).
**Limitation, stated once:** a file existing proves only that a file with that name exists. It does
not prove the contents are correct, or that it is a true double-wall Enhanced part. Contents are
the probe's job (`scripts/probe-enhanced.rb`); nothing here is measured.

---

## THE AUTHORING QUEUE — files Benton still needs to create

Prioritised by "a real customer configuration from the booth builder fails on it."

### Priority 1 — hard failure on a live booth-from-link.rb code path

1. `ENH LeftWADoorWithRamp.skp` (derived — absent)
2. `ENH RightWADoorWithRamp.skp` (derived — absent)
3. `ENH LeftWADoorWithRamp_HX.skp` (derived — absent)
4. `ENH RightWADoorWithRamp_HX.skp` (derived — absent)
   - `scripts/booth-from-link.rb` line 116 emits `"#{hand}WADoorWithRamp"` whenever the customer
     picks the ramp option on a WA door. Confirmed: **no ENH ramp-door file of any kind exists**
     (`ls | grep -i "ENH.*Ramp"` returns nothing). Any Enhanced WA-door + ramp link is a hard failure.

### Priority 2 — hard failure on any Enhanced vent option (VSS / EFS / casters)

`booth-from-link.rb` lines 122–127 compose `<w>VNT` + `_VSS` + `_EFS` + `_CP` in that fixed order.
For Enhanced, **only the plain vents exist** (`ENH 35.5VNT`, `ENH 41.5VNT`, + `_HX`). All 28
option variants are missing (derived, from the full 16-file Standard matrix per width):

35.5 family (14 files):
`ENH 35.5VNT_VSS`, `_VSS_HX`, `_EFS`, `_EFS_HX`, `_VSS_EFS`, `_VSS_EFS_HX`,
`_CP`, `_CP_HX`, `_VSS_CP`, `_VSS_CP_HX`, `_EFS_CP`, `_EFS_CP_HX`, `_VSS_EFS_CP`, `_VSS_EFS_CP_HX`

41.5 family (14 files):
`ENH 41.5VNT_VSS`, `_VSS_HX`, `_EFS`, `_EFS_HX`, `_VSS_EFS`, `_VSS_EFS_HX`,
`_CP`, `_CP_HX`, `_VSS_CP`, `_VSS_CP_HX`, `_EFS_CP`, `_EFS_CP_HX`, `_VSS_EFS_CP`, `_VSS_EFS_CP_HX`

**Naming decision needed before authoring:** Standard's own CP files are `40Vnt_CP` / `46VntCP` /
`46vnt_VSS_CP` — three different casings and one missing underscore. Recommend Benton pick the
uniform `VNT_..._CP` form the composing code already emits (see inconsistency section), but that is
a decision for him/the Scoper, not something to normalise silently.

### Priority 3 — side vents: zero Enhanced coverage

Standard carries full 16-file matrices for `LeftSideVent*` and `RightSideVent*`
(plain/`_VSS`/`_EFS`/`_CP` combos × `_HX`) — observed. **No `ENH *SideVent*` file exists at all**
(observed — grep empty). If any Enhanced layout can take a side vent, all 32 are missing (derived).
Whether Enhanced layouts actually offer side vents is a portal/spec question — Scoper to confirm
before Benton authors 32 files.

### Priority 4 — ceiling/floor seam seals

All eight Standard `STDSS` files have **no Enhanced counterpart whatsoever** (derived — set
difference is exactly these eight): `STDSS CL5`, `STDSS CL6`, `STDSS CL7`, `STDSS CL8`,
`STDSS 8.5CL`, `STDSS FL6`, `STDSS FL7`, `STDSS FL8`.
Enhanced has only `ENH CornerSeamSeal(_HX)` and `ENH MidWallSeamSeal(_HX)` (observed).
If Enhanced multi-section decks need seam seals — physically likely — the `ENHSS` set (naming TBD)
must be authored. Sizes needed depend on Enhanced deck spans; Scoper/probe to confirm which.

### Priority 5 — open questions, not confirmed gaps

- `7Panel` / `7Panel_HX`: no Enhanced twin (a `2.5` would be the arithmetic match; none exists) —
  derived, and matches GOAL.md's expectation that this is by design. Needs a one-line confirmation
  from Benton, not authoring.
- Shared/unprefixed parts with no ENH twin: `CP30…CP192` (14 caster plates), `RM60…RM192` + `_BACK`
  + `_VSS` variants, `RMVentilation*`, `RMVSS_Stack_*`, `Duct Cover`, `Foam`, `MJP`,
  `RampSideView(_HX)`, `StepFront`, `DeskLarge/Small` — all observed present only unprefixed.
  Filenames cannot tell whether these are line-agnostic (used as-is for Enhanced) or need ENH
  versions. Note: `RampSideView` pairs with the WA ramp doors in Priority 1 — if the ramp geometry
  differs for Enhanced, an ENH ramp side-view may be needed too.
- `ENH 423.54CL` / `ENH 423.54FL`: suspected typo — see deck section. Rename/confirm, do not
  silently normalise.

---

## 1. Wall panels — present/missing table

Width map applied (derived rule, verified one-for-one by listing): 16→11.5, 19→14.5, 22→17.5,
28→23.5, 31→26.5, 40→35.5, 43→38.5, 46→41.5; 7→none.

| Standard (observed) | Expected ENH | ENH status |
|---|---|---|
| 7Panel, 7Panel_HX | ENH 2.5Panel(?) | **missing — believed intentional** (derived) |
| 16PanelSolid (+_HX) | ENH 11.5PanelSolid (+_HX) | present (observed) |
| 19Panel (+_HX) | ENH 14.5Panel (+_HX) | present (observed) |
| 22PanelSolid (+_HX) | ENH 17.5PanelSolid (+_HX) | present (observed) |
| 28Panel (+_HX) | ENH 23.5Panel (+_HX) | present (observed) |
| 31Panel (+_HX) | ENH 26.5Panel (+_HX) | present (observed) |
| 31Panel1648WDO (+_HX) | ENH 26.5Panel1648WDO (+_HX) | present (observed) — **and** `ENH 26.5Panel11.548WDO (+_HX)` also exists with a shifted window code; both codes are real files (observed) |
| 40NV (+_HX) | ENH 35.5NV (+_HX) | present (observed) |
| 40Panel2630/2636/2642/2648WDO (+_HX each) | ENH 35.5Panel2630/2636/2642/2648WDO (+_HX) | all present (observed) — window codes **unshifted** at 35.5 |
| 40PanelCBL (+_HX) | ENH 35.5PanelCBL (+_HX) | present (observed) |
| 40PanelSolid (+_HX) | ENH 35.5PanelSolid (+_HX) | present (observed) |
| 43Panel (+_HX) | ENH 38.5Panel (+_HX) | present (observed) |
| 43Panel2636/2648WDO (+_HX each) | ENH 38.5Panel2636/2648WDO (+_HX) | present (observed) — codes unshifted |
| 46NV (+_HX) | ENH 41.5NV (+_HX) | present (observed) |
| 46Panel3230/3236/3242/3248WDO (+_HX each) | ENH 41.5Panel3230/3236/3242/3248WDO (+_HX) | all present (observed) — codes unshifted |
| 46PanelCBL (+_HX) | ENH 41.5PanelCBL (+_HX) | present (observed) |
| 46PanelSolid (+_HX) | ENH 41.5PanelSolid (+_HX) | present (observed) |

**Window-code finding (observed, not assumed):** ENH WDO panels keep the Standard window code
(`2630`, `2648`, `3248`, `1648`…) at every width **except** 26.5, where both `1648` (unshifted) and
`11.548` (shifted by 4.5) exist side by side. One of the two 26.5 pairs is presumably the odd one
out; translation code should map Standard `31Panel1648WDO` → `ENH 26.5Panel1648WDO` (exists) and
treat `11.548` as an alias/duplicate until Benton says which is canonical.

Non-vent wall panel coverage is otherwise **complete** — the mechanical diff of every derived name
against the ENH listing produced zero missing non-vent wall files (derived).

## 2. Doors

| Standard (observed) | ENH counterpart | Status |
|---|---|---|
| Left40Door (+_HX) | ENH Left35.5Door (+_HX) | present (observed) |
| Right40Door (+_HX) | ENH Right35.5Door (+_HX) | present (observed) |
| Left46Door (+_HX) | ENH Left41.5Door (+_HX) | present (observed) |
| Right46Door (+_HX) | ENH Right41.5Door (+_HX) | present (observed) |
| LeftWADoor (+_HX) | ENH LeftWADoor (+_HX) | present (observed) |
| RightWADoor (+_HX) | ENH RightWADoor (+_HX) | present (observed) |
| LeftWADoorWithRamp (+_HX) | ENH LeftWADoorWithRamp (+_HX) | **MISSING** (derived — confirmed, see queue #1) |
| RightWADoorWithRamp (+_HX) | ENH RightWADoorWithRamp (+_HX) | **MISSING** (derived) |

The suspicion in the task brief is **confirmed**: both ramp doors and their `_HX` twins are absent.

## 3. Vents — the full matrix

Standard 40/46 built-in vents, 16 files per width (observed):
plain, `_VSS`, `_EFS`, `_VSS_EFS`, `_CP`, `_VSS_CP`, `_EFS_CP`, `_VSS_EFS_CP`, each × `_HX`.

Composed name from `booth-from-link.rb` (order `_VSS`,`_EFS`,`_CP`) vs what exists:

| Options | Composed (per code) | Standard 40 file | Standard 46 file | ENH 35.5 | ENH 41.5 |
|---|---|---|---|---|---|
| none | `<w>VNT` | 40VNT | 46VNT | **ENH 35.5VNT** present | **ENH 41.5VNT** present |
| VSS | `<w>VNT_VSS` | 40VNT_VSS | 46VNT_VSS | **missing** | **missing** |
| EFS | `<w>VNT_EFS` | 40VNT_EFS | 46VNT_EFS | **missing** | **missing** |
| VSS+EFS | `<w>VNT_VSS_EFS` | 40VNT_VSS_EFS | 46VNT_VSS_EFS | **missing** | **missing** |
| CP | `<w>VNT_CP` | 40**Vnt**_CP (case differs) | 46**VntCP** (case + no underscore) | **missing** | **missing** |
| VSS+CP | `<w>VNT_VSS_CP` | 40**Vnt**_VSS_CP | 46**vnt**_VSS_CP | **missing** | **missing** |
| EFS+CP | `<w>VNT_EFS_CP` | 40**Vnt**_EFS_CP | 46**Vnt**_EFS_CP | **missing** | **missing** |
| VSS+EFS+CP | `<w>VNT_VSS_EFS_CP` | 40**Vnt**_VSS_EFS_CP | 46**Vnt**_VSS_EFS_CP | **missing** | **missing** |

(Each row also has an `_HX` twin with identical present/missing status — observed for Standard,
derived for ENH.) All claims from the listing; the ENH "missing" cells are the 28 files in queue
Priority 2.

**Which composed names resolve for Enhanced:** only the no-options row. Every option flag on an
Enhanced built-in vent composes a filename that does not exist — silent hard failure per config.

Side vents (`LeftSideVent*` / `RightSideVent*`): Standard has both full 16-file matrices with
*consistent* casing (observed). Enhanced has **zero** side-vent files (observed) — queue Priority 3.

## 4. Deck parts (floors/ceilings)

Mechanical diff `sed s/^STD// | comm` against `ENH `-stripped names (derived):

- **Every Standard deck name has an exact ENH twin** — all of: `10218CL/FL CTR`,
  `10242CL/FL CTR|SIDE`, `127LPCL/FL`, `4230/4242/4260/4284/4848/4872/4896 CL+FL`,
  `6018CL/FL SIDE R`, `6042CL/FL SIDE L|R`, `7224CL/FL SIDE R`, `7248CL/FL SIDE L|R`,
  `8418 CL/FL` (space before CL/FL, same anomaly both lines), `8442CL/FL CTR|SIDE`,
  `9624CL/FL CTR`, `9648CL/FL CTR|SIDE`. Deck coverage: **complete parity**, no authoring needed.
- The only STD names without ENH twins are the eight `STDSS` seam seals (section 5).
- The only ENH deck names without STD twins: **`ENH 423.54CL` / `ENH 423.54FL`** (observed).
  These do not parse as `WWLL` (4230 = 42×30, etc.). Suspected typo. Plausible intents:
  a `42 × 3.54` filler strip unique to the double-wall geometry, or a mistyped `4230`/`4254`.
  Filenames cannot decide this — **ask Benton; do not silently normalise or delete.**

## 5. Seam seals

- `ENH CornerSeamSeal(_HX)`, `ENH MidWallSeamSeal(_HX)` — present (observed).
- The eight `STDSS` ceiling/floor seam seals (`STDSS CL5/CL6/CL7/CL8`, `STDSS 8.5CL`,
  `STDSS FL6/FL7/FL8`) have **no Enhanced counterpart at all** — confirmed by set difference
  (derived); no `ENHSS*` or `ENH *SS*` deck-seal file exists.

## 6. Everything else with no ENH twin

Observed present only unprefixed (no `ENH` version, no `STD` prefix either — likely shared, but
unverifiable from names): `CP30/42/48/60/72/84/96/102/120/126/144/168/186/192`,
`RM60/72/84/96/102/120/126/144/168/186/192` (+`_BACK`, `_VSS`, `_VSS_BACK` variants),
`RMVentilationIntakeBox`, `RMVentilationExhaustBox`, `RMVentilation(VSS)Left/RightSideView`,
`RMVSS_Stack_Left/RightSideView`, `RampSideView(_HX)`, `StepFront`, `Duct Cover`, `Foam`, `MJP`,
`DeskLarge`, `DeskSmall`. Whether any of these must differ for Enhanced (different footprint,
different wall thickness at the roof line) is a physical/spec question for the Scoper and probe.

---

## Naming inconsistencies that will break filename-composing code

`booth-from-link.rb` composes names mechanically; these observed irregularities are landmines:

1. **Vent casing chaos (Standard, inherited risk for ENH):** `40VNT_VSS` but `40Vnt_CP`;
   `46VNT_EFS` but `46Vnt_EFS_CP` and lowercase `46vnt_VSS_CP`. Composed `#{w}VNT_..._CP` matches
   these only because NTFS is case-insensitive — any case-sensitive lookup (SketchUp definition
   names, hash keys, a future Mac/network path) breaks.
2. **`46VntCP` has no underscore before `CP`** — composed `46VNT_CP` does **not** match even
   case-insensitively. This is a live break on *Standard* casters-only 46-vent configs, not just
   Enhanced. (Both `46VntCP` and `46VntCP_HX` observed.)
3. **`ENH ` prefix contains a space** (`ENH 41.5PanelSolid.skp`) while `STD` deck prefix does not
   (`STD4230CL.skp`) — regexes like `wr-deck.rb` line 283's `STD`-anchored pattern miss all ENH
   decks (GOAL.md already notes this).
4. **`8418 CL` / `8418 FL`** (both STD and ENH) have a space before CL/FL that no other deck name
   has (`8442CL` etc.).
5. **`STDSS ` uses a space** after the prefix while other STD parts do not; and within STDSS the
   size position flips: `STDSS CL5` (size after role) vs `STDSS 8.5CL` (size before role).
6. **`ENH 26.5Panel` window-code duality:** `11.548WDO` (shifted) and `1648WDO` (unshifted) both
   exist; every other ENH width uses unshifted codes only. Whichever the translator emits, the
   other file is dead weight or the intended one — Benton to rule.
7. **`ENH 423.54CL/FL`** — unparseable size token (section 4).

---
Totals if every gap above is real: 4 ramp-door files + 28 vent-option files + 32 side-vent files
(pending confirmation Enhanced offers side vents) + 8 deck seam seals = **72 candidate files**, of
which **32 (ramp doors + vent options)** sit on already-confirmed booth-from-link.rb code paths.
