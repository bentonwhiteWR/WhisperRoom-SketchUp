# Render recipe, as run on the October 2026 client jobs

Every fact names its source. "WC" = `.forge/builder/weather-company/` (14 Oct, the
reference job), "HL" = `.forge/builder/holmdel/`, "UT" =
`.forge/builder/university-of-tennessee/`, "SJSU" = `.forge/builder/sjsu-eeg-lab/`,
"TL" = `.forge/builder/trout-lake-rev3/`. The client script for WC is
`scripts/weather-company-alpharetta-gabe.rb`. Where jobs differ, the WC/HL v2 way is
listed first and the variant after it.

"UV" = `.forge/builder/uvic-library/` (21 Oct, the v1 skill trial), "KC" =
`.forge/builder/kcur-radio/` (22 Oct).

All of this runs through the bridge (`scripts/sketchup-bridge.py`). Bridge jobs never
open a modal, never block, and only write inside the `write_roots` they are given.

**Two files open (1.85.0).** With more than one SketchUp window open, every bridge call needs
`--model <path, unique file-name fragment, or pid:N>` (or `WR_BRIDGE_MODEL` set for the session,
which `submit()` callers such as `render/` follow); without it the job is refused, exit 6, and the
open files are listed. `ping` lists them too. With one window open nothing changes. After a
Save As the file's name changes, so address it by the new name or by `pid:N`.

## 0. Realism floor (every first delivery; reference: WC round 3)

Look at `<WORK>\weather-company-renders-r3\01-hero-both-booths-and-doors.png` before
dressing the room. UV round one fell short of it on furniture, white balance and floor.
A speed request trims test renders and repeated lighting passes, never an item below.

| Item | The floor | WC source |
|---|---|---|
| Furniture and props | Real multi-part models, never single boxes. Load `.skp` components with `model.definitions.load` from SketchUp 2026's `C:\ProgramData\SketchUp\SketchUp 2026\SketchUp\Components\Components Sampler\` (e.g. `Couch Modern`, `Bench Wood HighBack`, `Tall Table Barstools`) or downloads kept in `<WORK>\<client>-furniture\`; scripted props must be built from their parts as WC's were | `studio_set!`: camera pedestal with casters, column, ring, lens, prompter; displays with frame and glass |
| Ceiling grid | Subtle: 15/16" white T-bar (`[242, 242, 240]`), 1" deep, on 24" centres from a room corner, over a 24" tile texture (`[232, 232, 230]`); LED panels sit in grid cells | `tbar!`, `M_TBAR`, `M_CEILT`, `PANELS` |
| White balance | Neutral: lights `kelvin_rgb(4000)` and `--wbk 4000` matched, white dome. **Check:** on near-white pixels (mean > 190, channel spread < 40) of each hero, mean R-G and B-G within 3 levels. WC r3 01: -1.2 / -2.3; UV 01: 3.8 / -7.0 (a warm cast, fails). Fix the kelvin or WB, not the image | `PANEL_K`, finals-r3 |
| Floor | A texture with visible variation at real scale, plus roughness and normal maps: WC concrete 72" repeat, `roughness_factor` 0.32 | `M_CONC` (`wc-floor-alb/-rgh/-nrm.png`) |
| Walls and columns | Plaster albedo retinted, with roughness + normal maps, `rf` 1.0 / 0.9 | `M_WALL`, `M_COLUMN` |
| Texture source order | 1. downloaded photo-scanned PBR sets (albedo, roughness, normal); 2. SketchUp 2026 library `.skm` (`skm_mat`, e.g. `Materials\Metal\Metal_06_1K.skm`), or its maps retinted, as WC did; 3. generated textures only when neither has the finish | WC round 2 (`mat()` 5th element) |
| Room dressing | Base trim, real door, windows with mullions, exterior context through glazing, fixtures in the ceiling | `finishes!` |

WC round 2 brought the room to this level (PBR finishes, T-bar grid, LED panels on the
grid, dome on its own tag, screens self-lit, exterior context); round 3 changed only
geometry and moved hero 02 (eye (396,-282,44), fov 52). Time target with this floor:
20 to 30 minutes for one booth.

## 1. Order of operations (WC `jobs/rerun.rb`, HL `jobs-v2/rerun.rb`)

1. Load the client script with `$wr_suppress_autorun = true`, guarded so it refuses
   unless the active model is the client's local `.skp`.
2. Stages as needed: `run`, `booths!`, `ap!`, `scenes!`, then `m.save(m.path)`.
   On a model Gabe has hand-edited, skip `run` and `booths!` (see SKILL.md).
