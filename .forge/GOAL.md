# GOAL

## Mission
Extend the proposal package script's per-scene hiding so it covers ANNOTATIONS — text,
dimensions, labels, section planes and the like — not just whole walls. Benton: "Sometimes
I have tons of text I want on one scene, but not another." Same feel as the existing WALLS
column in proposal-package.rb, driven by wr-scene-walls.rb's proven mechanism.

## Done means
- A Scoper spec + viewable mockup approved by Benton BEFORE any script code is written.
- Per-scene show/hide of screen text, 3D text, linear/angular dimensions and labels,
  saved into the scene the same way walls are (page.update with the hidden-state mask),
  so proposal-package.rb picks it up for free when it selects each scene to export.
- Grouping that matches how Benton actually works — annotations picked as sets, not one
  entity at a time — settled with him in the mockup.
- The proposal-package.rb export manifest records what was hidden by design, the way
  groups_hidden already does for walls.
- Verified live in SketchUp, not just reasoned about. Committed and pushed.

## Now
Follow-up ask (Benton, 10 Sep 2026): the annotations dialog can move a selection into a
set, but there is no way to CREATE an annotation set from the dialog on its own. Add
explicit set creation — name it, it appears as a set row immediately, empty, with no
selection required. Existing "New set…" + MOVE flow keeps working.

## Out of scope
- Rewriting the walls feature; extend/parallel it, don't replace it.
- Any change to the PeoplesSpace room work (archived: .forge/GOAL.peoplesspace.archive.md).

## History
- PeoplesSpace MDL 96120 E + ADA alcove take-off — see .forge/GOAL.peoplesspace.archive.md
