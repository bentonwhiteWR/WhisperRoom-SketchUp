# DEFECT — side wall panels flipped, MDL 96144 E and MDL 102144 E

Benton, 2026-08-26, after building both booths from real share links on v1.6.23/24:

> *"also on both, the side walls panels were flipped. See the window for example"*

**Both booths, so it is not booth-specific.** The window is his *example* of the flip, not
necessarily the only affected panel — read it as "the side wall's panel run is mirrored, and
the window is where you can see it."

## What is evidence and what is not

Benton supplied two screenshots: the **portal's** 3D view of the configured booth (which is
authoritative — it is what the customer bought) and his **SketchUp** build. They are at
different camera angles.

**`CLAUDE.md` warns in as many words: avoid left/right spatial claims, because renders get
mirrored and a draft once told a client their work surface was on the wrong wall.** Do not
resolve this by eyeballing two photos taken from different viewpoints. The method that has
worked on this project twice is the **text comparison**: diff the builder's own RAW PACK /
placement printout against the portal's "YOUR BOOTH" panel, which is how the door-hand
translation was proved correct on 2026-08-18 and is named in `.forge/GOAL.md` under Done-means.
Ask Benton for the two share links and the printouts rather than inferring from pixels.

## Where to look — leads, not conclusions

- `REVERSED` (`scripts/build-booth-components.rb:1110`) is `%w[MidWallSeamSeal
  MidWallSeamSeal_HX]` — parts whose thickness axis is authored opposite to everything else.
  `FACE_OUT = false` sits just above it at line 1105, with a comment warning to get the global
  right *before* adding names to `REVERSED`.
- `rev = REVERSED.include?(r[:name])` at line ~1738, feeding `place()` / `rotation()`.
- Both booths have **split runs on E and W**. The 6060's `ASSIGN` E/W reversal was untested
  until this week; 96144 E has **no `ASSIGN` row at all**, so its components come from
  `guess_component`.
- Whether the affected panels are **outer (Standard) or inner (IEP)** is the first thing to
  establish. A window is visible from outside, which points at the outer shell — and the outer
  shell is the live, fit-tested Standard path. **If the root cause lands in shared Standard
  code, stop and report before changing it.**

## Open question for Benton

Does a **Standard** 96144 / 102144 build the side walls correctly today? If yes, the fault is
in the Enhanced path and the Standard path must not be touched. If no, this is a long-standing
Standard bug that these two booths merely exposed, and that is a much larger blast radius.
