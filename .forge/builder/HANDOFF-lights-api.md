# Handoff — Drop Interior Lights on the real V-Ray light API (plugin 1.8.0)

Builder, 2026-08-28. **Nothing in this handoff was executed in SketchUp.** There is no
SketchUp and no `ruby.exe` on this machine. Provenance is tagged throughout: **observed**
(I ran it / read it myself), **derived**, **reported**, **assumed**.

## Produced

| File | What changed |
|---|---|
| `C:\Users\bento\Documents\Claude\Sketchup\scripts\wr-drop-lights.rb` | Rebuilt on `VRay::Command.create_rectangle_light`. Seed `.skp` machinery deleted (~450 lines). Per-light plugin configuration with read-back. Kelvin→RGB. Grid-count fix. Recursive world-space stale sweep with plugin deletion. Accent layer now builds. |
| `C:\Users\bento\Documents\Claude\Sketchup\scripts\rbtest-lights.py` | 33 → 38 checks. New: `grid_count` (raw + whole grid), `kelvin_rgb`, `scalar_intensity`, `param_agrees?`, `in_box?`, the layer table. Removed the three seed-plugin checks whose code is gone. |
| `C:\Users\bento\Documents\Claude\Sketchup\scripts\wr_tools\VERSION` | 1.7.9 → **1.8.0** |
| `C:\Users\bento\Documents\Claude\Sketchup\DEVLOG.md` | 1.8.0 entry |

**Verified (observed):** `python scripts\rbparse.py` — 56 files parse, real CRuby 3.2 parse.
`python scripts\rbtest-lights.py` — 38 + 10 checks PASS. **Ten mutations applied to
`wr-drop-lights.rb`, each run, each confirmed to FAIL the test, each reverted** (list in the
test file's header).

## Read first

1. `scripts\wr-drop-lights.rb` header — it is the whole rationale, and the OLD header's
   central claim was false. Do not carry the old one forward.
2. `.forge\auditor\lighting-inconsistency-2026-08-28.md` — C2 (shared asset) and C7
   (non-recursive sweep) are the two this change closes. **C1 (scene-stored tag visibility
   and sun), C3 (exposure EV 14.2) and C4 (draft/render polarity) are UNTOUCHED and are
   still live.** They are render-time, not placement-time, and they were out of scope here.
3. `.forge\researcher\interior-lighting-design.md` §1.2 (grid rule), §1.4 (lumens, and the
   sentence that scalar-units intensity depends on size).
4. The installed V-Ray docs: `VRay/Command.html`, `VRay/Scene/Plugin.html`, `VRay/Color.html`,
   `VRay/Scene.html` under
   `C:\Program Files\Chaos\V-Ray\V-Ray for SketchUp\extension\documentation\`.

## Assumptions — named, and each one a single constant

| # | Assumption | Provenance | The one thing to change if it is wrong |
|---|---|---|---|
| 1 | Under `units = 0`, intensity is per-area, so a 12x12 fixture needs 8x the scalar of the 24x48 reference to emit the same power. **This is the weakest link in the file.** | reported (design doc §1.4 quoting Chaos' Rectangle Light page) | `AREA_NORMALIZED = 0.0` |
| 2 | `intensity 30` at 24x48 is a correctly-exposed room light | observed once, by Benton, in one room | `REF_INTENSITY` |
| 3 | A light from `create_rectangle_light` already faces DOWN (−Z) with an identity transform | derived from Benton's lit render, never measured | `FACE_FLIP = 180.0` |
| 4 | `plugin[:invisible] = true` is accepted (the dump shows the parameter as an integer 0/1, `each` yields it as a boolean) | assumed; `param_agrees?` bridges both and the read-back reports the truth | nothing — it self-reports |
| 5 | `directional` is the "Directionality" slider (default 0, spec wants ~0.5); `directional_strength` is left at its default 0.9 | assumed — the dump has both and the docs name neither | `LIGHT_LAYERS[:accent][:dir]`, or move the write to `directional_strength` |
| 6 | The units enum is **not** guessed. `units` stays 0. | observed: no units enum in the installed docs | — |
| 7 | `scene.delete(name)` removes a light's plugin | documented (`VRay/Scene.html`), never run | the sweep counts and reports what it could not delete |

## Open questions

- **Exposure is still nobody's job.** Out of scope by instruction; the tool still only
  prints the EV 8 advice. Until it is set, the scalar anchor cannot be judged fairly — a
  uniformly dark first render may be EV 14.2, not the lights.
- **`.forge\GOAL.md` is now stale in one place.** It lists as Benton's job: *"Author
  `scripts/vray-seeds/WR Interior Light.skp` — `wr-drop-lights.rb` refuses by name until it
  exists."* That is no longer true; no seed is needed and no layer refuses for a missing
  one. I did not edit GOAL.md — it is not mine — but it should be corrected.
- **`scripts\vray-seeds\WR Light Booth.skp`, `WR Light Downlight.skp`,
  `WR Light Wallwash.skp` are now dead** and nothing in the repo reads them (grepped).
  Deliberately NOT deleted here, so a machine mid-upgrade cannot break. Delete once every
  install is past 1.8.0.
- **One API call per light** means a 12-light room creates 12 component definitions and 12
  V-Ray plugins. That is the price of per-light control and is the whole point. Whether it
  is slow at Showroom density in a big room is unmeasured.
- **Aborting a failed press leaves orphan plugins.** V-Ray's scene is not on SketchUp's
  undo stack. The tool now says so on the console rather than leaving it a mystery, but it
  cannot roll them back.
- The `:unknown`/`:dangling` "will it emit" apparatus is gone because the failure class it
  guarded (a seed naming an absent plugin) cannot occur when V-Ray creates the light itself.
  If a future render is unlit, the suspects are now C1/C3/C4 from the audit, not the light.
