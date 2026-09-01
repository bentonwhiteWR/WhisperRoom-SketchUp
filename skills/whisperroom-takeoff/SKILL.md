---
name: whisperroom-takeoff
description: Turn a client floor plan — phone photo of a marked-up printout, PDF, or DWG — into an accurate SketchUp room via the take-off pipeline. Invoke when Benton or Gabe sends a floor plan to draw, says "take-off" or "transcribe this plan", asks to build a client room in SketchUp from a drawing, or when a takeoff.json needs checking, review, or a patch applied.
---

# WhisperRoom floor-plan take-off

**Normative schema and full procedure: `reference/takeoff-format.md` in the
WhisperRoom-SketchUp repo. Read it before writing a take-off — this skill is the
short form.** Worked example: `clients/uic-daley-library/takeoff.json`, the real
31 Aug 2026 job.

## Two paths — know which one you are on

- **Stated hand-written measurements (the mainline).** Typical client input is a
  phone photo of a printout with pen dimensions on it. The accuracy-critical step
  is **transcribing** those numbers and applying them to the right feature — not
  estimating anything. A pen number is exact; the failure mode is reading the
  right number as the wrong thing (a clear width transcribed as the wall width).
  Never estimate a dimension that is written on the plan, and never "sanity-check"
  a stated number against a pixel scale and blend the two.
- **No usable numbers on the plan.** Only then estimate scale from one named
  anchor per `reference/scale-estimation.md`. The failure mode is opposite — one
  scale error spreads over every dimension — so the output is a **range with a
  tolerance and the anchor named**, never a bare number, and it stays flagged as
  estimated until someone confirms it with a tape.
- Vector PDF / DWG in the job folder is the rare bonus: exact geometry, use it as
  `plan-vector` with a named anchor. Check the folder before scaling a photo.

## The workflow

```
photos / PDF  ->  clients/<job>/takeoff.json        (you transcribe — minutes)
python scripts/takeoff-check.py clients/<job>/takeoff.json --html
    -> fails BY NAME, or writes takeoff.lock.json + takeoff.review.html
Gabe reads the review sheet, answers the ASSUMED flags
    -> the sheet's copy box emits a structured patch (never prose)
python scripts/takeoff-check.py clients/<job>/takeoff.json --apply-patch patch.json
    -> refuses stale or sourceless edits by name; clean edits re-run the full check
SketchUp: load scripts/build-takeoff.rb, pick the lock file
    -> every room built and dimensioned; every ASSUMED value noted IN THE MODEL
```

Nothing builds from `takeoff.json` directly — `build-takeoff.rb` consumes only the
lock, so an unchecked take-off cannot reach the model.

## Record chains with their parts

A pen chain is written down **with its arithmetic**: `parts` must sum to `v`
exactly or the check fails by name. The 31 Aug job is the reason:
`10" + 17'-3" + 10" = 18'-11"`, where `17'-3"` was the clear width *between two
heaters*, not the room — transcribing it as the room width was ~8 ft wrong on one
axis. With the parts recorded, the checker catches the error; the reproduced
failure scores 20.00" of width error and the corrected take-off 0.00"
(`eval/RESULTS.md`).

**The named limit: the checker cannot catch a lone wrong number with no chain.**
A take-off that transcribes a clear width as the wall width, with no `parts`
recorded, validates clean and builds a room 24" too small — that case is
committed as `eval/floorplans/synthetic-clearwidth-trap/` and is caught only by
the scorer, which needs ground truth a real job doesn't have. So: **when the plan
shows a chain, record the chain.** Writing only the total throws away the one
cross-check the pipeline has, and no downstream step recovers it.

## Walk the room clockwise from the northwest corner

**This is the one convention nothing downstream can recover for you.** Runs are
a clockwise walk of the interior starting at the **northwest-most corner**, so
run 0 heads `E` along the northernmost wall. `build-takeoff.rb` reads its mitre
sense from the signed area and builds either winding happily — so a
counter-clockwise run list closes, validates and produces a clean, plausible
room, and a counter-clockwise list is exactly what a **mirrored** read of the
plan produces, since swapping east for west reverses the walk. The checker now
refuses an undeclared counter-clockwise walk, and a clockwise walk starting at
the wrong corner, by name.

