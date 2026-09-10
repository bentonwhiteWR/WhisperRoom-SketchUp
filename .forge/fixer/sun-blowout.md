# Blow-out after "Drop the interior lights" — sun AND the booth's own light

Fixer notes, 10 Sep 2026. Diagnosis only. **Nothing under `scripts/` was changed** and no
lighting default, exposure stamp or sun value was touched. Nothing here was proven by
execution: there is no `ruby.exe` on this machine and SketchUp / V-Ray cannot be driven
from here. Every claim is labelled **observed** (read or computed from files in this repo
and its recorded results), **derived** (arithmetic on observed numbers, shown),
**reported** (a doc or a prior agent) or **assumed** (needed, not checked).

Benton, 10 Sep 2026:

> "Still have some crazy lighting issues whenever we 'drop in lights'. I need to confirm
> if this is on a new model before any of our scripts, but the sun at level 1 just totally
> blows out everything. I have to set it to 0.05 or lower generally speaking."

> "so regarding the lights, it also blows out our 'internal' light that we added into the
> whisperrooms when they are loaded in from the booth builder link. Will this continue to
> be blown out?"

---

## The answer, plainly

**Yes — it will keep happening on every fresh model, by design, until one of three things
changes, and it is one cause, not two.** The first press of *Drop the interior lights* in
any model whose V-Ray camera is still at the factory ISO 100 writes ISO 3200. That is a
camera-level gain of five stops (32x) that applies to *everything* that emits light in the
frame — the sun, the sky, the `BoothLighting.skp` light inside every link-built booth,
and the rig's own fixtures alike. The rig's fixtures were calibrated *for* that camera
(ISO 3200 is what makes their lumen figures mean anything), so they look right. The sun
and the booth light were authored at the factory camera, so they now read five stops hot.
Sun 1.0 → ~0.031 is exactly five stops; Benton lands at "0.05 or lower" by eye.

It is not a guard failing. The stamp fires once per model, only from ISO 100, records
itself, reads back, and never touches `/SunLight` — all as documented. The gap is that the
*consequence* for everything else in the model was never carried through: the record
already contained the blow-out (see Evidence 2) and the rig's own hand-off marked "the sun
contributes little" as **assumed, never A/B'd**.

The three ways it stops:

| | What changes | What it costs |
|---|---|---|
| A | The tool keeps stamping ISO 3200 and **tells him at press time** (a message, not a write) that `/SunLight` and any pre-existing V-Ray light now need ~1/32 of their factory intensity, with the two Asset Editor paths | Nothing in the render moves; he still turns two knobs per model, but he is told which and by how much |
| B | `BoothLighting.skp` is re-authored once by Benton at 1/32 of its current intensity (or in lumens), so link-built booths arrive tuned for EV 9.23 | One component edit in the parts library; the sun still needs its knob |
| C | The stamp is removed and the rig is re-tuned for ISO 100 | Reopens the whole 148-frame calibration; **not recommended** and not mine to do |

Ranked options with trade-offs are at the end. **Changing nothing** stays on the list and
is what this note does.

---

## What was checked, against the hand-over list

### 1. Is the ISO stamp reached on every press? Is it opt-in anywhere?

**Observed** (`scripts/wr-drop-lights.rb`). `run` (line 2767) reaches
`stamp_exposure!(model, scene)` at line 2905 on every press that gets past the selection
check, the settings dialog and the V-Ray API check — it is inside the same
`start_operation` as the light placement and there is no option that skips it. The
settings dialog asks Brightness / Warmth / Add ceiling only; the file says in its own header
(line 128–129): *"The exposure question is gone: exposure is written ONCE as a documented
default, never asked per press."* Not opt-in, not opt-out.

The stamp's guards (lines 1649–1686) hold as written: it returns without writing if there
is no `/CameraPhysical`, if the model dictionary already carries `exposure_stamped`, or if
ISO is not 100 (`param_agrees?(EXPO_FACTORY_ISO, iso_before)`). So **in a fresh model the
first press always writes ISO 3200** — which is exactly the "every new model" pattern.

**The report goes to the Ruby Console only.** `print_exposure_report` is `puts` (line
1688); the only `UI.messagebox` calls in the run path are refusals (lines 2797, 2807, 2825)
and the failure handler (3377). It prints `NEVER WRITTEN: /SettingsOutput, /SunLight, …` and
never says that the sun now needs to come down. If Benton is not reading the console, he
sees no announcement at all.

### 2. Does anything else write sun, sky, GI, exposure or environment multipliers?

