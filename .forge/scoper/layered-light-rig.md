# Spec — `wr-drop-lights.rb` as a layered interior lighting rig

Scoper, 2026-08-30. **Revision 2** — Benton answered all five forks and two of them moved the
foundation: the rig is now in **lumens** against a **considered interior exposure**, and the
tool **builds its own fixture geometry**. Revision 1's scalar calibration is preserved in §5
because it is what *proved* the exposure was wrong; it is no longer what sets the numbers.

Provenance tagged **observed / derived / reported / assumed** throughout. **No code written, no
render run.** Numbers trace to `.forge/builder/sunoff-results.json` (148 frames, sun off on all
of them, **observed**), the live rig read through the bridge (**observed**), the V-Ray
install's own resources (**observed**), a luminaire research pass (**reported**, cited in §7.4),
or arithmetic on those (**derived**).

---

## 0. What changed in revision 2

| Fork | Benton's answer | What it moved |
|---|---|---|
| **Exposure** | "Just the default, never touched it." EV 14.23 was never a choice | §4 and §5 rebuilt. **One considered interior exposure, written once as a documented default. Units move to `1` — lumens.** |
| **Fixtures** | "Can't you make your own? … just make them into our scripts" | New §7: **four procedurally generated fixture types**, drawn in Ruby from primitives. **Five of the nine lights are now visible fixtures** |
| **Ceiling** | On demand — the tool adds one and takes it away | New §8. Specced with a **verified removal**, because two restores have already lied today |
| **Aiming** | Booth-relative | Confirmed as already specced |
| **Tag gate** | Stands | Still a gate (§9 Step 2) |

**And one thing the fixture research changed that Benton did not ask for.** Revision 1 gave the
visible practical **4% of the room budget — 500 lm**. A real 18" flush-mount ceiling fixture
emits **2,000 lm** (**reported**, §7.4). A visible fixture that emits a tenth of what its
real-world twin emits is *itself* a CG tell: the eye reads the fixture, then reads the light,
and they disagree. So the table below is reorganised around a rule that was not in revision 1 —
**where a share disagrees with a real product, the real product wins for anything visible, and
the invisible layers absorb the difference.**

---

## 1. Goal

Replace the current one-tier grid of identical invisible glowing panels with a **seven-role
layered rig, lit by fixtures the tool draws**, that

* is calibrated in **lumens against a considered interior exposure**, so every number in the
  layer table can be checked against a real product on a shelf;
* **carries the shot with the sun off** — sun becomes dressing, not the source;
* puts **five real, visible luminaires in frame** — two ceiling fixtures, a pendant and a pair
  of sconces — built procedurally, not stubbed;
* varies **colour temperature (2700 K → 5000 K)**, **size** and **direction** across layers;
* **rakes the acoustic foam** so its 1,447-face pyramid relief reads instead of disappearing;
* stays **one button with sensible defaults** — two dropdowns, no lighting-designer UI;
* **leaves Benton's drawing exactly as it found it**, including the ceiling it borrows.

## 2. What is wrong today, in one paragraph

Eight lights, **one colour on all of them** — `Color(1, 0.694903, 0.431048)`, exactly
`kelvin_rgb(3000)` (**derived**) — **`invisible = 1` on all of them**, all flat rectangles
pointing straight down, `units = 0`. Four 12"×12" @ 426.64, two 6"×24" @ 120, one 12"×24" @
106.8, one 12"×12" @ 480 (**observed**). One layer doing every job: no visible source, no
temperature spread, nothing raking anything, one shadow direction. That is a **design** fault,
not a tuning fault — which is why no amount of moving `REF_INTENSITY` has fixed it.

## 3. What is worth keeping — do not rewrite these

| Keep | Why |
|---|---|
| The whole **pure placement section** — `grid_spacing`, `axis_points`, `grid_count` and its 1/16" snap, `point_in_poly?`, `seg_dist`, `edge_dist`, `poly_area`, `poly_centroid`, `in_keepout?`, `edge_threshold`, `grid_points`, `nearest_edge`, `opposite_edge`, `wash_points`, `accent_axis` | 38 + 10 checks pass in `scripts/rbtest-lights.py` in real CRuby outside SketchUp. L-shapes, keep-outs, edge band and centroid fallback are sound. **observed** |
| `write_params` / `read_param` and the `VRay::Scene#change` transaction | The 1.9.1 fix. A bare `plugin[k] = v` outside a transaction is silently discarded. **observed** |
| `erase_lights` / `reap_lights`, place-first-reap-last | The 1.9.1 second-press kill fix. **observed** |
| `create_light`, `param_agrees?`, the refuse-by-name style, the per-layer console report | The no-silent-fallback discipline this repo runs on |
| `kelvin_rgb` | Correct, exact at 6600 K — now called **per layer** instead of once |
| `room_info` | It already returns `:poly` (world-space floor polygon) and `:z_top` (wall top). **The on-demand ceiling is that polygon, faced at that height** — so §8 needs no new geometry logic and gets L-shaped rooms for free |
| `booth_door_center`, `accent_axis`, and the tilt composition at `:2023` (`translation * rotation`, so a light spins about its own origin) | The only aiming machinery in the file. The rim and the foam graze reuse it verbatim |
| The subject vetoes — `subject_veto`, `light_words?`, `vray_light?`, `booth_like?` | The light-as-room incident is not worth repeating |
| `scripts/pendant-jig.rb`'s geometry idiom — `add_group` / `add_circle` / `add_face` / `pushpull` / `add_faces_from_mesh` | The in-house procedural-geometry precedent §7 builds on. **observed**, `pendant-jig.rb:222-359` |

---

