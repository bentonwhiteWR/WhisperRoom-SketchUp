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

**The full vocabulary is now OBSERVED — see question 2 below.** The line
that used to stand here said "matches /idle/i is finished", and that was
wrong in the most expensive way: **three of the five states match /idle/i**,
two of them meaning the renderer never started. On 28 Aug 2026 that wrote
five empty framebuffers into a client folder. The rule now is
**`:idleDone` only, and only after the row has been seen in a running
state** (`proposal-package.rb`'s completion-classification section is the
worked example).

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
| `state` | `:idleInitialized` | observed cold; full vocabulary observed 28 Aug — see question 2 |
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
2. ~~Is `start` blocking or asynchronous, and what does `state` return
   mid-render?~~ **ANSWERED 28 Aug 2026 (Benton, live SketchUp 2026):** a
   0.25 s state watcher across a hand render gave the complete vocabulary,
   and `start` is **asynchronous** — it returns and `state` moves on its own.

   | `state` | `sequence_ended?` | meaning |
   |---|---|---|
   | `:idleStopped` | true | stopped |
   | `:idleInitialized` | true | cold, never started |
   | `:preparing` | false | starting up |
   | `:rendering` | false | actively rendering |
   | `:idleDone` | true | **FINISHED — the only value meaning a frame exists** |

   Timing from that watch: `:idleInitialized` 11:56:10.735 -> `:preparing`
   11:56:11.176 (**440 ms lead-in**) -> `:rendering` 11:56:11.432 ->
   `:idleDone` 12:01:37.674 (5m26s total). A batch-triggered render reached
   `:preparing` at 12:03:49.462, so **`renderer.start` does engage from a
   script**.

   What this costs anyone reading the old advice: `/idle/i` matches THREE of
   the five, and `sequence_ended?` is `true` on a renderer that has never
   run. **Neither signal alone can tell "never started" from "finished".**
   Both need a latch — the row must be seen `:preparing` / `:rendering` /
   anything outside the idle family before a finish is believed. That is
   what `proposal-package.rb` does now, and its `classify_render` takes the
   latch as an argument so `rbtest-proposal.py` can prove it offline.

   Still unobserved on this surface: what `state` reads while V-Ray is
   *saving* a frame, and whether `:idleDone` can ever be reached without
   passing through a running state on a very short render.

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
7. **Which camera does a scripted render use** — PARTLY ANSWERED, and it
   bit. 28 Aug 2026, observed by Benton: with only one scene marked Render,
   V-Ray rendered a DIFFERENT scene's view — the one selected before it. So
   the render follows the **active view at export time**, and V-Ray's own
   log (`"Exporting model: Done (0.2201505 seconds)"`) says it snapshots the
   camera ~0.22 s after `start`. `model.pages.selected_page =` starts a
   camera ANIMATION over `PageOptions['TransitionTime']` (1 s by default),
   so the export caught the camera in flight, still near where it came from.
   `view.refresh` does not wait for a transition. The fix, mirroring what
   `export-scenes.rb` has always done for the image lane: **set
   `TransitionTime = 0` for the batch, set `view.camera` from `page.camera`
   directly, and compare the two before calling `start`.**

   Still open: whether `/CameraPhysical` carries its own values on top of
   that (the field-of-view specifically), which is why
   `proposal-package.rb` treats a lens-only difference as a warning and a
   position difference as a failed row.
