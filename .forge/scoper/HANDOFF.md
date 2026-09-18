# HANDOFF — Scoper → Benton (approval), then Builder: Draw floor plan redesign

18 Sep 2026 · plugin 1.71.1, ships as 1.72.0. The previous handoff (Interior Lights panel) is
preserved at `.forge/scoper/HANDOFF-light-rig.md` / `drop-lights-panel/`.

**Approval gate: Benton opens the mockup and says yes/no.** Nothing is approved yet. Q1 in the
spec is the one that changes where doors build; the rest is look-and-feel he can change by
pointing at the mockup.

## Produced
- `.forge/scoper/floorplan-redesign.mockup.html` — click a wall to add a door, drag it, edit
  offset/width/hinge, click a dimension to edit a wall, chain closure, Build shows the payload.
  Open in a browser; `?test=1` runs the acceptance scenario (six PASS lines observed in
  headless Chrome). Same CSS variables and helpers as the shipped dialog; MOCKUP-ONLY blocks
  are marked for removal.
- `.forge/scoper/floorplan-redesign.md` — the spec: §3 contract, §4 ordered steps, §5 runnable
  ACs, §7 questions.
- Nothing under `scripts/` touched. VERSION untouched. Nothing committed.

## Read-first (Builder)
1. Spec §3 — the payload contract; the only change is the additive `placed:true` on a door.
2. `scripts/build-room.rb:352-361` (`build` reads the cfg) and `:518-534` (callbacks).
3. `scripts/takeoff-vectors.html:33` — the regex that lifts `parseLen` out of the HTML.
4. Mockup `renderInspector` — the focus/caret guard for a card that redraws per keystroke.
5. The `FLIP_NS` comment in the mockup, and spec Q1.

## Assumptions (tagged)
- **observed** the HTML flips N↔S on output while `takeoff-format.md` and the preview both
  walk clockwise from NW with north up; **derived** that today's rooms with doors build mirrored
  (preview north wall → model south wall). **Not verified live.** Kept as-is behind `FLIP_NS`.
- **assumed** a clicked door warns rather than blocks Build (spec Q2).
- **assumed** 36" default width, compass wall names, the list kept collapsed (Q3, Q4, Q6).
- **assumed** CEF supports `setPointerCapture`/`getScreenCTM` (standard Chromium; fallback in
  spec §6).
- **observed** every AC-1 payload value against `build-room.rb` `door_errors`: at=48 > TOL and
  48+36=84 < 144−TOL, so Ruby would cut it.

## Open questions
Spec §7 Q1–Q6. Q1 (mirror) needs one live build with one door to answer; Q2 (warn vs block)
is one line either way.
