# GOAL

## Mission
Teach the booth-building scripts to build **Enhanced** booths. Benton has authored and loaded
the `ENH` component library into `P:\Sketchup\NewMasterComponentList` (also mapped as `Z:` —
same share, identical contents), which unblocks work that has been stalled on missing parts.
Enhanced is a booth-inside-a-booth: an inner shell set inside the outer with a gap.

The **booth-builder share link is the priority path** (`scripts/booth-from-link.rb`). A customer
who configures an Enhanced booth in the portal must get an Enhanced booth built. Today they
silently get a Standard one.

## Done means
- **`booth-from-link.rb` builds an Enhanced booth from a real Enhanced share link**, verified by
  the script's own RAW PACK / placement printout diffed against the portal's "YOUR BOOTH" panel —
  the text-comparison method that proved the door-hand translation correct on 2026-08-18. A render
  is not the check.
- **No silent Standard fallback.** An Enhanced link that hits a missing or unrecognised `ENH` part
  reports it loudly and by name. Building the Standard part in its place without saying so is the
  specific failure this mission exists to remove.
- The three scripts below work for Enhanced, in this order of importance:
  1. `scripts/booth-from-link.rb` — the customer path. Highest value.
  2. `scripts/build-booth-components.rb` + `scripts/wr-deck.rb` — walls/doors/vents and the
     floor/ceiling deck, in SketchUp.
  3. `scripts/gen-booth.py` — the offline generator; all 25 `E` variants currently skip.
- The **gap dimension** between inner and outer shell is a measured number from the real
  components, not inferred from the 4.5-inch name arithmetic. Both may agree; that is a check,
  not a substitute.
- A definitive **present/missing table** for the `ENH` library, so Benton knows exactly which
  components still need authoring before a full Enhanced build can succeed.
- No regression: every Standard booth that builds correctly today still does. Enhanced is additive.

## Now
**The probe has been RUN. The gating question is answered, and it went the harder way.**

Benton ran `scripts/probe-enhanced.rb` in SketchUp on 2026-08-24: **116 measured, 0 failed.**
Results in `P:\Sketchup\NewMasterComponentList\_enhanced-probe.tsv` and `_enhanced-nesting.tsv`.

### THE VERDICT: ENH parts are SINGLE SHELLS, not combined double-wall components

Every one of the 116 parts reports `shells = 1` and an **empty gap** — no exceptions (observed:
`awk` over column 9 of `_enhanced-probe.tsv` returns `116  1`, and column 10 is empty for all 116).
The DEVLOG's expectation that Benton would author *combined* parts (exterior + interior + foam
grouped, relationship baked in) **did not happen.** The shipped `ENH` files are narrower single
inner-wall panels.

They *are* internally nested — 4 to 15 nested containers each, with a `fill / shell / trim / void`
band profile through the thickness — but that is one wall's internal construction, not two shells.

**What this means for the build:**
- **Combining is still to be done, and the gap lives in the LAYOUT, not in the part.** The
  assembler has to place an outer shell and an inner shell and solve the offset itself. This is
  the "very different piece of work" branch the spec named — Steps 5+ fork here.
- **Blocker 5 does NOT fire.** `wall_slab`'s single-tall-slab premise holds, because every part
  really does contain exactly one slab. That is the one piece of good news in this verdict.

### Measured facts that supersede earlier guesses
- **Enhanced wall height is 79.5000, and 89.5000 for `_HX`** (30 and 24 parts respectively; the
  `NV`/`CBL`/`VNT` family sits at 79.4375 / 89.4375). Standard measures **81.0000 / 91.0000**.
  So Enhanced walls are **1.5000 SHORTER** than Standard. Where that 1.5 goes — deck lift, or a
  genuine height difference — is not yet established and must not be assumed.
- The DEVLOG's `83.0000` / `84.3125` panel heights are **wrong**; neither appears in any
  measurement. `84.3125` shows up only on `ENH 127LPCL` / `127LPFL`, which are a different animal.
