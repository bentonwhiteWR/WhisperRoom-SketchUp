# Handoff — Drop Interior Lights, first live run (plugin 1.9.1)

Builder, 2026-08-30. **Everything here was executed in SketchUp 2026 / V-Ray 7** through
`scripts/sketchup-bridge.py --su 2026`, on a scratch **Untitled** model. SketchUp 2024 was
never touched. Provenance tagged throughout: **observed** (I ran it and read the number
back), **derived**, **reported**, **assumed**.

## Produced

| File | What changed |
|---|---|
| `scripts/wr-drop-lights.rb` | `set_param` → `write_params` + `read_param` (writes inside one `VRay::Scene#change`, read-back after it). `erase_lights` split into `erase_lights` (instances) + `reap_lights` (definitions and plugins, after placement). Header rewritten: it no longer claims to be unrun. |
| `scripts/wr_tools/VERSION` | 1.9.0 → **1.9.1** |
| `scripts/rbtest-lights.py` | one comment line: the "not coverable offline" list now names `write_params`/`read_param` instead of the deleted `set_param`. No check changed. |
| `DEVLOG.md` | 1.9.1 entry with the full checklist table |

**Verified (observed):** `python scripts/rbparse.py` — 58 files parse (real CRuby 3.2).
`python scripts/rbtest-lights.py` — 38 + 10 checks PASS. Live: reset → press → press →
press, three times, zero `DID NOT STICK`, 8 instances and 8 live plugins every time.

## Read first

1. The two new comment blocks in `scripts/wr-drop-lights.rb` — "THE TRANSACTION, and why it
   is not optional" (above `write_params`) and "THE SECOND-PRESS KILL, and why the reap is
   deferred" (above `erase_lights`). They carry the live evidence and the three variants
   that were run.
2. `DEVLOG.md`, 1.9.1 entry — the checklist table with the actual numbers.
3. `.forge/builder/HANDOFF-lights-api.md` — the checklist this run executed. Its assumption
   3 (`FACE_FLIP`) is now settled; its assumption 4 (`invisible` accepted) is settled but
   only inside a transaction.

## The two defects, in one line each

- **A bare `plugin[key] = value` does not persist.** V-Ray's authoritative copy is the JSON
  in the light *component definition's* `VRayPlugins` attribute dictionary; without
  `VRay::Scene#change` the write is re-synced away. All eight lights of the first live press
  read back `intensity 30, invisible false` — factory defaults — minutes later. **observed**
- **Removing a replaced light's definition schedules a deferred purge by plugin name**, and
  the new lights created in the same press inherit those freed names, so a second press left
  8 instances and 0 light plugins. **observed** (four variants run; three survive, and
  place-first-reap-last is the one taken).

## Checklist result

| # | Check | Result |
|---|---|---|
| 1 | Emitters invisible | **PASS after fix.** `invisible => true` on all 8 plugins in a later job; the light definition contains **zero faces**, so no white slab in the viewport either. |
| 2 | FLOOR lit, not ceiling | **PASS.** Widget direction arrow `(0,0,0) → (0,0,-7.41)`; screenshot shows 8 arrows pointing down. `FACE_FLIP` stays `0.0`. |
| 3 | No `DID NOT STICK` | **PASS** — and it was worthless before the fix: it also passed on 8 unconfigured lights. |
| 4 | Dim vs Bright | **PASS.** Read off the scene plugins: Dim 128/60, Normal 256/120, Bright 512/240. |
| 5 | Idempotency | **PASS after fix.** Press 2 and 3: 8 instances, 8 plugins, `8 V-Ray plugins deleted, 0 left behind`. |
| 6 | 16' x 12' → FOUR lights | **PASS.** 4 downlights at (48,36) (48,108) (144,36) (144,108). |

## Assumptions

| # | Assumption | Provenance | What to change if wrong |
|---|---|---|---|
| 1 | The light widget's arrow is the emission direction | derived from observed geometry — never seen in a render | `FACE_FLIP = 180.0` |
| 2 | `VRay::Scene#change` is the only transaction needed; no explicit flush | observed (values persist across jobs and sessions-of-work) | — |
| 3 | Placing first and reaping last is safe when the press aborts | derived: `abort_operation` restores the instances and the reap never ran, so nothing is lost | — |
| 4 | The area-normalised scalar (`AREA_NORMALIZED = 1.0`) is right | reported (design doc) — **still unjudged** | `AREA_NORMALIZED = 0.0` |

## Open questions

- **No render was run** (out of scope by instruction, >5 min each). So "the floor is lit"
  rests on geometry, and `REF_INTENSITY` / `AREA_NORMALIZED` / exposure are all still
  untested. That is the next phase, and it is the only thing that can judge the scalar.
- **The float bug behind check 6 did not reproduce.** This room's polygon came back exactly
  `192.000000000000000`, so raw `ceil` would also have said 2. The 1/16" snap was confirmed
  on a synthetic input run inside SketchUp's Ruby (`grid_count(192.0000000001, 96.0) => 2`,
  raw ceil 3), not on a room that actually misbehaves. A room that does is still wanted.
- **Wall-wash lights point straight down**, same as the downlights — visible in the
  screenshot. Whether a wall wash should be tilted at its wall is a design question nobody
  has answered. Not on this checklist; not changed.
- **The tool autoruns on `load` and pops `UI.inputbox` immediately.** The bridge muzzles
  `UI::HtmlDialog#show`, not `UI.inputbox`, so any bridge job that presses this button must
  stub `UI.inputbox` first (this run did). A `$wr_no_autorun` guard, or a bridge-side
  `UI.inputbox` muzzle, would make the tool testable without a stub. Repo-wide convention
  question, deliberately left alone.
- **Pre-1.8.0 seed lights** still count as "left behind" in the reap, correctly. Untested
  live — no pre-1.8.0 light existed in the scratch model.
