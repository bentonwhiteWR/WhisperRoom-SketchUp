# Handoff — look-development matrix + honour-the-settings (plugin 1.9.4)

Builder, 2026-08-30. SketchUp 2026 / V-Ray 7 only, through
`scripts/sketchup-bridge.py --su 2026`. SketchUp 2024 never touched. `P:` and
`WhisperRoomQuote` read only. Nothing written to `Desktop\ProposalFiles\`.
Provenance tagged **observed / derived / reported / assumed** throughout.

---

## Read this first: the render time, because it changes the plan

**Measured, not estimated.** 400x225 at Benton's own Medium quality:

| | seconds |
|---|---|
| thumbnail 400x225, range over 67 frames | **7.06 – 16.64** |
| thumbnail 400x225, mean | **13.60** |
| same frame at 1600x900 | **53.07** |
| speed-up | **~3.9x** |

**The fast loop is real but it is 4x, not 10x.** My first single-frame probe measured
5.07 s and I reported that early; it was misleading and I am correcting it. That probe
rendered a dark frame at V-Ray's default exposure with no artificial lights in the scene.
A representative thumbnail — working exposure, lights on — costs about 13.6 s.

Two caveats that keep the number honest:

- Every thumbnail carries a **0.25 min (15 s) `progressive_maxTime` budget the harness
  imposes**. Benton's own settings leave it at **0.0, which means NO LIMIT**. Several
  frames hit the budget rather than converging, so they are noisier than a final frame.
- The 53.07 s full-size reference was rendered *before* the light rig was discovered
  hidden. A like-for-like 1600x900 with lights on would be slower, so 3.9x is conservative.

Twenty-plus thumbnails still cost less than one full render, so the loop does what it was
meant to do. It is just not "seconds a guess".

---

## The finding that matters more than any thumbnail

**The SketchUp tag `WR Lights` is hidden, so none of the eight rectangle lights has ever
reached a render.** **Observed.**

Evidence, and it is unambiguous:

- `model.layers['WR Lights'].visible?` read **false** on the model as found.
- Stage 2's first run swept the rig from as-found down to *every light disabled* and
  produced images **identical to four decimal places**.
- The decisive probe: sun disabled, interior camera, EV 9 — lights on, lights off, and
  booth light at 20x all measured mean luminance **0.05130**, identical to five decimals.

**Consequence.** Pass 2's "~8x room-to-booth imbalance" was never in the pictures. The
reason one exposure could not serve both views is that **the booth interior had no light
source at all** — only sky spill through the door and window. Every render this project has
produced, in every pass, was lit by V-Ray's sun and sky alone.

I did **not** leave the tag on. The model is back as found, hidden. Turning it on is
Benton's call and it is the single highest-value change available.

Also observed once the tag was shown:

- The true as-found ratio is **room : booth = 22.72 : 1** by summed intensity, not ~8x.
- **`/Standard Light` (intensity 2500, the biggest number in the rig) contributes nothing** —
  the `stdoff` arm is identical to `asfound` to three decimals. Worth deleting or explaining.

---

## Part 1 — the package now reads and honours the settings

`scripts/proposal-package.rb`, 1.9.3 → 1.9.4.

**What it used to do:** write its own `/SettingsOutput`, eight sampler/denoiser parameters
and `/CameraPhysical` on every render row. Benton's Asset Editor said 1600x900 / 16:9 /
Medium / Progressive / denoiser off; the package delivered 1200x900 at 4:3 with a denoiser
and a sampler floor of its own.

**What it does now:**

| | |
|---|---|
| `unit_vray_setup` → **`unit_vray_audit`** | READS 18 parameters, LOGS every one, writes nothing |
| Output size | comes from `/SettingsOutput`; **both lanes** are cut to it |
| `@size_source` | records where the size came from; every log line and row detail says so |
| `require_render_size!` | a render batch that cannot read V-Ray's size is **refused by name** before any file is written — no fallback, because that fallback is exactly how 1600x900 became 1200x900 |
| `/CameraPhysical` | **not written on a normal run**; the row logs the EV the configured camera implies |
| Overrides | `cfg['overrides']`, `'plugin\|key' => value`, **empty by default**, announced loudly in the log when on |
| Per-row EV | survives only behind `overrides['exposure']` |

**Verified live** (`honour_test.rb`, run through the bridge against Benton's real settings):

```
honoured_size -> 1600x900  source=the V-Ray Asset Editor (/SettingsOutput)
require_render_size! -> nil
V-RAY SETTINGS READ FROM THE MODEL - these are HONOURED, not changed.
   /SettingsOutput[img_width]=1600  /SettingsOutput[img_height]=900  ...
   /SettingsImageSampler[type]=3  progressive_threshold=0.04  maxSubdivs=20
   progressive_maxTime=0.0  min_shade_rate=6  /RenderChannelDenoiser[enabled]=false
   /CameraPhysical[f_number]=8.0  ISO=100.0  shutter_speed=300.0
   the camera as configured is EV 14.23
   no overrides are configured - nothing was written to V-Ray
