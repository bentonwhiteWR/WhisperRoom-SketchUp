# Interior lighting for renders — options and a recommendation

Researcher findings, 2026-08-27. Read-only pass; nothing outside `.forge/researcher/` was touched.

## Question

Benton: the sun-aim tool now works, but "the floor plan drawings we've made today" still render
with dark interiors — "it's almost like there needs to be some lighting inside of the rooms",
ideally "another plugin where I could drop simple lighting inside of the rooms". Simple and
minimalistic. What is the simplest thing that meaningfully fixes it, and exactly how do we build it?

## Answer, short version

**Build a one-button light dropper that places SketchUp component instances of a single
Benton-authored V-Ray rectangle-light component (`WR Interior Light.skp`) at the ceiling of each
selected room or booth group.** No V-Ray API calls at all — a V-Ray light in SketchUp *is* a
SketchUp component instance, and placing instances is plain `model.definitions.load` +
`entities.add_instance`, the exact pattern eight scripts in this repo already use. The scripted
V-Ray API route was investigated and is the wrong tool: the shipped YARD API documents **no light
class**, and its own architecture says anything injected into the render scene that is not in the
SketchUp model gets wiped on every re-export. For the images that are **plain SketchUp exports**,
no light of any kind can help — SketchUp's viewport has no local lights — and the correct lever
(shadow `Dark`, `DisplayShadows`) already exists in `scripts/wr-shading.rb` / `scripts/wr-mode.rb`;
that half is a defaults question for the proposal-package skill (GOAL stream 4), not a new tool.

## What was actually dark today (recovering the real problem)

- The only drawings made today are the **UTHSC Audiology rooms** — `scripts/uthsc-audiology-rooms.rb`
  (v1.6.36, git `45cb5ee`), four rooms with 8'-0" walls. **Observed** in the script: walls are
  extruded to `CEILING = 96.0` and **no ceiling slab is drawn** — the rooms are open-top boxes.
- The sun work (v1.6.39/1.6.40) was driven by "an afternoon of black V-Ray renders"
  (**reported**, `DEVLOG.md` 2026-08-27 entry). So today's deficient renders are **V-Ray renders
  of the room drawings**, and the GOAL separately names **booth-interior renders reading as black
  holes** (`.forge/GOAL.md` item 5). Both are the same physics: sun-only lighting of a walled
  volume. Even with no ceiling, a sun at camera height (what "Light It From Here" now produces)
  rakes over the walls and leaves the floor inside in wall shadow; a booth interior with its tray
  ceiling on gets nothing at all.
