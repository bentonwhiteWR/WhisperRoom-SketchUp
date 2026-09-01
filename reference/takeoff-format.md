# The take-off file — `takeoff.json`

Normative schema for the floor-plan intake format. One file per job, living
in `clients/<job>/takeoff.json`, recording every dimension **as stated on the
plan, with its arithmetic and its source**. Validated by
`python scripts/takeoff-check.py <file>` (exit 0 writes `takeoff.lock.json`
next to it; `--html` also writes the one-page review sheet); built by
`scripts/build-takeoff.rb`, which consumes **only the lock file**. Worked
example: `clients/uic-daley-library/takeoff.json` — the real 31 Aug 2026 job,
which exercises every feature below.

Two rules generate everything else, each mapped to a confirmed failure:

1. **Chains carry their arithmetic.** On the 31 Aug job the pen chain
   `10" + 17'3" + 10" = 18'11"` closed exactly and nothing checked it;
   reading 17'3" as the room width was ~8 ft wrong. A run may carry `parts`,
   and the checker requires them to sum to `v` exactly.
2. **Never invent a placement number.** Every dimension is a `{v, src}`
   pair. A missing value fails by name. A value nobody measured is legal
   only as an explicit `{"assumed": ..., "reason": ...}` — and it is flagged
   on the review sheet, in the build report, and as a text note in the model
   at the feature itself.

## Values

Every dimension is an object, one of:

```jsonc
{"v": "12'6\"", "src": "pen IMG_7594"}                  // measured/stated
{"v": "18'11\"", "parts": ["10\"", "17'3\"", "10\""],    // chain with its
 "src": "pen IMG_7594", "note": "17'3\" is between the heaters"}  // arithmetic
{"assumed": "6\"", "reason": "no position on plan; ..."} // recorded guess
{"v": "96\"", "src": "default", "note": "8'-0\" house default, not measured"}
```

- `v` / `assumed` / `parts[]` entries use the dialog grammar (`parseLen`,
  `scripts/build-room.html`): `150`, `150"`, `12'6"`, `12'-6"`,
  `12' 6 1/2"`, `12.5'` — **a bare number is inches**. The Python port in
  `takeoff-check.py` is held identical by `scripts/takeoff-vectors.json`
  (`--selftest`; JS side: `scripts/takeoff-vectors.html`, or the cscript
  parity run — 25 shared vectors).
- `src` is mandatory. Its first word is closed vocabulary:
  `pen` (hand-written field measurement — name the image),
  `plan-vector` (from PDF/DWG geometry — name the anchor),
  `stated` (client email/text/other statement — name it),
  `assumed` (requires `reason`), `default` (requires a note naming the
  default). Only `assumed`/`default` flag; everything else is a measurement
  with a named source.
- `parts` must sum to `v` **exactly** (float dust only) — a mismatch is a
  transcription error, not noise, and fails by name.

## File shape

```jsonc
{
  "job": "uic-daley-library",              // = the clients/<job>/ folder
  "title": "...",                           // optional
  "sources": ["plans/IMG_7594.jpeg", ...],  // the inputs, by filename
  "anchor": "pen 18'11\" G+H interior width",
  "interpretations": ["..."],               // every judgment call, recorded
  "rooms": [ <room>, ... ]
}
```

## Rooms

