# Audit — why "Drop Interior Lights" produces inconsistent results

Auditor, 2026-08-28. READ-ONLY pass; no code changed. **Nothing here was executed in
SketchUp — there is no SketchUp and no ruby.exe on this machine.** Every claim is tagged
observed (read the code/doc myself), derived, reported, or assumed. Confidence is stated
at the weakest link.

## The outcome in three sentences

The placement geometry is the *consistent* half of this tool; the inconsistency lives in
everything **around** the placed instances — none of which the tool controls, and several
of which silently override each other. The single biggest engine is that **saved scenes
re-apply their own stored tag visibility and sun position every time they are activated**
(`proposal-scenes.rb:220-226` sets `use_hidden_layers = true` and `use_shadow_info = true`
— observed), so a render's lighting depends on the *state the model was in when that scene
was captured*, overriding the mode toggle, the sun aim, and the tag-forcing in
`wr-drop-lights.rb` — which is sufficient, on its own, to make two renders of the same
model minutes apart come out one warm and one black-and-blue, exactly the 28 Aug pair.
Close behind: the tool's Brightness/Warmth/exposure controls **write nothing** (printed
advice only — observed, the V-RAY WRITE SEAM), so actual emission is whatever the shared
per-model Asset Editor slider was last dragged to — a value Benton is observed (researcher
doc) to have set to 30,000 lm, 10× spec, during debugging — and exposure stays at V-Ray's
EV 14.2 sun default unless set by hand, which makes any interior-dominated frame 30-60×
too dark regardless of the rig.

===DETAIL===

## 0. What was read (all observed)

- `scripts/wr-drop-lights.rb` — all 2,041 lines.
- `scripts/wr-mode.rb` (364 lines), `scripts/wr-sun-aim.rb` (header + elevation/offset
  machinery), `scripts/proposal-scenes.rb` (scene-capture block), `scripts/proposal-package.rb`
  (mode-toggle vs scene-activation order in the render lane).
- `.forge/researcher/interior-lighting-design.md`, `vray-light-creation.md`,
  `interior-lighting-options.md` (grep), `HANDOFF-light-creation.md`,
  `HANDOFF-lighting-design.md`, `.forge/GOAL.md`.
- `git log --oneline` for the three scripts; seed files on disk
  (`WR Light Booth.skp`, `WR Light Downlight.skp`, `WR Light Wallwash.skp` present;
  **`WR Light Accent.skp` absent** — observed via `ls`).

## 1. The one real data point, explained

**Observed (relayed in the assignment, PNGs seen by the caller):** 28 Aug, same model,
same session — a booth-interior render came out very dark with a heavy blue cast; a
four-room overview shortly after was warm and well exposed. `wr-sun-aim.rb` ran during
the dark render (console log).

**Derived explanation, consistent with every mechanism below:** in the dark frame the
dropped rig did not emit (or emitted trivially against the exposure), so the only
illumination was **sky through the open room tops, filtered into the booth** — SketchUp/
V-Ray sky is ~blue; sky-only illumination at interior light levels against EV 14.2 is
precisely "very dark, heavily blue, night scene." The overview frame is dominated by
direct **sun**, which is warm and bright enough to expose correctly at EV 14.2. So the two
frames don't disagree — they are the same wrong configuration seen from two viewpoints:
one where the sun does the work, one where the rig was supposed to and didn't. Which
mechanism suppressed the rig in that frame is candidate 1, 3, 4, or 5 below; the five-
minute checks separate them. Confidence: **medium** — the causal chain is derived, not
rendered; the weakest link is the reported claim that V-Ray excludes hidden-tag lights
(Chaos help article + forum, never confirmed live — `vray-light-creation.md`).

## 2. Ranked candidate mechanisms

Ranked by probability × explanatory power. "Check" = under five minutes in live SketchUp.

### C1 — Scenes override everything: stored tag visibility + stored sun (TOP)

