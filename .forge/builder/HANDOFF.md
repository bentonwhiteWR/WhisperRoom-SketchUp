# HANDOFF — Builder: AUTO-SET the proposal package from a selected booth (1.48.0)

The previous mission's builder handoff (the step from the booth link, 1.45.0) is preserved
verbatim as `.forge/builder/HANDOFF-booth-link-step.md` — the scoper's own convention for
this baton pass.

10 Sep 2026. Built from `.forge/scoper/proposal-autoset.md` (11 sections), artifact
approved by Benton. Q1 = 2 renders (a knob, not a constant), Q2 = plate 3 is a FRONT
elevation. Q3/Q4/Q5 taken at their defaults: interior plate off, no sun presets, the
other booth stays visible.

## Produced
- `scripts/wr-autoset.rb` — **new.** `WR_AutoSet`: the resolver, the six plates, the
  render ladder, the annotation allowlist, the camera-cone wall rule, the stamp and the
  containment rule, the writer, the undo step, and `row_states` (the review columns).
  A **library** — added to `wr_tools/main.rb`'s `SKIP` list, so no `@title`/`@cat`/`@rank`
  and no `icon-map.json` entry. That is the `wr-scene-sun.rb` convention; the assignment's
  guess (tool headers + icon) was wrong for a library and CLAUDE.md/`main.rb` settle it.
- `scripts/proposal-package.rb` — loads `wr-autoset.rb`; `WR_AutoSet` joined `undo_mod`;
  `state()` gained per-row `walls`/`annots` + a `deep` flag; new `row_states` /
  `invalidate_rows!` / `rows_changed` / `log_row_cost` / `autoset_payload` /
  `autoset_push`; four callbacks (`autosetopen`, `autosetpick`, `autosetapply`,
  `autosetclose`); the AUTO-SET bar, the `#gwrap` popover, its CSS, and the
  `wallsCell` / `annotsCell` renderers in `draw()`.
- `scripts/proposal-scenes.rb` — two cosmetic changes only, no behaviour: `@title` says
  "(legacy - fixed five, no booth)", and `report` points at AUTO-SET and names the
  side-vs-front difference.
- `scripts/rbtest-autoset.py` — **new**, 63 checks + an allowlist-vs-denylist source check.
- `scripts/jstest-proposal-dialog.js` — 8 new checks for the review columns.
- `scripts/wr_tools/VERSION` 1.47.0 → 1.48.0. `scripts/wr_tools/main.rb` SKIP list.
- `.forge/builder/verify-autoset.rb` — **the live half. UNRUN.**
- `DEVLOG.md` — entry on top.

## Read-first (whoever is next)
1. The header of `scripts/wr-autoset.rb` — the allowlist and the containment rule, in full.
   They are the two things that must not be "simplified".
2. `scripts/rbtest-autoset.py`'s docstring — the nine mutants and which check each kills.
3. **`.forge/builder/verify-autoset.rb` has not been run.** Everything about page
   creation, the stamp across a re-run, what a scene actually saves, the undo step and
   the measured cost of the deep read is UNVERIFIED until Benton pastes it into the Ruby
   Console of an Untitled model.
4. `main.rb` changed, so this release needs `git pull` + `install-plugin.py` + restart on
   another machine, not just a pull.

## Assumptions
- **observed (run, this session):** `rbparse.py` 75/75 clean; `rbtest-autoset.py` 63/63;
  every other `rbtest-*.py` unchanged and exit 0 (`rbtest-live-booth.py` needs a live
  SketchUp and a subcommand — pre-existing, untouched); `node --check` and
  `jstest-proposal-dialog.js` PASS; nine Ruby mutants and four JS mutants each made the
  NAMED check fail and were reverted.
- **derived:** that `write_scene` (not `apply`) is the right seam for a multi-page run;
  that a re-aim needs its own `page.update(PAGE_USE_CAMERA)` because the walls' mask saves
  hidden state only; that the door heading must be read from the BOOTH's own subtree, or a
  two-booth model averages both doors.
- **assumed, and flagged:** that containers nested below the booth carry identity
  transforms (`tag_az`'s stated caveat — the same one `side_of` documents); that
  `Page#layers` returns the hidden tags (observed by others, 31 Aug 2026, not by me).
- **NOT run, and must not be claimed as run:** anything in SketchUp. No dialog has been
  opened, no scene created, no PNG exported. The D5 export check (§7's last line — open
  every exported PNG and confirm no `Ceiling 8'-0" - HOUSE DEFAULT` banner) is Benton's.

## Open questions
- The deep read's cost is still a number nobody has: `verify-autoset.rb` prints it, and
  `DEEP_BUDGET` (2.5 s) is a guess until it does. If it comes back slow, the fallback is
  already built and automatic.
- `06-interior`'s framing is a placeholder (eye 0.55·r inside, looking back across the
  booth). It is off by default and nudge-and-re-save is the documented answer, but nobody
  has looked at one.
- Whether Benton wants AUTO-SET's plate 3 change reflected back into
  `proposal-scenes.rb`'s own `03-side`. Left alone deliberately — §9 forbids behaviour
  changes there — but both packs on disk want a front elevation, so it is worth asking.