```jsonc
{
  "name": "3190G+H",              // unique — it names the model group
  "runs": [ {"d": "E", ...value}, ... ],   // d in E/S/W/N, model coords
                                            // (N = +y); polygon must CLOSE
                                            // to 0.02" or nothing builds
  "ceiling": <value>,             // MANDATORY. May be assumed-with-reason.
  "doors": [ {
      "run": 2,                   // index into runs
      "at": <value>,              // corner -> near jamb. MANDATORY: measured
                                  // or assumed-with-reason; absent fails by
                                  // name. May not touch a corner (< 0.02"
                                  // clearance) — that refusal replaces the
                                  // old silent leaf-in-solid-wall defect.
      "w": <value>,               // opening width
      "h": <value>,               // optional; omitted = 80" flagged DEFAULT
      "hinge": "near" | "far"
  } ],
  "features": [                   // flagged massing on WR-Obstruction —
                                  // footprint honesty, not furniture
    {"type": "heater",  "run": 1, "from": <v>, "length": <v>, "depth": <v>},
    {"type": "bulkhead","run": 0, "from": <v>, "length": <v>,  // thickness
         "head": <v>},            // underside height; builds head..ceiling
    {"type": "window",  "run": 0, "from": <v>, "width": <v>, "sill": <v>}
  ],
  "origin": [x, y],               // optional true offset, inches; omitted =
                                  // rooms placed side by side with a 48" gap
  "thick": <value>, "sill": <value>,   // optional; house defaults 4" / 48"
  "notes": ["..."]                // free text, echoed on the review sheet
}
```

Massing conventions (representation constants, not measurements — they are
not flagged): heater massing is 24" tall; the ceiling slab is 4" thick;
windows build 1" deep from sill to ceiling.

Reserved, explicitly not in v1: curved/angled walls (runs are rectilinear
E/S/W/N, matching `WR_BuildRoom::DIR`), multi-floor, wall openings other
than doors and windows.

## The pipeline

```
photos / PDF                       agent (or Gabe) transcribes — minutes
   -> clients/<job>/takeoff.json
python scripts/takeoff-check.py clients/<job>/takeoff.json --html
   -> fails BY NAME (open chain, parts mismatch, missing door position,
      missing ceiling, corner door, missing src...), or writes
      takeoff.lock.json + takeoff.review.html
Gabe reads the review sheet — 2-3 min, answers the ASSUMED flags
SketchUp: load scripts/build-takeoff.rb, pick the lock file
   -> every room, dimensioned, every ASSUMED value noted IN THE MODEL
```

Scoring loop: `python scripts/eval-floorplan.py <case>` against
`eval/floorplans/<case>/truth.json`, ledger in `eval/RESULTS.md`.

## The review sheet, and the patch it emits

`--html` writes `takeoff.review.html` next to the file: source photo beside
the interpretation (a pen-callout → value ledger per room), the to-scale
plan, a rotatable 3D view built **from the lock** (drag to rotate, scroll to
zoom, arrows step, R resets — ASSUMED values draw in the warn colour there
too), and per-room APPROVE / NEEDS CHANGES.

- `--embed-photos` inlines the job's photos as downsampled data URIs
  (1600 px long edge). Off by default: publishing the sheet sends the image
  to claude.ai, which is a per-client decision. Either way the sheet file is
  gitignored (`*.review.html`) — **client images are never committed**.
- Every stated value on the sheet is editable, and an edit **requires** its
  source (`pen`/`stated`/`plan-vector`, or `assumed` + reason) — an edit
  with no source is the dialog's invented `at:36"` again and the page
  refuses to record it.

The copy box emits a structured patch, never prose:

```jsonc
{
  "patch": 1,
  "job": "uic-daley-library",
  "review": {"3190G+H": "approved", "3190J": "needs-changes"},
  "edits": [
    {"room": "3190J", "field": "ceiling", "old": "8'-9\"",
     "new": {"v": "8'10\"", "src": "stated Gabe tape 1 Sep"}}
  ]
}
```

`field` is one of `runs[i]`, `ceiling`, `thick`, `sill`, `doors[j].at/.w/.h`,
`features[j].from/.length/.width/.depth/.head/.sill`. Apply it with

```
python scripts/takeoff-check.py clients/<job>/takeoff.json --apply-patch patch.json
```

which refuses by name any edit whose `old` no longer matches the file (stale
patch) or whose `new` has no source, rewrites `takeoff.json` only when every
edit applies cleanly, and re-runs the full check — so a patched value passes
the same closure/corner/src invariants as a hand-typed one. Editing a run
replaces its value and drops any old `parts` chain (the number changed; a
stale chain would contradict it) — restate the chain in the take-off if the
new value has one.
