# Handoff — the sun-off matrix, and whether the host room needs a ceiling

Builder, 2026-08-30. SketchUp 2026 / V-Ray 7 only, through
`scripts/sketchup-bridge.py --su 2026`. `P:` and `WhisperRoomQuote` read only. Nothing
written to `Desktop\ProposalFiles\`. `scripts/proposal-package.rb` **not touched** (another
agent is auditing it). Provenance tagged **observed / derived / reported / assumed**.

---

## 1. The tag assertion — read this before anything else

**`WR Lights` was VISIBLE on every frame in this sweep, and eight light instances were
visible on every frame. Observed, and asserted frame by frame, not once at the top.**

The tag read **`false` on the model as found**, exactly as you said. `sunoff-drive.py check`
turned it on and proved it before a single frame was spent:

```
tag was_visible=false  now=true  visible_light_instances=8
```

The harness no longer takes that on trust. `WR_LookDev.assert_lights_visible!` runs inside
`frame!` **before `VRay::Command.render_production`**, and it *raises* — the frame is failed
by name and no image is written. It refuses on two separate conditions, and both were
exercised as **negative tests** against the live model before the sweep began:

| condition | result |
|---|---|
| tag hidden | `RuntimeError: REFUSED TO RENDER: the tag "WR Lights" is HIDDEN...` |
| tag visible, one instance hidden | `RuntimeError: ...only 7 light instances are visible (expected 8)` |
| both put back | `assert -> 8` |

Every frame record carries `measured.tag_wr_lights_visible` and
`measured.visible_light_instances`, and `sunoff-results.json` opens with an `assertions`
block that lists by id any frame that rendered with the tag hidden, any frame with fewer
than eight instances, and any frame where the sun was still on. **All three lists are
empty.** The rest of this report is not void.

## 2. What was run

`C:\Users\bento\Desktop\BridgeTest-sunoff\` holds the thumbnails, every variable in the
filename. `.forge/builder/sunoff-results.json` is the machine-readable record, in the same
shape as `lookdev-results.json` — per frame: stage, every variable, output path, apply /
render / wall-clock seconds, what V-Ray actually read back (`measured`), and the
`scripts/image-qa.py` numbers — plus top-level `assertions`, `timing` and `axes` blocks for
the contact sheet.

**Filename and id are the same string**, so a thumbnail identifies itself:

```
S<stage>_<room>_<rig>_ev<EV>_<camera>.png
S A_w4-open_asfound_ev12.0_ext.png
```

### The axes

| room id | walls | ceiling | sky multiplier | what it asks |
|---|---|---|---|---|
| `w4-open` | 4 | none | 1.0 | the room exactly as it is today |
| `w4-ceil` | 4 | solid | 1.0 | the same room, capped |
| `w4-nosky` | 4 | none | 0.0 | open roof, but no sky light at all |
| `w3-open` | 3 | none | 1.0 | the 3-sided drawing you actually make |
| `w3-ceil` | 3 | solid | 1.0 | 3-sided but capped |
| `w3-nosky` | 3 | none | 0.0 | 3-sided, no sky light |

The rig arms are stage 2's, unchanged, so the two sweeps compare frame for frame. Every
number is a multiplier on the intensity the rig was **found** at.

**The sun is disabled on every frame.** `measured.sun_enabled` reads `false` on all of them
and the results file asserts it.

### The three stages

- **Stage A** — the rig, sun off, room as found (`w4-open`), 13 arms x 2 cameras, EV 12.
  This is the frame that did not exist anywhere in the 68.
- **Stage B** — the enclosure axis: 5 rig arms x the 5 rooms that are not `w4-open` x 2
  cameras, at the same EV, so the ceiling is the only thing that moved.
- **Stage C** — an exposure ladder: EV 9.5 / 11.0 / 12.5 / 14.0 x 3 rooms
  (`w4-open`, `w4-ceil`, `w3-ceil`) x 3 rigs (`asfound`, `booth8x`, `booth16x`) x 2
  cameras. The rooms and rigs are a **mechanical** pick — the room as found, the room
  capped, and the 3-sided room capped; the rig as found as a control plus the two booth
  multipliers stage A found viable. Not a look verdict.

## 3. The second null experiment, found and fixed mid-sweep — read this too

**The first run of the two "no sky" rooms was a null experiment, of exactly the same
species as the hidden light tag. I caught it, and re-rendered those twenty frames.**

`WR_LookDev.apply!` wrote `/Environment Sky[intensity_multiplier] = 0.0`. It **read back as
0.0** and it changed the render **not at all** — `w4-nosky` came back identical to `w4-open`
to four decimal places (0.4557 / 0.4557), and `w3-nosky` identical to `w3-open`
(0.5789 / 0.5789). Two arms that cannot legitimately match is what gave it away; nothing
raised, and the settings read back exactly as asked.

`/Environment Sky` is a **`TexSky`**, and its `intensity_multiplier` is not what scales the
environment's contribution to a render. The knob that works is `/SettingsEnvironment`'s
**per-slot multipliers** — `bg_tex_mult`, `gi_tex_mult`, `reflect_tex_mult`,
`refract_tex_mult`, all four together. Proven with a single controlled probe, same frame,
same rig, sun off:

| environment | mean luminance |
|---|---|
| all four multipliers at 1.0 | **0.4557** |
| all four at 0.0 | **0.2741** |

The four multipliers were added to `snap_pairs`, added to the live snapshot **only after
asserting each still read 1.0** (a swept value baked into a snapshot is how a restore lies),
and `sunoff-results.json` now carries a fourth assertion —
`env_multiplier_landed_on_every_frame` — that compares what each frame **asked** for against
what V-Ray **read back**. It is `true`, with an empty exception list — **on the 92 frames that carry the field**. The
other 56 (stage A, and the stage B rooms that are not `nosky`) were rendered before the field
existed, so a naive check would have passed them by saying nothing. They are listed by name in
`assertions.frames_env_multiplier_unrecorded` instead, with a note: all 56 asked for
`env_multiplier` 1.0, which is the as-found value, and the code path they ran **never wrote
`/SettingsEnvironment` at all** — so they were at 1.0 by construction. **Derived, not
measured**, and the file says which.

---

## 4. The numbers — 148 frames, sun off on every one

`frame_count` 148 · mean **12.86 s** · min 2.99 s · max 16.66 s · **1903.5 s** of rendering
total. No frame failed to save. All four assertions clean.

`image-qa` `render` profile throughout: PASS means mean luminance 0.12–0.75 and clipping
under 40%. **That is a mechanical gate, not a look verdict** — several arms that "PASS" are
plainly not the picture you want, and several that fail are failing for one camera only.

### Stage A — the rig alone, sun off, in the room as it is today (EV 12)

The frame that did not exist anywhere in the 68.

| rig | EXT mean / dark | EXT | INT mean / dark | INT |
|---|---|---|---|---|
| **lightsoff** (control) | 0.2310 / 0.127 | PASS | **0.0173 / 0.954** | FAIL |
| asfound | 0.4557 / 0.058 | PASS | 0.0821 / 0.110 | FAIL |
| stdoff | 0.4556 / 0.058 | PASS | 0.0821 / 0.109 | FAIL |
| room050 | 0.3858 / 0.080 | PASS | 0.0733 | FAIL |
| room025 | 0.3345 / 0.091 | PASS | 0.0688 | FAIL |
| room0125 | 0.2852 / 0.097 | PASS | 0.0665 | FAIL |
| room00625 | 0.2593 / 0.101 | PASS | 0.0653 | FAIL |
| boothonly | 0.2333 / 0.115 | PASS | 0.0642 | FAIL |
| **booth4x** | 0.4597 | PASS | 0.2246 / 0.023 | **PASS** |
| **booth8x** | 0.4648 | PASS | 0.3973 / 0.006 | **PASS** |
| **booth16x** | 0.4745 | PASS | 0.6261 / 0.001 | **PASS** |
| room050booth4x | 0.3902 | PASS | 0.2157 | PASS |
| room025booth8x | 0.3475 | PASS | 0.3843 | PASS |

**The `lightsoff` control is the row that matters.** Sun off, sky on, no artificial light:
the *exterior* still reads **0.2310** — that is **half of the as-found exterior**, all of it
sky falling through a roof that is not there. The *interior* reads **0.0173 with 95.4% of the
frame near-black**. So the sky was never lighting the booth interior; it was lighting the
room around it.

**Cutting the room lights still does not help the interior** (0.0821 → 0.0642), exactly as
with the sun on. **Raising the booth fixture is still what makes the interior work.** Taking
the sun away did not change that answer.

### Stage B — the enclosure axis (EV 12, sun off)

`d` is the fraction of the frame near-black.

**Exterior camera** — mean luminance:

| rig | w4-open | w4-ceil | w4-nosky | w3-open | w3-ceil | w3-nosky |
|---|---|---|---|---|---|---|
| asfound | 0.4557 | **0.1385** | 0.2741 | 0.5789 | 0.3314 | 0.2592 |
| boothonly | 0.2333 | 0.0137 FAIL | 0.0020 FAIL | 0.3788 | 0.2155 | 0.0020 FAIL |
| booth4x | 0.4597 | 0.1457 | 0.2782 | 0.5828 | 0.3382 | 0.2633 |
| booth8x | 0.4648 | 0.1550 | 0.2837 | 0.5880 | 0.3469 | 0.2687 |
| booth16x | 0.4745 | 0.1715 | 0.2937 | 0.5975 | 0.3628 | 0.2786 |

**Interior camera** — mean luminance:

| rig | w4-open | w4-ceil | w4-nosky | w3-open | w3-ceil | w3-nosky |
|---|---|---|---|---|---|---|
| asfound | 0.0821 | 0.0559 | 0.0656 | 0.0835 | 0.0579 | 0.0655 |
| boothonly | 0.0642 | 0.0462 | 0.0458 | 0.0657 | 0.0483 | 0.0458 |
| booth4x | 0.2246 | 0.1986 | 0.2080 | 0.2259 | 0.2006 | 0.2079 |
| booth8x | 0.3973 | 0.3722 | 0.3811 | 0.3987 | 0.3741 | 0.3810 |
| booth16x | 0.6261 | 0.6032 | 0.6107 | 0.6274 | 0.6051 | 0.6107 |

Three things fall straight out of those two tables.

**(a) The ceiling is enormous for the room view and almost nothing for the booth interior.**
Capping the four-walled room takes the exterior from 0.4557 to **0.1385** — the open roof was
supplying about **70% of the light in that frame** — while the interior moves 0.0821 to
0.0559, and at `booth16x` only 0.6261 to 0.6032, a **4% change**. The booth is a sealed box;
the sky was never getting into it.

**(b) So the ceiling does NOT change which rig balance wins.** Every one of `booth4x`,
`booth8x`, `booth16x` passes both cameras at EV 12 in **all six rooms**, and their interior
means are the same to within 4% across the whole enclosure axis. **`booth16x` was not
over-corrected for a room flooded with free sky light** — the free sky light was never in the
interior to over-correct for. The `lightsoff` interior at 0.0173 is the proof.

**(c) Removing a wall makes the room BRIGHTER, not darker.** `w3-open` reads 0.5789 against
`w4-open`'s 0.4557, because the missing east wall is another opening for sky. Your 3-sided
drawings are getting *more* free light than the test fixture, not less. Cap a 3-sided room
(`w3-ceil`, 0.3314) and it lands between the open 4-wall room and the capped one.

**What the `nosky` column is and is not.** It is the sky removed at the environment, not
blocked by geometry — it kills the skylight but gives no bounce surface. Read against the
`ceil` column it separates the two: at `boothonly`, `w4-nosky` is 0.0020 (black) while
`w4-ceil` is 0.0137, so the ceiling's own **bounce** is worth roughly 7x the no-bounce floor
there. A camera-invisible ceiling — if V-Ray for SketchUp had one — would land on the `ceil`
numbers with the `open` picture.

### Stage C — the exposure ladder (72 frames, 3 rooms x 3 rigs x 4 EV x 2 cameras)

Combinations where **one exposure serves both cameras**:

| room | rig | EV that works |
|---|---|---|
| **w4-open** (today) | asfound | **11.0** |
| w4-open | booth8x | 11.0, 12.5 |
| w4-open | booth16x | **12.5, 14.0** |
| **w4-ceil** | **asfound** | **9.5** |
| w4-ceil | booth8x | 11.0 |
| w4-ceil | booth16x | 12.5 |
| **w3-ceil** | booth8x | 11.0, 12.5 |
| w3-ceil | booth16x | 12.5 |
| w3-ceil | asfound | *none of the four* |

**The ceiling moves the exposure, not the rig.** Capping the room costs about **1.5 stops**:
every arm's working EV drops by one to two rungs, because the ceiling removed most of the
exterior's light while leaving the interior alone.

Two rows are worth your eye in particular, and I am not choosing between them:

- **`w4-open` + `booth16x` at EV 14.0** keeps the two-stop window the sun-on matrix found, and
  EV 14.0 is within **0.23** of your own untouched camera (f/8 @ 1/300, ISO 100 = EV 14.23).
  Nothing has to be written to `/CameraPhysical`.
- **`w4-ceil` + `asfound` at EV 9.5** is the *only* place in this entire sweep where the rig
  **as you built it** serves both cameras. Put a ceiling on the room and the rig stops needing
  a 16x correction — but the exposure moves 4.7 stops away from your camera, so that one is
  paid for at the camera instead of at the fixture.

**I have not picked.** All 148 thumbnails are on disk and every number above is in the JSON.

## 5. The camera-invisible ceiling — asked, investigated, and it is NOT available

You asked me to find out whether V-Ray for SketchUp actually supports the standard
architectural trick — geometry that blocks and bounces light without appearing in frame —
and to say so plainly if it does not rather than fake it with a hidden tag. **It does not,
on this build. Observed.**

### The mechanism exists in the V-Ray core, and I found it

`VRay::Scene#create(:MtlRenderStats, name)` succeeds, and the plugin it makes carries exactly
the right parameters:

