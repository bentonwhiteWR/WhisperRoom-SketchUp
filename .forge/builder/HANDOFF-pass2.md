# Handoff — pass 2 (plugin 1.9.3): the pictures are shippable

Builder, 2026-08-30. Everything was executed in **SketchUp 2026 / V-Ray 7** through
`scripts/sketchup-bridge.py --su 2026`, on a scratch **Untitled** model. SketchUp 2024 was
never touched. `P:` and `WhisperRoomQuote` were read only. Nothing was written to
`C:\Users\bento\Desktop\ProposalFiles\`. Provenance tagged throughout: **observed** /
**derived** / **reported** / **assumed**.

**Outcome, up front: PASS, with one honest reservation.** Five scenes, five files, 1200x900
in both lanes, no construction annotation anywhere, both V-Ray render rows landed at their
own exposure, and all five images pass the new automated image gate — which fails pass 1's
blown render by name. **The reservation: both renders ran out their six-minute time budget
rather than reaching the noise threshold, and the frames are still visibly grainy.** That is
better, not finished.

Outputs: `C:\Users\bento\Desktop\BridgeTest-pass2\`. Pass 1's folder is untouched at
`C:\Users\bento\Desktop\BridgeTest-2026-08-30\` for the before/after.

## Read first

1. **`.forge/builder/pass2-results.json`** — the deliverable. Every scene with its lane,
   path, pixels, bytes, wall clock, EV and image-QA numbers; the room, booth and light
   sections; the denoiser/sampler settings with what they cost; and the defect list.
2. `DEVLOG.md`, the 1.9.3 entry.
3. `scripts/image-qa.py`'s header — the gate, its two numbers, its profiles, and the
   calibration against Benton's own verdicts on pass 1's files.
4. The new comment blocks in `scripts/proposal-package.rb`: above `ev_for` (why `* 1.0` and
   not `.to_f`), above `annot_push` (why the client-safe hide is per row and not per batch),
   above `unit_vray_setup`, above `sidecars`, and inside `finish` (F3 and F10).

## The one-line version of each fix

| # | Was | Now |
|---|---|---|
| Exposure (D2) | one EV for the whole batch; the room view blew to white | per row, from the page, defaults EV 9 interior / EV 12 room, **the value used is in the run log** |
| Quality (D3) | stock sampler, denoiser off, nothing in the repo set either | denoiser on plus a sampler floor, written into the V-Ray scene, read back, restored |
| Client-safe (D5) | `WR-Notes` was in no tag list, so no mode ever hid the ceiling banner; draft mode shows dimensions by design | `ANNOT_TAGS = DIM_TAGS + WR-Notes`, hidden around **each export**; `annot: 'draft'` still gets the annotated version |
| Sizing (D4) | image height inherited the SketchUp window (1200 → 1200x475) | explicit `cfg['height']`; both lanes 4:3 from one Width field |
| D1 | fixed at 1.9.2, never run | **two five-row batches, two render rows each, every row landed both times** |
| F3 | `'unknown (never toggled)'` fell through the restore condition in silence | resolves to `MODE_FALLBACK` and says so in the log and the summary |
| Image QA | nothing had ever looked at a pixel | `scripts/image-qa.py` fails a row **by name** on mean luminance or clipped fraction |

## The four things worth knowing

- **`ISO` reads 100.0 — the key is `:ISO`, not `:iso`.** Pass 1 read `nil` and had to assume
  ISO 100, so its EV numbers were derived. They are now **observed**, and both passes'
  numbers stand.
- **The first client-safe design was written, run live, and FAILED.** Hiding the annotation
  tags once at the top of the batch is undone by the very next unit, `MODE -> DRAFT` — showing
  dimensions is draft mode's whole job, and the plan export came out fully annotated. Moving
  the hide after the mode unit fixes the picture and breaks something worse: `WR_Mode`
  snapshots live tag visibility when it *leaves* a mode, so the model would have memorised
  "draft means no dimensions" forever. The hide therefore brackets each **export**. Run 2
  proves it: the plan has no dimensions and no banner. **observed, both ways.**
- **The denoiser writes sidecars, and the saved frame is not the denoised one.**
  `<name>.denoiser.png` and `<name>.effectsResult.png` now land beside every render and
  nothing in the collision map plans for them — they are named in the row detail rather than
  silently left. Measured on 01 at 1200x900: mean neighbour-pixel difference **0.0444** in
  the saved `.png` against **0.0416** in `.denoiser.png`. `save_vfb_image` saves the RGB
  channel. Whether it can be pointed at the denoised channel was **not tried**.
- **F10's residual raiser fired.** `finish`'s closing `UI.messagebox` raised under a muzzled
  caller *after* every file was written, escaped into `step`'s rescue, ran `finish` a second
  time (mode restore twice) and left `@running` latched true on a completed batch. The latch
  now comes down first and the box is rescued. **observed live**, run 1.

## Assumptions

| # | Assumption | Provenance | What to change if wrong |
|---|---|---|---|
| 1 | `progressive_maxTime` is in MINUTES | **derived** — 6.0 was written and both renders ended at 358 s and 363 s, i.e. six minutes | if seconds, the budget is 100x too small and the renders were converging, not capped |
| 2 | The image-QA thresholds are the right line | **derived from observed** — tuned so the frames Benton called blown or clipping fail and the ones he called best pass | move `PROFILES` in `scripts/image-qa.py`; the calibration table is in its header and in the results JSON |
| 3 | Hiding tags around each export cannot poison a `WR_Mode` snapshot | **derived** — no mode transition occurs between a push and its pop, and the render rows' pop is in `finish` before the mode restore | if a future unit list puts a mode change between them, the push/pop must move with it |
| 4 | V-Ray does not render `Sketchup::Text` or dimension entities | **observed** — run 1's renders carried none even though the tags were visible at the time | nothing: the per-row hide now guarantees it either way |

## Open questions

- **The renders are still grainy, and both hit the time budget.** 0.01 was not reached in six
  minutes at 1200x900 on this machine. Nobody has measured what it *would* take, or whether
  a bucket sampler beats progressive here. That is the next quality question.
- **The saved frame is the RGB channel, not the denoiser channel.** One `save_vfb_image`
  experiment would settle it.
- **`Sketchup.file_new` on a dirty model raises a native modal the bridge cannot muzzle.** It
  blocked SketchUp for ~3 minutes in this pass; the bridge diagnosed it correctly (exit 4,
  "the likely cause is A MODAL DIALOG"). It was cleared by invoking the dialog's "No" button
  through Windows UI Automation — a named-button invoke, not blind keystrokes, and not the
  VFB or an HtmlDialog. **Stated as a deviation**: the pass was otherwise fully scripted. A
  bridge-side `file_new` muzzle would remove the need.
- **The ANNOTATION dropdown's markup was never exercised in a real `UI::HtmlDialog`.** Both
  batches ran with a stub dialog, so the Ruby side of `cfg['annot']` is proven live and the
  HTML is not.
- **There is still no glazing anywhere** — all 36 materials read alpha 1.0, so the booth
  window shows `[Color_I06]`, the interior panel colour. Library authoring question, reported
  not fixed, by instruction.
- **The room-to-booth light ratio is still ~8x** in design lumens (10,667 against 2,670).
  Per-row exposure works around it; it does not settle it. Reported not fixed, by instruction.
- **`build-room.rb` still builds no ceiling slab**, so V-Ray's sky lights every interior view.
  Unchanged from pass 1's D10.
- **`Float#to_f`, `Integer#to_i` and `NilClass#to_i` do not exist** in the barebones Ruby VM
  `rbparse.py` boots out of SketchUp's DLL (`(10.5).to_f` raises; `3.to_f` works). A `.to_f`
  in a pure method is a method that cannot be tested offline. Worth a line in CLAUDE.md.
