# HANDOFF — Scoper → Benton (approval) → Builder: per-scene ANNOTATIONS, rev 2 (hybrid)

2026-09-09. Rev 1 (tags only) superseded the same day by the live probe. Prior mission's
handoff preserved as `.forge/scoper/HANDOFF-peoplesspace.md`.
**Approval gate: Benton has not approved anything yet.**

## Produced
- `.forge/scoper/scene-annotations.md` — rev 2 spec: probe output verbatim, why the one
  FAIL (Untagged cannot be hidden) reshapes the design, the unified-list interaction model,
  9 ordered steps with file:line, 14 acceptance criteria, manifest fields, open forks.
- `.forge/scoper/scene-annotations.mockup.html` — rev 2 mockup: one picker with set rows
  (expandable to their callouts) and loose-callout rows with `all · none`; probe evidence;
  manifest sample; approve/needs-changes strips; six forks; copy-back JSON. Published:
  **https://claude.ai/code/artifact/53cfa4ec-b6fd-407e-9377-d2c4ae65cc69** (same URL, v2)
- `.forge/scoper/probe-scene-annotations.rb` — the probe that was run; keep it, the Builder
  re-runs it on the acceptance model and pastes the output into the DEVLOG.

## Read-first (Builder)
1. `scene-annotations.md` §"The evidence" and §"Why the FAIL is load-bearing" — the design
   rests on those ten lines; §"Approach — one list, one rule" is the interaction contract.
2. `scripts/wr-scene-walls.rb` in full — the shape `wr-scene-annotations.rb` mirrors
   (do not edit the walls file; the new module carries its own `apply_selection`).
3. `scripts/proposal-package.rb` 2905–2996 (walls callbacks), 3050–3320 (CSS/markup),
   3500–3620 (walls modal JS), 449–570 + 2194–2410 (manifest), 1422–1480 (`annot_push`/
   `annot_pop`, for the client-safe hole in Step 7).
4. `scripts/wr-mode.rb` 170–200 and 300–345; `scripts/proposal-scenes.rb` 40–70.
5. Benton's copy-back JSON from the mockup, once it arrives — it overrides the spec's
   decision table.

## Assumptions
- **observed (probe, SketchUp 26.2.243, 9 Sep 2026):** scenes save per-tag visibility
  (`set_visibility`/`Page#layers`) and per-entity hidden state for screen text, leader text,
  linear dimensions and 3D-text groups via `page.update(384)`; that mask leaves the camera
  identical; **Untagged cannot be hidden.**
- **observed (repo/DEVLOG):** Draft annotation mode hides only `LIGHT_TAGS` after each page
  switch, so scene state already governs export; `annot_push` hides tags only.
- **derived:** hand-placed Untagged text goes out on a client-safe image today (tags-only
  hide + Untagged unhideable) — Step 7 closes it; a tag-only picker could not have reached
  most of Benton's existing text; `page.update(384)` re-saves wall flags the scene already
  asserted on open, so no new hazard.
- **assumed:** most of Benton's existing text is on Untagged (hand-placed text lands on the
  active tag). If wrong, nothing breaks — sets simply matter more.
- **reported:** V-Ray ignores SketchUp Text/Dimensions; renders 3D-text geometry when visible.
- Not verified today: the picker itself (no code exists), the manifest fields, the V-Ray lane.

## Open-questions (for Benton, in the mockup's copy-back)
1. Q1 separate ANNOTATIONS column (recommended) vs one HIDE… button with Walls/Notes tabs.
2. Q3 new sets named `WR-Notes-<name>` — prefix editable; sets are optional now.
3. Q4 Client-safe stays the dropdown default (recommended).
4. Q7 callouts inside a set behind an expand arrow (recommended) vs always listed.
5. Q-CS close the Untagged client-safe hole in this build (recommended) vs later with a
   warning in the dropdown text.
6. Q6 wording: column header, row-button label.
Settled, no longer asked: ticked = hidden; single-callout hiding in scope; Untagged never a set.
