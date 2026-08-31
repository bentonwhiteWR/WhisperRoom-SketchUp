# HANDOFF — "the 6060's window needs to go inwards 11/16" — REFUSED, part not identified

Fixer, 2026-08-30. **No code was changed. `scripts/wr_tools/VERSION` stays at 1.9.7.
The booth-matrix baseline was not touched and was not regenerated.**

## Outcome, first

**I could not identify a window on a generated 6060, and I stopped rather than guess.**

Two independent stop conditions were hit, either one of which is sufficient on its own:

1. **The part named in the brief is not a window.** `40VNT` is a **ventilation** panel.
2. **A generated `MDL 6060 S` / `MDL 6060 E` contains no window panel of any kind.**

And had `40VNT` been the right part, the blast radius alone would have stopped the change:
**`40VNT` appears in 30 of the 50 booth-matrix keys** (15 models × S and E). Moving it
0.6875" would have moved 30 keys' landed bounds, not two.

Benton's 0.6875" is not in dispute and has not been discarded — it is an authoritative
measured figure with, as yet, **no part to attach it to**. One question to him closes this;
it is at the bottom.

---

## 1. Which part is the window — answered, and the brief's premise is wrong

**`40VNT` is a vent, observed three ways:**

- Its rendered component art
  (`WhisperRoomQuote/assets/booth-art-iso30/inner-40-vnt-iso30-extl.png`) shows two louvred
  duct grilles in a panel. No glazing, no opening.
- It sits in the VNT family on the share alongside `40VNT_VSS`, `40VNT_EFS`, `40Vnt_CP` —
  the vent-option variants. Window panels are a **separate, differently named** family:
  `40Panel2636WDO`, `46Panel3236WDO`, `31Panel1648WDO`, … (`WDO` = window).
- The code agrees. `scripts/wr-overlays.rb:221` classifies `WDO` as `:window` and matches
  `VNT` separately; `build-booth-components.rb` places **duct covers** on `E1 40VNT`
  (`.forge/builder/booth-matrix/build/MDL-6060-S.txt`), which is vent behaviour.

