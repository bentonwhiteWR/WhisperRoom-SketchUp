# HANDOFF — remove the SHOWN → bulk bar

## Produced
- `scripts/proposal-package.rb`: SHOWN → bar markup, `#picksum` tally, `$pick` binding,
  `[data-bulk]` click wiring and the Ruby `bulk` action callback removed; three comments
  updated so they no longer describe the bar as present.
- `DEVLOG.md`: entry appended under 2026-09-11 (VERSION bump held by the orchestrator).
- Local commit only; not pushed; VERSION untouched.

## Read-first
- `scripts/proposal-package.rb` — search `class="bulk"` (AUTO-SET bar, kept), `allScope` /
  `shownNs` (walls/annotations APPLY-TO-ALL scope, kept), `busy?(d, 'mark')`.
- `scripts/jstest-proposal-dialog.js` — the harness that runs `draw` under a fake DOM.

## Assumptions
- Nothing outside `proposal-package.rb` called `sketchup.bulk` / the `bulk` callback
  (observed by grep over `scripts/`, `.forge/builder/verify-autoset.rb`, tests).
- The SCENES header (`#scenesum` = `#count`) is the surviving home of the render/image
  count; SKIP was only ever the remainder and is not shown anywhere now.

## Open-questions
- Dialog is UNRUN on this machine. Someone with SketchUp should open Proposal package once
  and confirm the grid draws and the AUTO-SET bar is still there.
- If Benton wants a SKIP count on screen, it belongs in the SCENES header string in `draw`.
