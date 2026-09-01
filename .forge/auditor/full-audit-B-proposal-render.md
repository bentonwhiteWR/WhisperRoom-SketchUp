# Full audit, lane B — proposal package and render lane (2026-09-01, plugin 1.19.2, commit 14197b9)

Auditor pass, READ-ONLY. Nothing under `scripts/` was changed; every scratch file lives
under the session scratchpad. Provenance tags on every load-bearing claim: **observed** (I
ran it or read it myself), **derived** (traced through code, not executed), **reported** (a
handoff, DEVLOG or Benton), **assumed** (needed to proceed, unchecked).

No SketchUp, no V-Ray, no `ruby.exe` on this machine. What WAS executed: `scripts/rbparse.py`'s
CRuby 3.2 VM (SketchUp's own DLL) for the three harnesses, for the lights diagnosis, and for
evaluating the proposal dialog's real `html()` method; `node --check` (v24.14.1) on the
extracted JavaScript. Everything about live SketchUp/V-Ray behaviour is **reported**.

Files read in full: `scripts/proposal-package.rb` (3667 lines), `wr-png-srgb.rb`,
`wr-scene-walls.rb`, `wr-mode.rb`, `wr-materials-swap.rb`, `export-scenes.rb`,
`proposal-scenes.rb`, `wr-preflight.rb`, `wr-shading.rb`, `probe-vray-color.rb`. Read in
part (headers, entry points, every mutation site): `wr-drop-lights.rb` (3378 lines — the
constants, exposure stamp, transaction seam, settings panel, `run`), `wr-lower-walls.rb`,
`wr-sun-aim.rb`, `wr-pack-export.rb`, `export-this-view.rb`, `orbit-export.rb`,
`list-scenes.rb`, `save-scene-components.rb`, `image-qa.py`, `rbtest-proposal.py`,
`rbtest-srgb.py`, `rbtest-lights.py`. Prior audits and the five builder handoffs were read
in full and treated as **reported**.

## Harness results (observed, 1 Sep 2026)

| harness | result |
|---|---|
| `python scripts/rbtest-proposal.py` | PASS — 107 checks in one transcript |
| `python scripts/rbtest-srgb.py` | PASS — 29 checks; `encode_file` ran end to end in CRuby, Python zlib re-verified every byte |
| `python scripts/rbtest-lights.py` | **FAIL** — `RuntimeError: the check harness itself raised inside Ruby`. Root cause below (finding 1). |

---

## The answer to Benton, up front

The image lane and the manifest are in good shape and have been live-verified by builders
(**reported**). The render lane's headline defect of the day — dark files — has a real,
measured fix in `wr-png-srgb.rb`, and that fix is the most carefully engineered thing in this
lane (**observed**: 29 offline checks, refusal list, temp-verify-replace). But three things
in the package still produce a wrong-looking or wrong-state result without saying so, and
they outrank everything else here:

1. **The "even shading" checkbox does nothing on a proposal scene** (finding 2). Every scene
   `proposal-scenes.rb` makes stores its own rendering options and shadow settings, and
   every scene switch re-applies them AFTER the shading contract was pushed. The image
   lane's flat, shadow-free promise is not kept on those scenes, and nothing in the log
   says so.
2. **An image-only batch permanently changes a saved client model that had never been
   mode-toggled** (finding 3): every dimension tag turned on, shadows and ambient
   occlusion off, `WR Lights` stamped hidden into every scene, and a `WR_Mode` dictionary
   written — announced only as "restored to DRAFT".
3. **The sRGB re-encoder will silently double-correct** the day V-Ray starts saving
   display-corrected pixels without a colour-space chunk (finding 4). The "before mean
   near 0.35" tripwire the DEVLOG describes is a number in a log line, not a refusal.

The `rbtest-lights.py` failure is the **harness**, not the tool: it is stale against 1.10.0.

---

## Ranked findings

Probability × cost; silent above loud; customer-facing above internal.

### 1 — `rbtest-lights.py` fails because the HARNESS is stale, not `wr-drop-lights.rb` (observed, root-caused)

**Files:** `scripts/rbtest-lights.py:287-296` (`SCALARS` list), `:686` (`EXPECT`);
`scripts/wr-drop-lights.rb:755-758` (`LUMEN_GAIN`, `layer_lumens`).

**The actual Ruby exception** — `rbparse.rb_eval` discards it (it raises a generic
`RuntimeError` whenever `rb_eval_string_protect` reports non-zero state,
`scripts/rbparse.py:100-103`). Re-running the harness's own program under a rescue wrapper
(`scratchpad/lights-diag.py`) prints:

```
RAISED: uninitialized constant WR_DropLights::LUMEN_GAIN
eval:467:in `layer_lumens'
eval:778:in `check'
```

The harness lifts constants by an explicit name list; `LUMEN_GAIN` was added in 1.10.0
(`git log -S LUMEN_GAIN` → `722992c`) and the harness was last touched at 1.9.9
(`f80ae5b`). It has failed on every commit since, including — as DEVLOG 2026-08-31 and
2026-09-01 both note — before any of today's work. The 1.16.0 lighting panel is NOT the
cause.

**And it is stale twice.** Adding `LUMEN_GAIN` to `SCALARS` (patched copy, repo untouched)
makes 43 of 44 checks pass; the one failure is
`lm 20000,40000,10000,7000,5000,8000` against an expected `2000,4000,1000,700,500,800` —
exactly the 10x gain, which the pinned `EXPECT` predates. The program also PARSES clean, so
the pure placement section of `wr-drop-lights.rb` is sound (**observed**). The WR_Mode half
of the same harness passes today (`rpin 111 | dpin 1 | ... | snap 1` matches).

**Cost.** Medium, internal: the only offline regression net over the light rig has been
red for two weeks and everyone learned to ignore it (three DEVLOG entries say "left
alone"). A red suite nobody reads is the same as no suite.

**Fix direction.** Add `LUMEN_GAIN` to `SCALARS`; re-pin the `lm` expectation at 10x (or
divide the gain out in the check so the product numbers stay readable); and make
`rbparse.rb_eval` surface `$!.message` instead of a generic RuntimeError, so the next stale
constant names itself.

### 2 — HIGH, silent, customer-facing: the image lane's shading contract is undone by every scene switch on a proposal scene (derived)

**Files:** `scripts/proposal-package.rb:1093` (`[:shade_push]` unit is placed ONCE, before
all image rows), `:1575` (`unit_shade_push` → `WR_Shading.push`), `:1589-1629` (`unit_image`
→ `export_pages`); `scripts/export-scenes.rb:256` (`pages.selected_page = p[:page]`),
`:264-269` (re-forces only `DrawGround/DrawHorizon/DisplayFog`, and only when
`bg == 'Transparent'` — the package passes `'bg' => 'Opaque'`, `:1611`);
`scripts/proposal-scenes.rb:236-237` (`page.use_rendering_options = true`,
`page.use_shadow_info = true`); `scripts/wr-shading.rb:126-150` (what the contract sets:
`DisplayShadows`, `Light`, `Dark`, `AmbientOcclusion`, ground, horizon, fog, watermarks).

**Trigger.** Any image row whose scene saves rendering options and shadow info — which is
every scene `proposal-scenes.rb` creates, and SketchUp's default for a hand-made scene.
Order of events: shading contract pushed (shadows off, AO off, Light 80 / Dark 45) → for
each row, `selected_page =` re-applies that scene's SAVED shadow_info and rendering
options → `write_image`. The contract survives only on scenes that do not store those
properties.

**Failure.** The plain image goes out with whatever shadows, AO, ground and horizon the
scene was captured with, while the log says `shading contract on (Light 80 / Dark 45,
shadows off)` and the file header promises "PLAIN IMAGES GET THE wr-shading.rb CONTRACT BY
DEFAULT". Same mechanism as the 1.9.12 lights defect (a page restores its own tag
visibility) and the 30 Aug D5 defect (draft mode re-shows dims) — the package already
learned this lesson for tags (`hide_tags` re-applied after each switch,
`export-scenes.rb:259-262`) but not for shadow_info / rendering_options. The DRAFT-mode
"flat" pin (`wr-mode.rb:209-215`) is beaten the same way on the model itself.

**Provenance.** Derived — the SketchUp behaviour "a page with use_shadow_info re-applies
DisplayShadows on activation" is the documented Page contract and was observed for tags
live (DEVLOG 1.9.12); I have not seen a plain export from this path with shadows in it.
Five-minute check: make one scene with shadows ON, tick SHADING, export it as Image, look
for shadows.

**Fix direction.** Re-apply the shading contract after every page switch inside the export
loop (the way `hide_tags` is), or pass it into `export_pages` as something it re-forces
like the transparent-mode keys; log the read-back per row.

### 3 — HIGH, silent-ish, persists into the client file: an image-only batch rewrites the mode state of a never-toggled saved model (derived)

**Files:** `scripts/proposal-package.rb:1090-1101` (unit list: `[:mode,'draft']` first
whenever there are image rows), `:1145` (`@saved_mode = WR_Mode.current` →
`'unknown (never toggled)'`), `:2426-2441` (finish resolves to `MODE_FALLBACK` and calls
`WR_Mode.to_mode(model, 'draft')`); `scripts/wr-mode.rb:303-306` (first toggle snapshots
"whatever is showing" as the OTHER mode), `:312` (target snapshot falls back to `DEFAULT`),
`:135-142` (`DEFAULT['draft']`: every `ANNOT_TAGS` tag VISIBLE, `WR Lights` hidden,
`DisplayShadows` false, `AmbientOcclusion` false), `:339` (`stamp_light_pages` writes
`WR Lights` visibility into EVERY saved scene), `:345` (`save` writes the `WR_Mode`
dictionary into the model).

**Trigger.** Benton opens a real, saved client model that has never seen the Toggle
button, marks a few scenes Image, presses Export. The batch flips to draft using `DEFAULT`,
flips back at finish to `MODE_FALLBACK = 'draft'` — which is the same `DEFAULT`, not the
model as it was.

**Failure.** After a batch that reports `Done. Model restored.`, the model has: all five
annotation tags switched ON in the live tag state (whatever they were), shadows and AO
switched OFF, `WR Lights` HIDDEN and stamped hidden into every scene (so a hand V-Ray
render from any scene tab is now unlit until he toggles to render), and a `WR_Mode`
dictionary recording all of this as "draft". The only notice is one line, `the model had
never been mode-toggled ... restored to DRAFT rather than left in RENDER`, which describes
the mode word, not the four state changes. This is F3's fix from 30 Aug doing exactly what
it was designed to do; the cost of that design on a saved client file was never weighed.
The 30 Aug audit's readiness list item 6 ("run on a never-toggled scratch model, inspect
the model afterwards") remains undone (**reported**: every live run was on a scratch
`Untitled`).

