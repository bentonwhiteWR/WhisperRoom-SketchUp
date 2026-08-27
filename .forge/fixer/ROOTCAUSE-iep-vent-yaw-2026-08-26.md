# ROOT CAUSE — the IEP vent walls, and why the constant could never be right

**2026-08-26, shipped in v1.6.32.** Benton, on an **HX** Enhanced booth:
*"looked at the HX, the IEP vent walls are all flipped wrong. Need to flip the 180."*

## The symptom, and the wider symptom he did not report

The inner-shell vent panels are placed end for end. He saw it on an HX booth.
**It is also true of the ten non-HX `E` layouts whose inner vent is 41.5 wide, and it has been
true of them since 10:04 this morning.** He has not rebuilt one since, so nobody has looked.
That includes `MDL 4872 E`, the booth signed off complete on 2026-08-25.

## The root cause, in one sentence

`rotation()` (`scripts/build-booth-components.rb:1392`) pins height→up and thickness→the wall
normal and then **derives** the along-wall width direction from the *parity of the definition's
own axis permutation*, so two parts whose parity differs land end for end from each other on the
same wall — and `IEP_VENT_YAW = 180` was a blanket half turn calibrated against `ENH 35.5VNT`,
the **only** one of the eight `ENH` vent parts whose width runs X.

The mechanism is one line, `build-booth-components.rb:1400`:

```ruby
s = EVEN.include?([hi, ti, wi]) ? 1 : -1
...
ax[wi] = s > 0 ? VZ.cross(nrm_vec) : nrm_vec.cross(VZ)
```

`VZ.cross(n)` and `n.cross(VZ)` are exact negatives. For every wall panel `hi == 2` (the height
axis is Z), so `[hi, ti, wi]` is either `[2,0,1]` — width on Y, in `EVEN`, `s = +1` — or
`[2,1,0]` — width on X, not in `EVEN`, `s = -1`. **Width runs X ⇔ the part comes out end for end
from a width-runs-Y part on the same wall.** derived, from the code.

## The measured axes — observed, `P:\Sketchup\NewMasterComponentList\_component-probe.tsv`

| part | x | y | runs | parity | turn it needs |
|---|---:|---:|:--:|:--:|---:|
| `ENH 35.5VNT` | **35.7500** | 2.3750 | **X** | −1 | **180** |
| `ENH 35.5VNT_HX` | 2.3750 | **35.7500** | Y | +1 | 0 |
| `ENH 35.5NV` | 2.3750 | **35.7500** | Y | +1 | 0 |
| `ENH 35.5NV_HX` | 2.3750 | **35.7500** | Y | +1 | 0 |
| `ENH 41.5VNT` | 2.3750 | **41.7337** | Y | +1 | 0 |
| `ENH 41.5VNT_HX` | 2.3750 | **41.7337** | Y | +1 | 0 |
| `ENH 41.5NV` | 2.3750 | **41.7337** | Y | +1 | 0 |
| `ENH 41.5NV_HX` | 2.3750 | **41.7337** | Y | +1 | 0 |

One part out of eight. The constant was fitted to it.

## Five in-SketchUp reports, and the rule fits all five at face value

This is the part that matters, because the previous version of this code explained away one of
them. `.forge/fixer/verify-vent-yaw.py` checks it mechanically.

| # | booth | its inner vent | yaw live | Benton | rule says | fits |
|---|---|---|---:|---|---:|:--:|
| R1 | `MDL 6060 E` | `ENH 35.5VNT` (X) | 0 | wrong | 180 | yes |
| R2 | `MDL 96144 E` | `ENH 41.5VNT` (**Y**) | 180 | wrong | 0 | **yes** |
| R3 | `MDL 102144 E` | `ENH 35.5VNT` (X) | 0 | wrong | 180 | yes |
| R4 | `MDL 4872 E` | `ENH 41.5VNT` (**Y**) | 0 | **right** (signed off 08-25) | 0 | yes |
| R5 | the HX, today | `ENH ...VNT_HX` (**Y**) | 180 | wrong | 0 | yes |

**R2 was not stale state.** v1.6.25's comment reconciled R1 and R2 by arguing that Benton's
SketchUp had not been restarted, so the 180 was not really live and he was looking at old code.
That was an *inference invented to remove a contradiction*, and it was wrong. R1 and R2 are
reports about **different components** — the 6060 E's vent is `ENH 35.5VNT`, the 96144 E's is
`ENH 41.5VNT` — and the two parts genuinely want opposite turns. Two true reports were read as
one contradictory report about one constant.

The general lesson at that comment (*a Ruby module keeps its constants until SketchUp restarts;
"the file on disk says X" is not evidence about the running build*) is still true and is kept in
the source. The failure was using it to **discard** a report rather than to qualify one.

