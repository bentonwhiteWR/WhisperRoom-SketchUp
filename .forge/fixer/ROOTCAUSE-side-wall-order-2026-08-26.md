# Side-wall panel ORDER — diagnosis, v3 (2026-08-26)

**Supersedes the v2 of this file entirely. v2's proposed four-line `gen-booth.py` revert was
WRONG and is retracted below.** Nothing has been shipped. The only changes on disk are in
`.forge/fixer/`.

Diagnosed on `main` @ v1.6.29. `VERSION` untouched. No `.rb` touched. `WhisperRoomQuote` was
read and `require`d, never written.

---

## RETRACTIONS — read these first

1. **`lib/pl-data/booth-iso-geometry.json` is NOT an independent witness. Retracted.**
   Its generator header (`lib/pl-data/extract-booth-iso-geometry.js:5`) says it is *parsed from*
   `scripts/wr-booth-data.rb`. It is a **stale copy of the file under test**, stamped
   `2026-08-07T22:57:11.420Z` — four days before `gen-booth.py` changed the E/W walk. Comparing
   a file to an old copy of itself measures drift, not truth. The v2 harness built on it has
   been **deleted**, not patched.

2. **"The portal has the same bug on 14 models." Retracted — it was wrong.**
   `wallPanelRun()` implements the documented convention *exactly*.
   `reference/seam-seal-attachment.md:317-322` scopes the measured hinge-slot convention to the
   four split-run booths and then says, in the same paragraph: *"Every other model is symmetric
   on E and W — the 96168 is 46+46, the 102126 is 40+16+40 — so nothing reverses."* The portal's
   gate `n === 2 && skuRaw[0] !== skuRaw[1]` is that sentence in code. It is correct.

3. **The four-line `gen-booth.py` revert. Retracted.** It would have moved 108 walls to match a
   stale file, and would have *broken* the 14 models where the builder currently matches the
   plan the customer is actually shown.

4. **The "door end" framing. Retracted as a rule.** Benton: *"The door should go wherever the
   customer selects the door to go."* He is right. `layout-render.js:268` reads
   `layout.door.wall`, and the v2.417.1 note at `:249-256` is explicit that the anchor must be
   **the model's own fixed property, not the live placement** — dragging the frame from S0 to N0
   used to flip both side walls, and that was logged as a bug. All 25 catalogue models happen to
   have `door.wall === 'S'` (observed), which made "low-y end" and "door end" look like the same
   statement. They are not, and only the first is safe to code against.

---

## Which view disagrees with the builder — file and line

There are **three** sources, not two, and they do not all agree.

| source | code path | what it is |
|---|---|---|
| **layout** | `scripts/wr-booth-data.rb` → `build-booth-components.rb:1988` (`place(… p[:poly] …)`) | what SketchUp builds |
| **portal 2D** | `assets/layout-render.js:156` `wallPanelRun()` → `:1562-1565` | the top-down plan |
| **angled 3D** | `assets/iso-render.js:1464-1475` (parts by `p.id` / `p.poly`) + `:1731-1752` `kindsFrom()` (pack painted onto the matching **slot id**), reading `lib/pl-data/booth-iso-geometry.json` | the "YOUR BOOTH" view |

**Measured by executing the portal's own function** (`.forge/fixer/replay-portal-wallrun.js`,
which `require`s `layout-render.js` rather than paraphrasing it):

- **`MDL 102144`: the builder and the portal 2D plan AGREE.** Both put `W0` — the window — at
  builder y **62.00 .. 102.00**, the high-y end. `E0` likewise. Verdict `same` on every slot.
- **`MDL 102144`: the ANGLED view is the lone dissenter**, putting `W0` at y **2.00 .. 42.00**.
- Across all 25 models × both variants: **300 walls, 24 disagree** between layout and portal 2D,
  and they are *exactly* the four split-run booths.
- The angled view disagrees with the portal 2D plan on **56 outer walls / 14 models** — every
  multi-slot side wall **except** the four, where the portal's flip happens to reproduce the old
  order.

### So Benton's picture is explained, and it does not convict the builder

