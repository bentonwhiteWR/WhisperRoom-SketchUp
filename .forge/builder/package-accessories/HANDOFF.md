# HANDOFF — Builder: package links load their accessories (24 Sep 2026, plugin 1.77.3)

## Produced
- No importer change. A package link already carries its content flags beside `pk`. Evidence: `applyPackage()` sets
  `state[k] = true` for every `PACKAGES[name].o` key, and `designPayload()` emits them. A scratch harness running
  the page's real `applyPackage` + `designPayload` printed the flags for all 19 packages (Drum Booth `sl ac bt`,
  Recording Studio `sl ac bt vs ef`, etc.).
- `scripts/rbtest-accessories.py`: `package_flags()` drift check guards that premise (mutation-checked twice).
- Skills: `whisperroom-photo-job` stage 6 (+ stage 8 reworded), `whisperroom-takeoff` (new paragraph after the
  workflow block), `whisperroom-acoustic-package` (auto-invocation note). After the importer runs: sl / bt / hp are
  placed by it, and if the summary lists `ac: Audimute acoustic package`, the AP skill runs next, unasked.
- `scripts/wr_tools/VERSION` 1.77.2 -> 1.77.3; DEVLOG entry; installer run (skills byte-identical).

## Read-first
- DEVLOG.md top entry. `.forge/builder/importer-accessories/HANDOFF.md` for the 1.77.0 accessory placement.

## Assumptions
- The "NOT built" line `ac: Audimute acoustic package ...` in `booth-from-link.rb` (~line 1178) is the trigger the
  skills key on. If that wording changes, update the three skills.
- AP panels go inside the booth group (observed in the People's Space `ap-v2.rb`), so the photo-job stage 7 move
  carries them. Staged leftovers might not; the skill says to check.
- The harness stubbed window seating, so windows were not covered by it (they ride in `a`, not flags).

## Open questions
- **Unrun end to end.** The bridge was up, but Benton's open model (`TampaPrepatory MDL 144144 E.skp`) had unsaved
  changes, so nothing was built. First real test: a Practice Basic or Drum Booth link through photo-job stage 6.
- `.forge/GOAL.md` still says AP goes in "as a staged kit BESIDE the booth". 1.77.1 and this change lay it out on the
  walls with the skill. GOAL.md needs updating by whoever owns it (it was not staged here).
- The Audimute layout inside the booth is still the skill's untested first use (1.77.1 open item).
