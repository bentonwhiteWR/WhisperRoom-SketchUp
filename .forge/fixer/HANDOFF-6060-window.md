# HANDOFF — "the window needs to go inwards 11/16" — FIXED on the 7272 E inner window

Fixer, 2026-08-30. Filed under the 6060 name the assignment was opened with; **the booth is
the 7272, not the 6060.** Two passes: the first refused for want of a part, the second fixed
it once Benton named the part.

`scripts/build-booth-components.rb` (one rule changed), `scripts/wr_tools/VERSION` 1.9.7 ->
**1.9.8**.

---

## THE ANSWER, in three lines

1. **It is the INNER panel, `W1i` `ENH 41.5Panel3236WDO`. Not the outer, not both.** The
   geometry decides it outright and the reasoning is below.
2. **0.6875 is not a fudge — it is a dimension of the part.** It is the depth of the window's
   trim ring, which the room-proud rule was mistaking for the panel face.
3. **Proven live, four numbers, all exact.** The inner window now lands flush with the inner
   panel beside it on every face. The Standard 7272 did not move.

---

## Pass 1 — the refusal, and what it was right about

The first brief said the part was `40VNT` on a **6060**. Both were wrong, and stopping was
correct:

- **`40VNT` is a ventilation panel**, observed from its component art (two louvred duct
  grilles), its option family (`40VNT_VSS`, `40VNT_EFS`, `40Vnt_CP`), `wr-overlays.rb:221`
  classifying `WDO` as `:window` and `VNT` separately, and the duct covers the builder hangs
  on it.
- **A generated 6060 has no window at all.** `WDO` does not occur in `wr-booth-data.rb`;
  neither golden 6060 build places one. **Across all 50 matrix keys only `MDL 7272 S/E`
  places a window.** That is what made the 7272 findable.
- Had `40VNT` been right, it is in **30 of the 50 keys** — a blanket move would have shifted
  30 booths to fix one.

Benton then named it: the **7272's window panel**, **Enhanced only**.

---

## Pass 2 — outer, inner, or both: the geometry answers

Measured live on a real `MDL 7272 E` (bridge, SketchUp 2026 **26.2.243**, Ruby 3.2.2,
library `P:/Sketchup/NewMasterComponentList`, plugin resolving live from the checkout via
`WhisperRoom::Tools::SCRIPTS_DIR`). The probe is committed at
`.forge/fixer/probe-wall-face-levels.rb`; it prints the world-x level of every face parallel
to the wall, with its area, so a panel slab and a trim ring are separate readable numbers.

**W wall, room toward +x. BEFORE:**

    outer band x 1.00 .. 2.00
      W0  22PanelSolid             1.0000 ................ 2.0000
      W1  46Panel3236WDO   0.2500 | 1.0000 ................ 2.0000
                           ^ trim   ^------ 1.0 panel ------^

    inner band x 2.25 .. 4.25
      W0i ENH 17.5PanelSolid              3.1875 | 3.2500 ....... 4.2500 | 4.3125
      W1i ENH 41.5Panel3236WDO   2.5000 | 2.5625 ....... 3.5625 | 3.6250 ....... 4.3125
                                          ^--- 1.0 panel ---^     ^--- trim 0.6875 ---^

**The outer window is already right.** `W1`'s panel faces sit at 1.0000 and 2.0000 — exactly
where `22PanelSolid`'s do. It is placed off a slab that IS found, so it is flushed to the
band like every other outer panel. Moving it 11/16 would put a step in a wall that has none,
and it would move **Standard** booths, which Benton excluded. **Not the outer. Not both.**

**The inner window is 0.6875 out, and by exactly the trim ring's own depth.** `W1i`'s panel
runs 2.5625..3.5625 where its neighbour `W0i`'s runs 3.2500..4.2500 — **0.6875 apart**.