**Provenance.** Derived from code; the never-toggled path was observed live once on 30 Aug
(F3), before this fallback existed.

**Fix direction.** On a never-toggled model, seed BOTH snapshots from the as-found state
(the model's own live tag/shadow/AO state) rather than from `DEFAULT`, so "restore to
draft" restores what was there; or refuse to mode-toggle a saved (`model.path` non-empty)
never-toggled model without an explicit Yes that lists the four things that will change.
Either way, print the four things.

### 4 — HIGH-latent, silent, customer-facing: the sRGB re-encoder has no guard against a corrected input except a chunk V-Ray does not write (observed in code)

**Files:** `scripts/wr-png-srgb.rb:56` (`COLOR_CHUNKS = gAMA sRGB iCCP`), `:259-274`
(`refusal` — the only double-correct guard is "a colour-space chunk is present");
`scripts/proposal-package.rb:2039-2062` (`srgb_bake` — the before/after means go into the
row detail and the log, nothing judges them), `:2023-2024` (`SAVE_OPTS` now includes
`:apply_color_corrections => true`).

**Trigger.** Any future condition under which `save_vfb_image` writes display-corrected
pixels WITHOUT a gAMA/sRGB chunk: a V-Ray update, a VFB "save with display correction"
preference, a colour-management change in the Asset Editor, or Benton dialling a curve or
LUT into the VFB (which `:apply_color_corrections` now bakes). The DEVLOG's own theory of
the bug is that the saved file is the raw buffer; the only evidence that this is stable
across settings is one measured pair on one day (**reported**).

**Failure.** A correctly-bright render is pushed through the sRGB curve a second time and
shipped as `ok`; mid-tones jump roughly from 0.35 to 0.63 mean, highlights clip. The row
detail carries `sRGB-encoded (mean 0.35 -> 0.63 ...)` and a reader who knows the doctrine
can spot it; nobody else can, and nothing refuses. The DEVLOG sentence "a future V-Ray
that starts saving corrected pixels shows up as a 'before' near 0.35 instead of silently
double-correcting" is only true if a person reads every row's numbers.

**What IS solid here (observed):** the refusal list covers 16-bit, palette, greyscale,
interlaced, non-zero compression/filter methods, truncated files, CRC mismatches, and any
declared colour space; every refusal leaves the original byte-untouched (29 checks). The
temp-write / re-decode / pixel-compare / replace path is correct, and the one
non-restoring case (delete succeeded, rename failed) names the temp path. Alpha bytes are
never touched. `probe-vray-color.rb` is the right experiment to retire the whole
post-process and has not been run (**reported**, DEVLOG next-steps 4). The re-encode is
NOT applied to image-lane exports — `srgb_bake` is called only from `save_frame`
(`:2109`), which is render-lane only; `unit_image` goes through `export_pages` untouched
(**observed**). No image-lane double-correction exists.

**Fix direction.** Turn the tripwire into a refusal: if the decoded `before` mean is above
a stated threshold (the linear signature measured today is 0.16; a corrected frame reads
~0.35) refuse by name and leave the file as saved, exactly like the declared-colour-space
case; and run `probe-vray-color.rb` once so the transform is either native or provably
permanent.

### 5 — MEDIUM, wrong audit trail: `warn_output_size` still logs a size the batch will not use and a write it will not make (observed in code; 30 Aug finding 7 STILL OPEN)

**File:** `scripts/proposal-package.rb:1654-1685`, called at `:1185` on every render batch.
Unchanged since 1.9.4. It computes `package_size(@cfg['width'])` — the 4:3 fallback from
the already-honoured width — and logs `this batch will set it to WxH - the same size the
image rows use, and it is put back at the end of the batch`. The batch sets nothing and
puts nothing back (`unit_vray_audit`, `:1509`, writes only when overrides are configured,
and none can be from the dialog). With Benton's 1600x900 this prints "V-Ray is at
1600x900; this batch will set it to 1600x1200". The first render-lane line of every log
contradicts the release's honour-the-settings promise. Fix: delete the method or make it
say "V-Ray is at WxH (honoured)".

### 6 — MEDIUM, silent mutation on a wrong path: `reset_stale_batch` still restores from a previous batch's snapshot (observed in code; 30 Aug finding 6 STILL OPEN)

**File:** `scripts/proposal-package.rb:2675-2691`; `finish` `:2360` never clears
`@saved_mode`, `@mode_now`, `@prev_page`, `@prev_cam` (it clears `@plan_files`,
`@manifest_plan`, `@vray_saved`, `@page_opts`, `@prev_tt` only). A stale reset therefore
runs `mode_restore_target(@saved_mode)` on stale or nil values: nil → `'draft'`, `@mode_now`
nil ≠ `'draft'` → a full `WR_Mode.to_mode(draft)` (materials swap, tag flip, page stamps,
dictionary write) on a model the batch never touched, plus `selected_page =` to a page
object that may belong to a different, closed model (rescued into a restore error). Lower
probability than on 30 Aug — the launch path between `@running = true` (`:1103`) and
`@saved_mode` (`:1145`) is now only assignments — but the reset path is exactly the one a
confused operator reaches. Fix: `reset_stale_batch` should not call `to_mode` unless
`@saved_mode` was captured by THIS latch; clear the four variables in `finish`.

### 7 — MEDIUM, dormant but wired: the package's EV log ignores ISO, and the lights tool now writes ISO (derived)

**Files:** `scripts/proposal-package.rb:1883-1891` (`camera_ev` → `ev_of_camera(f_number,
shutter)`, ISO not an input), `:322-330` (`ev_of_camera`), `:1898-1906` (`apply_exposure`
writes `ISO = 100` back whenever an override fires); `scripts/wr-drop-lights.rb:1649-1686`
(`stamp_exposure!` writes `/CameraPhysical ISO 3200` once per model, from factory 100).

**Trigger.** Drop Interior Lights has been pressed on the model (ISO now 3200, EV 9.23 by
the lights tool's own arithmetic), then a render batch runs.

**Failure.** Every render row logs `EV 14.23, read from the camera as configured` — five
stops off the truth — and `manifest.json` carries no EV at all. If overrides were ever
enabled, `apply_exposure` would silently reset ISO to 100 and undo the lights tool's one
sanctioned write, and its restore would put 3200 back — two tools fighting over one
parameter with neither aware of the other. The override path is unreachable from the
dialog today (`cfg['overrides']` has no control, **observed**: the JS `export` payload
sends `dir, width, over, shade, annot` only), so the second half is dormant. Fix: give
`ev_of_camera` an ISO term (`EV = log2(f² × shutter × 100/ISO)`); have `apply_exposure`
leave ISO alone.

### 8 — MEDIUM, cosmetic-but-misleading in a client-facing tool: the WIDTH field lies about what it does (observed in code)

**File:** `scripts/proposal-package.rb:3203` — the label reads "PX — height follows the
viewport aspect. V-Ray renders use the size in the V-Ray Asset Editor." Since 1.9.4 BOTH
lanes take their size from V-Ray's `/SettingsOutput` whenever V-Ray is present
(`render_size_gate`, `:389`; `honoured_size`, `:350-361`), so on Benton's machine the
Width field is ignored for image rows too (1.10.8 handoff observed 1600x900 on an
image-only batch) and height never follows the viewport (explicit `cfg['height']`,
`export-scenes.rb:186-199`). The run log says where the size came from; the dialog says
the opposite. Fix the label, or grey the field out when V-Ray is present.

### 9 — LOW-MED, silent partial: `WR_Mode` still nests `start_operation` inside `start_operation` (observed in code; 28 Aug F6 / 30 Aug finding 8 STILL OPEN)

`scripts/wr-mode.rb:297` opens the mode operation; `scripts/wr-materials-swap.rb:248` and
`:292` open and commit their own inside it. SketchUp operations do not nest (**reported**,
documented API behaviour, never verified here). Consequences: "one Ctrl+Z undoes the whole
flip" (`wr-mode.rb:66-69`) is false, and a raise after the materials sweep leaves
`abort_operation` with the wrong operation open. Masked inside the batch by `finish`'s
restore; live on a standalone Toggle press and in the dialog's `togglemode` callback
(`proposal-package.rb:2829`). Five-minute check unchanged: toggle once, Ctrl+Z once.

### 10 — LOW-MED: the lighting panel displays pre-gain lumens while writing 10x (observed in code)

**File:** `scripts/wr-drop-lights.rb:2639` (`r.lumens` from `LIGHT_LAYERS[:lumens]` — 2000
lm), `:755-758` (`layer_lumens` multiplies by `LUMEN_GAIN = 10.0`), `:2608` ("Intensity
multiplies that layer's own lumens"), header `:113-116` ("every number in LIGHT_LAYERS is
now a real product number"). The row Benton edits says 2,000 lm; the plugin gets 20,000 ×
scale. The console report prints the written value (`print_light_report`, `:2711`), so it
is not silent — but the panel is the surface he is now meant to reason on, and it is off
by the one constant that was tuned by eye. Also `:2871` still prints "Drop Interior Lights
1.9.9" on every press (stale version label). Fix: show `lumens × LUMEN_GAIN` in the panel,
or fold the gain into the table and delete the constant.

### 11 — LOW, correctness of an edge: a scene named with `</script>` breaks the proposal dialog (observed)

**File:** `scripts/proposal-package.rb:3271` (`var ST = #{st.to_json};` inline in
`<script>`). Ruby's `JSON.generate` escapes `"` and `\` but not `/` or `<`; evaluating the
real `html()` in CRuby with a scene named `</script><script>alert(1)</script>` produces a
document whose script block ends inside the JSON (`node --check` on the naive split fails
at that token; `</script><script>` appears verbatim once, `<\/script` zero times). The
window opens dead — no rows, no Export. Every OTHER quoting path is right: `esc()` handles
`& < > " '` and is applied to every scene name, file name, key, material and room label
that reaches `innerHTML` or an attribute; titles and message text go through `textContent`;
`execute_script` payloads use `to_json` and are not subject to HTML parsing. With a benign
scene set, the full 18,406-byte script block passes `node --check`, as does the lighting
panel's script (**observed**). Fix: `.gsub('</', '<\/')` on the embedded JSON (or
`script_safe: true`).

### 12 — LOW: the file still documents three behaviours it no longer has (observed; 30 Aug finding 12 STILL OPEN)

`scripts/proposal-package.rb:143` ("`/SettingsOutput` is written ... see
`apply_output_size`" — no such method), `:209-218` (`QUALITY` defined, listed in the
`remove_const` set at `:116`, referenced nowhere else), `:1662` ("`unit_vray_setup` now
WRITES /SettingsOutput" — renamed to `unit_vray_audit`, writes nothing). The next agent
who reads this file will believe the package writes V-Ray settings; that is how the
setting-stomping behaviour Benton ruled out comes back.

### 13 — LOW: Hide-walls picker in the package can write to a scene other than the one it names (derived)

`scripts/proposal-package.rb:2870-2888` (`wallsopen` selects the scene and remembers
`@walls_return`), `:2890-2905` (`wallsapply` → `WR_SceneWalls.apply`, which writes into
`model.pages.selected_page`, `wr-scene-walls.rb:240`, `:265`). The picker is a modal over
the HtmlDialog only; SketchUp's scene tabs stay live. Click a tab between opening and
applying and the hidden-wall state lands on that scene while the title still names the
first. Small window, real. Fix: `wallsapply` should carry `n` (it already does in the JSON)
and re-select that page before `apply`, or refuse if `selected_page` differs.

### 14 — INFO: nothing in the button path looks at a pixel (observed; 30 Aug finding 9 STILL OPEN)

`scripts/image-qa.py` is imported by `lookdev-drive.py` and `sunoff-drive.py` only. A
black or blown frame that reaches `:idleDone` still ships as `ok`. The sRGB step now
measures every render-lane file's mean and max on the way through — the numbers are
already computed; only the verdict is missing.

---

## Re-check of every prior finding

### 30 Aug proposal-package audit (1.9.4 → now 1.19.2)

| # | Was | Now | Evidence |
|---|---|---|---|
| 1 | BLOCKER: render gate read `@size_source` before it was set | **FIXED** | `render_size_gate` (`:389-394`) reads then judges; `rbtest-proposal.py` gate1-4 pass (observed) |
| 2 | `annot_push` leaked hidden tags on a partial failure | **FIXED** | `@annot_saved` published before the loop, filled in place (`:1412-1459`); annot1-4 pass (observed) |
| 3 | lost row reported as `0 FAILED` / `Done. Model restored.` | **FIXED** | `lost_rows` feeds both headline and verdict (`:2572-2583`, `:2511-2523`); whole summary reaches the window (`:2504-2507`); lost1-3 pass |
| 4 | dialog callbacks unguarded during a batch | **FIXED** | `busy?` (`:2652`) on mark/bulk/setfill/setsrc/togglemode/activate/walls*; busy1-3 pass |
| 5 | restore-failure `UI.messagebox` bare; `finish` no re-entrancy guard | **FIXED** | box wrapped (`:2475-2486`); `@finishing` guard (`:2367-2373`) |
| 6 | `reset_stale_batch` restores from a stale snapshot | **STILL OPEN** — finding 6 above | `:2675-2691`, `finish` does not clear `@saved_mode`/`@mode_now`/`@prev_page`/`@prev_cam` |
| 7 | `warn_output_size` logs a size and a write that do not happen | **STILL OPEN** — finding 5 above | `:1666-1685` unchanged |
| 8 | `WR_Mode` nests operations | **STILL OPEN** — finding 9 above | `wr-mode.rb:297` / `wr-materials-swap.rb:248,292` |
| 9 | nothing looks at a pixel | **STILL OPEN** — finding 14 | grep |
| 10 | sidecars named, not managed | **UNCHANGED, dormant** | `sidecars` (`:2058`), denoiser is the operator's; `:skip_alpha`/`:no_alpha` in `SAVE_OPTS` |
| 11 | `camera.clone` may alias | **STILL OPEN, unverified** | `:1148`; one console line would settle it |
| 12 | stale comments / dead `QUALITY` | **STILL OPEN** — finding 12 | `:143`, `:209`, `:1662` |
| 13 | width outside 200–6000 splits the lanes | **UNCHANGED, dormant** | `export-scenes.rb:205-206` clamps; `honoured_size` does not |

### 28 Aug render-lane audit F1–F10

F1 error states → `ERROR_STATE` (`:317`), classified first (`:366`), never fired live
(**reported**) — closed on code + tests. F2 cold `start` → `render_production` (`:1834`),
observed 3x (**reported**) — closed. F3 never-toggled restore → `MODE_FALLBACK`; closed as
written but see finding 3 for what the fallback does to a saved model. F4
`save_vfb_image` Boolean/options — closed (`:2066-2100`). F5 — closed (finding 4 of
30 Aug). F6 — STILL OPEN. F7 raw state in failures — closed (`:1940`). F8 — STILL OPEN.
F9 — half closed, Asset-Editor-vs-scene mystery untouched. F10 — closed.

### 28 Aug lighting-inconsistency audit C1–C10 (what changed under 1.16.0)

- **C1 scenes override tag visibility** — addressed at placement (`stamp_tag_into_pages`,
  `wr-drop-lights.rb:1723`, called from `run`) and by `WR_Mode.stamp_light_pages`
  (`wr-mode.rb:339`) at every toggle. Sun/shadow half is NOT addressed and is now finding
  2's mechanism for the image lane. **Partly closed; the shadow half regressed into a new
  place.**
- **C2 Brightness/Warmth write nothing** — **FIXED.** Since 1.8.0 every light owns a
  plugin; `configure_light` (`:1853-1906`) writes `invisible`, `units`, `intensity`,
  `color`, `directional`, `is_disc` inside one `scene.change` (`write_params`, `:1798`)
  and reads each back (`read_param`, `:1826`). The 1.16.0 panel's per-layer scale and
  Kelvin nudge reach those writes through `role_scale` / `role_kelvin_delta`
  (`:773-784`) → `layer_lumens` / `layer_kelvin`. Brightness and warmth are real writes now.
- **C3 exposure is nobody's job** — **FIXED, narrowly and correctly.** `stamp_exposure!`
  writes ISO only, once per model, only from factory ISO 100, reads f/shutter back to
  prove they did not move, records the stamp in the model dictionary, and prints the undo
  (`:1649-1710`). `NEVER_WRITE` (`:351-357`) is honoured in code. But see finding 7: the
  proposal package's EV log does not know about ISO.
- **C4 draft/render polarity** — addressed by `pin_light_tags` and page stamping;
  `assert_lights_visible!` (`:1742`) exists but is NOT called by the proposal package
  before a render row (grep) — the batch relies on `WR_Mode` render mode having stamped
  the pages. Adequate; a render row could call it for one more named refusal.
- **C5 dead seeds** — gone with the seed architecture (1.8.0). Closed.
- **C6 sun aim fights scene cameras** — unchanged by design (`wr-sun-aim.rb` writes live
  shadow_info only, header §2). Open as a design question, not a defect.
- **C7 idempotency** — recursive world-space sweep with `BOX_TOL` (`:1923-2036`); observed
  live 3x (**reported**, HANDOFF-lights-run). Closed.
- **C8 fixed seed lumens** — superseded (per-light lumens). Closed.
- **C9 selection dependence** — unchanged, documented behaviour.
- **C10** accent seed absent → accent layer now builds; `BOOTH_DROP = 6"` still assumed
  (`:216-219`, says so).

**Is anything in `wr-drop-lights.rb` still claiming to set what it cannot (the C2/C3
question)?** No. Every write is transacted and read back; every print-only item is
labelled advice. Two honesty gaps remain: the panel's displayed lumens are pre-gain
(finding 10), and the header's "TWO DROPDOWNS, and no more" comment (`:2384`) describes
the pre-1.16.0 dialog.

---

## Question 5 — the Untitled-model guard and mutation restoration

**No script in this lane asserts `model.path` is empty** (grep over all 19 files:
`model.path` appears only as manifest data at `proposal-package.rb:2329` and
`orbit-export.rb:228`). Under the GOAL rule as written that is a finding for each of
them; in substance these tools are DESIGNED to act on Benton's saved client model
(hide walls per scene, toggle mode, drop lights, lower walls, aim the sun, make plates)
and refusing on a saved model would make them useless. The rule that actually protects
him is the second one: a saved model must not be changed in a way that persists without
being asked. On that rule:

- **Persist by design, announced:** proposal marks (`set_attribute` on the page, `:263`),
  `WR_SceneWalls.apply` (hidden flags + `page.update`, `wr-scene-walls.rb:246-266`, one
  operation), `wr-lower-walls.rb` (one operation, title says EDITS MODEL), `wr-sun-aim.rb`
  (one operation, shadow_info only), `proposal-scenes.rb` (adds pages, asks before
  replacing), `wr-drop-lights.rb` (one operation + one V-Ray ISO write announced with its
  undo).
- **Persist without being asked:** finding 3 (mode state on a never-toggled model), and
  `WR_Mode.stamp_light_pages` on every toggle (rewrites a tag's visibility in every saved
  scene — by design, but it is the one write that touches scenes the operator did not
  select).
- **Batch restoration trace (`proposal-package.rb`):** every exit — done, cancel, raise in
  a tick, raise in `finish` itself — reaches `finish` exactly once (`step_body` rescue
  `:1353-1358`, `@finishing` guard). Shading pop, V-Ray override restore, annotation tag
  restore (before the mode restore, so no snapshot records the hide), mode restore,
  scene, camera, then TransitionTime last, each individually rescued and reported
  (`:2377-2463`). Cancel mid-render stops the renderer best-effort and records the row as
  `cancelled` (`:1250-1263`). Cancel during `render_production` cannot land until the
  export returns (documented, `:1849-1855`). The image lane's own `export_pages` restores
  its page, rendering options and touched tags in an `ensure` (`export-scenes.rb:287-297`).
  **Observed** in code; the cancel path has never been driven live (**reported**, 1.10.8
  handoff: "batch too fast to cancel into").

---

## Question 6 — dialog JavaScript

`html()` (`proposal-package.rb:2992`) was evaluated for real in SketchUp's CRuby with
stubbed `WR_Shading`/`WR_Mode` constants and a hand-rolled `to_json` matching Ruby JSON's
escaping. Result: 32,706 bytes of HTML; the full script block (18,406 bytes) passes
`node --check`; the lighting panel's script (`wr-drop-lights.rb:2624-2707`, 3,737 bytes)
passes `node --check`. `esc()` covers `& < > " '`; scene names with quotes and angle
brackets render correctly in cells, `title=` attributes and `data-key` attributes. The
one hole is the raw JSON embedded in the script tag (finding 11).

---

## What is solid

- **`wr-png-srgb.rb`** is the best-engineered file in the lane: pure, offline-runnable end
  to end, six named refusals, temp-verify-replace, alpha untouched, original never
  corrupted, and the harness mutation-checked (**observed**, 29/29). Its one gap is
  finding 4, which is about the future, not today.
- **The launch path** (`start_run`) is in the right order now: gate reads before it judges;
  V-Ray absence forks to image-only with a Yes/No; collision policy resolved up front;
  preflight shown; every dialog call rescued; `runStarted` failure cannot latch the batch.
- **The re-entrancy story** — `step` wrapper without an `ensure`, `@finishing` guard,
  `@running` down before the last box — is closed in code and covered by the offline
  suite where it is pure (`busy`, `launch`, `lost`, `sum`, `annot` cases).
- **Lost-row accounting**: one method (`lost_rows`) feeds the headline, the verdict, the
  manifest (`status: 'lost'`) and the reconciliation block. Cannot disagree.
- **The manifest** carries verbatim callout strings, measured spans with honest nulls,
  per-row hidden groups, the client-safe flag and its own field notes; live-verified
  against pixels (**reported**, 1.10.8).
- **Hide-walls integration** reuses `WR_SceneWalls.inventory/apply` rather than a second
  implementation; the two-way pick/reveal matches on entity ids through the containment
  tree; every callback is `busy?`-guarded; scene restored on close.
- **`wr-drop-lights.rb`'s V-Ray discipline**: one `scene.change` per light, read-back
  after, refusals by name for a missing API, a recursive world-space stale sweep,
  place-first-reap-last, one sanctioned ISO write with five guards and a printed undo.
- **`rbtest-proposal.py`** has grown from 64 to 107 checks and now covers the gate order,
  lost rows, annotation push/pop, busy guards, manifest rows and the size gate — the
  exact untested half named on 30 Aug.

## What I could not check

- Anything live: SketchUp, V-Ray, the real `UI::HtmlDialog`, a hand click on Export. All of
  that is **reported** from the handoffs, and the 30 Aug readiness step 6 (a batch driven
  by Benton through the button on a never-toggled scratch model, model inspected
  afterwards) is still the one thing that has not happened.
- Whether `Page#use_shadow_info` re-applies `DisplayShadows` on `selected_page=` (finding
  2) — documented API behaviour, not observed here.
- SketchUp operation nesting (finding 9) — unchanged from two prior audits.
- `wr-drop-lights.rb` lines 430-1630 and 1910-2380 (placement, fixtures, sweep) were not
  re-read line by line; the pure section is proven by the (patched) harness, and the
  28 Aug audit covered the rest at 1.7.9.
- `wr-pack-export.rb`, `export-this-view.rb`, `orbit-export.rb`, `list-scenes.rb`,
  `save-scene-components.rb`: headers and mutation sites only. `wr-pack-export.rb`'s
  header still says its V-Ray lane is a stub behind an unrun probe (`:20-27`) — stale
  since 1.9.2, and the tool is largely superseded by the proposal package; worth a
  "SUPERSEDED" line rather than a rewrite.
