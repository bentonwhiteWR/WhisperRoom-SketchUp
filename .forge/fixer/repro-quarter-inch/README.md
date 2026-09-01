# Repro: quarter-inch value unpatchable (fixed in 1.12.6)

The review sheet displays through arch() (tenth-of-an-inch); the patch's
`old` is that displayed string. Before 1.12.6, --apply-patch compared it to
the exact stored value with TOL=0.02", so any value finer than 0.1" always
refused as "written against a different take-off".

Re-trigger:
1. `python scripts/takeoff-check.py .forge/fixer/repro-quarter-inch/takeoff.json --html review.html`
2. `python scripts/takeoff-check.py .forge/fixer/repro-quarter-inch/takeoff.json --apply-patch .forge/fixer/repro-quarter-inch/patch.json`
   - pre-fix: refuses with "old is 12'-6.2" but the file currently says 12'-6.2""
   - post-fix: applies (staleness judged at DISPLAY_TOL = 0.05"+eps)
3. `stale-patch.json` (old off by 1/2") and `sixteenth-stale.json` (old off by
   exactly 1/16") must BOTH still refuse — the staleness check keeps catching
   real mismatches.

NOTE: takeoff.json now holds 12' 6 1/2" (the applied patch); the original
quarter-inch values are what steps 1–2 regenerate against if you reset it to
12' 6 1/4" on runs[0] and runs[2].
