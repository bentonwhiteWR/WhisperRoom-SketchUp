# HANDOFF — Auditor, lighting inconsistency (2026-08-28)

## Produced

- `.forge/auditor/lighting-inconsistency-2026-08-28.md` — ranked root-cause analysis of
  Benton's "drop in your lights is HIGHLY inconsistent" complaint. Ten candidate
  mechanisms (C1-C10), each with file/line, the symptom it produces, likelihood, and a
  under-five-minute live check. Top three: (C1) scenes re-apply stored `WR Lights`
  visibility + sun on every activation (`proposal-scenes.rb:221,223` sets
  use_hidden_layers/use_shadow_info true; render lane toggles mode BEFORE selecting the
  page — `proposal-package.rb:708` vs `:813`), overriding the mode toggle, the sun aim,
  and placement's tag-forcing; (C2) the dialog's Brightness/Warmth/exposure are printed
  advice only — real emission is the shared per-model Asset Editor slider, observed at
  30,000 lm (10× spec) during 27 Aug debugging; (C3) exposure stays at EV 14.2 unless
  hand-set, making interior frames 30-60× dark. Together these explain the observed
  28 Aug pair (dark blue booth interior vs warm overview) as sky-only illumination at
  sun exposure. Recommendation: close the RENDER-time seam (preflight + make scenes and
  the light tag agree + run the §3.3 writability probe), not a fifth placement-time fix.
- This file.

READ-ONLY pass: no code, no VERSION bump, nothing outside `.forge/auditor/`.

## Read-first

1. `.forge/auditor/lighting-inconsistency-2026-08-28.md` — §2 (the ranked table) and §6
   (gaps). §5 is the recommended fix, for the Builder AFTER a greenlight.
2. `.forge/researcher/vray-light-creation.md` Part 2 — Probe A2 is still un-run and still
   the decisive one-paste test for the hidden-tag suspect.
3. `.forge/researcher/interior-lighting-design.md` §3.3 — the writability probe that
   decides whether Brightness/Warmth/EV can ever be real controls.

## Assumptions

- The 28 Aug dark-interior / warm-overview render pair is as relayed in the assignment;
  the PNGs were not re-examined here.
- "V-Ray excludes hidden-tag lights" is reported (Chaos docs/forum), never confirmed live.
- SketchUp behavior for a tag created after a scene was captured (shown or hidden on
  activation) is unknown here — C1's live check answers it per model.
- `Geom::BoundingBox#contains?` boundary inclusivity at DROP=0.0 (C7) untested.
- No runtime verification of any kind — no SketchUp/ruby.exe on this machine.

## Open-questions

- Benton's characterization of "inconsistent" (asked, unanswered) — §2's symptom column
  maps his eventual answer straight onto a candidate.
- Probe A2 result (hidden tag) and the §3.3 probe result (intensity/EV writability) —
  both ~3 minutes at the desk, both fork the fix design.
- Per-scene check: does the dark-render scene's Tags tray show `WR Lights` hidden and a
  different Shadows time than the overview scene? (C1 confirmed/killed in two clicks.)
- The real booth tray thickness (BOOTH_DROP=6" is assumed) — needs Benton's tape measure.
