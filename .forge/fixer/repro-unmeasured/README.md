# Repro: unmeasured room scored 0.00" (fixed in 1.12.6)

truth.json lists a phantom room ("fixer-ghost") the take-off never builds.
Pre-fix, eval-floorplan.py recorded the run's worst vertex error as 0.00" —
a perfect-looking score for a room that was never measured. Post-fix the
worst column records "—" and the run prints a loud UNMEASURED line.

Re-trigger (SketchUp open, bridge listening; builds/replaces a scratch group
named "fixer-jog" — erase it after):
  python scripts/eval-floorplan.py "<abs path>/.forge/fixer/repro-unmeasured" --json
(absolute case path: the lock path crosses into SketchUp's own cwd)
