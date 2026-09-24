# HANDOFF — Builder: booth-from-link places quote accessories (24 Sep 2026, plugin 1.77.0)

## Produced
- `scripts/wr-accessories.rb` (new, pure, in wr_tools SKIP): the studio-light table (`sl_by_model`,
  copied from WhisperRoomQuote `lib/pl-data/feature-rules.json`), bass-trap packs
  (`PRESET_QTY_OVERRIDES`, quote-builder.html), the MDL 127 LP exclusion, the corner order and the
  studio-light plan layout, plus the HEPA seat constants proven at People's Space.
- `scripts/wr-overlays.rb`: `place_studio_lights`, `place_hepa`, `place_bass_traps` (+ helpers
  `turned_span`, `quarter_turn`, `ceiling_over`), called from `place_all` after the roof unit and before
  the caster plate, each fenced so a failure is a named warning in the build summary.
- `scripts/booth-from-link.rb`: passes `studio_light` / `hepa` / `bass_traps` / `package` in the overlay
  hash; prints the plan; refuses by name: MDL 127 LP (every accessory), an unknown model (sl), HEPA on a
  wall-vented booth, and Audimute (ac, decision pending).
- `scripts/build-booth-components.rb` loads wr-accessories.rb; `scripts/wr_tools/main.rb` SKIP list.
- `scripts/rbtest-accessories.py` (new): 43 checks + drift checks against the WhisperRoomQuote sources.
- `scripts/wr_tools/VERSION` 1.76.1 -> 1.77.0; DEVLOG entry.

## Read-first
- DEVLOG.md top entry (2026-09-24), which also lists what to check on the first live build.
- `.forge/builder/peoplesspace-ap/HANDOFF.md` for where the HEPA geometry came from.

## Assumptions (none of these are sourced; each is flagged in code)
- The link carries `bt` as an on/off flag only (observed, booth-builder.html designPayload). Pack count
  comes from `pk`; a hand-edited quote quantity cannot be seen.
- Studio-light plan layout: evenly spaced along the ceiling's long axis, across the booth when it clears
  6 in each side, otherwise along it. Hung at the standard ceiling tile underside, same as the Standard
  Light (so on Enhanced it sits at the standard ceiling, not the IEP tray, exactly like the old fixture).
- Every instance on the `WR Lights` tag in the fresh booth group is a Standard Light to replace.
- Bass Trap.skp is authored standing (z up) with its back corner at its own low-x/low-y corner; traps 5+
  stack as a second tier under the first four.
- HEPA: the `VSS duct box` in every RM part is the same box as in RM96120VSS (guarded: the measured
  open-end point must lie inside its bounds, or it is refused by name).

## Open questions
- **Audimute (ac):** staged kit vs People's Space wall layout. Orchestrator put this ON HOLD mid-task;
  nothing was built and `AP_PACKAGES` is not embedded.
- **HEPA on wall-vented booths** (the common case) is refused. To build it, someone has to measure the
  vent-wall parts' duct boxes in SketchUp and say which is the intake.
- **UNRUN in SketchUp.** The bridge was not listening (`sketchup-bridge.py ping`). Build one link with
  sl + bt, and one RM + VSS link with hp, and inspect before trusting any placement.
- Whether studio lights on an Enhanced booth should hang from the IEP tray instead.
