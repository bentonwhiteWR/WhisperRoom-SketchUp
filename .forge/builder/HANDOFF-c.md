# HANDOFF — Builder C

## Produced

- `scripts/build-room.rb` — modified. Every wall run and every door header now builds as
  two stacked solids split at a sill height instead of one. The upper solid goes on a new
  tag, `WR-Room-Upper`, alongside the existing `WR-Floor`, `WR-Room`, `WR-Doors`,
  `WR-Doors-Leaf`, `WR-Notes`. New helper `WR_BuildRoom.band` does the split generically —
  same code path for a plain wall span and a door header, no special-casing by kind. Sill
  height is `cfg['sill']`, defaulting to the new `DEFAULT_SILL = 48.0` (4'-0") constant
  near the top of the module. `wall_run` and `report` both took new parameters (`sill`,
  `upper_tag` / `sill`, `door_h`) to carry this through; every existing call site was
  updated to match.
- `scripts/build-room.html` — modified. Added a "Wall split (sill)" field to both the
  simple and detail panes, bound to a new `S.sill` (default 48, i.e. 4'-0"), sent in the
  build payload as `sill`. Same field-binding pattern already used for ceiling height.
- `scripts/wr-split-walls.rb` — new. One-time retrofit for models that already exist with
  one-piece walls (anything drawn before this change, including by
  `scripts/csusb-rooms.rb` or by hand). Title is `# @title Split existing walls at sill
  (EDITS MODEL)...` — loud on purpose, and it is the only script in this batch that
  actually edits existing geometry. Defaults to a dry run (`UI.inputbox`, same pattern as
  `scripts/merge-materials.rb`); the real run requires a second `UI.messagebox` YES/NO
  confirmation naming exactly how many solids it is about to touch, then does the whole
  edit inside one `model.start_operation`/`commit_operation` so a single Ctrl+Z reverses
  it. Full detection rule is in the file's own header comment; short version: a candidate
  must be a leaf `Sketchup::Group` (no nested group or component instance), untagged or
  tagged `WR-Room` (never `WR-Floor`/`WR-Doors`/`WR-Doors-Leaf`/`WR-Notes`/
  `WR-Room-Upper`), and its geometry must resolve to exactly one horizontal face at its
  lowest point and one at its highest point sharing the same outline in plan — i.e. a
  clean vertical extrusion, which is exactly what `build-room.rb`'s `quad()` produces.
  Anything that fails any of those checks is skipped and named in the console report by
  its group name and the specific reason, never guessed at. Already-split groups (tagged
  `WR-Room-Upper`) are recognized and left alone so the script is safe to run twice.
- `.forge/builder/HANDOFF-c.md` — this file.

## Read-first

- `CLAUDE.md` (repo root) — imperial units, 8'-0" default ceiling, walls built outward
  from the measured interior polygon and mitred at the corners, 4" default wall thickness.
- `reference/sketchup-drawing.md` — model standards, default materials, tag list, geometry
  rules (mitred corners, back-face handling, polygon winding), traps that have cost time.
- `scripts/build-room.rb` (as it stood before this change) — `quad(ents, poly, z0, z1)`
  already took a height range; `wall_run` already called it twice with two different
  ranges (`0.0..ceil` for a wall, `door_h..ceil` for a header). Confirmed by reading the
  file directly, not assumed.
- `scripts/proposal-scenes.rb` — the per-scene tag-visibility pattern this whole feature
  rests on: `DIM_TAGS`/`SHOWN_ON_DIMENSIONED`, `set_dims`, and each scene page being saved
  with `page.use_hidden_layers = true` so tag visibility travels with the scene. No code
  from it was reused directly (build-room.rb doesn't touch scenes), but its shape is why
  "put a wall on its own tag" was sufficient and no scene-side work was needed here.
- `scripts/merge-materials.rb` — the existing pattern for a script that edits the model:
  `UI.inputbox` for parameters, defaults to a dry run, one `start_operation`/
  `commit_operation`, a `begin/rescue Exception` wrapper around the top-level call. Copied
  this pattern into `wr-split-walls.rb` rather than inventing a new one.

## Assumptions

- **`DEFAULT_SILL = 48.0` (4'-0")**, in both `build-room.rb` and offered as the default in
  `wr-split-walls.rb`'s dialog. This is a guess, not a measured convention — Benton had not
  said whether the sill is fixed or varies per job. Picked 4'-0" because, against the
  80"-default door head, it lands the header-interaction on the "clean pass-through" side
  (see Open questions) — a lowered wall that also clears every doorway seemed like the more
  useful default for a "see into the room" render than a wall that still carries a header
  shard over each door. Exposed per-build as `cfg['sill']` from the dialog and changeable
  in one named place in the file, per the brief.
  reported: the 48" figure itself, and which behavior is "more useful," are my judgment
  calls, not something read off a prior drawing or told to me.
- The tag color for `WR-Room-Upper` (`[176, 182, 190]`, a lighter grey than `WR-Room`'s
  `[120, 128, 140]`) is cosmetic and arbitrary — picked only so the two tags are visually
  distinct in the Outliner. assumed.
- `wr-split-walls.rb`'s wall-recognition rule is intentionally scoped to groups matching
  what `build-room.rb`'s `quad()`/`wall_run` produces (a leaf group, one bottom face, one
  top face, same outline). A model built by `scripts/csusb-rooms.rb` or drawn by hand uses
  different geometry/grouping and will legitimately show every wall as "skipped" rather
  than being force-processed by a looser geometric guess (e.g., "any box-shaped leaf
  group"). This was a deliberate scope decision given the brief's explicit instruction
  that silently mangling a client drawing is the worst available outcome — a narrower,
  more certain rule was chosen over a broader, guessier one. Untested against an actual
  `csusb-rooms.rb` model or any real client file — reported, not observed.
- In `wr-split-walls.rb`, `Sketchup.parse_length` and `Sketchup.format_length` are used to
  parse/format the sill-height dialog field. I believe both are real SketchUp Ruby API
  methods (I have used the equivalent pattern conceptually before), but I could not run
  this file to confirm either resolves and behaves as expected at runtime — see Hard
  constraints below. The parse path has a `rescue StandardError` fallback to `to_f` if
  `parse_length` raises, but if `format_length` does not exist at all, `report`'s first
  line would raise `NoMethodError`, which the file's own top-level `begin/rescue Exception`
  wrapper would catch and surface as a `messagebox`, not something that could corrupt the
  model, but not silently ignored either — this is a real gap I could not close without
  running it. assumed.

## Open questions

- **The door-header interaction is real and reverses what the mission brief's wording
  suggests, as best I can tell from reading it literally.** Working through the actual
  geometry (both in `build-room.rb`'s `band` and in `wr-split-walls.rb`'s equivalent
  split): when the sill height is BELOW the door head height, the header
  (`door_h..ceil`) falls entirely at or above the sill line, so it builds as ONE solid,
  entirely on `WR-Room-Upper` — hiding that tag makes the whole header disappear and the
  doorway reads as a clean pass-through. When the sill is AT OR ABOVE the door head, the
  header straddles the sill and SPLITS: a shard from `door_h` to `sill` stays on the
  always-visible lower tag, so hiding `WR-Room-Upper` still leaves that shard hanging over
  the opening. The mission brief's prose describes it the other way round ("if the sill is
  above the door head, headers sit entirely in the upper band ... clean open
  pass-throughs; if the sill is below, headers get split too"). I could not reconcile that
  wording with the geometry under either plausible reading of "sill" and "upper band," so
  I implemented and documented the behavior the geometry actually produces (derived, shown
  above) rather than force a special case to match prose I could not make consistent.
  This needs Benton's eyes: either the brief's wording was reversed, or there is a
  reading of "sill" or "upper band" here that changes which case is which, and I could not
  settle it by inspection alone. It does not change the mechanism, only which of the two
  named behaviors goes with which sill/door-head relationship. Both cases work correctly
  and are handled by the same generic code path in both files — this is purely a labeling
  question for the write-up, and it is now stated precisely (in inches, not "above"/
  "below") in both files' headers and in `build-room.rb`'s `report()` console output, so
  the actual behavior at build time is never in doubt regardless of how the prose reads.
- **Whether the sill height should be fixed across jobs or vary per room** is still open —
  named in the brief as Benton's call, and I did not try to guess it. It is a dialog field
  with a named default, so changing the answer per job costs nothing.
- I did not verify whether a door leaf swung open (tagged `WR-Doors-Leaf`, height =
  `door_h`) could ever be misidentified as a wall/header candidate by
  `wr-split-walls.rb`'s geometry test. By construction it can't reach that test at all —
  its own explicit tag (`WR-Doors-Leaf`) is in `SKIP_TAGS` and excludes it before the
  geometry check runs — but this is derived from reading `build-room.rb`'s `door()` method,
  not observed by running the splitter against a real door leaf.

## On "this parses" vs "this works"

**There is no `ruby.exe` on this machine, and I did not run any of this.** Every claim
above about what the code produces is derived by hand-tracing the Ruby against the real
SketchUp API as documented and as used elsewhere in this repo — never observed running.
What I did verify directly:

- `python scripts/rbparse.py scripts/build-room.rb scripts/wr-split-walls.rb` — both
  report `ok`, meaning the real CRuby 3.2 parser SketchUp ships (via
  `x64-ucrt-ruby320.dll`) accepted both files as syntactically valid Ruby. Confirmed by
  running it myself, output: `2 file(s) parse.`
- Re-read `build-room.rb`'s existing call sites (`build()`, `report()`, the two callbacks
  in `open()`) after editing to confirm every changed method signature was updated at
  every caller — no orphaned old-arity calls left behind.
- Traced `wall_run`/`band`'s Z-range arithmetic by hand against the default parameters
  (ceil 96, door_h 80, sill 48) to confirm: a plain wall span produces one lower solid
  (0..48) and one upper solid (48..96) whose combined height matches the original single
  0..96 solid exactly; a door header (80..96) produces one solid entirely on
  `WR-Room-Upper` (80..96) with no lower-band remnant, since 80 >= 48. This is the
  "combined geometry unchanged, only the grouping changed" claim the brief required for
  the default-settings case — derived from the arithmetic, not observed running.
- Confirmed by reading (not running) that the XY footprint and the mitred-corner
  computation (`mitre`, `outer[]`) are computed once per wall run in `build()`/`wall_run`
  entirely before any Z-splitting happens, and that `poly` (the XY footprint passed into
  `band`) is identical for both bands of a given span — so the split cannot move a
  dimension or disturb a mitred corner. This matches what the mission brief asked me to
  verify rather than assume, and I did verify it by reading the code, not by building a
  model and measuring it.
- Confirmed by reading (not running) that no ceiling face is built anywhere in
  `build-room.rb` — `build()` only ever creates a floor group (`fg`), a walls group
  (`wg`), a doors group (`dg`), and an optional note. There is no third dimension
  (`quad`/`add_face`) call that would produce a horizontal ceiling face. Hiding
  `WR-Room-Upper` therefore has nothing floating over the room to worry about — this
  confirms the mission brief's second reading, and I checked it against the actual file
  rather than taking the brief's word for it.

I have not seen a model built with these scripts, in SketchUp, on screen, at any point.
"Parses cleanly" and "the arithmetic works out by hand" are the strongest claims I can
make; "this looks right when you actually build and render a room" is unverified and
should be treated as the first thing to check when someone with a SketchUp install picks
this up.

## Blockers

None. Both files are ready for review; neither has been run.
