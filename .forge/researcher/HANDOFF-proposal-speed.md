# HANDOFF — proposal image-step speed (the 45 minutes)

Researcher, 2026-08-31. Read-only. Companion to the floor-plan researcher working in
this same folder; this file covers only the proposal-assembly question.

## Produced

- `.forge/researcher/proposal-image-step-timing.md` — full findings. Short form: the
  45 minutes is roughly what the written procedure costs when followed exactly
  (~40–60 mandated image inspections per job: reference-pack rebuild, 300–700 dpi
  caption transcription, every-page + every-bottom-edge verification), aggravated by
  a path table whose warm-start targets are all missing on this machine, and possibly
  by V-Ray rendering at ~6 min/frame if renders happened inside the session (unknown —
  the run left no log in this repo).

## Read-first

- `.forge/researcher/proposal-image-step-timing.md` §3 (the time budget) and §6 (the
  ranked cuts) — the actionable core.
- §4 — the path audit: `WhisperRoom Proposals\build-v2.js`, the peoplespace example,
  `Desktop\WhisperRoom\`, and every shipped pack under `Desktop\ProposalFiles\` are
  MISSING on this machine (observed today); CLAUDE.md:49-55, playbook §1/§9/§12 point
  at them.
- `.forge/researcher/proposal-scene-generation.md` — the earlier report on the export
  half; its D1–D4 camera defects are why scenes are still set by hand upstream.
- `scripts/proposal-package.rb:1-72` — what the automated half actually does (bare
  PNGs, no manifest) and the render lane's unrun status.

## Assumptions

- The 45-minute session happened on a machine/session not represented in this repo's
  DEVLOG or git history (no trace found; prior packs claimed at Desktop paths absent
  here — likely the laptop side of the `<CLAUDE>` split).
- The §3 budget is derived from the procedure, not measured; band 36–68 min.
- Minutes-saved estimates in §6 are labelled guesses; items 1–3 (manifest+dimension
  sidecar at export time, kill the per-job reference rebuild, fix the path table) are
  the confident ones.

## Open-questions

1. **Did the 45-minute job include V-Ray rendering, or were the images already on
   disk?** One question to Gabe; it decides whether the fix is docs/tooling or the
   parked render mission. Highest-value unknown.
2. Which machine ran it, and does its transcript survive (claude.ai session list)?
3. Where should client configs canonically live? Three docs name three destinations
   (playbook §9:320 vs SKILL:27 vs private repo, playbook §2:67-71) — a decision for
   Benton before the GOAL item-5 rewrite.
4. Do the prior shipped packs still exist on the laptop, and should the playbook's
   "newest shipped pack is the standard" rule survive the machine split (a committed
   reference render would replace it)?
