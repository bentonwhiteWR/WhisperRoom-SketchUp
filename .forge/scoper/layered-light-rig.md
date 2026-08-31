# Spec — `wr-drop-lights.rb` as a layered interior lighting rig

Scoper, 2026-08-30. Provenance tagged **observed / derived / reported / assumed** throughout.
**No code written, no render run.** Every number traces to `.forge/builder/sunoff-results.json`
(148 frames, sun off on all of them, **observed**), the live rig read through the bridge
(**observed**), the V-Ray install's own resources (**observed**), or arithmetic on those
(**derived**). Where a number is designer's judgement it says so.

---

## 1. Goal

Replace the current one-tier grid of identical invisible glowing panels with a **seven-role
layered rig** — the way a lighting designer lights a bedroom — that

* looks right at **Benton's own camera, f/8 @ 1/300, ISO 100 = EV 14.23**, with the tool
  **never writing `/CameraPhysical`** and never writing any other V-Ray setting;
* **carries the shot with the sun off** — sun becomes dressing, not the source;
* shows **at least one visible fixture** that reads as the source of light;
* varies **colour temperature (2700 K → 5000 K)**, **size (4"×36" → 48"×48")** and
  **direction** across the layers;
* puts **one raking source across the acoustic foam** so its 1,447-face pyramid relief reads
  instead of disappearing;
* stays **one button with sensible defaults** — two dropdowns, no lighting-designer UI.

## 2. What is wrong today, in one paragraph

Eight lights, **one colour on all of them** — `Color(1, 0.694903, 0.431048)`, which is exactly
`kelvin_rgb(3000)` (**derived**, so the tool did write 3000 K and wrote it everywhere) —
**`invisible = 1` on all of them**, all flat rectangles pointing straight down, `units = 0`.
Four 12"×12" @ 426.64, two 6"×24" @ 120, one 12"×24" @ 106.8, one 12"×12" @ 480
(**observed**). One layer doing every job: no visible source, no temperature spread, nothing
raking anything, one shadow direction. That is a **design** fault, not a tuning fault, which is
why no amount of moving `REF_INTENSITY` has fixed it and why this spec changes the shape of the
rig rather than its numbers alone.

## 3. What is worth keeping — do not rewrite these

| Keep | Why |
|---|---|
| The whole **pure placement section** — `grid_spacing`, `axis_points`, `grid_count` and its 1/16" snap, `point_in_poly?`, `seg_dist`, `edge_dist`, `poly_area`, `poly_centroid`, `in_keepout?`, `edge_threshold`, `grid_points`, `nearest_edge`, `opposite_edge`, `wash_points`, `accent_axis` | 38 + 10 checks pass in `scripts/rbtest-lights.py` in real CRuby outside SketchUp. The L-shape handling, keep-outs, edge band and centroid fallback are sound. **observed** |
| `write_params` / `read_param` and the `VRay::Scene#change` transaction | The 1.9.1 fix. A bare `plugin[k] = v` outside a transaction is silently discarded. **observed** |
| `erase_lights` / `reap_lights`, place-first-reap-last | The 1.9.1 second-press kill fix. **observed** |
| `create_light`, `param_agrees?`, the refuse-by-name style, the per-layer console report | The no-silent-fallback discipline this repo runs on |
| `kelvin_rgb` | Correct, exact at 6600 K — and now called **per layer** instead of once |
| `booth_door_center`, `accent_axis`, and the tilt composition at `:2023` (`translation * rotation`, so the light spins about its own origin) | The only aiming machinery in the file. The rim and the two graze layers reuse it verbatim |
| The subject vetoes — `subject_veto`, `light_words?`, `vray_light?`, `booth_like?` | The light-as-room incident is not worth repeating |

## 4. The calibration this rig is built on — read this before arguing with a number

One **rigorous** identity is available, and it is what makes the intensity column a fact
rather than a guess:

> Physical-camera exposure is linear in `2^-EV` and is applied **before** tone mapping.
> Therefore *multiplying every light by `2^Δ` is exactly identical to lowering EV by `Δ`.*
> **derived**, from the definition of EV. No gamma assumption anywhere.

