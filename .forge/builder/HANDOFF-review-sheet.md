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

## Judgement — the clear-width residual (synthetic-clearwidth-trap)

The trap is real and my checker does not catch it: a 15'-0" clear width
transcribed as the wall width with no parts chain and no declared
obstructions is internally consistent, so it validates clean and builds a
plausible room 24" too small. **No invariant over a single-source take-off
can close this** — a validator checks consistency, and a lone wrong number
is consistent. What would actually close it, sized:

1. **Vector-PDF cross-check (the real fix — a full Builder slice, ~a day).**
   The only mechanical second measurement source. On S609-3 the PDF vectors
   reproduce the field measurements to 1–2" from one anchor. Shape: scale
   the PDF line geometry from the take-off's named anchor (PyMuPDF), match
   each run to its nearest parallel wall-line pair, refuse by name above
   ~3" disagreement. Hard parts are wall-face identification among
   furniture/fixture linework and rotated plans. Make the pass REQUIRED
   whenever `sources` lists a vector PDF/DWG — "the exact geometry was in
   the job folder and nothing pointed at it" was a named 31 Aug root cause.
   `eval/gen-plans.py` already emits vector PDFs derived from authored
   truth, so the loop can score this the day it exists.
2. **Cheap interim guard (an evening, not built — out of my scope order):**
   fail, or loudly flag, any job whose `sources` list a `.pdf`/`.dwg` while
   no value carries a `plan-vector` src. It validates nothing but makes
   ignoring the second source impossible to do silently.
3. **Per-run "wall-to-wall, nothing intervening" attestation — recommend
   AGAINST.** The 31 Aug transcriber believed 17'3" WAS the width; they
   would attest it. Ritual that makes the checker look safer than it is.
   Same for "require a chain when obstructions are declared": the trap
   take-off omits the obstructions too, so the same silence defeats it.
4. **When no vector plan exists** the second source is a human, and the
   review sheet's photo-beside-ledger comparison is that check made cheap.
   There is no mechanical substitute for a photo-only job.

## Open-questions
- Whether the PUBLISHED artifact should carry the photos is cleared for UIC
  (Benton, 31 Aug) but is a per-client decision — keep `--embed-photos`
  explicit.
- 3D labels can overlap at certain angles in dense rooms (G+H); rotation
  resolves it. Leader lines would fix it if it ever annoys Gabe.
- Working tree is shared with the eval-loop Builder; this commit includes
  only the files above plus VERSION/DEVLOG.