```
MtlRenderStats "..." (material, v23):
    base_mtl = ""            camera_visibility = 1     gi_visibility = 1
    reflections_visibility=1 refractions_visibility=1  shadows_receive = 1
    shadows_visibility = 1   visibility = 1
```

and every real V-Ray material in this scene (`MtlSingleBRDF`) carries an **empty
`renderStats` userdata slot** naming one:

```
MtlSingleBRDF "/WR Sweep Ceiling Matte":
    params:   brdf = ".../BRDFVRayMtl"   scene_name = List("WR Sweep Ceiling Matte")
    userdata: ...  renderStats = "" (s)  ...
```

`camera_visibility = 0` with the rest at 1 is precisely the matte ceiling.

### It cannot be driven from Ruby. Four hangs, four force-kills

| attempt | result |
|---|---|
| `sc.change { sc.delete('/<material bound to live geometry>') }` | **HANGS** |
| `sc.change { rs = sc.create(:MtlRenderStats,n); rs[:camera_visibility]=0 }` | **HANGS** |
| `sc.create(:MtlRenderStats,n)` outside a change, then `rs[:camera_visibility]=0` | **HANGS** |
| `sc.change { rs = sc.create(...); rs[:base_mtl]='/Aluminum'; rs[:camera_visibility]=0 }` | **HANGS** |

