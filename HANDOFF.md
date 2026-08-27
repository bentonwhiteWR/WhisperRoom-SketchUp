# HANDOFF — 2026-08-27, end of day

## Read this first

Plugin **1.6.40**. Tree clean, everything pushed to `main`. Eight versions today, 1.6.33 → 1.6.40.
The full story is the 2026-08-27 `SESSION CLOSE` block of `DEVLOG.md`; this is the short version.

**Nothing shipped today has been run.** There is no `ruby.exe` outside SketchUp on this machine.
`rbparse.py` parses all 53 files and three harnesses pass, and none of that is evidence a booth
builds. Every item below needs one SketchUp pass to become real.

## Step 0, and it is not optional

`git pull` → `python scripts/install-plugin.py` → **RESTART SketchUp.**

A Ruby module keeps its constants until the process restarts. Two versions have already been
spent on reports made against code that was never in memory. A report about anything below is
only evidence if the restart happened first.

## The one thing that is BLOCKED on Benton

**The 7272 S / 7272 E side walls, and it is a live regression.** Benton, off a real build:
*"The 22" wall is where the window should be, and the window is where the 22" wall should be."*

Traced and **not fixed**, deliberately:

- v1.6.34's E/W walk revert moved the 7272's big run from the far end to the door end.
  `E0` went from `y 26–72` (46" at the far end) to `y 2–48` (46" at the door end); `W` mirrors it.
  `N`/`S` never moved.
- **HEAD now matches the portal's own `booth-iso-geometry.json` exactly** — it has `E0` at
  `y 2–48` and `E1` at `y 50–72`. The portal's 2D plan agrees too. So if the build is wrong, the
  booth builder has been showing customers the same wrong arrangement.
- A blanket flip back would **undo the 102144 window fix Benton signed off on**, because the same
  walk drives both and the 102144's `W` wall is `40 / 16 / 40` where reversing the order is
  exactly what moves the window between the two 40s.

**The question that unblocks it:** on a real 7272, taking the door wall as the reference, does the
46" window panel sit at the **door end** of the side wall or at the **far end**? Answer that and
the fix is surgical — split the two-slot split-run booths from the general walk, add the 7272 to
`.forge/builder/` as a pinned case so it cannot flip a fourth time, and raise the portal
discrepancy with the slot coordinates.

This has now moved three times and one earlier revert was retracted for a stale witness
(`e2e3461`). Do not flip it on reasoning.

## What to check in one SketchUp pass

1. **MDL 4896 E** — the ceiling that started this. The deck's quarter turn is now measured off the
   part instead of asserted from its filename (1.6.38). The build **names every part whose box
   contradicts its name**; that console output is the measurement and it does not exist yet.
   Paste it. If the ceiling is still crossways, the inferred premise was wrong and the cause is
   elsewhere.
2. **MDL 102144 E, and its HX** — inner vent walls 1/16 lower than the rest of the shell (1.6.33),
   floor seam seals at `-1.0000` (1.6.37), window at the door end of its wall (1.6.34).
3. **Any Enhanced booth** — the floor seal datum landed on the round `-1.0000` after three fit
   tests. **The roundness is not evidence.** What would make it a rule is the same figure holding
   on a different profile — an `STDSS FL6` or `FL7`, not the `8.5FL` all three came off.
4. **Light It From Here** (1.6.40) — the sun is now aimed in both axes. Height is solved by
   bisecting latitude at a pinned equinox noon against a live `SunDirection` reading. Confirm a
   render actually lights, and that the reported height error is small.

## What shipped, in one line each

| Ver | |
|---|---|
| 1.6.33 | IEP vent walls drop 1/16 on the 102144 E; a literal `0x08` backspace repaired in three vent regexes, live since 1.6.12 |
| 1.6.34 | E/W slot order reverted to south→north — the side-wall window defect **(see the blocked item above)** |
| 1.6.35 | Floor seam seal datum `-1.1250` → `-1.0078125` |
| 1.6.36 | UTHSC Audiology: the four marked rooms drawn, no booth |
| 1.6.37 | Floor seam seal datum → `-1.0000`, third fit test |
| 1.6.38 | Deck quarter turn measured off the part, not the filename |
| 1.6.39 | `ShadowTime` is UTC, not `Time.new` — the black-render bug |
| 1.6.40 | Sun aimed in both axes; height solved by latitude, calendar is machinery |

## The client work

**UTHSC Audiology** — `scripts/uthsc-audiology-rooms.rb` (CLIENT DRAWINGS tab),
`clients/uthsc-audiology/notes.md`. Four rooms drawn to their measured interiors. Room 2 is an
**L** — Benton's own numbers, and its area closes to 334.94 sf against the plan's printed 333.45.

Site visit is **Tuesday** and the list is in the notes. In priority order: **ceiling heights in
all four rooms** (none on the plan anywhere; all four drawn at the 8'-0" house default and
labelled assumed — and going all-Enhanced is exactly the choice that spends the extra 2" of
install clearance, 7'-1" against 6'-11"), then the doors (**the plan dimensions none of them**, so
positions carry ±3" and only one door per room was legible in the raster — nothing could be
confirmed or ruled out in the wall Rooms 1 and 2 share), then the delivery path.

**On the package question:** Audiology Deluxe and Audiology Premium are **both single-wall**.
Saravanan wants all-Enhanced, and the only Enhanced Audiology package is **Audiology Ultra**
(6×6, base 7272, ADA) — Deluxe's `tierCounterpart`. Premium's is `null`; there is no 6×8 Enhanced
Audiology package, so that would have to be configured. Floor area is not the constraint in any of
the four rooms — ceiling height is, and it is unmeasured. Sales owns the model choice.

## Two lessons from today worth keeping

**Deriving a dimension from an area can be exactly right and completely wrong.** Room 2's printed
area would not close on its printed width × depth, so a depth was derived from the area and it
matched a plausible misread digit to three decimals. The room simply was not a rectangle. The
arithmetic was flawless about a false premise, and it also invented a "chain that does not close"
that never existed.

**The shell ate an escape, twice.** Three vent regexes have carried a literal backspace byte since
v1.6.12 because a heredoc turned `\\b` into `\b`. Found by an assertion counting occurrences — and
then reproduced by doing it again in the fix. Non-trivial escapes go through a file written with
the Write tool, never a shell heredoc. The harness now asserts no control character survives.
