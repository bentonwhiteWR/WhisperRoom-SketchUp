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
Follow-ups from Benton, 10 Sep 2026, in order:
1. DONE 1.20.1 — create an annotation set from the annotations dialog, no selection needed.
2. DONE 1.20.2 — clicking a scene name in the proposal package goes to that scene.
3. DONE 1.21.0 — hide whole OBJECTS (booth, furniture) per scene, in the proposal package window.
   Real bug, seen live 10 Sep 2026: Benton selected the booth, pressed USE MY SELECTION in
   the popover, got "Nothing in your selection matched a named wall". The popover shares
   WR_SceneWalls inventory/apply/keys_for_selection/reveal but NOT apply_selection, so
   from that window nothing but a named wall can be hidden.
   SCOPE CORRECTION: the booth is a Sketchup::GROUP named "MDL 96120 E (components)", not
   a ComponentInstance. List top-level groups AND component instances that are not already
   named-wall rows. "Component instances only" was my misreading and is dead.
All three are unverified in SketchUp — Benton has not click-tested them yet.

## Out of scope
- Rewriting the walls feature; extend/parallel it, don't replace it.
- Any change to the PeoplesSpace room work (archived: .forge/GOAL.peoplesspace.archive.md).

## History
- PeoplesSpace MDL 96120 E + ADA alcove take-off — see .forge/GOAL.peoplesspace.archive.md