- **What:** every scene made by `proposal-scenes.rb` is captured with
  `use_hidden_layers = true` and `use_shadow_info = true` (**observed**,
  `scripts/proposal-scenes.rb:221,223`). Activating a scene therefore re-applies the
  `WR Lights` tag visibility and the sun position **as of the moment that scene was
  captured** — after, and on top of, anything `wr-mode.rb`, `wr-sun-aim.rb`, or
  `wr-drop-lights.rb`'s tag-forcing (`wr-drop-lights.rb:1016-1033`) just did. The batch
  render lane does mode toggle first, `selected_page =` second
  (**observed**, `proposal-package.rb:708` vs `:813`), so scene state wins there too.
  A manual render after clicking a scene tab is identically exposed.
- **Symptom it produces:** per-scene lottery. Scenes captured while the model was in
  draft mode (tag hidden) or before the rig existed render unlit; scenes captured in
  render mode render lit. Sun aimed with "Light It From Here" holds only until the next
  scene click, then snaps back to that scene's stored sun. Same model, same session,
  some frames warm, some black-blue — the observed pair.
- **Likelihood:** high. This is the only mechanism found that *by construction* differs
  per scene within one session.
- **Check (2 min):** click the scene tab that produced the dark render; open the Tags
  tray and read the `WR Lights` visibility box; open Window > Shadows and read the
  time/north. Click the overview scene and read both again. If they differ, this is it.
- **Known unknown (assumed):** how SketchUp treats a tag **created after** a scene was
  captured (visible or hidden when that older scene is activated) is version-dependent
  behavior I could not verify here. The check above answers it for this model.

### C2 — The dialog's Brightness/Warmth/exposure do nothing; the shared asset slider does everything

- **What:** the pop-up offers Density/Brightness/Warmth/Layers/exposure, but Brightness,
  Warmth and exposure are only **printed** as an Asset Editor recipe
  (**observed** — header "BRIGHTNESS / WARMTH / EXPOSURE ARE PRINTED, NOT WRITTEN",
  `wr-drop-lights.rb:112-127`, and `print_asset_advice`, `:1511-1529`, the V-RAY WRITE
  SEAM). Actual emission per layer = whatever that seed's ONE shared V-Ray asset slider
  is set to **in this model** — copies share one asset by design (`:30-39`). A manual
  slider change persists in the model file and silently applies to every copy and every
  future press; a different model has a different slider value; the seed `.skp` files on
  disk carry whatever the *source light* had when minted, not necessarily the spec's
  3,000/1,500/1,000 lm (**observed** — minting "does NOT set" sizes/intensities,
  `:66-70`, `print_mint_recipe :925-938`).
- **Live evidence:** Benton had the downlight asset at **30,000 lm** on 27 Aug
  (**observed** in `vray-light-creation.md`, Suspect 4) — 10× the spec value, set while
  debugging darkness. If that stuck in the model, every subsequent lit render is 10×
  over target; in a fresh model it isn't.
- **Symptom:** "Bright"/"Dim" appear to do nothing; identical presses in two models give
  wildly different brightness; "sometimes way too bright" after a debugging session.
- **Likelihood:** high — this is not a bug, it is the designed seam, but it is exactly
  what "HIGHLY inconsistent" feels like from the operator's chair.
- **Check (2 min):** Asset Editor > Lights: read the intensity of each `WR Light *`
  asset in the current model and compare to the console's printed targets from the last
  press. Any mismatch is live inconsistency.

### C3 — Exposure is nobody's job: EV 14.2 vs the needed ~EV 8

- **What:** V-Ray's default physical-camera exposure is EV 14.2 (full-sun exterior);
  a correct 40 fc interior at that EV is 30-60× underexposed (**reported**, design doc
  §1.4 with sources; the arithmetic is derived). The tool only prints "set EV 8"
  (**observed**, `:1524-1527`); nothing in the repo writes it; whether it *can* be
  written from Ruby is the un-run §3.3 probe (**reported/open**). So exposure is a
  per-model, per-session hand setting — and Auto Exposure, if enabled, re-decides per
  frame.
- **Symptom:** interior-dominated frames dark, sun-dominated frames fine — in the same
  model with identical lights. Exactly the observed pair's brightness split.
