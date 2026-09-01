# HANDOFF — Roof-Mounted Ventilation (RM)

## Produced

- `.forge/researcher/roof-mount-ventilation.md` — full findings, with citations, risk
  ranking, and the six questions for Benton.
- This handoff.

Nothing else was written. No repo source touched, no model opened, no bridge query run.

## Read first

1. `.forge/researcher/roof-mount-ventilation.md` §"Answer, short" and §6 (risks) — those
   two carry the whole decision.
2. `C:\Users\bento\OneDrive\Documents\Claude\Sketchup\WhisperRoom-SketchUp\scripts\booth-from-link.rb`
   lines 186-217 (`component_for`) — the missing `CBL` branch, the live defect.
3. `C:\Users\bento\OneDrive\Documents\Claude\WhisperRoomQuote\booth-builder.html`
   lines 3180-3188 (`applyRoofVent`) and 2884-2890 — the VNT→CBL swap, already done
   upstream of our payload.
4. `C:\Users\bento\OneDrive\Documents\Claude\WhisperRoomQuote\assets\layout-render.js`
   lines 3085-3107 (RM art/size tables, `rmSupported`) and 4434-4478 (roof placement in
   the elevation).
5. `C:\Users\bento\OneDrive\Documents\Claude\Sketchup\WhisperRoom-SketchUp\scripts\wr-overlays.rb`
   header — the "portal-sourced or refused by name" rule that governs any RM placement.

## Assumptions

- **assumed:** `RM<model>.skp` (22 models, plus a `VSS` twin each, in
  `P:\Sketchup\NewMasterComponentList`) is one pre-composed roof assembly per booth. It
  follows from the exact one-file-per-RM-supported-model match and from the `RM<size>`
  family matching the portal's art tables exactly, but nobody has opened one. **This is
  the assumption that decides the size of the job.** Verify it by loading one into an
  Untitled model under the GOAL's in-Ruby guard.
- **derived, not executed:** the failure chain in which a `STDWL46 CBL` pack builds a
  `46VNT` wall. Traced through `component_for` → `odd` → unassigned slot →
  `build-booth-components.rb:2226` `guess_component('VNT', run)`. There is no `ruby.exe`
  here; confirm with a dry run of `booth-from-link.rb` on a real RM share link.
- **observed:** all `.skp` and `.webp` inventories, timestamps, the `rv` payload shape,
  the portal's clearance and gating logic, and the absence of RM from the catalog JSON.
- **not checked:** the RM parts' bounding boxes, insertion points and internal
  arrangement. Benton had files open; no model was touched.

## Open questions

Benton's, in priority order (full wording in the findings file):

1. Is `RM<model>.skp` the complete roof set, or do intake/exhaust place separately?
2. Where exactly does it seat on the roof, and is there an orientation rule?
3. What ceiling height does an RM booth actually need? (The portal's fit card does not
   add the roof unit's 10″/16.5″ — likely a portal bug worth reporting separately.)
4. HX booths — same RM part 10″ higher? There is no `RM*_HX.skp`.
5. Are `RM<size>`, `_BACK` and the `*SideView` files art-only scenery, excluded from the
   build library?
6. Ship the `CBL` pack fix now, ahead of the roof geometry?

## Note on GOAL divergence

`.forge/GOAL.md`'s current mission is the floor-plan intake pipeline; roof-mount
ventilation is not in it, and `booth-from-link.rb:37` and `:421` refuse `rv` citing that
GOAL. This assignment supersedes that for the diagnosis, which is why the refusal lines
are reported as current-state rather than as something to change. Anyone acting on this
should get the GOAL updated first, or the next reader will find code and goal disagreeing.