size   before=[1600, 900] after=[1600, 900] UNCHANGED=true
camera before=[8.0, 300.0] after=[8.0, 300.0] UNCHANGED=true
denoiser before=false after=false UNCHANGED=true
```

A render at scene-side 1600x900 produced a file measured at exactly **1600x900**
(`_verify-1600x900.png`, 1,534,233 bytes). `scripts/rbtest-proposal.py` passes whole.

**Not run:** a full end-to-end batch through the real `UI::HtmlDialog`. The audit, sizing,
refusal and exposure paths were exercised directly and live; the dialog wiring for
`cfg['overrides']` is **unexercised**.

---

## Part 2 — the matrix

68 frames in `C:\Users\bento\Desktop\BridgeTest-lookdev\`, every variable in the filename.
Machine-readable records in **`.forge/builder/lookdev-results.json`** — per frame: stage,
every variable value, output path, wall-clock seconds, and its `scripts/image-qa.py`
numbers, plus top-level `timing`, `stages` and `findings` blocks for the contact sheet.

New: `scripts/lookdev-matrix.rb` (renders one frame; snapshots and restores everything it
can touch) and `scripts/lookdev-drive.py` (composes the sweep, chunks it, joins image-qa).

### Stage 1 — environment and sun, 8 arms, exterior camera

Driven through **`scripts/wr-sun-aim.rb`**, per Benton. It gained a `$wr_no_autorun` guard
(the convention `probe-vray.rb` already uses) so the solver can be loaded without its dialog.

**Requested vs achieved elevation — you asked for both, they are recorded per frame:**

| arm | requested | **achieved** | offset | mean | clip | dark |
|---|---|---|---|---|---|---|
| sun-off | – | – | – | 0.221 | 0.053 | 0.144 |
| **matchcam** (control) | 12.88 | **12.83** | +30 | 0.186 | 0.053 | **0.249** |
| elev15 | 15.0 | **14.95** | +30 | 0.196 | 0.056 | 0.227 |
| elev35 | 35.0 | **34.94** | +30 | 0.325 | 0.123 | 0.113 |
| elev35-offneg30 | 35.0 | **34.94** | −30 | 0.441 | 0.157 | 0.066 |
| elev35-off60 | 35.0 | **34.94** | +60 | 0.281 | 0.104 | 0.124 |
| elev60 | 60.0 | **59.90** | +30 | 0.450 | 0.207 | 0.035 |
| elev85 | 85.0 | **85.20** | +30 | 0.597 | 0.381 | 0.015 |

**The solver is accurate.** Every arm landed within **0.3 deg** of the request; azimuth
error **0.00** on all seven; `calibration_confident` true throughout. `clamp_elev` never
had to intervene — nothing was requested below 8 or above 85.

**`match_cam` lands at 12.83 deg, not 8.** The DEVLOG's "8 degree raking sun" is the
`ELEV_MIN` floor for a *level* camera; the exterior three-quarter camera is angled slightly
down, so it solves to 12.83. The complaint is real in kind but the number is a little
higher than recorded.

### Stage 2 — the light balance, 13 arms x 2 cameras, tag forced visible

Carrying `elev35-offneg30` (mechanical tie-break: image-qa mean closest to 0.40 among
PASSing arms — **not** a look verdict; re-run under any other arm cheaply).

All at one exposure, EV 12. `r/b` is room:booth by summed intensity.

| rig | r/b | EXT mean/clip | EXT | INT mean/clip | INT |
|---|---|---|---|---|---|
| **asfound** | **22.72** | 0.628 / 0.287 | PASS | 0.099 / 0.006 | **FAIL** |
| room050 | 11.36 | 0.573 / 0.258 | PASS | 0.091 | FAIL |
| room025 | 5.68 | 0.532 / 0.197 | PASS | 0.086 | FAIL |
| room0125 | 2.84 | 0.489 / 0.159 | PASS | 0.084 | FAIL |
| room00625 | 1.42 | 0.466 / 0.158 | PASS | 0.083 | FAIL |
| boothonly | 0 | 0.443 / 0.157 | PASS | 0.082 | FAIL |
| lightsoff | – | 0.441 / 0.157 | PASS | 0.034 | FAIL |
| **booth4x** | 5.68 | 0.632 / 0.288 | PASS | 0.242 / 0.006 | **PASS** |
| **booth8x** | 2.84 | 0.637 / 0.289 | PASS | 0.414 / 0.012 | **PASS** |
| **booth16x** | 1.42 | 0.645 / 0.292 | PASS | 0.638 / 0.104 | **PASS** |
| room050booth4x | 2.84 | 0.577 / 0.260 | PASS | 0.233 | PASS |
| room025booth8x | 0.71 | 0.544 / 0.214 | PASS | 0.401 | PASS |
| stdoff | 22.72 | 0.628 / 0.287 | PASS | 0.099 | FAIL |

**The direction of the fix is the opposite of what pass 2 assumed.** Cutting the room does
not help the interior at all (0.099 → 0.082); it only darkens the exterior. **Raising the
booth fixture is what makes the interior work.**

### Stage 3 — does one EV serve both? 5 EVs x 2 cameras x 3 rigs

| rig | EV 8.0 | EV 9.5 | EV 11.0 | EV 12.5 | EV 14.0 |
|---|---|---|---|---|---|
| **asfound** | – | – | – | – | – |
| **booth8x** | – | – | – | **BOTH** | – |
| **booth16x** | – | – | – | **BOTH** | **BOTH** |

(“BOTH” = exterior and interior both PASS `image-qa`'s render profile at that one exposure.)

**Answer, plainly: as found, no single EV serves both views.** Every rung either blows the
exterior (EV 8–11) or crushes the interior (EV 12.5–14). That is pass 2's problem, reproduced.

**Once the booth fixture is raised, a single EV does work.** `booth8x` gives one working
exposure; **`booth16x` gives a two-stop window (EV 12.5 and 14.0)**, which is margin rather
than a knife-edge. And **EV 14.0 is within 0.23 of Benton's own untouched camera**
(f/8 @ 1/300, ISO 100 = EV 14.23) — so at `booth16x` his configured camera serves both views
with nothing written to `/CameraPhysical`, which is exactly the outcome you asked for.

**I have not picked the ratio.** The thumbnails for all three rigs at all five EVs are on
disk for Benton to choose from.

---

## The foam, and the correction carried

**The wedge geometry survives into the render intact. The material does not.** **Observed.**

`FOAM_interior-800x450_booth16x_ev14.png` shows the blue panel as a full pyramidal wedge
field with clear relief and self-shadowing — the diamond pattern is there, in geometry.

- Geometry: definition **`Foam`, 1447 faces, 2 instances**, tag `WR-Booth-Foam` **visible**.
- Material: all 1447 faces carry **`Color_I06`**, which in the V-Ray scene is a
  **`_HostMaterial`** — a pass-through shim with **no `/VRay Mtl` child, no reflection layer,
  no roughness, no texture**. Pure flat diffuse.
- For contrast, `Bass Trap Gray` is a real **`MtlSingleBRDF`** with a `/VRay Mtl` and a
  `TexBitmap`, and it reads as a material in the same frame.

So the "flat saturated blue" is the **material**, not missing geometry, and pass 2 was wrong
to call the panel a defect. **Reported, not fixed** — library materials live on `P:`, read
only. The same `_HostMaterial` shim covers `0099_LightSteelBlue` and `Carpet Plush Charcoal`;
converting the host materials to VRayMtl is probably the largest remaining win on "why does
it read as cardboard".

---

## Safe Frame — you cleared me to turn it on, and I could not

**Benton must tick it himself. Observed, twice, at the cost of two SketchUp restarts.**

- The setting is **`/SettingsOutput` userdata `show_safe_frames`**, currently **0**.
- Writing it from Ruby — `sc.change { sc['/SettingsOutput'][:show_safe_frames] = 1 }` —
  **never returns.** Ruby wedges, no modal is on screen, the SketchUp main window still
  reports enabled, the bridge times out at its ceiling, and the process must be killed.
- Likely mechanism (**derived**): toggling safe frames makes V-Ray rebuild its viewport
  widgets (`VRay::Command.rebuild_viewport_widgets` exists) and that cannot complete while
  driven from inside a scene transaction on the same thread.
- `WR_LookDev.safe_frames!` now **refuses by name** rather than hanging, and
  `show_safe_frames` is in `NEVER_WRITE` so `restore!` cannot wedge either.

**Where to click, for Benton and for Gabe:** V-Ray Asset Editor → Settings → **Render
Output** → the **Safe Frame** toggle, beside the resolution fields. It is a per-model V-Ray
setting stored in `/SettingsOutput`, so it needs doing once per model, not once per machine.

**It matters.** With it off, the viewport is the SketchUp window's aspect while the render is
16:9, so what is composed is not what renders — which is worth fixing before any of the
Stage 1 arms are judged on framing.

---

## The HDRI arm — attempted, failed, and NOT shipped

You said to check before assuming. **V-Ray does ship HDRIs locally**, so the arm was not
skipped for lack of a file:

- `...\V-Ray for SketchUp\extension\integration\resources\Default Dome Light Texture.exr`
- `C:\Program Files\Chaos\Vantage\samples\scene\Assets\Sunny_field_D.hdr`
- `...\Vantage\vray_usd\0.24.08\usd\hdx\resources\textures\StinsonBeach.hdr`

**What worked:** `VRay::Scene#create(:TexBitmap, name)` and `(:BitmapBuffer, name)` both
create cleanly, `#delete(name)` removes them (it takes a **name string**, not a Plugin), and
the buffer accepts the `.exr` path and reads it back.

