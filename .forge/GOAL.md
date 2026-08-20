# GOAL

## Mission

Add the render-prep toolkit to the WhisperRoom SketchUp plugin: make the switch between
"model built to be measured" and "model built to be photographed" a scripted, reversible
operation, and make exporting a full client pack a single press.

The whole point is that today every one of those changes is done by hand from memory, which
is where the mistakes come from — a dimension string left on in a hero render, a wall still
wearing a flat drafting material.

## Done means

Six things exist, each with a `@title` header so the panel picks them up, each passing
`python scripts/rbparse.py`:

1. `scripts/wr-materials-swap.rb` — drafting <-> render materials, mapped BY NAME, with
   named slots. Names every surface it could not map.
2. `scripts/wr-mode.rb` — Draft <-> Render toggle. Calls #1, plus dimension tags, style,
   shadow settings. Stores both states in the model so flipping back restores exactly.
3. `scripts/wr-sun-aim.rb` — "Light it from here": sun snaps to the current camera azimuth
   plus a ~30 degree offset. Moves no geometry.
4. Two-band walls in `scripts/build-room.rb` — walls built in a lower and an upper band,
   upper on tag `WR-Room-Upper`, so a scene can hide it. Plus a one-time splitter for
   models already drawn with one-piece walls.
5. `scripts/wr-preflight.rb` — pre-render checklist in an HtmlDialog where every failing
   row carries the fix that clears it.
6. `scripts/wr-pack-export.rb` — mark scenes for V-Ray, one press exports everything into
   ProposalFiles\<Client>\ under the names proposal-v2.json expects. VIEWPORT LANE LIVE,
   V-RAY LANE STUBBED behind a finished interface.

## Now

Three Builders running in parallel:
- Builder A: items 1, 2, 5, 6 (a dependency chain — one context)
- Builder B: item 3
- Builder C: item 4

## Out of scope

- Light rig placement (`wr-lightrig.rb`) — deliberately deferred, Benton's call 20 Aug 2026.
- Pinned render settings, .vrscene archive, lighting contact sheet, rig presets.
- ANY live V-Ray API call. `probe-vray.rb` has not been run; nothing about V-Ray's Ruby API
  is confirmed. The V-Ray lane of the exporter is a stub only.
- Bumping `scripts/wr_tools/VERSION` — the orchestrator owns that file to avoid three
  agents colliding on it.
- Committing or pushing. The orchestrator does that after review.
