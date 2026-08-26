# Probe Component Files — 370 parts, 2026-08-26 (v2, sourced from the TSV)

> **Source change, and it is the point of this revision.** v1 of this document was transcribed
> from a terminal paste because the `P:` share was unreachable, and it carried a warning to
> re-read the TSV if `P:` came back. **`P:` came back.** Every figure below is now read
> directly from `P:\Sketchup\NewMasterComponentList\_component-probe.tsv`
> (43,857 bytes, 371 lines = header + 370 rows, written 2026-08-26 17:26 by
> `scripts/probe-components.rb`). **observed.**
>
> The audit of v1 against the TSV is in "What the transcription got right and wrong" below.
> Corrections are called out there explicitly rather than silently folded into the text.
>
> Reproduce with: `python .forge/fixer/analyze-component-probe.py <path-to-tsv>`

## What the transcription got right and wrong

**The v1 transcription was accurate. Every number in it survives contact with the TSV.**
That is a real result, not a null one — it means the paste-derived conclusions were not
built on garbled figures.

Checked and **confirmed**, all observed:

- All 11 rows of the width-axis table (x, y and `RUNS` for `40Panel2636WDO`, `40PanelSolid`,
  `16PanelSolid`, `31Panel`, `40VNT`, `RightWADoor`, `MidWallSeamSeal`,
  `ENH 35.5Panel2636WDO`, `ENH 35.5PanelSolid`, `ENH 11.5PanelSolid`, `ENH 35.5VNT`) —
  exact matches, to all four decimal places.
- The origin-anchor histogram, all ten buckets, exactly: 140 `min/min/min`, 107 `?/?/?`,
  40 `?/?/min`, 30 `min/?/min`, 20 `min/min/?`, 12 `min/?/?`, 12 `?/min/min`, 4 `?/min/?`,
  4 `min/mid/min`, 1 `max/min/min`.
- "20 parts do not measure the number in their name, all vent option variants" — exactly 20,
  and they are exactly the `40VNT`/`40Vnt`/`46VNT`/`46Vnt` `_EFS` and `_VSS` variants.
  Reproduced using the probe's own rule (`scripts/probe-components.rb:187-193`: leading
  digits of the *filename*, skipped under 5, flagged over 0.02in). `40VNT_EFS` = 48.9369
  and `40VNT_VSS_EFS` = 56.1824 both confirmed.
- `STD7224FL SIDE R` is the only `max/min/min` anchor in all 370, and measures 37.9375.
- `ENH 8418 FL` and `STD8418 FL` both measure 17.9375, 1/16in under nominal.

**One claim is corrected, and it is a substantive correction:**

> v1 said: *"Every X-running part above has an `_HX` sibling that runs **Y**… Consistent
> across the whole set."*

**That is false across all 370.** It was true of the four pairs v1 sampled, and those four
still check out. But over the 99 `_HX` pairs that actually exist, the axis flips in **both**
directions: 26 pairs go X→Y as v1 described, and **16 pairs go the other way, Y→X** — the
whole `LeftSideVent`/`RightSideVent` family plus `7Panel`. A further 56 pairs do not flip at
all. See `.forge/fixer/WIDTH-AXIS-FAMILY-2026-08-26.md` for the full enumeration.

The *operational* warning v1 drew from its sample is unchanged and if anything stronger:
**a rule keyed on the part name must not assume the HX sibling shares the non-HX axis.**
v1 got the right lesson from an incomplete sample.

## THE FINDING — the width axis splits by family, and the split is real

`RUNS` is the axis the part's WIDTH lies on — computed as `w >= d ? 'X' : 'Y'`
(`scripts/probe-components.rb:80`). Across 370 parts: **115 X, 255 Y**. observed.

| part | x | y | RUNS |
|---|---:|---:|:--:|
| `40Panel2636WDO` | **40.0000** | 1.7500 | **X** |
| `40PanelSolid` | 1.0000 | **40.0000** | **Y** |
| `16PanelSolid` | 1.0000 | **16.0000** | **Y** |
| `31Panel` | 1.0000 | **31.0000** | **Y** |
| `40VNT` | **40.0000** | 8.5468 | **X** |
| `RightWADoor` | 29.4965 | **49.0000** | **Y** |
| `MidWallSeamSeal` | **7.7500** | 2.0000 | **X** |
| `ENH 35.5Panel2636WDO` | **35.5000** | 1.8125 | **X** |
| `ENH 35.5PanelSolid` | 2.0625 | **35.6250** | **Y** |
| `ENH 11.5PanelSolid` | 1.1563 | **11.5000** | **Y** |
| `ENH 35.5VNT` | **35.7500** | 2.3750 | **X** |