- **Assumed** (couldn't observe): today's renders themselves. No image newer than 2026-08-26
  exists anywhere under `C:\Users\bento\Desktop` on this machine, and **V-Ray is not installed on
  this desktop** (`C:\Program Files\Chaos` does not exist; the SketchUp 2024 Plugins folder holds
  only `wr_tools`, sandbox, dynamic components). Rendering happens on another machine — the one
  `reference/vray-ruby-api.md` was written on, which had V-Ray at
  `C:\Program Files\Chaos\V-Ray\V-Ray for SketchUp\`. Every V-Ray behavioural claim below is
  therefore **reported**, not observed, and the one-pass checklist at the end says what to verify.

## The load-bearing API question: can Ruby create a V-Ray light?

**Not through any documented light call — the API has no light class.** Evidence:

- `reference/vray-ruby-api.md` (a transcription of the YARD docs shipped with V-Ray, made
  2026-08-19 on the render machine — **reported**) lists the complete documented class surface:
  `VRay::Context`, `Scene`, `Scene::Plugin`, `Scene::ChangeSet`, `VRayRenderer`,
  `VRayRenderer::Plugin`, `ModelExporter`, `ScenePreview`, `VRayImage`, `UVTextureSampler`,
  `Proxy`, plus value types. **No `Light*` class of any kind.**
- The only generic creation call is `scene.create(:PluginType)` inside a `scene.change { }`
  transaction (same file, worked example creates a `:TexAColor`). A `.vrscene` plugin named
  `LightRectangle` exists in V-Ray's file format, so `scene.create(:LightRectangle)` might
  execute — **assumed, never run anywhere** — but it would create a *renderer-side* object, not a
  SketchUp-side one.
- The same reference file states the architecture that kills that idea: `ModelExporter#subscribe`
  "lets you run code AFTER the model has been exported to the renderer but BEFORE rendering
  starts — which is where you would inject anything that is not in the SketchUp model"
  (**reported** from the docs). **Derived:** V-Ray rebuilds its scene from the SketchUp model on
  every render, so a light injected once via `scene.create` is wiped on the next export unless
  re-injected from an export subscription on every render — permanent machinery for a "simple"
  feature, invisible in the Asset Editor, unmovable with the Move tool, gone if the subscription
  isn't loaded.
- Community confirmation (**reported**, web): there is no supported scripting route for light
  creation; the long-standing practitioner workaround is exactly the seed-component approach —
  "created separate .skp files for each light object … loaded these files as component
  definitions and created instances as needed"
  ([sketchucation thread](https://sketchucation.com/forums/viewtopic.php?f=322&t=59286)). And
  copying a light instance works because **a V-Ray light is a SketchUp component instance**
  carrying the extension's attributes — copies "act as one" light asset sharing one set of
  properties ([Domestika V-Ray lighting tutorial](https://www.domestika.org/en/blog/5149-v-ray-tutorial-introduction-to-lighting-tools),
  [SketchUp forum: copied lighting](https://forums.sketchup.com/t/vray-some-copied-lighting-wont-work/15772)).

**So the plain answer: we cannot cleanly create a V-Ray light from Ruby, and we don't need to.**
We can *place instances of one that already exists* using nothing but the standard SketchUp API,
and all its properties stay editable in the Asset Editor like any hand-made light. The shared-
properties behaviour is a feature here: tune the intensity once, every room follows.

## The four options, honestly

### 1. V-Ray rectangle lights auto-placed at ceilings — **recommended, via seed component**

Two sub-shapes:

- **1a. Raw API (`scene.create(:LightRectangle)`)** — rejected. Undocumented plugin name
  (**assumed**), wiped on re-export unless re-injected every render (**derived**, see above),
  produces a light Benton cannot see, move, or delete in SketchUp. Fails the "simple" brief in
  the worst way: invisible complexity.
- **1b. Seed component** — a single `WR Interior Light.skp` that Benton authors once (draw one
  rectangle light with the V-Ray toolbar, size it 24"×48" like a ceiling troffer, point it down,
  set intensity by eye on one test render, right-click → Save As). The tool
  `model.definitions.load`s it and drops an instance centered under the top of each selected
  group's bounding box. ~150 lines of pure SketchUp Ruby; every idiom already exists in this
  repo. UI: select rooms (or the booth), press one panel button. Fails at: does nothing for
  plain SketchUp exports (see option 3); light properties are shared across all instances
  (acceptable — arguably wanted); needs the one-time seed authoring, and GOAL already says
  authoring `.skp` files is Benton's job — the tool refuses **by name** if the file is missing.

### 2. Dome / environment light, or raising GI

A dome light is an environment light: it illuminates from outside the model. **Derived:** inside
a booth with its ceiling on it contributes nothing except through the window; in the open-top
UTHSC rooms it would help the floors but flatten exactly the face modelling the 30-degree offset
in `wr-sun-aim.rb` exists to preserve. Raising GI/exposure means driving Asset Editor render
settings, which the documented API only reaches through raw plugin parameters (**assumed**), and
it changes every render globally — exteriors included. No per-room control, which is the thing
Benton asked for ("lighting inside of the rooms"). Rejected.

### 3. SketchUp-native, surviving plain exports

**There is no such thing as a light in the plain SketchUp viewport** — no point/area lights
exist in the product; face brightness comes from sun direction plus the style's shadow
`Light`/`Dark` values (**observed**: this is precisely the mechanism `scripts/wr-shading.rb`
manipulates, with its own comment "the lever that actually flattens the difference is the shadow
settings' DARK value: it lifts the unlit faces toward the lit ones"). So for the half of the
images that are plain exports, the *only* fixes are: raise `Dark` (toward 60–70), or turn
`DisplayShadows` off for floor-plan plates. That machinery exists and is already per-mode in
`scripts/wr-mode.rb` (`DEFAULT['render']['shadow']`) and per-scene once the proposal-package
skill (GOAL stream 4) exists — the right home is **a default in that skill's plain-export pass**,
not a new tool. **Does it matter?** Yes, and it should be said plainly: dropping V-Ray lights
will not brighten a plain export by one pixel. The two halves need the two different levers, and
both levers stay one-button.

### 4. Do nothing new; adjust what the sun script touches

`wr-sun-aim.rb` writes only `shadow_info` — azimuth, and elevation-via-latitude (**observed**,
full read of the file). Its elevation floor `ELEV_MIN = 8.0` exists precisely because sun-only
interiors go black; the ceiling of what sun can do for a walled interior has been reached, which
is Benton's own report. Raising shadow `Dark` helps plain exports (option 3) but does nothing
for V-Ray, which computes its own lighting. Rejected as the whole answer; it *is* the answer's
plain-export half.

## Recommendation

**Option 1b**, plus one sentence of option 3 folded into stream 4's defaults. It is the only
option that puts light *inside* an enclosed volume, needs zero V-Ray API surface, zero new UI
beyond one button, and leaves every light as an ordinary component Benton can move with the Move
tool or delete with the eraser — SketchUp itself is the lighting-designer UI, so we never build one.

## Implementation sketch (for the Builder)

**New file: `scripts/wr-drop-lights.rb`** — auto-discovered by the panel like every other script.

Header (the panel reads these — **observed**, `scripts/wr_tools/main.rb` parses `@title`,
`@cat`, `@rank`):

```ruby
# @title Drop Interior Lights...
# @cat V-Ray renders
# @rank 3
```

**Seed component.** `scripts/vray-seeds/WR Interior Light.skp` (new folder; keeps it inside the
live-loaded `scripts/` tree so `File.dirname(__FILE__)` finds it and a `git pull` ships it).
Benton authors it once on the render machine: V-Ray toolbar → Rectangle Light, 24"×48" (a
standard troffer), facing **down**, drawn at the component origin so placement is a pure
translation; set intensity on one test render; right-click → Save As. Until that file exists the
tool must refuse **by name**: `"scripts/vray-seeds/WR Interior Light.skp is missing — author it
once (V-Ray toolbar > Rectangle Light, face down, Save As) and press again."` — GOAL rule: no
silent fallback, no faked component.

**Behaviour (one `start_operation`, one Ctrl+Z):**

1. Read `model.selection`. Keep only `Sketchup::Group` / `Sketchup::ComponentInstance`. Empty →
   `UI.messagebox` "Select the room or booth groups to light, then press again." and stop.
   No guessing which groups are rooms.
2. `defn = model.definitions.load(seed_path)` — the pattern already used in
   `scripts/merge-scenes.rb:294`, `scripts/wr-deck.rb:767`, and six other scripts (**observed**).
   Load once, reuse across presses (cache by path, the `build-booth-components.rb:1409` pattern).
3. Per selected container: world `bounds`; place one instance at
   `(center.x, center.y, bounds.max.z - DROP)` with `DROP = 6.0` inches — below an open-top
   room's wall line and below a booth's tray-ceiling underside in the common cases; it is a
   normal instance, so if 6" lands inside a ceiling panel Benton moves it with the Move tool.
   Default one light per group; a group whose larger plan dimension exceeds `SPLIT = 144.0`
   inches (12') gets two, spaced at the third-points of the long axis — Rooms 1 and 2 at UTHSC
   are 19–22' across and one troffer in a 22' room is a visibly single hotspot. No other layout
   logic. Instances go in `model.active_entities` (not inside the room group — keeps client
   drawing groups untouched).
4. Tag every instance with tag `WR Lights` (create if absent) and stamp an attribute
   (`set_attribute('WR_DropLights', 'seed', 'WR Interior Light')`).
5. **Idempotent re-press:** before placing, delete every instance carrying that attribute whose
   origin falls inside a selected group's bounds. Press again = re-place, not double-light.
6. Console report, the house style: one line per light with the group name and coordinates,
   plus a count; failures print `FAILED:` and abort the operation.

**What Benton clicks:** select the four room groups (or the booth), press **Drop Interior
Lights** on the panel, render. To brighten or dim: open Asset Editor, one light asset, one
intensity slider — every instance follows (shared-asset behaviour, **reported**, see sources
above). To remove: select the rooms and there is nothing to press — erase the instances or the
`WR Lights` tag's contents; a `Ctrl+Z` right after pressing removes all of them at once.

**Two interactions to document in the file header, not solve with UI:**

- Hiding the `WR Lights` tag almost certainly disables the lights in the render too — V-Ray
  skips hidden geometry by default (**reported**, community; verify once). So the tag exists for
  *finding* the lights, not for per-scene hiding; plain-export scenes can turn it off harmlessly
  since those exports never used the lights anyway.
- `scripts/wr-mode.rb` snapshots tag visibility per mode (**observed**) — after the first
  draft/render toggle with lights present, the tag's state rides along automatically; nothing
  to build.

**Also ship (one line each):** bump `scripts/wr_tools/VERSION` (any `scripts/` change requires
it — CLAUDE.md); and in stream 4's plain-export pass, default floor-plan plates to
`DisplayShadows false` or `Dark 60+` via the existing `WR_Shading` contract.

**Verification pass (on the render machine — nothing here can run Ruby):**

1. Author the seed, press the button on the UTHSC model, confirm four+ lights land and a V-Ray
   render lights the room floors.
2. Confirm a copy-placed instance actually emits (the entire design rests on this **reported**
   behaviour; if V-Ray 7 broke it, fall back to `definitions.load` of the seed being equivalent
   to File→Import, which the sketchucation workaround says works).
3. Run `scripts/probe-vray.rb` while there — it is written, unrun, and would settle whether
   `VRay::Context.active` exists cold, for stream 4's benefit.

## Confidence and gaps

- Weakest link: **every V-Ray behaviour is reported, none observed** — no V-Ray on this machine,
  no render seen. The seed-component mechanism has years of community use behind it but the
  specific V-Ray version on the render machine was never confirmed (the YARD docs there were
  generated 2025-12-01, so V-Ray 6/7 era).
- The claim "today's dark images are V-Ray renders of the UTHSC rooms" is **derived** from
  DEVLOG + git, not observed; if some were plain exports, option 3's lever is the fix for those
  and the recommendation is unchanged.
- `DROP = 6.0` and the 12' split threshold are **assumed** starting values, chosen to be cheap
  to change (each is one constant, and every light is hand-movable).
- Whether hiding the `WR Lights` tag kills the light in-render: **reported**, unverified; it is
  on the verification list because wr-mode will eventually toggle that tag.

Sources: [sketchucation — V-Ray scripting in Ruby](https://sketchucation.com/forums/viewtopic.php?f=322&t=59286),
[Domestika — V-Ray lighting tools](https://www.domestika.org/en/blog/5149-v-ray-tutorial-introduction-to-lighting-tools),
[SketchUp forum — copied lighting](https://forums.sketchup.com/t/vray-some-copied-lighting-wont-work/15772),
[Chaos docs — Lights, V-Ray for SketchUp](https://documentation.chaos.com/space/VSKETCHUP/109776489/Lights),
and `reference/vray-ruby-api.md` in this repo (transcription of the shipped YARD docs).
