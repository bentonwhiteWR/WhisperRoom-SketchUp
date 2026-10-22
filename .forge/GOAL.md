# GOAL

## Mission
Let two SketchUp files be worked at once through the bridge: each running SketchUp gets its own job
folder, every job names the file it is for, and a job can never run on the wrong model.

## Done means
1. Each SketchUp process polls its own slot folder; two open files never race for one job.
2. `sketchup-bridge.py` takes a target file (`--model`), refuses to run elsewhere, and `ping` lists open files.
3. With one SketchUp open, every existing command works unchanged (no `--model` needed).
4. The listener re-checks the open file before running, so a window that switched files refuses the job.
5. rbparse clean, pure tests for the client side, a live single-window check, VERSION bumped, pushed, DEVLOG.

## Now
Built and pushed as 1.85.0 (3d33cfa); waiting on Benton for the supervised two-window test.

## Out of scope
Changing the job protocol beyond addressing. Write-fence rules. Anything in WhisperRoomQuote.

## History
- 22 Oct: Walsh Construction Tech Lab v3 proposal DONE and approved; 1.84.7 installer covers every Forge account.
- 20 Oct: ISL 7296 4 ft proposal 9-page PDF built (private repo bc98a7b), waiting on Benton's review.
- 18 Oct: corner seam seal flip, 1.84.4 pushed (95ba408).
- 12 Oct: Walsh Construction Tech Lab MDL 96168 E DONE (first version).