The angled view paints the customer's window pack onto **the part whose id is `W0`**, and takes
that part's polygon from a 2026-08-07 snapshot of `wr-booth-data.rb`. The builder takes the same
slot's polygon from today's `wr-booth-data.rb`. The two copies of that one field differ because
of the 2026-08-11 walk change. **The portal render and the SketchUp render differ by exactly one
stale file, on a wall where nothing geometric distinguishes the two options.**

`MDL 102144`'s W wall is **40 / 16 / 40** — symmetric. Reversing it moves no joint, no seal and
no corner by a thousandth. Only which slot id owns which end changes. That is why nothing caught
it and why no closure or geometry argument can settle it.

**This is the ORDER question.** It is not the width-axis family split (`40Panel2636WDO` runs X,
`16PanelSolid`/`40PanelSolid` run Y) — that turns a panel end-for-end *in place* and is still
open, untouched, and unaddressed by anything here.

---

## Is the 102144 window at the low-y or the high-y end? — **UNRESOLVED, and it cannot be
resolved from anything on disk**

Stated without reference to the door, as asked:

- **No geometric evidence exists.** The wall is width-symmetric; both orders close identically.
- **No measurement covers it.** `reference/seam-seal-attachment.md:317` measures hinge slots on
  6060 / 6084 / 7272 / 7296 only, and explicitly says symmetric walls do not reverse.
- **The two portal views contradict each other on this model**, and the one that matches
  Benton's reading is the stale one.
- The portal 2D plan and the builder agree — but they agree on a *drawing convention*
  (`aIn` grows from the N end), not on a measurement.

**I will not propose a geometry change for the 102144. The honest answer is that it needs a
measurement from Benton.**

### What to measure, and how to state it door-free

On a real `MDL 102144` — or on WhisperRoom's own assembly drawing for it — orient the booth by a
datum that does **not** move when the door moves. Use the same datum the reference already uses:
the **floor and ceiling panels' hinge slots**.

1. **Which end of the side wall does the window panel occupy — the same end as the hinge slots,
   or the opposite end?** That is the whole question, and it is one sentence of answer.
2. **Is it fixed by the model at all, or does the assembler put the window where the customer
   asks?** Benton's own pushback about the door points straight at this. If the window is
   customer-placed, then **there is no rule to code**, the slot index is only a label, and the
   real defect is different: `booth-from-link.rb` would need to honour a chosen window position
   rather than inherit a hard-coded polygon. That would be a change on the customer path with a
   different blast radius again.
3. **Same two questions for `MDL 96144`** (46 + 46, also symmetric) — Benton named it alongside
   the 102144.

Until 1 and 2 are answered, changing the 102144 would be swapping one unevidenced convention for
another.

---

## What IS evidenced, and IS worth fixing — a different, smaller defect

**The builder never implements the big-run convention at all.** On the four split-run booths the
layout puts the big run at the high-y end; the portal 2D plan, the angled view, and the hinge
slots all put it at the low-y end.

    node .forge/fixer/replay-portal-wallrun.js "MDL 6060 S"
      W0  SOLID   layout 20.00..60.00  HIGH    portal  2.00..42.00  LOW   MOVED    angled 2.00..42.00
      W1  SOLID   layout  2.00..18.00  LOW     portal 44.00..60.00  HIGH  MOVED    angled 44.00..60.00
      => *** DISAGREES on 2 slot(s)

Four independent things agree against the builder here:

- the **hinge slots** — a measurement on a real booth (`seam-seal-attachment.md:317-320`);
- the portal **2D plan** (the flip fires);
- the portal **angled view**;
- **Benton, this session: the portal's top-down for a 6060 S looks correct to him.**

**24 walls: `MDL 6060 / 6084 / 7272 / 7296`, both side walls, `S out` + `E out` + `E in`.**
Every other wall in the catalogue already agrees with the plan.

### The change I would make — NOT shipped, and gated

The flip is exactly "walk this wall the other way", so it is a walk-direction conditional, not a
mirror pass.

