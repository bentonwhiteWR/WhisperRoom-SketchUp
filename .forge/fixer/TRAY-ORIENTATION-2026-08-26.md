# IEP TRAY ORIENTATION — the abstention is lifted (v1.6.30)

**Witness.** `P:\Sketchup\NewMasterComponentList\_face-levels.tsv`, **380,767 bytes, written
2026-08-26 19:38, 6,625 lines, 1,761 of them `ENH`.** Benton's full-folder run of
`scripts/probe-levels.rb` with a blank filter, all 370 parts. Read directly off `P:`, which is
reachable from this machine. **It replaced a 259,014-byte file dated 2026-08-14 that carried no
`ENH` face levels at all** — which is precisely why the tray rule had been abstaining.

**This document is not checked against a copy of itself.** The TSV is the sole input to
`.forge/fixer/verify-tray.py`, whose header names it. Nothing here is compared against
`_enhanced-probe.tsv`, `_component-probe.tsv`, or any repo snapshot. The one repo-derived input
is the *transcription* of the two Ruby functions under test, and that is stated as derived below.

---

## Symptom

`scripts/build-booth-components.rb` `iep_upside_down?` returned **`NO ORIENTATION CUE — left as
authored`** for 11 of the 23 `ENH` ceiling parts, so those tiles were placed however the `.skp`
happened to be modelled. Four of them are modelled upside down, so the tray opened **upward**
instead of capping the standard ceiling. That is the defect Benton reported on the **MDL 102144 E**
and which v1.6.25 did not actually fix — v1.6.25 made the decision per-part, but the per-part rule
still abstained on exactly those parts.

## Root cause, in one sentence

**`IEP_LEVEL_MIN_SHARE = 0.05` deleted the tray's rim from the level list before the mouth ratio
could see it**, leaving the rule to compare the plate against the plate's own underside — two
near-equal areas — and abstain.

An `ENH` tray has exactly three flat levels and nothing else (**observed**, all 23 parts):

| level | what it is | area |
|---|---|---|
| PLATE | the closed end | `box_x × box_y`, the whole footprint |
| FIELD | the plate's underside | footprint less the 1 in lip inset |
| RIM | the open mouth | a 1 in ring on the **outer** edges only |

The rim of a CTR or a long tile is `2 × cross × 1 in` against a plate of `cross × run` — **84 sq in
against 4,368 on `ENH 10242CL CTR`, 1.9% of peak.** Under a 5% filter it is discarded as a chamfer.
The threshold sat directly on top of the answer: measured rim shares run **1.9% to 6.6%**, and the
only rims that cleared 5% are the single-piece and short tiles. That is exactly why the closed
**MDL 4872 E** (`ENH 4872CL`, rim 6.6%) read correctly and the **MDL 102144 E** did not.

## What the fresh TSV says

Two parts, mirror images in z (**observed**):

```
ENH 4872CL       box 50 x 74    z 1.7500 -> 3700 PLATE   0.7500 -> 3456   0.0000 ->  244 rim
ENH 10242CL CTR  box 42 x 104   z 1.7500 ->   84 rim     1.0000 -> 4284   0.0000 -> 4368 PLATE
```

**Four of the 23 `ENH` ceiling parts carry the plate at the LOW end and are therefore authored
upside down** (**observed**):

| part | box | low level | high level | verdict |
|---|---|---|---|---|
| `ENH 10218CL CTR` | 18 × 104 | z 0.0000 → **1872** | z 1.7500 → 36 | FLIP |
| `ENH 10242CL CTR` | 42 × 104 | z 0.0000 → **4368** | z 1.7500 → 84 | FLIP |
| `ENH 10242CL SIDE` | 43 × 104 | z 0.0000 → **4472** | z 1.7656 → 188 | FLIP |
| `ENH 8442CL SIDE` | 43 × 86 | z 0.0000 → **3698** | z 1.8281 → 170 | FLIP |

The other 19 carry the plate at the high end and are correct as authored.

**`ENH 8442CL CTR` is authored the right way up while `ENH 8442CL SIDE` is not.** Same family,
same cross, opposite convention. No name-level or family-level rule can catch that — it has to be
measured per part, which is what the code already does and why this was worth fixing rather than
tabulating. (This is the same shape of finding as the width-axis split in
`.forge/fixer/WIDTH-AXIS-FAMILY-2026-08-26.md`: ad hoc per file, no name rule.)

## The rule now

Compare the levels at the **two ends of the box** — lowest and highest flat face — with **no share
filter**, because the filter was the bug. One end must hold a plate, the other a rim:

```
plate  area >= peak * IEP_PLATE_MIN_SHARE (0.50)
rim    area <= peak * IEP_RIM_MAX_SHARE   (0.25)  AND  area >= IEP_RIM_MIN_AREA (10.0 sq in)
```

Plate high → mouth down → as authored. Plate low → mouth up → **FLIPPED**.

