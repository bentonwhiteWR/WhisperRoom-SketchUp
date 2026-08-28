# HANDOFF — showroom interior lighting design (2026-08-27, second lighting pass)

## Produced

- `.forge/researcher/interior-lighting-design.md` — the lighting-design grounding with
  citations (layers, spacing arithmetic, wall wash, fc/lumen targets, CCT, the exposure
  finding), the placement algorithm over `build-room.rb` geometry (polygon grid, keep-outs,
  L-shapes, open-top rooms, booths), the four seed components Benton authors, the pop-up
  settings split (four settings + one checkbox vs. things that are just right), the
  failure-case table, and a ready-to-paste probe that decides whether the pop-up's
  Brightness/Warmth/exposure controls can be real.
- This file. Nothing else created or modified; the pass was read-only outside
  `.forge/researcher/`.

## Read-first

1. `.forge/researcher/interior-lighting-design.md` — the whole finding. Scoper: §3.2 is the
   dialog contract and it FORKS on the §3.3 probe result — do not commit the pop-up before
   the probe runs. Builder: §2 is the algorithm, §3.4 the refusal table.
2. `.forge/researcher/interior-lighting-options.md` — still the mechanism ruling (seed
   component, no V-Ray light API); only its placement half (one troffer per bbox) is
   superseded.
3. `scripts/wr-drop-lights.rb` — the baseline being replaced; its idempotence, tagging,
   refusal-by-name, and active_entities/containment machinery carry over unchanged.
4. `scripts/build-room.rb:137-151, 382-400` — the polygon and group structure the
   algorithm queries (Floor face on WR-Floor, walls to `ceil`, NO ceiling slab ever).

## Assumptions

- CU = 0.6 in the lumen arithmetic; DROP = 6"; keep-out inflation 12" and the "top above
  mount plane − 18"" obstruction rule; washer lumens = ½ downlight; accent tilt 35°;
  washer standoff 24". Each is one constant, labelled assumed in the report.
- The probe's V-Ray parameter key names (`:intensity`, `:temperature`, …) are guessed from
  `.vrscene` conventions; the probe prints errors rather than failing if they are wrong.
- Every V-Ray behavioural claim (lumens-unit semantics, EV defaults, invisible flag,
  shared-asset sliders, the export-wipe risk) is reported from docs/community — no render
  has been observed from this machine.
- "Showroom" illuminance = 40 fc default, chosen inside the sourced 30–80 fc retail band.
- Booths are recognized as obstructions by bbox/height and as booths by name; the exact
  name-match rule against the booth scripts is left to the Builder to pin.

## Open-questions

1. **Run the §3.3 probe** (model with one hand-made rectangle light: cold → render → run →
   render again). It decides: (a) do light plugins surface in `context.scene`, (b) are
   intensity/temperature writable via `scene.change`, (c) does a write survive the next
   export, (d) is `/CameraPhysical` exposure writable. Path (a-yes/writable/survives) makes
   the pop-up's Brightness/Warmth/exposure real; otherwise those become printed Asset
   Editor advice plus three per-seed sliders. Benton is at the desk — this is the one
   blocking unknown.
2. Benton authors the seeds in `scripts/vray-seeds/`: `WR Light Downlight.skp` (12×12,
   3000 lm), `WR Light Wallwash.skp` (6×24, 1500 lm), `WR Light Booth.skp` (12×24,
   1000 lm), optional `WR Light Accent.skp` (12×12, 6000 lm, directionality ~0.5) — all at
   origin, facing down, Luminous Power units, 3000K, Invisible ON. The earlier
   `WR Interior Light.skp` spec is superseded (report §3.1 says how it maps if already made).
3. Does an accent light tilted 35° render acceptably as a Rectangle Light, or does the
   booth-face accent want an IES/spot asset instead? Unverifiable without a render; the
   layer is optional and last.
4. Does sun/environment light through the open room top fight the rig at interior EV
   (~8)? Expected tolerable (reads as skylight); one test render settles it.
5. GOAL.md item 5 still describes the superseded "one button, no lighting-designer UI"
   tool and the `WR Interior Light.skp` authoring item — the GOAL owner should reconcile
   it with this brief once the Scoper commits.
