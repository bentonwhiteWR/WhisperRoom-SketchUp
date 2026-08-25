# Builder HANDOFF — Enhanced on the share-link path

2026-08-24. Scope was `scripts/booth-from-link.rb` only. `wr-deck.rb`,
`build-booth-components.rb` and `gen-booth.py` were not touched.

**The script is UNRUN.** There is no Ruby outside SketchUp on this machine. It is
syntax-checked with `scripts/rbparse.py` (the CRuby 3.2 library SketchUp ships) —
`ok booth-from-link.rb`, and all 49 `.rb` files in `scripts/` parse. No behaviour below was
observed executing in SketchUp; the resolution behaviour was verified by replaying the same
logic against the real component folder in Python (see Verification).

## Produced

- `scripts/booth-from-link.rb` — the fix. Four changes:
  1. `component_for(pack, o, enh = false)` now takes the variant and emits `ENH ` names.
  2. `resolve_part` / `library_index` / `norm_name` — every composed name is checked against
     the real folder **before** anything is built, tolerant of the library's real
     case-and-separator inconsistency.
  3. Loud, by-name reporting of every file that does not exist, in the script's existing
     `puts` style. No new logging mechanism.
  4. `ENH_MISSING_ABORTS` — the Enhanced refusal, and the switch to flip it.
- `scripts/wr_tools/VERSION` — 1.5.2 → 1.5.3 (CLAUDE.md requires a bump for any change
  under `scripts/`).
- `.forge/builder/replay-component-for.py` — the offline coverage check. Re-runnable:
  `python .forge/builder/replay-component-for.py [folder]`.

## Read-first

1. `scripts/booth-from-link.rb` header (the STANDARD / ENHANCED fallback paragraphs) and
   `ENH_MISSING_ABORTS` at the top of the module — the decision and why.
2. The comment inside `build_from_payload` naming the **still-open** downstream blocker.
3. This file's "What is still blocked" section.

## What changed, precisely

**The mapping.** `ENH_WIDTH` maps every Standard width to Standard − 4.5
(`7→2.5, 16→11.5, 19→14.5, 22→17.5, 28→23.5, 31→26.5, 40→35.5, 43→38.5, 46→41.5`), and the
prefix is `'ENH '` **with the space**. Verified against the real filenames, not the
arithmetic (observed, `ls` of `P:\Sketchup\NewMasterComponentList`).

- **`Panel` / `PanelSolid` split confirmed.** The existing `%w[7 19 28 31 43]` list, keyed on
  the **Standard** width, is correct for both variants: the folder holds
  `ENH 14.5Panel`, `ENH 23.5Panel`, `ENH 26.5Panel`, `ENH 38.5Panel` and
  `ENH 11.5PanelSolid`, `ENH 17.5PanelSolid`, `ENH 35.5PanelSolid`, `ENH 41.5PanelSolid`
  (observed). One list now serves both paths — nothing was duplicated.
- **Window opening codes do NOT take the −4.5.** Only the panel width shifts:
  `STDWL31 WDO1648` → `ENH 26.5Panel1648WDO` (observed — that file exists).
- **Vents drop the option suffixes on the Enhanced path**, per Benton's ruling. `component_for`
  returns the plain `ENH <w>VNT` and never appends `_VSS`/`_EFS`/`_CP`. The dropped flags are
  **printed**, so it is stated rather than silent.
- **Ramp WA doors are still composed as `ENH Left/RightWADoorWithRamp`** even though those
  files do not exist. That is deliberate: it makes the resolver report the exact filename it
  looked for, instead of quietly handing back a ramp-less door.
- **`STDWL7` composes `ENH 2.5Panel`**, which does not exist, for the same reason — the gap is
  surfaced by name rather than papered over.
- **Standard is byte-for-byte the same mapping.** With `enh = false` the prefix is `''` and the
  width is unshifted, so every branch produces exactly the string it produced before.

**The Standard bug, fixed.** `46VntCP.skp` has no underscore (observed). `load_def` in
`build-booth-components.rb` already forgives *case* (line 255) but not the missing separator,
so a 46-inch vent with the caster package and nothing else composed `46VNT_CP` and found
nothing — a live defect on the Standard path today. Rather than hand-list it, names are now
matched with case **and** separators removed. That is safe here and was checked, not assumed:
across all **353** `.skp` files the normalisation produces **353 distinct keys**, so no two
different parts collapse onto each other. Proof:

| wanted | `load_def` case-only match | new normalised match |
|---|---|---|
| `46VNT_CP` | **MISS** | `46VntCP` |
| `46VNT_CP_HX` | **MISS** | `46VntCP_HX` |
| `40VNT_CP` | `40Vnt_CP` | `40Vnt_CP` |
| `46VNT_VSS_CP` | `46vnt_VSS_CP` | `46vnt_VSS_CP` |

Those two were the only names case-only matching could not find.

## The fallback rule — the decision, and how to flip it

**On the Enhanced path a missing part ABORTS the build.** `ENH_MISSING_ABORTS = true`, at the
top of the module.

Why abort rather than place-the-Standard-part-with-a-warning, or drop the slot:

- **Dropping the slot is not neutral.** `build-booth-components.build_booth` fills any
  unassigned slot with `guess_component(p[:sk], run)`, which composes **Standard** names
  (observed, lines ~835–845). So "leave it out" on the Enhanced path silently becomes "put a
  Standard part there" one function later. Vanishing is not actually on the menu.
- It matches the chain's own precedent for *cannot build this*: `build_booth` already
  messageboxes and returns on a layout key it does not have.
- The Standard path's "report and fall back" philosophy is untouched.

