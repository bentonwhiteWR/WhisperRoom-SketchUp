# Showroom interior lighting — the design grounding and the placement algorithm

Researcher findings, 2026-08-27 (second lighting pass). Read-only outside `.forge/researcher/`.
Supersedes the *placement* half of `interior-lighting-options.md`; the *mechanism* half of that
file (seed component, no V-Ray light API) stands and is the foundation here.

## Question

Benton, superseding what shipped: select a room, press a button, get a pop-up that defaults to
"five or six sources of light," and have the tool place invisible lights "appropriately as you
would expect an interior design … very professional … not too bright, not too dim … almost like
a showroom," with "some settings where we tweak that kind of stuff." What does a professional
interior rig for a small-to-medium room actually look like, and how does it reduce to an
algorithm over `build-room.rb` geometry?

## Answer, short version

A showroom rig is **three layers, not one plane**: (1) an **ambient downlight grid** spaced at
half the ceiling height with half-spacing at the walls, (2) a **wall-wash row** on one feature
wall at ~24" standoff, and (3) an **accent** treatment of the merchandise — which in our renders
is **the booth itself**, lit ~3× brighter than its surround, plus its own small interior light.
The arithmetic that sizes it: target **40 fc** on the floor (retail-sales-floor range is
30–80 fc), total lumens = area × fc ÷ 0.6, split across the grid — for a 12×15 room that is
~12,000 lm over 4–12 fixtures depending on density. Benton's "five or six" is right for the
**soft render-grade density** (4 ambient + 1–2 feature lights); real recessed-can practice for
that room is 9–12 smaller sources — the pop-up's density setting covers both. **Half of "not too
bright, not too dim" is exposure, not lumens**: V-Ray's default EV 14.2 is sunny-day exposure
and makes any physically-plausible artificial interior render near-black; interiors want EV
7–9 or Auto Exposure. Whether the tool can set that (and light intensity/CCT) from Ruby turns
on one probe written at the end — Benton can run it now. The seed-component mechanism is
unchanged, but it becomes **three seed components, one per layer**, because copies share one
light asset: three seeds = three independent brightness sliders for free.

---

## Part 1 — the lighting-design grounding

### 1.1 Layered lighting: why one light reads as "lit by a script"

