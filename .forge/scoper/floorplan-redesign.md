# Draw floor plan — redesign around the plan itself

Scoper spec · 18 Sep 2026 · plugin at 1.71.1 → ships as **1.72.0**.
Mockup: `.forge/scoper/floorplan-redesign.mockup.html` (open in any browser; `?test=1` runs the
acceptance scenario). Nothing under `scripts/` was touched.

Provenance tags: **observed** = read in the code or screenshot; **derived** = follows from it;
**reported** = Benton said it; **assumed** = my call, listed in §7.

---

## 0. The real problem, in one sentence

The dialog makes the drafter address walls by index and doors by a table row, so the picture
and the numbers never touch; Benton wants to put the door on the wall he is looking at.

Reported verbatim: "I hate how the draw floor plan script works. It's not clear. The adding a
door isn't clear at all (let me click the wall for example)."

What is wrong today (observed, screenshot + `scripts/build-room.html`):

| Symptom | Where |
|---|---|
| Doors are a row `run # / from corner / width / near-far`; no link to the plan | `doorRows()` :396 |
| Run indices `0 1 2 3` are tiny grey glyphs on the wall, only in detail mode | `draw()` :289 |
| "from corner" — which corner is never said | :405 placeholder |
| Footer error "door 1 has no position — measure corner → near jamb" | :330 |
| Runs table (direction dropdown + length) has no hover/selection tie to the plan | `runRows()` :380 |
| "← Back to length & width (remove the door first)" disables itself with a reason nobody asked for | :319-324 |
| No door swing drawn; no north arrow; no door dimensions on the plan | `draw()` |

What is right today and is kept: simple rectangle first; one state feeding one build path;
chain-closure check with the red dashed gap; `parseLen` (12'6" / 150 / 12.5, bare = inches);
walls outward, 4" cosmetic; 8'-0" and 80" defaults labelled as not measured; a corner door is
refused.

## 1. Goal

Direct manipulation on the plan preview, contract to Ruby unchanged:

- hover a wall → it highlights and a ghost door follows the cursor;
- click the wall → a 36" door drops there and is selected;
- drag the door along its wall; arrow keys nudge 1" (Shift 12"); Delete removes;
- selecting a door shows its offset **corner → near jamb** (the corner named, and switchable to
  the other end of the wall), width, and hinge jamb — and the offset + width are drawn live on
  the plan as a secondary chain;
- click a wall's dimension → edit that wall's heading/length; insert or delete a wall from there;
- the runs list survives as a collapsed "Walls, as a list" for reading a take-off off a plan in
  order, with row hover ↔ wall highlight;
- one screen, no modes to back out of: Length/Width/Ceiling stay on top and go read-only
  (showing overall extents) once the polygon is not a rectangle.

## 2. Approach and the decisions behind it

**One screen instead of two modes.** Today `mode` selects which numbers the payload carries
(`simple` forces `Room`/`[]`/4/80). Ruby only uses `mode` for `remember_mode` → `WR_setMode` on
the next open (observed `build-room.rb:489-500, 518-528`). So the redesign *derives* `mode`:
`"detail"` when the walls are not a plain rectangle, or there is any door, or name/thick/door_h
differ from `Room`/4/80; else `"simple"`. `WR_setMode("detail")` now just opens the "More"
disclosure. Payload keys and their meaning are identical; Ruby needs no change for this.

**Click adds, dimension edits.** Two affordances on one wall have to be unambiguous: the wall
body is `cursor:copy` with a ghost door and a tooltip "click to add a 36" door here"; the orange
number is `cursor:text` with "click to change this wall". Hover states make each obvious before
the click. Rejected: a modal "Add door" tool button — an extra step Benton explicitly did not ask
for; and double-click to edit — undiscoverable in a dialog.

