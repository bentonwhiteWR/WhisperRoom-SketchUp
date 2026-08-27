# MDL 84126 — two Standard-deck defects, both root-caused, both fixed (v1.6.31)

Benton, 2026-08-26, off a built `MDL 84126 E` (Shell = Both). Both complaints sit in the
**Standard outer shell**, not the Enhanced inner one.

> "the 84126 E standard ceiling components side pieces need to be rotated 180. The hinges are
> on the inside right now, they should be on the outside perimeter."

> "One of the 8442FL Sides needs to move outwards 1/32. Only one, so kinda weird"

## FIRST: is this a live defect, or a build that no longer exists?

**Both are LIVE. Neither is touched by 1.6.30.** His panel read v1.6.29 and he had not pulled,
reinstalled or restarted, so the question had to be asked — but the answer is that 1.6.30 is
irrelevant to what he saw.

**observed** — I re-ran `.forge/fixer/verify-tray.py` myself against its named witness
(`_face-levels.tsv`, the 370-part full-folder run). The 1.6.30 rule returns
`ABSTAIN(no cue)` on **all 23 Standard ceilings** and decides **zero** Standard floors. The
previous Fixer's claim is correct as stated.

**observed** — the call site is gated independently of that: `iep_upside_down?` is invoked once,
at `scripts/build-booth-components.rb:909`, inside the **inner (IEP) tile loop**. No Standard
tile reaches it. `wr-deck.rb`, which places the Standard deck, was not touched by 1.6.30 at all.

So his observations describe code that is still shipping. Nothing here is a stale report.

---

## DEFECT 1 — the 1/32, and why exactly one side moves

### Root cause, one sentence
`WR_Deck.plan` steps each tile's station by its **nominal name width**, while `WR_Deck.build`
seats each tile by its **measured** low corner — so every tile is laid low-edge-first and the
undersize surfaces once, at the far perimeter, on the last tile only.

### The chain
- **observed**, `wr-deck.rb:341` — `catalogue` builds `:cross`/`:along` from the **name digits**
  (`:cross => m[1].to_f, :along => m[2].to_f`). Not from geometry. So `STD8442FL SIDE` is
  "42 wide" to the planner whatever it measures.
- **observed**, `_component-probe.tsv` — it measures **41.9688**. Its CTR measures **41.9375**.
  The difference between them, 0.0313, is the 1/32 the assignment flagged; but the figure that
  actually matters is each part against its own **nominal**.
- **observed**, `wr-deck.rb` `plan` — stations advance `pos += width` on nominal widths: 0, 42, 84.
- **observed**, `wr-deck.rb` `build` — seating is `x - got.min.x`, the **measured** transformed
  minimum corner.
- **derived** — the low tile is seated low-edge-first *at the low perimeter*, so it is flush by
  construction. Every other tile is seated low-edge-first at an interior station, so its own
  undersize opens a gap on its high side. On the last tile that gap is against the **wall**.

### The reproduction
`.forge/fixer/verify-deck-pitch.py` (witnesses: the folder listing, `_component-probe.tsv`,
`wr-booth-data.rb` — never a snapshot of `wr-deck.rb`). For `MDL 84126 S`, floor:

    STD8442FL SIDE  nom 42  meas 41.9688  station  1.0000  spans   1.0000 ..  42.9688  flush at the low wall
    STD8442FL CTR   nom 42  meas 41.9375  station 43.0000  spans  43.0000 ..  84.9375
    STD8442FL SIDE  nom 42  meas 41.9688  station 85.0000  spans  85.0000 .. 126.9688  <-- 0.0312 SHORT of 127

**0.0312 = 1/32, on exactly one of the two SIDE tiles.** That is Benton's number and his
asymmetry, derived from the code and the probe without reference to his report.

### Why he reported it on the FLOOR and not the ceiling
**observed** — every Standard **CL** part measures its nominal name exactly, so every ceiling
deck is already flush and moves by nothing. All 21 of them. The defect can only appear on floors.
That is an independent corroboration of the diagnosis: the code predicts a floor-only symptom and
a floor-only symptom is what he reported.

### The fix
`wr-deck.rb` `build` — the last tile of a multi-tile run seats against the **far perimeter**
(`far - got.max`) instead of its nominal station (`x - got.min`). Taken from `got.max` rather
than by adding a correction, so it is right whatever `deck_extent` measures.

**Blast radius, computed part by part:** 17 floor decks move, each by its own measured undersize
(1/32 or 1/16). **No ceiling moves. No single-tile deck moves** — those are excluded explicitly,
since a lone tile is both ends at once. `MDL 84126 S` floor: the high `STD8442FL SIDE` moves out
0.0312 and the deck reaches the wall.

### What this does NOT fix, stated plainly
The **interior** slack is untouched and is not claimed to be. An `MDL 84126` floor still carries
a 3/32 gap at the CTR/high-SIDE butt joint (the CTR is 1/16 under nominal and the SIDE 1/32).
Benton reported the perimeter; the perimeter is what moved. Closing interior joints would mean
re-pitching the whole run off measured widths, which is a different and much larger change.

---

## DEFECT 2 — the ceiling hinges

### Root cause, one sentence
A ceiling's plan rotation is taken from its **floor twin** on the strength of an unmeasured
"coplanar hinges" invariant, and for the 17 Standard ceiling parts authored pre-inverted about
their long axis that invariant is false — their bracket line sits at the **opposite** end of the
tiling axis, so the twin's fraction turns them exactly the wrong way.

