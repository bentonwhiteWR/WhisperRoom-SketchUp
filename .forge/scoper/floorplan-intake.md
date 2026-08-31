# Spec — Floor-plan intake pipeline + evaluation loop

Scoper, 2026-08-31. Sources: `.forge/researcher/floorplan-pipeline-diagnosis.md` (verified
where load-bearing — I re-read `scripts/build-room.rb`, `scripts/build-room.html`,
`scripts/sketchup-bridge.py` header, `scripts/wr_tools/wr_bridge.rb` header,
`reference/scale-estimation.md`, and the actual photo `C:\Users\bento\Downloads\IMG_7594.jpeg`
myself), `.forge/GOAL.md`, `CLAUDE.md`. No production code written; SketchUp is not running,
so nothing here has been executed live — every "the code does X" claim below is a code read
unless a DEVLOG live run is cited by the diagnosis.

**The one decision Benton must make** is Q1 in Open Questions: approve the take-off-file
shape (agent transcribes → Gabe reviews a check sheet → one click builds every room) over
extending the typing dialog. Everything else follows from it.

---

## Goal

A client floor plan — usually a phone photo of a pen-marked printout, sometimes a PDF,
rarely a DWG — becomes an accurate, dimensioned SketchUp model of every room on it in
minutes of human time, with the two 31 Aug failures made structurally hard to repeat:
a stated dimension can no longer be silently misapplied (chain arithmetic is recorded and
checked), and no placement number can be invented without being marked ASSUMED all the way
into the model. A scoring loop measures error in inches against known ground truth, so
every change to the pipeline can be shown to help or not.

---

## Approach — the shape and why

### The root decision: the intake artifact is a data file, not keystrokes

The intake becomes a **take-off file** — `takeoff.json`, one per job, living in
`clients/<job>/` — that records every dimension **as stated on the plan, with its
arithmetic and its source**. It is authored by whoever reads the plan (in practice: the
agent, from the photos/PDF, in minutes), validated by a standalone checker that runs
without SketchUp, reviewed by Gabe as a one-page HTML check sheet, and built by one
command that constructs **all rooms in one go** through the existing `WR_BuildRoom`
geometry (which is sound — the polygon/mitre/wall/door math built a room end-to-end
through the bridge in 0.271 s per `DEVLOG.md:1203`, reported).

Why a file and not a better dialog, against how Gabe actually works:

- **The expensive human step on 31 Aug was not clicking — it was interpreting three
  photos and then re-typing the interpretation, four times, into a form that could not
  hold half of it** (heaters, bulkhead, per-room ceilings, window walls, notes — observed
  absence in `scripts/build-room.html`). A dialog fix makes the typing nicer; it does not
  remove it. A file removes it: the agent does the transcription, Gabe only reviews.
- **Provenance needs somewhere to live.** "17'3" is the width *between the heaters*,
  parts 17'3" + 10" + 10" = 18'11"" is a sentence about a number. A dialog cell holds a
  number; a file holds the sentence, and the validator can then *check* the sentence.
- A file diffs, commits to `clients/<job>/` (the protocol the 31 Aug job never entered —
  observed: no `clients/` folder exists for it), reruns identically, and is exactly what
  the eval loop needs as its unit under test.
- **The dialog stays** for its real case — a quick rectangle typed at the machine — and
  gets its invented-default defects fixed (Step 7). It stops being the multi-room path.

Pipeline, end to end:

```
photos / PDF / DWG
   │  transcription (agent; or Gabe by hand for a trivial job)
   ▼
clients/<job>/takeoff.json      every value: {v, src}; chains carry their parts
   │  python scripts/takeoff-check.py        ← no SketchUp needed
   ▼  fails BY NAME on: open chain, parts≠sum, missing door position, missing ceiling…
takeoff.lock.json  +  review sheet (HTML)    ← Gabe reads this, 2–3 min, answers flags
   │  panel button "Build from take-off…"  or  bridge job
   ▼
SketchUp: all rooms, dimensioned, every ASSUMED value flagged in the model itself
```

### Where the human time goes, honestly

