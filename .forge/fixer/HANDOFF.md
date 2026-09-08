# HANDOFF — 1.19.13: MJP orientation fix + desk 3/32 drop (UNCOMMITTED, awaiting Benton)

## Produced
- `scripts/wr-overlays.rb`
  - `MJP_SPIN180 = false` (:158), `FACE_ROOM[:mjp] = -1` (:212), MJP `axes_for` height `nil`.
  - `DESK_SURFACE_Z = 32.5 - 3.0 / 32.0` (:139) — Benton 8 Sep 2026, written as anchor minus
    correction, commented with its origin. `MJP_TOP_Z` (:177) untouched and its comment now
    says it is a wall datum that does NOT track the desk.
- `scripts/rbtest-part-orientation.py` — `test_mjp_chain` (chain transcribed, 8 wall/face
  cases, 1.19.2 settings reproduce the defect, `MJP_TOP_Z` independence) and
  `test_desk_height` (expression read from source, evaluates to 32.40625, anchor-minus form,
  read on exactly two code lines). 100 checks; three red-injections tried and each caught.
- `scripts/wr_tools/VERSION` 1.19.13 (one bump for both changes). `DEVLOG.md` 2026-09-08 entry.
- `.forge/fixer/mjp-orientation-diagnosis.md`, `mjp-transform-repro.py`, `probe-mjp-faces.rb`.
- NOT committed, NOT pushed.

## Read-first
- `DEVLOG.md` top entry — why the 1 Sep axis was wrong, and why the MJP did not follow the desk.
- `scripts/wr-overlays.rb:130-177` — the desk and MJP datums side by side with their reasons.

## Assumptions
- SketchUp `A * B` applies B first; `Transformation.axes` maps def X/Y/Z to its vectors.
  Derived from foam/desk landing correctly through the same code.
- The jack field is on MJP.skp's def −Y face — derived from the 8 Sep screenshot, not read
  off the .skp.
- The MJP is mounted to the wall on its own datum, not relative to the desk. Evidence: the
  portal fixes `MJP_PLATE_CENTER_IN = 27.25` as its own constant; Benton's report names only
  the desk. If he wanted the MJP down 3/32 too, it is one literal (:177) and the harness pin.

## Open questions
- **UNRUN IN SKETCHUP.** Benton's next booth-link import checks three things: MJP box at
  21.70..29.07 booth-local (+4.75 with casters), jack field facing him inside / outward
  outside, tails hanging to 10.69 — UNCHANGED by the desk drop; and the desk surface at
  32.40625 (strip top 37.24625).
- Wall-side uniformity of the MJP is derived, not seen: drag the MJP to another wall's
  window/cable panel in the booth builder and re-import, or load
  `.forge/fixer/probe-mjp-faces.rb` and read Part 2.
- Out of scope, flagged: MJP.skp's box is ~7.4 in tall vs the portal's 3.64, so `MJP_TOP_Z`
  centres it ~1.9 in below the QA'd 27.25.
