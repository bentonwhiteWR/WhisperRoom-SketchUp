# HANDOFF — booth-matrix harness (Phase 0, complete)

Builder, 2026-08-30. **All 50 dry runs pass. Four real builds done. Baseline
committed. One stale refusal fixed and proven. Two library defects found.**

---

## Produced

| Path | What |
|---|---|
| `scripts/rbtest-live-booth.py` | the harness — `keys` / `selftest` / `dry` / `build` / `diff` |
| `scripts/wr-overlays.rb` | the stale 96192 EFP refusal deleted (the one cleared fix) |
| `.forge/builder/booth-matrix/dry/` | **the golden baseline** — 50 keys, `<KEY>.txt` + `<KEY>.json` + `index.json` |
| `.forge/builder/booth-matrix/build/` | real builds: 6060 S, 6060 E, 96192 E, 102186 E |
| `.forge/builder/booth-matrix/build-efp/` | 96192 E with `--overlay efp` — the EFP fix proof |
| `DEVLOG.md` | entry, dated 2026-08-30 |
| `.forge/builder/HANDOFF-booth-matrix.md` | this file |

**Provenance of the baseline:** SketchUp 2026 **26.2.243**, Ruby 3.2.2, plugin
**1.9.0 as loaded in the running application** (the repo was at 1.9.1; `wr_tools/`
had not been reinstalled, which does not affect this work — every script the
harness drives lives in `scripts/` and resolves live from the checkout, confirmed
via `WhisperRoom::Tools::SCRIPTS_DIR`). Library
`P:/Sketchup/NewMasterComponentList`. Captured 2026-08-30.

`scripts/wr_tools/VERSION` was **not** bumped: Python plus one `scripts/` Ruby
file, both live-resolved, and the lighting lane holds 1.9.1.

---

## How to use it

    python scripts/rbtest-live-booth.py selftest        offline, 20 checks
    python scripts/rbtest-live-booth.py dry --out /tmp/now
    python scripts/rbtest-live-booth.py diff .forge/builder/booth-matrix/dry /tmp/now

`diff` names the keys whose report moved and by how many lines; the line-by-line
is `git diff` on the `.txt` files, which is why they are written verbatim.

Requires an **Untitled** scratch model open in SketchUp 2026 with the bridge
enabled. The harness wipes the model between keys and refuses by name on a saved
one.

---

## Findings — for whoever picks up the fixes

### 1. LIBRARY DEFECT: the STD6042FL floor tiles are 0.392 in over-tall

Measured from the `.skp` definition bounds (w x d x h):

    STD6042FL SIDE L   41.9688 x 60.0 x 3.5000   <-- 0.392 taller than every other deck part
    STD6042FL SIDE R   41.9688 x 60.0 x 3.5000   <-- same
    STD6018FL SIDE R   17.9688 x 60.0 x 3.1080
    STD6042CL SIDE L   42.0000 x 60.0 x 3.1080
    STD6018CL SIDE R   18.0000 x 60.0 x 3.1080

Consequence, visible in `.forge/builder/booth-matrix/build/MDL-6060-S.txt`: the
6060's two floor tiles land at **different heights** — top z 2.50 vs 2.11 — from
the same `contact 1.0000` and the same bottom at z -1.00. **The 6060 floor is
not flat.** This is in the components, not the placement code; `wr-deck.rb`
seated both correctly at the same contact plane. `P:` is read-only, so the fix
is Benton's, in the library.

**Not checked:** whether the extra 0.392 in is the walking surface or a
non-structural feature (a lip, a label, stray geometry) sitting inside the
bounding box. Someone should open `STD6042FL SIDE L.skp` and look before
re-authoring it. Also unchecked: which other booths use the 60-series floor —
`MDL 6084` is the obvious candidate and was not built.

### 2. Same root cause: floor tiles gap at their joints, ceiling tiles do not