| Step | Today (31 Aug shape) | With this spec |
|---|---|---|
| Interpret pen chains | 5–15 min/room, in Gabe's head, unrecorded | agent transcribes; ambiguities become named flags |
| Enter geometry | 3–5 min/room typing into the dialog | zero — file is the input |
| Heaters, bulkhead, windows, ceilings | impossible in the tool; hand-modeled after | fields in the file, built as flagged massing |
| Review | none (errors surface in the model, or never) | **2–3 min/job** on the check sheet — the irreducible step, and the right one |
| Build | once per room, then manual fix-up | one command, all rooms |

The irreducible human work is resolving genuine ambiguity — which face a dimension runs
to, where an unmeasured door sits, whether a removed wall makes one room or two. The
design's job is to make those the *only* things a human is asked, and to ask them by name
instead of silently guessing. A design that still needed an hour of typing would not have
solved Benton's problem; this one needs minutes of review.

---

## Part A — the intake

### A1. The take-off format (`takeoff.json`)

New reference doc: `reference/takeoff-format.md` (Step 2) is the normative schema; this
section is its content in brief. Worked example committed as
`clients/uic-daley-library/takeoff.json` — the real 31 Aug job, which exercises every
feature of the format.

Principles, each mapped to a confirmed failure:

1. **Every dimension is a `{v, src}` pair.** `v` is a dimension string in exactly the
   grammar `parseLen` already accepts (`150`, `150"`, `12'6"`, `12'-6"`, `12' 6 1/2"`,
   `12.5'`; bare number = inches — observed at `scripts/build-room.html:194–215`). One
   grammar, specified in `reference/takeoff-format.md`, ported to Python in the checker;
   the two implementations are held identical by a shared test vector list (Step 3).
   `src` is mandatory and closed-vocabulary: `pen` (hand-written field measurement —
   names the image), `plan-vector` (from PDF/DWG geometry — names the anchor), `stated`
   (client email/text), `assumed` (requires `reason`), `default` (house default —
   requires the default's name). Missing `src` is a validation failure by name.
2. **Chains carry their arithmetic.** A run value may be written
   `{"v": "18'11\"", "parts": ["10\"", "17'3\"", "10\""], "src": "pen IMG_7594",
   "note": "17'3\" is clear width between the two 10\" heaters"}` — and the checker
   *requires* parts to sum to `v` exactly. This is the invariant that catches the exact
   31 Aug trap: transcribe 17'3" as the wall-to-wall width and the file cannot validate,
   because the pen chain 17'3"+10"+10" = 18'11" is recorded, not remembered.
3. **The polygon must close** (same check the dialog already runs, now at intake) —
   and where two chains state the same span (e.g. 18'11" at the window wall *and* at the
   door wall), both are recorded and must agree within a stated tolerance.
4. **Placement numbers cannot be invented silently.** A door row is
   `{"run": 2, "w": {"v": "38\"", "src": "pen IMG_7594"}, "hinge": "near", "at": …}` and
   `at` must be present as either a measured `{v, src}` or an explicit
   `{"assumed": "6\"", "reason": "no position on plan; drawn at jamb per plan symbol"}`.
   A door with no `at` at all fails by name:
   `door 1 on run 2: no position. Measure corner→near jamb, or mark it assumed with a reason.`
   Same rule for `door_h` (the dialog currently hardcodes 80" with no field — observed at
   `scripts/build-room.html:497`), ceiling, and every feature offset.
5. **The plan's annotations have fields.** Per room: `ceiling {v, src}` (mandatory —
   `default` src allowed but flags), `features[]` with types `heater`
   (`run`, `from` corner offset, `depth`, `length`), `bulkhead` (`between`/`run`,
   `head_height`), `window` (`run`, `from`, `width`, optional `sill`), and free
   `notes[]`. Features build as simple flagged massing boxes on a `WR-Obstruction` tag —
   their job is to occupy footprint so booth-fit math is honest, not to look like a
   radiator.
