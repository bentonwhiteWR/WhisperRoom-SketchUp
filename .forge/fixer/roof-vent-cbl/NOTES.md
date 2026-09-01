# Roof-mounted ventilation built the wrong walls — reproduction and fix

Fixer, 2026-08-31. Provenance words are the Manual's: observed / derived /
reported / assumed.

## Symptom

A booth-builder share link with roof-mounted ventilation (`rv=1`) built a booth
with **vent walls** instead of the **cable walls** such a booth actually ships
with, and said nothing about it. The only line the console printed on the
subject was

    rv: roof-mounted vent (out of scope per GOAL)

which reads as "we skipped the roof unit", not "we drew walls the customer is
not buying".

## Root cause (one sentence)

`booth-builder.html`'s `applyRoofVent()` rewrites every ` VNT` pack to ` CBL`
before the link is serialised, and `scripts/booth-from-link.rb`'s
`component_for` had no `CBL` branch, so the pack was untranslatable, the slot
was left unassigned, and `build-booth-components.rb`'s `guess_component`
refilled it from the layout's own `:sk => 'VNT'`.

## Reproduced, live, before any change (observed)

`repro-rm-cbl.py` builds an `MDL 7272 S` roof-mount design from a
self-contained `#d=` link inside the running SketchUp, reads back the component
that landed on each of the two vent slots, and erases everything it created by
entityID.

    slot N0   built as 46VNT
    slot E0   built as 46VNT
    FAIL — the roof-mount booth built the wrong walls

The wrongness went further than the panel: `wr-overlays.rb` keys duct covers on
the assigned component's name, so the run also placed **four duct covers** on a
booth whose ducts are on the roof (31 component instances placed).

## After the fix (observed, all three modes)

    (default)  N0 46PanelCBL, E0 46PanelCBL                            PASS
    --enh      N0/E0 46PanelCBL, N0i/E0i ENH 41.5PanelCBL              PASS
    --half     nothing built; refused by name                          PASS

The duct covers went with the vent walls, unprompted — the overlay pass now
prints `DUCT COVERS: no qualifying 40/46 in vent walls on this booth.` and the
instance count drops 31 -> 27. Every run reported `model path ''` and
`entities left behind after the erase []`.

## Model safety

The guard is inside the Ruby job, before any geometry, in the same
single-threaded execution as the build. It fired for real during this work:
between two runs minutes apart the active model became
`Z:\Sketchup\BoothBuilderClaude\Master Component List.skp` and the job refused
by name rather than building into it (observed). That is exactly the hazard
`.forge/GOAL.md` describes, and it happened twice in one session.

## Notes for whoever builds the roof geometry

- The roof unit is still not placed. `RM<model>.skp` exists on the share; where
  it seats is not sourced. Do not invent it.
- When it does land, extend `roof_vent_complaints` so the fence also asserts a
  roof set was placed per former vent slot. The half-apply it guards today is
  the wall half only.
- `rv` is a bare `0|1` and is the ONLY thing that says roof-mounted. A cable
  wall is a legitimate product on its own; never infer roof mounting from CBL
  packs.
- Pre-existing and not touched: several IEP parts, `ENH 41.5PanelCBL` among
  them, report `NOT FOUND` in the builder's panel-search column and a width a
  fraction over nominal (`+0.2500`). `ENH 41.5PanelSolid` and
  `ENH 17.5PanelSolid` do the same, so it is a part-authoring matter, not a
  consequence of this fix (observed).