3. `lights!` (V-Ray lights + dome).
4. The materials job (WC `jobs/materials-r2.rb`, HL `jobs-v2/materials.rb`), which sets
   `$hl_refl` and loads `render/vray-setrefl.rb`. **Re-run it after every `run`**:
   `run` resets the material colours and the reflection layers go with them (WC HANDOFF).
5. V-Ray frames with `render/render.py`, then SketchUp plates with `render/plates.py`.

## 2. V-Ray settings (driver `render/vray-render.rb`)

`render/render.py` (the portable copy of the UT round-2 driver that every October job
ran from `.forge/builder/holmdel/jobs/`) loads `render/vray-render.rb` (a verbatim copy of
`.forge/builder/cms/render.rb`) and calls, per run:

| Setting | Value | Source |
|---|---|---|
| Size | 1600 x 900 heroes; 2560 x 1440 the overhead | WC `jobs/render-finals-r3.sh` |
| Progressive max time / noise threshold | 2.0 min / 0.03 | same; `settings!` in render.rb |
| Denoiser | on (`/RenderChannelDenoiser`) | render.rb `settings!`; WC `render-log-r3.txt` |
| Exposure | physical camera f/8, ISO 100, shutter from EV (`ev!`) | render.rb |
| EV | WC 16.1 / 16.0 heroes, 16.8 overhead; HL, UT, SJSU 16.7; SJSU interior 15.2 | WC finals-r3; HL, UT, SJSU HANDOFFs |
| White balance | 4000 K (`--wbk 4000`, via `WR_DropLights.kelvin_rgb`); it persists in the scene once set | WC finals-r3, HL HANDOFF |

`settings!` reads the output size back and raises if it did not stick. `aim!` sets
`TransitionTime` 0 and copies the page camera; `start!` then `poll` until idle;
`save!` writes the **linear** VFB (`save_vfb_image`), and `render.py` applies the sRGB
encode and prints one JSON line per frame (`render_s`, `mean`, `clipped`, `dark`).
`--out` is required. Both drivers find the repo from their own location, so they run
from any working directory. If `WR_DropLights` is not loaded yet (a fresh SketchUp
session), `--wbk` loads `scripts/wr-drop-lights.rb` module-only first.

Invocation as run (WC `jobs/render-finals-r3.sh`):

```
python render/render.py --out "<WORK>/<client>-renders-rN" --w 1600 --h 900 --min 2.0 --thr 0.03 --ev 16.1 --wbk 4000 "01 ..."
```

Render times observed: WC r3 71.1 s, 83.4 s, 45.9 s (`render-log-r3.txt`); TL
34.6 s and 10.9 s (TL HANDOFF).

**One render job at a time** (KC). Before each, kill every render process and confirm
`WR_CMSRender.poll['state']` reads idle. A stale run left alive shared the V-Ray session
and wrote KC's R2A-01 as a byte copy of R1A-01. UV heroes ran at EV 16.3 and 16.8.

**Variant (TL, 1 Oct, the earliest job):** shutter 1/600, WB 5200 K, dome 30, settings
restored after. TL's own HANDOFF calls that lighting "a quick test level". Use the
WC/HL values.

## 3. Lighting rig (WC `lights!`)

- Ceiling LED panels as V-Ray rectangle lights, 10.5 x 10.5 in, made with
  `WR_DropLights.create_light` and `write_params` (from `scripts/wr-drop-lights.rb`):
  invisible, `affectReflections` false, units 1, intensity
  `LUMENS * LIGHT_GAIN * LIGHT_TUNE` = 8000 x 320 x 3, colour `kelvin_rgb(4000)`.
  One per ceiling-grid fixture position (`PANELS`), just under the ceiling, on the
  `WR Lights` tag (`T_LIGHT`).
- A V-Ray dome light, intensity 250 (`DOME_INTENSITY`), on its own tag `WC Dome Light`,
  shown only in render scenes. HL v2 also used dome 250 (HL HANDOFF).
- The booth's own interior light is left as modelled; the interior frame (SJSU 07)
  drops EV to 15.2 instead of adding light.

## 4. Materials