The FL parts are 1/32 in narrow (41.9688 / 17.9688) where the CL parts are exact
(42.0 / 18.0). So 6060 floor tiles meet at 42.97 | 43.03 while the ceiling meets
flush at 43.00 | 43.00. Across the larger booths the floor gaps run 0.03–0.09 in.
The seam seals cover them. One root cause, two symptoms.

### 3. `EFP96192.skp` still contains a definition named `EFP96196`

The file was renamed; the component inside it was not. The placed instance is
named `EFP96192 elevated floor` but its definition reads `EFP96196`, a size not
in the catalogue. Cosmetic today, but it will confuse the next person who greps
a model for its parts. Library-side, Benton's.

### 4. Tool self-warnings, unresolved (the `flagged` verdicts)

None of these is a harness finding — they are the tools reporting on themselves.

- No `IEP_VENT_LIFT_DROP` measured for `6060 E`, `96192 E`, `102186 E`; only
  `MDL 102144 E` has ever been measured.
- `IEP wall lift` defaulted on `96192 E`; measured only on `4872 E`, `6060 E`,
  `102144 E`.
- Inner panels proud of their slots: `ENH 41.5VNT` +0.2337 in, `ENH
  41.5PanelSolid` +0.1250 in, `ENH 35.5VNT` +0.2500 in.
- `6060 E`: five inner slots use the 41.5's room-proud figure at a width it was
  not measured for.

### 5. The 6060 side-wall swap — recorded, not adjudicated

Both S and E place identically, every panel an `exact` fit:

    E wall   40VNT          y  2.00.. 42.00   (door end)
             16PanelSolid   y 44.00.. 60.00
    W wall   40PanelSolid   y  2.00.. 42.00   (door end)
             16PanelSolid   y 44.00.. 60.00

Symmetric, matching the stated intent of `ASSIGN['MDL 6060 S']`. **The harness
cannot adjudicate this against the portal's `wallPanelRun()`** — it records
stations. These are the numbers to compare. That comparison is still open and is
the reason this pair was chosen.

---

## Assumptions — all four settled, all four held

1. **The scratch wipe completes without a dialog on a model holding a full
   booth.** HELD. Wiped models carrying 29, 49, 89 and 111 placed instances.
2. **`build_booth` reaches its closing messagebox on every dry run.** HELD, 50/50.
3. **50 keys survive one session despite definition churn.** HELD. 115.3 s, one
   session, no degradation (key 1 1.7 s, key 50 2.5 s, slowest 4.1 s).
4. **600 s per key suffices for `MDL 102186 E`.** HELD by a wide margin — 5.8 s.

---

## Open questions / what is next

1. **Dry runs do not exercise the deck.** `build_booth` skips floors, ceilings
   and seam seals on a dry run by design, so all 50 dry manifests carry **zero**
   deck lines. Component resolution is proven catalogue-wide; **floor and ceiling
   geometry is proven only for the four keys really built.** The remaining 46
   real builds are the next phase — the harness and the manifest format are now
   proven, which is what this pass was for. At ~5 s per key that is under five
   minutes; the reason to do it as its own pass is that each one wants reading,
   not that it is slow.
2. **Nothing in the harness asserts anything about geometry.** It records. The
   STD6042FL defect was found by a human reading two numbers in a manifest, not
   by a check. Turning the baseline into assertions — a floor must be flat, a
   deck must tile without gaps, a ceiling must meet the wall top — is the
   obvious next build, and finding 1 is the first test case.
3. **Compare the 6060 stations against the portal's `wallPanelRun()`.** Still
   open; see finding 5.
4. **The `.json` manifests embed the absolute checkout path** in their `stderr`
   field (build_booth's own `load DATA` constant-redefinition warning, 308
   bytes). Harmless, but it means the `.json` files would diff spuriously on
   another machine. The `.txt` files — the artifact actually diffed — are clean.
5. **`MDL 6084`** uses the 60-series deck and was not built. If the STD6042FL
   defect matters, that is the other booth to check.
