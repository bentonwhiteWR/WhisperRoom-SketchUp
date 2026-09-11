# FIXER HANDOFF — 1.65.1, the end-of-batch modal

(This file replaces a stale 1.55.0 handoff that was still on disk.)

## Produced
- `scripts/proposal-package.rb` — `self.finish` no longer opens ANY window at
  the end of a batch. The `UI.messagebox(lines.join("\n"))` and its
  `headless?` guard are deleted outright. New pure `self.summary_class(line,
  headline, bad_run)` decides the run-log colour; `finish` now computes
  `lost_now` / `fails_now` once and both the log colouring and the closing
  verdict read them.
- `scripts/rbtest-proposal.py` — new `nobox` source guard (no end-of-batch
  box in `finish`; exactly one messagebox left, the restore-failure one) and
  `sc1-sc6` for `summary_class`. Both mutation-checked.
- `scripts/wr_tools/VERSION` → 1.65.1. `DEVLOG.md` entry on top.
- `.forge/fixer/probe-finish-interactive.rb` — the live repro/oracle. Run it
  over the bridge with the panel OPEN. Returns `box_attempted` and
  `headless?`; a valid run has `headless? => false`.
- `.forge/fixer/probe-log-classes.rb` — live capture of the exact
  (text, class) pairs `finish` hands the panel log.

## Read-first
- `scripts/proposal-package.rb`, `self.finish` (~line 3469) — the comment
  block there is the whole argument. **Do not reintroduce a box guarded by
  `headless?`, `dlg.nil?`, or anything else.** That is precisely the fix that
  shipped in 1.65.0 and did nothing.
- `self.headless?` (~line 3563): latched in `start_run` as
  `dlg.nil? || cfg['force']`. It describes the CALLER, never the box.
- **Never verify an interactive-path fix with a `force` run.** It takes the
  headless branch, everything looks clean, and nothing is proven. This is how
  Benton was told three times that a live bug was fixed.

## Assumptions
- `.forge/fixer/probe-*.rb` drive `finish` with hand-set state rather than a
  real render batch. The box decision, the restores, the manifest call and
  the log traffic are the real code; only the WORK that filled `@results` is
  synthesised. No full render-to-disk batch was run end to end.
- The panel's log was verified at the Ruby seam (the pairs sent, plus zero
  `execute_script` errors), not by reading the rendered CEF DOM — a callback
  registered after page load never fires, so the DOM could not be read back.
  `logLine` is unchanged shipped code.
- The probes ran against a blank model (0 scenes). Restores were configured
  to be no-ops so `restore_errs` stayed empty and the out-of-scope
  restore-failure box could not muddy the oracle.

## Open questions
- `@close_after` (window X'd mid-run) closes the panel right after `finish`,
  so that one path loses the log and keeps only the console. Pre-existing,
  not touched; worth a look if Benton ever closes the window to cancel.
- `finish`'s restore ORDER is still uncovered by any test.
- Not pushed. Benton is mid-reinstall; see the commit note on whether he
  needs to reinstall again (he does not, on this desktop).
