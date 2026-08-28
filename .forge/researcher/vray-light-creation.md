# Why the dropped lights stopped emitting — differential diagnosis, probes, and the light-creation appendix

Researcher findings, 2026-08-27 (evening). Read-only outside `.forge/researcher/`.
Companion corrections applied the same day to `interior-lighting-options.md` and
`interior-lighting-design.md`.

## Question

The seed-`.skp` light mechanism (`scripts/wr-drop-lights.rb`) placed lights that **emitted in
an early run and do not emit today**, in the same modeling workflow, while a hand-drawn light
and a SketchUp copy/paste of one both emit. What changed between the run that emitted and the
run that did not — and, as a fallback that is now probably unneeded, can a V-Ray light be
created programmatically at all?

## Answer, short version

**The mechanism is sound and was never the problem.** The corrected observation set (all
observed, Benton, live, 2026-08-27) is:

| What | Emits? | When |
|---|---|---|
| Hand-drawn rectangle light | **yes** | today |
| SketchUp copy/paste of a working light | **yes** | today |
| Seed-minted, `definitions.load`-placed instances, plugin ~1.7.2-era code | **yes** | earlier run — Benton: "your very first example, they were shown. They just didn't look good at all." (visible white rectangles, Invisible off) |
| Same mechanism, plugin 1.7.4 | **no** — dark at 30,000 lm | today |