### Nobody had ever looked
**observed** — `reference/floor-ceiling-geometry.md:251-265` states "FLOOR AND CEILING HINGES ARE
COPLANAR IN PLAN". Its entire evidentiary basis is the two words *"Also Benton"* (line 253). No
probe, no TSV, no numbers — in a document where every neighbouring claim carries a measured table.

**observed** — the same file, lines 331-338, records that the check can never have been run:
`probe-levels.rb` *"prints nothing for ceilings, because their deck is detected at the top of the
box and nothing sits above it."*

**observed** — the `bracket_edge` rule (commit `03f6441`) was validated by **simulation**, over
**floor** parts. The DEVLOG lists the follow-up build confirmation as still owed, twice
(`DEVLOG.md:2545`, `:2621`), and no entry ever closes it.

**Negative result, stated as prominently as the wins:** there is no record anywhere — DEVLOG,
`reference/`, `.forge/`, or any commit message — of a Standard **ceiling** deck's plan rotation
being confirmed correct, by eye or by probe. Every booth sign-off in the corpus is floor-scoped
(`b6aa682`: *"The 7224 FL was confirmed correct"*). Every ceiling report is about **vertical**
flip or z-height, never plan rotation. **Benton is the first person to look at one.** The absence
of prior complaints is not evidence the ceilings were right; it is evidence nobody checked.

### The two authoring conventions — measured, not named
`.forge/fixer/verify-ceiling-cue.py`, sole witness `_face-levels.tsv`. The 23 Standard ceiling
parts split cleanly in two, and the split is a **measured signature**, not a name rule:

| | rim_z | area above rim | `contact_z` flip | count |
|---|---|---|---|---|
| **B** authored like a floor, turned over by the code | 1.7500 | > 0 | **true** | 6 |
| **A** authored already inverted | 3.1094 | **0** | false | **17** |

**Convention B is measured to be coplanar, and must not move.** An X-axis 180 mirrors Y and
leaves the short (tiling) axis alone, so the plan position survives the flip — and it does:

    STD9648CL SIDE   own bracket_edge  0.7366
    STD9648FL SIDE   floor twin        0.7366     <- identical to four decimals

That is the **only** Standard ceiling part carrying a cue of its own, and for it the invariant
holds exactly. It is also the sole measured support the invariant has ever had — one part pair,
generalised to 23.

**Convention A cannot be measured by the current probe** (nothing above its rim; `bracket_edge`
returns nil for all 17). Its hardware hangs *below* the plate. Being authored pre-inverted about
the **long** axis mirrors the short axis, putting the bracket line at the opposite end from the
floor twin's — and the code applies the twin's fraction unmirrored. **reported** (Benton, the
authority on how these assemble): that is what he is seeing on the 84126.

### The fix
`wr-deck.rb` `build` — a ceiling uses its **own** cue when it has one, and the **mirror**
(`1.0 - e`) of the twin's when it does not. Floors always have a cue of their own and are
untouched.

- Convention B takes its own reading, which **is the same number as the twin's** — provably no
  change. Verified: the entire 96 series ceiling is unchanged before and after.
- Convention A takes the mirror. This is the change.

**Blast radius:** 18 ceiling end-tiles across the 60, 72, 84 and 102 series. **Zero floor tiles
change rotation** (control run, expected 0, got 0). **Zero 96-series ceiling tiles change**
(control run). `MDL 84126 S`: **both** ceiling SIDE tiles reverse — which is exactly what Benton
asked for, in the plural, and I derived it before reading his sentence that way.

### Confidence, at its weakest link
**reported.** The measured part is the two-convention split and convention B's coplanarity. The
*direction* of convention A's mirror rests on Benton's single observation of one booth,
generalised across a measured class of 17 parts. That generalisation is the weakest link in this
document and it is not hedged away: if convention A is not uniformly authored, some booth will
come out turned the wrong way.

**What falsifies it:** any convention-A ceiling that still reads hinges *inboard* after v1.6.31,
or one that read *correct* before and reads wrong now. The 72 series is the one to watch — its
floor was signed off in August, its ceiling never was, and it moves here.

---

## Two things found on the way, flagged not fixed

1. **`STD7224FL SIDE R.skp` is defective.** `_component-probe.tsv` measures it **37.9375 x 72**
   where its name says 24 across, with `origin_anchor max/min/min`. Both harnesses refuse to
   guess a width for it rather than silently pick one. This means **`MDL 7272 S`'s floor is
   ~14 in wrong at the high end** and has been all along. Component-authoring fix, Benton's to
   make, not a code change. Same class as the `RightSideVent_CP_HX` defect already open.

2. **The window-end question (HANDOFF open item 2) is now answerable, and I did not answer it.**
   It asked for a hinge datum *"that does not move when the door moves."* `hinge_runs`
   (`wr-deck.rb:149`) measures exactly that along the panel's long axis, and `probe-levels.rb`'s
   `brackets` already computes it — but **only the TSV's short-axis `bracket_edge` is persisted;
   the long-axis runs are printed to the console and thrown away.** Adding a `runs` column to
   `_face-levels.tsv` would close it. **Flagged as newly answerable. Deliberately left.**

3. **Neither fix reaches the Enhanced inner deck.** `build-booth-components.rb` calls
   `WR_Deck.plan` but runs its own placement loop and never calls `WR_Deck.build`, so the inner
   deck keeps both behaviours. `ENH 8418 FL` measures 17.9375 — 1/16 under nominal — so an inner
   floor ending on it carries the same perimeter gap. **Deliberately out of scope:** Benton
   reported the Standard deck and the fence was lifted for the Standard deck. Flagged, not fixed.
