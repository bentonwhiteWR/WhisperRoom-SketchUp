# HANDOFF — light emission diagnosis + programmatic light creation

2026-08-27, Researcher.

## Produced

- `.forge/researcher/vray-light-creation.md` — the findings. Leads with a ranked
  differential diagnosis of why seed-placed lights emitted in one live run and not in
  another (leading suspect by a wide margin: draft-mode hiding of the `WR Lights` tag,
  shipped between the two runs at commit `2f48a6e`); carries **Probe A2** (one paste + one
  render, confirms or kills the tag suspect) and a **master probe** (one paste, reports tag
  visibility, wr-mode state, every light's world Z / tag / container path, group tops, and
  the V-Ray scene's light plugins). Appendix: the programmatic-creation research
  (`scene.create`, `scene.import`, Script Access, Light Gen) — currently not needed, since
  duplication is observed to work. Also answers the coexistence question: the
  proposal-package batch lane already shows the tag before rendering (code-read);
  only a manual render from a draft-mode model is exposed; minimal-guard options stated,
  no code written.
- `.forge/researcher/interior-lighting-options.md` — corrected in place (dated UPDATE
  block): the copy-emits claim is **partially observed and stands** — emitted in one live
  run, suppressed in another, with the between-runs code change named. NOT disproven.
- `.forge/researcher/interior-lighting-design.md` — same correction, plus a pointer that
  the emission question now lives in `vray-light-creation.md`.
- `.forge/researcher/HANDOFF-light-creation.md` — this file.

## Read-first

1. `.forge/researcher/vray-light-creation.md` — Part 2 (ranked suspects) and Part 4 (the
   master probe). If you are Benton at the desk: run **Probe A2 first** (show the
   `WR Lights` tag, render, touch nothing else), then the master probe if still dark.
2. The UPDATE blocks atop `interior-lighting-options.md` and `interior-lighting-design.md`
   — so nobody builds on the transient "copies don't emit" mis-read.

## Assumptions

- Benton's four emission observations are taken as relayed (hand-drawn emits; copy/paste
  emits; early seed run emitted; today's 1.7.4 run did not). Not re-observed here — no
  V-Ray or SketchUp runs on this machine.
- "V-Ray skips hidden-tag lights" is still **reported** (Chaos help article via search
  excerpt + forum threads) until Probe A2's render lands; the whole ranking leans on it.
- The batch lane's tag-showing correctness is **derived from code** (`proposal-package.rb`
  `unit_mode` → `WR_Mode.to_mode`; `wr-mode.rb` LIGHT_TAGS render polarity true), never run
  live.

## Open-questions

- **Probe A2's result** — the one paste that turns the leading suspect from circumstantial
  into confirmed (or kills it). Everything downstream (the minimal guard decision) waits on
  it.
- If A2 confirms: **who owns the guard** — move tag hiding out of placement and into the
  mode switch only, and/or add a preflight row? Builder decision; options in Part 3 of the
  findings. Do not let placement keep hiding the rig silently.
- The wr-mode **snapshot trap** (a tag manually hidden while in render mode gets memorized
  as render state forever) — real per code-read, unobserved; a preflight row would surface
  it.
- Master probe's light-Z section: if Z figures show lights inside/below the booth roofline,
  suspect 2 (bounds reading) goes to the Builder even after A2 confirms — visibly-low
  rectangles were observed in the viewport either way.
- Appendix residual: whether any undocumented light API exists — closable in minutes by
  grepping the YARD docs folder on the render machine
  (`C:\Program Files\Chaos\V-Ray\V-Ray for SketchUp\extension\documentation\`). Low value
  now that duplication is proven.
