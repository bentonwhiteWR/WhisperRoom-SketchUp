# Fixer handoff — 2026-08-28, plugin 1.7.9

## Produced
- `scripts/proposal-package.rb` — the two live render-lane defects fixed:
  `:idleDone`-only completion **with a latch** (empty frames), and a **settled camera**
  before `start` (wrong view). Plus a loud output-size warning before the first render row.
- `scripts/rbtest-proposal.py` — extended: 14 classifier cases, an idle-forever loop, the
  full happy sequence, six `cam_mismatch` cases. 34 assertions, all passing, mutation-checked.
- `reference/vray-ruby-api.md` — open question **2 ANSWERED** (full state table + timings),
  question **7 half answered** (the render follows the active view at export time), and the
  old "matches /idle/i is finished" advice replaced where it appeared.
- `scripts/wr_tools/VERSION` -> **1.7.9**.
- `DEVLOG.md` — 2026-08-28 entry.
- `.forge/fixer/ROOTCAUSE-empty-frames-and-wrong-view-2026-08-28.md` — full write-up.

## Read first
- `.forge/fixer/ROOTCAUSE-empty-frames-and-wrong-view-2026-08-28.md` — especially its
  **"What is NOT proven"** section before the next live run.
- The completion-classification and camera-settling comment blocks in
  `scripts/proposal-package.rb` — they carry the observed evidence inline.

## Assumptions
- `PageOptions['TransitionTime'] = 0` works from a batch context — **corroborated**, it is
  what the working image lane does, but not run on this path.
- `view.camera = page.camera` leaves the viewport camera reading back equal to the page's.
  If it does not, every render row fails **by name** ("camera never settled") — loud, but it
  blocks the batch. This is the single most likely way the fix misfires.
- `/SettingsOutput` with `img_width` / `img_height` are the V-Ray names. Reported only; a
  miss just produces the louder "could not read" warning.
- `STOP_CONFIRM_S = 10` assumes no legitimate idle transient between `:preparing` and
  `:rendering`. None appears in the observed watch.

## Open questions
- Does the latch ever fail to set on a very short render? Watch the log for
  `render started` on every row.
- Does `/CameraPhysical` override the fov? That is why a lens-only difference warns instead
  of failing. If Benton sees correct framing with a lens warning, the warning can be dropped.
- Can V-Ray's output size be set from Ruby at all? Not attempted — nothing invented.
- Unrelated, spotted not fixed: `wr-preflight.rb` / `wr-mode.rb` / `wr-pack-export.rb` still
  use the `$wr_no_autorun` global-temp idiom that caused the 27 Aug dead button.
