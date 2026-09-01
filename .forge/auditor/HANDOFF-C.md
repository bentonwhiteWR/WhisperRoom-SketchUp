# HANDOFF — Auditor lane C (booth geometry, booth-builder link, dimensioning)

2026-09-01, plugin 1.19.2 at `14197b9`. Read-only pass; no source, VERSION or git changes.

## Produced

- `.forge/auditor/full-audit-C-booth-geometry.md` — 13 ranked findings (C-1 … C-13), the
  status of every 15 Aug finding touching this lane, one-line answers to the seven lane
  questions, a "what is solid" section, and the stated coverage limits.
- Scratch only (not in the repo): a rbparse probe that loads `wr-booth-data.rb` and lifts
  `auto-dimension.rb`'s `arch()`; a `gen-booth.py --all` regeneration into a scratch folder for
  the byte-for-byte diff. Both are reproducible from the audit text.

## Read first

1. **C-1** in the audit. It is the finding Benton will recognise: the 27 Aug "22 wall where the
   window should be" complaint is still open, and the standalone *Build from real components*
   button and the *share link* button now build the 6060 / 6084 / 7272 / 7296 side walls
   mirrored relative to each other. The 30 Aug booth-matrix baseline was captured on the
   standalone (`ASSIGN`) path and therefore holds the pre-28-Aug arrangement.
2. **C-2 / C-3** together: door dimensions are never drawn on a built room (long-standing), and
   the 1.17.0 attachment work behind them is unrun and cannot report its own `:loose` count.
3. **C-4** — the Untitled guard is in no Ruby build script; only in Python-side jobs. The fix
   direction keeps panel use working (guard only under the bridge).
4. `scripts/build-booth-components.rb:1312-1400` (`ASSIGN`) beside `scripts/gen-booth.py:60-97`
   and the probe output quoted in C-1 — read the two together before touching either.

## Assumptions

- **assumed**: the SketchUp API's behaviour when `add_dimension_linear` is handed a bare
  `Vertex` from inside a group (C-3). Two outcomes are possible; both are described. Only a live
  run settles it — DEVLOG Next-step 1 is the right test, once `loose` is actually printed.
- **reported**: everything about which booths Benton has looked at (the coverage list in C-5)
  comes from the DEVLOG and the Fixer/Builder handoffs. The list of never-inspected models is
  the complement of that, not an observation.
- **derived**: C-1's placement on the standalone path is derived from observed data plus the
  observed `rebalance_walls` algorithm; the 30 Aug live transcript corroborates it for the 6060
  but no 7272 transcript exists on disk.
- **assumed**: `MJP.skp`'s real extents (C-6). The defect is the same shape as the desk's; whether
  it currently bites depends on numbers not recorded anywhere in the repo.
- Which of the two 7272 arrangements is physically right is **not** decided here. Both paths
  cannot be right; that is the finding.

## Open questions

1. On a real MDL 7272 / 7296, taking the door wall as the reference: does the 46-in panel sit at
   the door end or the far end? (Unchanged since 27 Aug; one tuple in
   `SWAP_TWO_PANEL_SIDE_WALL` once answered, and `ASSIGN`'s E/W entries must go either way.)
2. Should E/W order have one owner (generator) with `ASSIGN` limited to N/S and to the part
   choices it actually makes? The audit recommends yes.
3. Is the "floor and ceiling hinges are coplanar" invariant in
   `reference/floor-ceiling-geometry.md` true of the 7296? 1.19.2's per-kind mirror says no by
   construction. Either the doc or the floor is wrong.
4. Should the Standard link path refuse an untranslatable pack the way the Enhanced path does
   (C-8)? It was left as "today's behaviour EXACTLY" on 24 Aug; the roof-vent lesson of 31 Aug
   argues for refusing.
5. What is `MJP.skp`'s measured height, and does `MJP_SPIN180` survive passing `nil` to
   `axes_for`?
6. Under-bridge guard mechanism (C-4): `$wr_bridge_job` global versus a `cfg` key — a Fixer
   decision that needs Auditor A's view of `wr_bridge.rb`.