**The W wall of the 102144 E is `W0 = 40Panel2636WDO` (runs X), `W1 = 16PanelSolid` (runs Y),
`W2 = 40PanelSolid` (runs Y).** The window panel is in a different width-axis family from both
its neighbours. The vents are in that same X family — and `IEP_VENT_YAW = 180`
(`scripts/build-booth-components.rb:221`) patches the vents while the WDO panels get nothing.

**That is hypothesis A, carried by measurement rather than inference.** It also explains
"on both": the 96144 E has a window too.

### Correction to an earlier reading (carried over from v1, still stands)

The build console's `FACING` column showed `W0`, `W1`, `W2` all as `X+ IN`, and that was taken
as evidence against hypothesis A. It was not. **`FACING` reports the thickness sense; `RUNS`
reports the width axis.** They are different properties and only the second one was ever in
question. Do not reuse the earlier conclusion.

## Blast radius — the outer shell is affected too

`40Panel2636WDO` is the **outer** (Standard) window panel and it runs X exactly as the inner
`ENH 35.5Panel2636WDO` does. So this is not confined to the Enhanced path.

Benton, asked whether a Standard 96144/102144 builds its side walls correctly today:
*"No neither 96144 or 102144 have the correct side wall positions from the link."* Read that as
covering both builds. **It still means editing shared Standard code, and `.forge/GOAL.md` puts
"changing how Standard booths resolve or place" out of scope. Confirm with Benton before
shipping a change that moves Standard geometry.**

## Authoring defect found in this data — `RightSideVent_CP_HX`

**`RightSideVent_CP_HX.skp` never received its HX rework.** Its definition is correctly *named*
`RightSideVent_CP_HX`, but every measured property is identical to the non-HX twin
`RightSideVent_CP`: x=8.5468, y=46.0000, z=86.6128, origin offset (0.0000, -1.0000, 4.7500),
anchor `min/?/?`, **1 entity**. Its mirror `LeftSideVent_CP_HX` is x=46.0000, y=8.5468,
z=96.6128, anchor `min/min/min`, **3 entities**. observed.

It is the **only** one of 99 `_HX` pairs whose Z delta is not +10in (it is +0.0000), and the
**only** `_HX` part in the set that is dimensionally identical to its twin.

This is a **component-authoring defect, not a code defect** — the fix is in the .skp file, and
Benton authors components. Full detail and the sweep that found it are in
`.forge/fixer/WIDTH-AXIS-FAMILY-2026-08-26.md`.

## Other facts, all re-read from the TSV

- **The origin anchor is a MIX** — ten distinct anchors across 370 parts (histogram above).
  The probe's own note: *"A SINGLE anchor across the set means one placement rule works for
  everything. A mix means placement has to go by bounding box."* That note is binding.
- **20 parts do not measure the number in their name**, all vent option variants.
  Consistent with the packaged-box lesson from v1.6.21: the name is the module width, the box
  is the module plus hardware.
- `STD7224FL SIDE R` is the only `max/min/min` anchor and measures 37.9375 on a 24 name —
  the part the DEVLOG already records as a seating trap.
- `ENH 8418 FL` measures 17.9375, 1/16 under nominal, as does `STD8418 FL`. Already known.
- **New, not in v1:** `RightWADoorWithRamp_HX` is the only `_HX` part in the set with **no
  non-HX twin**. Its would-be twin is named `RightWADoorWithRamp#1` — the `#1` suffix is
  SketchUp's duplicate-definition marker, so a name-keyed lookup for `RightWADoorWithRamp`
  will miss it. Worth a look, but not chased here.
- **New, not in v1:** `ENH LeftWADoor_HX` and `ENH RightWADoor_HX` are +9.9908in over their
  twins, not +10.0000 — 0.0092in (~1/128) under. Probably deliberate door-leaf clearance
  rather than a defect, but it is the only other Z-rule deviation in the set. **assumed** —
  not confirmed with Benton.

## Still NOT answered by this probe

This gives bounding boxes and anchors, **not face levels**. The IEP tray orientation still
abstains for want of `_face-levels.tsv` rows for `ENH` parts. That needs
`scripts/probe-levels.rb` run over the folder with an **empty** filter — a different tool from
the one Benton ran.

Note that `_face-levels.tsv` on the share is dated **2026-08-14** and is the stale
Standard-only measurement. **No `ENH` part has ever been face-level probed.** Do not use that
file to answer width-axis or Enhanced questions.