`sunoff-results.json` stage C is an EV ladder over the as-found rig with the sun off. Read
through that identity:

| room | works at EV | the frames | ⇒ multiplier to get that same picture at EV 14.23 |
|---|---|---|---|
| **`w4-ceil`** (4 walls, capped) | **9.5** | ext 0.3908 PASS, int 0.3119 PASS | **×26.5** |
| `w4-open` (4 walls, open roof) | 11.0 | ext 0.6227 PASS, int 0.1537 PASS | ×9.4 — but the sky supplies part of that frame and cannot be multiplied |
| `w4-open` + `booth16x` | 14.0 | ext 0.1878 PASS, int 0.1992 PASS | ×1 — the only as-found-adjacent arm that already works at Benton's camera |

**Headline: in a capped four-walled room with the sun off, the rig as built is ×26.5 — 4.73
stops — too dim for Benton's camera.** That is why every earlier attempt reached for exposure.
The `w4-ceil` row is the one to design to, because it is the only row where the *fixtures
alone* light the frame. That is the brief.

**Cross-check from an independent frame.** `booth16x` puts the booth light at
`106.8 × 16 = 1708.8` and reads int 0.1992 PASS at EV 14.0. The ×26.5 rule puts the same light
at `106.8 × 26.5 = 2830`, 1.66× brighter — and the ×26.5 frame it comes from reads int 0.3119,
1.57× the mean. **The two anchors agree to 6%.** (**derived**; the agreement of the ratios is
the check.)

### The energy budget

Working assumption: scalar (`units = 0`) intensity is a **surface-brightness** number, so a
light's contribution ∝ `area × intensity × Y(colour)`, with
`Y = 0.2126r + 0.7152g + 0.0722b`. That is what `AREA_NORMALIZED = 1.0` already encodes, and
**Step 1 exists solely to prove or kill it.**

```
E_room  = (4·144·426.64 + 2·144·120 + 144·480) · Y(3000K) · 26.5 = 6.86e6
E_booth = (288·106.8)                          · Y(3000K) · 26.5 = 6.04e5
```

in `in² · scalar · luminance`. `Y(3000K) = 0.741`, **derived** from `kelvin_rgb`. `E_room`
over the reference room's 192 sq ft is **35,700 per sq ft** — the figure that scales the rig
to other rooms.

**Colour costs light, and today nobody pays for it.** At the same intensity a 3000 K light
emits `Y = 0.741` of a white one; 2700 K is 0.705, 4000 K is 0.837, 5000 K is 0.910. So each
layer's intensity must be **divided by that layer's `Y`**, or the warm layers land a third of
a stop dim. Today they do — but because *every* light was 3000 K the error was uniform and
therefore invisible. With seven temperatures it stops being uniform. **derived**, and it is a
one-line fix with a visible effect.

---

## 5. THE LAYER TABLE

Seven roles. **9 instances in a room with a booth, 6 without.** Benton's "5-7 light sources"
is read as *roles* — which is what a designer counts; the ambient pair and the graze pair are
one role each. Heights are relative to the **wall-top plane** (`z_m` in the existing code)
unless stated. Intensities are for a **capped room, sun off, EV 14.23, Brightness = Normal**,
in the 192 sq ft reference room; they scale `× room_sqft / 192`.

