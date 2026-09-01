# HANDOFF — Full audit, 1 Sep 2026 (plugin 1.19.2, commit 14197b9)

## Produced
- `.forge/auditor/full-audit-2026-09-01.md` — the consolidated ranking across all four
  lanes (22 entries, 10 HIGH), the five decisions Benton owns, prior-audit tally, what is
  solid. Start here.
- Lane reports with full evidence: `full-audit-A-plugin-core.md`,
  `full-audit-B-proposal-render.md`, `full-audit-C-booth-geometry.md`,
  `full-audit-D-takeoff-skills-docs.md`, each with its own `HANDOFF-<lane>.md`.
- Orchestrator actions on the machine: installed plugin brought 1.12.9 → 1.19.2 for
  SketchUp 2024 and 2026; skills re-synced. No source edits, no VERSION bump.

## Read-first (for a Fixer)
1. The consolidated file, findings 1–10. Findings 1, 2, 5 and 7 are blocked on Benton's
   decisions 1–4 respectively; findings 3, 4, 6, 8, 9, 10 are fixable now.
2. Per finding, the lane report has file:line, trigger, provenance and fix direction.
3. Before touching `ASSIGN` (finding 1), read `.forge/builder/HANDOFF-booth-matrix.md`
   finding 5 and `HANDOFF.md` (root, 27 Aug) — this has flipped three times; do not flip
   it on reasoning.

## Assumptions
- No SketchUp, V-Ray or ruby.exe: every SketchUp-API behaviour is derived from code and
  the documented API. Findings 3, 4, 6 and 15 each carry a five-minute live check.
- Builder/Fixer handoffs and the DEVLOG are treated as reported.
- The 31 Aug bridge logs, heartbeat and reflog on this machine are complete.

## Open-questions
- Decisions 1–5 in the consolidated file.
- Whether `Sketchup.read_default` accepts the NUL sentinel (finding 15) — one console line.
- Whether a `Page` with `use_shadow_info` re-applies `DisplayShadows` on `selected_page=`
  (finding 3) — documented, not observed here.
