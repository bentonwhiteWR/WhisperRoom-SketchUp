# Handoff — first full end-to-end run (plugin 1.9.2)

Builder, 2026-08-30. Room → booth → lights → scenes → proposal package, all in one
**Untitled** scratch model in **SketchUp 2026 / V-Ray 7**, driven through
`scripts/sketchup-bridge.py --su 2026`. SketchUp 2024 was never touched. No client work was
opened. `P:` and `WhisperRoomQuote` were read only. Provenance tagged throughout:
**observed** / **derived** / **reported** / **assumed**.

**Outcome, up front: partial, and the pictures are not shippable.** Geometry, lights and
scenes are clean. Three plain image exports succeeded. One V-Ray render produced a file and
it is blown out and noisy; the second render row was silently lost to a defect found during
the run. Five ranked defects remain open. The run's real value is the defect list.

## Produced

| File | What changed |
|---|---|
| `scripts/proposal-package.rb` | six fixes — see below |
| `scripts/rbtest-proposal.py` | classifier cases 14 → 20 (the five documented V-Ray states never seen live) |
| `scripts/wr_tools/VERSION` | 1.9.1 → **1.9.2** |
| `DEVLOG.md` | 1.9.2 entry |
| `.forge/builder/endtoend-results.json` | the machine-readable record: every scene, timing, setting, and all 12 defects |
| `C:\Users\bento\Desktop\BridgeTest-2026-08-30\` | 4 output images + `exposure-bracket/` (7 frames) + `_coldtest.png` |

Nothing was written to `C:\Users\bento\Desktop\ProposalFiles\`.

## Read first

1. **`.forge/builder/endtoend-results.json`** — it is the deliverable. Defects D1–D12 with
   severity, status, and the evidence for each.
2. The new comment blocks in `scripts/proposal-package.rb`: above `ERROR_STATE` (F1), above
   `self.step` (the re-entrancy story with the live log), inside `unit_render` (why
   `render_production` and not `start`), above `save_frame` (F4), and above `output_size`
   (which `/SettingsOutput` governs).
3. `DEVLOG.md`, the 1.9.2 entry — the exposure bracket table is there.

## The three things worth knowing

- **`renderer.start` renders an empty scene.** It engages fine cold with `sync: true`, but
  nothing exports the model into the renderer, so it produces a 429-byte black frame in
  0.6 s. `VRay::Command.render_production(context:)` exports first and produces a real
  image. That closes the 28 Aug "five empty frames" question: the renders ran, on nothing.
  **observed**, three times each.
- **`step`'s `return if @in_step` guard exited through the method-level `ensure` that
  cleared the flag**, so the guard unlocked itself. `render_production` pumps the message
  loop, a nested tick dispatched the next render row, and row 04 was rendered and thrown
  away while the batch reported "4 exported, 0 skipped, 0 FAILED" on a 5-row plan.
  **observed** in the dialog log. Fixed; **not re-run live**.
- **No single exposure works for both a room view and a booth interior of this rig.** EV 9
  is right for the booth interior and blows a room shot to white; EV 12 is right for the
  room and leaves the booth dark. Set via `scene['/CameraPhysical'][:shutter_speed]` inside
  `scene.change`, `EV100 = log2(f_number² × shutter_speed)`; `:exposure_value` reads 0.0 and
  is not used. **observed**, seven bracket renders on disk.

## Assumptions

| # | Assumption | Provenance | What to change if wrong |
|---|---|---|---|
| 1 | `EV100 = log2(f_number² × shutter_speed)` with an implicit ISO 100 | **derived** — the formula reproduces V-Ray's documented 14.2 default from the observed f/8 @ 1/300, and every bracket step moved brightness the predicted direction | if `:iso` (reads `nil`) is not 100, every EV number here shifts by a constant |
| 2 | The blue glows are lit wall geometry, not visible emitters | **derived** — all 8 plugins read `invisible => true`, and projecting the widget origins onto scene 01 puts every one near the top of frame, not at the glows | an A/B render with the lights deleted would settle it; it was not run |
| 3 | `render_production` re-exports `/SettingsOutput` from the scene on every call | **observed once** (renderer 400×300 + scene 1200×900 → a 1200×900 PNG) | if it is conditional, the render lane needs to write both copies |
| 4 | The D1 fix holds | **derived** — code reading plus 40 offline checks. The batch was never re-run after it | re-run a 2-render batch and confirm both rows land |

## Open questions

- **Row 04 was never re-rendered.** The re-entrancy fix is unproven live. That is the single
  cheapest next test: a 2-row render batch, both rows must produce files.
- **The F1 `:fatalError` fix never fired** — no render reached an error state. Offline only.
- **The image lane and the render lane size images differently.** `export-scenes.rb:164`
  derives height from `view.vpheight / view.vpwidth` (1200 → 1200×475 this session); the
  render lane sets `img_width`/`img_height` explicitly (1200×900). One package, two shapes.
- **Nothing in this repo sets a sampler value, a time budget, or a denoiser.** All stock.
  That is the speckle, and it is unowned in exactly the way exposure was.
- **`WR-Notes` is not in `DIM_TAGS`**, so no mode ever hides the "Ceiling 8'-0" — HOUSE
  DEFAULT" banner. A client-safe pass must hide `WR-Dims`, `WR-Dims-Doors`,
  `WR-Dims-Booth`, `WR-Dims-Selection` **and** `WR-Notes`.
- **`build-room.rb` builds no ceiling slab**, so V-Ray's sky lights every interior view and
  is visible above the wall tops. Until that is decided, interior exposure cannot be
  calibrated cleanly.
- **F3 confirmed live**: `WR_Mode.current` returned `'unknown (never toggled)'`, so `finish`
  skipped the mode restore in silence and left the model in RENDER mode.
- **The Asset Editor was never opened**, so F9's 1600 → 2400×1350 mystery is untouched.
- **There is no glazing anywhere in the model.** All 30 materials read `alpha 1.0`. The blue
  rectangle at the booth window is `[Color_I06]` RGB (0,0,204) — the library's interior
  panel colour seen through an unglazed opening.