## 4. Exposure — the number, and the distinction that matters

### The distinction, first, because it is the whole point

**Setting a considered interior exposure once, as a documented default, is not the same thing
as a tool fiddling with exposure per scene.** Benton objected to the second and was right to:
per-scene EV was a workaround for a rig that had no light in it, and chasing a bad rig with the
camera is backwards. That stays cancelled.

What this spec does instead: **write one interior exposure, once, log it loudly, and then leave
the camera alone.** It does not vary per row, per scene or per room. It does not adjust to
compensate for anything. It is a default — the way 8'-0" is the house default ceiling height in
`build-room.rb` — and it is revertible in one number.

### The number

EV 14.23 was never chosen. It is `f/8 @ 1/300, ISO 100` — V-Ray's factory physical camera
(**observed**, `/CameraPhysical` read back as f/8, ISO 100, shutter 300) — and it is a
**full-sun exterior exposure**. Deriving what an interior actually wants, from the design
target this project already uses:

* Design target **40 fc** on the floor (retail sales-floor band 30-80 fc, **reported**,
  `interior-lighting-design.md`) = **430.6 lux**.
* A Lambertian surface at illuminance `E` and reflectance `ρ` has luminance `L = ρE/π`.
* A reflected-light meter at ISO 100 is calibrated `L = 2^EV × K/S` with `K = 12.5`, so
  `EV = log2(L × 8)`.

| effective room reflectance ρ | L (cd/m²) | EV |
|---|---|---|
| 0.35 (charcoal carpet weighted in) | 48.0 | **8.58** |
| 0.40 (walls + booth panels dominate the frame) | 54.8 | **8.78** |
| 0.50 (light interior) | 68.5 | **9.10** |

WhisperRoom interiors run charcoal carpet (~0.15), grey/white panels (~0.4-0.5), light walls
(~0.6), blue foam (~0.2), and the frame is dominated by walls and panels rather than floor — so
**ρ ≈ 0.40-0.50 and the target band is EV 8.8-9.1**. **derived.**

**Corroboration from a rendered frame, not just arithmetic:** `w4-ceil` + the as-found rig,
sun off, passes both cameras at **EV 9.5** — the only arm in the entire 148-frame sweep where
the *fixtures alone* serve both views (**observed**). That is within 0.4-0.7 stops of the
photometric band, from a completely independent direction.

### The recommendation: `f/8, 1/300, ISO 3200` → **EV 9.23**

**Change ISO only. Leave f-number and shutter exactly where Benton has them.**

* In a V-Ray physical camera **ISO is pure gain** — it changes brightness and nothing else.
  f-number also drives depth of field and shutter also drives motion blur if either is enabled;
  neither should move, and not moving them removes that risk entirely.
* ISO 100 → 3200 is **exactly five stops**. One clean, memorable, trivially revertible number.
* EV 9.23 sits **0.13 stops** from the ρ = 0.50 photometric target and **0.27 stops** from the
  measured-good EV 9.5. Both agree.
* Erring very slightly **dark** is the safe direction: clipped highlights are unrecoverable,
  shadows are not, and the Brightness dropdown adds a stop when a room wants one.

### How the tool is allowed to write it

Narrow, loud, once — this is the part that must not drift back into per-scene fiddling:

1. Write `/CameraPhysical` **ISO only**. Never `f_number`, never `shutter`, never anything in
   `/SettingsOutput`, `/SunLight` or `/SettingsEnvironment`.
2. Write it **only if the model has not been stamped before** — record the stamp in the model's
   `WR_DropLights` dictionary (`exposure_stamped => ISO, timestamp`). A second press does not
   re-write it.
3. Write it **only if the camera is still at the factory ISO 100**. If it holds anything else,
   Benton has set it: **report the value and leave it alone.** This is the "honour the user's
   settings" rule, applied exactly.
4. **Print what it did and how to undo it**, by name: the old value, the new value, and
   `Asset Editor > Settings > Camera > ISO`.
5. Read it back after the transaction and refuse by name if it did not stick.

---

## 5. The calibration — and why revision 1's scalar work still matters

Revision 1 established one **rigorous** identity, and it is what proved the exposure was wrong:

> Physical-camera exposure is linear in `2^-EV` and is applied **before** tone mapping.
> Therefore *multiplying every light by `2^Δ` is exactly identical to lowering EV by `Δ`.*
> **derived**, from the definition of EV. No gamma assumption anywhere.

Applied to the sun-off EV ladder, it said the rig as built was **×26.5 — 4.73 stops — too dim**
for EV 14.23 in a capped room. The photometric route in §4 independently said **5.1 stops**.
Two methods, 0.4 stops apart, both pointing at the same thing: **the camera, not the rig.**

That is now acted on. With EV 9.23 the deficit is gone and **the design lumens stop being a
fiction** — which is precisely what makes lumens the right unit.

**What still comes from the sun-off data, and is not superseded:**

* **The booth is a sealed box.** Sun off, lights off, the interior camera reads **0.0173 mean
  with 95.4% of the frame near-black** (**observed**). Nothing but a fixture inside the booth
  lights the booth.
* **Capping the room costs about 1.5 stops** on the room view and **4%** inside the booth
  (0.6261 → 0.6032 at `booth16x`, **observed**). That asymmetry is why §6's enclosure trim
  applies to room layers only.
* **A 3-sided room is brighter than a 4-sided one** — `w3-open` 0.5789 vs `w4-open` 0.4557
  (**observed**) — because the missing wall is another sky opening.
* **`image-qa` mean luminance is a crude proxy.** In an open-roof room the mean tracks how much
  sky is in shot as much as how well the room is lit. Judge open arms by eye.

### The lumen budget

