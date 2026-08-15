# Scoper handoff — panel redesign

## Produced
- `.forge/scoper/panel-redesign.mockup.html` — interactive mockup: two 348 px frames
  (light + dark), real tools under the Researcher's category tree and renames, working
  search (finds hidden dev tools, DEV-badged), ability toggles with state strip, inline
  settings, pre-run sheet, toolbar-slot editor with pending-restart state, dev/workshop
  footer switch, and the 18-icon WhisperRoom icon system as inline SVG symbols with the
  20 px pair test.
- `.forge/scoper/panel-redesign.md` — the spec: art direction, icon system rules,
  ordered Builder steps, acceptance criteria, risks, header-grammar cost call-out
  (zero required script edits; `@icon`, `@shelf`, action-`@setting` are optional and
  additive; ~22 recommended one-line `@title`/`@shelf` edits), and the autorun-defect
  prerequisite.
- Published artifact of the mockup (URL in the report).

## Read-first
1. `.forge/scoper/panel-redesign.md` — the whole plan; steps name every file.
2. The mockup in a browser — the visual contract; extract its `<symbol>` blocks for the
   standalone toolbar SVGs.
3. `.forge/researcher/proposed-structure.md` and `.forge/researcher/panel-problems.md` —
   the category tree, renames, icon briefs, and the autorun defect this spec depends on.
4. `scripts/wr_tools/main.rb` comments — mechanisms deliberately kept (slot binding at
   load, rename-not-filename, pipe-joined prefs, rescue Exception).

## Assumptions
- SketchUp's embedded Chromium honours `prefers-color-scheme` (unverified — check in
  step 1; fallback is a manual theme pref on the same tokens).
- The autorun defect description is reported from the Researcher, not runtime-verified;
  the Builder must confirm in SketchUp before and after the guard fix.
- Pre-run sheet fields shown for Orbit are illustrative, not that script's real
  parameters.

## Open-questions (Benton's approval gate — nothing is user-approved yet)
- Accept the Researcher's 14 `@title` renames?
- Fixed pipeline ordering (as mocked) vs the current newest-first?
- Retire `booth-4260-s.rb` / `booth-96168-s.rb`; move `csusb-rooms.rb` to `clients/`?
- Six tools still share neighbour icons (component-art pair, list-scenes vs
  export-scenes, probe pair, the two shop jigs) — Graphics Designer pass to the
  Researcher's icon briefs, or Builder authors them to the system rules?