**Observed**, every file grepped for `/SunLight`, `intensity_multiplier`,
`/SettingsEnvironment`, `/CameraPhysical`, `ISO`, `gi_`, `sky_`, `exposure`,
`ColorMapping`, `shadow_info`:

| File | Writes | Reaches a normal press? |
|---|---|---|
| `scripts/wr-drop-lights.rb` | `/CameraPhysical[ISO]` only, once | **Yes — every first press** |
| `scripts/lookdev-matrix.rb` (panel: *Look-development matrix (dev)*) | `/SunLight` enabled + `intensity_multiplier`, `/Environment Sky`, all four `/SettingsEnvironment` tex mults, `/CameraPhysical` f/ISO/shutter, light intensities (lines 606–663) | Only inside a sweep, with `capture!` / `restore!`. **But** the DEVLOG records four SketchUp force-kills mid-sweep (§ "sun-off look matrix"); a killed sweep leaves its writes in *that* model unrestored. Not a cause on a new model. |
| `scripts/sunoff-drive.py`, `lookdev-drive.py` | drive the above through the bridge | No |
| `scripts/proposal-package.rb` | `/CameraPhysical` f/ISO/shutter **only when `cfg['overrides']['exposure'\|'ev']` is set** (line 2029, `exposure_override?` 2118) — and it writes `EV_ISO = 100`, restored after the row | No, opt-in, empty by default (1.9.4). Its shading pass ("Light 80 / Dark 45") is SketchUp `shadow_info`, not V-Ray — the dialog text itself says *"V-Ray scenes are never touched by this."* (line 3692) |
| `scripts/wr-sun-aim.rb` | `shadow_info` NorthAngle / latitude only — sun *direction*. Header (line 104): *"This script calls no V-Ray API at all"* | Direction only, never intensity |
| `scripts/wr-shading.rb`, `wr-mode.rb`, `angled-component-art.rb` | `shadow_info` DisplayShadows / UseSunForAllShading / Light / Dark — SketchUp viewport shading | Not V-Ray |
| `scripts/wr-pack-export.rb`, `wr-png-srgb.rb`, `wr-overlays.rb` | nothing in this family | — |
| `scripts/probe-vray.rb`, `probe-vray-color.rb` | read only | — |
| `scripts/build-booth-components.rb`, `booth-from-link.rb` | no `VRay` reference at all (grepped) | — |
| `scripts/vray-seeds/*.skp` | three seed components; HANDOFF-lights-api.md §"dead": *"nothing in the repo reads them"* (grepped again today: confirmed) | No |

**Conclusion: there is exactly one writer on the normal path, and it is the ISO stamp.**
No second writer contradicts it.

### 3. Is the sun on, and is 1.0 V-Ray's own default?

**Observed** in the sweep records, which are live read-backs from Benton's own model as
found on 30 Aug:

- `.forge/builder/HANDOFF-sunoff.md` line 372, as-found table: `/SunLight` **enabled
  true, multiplier 1.0**; `/Environment Sky` `intensity_multiplier` 1.0.
- `.forge/builder/lookdev-results.json`: 64 of 68 frames measured `sun_enabled true,
  sun_mult 1.0, f/8, ISO 100`.
- `.forge/builder/rig-build-results.json` `vray_settings_at_render`: `sun_enabled true,
  sun_intensity 1.0`, ISO 3200 (after the stamp).