**"Inwards along the wall normal" is the right reading of "inwards" for a wall panel** — it
is the same axis as the two measured inward pushes already in the code
(`IEP_ROOM_PROUD`, `IEP_DOOR_IN = 0.5`, both from Benton's own eye). That interpretation was
never the problem. The problem is the noun.

## 2. The 6060 has no window part — observed, from the committed golden builds

`scripts/wr-booth-data.rb:777` (`MDL 6060 S`) and `:796` (`MDL 6060 E`) list every slot.
**Neither carries a `WDO` slot; the string `WDO` does not occur anywhere in
`wr-booth-data.rb` (0 occurrences).** The 6060's slot kinds are `VNT`, `SOLID`, `DRFRM`,
`SEAL`, `CORNER` only.

The real builds confirm it. Everything placed in a `MDL 6060 S` (29 instances,
`.forge/builder/booth-matrix/build/MDL-6060-S.txt`):

| slot | component | kind |
|---|---|---|
| N0, E1 | `40VNT` | vent |
| N1, S1, E0, W0 | `16PanelSolid` | solid |
| S0 | `Right40Door` | door |
| W1 | `40PanelSolid` | solid |
| 4× mid-wall + 4× corner | seam seals | seal |
| deck | `STD6042FL/CL`, `STD6018FL/CL`, `STDSS FL5/CL5` | floor/ceiling |
| overlays | foam ×3, duct covers ×4 | overlay |

`MDL 6060 E` adds only the inner shell (`ENH 35.5VNT`, `ENH 11.5PanelSolid`,
`ENH 35.5PanelSolid`, `ENH Right35.5Door`, `ENH` seals) — again no window.

**Across all 50 matrix keys, only `MDL 7272 S` and `MDL 7272 E` place a window**
(`46Panel3236WDO` / `ENH 41.5Panel3236WDO`, hard-coded at
`build-booth-components.rb:1225` and `:1278`). Verified by grepping `WDO` across
`.forge/builder/booth-matrix/dry/*.txt` — 2 files of 50 hit, both 7272.

**Nothing in the overlay set is a window either.** `wr-overlays.rb` places foam, duct
covers, desk, MJP, EFP, caster and CP plates, and its own header says foam goes on
"never a door, never a window".

## 3. So what is Benton looking at? Three candidates, none confirmable from here

**(a) The lite in the door leaf — most likely.** `Right40Door` (and, on the E, the inner
`ENH Right35.5Door`) carries a rectangular glazed window in its leaf; see
`WhisperRoomQuote/assets/booth-art-iso30/door-40-right-iso30-extl.png`. On a generated
6060 this is the **only** window in the picture. But it lives **inside the `.skp`
definition** — the scripts place the whole door, never the lite — so "move the window
inwards 11/16" against it means one of two very different things:

  - move the **whole door** inwards 11/16 (a placement change, in scope), or
  - move the **lite within the leaf** (a library edit to `Right40Door.skp`, **out of
    scope** — `P:` is read-only and the `.skp`s are not mine to edit).

  On a **6060 E** there is a further reading: the outer and inner door lites are separate
  and may not register with each other. The inner door already carries a measured inward
  push, `IEP_DOOR_IN = 0.5` ("the door should push inwards 1/2", Benton) —
  `build-booth-components.rb:~395`. 11/16 could be a correction to that, and it would
  apply to the **Enhanced only**. That is a guess and is not being acted on.

**(b) A 6060 built from a booth-builder link, not from the matrix.**
`scripts/booth-from-link.rb` can put a `WDO` panel on any wall of any booth from the
customer's own configuration. If Benton's screenshot came from a link, "the window" is a
real `40Panel26xxWDO` panel and the fix belongs to the **WDO family's seating depth**, not
to the 6060. Worth noting: `40Panel2636WDO` measures **1.750** thick where `40PanelSolid`
measures **1.000** (`P:/Sketchup/NewMasterComponentList/_component-probe.tsv`, observed) —
a 0.75 difference on a part the placer centres in a 1.0 band, so a systematic depth error
on windows is entirely plausible. **0.6875 is not 0.375, so this is not a derivation — it
is a reason the question is worth asking, nothing more.**

**(c) Something I have not thought of.** Named for honesty.

## 4. Blast radius, since the brief asked for it explicitly

| candidate part | keys affected if moved 0.6875" |
|---|---|
| `40VNT` (the brief's guess) | **30 of 50** — 4230, 4242, 4260, 4284, 6060, 6084, 8484, 84102, 84126, 10284, 102102, 102126, 102144, 102168, 102186, each × S and E |
| `Right40Door` | every booth with a 40" door frame |
| `IEP_DOOR_IN` (Enhanced inner door) | every `E` booth |
| `46Panel3236WDO` / `ENH 41.5Panel3236WDO` | 2 keys (7272 S, 7272 E) |
| a new 6060-only offset | 2 keys |

**A blanket `40VNT` move was never going to be the narrow fix.** Even with the right part,
the honest shape of this change is a **per-part or per-family** offset in the style of
`IEP_ROOM_PROUD` / `IEP_DOOR_IN` — a named constant carrying who measured it and on which
booth — not a bare number at a call site.

## 5. Before / after numbers — NOT PRODUCED, and why

The brief asked for the window's landed bounds before and after, proven live.
**Neither was produced. There is no measurement in this handoff and the change is unproven
because it was not made.**

Two reasons, both stated plainly:

- **There is no window to measure on a 6060.** A before-figure for a part that is not
  placed does not exist.
- **SketchUp was not running.** `python scripts/sketchup-bridge.py --su 2026 ping` reported
  the listener silent with a stale heartbeat (72 s → 166 s across three attempts), and
  `Get-Process` found **no SketchUp process at all**. The listener's last log line is
  `2026-08-30 20:13:39 listener started (SketchUp 2026, plugin 1.9.3)`; the application has
  since exited. **No live build, no screenshot.** Nothing in this document rests on a live
  run — every observation above comes from the committed golden manifests, the layout data,
  the component-probe TSV, and the rendered component art.

## 6. What was and was not changed

- **No `.rb`, `.py` or data file changed.** `git status` clean apart from a Scoper file I
  did not touch.
- **`scripts/wr_tools/VERSION` stays at 1.9.7.** The brief asked for 1.9.8. Nothing under
  `scripts/` changed, and CLAUDE.md ties the bump to a `scripts/` change because the bump
  is the update banner — bumping on a diagnosis would tell Gabe there is new code to pull
  when there is not. **Bump it with the fix, not with this.**
- **The booth-matrix baseline at `.forge/builder/booth-matrix/` is untouched and was not
  regenerated.** No diff was run, because nothing moved.
- `python scripts/rbparse.py` — **59 files parse** (run to confirm the tree is clean as
  found, not because anything was edited).
- Nothing was written to `P:` or to `WhisperRoomQuote`.

## 7. The one question that closes this

**Benton: on the 6060 screenshot, which window?**

1. **The window in the door** — and if so, should the *whole door* move in 11/16, or is the
   glass in the wrong place inside `Right40Door.skp` (a library fix, not ours)?
2. **A window panel on a side wall**, from a booth-builder link rather than the plain
   `MDL 6060 S` / `MDL 6060 E` — if so the link, please, and the fix lands on the WDO family.
3. **Standard, Enhanced, or both?** The brief flagged this and it stays open. On an
   Enhanced 6060 the window you can see through is two lites deep, and 11/16 might belong
   to the inner door alone.

The screenshot itself would answer all three at once. With any one of them answered the fix
is small, narrow, and provable in a single pair of builds.
