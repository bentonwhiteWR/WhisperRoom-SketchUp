# Documenter handoff — seam seal spec, plus the end-of-day session entry

Two deliverables this session. The DEVLOG entry is second, at the bottom of this file.

---

# 1. Seam seal attachment, for the quote-tool plan-art agent

**Delivered:** `C:\Users\bento\Documents\Claude\Sketchup\reference\seam-seal-attachment.md`

Self-contained. Written for an agent with no access to this repo, producing 2D top-down art
in `WhisperRoomQuote`. Nothing was written to `WhisperRoomQuote`; nothing was committed.

## What is in it

Plan footprint of both seals, exact vertex lists per wall and per corner, the station formula
for a joint centre, the closure rule worked through on the 4872 S and checked on the 96120 S,
two ASCII plan diagrams, and a pre-ship checklist. Ruby placement internals deliberately left
out; only the *consequences* of two of them are stated (the seal is flush, the corner has four
square orientations).

## Provenance of the content

- **Observed** — every plan polygon and station. Read out of `scripts\wr-booth-data.rb`
  (generated layout data, 4872 S at line 272, 96120 S at line 443) and re-derived from the
  generator that produced it, `scripts\gen-booth.py` lines 44–228. The two agree exactly. The
  exterior/interior envelopes were read live out of
  `…\WhisperRoomQuote\lib\pl-data\booth-layouts.json` (read-only).
- **Reported** — part dimensions (7 3/4 T, 4 7/8 L, 1 in thicknesses) and the "panels do not
  touch" rule, from `reference\booth-components.md`, itself off Benton's source drawings.
- **Assumed, and labelled as such in the document** — the mid-wall stem's projection depth.

## Facts I verified rather than took on trust

Everything in the assignment brief checked out. Additional things the sources gave up that the
brief did not have, and that a plan renderer needs:

- The **outboard 1 in band is empty except at seals**, so the booth's exterior profile steps in
  and out by 1 in and the quoted exterior is measured *over the corner seals*. At any real plan
  scale that recess is below line weight — stated both ways in the document.
- The **corner seal is three rectangles, not two legs**: the two 4 7/8 legs plus a 1 × 1 inner
  block at `x 1…2, y 1…2` that the two panel ends actually butt into. That block *is* the
  attachment, and the two-leg description alone would draw it wrong.
- **E and W wall slot lists run north → south**, not south → north (`gen-booth.py` line 166,
  which records this as a live bug fixed 2026-08-11). Getting it wrong mirrors both side walls.
- Corner and mid-wall seals **cannot collide** on any standard booth — 1.25 in minimum
  clearance, derived from the 7 in minimum stock panel.
- The `+24.000` seal shift in the placement code's rebalance reproduces exactly from the 7272
  geometry: joint at `y = 25` unswapped, `y = 49` swapped.

## Open items surfaced, not filled in

1. **Stem projection depth** — undimensioned. I argue in the document that it does not matter
   for a plan (a projection large enough to show at 1/4 in = 1 ft would be a visible interior
   feature and would have been dimensioned) and instruct the reader to draw it flush and label
   it. No number supplied.
2. **Door leaf thickness and swing geometry** — undimensioned, and this one *will* block the
   receiving agent: no swing arc can be drawn without it. Flagged prominently.
3. **Vent duct and silencer box dimensions** — undimensioned, and the vent projects beyond the
   footprint, so a plan that stops at the exterior rectangle is incomplete. Flagged.
4. `reference\booth-components.md`'s "Still needed" list is **stale on one line**: it asks for
   panel height, which the same file already states as 81 in. Worth deleting there.
5. `booth-layouts.json` still records the 4872's narrow panel as `24` where it is a `22`. Known
   data error, still unfixed at source.

## What I did not do

- Did not open `MidWallSeamSeal.skp` or `CornerSeamSeal.skp` — no Ruby outside SketchUp on this
  machine. No dimension in the document comes from either file, so nothing here would change if
  they were opened; but neither is the document a *measurement* of the parts. It is the plan
  model the layout generator and the 3D build both use, cross-checked against Benton's drawing
  figures.
- Did not commit, push, or touch anything outside this repo.

---

# 2. Session handoff entry in `DEVLOG.md`

New entry added at the very top of `C:\Users\bento\Documents\Claude\Sketchup\DEVLOG.md`, above
the existing floor/ceiling-toggle entry: **"2026-08-17 — session handoff: two dialogs that have
never been opened"**. Shorter and more operational than the feature entries around it, so a
fresh terminal on the desktop can start cold. Covers the three pieces of work, the three
smaller fixes, an ordered next-session list, and the open decisions.

Nothing was committed or pushed.

## What I verified rather than transcribing

Every claim was checked against the repo. All of the coordinator's facts held; three needed
adding or sharpening:

- `c9ed74e` exists and is the ceiling-seal commit; `SEAL_DATUM_LIFT = -1.75` and the
  `feet × 12 − 2` selection rule are in its message verbatim.
- **The commit message contradicts the four-booth claim** — it says *"Only the MDL 7272 S has
  been built in SketchUp."* `.forge\builder\HANDOFF.md` (uncommitted) lists all four: 7272 S,
  9696 S, 96120 S, 102186 S. The builder file is the later record, so the four stand and the
  DEVLOG says explicitly *why* the commit message reads narrower. Left as a visible
  reconciliation rather than a silent overwrite.
- The builder handoff names a **third untested branch the brief did not**: the zero-seal case
  (4872 / 4230), alongside `STDSS CL5`, `STDSS CL7` and the 10284 quarter turn. Added.
- `git status` confirms the toggle removal is uncommitted (`scripts\build-booth-components.rb`,
  `scripts\booth-from-link.rb` both modified) and `reference\seam-seal-attachment.md` untracked.
- `git diff scripts\export-component-art.rb` confirms the stray edit exactly: a single line,
  `@title Component art — flat views...` → `@title Scene PIctures...`.
- `e90321d` is the auto-dimension container-transform commit, dated 2026-08-16.
- The "never opened in SketchUp" claim is the one thing **not independently verifiable** — it is
  a negative about a GUI. It is consistent with the existing DEVLOG entry, which already says
  the change is unrun and that `rbparse.py` green is not a claim that either dialog was opened.
  Recorded as reported, and the DEVLOG explains why a parse cannot substitute for it.

## Still open after this session

Unchanged from section 1 and now also in the DEVLOG: door swing geometry and vent projection
both undimensioned and both blocking the quote-tool agent; the two `auto-dimension` questions in
`.forge\fixer\root-cause-transform.md`; and the `export-component-art.rb` title typo left
uncommitted for Benton to call.
