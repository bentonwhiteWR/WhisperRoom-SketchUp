# Handoff — Scoper, layered interior light rig

2026-08-30, **revision 2** (Benton's five answers folded in). **No code written, no render run,
no V-Ray setting touched, `scripts/` untouched, `VERSION` untouched at 1.9.7.** Provenance tagged
**observed / derived / reported / assumed** throughout the deliverable.

## Produced

| File | What |
|---|---|
| `.forge/scoper/layered-light-rig.md` | **The spec, revision 2.** Goal, what to keep, the exposure derivation, the calibration, the seven-role layer table, four procedural fixture types with sourced dimensions, the on-demand ceiling and its verified removal, six ordered steps, fifteen acceptance criteria, risks, out-of-scope |
| `.forge/scoper/HANDOFF.md` | this |
| `.forge/scoper/HANDOFF-sketchup-bridge.md` | the prior bridge handoff, preserved rather than overwritten |

## Read first

1. **§6, the layer table.** Still the centrepiece. Seven roles, 9 instances, and now **five of
   the nine are visible fixtures** where revision 1 had one.
2. **§4, the exposure.** `f/8, 1/300, ISO 3200` → **EV 9.23**. ISO only; f-number and shutter do
   not move. Three independent lines converge on EV 8.8-9.5.
3. **§7.4, what the fixture dimensions are drawn from** — and the one figure that does not exist.
4. **§8, the ceiling removal.** The riskiest thing in the spec, and the reason criterion 9 does
   not trust the tool's own capture.

## What Benton's answers changed

**Exposure.** "Just the default, never touched it" turned my filed recommendation live. The spec
now writes **one** interior exposure as a documented default and moves the rig to **lumens
(`units = 1`)**. The distinction he cared about is held explicitly in §4: setting a considered
exposure once is not the same as a tool fiddling with exposure per scene — the second stays
cancelled, and there are five guards on the write (ISO only, once, only from factory ISO 100,
logged with its undo, read back).

The number is derived rather than rounded: 40 fc design target → 430.6 lux → `L = ρE/π` → the
meter equation `EV = log2(L × 8)` gives **EV 8.58-9.10** across the reflectances a WhisperRoom
interior actually holds. `f/8, 1/300, ISO 3200` = **EV 9.23** — exactly five stops from the
factory ISO, 0.13 stops off the photometric target, and 0.27 stops from **EV 9.5**, the one arm
in the 148-frame sweep where the fixtures alone served both cameras (**observed**). Erring
slightly dark is deliberate: clipped highlights are unrecoverable, shadows are not.

**The payoff landed.** The lumen column now comes straight from the design doc's own
`area × fc ÷ CU` with no fudge factor, `AREA_NORMALIZED` and three other constants delete
themselves, and every number is checkable against a product page: 2,000 lm 18" flush mount,
1,200 lm drum pendant, 600 lm sconce, 800 lm booth light.

**Fixtures.** Four procedural types — F1 flush ceiling drum, F2 cord-hung pendant, F3 cylinder
up/down sconce, F4 floor lamp — drawn in Ruby from primitives, building on `pendant-jig.rb`'s
existing idiom. Ranked: **F1 alone is a complete, shippable improvement**; F4 is genuinely
optional. The binding rule is that fixture geometry never goes inside the V-Ray light definition
(deleting one schedules a deferred purge that killed the rig once), so the fixture is its own
group and both carry the dictionary the existing sweep already walks — no new sweep logic.

**Ceiling.** On demand, tool-owned, ownership by dictionary and UUID rather than by name.

**Aiming.** Booth-relative, as recommended.

## One thing Benton did not ask for, and I changed anyway

**Revision 1 gave the visible practical 4% of the budget — 500 lm. A real 18" flush-mount ceiling
fixture emits 2,000 lm.** A visible fixture emitting a tenth of its real-world twin is *itself* a
CG tell: the eye reads the fixture, then reads the light, and they disagree. Revision 1 had a
phantom 48" panel doing the ambient work while a dim prop hung nearby — which is the same mistake
as the current rig, wearing better clothes.

So the ambient layer and the practical are now **the same object**: two visible 18" ceiling drums
at 2,000 lm, which is what the real fixture emits. New rule, stated in §0: **where a share
disagrees with a real product, the real product wins for anything visible, and the invisible
layers absorb the difference.** This is the change I would most want Benton to look at.

## Assumptions

| # | Assumption | Provenance | What to change if wrong |
|---|---|---|---|
| 1 | `units = 1` is Luminous Power (Lumens) | **observed** in the Asset Editor's Electron bundle, **never rendered** | Step 1(a) is a gate. Fallback is revision 1's scalar column, in git history |
| 2 | Lumens are flux *before* the colour tint, so no `Y` division | **assumed** | Step 1(b). If wrong, revision 1's `Y` division returns |
| 3 | ρ ≈ 0.40-0.50 for a WhisperRoom interior | **assumed** from material knowledge, not measured | Moves the EV recommendation by up to 0.5 stops. The ladder settles it |
| 4 | Shade absorption | **unmeasured, and no published figure exists** (§7.4) | Step 3 renders it. **The largest unknown in the lumen column** |
| 5 | Fixture dimensions and real-world lumens | **reported** — product data and design guides; items marked *(generalised)* are syntheses, not citations | Each is a single constant |
| 6 | The budget is linear in floor area and ignores ceiling height | **assumed** | Step 5 sweeps enclosure but **not size** |
| 7 | Enclosure trims ×0.35 / ×0.25 | **derived** from the observed 1.5-stop capping cost | Two constants; Step 5 measures them |
| 8 | The seven shares | **assumed** — designer's judgement, now constrained by real fixture outputs | Benton's call after the contact sheet |
| 9 | UI dictionary keys are plugin parameter names | **assumed** for `is_disc`; **observed** only for `invisible`, `units`, `intensity`, `color`, `directional`, `u_size`, `v_size` | Write, read back, refuse by name. Only F1 depends on it |

## What I could not check

* **No render was run** — speccing, not testing, by instruction. Every claim about how the new rig
  will look derives from the 148 existing sun-off frames, not from a frame of this rig.
* **Nothing at a room size other than the 192 sq ft reference room.**
* The 60° rim tilt — only 35° has ever been placed, and never rendered. `FACE_FLIP` is still an
  untested assumption inherited from 1.9.1.
* What a *visible* emitter actually looks like at a chosen lumen value. Nobody has seen one
  deliberately.
* Whether the pendant at 78" AFF clears everything Benton draws — that height is *generalised*,
  not sourced.

## Open questions

Benton settled all five forks; these are consequences worth putting to him, not re-openings.

1. **The ceiling's lifetime.** "Adds a ceiling when it drops lights and removes it afterwards" —
   a ceiling removed at the *end of the press* does not exist when the render runs, which defeats
   its purpose and leaves five fixtures floating. I specced **lifetime = the rig's lifetime**:
   created with the rig, removed by the same sweep that removes the rig, so the drawing is never
   left altered. If he meant end-of-press literally, it is a one-line change — and roles 1 and 3
   lose their mounting surface. **Worth confirming before Step 4.**
2. **F2 and F4's shades will render opaque** where a real fabric shade glows. Fixing it needs a
   translucent material, and this tool must not create materials (creating one and writing to it
   **hangs SketchUp** — observed, four force-kills). Named as a limitation, not hidden. F1 and F3
   are unaffected.
3. **Is EV 9.23 the right *look*, or just the right *meter reading*?** The photometry says
   correctly exposed. Whether Benton wants his renders a half stop brighter or moodier is taste,
   and the Brightness dropdown covers ±1 stop without touching the camera again.
4. **F4, the floor lamp, is optional and I did not decide it.** It is the most "bedroom" object
   of the four and the only one at human scale on the floor — and the only one that can collide
   with the booth. Build it last; drop it without loss if the room is tight.
