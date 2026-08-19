# V-Ray for SketchUp — the Ruby API

**V-Ray is scriptable from Ruby, and the full documentation is already on the
machine.** This file records what was found on 19 Aug 2026 so nobody has to
rediscover it, and sets out what it would let us build.

Nothing here has been RUN. Every method name below is transcribed from the
shipped documentation, not from a live session. Confirm with `probe-vray.rb`
before writing anything that depends on it.

---

## Where it is

| Thing | Path |
|---|---|
| Extension root | `C:\Program Files\Chaos\V-Ray\V-Ray for SketchUp\extension\` |
| **API docs (open this)** | `…\extension\documentation\index.html` |
| Overview page | `…\documentation\file.V-Ray for SketchUp Ruby API.html` |
| Native binding | `…\extension\vray\sketchup\3.2\vray.so` |

The docs are a YARD set generated 1 Dec 2025 by yard 0.9.36 on ruby-3.2.3 —
i.e. they match the Ruby that SketchUp 2024 runs.

The implementation is compiled into `vray.so`, so the docs are the only readable
source. Method signatures are documented; behaviour is not.

---

## The shape of it

One entry point ties everything together:

```ruby
context  = VRay::Context.active
model    = context.model      # the Sketchup::Model
scene    = context.scene      # V-Ray assets and their state
renderer = context.renderer   # the renderer
```

Documented classes: `VRay::Context`, `Scene`, `Scene::Plugin`,
`Scene::ChangeSet`, `VRayRenderer`, `VRayRenderer::Plugin`, `ModelExporter`,
`ScenePreview`, `VRayImage`, `UVTextureSampler`, `Proxy`, plus the value types
`Color`, `AColor`, `Vector`, `Matrix`, `Transform`.

### VRayRenderer — 61 methods, the ones that matter to us

| Method | Use |
|---|---|
| `start`, `stop`, `wait` | drive a render |
| `save_vfb_image` | write the result to a file |
| `export` | write a `.vrscene` |
| `image` | get the rendered image |
| `denoise`, `set_denoiser_options` | denoising |
| `show_vfb`, `hide_vfb`, `vfb_visible?` | the frame buffer window |
| `vfb_settings`, `apply_settings_vfb`, `fill_settings_vfb` | render settings |
| `render_mode`, `get_compute_devices`, `set_compute_devices` | CPU / GPU |
| `save_irradiance_map_file`, `save_light_cache_file` | GI caches |
| `add_hosts`, `active_hosts`, `dr_enabled?` | distributed render / Swarm |
| `subscribe`, `unsubscribe` | progress and completion callbacks |
| `state`, `in_process?`, `sequence_ended?` | is it finished? |

### Scene — 19 methods

`create`, `delete`, `fetch`, `each`, `grep`, `change`, `import`,
`import_buffer`, `import_plugins`, `add_search_path`, `relink_files`,
`rename_plugin`, `unique_name`, `clear!`, `dump`, `subscribe`.

Everything in a Scene is a **Plugin** with a URL-like name (`/ExamplePlugin`,
`/ExamplePlugin/SomeChild`). Changes belong inside a transaction:

```ruby
scene.change {
  tex = scene.create(:TexAColor)
  tex[:texture] = VRay::Color.new(1, 0, 0)
}
```

### ModelExporter — the hook before the render

`export_model`, `export_group`, `export_component_definition`,
`export_component_instance`, `renderer`, `scene`, `subscribe`.

`subscribe` lets you run code AFTER the model has been exported to the renderer
but BEFORE rendering starts — which is where you would inject anything that is
not in the SketchUp model. The docs give a worked example that walks every
`:Node` plugin and multiplies its transform.

---

## What this is worth building

**Batch the proposal renders.** Today the pipeline is: set up scenes → render
each one by hand in V-Ray → hand the folder over → build the pack. The first
two steps are the only manual ones left. A script could walk the proposal scene
list, render each at one fixed resolution, and `save_vfb_image` straight into
`ProposalFiles\<Client>\` with the names the proposal config expects.

That is the same discipline `elevation-export.rb` already applies to the
SketchUp exports, and it would close the last gap in the proposal pipeline.

Second candidate: **one render contract**, the way `wr-shading.rb` is one
shading contract. Resolution, denoiser and output settings pinned in one place
and pushed before every render, so a pack rendered today matches one rendered in
six weeks.

---

## Open questions — answer these before writing anything

1. **Is `VRay::Context.active` non-nil in a normal session,** or only once V-Ray
   has been "activated" (rendered at least once) in that SketchUp instance?
   This decides whether a batch script can run cold.
2. **Is `start` blocking or asynchronous?** There is a `wait` and a `subscribe`,
   which suggests async. A batch loop needs to know which.
3. **Does `save_vfb_image` take a path and a format,** and does it respect the
   VFB colour corrections, or write the raw beauty pass?
4. **What does a render do to the SketchUp UI** — does it steal focus, and can
   it run with the VFB hidden?
5. **Licensing:** does a scripted render consume a licence seat the same way an
   interactive one does?

`scripts/probe-vray.rb` answers 1 and prints enough of the live API surface to
narrow the rest.
