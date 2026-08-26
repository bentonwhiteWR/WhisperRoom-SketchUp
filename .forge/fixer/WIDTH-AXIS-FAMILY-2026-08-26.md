# The width-axis family split — fully characterised, 2026-08-26

Closes open item 4 of `.forge/fixer/HANDOFF.md` ("The width-axis family split is still open
and untouched").

**Source, and it is the only source:** `P:\Sketchup\NewMasterComponentList\_component-probe.tsv`
— 43,857 bytes, header + 370 rows, written 2026-08-26 17:26 by `scripts/probe-components.rb`
running inside SketchUp over the 370 `.skp` files on the share. **observed.**

That TSV is an *independent* witness for the questions asked here: it is a fresh measurement of
the component files themselves, not a copy of, and not derived from, any `.md` in this repo or
any `.rb` under `scripts/`. This is deliberate — see
`.forge/fixer/ROOTCAUSE-side-wall-order-2026-08-26.md` for the two findings retracted on
2026-08-26 because a harness checked an artifact against a stale copy of itself.

**Reproduce:** `python .forge/fixer/analyze-component-probe.py <path-to-tsv>`
**Diagnosis only. No `.rb` was modified. `scripts/wr_tools/VERSION` is untouched at 1.6.29.
Nothing was written to `P:`.**

---

## THE ANSWER, in three lines

1. **The X/Y split is ad hoc per file. There is no name-level rule.** The best rule I could
   construct still misses **20 of 194** wall parts (89.7%), and the misses are not a tidy
   family — they include four WDO panels, the entire `46VNT` cohort, and both WA-door ramps.
2. **The `_HX` convention claimed in the previous document is false.** The axis flips in
   *both* directions (26 pairs X→Y, 16 pairs Y→X) and 56 pairs do not flip at all.
3. **Placement must go by measured bounding box, not by part name.** This was already implied
   by the mixed origin anchor; the axis data makes it unavoidable.

---

## 1. What `runs` actually is (read this before using any table below)

`runs` is computed at `scripts/probe-components.rb:80`:

    row[:runs] = row[:w] >= row[:d] ? 'X' : 'Y'

It is **purely a comparison of the two horizontal bounding-box dimensions** — "is the part
wider on X or on Y". Two consequences that the previous document did not account for:

- **It is only meaningful for thin parts.** For a wall panel (thickness 1–2.5in) `runs` really
  does name the wall-plane axis. For a floor or ceiling slab, *both* dimensions are large, so
  `runs` just reports which footprint edge is longer — a completely different property that
  happens to share a column. **Do not mix them.** Of 370 parts, only **114** have
  `min(x,y) <= 3in`, i.e. are panel-like.
- **`>=` means ties break to X.** That matters, and section 3 shows it produces contradictory
  results on real parts.

Across all 370: **115 run X, 255 run Y.** observed.

---

## 2. Which parts run X, exhaustively

Full enumeration in **Appendix A**. Summary of what is in it:

| group | X | Y | uniform? |
|---|---:|---:|:--|
| `RM*` reference drawings | 31 | 0 | uniform X — these are 2D side-view drawings, not parts |
| `*PanelSolid` | 0 | 16 | uniform Y |
| `*Door` (non-WA) | 0 | 16 | uniform Y |
| `CP*` corner posts | 4 | 27 | uniform Y once the 4 square `CP42/CP48` are excluded (section 3) |
| `MidWallSeamSeal` | 4 | 0 | uniform X |
| `*WADoorWithRamp` | 4 | 0 | uniform X |
| `*WDO` window panels | 19 | 25 | **MIXED** |
| `*VNT` / `*Vnt` vents (excl. side vents) | 9 | 27 | **MIXED** |
| `*SideVent` | 15 | 17 | **MIXED** |
| `*CL` / `*FL` slabs | 19 | 83 | **MIXED** — but see section 1; not a wall axis |

**The clean families are clean.** Solid panels, doors and corner posts are uniformly Y;
mid-wall seam seals and WA-door ramps are uniformly X. If the split were only these, a name
rule would work.

**The three mixed families are where it breaks**, and they are exactly the families that
matter for the 96144/102144 side wall.

### 2a. WDO window panels — mixed, and not by width

Non-HX WDO panels *mostly* run X, with four exceptions:

| runs X (18) | runs Y (4 — the exceptions) |
|---|---|
| `40Panel2630/2636/2642/2648WDO` | `31Panel1648WDO` |
| `46Panel3230/3236/3242/3248WDO` | `43Panel2636WDO` |
| `ENH 26.5Panel1648WDO` | `43Panel2648WDO` |
| `ENH 35.5Panel2630/2636/2642/2648WDO` | `ENH 38.5Panel2648WDO` |
| `ENH 38.5Panel2636WDO` | |
| `ENH 41.5Panel3230/3236/3242/3248WDO` | |

Note `ENH 38.5Panel2636WDO` runs **X** while `ENH 38.5Panel2648WDO` runs **Y** — same module
width, same family, different axis. **That single pair kills any width-based or family-based
rule on its own.** The only difference between them is the window size in the name.

### 2b. Vents — split by module width, but the WDO panels do not follow the same split

| | runs |
|---|:--|
| `40VNT`, `40VNT_EFS`, `40VNT_VSS`, `40VNT_VSS_EFS`, and all four `40Vnt_*_CP` | **X** |
| `46VNT`, `46VNT_EFS`, `46VNT_VSS`, `46VNT_VSS_EFS`, and all four `46Vnt*CP` | **Y** |
| `ENH 35.5VNT` | **X** |
| `ENH 41.5VNT` | **Y** |

This looks like a beautiful rule — the 40/35.5 cohort (the short W wall) runs X, the 46/41.5
cohort (the long L wall) runs Y. **It does not generalise.** `46Panel3236WDO` is a 46-cohort
part and it runs **X**, against the vent pattern. So the cohort rule holds inside the vent
family and nowhere else.

### 2c. Side vents — the axis lives on the `_HX` flag, with one defect

All 16 non-HX `*SideVent*` parts run **Y**. Fifteen of the sixteen `_HX` siblings run **X**.
The sixteenth is `RightSideVent_CP_HX`, and it is broken — section 4.

---

## 3. The square-part trap — 17 parts whose `runs` is floating-point noise

17 of the 370 parts have `x` and `y` equal to within 0.01in. For these, `runs` is decided by
the `>=` tie-break in `probe-components.rb:80` resolving a difference **below the TSV's own
four-decimal display precision**. It carries no authoring meaning whatsoever.

The proof is that identically-shaped parts disagree:

| part | x | y | runs |
|---|---:|---:|:--:|
| `ENH CornerSeamSeal` | 5.3750 | 5.3750 | **X** |
| `ENH CornerSeamSeal_HX` | 5.3750 | 5.3750 | **Y** |
| `ENH 4848CL` | 50.0000 | 50.0000 | **X** |
| `STD4848CL` | 48.0000 | 48.0000 | **Y** |
| `STD4242CL` | 42.0000 | 42.0000 | **X** |
| `STD4848FL` | 48.0000 | 48.0000 | **Y** |

The full 17: `CP42`, `CP4242`, `CP48`, `CP4848`, `CornerSeamSeal`, `CornerSeamSeal_HX`,
`ENH 4242CL`, `ENH 4242FL`, `ENH 4848CL`, `ENH 4848FL`, `ENH CornerSeamSeal`,
`ENH CornerSeamSeal_HX`, `STD127LPCL`, `STD4242CL`, `STD4242FL`, `STD4848CL`, `STD4848FL`.

**Consequence for the previous document:** its `ENH CornerSeamSeal` X→Y "flip" was one of
these. Excluding squares, the real count of axis-flipping `_HX` pairs is **42, not 43**.

**Consequence for any future code:** never branch on `runs` for a part whose two horizontal
dimensions are within a tolerance of each other. It is a coin flip.

---

## 4. The `_HX` convention — the previous claim is false, and one file is defective

### 4a. The pairing

100 parts end in `_HX`. **99 have a non-HX twin; one does not** —
`RightWADoorWithRamp_HX`. Its would-be twin is in the set under the name
`RightWADoorWithRamp#1`. The `#1` is SketchUp's duplicate-definition suffix, so **any
name-keyed lookup for `RightWADoorWithRamp` will miss it.** Flagged, not chased.

### 4b. The axis claim, retracted

The previous document claimed, from a sample of four pairs, that *"every X-running part has an
`_HX` sibling that runs Y."* Across all 99 pairs:

| | pairs |
|---|---:|
| non-HX X → HX Y (the claimed direction) | 26 |
| non-HX Y → HX X (**the opposite direction**) | 16 |
| no flip at all | 56 |
| square-noise flip (not real) | 1 |

The 16 reverse cases are the `LeftSideVent`/`RightSideVent` family (15) plus `7Panel`
(`7Panel` runs Y at 1.0000 × 7.0000; `7Panel_HX` runs X at 7.0000 × 1.1250).

Full enumeration in **Appendix B** (flipping) and **Appendix C** (non-flipping).

The 10 pairs that flip without a clean x↔y swap all differ only by HX thickness
(1.7500 → 1.8125, or 1.0000 → 1.1250). That is expected and is not an anomaly.

### 4c. The +10in height rule, and its three deviations

96 of 99 pairs satisfy `z(HX) == z(non-HX) + 10.0000in` exactly. The three that do not:

| non-HX | z | `_HX` | z | delta |
|---|---:|---|---:|---:|
| `ENH LeftWADoor` | 79.5000 | `ENH LeftWADoor_HX` | 89.4908 | +9.9908 |
| `ENH RightWADoor` | 79.5000 | `ENH RightWADoor_HX` | 89.4908 | +9.9908 |
| `RightSideVent_CP` | 86.6128 | **`RightSideVent_CP_HX`** | **86.6128** | **+0.0000** |

The two WA doors are 0.0092in (~1/128) under. Plausibly deliberate door-leaf clearance.
**assumed** — not confirmed with Benton, and worth one look but not a defect claim.

### 4d. `RightSideVent_CP_HX` IS a defect — component authoring, not code

The assignment flagged a suspected Z = 86.6128 on this part. **It is real, and the problem is
larger than the Z.** The part is not merely mis-measured; **the HX rework was never applied to
it at all.**

| property | `RightSideVent_CP` | `RightSideVent_CP_HX` | `LeftSideVent_CP_HX` (correct mirror) |
|---|---|---|---|
| x | 8.5468 | **8.5468** | 46.0000 |
| y | 46.0000 | **46.0000** | 8.5468 |
| z | 86.6128 | **86.6128** | 96.6128 |
| runs | Y | **Y** | X |
| anchor | `min/?/?` | **`min/?/?`** | `min/min/min` |
| origin | 0.0000, -1.0000, 4.7500 | **0.0000, -1.0000, 4.7500** | 0.0000, 0.0000, -0.0000 |
| entities | 1 | **1** | 3 |

**Every single measured property of the `_HX` file matches the non-HX twin exactly**, including
the origin offset and the entity count. Its correctly-authored mirror `LeftSideVent_CP_HX` has
3 entities, the swapped footprint, and +10in of height. All seven other `RightSideVent_*_HX`
parts are correct.

It is the only part in all 370 with this signature — the only `_HX` dimensionally identical to
its twin, and the only pair with a +0.0000 Z delta.

**Corroborating evidence from a second, independent source** (file bytes on the share, not the
probe's measurements): `RightSideVent_CP_HX.skp` is **349,650 bytes** while its correct mirror
`LeftSideVent_CP_HX.skp` is **387,210 bytes** and the non-HX `RightSideVent_CP.skp` is
**387,262 bytes**. So it is *not* a byte-copy of the non-HX file — it is a distinct file whose
definition is correctly *named* `RightSideVent_CP_HX` but which carries un-reworked geometry.
Read that as: someone opened the file and renamed the definition, and the geometry work was
either never done or was reverted.

**Expected values, if Benton re-authors it** (derived by mirroring `LeftSideVent_CP_HX`):
x = 46.0000, y = 8.5468, z = 96.6128, anchor `min/min/min`, origin (0, 0, 0), 3 entities.

**This is a component-authoring defect. The fix is in the `.skp`, on the share, and Benton
authors components. No code change is implied and none is proposed.** `P:` is read-only to
me; I have not touched it. Nothing under `scripts/` references this part by name — parts are
resolved dynamically — so there is no code-side workaround to write either.

---

## 5. Is a name-keyed rule safe to write? No.

I built the most generous name rule the data supports, over the **194 wall parts** (excluding
floor/ceiling slabs, `RM*` reference drawings, furniture, and the 17 square parts):

    MidWallSeamSeal          -> X
    other *SeamSeal          -> Y
    *SideVent  and _HX       -> X ;  *SideVent  and not _HX -> Y
    (*WDO or *VNT) and not _HX -> X
    everything else          -> Y

**It gets 174 of 194 right — and misses 20.** The misses:

| part | rule says | actually |
|---|:--:|:--:|
| `31Panel1648WDO` | X | Y |
| `43Panel2636WDO` | X | Y |
| `43Panel2648WDO` | X | Y |
| `ENH 38.5Panel2648WDO` | X | Y |
| `ENH 26.5Panel1648WDO_HX` | Y | X |
| `46VNT`, `46VNT_EFS`, `46VNT_VSS`, `46VNT_VSS_EFS` | X | Y |
| `46VntCP`, `46Vnt_EFS_CP`, `46Vnt_VSS_EFS_CP`, `46vnt_VSS_CP` | X | Y |
| `ENH 41.5VNT` | X | Y |
| `7Panel_HX` | Y | X |
| `LeftWADoorWithRamp`, `LeftWADoorWithRamp_HX` | Y | X |
| `RightWADoorWithRamp#1`, `RightWADoorWithRamp_HX` | Y | X |
| `RightSideVent_CP_HX` | X | Y |

One of those 20 (`RightSideVent_CP_HX`) is the authoring defect and would go away if the part
were fixed. **The other 19 are real authoring choices with no name-level pattern.**

You can of course special-case all 19 into a lookup table — but a hard-coded table of 194 part
names *is* the bounding box, only stale and hand-maintained. Each new part Benton authors would
silently take the wrong default.

### The recommendation

**Resolve the width axis from the measured bounding box at build time, not from the name.**
This is the same conclusion the probe reaches independently from the anchor distribution:

> *"A SINGLE anchor across the set means one placement rule works for everything. A mix means
> placement has to go by bounding box."*

The anchor distribution is a mix — 10 distinct anchors over 370 parts, with `min/min/min`
covering only 140 of them. So placement already had to read the bounding box. Reading the
width axis from the same bounding box is free.

**No code change is proposed here, and none has been made.** Writing one would touch the outer
Standard shell as well as Enhanced, and `.forge/GOAL.md` puts *"changing how Standard booths
resolve or place"* out of scope. This document is the evidence Benton needs to green-light or
refuse that change; the change itself is his call.

---

## 6. What this does NOT settle

- **Which end of the side wall the window belongs at.** That is open question 1 in
  `HANDOFF.md` and is still unanswerable from anything on disk. The axis data says the window
  panel is authored on a different axis from its neighbours; it does not say which end is
  correct.
- **Face levels.** This probe measures bounding boxes and anchors only. The IEP tray
  orientation still abstains. `_face-levels.tsv` on the share is dated **2026-08-14**, is
  Standard-only, and **no `ENH` part has ever been face-level probed.** That needs
  `scripts/probe-levels.rb` with an empty filter — a different tool. Do not use that file for
  width-axis questions.
- **Whether `runs` matches the panel's in-model orientation after placement.** The TSV
  measures the definition in its own space. Confirming the built result needs SketchUp, which
  I cannot run.

---

## Appendices — generated directly from the TSV, not transcribed

### A. Every X-running part, exhaustively (115 rows)

14 of these are SQUARE: x and y are equal, so `runs` is not an authoring choice at
all -- see section 3.

| part | x | y | z | anchor | note |
|---|---:|---:|---:|:--|:--|
| `40Panel2630WDO` | 40.0000 | 1.7500 | 81.0000 | `?/?/min` |  |
| `40Panel2636WDO` | 40.0000 | 1.7500 | 81.0000 | `?/?/min` |  |
| `40Panel2642WDO` | 40.0000 | 1.7500 | 81.0000 | `?/?/min` |  |
| `40Panel2648WDO` | 40.0000 | 1.7500 | 81.0000 | `?/?/min` |  |
| `40VNT` | 40.0000 | 8.5468 | 82.0000 | `?/?/min` |  |
| `40VNT_EFS` | 48.9369 | 12.1250 | 87.1997 | `min/?/?` |  |
| `40VNT_VSS` | 41.6856 | 8.5845 | 82.3212 | `?/min/?` |  |
| `40VNT_VSS_EFS` | 56.1824 | 12.3066 | 81.9535 | `min/?/min` |  |
| `40Vnt_CP` | 40.0000 | 8.5468 | 86.6128 | `?/?/?` |  |
| `40Vnt_EFS_CP` | 48.9369 | 12.1250 | 87.1997 | `min/?/?` |  |
| `40Vnt_VSS_CP` | 41.6856 | 8.6340 | 87.0683 | `?/min/?` |  |
| `40Vnt_VSS_EFS_CP` | 55.6250 | 12.0986 | 87.1976 | `?/?/?` |  |
| `46Panel3230WDO` | 46.0000 | 1.7500 | 81.0000 | `?/?/min` |  |
| `46Panel3236WDO` | 46.0000 | 1.7500 | 81.0000 | `?/?/min` |  |
| `46Panel3242WDO` | 46.0000 | 1.7500 | 81.0000 | `?/?/min` |  |
| `46Panel3248WDO` | 46.0000 | 1.7500 | 81.0000 | `?/?/min` |  |
| `7Panel_HX` | 7.0000 | 1.1250 | 91.0000 | `min/min/min` |  |
| `CP42` | 44.0000 | 44.0000 | 5.3674 | `min/min/?` | **SQUARE - noise** |
| `CP4242` | 44.0000 | 44.0000 | 5.3674 | `min/min/?` | **SQUARE - noise** |
| `CP48` | 50.0000 | 50.0000 | 5.3674 | `min/min/min` | **SQUARE - noise** |
| `CP4848` | 50.0000 | 50.0000 | 5.3674 | `min/min/min` | **SQUARE - noise** |
| `CornerSeamSeal` | 4.8750 | 4.8750 | 81.0000 | `min/min/min` | **SQUARE - noise** |
| `CornerSeamSeal_HX` | 4.8750 | 4.8750 | 91.0000 | `min/min/min` | **SQUARE - noise** |
| `Duct Cover` | 23.7500 | 3.1188 | 80.2590 | `min/min/?` |  |
| `ENH 127LPCL` | 64.1749 | 53.1272 | 1.7500 | `min/min/min` |  |
| `ENH 127LPFL` | 61.8157 | 50.7130 | 0.3125 | `min/min/min` |  |
| `ENH 26.5Panel1648WDO` | 26.5000 | 1.7500 | 79.5000 | `?/min/?` |  |
| `ENH 26.5Panel1648WDO_HX` | 26.5000 | 1.8125 | 89.5000 | `min/min/min` |  |
| `ENH 35.5Panel2630WDO` | 35.5000 | 1.8125 | 79.5000 | `?/?/?` |  |
| `ENH 35.5Panel2636WDO` | 35.5000 | 1.8125 | 79.5000 | `?/?/?` |  |
| `ENH 35.5Panel2642WDO` | 35.5000 | 1.8125 | 79.5000 | `?/?/?` |  |
| `ENH 35.5Panel2648WDO` | 35.5000 | 1.8125 | 79.5000 | `?/?/?` |  |
| `ENH 35.5VNT` | 35.7500 | 2.3750 | 79.4375 | `?/?/?` |  |
| `ENH 38.5Panel2636WDO` | 38.5000 | 1.8125 | 79.5000 | `min/min/min` |  |
| `ENH 41.5Panel3230WDO` | 41.5000 | 1.8125 | 79.5000 | `?/?/?` |  |
| `ENH 41.5Panel3236WDO` | 41.5000 | 1.8125 | 79.5000 | `?/?/?` |  |
| `ENH 41.5Panel3242WDO` | 41.5000 | 1.8125 | 79.5000 | `?/?/?` |  |
| `ENH 41.5Panel3248WDO` | 41.5000 | 1.8125 | 79.5000 | `?/?/?` |  |
| `ENH 4230CL` | 44.0000 | 32.0000 | 1.7500 | `min/min/min` |  |
| `ENH 4230FL` | 42.0000 | 30.0000 | 0.3125 | `min/min/min` |  |
| `ENH 4242CL` | 44.0000 | 44.0000 | 1.7500 | `?/?/min` | **SQUARE - noise** |
| `ENH 4242FL` | 42.0000 | 42.0000 | 0.3125 | `min/min/min` | **SQUARE - noise** |
| `ENH 4848CL` | 50.0000 | 50.0000 | 1.7500 | `min/min/min` | **SQUARE - noise** |
| `ENH 4848FL` | 48.0000 | 48.0000 | 0.3125 | `?/?/min` | **SQUARE - noise** |
| `ENH CornerSeamSeal` | 5.3750 | 5.3750 | 79.5000 | `?/?/?` | **SQUARE - noise** |
| `ENH MidWallSeamSeal` | 12.2500 | 2.5000 | 79.5000 | `?/?/?` |  |
| `ENH MidWallSeamSeal_HX` | 12.2500 | 2.5000 | 89.5000 | `?/?/?` |  |
| `Foam` | 48.0000 | 24.0000 | 2.0000 | `min/min/min` |  |
| `LeftSideVent_CP_HX` | 46.0000 | 8.5468 | 96.6128 | `min/min/min` |  |
| `LeftSideVent_EFS_CP_HX` | 51.9396 | 12.1250 | 96.0625 | `min/min/min` |  |
| `LeftSideVent_EFS_HX` | 51.9396 | 12.1250 | 92.3125 | `min/min/min` |  |
| `LeftSideVent_HX` | 46.0000 | 8.5468 | 91.8628 | `min/min/min` |  |
| `LeftSideVent_VSS_CP_HX` | 46.0000 | 8.6003 | 96.9200 | `min/min/min` |  |
| `LeftSideVent_VSS_EFS_CP_HX` | 58.6250 | 12.1250 | 97.0625 | `min/min/min` |  |
| `LeftSideVent_VSS_EFS_HX` | 58.6250 | 12.1250 | 92.3125 | `min/min/min` |  |
| `LeftSideVent_VSS_HX` | 46.0000 | 8.6003 | 92.1700 | `min/min/min` |  |
| `LeftWADoorWithRamp` | 61.8898 | 49.0000 | 82.0833 | `min/?/min` |  |
| `LeftWADoorWithRamp_HX` | 61.8898 | 49.0000 | 92.0833 | `min/min/min` |  |
| `MJP` | 8.7500 | 3.0306 | 18.3839 | `min/min/?` |  |
| `MidWallSeamSeal` | 7.7500 | 2.0000 | 81.0000 | `min/min/min` |  |
| `MidWallSeamSeal_HX` | 7.7500 | 2.0000 | 91.0000 | `min/min/min` |  |
| `RM102` | 92.0000 | 31.0695 | 10.3125 | `?/?/?` |  |
| `RM102_BACK` | 92.0000 | 31.0695 | 10.3125 | `?/?/?` |  |
| `RM120` | 110.0000 | 31.0695 | 10.3125 | `?/?/?` |  |
| `RM120_BACK` | 110.0000 | 31.0695 | 10.3125 | `?/?/?` |  |
| `RM126` | 116.0000 | 31.0695 | 10.3125 | `?/?/?` |  |
| `RM126_BACK` | 116.0000 | 31.0695 | 10.3125 | `?/?/?` |  |
| `RM144` | 134.0000 | 31.0695 | 10.3125 | `?/?/?` |  |
| `RM144_BACK` | 134.0000 | 31.0695 | 10.3125 | `?/?/?` |  |
| `RM168` | 158.0000 | 31.0695 | 10.3125 | `?/?/?` |  |
| `RM186` | 176.5450 | 31.0695 | 10.3125 | `?/?/?` |  |
| `RM192` | 182.0000 | 31.0695 | 10.3125 | `?/?/?` |  |
| `RM60` | 53.5000 | 25.0000 | 10.3125 | `?/?/?` |  |
| `RM60_BACK` | 53.5137 | 30.0000 | 10.3125 | `?/?/?` |  |
| `RM60_VSS` | 53.5000 | 30.0000 | 16.8125 | `?/?/?` |  |
| `RM60_VSS_BACK` | 53.5000 | 30.0000 | 16.8125 | `?/?/?` |  |
| `RM72` | 62.0000 | 30.0000 | 10.3125 | `?/?/?` |  |
| `RM72_BACK` | 62.0000 | 30.0000 | 10.3125 | `?/?/?` |  |
| `RM72_VSS` | 53.5000 | 30.0000 | 16.8125 | `?/?/?` |  |
| `RM72_VSS_BACK` | 53.5000 | 30.0000 | 16.8125 | `?/?/?` |  |
| `RM84` | 78.8555 | 31.0695 | 10.3125 | `?/?/?` |  |
| `RM84_BACK` | 78.8555 | 31.0695 | 10.3125 | `?/?/?` |  |
| `RM96` | 87.0000 | 31.0695 | 10.3125 | `?/?/?` |  |
| `RM96_BACK` | 87.0000 | 31.0695 | 10.3125 | `?/?/?` |  |
| `RMVSS_Stack_LeftSideView` | 53.5000 | 30.0000 | 16.8125 | `?/?/?` |  |
| `RMVSS_Stack_RightSideView` | 53.5000 | 30.0000 | 16.8125 | `?/?/?` |  |
| `RMVentilationExhaustBox` | 159.9333 | 30.0000 | 10.3125 | `?/?/?` |  |
| `RMVentilationIntakeBox` | 159.9333 | 30.0000 | 10.3125 | `?/?/?` |  |
| `RMVentilationLeftSideView` | 92.0000 | 31.0695 | 10.3125 | `?/?/?` |  |
| `RMVentilationRightSideView` | 92.0000 | 31.0695 | 10.3125 | `?/?/?` |  |
| `RMVentilationVSSLeftSideView` | 159.9333 | 30.0000 | 10.3125 | `?/?/?` |  |
| `RMVentilationVSSRightSideView` | 92.0000 | 31.0695 | 10.3125 | `?/?/?` |  |
| `RampSideView` | 61.8898 | 49.0000 | 82.0833 | `min/?/min` |  |
| `RampSideView_HX` | 61.8898 | 49.0000 | 92.0833 | `min/min/min` |  |
| `RightSideVent_EFS_CP_HX` | 51.9396 | 12.1250 | 96.0625 | `min/min/min` |  |
| `RightSideVent_EFS_HX` | 51.9396 | 12.1250 | 92.3125 | `min/min/min` |  |
| `RightSideVent_HX` | 46.0000 | 8.5468 | 91.8628 | `min/min/min` |  |
| `RightSideVent_VSS_CP_HX` | 46.0000 | 8.6003 | 96.9200 | `min/min/min` |  |
| `RightSideVent_VSS_EFS_CP_HX` | 58.6250 | 12.1250 | 97.0625 | `min/min/min` |  |
| `RightSideVent_VSS_EFS_HX` | 58.6250 | 12.1250 | 92.3125 | `min/min/min` |  |
| `RightSideVent_VSS_HX` | 46.0000 | 8.6003 | 92.1700 | `min/min/min` |  |
| `RightWADoorWithRamp#1` | 61.8898 | 49.0000 | 82.0833 | `min/?/min` |  |
| `RightWADoorWithRamp_HX` | 61.8898 | 49.0000 | 92.0833 | `min/min/min` |  |
| `STD127LPCL` | 51.9139 | 51.9139 | 3.3580 | `min/min/?` | **SQUARE - noise** |
| `STD127LPFL` | 61.8157 | 50.7130 | 3.3580 | `min/min/min` |  |
| `STD4230CL` | 42.0000 | 30.0000 | 3.1080 | `min/min/min` |  |
| `STD4242CL` | 42.0000 | 42.0000 | 3.1080 | `min/min/min` | **SQUARE - noise** |
| `STD4242FL` | 42.0000 | 42.0000 | 3.1080 | `min/min/min` | **SQUARE - noise** |
| `STD4260CL` | 60.0000 | 42.0000 | 3.1080 | `min/min/min` |  |
| `STD4260FL` | 60.0000 | 42.0000 | 3.1080 | `?/min/min` |  |
| `STD4284FL` | 84.0000 | 42.0000 | 3.1080 | `?/min/min` |  |
| `STD4872CL` | 72.0000 | 48.0000 | 3.1080 | `min/min/min` |  |
| `STD4872FL` | 72.0000 | 48.0000 | 3.1080 | `?/?/min` |  |
| `STD4896FL` | 96.0000 | 48.0000 | 3.1080 | `min/min/min` |  |
| `StepFront` | 44.0000 | 12.0000 | 5.0000 | `min/min/?` |  |

### B. The 42 real axis-flipping `_HX` pairs

| non-HX | runs | `_HX` | runs | direction |
|---|:--:|---|:--:|:--:|
| `40Panel2630WDO` | X | `40Panel2630WDO_HX` | Y | X -> Y |
| `40Panel2636WDO` | X | `40Panel2636WDO_HX` | Y | X -> Y |
| `40Panel2642WDO` | X | `40Panel2642WDO_HX` | Y | X -> Y |
| `40Panel2648WDO` | X | `40Panel2648WDO_HX` | Y | X -> Y |
| `40VNT` | X | `40VNT_HX` | Y | X -> Y |
| `40VNT_EFS` | X | `40VNT_EFS_HX` | Y | X -> Y |
| `40VNT_VSS` | X | `40VNT_VSS_HX` | Y | X -> Y |
| `40VNT_VSS_EFS` | X | `40VNT_VSS_EFS_HX` | Y | X -> Y |
| `40Vnt_CP` | X | `40Vnt_CP_HX` | Y | X -> Y |
| `40Vnt_EFS_CP` | X | `40Vnt_EFS_CP_HX` | Y | X -> Y |
| `40Vnt_VSS_CP` | X | `40Vnt_VSS_CP_HX` | Y | X -> Y |
| `40Vnt_VSS_EFS_CP` | X | `40Vnt_VSS_EFS_CP_HX` | Y | X -> Y |
| `46Panel3230WDO` | X | `46Panel3230WDO_HX` | Y | X -> Y |
| `46Panel3236WDO` | X | `46Panel3236WDO_HX` | Y | X -> Y |
| `46Panel3242WDO` | X | `46Panel3242WDO_HX` | Y | X -> Y |
| `46Panel3248WDO` | X | `46Panel3248WDO_HX` | Y | X -> Y |
| `7Panel` | Y | `7Panel_HX` | X | Y -> X |
| `ENH 35.5Panel2630WDO` | X | `ENH 35.5Panel2630WDO_HX` | Y | X -> Y |
| `ENH 35.5Panel2636WDO` | X | `ENH 35.5Panel2636WDO_HX` | Y | X -> Y |
| `ENH 35.5Panel2642WDO` | X | `ENH 35.5Panel2642WDO_HX` | Y | X -> Y |
| `ENH 35.5Panel2648WDO` | X | `ENH 35.5Panel2648WDO_HX` | Y | X -> Y |
| `ENH 35.5VNT` | X | `ENH 35.5VNT_HX` | Y | X -> Y |
| `ENH 38.5Panel2636WDO` | X | `ENH 38.5Panel2636WDO_HX` | Y | X -> Y |
| `ENH 41.5Panel3230WDO` | X | `ENH 41.5Panel3230WDO_HX` | Y | X -> Y |
| `ENH 41.5Panel3236WDO` | X | `ENH 41.5Panel3236WDO_HX` | Y | X -> Y |
| `ENH 41.5Panel3242WDO` | X | `ENH 41.5Panel3242WDO_HX` | Y | X -> Y |
| `ENH 41.5Panel3248WDO` | X | `ENH 41.5Panel3248WDO_HX` | Y | X -> Y |
| `LeftSideVent` | Y | `LeftSideVent_HX` | X | Y -> X |
| `LeftSideVent_CP` | Y | `LeftSideVent_CP_HX` | X | Y -> X |
| `LeftSideVent_EFS` | Y | `LeftSideVent_EFS_HX` | X | Y -> X |
| `LeftSideVent_EFS_CP` | Y | `LeftSideVent_EFS_CP_HX` | X | Y -> X |
| `LeftSideVent_VSS` | Y | `LeftSideVent_VSS_HX` | X | Y -> X |
| `LeftSideVent_VSS_CP` | Y | `LeftSideVent_VSS_CP_HX` | X | Y -> X |
| `LeftSideVent_VSS_EFS` | Y | `LeftSideVent_VSS_EFS_HX` | X | Y -> X |
| `LeftSideVent_VSS_EFS_CP` | Y | `LeftSideVent_VSS_EFS_CP_HX` | X | Y -> X |
| `RightSideVent` | Y | `RightSideVent_HX` | X | Y -> X |
| `RightSideVent_EFS` | Y | `RightSideVent_EFS_HX` | X | Y -> X |
| `RightSideVent_EFS_CP` | Y | `RightSideVent_EFS_CP_HX` | X | Y -> X |
| `RightSideVent_VSS` | Y | `RightSideVent_VSS_HX` | X | Y -> X |
| `RightSideVent_VSS_CP` | Y | `RightSideVent_VSS_CP_HX` | X | Y -> X |
| `RightSideVent_VSS_EFS` | Y | `RightSideVent_VSS_EFS_HX` | X | Y -> X |
| `RightSideVent_VSS_EFS_CP` | Y | `RightSideVent_VSS_EFS_CP_HX` | X | Y -> X |

### C. The 56 `_HX` pairs that do NOT flip

Both members run **X** (6 pairs): `CornerSeamSeal`, `ENH 26.5Panel1648WDO`, `ENH MidWallSeamSeal`, `LeftWADoorWithRamp`, `MidWallSeamSeal`, `RampSideView`

Both members run **Y** (50 pairs): `16PanelSolid`, `19Panel`, `22PanelSolid`, `28Panel`, `31Panel`, `31Panel1648WDO`, `40NV`, `40PanelCBL`, `40PanelSolid`, `43Panel`, `43Panel2636WDO`, `43Panel2648WDO`, `46NV`, `46PanelCBL`, `46PanelSolid`, `46VNT`, `46VNT_EFS`, `46VNT_VSS`, `46VNT_VSS_EFS`, `46VntCP`, `46Vnt_EFS_CP`, `46Vnt_VSS_EFS_CP`, `46vnt_VSS_CP`, `ENH 11.5PanelSolid`, `ENH 14.5Panel`, `ENH 17.5PanelSolid`, `ENH 23.5Panel`, `ENH 26.5Panel`, `ENH 35.5NV`, `ENH 35.5PanelCBL`, `ENH 35.5PanelSolid`, `ENH 38.5Panel`, `ENH 38.5Panel2648WDO`, `ENH 41.5NV`, `ENH 41.5PanelCBL`, `ENH 41.5PanelSolid`, `ENH 41.5VNT`, `ENH Left35.5Door`, `ENH Left41.5Door`, `ENH LeftWADoor`, `ENH Right35.5Door`, `ENH Right41.5Door`, `ENH RightWADoor`, `Left40Door`, `Left46Door`, `LeftWADoor`, `Right40Door`, `Right46Door`, `RightSideVent_CP`, `RightWADoor`
