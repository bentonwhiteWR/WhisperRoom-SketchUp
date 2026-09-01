# HANDOFF — Auditor lane D (take-off pipeline, skills, docs), 2026-09-01

## Produced
- `.forge/auditor/full-audit-D-takeoff-skills-docs.md` — 12 ranked findings (4 HIGH,
  5 MEDIUM, 3 LOW), harness results, a checker-result table for all 26 eval cases, a
  skill-vs-code checklist both directions, and a "what is solid" section.
- `.forge/auditor/eval-run/<case>/` — scratch copies of every eval `takeoff.json` with the
  lock files the checker wrote there (none written into `eval/` or `clients/`).
- `.forge/auditor/eval-run/uic-daley-library/takeoff.review.html` — the UIC sheet generated
  WITHOUT `--embed-photos` (no client image in it); `autotest-dom.html`, `patch-observed.json`
  (what the sheet emitted), `patch-hand.json`, `patch-reopen.json`, and the `rt-*/`
  round-trip results; `block0.js`/`block1.js` used for `node --check`.
- `.forge/auditor/eval-run/hinge-probe/` — the assumed-hinge probe behind finding D-6.
- `.forge/auditor/proposal-run/` — `example.html`, `example.pdf`, page and bottom-edge
  rasters (no client material; the repo's example only).

## Read-first
1. Findings D-1 (no Untitled guard in either builder), D-2 (proposal skill commits client
   material to the public repo), D-3 (`CLAUDE.md` contradicts the take-off STOP block),
   D-4 (`NOTES_IN_MODEL=false` vs docs/sheet/scorer) — these are the ones that change what
   Benton does tomorrow.
2. The eval table — the only case out of line is `synthetic-headroom` (D-5).
3. The "what is solid" section before deciding scope for the Fixer: the checker, the sheet
   and the patch loop are in good shape; the drift is in Ruby entry points and prose.

## Assumptions
- **observed:** every harness result, every checker exit code, the sheet's contents and
  autotest, the patch round-trips, the proposal build/print, the doc text and line numbers.
- **derived:** the builders write into the active model unguarded and erase by name
  (`build-takeoff.rb:190,219`; `build-room.rb:353`); the scorer will fail expect-flag
  cases now that notes are off (`wr-bridge-lib.rb:223` + `eval-floorplan.py:291-299`);
  `:loose` is never printed. All from reading Ruby that `rbparse.py` says parses; none run.
- **reported:** the 31 Aug diagnosis, the builder handoffs, `eval/RESULTS.md` rows, and
  "we were working on the skills today".
- **assumed:** that the skills installed in `~/.claude/skills/` match the repo (the
  orchestrator says byte-for-byte; I did not re-diff).

## Open-questions
1. D-4 needs a decision before a fix: where does provenance live in the model now that
   text is banned — group attributes read by `takeoff_readback`, or the lock alone with
   the scorer reading it? The eval suite cannot be re-run meaningfully until this is chosen.
2. D-2: which private location is THE one for client proposal configs — the
   `whisperroom-proposals` repo (CLAUDE.md) or the `WhisperRoom Proposals\examples`
   folder (playbook)? Benton's call; the skill must then say only that.
3. Should `--embed-photos` be the skill's default with an explicit opt-out, or stay opt-in
   with the skill told to ask? Per-client policy, Benton's call.
4. Whether `build-room.rb` needs a saved-model override for anyone who deliberately draws
   into a client file — the guard in D-1 should refuse by default either way.
5. Nobody has clicked the sheet's zoom, popover, unit toggle or notes box (DEVLOG Next-step 3
   still open); this audit exercised them only through `#autotest` and code reading.
