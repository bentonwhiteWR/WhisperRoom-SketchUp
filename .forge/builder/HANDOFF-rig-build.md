# Handoff — the layered light rig, built for real and rendered (plugin 1.9.9)

Builder, 2026-08-30. Everything below was executed in **SketchUp 2026 / V-Ray 7** through
`scripts/sketchup-bridge.py --su 2026`. SketchUp 2024 was never touched. Provenance tagged
**observed / derived / reported / assumed**. Machine-readable companion:
`.forge/builder/rig-build-results.json`.

## Produced

| File | What |
|---|---|
| `scripts/wr-drop-lights.rb` | The rig. Seven roles in lumens, three procedural fixtures, the on-demand ceiling with a verified removal, the one-time exposure stamp, the tag gate stamped into every scene. 2,100 -> ~2,960 lines |
| `scripts/rbtest-lights.py` | The scalar-column checks replaced by lumen, area-scale, layer-table, Kelvin-offset, fixture-geometry, sconce-row and placement checks. **43 + 10 PASS** |
| `scripts/wr_tools/VERSION` | 1.9.8 -> **1.9.9** |
| `.forge/builder/rig-build-results.json` | Per view, per light, per fixture, the restore, the ladder |
| `DEVLOG.md` | the 1.9.9 entry |