Every one of those wedged SketchUp: Ruby stopped answering the bridge, the heartbeat timer
kept ticking, and the process had to be killed. **There was no modal on screen** — I
enumerated the process's windows through `EnumWindows` rather than guessing, and the only
visible windows were the main frame, the VFB and the Ruby Console.

The failure was **isolated**, so this is a claim about one operation and not a shrug:

| probe | result |
|---|---|
| `sc.create(:MtlRenderStats, n)` alone, no writes | **returns, 1.73 s** |
| `sc.change { sc['/Aluminum'][:double_sided] = 1 }` (existing, bound material) | **returns, 0.02 s** |
| write a parameter on a **newly created** material-category plugin | **never returns** |

Two more V-Ray hazards found on the way, both worth adding to the never-do list:

- **`VRay::Scene#delete` on a material plugin bound to live geometry hangs SketchUp.** This
  is what killed the first attempt.
- **V-Ray garbage-collects an unreferenced material plugin between bridge jobs** — an
  `MtlRenderStats` created in one job was simply gone by the next, which is why the
  create-then-write had to be attempted in a single job.

### Nor is it in the product's UI

`.../V-Ray for SketchUp/extension/localisation/languages/en-US.json` carries

```
"objectVisibility": "V-Ray Object Visibility",
"objectVisibilityEnabled": "Enabled",
"objectVisibilityDisabled": "Disabled"
```