**`scripts/gen-booth.py`, outer shell** — before the `for i, (slot, ln) …` loop at line 402 add:

    # The big-run convention, matching layout-render.js wallPanelRun():266-277.
    # A 2-panel E/W wall whose REAL parts differ is walked the other way, so the
    # big run lands at the low-y end. Detected structurally, exactly as the portal
    # detects it - this picks out 6060/6084/7272/7296 and nothing else. Evidence
    # is the floor and ceiling HINGE SLOTS (reference/seam-seal-attachment.md
    # "Two things that move a seal along a wall"), which do not move when the
    # door moves. It is a build convention: verify against the job.
    flip = side in ('E', 'W') and len(lengths) == 2 and lengths[0] != lengths[1]

then at line 411:

    -                x, y = (W - t if side == 'E' else t - PANEL_T), H - cursor - ln
    +                x, y = (W - t if side == 'E' else t - PANEL_T), (cursor if flip else H - cursor - ln)

and at lines 422-424:

    -                mid = cursor + SEAL_W / 2.0
    -                if side in ('E', 'W'):
    -                    mid = H - cursor - SEAL_W / 2.0   # same N->S flip as the panels
    +                mid = cursor + SEAL_W / 2.0
    +                if side in ('E', 'W') and not flip:
    +                    mid = H - cursor - SEAL_W / 2.0

**Inner (IEP) shell, lines 253-269** — the same conditional, but ⚠ **the predicate must be
computed from the OUTER lengths, not `inner[side]`.** If the two shells decide independently
they can disagree with each other and the inner shell will sit inside a mirrored outer one. That
is the one place this change can go quietly wrong, and it is why I am not writing the inner-shell
lines blind: `iep_parts()` does not currently have the outer `lengths` in scope and the fix must
thread it in, not re-derive it.

Then:

    python scripts/gen-booth.py --all
    python scripts/rbparse.py                                  # real syntax check
    node .forge/fixer/replay-portal-wallrun.js --all            # must read 0 DISAGREE, exit 0
    python .forge/builder/replay-iep-deck.py                    # 31 assertions
    python .forge/builder/replay-iep-wall-lift.py               # 105 checks

Bump `scripts/wr_tools/VERSION` 1.6.29 → 1.6.30 (`wr-booth-data.rb` is under `scripts/`).

### What it moves on the Standard path

- **Only 6060, 6084, 7272, 7296.** Both side walls, Standard and Enhanced. The seal moves 24 in
  on all four — into the position the hinge slots already say.
- **All 21 other models: byte-identical.** Including `MDL 102144` and `MDL 96144` — so **this
  change does NOT address Benton's window complaint.** Saying otherwise would be the whole
  mistake repeating.
- **`MDL 4872 E` (signed off): unchanged** — single panel per side wall.
- ⚠ **`MDL 6060 E` IS one of the four, and it is the current `.forge/GOAL.md` "Now".** Its E and
  W panels and seals move on both shells. Any inner-deck or wall-lift measurement Benton takes on
  a 6060 E built *before* this change is taken against the old order. **Sequence this against his
  6060 work deliberately; do not land it underneath him.**

---

## A `WhisperRoomQuote` issue to report, not to fix (read-only from here)

The portal's **angled view is stale** — 56 outer walls across 14 models where it contradicts the
portal's own 2D plan. Re-running `node lib/pl-data/extract-booth-iso-geometry.js` would refresh
it, **but a naive refresh would break the four split-run booths' angled view**, because the
extract carries no flip logic and today's `wr-booth-data.rb` has the big run at the wrong end.
The correct sequence is: fix `gen-booth.py` first, regenerate `wr-booth-data.rb`, *then* re-run
the extract. I have not touched that repo.

---

## Confidence, at the weakest link

- The three sources, their code paths, and the 300/24 and 56/14 counts: **observed**, by
  executing `wallPanelRun()` against parsed `wr-booth-data.rb`, not by reasoning about either.
- The angled view being a stale copy of `wr-booth-data.rb`: **observed** (generator header +
  `generated` timestamp + a byte-level match to the pre-`92dc59b` data).
- The four-booth flip being the right fix: **derived** from a measurement (hinge slots) plus
  three agreeing renderings plus Benton's confirmation on the 6060. Strong, but the reference
  itself says "verify against the job."
- **The 102144 window: unresolved. No evidence either way exists on disk.** This is the weakest
  link and it is the thing Benton actually asked about.
- Nothing here ran in SketchUp. No Ruby was executed. No claim is confirmed against a build.