- **THICKNESS: USE THE `shell` BAND, NEVER THE BOUNDING BOX.** Benton ruled on 2026-08-24, and
  the probe's own band data confirms it: *the bulk of the wall is still 1 inch. There may be foam
  on one side that protrudes it out a bit. The Standards are so "big" because they have the vent
  boxes connected to them.*

  Measured (observed, from the `bands` column of `_enhanced-probe.tsv`): **every** Enhanced wall
  panel's `shell` band is **1.0000–1.1250**, clustering hard at 1.0000 (37 parts) with the rest at
  1.0625 or 1.1250. The bounding-box thickness is fill, trim and void on top of that.
  `ENH 35.5VNT` is the clearest case — bbox 2.3750, bands
  `fill 0.7438-0.8063 / shell 0.8063-1.9313 / fill 1.9313-3.1188 / void 3.1188-3.1813`. The wall
  is the 1.1250 shell; the rest is not wall. Standard `40VNT`'s bbox of 8.5468 is its **vent box**.

  **A superseded earlier claim, corrected:** this file previously said Enhanced panels are
  "mostly thicker than Standard, +0.9375 to +1.0625, but vents and doors are much thinner." That
  was a bounding-box comparison and it is misleading. Standard and Enhanced walls carry the same
  ~1 inch of actual wall; the deltas were attached hardware and foam.

  This is the same trap the DEVLOG already records in capitals — *"SEATING BY THE BOUNDING BOX IS
  WRONG AND IT COST A ROUND."* The builder seats on the shell band.

  One probe artifact to be aware of, not a geometry defect: `ENH 41.5NV` and `ENH 41.5VNT` report
  a 2.0625 shell where their `_HX` siblings report 1.1250, because the band detector merged an
  adjacent fill layer into the shell. Treat the `_HX` figure as the true one for that family, or
  tighten the detector before relying on those two rows.

### DEFECT — RE-AUTHORED BY BENTON 2026-08-24 21:07, GEOMETRY NOT YET RE-VERIFIED
Benton replaced the two bad files. Observed from the folder listing: both `11.548WDO` files are
**deleted** (not renamed), and `ENH 26.5Panel1648WDO.skp` / `ENH 26.5Panel1648WDO_HX.skp` were
re-saved at 21:07. The `ENH` count went 116 → 114. **This settles the window-code question: `1648`
is canonical and `11.548` is gone.**

A listing proves the files changed; it does not prove the geometry is right. The `_HX` must be
re-measured at **26.5000 wide × 89.5000 tall**, not the 31.0000 × 91.0000 it held before. Re-run
`scripts/probe-enhanced.rb` and confirm before any Builder relies on it.

The original finding, kept for the record:
`ENH 26.5Panel1648WDO_HX` and `ENH 26.5Panel11.548WDO_HX` both measure **31.0000 wide × 91.0000
tall × 1.8125 thick with 61 faces**. That is not an Enhanced part — it is the Standard
`31Panel1648WDO_HX`, which measures identically (observed, from `_component-probe.tsv`). The
correct non-HX siblings measure 26.5000 × 79.5000 with 333 faces, so the mistake is isolated to
the two `_HX` files. This is the same failure mode the DEVLOG records for `STD7224CL/FL SIDE R` —
master files saved out of alignment, not a script bug.

### Established already (observed 2026-08-24)
- **`booth-from-link.rb` reads the variant but never uses it for parts.** Line 170 builds the
  layout key from `payload['v']` (`'S'`/`'E'`), so the *layout* resolves for Enhanced — but
  `component_for(pack, o)` at line 111 never receives the variant, and every branch emits a
  Standard name. An Enhanced link therefore builds Standard parts with no warning. This is the
  core defect and it is silent.
- **The portal always sends `STDWL<n>` pack strings**, whatever the variant (see the payload
  contract at line 22). So the Enhanced translation is a mapping problem inside `component_for`,
  not a portal change.
- **Enhanced wall widths are Standard minus 4.5 inches, one-for-one**: `16 19 22 28 31 40 43 46`
  → `11.5 14.5 17.5 23.5 26.5 35.5 38.5 41.5`. The `Panel`/`PanelSolid` split survives the shift
  intact (`ENH 14.5Panel`, `ENH 35.5PanelSolid`), which mirrors the `%w[7 19 28 31 43]` list at
  line 132. **`STDWL7` has no Enhanced counterpart** — a `2.5` would be the match and none exists.
