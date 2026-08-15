# DEVLOG

## 2026-08-15 — the panel is rebuilt, and flipping a switch no longer opened a dialog

**`scripts/wr_tools/panel.html`** rewritten, **`scripts/wr_tools/main.rb`** extended,
29 purpose-built icons added, and header lines touched across `scripts/*.rb`.
Steps 1–5 of `.forge/scoper/panel-redesign.md`; 6 and 7 were deliberately
left. **Nothing here has been run in SketchUp** — see the last section, which is
as much of this entry as the wins are.

### The defect that gated the whole thing

`main.rb#toggle` did `load` on the ability's file and then evaluated its `@on`
expression. Every ability script also ends in a top-level autorun — the line that
makes `load "…/explode-view.rb"` in the Ruby Console actually do something — and
`toggle` set **neither** suppression global. So flipping a switch ran the
script's normal entry point first, modal dialog and all, and then did the work a
second time with whatever the dialog returned. `explode-view.rb`'s own header
says the ability path exists precisely so a modal never gets in the way of a
toggle.

Two of the five ability scripts had no guard at all to set (`explode-view.rb`,
`proposal-scenes.rb`; they have one now), and the three that did had drifted into
two spellings — `auto-dimension.rb` reads `$wr_suppress_autorun`, the other four
read `$wr_no_autorun`.

`load_quietly` sets **both**, so neither script has to change and an ability
written to either spelling is already covered — and **restores the previous
values afterwards**, which is the part worth recording. Leaving them set silences
the autorun for the next script *run* from the list, and a script that loads and
then does nothing presents as a dead button. `booth-from-link.rb` and
`build-room.rb` already save-and-restore for the same reason; this is that
pattern, not a new one.

### Three new header directives, all optional

The property that matters is not what they do, it is that **a script declaring
none of them renders exactly as it did before**. That was an acceptance
criterion, not a happy accident — the redesign had to be worth zero edits across
40 script files, so every one of these is additive and parsed beside `@cat` in
`meta_of`:

| Directive | Grammar | What it does |
|---|---|---|
| `# @icon <id>` | one token | Names a symbol in the sprite. Resolution is `@icon` → `icon-map.json` → `wr-default`. |
| `# @shelf dev\|workshop\|archive` | one keyword | Keeps the script off the default list, behind the footer switch. |
| `# @rank <n>` | signed integer only | Sorts within a category; lower first, unranked sinks below every ranked row. |

`@rank` parses integers only and leaves anything else as *no rank* rather than
letting it become 0, because a typo sorting to the top is worse than a typo doing
nothing. The icon fallback is deliberately loose at both ends: `wr-icons.svg` and
`icon-map.json` may both be missing and every row still draws the house glyph,
because a missing sprite must never blank the list.

### Why two categories are ranked and the rest are not

Alphabetical is right for a set and wrong for a sequence. *Build the booth* is
three ways in, best first, and by title alphabetical opened with
**Block-out booth (plain boxes, fast)** and buried
**Build the customer's booth (share link)** at the bottom. The eye lands on the
first row, so that order did not merely fail to help — it recommended the fast
low-detail block-out to someone who had a customer's actual configuration in
hand. Same class of error in *Scenes and images*: **Set up the five proposal
plates** sorted last, behind the two exporters that consume the plates it makes.

Everything else is left alphabetical on purpose. *Add dimensions* holds three
different subjects rather than a sequence, so nothing is misread by sorting them
by name, and *Pinned* keeps toolbar-slot order because that order is its meaning.

### The icon rules, and what enforces them

