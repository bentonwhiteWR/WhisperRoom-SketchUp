# The take-off file — `takeoff.json`

Normative schema for the floor-plan intake format. One file per job, living
in `clients/<job>/takeoff.json`, recording every dimension **as stated on the
plan, with its arithmetic and its source**. Validated by
`python scripts/takeoff-check.py <file>` (exit 0 writes `takeoff.lock.json`
next to it; `--html` also writes the one-page review sheet); built by
`scripts/build-takeoff.rb`, which consumes **only the lock file**. Worked
example: `clients/uic-daley-library/takeoff.json` — the real 31 Aug 2026 job,
which exercises every feature below.

Three rules generate everything else, each mapped to a confirmed failure:

1. **Chains carry their arithmetic.** On the 31 Aug job the pen chain
   `10" + 17'3" + 10" = 18'11"` closed exactly and nothing checked it;
   reading 17'3" as the room width was ~8 ft wrong. A run may carry `parts`,
   and the checker requires them to sum to `v` exactly.
2. **Never invent a placement number.** Every dimension is a `{v, src}`
   pair. A missing value fails by name. A value nobody measured is legal
   only as an explicit `{"assumed": ..., "reason": ...}` — and it is flagged
   on the review sheet, in the build report, and as a text note in the model
   at the feature itself.
3. **The walk has one direction and one starting corner.** Runs are a
   **clockwise** walk of the interior starting at the **northwest-most
   corner**, so run 0 always heads `E` along the northernmost wall. Nothing
   downstream recovers this: `build-takeoff.rb` reads its mitre sense from the
   signed area and builds either winding without complaint, so a
   counter-clockwise run list closes, validates and produces a clean plausible
   room — and a counter-clockwise list is exactly what a **mirrored** read of
   the plan produces, because swapping east for west reverses the walk. The
   checker refuses an undeclared counter-clockwise walk, and a clockwise walk
   that starts at the wrong corner, both by name.

## Values

Every dimension is an object, one of:

```jsonc
{"v": "12'6\"", "src": "pen IMG_7594"}                  // measured/stated
{"v": "18'11\"", "parts": ["10\"", "17'3\"", "10\""],    // chain with its
 "src": "pen IMG_7594", "note": "17'3\" is between the heaters"}  // arithmetic
{"assumed": "6\"", "reason": "no position on plan; ..."} // recorded guess
{"assumed": "17'8\"", "parts": ["15\"", "15'2\"", "15\""],   // an assumption
 "reason": "no wall-to-wall total anywhere on the plan; this is the pen clear
            width plus the two heater depths"}                // with its arithmetic
{"v": "96\"", "src": "default", "note": "8'-0\" house default, not measured"}
{"v": "12'6\"", "src": "derived closure",                     // forced by the
 "note": "unlabelled on the plan; forced by run 0"}           // other runs
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
  `derived` (arithmetic on other numbers on this plan — requires a note or
  reason naming what it came from), `assumed` (requires `reason`), `default`
  (requires a note naming the default). `assumed`, `default` and `derived`
  all flag; `pen`, `plan-vector` and `stated` are measurements with a named
  source and do not.
- `parts` must sum to the value **exactly** (float dust only) — a mismatch is
  a transcription error, not noise, and fails by name. `parts` may hang off an
  `{"assumed": ...}` value as well as a `{v, src}` one: an assumption reached
  by honest chain arithmetic is a *checkable* assumption, and burying the
  arithmetic in the reason string puts it where nothing can verify it.

### `derived` — the closure-forced value

An unlabelled wall whose length is whatever makes the polygon close is
**not a measurement**. Closure gives it that value by construction, so the
closure check confirms nothing about it. Record it as
`"src": "derived closure"` with a note naming the runs that force it. It
flags, so it reaches the review sheet and the model as DERIVED and gets a
tape put on it like any other unconfirmed number.

Two `derived closure` runs on the same axis fail by name: closure forces
exactly one unknown per axis, and with two, any pair summing to the same
total closes and neither is determined.

### Enums

`hinge` is `"near"` or `"far"`. It obeys the never-invent rule like every
other value: a missing or unknown hinge **fails by name** — it does not
quietly become `near`. Three legal forms:

```jsonc
"hinge": "near"                                    // stated, read off the plan
"hinge": {"v": "far", "src": "pen IMG_7595"}       // stated, source named
"hinge": {"assumed": "near", "reason": "no leaf drawn"}   // recorded guess
```

Recorded non-numeric guesses (an assumed hinge, a declared winding) land in
the lock's `flag_inventory` rather than `assumed_inventory`, because the
builder formats every entry of the latter as a length for its in-model note.
They print on the console report and the review sheet; **they do not yet get
an in-model note** — that is a `build-takeoff.rb` change and is not done.

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
                                            // to 0.02" or nothing builds.
                                            // CLOCKWISE from the NW-most
                                            // corner — run 0 heads E.
  "winding": {"order": "ccw",     // optional; ONLY to declare a deliberate
              "reason": "..."},   // departure from the convention, and the
                                  // reason is required
  "ceiling": <value>,             // MANDATORY. May be assumed-with-reason.
  "doors": [ {
      "run": 2,                   // index into runs
      "at": <value>,              // distance from the corner where THIS RUN
                                  // STARTS, measured along the run's own
                                  // travel direction, to the near jamb.
                                  // MANDATORY: measured or assumed-with-
                                  // reason; absent fails by name. May not
                                  // touch a corner (< 0.02" clearance) —
                                  // that refusal replaces the old silent
                                  // leaf-in-solid-wall defect.
      "w": <value>,               // opening width
      "h": <value>,               // optional; omitted = 80" flagged DEFAULT
      "hinge": "near" | "far"     // MANDATORY; or {"assumed", "reason"}
  } ],
  "features": [                   // flagged massing on WR-Obstruction —
                                  // footprint honesty, not furniture
    {"type": "heater",  "run": 1, "from": <v>, "length": <v>, "depth": <v>},
    {"type": "bulkhead","run": 0, "from": <v>, "length": <v>,  // thickness
         "head": <v>},            // underside height; builds head..ceiling
    {"type": "window",  "run": 0, "from": <v>, "width": <v>,
         "sill": <v>}             // REQUIRED: height off the floor
  ],
  "origin": [x, y],               // optional true offset, inches; omitted =
                                  // rooms placed side by side with a 48" gap
  "thick": <value>,               // optional; house default 4"
  "notes": ["..."]                // free text, echoed on the review sheet
}
```

