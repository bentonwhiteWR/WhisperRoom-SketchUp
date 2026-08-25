# Scoper HANDOFF — Enhanced (ENH) booth build

2026-08-24. Supersedes the earlier ceiling-seam-seal handoff for this workspace.

## Produced

- `scripts/probe-enhanced.rb` — the probe Benton runs in SketchUp. **Written,
  syntax-checked with `scripts/rbparse.py` (CRuby 3.2, reports `ok`), and UNRUN.** It has
  produced no numbers. Dry-run-safe: loads definitions, measures, writes two TSVs, purges;
  places no instances, draws nothing, never saves.
- `.forge/scoper/enhanced-booth-build.md` — the spec. Contains the ENH↔STD coverage and
  missing-parts tables, the five confirmed blockers with line numbers, and an ordered build
  plan that forks on the probe's verdict.

Nothing else was written. No production code was changed.

## Read-first

1. `.forge/scoper/enhanced-booth-build.md` — start at **Deliverable 0**. Steps past 4 must
   not begin until Benton has run the probe and its verdict is pasted into Step 1.
2. `scripts/probe-enhanced.rb` header — it documents *why* each measurement is needed and
   carries the `WALL_SLAB WARNING` the Builder needs before touching
   `build-booth-components.rb`.
3. `scripts/booth-from-link.rb` `component_for` (lines ~116–133) — this is blocker B1 and
   the first thing that fails on an Enhanced link.

**`.forge/GOAL.md` is current, not stale.** My assignment said it still described an older
ceiling-seam-seal mission; it does not — the coordinator has rewritten it and it now
describes this mission, names `booth-from-link.rb` as the priority path, and independently
states the same "single assumption" (combined vs single parts) this spec is built around.
I read it and did not edit it. My spec agrees with it on every point I checked.

## Assumptions

- **The −4.5 inch rule is a naming observation only.** It maps every Enhanced filename to a
  Standard one, one-for-one, across the whole set (observed). Whether 4.5 encodes the
  double-wall gap is untested; the probe's `delta_thickness` column tests it. Nothing in
  the spec computes a gap from it.
- **Axis assignment by extent** (thickness = smallest, height = largest) is verified against
  the Standard probe TSV for panels, vents and doors, and is an *inference* for Enhanced.
  The probe prints the assignment per row so a wrong pick is visible.
- **Plan A vs Plan B** — the spec's build steps assume Plan A (combined parts) past Step 5.
  If the probe reports single shells, Step 5 says stop and escalate rather than proceed.
- I did **not** re-read the DEVLOG in full. A subagent trawling it was lost to the usage-limit
  interruption and I did not relaunch it. The DEVLOG claims I rely on (the "booth-inside-a-booth
  with a gap" framing, the "combined components" intent, the "prefer-outermost-slab" warning)
  reached me through the assignment and `.forge/GOAL.md`, so they are **reported**, not
  observed by me directly. Everything in the coverage tables and the five blockers is
  observed first-hand from the share and the scripts.

## Open questions

**O1 — the portal pack vocabulary: CLOSED.** I was going to raise this and then resolved it.
`WhisperRoomQuote/booth-builder.html` emits `STDWL<n>` packs unconditionally; `ENHWL` does
not appear in the file at all. The variant travels only in `payload['v']`. No fork remains.

**O2 — `ENH 423.54CL.skp` / `ENH 423.54FL.skp`: suspected typo, needs Benton.**
Every other deck name is `<cross><along>` digits. `423.54` parses as none of those and has a
decimal point no other deck name has. There is no Standard counterpart. **Not renamed, not
normalised.** What were these meant to be?

**O3 — `ENH 26.5Panel11.548WDO` (+`_HX`): deliberate, or a mis-rename?**
`ENH 26.5Panel1648WDO` also exists and maps correctly to `31Panel1648WDO`. So the 26.5 panel
ships with two window variants, 16×48 and 11.5×48. It is the only place in the whole set
where a *window opening* dimension took the −4.5, every other `WDO` keeping its Standard
opening. Reads as deliberate, but it is a one-off pattern and worth one sentence from
Benton. Not renamed.

**O4 — which of the 74 missing parts get authored first, and does a 2.5" panel get made?**
66 wall-family parts plus all 8 `STDSS` ceiling/floor seam seals have no Enhanced
counterpart. The spec has the full grouped table. Two decisions are Benton's:
- The **2.5" panel** (the Enhanced twin of `7Panel`) is the WA-door companion wall, emitted
  by the portal as `'STDWL7 / WL16'`. Without it **no Enhanced booth with a wide-access door
  can be built.** That argues for authoring it before the other 65.
- The **28 vent option variants** (VSS / EFS / caster) and **both side vents** are missing
  entirely, so any Enhanced link with `vs`, `ef` or `cs` set is unbuildable. Base vents
  (`ENH 35.5VNT`, `ENH 41.5VNT`, +`_HX`) and the no-vent blanks do exist.

**O5 — the `84.3125` / `83.0000` panel heights do not match the measured data.**
Standard panels measure **81.0000** and HX **91.0000** (observed, 33 and 32 parts in
`_component-probe.tsv`); neither 83.0 nor 84.3125 occurs anywhere in that 182-part file, and
the code agrees (`want = hx ? 91.0 : 81.0`; every booth carries `:ph=>81.0`). Those figures
are measuring something other than the panel — panel plus rail, or an assembly height. The
probe's height tally settles the real Enhanced number; whichever source carries 83.0/84.3125
should then be corrected or re-labelled. **Nothing should encode 84.3125 in the meantime.**

## Next action

Benton runs, on an empty scratch model:

```
load "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/probe-enhanced.rb"
```

Then paste the `COMBINED, OR SINGLE?` block into Step 1 of the spec. That selects Plan A or
Plan B and unblocks the Builder.