6. **Job-level facts are recorded once**: source images/PDF by filename, the scale anchor
   if any, and interpretation calls (`"partition between 3190G/H removed per pen note;
   modeled as one room with bulkhead at 8'3\""`) so the file is the provenance record
   `clients/README.md` already asks for.

Reserved, explicitly not in v1: curved/angled walls (runs are rectilinear `E/S/W/N`,
matching `WR_BuildRoom::DIR` — observed), multi-floor, wall openings other than doors and
windows.

### A2. The checker — `scripts/takeoff-check.py`

Pure Python, no SketchUp, runs on any machine. Given `takeoff.json`:

- parses every dimension (grammar above); any unparseable value fails naming the field;
- runs the invariants: per-room polygon closure (tolerance 0.02", matching
  `WR_BuildRoom::TOL`), every `parts` list sums to its `v` **exactly** (these are stated
  integers of inches; a mismatch means a transcription error, not noise), duplicate-chain
  agreement, doors within their run, door/window overlap, `src` present everywhere,
  ceiling present per room;
- prints the **ASSUMED inventory** — every value whose src is `assumed` or `default`,
  by name, with its reason — and exits non-zero if any invariant fails;
- on success writes `takeoff.lock.json`: everything normalized to float inches with the
  assumed/default flags carried through. **The builder consumes only the lock file** —
  Ruby never re-parses dimension strings, so the grammar lives in exactly two places
  (dialog JS, checker Python) instead of three;
- `--html` emits the **review sheet**: a self-contained HTML page (mockup:
  `.forge/scoper/takeoff-review.mockup.html`, populated with the real 3190G/H data —
  this is the approved look, in `build-room.html`'s own house style) showing per room a
  to-scale plan with the chains drawn, each value badged by source
  (PEN / VECTOR / ASSUMED / DEFAULT), the closure checks green/red, and the ASSUMED
  inventory as the loudest block on the page. Gabe opens it in a browser; no new
  HtmlDialog is needed.

### A3. The builder — `scripts/build-takeoff.rb`

A TOOLS-tab script (and a panel button) that takes a `takeoff.lock.json` path
(file-picker from the panel; `WR_TAKEOFF` env/arg when driven through the bridge) and
builds **every room in the file** in one operation:

- reuses `WR_BuildRoom`'s geometry (`polygon`, `mitre`, `wall_run`, `door`, `band`) —
  **which requires `scripts/build-room.rb` to grow an autorun guard and a callable API**
  (today it executes `WR_BuildRoom.open` unconditionally on load — observed at
  `scripts/build-room.rb:531`, and noted as a bridge annoyance in `DEVLOG.md:1221–1227`,
  reported). Change: wrap the trailing `.open` in the existing `$wr_suppress_autorun`
  convention; no geometry change.
- places rooms side by side with a stated gap, or at true relative offsets when the file
  gives per-room `origin` values;
- builds a **ceiling slab per room at that room's own ceiling height** (closes the
  DEVLOG.md:833 gap; the 31 Aug client's headline data was per-room ceilings 8'7"–8'9",
  observed on the photos);
- builds features as massing on `WR-Obstruction` (heaters, bulkhead at its head height);
- **every ASSUMED/DEFAULT value produces a model text note** on `WR-Notes` at the
  feature itself, in the exact pattern the 96" ceiling already uses (observed at
  `scripts/build-room.rb:414–423`): e.g.
  `Door position ASSUMED (6" from corner) — no measurement on plan. Confirm before quoting.`
  The console report lists the same inventory. This is the "never invent a placement
  number" rule moving from a document into code: an invented number can still exist, but
  it cannot exist *unmarked*.
- dimensions every room via `WR_AutoDimension.dimension_face` as build-room already does.

### A4. Fix the dialog's invented defaults and the corner-door defect

Named for a Builder; not built now; `scripts/wr_tools/VERSION` bump required.

1. `scripts/build-room.html:477` — "+ door" seeds `{at:36}`. Change: seed `at` empty and
   red (the `lenField`/`bad` machinery already blocks Build on a red field — observed at
   `:347–363` and `:334`); placeholder text `from corner — measure it`. A door row with
   no position blocks Build with the hint naming it. (An "assumed" escape hatch in the
   dialog is deliberately *not* added — the dialog is for measured quick jobs; anything
   with assumptions belongs in the take-off file where the flag propagates.)