24-unit grid with a 20-unit live area, 1.8 centred stroke (1.4 / 1.2 for
deliberately recessive context marks — extension lines, ghosts, level rules), two
inks only: graphite for context, and `#ee6216` on **exactly one element, the
thing the tool creates or changes**. The house motifs are the booth (solid rect +
door return), the room (open rect + door swing arc), and the dimension string
(oblique drafting ticks, never arrowheads — Benton's own drawing convention). The
failure test is the useful half: **an icon serving two tools is rejected**, which
caught three real collisions in the mockup (`i-scenes` served two scripts,
`i-scenecomp` four, `i-probe` three).

`.forge/builder-icons/gen-icons.py` is the source of truth — it emits all 29
standalone `wr-ico-*.svg` files, the sprite, `icon-map.json` and the contact sheet
in one pass, and exits non-zero on a duplicate id, a wrong `viewBox`, an
off-contract stroke width or geometry outside the live area. Hand-editing any one
of the four outputs makes them drift, so don't.

The library glob now takes `wr-ico-*.svg` **beside** `ico-*.svg` and resolves a
saved slot id through both, so the ids already sitting in preferences keep
working.

### What was deliberately not done

Both of these are cheap to re-propose and expensive to get wrong, so the reasons
are here rather than in a commit message.

- **The pre-run settings sheet** (spec step 6) touches `meta_of`, which every
  panel render runs. A regression there does not degrade the list, it blanks it.
  It is a separate round on its own.
- **Deleting the legacy `ico-*.svg` library** (spec step 7). Saved `slot_icons`
  prefs still reference those ids; deleting them regresses the toolbar to
  numbered faces.
- **`booth-4260-s.rb`, `booth-96168-s.rb` and `csusb-rooms.rb` were shelved, not
  retired.** Deleting them was proposed and refused: it is the one irreversible
  call in the set and it is Benton's. `csusb-rooms.rb` is additionally cited in
  `CLAUDE.md` as the worked example, so shelving keeps that reference true. They
  sit on a third shelf, "One-off & superseded".

### Unverified — the honest half

**Nothing was run in SketchUp.** The checks that exist are headless render
assertions over a real payload plus desktop Chrome at 330 px and 640 px, and they
say nothing about the following, all of which need a live session:

- The autorun fix, across all five ability scripts.
- The toolbar pending state clearing across a SketchUp restart.
- Whether SketchUp's embedded Chromium honours `prefers-color-scheme` at all. The
  tokens also answer to `:root[data-theme]`, so if it does not, a manual theme
  pref is one line of JS and no restyling.
- Collapse state and the developer-tools switch surviving a panel reopen.
- **Icon legibility at 20 px was never rendered by anyone.** Every geometric claim
  about the set is parsed, not seen. `.forge/builder-icons/contact-sheet.html` is
  the instrument — open it in a browser. The `wr-dim-booth` / `wr-dim-selection`
  pair and the two `booth-preset-*` icons are the ones to look at first.

### One open question for Benton

Six scripts carry a proposed title in the Researcher's tree that was **not** among
the 14 approved renames, so their old titles are untouched and the list now reads
inconsistently against its neighbours: `list-scenes.rb`, `orbit-export.rb`,
`explode-view.rb`, `save-scene-components.rb`, `find-replace-names.rb`,
`merge-materials.rb`.

## 2026-08-14 — a booth-specific dimension tool

**`scripts/dimension-booth.rb`** (new). The three figures that go on a
WhisperRoom drawing, taken from the catalogue rather than measured.

`dimension-selection.rb` already measures a bounding box, and that is exactly why
this is a second tool rather than a setting on that one. A built booth's box also
contains the door leaf modelled standing open, a VSS silencer stack, a
condensate pan below the floor and any ADA ramp. A 7296 measures over ten feet
long that way, and the number would go in front of a customer. So the model
NAMES the booth and the size comes from `wr-booth-data.rb` plus one rule.

### The rule, and why it is not a guess

A vented face adds **5.5 in to the dimension on its own axis** — per FACE, not
per vent. It reproduces both worked examples exactly:

| booth | vented | dimensioned |
|---|---|---|
| MDL 7296 S | N only | **8'2" x 6'7 1/2"** |
| MDL 96120 S | N and E | **10'7 1/2" x 8'7 1/2"** |

The first is Benton's own worked example; the second is read straight off a
dimensioned render he made before this script existed. Two independent
confirmations of one rule.

Per-face is what makes the 7296 work: it carries two vent sets and both sit on
N, so N projects once and the booth gains 5.5 in, not 11.

Heights are `Standard 6'11"` (83.0000) and `Enhanced 7'-0 5/16"` (84.3125). The
standard figure is also what the built model comes to — floor underside −1.0,
wall 0 to 81, ceiling top 82.0 — which is a free check on the deck work above
rather than a coincidence.

### The one thing deliberately left open

**5.5 in is the NO-EFS figure.** An EFS wall stands further out and that distance
has never been measured, so `VENT_PROUD` is a dial with the reasoning written
beside it rather than a constant. It specifically must not be confused with the
10 in EFS figure in `CLAUDE.md`, which is a *clearance to leave around* the
booth, not the booth's own projection.

### It identifies the booth — there is no dropdown, deliberately

A dropdown is a second place for the answer to live, and the two drift apart the
moment a booth is rebuilt as a different model. Select the booth; it works out
which one, by two routes, and the console always says which one answered:

1. **The group name.** `build-booth-components.rb` names its group
   `MDL 96120 S (components)`, so the key is sitting there. Exact, and normal.
2. **The deck part names.** `wr-deck.rb` names each panel after its file, so
   `STD9648FL SIDE` + `STD9624FL CTR` + `STD9648FL SIDE` is 96 across by 120
   along, and the exterior is that plus the 1 in inset per side.

Every model resolves uniquely by route 2 — verified against the deck plan for
all 25. **`MDL 10284 S` and `MDL 84102 S` are the same 86 × 104 rectangle turned
90°** and even share a deck (84 × 102), so the tiling *direction* is measured
from where the panels actually sit to separate them. If it cannot, both
candidates are reported rather than one being picked.

No route means no answer: it says so and stops, because the alternative is a
plausible model name on a drawing.

**Vents come off the placed parts, not the layout data** — the layout says what
kind of slot a wall has, the placed part says what actually went in it, so a
booth whose vent was moved for a customer dimensions as built. It falls back to
the layout when parts are not named per slot, and says when the two disagree.
EFS and HX parts are both detected and reported, never guessed at: the EFS
projection is unmeasured and there is no agreed drawing height for HX.

Own tag, `WR-Dims-Booth`, separate from `dimension-selection.rb`'s so both can be
on at once — and it counts that tool's dimensions if they are present, because a
booth carrying both shows two different footprints with nothing saying which is
which. That has already happened once: a 96120 reading 10' 8 7/16" x 9' 11 1/2"
off a bounding box against its catalogue 10' 7 1/2" x 8' 7 1/2".

## 2026-08-14 — the deck orientation is measured now, and the 96 series is the odd one out

Three defects reported on the MDL 96120 S. All three are fixed, and none of them
needed a constant to be guessed at.

### The 96 series carries its bracket line at the opposite end

The turn was positional — turn the high-end tile, leave the low one. That made
the MDL 7272 S correct (confirmed by Benton) and the MDL 96120 S wrong at **both**
ends, which is only possible if the parts differ rather than the rule. The full
237-part probe says exactly that, measuring the bracket line as a fraction across
the panel's short axis:

```
STD7224FL SIDE R   0.218      STD9648FL SIDE   0.737
STD7248FL SIDE L   0.261      STD9648CL SIDE   0.737
STD10242FL SIDE    0.240      STD6018FL SIDE R 0.216
STD8442FL SIDE     0.266      every CTR        0.500
```

`wr-deck.rb` now turns each SIDE panel so its bracket line faces out. Simulated
across the decks: the 7272, 6060, 6084 and 102102 are **unchanged**, and only the
96 series flips — both of its SIDE panels, at once, which is precisely the report.

This retires the `SIDE_R_SMALL_WALL_AT_LOW_END` plan in
`reference/floor-ceiling-geometry.md`. That was written when the only measurement
being attempted ran *along* the long axis, where L and R are genuinely
indistinguishable — the 6042 pair still reads 0.430 for both. Measuring *across*
the short axis is a different question and it does have an answer.

**Orientation is read off the FL part for both decks.** A convention-A ceiling
has nothing above its rim to measure and yields no cue; its floor twin always
does. That is the coplanar-hinges invariant used as a rule rather than a check.

### The other two were already fixed by the contact_z work

Confirmed against the real probe numbers rather than the doc's summary:

- **`STD9624CL CTR`** (1.7500 / 1.0000 / 0.0000, all over half the peak) fell
  into the `minor.empty?` branch, which returns `flip = false` unconditionally —
  so the part stayed as modelled, upside down. It now reads minor = 1.7500 above
  the slab and flips. **Fixed.**
- **`STD9648CL SIDE`** has its 1.0000 face at 45% of peak, under the old 50%
  threshold, so the slab came out as 0.0000/1.7500 and contact as 1.7500 instead
  of 1.0000 — 0.75 in high. **Fixed.**
- **`STD9624FL CTR`** carries a 6% lip at 0.0312 inside its slab, read as the
  room-side tell, flipping every floor centre panel. **Fixed.**

Worth noting the two ceiling parts also disagreed with each other: the SIDE
landed 79.64–82.75 and the CTR 81.00–84.11. That is the mismatch visible in the
screenshot, and both now land 78.89–82.00.

## 2026-08-14 — the narrow deck panel goes over the short wall, not at the end

Benton on the MDL 96120 S: *"It should have two 9648 side pieces, and then the
center piece. However, in all situations, the smaller ceiling would crossover in
one of the middle sections, on top of the 22 in wall."* Both halves of that are
now implemented, and the second half turned out to be derivable rather than a
preference.

`tile` is greedy — as many full-width panels as fit, remainder last — so the
96120 came out `48 + 48 + 24` with the narrow strip standing on the end wall and
only ONE 9648 SIDE panel in the deck. It should be `48 + 24 + 48`: two SIDE
panels with the 9624 CTR between them.

### The position is read off the wall layout, not chosen

Every booth in this group has exactly one short run in its long walls, and the
narrow deck panel bridges it:

```
96120   walls  46 | 22 | 46          short wall  50..72
        deck   48 | 24 | 48          odd tile    49..73   covers it
96168   walls  46 | 46 | 22 | 46     short wall  98..120
        deck   48 | 48 | 24 | 48     odd tile    97..121   covers it
```

So `order_cuts` places the odd tile at whichever index centres it on the short
wall run, and `short_wall_mid` reads that run out of the layout data. One rule,
nothing to tune.

**It reproduces both decks already confirmed correct.** The MDL 7272 S (48 + 24)
and MDL 6060 S (42 + 18) have their short wall at the high end, so the odd tile
stays exactly where greedy tiling already put it. Neither moves. That is the
check that the rule is right rather than merely convenient.

### Simulated across all 25 models against the real library

Seven reorder, and in every one the odd tile spans the short wall:

| Booth | Was | Now |
|---|---|---|
| MDL 96120 S | 48 / 48 / **24** | 48 / **24** / 48 |
| MDL 96168 S | 48 / 48 / 48 / **24** | 48 / 48 / **24** / 48 |
| MDL 102102 S | 42 / 42 / **18** | 42 / **18** / 42 |
| MDL 102144 S | 42 / 42 / 42 / **18** | 42 / 42 / **18** / 42 |
| MDL 102186 S | 42 / 42 / 42 / 42 / **18** | 42 / 42 / **18** / 42 / 42 |
| MDL 10284 S | 42 / 42 / **18** | 42 / **18** / 42 |
| MDL 84102 S | 42 / 42 / **18** | 42 / **18** / 42 |

The other 18 are unchanged — either a single tile, all one width, or the two
confirmed booths above. The 96120 now plans
`STD9648FL SIDE | STD9624FL CTR | STD9648FL SIDE`, which is what Benton asked for.

A knock-on worth noting: the end tiles now both ask for SIDE and get it. Before,
the 24 in end asked for SIDE, found none at that width, and silently fell back to
CTR — so the deck was short a SIDE panel as well as having it in the wrong place.

## 2026-08-14 — deck hand selection, and one part that needs exporting

> ### FOR BENTON, MONDAY
>
> **Export `STD7248FL SIDE R.skp` and `STD7248CL SIDE R.skp` into
> `P:\Sketchup\NewMasterComponentList`.** They are the only two files missing,
> and the MDL 7296 S is the only booth that needs them.
>
> A right-hand 7248 floor already exists in the old library —
> `P:\Sketchup\MasterComponentFolder\History\Floor component (7248 side right) as shipped.skp`
> and `…(7248 side right)  all hinges.skp` — so this is probably a re-export
> under the STD naming scheme rather than new modelling. There is no equivalent
> right-hand ceiling in History; that one may need making.
>
> Nothing else is needed. The code side is done and pushed.

**The bug Benton reported: the 7296 pulls SIDE L at both ends.** Confirmed, and
the cause is not what it looked like.

`WR_Deck.pick` took `handed.first` and ignored which end the tile was at — the
`at_low_end` argument was literally named `_at_low_end` and unused. The comment
justified it: the 72 series ships one hand per size, so there is no choice to
make. That is true of an **MDL 7272 S**, which tiles 48 + 24 and therefore draws
`STD7248 SIDE L` low and `STD7224 SIDE R` high no matter what `pick` does. It is
why the 7272 has always looked right, and it is why the dead code went unnoticed.

It is false for the **MDL 7296 S**, which tiles **48 + 48**. Both ends ask for a
7248, and only `STD7248 SIDE L` exists — so both ends got a left-hand panel, and
`substituted` was reported as `false` because there was only one hand to choose
from. A silently wrong deck that read as a clean build.

### The fix, and what it does and does not touch

`pick` now chooses **L at the low end, R at the high end**. That rule is read off
the two booths already confirmed correct, not chosen: the 7272 has SIDE L low and
SIDE R high, and the 6060 does the same with `STD6042 SIDE L` and
`STD6018 SIDE R`. Where only one hand exists, nothing changes.

**Orientation is untouched.** The half turn on the high-end panel stays exactly
as it was — that is the state confirmed on the 7272, and picking the file by end
and turning the panel by end are two independent rules that both happen to key
off position. Tangling them is the mistake that cost an evening; this does not
re-tangle them.

`substituted` now means what its name says — this end wanted a hand the folder
does not have — and it is pushed to the deck warnings so it prints.

### Simulated across all 25 models against the real library

| Booth | Was | Now |
|---|---|---|
| MDL 6084 S | `6042 SIDE L` \| `6042 SIDE L` | `6042 SIDE L` \| **`6042 SIDE R`** ✅ fixed |
| MDL 7296 S | `7248 SIDE L` \| `7248 SIDE L` | unchanged, now **reported** as a substitution ⚠ needs the file |
| MDL 7272 S | `7248 SIDE L` \| `7224 SIDE R` | identical — the confirmed booth does not move |
| MDL 6060 S | `6042 SIDE L` \| `6018 SIDE R` | identical |
| all other 21 | — | identical; their SIDE parts are unhanded |

So **6084 was the same bug but not the same fix**: `STD6042` ships both hands, so
the code change alone corrects it. **7296 is the only booth in the catalogue that
needs a part that does not exist.**

### Next

1. Benton: export the two `STD7248 … SIDE R` files (top of this entry).
2. Build `MDL 6084 S` — it should now come out with a genuine right-hand panel at
   the high end, and it is the check that the L-low/R-high rule is right.
3. Then 6060, 7296 and 96168 as already planned.

## 2026-08-14 — the E/W wall order is fixed, in ASSIGN rather than gen-booth.py

The big wall now sits at the door end on all four split-run booths. **7272 is
confirmed built correctly by Benton**; 6060, 6084 and 7296 are the same change,
unbuilt.

This closes the open item below, and it was done in `ASSIGN` in
`build-booth-components.rb` — **not** in `gen-booth.py` as that item proposed.
Swapping the two component names end-for-end leaves the generated layout
untouched and lets `rebalance_walls` do the work it already existed for: it
re-walks each wall from the real part widths, and `short + 2 + big` sums to the
same interior run as `big + 2 + short`. Simulated against the layout data, all
eight walls close on their original end with **0.00 in** error and the seam seal
shifts **+24 in** on every one of them — 46/22 on the 7272 and 7296, 40/16 on
the 6060 and 6084.

Two things worth keeping:

- **The tag has to follow the component, not the slot's `:sk`.** The swap puts a
  vent in a slot the layout data calls SOLID, so slot-kind tagging landed the
  vent on `WR-Booth-Walls` and a plain panel on `WR-Booth-Vent` — hiding the
  vent tag would have hidden the wrong part. Adding `:sk` as a *fallback* does
  not help either; it re-tags the very slots the swap emptied. The component
  name is always informative, because `guess_component` builds `<w>VNT` and
  `Right<w>Door` from the kind.
- **An unspecified vent stays unspecified.** 6060's relocated vent is written as
  `40VNT` — the exact name the guess already produced — not `40VNT_VSS`.
  Choosing VSS while moving a slot would be inventing a customer's choice.

6060 and 6084 list only their E/W slots; N and S fall through to
`guess_component`, which resolves to `40VNT`, `Right40Door` and `40PanelSolid`,
all confirmed present in `P:/Sketchup/NewMasterComponentList`.

### Next

1. Build `MDL 96168 S` — the deck confirmation still owed, and a useful control:
   its E/W is a symmetric 46+46, so the swap is a no-op there.
2. Build 6060, 6084 and 7296 to confirm the swap the way 7272 was confirmed.
3. `MDL 102126 S` is the EFS-vent regression check.

## 2026-08-14 — floors and ceilings, and a long detour

Floors and ceilings now build. `scripts/wr-deck.rb` reads the catalogue from the
folder, tiles each booth's footprint, and places the panels; all 25 Standard
models plan, and the three the quote repo's golden packing list confirms come
out identical. `reference/floor-ceiling-geometry.md` holds every measurement.

Getting there took far longer than it should have, and the reasons are worth
keeping.

### Two bugs that made everything else look inconsistent

**`unless defined?` froze every tuning constant.** Added in the morning to
silence "already initialized constant" warnings on reload. A constant IS defined
after the first load, so the guard skipped the assignment on every load after
it. Four separate constant changes were edited, committed, reloaded and had **no
effect whatsoever** — only a SketchUp restart would have applied them. Every
report that came back during those rounds was describing a build made with
values nobody chose, which is why the picture looked genuinely contradictory:
the same panel was "correct" and then "wrong" with nothing changing between.

Fixed with `remove_const` before each assignment, which updates on reload and
still avoids the warning. **`unless defined?` is only for something that must
never change in a session.**

**A `SyntaxError` made a script do nothing at all.** `Tools.run` rescued
`StandardError`; `SyntaxError` descends from `ScriptError`, so it escaped the
action callback, SketchUp swallowed it, and clicking the script was silent. Now
rescues `Exception` and says plainly when the failure is a syntax error. This is
the second time that distinction has bitten this plugin.

### Editing Ruby with a script broke three files

Twice by cutting at the wrong `end` — a non-greedy regex stopping at an inner
`if`'s `end` rather than the method's — and once by matching only the last line
of a three-line statement. The rule is not "write a better regex". **Do not edit
Ruby with a script.** Use the editor, one statement at a time, and read it back.

### What is actually measured

- Footprint `(exterior_w - 2) x (exterior_h - 2)`; the deck runs under the walls.
- Wall and door frame both sit on the floor's deck top, `z = 1.0`.
- Panel names are not sizes, and the packing list is the **packaged** part —
  3.25 there against 3.108 measured. Sizes come from the probe, never the list.
- `STD7224FL SIDE R` has a bounding box **13.938 in wider than its panel**, the
  only such part. Seating by the box put it 1' 1-15/16" out — the same "find the
  panel inside the part" lesson the wall builder already learned.
- Hinge gaps name the walls: **24.125** for the 46 in, **21.125** for the 22 in.
  Measured above the RIM, not the deck — measuring above the deck sweeps in the
  rim, which runs the panel's full length and merges every hinge into one span.

### The finding that matters, still unfixed

Every panel's 24.125 slot sits on its **low** half. The layout puts the big wall
on the **high** half for all four split-run booths — 6060, 6084, 7272, 7296.
**The panels are right and the layout is backwards**, which is what Benton
reported independently: the window belongs nearer the door.

That is a `gen-booth.py` fix and it moves walls, so it was left for its own
change. `big_wall_fraction` and `layout_big_on_low?` are in `wr-deck.rb`,
deliberately unused, and become the check that proves it once the layout moves.

### Where the deck stands

`7248` at the low end not turned, `7224` at the high end turned, ceilings
flipped by `contact_z`. That is the state Benton called "almost perfect". I broke
it by answering a report about three panels with a blanket change that also
undid the one already confirmed correct — restored in `b6aa682`.

### Next

1. Confirm the restored deck on `MDL 7272 S`, then `MDL 96168 S`.
2. ~~Reverse the E/W wall run order for the four split-run booths in
   `gen-booth.py`, so the big wall sits against the door end.~~ **Done** in
   `ASSIGN` instead — see the entry at the top of this file. Do not redo it in
   `gen-booth.py`, or the two reversals would cancel out.
3. `DECK_TOP_Z` is 0.0, so the floor hangs below the wall base rather than the
   walls rising to sit on it. Physically the walls should rise — one commit,
   both changes, or they float.

## 2026-08-13 — material merge, script renaming, and where to pick up

**`scripts/merge-materials.rb`** (new). Imported components arrived carrying
their own copy of the fabric material, so a colour change would have had to be
made twice. This points every face front, face back, edge, instance and group —
at any nesting depth — from one material onto another and deletes the emptied
one, in a single undoable operation, verifying by re-counting afterwards rather
than trusting its own tally.

It took three passes to get right, and the two failures are the useful part:

1. *"Nothing matches Carpet Plush Charcoal"* while the tray had exactly that
   selected. A material has **two** names — `Material#name` and
   `Material#display_name` — and they diverge for imported materials. The tray
   shows one; the API was matching the other.
2. *`TypeError: reference to deleted Material`*, which rolled back a merge that
   had already correctly repainted **39,918** assignments. A `Material` is a
   live handle, not a copy: the instant `materials.remove` succeeds, every
   reader on it raises. The removal loop logged `m.name` *after* the remove, the
   rescue raised again building its own error string, and the outer handler
   aborted the operation over a bookkeeping message.

Both fixed, and the dialog was then rebuilt around **dropdowns populated from
the model** — each entry showing its live use count, most-used first — so a name
can no longer be got wrong in either direction. "Also merge others whose name
starts the same" replaces the wildcard, which is exactly how SketchUp
uniquifies an imported duplicate.

**`save-scene-components.rb`** gained an off-by-default, undoable option to
rename each component in the model to match its saved file, so a file named
after a scene stops containing "Component#41". Stated plainly in the header:
SketchUp offers **no two-way sync** for external components in either
direction. What renaming buys is right-click → Save As offering the correct
filename.

**The plugin** got mappable toolbar slots (script + icon chosen separately from
a 47-icon library), in-panel script renaming, and a fix for the panel's slot row
disagreeing with the real toolbar — two different fallback rules for one slot,
now resolved once in Ruby and shipped to the panel.

### Where to pick up

1. **Re-shoot the component library.** The material lift means every previously
   exported image reads dark beside a new one. Settings that worked: scenes
   `1-5,40`, view height **104**, style **Interior**, Dark **45**, Recover
   **Yes** — the same style and Dark in *both* exporters.
2. **`merge-materials.rb` has still never completed a real run.** The dropdown
   rebuild is unrun; first run should be a dry run.
3. **`selector2._domainkey.whisperroom.com` has no key.** Microsoft signs with
   selector1 so mail is fine, but the standby rotation key is missing — Defender
   portal → Email authentication settings → DKIM, rotate once. Same action
   upgrades the 1024-bit key to 2048. HubSpot is fully authenticated and
   verified; nothing to do there.
4. **DMARC `rua` goes to two personal mailboxes as raw XML.** Point it at a free
   aggregator, then move `p=quarantine` to `p=reject` once the reports are clean.
5. Still open from before: floors and ceilings (components not exported yet),
   Enhanced walls (all 25 E variants skip with "panel lengths unresolved"),
   furniture, and `.rbz` packaging for the team.

## 2026-08-12 — the fabric material was lightened ~1.47x

Benton's call, and the right one. The component library rendered at a mean luma
of **48.8 / 255** — 19% of full scale — so every downstream use (assembly manual
covers, proposals, the booth builder) needed a rescue lift, and the flat set
already carried a hand-applied gamma correction of unknown size.

Lightening the **texture bitmap** fixes every consumer at once, with no post-pass
and no risk of double correction, and it is visible while working in SketchUp.

Measured before and after, same part, both exporters:

| | before | after |
|---|---|---|
| overall mean luma | 48.8 | **72.3** |
| p99 | 120 | 144 |
| max | 238 | **216** — nothing clipped |
| flat shading (`blur_std`) | 7.5 | **14.1** |
| flat shading ÷ grain | 0.43 | **0.97** |

The lift came out uniform — flat ×1.47, angled ×1.44–1.48 — so the two sets kept
their relationship. Shading improved *more* than proportionally, because
multiplying luma multiplies the differences between faces too; that is what the
jump in legibility actually is.

**Headroom left:** another ×1.25 would still clip nothing. Stopping at 72 is
deliberate — real charcoal fabric photographed in a lit room sits around 60–90,
so this is close to accurate, and going further reads as medium grey rather than
charcoal, which is a product-appearance question rather than a technical one.

**A trap that turned out not to be one**, recorded so nobody re-raises it:
`fix-angled-alpha.py` only recovers a file whose `rgb_max <= 70`, which looks
like it could start silently skipping as the material gets brighter. It cannot.
The composite is `out = 0.25 * src` and `src <= 255`, so `out <= 63.75` no matter
how bright the source is. The threshold is safe at any material brightness.

**Consequence:** every previously exported image in the library is now out of
date and reads dark beside a new one. The whole set needs re-shooting.

## 2026-08-12 — one shading contract for both component-art exporters

The flat walk-around set and the angled Iso30 set are shown side by side in the
booth builder, and the flat set came out visibly lighter. Three causes, two of
them fixable in code:

1. `export-component-art.rb` **activates** each scene, so each scene's stored
   style applies; `angled-component-art.rb` never activates a scene, so it
   renders under whatever style the viewport holds. Same model, two styles, no
   warning — the same root cause as the missing-edge-lines batch.
2. The angled exporter ran the brightness recovery pass. The flat one had **no
   recovery step at all**.
3. Face-normal shading. A flat elevation puts the face perpendicular to the
   camera; an Iso30 puts every visible face oblique. That one is geometry, not
   a bug, and lightening the material would fix the iso and blow out the
   elevation — the material is shared.

`scripts/wr-shading.rb` is now the single contract both `load`: the
transparency keys, a named-style selection, and `DisplayShadows` /
`UseSunForAllShading` / `Light` / `Dark`, every one written and **read back**.
Both scripts gained a **Style** and a **Shadow Dark** field defaulting to the
same value, and both print `WR_Shading.describe` so a mismatch is a diff of two
console blocks rather than a judgement about which image looks lighter. The
flat exporter now runs `fix-angled-alpha.py` too.

`Dark` is the lever for cause 3: it lifts unlit faces toward lit ones without
touching the material. Both default to 45 (SketchUp's own), so turning the
contract on makes the two exporters **identical first**; raise Dark toward 70 in
both to close the remaining gap. The Light/Dark values are a starting point, not
a measurement — none of this has been rendered.

## 2026-08-12 — mappable toolbar slots and a 47-icon library

The toolbar's eight buttons were eight identical numbered stars. They are now
customisable slots, Word-ribbon style: each holds a script AND an icon, chosen
independently in the panel's new TOOLBAR row.

**Why the previous attempt failed, which is the useful part.** `FAV_ICONS`
already mapped five scripts to their own faces, and `refresh_fav_labels`
assigned `cmd.small_icon` at load — yet every button still showed a star.
`UI::Command` uploads its bitmap to the native toolbar when the command is
*created*; assigning `small_icon` after `UI::Toolbar#add_item` does not
reliably repaint. So the icon is now read from preferences and set **before**
the command is constructed. The consequence is honest and stated on screen: a
re-pointed slot runs the new script immediately, but a new *face* appears at
the next SketchUp launch.

- `scripts/make-icons.py` writes 47 `wr_tools/ico-*.svg` — booth, door, window,
  vent, wall, floor, ceiling, ramp, seal, link, cube, dimension, elevation,
  camera, export, gear and so on — from one shared frame, so stroke width and
  colour cannot drift between them. It also writes `ico-labels.txt`.
- The plugin **globs** `ico-*.svg`. Adding an icon is dropping a file in; no
  edit to `main.rb` and none to `panel.html`.
- Storage: two pipe-joined lists of exactly `PIN_N` entries, `slots` and
  `slot_icons`, positionally aligned with `-` for an empty slot — `read_list`
  drops empty strings, so a real blank needs a placeholder or every later slot
  shifts up one. The old flat `pinned` list migrates on first read.
- The panel's star still works: it means "first free slot", no icon chosen.

## 2026-08-11 — booths from real components, booths from links, plugin redesign

**The headline: paste a booth-builder share link, get that customer's exact
booth built from real components.** Both link forms work — `?d=<id>` fetches
`/api/booth-design/<id>` from the link's own host, `#d=<base64>` decodes
locally — verified byte-identical on a real pair. Furniture (desk, MJP) and
roof vents are reported as out of scope rather than dropped.

**`build-booth-components.rb`** places the actual `.skp` components from
`P:/Sketchup/NewMasterComponentList` into the layout slots. Every rule is
measured per part, never tabulated, and each was earned the hard way:

- *Orientation*: axes classified by extent — height ≈ 81/91, width larger of
  the rest — with a retry that swaps width/thickness when the panel search
  fails (the WA ramp door projects 60" out of a 49" frame and fooled the guess).
- *Placement*: by the WALL PANEL found inside each part (tall faces, widest
  cluster), never the bounding box — an EFS silencer widens a part sideways by
  10"+ and a leaf swings 32" out. Panels flush to corners; thin parts centred
  in their band (HX's 1.125" H-strip stays symmetric); seals centred; parts
  top-aligned so vent fans hang below the wall line.
- *Facing*: the floor rule (below-the-wall geometry stands on the host floor,
  which is outside) outranks a bulk vote, which outranks the convention. Doors
  point their leaf inward; WA doors and everything with below-wall geometry
  self-orient. VSS/EFS vents carry bulk on BOTH sides, so only the fan is a
  reliable witness.
- *Wide access*: walls re-derive from real part widths when they disagree with
  the layout slots — the seal beside a 49" WA frame shifts 3" (46-series) or
  9" (40-series), emerging from the walk rather than hard-coded.
- The console table prints slot/part/fit/panel/facing plus raw facing votes
  per thick part. FIT shows the signed number, not a pass mark.

**`gen-booth.py`: E/W walls now run north→south**, matching the portal's own
renderer (`layout-render.js`) — they ran south→north, mirroring every E/W wall
in the catalogue. `wr-booth-data.rb` regenerated (also picks up the upstream
"96168 never had a 28-inch vent" fix). All 25 Standard booths resolve every
slot against the component folder, standard and HX.

**The measurement pass that made it possible:** `probe-components.rb` loads
all 182 component files and measures extents, origins, anchors. Findings that
drove the design: origins are inconsistent (73/182 at a corner) so placement
must use bounding geometry; `_HX` = 91" panels (+10", not the Enhanced
variant); panels measure their names to 0.02"; vent fan drop is identical
between standard and HX.

**New tools:** `elevation-export.rb` (axis views at ONE shared scale per run —
auto is per-run-consistent, typed survives re-runs), `list-scenes.rb`
(numbered scene table), `find-replace-names.rb` (preview-first rename across
scenes/definitions/tags/materials, collision-refusing, one undo),
`save-scene-components.rb` (each scene's component → its own .skp),
`booth-from-link.rb`, `combine-ao.py`.

**Angled Component Art:** batch 4 (all four cameras, every scene); style
selectable BY NAME from the model's styles (the exporter never activates
scenes, so scene styles never applied — that was the missing-edges mystery);
"Bold edges" override; and a two-pass **Viewport shading (AO)** option —
transparent shot for alpha, opaque AO shot for colour, married by
`combine-ao.py`. Interior edges are engine-fixed at 1px; judge exports at 100%.

**wr_tools redesigned:** one surface, one search over scripts AND abilities,
favourites as pills, scripts grouped by `# @cat` headers (untagged one-offs
sink to MORE SCRIPTS), per-script SVG icons on toolbar and pills, and the
command bar accepts a pasted booth-builder link directly.

**The trap that started the day:** `Sketchup.read_default` EVALS its stored
string and `write_default` doesn't escape quotes — a JSON favourites list
raised SyntaxError (not a StandardError!) at load and took the extension down.
Preference lists are now pipe-joined, quotes stripped on write, Exception
rescued with self-healing. Every new script carries the same guard.

### Next steps (tonight, desktop)

1. `git pull`, then `python scripts/install-plugin.py`, restart SketchUp.
   Desktop repo path differs (see CLAUDE.md); the plugin resolves it.
   Components live on `P:` — confirm the desktop sees that share.
2. **Floors and ceilings**: export the components (save-scene-components),
   probe them, then wire the datum shift — walls up by the floor lip, fans
   stay at host-floor zero (documented in build-booth-components.rb).
3. **Enhanced walls**: Benton authors combined components (exterior + interior
   wall + foam grouped, relationship baked in). Separately: solve the E run
   rule in gen-booth.py — all 25 E variants still skip. Panel finder needs a
   prefer-outermost-slab tweak once two same-width tall slabs exist in one part.
4. If any facing still misbehaves: the console votes table is the data —
   paste it rather than iterating by screenshot.
5. Team hand-off: .rbz packaging decision pending (Python dependency, P: path,
   personal defaults). Pilot with one teammate first.

### Open decisions

- Angled art style for batch 3+ (named style vs Bold edges vs AO two-pass) —
  test batch 0 first; the viewer team must be told if the look changes.
- Panel category names/splits are one-line edits if the taxonomy feels wrong.

## 2026-08-06 (night) — the room tools, exploded views, and docs in the repo

**`auto-dimension.rb`** chain-dimensions a room off its **interior floor face**,
so the dimensions can never disagree with the geometry. Three things it refuses
to get wrong, all three of which are in `reference/sketchup-drawing.md` as
having cost time already: winding is **computed** from the signed area rather
than assumed; chains must close, reported per axis, and it prints
`DOES NOT CLOSE` instead of drawing a plausible wrong number; chain lines carry
segment lengths only, never running totals. Doors come off the `WR-Doors` tag —
a gap in a wall might be a modelling mistake, a tagged door is a stated fact.

**`build-room.rb`** is the take-off editor. Direction-and-length runs, live
polygon and closure, and **Build stays disabled until it closes**. Walls build
outward from the interior polygon and mitre by intersecting adjacent offset
edges. Doors split the run with a header over the gap and the leaf drawn open
90 degrees.

One non-obvious detail: the opening marker sits in the wall plane on
`WR-Doors`, and the leaf and swing go on `WR-Doors-Leaf`. A leaf swung 90
degrees has bounds reaching into the room, and `auto-dimension` reads bounds to
find the jambs — on one tag it would have produced wrong jamb dimensions.

It finishes by calling `auto-dimension`, which is why that was built first.

**`proposal-scenes.rb`** creates the five plates in order, each holding its own
camera, tag visibility and style, so `02-dimensioned` shows `WR-Dims` and the
other four hide it. Door and vent sides are **read** from the `WR-Booth-Door`
and `WR-Booth-Vent` tags `build-booth.rb` already writes. The angles are
defaults, and the script says so — framing is a taste call, the ordering and
per-scene tag state are the parts worth automating.

**`explode-view.rb`** pulls an assembly apart and puts it back. Each part
records its home the first time it moves, so a re-explode measures from home
rather than compounding, Reset is exact, and the homes save with the model.
Default is **one axis per part** — whichever it is already furthest along — so
panels come straight off their walls. Radial drift looks acceptable in a
viewport and wrong on a printed page, which is the only place it matters.

**Plugin:** scripts can now be **starred to pin** them to the toolbar. Buttons
appear next launch, not immediately, because `UI::Toolbar#add_item` has a known
severe slowdown on Windows when the toolbar was docked in a previous session
(api-issue-tracker #628). The panel says so on screen. For an instant shortcut,
Window > Preferences > Shortcuts binds a key to any script's menu item.

**`docs/` is new.** The four design pages that were living only as Artifacts are
now in the repo, wrapped as standalone documents that open straight off disk.
They hold reasoning that is not recoverable from the code — why the jig prints
socket-up, why chains must close before anything is built — in a form you can
poke at rather than read.

**Still unrun.** Nothing in `scripts/` has executed. `rbcheck.py` says all 14
Ruby files balance and the two dialogs' JavaScript parses; that is the whole of
what is verified.

## 2026-08-06 (late) — orbit exporter, and what the manual actually is

Benton's target for the assembly manual is now clear and it is bigger than a
generic manual: **a manual generated from a customer's own Booth Planner
configuration.** Press a button, pull that design into SketchUp exactly as the
customer specified it, and produce step-by-step assembly for that booth.

**Most of the front half already exists and nobody wrote it down.**
`booth-builder.html` encodes a design as base64 JSON in a `#d=` URL fragment,
and `gen-booth.py --design "<link>"` already decodes it and solves the panel
geometry. So the path is:

```
booth-builder #d= link
  -> gen-booth.py --design      EXISTS
  -> wr-booth-data.rb           EXISTS
  -> build-booth.rb             EXISTS  (25 Standard booths build today)
  -> orbit-export.rb            NEW, below
  -> manifest.json              NEW, written by the exporter
  -> the manual                 not built
```

**`scripts/orbit-export.rb`** is the new piece. It photographs a part — or every
part of an assembly, isolated one at a time — from every angle in one run, and
writes a `manifest.json` describing what came out.

The design decision that matters is **constant scale**. `zoom_extents` reframes
every shot, so a part would change size as it turns and two parts on facing
pages would not match. The camera instead uses parallel projection with a view
height computed once for the whole run from the largest part's bounding
diagonal — the diagonal rather than the width, because a part's widest
silhouette as it turns is its diagonal. "Each part fills the frame" is offered
as an alternative, and the console says plainly that it is wrong for any step
showing two parts together.

Style is deliberately left alone. Set edges, shading and hidden-line in
SketchUp before running; the script only forces ground, horizon and fog off so
transparency works, and restores them. Guessing at rendering-option keys was
not worth the risk.

The manifest is the contract: part, slug, size, and every frame with its
azimuth and elevation, plus a null `step` to fill in for assembly order.
Nothing downstream needs to know SketchUp exists.

### Also fixed: the generators were laptop-only

`gen-booth.py` and `gen-booth-models.py` hard-coded
`C:\Users\bento\Documents\Claude\...`, which does not exist on the desktop —
the same redirection problem the plugin had. Both now resolve the workspace
root, with `WR_CLAUDE_ROOT` as an override, and write relative to their own
location. Verified: all four paths land on real files here. Without this,
`gen-booth.py --design` — the front half of the button — could not run on this
machine at all.

## 2026-08-06 (late) — the plugin gets a panel

**The menu could never have worked the way it was meant to.** SketchUp has no
API for removing or rebuilding a menu item once added, so "Reload Scripts" was
only ever able to pop a message box explaining that a restart was needed. For a
folder we add scripts to constantly, that is backwards.

`wr_tools` now opens a **`UI::HtmlDialog` panel** instead. It rescans `scripts/`
every time it opens or you hit Rescan, so a new file is one click away with no
restart and no reinstall.

- **Newest first.** Sorted on file mtime, with a NEW pill on anything touched in
  the last 24 hours. The script being worked on is nearly always the one to run.
- **Type to filter**, arrow keys to move, Enter to run. Matches on title, file
  name and blurb.
- **Recent chips** across the top, five deep, persisted in `Sketchup.write_default`.
- Each row shows the script's `@title`, the comment paragraph under it as a
  blurb, the file name and how long ago it changed — all parsed from the header,
  so a script documents itself in the launcher by being commented normally.
- Toolbar cut from seven buttons to three (Panel, Folder, Console) with **SVG
  icons**, which stay crisp at any toolbar size. The old PNGs remain as a
  fallback so a partial install shows buttons rather than blanks.
- The menu is kept, still frozen at load time, as a fallback.

**`scripts/rbcheck.py` is new.** There is no Ruby interpreter on either machine
outside SketchUp, so nothing in `scripts/` gets syntax-checked before it reaches
the Ruby Console. It is not a parser — it strips strings, heredocs and comments
and matches block openers against `end`, which catches the one error that
actually happens when hand-editing a long file. Run `python rbcheck.py` in
`scripts/`. All 9 files currently balance.

Worth knowing about it: the first version flagged `build-booth.rb` and
`tube-drying-stand.rb`, and both were **false positives** — it did not know that
`dir = case axis` opens a block. Fixed. A checker that cries wolf is worse than
no checker.

### Next, for the dynamic assembly manual

Benton's direction for this workspace is mass component photography at many
angles, feeding a rebuilt assembly manual. Nothing below is built yet:

1. **Orbit exporter.** `export-scenes.rb` only exports scenes that already
   exist. The manual needs N angles per component without hand-making N scenes:
   drive `Sketchup::Camera` round a component's bounding box at a set azimuth
   and elevation step, `write_image` each stop, name them predictably.
2. **Exploded views** driven off the tag structure the fixtures already use.
3. **A manifest** — a JSON sidecar naming every image with its component,
   azimuth and elevation, so the manual can be generated from data rather than
   by hand-placing pictures. This is the piece that makes it *dynamic*.

## 2026-08-06 (evening) — pendant fixtures

A side project, not WhisperRoom: 3D-printed fixtures for the pendant line.
Both are parametric, both print without supports, and both self-audit to the
Ruby Console on every run.

**`scripts/pendant-jig.rb`** — holds the metal housing square and centres the
polycarbonate tube in it while the adhesive cures. Ø15.29 socket × 18 deep,
Ø9.90 tube guide × 36, one lathed solid, 57.50 tall, ~18 g. Holds the tube to
0.40° / 0.375 mm over its length.

Two things went wrong on the way and are worth remembering:

- **`follow_me` left the rims cracked.** A revolve has to close back on itself
  and SketchUp does not reliably weld that seam. Rebuilt as an explicit
  `Geom::PolygonMesh` whose last column of quads wraps to column 0 by index, so
  there is no seam to fail. **Every solid now reports its naked-edge count** —
  that check is what should have caught it, and it costs nothing.
- **The first version printed the wrong way up.** Flange-down made the shoulder
  the housing registers against an unsupported ceiling over the socket, which
  is the one surface whose flatness decides whether the housing sits square.
  It prints socket-up. That drove the 45° flange underside, the lead-in, and
  the guide-mouth chamfer.

**`scripts/tube-drying-stand.rb`** — 60 tubes upright while epoxy cures. 10 × 6
pockets, 123.50 × 74.90 × 31.50, ~94 g. Rev B added 136 diamond openings and
dropped the seven under-ribs for four corner pads once it was clear the thing
prints inverted. Worst-case lean 1.62°, which is a ceiling rather than an
expectation — a 54 mm tube on a 9.65 mm base self-rights, and would need 10.1°
to topple. **Cut-end squareness is the likelier dominant error**; measure a
tube against a square before spending print time on a deeper pocket.

**`reference/3d-printing.md`** is new and carries the printer (Dremel 3D45),
the sourced overhang and bridging limits, the two slicer settings that are not
the defaults, and the design rules that follow. Read it before changing either
fixture's geometry.

**Nothing here has been printed yet, and no script has been run.** Clearances
are all built on the 0.25 mm allowance and are unconfirmed. Print the jig
first — an hour and 18 g calibrates that figure before the stand's 94 g.

## 2026-08-06 (later) — desktop brought online

**Repo cloned to the home desktop** at
`C:\Users\bento\OneDrive\Documents\Claude\Sketchup\WhisperRoom-SketchUp\`. Documents is
redirected into OneDrive on this machine, so the laptop's `C:\Users\bento\Documents\Claude\`
does not exist here.

**Plugin made machine-independent.** `wr_tools/main.rb` hard-coded
`C:/Users/bento/Documents/Claude/Sketchup/scripts`, which resolves to nothing on the desktop.
It now walks a `CANDIDATES` list (both Documents roots × both repo layouts) and takes the first
that exists, with a `WR_SCRIPTS_DIR` environment-variable override for a new machine.
`install-plugin.py` likewise no longer requires `%APPDATA%\SketchUp` to already exist — a
SketchUp that has never been launched has no profile folder, so the installer now detects
installed versions from Program Files and creates the Plugins folder itself.

**Installed and verified on the desktop.** SketchUp 2024, `wr_tools.rb` + `wr_tools\` in
`%APPDATA%\SketchUp\SketchUp 2024\SketchUp\Plugins\`. The resolver was run against this
machine's filesystem and picks the OneDrive clone; 4 scripts will appear on the menu
(`booth-4260-s`, `build-booth`, `csusb-rooms`, `export-scenes`). The menu itself is unverified
until SketchUp is launched.

**Sibling repos on the desktop.** `WhisperRoomQuote` was already present. `whisperroom-proposals`
cloned to `<CLAUDE>\WhisperRoom Proposals\`.

### Still missing on the desktop — needs a push from the laptop

These are referenced by `CLAUDE.md` but are not in any branch of any repo on GitHub, so they
exist only on the laptop:

- `WhisperRoom Proposals\build-v2.js` and `examples\<client>\proposal-v2.json` — the
  `whisperroom-proposals` repo on GitHub is still the single-commit **v1** system (`build.js`).
- `WhisperRoomQuote\tools\sketchup-scene-export\` — never committed on any branch.
- `Desktop\ProposalFiles\` and `Desktop\WhisperRoom\` (brand guideline, historical drawings) —
  local-only by design; copy them across manually.

## 2026-08-06

### Done

**Workspace set up.** Repo created and pushed — `bentonwhiteWR/WhisperRoom-SketchUp`,
private (it carries internal pricing). `CLAUDE.md` plus `reference/` hold the rules;
`scripts/` holds the working tools.

**CSUSB job, start to finish.**

- Took off both rooms from the client's PDFs: Chaparral **117 = 51'-4" × 48'-3"** (2,013 sq ft
  net) and University Hall **056 = 25'-3" × 13'-4"** (274 sq ft), every in-line wall run
  dimensioned, all chains closing within ¼".
- Found **Room 117's printed scale is wrong** — the sheet says 1" = 30'-0" but the scale bar
  works out to 1" = 30'-10½". The bar is right; the sheet was reduced on export.
- Read the site photos: 117 is an **active dance studio on a raised sprung floor** (weight
  question for a 1,798–3,100 lb booth) and 056 has a **suspended lay-in ceiling in a basement**,
  which is the likeliest dealbreaker on that room.
- Delivered **`Desktop\ProposalFiles\CSUSB\CSUSB-Booth-Renderings.pdf`** — 23 pages, four
  configurations, 3.09 MB, verified page by page.

**Proposal rules corrected.** The shipped format is **US Letter portrait**, not the landscape
layout `PROPOSAL-GUIDELINES.md` describes. That doc is superseded; `reference/proposal-brand.md`
now matches the David Smith pack, which is the standard.

**SketchUp automation built.**

- `wr_tools` plugin — **Extensions > WhisperRoom** menu and toolbar, auto-discovering every
  script in `scripts/`.
- `csusb-rooms.rb` — both rooms to the measured interiors, mitred corners, doors with swings,
  dimensions on all four sides.
- `export-scenes.rb` — batch scene → PNG into `Desktop\ProposalFiles\ImageExports`.
- `build-booth.rb` + `gen-booth.py` — **all 25 Standard booths** from a dropdown. Panels 1"×81",
  mid-wall seam seals as single T solids, corner seals as single L-with-notch solids including
  the 1"×1" inside block, finished in Carpet Plush Charcoal.

**The assembly rule, confirmed and implemented:**

```
interior wall run = sum(panel lengths) + 2" per joint
```

The 2" is the mid-wall seam-seal stem. It also explains both errors in
`booth-layouts.json` — the 4872's "24" is a 22 with its seal absorbed, the 96120's "47+47" is
really 46+seal+46. `components-master.json` holds **shipping** sizes, never finished geometry.

### Next steps

1. **Settle instance-vs-model.** Open `BoothBuilderV2.skp`, run in the Ruby Console:
   ```ruby
   Sketchup.active_model.definitions.map { |d| "#{d.name}  (#{d.count_instances} used)" }.sort.each { |s| puts s }
   ```
   If real component definitions exist, we instance them instead of modelling doors, vents and
   windows — and the booth-builder share link goes live immediately. If not, we model those
   three features ourselves. **This decides the next chunk of work; do it first.**
2. **Ceiling panels** — need finished dimensions from Benton, same as the wall panels.
3. **Booth-in-room placement** — put a built booth inside a built room against the clearance
   rules (1" nominal, 10" vented with silencers, 45.625" ADA ramp). Produces the dimensioned
   top-down plate.
4. **Scenes and cameras** — five standard views named in plate order, feeding `export-scenes.rb`
   and then `proposal-v2.json`.
5. **Enhanced variants** — 25 more booths. Booth-inside-a-booth with a gap; only needs the gap
   dimension.

### Open decisions

- **"Inside dimension" — clear or panel-face?** Benton's 4260 note says the 40" side has a 38"
  inside dimension. The data says 40. The corner seals' 1"×1" blocks intrude 1" at each end,
  which is exactly the 2". If clear-between-corners is the number that matters, say so and both
  figures get reported.
- **`models.json` 4260 depth** lists 5'-8" (68") where `booth-layouts.json` says 62", and 62 is
  what the model number implies. One of them is wrong, and `models.json` is what the quote tool
  prices from.
- **CSUSB, with the client:** ceiling height in both rooms, the ADA raised-floor height (adds on
  top of the 7'-1"), and which wall in 117 the booth goes on — Maxine named it by photo, not
  compass.
- Two Enhanced renders disagree on the vertical callout — 7' 5/16" vs 7' 1". Resolved as
  exact-vs-marketed, but worth knowing the pack shows the exact figure.

### On another machine

```
git pull
python scripts/install-plugin.py     # then restart SketchUp
```

Only `wr_tools` needs installing. Everything else in `scripts/` is read live from the repo, so
edits take effect on the next click with no restart.

---

## 2026-08-07

### Done

**Plugin rebuilt around abilities and favourites.** The panel now has two tabs.
**Abilities** are on/off toggles that undo what they do — Exploded, Dimensioned,
Proposal scenes, and a built-in Reference geometry tag toggle. They are declared
in each script's own header (`@ability`, `@setting`, `@on`, `@off`), so a new one
needs no plugin edit. State lives on the model, so it survives save and reopen.
**Favourites** now appear both as a strip in the panel and as eight numbered
toolbar buttons. The toolbar slots are created once at load and resolve the pin
list at click time, so starring rebinds a slot immediately — the old behaviour
needed a restart and read as broken.

**Five exporters, each with a dialog and a scene/component selector**
(`all` / `current` / `1-7,12` / text):

- `export-scenes.rb` — proposal plates, opaque, folder browser
- `export-component-art.rb` — every scene, transparent, manifest, HX suffixing
- `export-this-view.rb` — one-off, settings seeded from the batch exporter
- `angled-component-art.rb` — the Iso30 library, four parallel cameras
- `merge-scenes.rb` — import a .skp and rebuild its scenes at the new offset

Filenames are now the scene name **verbatim**; only characters Windows forbids
are replaced. They used to fold spaces to hyphens.

**Design sheets are now the standard deliverable** for anything we design.
`reference/design-sheet.md` is the spec; `docs/tube-drying-stand.html` and
`docs/pendant-jig.html` are the exemplars. Both carry a live WebGL view.

- Drying stand → two 5x6 stands, 60 tubes, fits a 92x135 silicone tray.
- Pendant jig Rev B → tube bore Ø10.10, socket 6.50, flange 3.50, total 46.00.
  Hand-held: 9.00 of housing left proud to grip.

**Bohn Music Academy** take-off and proposal. Room 635¼ x 336½, ~27 ft ceiling.
8-page PDF delivered to `Desktop\ProposalFiles\Bohn Music Academy\`.

### The one that cost the most time

`view.write_image` came back dark with a broken alpha channel. Four confident
explanations were wrong (ambient occlusion, watermark, shading, an open editing
context). The cause, proven from pixel values rather than reasoning:

**SketchUp 24.0.553's new graphics engine composites a uniform 75% black layer
over everything write_image produces, in colour AND alpha.**

    out_rgb   = 0.25 * src_rgb
    out_alpha = 191.25 + 0.25 * src_alpha

A wireframe export contains only the values {0, 4, 8 ... 64} — multiples of four
capped at 255 x 0.25. The Classic engine exports correctly but renders chrome as
flat black, which is worse because it is not recoverable. So: keep the new
engine and undo the composite. `scripts/fix-angled-alpha.py` does it, and the
angled exporter runs it automatically.

**`rbcheck.py` cannot catch a syntax error or an undefined variable.** It counts
block keywords. It reported "balanced" on a file with a `rescue` modifier inside
a subscript assignment (which never parsed) and on one referencing a deleted
variable. Treat a clean run as "blocks balance", nothing more.

### Next steps

1. `python scripts/install-plugin.py`, then **restart SketchUp** — the eight
   favourite toolbar slots only appear at load.
2. **Nothing in `scripts/` has a confirmed run except `tube-drying-stand.rb`.**
   The abilities, the four exporters and `merge-scenes.rb` are all unrun.
   Cheapest first: open the panel, toggle **Reference geometry** (no script, no
   selection — it isolates the ability framework from the scripts).
3. Angled library: run Batch 1 as a **dry run**. The diagnostics file lists every
   scene label against the component it resolved to. That table is what is needed
   to write the scene-label → `Component_…` mapping, which is still missing —
   files currently come out `LeftWADoorWithRamp_…`, the importer wants
   `Component_WADoorWithRamp_…`.
4. Pendant jig and drying stand are both **unprinted and the scripts unrun since
   the last edits**.

### Open decisions

- Angled set: frame on the part (fills the canvas) or on the insertion point
  (clean registration, half the canvas)? Currently part-centred.
- Bohn: booth model still not chosen — waiting on the quote link. The column on
  the door wall has no dimension at all and sits where a booth would go.