- Room finishes come from the client script's `mat(model, [name, texture, size, rgb, opts])`
  (PBR, textures in `<WORK>\<client>-textures\`) or `skm_mat` (SketchUp 2026 library
  `.skm`), matched to any client room photo (HL v2).
- **Reflection layers** with `vray-setrefl.rb`: `$hl_refl = { name => [reflect grey,
  glossiness] }`; it edits the plugin JSON in the material's `VRayPlugins` dictionary
  and calls `VRay::MaterialSync.to_vray`. Writing the BRDF directly does not stick:
  the sync resets it (HL HANDOFF, observed twice). A freshly converted material's key
  is `.../BRDFVRayMtl`, not `.../VRay Mtl` (WC HANDOFF).
  Load it repo-relative, never by a person's path (the October jobs' `materials.rb` used
  Gabe's absolute path): `load File.join(File.dirname(WhisperRoom::Tools::SCRIPTS_DIR),
  'render', 'vray-setrefl.rb')`. `SCRIPTS_DIR` is `<REPO>\scripts` whenever the plugin
  finds a repo checkout (`scripts/wr_tools/main.rb`); with only the bundled copy there
  is no `render\`, so set `WR_SCRIPTS_DIR` to the clone's `scripts` folder.
- **PBR maps reach V-Ray broken** (UV, observed 21 Oct): normal and roughness maps set
  through `ImageRep` arrive as a `BitmapBuffer` whose file is literally `".png"`. UV's
  `jobs/materials.rb` points those buffers at the real files and re-syncs; copy it.
- **Screens** (WC only): self-illumination set to their own diffuse texture
  (`materials-r2.rb`).
- **Glass** at SketchUp alpha 0.18 converts to refractive glass (HL HANDOFF; WC uses the same alpha).
- **Foam** recoloured to a neutral gray: `foam_gray!` sets `[Color_I06]` to
  (96, 96, 98), and refuses if anything other than the foam uses that material (WC).

## 5. Scene set and cameras (WC `scene_defs` / `scenes!`)

`scenes!` **deletes every scene** and rebuilds this list, so never run it on a model
where someone saved their own scenes.

| Scene | Kind | Output |
|---|---|---|
| 01 hero (both booths and doors) | V-Ray | 1600 x 900 |
| 02 second hero (WC: from the studio floor; the PDF cover; the cover rule is in SKILL.md stage 9) | V-Ray | 1600 x 900 |
| 02b vestibule (WC only, defined, not in the PDF) | V-Ray | |
| 03 overhead cutaway | V-Ray | 2560 x 1440, background flood-filled to white, unfilled copy in `raw\` |
| 04 dimensioned plan | SketchUp plate | parallel projection |
| 04b booth-area plan | SketchUp plate | parallel |
| 05 dimensioned elevation | SketchUp plate | parallel, section-plane cut |
| 06 booth interior plan | SketchUp plate | parallel, booth roofs hidden |
| 07 inside-booth render (SJSU only) | V-Ray | EV 15.2 |

- Perspective cameras: `cam(eye, target, fov)` with `aspect_ratio = 0`. Parallel:
  `par_cam(cx, cy, w, h)`. Section planes hidden in the display.
- Tags per scene: every job tag hidden, then the scene's own list on. Ceiling,
  context and lights are on in the render scenes only.
- The 03 flood fill: `python render/sky-fill.py --dir <renders> "<name>-03-overhead-cutaway.png"`
  (KCUR's fill, generalised: seeds at the corners and edge midpoints, sky-blue only,
  threshold 28; the unfilled frame is kept as `raw\<name>-unfilled.png`). Earlier jobs
  filled inline (UT) or used a SketchUp transparent-export mask (SJSU).
- Variant: the repo's proposal playbook orders pages hero, dimensioned, side, rear/vent,
  plan. The October jobs used the 01 to 06 order above.

## 6. Dimensioned views

- `render/plates.py --out <dir> --w 2560 --h 1440 --sf 1.5` (HL HANDOFF; script default sf is
  2.0): `write_image` with `scale_factor` to enlarge dimension text, not transparent,
  flattened onto white, cropped to content with a 3% pad; raw export kept in `raw\`.
- Dark floor or foam under dimension text gets a lightened copy **in these views only**,
  on a `<client>-Floor-Light` tag (WC tag `WC-Floor-Light`; materials `WC Polished Concrete Light (dims views)`,
  `WC WhisperRoom Carpet Light (dims views)`; HL: `HL WhisperRoom Carpet Light (dims
  views)`). Rule from Gabe, Shepherd job, 25 Sep 2026.
- Plates carry the door swing arcs, notes and labels on their own tags. SJSU kept a
  client copy of each plate with plain labels, no ASSUMED marks (`$wr_sjsu_client`, SJSU only).

## 7. Image export to the PDF

- V-Ray: linear VFB to `raw\`, sRGB-encoded PNG beside it (`render/render.py`).
- `prep.py` in the proposal folder: flatten onto white, trim (2% pad; 3% overhead, 1% elevation;
  06 untrimmed), downsize to 1600 px wide, JPEG quality 88 into `renders-web\` (WC and HL v2
  `prep.py`). For a long multi-option pack, KC cut this to 1400 px at q84 (cover 1800 px):
  24 pages went from 6.87 MB to 4.92 MB with print quality intact.
