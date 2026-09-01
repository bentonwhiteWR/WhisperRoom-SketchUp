# synthetic-nasty-t2 — tier-2: a fresh transcription of the photo

Tier 2 tests the READING of a plan, which is where 31 Aug actually failed.
`../synthetic-nasty/takeoff-t2.json` was transcribed from
`../synthetic-nasty/input/photo.png` by a fresh agent that was given ONLY
the photo and `reference/takeoff-format.md` — it never saw truth.json, the
tier-1 fixture, or `eval/gen-plans.py` (the transcription prompt is
reproduced in `.forge/builder/HANDOFF.md`). Scoring it against the same
truth measures transcription error, in inches, end to end:

    python scripts/eval-floorplan.py synthetic-nasty-t2

Pass, per spec B2: every stated dimension transcribed exactly (a stated
number is exact — any transcription error is a miss), traps flagged rather
than guessed. The run's verdict and any misreads are recorded in
eval/RESULTS.md.
