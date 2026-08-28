# Root cause — proposal-package.rb wrote empty frames of the wrong scene (28 Aug 2026)

Fixed at plugin **1.7.9**. Both defects are in `scripts/proposal-package.rb`.
**Nothing here was run in SketchUp** — no SketchUp and no `ruby.exe` on this machine.
Evidence below is tagged: **observed** (I ran/read it), **derived**, **reported**, **assumed**.

---

## Defect 1 — five empty framebuffers

**Symptom (reported by Benton, observed by the orchestrator with PIL):** five PNGs in
`Desktop\ProposalFiles\UTHealthSciences\`, each 1,271 bytes, 640x480, every pixel `(0,0,0,0)`.
mtimes spaced exactly 3.17 s apart.

**Root cause (derived from the source + Benton's observed state table):** the completion test
was `IDLE_STATE = /idle/i`. The full state vocabulary — **observed** live by Benton on
28 Aug — is `:idleStopped`, `:idleInitialized`, `:preparing`, `:rendering`, `:idleDone`.
Three of the five match `/idle/i`, and `sequence_ended?` (the backup signal) is `true` for all
three. So `classify_render` returned `:finished` for a renderer that had never started, on the
first poll past `START_GRACE_S = 3` — a blind time window standing in for a signal that did
not exist. 3 s grace + one 0.1 s tick ≈ the observed 3.17 s file spacing, which is the
strongest single piece of corroboration: **the timestamps are the bug's own clock, not a
render's.**

**Fix.**
- `IDLE_STATE` is now `/\Aidle/i` (the family) and `DONE_STATE = /\AidleDone\z/i` is the only
  value that means a frame exists.
- `classify_render(state_val, seq_ended, seen_running)` — **still pure**, the latch threaded in
  as an argument. Returns `:running` / `:finished` / `:idle` / `:unreadable`.
- The poll loop owns `@seen_running` (set the first time a row reads `:running`) and
  `@idle_since`.
- Never latched and `START_WINDOW_S = 30` s elapsed -> **fail the row by name**, "the render
  never started". 30 s is ~68x the **observed** 440 ms lead-in and far under
  `RENDER_TIMEOUT_S`.
- Latched, then idle-but-not-done for `STOP_CONFIRM_S = 10` s -> fail by name, "stopped or
  cancelled". No such transient appears in the observed watch; 10 s is margin against one.
- `:unreadable` / `UNREADABLE_LIMIT` / `RENDER_TIMEOUT_S` behave exactly as before.
- `in_process?` / `dr_enabled?` are still never called anywhere in the file (**observed** by
  grep).

## Defect 2 — the render showed the previous scene

**Symptom (observed by Benton):** with ONLY "Overview R" marked Render, the V-Ray frame buffer
rendered the "Room1R" view.

**Root cause (derived; the mechanism is confirmed against the code, the 0.22 s figure is
reported from Benton's V-Ray log).** `unit_render` did:

    model.pages.selected_page = p[:page]
    model.active_view.refresh
    ... rend.start

`selected_page=` starts a camera **animation** over `PageOptions['TransitionTime']` — 1 s by
default. V-Ray logs `"Exporting model: Done (0.2201505 seconds)"`, i.e. it snapshots the
camera roughly 0.22 s after `start`. The camera has moved ~22% of the way, so the export
frames something very close to the PREVIOUS scene. `view.refresh` draws a frame; it does not
wait out a transition. Nothing in the file touched `PageOptions` (**observed** by grep).

**Why the image lane never showed it (observed):** `export-scenes.rb`'s `export_pages` sets
`page_opts['TransitionTime'] = 0` around its loop and restores it in an `ensure`, with the
comment *"else write_image can catch a tween"*. The answer was already in the repo, in the
lane that worked.

**Fix.**
- `start_run` saves `PageOptions['TransitionTime']` and sets it to **0** for the whole batch.
- `finish` restores it **after** its own `selected_page` / `camera` restore, so those two are
  instant as well, and a failed restore joins `restore_errs` like every other leak.
- `unit_render` sets `model.active_view.camera` from `p[:page].camera` directly after the
  scene switch.
- It then **asserts**: `cam_mismatch(cam_tuple(view.camera), cam_tuple(page.camera))`, judged
  as position (eye/target/up, tolerance 0.01") and lens separately. A position mismatch
  **fails the row by name** and renders nothing. A lens-only difference is a warning —
  `/CameraPhysical` may carry its own fov (open question 7), and failing on that would block
  every row over something that is not this bug.
- A scene with no saved camera warns and renders the current view.
- `cam_mismatch` is **pure** and unit-tested; `cam_tuple` is the impure half.

## Also — the 640x480

That is the V-Ray Asset Editor's output size. The dialog's `WIDTH` field only reaches the
image lane (`WR_ExportScenes.export_pages`). No documented, safe way to set V-Ray's size from
Ruby was found, so **nothing was invented**: `warn_output_size` logs the size before the first
render row if `/SettingsOutput`'s `img_width`/`img_height` can be read (**reported** parameter
names, never observed — every hop is `respond_to?`-gated and rescued, and reads only), and
logs a louder warning naming the 640x480 default when it cannot.

## Verification (all offline)

- `python scripts/rbparse.py` — **56 files parse** (real CRuby 3.2 parse). Observed.
- `python scripts/rbtest-proposal.py` — **34 assertions PASS**. Observed. Extended with the
  latch, `:idleDone`-only, a renderer that reports idle forever (1000 polls, never finished),
  the full cold->preparing->rendering->done sequence, and six `cam_mismatch` cases.
- Mutation-checked (observed, each reintroduced bug makes it FAIL):
  - any `/idle/` state finished, no latch (the old code) -> cases 1, 2, 6, 7, forever, seq
  - latch ignored on `:idleDone` -> case 6
  - `cam_mismatch` tolerance widened to 99 -> cam3, cam4

## What is NOT proven

Runtime behaviour. Nothing in this repo can execute SketchUp or V-Ray. In particular:

1. That `PageOptions['TransitionTime']` is settable to 0 from this context (**reported** — the
   image lane does it, so it is well corroborated, but that path has run and this one has not).
2. That `view.camera = page.camera` leaves `view.camera` reading back **equal** to
   `page.camera`. If SketchUp re-derives fov from the viewport aspect, the lens warning fires
   (harmless by design). If it perturbs eye/target/up, **every render row will fail by name** —
   loud, not silent, but it would block the batch.
3. That `/SettingsOutput` / `img_width` exist. If not, the tool logs the louder warning.
4. That the latch ever sets: it depends on a poll landing while `state` is `:preparing` or
   `:rendering`. **Derived** from the observed timing (440 ms lead-in, 5m26s render, 0.1 s
   tick) this is near certain, but if V-Ray ever went start -> `:idleDone` inside one tick the
   row would fail with "the render never started" rather than saving anything. Safe direction.
