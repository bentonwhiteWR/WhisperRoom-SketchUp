# V-Ray for SketchUp — the Ruby API

**V-Ray is scriptable from Ruby, and the API has now been touched live.**
This file was first written 19 Aug 2026 from the shipped documentation alone.
On **27 Aug 2026 `scripts/probe-vray.rb` ran in a live SketchUp 2026 session
with V-Ray loaded — cold, before any render** — and this file now separates
what that run **OBSERVED** from what is still only **REPORTED** (transcribed
from Chaos's docs, never called). A second probe run taken after a manual
render came back garbled in transit, so **nothing post-render or mid-render
has been observed by anyone** — that is the biggest remaining hole.

---

## ⚠ OBSERVED: `in_process?` and `dr_enabled?` RAISE on this machine

On a **cold, idle** renderer, with no render ever performed and distributed
rendering never used:

```
renderer.in_process?   !! StandardError: Incorrect DR version
renderer.dr_enabled?   !! StandardError: Incorrect DR version
```

These are the distributed-rendering pair, and the raise is **not** conditional
on actually using DR — DR is evidently misconfigured or unlicensed here and
the methods raise on every call. **Never write code that calls either one,
and never gate anything on them.** `proposal-package.rb` originally polled
`in_process?` as its render-completion signal and was fixed the day this was
observed; the working signals are:

```
renderer.state             :idleInitialized      (idle, cold — works)
renderer.sequence_ended?   true                  (same moment — works)
```

`state`'s vocabulary is observed from **one sample**. Nobody has seen the
mid-render or just-finished value. Code that classifies it must treat
"matches /idle/i" as finished and **any unknown state as still running**,
with a wall-clock timeout — never a hard-coded list of running states.
(`proposal-package.rb`'s completion-classification section is the worked
example; widen its `IDLE_STATE` when a mid-/post-render probe lands.)

---

## Where it is

| Thing | Path |
|---|---|
| Extension root | `C:\Program Files\Chaos\V-Ray\V-Ray for SketchUp\extension\` |
| **API docs (open this)** | `…\extension\documentation\index.html` |
| Overview page | `…\documentation\file.V-Ray for SketchUp Ruby API.html` |
| Native binding | `…\extension\vray\sketchup\3.2\vray.so` |

The docs are a YARD set generated 1 Dec 2025 by yard 0.9.36 on ruby-3.2.3.
The probe ran in **SketchUp 2026** and the entry points below all answered,
so the docs still describe the installed binding well enough to navigate by.

The implementation is compiled into `vray.so`, so the docs are the only
readable source. Method signatures are documented; behaviour is not — where
behaviour matters, only a live call counts.

---

## The shape of it — OBSERVED working, cold

```ruby
context  = VRay::Context.active   # OBSERVED: VRay::Context, NON-NIL cold
model    = context.model          # OBSERVED: Sketchup::Model
scene    = context.scene          # OBSERVED: VRay::Scene
renderer = context.renderer       # OBSERVED: VRay::VRayRenderer
```

**`VRay::Context.active` is non-nil in a cold session, before any render.**
That settles the old open question 1: a batch script CAN run cold. But note
what it does — and does not — prove: a nil context means V-Ray is absent
(not installed / not enabled), while a **non-nil context proves only that
V-Ray is loaded, not that a render will succeed** — the very context the
probe returned also owns the renderer whose DR methods raise. "Context
exists" is presence, not readiness.

Documented classes (reported): `VRay::Context`, `Scene`, `Scene::Plugin`,
`Scene::ChangeSet`, `VRayRenderer`, `VRayRenderer::Plugin`, `ModelExporter`,
`ScenePreview`, `VRayImage`, `UVTextureSampler`, `Proxy`, plus the value
types `Color`, `AColor`, `Vector`, `Matrix`, `Transform`.

### VRayRenderer — 77 methods live (docs said 61)

Observed on the cold idle renderer:

| Read | Value | Status |
|---|---|---|
| `render_mode` | `:production` | observed |
| `state` | `:idleInitialized` | observed (one sample — see warning above) |
| `sequence_ended?` | `true` | observed |
| `vfb_visible?` | `false` | observed |
| `thread_count` | `0` | observed (cold; meaning idle-time value unknown) |
| `get_compute_devices` | `[]` | observed — **empty; possibly no GPU configured, worth checking** |
| `vfb_settings` | JSON string (`{"Version":"1","RenderRegionProps":…}`) | observed |
| `in_process?`, `dr_enabled?` | **StandardError "Incorrect DR version"** | observed — DO NOT CALL |

Methods **observed present** (existence only — none of these has been
called): `start`, `stop`, `wait`, `export`, `image`, `save_vfb_image`,
`denoise`, `set_denoiser_options`, `show_vfb`, `hide_vfb`,
`apply_settings_vfb`, `subscribe`, `unsubscribe`, `load`, `dump`, `change`,
`create`, `fetch`, `each`, `grep`, `get_persistent_state`,
`set_persistent_state`, `set_resumable_rendering`, `user_scene_name`,
`vfb_progress_text=`, `vfb_progress_value=`, `current_time` — 77 in total.

The last few are interesting: `subscribe`/`unsubscribe` (callback-driven
completion — see "polling vs callbacks" below) and the `vfb_progress_*=`
writers (a batch could paint its own progress into the VFB). All still
**reported behaviour**: present ≠ working, as `in_process?` just taught us.

Reported-only (from the docs, unverified): `save_irradiance_map_file`,
`save_light_cache_file`, `add_hosts`, `active_hosts`, `set_compute_devices`,
`fill_settings_vfb`.

### Scene — observed live

`scene.id` returned `2285076156128`. The scene held **71 plugins cold**,
among them `/SettingsDMCSampler`, `/VolumeAerialPerspective`,
`/SettingsColorMapping`, `/SettingsTIFF`, `/SettingsVFB`,
`/CameraPhysical`, `/RenderChannelDenoiser`, plus material/texture plugins
for Cosmos assets. So the `/Settings*` family and a physical camera are
already present as plugins before anything is rendered — the render
contract (resolution, denoiser, output) plausibly lives in those, and
`/CameraPhysical` bears on the still-open "which camera does a render use"
question (its existence is consistent with V-Ray maintaining a camera from
the active view, but observing one cold scene settles nothing — only a
two-scene render comparison will).

Scene methods observed: `[]`, `add_search_path`, `change`, `clear!`,
`create`, `delete`, `dump`, `each`, `fetch`, `grep`, `id`, `import`,
`import_buffer`, `import_plugins`, `plugins_version`, `relink_files`,
`rename_plugin`, `subscribe`, `unique_name`, `unsubscribe` — matches the
docs' list.

Everything in a Scene is a **Plugin** with a URL-like name
(`/ExamplePlugin`, `/ExamplePlugin/SomeChild`). Changes belong inside a
transaction (reported):

```ruby
scene.change {
  tex = scene.create(:TexAColor)
  tex[:texture] = VRay::Color.new(1, 0, 0)
}
```

### ModelExporter — the hook before the render (reported)

`export_model`, `export_group`, `export_component_definition`,
`export_component_instance`, `renderer`, `scene`, `subscribe`.

`subscribe` lets you run code AFTER the model has been exported to the
renderer but BEFORE rendering starts. The docs give a worked example that
walks every `:Node` plugin and multiplies its transform.

---

## Polling vs callbacks for "is it finished?"

The docs offer three completion surfaces: `state`/`in_process?`/
`sequence_ended?` (poll), `wait` (block), and `subscribe` (callback).
Where that stands now:

- **Poll `state`** — the working path. Observed readable; unknown-state-means-
  running plus a timeout covers the unseen vocabulary.
- **`in_process?`** — broken here (raises). Dead.
- **`subscribe`** — observed to exist on both renderer and scene, never
  called. It would beat polling (no vocabulary guessing) **but do not build
  on it blind**: its event names, callback signature, and which thread the
  callback lands on are all unknown, and a callback raising on the wrong
  thread inside SketchUp is a crash, not a failed row. The probe that would
  earn it: subscribe with a callback that only appends
  `[Time.now, args.inspect]` to a global array, start a small render by
  hand, and print the array — that shows the event vocabulary and proves
  the callback fires on something survivable.
- **`wait`** — reported blocking; would freeze the UI thread mid-batch, so
  it is only the fallback of last resort.

---

## What this is worth building

**Batch the proposal renders** — now built: `scripts/proposal-package.rb`
(unrun live). It walks the marked scenes, `start`s, polls `state`, and
`save_vfb_image`s into the chosen folder.

Second candidate: **one render contract**, the way `wr-shading.rb` is one
shading contract — resolution, denoiser and output settings pinned in one
place and pushed before every render. The observed `/Settings*` plugins are
where that would live.

---

## Open questions — updated 27 Aug 2026

1. ~~Is `VRay::Context.active` non-nil in a normal session?~~ **ANSWERED:
   yes, non-nil cold (observed).** But presence only — see above.
2. **Is `start` blocking or asynchronous, and what does `state` return
   mid-render?** Still open, and now the load-bearing unknown: the batch's
   completion test inverts on /idle/i precisely because nobody has seen the
   running value. One probe settles it — run this in the Ruby Console,
   start a render **by hand** immediately after, and paste the output:

   ```ruby
   r = VRay::Context.active.renderer
   $wr_states = []
   $wr_t = UI.start_timer(0.5, true) {
     $wr_states << [Time.now.strftime('%H:%M:%S'),
                    (r.state rescue :raised),
                    (r.sequence_ended? rescue :raised)]
     if $wr_states.size >= 240
       UI.stop_timer($wr_t)
       $wr_states.each { |row| puts row.inspect }
     end
   }
   # …render by hand, wait for it to finish, then if 2 min hasn't elapsed:
   # UI.stop_timer($wr_t); $wr_states.each { |row| puts row.inspect }
   ```

3. **Does `save_vfb_image` take a path and a format,** and does it respect
   the VFB colour corrections? Still reported only.
4. **What does a render do to the SketchUp UI** — focus, VFB visibility?
   Still open (`vfb_visible?` false cold is the only data point).
5. **Licensing:** does a scripted render consume a seat like an interactive
   one? Still open — and the "Incorrect DR version" raise hints the licence
   state on this machine is at least partly unhappy.
6. **NEW: `get_compute_devices` returned `[]`.** If GPU rendering is
   expected on this machine, that empty list deserves a look in the V-Ray
   Asset Editor's device settings before blaming a script for slow renders.
7. **NEW: which camera does a scripted render use** — the active view, the
   scene's saved camera, or `/CameraPhysical`'s own state? The plugin's
   presence (observed) says a physical camera participates; whose values it
   carries is unknown. Settled by rendering two scenes in a row from a
   script and seeing whether the framing follows the scene switch.