### Winding, the start corner, and what `at` is measured from

These three are one rule, because `at` has no meaning without the other two.

- **Run 0 starts at the northwest-most corner** — the vertex that is furthest
  north, and among those, furthest west — and the walk goes **clockwise**, so
  run 0 heads `E` along the northernmost wall. The checker refuses any other
  start corner by name.
- **`at` is measured from the corner where its run starts**, along that run's
  own travel direction. A run heading `E` is dimensioned from its **west**
  end; heading `S`, from its **north** end; heading `W`, from its **east**
  end; heading `N`, from its **south** end. This is what `build-takeoff.rb`
  has always done — it offsets from `pts[i]` toward `pts[i+1]` — and the
  checker now prints the corner in words for every door, so a reader can
  check the transcription against the pen chain without deriving it.
- Benton's own convention (`CLAUDE.md`) is *corner → near jamb*. This says
  **which** corner.

**Declaring the other winding.** A plan whose pen chains all run the other way
may be transcribed counter-clockwise — but it must say so, with a reason, per
room:

```jsonc
"winding": {"order": "ccw", "reason": "the only measured door position is a
            vertical pen chain running north corner -> near jamb down the west
            wall; a clockwise walk would force that pen number to be restated
            as a subtraction"}
```

That is the real UIC 3190J, and it is the worked example. The escape exists
for the same reason `assumed` does: the judgment call is legitimate, making it
silently is not. A counter-clockwise walk with no declaration, a bare
`"ccw"` with no reason, and a declaration that contradicts the geometry all
fail by name. Declaring `ccw` moves the required start corner to the
northeast-most vertex, so run 0 heads `W`.

Massing conventions (representation constants, not measurements — they are
not flagged): heater massing is 24" tall; the ceiling slab is 4" thick;
windows build 1" deep from sill to ceiling.

**There is no room-level `sill`, and one in a file fails by name.** It used to
be the height walls were SPLIT at for the two-band construction; walls have
built as one solid floor-to-ceiling since 1.12.8 and nothing reads it. A
window's `sill` — how high it sits off the floor — is a different number that
happened to share the name, it lives on the window feature, and it is
**required**: measured, or assumed with a reason. It was optional until
1.12.9, and a window without one got invented twice over, differently — the
review sheet drew it at the room's retired 48" band sill while
`build-takeoff.rb` built it from the floor at 0". One missing number, two
silent placements that disagreed with each other.

Reserved, explicitly not in v1: curved/angled walls (runs are rectilinear
E/S/W/N, matching `WR_BuildRoom::DIR`), multi-floor, wall openings other
than doors and windows.

## The pipeline

```
photos / PDF                       agent (or Gabe) transcribes — minutes
   -> clients/<job>/takeoff.json
python scripts/takeoff-check.py clients/<job>/takeoff.json --html
   -> fails BY NAME (open chain, parts mismatch, missing door position,
      missing ceiling, corner door, missing src, undeclared counter-clockwise
      walk, wrong start corner, missing hinge...), or writes
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

`field` is one of `runs[i]`, `ceiling`, `thick`, `doors[j].at/.w/.h`,
`features[j].from/.length/.width/.depth/.head/.sill`. Apply it with

```
python scripts/takeoff-check.py clients/<job>/takeoff.json --apply-patch patch.json
```

which refuses by name any edit whose `old` no longer matches the file (stale
patch — matching is at the sheet's own display precision, a tenth of an inch,
because `old` is the displayed string; a stored `38 1/4"` shown as `3'-2.3"`
still matches, while a real change of even a sixteenth refuses) or whose
`new` has no source, rewrites `takeoff.json` only when every
edit applies cleanly, and re-runs the full check — so a patched value passes
the same closure/corner/src invariants as a hand-typed one. Editing a run
replaces its value and drops any old `parts` chain (the number changed; a
stale chain would contradict it) — restate the chain in the take-off if the
new value has one.
