# DEFECT — side wall panels flipped, MDL 96144 E and MDL 102144 E

Benton, 2026-08-26, after building both booths from real share links on v1.6.23/24:

> *"also on both, the side walls panels were flipped. See the window for example"*

**Both booths, so it is not booth-specific.** The window is his *example* of the flip, not
necessarily the only affected panel — read it as "the side wall's panel run is mirrored, and
the window is where you can see it."

---

## STATUS 2026-08-26, second pass (fixer) — NOT FIXED, root cause NOT established offline

Nothing was changed. `scripts/wr_tools/VERSION` stays **1.6.26**. Everything below is
either read off the two layout files or read off the builder's own source; nothing was
inferred from a screenshot, and no left/right claim is made anywhere in it.

### What is now RULED OUT — observed

**The slot mapping is not mirrored.** `.forge/fixer/replay-side-wall-order.py` diffs
`scripts/wr-booth-data.rb` (what the builder places from) against
`WhisperRoomQuote/lib/pl-data/booth-layouts.json` (what the portal draws from), per wall,
per shell, for all **25 Enhanced layouts**. Result:

- **0 mirrored walls out of 25 models × 4 walls × 2 shells.** On every wall, slot `n0`
  sits on the same physical end in both files. On an E/W wall that end is the **N end**;
  the portal's own convention is fixed in `assets/layout-render.js` `wallPanelRun()`
  ("aIn grows DOWNWARD → high aIn is the S end").
- Slot **kinds** agree with the portal row on every wall of both of Benton's booths.
- `MDL 96144 E` E/W are **46 + 46** and `MDL 102144 E` E/W are **40 + 16 + 40** — both
  symmetric, and the portal's own big-run-at-the-door-end flip explicitly does not fire on
  either (it needs exactly two pieces of unequal real width).

`booth-from-link.rb` translates pack → component keyed on the slot id and never reorders
(observed, `build_from_payload`). With the slot ids landing on the same ends in both files,
**that path cannot mirror a side-wall run on these two booths.** The `ASSIGN` E/W swap and
`guess_component` are both irrelevant here as well — see the separate finding below.

### What is therefore LEFT — derived, and NOT proven

The only remaining mechanism in the code that can mirror a panel along its wall is the
**180° yaw that follows the thickness sense**. `rotation()` pins height→up and
thickness→outward-normal and *derives* the width direction from right-handedness, so
flipping which way a part's thickness axis points also turns the part end for end. An
asymmetric part — a window, a vent — visibly mirrors; a plain solid panel does not.

Two candidate root causes, both consistent with everything observed, with **opposite fixes**:

**(A) The window panel is missing the half turn its own authoring family gets.**
`build-booth-components.rb` header, measured across the library:

> *"WIDTH is on Z for solid panels, doors and both seam seals, and on X for the **WDO window
> panels and the vents**. Two families, no flag to tell them apart."*

Those two families land on **opposite** handedness signs in `rotation()`
(`s = EVEN.include?([hi, ti, wi])`: height=Y, width=Z → `[1,0,2]`, odd, `s=-1`;
height=Y, width=X → `[1,2,0]`, even, `s=+1`), so their width axes point opposite ways
along the same wall. `IEP_VENT_YAW = 180` is the patch for one member of the X-width
family and is confirmed by Benton's eye on a restarted SketchUp. **The WDO window panel is
in that same family and gets no half turn** — the harness prints `NONE` on it. If the turn
is a property of the family, the window is short one.

**(B) The half turn belongs to the whole ENH family / the global convention is wrong.**
`FACE_OUT = false` with `REVERSED = %w[MidWallSeamSeal MidWallSeamSeal_HX]`. Its own
comment warns: *"Do not add per-part exceptions to compensate — a mix of a global flag and a
list of exceptions is how this ended up flipping back and forth."* `IEP_VENT_YAW` is
already one such exception. If the real fault is family-wide, adding a second per-kind
exception for windows makes the tangle worse and papers over it.

**These cannot be told apart from here.** Which branch of `place()` sets `sense` for a
given part depends on `wall_slab()`, which measures the real `.skp` geometry. There is no
Ruby and no SketchUp on this machine.

### Blast radius — the question that was asked first

**Unresolved, and it is the reason nothing was changed.** `place()`, `rotation()`,
`wall_slab()`, `FACE_OUT` and `REVERSED` are all **shared Standard code**. The outer shell
of an Enhanced booth is built by exactly the same code, from exactly the same Standard
parts, as a Standard booth — so if the flip is on the outer shell, a Standard 96144 /
102144 flips identically today and the blast radius is the live customer path.
The only Enhanced-only orientation code is `IEP_VENT_YAW` / `IEP_DOOR_YAW` /
`IEP_SEAL_YAW`, all gated on `inner?(p)`.

Per the standing instruction: **if it lands in shared Standard code, stop and report.**
It might. So: reported, not touched.

---

## A SEPARATE, REAL, OFFLINE-PROVABLE DEFECT found on the way — not this symptom

**The `ASSIGN` E/W big-run swap never fires on the customer (share-link) path.**

- `ASSIGN` is read in exactly one place: `self.run` — the standalone dialog
  (`scripts/build-booth-components.rb:1765`, `ASSIGN[cfg['booth']] || {}`).
- `booth-from-link.rb` calls `WR_BuildBoothComponents.build_booth(key, assign, ...)` with
  the **link's** assign (`scripts/booth-from-link.rb:411`). `ASSIGN` is never consulted.

So on a booth built **from a link**, the E/W swap that `ASSIGN` documents at length is
absent, and the side walls come out mirrored against what the portal draws. The harness
reports which models this hits, and it is exactly the four the portal's own comment names:

    MDL 6060 E, MDL 6084 E, MDL 7272 E, MDL 7296 E   (and their ' S' twins)

This is **not** Benton's two booths — neither of them qualifies. But it is a live mirror on
the customer path for those four, on **both** Standard and Enhanced, and it is the same
sentence he used ("the side walls panels were flipped"). Flagged, not fixed: the fix lands
in the shared Standard path.

---

## What is needed from Benton — one pass in SketchUp, and one paste

1. **The two share links** (`sales.whisperroom.com/booth-builder?d=…`) for the 96144 E and
   the 102144 E he built. Without them nobody knows which slot the window was in, and the
   whole report turns on the window.

2. **The Ruby Console output of one rebuild**, restarted SketchUp, plugin 1.6.26. The
   builder already prints the table this needs — `SLOT · COMPONENT · SLOT in · PART in ·
   FIT · PANEL · FACING · BELOW WALL` — plus booth-from-link's `RAW PACK` block and its
   `COMPARE THESE AGAINST THE BUILDER'S "YOUR BOOTH" PANEL` summary. The whole console,
   pasted, settles (A) vs (B): the **FACING** column shows whether the window panel faces
   the same way as its neighbours on the same wall, and the **PANEL** column shows whether
   `wall_slab` found a slab on it (which decides which branch of `place()` chose the sense).

3. **`Probe Component Files` run once on `P:/Sketchup/NewMasterComponentList`** (scratch
   model — it loads every definition). Its X/Y/Z extent table gives the authoring family of
   every part, ENH included, which is what tells us whether the window panel really is in
   the vent's family. That measurement has never been recorded for the ENH library; the
   "two families" note in the header predates it.

4. **Does a Standard 96144 or 102144 build its side walls correctly today?** Still open.
   It bounds the whole problem and only he can see it.