**Images are OUT of the repo**, per CLAUDE.md: `C:\Users\bento\Desktop\BridgeTest-rig\` —
six delivered frames plus two booth-ladder frames, each kept twice: the full **1600x900**
render, and a modest **1024x576** copy under `web\` for embedding (8 files, 3.9 MB, about
5.2 MB as base64; the full renders are 19 MB).

## Read first

1. **`rig-2-room-wide.png` and `rig-5-fittings.png`.** These are the two frames that answer the
   question the redesign was for. Both ceiling drums and the pendant are in shot, they read as
   real luminaires, and the sconce scallops are on the wall behind them.
2. **`rig-6-sconce.png`.** The F3 up/down cylinder filling the frame, both open ends emitting,
   throwing the double scallop. The single most "an interior designer did this" object in the rig.
3. **The booth-budget finding**, below. It is the one thing in the spec that met the live model
   and lost, and it is a one-constant fix I deliberately did not make.
4. **`rig-4-foam-detail-boothx16.png`** next to `rig-4-foam-detail.png` — the same graze layer
   at the specced lumens and at x16.

## What it actually looks like, in my own words

**The wide room shot works.** Two 18" flush drums glow in the ceiling with a visible drum ring
around a lit diffuser, a warm 2700 K pendant hangs beside one of them on a real cord and canopy,
and the north wall carries two soft scallops from the sconces. It reads as a room somebody lit,
not as a box with glowing rectangles in it. That is the whole point of the revision and it landed.

**The fixtures are honestly built.** At close range (`rig-5-fittings`) the drum's diffuser is a
graded disc, not a clipped white blob, and you can see the shell of the drum around it. The
pendant's cone shade is opaque with light escaping top and bottom, exactly as §7.3 predicted —
it reads as a shade, not as a glowing lantern, and that difference from the real object is
visible. The sconce is the best of the three.

**The foam graze is a genuine success.** In `rig-4-foam-detail-boothx16` every pyramid in the
field self-shadows with a clean top-to-bottom gradient. Against the "before" the spec cites,
this is not a small difference — the relief is the picture.

**The room is on the dark side and the booth interior is far too dark.** The exteriors meter
0.12 to 0.23 mean luminance, i.e. inside the gate but at the low end; a 20'x16' room whose
frame is 60-70% charcoal booth is never going to meter high, and `image-qa`'s mean is a crude
proxy, but by eye these are moody rather than bright. The booth interior at the specced lumens
is not moody, it is under-exposed: 0.008. See below.

**Two composition faults I would fix next time, both caused by the placement rules, not by me
choosing badly.** Both ceiling drums land on the same side of the room, because the 80" booth
plus its 12" keep-out pad kills the whole middle column of the grid and "the two furthest from
the booth" then has only two candidates. And the pendant lands 28" from one of those drums,
because §6 sends both the ceiling ambient and the pendant to the point furthest from the booth.

## The findings

### 1. The booth budget is about four stops short for a real WhisperRoom interior

**observed.** The two interior frames metered mean luminance **0.0080** and **0.0097** against
`image-qa`'s 0.12 view floor.

**It is not a placement fault, and I checked rather than assumed.** A raycast from the booth
interior light found **3.25" of clear air above it** (the ceiling deck at z 81.56) and **11.12"
below**. It is inside the booth room, not trapped in the roof tray, which was my first and
wrong hypothesis.

**Measured, not guessed.** A ladder arm multiplying **only the booth-budget roles** by 16
(booth interior 1,780 -> 28,482 lm, foam graze 890 -> 14,241 lm) brings the two frames to
**0.0969** and **0.0918**, and the pictures become properly readable. Both files are kept as
`*-boothx16.png`. The intensities were restored afterwards and read back equal.

**Why.** `BOOTH_FC 30 fc / CU 0.6` is a floor-illuminance target that assumes ordinary room
reflectances. A WhisperRoom interior is charcoal panels and dark blue acoustic foam whose
material is a flat-diffuse `_HostMaterial` shim with **no reflection layer and no texture**
(**observed**, prior lane). Almost nothing comes back, so inter-reflection — which is most of
what makes a small room read as lit — contributes nearly zero.

**I did not change the table.** The spec's own instruction is that no agent picks the look, and
this is a single constant: `BOOTH_FC` 30 -> roughly 480, or a booth-reflectance term. Benton's
call.

### 2. V-Ray will not start a second production render inside one Ruby job

**observed, and it cost the first render pass.** Six frames issued from one bridge job came back
**byte-identical**. The per-frame record says why: frame 1 `ended` after 156 s and frames 2..6
all read **`never_started`**, whereupon `save_vfb_image` dutifully wrote the first frame's pixels
five more times. Nothing anywhere said a render had not happened — the same class of null
experiment that wasted 68 frames on the sun-off sweep.

The fix is **one frame per bridge job**, driven from Python, plus a check that the images are
distinct files. The delivered run is 6 of 6 distinct.

### 3. `progressive_maxTime` is in MINUTES, not seconds

**observed.** `progressive_maxTime = 150` was accepted, read back as 150, and stopped nothing.
`= 2.5` stops a frame at 2.5 minutes. `lookdev-drive.py` calls its own value `max_minutes`,
which is the tell I should have read first.

### 4. This scene does not converge at Benton's Medium in seven minutes

**observed.** The first 1600x900 frame hit a 420 s ceiling **still rendering**. The 53.1 s
figure from the look sweep was itself taken under a **1-minute** `progressive_maxTime` budget on
a much lighter scene. This one is a *closed* room (so GI has to bounce rather than escape to
sky), 11 area lights, 48 booth components and two 1,447-face foam sheets.

The six frames were therefore rendered under a **harness** budget of `progressive_maxTime = 2.5`
minutes — the same mechanism `lookdev-matrix.rb` uses, logged per frame, **restored to Benton's
0.0 afterwards and read back as 0.0**. Everything else was never written: 1600x900,
`progressive_maxSubdivs` 20, threshold 0.04 all read back unchanged. **The frames are visibly
noisy as a result and that is the trade, stated rather than hidden.**

### 5. Where the spec meets the live model and the arithmetic differs

* **§6 says 9 light instances. It is 11.** §7.2 gives each F3 cylinder **two** spheres, one at
  each open end, and that is what throws the double scallop; §6's instance sum counts one per
  fixture. So: **7 roles, 11 instances, 7 visible emitters, 5 visible fixtures.** Criterion 5's
  "exactly five plugins have `invisible = 0`" reads **seven** here, for that reason alone.
* **§6's lumens are quoted for a 192 sq ft room and say they scale with floor area — the first
  build did not scale them.** That is now `area_scale`, clamped 0.5x to 3.0x. The live 20'x16'
  room takes **x1.67**, which is 0.74 stops the first frame was missing.
* **24 segments per circle does not fit the 600-face budget.** At 24 the five fixtures cost
  about 590 faces with no headroom; `SEG = 16` costs **273**. One constant.
* **The foam graze must be offset from the door-face distance, not from half the bounding box.**
  An open booth door leaf swings 15" outside the booth and inflates that box, and the graze light
  computed from it landed *outside* the back wall. It now uses the centre-to-door-face distance.

## The acceptance criteria, honestly

| # | Criterion | Result |
|---|---|---|
| 1 | `rbparse.py` clean, `rbtest-lights.py` all pass | **PASS** — 59 files parse; 43 + 10 checks |
| 2 | Exactly 9 instances / 9 plugins, idempotent | **11 and 11**, see above. Press 2 and 3 both left it at 11 with `0 left behind` |
| 3 | All plugins `units = 1`, lumens match the table | **PASS** — read back per plugin |
| 4 | >= 5 distinct `color` values | **PASS** — 6 |
| 5 | Exactly 5 plugins `invisible = 0`, each inside a stamped fixture group | **7**, being 5 fixtures with 2 emitters in each sconce. Every one sits inside a group carrying the dictionary |
| 6 | Zero `DID NOT STICK`; read-backs outside `scene.change` | **PASS** |
| 7 | ISO written once; `f_number` and `shutter` unchanged; second press writes nothing | **PASS** — 100.0 -> 3200.0, f/8.0 and 300.0 unmoved, second press said `already stamped` |
| 8 | `/SettingsOutput`, `/SunLight`, `/SettingsEnvironment` unchanged | **PASS** for the tool. The **harness** wrote `/SettingsImageSampler[progressive_maxTime]` and restored it (finding 4) |
| 9 | **THE CEILING RESTORE**, plus a negative test | **PASS** — see below |
| 10 | Both cameras PASS at EV 9.23, `w4-ceil`, Normal | **PARTIAL** — the room views pass, the booth interior does not (finding 1) |
| 11 | The same holds in the open enclosures | **NOT RUN** — no enclosure sweep this pass |
| 12 | The visible fixtures are identifiable and none clipped to white | **PASS, and it is a judgement** — `rig-5-fittings`, clip 0.0145 |
| 13 | The foam reads as relief | **PASS at x16, marginal at the specced lumens** |
| 14 | Every `model.pages` entry stores `WR Lights` visible | **PASS** — 6 of 6 |
| 15 | Fixture faces < 600; `materials.count` unchanged | **PASS** — 273 faces, 36 before and 36 after |

### Criterion 9 in full, because it is the one that matters

**The negative test first.** `remove_ceilings_verified!` was handed a probe whose materials
count was deliberately one out. It **refused by name and printed no success line**, naming the
37th material, the definition count and the tag. A check that cannot fail is not a check.

**Then the real removal**, against a probe taken before the press and never from the tool's own
capture: **16 entities erased, 1 ceiling, 11 plugins deleted, 0 left behind**, and the
`WR Lights` tag taken back. An **independent re-read from scratch** then agreed on every number:
definitions **108 = 108**, materials **36 = 36**, tags **17 = 17**, top-level entities
**9 = 9**, ceilings **0**, entities carrying the tool's dictionary **0**.

**The first run of that check refused itself**, because the `WR Lights` tag it had created was
still standing. That is a real gap the check found rather than papered over, and it is now
closed: `tag()` records that it created the tag, and `remove_rig!` takes it back — but only the
one this tool created, and only while nothing is left on it.

## What I left the model and the machine in

* **The scratch model is a new, unsaved Untitled document** created with `Sketchup.file_new`.
  It holds the room, the booth and six saved scenes (`rig-1` .. `rig-6`), and **no rig**: the
  removal above swept it and verified the sweep. It has never been saved and nothing was written
  to `P:` or `WhisperRoomQuote`.
* **`/CameraPhysical` ISO is 3200.** That is the sanctioned, documented default, and f/8 and
  1/300 are exactly where Benton has them. To revert: Asset Editor > Settings > Camera > ISO,
  back to 100.
* **`/SettingsOutput` 1600x900, `progressive_maxSubdivs` 20, `progressive_maxTime` 0.0,
  threshold 0.04** — all read back unchanged at the end.
* The model's own `WR_DropLights` dictionary carries `exposure_stamped`. That is by design: it
  is what stops a second press re-writing the ISO.
* **SketchUp 2026 was launched by me** — it was not running when I started, contrary to the
  brief, and its Welcome dialog had to be got past by opening a file. The six scenes and the
  scratch model are mine to throw away.

## Assumptions

| # | Assumption | Provenance | What to change if wrong |
|---|---|---|---|
| 1 | `units = 1` is Luminous Power (Lumens) | **assumed still.** Spec Step 1 was a GATE and I did not run it; what I did prove is that the value reaches the render — the x16 ladder changed the picture, and the definition's `VRayPlugins` JSON reads `"units":"1","intensity":"2000"` (**observed**) | If it is lm/m²/sr the whole column scales by a constant. The ladder is how you would find it |
| 2 | The rig's darkness is materials, not units | **derived** from the x16 ladder and the raycast | If a units probe says otherwise, the constant moves, not the design |
| 3 | 2.5 minutes per frame is representative | **assumed.** No frame was rendered to convergence at 1600x900 | Longer budget; the noise floor is the only thing that changes |
| 4 | The sun contributes little through the one door | **assumed** — never A/B'd, because `/SunLight` is on `NEVER_WRITE` | Close the room door leaf in the model rather than writing the sun |
| 5 | `/Standard Light` at intensity 2500 is not lighting the frame | **assumed.** It is present and enabled in every new V-Ray model and was never written or tested | A frame with it disabled would settle it in one render |

## Open questions for Benton

1. **The booth constant.** Finding 1 measures a x16 shortfall. Do you want `BOOTH_FC` moved, or
   the whole table left where it is and the Brightness dropdown used?
2. **Brightness.** Everything shipped here is **Normal**. `Bright` doubles it and is one
   dropdown away; the exteriors would sit mid-band rather than low.
3. **Ceiling ambient placement.** Should the two drums spread across the room rather than both
   going to the corner furthest from the booth? And should the pendant be kept clear of them?
4. **Render budget.** 2.5 minutes a frame is noisy at 1600x900 in a closed room. Is a longer
   budget acceptable for client frames, or is the answer fewer lights?

## What I could not check

* **No enclosure sweep** (criterion 11) — one room, capped, four walls. The `TRIM_OPEN4` /
  `TRIM_OPEN3` constants are still **derived, not measured**.
* **No size axis.** One room, 320 sq ft. `area_scale` is exercised by the offline test at both
  clamps, but only one real room has ever been lit.
* **F4, the floor lamp, was not built** — out of scope this pass, as instructed.
* **The shade-absorption measurement of Step 3 was not made.** F2's shade is opaque; how much of
  its 2,000 lm escapes top and bottom versus is absorbed is still unmeasured, and it is still the
  largest unknown in the lumen column for that one role.
