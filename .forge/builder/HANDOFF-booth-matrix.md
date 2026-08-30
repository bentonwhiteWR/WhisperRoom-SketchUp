# HANDOFF — booth-matrix harness (Phase 0)

Builder, 2026-08-30. **Harness built and proven offline. No live run happened.**

---

## Produced

| Path | What |
|---|---|
| `scripts/rbtest-live-booth.py` | the harness — `keys` / `selftest` / `dry` / `build` / `diff` |
| `DEVLOG.md` | entry at the top, dated 2026-08-30 |
| `.forge/builder/HANDOFF-booth-matrix.md` | this file |

Nothing else changed. No Ruby was edited. **`scripts/wr_tools/VERSION` was not
bumped** — this adds Python only, and the other Builder holds 1.9.1. Bump to
1.9.2 only if you end up touching Ruby.

`.forge/builder/booth-matrix/` does **not** exist yet. It is created by the
first live run and is where the golden baseline lands
(`dry/<KEY>.txt`, `dry/<KEY>.json`, `dry/index.json`; same under `build/`).

---

## Read first

1. `scripts/rbtest-live-booth.py` — its module docstring is the design document.
   The clean-model section and the "every dry run comes back as a raise" section
   are the two things that will otherwise look like bugs.
2. `scripts/sketchup-bridge.py` header — the protocol, exit codes, and `submit()`.
3. `scripts/wr-bridge-lib.rb` — `WRB.scratch!` and `WRB.tool`, which the job uses.
4. `scripts/wr-deck.rb:1130-1139` and `:1561-1568` — the landed-bounds prints
   that ARE the floor/ceiling manifest. The harness captures them; it does not
   reimplement them, and it must not start to.
5. `scripts/build-booth-components.rb:2034` — `build_booth(key, assign, cfg)`.

---

## Design decisions, so nobody re-litigates them

- **`Sketchup.file_new` is not used.** On a dirty model it opens a native
  save-or-discard prompt. The bridge patches `UI.messagebox`/`inputbox`/panels —
  not the application's own file dialogs — so a native modal wedges SketchUp
  until a human clicks. That is the one outcome this harness must never produce.
- **Clean model = `WRB.scratch!` per key**, then an assertion that the
  post-wipe census total is **0**, recorded in the manifest as `pre`. Carryover
  is proven per key and written down, not assumed. A non-zero `pre` is a
  `harness` verdict, never a booth result.
- **Definitions are purged between keys.** Costs a re-read of every `.skp` from
  `P:` and is most of the wall-clock time. Accepted: a warm cache makes key N's
  result depend on keys 1..N-1, which a golden baseline cannot tolerate. If the
  50-key dry run turns out to take too long, the fix is a flag with the tradeoff
  named in the manifest — not a silent change of default.
- **`<KEY>.txt` is the primary artifact**, verbatim stdout in the tools' own
  words. `<KEY>.json` is the parse plus an instance census. Diff the `.txt`.
- **`ModalBlocked` is rescued separately from every other exception** and lands
  in `dialog`, not `error`. Every dry run raises it (build_booth's closing
  `UI.messagebox`), and so does the missing-parts path. Both fire after the
  console report is complete, so nothing is lost.
- **`--su 2024` is refused by name** in the CLI. Benton's call, 30 Aug 2026: the
  baseline is captured on 2026, the version the work is drawn in.

---

## Assumptions — verify these on the first live run

- **`WRB.scratch!` on a model holding a full booth build completes without a
  dialog.** Reasoned from its source (no UI call in it), not observed on a
  booth-sized model. If it prompts, the whole clean-model design needs revisiting.
- **`build_booth` reaches its closing `UI.messagebox` on every dry run.** Read
  from `build-booth-components.rb:2530ish`; the parse of `DRY RUN — nothing
  built. N parts would be placed.` depends on it.
- **`WRB.tool('build-booth-components')` loads cleanly once per session** and the
  `defined?(WR_BuildBoothComponents)` guard keeps it to once. If the second key
  behaves differently from the first, suspect this first.
- **A 50-key dry run fits in one SketchUp session** without the definition churn
  exhausting memory. Unmeasured.
- Job timeout defaults to **600 s per key**. Unmeasured against a real build of
  `MDL 102186 E`.

---

## Open questions / outstanding work

1. **Run the 50 dry runs** on SketchUp 2026, Untitled scratch model open:
   `python scripts/rbtest-live-booth.py dry`. Report the tally as named key
   lists per bucket, not an adjective.
2. **Run the four real builds:** `MDL 6060 S`, `MDL 6060 E`, `MDL 96192 E`
   (with `--overlay efp`, which is the only way to reach the EFP path),
   `MDL 102186 E`. `--keys` them; **do not run all 50 real builds** this pass.
3. **Commit the resulting manifests as the golden baseline** and say in the
   commit which SketchUp build and which plugin VERSION produced them — a
   baseline without its provenance cannot be diffed honestly.
4. **The EFP96192 finding needs live confirmation.** `EFP96192.skp` exists on the
   share (426,135 bytes, observed) and `EFP_SIZES` already lists `96192`, but
   `scripts/wr-overlays.rb:898-905` still refuses by name from an
   `if digits == '96192'` branch placed **ahead of** the `EFP_SIZES` test. Read
   from source; not yet seen fire in a live build. Deleting that branch is a
   separate, scoped job — **do not fix it inside a diagnosis pass.**
5. **The 6060 S/E side-wall check** (the 40/16 swap from 1.7.10 that disagrees
   with the portal's `wallPanelRun()` in two places) is the highest-value single
   comparison in the real-build set. Nothing in this harness judges it — it
   records the landed bounds; a human or a follow-up assertion compares them to
   the portal.
6. **Nothing in the harness asserts anything about geometry yet.** It records.
   Turning a baseline into assertions (a floor part must be flush at z=0, a
   ceiling must sit at the wall top, a deck must tile without gaps) is the phase
   after the baseline exists.
