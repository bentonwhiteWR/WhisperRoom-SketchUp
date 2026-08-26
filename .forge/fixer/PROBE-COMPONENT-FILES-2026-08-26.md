# Probe Component Files — 370 parts, 2026-08-26

Benton ran **Probe Component Files** and pasted the whole table. **This is the authoring-family
data that has never existed before**, and it settles the side-wall mirror.

> Note: the `P:` share was unreachable from the shell right after this run, so `_component-probe.tsv`
> could not be re-read. The figures below are transcribed from Benton's paste. If `P:` comes
> back, re-read the TSV before relying on any number not listed here.

## THE FINDING — the width axis splits by family, and the split is real

`RUNS` is the axis the part's WIDTH lies on. Transcribed from the paste:

| part | X | Y | RUNS |
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
its neighbours. The vents are in that same X family — and `IEP_VENT_YAW = 180` patches the
vents while the WDO panels get nothing.

**That is hypothesis A, now carried by measurement rather than inference.** It also explains
"on both": the 96144 E has a window too.

### Correction to an earlier reading

The build console's `FACING` column showed `W0`, `W1`, `W2` all as `X+ IN`, and that was taken
as evidence against hypothesis A. It was not. **`FACING` reports the thickness sense; `RUNS`
reports the width axis.** They are different properties and only the second one was ever in
question. Do not reuse the earlier conclusion.

## A SECOND, SYSTEMATIC AUTHORING SPLIT — non-HX runs X, HX runs Y

Every X-running part above has an `_HX` sibling that runs **Y**:

    40Panel2636WDO       X      40Panel2636WDO_HX       Y
    40VNT                X      40VNT_HX                Y
    ENH 35.5VNT          X      ENH 35.5VNT_HX          Y
    ENH 35.5Panel2636WDO X      ENH 35.5Panel2636WDO_HX Y

Consistent across the whole set, so it is a convention, not a mistake in one file — but it means
**a rule keyed on the part name must not assume the HX sibling shares the non-HX axis.** HX
Enhanced is untested (`.forge/GOAL.md`), so this is a live trap rather than a hypothetical.

## Blast radius — the outer shell is affected too

`40Panel2636WDO` is the **outer** (Standard) window panel and it runs X exactly as the inner
`ENH 35.5Panel2636WDO` does. So this is not confined to the Enhanced path.

Benton, asked whether a Standard 96144/102144 builds its side walls correctly today:
*"No neither 96144 or 102144 have the correct side wall positions from the link."* Read that as
covering both builds. **It still means editing shared Standard code, so confirm the reading with
Benton before shipping a change that moves Standard geometry.**

## Other facts worth keeping from the same run

- **The origin anchor is a MIX**, and the probe says so itself: 140 `min/min/min`, 107 `?/?/?`,
  40 `?/?/min`, 30 `min/?/min`, 20 `min/min/?`, 12 `?/min/min`, 12 `min/?/?`, 4 `min/mid/min`,
  4 `?/min/?`, 1 `max/min/min`. Its own note: *"A SINGLE anchor across the set means one
  placement rule works for everything. A mix means placement has to go by bounding box."*
- **20 parts do not measure the number in their name**, all vent option variants — `40VNT_EFS`
  is 48.9369 against a name saying 40, `40VNT_VSS_EFS` is 56.1824. Consistent with the
  packaged-box lesson from v1.6.21: the name is the module width, the box is the module plus
  hardware.
- `STD7224FL SIDE R` is the only `max/min/min` anchor in the set and measures 37.9375 on a
  24 name — the part the DEVLOG already records as a seating trap.
- `ENH 8418 FL` measures 17.9375, 1/16 under nominal, as does `STD8418 FL`. Already known.

## Still NOT answered by this probe

This gives bounding boxes and anchors, **not face levels**. The IEP tray orientation still
abstains for want of `_face-levels.tsv` rows for `ENH` parts. That needs
`scripts/probe-levels.rb` run over the folder with an **empty** filter — a different tool from
the one Benton just ran.