R4 is the weakest of the five: the 4872 E was signed off as a whole booth, and there is no note
saying its vent's end-for-end orientation was specifically stared at. **reported.** R2 and R5 are
the ones carrying "Y wants 0", and they are independent of each other.

## The fix

`IEP_VENT_YAW` is deleted. `iep_vent_yaw(cls)` derives the turn from the same measured `cls` the
rotation itself used:

```ruby
def self.iep_vent_yaw(cls)
  return 0.0 if cls.nil?
  EVEN.include?([cls[:hi], cls[:ti], cls[:wi]]) ? 0.0 : 180.0
end
```

The build now prints, per inner vent, the width axis it measured and the turn it chose. Nothing
is inferred from a name.

## Blast radius — 35 of 50 (layout, part) pairs change; **nothing confirmed good moves**

| set | count | before | after |
|---|---:|---:|---:|
| non-HX, 35.5 vent (15 layouts, incl. 84126 E, 102144 E, 6060 E) | 15 | 180 | **180 — unchanged** |
| non-HX, 41.5 vent (4848, 4872, 4896, 7272, 7296, 96120, 96144, 96168, 96192, 9696) | 10 | 180 | **0** |
| every HX layout, both widths | 25 | 180 | **0** |

Every booth Benton has ever confirmed the vents good on is in the unchanged row. The change is
confined to the two sets nobody has signed off — which is exactly the shape you want.

## What this rule is NOT, and do not generalise it

**The turn is a per-family authoring convention.** Parity says which of the two rigid orientations
`rotation()` produces; which one is *correct* is a property of how the part was drawn, and the
families disagree:

- **vents** — X-runner wants 180, Y-runners want 0. (this document)
- **mid-wall seal** — `ENH MidWallSeamSeal` runs **X**, `IEP_SEAL_YAW = 180`, confirmed in builds.
  Same convention as the vents. A free fourth agreement from a different family.
- **inner doors** — `ENH Right35.5Door`, `Right41.5Door`, `RightWADoor` and every `_HX`
  sibling **all run Y**, and `IEP_DOOR_YAW = 180` is confirmed correct. That is the **opposite**
  convention. A blanket parity rule applied to every inner part would break the door.

So `iep_vent_yaw` is scoped to vents on purpose. A part authored end for end **in its own frame**
would defeat it, exactly as four of the 23 `ENH` ceiling parts are authored upside down
(v1.6.30). Of the eight vent parts only `ENH 35.5VNT` and `ENH 35.5VNT_HX` have been seen in a
built model; the 41.5s rest on R2 and R4.

## Predicted, not fixed — the inner window panels

`ENH 35.5Panel2636WDO` and every `ENH ...WDO` inner window panel runs **X** (observed, TSV) and
gets **no** turn at all today. Under the vent/seal convention they want 180, i.e. they are
predicted to be end for end. This is hypothesis A of
`.forge/fixer/PROBE-COMPONENT-FILES-2026-08-26.md`, reached by a different route.

**Deliberately not changed.** The door family proves conventions differ per family, there is no
in-SketchUp observation of an inner WDO panel, and inner WDO panels are never auto-assigned —
`guess_component` has no WDO branch, so they only appear via an explicit assignment such as
`'W1i' => 'ENH 41.5Panel3236WDO'` (`build-booth-components.rb:1200`). Test named in the HANDOFF.

## Deeper defect, reported and not fixed

`rotation()` deriving the along-wall direction from authoring parity is a **general** defect, not
a vent one. It is the same mechanism behind the outer window panel sitting in a different
width-axis family from its neighbours. Fixing it properly means resolving the width axis for
every part, which touches the Standard outer shell and is open question 5 in the HANDOFF —
still not green-lit.

## Verification

`python .forge/fixer/verify-vent-yaw.py` — its independent witnesses are named in its header:
the measured `_component-probe.tsv` and the generated `scripts/wr-booth-data.rb`. Neither is
derived from `build-booth-components.rb`. It re-implements `classify()`'s axis pick and the
parity from the measurements, prints the turn for all 25 layouts × {non-HX, HX}, and asserts the
five reports above. **All five fit; exit 0.**

`python scripts/rbparse.py` — 52 files parse on the CRuby 3.2 parser SketchUp ships, including
`build-booth-components.rb`. **A parse is not a run.** There is no Ruby interpreter on this
machine; nothing here was executed in SketchUp.

## Needs a restart

`iep_vent_yaw` lives in `scripts/`, not `wr_tools/`, so on a machine with a repo checkout in
`CANDIDATES` a `git pull` alone would reach it — **but `wr_tools/VERSION` moved to 1.6.32**, so
do the full three steps anyway: `git pull` → `install-plugin.py` → **restart SketchUp**. The old
`IEP_VENT_YAW` constant is in the running module until then.
