# GOAL

## Mission
**Full audit of the WhisperRoom SketchUp plugin and the two drawing skills, 1 Sep 2026,
at plugin 1.19.2 (commit 14197b9).** Benton: "We finally got the SketchUp plugin working
pretty good ... run a full audit on the entire SketchUp plugin as well as our skills ...
review all the changes ... Look for areas of improvement with the things that are broken
that need to be fixed."

This is a READ-ONLY review. Auditors report; nothing gets fixed in this mission. The
deliverable is one ranked findings document Benton can act on, published as an artifact and
emailed to him.

## Done means
1. Every file under `scripts/` that the panel can run, plus `scripts/wr_tools/`,
   `scripts/install-plugin.py`, both `skills/*/SKILL.md`, and the reference docs they cite,
   has been read by an Auditor against `CLAUDE.md` and `reference/sketchup-drawing.md`.
2. Every finding carries file:line, the concrete trigger, the failure it causes, a
   provenance tag (observed / derived / assumed), and a fix direction.
3. The prior audits (`.forge/auditor/script-audit.md` 15 Aug,
   `.forge/auditor/proposal-package-audit-2026-08-30.md`,
   `.forge/auditor/lighting-inconsistency-2026-08-28.md`) are re-checked: each earlier
   finding is marked FIXED / STILL OPEN / REGRESSED with evidence.
4. Every offline harness (`rbparse.py`, `takeoff-check.py --selftest`, every `rbtest-*.py`)
   has been run and its result recorded. Baseline run by the orchestrator 1 Sep:
   all pass EXCEPT `scripts/rbtest-lights.py`, which raises
   "the check harness itself raised inside Ruby" — root cause owed.
5. One consolidated report at `.forge/auditor/full-audit-2026-09-01.md`, ranked by
   probability × cost, silent failures above loud ones, customer-facing above internal.

## Now
**Audit complete, 1 Sep 2026 evening.** Consolidated ranking at
`.forge/auditor/full-audit-2026-09-01.md` (22 entries, 10 HIGH), published as an artifact and
emailed to Benton. Next move is Benton's: answer the five decisions in that file, then a Fixer
mission on findings 3, 4, 6, 8, 9, 10, 13, 14 (unblocked) and 1, 2, 5, 7 (once decided).

The four lanes, each with its own file under `.forge/auditor/`:
- **A — plugin core & distribution**: `wr_tools.rb`, `wr_tools/main.rb`, `panel.html`,
  `wr_bridge.rb`, `defaults.json`, `icon-map.json`, `install-plugin.py`, the update
  banner / VERSION mechanism, `sketchup-bridge.py`, `wr-bridge-lib.rb`.
- **B — proposal package & render lane**: `proposal-package.rb`, `wr-png-srgb.rb`,
  `probe-vray-color.rb`, `wr-scene-walls.rb`, `wr-mode.rb`, `wr-materials-swap.rb`,
  `export-scenes.rb`, `proposal-scenes.rb`, `image-qa.py`, `wr-drop-lights.rb`,
  `wr-lower-walls.rb`, `wr-sun-aim.rb`, `wr-preflight.rb`, and the `rbtest-lights.py`
  failure.
- **C — booth geometry & dimensioning**: `build-booth-components.rb`, `wr-deck.rb`,
  `booth-from-link.rb`, `wr-overlays.rb`, `wr-roof-vent.rb`, `wr-booth-data.rb`,
  `auto-dimension.rb`, `dimension-booth.rb`, `dimension-selection.rb`,
  `build-booth.rb`, `wr-split-walls.rb`, `wr-name-walls.rb`.
- **D — take-off pipeline, skills & docs**: `takeoff-check.py`, `build-takeoff.rb`,
  `build-room.rb` / `.html`, `eval-floorplan.py`, `reference/takeoff-format.md`,
  `skills/whisperroom-takeoff/SKILL.md`, `skills/whisperroom-proposal/SKILL.md`,
  `reference/proposal-playbook.md`, `proposals/build-v2.js`, `CLAUDE.md` consistency
  with the code it describes, `check-doc-paths.py`.

Orchestrator consolidates, publishes the artifact, emails Benton.

## Facts established by the orchestrator, 1 Sep 2026
- Repo is at `14197b9`, clean, in sync with `origin/main` (observed).
- The installed plugin was **1.12.9** against a repo at **1.19.2**; `install-plugin.py`
  was run and the installed copy now reads 1.19.2 for SketchUp 2024 and SketchUp 2026
  (observed). Both skills in `~/.claude/skills/` now match the repo byte-for-byte
  (observed). SketchUp was not running, so no restart is pending.
- The Update-now mechanism evidently did not keep this machine current across a day of
  fourteen versions — Auditor A owns why.

## Rules that bind this work
- Auditors write ONLY under `.forge/auditor/`. No source edits, no VERSION bump.
- No SketchUp, no V-Ray, no `ruby.exe` on this machine. `scripts/rbparse.py` boots
  SketchUp's own CRuby DLL and can evaluate pure-Ruby snippets; use it to turn a derived
  finding into an observed one where the code is pure.
- A finding with no trigger path is noise. Rank by probability × cost.
- Build only into an Untitled model — any script that writes to `Sketchup.active_model`
  without that guard is a finding.
- Never invent a placement number; never recommend a booth model — code that does either
  is a finding.

## Out of scope
- Fixing anything. A Fixer mission follows once Benton picks from the ranked list.
- Render look development and V-Ray settings tuning (parked at
  `.forge/GOAL-prev-render-lookdev.md`).
- The one-off client scripts (`csusb-*.rb`, `smith-studio.rb`, `uthsc-audiology-rooms.rb`,
  `dowaly-kuwait-tv.rb`, `fvrl-podcast-alcove.rb`, `booth-4260-s.rb`, `booth-96168-s.rb`)
  and the 3D-print jigs — drawn once, not maintained.

## History
2026-09-01 — Floor-plan intake mission (accuracy + proposal speed) shipped through 1.19.2;
full text parked at `.forge/GOAL-prev-floorplan-intake.md`.
2026-08-31 — Render look-development mission parked, `.forge/GOAL-prev-render-lookdev.md`.
2026-08-30 — Portal-parity / proposal-package mission parked, `.forge/GOAL-prev-portal-vray-mission.md`.
2026-08-27 — Enhanced/IEP two-shell mission parked at 1.6.32, `.forge/GOAL-prev-iep-mission.md`.
