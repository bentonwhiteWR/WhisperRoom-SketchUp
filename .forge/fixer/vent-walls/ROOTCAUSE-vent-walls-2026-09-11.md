# ROOT CAUSE — the ventilation plate on Benton's MDL 96144 E (11 Sep 2026)

Two defects on the same plate, reported ten minutes apart, one fixture for both.

## 1. "I had a backshot, and it didnt hide the wall that was right behind it"

**Reproduction (observed, from the screenshot).** `benton-ventilation-wall-not-hidden.png`:
the `05-ventilation` viewport is filled by a pale-blue room wall (build-room.rb's
`0099_LightSteelBlue`), the booth is not visible, the WALLS column reads `all shown` on
every row of a 10-scene set, and the interior plate's log line says walls: none hidden.
The model is Untitled; an earlier dimension run on it printed `*** left side blocked by
"Room"`, so a top-level container named `Room` (build-room.rb's default name) stands
next to the booth.

**Not reproducible offline** — there is no Ruby VM with SketchUp's `Sketchup::Group#bounds`
here — so the reproduction is by reading the code path against the two facts the screenshot
gives (a build-room room, ten plates, zero hidden), and by a fixture that puts the same
shape in front of the live harness.

**Root cause (derived from code; the room-transform half is a hypothesis about his model,
tagged assumed).** `WR_AutoSet.wall_geometry` handed the camera cone a wall centre computed
from the wall pieces' own `#bounds`, and a nested group's `#bounds` is in its **parent's**
space, not the model's. The cone compares that centre against a booth centre and a camera
eye that are in model space. Whenever the `Room` group (or its `Walls` container) carries
a non-identity transformation — a room dragged into place with the Move tool, which is
how a room ends up around a booth — every wall's centre is reported where the room was
built, not where it stands, and no wall lands in the cone on any plate. The fixture room
in `verify-autoset.rb` sits at the origin with an identity transformation, the single
configuration where parent space and model space agree, which is why
`walls.ventilation_hides_at_least_one` passed live on 11 Sep while his plate looked into
a wall. `wr-scene-walls.rb#side_of` carries a comment recording the identical trap,
observed live on 31 Aug 2026, fixed there and nowhere else.

**Why this is the cause and not the recogniser.** `PIECE_RE` matches `Wall N` groups up to
two containers deep under a top-level group; build-room.rb's `Room > Walls > Wall N` is
one deep. If his room had not been recognised, the plate log would have said
`walls: none in the camera cone` on every plate exactly as the screenshot implies — the
two failure modes were indistinguishable in the tool's own output, which is the second
half of this defect: a run that found **no wall units at all** reported "all shown" as if
it were a clean result.

**What I could not determine.** Whether his `Room` actually carries a transformation, or
whether the walls are named at all. Either produces the screenshot. The one-line console
command in the handoff prints both in ten seconds. The fix covers both: the transform is
carried out (the bug if it is moved), and the empty case is now said out loud in the log
and the summary message (the diagnosis if it is not).

## 2. "the ventilation scene also doesnt really go 'back'"

**Reproduction (observed: his build log; derived: the code path).** His build log for
this booth reads `Ventilation  Right (E0), Back (N0), Back (N1), Back (N2)` — one vent on
the right wall, three on the back, the right one placed first.

**Root cause (derived).** The vent bearing came from `tag_anchor(booth, 'WR-Booth-Vent')`,
a method written for the **door**: it runs `frame_hits`, which keeps ONE tagged part — a
part whose name says FRAME, else the part closest to the shell plane by a score of
`1 - |n - 1|`. Every vent panel sits in the shell plane and scores the same, and the loop
keeps the first best (`score > best_n`, strict), so the first part walked wins. E0 is
walked first. The plate therefore read the +X wall's normal and shot the side with one
vent; the fixed `:swing => 25.0` was then applied with a sign that has always been
positive, so which physical way the camera leaned depended on how the booth sat in the
model — the same mistake the side plate had before 1.57.0.

## The fix (both, one commit)

- `scripts/wr-scene-walls.rb` — `each_piece` threads the room-to-model transformation
  down through containers and yields it; `model_centre` carries each wall solid's eight
  corners out through it; every wall unit now carries `:centre` in MODEL space (the wall
  bands only — the swung leaf is `:extra` and would drag the centre into the room).
- `scripts/wr-autoset.rb` — `wall_geometry` uses `:centre` (falling back to the old read
  only if it is nil); `walls_line` + `top_level_names` print, once per run, either the
  wall units the cone can hide or, when there are none, that NO plate can hide a wall,
  what the rule looks for, and what it saw at the top level; `plate_log` says "NO wall
  units" instead of "none in the camera cone" when the list is empty; the Apply summary
  carries a WARNING for the empty case. Vent: `VENT_PLATE`, `vent_rank`, `wall_word`,
  `pick_vent`, `vent_line` (pure) and `vent_parts`, `local_bearing`, `vent_choice` (live);
  `az_for` and `aim_plate` take `vshift`, honoured on the vent plate only; `apply` decides
  once per run and prints the choice under the vent plate; `autoset_payload` reports the
  wall apply will shoot.
- The rule: most vent parts anchors; the swing's SIGN turns toward the wall with the
  next-most vents; every vent on one wall keeps +swing exactly as before; the other vents
  on the opposite wall keep the primary and say so; ties rank opposite-the-door, side,
  door wall, then +Y, -Y, +X, -X. The magnitude is the plate's existing `:swing` (25).
- The cone is untouched: at 25 degrees off the primary wall's normal the wall behind it
  is at dot 0.91 (> 0.5, hidden) and the wall behind the secondary vents at dot 0.42
  (shown). `wp10`/`wp11` pin that with the real eye either hand.

## Verification

- `python scripts/rbparse.py` — 75 scripts + `verify-autoset.rb` parse (real CRuby 3.2).
- `python scripts/rbtest-autoset.py` — 217 -> 243, green. New: `vt1-vt21`, `wl1-wl3`,
  `wp10-wp11`. Five mutants run and each fails by name (see the suite's docstring).
- `.forge/builder/verify-autoset.rb` section 15 — UNRUN (no SketchUp here). `roomx.*`
  and `vent.*`, listed in the handoff.

Everything in `.rb` is unrun until Benton loads it.