2. `scripts/build-room.html:497` — `door_h:80` hardcoded. Change: a "Door height" field
   in detail mode, pre-filled 80" with a note "standard leaf, not measured", passed
   through as today; the Ruby report line (`build-room.rb:353–354`) already prints it.
3. `scripts/build-room.rb:254–257` vs `:405–410` — a door whose cut touches a corner is
   silently dropped from `wall_run`'s cuts while `door()` still draws the leaf: solid
   wall with a leaf embedded, no message. Change: validate doors *before* building —
   any door with `at < TOL` or `at + w > len − TOL` fails the whole build by name
   (`door 1 on run 2 touches the corner — build-room cannot cut a corner opening; move
   it or shrink it`), matching the existing closure-failure messagebox pattern at
   `:359–364`. (Refusing loudly beats teaching the mitre code corner openings; corner
   doors are rare and the failure today is silent, which is the actual defect.)
   The same guard goes in `build-takeoff.rb`.

### A5. Vector-PDF fast path — `scripts/pdf-takeoff.py`

When the job includes a vector PDF (Benton: input is "usually just photos/PDF" —
PDF is half the mainline), PyMuPDF (installed, 1.28.2 — reported by the diagnosis, whose
numeric verification I re-read but did not re-run) extracts the wall segments in a
cropped region, takes **one named pen anchor** from the operator
(`--anchor "18'11\" across G+H interior"`), and emits a *draft* `takeoff.json` with
`src: "plan-vector (anchor: …)"` on every derived value. Every stated pen dimension is
then attached as a cross-check the checker enforces: PDF-derived value and pen value must
agree within a stated tolerance (default ±2", the accuracy the Researcher verified on
S609-3) or the check fails by name. The draft still goes through the same review sheet —
the fast path changes who types, never what gets checked. The Researcher's diagnosis
(§1.3) demonstrated the extraction numerically on S609-3 (reported; their probe script is
in their scratchpad and the approach is re-implemented properly here).

### A6. DWG — documented path, not built

`dwgimporter.dll` ships in both installed SketchUps (reported, diagnosis §1.4).
Documented procedure in `reference/floorplan-intake.md`: File → Import → DWG, set units
at import, use the imported linework as a tracing underlay and/or read dimensions off it
with the tape tool; the take-off file still gets written (src `plan-vector`), because the
file is the provenance record and the eval unit. A scripted DWG→takeoff path (ODA File
Converter + `ezdxf`) is named as the future upgrade and **explicitly out of scope** —
the vector-PDF route covers the same jobs with tools already installed (Q4).

### A7. The written protocol

New `reference/floorplan-intake.md`: how to read a marked-up plan — transcribe every pen
number *verbatim* with its location; record chain arithmetic and require closure **at
intake** (today that rule exists only for output drawings in `CLAUDE.md` — observed);
the which-face rule (a dimension with unstated faces is recorded with a `note` and,
if it changes geometry, an `assumed` interpretation); **pen beats print** (a pen note
contradicting the printed plan — a removed wall — wins, and the call is recorded in the
job-level interpretation list, Q3); when a PDF/DWG exists, run A5 first and use the pen
as anchor + cross-check. `reference/scale-estimation.md` gets one added paragraph up top:
if the measurements are *stated* on the plan, scale estimation does not apply — go to
`floorplan-intake.md` (its §7 "never invent" rule now points at the enforcement, not
just the ask). The `whisperroom-proposal` skill's intake references update to match
(GOAL "Done means" #5).

---

## Part B — the evaluation loop

### B1. Structure

```
eval/floorplans/
  <case>/
    truth.json        exact ground truth (committed — numbers only)
    takeoff.json      the transcription fixture (committed)
    input/            photos / PDFs (gitignored when client-derived; synthetic committed)
    README.md         what the case exercises, where truth came from
  gen-plans.py        synthetic plan author (PyMuPDF): vector PDF + rasterized "photo"
  RESULTS.md          the before/after ledger, one dated row per scored run
scripts/eval-floorplan.py   the scorer (drives the bridge)
```

`truth.json` per room, in the room's own frame (origin = the corner the take-off's run 0
starts from, so no best-fit alignment is needed): interior polygon vertices (inches),
per-door jamb positions along their run + width, ceiling height, feature list
(type + position + size), and a per-value tolerance.

