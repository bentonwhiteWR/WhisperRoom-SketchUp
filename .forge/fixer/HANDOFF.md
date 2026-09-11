# Fixer HANDOFF — the two blockers in front of rank cycle 1 (11 Sep 2026, desktop)

## Produced

- `scripts/wr-drop-lights.rb` (1.66.0)
  - `door_face_normal`, `booth_door_box`, `accent_place` + `ACCENT_FAN_STEP`
    / `ACCENT_FAN_MAX`: the key is aimed along the door FACE normal and walks
    out from the face; a perpendicular that does not fit is swept +/-15..60
    deg (`KEY SWUNG`) before `KEY SKIPPED`. Rim and foam use the same normal.
  - `audit_scene(model)` / `audit_verdict(rows, missing)` + `FACTORY_INTENSITY`,
    and every placed light now carries a `lumens` attribute: the render-time
    check that V-Ray holds exactly the rig the model shows.
- `scripts/rbtest-lights.py` — `dfn`, `ap`, `av` transcripts (59 checks,
  green; three mutations red). `scripts/wr_tools/VERSION` 1.65.1 -> 1.66.0.
- `.forge/fixer/ROOTCAUSE-key-light-and-2x-2026-09-11.md` — both root
  causes with every number and its provenance.
- `.forge/fixer/rank-loop/` — the bridge jobs that ran a full headless cycle
  on this desktop (`lib.rb`, A-setup, B-drop, C-export, D-redrop, E-rollback,
  F-abort, G-ghosts, H-fixed, Z-cleanup), `measure.py` (the rubric formulas
  plus linear decode), the console transcripts, `renders-r1-r6.txt`, and
  `ratio-c1b-over-c3.png`. This IS the cycle recipe: AUTO-SET -> drop ->
  audit -> export -> poll `@running` -> measure.
- `DEVLOG.md` 1.66.0.
- Benton's model: put back to its pre-experiment census exactly (no scenes,
  no rig, tag hidden, remembered export folder list stripped of my scratch
  paths). The camera was restored by eye only (the eye point was recorded,
  the target was not).

## Read-first

1. `.forge/fixer/ROOTCAUSE-key-light-and-2x-2026-09-11.md` — the whole case.
2. The `KEY` / `KEY SWUNG` / `KEY SKIPPED` block in `wr-drop-lights.rb`
   (search `door_face_normal`) and the `THE SCENE AUDIT` block.
3. `.forge/fixer/rank-loop/lib.rb` + `C-export.rb` for how a cycle is driven
   over the bridge without a dialog.

## Assumptions

- The laptop's V-Ray colour mapping / camera match the desktop's (Reinhard
  burn 1.0, mode 2, f/8 @ 1/300 @ ISO 100). The manifests' EV 14.23 on every
  cycle supports the camera half; the colour-mapping half is assumed.
- The c1b -> c3 darkening on the laptop was rig plugins losing their
  configuration (observed here once in three replace-path drops) and/or the
  tool-owned enclosure differing (the c3 sky-leak). Derived, not observed on
  that session; it is gone.
- The desktop model (`MDL 96120 S`, 11"/13" off two walls) stands in for the
  cycle model (`MDL 96144 E`, 4"/6" off) for pipeline behaviour, not for
  absolute numbers.

## Open-questions

- **The rim.** With the axis-aligned direction it is skipped on a corner
  booth (it used to sit half in the wall). Fan it, flank it, or accept no
  rim in corners — a lighting decision, not made here.
- **Kelvin.** The rubric's Reversal 2 and DEVLOG 1.65.0's floor-bounce
  diagnosis rest on c2 being a clean Kelvin-only change; c2's 3.4x darkening
  is the same unexplained class as c3's. Re-test 5000 K once, with the audit
  green, before treating "never touch Kelvin" as settled.
- **Why do params fail to stick on the replace path, one press in three?**
  The audit catches it; the cause (V-Ray re-syncing a plugin from a
  definition blob written by a transaction that undo touched?) is not
  established. `wr-drop-lights.rb`'s own "Ctrl+Z removes the lights" line is
  untrue on this build and should be reworded.
- **The cycle model lives on the laptop, unsaved.** Cycle 1 either runs
  there (pull 1.66.0 first — scripts are read live from the checkout) or the
  room is rebuilt here. The desktop bridge is on and works.
