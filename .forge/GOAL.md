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
One Scoper. It cannot open the binary `.skp` files — there is no Ruby outside SketchUp on this
machine — so its **first deliverable is a probe Benton runs in SketchUp**, extending the pattern of
`scripts/probe-components.rb`, and the spec is written against the numbers that come back.
Marking an unmeasured number as measured is the failure mode to avoid.

**The single assumption that invalidates the most downstream work:** whether an `ENH` file is a
*combined* part (outer shell + inner shell + foam, grouped, relationship baked in — what the
DEVLOG said Benton would author) or just a *narrower single slab*. Everything about placement,
the gap, and the panel finder depends on which. Settle it before anything else.

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