- **Likelihood:** high as a *contributor*; it cannot explain a blue cast alone.
- **Check (1 min):** Asset Editor > Settings > Camera: read Exposure Value / Auto
  Exposure in the model that produced the dark render.

### C4 — Draft/render mode polarity at render time

- **What:** `wr-mode.rb` hides `WR Lights` in draft, shows it in render (**observed**,
  LIGHT_TAGS + pin_light_tags). Placement now forces the tag visible (**observed**,
  `wr-drop-lights.rb:1016-1033`, the documented 1.7.3/1.7.4 regression fix), but a later
  draft toggle re-hides it, and a manual V-Ray render from a draft-mode model renders
  unlit (**reported** that V-Ray skips hidden-tag lights — still never confirmed live;
  Probe A2 in `vray-light-creation.md` remains un-run per the record read here).
- **Symptom:** renders lit or unlit depending on which mode the model happened to be in
  — invisible in the viewport because the lights are Invisible=ON anyway.
- **Likelihood:** medium-high; four commits have circled it (`2f48a6e`, `c5b2cd2`,
  `8cf7c5f`, `26d3f7b` — observed in git log), which per the assignment's own heuristic
  suggests the class was real but the render-time end (and C1's scene override of it)
  was never closed — only the placement-time end was.
- **Check (1 min):** before rendering, read the `WR Lights` box in the Tags tray. Or run
  Probe A2 (`vray-light-creation.md` Part 2) — it is still the decisive one-paste test.

### C5 — Dead seeds: a seed emits only where its named plugin exists

- **What:** a seed `.skp` points at a V-Ray scene plugin by name
  (`VRayInfo["main_plugin"]`); in a model whose V-Ray scene lacks that plugin the lights
  place, list in the Asset Editor, and emit nothing (**observed live 27 Aug**, per the
  file's own header `:84-109`). The 1.7.8+ code refuses dangling seeds by name
  (**observed**, `:1630-1677`) — but the `:unknown` verdict (scene unreadable) **places
  anyway** with a console warning (`:1654-1656`), and the pre-check depends on V-Ray
  being loaded and answering. So the same press is verified in one session and
  unverified in another.
- **Symptom:** per-*model* (not per-scene) total darkness from the rig with everything
  else looking right; the classic "worked in the model it was minted in, dead in the
  next one."
- **Likelihood:** medium — largely hardened, but the unknown-path placement and any
  model the seeds weren't minted/pasted into keep it alive.
- **Check (1 min):** re-press the button and read the "WILL IT EMIT" bottom line
  (**observed**, `:2011-2022`). "UNVERIFIED" or "probably" = this candidate is open.

### C6 — Sun aim is camera-of-the-moment, and fights the scene cameras

- **What:** `wr-sun-aim.rb` writes the model's **live** shadow_info from the **current**
  camera — azimuth and elevation (**observed**, header + `light_it_from_here`). It
  deliberately does not touch scene-stored shadow info (**observed**, header §2). Run it
  on one view, then render a different scene (or re-click any scene tab — C1), and the
  sun is aimed for the wrong view or silently replaced. Additionally `SUN_BEHIND_CAMERA
  = true` is flagged in the file itself as an unverified derived choice (**observed**,
  `:94-98, :223`), and whether V-Ray's SunLight even follows SketchUp shadow_info is an
  open question the script states it does not answer (**observed**, header).
- **Symptom:** the sun lights the intended shot only when sun-aim was the *last* thing
  run before render with no scene click in between — order-dependent lighting; it ran
  during the observed dark render.
- **Likelihood:** medium-high as an interaction amplifier of C1; low as a sole cause of
  a *blue* interior.
- **Check (2 min):** aim, note the Shadows-dialog time, click the target scene tab, read
  the time again. If it changed, aim and scenes are fighting (this is C1's check from
  the other side).

### C7 — Idempotency: stacking is possible across drawing contexts

- **What:** re-press cleanup searches `model.active_entities` only, non-recursively
  (**observed**, `stale_lights :1063-1069` over `ents = model.active_entities :1679`),
  for lights whose origin lies inside the currently selected subjects' bounding boxes.
  Two gaps (both derived):
  1. Lights placed while a group was open for edit live *inside that group*; a later
     press from the top level cannot see or remove them → **stacked duplicates**, i.e.
     double brightness in the render but near-invisible in the viewport
     (Invisible=ON assets).
  2. `DROP = 0.0` mounts room lights **flush** with the wall top (**observed**, `:200`),
     i.e. their origins sit exactly on the room bbox's max-z face; whether
     `BoundingBox#contains?` includes the boundary under floating-point equality decides
     whether a re-press finds them. **Assumed risk, unverified** — if exclusive or
     epsilon-off, every re-press doubles the grid.
  3. Cleanup is scoped to the selection: pressing on room A then later on room B leaves
     A's lights (intended), but pressing on A with different Density stacks nothing yet
     *replaces* — only if the old ones are findable per (1)/(2).
- **Symptom:** "sometimes way too bright," growing worse with repeated pressing;
  brightness differs with where in the model hierarchy the press happened.
- **Check (3 min):** after two presses on the same room, Asset Editor > Lights or
  the Outliner filtered to `WR Light` — count instances vs the console's "N lights"
  line; or select-all on the `WR Lights` tag and read the count.

### C8 — Fixed seed lumens vs. computed targets: Density and room size change the target, never the light

- **What:** per-fixture targets are computed from area/count/multiplier (**observed**,
  `downlight_lumens :516-519`) but never applied (C2); the seeds are fixed-lm. The
  design doc itself states Showroom density "overshoots by ~3×" until the slider is
  nudged (**observed** in `interior-lighting-design.md` §2.3). Rooms in the live model
  span 249-445 sf (**reported**, assignment); with several rooms in one press the tool
  prints a single *averaged* slider target per seed (**observed**, `:1996-2005`), so no
  single slider value is right for every room.
- **Symptom:** Showroom grid renders ~3-4× brighter than Soft; the largest room reads
  dimmer than the smallest relative to intent; nudging the slider "for" one room
  un-tunes the others.
- **Likelihood:** medium — real, bounded, and by design; reads as inconsistency.
- **Check (2 min):** compare the console's per-room "target N lm" lines from one press
  against the single asset slider value.

### C9 — Selection dependence and door-detection variance

- **What (all observed in code):**
  - A booth selected *alone* gets only the interior light (`:1736-1761`); the same booth
    with its room selected gets the full rig. Result changes with what was selected.
  - Untagged booths are recognized by a size band (30-190" sides, 78-94" tall,
    `:251-254`); a booth on a 5" caster plate (~90") is inside, but anything outside the
    band silently loses its booth/accent layers (a console line says so — loud, but easy
    to miss).
  - Wall-wash wall choice depends on door detection, which has three mechanisms plus a
    longest-wall fallback (`room_info :1166-1226`, wash block `:1868-1893`); rooms built
    by different generators wash different walls, and a bbox-fallback room *with* no
    door is refused entirely by the multi-fallback rule (`fallback_verdict :549-562`).
- **Symptom:** the wash lands on different walls in near-identical rooms; some rooms
  refuse while their neighbors place; booth layers appear/disappear with selection.
- **Likelihood:** medium-low for the complaint as voiced, but it is the mechanism most
  likely behind "the tool does something different every time I press it."
- **Check:** read the per-room console lines — the tool already names every mechanism
  and fallback it used (this part of the design is good).

### C10 — Latent/minor
- **Accent seed absent** (`WR Light Accent.skp` — observed missing): the accent layer is
  always skipped today; the day it is authored, every render gains a 6,000 lm tilted
  light and past/future renders stop matching. Deterministic now, a step-change later.
- **Sticky dialog defaults:** `@last` persists across presses within a session
  (**observed**, `ask :1478-1479`) but resets on restart — the same "just press OK"
  gesture means different settings on different days.
- **BOOTH_DROP = 6" is an assumed tray thickness** (**observed**, `:207-211`): if the
  real tray is thicker, the booth interior light sits inside the ceiling solid and emits
  into it — a specifically-black booth interior, which is what the dark render showed.
  Check: select the booth interior light, read its Z against the tray underside.

## 3. Spec-vs-code gaps (design doc says, code does not)

- **§3.2/§3.3 probe fork never resolved:** the dialog ships the Brightness/Warmth/
  exposure controls in "advice" form; the probe that decides whether they can be real is
  still un-run (GOAL.md and the design doc both say so — reported). Until it runs, C2
  and C3 are permanent.
- **§2.4 "which wall, default auto"** — the design allows re-aiming the wash; the code
  offers no control, only the auto choice (minor).
- Everything else in §2 is faithfully implemented, including the L-shape handling,
  centred grid, keep-outs, and the refusal table — the placement math is *not* where
  the inconsistency lives (derived from the code read; also exercised outside SketchUp
  by `rbtest-lights.py` per the file header — reported).

## 4. Why four fixes didn't kill it

The commit series ("never light a light" → "placement never hides the tag" → "refuse
dead seeds" → "say whether it will emit") each hardened **placement time**. But emission
is decided at **render time**, by state the placement code cannot pin: scene-stored tag
visibility and sun (C1), the shared asset slider (C2), camera exposure (C3), the live
mode (C4). Every fix moved the guard earlier while the failure stayed later — which is
exactly the signature the assignment predicted for "a bug fixed four times."

## 5. Recommended fix (recommendation only — no code changed)

1. **Close the render-time seam, not another placement-time one.** A single "render
   preflight" that runs at render/scene-activation time and reports (or pins): WR Lights
   tag visible, per-scene stored visibility for that tag, asset intensities vs printed
   targets, EV value, sun azimuth vs active camera. Most of the pieces exist
   (`wr-preflight.rb` is referenced by wr-mode — not audited here).
2. **Make scenes and the light tag agree:** either update every page's stored
   `WR Lights` visibility when placing/toggling (one loop over `model.pages`), or stop
   scenes from owning that tag. This kills C1's tag half.
3. **Run the §3.3 probe** (Benton, ~3 min, already written in
   `interior-lighting-design.md`) — it decides once whether Brightness/Warmth/EV can be
   written, converting C2/C3 from permanent seams into one build task.
4. Decide the sun policy: either sun-aim also stamps the target scene's shadow_info
   (with Benton's consent per scene), or renders always use live shadow — one owner.
5. Add a stale-light sweep that searches recursively (definition-instances of the seed
   names), closing C7 regardless of drawing context.

Numbers needed from Benton before any of this ships: the real tray-ceiling thickness
(BOOTH_DROP), and his characterization of "inconsistent" — the table in §2 maps each
likely phrasing to a candidate so the answer lands on a mechanism immediately.

## 6. Gaps — stated as prominently as the findings

- **Nothing was executed.** No SketchUp, no V-Ray, no ruby.exe here. Every "would
  render dark/blue" statement is derived from code + reported V-Ray behavior, not from a
  render I made.
- The two 28 Aug PNGs were **relayed** to this audit, not re-examined here.
- "V-Ray skips hidden-tag lights" remains **reported** (Chaos article via search
  excerpt) — the entire C1/C4 chain leans on it; Probe A2 is still the confirmation.
- Whether a scene captured **before** a tag existed shows or hides that tag on
  activation is **unknown** (version-dependent SketchUp behavior) — C1's check answers
  it empirically for this model.
- `BoundingBox#contains?` boundary inclusivity (C7.2) is **assumed uncertain**, not
  tested.
- Whether V-Ray's sun follows SketchUp shadow_info at all is the open question
  `wr-sun-aim.rb` itself declares (probe-vray.rb, partially run per GOAL.md — the sun
  half not).
- Overall confidence: **medium** — the ranking is solid code-reading, but every rung
  between "code does X" and "the render looks Y" passes through at least one reported,
  never-observed V-Ray behavior.
