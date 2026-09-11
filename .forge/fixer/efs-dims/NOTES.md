# EFS dimensions — root cause and evidence (11 Sep 2026, plugin 1.54.0)

## Symptom (reported)

Benton, on a booth with a caster plate and exterior fan silencers:
"the dimension tool is not currently accounting for the EFS. The dimensions
should extend 10" total from the booth corner on booths with EFS."
Screenshot `benton-cp-efs-screenshot.png`: height `7' 5 1/16"` (correct,
1.49.0 CP datum — not touched), plan strings `12' 7 1/2"` and `8' 7 1/2"`.
Those are 146 + 5.5 and 98 + 5.5: a 96144 E with vents on two walls, each
string stopping 5 1/2 in past the shell — the vent box — while the silencer
housings on the end wall stand further out.

## Root cause (observed in code, reproduced offline)

`scripts/dimension-whisperroom.rb`, the 1.42.0 rule in `vent_box_level` /
`vent_box_bound`: a wall part's extent along its wall normal is the outboard
face level carrying the MOST area; anything further out is "a fitting,
reported and not counted", and the bound moves inward from the assembly box
to that level. On an EFS part the silencer box's outer face (a 10 x 22 box,
~220 sq in) always loses the area vote to the vent-duct faces (~1800 sq in),
so it is set aside as a fitting on every EFS wall.

`repro-efs-trim.py` (`repro-BEFORE.txt`): faces 97/98 panel, 103.5 vent box
(1800), 108.125 silencer (220), assembly edge 108.125 →
`beyond it: [[108.125, 220.0]]`, E bound 103.5, width 103.5.

**Wrong rule, not a missing input.** The tool already reads EFS off the part
name (`vents_from_names`, `/EFS/i`) — booth-from-link.rb composes `_EFS`
into every Standard-shell vent part, and an Enhanced booth's OUTER shell is
Standard parts — but used the flag only for a console line.

## Which "10"

Three readings of "10 total from the booth corner" were possible:
(a) +10 on the overall run, (b) 5 at each end, (c) the EFS face landing 10
past the shell corner in place of the vent box's 5.5. Taken: **(c)**.
- "total" reads naturally as "instead of the 5.5, not on top of it".
- The quote tool draws exactly that: `layout-render.js` `EPROT = EFS ? 10 :
  VPROT` "how far the vent assembly reaches", and `tdVentImg(..., (EFS ? 10
  : VPROT) + PROUD_IN)` to reach "the published 5.5″ (10″ with EFS) past the
  line" (observed).
- A booth has one or two vented walls; each vent part pushes only its own
  wall's bound (1.40.0), so (b) — growing both ends of a run — has no
  geometry to stand on.

**The clearance trap.** CLAUDE.md's "Vented wall 6 in, or 10 in with EFS" is
`clrIn` in the same renderer — air against a room wall, a different
quantity. A plain vent is 5.5 reach / 6 clearance; with EFS the two happen
to coincide at 10. The dimension tool encodes neither: it measures the part.
The only 10 added is `EFS_PROUD`, a cross-check figure printed beside the
measured one, the same status as `VENT_PROUD` 5.5.

## What the part actually measures (the open number)

- **observed** — `Z:/Sketchup/NewMasterComponentList/_component-probe.tsv`
  (probe-components.rb inside SketchUp, 26 Aug 2026): every 46-series EFS
  variant (`46VNT_EFS`, `46VNT_VSS_EFS`, `46Vnt_EFS_CP`, `46Vnt_VSS_EFS_CP`)
  is **12.1250** thick; plain `46VNT` 8.5468, `46VNT_VSS` 8.6003. The 40
  family: 12.1250 / 12.3066 / 12.0986 against 8.5468.
- **derived** — the builder seats the panel found inside a thick part on the
  1 in slot band, whose outer face is 1 in inside the seal line (published
  dims = panel + 2). Reach past the seals = 12.125 − 1 (panel) − 1 (seal)
  = **10.125** IF all of the extra bulk is outboard. A plain vent by the
  same arithmetic reaches 6.5468, i.e. the 5.5 box plus ~1 in of collar —
  which is what 1.42.0 trimmed off.
- **conflicting record** — DEVLOG 1.42.0: on a 7296 E carrying
  `46Vnt_VSS_EFS_CP` parts the untrimmed 1.40.0 tool drew `8' 8 7/16"`
  (104.4375 on a 98 shell = 6.4375 past), and Benton then said those
  strings "should be 8'7.5" x 6'7.5"" — the 5.5 figure, on an EFS booth.
  Today's instruction reverses that for EFS parts. Both cannot hold; the
  newer one is drawn, and the console now prints the vent box level, the
  assembly edge and the inches between them on every EFS part.
- The probe TSVs carry z levels only, so the thickness-axis faces of an EFS
  part have never been read offline. `verify-efs-dims.rb` reads them live
  and reports the reach past the seals by name; a reach outside 10 ± 1/4 is
  a FAIL that carries the real number, which is the answer Benton needs.

## Fix

`measure_to(name, edge, res, out_sign)` in the PURE section: an `_EFS` part →
`[edge, :assembly]`; any other wall part → the 1.42.0 vent-box trim
(`[res[:box], :vent_box]`, inward only); no faces → `[edge, :box]`.
`vent_box_bound` calls it and records `:level` / `:rule`. `catalogue_extent`
takes an optional per-face EFS list (`efs_faces_from_names`) and expects
`EFS_PROUD` 10 there. Console: an `EFS:` line per part with both levels.
Per-wall by construction: only the EFS wall's own axis grows.

## Proof

- `repro-AFTER.txt`: E bound 108.125, width 108.125, N wall untouched.
- `suite-AFTER.txt`: `rbtest-boothdims.py` 147 → 148 checks, 0 failures.
  The CP fixture now feeds RAW assembly boxes through `measure_to` the way
  `dimension()` does — the old fixture hand-trimmed them to 103.5/79.5,
  which is why the suite was blind to this fault.
- `mutants.txt`: measure_to ignoring `efs_part?` → 7 failures;
  `efs_faces_from_names` → [] → 3 failures. Tool restored byte-identical.
- `rbparse.py` (the real CRuby parse) clean on every script and on
  `.forge/builder/verify-efs-dims.rb`.
- **UNRUN in SketchUp.** No ruby.exe, no bridge.

## Values in the fix that are not measured

- `EFS_PROUD = 10.0` — cross-check only, never drawn (quote tool EPROT +
  Benton's words).
- The fixture's 108.125 / 84.125 — derived from the probe thickness as above.
