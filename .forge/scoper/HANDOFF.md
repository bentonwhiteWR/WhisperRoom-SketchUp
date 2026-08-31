# Handoff — Scoper, layered interior light rig

2026-08-30. **No code written, no render run, no V-Ray setting touched, `scripts/` untouched,
`VERSION` untouched.** Provenance tagged **observed / derived / reported / assumed** throughout
the deliverable.

## Produced

| File | What |
|---|---|
| `.forge/scoper/layered-light-rig.md` | **The spec.** Goal, what to keep, the calibration, the seven-role layer table, both investigations answered, five ordered steps, twelve acceptance criteria, risks, out-of-scope |
| `.forge/scoper/HANDOFF.md` | this |

## Read first

1. **`.forge/scoper/layered-light-rig.md` §5, the layer table.** That is the thing Benton
   reacts to. Seven roles, 9 instances with a booth, real intensities, seven colour
   temperatures, two grazing sources, one visible fixture.
2. **§4, the calibration.** The whole intensity column rests on one identity —
   *multiplying every light by `2^Δ` is exactly identical to lowering EV by `Δ`* — applied to
   the sun-off EV ladder. It says the rig as built is **×26.5 (4.73 stops) too dim** for
   Benton's camera in a capped room with the sun off. Two independent routes agree on that
   figure to within 0.4 stops.
3. **§6, units.** The enum was found and is now **observed**, in a place nobody had looked:
   the Asset Editor's Electron bundle, `…\extension\vrayneui\resources\app.asar` →
   `asset-editor.bundle.js`. `0 = Default (Scalar)`, `1 = Luminous Power (Lumens)`,
   `2 = Luminance`, `3 = Radiant power (W)`, `4 = Radiance`. The YARD docs genuinely carry no
   light parameters at all — that part of the 1.8.0 header was right.
4. **§8 Step 2(b)** — the `WR Lights` tag was `false` on the live model as found, and scenes
   re-apply their own stored copy. No rig design survives that. It is a gate for a reason.

## Assumptions

| # | Assumption | Provenance | What to change if wrong |
|---|---|---|---|
| 1 | Scalar `intensity` is surface brightness, so output ∝ `area × intensity` | **assumed** — `AREA_NORMALIZED = 1.0` encodes it, no render has ever tested it, and the Asset Editor has no "multiply by size" control to check against (**observed**) | Every intensity in §5 recomputes as `share × E / n`. **Step 1 is the gate that decides it** |
| 2 | The per-sq-ft budget (35,700) scales linearly with floor area and ignores ceiling height | **assumed** | Add a height term; Step 4 does not test a size axis and the spec says so |
| 3 | The enclosure trims ×0.35 / ×0.25 | **derived** from the observed 1.5-stop capping cost and the `w3-open` / `w4-open` ratio | Two constants; Step 4 measures them |
| 4 | The seven shares (0.42 / 0.22 / 0.04 / 0.20 / 0.12, and 0.68 / 0.32) | **assumed** — designer's judgement, the one column that is taste | Benton's call; they are seven numbers in one table |
| 5 | UI dictionary keys are the plugin parameter names | **assumed** for `is_disc` and everything else new; **observed** only for `invisible`, `units`, `intensity`, `color`, `directional`, `u_size`, `v_size` | Write, read back, refuse by name. The rig places without `is_disc` |
| 6 | `image-qa` mean luminance is a usable proxy for "well lit" | **assumed, and partly wrong** — in an open-roof room the mean tracks how much sky is in frame. Judge open arms by eye |

## What I could not check

* **No render was run** — speccing, not testing, by instruction. Every claim about how the new
  rig will look is derived from the 148 existing sun-off frames, not from a frame of this rig.
* **The rig has never been rendered at a size other than the 192 sq ft test room.**
* Whether the tilt direction convention holds for a 60° rim (only 35° has been placed, and
  never rendered — `FACE_FLIP` is still an untested assumption from the 1.9.1 handoff).
* What a *visible* emitter actually looks like at a chosen intensity. Nobody has seen one
  deliberately.

## Open questions — genuine forks, for Benton

1. **Does the host room get a ceiling?** This is the biggest one and it decides three things
   at once. With a ceiling: the fixtures alone light the frame, the rig is deterministic, the
   sky stops competing, and **a visible ceiling fixture has something to be mounted in**.
   Without one: the sky is an uncontrolled second source that changes with wall count
   (a 3-sided room is *brighter*, **observed**), and any visible fixture floats in mid-air.
   `build-room.rb` draws no ceiling today. The spec handles both by auto-detecting and
   trimming, and skips the visible practical when there is no ceiling — but a capped room is
   the better picture, and it is Benton's call whether `build-room.rb` should start drawing one.

2. **"5-7 light sources" — roles or instances?** I read it as **roles**, which is what a
   lighting designer counts: 7 roles, 9 instances with a booth, 6 without. If Benton means 7
   *instances*, the ambient pair drops to one 60"×60" and the graze pair to one, giving 7 —
   at the cost of a harder ambient shadow and a less even wall.

3. **Camera-relative or booth-relative aiming?** A designer lights to the camera. I specced
   **booth-relative** (key on the door face, rim opposite) because the proposal pack renders
   five scenes including a rear/ventilation view, and a camera-relative rig would look
   designed from one and odd from the others. Camera-relative would look better in the hero
   frame specifically. This is a real trade and I have not taken it away from him.

4. **The unit, and the exposure that comes with it.** §6 recommends staying on the scalar, and
   the reason is worth putting to him in one sentence: **at EV 14.23 a physically-truthful
   interior renders about five stops dark, so a lumen number this tool wrote would be ~26× a
   real fixture's — a false claim with units on it, where a scalar makes no claim at all.**
   The moment an interior exposure (EV ≈ 9.5) is acceptable, lumens becomes strictly better,
   `AREA_NORMALIZED` deletes itself, and the layer table turns into real fixtures — a 2,700 lm
   panel, a 500 lm bedside lamp. Exposure is settled and I have not reopened it; this is the
   note for whenever it is revisited.

5. **The missing asset, named rather than assumed away.** There is **no lamp, pendant, sconce
   or luminaire component anywhere in the WhisperRoom library** (**observed**). A visible
   emitter alone is enough to ship — a 20" warm disc in the ceiling reads as a flush-mount
   fixture — but a *bedroom* reads as a bedroom because of a shaded lamp on a nightstand, and
   that needs a `.skp` Benton would have to draw. One authored lamp plus a sphere light inside
   its shade is a small follow-up once the geometry exists.