Each figure has a measured moat, so a future part is judged against a spread and not a taste
(**observed**): plates run **64%–100%** of peak (the 64% is the non-rectangular `ENH 127LPCL`);
rims run **1.9%–6.6%**; nothing in the library falls between 25% and 50%.

**The absolute area floor is what keeps the rule Enhanced-only in effect as well as in name.** A
Standard ceiling carries a **1–3 sq in** chamfer at each end of its box, which on share alone would
read as a tray mouth. The smallest genuine `ENH` rim is **36 sq in**. 10 sq in sits in that gap with
an order of magnitude on either side.

## The precedence against `contact_z` is reversed, and this is the part to argue with

The old comment said *"contact_z's TRUE wins outright … the two cannot fight."* **They do fight, on
exactly one part, and `contact_z` is the one that is wrong.**

`ENH 127LPCL` measures `1.7500 → 2196.47` (plate), `1.0000 → 2017.09` (its underside),
`0.0000 → 179.38` (rim). `contact_z` hunts for a face pair 1.0000 apart, finds **rim-to-underside**
at `0.0000/1.0000`, calls that the Standard slab, and is then left with the **plate** at 1.7500 as a
"minor level above the slab" — which for a ceiling is its upside-down verdict. So it turns over the
one `ENH` tray whose plate-to-underside happens to measure 0.7500 instead of 1.0000.

Re-running `contact_z` offline over the fresh TSV: **`ENH 127LPCL` is the only one of the 23 `ENH`
ceiling parts it answers `true` on** (**derived**, from the transcription — see Confidence).

`contact_z` is a Standard-slab detector and an `ENH` tray has no Standard slab. The existing comment
already warned that its `false` could not be trusted here; this is the same defect in the other
direction. The mouth tell reads the part's actual shape and needs no slab, so it now goes first and
`contact_z` is the fallback.

**This changes nothing on any real build today.** `ENH 127LPCL` is an orphan — none of the 25 `E`
layouts tiles it. It is fixed because it is wrong, not because a booth needs it. **`wr-deck.rb` is
still called read-only and was not edited.**

## Blast radius — nine of the 25 `E` layouts

Cut lists **derived** by an independent run of the existing `.forge/builder/replay-iep-deck.py`
against the live library (all its self-checks passed; 44 ENH deck codes found, 22 FL + 23 CL):

| layout | inner ceiling tiles, low end → high end |
|---|---|
| MDL 8484 E | **8442CL SIDE**, **8442CL SIDE** |
| MDL 10284 E | **8442CL SIDE**, 8418 CL, **8442CL SIDE** |
| MDL 84102 E | **8442CL SIDE**, 8418 CL, **8442CL SIDE** |
| MDL 84126 E | **8442CL SIDE**, 8442CL CTR, **8442CL SIDE** |
| MDL 102102 E | **10242CL SIDE**, **10218CL CTR**, **10242CL SIDE** |
| MDL 102126 E | **10242CL SIDE**, **10242CL CTR**, **10242CL SIDE** |
| MDL 102144 E | **10242CL SIDE**, **10242CL CTR**, **10218CL CTR**, **10242CL SIDE** |
| MDL 102168 E | **10242CL SIDE**, **10242CL CTR** ×2, **10242CL SIDE** |
| MDL 102186 E | **10242CL SIDE**, **10242CL CTR**, **10218CL CTR**, **10242CL CTR**, **10242CL SIDE** |

Bold = a tile that moves. **The other 16 layouts do not move.** In particular **`MDL 6060 E`
(`ENH 6042CL SIDE L` + `ENH 6018CL SIDE R`) and `MDL 4872 E` (`ENH 4872CL`) tile none of the four**,
so the current GOAL work and the one closed, probe-verified booth are both untouched. That the
already-signed-off 4872 E does not move is the strongest regression check available offline.

## How this was verified

`.forge/fixer/verify-tray.py` — sole input the TSV, header names it. It re-implements
`WR_Deck.contact_z`, the **old** `iep_upside_down?` and the **new** one, and reports:

- old rule: **11 of 23** `ENH` ceilings abstain, including all four that need turning over;
- new rule: **23 of 23** decided — 19 down, 4 flipped;
- **all 23 Standard ceilings still abstain under the new rule** — the safety property
  `.forge/builder/replay-iep-deck.py` asserts, preserved by the area floor;
- all Standard **floors** also abstain, checked even though `kind == 'CL'` gates them out.

`python scripts/rbparse.py` → **52 files parse** on the CRuby 3.2 SketchUp ships.

## Confidence — at its weakest link

**The weakest link is that the TSV is a faithful stand-in for `WR_Deck.flat_levels` at build time.**
That is **derived**, not observed: `probe-levels.rb`'s `levels` and `wr-deck.rb`'s
`flat_levels_with_exact` use the same 0.999 flat test, the same 1/64 bin, and the same recursive
face walk — but they are two functions, and I could not execute either. If they diverge, the
verdicts diverge.

Everything about the parts themselves is **observed**. The cut lists are **derived** from a Python
transcription of `plan`. The reading that "plate up = correct" is **reported**, from Benton via the
DEVLOG: *"the tray faces downwards, and it sits on top of the standard ceiling, completely
engulfing it."*