**What failed:** assigning that texture into `/SettingsEnvironment` `bg_tex` / `gi_tex` /
`reflect_tex` / `refract_tex` **does not stick** — the slots read back `/Environment Sky`.
The two frames this produced were therefore just duplicates of the `sun-off` arm. **I deleted
them and their JSONL rows** rather than ship a mislabelled arm on the contact sheet.

**Next step:** `VRay::Command.create_dome_light` exists on this build and is the more likely
route; failing that, set the dome in the Asset Editor by hand and re-run Stage 1, which now
costs about two minutes.

---

## My recommendations, as asked

1. **`match_cam` should NOT stay the default for a level interior view.** On the exterior
   camera it solves to 12.83 deg and produces the darkest, most shadow-crushed arm in Stage 1
   (mean 0.186, dark fraction **0.249** — nearly a quarter of the frame near-black, the worst
   of the eight). On a genuinely level interior camera it would clamp to the 8 deg floor and
   be worse. **Suggested change:** keep `match_cam` as the button's behaviour for a
   deliberately low, dramatic exterior, but make the dialog default `match_cam = false` with
   an explicit elevation around 35 deg. That is a one-line default change in the dialog, not
   a change to the solver, which is working correctly. **Benton should confirm against the
   thumbnails** — this is my read of the numbers, not his eye.