Straight from the design doc's own arithmetic, with no fudge factor — which is the payoff:

```
room lumens  = floor_sqft × 40 fc ÷ 0.6 CU      192 sq ft → 12,800 lm
booth lumens = booth_sqft × 30 fc ÷ 0.6 CU       24 sq ft →  1,200 lm
```

`TARGET_FC`, `BOOTH_FC` and `CU` already exist as constants. In `Luminous Power (Lumens)` mode
intensity is **total output and size-independent**, so **the area term disappears and
`AREA_NORMALIZED` deletes itself.**

**One open assumption, and Step 1 tests it:** whether V-Ray's lumen value is the flux *before*
the colour tint (photometrically correct — colour changes chromaticity, not quantity) or
whether it still multiplies by the colour. If the latter, revision 1's `Y` division comes back.
**assumed**; the probe is two thumbnails, a 2700 K and a 6500 K light at the same lumens.

---

## 6. THE LAYER TABLE

Seven roles, **9 light instances** with a booth, **6 without**. Benton's "5-7 light sources" is
read as *roles* — what a designer counts; the ceiling pair and the sconce pair are one role
each. Heights are relative to the **wall-top plane** (`z_top` from `room_info`) or **AFF** where
stated. Lumens are for a **capped room, sun off, EV 9.23, Brightness = Normal**, in the 192 sq ft
reference room; they scale with floor area via the budget above.

| # | Role | n | Emitter | **Lumens each** | Colour | Fixture | Position | Direction | Visible | Why it exists |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | **Ceiling ambient** | 2 | 17.5" disc | **2,000** | **3500 K** | **F1 flush drum, ⌀18"** | ceiling plane, on the two `grid_points` furthest from the booth | down | **YES** | The general layer **and** the room's obvious light source, which is the same object because in a real room it is. Revision 1 kept these apart and that was the mistake: a phantom 48" panel doing the work while a dim prop hung nearby. 2,000 lm is exactly what an 18" flush mount emits (**reported**, §7.4), so fixture and light agree. |
| 2 | **Key / booth face** | 1 | 24"×24" rectangle | **2,800** | **3200 K** | none (invisible) | wall top, 42" out from the booth door face (`ACCENT_OUT`) | **tilted 35° onto the door face** (`ACCENT_TILT`) | no | The merchandise accent at roughly 3:1 over its surround (ALA, **reported**). What gives the booth a defined *front* instead of a lit *top*. 2,800 lm is a 30 W track head. Invisible because a track head aimed at the hero is stagecraft the client should feel, not see. |
| 3 | **Pendant** | 1 | sphere ⌀3" | **1,200** | **2700 K** warm | **F2 cord-hung drum, ⌀16"** | shade bottom **78" AFF**, in the corner of the floor polygon furthest from the booth | down + through the shade | **YES** | The warm, human-scale, domestic cue — the single object that makes a room read as *designed for people* rather than *lit for a camera*. At 2700 K against the 3500 K ceiling it is unmistakably the warm source. 1,200 lm is a real drum pendant (**reported**). |
| 4 | **Sconces / wall graze** | 2 | sphere ⌀2", one per open end (**4 spheres, 2 fixtures**) | **600** total per fixture, split 300 up / 300 down | **3000 K** | **F3 cylinder up/down, ⌀5"** | **66" AFF** on the wall opposite the largest door, spaced by `wash_points` | up **and** down through the open cylinder ends | **YES** | Vertical illuminance is what the camera sees. An open-ended cylinder throws the classic double scallop — **it is the graze layer and a visible fixture in one object**, the most "an interior designer did this" element available. Grazing is about *angle*, not total output, so 600 lm at 5" from the wall out-reads a 1,300 lm panel standing 14" off it. Fallback if it cannot be mounted: the invisible 6"×36" strip at 14" standoff. |
| 5 | **Rim / kicker** | 1 | 12"×36" rectangle | **1,600** | **5000 K** cool | none (invisible) | wall top, **opposite** the key across the booth, 30" out | **tilted 60° across the booth's back top edge** | no | Separation. Without it the booth's silhouette dissolves into the wall behind it and the frame goes flat. Cool against a warm key is the standard key/rim split, and it doubles as an implied window — which is also why it is the one layer that should *not* have a visible fixture. |
| 6 | **Booth interior** | 1 | 12"×24" rectangle | **800** | **4000 K** neutral | none (invisible) | 6" below the booth's outer top (`BOOTH_DROP`) | down | no | The booth is a sealed box: sun off and lights off, the interior camera reads **0.0173 mean, 95.4% near-black** (**observed**). Without this the hero product is a hole in every frame. **4000 K, deliberately cooler than the room** — a recording booth is a work space, and the temperature step across the doorway is what makes it read as a separate room rather than a niche. |
| 7 | **Foam graze** | 1 | 4"×36" rectangle | **400** | **3500 K** | none (invisible) | inside the booth, **4" off the foam wall**, at the tray ceiling | down, along the wall | no | The foam is a real pyramid field — definition `Foam`, **1,447 faces, 2 instances, tag `WR-Booth-Foam` visible, geometry confirmed to survive into renders** (**observed**). Lit flat from above it vanishes; raked from 4" away across 2" of relief it self-shadows and reads. Its material is a flat-diffuse `_HostMaterial` shim with no reflection layer and no texture (**observed**), so **geometry is the only channel this surface has** — grazing is not a nicety, it is the entire mechanism. |

**Instances:** 2 + 1 + 1 + 2 + 1 + 1 + 1 = **9** with a booth; **6** without (roles 2, 6, 7 are
booth-conditional). **Five of the nine are visible fixtures** — up from zero.