**Corner → near jamb, named.** The payload's `at` is always from the run's *start* corner
(observed `door()` :254, `door_errors` :337-341; convention `takeoff-format.md:159-170`). The
inspector shows the offset with a select "from W corner / from E corner" (derived from the run
heading: E starts at its W end, S at its N end, W at its E end, N at its S end). Choosing the
other end converts: `at = len − off − w`. UI-only; the payload never carries the anchor.

**Hinge as a jamb, not "near/far".** The select reads "W jamb / E jamb" (or N/S), mapped to
`near/far`. The leaf is drawn open 90° into the room with its arc, built the same way as
`build-room.rb` `door()` (pivot = hinge jamb, tip = pivot + inward × w, arc from the closed jamb
to the tip) so the preview cannot disagree with the model.

**Placed by eye is not measured — but it does not block.** The shipped dialog seeds a new door
with `at:null` and blocks Build until a number is typed, because an invented 36" once shipped as
a measurement (observed comment :476-481, the 31 Aug defect). Click-and-drag placement *is* an
invented position, so the door carries `placed:true` until the offset is typed; it shows a
"PLACED BY EYE" badge, the footer says "1 door placed by eye, not measured — type the offset to
confirm" in warning colour, and the payload carries `placed:true` on that door (additive key;
Ruby reads only `run/at/w/hinge`). Blocking would make dragging theatre. **Q2 asks Benton
whether warn is enough** — if not, flip `$go.disabled` to include `placed>0` (one line).

**Wall names by compass, run index kept.** "north wall · run 0". Derived from the inward
normal, so an L-shape gets "north wall (1) / north wall (2)". Ruby's messages still say `run 0`,
so the code tag stays visible. Corners: the offset dimension starts *at* the corner, so the
corner needs no label.

**Snap.** Drag and arrow keys move in whole inches, clamped to `[1", len − w − 1"]` so a dragged
door can never reach the corner Ruby refuses. Typing takes any precision `parseLen` accepts.

**Dimension styling** follows CLAUDE.md "Dimension the top-down properly": wall runs orange,
door chain (corner → near jamb, then width) thin grey *inside* the room so it never collides
with the wall chain; a legend bottom-left; a north arrow top-right.

## 3. The contract with Ruby (unchanged, plus one additive key)

Observed `build-room.rb`:

| Direction | Call | Shape |
|---|---|---|
| dialog → Ruby | `sketchup.ready()` | none (:518) |
| dialog → Ruby | `sketchup.build(json)` | `{mode, name, runs:[{d:"E|S|W|N", v:in}], doors:[{run:int, at:in, w:in, hinge:"near|far"}], thick:in, ceil:in, door_h:in}` (:352-361, :524) |
| dialog → Ruby | `sketchup.cancel()` | none (:534) |
| Ruby → dialog | `WR_setMode("simple"|"detail")` | after `ready` (:520) |

Change: each door **may** carry `placed:true`. `build()` and `door_errors` never read it
(observed :216-217, :330-346, :416-421), so geometry is byte-identical. Optional Step 6 prints it
in the console report. Nothing else moves. The N/S flip on output is preserved as-is behind a
constant (`FLIP_NS=true`) pending **Q1**.

Hidden dependency (observed `scripts/takeoff-vectors.html:33`): it regex-extracts
`function parseLen(s){` … `\n  }` from `build-room.html`. The mockup keeps that function
verbatim at two-space indent; the Builder must too.

## 4. Steps, in order — each independently checkable

Files the Builder opens: `scripts/build-room.html`, `scripts/build-room.rb`,
`scripts/wr_tools/VERSION`, `scripts/takeoff-vectors.html` (read only), `DEVLOG.md`.

1. **Replace `scripts/build-room.html` with the mockup, minus MOCKUP-ONLY blocks.**
   Remove: the `window.sketchup` stub, the `#payload` div and its CSS, the `?test=1` block and
   `#testout`. Keep everything else, including the `FLIP_NS` constant and comment.
   *Check:* file has no string `MOCKUP-ONLY`; `grep -c "function parseLen(s){" scripts/build-room.html` = 1.