Practice divides interior light into three layers — **ambient** (uniform general illumination
from ceiling fixtures), **task** (light where work happens), and **accent** (focal light on
features) — and the craft of a "designed" interior is the ratio between them, not any one
fixture ([1000Bulbs — Three Layers of Lighting Design](https://blog.1000bulbs.com/home/the-three-layers-of-lighting-design-explained),
[Lightbulbs Direct — Lighting in Layers](https://blog.lightbulbs-direct.com/lighting-in-layers-ambient-accent-task-lighting/)).
The American Lighting Association's specific, quotable ratio: **accent lighting works when the
focal point is about 3× as bright as its surround** (reported via
[1000Bulbs](https://blog.1000bulbs.com/home/the-three-layers-of-lighting-design-explained),
citing ALA's "Lighting Your Life"). A single centered rectangle light produces exactly the
opposite signature: flat top-down illumination, one hotspot, black walls — walls are what a
camera mostly sees, and unlit vertical surfaces are why a render reads as a cave even when the
floor meets a lux target.

Mapping the layers to our renders (derived):

| Layer | In a real showroom | In our model |
|---|---|---|
| Ambient | recessed downlight grid | grid of small invisible rectangle lights at the ceiling plane |
| Wall wash (accent on architecture) | washers 2–3' off the feature wall | short row of rectangle lights at 24" standoff, one wall |
| Accent on merchandise | adjustable spots at ~3:1 | one angled light on the booth face + one light inside the booth |
| Task | desk/counter fixtures | **skip** — nothing to work at in a proposal render; derived, not sourced |

### 1.2 Downlight spacing — the practitioner arithmetic

Two forms of the same rule circulate; both are sourced:

- **Spacing = ceiling height ÷ 2.** 8' ceiling → 4' on-center; 10' → 5'
  ([Take Three Lighting — Arranging Downlights](https://www.takethreelighting.com/layout-downlights-general.html),
  [Kichler — Downlight Placement Tips](https://www.kichler.com/tips-guides/indoor-lighting-guide/downlight-recessed-placement-tips),
  [Fromlux — Downlight Spacing Guide](https://fromlux.com/downlight-spacing-guide-how-to-perfectly-space-your-led-recessed-lights/)).
  The cones from adjacent fixtures then overlap around waist height — no dark stripes.
- **Spacing = SC × mounting height**, where the fixture's Spacing Criterion runs **0.5–1.5**
  ([Take Three Lighting](https://www.takethreelighting.com/layout-downlights-general.html)).
  "Spacing ≈ ceiling height" is this rule at SC ≈ 1 — the loose end of practice, tolerable for
  wide-beam sources. H/2 is SC 0.5, the uniform/conservative end.

**Walls: keep fixtures 2–3 ft off the wall** — i.e. roughly **half the fixture spacing**
([Take Three Lighting](https://www.takethreelighting.com/layout-downlights-general.html),
[Amicolight — Layout Rules](https://amicolight.com/blogs/news/recessed-lighting-layout-rules-spacing-placement-pattern-guide)).
The clean closed form that produces both rules at once (derived — standard uniform-grid
identity): along an axis of length `L` with spacing `S`,

```
n = max(1, ceil(L / S))          # fixtures on this axis
x_i = L * (2i + 1) / (2n)        # i = 0 .. n-1
```

which centers the grid and automatically leaves `S/2` (half-spacing) at each wall when
`L = n·S`. Worked example, 12' × 15' room, 8' ceiling, S = 4':
`n_x = ceil(12/4) = 3` at 2', 6', 10'; `n_y = ceil(15/4) = 4` at 1.875', 5.625', 9.375',
13.125' → **12 downlights**, every edge gap 1.9–2.0', inside the sourced 2–3' band.

### 1.3 Wall washing — why rooms photograph as "designed"

Vertical illuminance is what a camera sees; washing one wall raises perceived brightness of the
whole room and gives the eye a bright plane to read depth against. Practitioner numbers:

- **Standoff from the wall:** 2–3' for general wall lighting on 8–9' ceilings; 6–18" for a
  tight graze; 12–18" is the wall-*washer* norm
  ([Coohom — Recessed Light Distances](https://www.coohom.com/article/recessed-light-placement-5-smart-distances),
  [SYA Lighting](https://www.syaled.com/news/93/)). An alternative form: standoff = ⅓–½ of
  wall height ([Benwei Lighting](https://www.benweilighting.com/info/how-far-should-wall-washer-lights-be-from-the-95971451.html))
  — for an 8' wall that is 32–48", consistent with the 2–3' figure.
- **Spacing along the wall:** 1.2–1.5× the standoff
  ([Architectural Products — Wall Wash Design](https://www.arch-products.com/architectural-lighting/article/55092740/how-to-design-wall-wash-lighting-tips-for-perfect-vertical-illumination)),
  or simply spacing = standoff ([Take Three Lighting — Wall & Accent](https://www.takethreelighting.com/layout-downlights-wall.html));
  closer = more uniform.

At the sourced numbers a 15' feature wall wants 24" standoff and 30–36" spacing → **5–6
washers on one wall**. That is correct practice and too many parts for our brief; §2.4 trims
it to 3 per wall and says what that costs (derived trade, labelled there).

### 1.4 Intensity — the actual numbers, and which are sourced

**Illuminance target.** IES-derived commercial tables (reported via
[LED Lighting Supply — foot-candle chart](https://www.ledlightingsupply.com/blog/recommended-foot-candle-chart)):
retail sales floors **30–80 fc**; retail stores and merchandise areas **30–50 fc**; open
offices 30–50 fc; residential ambient practice is 10–20 lm/sqft ≈ 10–20 fc
([City Lights SF — lumens per room](https://citylightssf.com/blogs/city-lights-insights/how-many-lumens-for-ceiling-lights),
[Perfect Fit Living — lumens chart](https://perfectfitliving.com/home-decor/lighting/lumens-per-room-chart/)).
1 fc = 1 lm/ft² = 10.76 lux. **Default target: 40 fc (~430 lux)** — mid retail band, ~2–3×
living-room ambient, which is exactly the "showroom, not living room" brief (derived choice
from sourced bands).

**From target to fixture lumens** (derived; the CU is assumed):

```
total_lumens = floor_area_sqft × target_fc ÷ CU
per_fixture  = total_lumens ÷ n_ambient_fixtures
```

`CU` (coefficient of utilization — fraction of emitted lumens that arrives on the floor after
inter-reflection and spill) is **assumed 0.6**, a middling value for a light-walled room; real
CU tables are fixture-specific and we have no fixture. Worked, 12×15 = 180 sqft @ 40 fc:
`180 × 40 / 0.6 = 12,000 lm`. Sanity checks against real hardware (reported, common product
specs): 12 fixtures → 1,000 lm each ≈ a 6" LED retrofit can (800–1,200 lm) — matches can
practice; 4 fixtures → 3,000 lm each ≈ a small LED troffer — matches soft-density practice.
The arithmetic lands on real products from both directions, which is the sanity check that it
is not invented.

**Map to V-Ray:** set the rectangle light's Units to **Luminous Power (lm)** — Chaos'
documentation states this is total emitted lumens and "the intensity of the light will not
depend on its size" ([Chaos docs — Rectangle Light](https://docs.chaos.com/display/VSKETCHUP/Rectangle+Light)),
so the physical numbers above transfer directly and the seed's drawn size is a free choice.
The default scalar-units intensity does depend on size and maps to nothing physical — do not
use it. (The docs page is JS-rendered and would not fetch here; the Lumens/Watts/Radiance
unit descriptions were confirmed via its search excerpt — reported.)

**The exposure half — this is likely why renders were dark all along.** V-Ray's default
physical-camera exposure is **EV 14.2** — full-sun exterior; interior work wants **EV 7–9**
(reported: [Educk — V-Ray settings explained](https://educk.org/the-best-render-settings-explained-v-ray-for-sketchup/),
[Archgyan — V-Ray for SketchUp guide](https://archgyan.com/v-ray-for-sketchup-complete-beginners-guide/)).
Each EV step is a factor of 2, so a correctly-lit 430-lux interior rendered at EV 14.2 is
underexposed by roughly 5–6 stops — 30–60× too dark (derived). **No lumen value we place can
fix a wrong exposure without becoming physically absurd**, and physically absurd values then
blow out the next render that has a window or an open top. V-Ray Next+ also offers Auto
Exposure (reported, [Chaos video](https://www.youtube.com/watch?v=BHQyjedb1OQ)). What the tool
should do about it: see §3.2 — it turns on the writability probe.

### 1.5 Colour temperature

Sourced guidance: 4000K is the neutral general-retail default; **3000K is the boutique /
luxury-showroom choice** and warm 2700–3000K light makes shoppers linger and read products as
higher quality; warm surfaces (wood, earth tones) pair with 3000–3500K, cool surfaces (white,
gray, steel) with 4000–5000K
([Westgate — retail lighting guide](https://www.westgatemfg.com/blog/solutions/best-led-lighting-for-retail-stores),
[Jarvis Lighting — CCT guide](https://www.jarvislighting.com/blogs/jarvis-lighting-insights/color-temperature-cct-guide-commercial-lighting),
[Armor Lighting — retail CCT/CRI](https://www.armorlighting.com/color-temperature-cri-retail-lighting-buying-decisions/)).

**Default: 3000K, one value for every layer including the booth interior.** Our rooms are
LightSteelBlue-walled (cool-leaning, which argues 3500K), but the render goal is "showroom
that sells," and warm-inviting is the sourced retail play — 3000K, with 3500K as the one
alternative worth offering (derived choice from sourced guidance). Do **not** default the
booth interior to a different Kelvin: mixed whites in one frame read as an error, not a
design, and the booth window makes both visible at once (derived; standard practice is
consistent CCT within a visual field — [Jarvis](https://www.jarvislighting.com/blogs/jarvis-lighting-insights/color-temperature-cct-guide-commercial-lighting)).
CCT is baked into the seed asset at authoring time unless the probe proves it writable (§3.2).

### 1.6 "Five or six" — checked against practice

For a 12×15 room, can-practice (S = H/2) says **12** small sources (§1.2), not five.
Benton's number is not wrong — it is the count for the *other* end of the sourced SC range
(S ≈ H, wide soft sources): `n_x = ceil(12/8) = 2`, `n_y = ceil(15/8) = 2` → **4 ambient**,
plus wall wash and booth accent → **6–8 total**. Renders favor that end: fewer, larger area
lights give softer shadows and no ceiling full of hotspots, and V-Ray area lights have no
per-fixture lumen ceiling the way real cans do (derived). **So: derive the count from area and
ceiling height, never fix it** — expose the choice as one Density setting:

- **Soft (default): S = ceiling height** → 12×15 gives 4 + extras ≈ Benton's five-six.
- **Showroom grid: S = ceiling height ÷ 2** → 12×15 gives 12; the full can-practice look
  with a visible rhythm of pools on the walls.

Both settings are points on the same sourced SC 0.5–1.5 rule, not two theories.

---

## Part 2 — the algorithm over our geometry

### 2.1 What is queryable (all observed in `scripts/build-room.rb`)

- The room is one top-level group named from the dialog (`build-room.rb:382-383`), containing
  subgroups **`Floor`** (tag `WR-Floor`, a single face drawn from the measured interior
  polygon at z=0, `build-room.rb:386-393`), **`Walls`** (tag `WR-Room`, per-run solids from
  z=0 to `ceil`, upper bands on `WR-Room-Upper` split at the 48" default sill,
  `build-room.rb:395-400`), and **`Doors`** (tag `WR-Doors`, openings + leaf + swing).
- **There is no ceiling slab — every build-room room is open-top** (observed: nothing is
  built above the wall solids; the file's own header describes hiding `WR-Room-Upper` to
  "lower the walls"). The mount plane must be synthesized.
- The floor polygon is **arbitrary rectilinear** (the dialog take-off is a run list, N/S/E/W;
  `polygon()` at `build-room.rb:137-151`) — L-shapes are first-class, so bounding-box
  placement is wrong for them.
- Ceiling height = the wall solids' top. Robust query: the `Walls` subgroup's bounds max z in
  room coordinates (works even with `WR-Room-Upper` hidden — hidden geometry still bounds).
- Booths are separate groups/components sitting inside the room, built by the booth scripts;
  exterior height ~7'0" (reported, CLAUDE.md: a 96120 E measures 7'-0 5/16").

### 2.2 Inputs, resolved per selected room

1. **Floor polygon** `P`, world XY: find the child group tagged `WR-Floor` (fall back to name
   `Floor`), take its largest face's outer loop, transform to world. **If absent** (a booth,
   a hand-drawn group, an imported model): fall back to the group's bounding-box rectangle
   and say so on the console by name — the bbox is correct for every rectangular thing and
   the loud line keeps the fallback from being silent.
2. **Floor z** `z0` = that face's plane (0 in room coords).
3. **Ceiling plane** `z_top` = max z of the wall solids (or the group bounds top on the
   fallback path). **Mount plane `z_m = z_top − DROP`, DROP = 6"** (carried over from
   `wr-drop-lights.rb`; assumed, one constant). Open-top is the *normal* case, not an edge
   case: the lights simply hang at the plane where the ceiling would be. Sun/environment
   light will also enter from above in a render — acceptable; it reads as skylight and the
   rig still controls the walls and floor (derived, unverified in a render).
4. **Effective height** `H = z_top − z0` — drives spacing.
5. **Obstructions**: every other group/component instance whose bbox XY-footprint intersects
   `P` and whose top rises above `z_m − 18"` (i.e. anything the light plane would sit on or
   inside — a booth, tall cabinetry). Inflate each footprint by 12". Keep-out set `K`.
   A ~7' booth under an 8' ceiling is caught by this rule (7'0" > 7'6" − 18" = 6'0").

### 2.3 Layer A — ambient grid

```
S   = density == :showroom ? H / 2.0 : H          # sourced SC 0.5 / SC 1.0, §1.2
over the polygon's bbox (Lx × Ly):
  n_x = max(1, (Lx / S).ceil);  n_y = max(1, (Ly / S).ceil)
  candidate points: (x_i, y_j) by the centered formula of §1.2
keep a candidate iff:
  Geom.point_in_polygon_2D(pt, P, true)           # real SketchUp API — inside the floor
  distance from pt to every polygon edge >= min(S / 2, 36") and >= 18"
  pt not inside any keep-out footprint in K
if the keep-out test empties an axis row entirely, leave it empty — do not re-flow;
if EVERYTHING is culled (tiny room): one light at the polygon centroid
  (centroid, not bbox center — an L's bbox center can be outside the floor).
each survivor: one instance of the Downlight seed at (x, y, z_m), facing −Z.
```

The edge-distance test is what makes L-shapes right: a bbox grid point in the notch of an L
fails `point_in_polygon_2D` and is dropped; a point inside but hugging the notch wall fails
the edge distance. No special L case exists — the polygon tests *are* the L handling
(derived). Very small rooms (min span < S): the formula already yields n=1 on that axis;
below ~4' span the single-centroid clause takes over.

**Lumens for the layer** (derived, §1.4): `total = area(P)_sqft × 40 ÷ 0.6`, per-fixture =
total ÷ count. At Soft density in 12×15 that is 3,000 lm each; at Showroom, 1,000 lm each.
Whether the tool can *set* this per press is the §3.2 probe; if it cannot, the seeds are
authored at 3,000 lm (Soft is the default) and Showroom density overshoots by ~3× until the
one Asset Editor slider is nudged — the console must print the target number to nudge to.

### 2.4 Layer B — wall wash (optional, default: one feature wall)

Full practice (5–6 washers per wall, §1.3) triples the part count for a benefit the camera
only sees on walls it faces. Trim, labelled as the derived trade it is: **wash one wall — the
wall opposite the largest door** (the wall a person entering sees first; derived default,
cheap to re-aim), with:

```
standoff = 24" into the room from the wall face      # sourced 2–3' band, low end
n_w      = max(2, (wall_len / (1.5 * standoff)).ceil).clamp(2, 4)
positions: centered formula along the wall run, at z_m, facing -Z
```

2–4 washers at 36" spacing is coarser than the sourced 30–36"-uniform ideal — the wash will
scallop slightly. Acceptable at render scale; the setting to change it is the layer toggle,
not a spacing knob. Washer lumens: half a downlight (assumed; vertical surfaces need less to
read bright because the camera views them straight-on).

### 2.5 Layer C — the booth is the merchandise

When an obstruction in `K` is a WhisperRoom booth (recognize by definition/instance name
against the booth scripts' naming; anything unrecognized just stays a keep-out):

- **Accent**: one rectangle light at `z_m`, positioned 3–4' out from the booth's door face,
  **tilted 35° from vertical toward the booth face** (the classic accent aiming angle —
  reported as the museum/gallery "30-degree rule" family; the exact tilt is assumed within
  it), lumens ≈ 2× a downlight so the face meets the ALA ~3:1 focal ratio against ambient
  (sourced ratio §1.1, fixture math derived).
- **Interior**: one Booth seed instance at booth bbox top − 6", centered — the original
  `wr-drop-lights.rb` behaviour scoped down to booths, ~1,000 lm (derived: booth floor
  ~24 sqft × 30 fc ÷ 0.6 ≈ 1,200 lm).

### 2.6 Idempotence, tagging, containment

Carry over from `wr-drop-lights.rb` unchanged (observed working design, unrun live): one
`start_operation`; instances in `model.active_entities`, never inside the client's room
group; tag `WR Lights`; a `WR_DropLights` attribute per instance — extend it with a
`role` key (`downlight` / `wallwash` / `accent` / `booth`) so a re-press can replace
per-room, and the console can count per layer. Re-press = delete prior instances whose
origin falls in the selected rooms' bounds, then re-place.

---

## Part 3 — mechanism: seeds, settings, and the two probes

### 3.1 Seed components to author (Benton; exact specs)

Copies of one component share one V-Ray light asset — one slider moves every copy (reported,
community-confirmed in `interior-lighting-options.md`). That is why the rig needs **one seed
per layer**: three seeds = three independent brightness sliders in the Asset Editor with zero
UI built by us. All in `scripts/vray-seeds/`, each drawn **at the component origin, emitting
face down (−Z)**, Units = **Luminous Power (lm)**, colour mode Temperature = **3000K**,
**Invisible = ON** (the fixture must never appear as a gray slab in the render):

| File | V-Ray type | Drawn size | Lumens | Role |
|---|---|---|---|---|
| `WR Light Downlight.skp` | Rectangle Light | 12" × 12" | 3,000 | ambient grid |
| `WR Light Wallwash.skp` | Rectangle Light | 6" × 24" (long side along the wall) | 1,500 | feature wall |
| `WR Light Booth.skp` | Rectangle Light | 12" × 24" | 1,000 | booth interior |
| `WR Light Accent.skp` *(optional, can wait)* | Rectangle Light, Directionality ≈ 0.5 | 12" × 12" | 6,000 | booth face accent |

The already-specified `WR Interior Light.skp` (24×48 troffer): if Benton has authored it, it
maps onto the Booth role and can simply be re-saved under the new name with the size/lumen
tweak; if not, skip it — these four supersede it. The tool refuses **by name, per missing
seed**, and only for the layers actually requested — a run with wall wash off must not demand
the wallwash seed (GOAL rule: refuse loudly, never fake).

### 3.2 What the pop-up controls, what is just right, and the probe that decides

**Settings that belong in the pop-up (four, plus one checkbox):**

1. **Density** — Soft (default) / Showroom grid (§1.6).
2. **Brightness** — Dim / Normal / Bright (0.5× / 1× / 2× the lumen targets).
3. **Warmth** — 3000K (default) / 3500K.
4. **Layers** — wall wash on/off (+ which wall, default auto), booth accent on/off.
5. **"Set interior exposure"** checkbox, default ON — see below.

**Just right, no knob:** spacing rule and wall clearances, drop below ceiling, keep-out
inflation, lumen arithmetic and the 3:1 accent ratio, CCT consistency across layers,
invisibility, tagging/idempotence. A knob per constant is the lighting console Benton said
he does not want; the console printout carries the numbers for anyone who cares.

**The catch, stated plainly: settings 2 and 3 are only real if Ruby can write light
parameters.** Placement (1, 4) is pure SketchUp and always works. Brightness and Warmth live
on the shared V-Ray light asset; without a write path the pop-up can honestly offer them only
as "printed advice + three Asset Editor sliders." Today's live probe changes the odds: the
scene surface (`grep`/`fetch`/`change`) is reachable cold (observed today), and the
`/Settings*` + `/CameraPhysical` plugins exist cold — which means render *settings* live as
writable-looking plugins even before any export. Whether **lights** appear there too, and
whether a `scene.change` write survives the next model re-export (the wipe risk named in
`interior-lighting-options.md`), is exactly one probe away. **This is the fork that decides
the dialog design, so: run the probe below before the Scoper commits the pop-up.**

**Exposure (checkbox 5).** §1.4: at default EV 14.2 the rig cannot look right at any sane
lumen value. Three paths, in preference order: (a) probe proves `/CameraPhysical` writable →
the checkbox sets interior EV ≈ 8 (and the console says so loudly, since it is a global
render setting, not per-room); (b) not writable → the checkbox becomes a printed instruction
("Asset Editor → Camera → Exposure Value 8, or enable Auto Exposure") and the tool still
ships; (c) leave exposure alone entirely — rejected, because it silently guarantees the
"too dim" complaint recurs and gets mis-blamed on the lights. Do **not** touch
`/SettingsColorMapping` — exposure is the physically-meaningful lever and the camera is where
photographers set it; color mapping curves are Asset Editor territory (derived judgment).

### 3.3 The probe — ready to paste (Benton, ~3 minutes)

Run in a model that contains **one hand-made V-Ray rectangle light**. Run it cold, then
after one quick render, then render once more — the three runs answer: do lights surface as
scene plugins before/after export, are their parameters readable, does a write take, and
does the write **survive the next export** (the wipe question).

```ruby
ctx = VRay::Context.active
sc  = ctx ? ctx.scene : nil
if sc.nil?
  puts "no V-Ray context"
else
  lights = sc.grep(/light/i)
  puts "plugins matching /light/i: #{lights.size}"
  lights.each { |p| puts "  #{p.name}" }
  lp = lights.first
  if lp
    [:intensity, :intensity_tex, :units, :color, :color_mode, :temperature,
     :enabled, :invisible, :multiplier, :power].each do |k|
      begin
        puts "  #{k} = #{lp[k].inspect}"
      rescue StandardError => e
        puts "  #{k}: #{e.class}: #{e.message}"
      end
    end
    begin
      sc.change { lp[:intensity] = 60.0 }
      puts "WRITE OK — intensity reads back #{lp[:intensity].inspect}"
    rescue StandardError => e
      puts "WRITE FAILED: #{e.class}: #{e.message}"
    end
  end
  cam = sc['/CameraPhysical'] rescue nil
  if cam
    [:exposure_value, :exposure, :ISO, :f_number, :shutter_speed].each do |k|
      begin
        puts "  camera #{k} = #{cam[k].inspect}"
      rescue StandardError => e
        puts "  camera #{k}: #{e.class}: #{e.message}"
      end
    end
  else
    puts "no /CameraPhysical plugin fetched"
  end
end
```

Reading the results: **zero light plugins cold but some after a render** → the scene mirrors
the model only at export, writes will be wiped, Brightness/Warmth become Asset Editor advice
(path b). **Lights present cold and the intensity write survives a subsequent render** → the
pop-up's sliders are real (path a). **Parameter keys erroring** → the key names differ from
the `.vrscene` convention guessed here; `sc.dump` (method observed to exist) or
`lp.methods.sort` in the console will show the real surface — paste whatever it prints.
(The key names in this probe are **assumed** from V-Ray's `.vrscene` LightRectangle
parameter names; the probe is designed so a wrong guess prints an error line instead of
lying.)

### 3.4 Failure cases the Builder must handle by name

- **Missing seed** for a requested layer → refuse naming the file and the authoring steps
  (§3.1); other layers still place.
- **No `WR-Floor` child** in a selected group → bbox-rectangle fallback with a loud console
  line naming the group (§2.2). Not a refusal — booths and legacy rooms are legitimate.
- **Floor polygon found but degenerate** (face missing, zero area) → refuse for that group,
  by name.
- **Everything culled by keep-outs / tiny room** → one light at the polygon centroid, said
  on the console.
- **No booth recognized** → accent + booth layers silently have nothing to do; console says
  "no booth found in <room>" once so a mis-named booth is discoverable.
- **Selection empty / only loose geometry** → the existing `wr-drop-lights.rb` message
  pattern (observed) carries over.
- **Open-top room** → normal case, no message; the rig plane is synthesized (§2.2.3).

### 3.5 Professional vs minimalistic — do they conflict here?

Not fatally, and the resolution is the one already in motion: **professional lives in the
defaults (layers, spacing arithmetic, 3:1 ratio, 3000K, exposure), minimal lives in the
surface (one button, one pop-up, four settings + one checkbox).** The one genuine casualty
is per-fixture tweakability — a real lighting designer would never accept three shared
sliders for a whole model — but every instance remains an ordinary component: Move tool,
eraser, copy. SketchUp stays the fine-tuning UI, exactly the stance the shipped tool's
header already takes (observed). If the probe lands on path (b), the pop-up loses its two
prettiest controls and honesty beats decoration: show the printed targets rather than
sliders that do nothing.

## Confidence and gaps

- **Sourced:** the layer model and the 3:1 accent ratio; H/2 and SC-range spacing rules;
  2–3' wall clearance; wall-wash standoff and spacing bands; retail 30–80 fc / merchandise
  30–50 fc; lumens-unit size-independence in V-Ray; EV 14.2 default and EV 7–9 interior
  practice; retail CCT guidance. All web-reported from practitioner/vendor sources — none
  is the IES handbook itself, which is paywalled; the retail fc band appears consistently
  across three independent tables.
- **Derived:** the centered-grid formula; the 12,000 lm worked example; count-vs-density
  reconciliation of "five or six"; L-shape handling falling out of polygon tests; the
  underexposure factor at EV 14.2.
- **Assumed, each one constant:** CU = 0.6; DROP = 6"; keep-out inflation 12" and the
  −18" top rule; washer = ½ downlight lumens; accent tilt 35°; 24" washer standoff (low end
  of the sourced band); the probe's parameter key names.
- **Weakest links:** (1) no render has been seen — every V-Ray behavioural claim including
  the wipe risk is reported; (2) whether Brightness/Warmth/exposure are scriptable is
  undetermined until the §3.3 probe runs — the dialog design forks on it; (3) booth
  recognition by name is unspecified against the actual booth scripts' naming and needs a
  Builder to pin the match rule.