2. **Exposure: fix the rig, do not override the camera.** Already implemented — the package
   no longer writes `/CameraPhysical`. The evidence supports it: at `booth16x` his own
   camera setting serves both views.
3. **Turn the `WR Lights` tag on.** Nothing else in this report matters as much.
4. **Convert the host materials to VRayMtl** where the library allows it — that is my
   prime remaining suspect for the cardboard read, now that the sun has been swept and the
   geometry has been cleared.

---

## Deviations, and things I got wrong

- **SketchUp was force-killed and restarted twice**, both times because of the
  `show_safe_frames` wedge. The scratch model was preserved from SketchUp's own working copy
  (`...\SketchUp 2026\SketchUp\working\Untitled.skp`) and reopened as
  `Desktop\BridgeTest-lookdev\_recovery\Untitled-recovered.skp`. **SketchUp is currently open
  on that file, not on the original `Untitled`.** Nothing was lost — 5 pages, 36 materials
  and the full V-Ray state verified after recovery.
- **I misdiagnosed the first wedge as `renderer.wait` and said so in a code comment.** It was
  `show_safe_frames`. The comment is corrected in `lookdev-matrix.rb`; `wait` is not
  convicted. Polling is kept anyway because, unlike `wait`, it can impose a ceiling.
- **I reported 5.07 s per thumbnail early and it was wrong** — see the timing section.
- **`restore!` reported `restored clean` while putting back the wrong values**, because I
  re-ran `capture!` mid-sweep and swept values became the "original". Caught by verifying
  key-by-key against numbers recorded at 16:22. `capture!` now refuses a second call without
  `:force`. **This is the failure I would most want reviewed** — the restore lied, and only
  an independent record caught it.
- **Two intermediate sweeps produced silently identical images** (the ended-latch race, then
  the one-render-per-job limit). Both are fixed and both are commented at the site.

## Model state

**Left exactly as found**, verified key by key after the last frame: `/SettingsOutput`
1600x900, `show_safe_frames` false; sampler `progressive_maxTime` 0.0, threshold 0.04,
`maxSubdivs` 20, `min_shade_rate` 6; `/CameraPhysical` f/8, ISO 100, shutter 300;
denoiser off; sun enabled, multiplier 1.0; all nine light intensities; all six `shadow_info`
keys (ShadowTime `2026-11-08 08:30:00 -0500`, NorthAngle 0.0, Lat 40.018309,
Lon −105.242139, TZ −7.0, City "Boulder (CO)"); `WR Lights` **hidden**, the only hidden tag.

## Open questions

- Does `VRay::Command.create_dome_light` work, and does it give a usable HDRI arm?
- Why is `/Standard Light` in the scene at intensity 2500 with no SketchUp instance the
  walk could find, contributing nothing? It may be an orphan from an imported asset.
- The model's geo-location is **Boulder CO**, while `wr-sun-aim.rb`'s header says the model
  is meant to be pinned to Knoxville EST. Untouched by me, but the two disagree.
- The `cfg['overrides']` path has no dialog control yet — it is reachable only from Ruby.