2. **Confirm the grammar-parity harness still finds `parseLen`.**
   `cd scripts && python -m http.server 8000` then open `takeoff-vectors.html`: all vectors PASS.
   Also `python scripts/takeoff-check.py - -selftest` (the Python half) passes.

3. **`build-room.rb` header comment** (:6-21) describes two modes and "Back to length & width".
   Rewrite that paragraph to describe: one screen, click-to-add, `mode` derived, `placed` key.
   No code change in `build`, `door`, `door_errors`, `polygon`, `mitre`.
   *Check:* `git diff scripts/build-room.rb` touches only comment lines and (Step 6) `report`.

4. **Dialog size.** `open` (:508-514) is 860×640, min 520×420. The side panel is 330px; at
   min width the grid collapses to one column (CSS `@media (min-width:720px)`), which is fine.
   Leave as is unless Step 8 shows the inspector clipped; then raise `:min_height` to 480.

5. **VERSION → `1.72.0`**, and a DEVLOG entry (newest on top) naming: the redesign, the
   `placed` key, the `FLIP_NS` constant and Q1's status, and that it was parsed and
   browser-tested but not run live unless Benton did (see Step 8).

6. **(Optional, 3 lines) `report()`** (:469-485): after the counts line, for each door with
   `d['placed']`, `puts "  door #{j+1} on run #{d['run']}: PLACED BY EYE, not measured"`.
   Requires threading `doors` (already a parameter as `ndoors`; pass the array instead).
   This is console text, not geometry — inside the GOAL's "out of scope" only if Benton says so.

7. **Parse.** `python scripts/rbparse.py` — every `.rb` clean. `rbcheck.py` is not evidence.
   Also `python scripts/rbtest-takeoff.py` and `python scripts/rbtest-doorswing.py` still pass
   (they lift `door_errors` / `door` verbatim; a comment-only diff must not break the lift).

8. **Live check (Benton or the bridge, in an Untitled model).** Draw floor plan → 12'-0" ×
   5'-6" → click the north wall near 3' → drag to 4'-0" → width 36 → Build. Expect: 4 walls,
   1 opening + header, leaf open into the room, auto-dimension chains, console shows the door
   line from Step 6 if built. **Then look where the door is: north or south wall (Q1).**

9. Commit, push, `install-plugin.py`, restart SketchUp (the HTML is read from the repo
   checkout on a CANDIDATES machine, but `VERSION` needs the installer).

## 5. Acceptance criteria — runnable

Browser (mockup now, `build-room.html` after Step 1 with the stub temporarily restored, or in
SketchUp with the Ruby console open):

- [ ] AC-1 `mockup.html?test=1` prints six `PASS` lines and the payload
  `{"mode":"detail","name":"Room","runs":[{"d":"E","v":144},{"d":"N","v":66},{"d":"W","v":144},{"d":"S","v":66}],"doors":[{"run":0,"at":48,"w":36,"hinge":"near","placed":true}],"thick":4,"ceil":96,"door_h":80}`
  (observed 18 Sep, headless Chrome 1280×800). With `FLIP_NS=false` runs read `E,S,W,N`.