**Root cause.** The room-proud rule (`iep_room_proud`, applied at
`build-booth-components.rb` in the `inner?(p) && p[:k] == 'panel' && r[:slab].nil?` block)
pins an inner panel's **bounding box** face a measured sliver into the room. On a solid or a
vent the box is the panel plus an even sliver, so pinning the box pins the panel. **On a WDO
the box's room end is the tip of the window trim ring**, which stands 0.6875 proud of the
panel it is screwed to — so pinning the box drove the *panel* 0.6875 out of the room. The
0.0625 the width lookup handed it was never wrong for a 41.5; it was measured on
`ENH 41.5PanelSolid`, a part with **no trim ring**. The rule's own header already warns that
"the boxes are not symmetric about the panel"; the WDO is the part where that stopped being a
sliver.

## The fix

`scripts/build-booth-components.rb` — one branch in each of two methods, plus a named
constant carrying its provenance, in the style of `IEP_ROOM_PROUD` / `IEP_DOOR_IN`:

    IEP_ROOM_PROUD_WDO = 0.7500          # 0.0625 + 0.6875
    IEP_ROOM_PROUD_WDO_UNMEASURED = ['ENH 26.5Panel1648WDO'].freeze

    iep_room_proud:           return IEP_ROOM_PROUD_WDO if n =~ /WDO/i
    iep_room_proud_measured?: WDO is measured except the part named above

**One figure for the family, and the evidence for generalising it is the parts' own boxes,
not an assumption.** Of the 22 `ENH ...WDO` components on the share
(`_component-probe.tsv`, observed) **21 measure 1.8125 thick** — identical to the 41.5 this
was measured on — so it is the same trim ring on all of them. The exception,
`ENH 26.5Panel1648WDO` at **1.7500**, is a sixteenth thinner and may want 0.6875 instead. It
is **not** silently given the 41.5's figure: it is named in the build report, the same way an
unmeasured width already is.

**Standard is untouched by construction**, not by care: the whole rule sits inside the
`inner?(p)` guard, and the outer window is placed off a found slab that never reaches it.

## Proof — before and after, live

**`MDL 7272 E`, inner window `W1i ENH 41.5Panel3236WDO`, world-x face levels:**

| face | before | after | moved | neighbour `W0i` |
|---|---:|---:|---:|---:|
| box outboard end | 2.5000 | **3.1875** | +0.6875 | **3.1875** ✓ |
| panel outboard face | 2.5625 | **3.2500** | +0.6875 | **3.2500** ✓ |
| panel room face | 3.5625 | **4.2500** | +0.6875 | **4.2500** ✓ |
| H-strip edge | 3.6250 | **4.3125** | +0.6875 | **4.3125** ✓ |
| trim ring tip | 4.3125 | 5.0000 | +0.6875 | — (trim, into the room) |

Every face moved by 0.6875 and **four of them land on the neighbouring inner panel to four
decimal places.** Four exact hits is why this is a measurement and not a tuning.

**Nothing else moved.** Same build, outer shell:

    W1  46Panel3236WDO   0.2500 / 1.0000 / 2.0000   before AND after
    W0  22PanelSolid              1.0000 / 2.0000   before AND after

**`MDL 7272 S` built after the fix:** `W1` at 0.2500 / 1.0000 / 2.0000 and `W0` at 1.0000 /
2.0000 — **identical to the Enhanced booth's outer shell and to the pre-fix figures.** The
Standard has no inner shell, so the changed path cannot run; `W1i` and `W0i` probe
`NOT FOUND`. Harness verdict `clean`, 0 flagged.

A screenshot of the fixed inner W wall was taken (booth interior, grazing along the wall,
inner door lite on one side and the window trim ring sitting in the wall plane on the other).
**It is deliberately NOT committed** — CLAUDE.md keeps renders out of this public repo. It is
at `<scratchpad>/7272E-after-grazing.png`. It is corroboration; the numbers above are the
proof.

## Baseline diff — and a harness gap it exposed