and **nothing** for matte, camera visibility, or render stats. `VRay::ObjectProperties`
exposes only `get_object_visibility` / `set_object_visibility` — a **binary** toggle that
removes the object from the render entirely, which produces the same picture as having no
ceiling at all. So there is no checkbox for you to tick either, the way Safe Frame had one.

### What I swept instead, and how it differs

`WR_LookDev.room!` **refuses** `ceiling => 'matte'` by name. Faking it with a hidden tag would
have removed the ceiling from the export — exactly the trap that cost 68 frames — so it is
not faked.

The supported stand-in in the matrix is **`sky_multiplier => 0.0`** (`w4-nosky`, `w3-nosky`):
the free sky light is removed at the environment rather than blocked by geometry. It is
**not the same thing**, and the record says so: it kills the skylight but provides **no bounce
surface**, where a real ceiling both blocks and bounces. So the two arms **bracket** the
matte ceiling — a matte ceiling would carry the light of the `ceil` arm and the picture of
the `open` arm. Between the `ceil` and `nosky` columns you can read off how much of the
ceiling's contribution is blocking and how much is bounce.

## 6. What changed in the repo

| File | What |
|---|---|
| `scripts/lookdev-matrix.rb` | **extended, not forked** — `out_dir=` so a second sweep gets a second folder; `room!` / `ensure_ceiling!` / `remove_ceiling!` / `room_measured`; `assert_lights_visible!` and its call site in `frame!`; wall and ceiling state in `capture!` and `restore!`; `MATTE_SUPPORTED = false` with the four hangs recorded at the site |
| `scripts/sunoff-drive.py` | **new** — composes this matrix, runs it one frame per bridge job, joins `image-qa`, writes `sunoff-results.json` with the `assertions` block |
| `DEVLOG.md` | this entry |
| `.forge/builder/sunoff-results.json` | the record |