- [ ] AC-2 Hover any wall: highlight + ghost door + tooltip. Move off: both clear.
- [ ] AC-3 Click a wall: a door appears centred on the click (clamped ≥1" from either corner),
  the inspector opens on it, the door list gains a row with "BY EYE".
- [ ] AC-4 Drag it: offset changes in whole inches; the grey chain on the plan and the inspector
  field follow; it stops 1" short of the corner; releasing keeps it selected (no deselect).
- [ ] AC-5 Type `3'0` in the offset: badge flips to "TYPED", footer hint goes neutral, the
  plan chain reads 3'-0". Switch "from E corner": field shows `len − at − w`; payload `at` is
  unchanged.
- [ ] AC-6 Hinge "E jamb": leaf pivots on the east jamb, arc sweeps from the west jamb; payload
  `hinge:"far"`.
- [ ] AC-7 Click the 12'-0" dimension: wall inspector opens with the length field focused and
  selected; typing `14'` redraws; the door on that wall keeps its `at`.
- [ ] AC-8 "+ wall after this one" breaks closure: chip goes red "DOES NOT CLOSE", red dashed
  gap drawn, Build disabled, footer "fix the closure to build". Fix the lengths: chip green.
- [ ] AC-9 Non-rectangle: Length/Width go read-only showing overall extents with the note;
  making it a rectangle again re-enables them.
- [ ] AC-10 Delete key with a door selected removes it; Escape deselects; keys typed inside
  an input never trigger either.
- [ ] AC-11 Width `0` or unreadable text: red field, Build disabled, footer says so.
- [ ] AC-12 Dark mode (`prefers-color-scheme: dark`): every colour comes from a variable; no
  hard-coded white.
- [ ] AC-13 `WR_setMode("detail")` opens the "More" disclosure; `"simple"` closes it.

Repo:

- [ ] AC-14 `python scripts/rbparse.py` clean; `rbtest-takeoff.py`, `rbtest-doorswing.py` pass.
- [ ] AC-15 `scripts/wr_tools/VERSION` reads `1.72.0`; DEVLOG has the entry.
- [ ] AC-16 `takeoff-vectors.html` parity page: 0 FAIL.
- [ ] AC-17 No file under `scripts/` contains `MOCKUP-ONLY`.

## 6. Risks and out of scope

- **Q1 mirror (highest risk, observed in code, unverified live).** Fixing it changes where
  doors build for every asymmetric room drawn with this dialog. Ship with `FLIP_NS=true` unless
  Benton confirms via Step 8. If the door lands on the south wall when the preview showed
  north, set `FLIP_NS=false` in a follow-up (1.72.1) — one constant.
- **Pointer capture in CEF.** SketchUp's HtmlDialog is Chromium; `setPointerCapture` and
  `getScreenCTM` are standard there. If drag misbehaves live, fall back to `mousedown/mousemove/
  mouseup` on `document` — same handlers, different event names.
- **Redrawing the inspector each keystroke.** Handled by restoring value/caret/red state
  (mockup `renderInspector`). If the Builder restructures, keep that guard or bind fields to
  state without innerHTML.
- **Long rooms.** `viewBox` fits the polygon; text size scales with width. A 60' × 8' corridor
  gives small vertical labels — same as today, not worse.
- Out of scope: Ruby geometry; the take-off pipeline (`build-takeoff.rb` has its own path);
  multi-room; windows; curved walls; undo inside the dialog (Cancel is the undo).

## 7. Open questions for Benton (and what I assumed meanwhile)

- **Q1 — Is the room mirrored today?** Build any room with one door from this dialog and say
  which wall it landed on versus the preview. *Assumed:* keep today's flip until told.
- **Q2 — A door dropped by click: warn, or block Build until the offset is typed?**
  *Assumed:* warn (badge + footer + `placed:true` in the payload), because blocking makes drag
  pointless and the take-off file is where a recorded assumption belongs.
- **Q3 — Default dropped width 36"?** *Assumed:* 36", the commercial door in CLAUDE.md.
- **Q4 — Keep the "Walls, as a list" disclosure?** *Assumed:* yes, collapsed; reading runs off
  a plan is a list task. Drop it if it is never opened.
- **Q5 — Should the console report name eyeballed doors (Step 6)?** *Assumed:* yes, it is the
  "everything not measured" list `sketchup-drawing.md` asks for; it is 3 lines outside geometry.
- **Q6 — Compass names ("north wall") or run numbers first?** *Assumed:* compass first, `run 0`
  in small type beside it.
