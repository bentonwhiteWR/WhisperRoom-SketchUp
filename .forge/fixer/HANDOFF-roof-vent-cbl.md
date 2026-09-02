# HANDOFF — roof-mounted ventilation, the wall half (plugin 1.12.11)

## Produced

- `scripts/booth-from-link.rb` — the `CBL` branch in `component_for`, the
  `RM_HALF_APPLY_ABORTS` fence (`vent_slot_ids`, `cbl_pack`,
  `roof_vent_complaints`), the corrected console message, a `Cable wall` row in
  the placement summary, and an autorun now guarded like every other tool
  script's.
- `scripts/rbtest-boothlink-cbl.py` — offline regression test, 22 checks,
  mutation-checked.
- `.forge/fixer/roof-vent-cbl/repro-rm-cbl.py` — the live reproduction. Three
  modes: default, `--enh`, `--half`. Re-runnable, self-contained, cleans up
  after itself.
- `.forge/fixer/roof-vent-cbl/NOTES.md` — symptom, root cause, before/after
  evidence.
- `.forge/fixer/roof-vent-cbl/out-std.txt`, `out-half.txt` — the passing
  console transcripts.
- `DEVLOG.md` entry, `scripts/wr_tools/VERSION` at 1.12.11.

## Read first

1. `.forge/fixer/roof-vent-cbl/NOTES.md`.
2. `scripts/booth-from-link.rb` — the module header (the `CBL` paragraph and
   the roof-mount paragraph) and `RM_HALF_APPLY_ABORTS`.
3. `.forge/researcher/roof-mount-ventilation.md` §6 for the risks this fix
   closes (R1, R3) and the ones it does not (R4 model gating, R5 VSS naming,
   R6 HX, R7 the portal's ceiling-height under-report).

## Assumptions

- **observed:** the reproduction and all three passing modes, run live in
  SketchUp against an Untitled model; the eight `*PanelCBL*.skp` files on
  `P:/Sketchup/NewMasterComponentList`; the agreement, on all 50 layout keys,
  between the outer-shell `:sk => 'VNT'` slot count and the catalogue's `vents`
  figure.
- **derived:** that an Enhanced roof-mount link was previously refused outright
  by `ENH_MISSING_ABORTS` rather than mis-built. It follows from the code path
  and matches the Researcher; it was not run before the fix.
- **reported:** the portal-side behaviour of `applyRoofVent`, `rmSupported` and
  the `rv` payload shape — read from `booth-builder.html` by the Researcher and
  spot-checked here, not exercised in a browser.
- **not checked:** every model other than `MDL 7272`. The translation is width
  driven and the only vent-capable widths are 40 and 46, so the coverage is
  believed complete, but only 7272 was built.

## Open questions

1. `.forge/GOAL.md` still lists `rv` as out of scope, and
   `scripts/booth-from-link.rb` no longer cites the GOAL as its reason. That
   line is stale; an owner should edit it. **Not edited here, by instruction.**
2. The roof unit is unbuilt and blocked on Benton's measurement: is
   `RM<model>.skp` one complete assembly, and where does it seat? When it
   lands, extend `roof_vent_complaints` to assert a roof set per former vent
   slot — the fence covers only the wall half today.
3. `4230 / 4242 / 4848` have no RM part and the portal will not emit `rv` for
   them. A hand-edited link that does is not specifically refused; it would
   build cable walls and no roof unit. Worth a named refusal when the roof work
   lands, not before — a size table added now could drift.
4. Pre-existing, unrelated: `scripts/rbtest-lights.py` fails, identically with
   and without this change (verified by stashing). Left alone.
