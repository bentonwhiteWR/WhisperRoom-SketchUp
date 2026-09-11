# GOAL

## Mission
Make the proposal package a ONE-STOP SHOP. Benton, 10 Sep 2026: "I'd like to find a way
to auto set the entire proposal package... select the WhisperRoom, then it would make
scenes and label them accordingly. This way it can be clicked a 2nd time on a 2nd booth...
it would get a handful of shots, with a few of them being assigned as renders... would
properly go through and hide walls or set it as image or render. Almost do all of the
work, and just have you review it before you export."

## The gap today (observed 10 Sep 2026)
- scripts/proposal-scenes.rb builds five FIXED plates named 01-exterior .. 05-plan, with
  no booth selection and no per-booth naming, so a second booth collides with the first.
- Nothing assigns Skip / Image / Render per row; Benton sets each by hand.
- Nothing presets the per-scene WALLS picker (wr-scene-walls.rb) or the ANNOTATIONS
  picker (wr-scene-annotations.rb, 1.20.0) — both exist and both are per-scene.
- Plugin is at 1.47.0; client-safe annotation mode was removed at 1.47.0, so the
  per-scene ANNOTATIONS picker is now the ONLY authority on what an image shows.

## Done means
- A ranked, iterated Scoper spec for a booth-driven auto-setup: pick a booth in the
  model, get a named scene set for THAT booth, repeatable for a second booth without
  collision, each scene pre-assigned image/render with walls and annotations preset.
- The spec says how it lands INSIDE the proposal package, not beside it.
- A clickable Artifact showing the pre-filled proposal grid for Benton's review, with
  approve/edit controls and a copy-back box.
- The artifact link emailed to bentonwhite92@gmail.com.
- No production Ruby until Benton approves the artifact.

## Now
AUTO-SET is BUILT and pushed (1.48.0) — scripts/wr-autoset.rb, plus the AUTO-SET bar and
the per-row WALLS/ANNOTATIONS review columns in proposal-package.rb. Q1 = 2 renders (a
knob), Q2 = plate 3 is a FRONT elevation with the door open. Offline proof is done
(rbparse 75/75, rbtest-autoset 63 checks, jstest PASS, 13 mutants killed by name).
NOT YET VERIFIED LIVE: Benton runs .forge/builder/verify-autoset.rb in an Untitled model
and pastes the output back. Until then nothing about real pages, the stamp surviving a
re-run, or the measured cost of the review columns has been observed.

## Out of scope
- Sun presets (Q4), hiding the other booth (Q5), writing proposal-v2.json from the model.
- Changing what the WALLS or ANNOTATIONS pickers do; this drives them, not replaces them.

## History
- Per-scene ANNOTATIONS column shipped 1.20.0, verified live 9 Sep 2026 (30/30 checks).
- PeoplesSpace alcove take-off — .forge/GOAL.peoplesspace.archive.md
