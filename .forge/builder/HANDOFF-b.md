# HANDOFF — Builder B — wr-sun-aim.rb

## Produced

`scripts/wr-sun-aim.rb` — one script, one button ("Light It From Here"). Panel
picks it up via `# @title Light It From Here...` / `# @cat Render prep` (new
category — no existing script used it).

Non-modal `UI::HtmlDialog` with an offset slider (default +30 deg, range
-90..90) and a time-of-day slider (default 10:00, range 6:00-18:00, seeded
from the model's current `ShadowTime` hour if readable). Pressing "Light it
from here" reads `view.camera.direction`, derives the camera's azimuth,
computes a target sun azimuth, calibrates the live relationship between
`NorthAngle` and the sun's world azimuth (see below), solves for the
`NorthAngle` that hits the target, writes it plus the chosen time of day into
`model.shadow_info`, reads `SunDirection` back, and reports camera azimuth,
target azimuth, `NorthAngle` before/after, achieved azimuth and its error,
elevation, and the time that was set — in the dialog and echoed to the Ruby
Console. The dialog stays open so the operator can re-orbit and press again.
Wrapped in one `model.start_operation` / `commit_operation` pair, so Ctrl+Z
undoes the whole thing in one step. Touches only `model.shadow_info` — no
geometry, no scene cameras, no tags, no materials, no V-Ray API.

Everything is inline in the one file (`set_html`, no companion file), matching
`scripts/list-scenes.rb`'s pattern.

## Read-first

- `CLAUDE.md` (repo root) — Benton's drawing/tooling conventions.
- `reference/sketchup-drawing.md` — model standards, "no ruby.exe" constraint.
- `scripts/reorient-model.rb` — read in full; it is the closest relative and
  documents the exact habit ("rotate the model to fix lighting") this script
  exists to replace, plus the NorthAngle-rotates-with-geometry precedent this
  script's calibration approach follows in spirit (though reorient-model.rb
  assumes an additive NorthAngle relationship without measuring it — this
  script measures it instead, live in the model, rather than trusting that
  assumption a second time).
- `scripts/wr_tools/main.rb` — `@title` / `@cat` header format, `SCRIPTS_DIR`
  resolution, why the panel rescans instead of needing a restart.
- `scripts/wr-shading.rb` and `scripts/angled-component-art.rb` — read for
  style (module structure, "apply then read back, never trust a silent
  write" pattern, which `WR_SunAim.calibrate` and `light_it_from_here` both
  follow for `NorthAngle` and `ShadowTime`).
- `scripts/list-scenes.rb` — the `UI::HtmlDialog` + `set_html` + action
  callback + `execute_script("WR.xxx(...)")` pattern this script's UI copies
  almost exactly, including the CSS token set (`--accent:#ee6216` etc.).

## Assumptions

Tagged in four words per `.forge/ROLE-builder.md`; the load-bearing ones are
also written into the script's own header comment so they travel with the
code, not just this note.

- **derived, hedged in-header** — "light it from here" places the sun roughly
  *where the camera is standing* (dead-behind-camera baseline, then offset),
  not where the camera is looking. This is `SUN_BEHIND_CAMERA = true`, a
  single named constant the header explains and tells the next person to
  flip if a real render lights the wrong face. Nobody has looked at an actual
  render from this script — this has not been checked against real behavior.