| # | Role | n | Size (u × v) | Intensity | Colour | Height / position | Direction | Visible | Why it exists |
|---|---|---|---|---|---|---|---|---|---|
| 1 | **Ambient soft fill** | 2 | 48" × 48" | **750** | **4000 K** neutral | flush at wall top | straight down | no | The general layer. **Big and few, not small and many** — a 48" source throws a soft shadow edge; four 12" panels throw four hard ones, and that is the CG tell. Deliberately the *coolest* room layer so the warm practicals read as warm against it. |
| 2 | **Key / booth face** | 1 | 24" × 24" | **3300** | **3500 K** | wall top, 42" out from the booth door face (`ACCENT_OUT`, existing) | **tilted 35° onto the door face** (`ACCENT_TILT`, existing) | no | The merchandise accent at roughly 3:1 over its surround (ALA, **reported** via `interior-lighting-design.md` §1.1). This is what gives the booth a defined *front* instead of a lit *top*. |
| 3 | **Practical — VISIBLE** | 1 | 20" disc (`is_disc`), else 20" × 20" | **1000** | **2700 K** warm | in the **ceiling plane**, on the grid point furthest from the booth | down | **YES — `invisible = 0`** | The single biggest lever on "looks natural", and today the rig has none. A 20" warm disc in the ceiling reads as a flush-mount luminaire. Its intensity is set **by eye on a ladder**, not by the budget — its job is to be *believed*, not to light, and at 4% of the room budget it is decoration that happens to emit. |
| 4 | **Wall graze** | 2 | 6" × 36" | **4300** | **3000 K** | wall top, **14" off** the wall opposite the largest door (today 24") | down | no | Vertical illuminance is what the camera sees. Pulled from 24" to 14" so it *grazes* rather than washes — the sourced graze band is 6-18" (**reported**, `interior-lighting-design.md` §1.3) — which turns the room wall into a texture instead of a gradient. Narrow and bright: a linear source, not another panel. |
| 5 | **Rim / kicker** | 1 | 12" × 36" | **2100** | **5000 K** cool | wall top, **opposite** the key across the booth, 30" out | **tilted 60° across the booth's back top edge** | no | Separation. Without it the booth's silhouette dissolves into the wall behind it and the frame goes flat. Cool against a warm key is the standard key/rim split, and it doubles as an implied window. |
| 6 | **Booth interior** | 1 | 12" × 24" | **1900** | **3000 K** warm | 6" below the booth's outer top (`BOOTH_DROP`, existing) | down | no | The booth is a sealed box: the sky and the room never light it. Sun off, lights off, the interior camera reads **0.0173 mean with 95.4% of the frame near-black** (**observed**). Without this layer the hero product is a hole in every frame. |
| 7 | **Foam graze** | 1 | 4" × 36" | **1800** | **3000 K** | inside the booth, **4" off the foam wall**, at the tray ceiling | down, along the wall | no | The foam is a real pyramid field — definition `Foam`, **1,447 faces, 2 instances, tag `WR-Booth-Foam` visible, geometry confirmed to survive into renders** (**observed**, `HANDOFF-lookdev.md`). Lit flat from above it vanishes; raked from 4" away across 2" of relief it self-shadows and reads. Its material is a flat-diffuse `_HostMaterial` shim with no reflection layer and no texture (**observed**), so **geometry is the only channel this surface has** — grazing is not a nicety, it is the entire mechanism. |

**Instances:** 2 + 1 + 1 + 2 + 1 + 1 + 1 = **9** with a booth; **6** without (roles 2, 6, 7
are booth-conditional).

**Variation achieved:** 2700 / 3000 / 3000 / 3000 / 3500 / 4000 / 5000 K · areas 144 → 2304 in²
(**16×**) · three directions (down, 35° tilt, 60° tilt) · one visible source · two grazing
sources.

### Where each intensity came from

`intensity = share × E / (n · u · v · Y(kelvin))`. The shares are design judgement — the one
column here that is taste rather than measurement, and they are **assumed**:

| Role | share | total area | Y | computed | rounded |
|---|---|---|---|---|---|
| Ambient | 0.42 of `E_room` | 4608 in² | 0.837 | 747 | **750** |
| Key | 0.22 of `E_room` | 576 | 0.792 | 3306 | **3300** |
| Practical | 0.04 of `E_room` | 400 | 0.705 | 973 | **1000** |
| Wall graze | 0.20 of `E_room` | 432 | 0.741 | 4287 | **4300** |
| Rim | 0.12 of `E_room` | 432 | 0.910 | 2093 | **2100** |
| Booth interior | 0.68 of `E_booth` | 288 | 0.741 | 1925 | **1900** |
| Foam graze | 0.32 of `E_booth` | 144 | 0.741 | 1811 | **1800** |