**Variation:** six colour temperatures (2700 / 3000 / 3200 / 3500 / 4000 / 5000 K) · three
emitter shapes (disc, sphere, rectangle) · four directions (down, up-and-down, 35° tilt, 60°
tilt) · three fixture types · two grazing sources.

**Every visible number is a real product number**, which is the whole point of moving to lumens:
2,000 lm 18" flush mount · 1,200 lm drum pendant · 600 lm decorative sconce (all **reported**,
§7.4) · 2,800 lm track head · 1,600 lm wall washer · 800 lm booth light · 400 lm graze strip.
Benton can hold every one of them against a product page.

### The budget, and the 16% it does not spend

| Role | n | lumens each | total | share of room budget |
|---|---|---|---|---|
| Ceiling ambient | 2 | 2,000 | 4,000 | 31% |
| Key | 1 | 2,800 | 2,800 | 22% |
| Pendant | 1 | 1,200 | 1,200 | 9% |
| Sconces | 2 | 600 | 1,200 | 9% |
| Rim | 1 | 1,600 | 1,600 | 13% |
| **room total** | | | **10,800** | **84% of 12,800** |
| Booth interior | 1 | 800 | 800 | 67% of booth |
| Foam graze | 1 | 400 | 400 | 33% of booth |
| **booth total** | | | **1,200** | **100% of 1,200** |

**The room lands 2,000 lm — 0.24 stops — under its nominal budget, and that is deliberate,
not a rounding error.** The `area × fc ÷ CU` formula assumes a coefficient of utilisation for
downward-throwing fixtures. Three of these five room sources are shaded luminaires that throw
sideways and upward; some of their output lands on ceiling and wall rather than floor. Rooms lit
that way *meter* lower and *look* better, which is the trade being made on purpose. 0.24 stops
is inside the noise of the ladder anyway, and Brightness = Bright doubles everything. **derived**;
Step 5's ladder settles it empirically.

### The enclosure trim

With §8's on-demand ceiling the **capped case is the default**. The trims below are the fallback
for when a ceiling could not be added — refused, or the room already has one the tool does not
own:

| enclosure | roles 1, 3, 4, 5 (room) | roles 2, 6, 7 (booth-side) |
|---|---|---|
| ceiling present, 4 walls | ×1.00 | ×1.00 |
| **no ceiling, 4 walls** | **×0.35** (−1.5 stops) | ×1.00 |
| **no ceiling, 3 walls** | **×0.25** (−2 stops) | ×1.00 |

Booth-side roles never trim — the sky was never getting into the booth. The trims are **derived**
from the observed 1.5-stop capping cost and the `w3-open` / `w4-open` ratio; they are the least
certain numbers here and Step 5 measures them. **Auto-detected, never asked.**

---

## 7. The fixtures — procedurally generated, in Ruby, at drop time

Benton's answer lifted the blocker: build them rather than wait for authored `.skp` files. The
repo already does this — `scripts/pendant-jig.rb` draws its whole part from `add_group`,
`add_circle`, `add_face`, `pushpull` and `add_faces_from_mesh` (**observed**, `:222-359`). House
practice, not a new idea.

### 7.1 The binding rule — read this before drawing anything

**Fixture geometry does NOT go inside the V-Ray light definition.** `create_rectangle_light`
returns a component definition V-Ray owns; it contains zero faces, and deleting such a definition
schedules a **deferred purge by plugin name** that killed the entire rig once already
(**observed**, 1.9.1). So:

* The fixture is its **own group**, drawn by the tool, placed in the same drawing context.
* The light instance is placed **separately**, at the right offset inside the fixture's frame.
* **Both** go on the `WR Lights` tag and **both** carry the `WR_DropLights` dictionary, so the
  existing recursive world-space stale sweep removes both on the next press. **No new sweep
  logic.**
* Emitters inside a shade use **`create_sphere_light`** — a sphere reads round from every angle,
  is physically exactly "a bulb in a shade", and needs **no unproven parameter**. Only F1's flush
  disc wants `is_disc`, and its fallback is a square emitter behind a ring.

### 7.2 The four types

