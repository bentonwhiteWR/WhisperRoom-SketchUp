# Documenter handoff — panel redesign

## Produced

- `DEVLOG.md` — new top entry, `## 2026-08-15 — the panel is rebuilt, and flipping a
  switch no longer opened a dialog`. Covers the autorun defect and why `load_quietly`
  restores the globals, the three optional header directives and the zero-edit
  property, why two categories are ranked, the icon system rules and their enforcer,
  what was deferred (spec steps 6 and 7) and what was shelved rather than deleted, the
  unverified list, and the six-title open question.
- `README.md` — two corrections only. The scripts section and the plugin section both
  described the panel as "newest first"; sorting is now fixed category order, then
  `@rank`, then alphabetical. Also names the shelves and the NEW pill.

## Read first

1. `DEVLOG.md` top entry — it is the durable record of this round.
2. `.forge/builder/HANDOFF.md` and `.forge/builder-icons/HANDOFF.md` — the two
   builders' own accounts, including their open questions.

## Assumptions

- Everything in the DEVLOG entry is checked against the diffs of `ec6e79b`, `ece6e1e`,
  `14a31c4`, `3cbe143` and the files on disk, not taken from the builders' summaries.
  The one exception: the headless render-assertion counts (54, then 59) and the Chrome
  330/640 px check are **reported** from the builder's commit messages and were not
  re-run, so the entry states them as "headless render assertions" without a count.
- Nothing in `scripts/`, `.forge/` or any asset was edited by me.

## Open questions

1. The six unrenamed titles (`list-scenes.rb`, `orbit-export.rb`, `explode-view.rb`,
   `save-scene-components.rb`, `find-replace-names.rb`, `merge-materials.rb`) are in
   the DEVLOG as an open question for Benton. When he answers, the entry needs no
   change — a later entry records the renames.
2. `README.md`'s script table still lists nine scripts by filename with old-style
   descriptions. It is not wrong, but it predates the category tree and does not
   mention the other ~24 scripts. Left alone; expanding it was not this round's job.
