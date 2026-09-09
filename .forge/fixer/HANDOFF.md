# HANDOFF — roof-mount (rv = 1) refused a booth whose cable walls had been moved

**Outcome: fixed and proven outside SketchUp.** `roof_vent_complaints` was doing an
identity check on slot ids where the product rule is a count. Shipped as **1.19.14**.

## Produced

- `C:\Users\bento\Documents\Claude\Sketchup\scripts\booth-from-link.rb` — the fix.
  `roof_vent_complaints` now counts CBL packs across every outer panel slot and
  compares that to the vent-set count; new `outer_panel_ids`, and `vent_slot_ids`
  refactored onto a shared `outer_panels` reader. Console + messagebox reworded.
  `RM_HALF_APPLY_ABORTS`'s header comment rewritten to describe a count.
- `C:\Users\bento\Documents\Claude\Sketchup\scripts\rbtest-boothlink-cbl.py` — group 5
  is the reported payload (stubbed slot lists); group 4's assertions loosened off
  exact line counts onto content.
- `C:\Users\bento\Documents\Claude\Sketchup\.forge\fixer\rm-moved-cbl\repro-moved-cbl.py`
  — the same design against the REAL `wr-booth-data.rb`, plus the part-translation
  check. This is the file to re-run if the fence is ever touched again.
- `C:\Users\bento\Documents\Claude\Sketchup\DEVLOG.md` — 1.19.14 entry.
- `C:\Users\bento\Documents\Claude\Sketchup\scripts\wr_tools\VERSION` — 1.19.13 → 1.19.14.

## Read first

- The portal is the authority and it is READ-ONLY from here:
  `C:\Users\bento\Documents\Claude\WhisperRoomQuote\booth-builder.html` —
  `applyDesign`'s re-seat block at 3496-3536 (`(VNT + CBL) === ventSets`),
  `applyRoofVent` at 4195 (position-blind), `doSwap` at 4360-4405 (moves packs
  between any two same-module slots). Nothing in that repo was changed.
- The vent-set count equals `base-bom.json`'s `F01` for all 25 layouts — verified,
  not assumed (`C:\Users\bento\Documents\Claude\WhisperRoomQuote\lib\pl-data\`).
- `scripts/rbparse.py` is the real syntax check. `rbcheck.py` is a bracket counter
  and is not evidence of anything.

## Assumptions

- **assumed** — that the payload Benton hit is equivalent to the one reconstructed
  here. The actual `sales.whisperroom.com/q/W-…` link was never supplied. The
  reconstruction reproduces his messagebox text verbatim ("1 of 3 vent slot(s)…"
  with N0 and N2 as plain `STDWL46`), which is strong but not the same as the link.
- **assumed** — that a SURPLUS of cable walls (more than ventSets) should not be
  refused. It is unreachable from the builder and refusing it risks a second
  too-strict fence; it is now not checked at all. Say so if that is wrong.

## Open questions

- **Nothing was run inside SketchUp.** No `ruby.exe` on this machine and no live
  bridge. The fence, the layout reader and the part translation were exercised
  through SketchUp's own CRuby 3.2 via `rbparse.py`; `build_booth` actually placing
  those parts in a model is unrun. Benton re-running his own link is the last check.
- Reaching Gabe still takes `git pull` + `install-plugin.py` + restart on his
  machine (or the panel's **Update now**). Pushing is not installing.
