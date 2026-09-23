# HANDOFF — Documenter, 22 Sep 2026 late (skill `whisperroom-photo-job`, 1.76.1)

## Produced

- `skills/whisperroom-photo-job/SKILL.md`: a new skill covering client photos to proposal.
  It has the 13-stage concept, "Traps we already paid for" and "How Benton works on these jobs".
  It points to `whisperroom-takeoff` and `whisperroom-proposal` rather than duplicating them.
- `scripts/wr_tools/VERSION` 1.76.0 -> 1.76.1, which triggers the update banner.
- `DEVLOG.md`: a 1.76.1 entry at the top.
- `python scripts/install-plugin.py` ran without a prompt while SketchUp was open. The skill is
  installed at `~/.claude/skills/whisperroom-photo-job/SKILL.md` (observed). The SketchUp
  2024 and 2026 plugin folders were refreshed too; a SketchUp restart picks up the VERSION.

## Read-first

- The skill's sources: `.forge/builder/cms/HANDOFF.md` (hazards),
  `clients/community-music-school/notes.md`, `.forge/builder/cms/scene-plan.md` and
  `progress.txt`.
- Every path and function the skill cites was checked with ls or grep (for example
  `WR_CMS.photo_scenes!`/`check!`/`floor_text` in `dims.rb`, `niche_floors!` in `features.rb`,
  `WR_CMS_Lights.place!`/`audit`, and `scripts/booth-from-link.rb`).

## Assumptions

- Several items came from the coordinator's brief, not from repo files. I could not verify them
  in the HANDOFF, notes or progress, so the skill attributes them or states them as Benton's
  rules:
  - "the dark high and ventilation renders were dropped from the final pack" (attributed in the skill);
  - "the 86° lens stretches the inside-booth scene" (attributed; the HANDOFF records only the 85.93° height fov);
  - "include every plate; flatten onto white; keep dims visible over transparency" (stated as the procedure);
  - "back up before scene-changing rounds" (supported by the HANDOFF's revert records).
- On the zoom trap, the brief said "stored as HORIZONTAL fov at 2.5:1 (14.24°)". The HANDOFF is
  more precise: 35° was taken as horizontal, then re-expressed as a 14.24° HEIGHT fov at the
  2.525:1 window. The skill follows the HANDOFF.

## Open-questions

- CLAUDE.md line ~323 still says the installer carries "currently `whisperroom-proposal` and
  `whisperroom-takeoff`". I did not edit it because it was outside the commit scope I was given.
  It is a one-line fix.