**No change to `scripts/proposal-package.rb`** — another agent is auditing it read-only, and
nothing here needed it.

**On the version number.** The brief said VERSION was at 1.9.4 and to use 1.9.5. It is
already at **1.9.6** on `main` — 1.9.6 landed today from the audit-fix pass — and nothing in
this work changes plugin behaviour, only the dev harness under `scripts/`, so **VERSION is
untouched at 1.9.6.** Flagging it rather than bumping past a number I did not earn.

## 7. Model state — restored, and verified against a record I did not write during the sweep

The predecessor's `restore!` once reported "restored clean" while putting back the wrong
values, because `capture!` had been re-run mid-sweep. So the check here does not trust
`restore!`'s own word:

1. **Before** anything moved, I read the model independently through the bridge and kept that
   text — V-Ray settings, all nine light intensities, all six `shadow_info` keys, every tag's
   visibility, every wall group's hidden-ness.
2. `capture!` then took the harness snapshot. The two agree key for key (I diffed them).
3. **After** the last frame, `restore!` ran, and then I re-read the model with the **same
   independent probe** and compared it to step 1.

`restore!` said `restored clean (69 keys put back)` — and **it was not quite true**, which is
the point of step 3. The independent read caught **37 SketchUp materials where the model was
found with 36**: erasing the sweep's ceiling group leaves its material behind. I removed it
(`36` again, verified) and `restore!` now removes it too, with its own read-back check.

Everything else matched the as-found record **exactly**, key by key:

| | as found | after restore |
|---|---|---|
| `/SettingsOutput` | 1600 x 900, `show_safe_frames` false | same |
| sampler | `progressive_maxTime` 0.0, threshold 0.04, maxSubdivs 20, min_shade_rate 6 | same |
| `/CameraPhysical` | f/8, ISO 100, shutter 300 | same |
| `/SunLight` | enabled true, multiplier 1.0 | same |
| `/Environment Sky` | `intensity_multiplier` 1.0 | same |
| `/SettingsEnvironment` | all four `*_tex_mult` 1.0 | same |
| denoiser | false | same |
| all nine light intensities | 426.64 x4, 120 x2, 106.8, 480, 2500 | same |
| `shadow_info` | 2026-11-08 08:30:00 -0500, North 0.0, Lat 40.018309, Lon -105.242139, TZ -7.0, Boulder (CO) | same |
| tags | `WR Lights` **hidden**, the only hidden tag | same |
| walls | all eleven wall groups visible | same |
| ceiling | no `WR Sweep Ceiling` group | none |
| materials | 36 | **36** (after the fix above) |

No V-Ray plugin named `Sweep` remains in the scene. The model was **never saved** during the
sweep, so nothing reached disk in any case.

## 8. Deviations, and what went wrong

- **SketchUp was force-killed and restarted four times**, every one of them chasing the
  camera-invisible ceiling. Nothing was lost: the scratch model was never saved during the
  sweep, so each restart reopened
  `Desktop\BridgeTest-lookdev\_recovery\Untitled-recovered.skp` clean — verified against the
  independent as-found record each time.
- **SketchUp is still open on `Untitled-recovered.skp`, not the original `Untitled`.** That
  is inherited from the predecessor's recovery, unchanged by me.
- **The exterior camera is not outside the room.** Its eye is at x = 232, inside the east
  wall at x = 240. That is why the 3-sided arm removes the east wall rather than a wall in
  frame, and it is worth knowing before anyone reads "exterior" as "outdoors".
- **`Untitled-recovered.skp` was never saved.** Anything the sweep put into the V-Ray scene
  in memory that could not safely be deleted stays only in memory.