- **derived** — `SunDirection` points *toward* the sun (compass bearing of
  the sun's position), not the direction light travels. Based on: (a) a
  community forum description calling it "the vector to the Sun's rays", and
  (b) the sign logic that a vector with positive z (pointing up) at midday
  only makes sense as "toward the sun" rather than "light travel direction"
  (which would point down at midday). Neither the official Ruby API doc page
  nor the C API reference states this explicitly — I could not find a source
  that says so in as many words. This assumption only affects the *sign* of
  `SUN_BEHIND_CAMERA`'s effect; the offset math and the calibration are
  unaffected by it either way.
- **reported, from a live WebFetch of ruby.sketchup.com/Sketchup/ShadowInfo.html
  and Sketchup/Page.html** (not memory) — the documented `ShadowInfo` keys
  include `NorthAngle`, `SunDirection`, `ShadowTime`; `Sketchup::Page` has its
  own `#shadow_info`, `#use_shadow_info?`, `#use_shadow_info=`. This is the
  basis for the header's claim that a scene can carry its own sun.
- **assumed** — `model.shadow_info['ShadowTime'] = a_ruby_Time_object` is
  accepted. This is a very well-known idiom in the SketchUp Ruby ecosystem
  but I did not find a page stating the assignment's accepted type in the
  fetched doc excerpts, and it cannot be tested here. The write is wrapped in
  its own rescue (`time_stuck` in the result hash) so a rejected write is
  reported rather than silently ignored, and it does not abort the rest of
  the operation (NorthAngle is the part that matters most).
- **assumed** — the panel category `Render prep` is new; no existing script
  used it, so there was nothing to match. It groups sensibly with the other
  five items in this mission per `.forge/GOAL.md`, but if Builder A or C
  picked a different string for their own scripts' `@cat`, the category list
  will show two "Render prep"-ish groups rather than one until someone
  reconciles the strings — worth a look once the other five land.

## Open questions

- **Whether the composition is truly additive was NOT confirmed from
  documentation** — it is instead measured at runtime, every time the button
  is pressed, by `WR_SunAim.calibrate`: it nudges `NorthAngle` by 10 degrees
  in the live model, reads `SunDirection` back before and after, and derives
  the sign and confirms the step size. If a real run ever shows the measured
  step is not close to 10 degrees, the dialog reports "LOW CONFIDENCE
  calibration" in red and gives the slack in degrees — that is the signal
  that either the relationship isn't linear the way I assumed, or something
  else about this SketchUp build's shadow math differs from what I derived.
  I have never seen this run, so I do not know whether that flag will ever
  fire in practice.
- **Whether V-Ray's SunLight follows `shadow_info` is untouched and unknown**,
  per instruction — `probe-vray.rb` has not been run by anyone. If it turns
  out V-Ray holds an independent sun direction, this script's math is still
  correct (it is about where the sun *should* be), but it would need a
  V-Ray-side write added later, which is explicitly out of scope here.
- **This script has not been run in SketchUp at all.** Only
  `python scripts/rbparse.py scripts/wr-sun-aim.rb` has been checked, and it
  reports `ok` — that confirms the file is valid CRuby 3.2 syntax (the same
  parser SketchUp 2024 ships), not that the SketchUp API calls succeed, that
  the HtmlDialog renders correctly, that `sketchup.apply(...)` reaches the
  Ruby callback, or that the resulting shadow actually looks the way the
  header describes. All of that is unverified.
- **`SunDirection`'s sign convention (toward-sun vs. travel-direction)** is a
  genuine open question I could not close from available documentation — see
  Assumptions above. It is isolated to the effect of `SUN_BEHIND_CAMERA`, so
  it is a one-line fix if the first real shot comes out backwards.

===REPORT===

Built `C:\Users\bento\Documents\Claude\Sketchup\scripts\wr-sun-aim.rb` — the
"Light It From Here" button. It reads the current camera azimuth, computes a
target sun azimuth (dead-behind-camera plus an adjustable ~30 degree offset,
default sign toward one side), measures the live relationship between
`NorthAngle` and the sun's actual world azimuth by nudging it 10 degrees and
reading `SunDirection` back (rather than trusting an assumed formula), solves
for the `NorthAngle` that lands on target, and writes that plus a chosen
time-of-day into `model.shadow_info` inside a single undo step. It writes no
geometry, no scene cameras, no tags, no materials, and calls no V-Ray API.
Report goes to a non-modal `UI::HtmlDialog` (camera azimuth, target vs.
achieved azimuth and the error between them, `NorthAngle` before/after,
elevation, time set, and a red flag if the live calibration didn't confirm a
clean linear relationship) plus a mirrored summary in the Ruby Console; the
dialog stays open so the operator can re-orbit and press it again.

Verified: `python scripts/rbparse.py scripts/wr-sun-aim.rb` reports `ok` —
this is the real CRuby 3.2 parser SketchUp ships, confirming the file is
syntactically valid. Not verified, because there is no `ruby.exe` outside
SketchUp on this machine and I did not run SketchUp: whether the HtmlDialog
renders and wires up correctly, whether the `NorthAngle`/`SunDirection`
calibration behaves as measured in a real session, whether the resulting sun
position actually looks right in a render, and whether the `ShadowTime`
assignment is accepted by this SketchUp build. Two assumptions are called out
explicitly in the script's own header and in this note as flip-one-line
fixes if wrong: `SUN_BEHIND_CAMERA` (which side of the camera the sun sits
on) and the implicit assumption that `SunDirection` points toward the sun
rather than along the light's travel direction.

Files touched: `C:\Users\bento\Documents\Claude\Sketchup\scripts\wr-sun-aim.rb`
(created), `C:\Users\bento\Documents\Claude\Sketchup\.forge\builder\HANDOFF-b.md`
(created). No other file was touched — `scripts/wr_tools/VERSION` was left
alone, nothing was committed or pushed, per instructions.

blockers: none for handing this off, but the script is unrun. It needs a real
SketchUp session to confirm the calibration, the dialog, and the resulting
shadow before it can be called done rather than "built and parses."