If the plan genuinely reads the other way round — its pen chains all run
counter-clockwise, and forcing the convention would turn a measured number into
arithmetic — you may transcribe it counter-clockwise, but you must say so and
say why:

```jsonc
"winding": {"order": "ccw", "reason": "the only measured door position is a
            vertical pen chain running north corner -> near jamb down the west
            wall"}
```

That is the real UIC 3190J. Declaring `ccw` moves the start corner to the
northeast-most vertex, so run 0 heads `W`. A bare `"ccw"` with no reason, and a
declaration that contradicts the geometry, both fail by name.

**`at` is measured from the corner where its run starts**, along that run's own
travel direction — a run heading `E` is dimensioned from its **west** end,
heading `S` from its **north** end, `W` from its **east** end, `N` from its
**south** end. Benton's convention is corner → near jamb; this is *which*
corner. The checker prints it in words for every door
(`8'-10" from the north end of run 1`), so check your transcription against
that line rather than deriving it.

## Never invent a placement number

Every dimension is a `{v, src}` pair; `src` is mandatory and its first word is
closed vocabulary (`pen` / `plan-vector` / `stated` / `assumed` / `default`). A
missing dimension fails by name; a guess is legal only as explicit
`{"assumed": ..., "reason": ...}` and is flagged on the review sheet, in the
build report, and as a text note in the model at the feature itself. This is
enforced in code — the old dialog's silent `at:36"` door seed is the defect the
rule exists to prevent. Review-sheet edits obey the same rule: an edit with no
source is refused.

This covers the non-numeric values too:

- **`hinge` is mandatory** and fails by name when missing or unknown — it no
  longer quietly becomes `near`. Write `"near"`/`"far"` when the plan shows the
  leaf, `{"v": "far", "src": "pen IMG_7595"}` to name where you read it, or
  `{"assumed": "near", "reason": "no leaf drawn"}` when you had to guess.
- **An assumption may carry its arithmetic.** `parts` now hangs off an
  `{"assumed": ...}` value as well as a `{v, src}` one, and is summed either
  way. If you assume a total *from a chain* — 15" + 15'-2" + 15" — put the
  chain in `parts` where the checker can verify it, not in the reason string
  where it is prose.
- **A wall whose length is forced by closure is not a measurement.** Closure
  gives it that value by construction, so nothing confirms it. Record it as
  `"src": "derived closure"` with a note naming the runs that force it; it
  flags as DERIVED and gets a tape put on it. Two `derived closure` runs on one
  axis fail by name — closure forces exactly one unknown per axis.

## Machine facts — reuse these, don't rediscover them

- **A bare number is inches** in the value grammar (`150` = 150"). Feet need the
  mark: `12'6"`, `12'-6"`, `12' 6 1/2"`, `12.5'` all parse. The Python and JS
  parsers are held identical by `scripts/takeoff-vectors.json`
  (`takeoff-check.py --selftest`).
- Runs are rectilinear E/S/W/N in model coordinates (N = +y), walked clockwise
  from the northwest-most corner, and the polygon must close to 0.02" or nothing
  builds. Doors dimension the run's start corner → near jamb (`at`), may not
  touch a corner, and an omitted `h` builds 80" flagged DEFAULT.
- `--embed-photos` inlines the job photos into the review sheet as data URIs —
  off by default because publishing the sheet sends the image to claude.ai, a
  per-client decision. `*.review.html` and `*.lock.json` are gitignored;
  **client images are never committed to this public repo.**
- Scoring loop (eval work only): `python scripts/eval-floorplan.py <case>`
  against `eval/floorplans/<case>/truth.json`, ledger in `eval/RESULTS.md`.
  **It builds real geometry, so it refuses by name unless the active SketchUp
  model is Untitled**, and it erases the groups it created and reads back to
  confirm. Never aim it at a saved file.
- House defaults when the plan is silent: wall thickness 4", ceiling 8'-0" —
  but a defaulted ceiling is still recorded as `src: default` with a note, and
  the real height keeps being asked for; it disqualifies booths fastest.
- **There is no room-level `sill`** and one in a file fails by name. It was the
  height walls were split at for the old two-band construction; walls have
  built as one solid floor-to-ceiling since 1.12.8. A window's `sill` — how
  high it sits off the floor — is an unrelated number that shared the name, it
  lives on the window feature, and it is **required**: measured, or assumed
  with a reason.