| | **F1 — Flush ceiling drum** | **F2 — Cord-hung pendant** | **F3 — Cylinder up/down sconce** | **F4 — Floor lamp** |
|---|---|---|---|---|
| **Role** | 1 (ceiling ambient) | 3 (pendant) | 4 (sconces) | dressing / optional |
| **Drawn from** | commodity LED flush mount — an archetype, no iconic reference design exists | Louis Poulsen **PH5** (19.7"⌀ × 11.1"H), Nelson **Bubble/Ball** (medium 19"W × 15.5"H), Noguchi **Akari** | commodity up/down cylinder — archetype, no iconic reference | IKEA **BARLAST** (59"H, 11.8"⌀ shade, 13.4"⌀ base) |
| **Geometry** | canopy disc ⌀5" × 1"; drum wall ⌀18" × 3.5"; **open bottom** — the emitter disc *is* the diffuser | canopy ⌀5" × 0.75"; cord ⌀0.5"; truncated-cone shade, top ⌀10", bottom ⌀16", 10" tall, 0.125" shell | open-ended cylinder ⌀5" × 12", 0.125" shell; backplate ⌀5" × 0.5"; body projects 5.5" from wall | base disc ⌀13" × 0.75"; stem ⌀1"; drum shade ⌀18" × 11", 0.125" shell; overall 59" |
| **Mount** | ceiling plane (flush, ≤3" drop) | canopy at ceiling; **shade bottom 78" AFF** | **66" AFF**, 3" standoff | floor |
| **Emitter** | 17.5" disc rectangle light (`is_disc`), 0.25" inside the open bottom | sphere ⌀3", centred 4" up inside the cone | **two** spheres ⌀2", one at each open end, ±0.5" outside | sphere ⌀3", 4" up inside the shade |
| **Real lumens** | 1,200-2,000 (18" = 2,000) | 800-1,600 | 150-600 interior decorative | 800-1,500 |
| **Real CCT** | 2700-5000 selectable; 3000 K most common | 2700-3000 K | 3000 K | 2700-3000 K |
| **Faces (24-seg)** | ~75 | ~130 | ~110 | ~180 |
| **Build order** | **first** | second | third | **last, optional** |

**Why that build order.** F1 first because it *is* role 1 in the default rig and it is the
largest single change to the picture. F2 second: biggest look payoff per face, hangs in open air
so it needs no collision logic. F3 third: it upgrades role 4 from an invisible strip to a
visible fixture — the largest jump in "an interior designer did this" — but it costs two extra
light instances and a wall-mounting frame. **F4 last, and it is genuinely optional**: the most
"bedroom" of the four and the only one that puts a human-scale object at floor level, but it
stands on the floor where the booth is, so it needs the existing keep-out test and is the most
likely to intersect something.

**If a Builder can only do one: F1 alone is a complete, shippable improvement.** Roles 3 and 4
fall back to invisible emitters and the rig still works.

### 7.3 Honesty rules for the geometry

* **A shade must read as a shade, not a box.** Cones and cylinders get a real 0.125" shell, not
  a single unshaded plane — a one-sided surface renders dark from inside and gives the whole
  thing away. Extra faces are cheap; ambiguity is not.
* **Create no SketchUp materials.** Reuse an existing model material by name if one is there,
  otherwise leave the default. `lookdev-matrix.rb:446` does `materials[X] || materials.add(X)`
  and its removal path never took the material back — exactly the orphan that left **37 materials
  where the model had 36** (**observed**). Do not repeat it.
* **KNOWN LIMITATION, stated rather than hidden: F2 and F4's shades will render opaque.** A real
  fabric drum shade is a *translucent diffuser* — light escapes through the shade wall as well as
  up and down (**reported**, §7.4). Making ours glow needs a translucent V-Ray material, and this
  tool is forbidden from creating materials (above, and because writing a newly created material
  plugin **hangs SketchUp** — **observed**, four force-kills). So the pendant and floor lamp will
  read as a shade with light escaping top and bottom, not as a glowing lantern. **That is a
  visible difference from the real object.** F1 and F3 are unaffected: F1's diffuser *is* the
  visible emitter, and a real up/down cylinder is opaque metal anyway. Fixing F2/F4 properly is a
  materials question and is out of scope.
* **Face count is a budget.** 24 segments everywhere; assert the total added face count on the
  console.
* Every fixture group is **named**, **tagged `WR Lights`**, and **stamped with the
  `WR_DropLights` dictionary** so the sweep owns it.

### 7.4 What the dimensions and lumens are drawn from

A luminaire research pass sourced the figures above. **All of it is `reported`** — read from
product data and design guides, not measured here. Where a figure was a synthesis across sources
rather than a single citation it is marked *(generalised)* and is a single constant a Builder can
change.

* **Flush ceiling drum.** Common residential diameters 12-24"; ≤3" deep for a flush mount on an
  8-9 ft ceiling. Measured products: 9" = 1,500 lm / 17 W; 14" = 1,460-1,500 lm; **18" = 2,000 lm**
  — which is the number role 1 uses. Nearly all ship colour-selectable 2700-5000 K with 3000 K the
  common default. Diffuser is a translucent acrylic lens that glows evenly, **which is exactly the
  visible-emitter-as-diffuser construction F1 uses.** A sizing rule of thumb — diameter in inches
  ≈ room length + width in feet — would give 28" for the 16'×12' reference room; **18" is chosen
  instead**, at the top of the common band, because a 28" disc dominates a booth render.
  *Sources: Lumens ceiling-light size guide; Parrot Uncle sizing guide; Home Depot Maxxima 9"
  1500 lm; Sunlite 14" 1500 lm; LightUp 18" 2000 lm.*
* **Pendant.** Shade diameters 10-14" small, **16-20" the common medium**, 30"+ oversized. Canopy
  5" is the standard single-hole kit; cord/stem is ¼ IPS lamp pipe, **OD ≈ 0.5"**. Hanging: shade
  bottom 30-36" above a table on an 8-9 ft ceiling; **78" AFF in a walkway is generalised**, not
  sourced. Named forms the shape is drawn from: **Louis Poulsen PH5** 19.7"⌀ × 11.1"H (PH5 Mini
  11.8"⌀ × 6.4"H); **Nelson Bubble/Ball** small 12.75"W × 12"H, medium 19"W × 15.5"H, large
  26.75"W × 23"H; **Noguchi Akari** 45A ≈ 17.7", 55A ≈ 21.7". Output 800-1,600 lm *(generalised)*,
  2700-3000 K. *Sources: Fenchel Shades drum-pendant guide; Houlte pendant size calculator; Barn
  Light canopy guide; Louis Poulsen; Century House / Modernica; Vitra Akari.*
* **Cylinder up/down sconce.** Diameters 2.5-6" (5.1" and 6" both common); heights 3.5" / 12" /
  16" / 18". Backplates 4.5-11.25"; a compact modern unit is 4.5-6". Wall projection 4-7"
  *(generalised)*. **Mounting height 60-72" AFF, commonly 66"** for 8 ft ceilings — 60" in
  hallways, 60-70" at a vanity, ~60" beside seating. The body is **opaque metal; light escapes
  only through the open top and bottom**, which is the double scallop role 4 wants. A bright
  outdoor example measures 1,680 lm at 3000 K / 24 W; interior decorative units run 150-600 lm
  *(generalised)*. *Sources: Maxxima outdoor cylinder; LED City 18" cylinder; Contech CYL6;
  Kichler via Lumens; Seus Lighting and Edward Martin sconce-height guides.*
* **Floor lamp.** Overall 58-60"; shade height 10-13" and roughly ⅔ of the stem height below it;
  shade bottom diameter ≈ 2× the widest point of the base, so a 10" base takes an 18" shade and a
  13" base a 20-22" shade. **IKEA BARLAST**: 59" tall, 11.8"⌀ shade, 13.4"⌀ base. Stem ~0.75-1.5"
  *(generalised)*. Output 800-1,500 lm, 2700-3000 K. *Sources: Antique Lamp Supply shade sizing;
  Precise Calculators shade calculator; IKEA BARLAST; DeckTok and Sunmory floor-lamp lumen
  guides.*
* **Mounting-height guidance.** Habitable rooms require ≥7 ft ceiling height by code; fixture drop
  itself is not code-restricted, but ≥7 ft clearance under the lowest point in a walkway is the
  practical convention.
* **The one figure the research could NOT find, and it matters.** There is **no published
  lamp-shade light-transmittance number**. The only percentages available (sheer window shades
  15-25%, semi-sheer 10-20%) are a *different product category* and were explicitly flagged as
  unsuitable. Lamp-shade sources describe transmission only qualitatively. **So shade absorption
  must be measured, not assumed** — which is why Step 3 renders it rather than taking a constant
  off a page. **This is the single largest unknown in §6's lumen column.**

---

## 8. The on-demand ceiling — and its removal, which is the riskiest thing in this spec

Benton's answer: drawings stay open as they are; the tool adds a ceiling for the lighting work
and takes it away. **The removal is the highest-risk part of this whole spec**, because a ceiling
that fails to be removed silently alters his drawing — and **two separate restores have already
lied today**: one reported "restored clean (69 keys put back)" while a material it never tracked
stayed behind (37 where the model had 36), and one wrote `sky_multiplier = 0.0`, read it back as
`0.0`, and changed nothing at all (**both observed**, `HANDOFF-sunoff.md` §3, §7).

### Lifetime — one clarification worth stating plainly

A ceiling removed at the *end of the press* is a ceiling that does not exist when the render
runs, which defeats its purpose and leaves five visible fixtures hanging in open air.

So: **the ceiling's lifetime is the rig's lifetime, not the press's.** It is created with the rig
and removed by the same thing that removes the rig — the next press's stale sweep, or an explicit
*Remove Lights* action. Benton's drawing is never left altered, because the ceiling leaves exactly
when the lights do, and both are tool-owned and swept by the same code. **If he wants it gone at
the end of the press instead, that is a one-line change** — and the consequences are that the §6
enclosure trims apply and roles 1 and 3 lose their mounting surface. Both paths are specced; the
rig-lifetime one is the recommendation.

### Construction

* The ceiling is **`room_info[:poly]` faced at `z_top`** — the floor polygon at the wall top. No
  new geometry logic, and L-shaped rooms work for free.
* `f.reverse! if f.normal.z > 0` — the lit face points **down** into the room
  (`lookdev-matrix.rb:452` has this right; borrow it).
* **No material is created.** Reuse by name if present, else default.
* **No new tag.** It goes on the existing `WR Lights` tag — a new tag would perturb every scene's
  stored tag state, the exact class of problem §9 Step 2 exists to fix.
* One group, named `WR Lights Ceiling`, stamped `WR_DropLights / kind => 'ceiling'` **plus a
  per-press UUID**. Ownership is by **dictionary**, never by name and never by tag alone — a name
  match is what `lookdev-matrix.rb:463` uses and it will happily miss a renamed group or match a
  user's own.
* Skipped, with a console line saying so, if the room already has a ceiling the tool does not own.

### Removal — verified by independent re-read, never by its own word

1. **Before the press**, record independently: `model.definitions.count`,
   `model.materials.count`, the tag list, and the top-level entity count.
2. Remove by walking for the **dictionary stamp**, recursively, to `SWEEP_MAX_DEPTH` — the same
   world-space walk `collect_lights` already does.
3. **Then re-read the model afresh** and assert, one by one:
   * no entity anywhere carries `WR_DropLights / kind => 'ceiling'`;
   * `model.materials.count` equals the recorded count — **this is the check that catches the
     37th material**;
   * `model.definitions` holds no definition left over from the ceiling group;
   * the recorded tag list is unchanged.
4. **If any assertion fails: refuse by name.** Print which check failed, the entity's name and
   persistent id, and what to delete by hand. **Do not print a success line.** A restore that
   cannot fail is not a check — the lesson the read-back taught in 1.9.1, applied here identically.
5. **Never `model.save`.** Never touch anything outside the tool's own dictionary.

---

## 9. Steps

Ordered. Steps 1 and 2 are **gates** — do not proceed past a failing one; report instead.

**Step 1 — settle the lumen unit. GATE.**
Files: `scripts/lookdev-matrix.rb` (reuse `frame!` and `assert_lights_visible!`), new
`scripts/units-probe.py` (dev harness, **not** plugin code).
Capped box, sun off, EV 9.23, six 400×225 thumbnails (~13 s each, **observed** mean 12.86 s):
* **(a) Is `units = 1` really lumens?** A 12"×12" and a 24"×24" light at the same intensity. In
  `Luminous Power (Lumens)` they must render **the same**; if the 24" is 4× brighter, the write
  did not take and the enum is not what the Asset Editor bundle says.
* **(b) Does the colour multiply the lumens?** A 2700 K and a 6500 K light at the same lumens. If
  the warm one is dimmer, revision 1's `Y` division stays in the formula.
* **(c) Absolute check.** One 2,000 lm light in the reference room at EV 9.23 — does it land near
  the design illuminance?
**If (a) fails, stop and report.** The fallback is fully specced: revision 1's scalar column, in
this file's git history.

**Step 2 — the two silent preconditions. GATE.**
File: `scripts/wr-drop-lights.rb`.
* **(a) Ceiling and wall-count detection** in `room_info`: a horizontal face at or above `z_top`
  spanning the floor polygon, plus a count of wall runs. Print `capped / open, N walls` **by
  name**. Drives §8 and the §6 trims.
* **(b) Stamp the tag into every scene.** `WR Lights` read **`false` on the live model as found**
  (**observed**, twice). A hidden tag means V-Ray renders none of this. The tool already forces
  the tag visible for the session; it must additionally write that visibility into **every
  `model.pages` entry**, because scenes are captured with `use_hidden_layers = true` and re-apply
  their own stored copy on activation (**observed**, `proposal-scenes.rb:221,223`). Auditor
  finding **C1**, ranked top, and the mechanism behind "same model, some frames lit, some black".
  No rig design survives it.

**Step 3 — the fixtures, and their absorption.**
Files: new fixture section in `scripts/wr-drop-lights.rb` (or a `scripts/wr_tools/` module),
`scripts/rbtest-lights.py`.
Build **F1 first**, then F2, F3, F4 as budget allows. Pure geometry maths — segment points, cone
loft, shell offsets — goes in the **pure section** so `rbtest-lights.py` runs it outside SketchUp,
exactly as the placement maths does today.
Then **measure shade absorption**: one thumbnail pair per fixture, emitter with and without its
shade, and put the factor in the fixture table as a constant. **Do not skip this and do not guess
it** — §7.4 establishes that no published lamp-shade transmittance figure exists, so a render is
the only source.

**Step 4 — the layer rewrite.**
Files: `scripts/wr-drop-lights.rb`, `scripts/rbtest-lights.py`, `scripts/wr_tools/VERSION` (bump),
`DEVLOG.md`.
* `LIGHT_LAYERS` grows from 4 entries to 7 and gains `:kelvin`, `:lumens`, `:budget`
  (`:room` / `:booth`), `:visible`, `:fixture`, `:tilt`, `:standoff`, `:n`, `:emitter`.
* `scalar_intensity` is **replaced** by a per-layer lumen figure; `UNITS_SCALAR` becomes
  `UNITS_LUMENS = 1.0`; **`REF_INTENSITY`, `REF_AREA`, `REF_LUMENS` and `AREA_NORMALIZED` are all
  deleted** — four constants and the weakest link in the file going away together.
* `configure_light` writes `invisible` from the layer spec instead of a constant, and writes
  `is_disc` for F1 with a read-back that refuses by name if it will not take.
* The exposure stamp of §4, with all five of its guards.
* Placement: ceiling ambient uses `grid_points` **capped at 2**; sconces use `wash_points` at 66"
  AFF; pendant takes the floor-polygon corner furthest from the booth; key reuses the existing
  accent placement verbatim; rim mirrors the key about the booth centre with a 60° tilt; foam
  graze offsets 4" inside the booth's foam wall at the tray plane.
* **Delete the exposure question from `ask` and the entire `if opts[:exposure]` advice block at
  `:1602`.** Rewrite the header's UNITS section per §4-5 and the "exposure is 30-60× more
  important" comment above `print_light_report` — both are now wrong and would mislead the next
  reader.
* Add a `NEVER_WRITE` list — `/SettingsOutput`, `/SunLight`, `/SettingsEnvironment`, and every
  `/CameraPhysical` key **except `ISO`** — with the reason at the site, the way
  `lookdev-matrix.rb` does.
* Dialog becomes **two dropdowns**: `Brightness` (Dim / Normal / Bright) and `Warmth`
  (Warm / Neutral), where Warmth is a **global Kelvin offset** — Warm = the table as written,
  Neutral = every layer +500 K. It *shifts* the palette; it never flattens it.
* `rbtest-lights.py` gains checks for: the lumen totals per budget, the enclosure trims, exactly
  five visible layers, at least five distinct Kelvins, the fixture geometry maths, and the ceiling
  polygon derivation.

**Step 5 — measure the rig at the new exposure.**
Files: `scripts/lookdev-matrix.rb`, new `scripts/rig-drive.py`, `.forge/builder/rig-results.json`.
Fixed **EV 9.23**, sun off: 6 rooms (the `sunoff` enclosure axis) × 2 cameras × 3 brightness
settings = **36 frames, ~8 minutes**. Assert per frame, *before* rendering, that the `WR Lights`
tag is visible and the instance count is 9 — `assert_lights_visible!` exists and has already
caught one null experiment. Then a **fixture ladder**: roles 1, 3 and 4 at 5 lumen values × 1
camera, for Benton to pick the visible fixtures' brightness from.

**Step 6 — contact sheet, then hand off. Benton picks; no agent picks the look.**

## 10. Acceptance criteria — every one runnable

| # | Criterion | How |
|---|---|---|
| 1 | `python scripts/rbparse.py` clean; `python scripts/rbtest-lights.py` all checks pass, new ones included | offline, real CRuby 3.2 |
| 2 | A press in a 16'×12' room containing a booth places **exactly 9 light instances and 9 live V-Ray plugins**; presses 2 and 3 leave it at 9 with `0 left behind` | bridge job: count instances, `scene.grep` |
| 3 | All 9 plugins read back `units = 1`, and their lumen values match the §6 table | read back per plugin |
| 4 | The nine plugins carry **≥ 5 distinct `color` values** | read back. A single-hue rig fails outright |
| 5 | **Exactly five** plugins have `invisible = 0`, and each sits inside a fixture group carrying the `WR_DropLights` dictionary | read back + walk the dictionary |
| 6 | Zero `DID NOT STICK` lines, and every read-back happens **outside** the `scene.change` block | console + code review |
| 7 | **`/CameraPhysical` ISO is written once and only once**; `f_number` and `shutter` read back **unchanged**; a second press writes nothing and says so; a model whose ISO is not 100 is left alone and reported | snapshot before/after across two presses |
| 8 | `/SettingsOutput`, `/SunLight`, `/SettingsEnvironment` read back **unchanged, key by key** | the `HANDOFF-sunoff.md` §7 method |
| 9 | **THE CEILING RESTORE.** Independent probe *before* the press records `definitions.count`, `materials.count`, the tag list and the top-level entity count. Press → remove → **re-run the same probe from scratch**. Every number matches exactly, and a recursive walk finds **no** entity carrying `WR_DropLights / kind => 'ceiling'`. A deliberate negative test — erase the ceiling group by hand, then run removal — must **refuse by name and print no success line** | bridge job, and it must not trust the tool's own capture. This is the check that would have caught 37-vs-36 |
| 10 | **Sun disabled, EV 9.23, `w4-ceil`:** both cameras PASS `image-qa`'s render profile (mean 0.12-0.75, clipping < 40%) at Brightness = Normal | Step 5 |
| 11 | The same holds in `w4-open`, `w3-open` and `w3-ceil` at Normal — **one exposure serves every enclosure**. If it does not, the §6 trims are wrong: state that with the numbers, do **not** patch it with a per-scene EV | Step 5 |
| 12 | The five visible fixtures are **identifiable as fixtures** in the exterior frame and none is clipped to white | Benton's eye on the ladder — **a judgement, and labelled as such** |
| 13 | The foam reads as relief: the interior frame shows self-shadowing across the pyramid field | Benton's eye, against `FOAM_interior-800x450_booth16x_ev14.png` as the "before" |
| 14 | After a press, **every** `model.pages` entry stores `WR Lights` visible | loop the pages and read |
| 15 | Total faces added by fixtures **< 600**; `model.materials.count` **unchanged** by the whole press | console assertion |

## 11. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| **The ceiling is not removed, and Benton's drawing is silently altered** | **highest** | §8's verified removal; criterion 9 including its negative test. Two restores have already lied today; this one must fail loudly or not at all |
| **`units = 1` is not lumens on this build** — the enum is read from the Asset Editor bundle, not from a render | high | Step 1 is a gate. Revision 1's scalar column is the fallback, in git history |
| **Shade absorption is unmeasured, and no published figure exists** (§7.4) — a sconce in an opaque cylinder may deliver a fraction of its 600 lm | **high** | Step 3 measures it per fixture and it becomes a constant. It is the largest unknown in the lumen column and must not be guessed |
| **F2 and F4 shades render opaque** where the real object glows | medium | Named as a known limitation in §7.3. Needs a translucent material, which this tool may not create. F1 and F3 are unaffected |
| The exposure stamp drifts back into per-scene fiddling | medium | Five explicit guards in §4: ISO only, once, only from factory ISO 100, logged with its undo, read back |
| **Scenes re-apply stored tag visibility** and can hide the whole rig | high | Step 2(b). Already produced "same model, some frames lit, some black" |
| The room budget runs 16% under nominal | low | Deliberate and explained in §6; 0.24 stops, inside the ladder's noise |
| The enclosure trims (×0.35 / ×0.25) are **derived, not measured** | medium | Step 5 measures them. Two constants if they miss |
| The lumen budget is linear in floor area and **ignores ceiling height** | medium | **assumed.** Step 5 sweeps an enclosure axis but **not a size axis** — say so rather than imply generality |
| **`image-qa` mean luminance is a crude proxy** in open-roof rooms | medium | Judge open arms by eye. The `w4-ceil` numbers are the trustworthy ones |
| `is_disc` may not be the real plugin key | low | Written, read back, refused by name. F1 falls back to a square emitter behind a ring; every other fixture uses a sphere light and needs no unproven parameter |
| A fixture group intersects the booth or a wall | low | F4 is the only one at floor level and is built last; the existing keep-out test covers it. The pendant hangs at 78" AFF in open floor |
| **Writing a newly created V-Ray *material* plugin hangs SketchUp**, as does `Scene#delete` on a bound material and `show_safe_frames` (**observed**, four force-kills) | high | Do none of those. This rig touches **light** plugins only, proven writable inside `scene.change` |

## 12. Out of scope

* Any change to booth geometry, foam geometry, or the `_HostMaterial` shim on `Color_I06`.
  Converting the host materials to real `VRayMtl` is probably the largest remaining "why does it
  read as cardboard" win (**observed**) — library materials live on `P:`, read only, and it is
  **not this work**. The translucent shade material for F2/F4 belongs to the same question.
* Adding a permanent ceiling to `build-room.rb`. Settled: the lighting tool borrows one instead.
* Writing any V-Ray setting other than the single documented ISO stamp.
* IES, dome, spot, cylinder and mesh lights. The API exposes all of them and `LightIES` takes
  real photometry in lumens (**observed**) — but there is no `.ies` file in this repo, and with
  lumens now in hand the marginal gain is small.
* `TexTemperature` wired into the colour slot. Better physics, later.
* Per-scene anything. One rig, one exposure.