### B2. Two tiers, because two different things can be wrong

- **Tier 1 — deterministic build** (`takeoff.json` fixture → lock → build → read back).
  Tests the checker + builder only. Pass: **max vertex error ≤ 0.1"** on every room,
  door jambs ≤ 0.1", ceiling exact — the math is exact, so anything more is a bug.
  This runs on every change to `takeoff-check.py` / `build-takeoff.rb` and is the loop's
  fast inner cycle.
- **Tier 2 — end-to-end transcription** (photo → agent writes `takeoff.json` → tier 1).
  Tests the reading of the plan, which is where 31 Aug actually failed. Pass, on
  synthetic cases (truth known exactly): **every stated dimension transcribed exactly**
  (a pen number is an integer of inches; ±0 is the standard — a transcription error of
  any size is a miss), every trap **flagged rather than guessed** (see B4). On the real
  S609 case: geometry within **±2"** of the PDF-derived truth (the source's own
  accuracy), and the ASSUMED inventory containing exactly the values the photos genuinely
  do not state (door positions) — an unflagged assumption is a failing score even when
  the number happens to be right.

### B3. The scorer — `scripts/eval-floorplan.py`

Drives the existing bridge (`scripts/sketchup-bridge.py` exports `submit()` for exactly
this — observed in its header; the resident half fences writes and JSON-encodes returns —
observed in `scripts/wr_tools/wr_bridge.rb`'s header; it has driven build-room end to end
per `DEVLOG.md:1203`, reported). Scratch models only, per GOAL rules. Per case:

1. submit a job that runs `takeoff-check.py`'s lock output through
   `build-takeoff.rb` in a new scratch model;
2. submit a read-back snippet (helper in `scripts/wr-bridge-lib.rb`, which is read live
   from the repo — observed note in wr_bridge.rb header) returning JSON: per room group —
   floor-face outer-loop vertex coordinates; every `WR-Doors` "Opening" group's bounds
   projected onto its run (the opening marker sits exactly in the wall plane spanning
   exactly the opening — observed at `scripts/build-room.rb:281–299` — which is what
   makes jambs machine-readable); ceiling slab height; `WR-Obstruction` groups
   (type from name, bounds); `WR-Notes` texts (the ASSUMED flags);
3. compare to `truth.json` and print a table **in inches**: per room max vertex error,
   per door jamb error, ceiling delta, features missing/extra, **unflagged-assumed
   count**; plus a machine-readable JSON blob;
4. exit non-zero on any threshold breach, and append a dated row to `eval/RESULTS.md`
   when `--record` is passed — that ledger *is* the measured before/after GOAL asks for.

### B4. The case set — mainline first, this job's traps specifically

Photo-of-marked-up-printout cases lead, per Benton's steer:

