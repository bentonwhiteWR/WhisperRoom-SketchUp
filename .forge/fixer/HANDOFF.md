# FIXER HANDOFF — side-wall panel ORDER, 2026-08-26 (v3, supersedes v2)

## Produced
- `.forge/fixer/ROOTCAUSE-side-wall-order-2026-08-26.md` — **rewritten.** Carries four explicit
  retractions of my own earlier conclusions, the three-source map, and the one change that IS
  evidenced. Read this.
- `.forge/fixer/replay-portal-wallrun.js` — new harness. `require`s and **executes**
  `WhisperRoomQuote/assets/layout-render.js`'s `wallPanelRun()`, so the witness is the portal's
  real function, not a paraphrase of it. Prints all three sources side by side; judges only
  layout-vs-plan. `--all` → `300 walls compared: 24 DISAGREE`, exit 1.
- `.forge/fixer/replay-side-wall-order.py` — **DELETED.** Both of its versions were unsound
  (v1 circular, v2 built on a stale copy of the file under test). A harness that says all-clear
  on a broken model is worse than none.

**No `.rb` touched. `scripts/wr_tools/VERSION` untouched at 1.6.29. Nothing committed.
`WhisperRoomQuote` read and `require`d only, never written.**

## The answer in three lines
The portal's **angled/3D view** (`assets/iso-render.js` ← `booth-iso-geometry.json`) is a
**2026-08-07 snapshot of `wr-booth-data.rb`**, taken before `gen-booth.py` changed the E/W walk;
Benton's portal render is that view, so his 102144 comparison is SketchUp against a stale copy of
itself. On the 102144 the builder and the portal's **live 2D plan agree** — the window sits at
the high-y end in both. The window's correct end **cannot be determined from anything on disk.**

## Assumptions
- The coordinate map (`E/W builder y == H - bIn .. H - aIn`) is **derived** from
  `layout-render.js:1003-1004` and `:1562-1565`; it is stated in the harness header so it can be
  checked. Every number in the report depends on it.
- The assign fed to `wallPanelRun()` is built from `wr-booth-data.rb`'s own resolved panel
  widths, because the flip keys on real part widths and slot sizes would misfire (6060's W slots
  are digitised 40+18; the real parts are 40+16).

## Open questions for Benton — 1 is the one that matters
1. **On a real 102144, which end of the side wall does the window sit at**, measured against the
   floor/ceiling **hinge slots** (a datum that does not move when the door moves)? And is it
   fixed by the model at all, **or does the assembler put the window wherever the customer
   asks?** If the latter, there is no rule to code and the real defect is that
   `booth-from-link.rb` inherits a hard-coded polygon instead of honouring a chosen position.
   Same question for the 96144 (46+46, also symmetric).
2. **Green-light the four-booth flip?** 6060 / 6084 / 7272 / 7296 only, 24 walls. Evidenced by
   the hinge slots, both portal views, and Benton's own "the 6060 top-down looks correct."
   ⚠ **`MDL 6060 E` is the current GOAL "Now"** — this moves its E/W panels and seals on both
   shells. Sequence it against his 6060 work; do not land it underneath him.
3. **The portal's angled view is stale on 14 models** (56 walls). Refreshing it requires fixing
   `gen-booth.py` FIRST — a naive re-extract would break the four split-run booths' angled view.
   `WhisperRoomQuote` change, not mine to make.
4. **The width-axis family split is still open and untouched.** Separate defect; turns a panel
   end-for-end in place.