**UNRUN IN SKETCHUP.** No claim here is a build. Every tile prints its verdict and its reason to
the console, so a wrong call is visible in text and not only on the screen.

## What Benton should build

**Build `MDL 84126 E`, Shell = Both.** It is the one booth that shows both halves of the rule in a
single deck: its two `ENH 8442CL SIDE` end tiles flip and its `ENH 8442CL CTR` middle tile does not.
**Before this change that deck has its two end trays opening upward and its middle tray opening
downward** — a mismatch inside one ceiling. After it, all three should cap the standard ceiling the
same way.

**Look at:** the inner ceiling from below. All three trays should show a closed plate facing down
onto the standard ceiling, with no tile showing an open box. **In the console**, three
`tray mouth reads …` lines: `UP … FLIPPED` for the two `SIDE` tiles, `DOWN` for the `CTR`.

**This needs a full restart, not a rescan** — `VERSION` is under `wr_tools/`, so `git pull` →
`install-plugin.py` → **restart SketchUp**. A Ruby module keeps its constants until restart, and
`IEP_PLATE_MIN_SHARE` / `IEP_RIM_MAX_SHARE` / `IEP_RIM_MIN_AREA` are new constants: a console report
made before the restart says nothing about them.

Second booth if the first looks right: **`MDL 102144 E`**, where all four tiles flip and Benton
already has console history to diff against.

---

# `SEAL_FL_DATUM_LIFT` — a correction, and the answer is no

**The premise I was given is out of date.** `WR_Deck::SEAL_FL_DATUM_LIFT` **is not `nil`.** It is
**`-1.1250`**, at `scripts/wr-deck.rb:1073`, shipped in **v1.6.27** (**observed**, read off the file
and confirmed in `DEVLOG.md`). `.forge/GOAL.md` step 3b — "Benton hand-measures the `STDSS FL5`
seal because the code could not" — **is stale and has been struck from the GOAL.** There is no
`-1.1250` versus GOAL disagreement to reconcile: the GOAL's own v1.6.27 note and the constant in the
code are the same number.

**Does the fresh TSV settle it? No, and it could not.** The seal's own geometry is confirmed
(**observed**) — `STDSS FL5/6/7/8` all measure `TOP 0.6875`, `BOTTOM -1.0000`, box_z `1.6906`, and
the largest face is at `-1.0000`, which is the datum the code picks. But that describes the *part*.
The lift is a statement about where that profile sits in the *booth*, and the TSV carries no
information about the slot the seal engages.

Tested explicitly against the panel geometry: with `-1.1250` the seal's faces land at booth
`0.5625 / 0.3125 / -0.0625 / -0.1250 / -1.0625 / -1.1250` and a standard floor panel's land at
`-1.0000 / 0.0000 / 0.7500 / 0.9219 / 1.3594 / 2.1094`. **Not one coincides** — and a
face-coincidence argument would have picked `-1.6906` (top flush with the walking surface) or
`-1.0000` (bottom flush with the panel underside), which are two of the three candidates Benton's
hand ruled out. So face coincidence is not the criterion here, the TSV cannot settle it, and it does
not contradict `-1.1250` either.

**Verdict: leave `-1.1250` alone.** It is a fit test off a built MDL 102144 E and it outranks
anything derivable from the TSV. Nothing in `wr-deck.rb` was changed, so **a Standard booth sees
nothing different** from this session's work.

**What the fresh TSV does add**, at no cost (**observed**): it independently confirms the datum
logic `datum = tally.max_by { area }` across the whole seal library, including `STDSS 8.5FL`, which
was not in the 2026-08-14 data — floor seals `-1.0000`, ceiling `CL5/6/7` `0.0000`, ceiling `CL8`
`-0.7500`, exactly as the comments in `wr-deck.rb` claim.

## What was NOT checked

- Nothing was run in SketchUp. No claim here is a build.
- The **floor mats** were not re-examined for orientation, and correctly so: every `ENH FL` part has
  exactly **two** flat levels of **equal area** (**observed**, all 22) — a plain 0.3125 sheet with no
  mouth to point. `IEP_FL_UPSIDE_DOWN = false` is confirmed by the data, not just declared. The
  end-for-end question is `iep_half_turn?`, a different rule, and it is untouched.
- The **perimeter-strip heights and top/bottom steps** for the `ENH` deck were read but imply no
  code change: `ENH` ceilings step `1.0000` plate-to-field (`0.7500` on `ENH 127LPCL`) and `ENH`
  floors have no step at all. `IEP_TRAY_DROP = 0.75` is the skirt depth and the TSV agrees with it —
  unchanged.
- `.forge/builder/replay-iep-deck.py` **still contains the stale assertion that
  `_face-levels.tsv` has zero `ENH` rows.** It was run this session and passed, but that section 9
  is now describing a file that no longer exists. Left alone deliberately — it is the Builder's
  harness, not mine — and flagged in `HANDOFF.md`.