| # | Case | Exercises | Truth source |
|---|---|---|---|
| 1 | `s609-3190gh` | **The real 31 Aug room pair.** Chain-with-parts trap (17'3" between two 10" heaters), removed partition + bulkhead 8'3", two ceilings on one plan (8'8"/8'9"), doors with widths but no positions, window walls | S609-3 PDF vectors + the 18'11" pen anchor, ±2" |
| 2 | `s609-3190j` + `s609-3190f` | chains that close; heater at a stated offset (9'1"); ordinary case | same |
| 3 | `synthetic-clean` | rectangle + one door with measured position; the base case | authored, exact |
| 4 | `synthetic-nonclosing` | a chain deliberately 4" open | authored — **pass = checker refuses by name; builder never runs** |
| 5 | `synthetic-missing` | door with no position; room with no ceiling | authored — **pass = fail-by-name, or ASSUMED-flag path end to end** |
| 6 | `synthetic-nasty` | L-shaped room, heater offset, bulkhead, two adjacent rooms with different ceilings, a parts-chain | authored, exact |

Cases 4 and 5 score behavior, not inches: the correct output *is* the named refusal or
the propagated flag. Cases 3–6 are authored by `eval/gen-plans.py`: PyMuPDF draws the
vector PDF (walls, dimension strings, hand-note-styled callouts), rasterizes at ~150 dpi,
and optionally applies a mild perspective warp to mimic a phone photo (warp only if
Pillow is present — its availability is **unverified**; without it the rasterized flat
image still exercises the transcription path, so Pillow is a nice-to-have, not a
dependency).

### B5. Capturing S609-3 as the real fixture

The 31 Aug artifacts are worth more than any synthetic case and are currently loose in
`Downloads`. Capture step (Builder, Step 1):

- copy `IMG_7594/5/6.jpeg` and `S609-3.pdf` (read-only from
  `C:\Users\bento\Downloads\` — never modify there) into
  `clients/uic-daley-library/plans/` — **gitignored** by the existing
  `clients/**/plans/` rule (observed in `.gitignore`), so client material stays out of
  the public repo; `eval/floorplans/s609-*/input/` holds relative pointers, and the case
  README states the images are machine-local;
- re-derive the truth numbers with a committed probe (`eval/floorplans/derive-s609.py`):
  PDF wall segments + the 18'11" pen anchor → per-room interior polygons, written to the
  `truth.json` files with `±2"` tolerance and the anchor named. Committing the *numbers*
  follows the existing precedent that `clients/*/notes.md` dimensions are committed while
  assets are not (observed, `clients/README.md`) — flagged as Q5 anyway since the repo is
  public;
- write `clients/uic-daley-library/takeoff.json` + `notes.md` — the job finally enters
  the repo's own protocol, and the take-off doubles as the format's worked example.

### B6. The loop protocol

Tier 1 runs on every checker/builder change (single command, seconds per case once
SketchUp is up). Tier 2 runs when the *reading* procedure changes
(`reference/floorplan-intake.md`, the transcription prompt/skill, `pdf-takeoff.py`).
Every scored run appends to `eval/RESULTS.md`; a change ships only with its before/after
row. First recorded row: the current state — case 1 scored against a take-off produced
the *old* way (dialog semantics: no parts, invented `at:36`, one 96" ceiling) — so the
baseline the fix is measured against is the 31 Aug failure itself, reproduced.

---

## Steps

Ordered; each independently verifiable. **Slice 1 = Steps 1–6** — removes most of the
pain (accurate multi-room build from a checked file, the real fixture, the scorer) and
can ship as soon as Benton answers Q1/Q2. Steps 7–9 follow. Every step: commit + push;
Steps 6–7 bump `scripts/wr_tools/VERSION`.

1. **Capture the S609 fixture.** Files: `clients/uic-daley-library/` (plans copied,
   gitignored; `notes.md`), `eval/floorplans/s609-*/{truth.json,README.md}`,
   `eval/floorplans/derive-s609.py`. Change: the real job becomes reproducible ground
   truth. *Check:* `derive-s609.py` re-run reproduces `truth.json` byte-identical; the
   truth table matches the pen dims within 2" (the diagnosis §1.3 table, re-derived).
2. **Take-off format + worked example.** Files: `reference/takeoff-format.md`,
   `clients/uic-daley-library/takeoff.json`. Change: the schema exists, with the 31 Aug
   job expressed in it (parts-chain, bulkhead, per-room ceilings, assumed door
   positions all present).
3. **Checker.** Files: `scripts/takeoff-check.py` (+ shared grammar test vectors in the
   file or alongside). Change: validation + lock emit + ASSUMED inventory + `--html`
   review sheet matching `.forge/scoper/takeoff-review.mockup.html`. *Check:* AC-1..4.
4. **Builder.** Files: `scripts/build-takeoff.rb` (new), `scripts/build-room.rb`
   (autorun guard + expose `build` for reuse — no geometry change),
   `scripts/wr-bridge-lib.rb` (read-back helper). Change: lock file → all rooms +
   ceilings + features + ASSUMED notes. *Check:* AC-5..8 via bridge.
5. **Scorer + tier-1 green.** Files: `scripts/eval-floorplan.py`,
   `eval/floorplans/synthetic-clean/`, `eval/RESULTS.md` (baseline row per B6).
   *Check:* AC-9..10.
6. **Dialog fixes.** Files: `scripts/build-room.html` (door `at` seed, door-height
   field), `scripts/build-room.rb` (corner-door refusal), `scripts/wr_tools/VERSION`.
   *Check:* AC-11..13. — **ship line**
7. **Panel button** "Build from take-off…" (file-picker → checker-validated lock →
   `build-takeoff`). Files: `scripts/wr_tools/` panel wiring per its existing pattern,
   `VERSION`. *Check:* AC-14.
8. **Synthetic generator + remaining cases + tier 2.** Files: `eval/gen-plans.py`,
   `eval/floorplans/synthetic-{nonclosing,missing,nasty}/`, tier-2 run recorded on
   case 1. *Check:* AC-15..16.
9. **Protocol docs.** Files: `reference/floorplan-intake.md`,
   `reference/scale-estimation.md` (pointer paragraph), skill update. *Check:* AC-17.

Out of the way of the concurrent Builder: nothing above touches
`scripts/proposal-package.rb` or `scripts/check-doc-paths.py`.

---

## Acceptance criteria

Checks a Builder runs once SketchUp is up with the bridge enabled (none were run in this
scoping — SketchUp is not running, observed at dispatch):

- **AC-1** `python scripts/takeoff-check.py clients/uic-daley-library/takeoff.json`
  exits 0; the report shows every chain closed (including 17'3"+10"+10" = 18'11") and an
  ASSUMED inventory listing exactly the door positions and nothing else.
- **AC-2** Change that file's `17'3"` to `17'5"` → exit non-zero, message naming the
  parts-chain and both sums.
- **AC-3** Delete a door's `at` → exit non-zero with the fail-by-name text from A1.4
  (message must name the door, the run, and the corner→jamb measurement to take).
- **AC-4** Grammar parity: the shared test vectors (≥ 15, covering every form in the
  `build-room.html` comment plus junk inputs) produce identical inches from the Python
  parser and from `parseLen` (JS vectors checked by a node-free harness — a small HTML
  page or manual table is acceptable; the vector list itself is the artifact).
- **AC-5** Bridge: build `clients/uic-daley-library/takeoff.lock.json` in a scratch
  model → three room groups exist (G+H combined per the interpretation record, J, F);
  read-back reports per-room floor vertices within 0.1" of the lock's polygons.
- **AC-6** The G+H room has a ceiling slab at 8'9" (and the F room at 8'7"), heater
  massing on `WR-Obstruction` at both window walls, bulkhead massing with its underside
  at 8'3", and a `WR-Notes` text at each door reading `ASSUMED`.
- **AC-7** A lock file with an assumed `door_h` builds and its report lists it in the
  ASSUMED inventory; a lock file missing `ceiling` never reaches Ruby (checker refuses).
- **AC-8** Corner door: a take-off with `at: 0` fails in the checker by name;
  forcing it past the checker into `build-takeoff.rb` also fails by name — at no point
  does a leaf-in-solid-wall build (bridge assertion: opening-marker count equals leaf
  count in every built model).
- **AC-9** `python scripts/eval-floorplan.py synthetic-clean` prints max vertex error,
  door jamb error, ceiling delta in inches; all ≤ 0.1"; exit 0.
- **AC-10** Corrupt the synthetic-clean takeoff by 2" on one run → scorer exits non-zero
  and the table shows the 2" on the right room and no other.
- **AC-11** Dialog: "+ door" yields an empty red `at` field; Build stays disabled until
  a value is typed; hint names the door row.
- **AC-12** Dialog detail mode shows a Door height field pre-filled 80" with its
  "standard, not measured" note; the build report prints the value.
- **AC-13** Dialog: a door typed at `at: 0` → build refused with the corner message
  (messagebox), nothing half-built (model unchanged — verify by entity count).
- **AC-14** Panel: "Build from take-off…" on the UIC lock file builds the same model as
  AC-5; on an invalid file it shows the checker's named errors and builds nothing.
- **AC-15** `eval/gen-plans.py` regenerates the synthetic cases deterministically
  (same seed → byte-identical truth.json); `synthetic-nonclosing` scores as PASS when
  the checker refuses and FAIL if anything builds.
- **AC-16** Tier-2 on `s609-3190gh`: a fresh transcription from the photos scores within
  ±2" on every stated dimension with door positions flagged ASSUMED; the recorded
  baseline row (old-way take-off) shows the failure it replaces (expected: ~20" error on
  the G+H width if 17'3" is misapplied, a 96" ceiling 9" off, invented door positions
  unflagged).
- **AC-17** `reference/floorplan-intake.md` exists, `scale-estimation.md` routes
  stated-measurement jobs to it, and the skill references match — checked by reading,
  and `scripts/check-doc-paths.py` (the concurrent Builder's tool) if it lands first.

---

## Risks / out of scope

- **Residual accuracy risk is transcription** — an agent (or human) misreading
  handwriting. The design contains it (recorded arithmetic, closure checks, review
  sheet, tier-2 scoring) rather than eliminating it; OCR automation of pen notes is out
  of scope. The 17'3" trap is caught by the parts invariant **only if the transcriber
  records the chain**; the protocol doc makes "transcribe the whole chain, not one
  number" the first rule, and tier 2 measures whether that holds in practice.
- **Assumed-flag fatigue**: if everything gets flagged, nothing is. The closed `src`
  vocabulary and the checker's inventory keep flags scarce (only `assumed`/`default`
  flag); watch this in review-sheet use.
- **Bridge dependency**: tier-1 scoring needs SketchUp up with the bridge enabled;
  everything through the checker (AC-1..4) runs without it, so the Builder is not
  blocked end-to-end on Benton's machine state.
- **Two-implementation grammar drift** (JS + Python) — held by AC-4's shared vectors.
- Out of scope: scripted DWG conversion (documented path only, Q4); curved/angled walls;
  booth placement/recommendation (separate rules in `CLAUDE.md`); render/proposal
  styling; the proposal image-assembly speed problem (other Researcher's thread); any
  edit to `scripts/proposal-package.rb` or `scripts/check-doc-paths.py`.

---

## Open questions — approval gates for Benton

Real forks only; recommendation stated on each. Mirrored in `.forge/scoper/HANDOFF.md`.

- **Q1 (the decision).** Intake shape: approve the take-off file + review sheet +
  one-click multi-room build, with the dialog demoted to quick rectangles? The
  alternative — growing the dialog into a multi-room, provenance-carrying form — keeps
  Gabe typing and cannot record why a number is what it is. **Recommend: the file.**
  Open `.forge/scoper/takeoff-review.mockup.html` to see what Gabe would review.
- **Q2.** Unmeasured door position: build with a loud ASSUMED flag (drawn note + report
  + score penalty), or refuse to build until measured? Refusing pushes Gabe back to
  hand-drawing when a client photo simply lacks the number. **Recommend: build flagged,
  refuse only when `at` is absent entirely (no measured value and no explicit
  assumption).**
- **Q3.** Pen beats print: when a pen note contradicts the printed plan (the removed
  G/H partition), model per the pen and record the call — so the UIC fixture is one
  G+H room with a bulkhead, not two rooms? **Recommend: yes.**
- **Q4.** DWG: standardize on the vector-PDF route (no installs) and document manual
  DWG import, deferring ODA File Converter + `ezdxf`? **Recommend: yes — defer.**
- **Q5.** Commit client truth *numbers* (`truth.json`, `takeoff.json`) to this public
  repo, images staying gitignored — consistent with the committed-`notes.md` precedent?
  **Recommend: yes**, but it is Benton's client-confidentiality call.