So 1.0 is what the model carries before any script runs, and it is the figure V-Ray ships
with (**reported** — Chaos' SunLight default; consistent with every read-back above). The
seeds do not set it (they are never read).

Also in the record and **not** explained: `/Standard Light` at intensity 2500, present and
enabled *with no SketchUp instance* (HANDOFF-lookdev.md lines 63 and 326; HANDOFF-rig-build
line 215 marks its contribution **assumed** nil). It is worth one look in the fresh-model
experiment below, because "blows out everything on a new model" is the one symptom it could
also produce.

### 4. Prior probes of factory values

**Observed.** `probe-vray.rb` / `probe-vray-color.rb` record the plugin *list* and
methods (`reference/vray-ruby-api.md` §"Scene — observed live": 71 plugins cold including
`/CameraPhysical`, `/SettingsColorMapping`), not values. The value evidence is the sweep
JSONs above, plus DEVLOG line 2771: *"Model left exactly as found … camera f/8 @ 1/300
ISO 100, denoiser off, sun on."* Factory camera f/8 @ 1/300 @ ISO 100 = EV 14.23 is
**observed** (DEVLOG 2946 table header, proposal-package.rb line 322 checked the formula
against it).

### 5. The 0.031-vs-0.05 gap

**Derived.** Five stops of ISO gain means the sun that metered correctly at ISO 100 meters
correctly again at 1.0 / 32 = **0.031**. Benton's 0.05 is 0.69 stop above that; "or lower"
brackets it. Candidates, in the order I believe them:

1. **It is a by-eye number, and 0.03–0.05 is inside by-eye.** Two-thirds of a stop is the
   difference between one Asset Editor slider notch and the next. This alone covers it.
2. **The target is not "correctly exposed sun" any more.** At the factory camera the sun
   *was* the lighting. Now the rig is the lighting and the sun is fill; the right value
   is *below* 0.031 — which is the direction "or lower" points.
3. **The sky rides on the same knob** (**reported**, Chaos docs: the Sun's intensity
   multiplier also scales the linked Sky). In the sweep, sun-off/sky-on through the open
   roof alone read 0.231 at EV 12 (HANDOFF-sunoff line 150, **observed**). If the sky did
   *not* follow the sun, a roofless room would still flood at 0.05 — the experiment below
   tests that.
4. Tone mapping / colour mapping and the vignette are at defaults on this rig
   (wr-png-srgb.rb header, **observed** in the record) and are not a candidate.
5. A different starting f-number or shutter in his model would move the whole ladder, not
   the ratio; `stamp_exposure!` reads both back and asserted 8.0 / 300.0 unmoved on the
   live run (DEVLOG 2275). Not it.

Bottom line: the gap is small enough that it does not need a second mechanism, and I am
not claiming one. It is **unexplained beyond "by eye"**.

### 6. What DEVLOG says — the history that must not be undone casually

**Observed**, `DEVLOG.md`:

- 1.9.2 (line ~2941): *"no single EV works for both a room view and a booth interior."*
  Bracketed table: EV 9 room = **BLOWN to white**, EV 12 room = best, at ISO 100 with the
  sun on. *"Disabling `/SunLight` did not rescue the EV 9 room render, so it is the rig,
  not the sky."* (Note: that was the *pre-1.9.9* rig at its old intensities.)
- 1.9.4 (line ~2704): the headline — `WR Lights` was hidden, every prior frame was lit by
  sun and sky alone. proposal-package stops writing `/CameraPhysical`.
- Sun-off sweep (line ~2432): 148 frames. *"The ceiling moves the EXPOSURE, about 1.5
  stops. `w4-ceil` plus the rig as built is the only place in the sweep where the untouched
  rig serves both cameras — at EV 9.5."* That EV 9.5 arm is **sun off**. The EV 9.23
  decision (1.9.9, 30 Aug, commit f80ae5b) is built on it: *"Lumens are for a capped room,
  sun off, EV 9.23"* — it says so at `wr-drop-lights.rb` line 360.
- 1.10.0 (31 Aug, commit 722992c, line 2184): **`LUMEN_GAIN = 10.0`**, set by Benton's eye
  — pendant 750 → 7500, sconce 187.5 → 1870.5 — the day *after* the stamp shipped. See
  "Defects and loose ends" #3.

So the record is consistent: the exposure was chosen for **a capped room with the sun
off**, the rig-build verification (HANDOFF-rig-build, 30 Aug) rendered a capped room with
one door and marked the sun's contribution **assumed**, and the case Benton actually draws
— open-top or 2/3-sided host rooms, sun on — was measured only at ISO 100.

---

## Evidence

1. **Observed** — `scripts/wr-drop-lights.rb` 344–357: `EXPO_ISO = 3200`,
   `EXPO_FACTORY_ISO = 100`, `NEVER_WRITE` includes `/SunLight` "sun is his dressing
   decision". 1649–1686: the five guards as described. 2905: the call, unconditional.
2. **Observed — the blow-out is already in the record.** `.forge/builder/lookdev-results.json`,
   stage 3, rig as found, **sun on at 1.0**, elevation 34.9°, roofless Studio Room,
   exterior camera, image-qa on the frame:

   | camera EV | mean luminance | clipped fraction |
   |---|---|---|
   | 14.0 (≈ factory) | 0.264 | 0.0015 |
   | 12.5 | 0.534 | 0.18 |
   | 11.0 | 0.780 | 0.55 |
   | **9.5** | **0.911** | **0.80** |
   | 8.0 | 0.944 | 0.90 |

   EV 9.23 is 0.27 stop below the 9.5 row. **That row is Benton's symptom, rendered on
   30 Aug**: sun at 1.0 seen through a camera five stops hotter than factory.
3. **Observed** — `rig-build-results.json`: with ISO 3200, sun 1.0, room **capped** with
   one door, the room views metered 0.121 / 0.203 mean, 1.7–2.8% clipped — fine. The only
   difference from row 2 is the roof. HANDOFF-rig-build line 214: *"The sun contributes
   little through the one door — assumed — never A/B'd, because `/SunLight` is on
   `NEVER_WRITE`."*
4. **Derived** — 1.0 / 2^5 = 0.031; Benton's 0.05 = 0.69 stop above; "or lower" brackets.

---

## The second symptom: the booth's internal light

**Where it comes from (observed).** `scripts/build-booth-components.rb` 602–661
`place_booth_lighting`: one instance of **`BoothLighting.skp`** — *"Benton's own
component, dropped into the same parts folder as everything else"*
(`P:/Sketchup/NewMasterComponentList`) — per standard CL ceiling tile, top flush to the
tile's underside, on the `WR Lights` tag. Called at 2574–2582; **default ON when the key is
absent**, and the comment says why: *"booth-from-link.rb builds its own cfg and does not
carry this answer; a missing key must mean 'the usual booth'."* `booth-from-link.rb` 1143
calls `WR_BuildBoothComponents.build_booth`, so every link-built booth carries it (DEVLOG
2174–2178: *"Reached by both doors"*). Neither builder file references `VRay` at all.

**What it is authored at (assumed — cannot be read here).** A `.skp` cannot be opened
from this machine, and no probe in the record has read the plugin inside `BoothLighting.skp`.
What the record does say: Benton's hand-made lights read V-Ray factory defaults
`intensity 30` (scalar units), `invisible false` (DEVLOG 2999, HANDOFF-lights-run line 37,
**observed**), and *"intensity 30 at 24x48 is a correctly-exposed room light — observed
once, by Benton, in one room"* (HANDOFF-lights-api line 40) — i.e. at the factory camera.
If `BoothLighting.skp` was tuned the same way, by eye at ISO 100, it is five stops hot at
ISO 3200, same as the sun. That is the tidy prediction; the experiment below is what tests
it rather than accepting it.

**What drop-lights does with it (observed).** Nothing, and that is two separate facts:

- It never *sees* it. `collect_lights` (1923–1945) only collects entities carrying this
  tool's own `seed` or `role` attribute in `DICT`; `stale_lights` (1952) reaps only those.
  `BoothLighting.skp` instances carry neither, so they are never removed, never re-tuned,
  never counted. The "never lights a light" rule (header line 119) only refuses lights as
  *selection subjects*.
- It **adds its own** 800 lm (x `LUMEN_GAIN` 10 = 8,000 lm-equivalent) interior light
  under the booth's top regardless — role 6, lines 3218–3222 for a booth inside a room,
  2993–3011 for a selected booth. So a link-built booth pressed with drop-lights carries
  **two** interior emitters: Benton's, and the rig's. Both are inside a sealed charcoal box
  that the sweep measured at 0.0173 mean with nothing inside, so the double may look like
  "brighter" rather than "doubled" — but it is a real double and it makes his internal
  light's blow-out worse than the five stops alone.

**Discriminating consequence (derived).** If the ISO stamp is the cause, the booth light is
blown by *the same* 32x as the sun, in the *same* frame in which the rig's own fixtures look
acceptable. If instead the rig's fixtures are *also* blown in that frame, the cause is not
the camera alone — see loose end #3.

---

## Defects and loose ends (reported, not fixed)

None of the five guards fails. These are the things I would call out if asked to change
anything; I have changed none of them.

1. **The stamp's announcement is console-only and silent about its consequence.** The
   design intent — *"a tool that quietly retunes a render setting is indistinguishable from
   a bug in the render"* (line 350) — was applied to what the tool *writes* and not to what
   the write *does to everything it does not write*. This is the gap behind both symptoms.
2. **Double interior light in every link-built booth** after a press (above). Separate from
   exposure; would exist at any ISO.
3. **`LUMEN_GAIN = 10.0` was calibrated against an unknown camera.** Set by eye on 31 Aug
   (commit 722992c), one day after ISO 3200 shipped in 1.9.9 (f80ae5b, 30 Aug). The
   comment at line 739–754 names *"the physical camera's exposure"* as a possible real
   cause and says this is *"the number that goes back to 1.0"* if it is found. Two readings
   are possible and the record cannot separate them:
   - his model was at ISO 3200 when he judged the rig 10x too dim → the rig is genuinely
     dim at EV 9.23 and everything *else* is five stops hot (sun, booth light) — matches
     today's two symptoms exactly;
   - his model was still at ISO 100 (stamp never fired: dictionary already set, or ISO
     hand-reset) → x10 was compensating for 10 of the missing 32x, and on a *fresh* model
     that does get stamped the rig is now 3.3 stops hot **as well as** the sun and booth
     light.
   The experiment below separates these with one reading (the ISO in the model he tuned
   on, if he still has it) and one look (do the rig fixtures clip in the same frame).
4. **`proposal-package.rb`'s "camera as configured is EV x" log ignores ISO.**
   `ev_of_camera(f_number, shutter)` (line 331) and its callers (1719, 2130) compute
   EV100 from f-number and shutter only, so on a stamped model the run log reports
   **EV 14.23** for a camera that is actually at **EV 9.23**. Honest at ISO 100, wrong by
   five stops after any drop-lights press. Cosmetic today (nothing acts on it), misleading
   in an audit.
5. **`lookdev-matrix.rb` writes `/SunLight` and `/CameraPhysical` inside a sweep**, and
   four force-kills are on record. Any model that was open during a killed sweep may carry
   sweep values. Not a cause on a new model; worth knowing if his test model looks odd.
6. `/Standard Light` at intensity 2500 with no instance, *"present and enabled in every new
   V-Ray model"* (HANDOFF-rig-build 215, **assumed** harmless). Never tested.

---

## The experiment — for Benton, in the order that discriminates

Three fresh-model renders and four readings. Each step's outcome says which cause is in
play; stop at the first that settles it. "Asset Editor" = V-Ray Asset Editor, the gear tab
for Settings, the bulb tab for Lights.

**Setup:** new SketchUp model, V-Ray loaded (any V-Ray toolbar button), a plain roofless
box room ~20' x 16' with one wall left out, nothing else. No scripts yet. Asset Editor →
Settings → Camera: expand **Exposure**; note **ISO**, **F-number**, **Shutter speed**.
Lights tab: note the **SunLight** *Intensity Multiplier* and whether it is on; note whether
any other light is listed (the record shows a `/Standard Light` at 2500 in some new
models — if it is there, note it).

| # | Do | Read | If … | … then |
|---|---|---|---|---|
| 0 | Render the empty room, sun at 1.0 | Is it blown? | **Blown** | Not our scripts. Read ISO: if it is not 100 / f/8 / 1/300, V-Ray's defaults on this install have moved (a saved render preset or template), and everything below still applies at that base. If the camera is factory and it is still blown, look at that extra light. |
| | | | Fine (this is the 0.26-mean case in the record) | Our scripts are the only remaining candidate. Go on. |
| 1 | Press *Drop the interior lights* on the room, Normal / Warm / ceiling **No** | Settings → Camera → **ISO** | reads **3200** | The stamp fired (expected). Sun unchanged at 1.0 — confirm on the Lights tab. |
| | | | reads 100 | Stamp did not fire; the blow-out has another cause. Check the Ruby Console for the EXPOSURE block's "nothing written — …" reason. |
| 2 | Render, sun still at 1.0 | Blown? And — **do the rig's own fixtures clip too**, or only the sunlit surfaces? | Sunlit surfaces blown, fixtures look fine | **ISO stamp is the cause; the rig is calibrated to it.** Loose end #3 resolves to the first reading. |
| | | | Everything including the rig fixtures clips | The rig at `LUMEN_GAIN` 10 is *also* hot at 3200 → #3's second reading. Note it; the sun test below still holds. |
| 3 | Set SunLight *Intensity Multiplier* to **0.031**, render | Does the sunlit patch now sit where it did in step 0? | Yes | Five stops, fully explained. Anything below 0.031 is taste ("or lower"). |
| | | | The open roof still floods the room | The sky is **not** following the sun on this build. Then the second knob is Settings → Environment → the GI / Background multipliers (the `/SettingsEnvironment` slots the sweep proved), or a ceiling on the host room. |
| 4 | **Booth link.** Load any booth from the booth-builder link into the same room. Before pressing anything, Lights tab: find the light that came in with the booth (it is inside `BoothLighting`) — note its **Intensity** and its **Units** dropdown | | Intensity ~30 scalar (or anything it looked right at before) | Authored at ISO 100. At 3200 it is the same five stops hot as the sun. **This will continue on every link booth until the component is re-authored or the tool announces it.** |
| 5 | Render the booth interior, no further press, ISO still 3200 | Blown? | Blown | Confirms #4 for the booth light alone — the rig is not even in the booth yet. Try Intensity / 32 (≈ 0.94 if it was 30) and render again: correct → done. |
| 6 | Now press *Drop the interior lights* with the room selected | Lights tab: how many lights are inside the booth? | Two | Loose end #2, the double interior light. Separate defect; the rig's `Booth interior` is the one with a `WR Lights` tag *and* a `WR_DropLights` attribute. |

Step 0 answers his own question ("is this on a new model before any of our scripts") in one
render. Steps 1–3 pin the sun on the stamp. Steps 4–5 answer "will this continue" for the
booth light. Step 6 is the bonus defect.

If he still has the model he tuned `LUMEN_GAIN` on (31 Aug): its Settings → Camera → ISO
reading, and whether the Ruby Console for that press said "already stamped", settles loose
end #3 without a render.

---

## Options, ranked, with the trade-off named

1. **Announce, don't write** — the tool keeps its one stamp, and the press ends with a
   window (not a console line) that says: *ISO is now 3200 (five stops). The V-Ray sun and
   any light that was already in this model will render ~32x hot. Sun: Lights tab →
   SunLight → Intensity Multiplier ≈ 0.03. Booth light: … ≈ Intensity ÷ 32.* Reads back
   `/SunLight` and lists any non-rig light plugins it found, so the numbers are the
   model's own. **Trade-off:** he still turns the knobs, but he is told which and why,
   every time, and `NEVER_WRITE` stays intact. This is the smallest change that fits the
   file's own rule ("loud, with its undo, by name"). It also matches the
   *output-in-a-window* convention in memory.
2. **Re-author `BoothLighting.skp` once** (Benton's component, his parts folder — not
   this repo) at 1/32 of its current intensity or in lumens, so link booths arrive tuned
   for the stamped camera. **Trade-off:** one-time, fixes every future link booth, but
   makes the component wrong for any model that is *not* stamped (a booth rendered on
   its own at ISO 100 would be five stops dark). Pair with #1 so the dependency is said.
   Note the double light (loose end #2) is separate and would still need a decision:
   either the rig skips role 6 when a `WR Lights`-tagged light already sits inside the
   booth, or the builder's light is the one that yields.
3. **Document the number** in `reference/` and the DEVLOG: "after drop-lights, sun ≈ 0.03,
   pre-existing lights ÷ 32." **Trade-off:** zero code risk, zero version bump; but the
   record already contained the blow-out and nobody read it, so on its own this is the
   option most likely to be forgotten.
4. **Offer to set the sun, opt-in** — a checkbox in the press dialog, default off, that
   writes `/SunLight[intensity_multiplier]` to 1/32 of what it reads. **Trade-off:** ends
   the per-model chore for the sun, but it is the first crack in `NEVER_WRITE` ("sun is his
   dressing decision"), it only helps the sun (the booth light is inside a component and
   is his), and it needs the read-back / did-not-stick machinery that the ISO write has
   (the light-plugin write-then-resync trap in DEVLOG 2992–3004 applies to any plugin
   write).
5. **Change nothing.** **Trade-off:** he keeps hand-setting the sun to ~0.05 and the booth
   light on every job, which is the thing he is asking not to do; but every render setting
   remains his and the calibration stays as swept. This is where things are as of this
   note.

Not recommended: **removing the stamp** and re-tuning the rig for ISO 100. It undoes the
sweep-backed decision, moves `LUMEN_GAIN` too, and every lumen figure in the layer table
stops meaning anything.

---

## What I could not check

- Nothing here was executed. No `ruby.exe` outside SketchUp; SketchUp and V-Ray cannot
  be driven from this session. `scripts/rbparse.py` was not run because no Ruby changed.
- The V-Ray light inside `BoothLighting.skp` — its intensity and units — is **assumed**
  from the pattern of Benton's other hand-made lights. Step 4 of the experiment reads it.
- Whether the linked Sky scales with the Sun's multiplier on V-Ray 7 for SketchUp is
  **reported** (Chaos docs), not observed. Step 3 tests it.
- Which camera Benton was at when he set `LUMEN_GAIN` — **unknown**; see loose end #3.
- The WhisperRoomQuote repo was read for the booth-builder link (the memory note and
  `tools/`) and not written. The link path's lighting lives entirely in this repo
  (`build-booth-components.rb`) and in Benton's `P:` parts library.