Brightness multiplies all seven: Dim ×0.5, Normal ×1.0, Bright ×2.0 (unchanged).

### The enclosure trim — how the rig survives 3 and 4 walls, capped and open

The ×26.5 anchor is for a **capped** room. In an **open-roof** room the sky adds a second
source that cannot be scaled, and a 3-sided room is *brighter* still: `w3-open` reads 0.5789
against `w4-open`'s 0.4557 at identical settings (**observed**) because the missing wall is
another sky opening. Capping costs about **1.5 stops** (**observed**, stage C).

So the tool **detects the enclosure and trims the room layers**:

| enclosure | roles 1, 3, 4, 5 (room) | roles 2, 6, 7 (booth-side) |
|---|---|---|
| ceiling, 4 walls | ×1.00 | ×1.00 |
| **no ceiling, 4 walls** | **×0.35** (−1.5 stops) | ×1.00 |
| **no ceiling, 3 walls** | **×0.25** (−2 stops) | ×1.00 |

The booth-side roles never trim: the sky was never getting into the booth. Capping the room
moves the booth interior by **4%** at `booth16x` (0.6261 → 0.6032, **observed**) — the
cleanest single result in the whole sweep. The trims themselves are **derived** from the
1.5-stop figure and the `w3-open` / `w4-open` ratio; they are the least certain numbers in
this spec, and Step 4 measures them.

**Auto-detected, never asked.** One button stays one button.

---

## 6. Investigation 1 — `units`: what V-Ray offers, and what to do

### The enum is no longer unknown. It is now observed.

