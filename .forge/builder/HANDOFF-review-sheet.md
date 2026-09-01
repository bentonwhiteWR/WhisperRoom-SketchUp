# HANDOFF — review sheet: photo comparison, 3D views, structured patch (1.12.2)

## Produced
- `scripts/takeoff-check.py` — the `--html` sheet now carries: source photo
  beside a pen-callout→value ledger per room (photos only via
  `--embed-photos`, default OFF, downsampled 1600px, EXIF ignored on
  purpose — flat-lay tags are wrong on all three UIC photos); a rotatable
  WebGL 3D view per room built from the lock (drag/wheel/arrows/R, labels in
  a screen-space overlay, ASSUMED values in warn colour); per-room APPROVE /
  NEEDS CHANGES; click-to-edit values that refuse to save without a source;
  a copy box emitting a structured JSON patch. New `--apply-patch` consumes
  that patch (refuses stale `old`, missing src, unknown field, wrong job;
  rewrites takeoff.json only when clean; re-runs the full check). Theme CSS
  fixed in the generator for all three artifact viewer states. Lock now also
  carries `*_src` on feature dims (additive; build-takeoff.rb unaffected).
- `reference/takeoff-format.md` — new "review sheet and the patch" section.
- `clients/uic-daley-library/takeoff.review.html` — regenerated WITH photos
  embedded (gitignored; the publishable copy).
- Selftest: +8 patch cases. Page `#autotest` fragment drives the edit path
  headlessly and dumps the patch into the DOM.

## Read-first
- `reference/takeoff-format.md` (patch shape), then the `--apply-patch` and
  `JS` blocks in `scripts/takeoff-check.py`.

## Assumptions
- EXIF orientation is untrustworthy on flat-lay plan photos; raw pixel
  orientation is embedded. A future sideways photo is loud and cosmetic.
- Bulkhead 3D massing spans the room's full extent along the run's inward
  normal (right for rectangular G+H; an L-room bulkhead would overreach —
  massing only, flagged here).
- Run edits via patch drop any old `parts` chain (documented in the format).
- Approval status is echoed by `--apply-patch` but not stored in
  takeoff.json — it is workflow state, not measurement.

## Open-questions
- Whether the PUBLISHED artifact should carry the photos is cleared for UIC
  (Benton, 31 Aug) but is a per-client decision — keep `--embed-photos`
  explicit.
- 3D labels can overlap at certain angles in dense rooms (G+H); rotation
  resolves it. Leader lines would fix it if it ever annoys Gabe.
- Working tree is shared with the eval-loop Builder; this commit includes
  only the files above plus VERSION/DEVLOG.
