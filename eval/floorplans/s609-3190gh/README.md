# s609-3190gh — the real 31 Aug room pair

The case the mission exists for. Exercises: the chain-with-parts trap
(17'3" is the clear width between two 10" heaters; 10" + 17'3" + 10" =
18'11" must be recorded and must close), the removed partition modeled as
one room with a bulkhead at 8'3" AFF (pen beats print), per-room ceiling
(8'9"), doors with pen widths but NO positions (must build flagged ASSUMED,
never silently placed), heaters as massing.

- Take-off: `clients/uic-daley-library/takeoff.json` (via `case.json`).
- Truth: written by `python eval/floorplans/derive-s609.py` from the
  S609-3.pdf vectors + the 18'11" pen anchor, +-2". Width 227" is exact by
  construction (it IS the anchor); depth uses the pen 14'4" (PDF face
  pairing gives 171.8-174.6"). The images and PDF are machine-local
  (gitignored) in `clients/uic-daley-library/plans/`; only these derived
  numbers are committed (Benton's Q5 call, 31 Aug 2026).
- Door positions have NO ground truth (stated nowhere) — truth marks them
  `expect_flag: assumed`, and a build without the ASSUMED note in the model
  scores as a failure even if the position happens to be right.

Companion case `../s609-3190gh-baseline/` reproduces the original failure
against this same truth — see `eval/RESULTS.md` for the before/after.
