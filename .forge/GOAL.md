# GOAL

## Mission
Redesign the WhisperRoom SketchUp plugin panel so a new user can sit down and use it
without being taught. The concept is right; the visual design, the grouping of the
scripts, and the icons are not. Produce an approved design direction and a viewable
mockup before any plugin code is rewritten.

## Done means
- A researched, opinionated UI design for `scripts/wr_tools/panel.html`, shown as a
  self-contained mockup Benton can open and react to.
- A proposed reorganisation of `scripts/` — every script placed in a category that
  makes sense to someone who has never seen the plugin, with the dev-only and
  one-off scripts separated from the daily tools.
- An icon set that says what each script actually does, replacing the current
  generic `ico-*.svg` collection.
- An artifact published to claude.ai showing the proposed design.

## Now
Design approved by Benton 2026-08-15. Building it, to the spec at
`.forge/scoper/panel-redesign.md`, steps 1-5 only. Two sub-agents on a clean file
split so they cannot collide:
1. Builder A — `scripts/wr_tools/panel.html` and `scripts/wr_tools/main.rb`. Owns
   the redesign and the autorun guard fix. Touches no other file.
2. Builder B — `scripts/wr_tools/wr-ico-*.svg`, `wr-icons.svg`, `icon-map.json`.
   Owns every icon asset. Touches no other file.

Decisions taken here so the builders are not blocked (all reversible, flagged to
Benton in the report):
- The 14 `@title` renames: ACCEPTED.
- Fixed pipeline category order rather than newest-first: ACCEPTED.
- Retiring `booth-4260-s.rb` / `booth-96168-s.rb`: NO. Shelve them behind the dev
  switch instead. Deleting is the one irreversible call in the set and it is
  Benton's to make.
- Moving `csusb-rooms.rb` to `clients/`: NO. `CLAUDE.md` cites it as the worked
  example; shelve it instead so the reference stays true.
- The 6 tools still sharing icons: Builder B authors them to the Researcher's
  written briefs. The system rules are specific enough now that this does not need
  a separate art pass.

## Out of scope
- Spec step 6 (pre-run settings sheet). It changes `meta_of`, which every render
  runs, and a regression there blanks the whole list. Separate round.
- Spec step 7 (deleting the generic `ico-*.svg` library). Saved slot prefs still
  reference those ids; deleting them regresses the toolbar to numbered faces.
- Rewriting any script's own `UI.inputbox`.
- Any change to booth geometry, `wr-booth-data.rb`, `wr-deck.rb` or the builders.
- The `WhisperRoomQuote` repo — read only, never write.
- Prices. Nothing from `models.json` goes into any artifact.