So duplication works, external-file import works, and the failure is specific to today's run.
**The leading suspect by a wide margin is the draft-mode tag hiding that shipped in between**
(observed in the code, and its warning line printed verbatim in Benton's console today):
`wr-drop-lights.rb` now hides the `WR Lights` tag at placement when the model is in draft
mode, V-Ray skips hidden geometry including lights (reported, vendor + community — about to be
confirmed the hard way), and a manual render from a draft-mode model therefore renders unlit.
Probe A2 below confirms or kills it in one paste plus one render. Everything else — mount
height, container nesting, units, exposure — is ranked and probed below, but none of them
explains "total darkness today, light earlier" as completely.

The V-Ray-API light-creation research survives as an appendix: **no documented light class
exists**, `scene.create(:LightRectangle)` is untested anywhere, and the renderer-side-wipe
claim is itself only **reported** (from the docs' architecture description, never observed).
Since duplication demonstrably works, none of it is needed.

---

## Part 1 — what changed between run A (emitted) and run B (did not)

Git history of `scripts/wr-drop-lights.rb` and `scripts/wr-mode.rb` (observed, `git log`):

```
fb05026  Add Drop Interior Lights (single troffer)          — run-A era
d335857  layered showroom rig replaces the single troffer
6239193  mint missing seed .skp files from one hand-made light
d786816  1.7.3
2f48a6e  never light a light … ← DRAFT-MODE TAG HIDING ENTERS HERE (git log -S)
b53cb7e  Add the three seed .skp files minted on the desktop
c5b2cd2  wr-mode: draft hides WR Lights, render shows them  ← LIGHT_TAGS polarity
8e20ab7  fix the UTHSC full-cull …
0f7e9c6  1.7.4                                              — run-B era
```

`git log -S 'this model is in DRAFT mode'` pins the hiding behaviour to `2f48a6e` —
**after** the run that emitted, **before** today's run (observed). It is the one behaviour
that exists in run B and not in run A, and it acts on exactly the thing that stopped working.

## Part 2 — differential diagnosis, ranked

### Suspect 1 — the `WR Lights` tag is hidden (draft mode). LEADING, near-conclusive.

**How it kills the light.** `WR_DropLights.tag` (`scripts/wr-drop-lights.rb:887-905`,
observed) sets `t.visible = false` at placement whenever `model.get_attribute('WR_Mode',
'current') == 'draft'`, printing:

> `tag "WR Lights" HIDDEN — this model is in DRAFT mode, and the light rectangles must not
> appear in plain image exports. Show the tag (or switch to Render mode) BEFORE a V-Ray
> pass, or the render will be unlit.`

**Benton's console printed that warning verbatim today (observed)** — so the model *was* in
draft mode and the tag *was* hidden at placement. V-Ray for SketchUp does not render lights
whose geometry is hidden or on a hidden tag/layer — reported: Chaos' own help article states
hiding V-Ray light geometry excludes the light from the render entirely
([Chaos Help Center — Lights not visible](https://support.chaos.com/hc/en-us/articles/4408870677265-V-Ray-Lighting-for-SketchUp-and-Rhino-Lights-not-visible),
retrieved via search excerpt; the page itself 403s from here), and a long-standing Chaos
forum thread carries the same finding
([Hidden lights will not render?](https://forums.chaos.com/forum/v-ray-for-sketchup-forums/v-ray-for-sketchup-bugs/42474-hidden-lights-will-not-render)).
The earlier research files listed this exact claim as **assumed, unverified**; today is very
probably its confirmation.

**Why it fits every observation.** The hand-drawn light and the copy/paste copy are not on
the `WR Lights` tag → unaffected, emit. The Asset Editor lists assets from the component
definitions, not from instance visibility → the three `WR Light *` assets still appear, with
editable parameters, exactly as Benton saw. The instances themselves are skipped at export
→ zero emission regardless of 30,000 lm.

**Probe A1 (state check)** — part of the master probe in Part 4.

**Probe A2 (kill test — one paste, one render):**

```ruby
m = Sketchup.active_model
t = m.layers['WR Lights']
if t.nil?
  puts 'NO "WR Lights" tag exists — suspect 1 is DEAD, run the master probe'
elsif t.visible?
  puts 'tag already VISIBLE — suspect 1 is DEAD (hiding is not the cause), run the master probe'
else
  t.visible = true
  puts 'tag "WR Lights" is now SHOWN. Render NOW, changing nothing else.'
  puts 'Room lights up  -> CONFIRMED: hidden tag was the whole cause.'
  puts 'Still dark      -> suspect 1 dead; run the master probe and go to suspect 2.'
end
```

Caveat: pressing the wr-mode toggle afterwards may re-hide the tag (that is its job in
draft); render before touching the mode toggle.

**Cost if confirmed:** zero new mechanism — a design decision about *when* hiding happens
(Part 3). **How this suspect could be wrong:** if A2 shows the tag and the render is still
dark, the tag was hidden *and* something else also suppresses emission — proceed down the
list; the master probe already collects the evidence for that.

### Suspect 2 — mount height: lights inside or under solid geometry

Benton's viewport shows the rectangles sitting **lower** than the spec's 6"-below-ceiling
(observed, his report). Placement code (observed): downlights at `z_m = z_top - DROP` with
`DROP = 6.0` (`wr-drop-lights.rb:163,1422,1504`), booth interior light at booth
`bb.max.z - DROP` (`:1538`). If `z_top` was read from the wrong container (the 1.7.4 commit
`0f7e9c6` message says the *suite group* was being taken as the keep-out — the same
bounds-reading family of bug), a light could land inside a ceiling/roof solid — a light
sandwiched inside geometry emits into the solid and reads near-black — or *below* the booth
roofline where the booth shadows it.

Fits "dim/wrong", fits "lower than expected"; fits "absolutely no light at 30,000 lm" poorly
— several downlights across an open-top room would still light *something*. Ranked second.

**Probe:** the master probe prints every placed light's world Z next to every top-level
group's bounding-box top; a light whose Z is at or above a container top it should be under,
or below the booth roof plane, shows up as a number, not a guess.

**Cost if confirmed:** one bounds-reading fix in the Builder's court. **Wrong-guess mode:**
Z figures look right → dead, move on.

### Suspect 3 — container nesting

Lights go in `model.active_entities` (observed, header §"WHAT A PRESS DOES"). If Benton
pressed while *inside* a group edit, `active_entities` is that group's entities and the
lights are nested. V-Ray has a known historical bug family with lights nested in components
("Unable to edit light — no light asset was provided", V-Ray 2.0 and Next eras; restart
sometimes fixed it — reported,
[sketchucation thread](https://community.sketchucation.com/topic/146432/help-quot-unable-to-edit-light-no-light-asset-was-provided-quot)).
Ranked third: the seeds ARE component instances and copy/paste of a light (also an instance)
works today, so simple instancing is fine; only deep nesting is in question, and nothing
observed says the lights are nested.

**Probe:** the master probe prints each light's container path (`MODEL TOP` or the chain of
enclosing groups). **Also cheap:** save, quit, reopen, render — the historical fix for stale
light-asset binding was a restart; if a reopen alone makes them emit, this family is the
cause.

### Suspect 4 — units / intensity / exposure

Benton set Units = Luminous Power, intensity 30,000 (observed, Asset Editor). 30,000 lm in a
booth-sized room is enormous; even at V-Ray's default EV ~14.2 full-sun exposure
(reported — see `interior-lighting-design.md` §1.4) it would read as *visible* light, and
the hand-drawn light in the same model, same exposure, emitted. Exposure explains "too dim",
never "the working light works and the placed one doesn't". Ranked fourth; no probe needed —
A2's render settles it implicitly.

### Suspect 5 — per-asset enable toggle off in the Asset Editor

Each light asset has an on/off toggle. Benton had the parameter panel open and read values
off it (observed), so an off toggle would likely have been seen — but it costs one glance:
in the Asset Editor's Lights list, confirm the toggle beside each `WR Light *` is on.
Ranked last.

---

## Part 3 — if suspect 1 confirms: how draft hiding and the V-Ray pass should coexist

Asked by the coordinator; answered from the code, no code written.

**The batch lane is already correct as coded (derived, unrun live).**
`scripts/proposal-package.rb` changes mode only through `unit_mode`
(`proposal-package.rb:509-522`, observed), which calls `WR_Mode.to_mode(model, target)`
before the render pass. `scripts/wr-mode.rb` (observed, `:75-97`) carries
`LIGHT_TAGS = ['WR Lights']` with render polarity **true** — entering render mode shows the
tag — and backfills the light key into pre-LIGHT_TAGS snapshots (`wr-mode.rb:177-188`,
observed, with the comment naming exactly this failure). So a proposal-package V-Ray pass
shows the lights before rendering. Unrun live — it is on the acceptance checklist anyway.

**The exposed path is exactly one:** press Drop Interior Lights while the model is in draft
mode, then start a **manual** V-Ray render without ever touching the mode toggle. That is
what happened today (derived from the printed warning + the dark render).

**One genuine trap in the snapshot design (derived from `wr-mode.rb:170` — leaving a mode
saves its live state):** if someone manually hides `WR Lights` *while in render mode* and
then toggles away, render mode memorizes "hidden" and every future render entry re-hides the
lights — silently, forever, surviving the backfill (which fills only *missing* keys). Worth
a preflight row more than a code change.

**Minimal guard, recommended shape (Builder's call):** placement should never be the thing
that hides the rig. Let `tag()` always leave `WR Lights` visible and print the draft-mode
note as advice only; hiding belongs to the *mode switch* (`wr-mode.rb` already owns it, both
polarities). A just-placed rig is about to be rendered far more often than it is about to be
plain-exported, and the failure asymmetry the code itself documents
(`wr-drop-lights.rb:874-886`: "a hidden light tag in a V-Ray pass renders silently UNLIT,
the worse failure") argues the same way — the current code states the right principle and
then implements the opposite default. Second, cheaper-still option: keep the behaviour and
add a `WR_Preflight` row "`WR Lights` tag hidden while lights exist" so the batch lane warns;
that does nothing for the manual-render path, which is the path that failed today.

---

## Part 4 — the master probe (one paste, reports everything)

Reports: tag existence/visibility, wr-mode state, every placed light's world Z, tag,
hidden-flag and container path, every top-level group's bounding-box top for Z comparison,
and what the V-Ray scene currently holds for lights. Every section rescues and prints the
error rather than dying silently.

```ruby
m = Sketchup.active_model
puts "=== WR light diagnosis #{Time.now.strftime('%Y-%m-%d %H:%M')} ==="

# -- 1. tag + mode ---------------------------------------------------------
t = m.layers['WR Lights']
puts t ? %(tag "WR Lights": EXISTS, visible=#{t.visible?}) : 'tag "WR Lights": DOES NOT EXIST'
mode = (m.get_attribute('WR_Mode', 'current') rescue "read failed")
puts "wr-mode 'current' = #{mode.inspect}   (nil = never toggled)"

# -- 2. every placed / seed light, wherever it hides -----------------------
found = 0
walk = nil
walk = lambda do |ents, path, tf|
  ents.each do |e|
    next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
    wtf = tf * e.transformation
    is_seed = (e.respond_to?(:definition) && e.definition && e.definition.name =~ /\AWR (Light|Interior Light)/)
    is_mine = (e.get_attribute('WR_DropLights', 'seed') rescue nil)
    if is_seed || is_mine
      found += 1
      o  = wtf.origin
      ly = e.layer
      puts format('  %-26s  worldZ=%8.2f"  tag=%-12s tagVis=%-5s hidden=%-5s in=%s',
                  (e.respond_to?(:definition) ? e.definition.name : e.name),
                  o.z, (ly ? ly.name : '?'), (ly ? ly.visible?.to_s : '?'),
                  e.hidden?.to_s,
                  path.empty? ? 'MODEL TOP' : path.join(' > '))
    end
    inner = e.is_a?(Sketchup::Group) ? e.entities : (e.definition ? e.definition.entities : nil)
    walk.call(inner, path + [(e.name.to_s.empty? ? e.class.name.split('::').last : e.name)], wtf) if inner && path.size < 4
  end
end
begin
  walk.call(m.entities, [], Geom::Transformation.new)
  puts '  (NO seed/dropped lights found anywhere down to depth 4)' if found.zero?
rescue StandardError => e
  puts "  light walk FAILED: #{e.class}: #{e.message}"
end

# -- 3. what stands where: compare light Z against these tops --------------
puts 'top-level groups/components (bbox top, for the Z comparison):'
m.entities.each do |g|
  next unless g.is_a?(Sketchup::Group) || g.is_a?(Sketchup::ComponentInstance)
  bb = g.bounds
  nm = g.name.to_s.empty? && g.respond_to?(:definition) ? g.definition.name : g.name
  puts format('  %-34s top Z=%8.2f"', nm.to_s[0, 34], bb.max.z)
end

# -- 4. does V-Ray currently hold light plugins? ---------------------------
begin
  if defined?(VRay) && VRay::Context.active
    sc = VRay::Context.active.scene
    lp = sc.grep(/light/i)
    puts "V-Ray scene: #{lp.size} plugin(s) matching /light/i:"
    lp.each { |p| puts "    #{p.name}" }
    puts '  NOTE: the scene may mirror the model only at export — a stale count'
    puts '  cold means little; the count RIGHT AFTER a render is the real one.'
  else
    puts 'V-Ray: no active context (not loaded in this session)'
  end
rescue StandardError => e
  puts "V-Ray probe FAILED: #{e.class}: #{e.message}"
end
puts '=== end ==='
```

**How to read it:** tag hidden or `tagVis=false` on the lights → suspect 1; run Probe A2.
Light `worldZ` at/above a group top it should be under, or below the booth top minus its
tray → suspect 2. `in=` anything but `MODEL TOP` → suspect 3. Everything clean but still
dark after A2 → paste the whole output back; that combination is currently unexplained and
the appendix routes become live again.

---

## Appendix — programmatic light creation (researched, currently not needed)

Kept because it was asked and because it documents where the walls are. **Since within-model
copy/paste and external-file `definitions.load` both demonstrably emit (observed, above),
nothing in this appendix is on the critical path.**

### A. Duplication — settled by observation

Works, both routes (observed today: copy/paste emits; earlier run: loaded-definition
instances emitted). How V-Ray binds a light to a component is still not documented anywhere
found: the light's parameters live in attribute dictionaries on the component (reported —
the SketchUp-forum answer that "V-Ray writes its own metadata … using attribute
dictionaries" [for materials]
([forums.sketchup.com](https://forums.sketchup.com/t/how-to-access-the-property-of-vray-material/252330)),
and the older XML-in-dictionaries description for V-Ray 2
([sketchucation — V-Ray scripting in ruby?](https://community.sketchucation.com/topic/147596/v-ray-scripting-in-ruby))).
The Asset Editor listing the three seed assets by name (observed) proves definition-carried
dictionaries are enough for asset *registration*; today's dark render is explained by tag
hiding, not by a binding failure.

### B. `scene.create` — untested everywhere, and the wipe claim is only reported

- The shipped YARD docs document **no light class** (reported, `reference/vray-ruby-api.md`,
  transcribed 2026-08-19).
- `scene.create(:PluginType)` inside `scene.change { }` is the only generic creation call
  (reported, same file). Whether `:LightRectangle` is accepted has never been run by anyone
  here. Plugin type names in `.vrscene` format are `LightRectangle`, `LightSphere`,
  `LightDome`, etc. (reported, general V-Ray file-format knowledge — not verified against
  this build).
- **The claim that renderer-side objects are wiped on every re-export is REPORTED ONLY** —
  derived in `interior-lighting-options.md` from the docs' description of
  `ModelExporter#subscribe` ("run code AFTER the model has been exported … BEFORE rendering
  starts"), never observed. Today's lesson about reported claims applies to it squarely: it
  is plausible architecture, not a measured fact.
- One-paste probe, if this route ever matters (designed to error loudly on a wrong guess):

```ruby
begin
  sc = VRay::Context.active.scene
  lp = nil
  sc.change do
    lp = sc.create(:LightRectangle)
    lp[:intensity] = 30000.0
    lp[:units]     = 3          # lumens — key/value ASSUMED from .vrscene convention
  end
  puts "created #{lp.name}; render once NOW, then run: " \
       "puts VRay::Context.active.scene.grep(/light/i).map(&:name)"
  puts 'If the render brightens and the plugin is still listed after: it survives.'
  puts 'If the render is unchanged or the plugin vanishes: the wipe claim is real.'
rescue StandardError => e
  puts "scene.create probe FAILED (that is an answer): #{e.class}: #{e.message}"
end
```

Even if it survives, this route makes a light Benton cannot see, move or delete in
SketchUp — it stays rejected for the product regardless.

### C. `scene.import` / `import_plugins` — unknown, plausible, unneeded

Both methods observed to exist on the live scene (`reference/vray-ruby-api.md`, probe of
2026-08-27); neither is documented beyond its name in anything found here or on the web.
The plausible reading — importing a `.vrscene` fragment — would share route B's fate on
re-export *if* the wipe claim is true, and shares its invisibility-in-SketchUp defect
either way. Probe only if B's probe is run and survives: same shape, `sc.import(path)` on a
two-line `.vrscene` containing one `LightRectangle`, wrapped in the same begin/rescue.

### D. Non-API routes

- **Official Script Access** (Chaos docs page "V-Ray Script Access") documents only render
  launching: `VRayForSketchUp.launch_vray_render`, `launch_vray_rt_render`,
  `launch_vray_batch_render` (reported —
  [forums.sketchup.com relay](https://forums.sketchup.com/t/ruby-script-to-launch-a-v-ray-render/179479);
  the docs page itself now redirects and would not fetch from here). No light creation.
- **No supported scripting route for light creation exists**; the community's standing
  workaround is precisely our seed-component approach (reported,
  [sketchucation — V-Ray scripting in ruby?](https://community.sketchucation.com/topic/147596/v-ray-scripting-in-ruby)).
- **V-Ray Light Gen** ([Chaos docs](https://documentation.chaos.com/space/VSKETCHUP/109777319/V-Ray+Light+Gen))
  is a lighting-*scenario* generator (environment/HDRI variants), not an artificial-light
  placer — not applicable (reported, docs page title/summary only).
- The full YARD docs live at
  `C:\Program Files\Chaos\V-Ray\V-Ray for SketchUp\extension\documentation\` on the render
  machine (reported, GOAL/reference); grepping that folder for `Light` would close the
  "does any light API exist undocumented-here" residual in minutes. Not possible from this
  machine.

---

## Confidence and gaps

- **Observed:** the four-row emission table (Benton, live, today); the tag-hiding code and
  its draft-mode trigger; the git timeline placing that code between run A and run B; the
  console warning having printed today; `proposal-package.rb`'s render lane switching mode
  through `WR_Mode.to_mode`; `wr-mode.rb`'s render polarity showing the tag.
- **Reported:** V-Ray skipping hidden lights (vendor help article via search excerpt +
  forum threads — the direct article 403s from this machine); everything in the appendix
  sourced to docs/forums; the renderer-side wipe claim (docs architecture only, stated as
  such).
- **Derived:** that today's model was in draft mode with the tag hidden (from the printed
  warning); that the manual-render-from-draft path is the only exposed one; the snapshot
  trap.
- **Assumed:** none load-bearing. The probes exist so nothing above has to be taken on
  faith.
- **Weakest links:** (1) suspect 1 is unconfirmed until Probe A2's render — everything else
  is circumstantial, however strong; (2) the batch lane's correctness is code-read, not
  live-run; (3) nobody has yet seen the master probe's V-Ray section on a scene that
  contains lights, so its "scene mirrors at export" caveat is itself reported.

Sources:
[Chaos Help Center — Lights not visible](https://support.chaos.com/hc/en-us/articles/4408870677265-V-Ray-Lighting-for-SketchUp-and-Rhino-Lights-not-visible) ·
[Chaos Forums — Hidden lights will not render?](https://forums.chaos.com/forum/v-ray-for-sketchup-forums/v-ray-for-sketchup-bugs/42474-hidden-lights-will-not-render) ·
[sketchucation — V-Ray scripting in ruby?](https://community.sketchucation.com/topic/147596/v-ray-scripting-in-ruby) ·
[sketchucation — "no light asset was provided"](https://community.sketchucation.com/topic/146432/help-quot-unable-to-edit-light-no-light-asset-was-provided-quot) ·
[forums.sketchup.com — V-Ray material properties via Ruby](https://forums.sketchup.com/t/how-to-access-the-property-of-vray-material/252330) ·
[forums.sketchup.com — Ruby script to launch a V-Ray render](https://forums.sketchup.com/t/ruby-script-to-launch-a-v-ray-render/179479) ·
[Chaos docs — V-Ray Light Gen](https://documentation.chaos.com/space/VSKETCHUP/109777319/V-Ray+Light+Gen) ·
[Chaos Forums — file paths via Ruby (Plugin#each)](https://forums.chaos.com/forum/v-ray-for-sketchup-forums/v-ray-for-sketchup-general/1182745-how-to-obtain-the-path-of-v-ray-file-assets-through-ruby)