To flip it: set `ENH_MISSING_ABORTS = false`. The build then proceeds, still naming every
missing file, and **still never assigns a Standard name to an Enhanced slot** — those slots go
to the builder unassigned, which means `guess_component` fills them with Standard parts.
That is exactly why the default is `true`; if Benton flips it he should read the console list,
not the model.

The refusal fires on **untranslatable packs too**, not only missing files, for the same reason.

## Verification (no SketchUp involved)

`.forge/builder/replay-component-for.py` replays the new `component_for` + `resolve_part`
against the live folder for every pack string the portal can emit — vocabulary taken from
`WhisperRoomQuote/booth-builder.html` lines ~1983–2009 (`solidPack`, `ventPack`, `doorPack`,
`waPack`, `shrinkPack`, `windowPack`, `companionWindowPack`) — in both variants, with all 8
VSS/EFS/caster combinations, both ramp states and both height states.

```
library: 353 .skp files, 353 distinct normalised keys

STANDARD   960 combinations   928 resolve   32 do not
  STDWL7 / WL16   -> (no mapping)   UNTRANSLATED     [all 32 flag combinations]

ENHANCED   960 combinations   896 resolve   64 do not
  STDWL7 / WL16   -> (no mapping)                 UNTRANSLATED   [32]
  WA STDDRFRM L   -> ENH LeftWADoorWithRamp(_HX)  missing        [16]
  WA STDDRFRM R   -> ENH RightWADoorWithRamp(_HX) missing        [16]
```

Every miss is a real library gap, named. Notably **`ENH 2.5Panel` never appears** in the
Enhanced miss list — because `STDWL7 / WL16` never reaches the `\ASTDWL(\d+)\z` branch at all
(see Open questions O1). The 2.5" hole is real but it is currently masked by an earlier,
pre-existing translation miss.

Doors/vents/no-vent blanks were restricted to the 40 and 46 modules, which is what
`realSize()` snaps a door or vent slot to; the library holds no 16/22/28 door or vent part in
either variant, so composing those would have reported a pre-existing library fact as a new
finding.

## What is still blocked (NOT fixed by this change)

**An Enhanced link still cannot produce a booth, and this file is no longer the reason.**
`scripts/wr-booth-data.rb` holds **25 layouts and every key ends `' S'`** (observed — tallying
the top-level keys returns `25 S`, zero `E`). `build_booth` therefore stops with its
*"Enhanced variants are not buildable yet — their panel lengths are unresolved in the layout
data"* messagebox on any Enhanced key.

This corrects a claim in `.forge/GOAL.md` (lines 127–131), which says the Enhanced **layout**
resolves and only the parts come out Standard. It does not resolve — there is no Enhanced
layout data. The silent-Standard-parts defect in `component_for` was nonetheless real and is
what the RAW PACK printout showed; it would have become a silently wrong *build* the moment
Enhanced layout data landed. Fixing it first is still the right order, but **`booth-from-link.rb`
alone cannot satisfy GOAL's "Done means" until the layout data exists.** I did not touch
`wr-booth-data.rb` — out of scope, and inventing Enhanced panel runs is not a Builder call.

## Assumptions

- **assumed** — that `library_index`'s memoisation per folder is acceptable within one
  SketchUp session. The module is re-`load`ed on every run so the cache does not survive a
  run, but a folder edited *during* a single run would be read stale. Judged not worth a
  cache-buster.
- **assumed** — that returning an already-`_HX`-suffixed name to the builder is safe.
  Grounded in `build-booth-components.rb` line 846,
  `name = "#{name}_HX" if cfg['hx'] && !name.end_with?('_HX')` — the append is a no-op, and no
  file in the folder uses a lowercase `_hx` that would defeat that case-sensitive test
  (observed: zero such files).
- **derived** — that the portal's realistic door/vent widths are only 40 and 46. From
  `realSize()`'s snap set `[16, 22, 28, module]` plus the absence of any 16/22/28 door or vent
  part in the library. Not observed from a real Enhanced link.
- **reported** — Benton's rulings on Enhanced vent options and on side vents being art-only
  reached me via `.forge/GOAL.md`, not from him directly.

## Open questions

**O1 — `'STDWL7 / WL16'` is untranslatable on BOTH paths, today.** `shrinkPack` emits exactly
that string for the wide-access door's 7-inch companion wall
(`booth-builder.html` line 1991), and `/\ASTDWL(\d+)\z/` is anchored, so it matches nothing and
the slot falls to `guess_component`. **This is a pre-existing Standard behaviour and I did not
change it** — widening the pattern to `\ASTDWL(\d+)(?:\s*/.*)?\z` would make it emit `7Panel`,
which exists, but that is a change to how a Standard booth resolves and "do not regress
Standard" outranked it. It needs a deliberate decision. On Enhanced it now at least triggers
the loud refusal instead of quietly seating a Standard part.

**O2 — should the 2.5" Enhanced panel be authored?** It is the WA-door companion. Until O1 is
decided the request never reaches the width mapping, so authoring it alone would not make an
Enhanced WA-door booth build. O1 first, then the file.

**O3 — `ENH Left/RightWADoorWithRamp` (+`_HX`), 4 files.** Any Enhanced link with `rp` set is
refused by name until these exist. Confirmed absent (observed).

**O4 — is aborting the right default?** Stated above with reasons, but it is Benton's call and
it is one constant.

## Files

- `C:\Users\bento\OneDrive\Documents\Claude\Sketchup\WhisperRoom-SketchUp\scripts\booth-from-link.rb`
- `C:\Users\bento\OneDrive\Documents\Claude\Sketchup\WhisperRoom-SketchUp\scripts\wr_tools\VERSION`
- `C:\Users\bento\OneDrive\Documents\Claude\Sketchup\WhisperRoom-SketchUp\.forge\builder\replay-component-for.py`