`python scripts/rbtest-live-booth.py dry` over all 50 keys, then
`diff .forge/builder/booth-matrix/dry <new>`:

    0 unchanged, 50 changed

**That headline is noise and must not be read as 50 booths moving.** The `.txt` manifests
embed V-Ray's `material_sync` / `materials_helper` stderr, which fires on the first build of
a session and not afterwards; the golden baseline carries ~330 lines of it per file and this
run does not. Filtering only that stderr:

    2 of 50 differ, and both by a single blank line (MDL 4242 E, MDL 4872 S)
    — the gap where the stderr block used to sit. No manifest line changed anywhere.

**Including `MDL 7272 E`.** Its *real build* manifest is **byte-identical** before and after
the fix.

**So the golden baseline does not need regenerating for this change — and it also could not
have caught it.** The manifest records slot fit, facing and along-wall stations; it records
**nothing about the across-wall position**. Real geometry moved 11/16 and the recorded
artifact did not blink. That is a gap, not a pass, and it is why this fix was proven with a
separate face-level probe. Turning "an inner panel's faces must agree with its neighbour's"
into an assertion is the obvious next build — it is the same shape as the flat-floor
assertion the booth-matrix handoff already asks for, and this is its second test case.

**Baseline decision is Benton's.** My recommendation: **leave it as it is.** Nothing in it
moved, and regenerating would only rewrite the V-Ray stderr noise.

## A trap that cost a wasted build, worth knowing

`scripts/rbtest-live-booth.py:230` loads the booth builder **once per SketchUp session**:

    WRB.tool('build-booth-components') unless defined?(WR_BuildBoothComponents)

So the first post-fix build reused the stale in-memory module and produced numbers identical
to the "before" — a green-looking result that proved nothing. It was caught only because the
face-level probe was run rather than the manifest trusted. Force a reload before measuring a
code change:

    python scripts/sketchup-bridge.py --su 2026 eval \
      "load File.join(WhisperRoom::Tools::SCRIPTS_DIR,'build-booth-components.rb')"

Then confirm the rule really changed before you build — `iep_room_proud('ENH
41.5Panel3236WDO')` returned **0.75** (and the solids still 0.0625 / 0.09375) before the
build that produced the numbers above. This is the same "a Ruby module keeps its constants
until SketchUp restarts" lesson the file's own header records, in a new place.

## Checks run

- `python scripts/rbparse.py` — **59 files parse.**
- `MDL 7272 E` real build: 48 placed, deck 4 + seals 2, verdict `flagged` **before and
  after, with an identical manifest** (the flags are the pre-existing inner-shell
  self-warnings, unchanged by this).
- `MDL 7272 S` real build: verdict `clean`.
- Full 50-key dry sweep: **50 clean, 0 flagged, 0 raised**, 119.8 s.
- Nothing written to `P:` or `WhisperRoomQuote`.

## State left behind

SketchUp 2026 was **not running** when this started; I launched it (via a copy of a stock
template in the scratchpad, then `Sketchup.file_new` to reach an Untitled model, because
plugins do not finish loading on the Welcome screen). It is left **running with an empty
Untitled model** — wiped after the last build, nothing saved. Close it if you would rather it
were not there.

## Still open

1. **`ENH 26.5Panel1648WDO`** — 1.7500 thick where the other 21 inner WDO parts are 1.8125.
   It takes 0.75 and is **reported as unmeasured**. One build of a booth that uses it would
   settle whether it wants 0.6875.
2. **The `_HX` inner WDO parts** are all 1.8125 and take the same figure, but none was built
   here. Derived from the box, not observed in place.
3. **No other Enhanced booth in the 50-key matrix carries an inner window**, so `MDL 7272 E`
   is the only key this change can move today. A booth-from-link build **can** put an inner
   WDO on any Enhanced booth, and the fix is correct for those too — it is a property of the
   part, not of the 7272.
4. **The across-wall assertion the baseline is missing** (see above).