- **`wr-deck.rb` cannot see a single Enhanced deck part.** Line 283's
  `NAME = /\ASTD(\d{2,3})(\d{2})…/` and line 287's `Dir.glob('STD*.skp')` both require a literal
  `STD` prefix; Enhanced parts are `ENH ` + digits — different prefix *and* an inserted space.
  Any widening must still keep `STDSS`/`…SeamSeal` parts out of the deck pool, which the current
  anchored pattern achieves for free.
- **`gen-booth.py` skips every `E` variant** at lines 367–373 with `'panel lengths unresolved'`.
- **VENT OPTION COMBINATIONS ARE NOT MISSING — Benton ruled this on 2026-08-24.** The
  `_VSS`, `_EFS` and `_CP` variants are **strictly for Standard walls**. Enhanced needs only the
  plain vent panel: `ENH 35.5VNT` / `ENH 41.5VNT` (plus `_HX`), which already exist. In Benton's
  words, *"the 35.5 VNT wall fits them all for the inner walls."* The 28 composed combination
  files earlier listed as missing are **not to be authored**.

  The consequence is a code requirement, not an authoring one: `component_for` in
  `booth-from-link.rb` (lines 122–127) appends `_VSS`/`_EFS`/`_CP` unconditionally. For Enhanced
  it must **stop appending them** and emit the plain `ENH <w>VNT`. Appending on the Enhanced path
  composes a filename that will never exist, whatever Benton authors.
- **SIDE VENTS ARE NOT BUILD COMPONENTS — Benton ruled this on 2026-08-24.** The
  `LeftSideVent` / `RightSideVent` families and their `_VSS`/`_EFS`/`_CP`/`_HX` matrices exist
  strictly for **front-view art**, not for assembly. They are to be **completely ignored** by
  every booth-building script, and no Enhanced counterpart is to be authored. Corroborated
  independently (observed 2026-08-24): `grep -rn "SideVent" scripts/*.rb scripts/*.py` returns
  zero hits outside the probe — no builder has ever referenced them.
- **Known library gaps** (to be confirmed precisely by the Scoper, not taken from this list):
  no Enhanced counterpart to any of the eight `STDSS` ceiling/floor seam seals; and
  `ENH 423.54CL` / `ENH 423.54FL` have no Standard counterpart and do not parse like the other
  deck names — suspected typo, to be flagged rather than silently normalised.
- **The DEVLOG's standing warning is now live, not future:** the panel finder "needs a
  prefer-outermost-slab tweak once two same-width tall slabs exist in one part." If the probe
  confirms combined components, that condition is met and it is a present bug.

## Out of scope
- **Furniture and accessories** — desk, MJP jack panel, step, bass traps, studio light — and the
  roof-mounted vent. `booth-from-link.rb` already documents these as not coming through; Enhanced
  does not change that and must not be the excuse to start.
- **Component art / image exports.** The top-down and Iso30 re-shoots are separate and settled.
- **Authoring new `.skp` components.** The Scoper reports what is missing; Benton authors it.
- The `WhisperRoomQuote` repo — read only, never write. No prices; nothing from `models.json`
  goes into any artifact.
- Changing how Standard booths resolve or place. That path works and is not to be touched.

## History
2026-08-24 — **Ceiling seam seals: done.** Built and verified; the mission that previously
occupied this file is closed.

2026-08-18 — `booth-from-link.rb` built the door inside-out when the customer moved it in the
portal; root cause was reading the layout's static slot kind instead of the resolved component
name. Fixed and verified against a real link (`8174e78`).

2026-08-17 — `STD7248CL SIDE R` / `STD7248FL SIDE R` authored by Benton; `wr-deck.rb` picked them
up with no code change. Earlier that day `STD7224CL/FL SIDE R` came out flipped — root cause was
the master files saved out of alignment, not the script.