The YARD Ruby docs at `…\extension\documentation\` genuinely contain **no light-parameter
reference at all** — they document the Ruby object model (`Context`, `Scene`, `Plugin`,
`Command`, `Transform`) and describe plugins as untyped key/value bags. Grepping the whole
tree for `intensity`, `lumens`, `kelvin`, `invisible`, `normalize`, `affect_reflections`
returns **zero matches**. The 1.8.0 header's conclusion was correct about that doc set.

The enum lives somewhere else, and it has now been read: the Asset Editor is an Electron app
and its label dictionary sits in
`…\extension\vrayneui\resources\app.asar` → `asset-editor.bundle.js`, keyed by V-Ray plugin
class (`"LightRectangle": {...}`). **Observed:**

| `units` | label (LightRectangle, LightSphere, LightSpot, LightMesh, LightOmni, LightCylinder) |
|---|---|
| **0** | **Default (Scalar)** |
| **1** | **Luminous Power (Lumens)** |
| **2** | **Luminance (lm/m^2/sr)** |
| **3** | **Radiant power (W)** |
| **4** | **Radiance (W/m^2/sr)** |

`LightDome` uses the same five with shorter labels. `LightIES` has no `units` — it has
`power`, labelled **"Intensity (lm)"**. Chaos's own tooltip on `units`, verbatim:

> "Specifies the light unit of measurement. Using correct units is essential when working with
> physical camera exposure. The light will automatically take the scene units scale into
> consideration to produce the correct result for the scale being worked in."

There is **no "Multiply by Size" / area-normalize control anywhere in the UI** (**observed** —
zero hits for `Multiply by Size`, `area_normalize`, `normalize_by`, `bySize` across all three
UI bundles). So the size-dependence of Default (Scalar) is inherent to the mode, not a toggle,
and `AREA_NORMALIZED` has no counterpart to check against. Step 1 still has to measure it.

### Recommendation: **stay on `units = 0`. And the reason has changed.**

The old reason ("we don't know the enum") is gone. The new reason is stronger, and it comes
straight out of the hard constraint:

**At EV 14.23, a physically-truthful interior rig renders about five stops dark, so any lumen
number this tool writes would be ~26× a real fixture's.** Two independent routes to that
figure, and they agree:

* The measured one: **×26.5 = 4.73 stops** (§4, from the sun-off EV ladder). **derived from
  observed frames.**
* The photometric one: the design doc's own arithmetic asks for 40 fc on the floor
  (`area × fc ÷ CU` = 192 × 40 ÷ 0.6 = **12,800 lm** for the reference room). 40 fc ≈ 430 lux;
  a 0.5-reflectance surface at 430 lux sits at ≈ 68 cd/m². EV 14.23 at ISO 100 meters for
  ≈ 2,400 cd/m². That is **35× — 5.1 stops** — under. **derived**, standard photometry.

So adopting lumens would put "**70,000 lm**" on a bedside lamp and "**340,000 lm**" in a
192 sq ft bedroom. **A physical unit carrying a false physical claim is worse than a scalar
that is honestly arbitrary** — it invites the next reader to compare it to a catalogue and be
wrong. The scalar makes no claim. That is the whole argument.

What adopting lumens would cost, stated so the decision can be revisited rather than
re-litigated:

* In `Default (Scalar)` intensity is a surface-brightness number, so a bigger light emits
  more; in `Luminous Power (Lumens)` it is total output and size is irrelevant. **Switching
  units does not rescale the layer table — it rebuilds the intensity column**, because the
  area term disappears. One-way door; do not ride it along with a design change.
* All 148 calibrated frames, the ×26.5 identity and the `booth16x` anchor are in the scalar.

**When lumens becomes the right answer, and it is a clean switch:** the moment an interior
exposure is acceptable. At **EV ≈ 9.5** the 12,800 lm arithmetic above drops straight in with
no fudge factor, `AREA_NORMALIZED` deletes itself, and the layer table becomes real fixtures —
a 2,700 lm ceiling panel, a 500 lm bedside lamp, an 800 lm light in the booth. `w4-ceil` +
`asfound` at EV 9.5 is already the one arm in the entire sweep where the rig as built serves
both cameras (**observed**). This is filed in Open-questions, not reopened here.

**Meanwhile:** `UNITS_SCALAR = 0.0` stays, and the console keeps printing the units value with
every layer, so a future change is visible rather than silent. The header's "the enum is NOT in
the docs, so this tool refuses to guess one" comment must be **rewritten** — it is now out of
date and would mislead the next reader.

### Two by-products of reading that bundle, worth having

* **No light type has a native Kelvin/temperature parameter** (**observed** — `color_mode` +
  `temperature` exist only on `SunLight` and on the `TexTemperature` *texture* node). So
  `kelvin_rgb` stays. A `TexTemperature` wired into `LightRectangle`'s Color/Texture slot is
  the alternative and is strictly better physics; it is **out of scope** here because it adds a
  second unproven plugin surface.
* **`LightRectangle` has `is_disc` → "Shape" (Rectangle / Disc)** (**observed**). A disc reads
  as a downlight and a rectangle reads as a panel — free, and it matters for role 3.
  Also present: `directional` ("Directionality"), `noDecay`, `doubleSided`, `affectDiffuse`,
  `affectSpecular`, `affectReflections`, `shadows`, `tex_resolution`, `lightPortal`.
* **Caution, and it is not optional:** those are **UI dictionary keys, not proven plugin
  parameter names.** The keys proven writable live are `invisible`, `units`, `intensity`,
  `color`, `directional`, `u_size`, `v_size` (**observed**). Anything new — `is_disc` included
  — must be written, read back, and **refused by name** if it does not stick. The disc is a
  nice-to-have; the rig must place correctly without it.

## 7. Investigation 2 — does the visible practical need real fixture geometry?

**No, not to ship this. But there is a real missing asset and a real precondition, and the
spec names both rather than assuming them away.**

* `VRay::Command` documents `create_rectangle_light`, `create_sphere_light`,
  `create_omni_light`, `create_spot_light`, `create_dome_light`, `create_ies_light`,
  `create_mesh_light`, `create_cylinder_light` (**observed**, `VRay/Command.html`) — geometric
  constructor args only, no light parameters.
* Setting `invisible = 0` on a rectangle light makes the emitter render as a bright rectangle.
  That is precisely the failure Benton reported on 2026-08-28 — "a visible white slab on the
  ceiling" (**observed**). **The defect and the feature are the same mechanism.** What made it
  a defect was that it was unintended, unshaped, and at room-lighting brightness. A **20" warm
  disc set into the ceiling plane at 1/25th of the room's energy budget** is a flush-mount
  luminaire. So role 3 needs **no new geometry**, and that is the recommendation for the first
  build.

**The precondition, stated plainly:**

* **A flush ceiling fixture needs a ceiling to be flush with, and `build-room.rb` draws no
  ceiling** (**observed**: `sunoff-results.json` carries `ceiling_in_model: false`;
  `lookdev-matrix.rb` has to build one with `ensure_ceiling!`). In an open-roof room the
  visible emitter is a glowing rectangle **floating in mid-air**, which is worse than no
  practical at all. **Role 3 is therefore placed only when a ceiling is detected, and refused
  by name — on the console — when it is not.**
* A `create_sphere_light` globe at pendant height has the same problem and worse: a glowing
  sphere with no cord, no canopy and nothing above it.

**What is genuinely missing, and it is Benton's to author:** there is **no lamp, pendant,
sconce, shade or luminaire component anywhere in the WhisperRoom library** — the listing is
booth panels, doors, vents, foam, desks and MJP (**observed**,
`.forge/builder/library-listing.txt`; a repo-wide grep for lamp / pendant / sconce / luminaire
/ fixture returns nothing outside the 3D-printing scripts). A shaded table lamp or a corded
pendant — the thing that would make a *bedroom* read as a bedroom rather than as a lit box —
requires a `.skp` component that does not exist. **This spec does not fake it and does not
build it.** With one authored lamp component and a `create_sphere_light` inside its shade, role
3 becomes the real thing; that is a small follow-up once the geometry exists.

## 8. Steps

Ordered. Steps 1 and 2 are **gates** — do not proceed past a failing one; report instead.

**Step 1 — settle the size/intensity coupling. GATE.**
Files: `scripts/lookdev-matrix.rb` (reuse `frame!` and `assert_lights_visible!`), new
`scripts/units-probe.py` (dev harness — **not** plugin code).
In a capped box, sun off: a 12"×12" and a 24"×24" rectangle light, same intensity, same
position; one 400×225 thumbnail each (~13 s a frame, **observed** mean 12.86 s). Read
`image-qa` means.
*If the 24" is ≈4× the 12":* intensity is surface brightness, `AREA_NORMALIZED = 1.0` stands,
and §4's budget stands — proceed.
*If they match:* **stop and report.** Every intensity in §5 must be recomputed as
`share × E / n` with the area term removed.
While the probe is set up, add `units` 1 and 3 arms (4 more frames) to record the
scalar↔lumens conversion factor, so §6's decision can be revisited later without re-deriving
anything.
Harness-only work does **not** bump `VERSION` (precedent: `HANDOFF-sunoff.md` §6).

**Step 2 — make the two silent preconditions explicit. GATE.**
File: `scripts/wr-drop-lights.rb`.
* **(a) Ceiling and wall-count detection** in `room_info`: a horizontal face at or above the
  wall top spanning the floor polygon, plus a count of wall runs. Print `capped / open,
  N walls` **by name**. Drives the §5 trims and role 3's precondition.
* **(b) Stamp the tag into every scene.** `WR Lights` read **`false` on the live model as
  found** (**observed**, `HANDOFF-sunoff.md` §1) — a hidden tag means V-Ray renders none of
  this. The tool already forces the tag visible for the session; it must additionally write
  that visibility into **every `model.pages` entry**, because scenes are captured with
  `use_hidden_layers = true` and re-apply their own stored copy on activation (**observed**,
  `proposal-scenes.rb:221,223`). This is auditor finding **C1**, ranked top, and it is the
  mechanism behind "same model, some frames lit, some black". Without it, no rig design
  survives a scene click.
* **(c)** No ceiling ⇒ apply the trims, **skip role 3, and say why on the console.**

**Step 3 — the layer rewrite.**
Files: `scripts/wr-drop-lights.rb`, `scripts/rbtest-lights.py`, `scripts/wr_tools/VERSION`
(bump), `DEVLOG.md`.
* `LIGHT_LAYERS` grows from 4 entries to 7 and gains `:kelvin`, `:share`, `:budget`
  (`:room` / `:booth`), `:visible`, `:tilt`, `:standoff`, `:n`.
* `scalar_intensity` becomes `share × E / (n · u · v · Y(kelvin))`, with `E` from the
  **35,700 per sq ft** room budget — **and it must divide by `Y`**. That is the colour-cost fix
  from §4.
* `configure_light` writes `invisible` from the layer spec instead of a constant, and writes
  `is_disc` for role 3 with a read-back that refuses by name if it will not take.
* Placement: ambient uses `grid_points` **capped at 2** (the grid is now the *soft* layer, not
  the whole rig); wall graze uses `wash_points` with `WASH_STANDOFF = 14.0`; key reuses the
  existing accent placement verbatim; rim mirrors the key about the booth centre with a 60°
  tilt; foam graze offsets 4" inside the booth's foam wall at the tray plane; practical takes
  the ceiling grid point furthest from the booth.
* **Delete the exposure question from `ask` and the entire `if opts[:exposure]` advice block at
  `:1602`** — it tells Benton to move to EV 8, which is cancelled. Rewrite the header's UNITS
  section per §6 and the "exposure is 30-60× more important" comment above
  `print_light_report`, both of which are now wrong.
* Add a `NEVER_WRITE` list — `/CameraPhysical`, `/SettingsOutput`, `/SunLight`,
  `/SettingsEnvironment` — with the reason at the site, the way `lookdev-matrix.rb` does.
* Dialog becomes **two dropdowns**: `Brightness` (Dim / Normal / Bright) and `Warmth`
  (Warm / Neutral), where Warmth is a **global Kelvin offset** — Warm = the table as written,
  Neutral = every layer +500 K. It *shifts* the palette; it never flattens it. Everything else
  is a default.
* `rbtest-lights.py` gains checks for: shares summing to 1.0 within each budget, the `Y`
  division, the enclosure trims, exactly one visible layer, and that no two layers share a
  Kelvin *and* a size.

**Step 4 — measure the rig at Benton's camera. Exposure is not a variable.**
Files: `scripts/lookdev-matrix.rb`, new `scripts/rig-drive.py`,
`.forge/builder/rig-results.json`.
Fixed **EV 14.23**, sun off: 6 rooms (the `sunoff` enclosure axis — `w4-open`, `w4-ceil`,
`w4-nosky`, `w3-open`, `w3-ceil`, `w3-nosky`) × 2 cameras × 3 brightness settings =
**36 frames, ~8 minutes**. Assert per frame *before* rendering that the `WR Lights` tag is
visible and the instance count is 9 — the `assert_lights_visible!` pattern exists and has
already caught one null experiment. Then a **practical ladder**: role 3 at 5 intensities × 1
camera = 5 frames, for Benton to pick the visible fixture's brightness from.

**Step 5 — contact sheet, then hand off. Benton picks; no agent picks the look.**

## 9. Acceptance criteria — every one runnable

| # | Criterion | How |
|---|---|---|
| 1 | `python scripts/rbparse.py` clean; `python scripts/rbtest-lights.py` all checks pass, new ones included | offline, real CRuby 3.2 |
| 2 | A press in a capped 16'×12' room containing a booth places **exactly 9 instances and 9 live V-Ray plugins**; presses 2 and 3 leave it at 9 with `0 left behind` | bridge job: count instances, `scene.grep` |
| 3 | The nine plugins carry **≥ 5 distinct `color` values** | read back per plugin. A single-hue rig fails outright |
| 4 | **Exactly one** plugin has `invisible = 0`, and it is the practical | read back |
| 5 | The nine `u_size × v_size` areas span **≥ 10×** | read back |
| 6 | Zero `DID NOT STICK` lines, and every read-back happens **outside** the `scene.change` block | console + code review |
| 7 | `/CameraPhysical`, `/SettingsOutput`, `/SunLight` and `/SettingsEnvironment` read back **unchanged, key by key**, across a press | snapshot before and after, the `HANDOFF-sunoff.md` §7 method |
| 8 | **Sun disabled, EV 14.23, `w4-ceil`:** both cameras PASS `image-qa`'s render profile (mean 0.12-0.75, clipping < 40%) at Brightness = Normal | Step 4 |
| 9 | The same holds in `w4-open`, `w3-open` and `w3-ceil` at Normal — **one exposure, Benton's own, serves every enclosure** | Step 4. If it does not, the §5 trims are wrong: state that with the numbers, do **not** patch it with a per-scene EV |
| 10 | The visible practical is identifiable as a fixture in the exterior frame and is not clipped to white | Benton's eye on the ladder — **this one is a judgement and is labelled as such** |
| 11 | The foam reads as relief: the interior frame shows self-shadowing across the pyramid field | Benton's eye, against `FOAM_interior-800x450_booth16x_ev14.png` as the "before" |
| 12 | After a press, **every** `model.pages` entry stores `WR Lights` visible | loop the pages and read |

## 10. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| **The size/intensity coupling is wrong** (`AREA_NORMALIZED`) — every intensity in §5 off by up to 16× | high | Step 1 is a gate and costs six thumbnails |
| The ×26.5 anchor comes from **one room** — 192 sq ft, 8' walls, one booth | medium | The per-sq-ft budget is linear in floor area and **ignores ceiling height** (**assumed**). Step 4 sweeps an enclosure axis but **not a size axis**; say so rather than imply generality |
| **`image-qa` mean luminance is a crude proxy.** The `w4-open` exterior frame contains open sky, so its mean tracks how much sky is in shot as much as how well the room is lit | medium | Judge the open-roof arms by eye, not by the gate. The `w4-ceil` numbers are the trustworthy ones, which is a second reason to design to that row |
| The enclosure trims (×0.35 / ×0.25) are **derived, not measured** | medium | Step 4 measures them. If they miss, they are two constants |
| **Scenes re-apply stored tag visibility** and can hide the whole rig | high | Step 2(b). This has already produced "same model, some frames lit, some black" (auditor C1) |
| A **visible** emitter may blow out, or may not read as a fixture at all | medium | The 5-frame ladder; Benton picks. If it reads as a floating slab, fall back to `invisible` and report that the practical needs authored geometry |
| `is_disc` may not be the real plugin key | low | Written, read back, refused by name. The rig places correctly without it |
| **Writing a newly created V-Ray *material* plugin hangs SketchUp**, as does `Scene#delete` on a bound material and `show_safe_frames` (**observed**, four force-kills) | high | Do none of those. This rig touches **light** plugins only, which are proven writable inside `scene.change` |
| Warm layers get visibly brighter than before, because of the `Y` division | low | Intended. It is the fix for a real error |

## 11. Out of scope

* Any change to booth geometry, foam geometry, or the `_HostMaterial` shim on `Color_I06`.
  Converting the host materials to real `VRayMtl` is probably the largest remaining "why does
  it read as cardboard" win (**observed**, `HANDOFF-lookdev.md`) — library materials live on
  `P:`, read only, and it is **not this work**.
* Authoring a lamp / pendant / sconce `.skp`. Named as missing; Benton's to draw.
* Adding a ceiling to `build-room.rb`. Named as a dependency; a separate decision.
* Writing **any** V-Ray setting — exposure, output, sun, environment. Not negotiable.
* IES, dome, spot, cylinder and mesh lights. The API exposes all of them and `LightIES` takes
  real photometry in lumens (**observed**) — but there is no `.ies` file in this repo, and
  adopting a second light type now stacks an unproven surface on an unproven area coupling.
* `TexTemperature` wired into the colour slot. Better physics, later.
* Per-scene anything. One rig, one exposure.
