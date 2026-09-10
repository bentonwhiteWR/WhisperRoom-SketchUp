# HANDOFF — Scoper → Benton (approval) → Builder: click a WhisperRoom, get its dimensions

2026-09-10. Prior mission's handoff preserved as `.forge/scoper/HANDOFF-scene-annotations.md`.
**Approval gate: Benton has not approved anything yet. No code until he points at a variant.**

## Produced
- `.forge/scoper/booth-dimensions-spec.md` — what the reference image is (decoded to an
  MDL 7296 E), the height figure settled, nine named defects in today's tools, eleven
  decisions, the identification / extent / anchor / placement rules, ownership and removal,
  panel wiring, twelve bridge-verified acceptance checks, ten open questions with defaults.
- `.forge/scoper/booth-dimensions-mockup.html` — standalone, inline SVG, to scale from the
  7296 E's own numbers: **A** (three dims, height off the rear — recommended), **A′** (height
  off the side, for a booth against a wall), **B** (optional plan set with interior clear).
  Rendered in headless Chrome and inspected; no external resources.
- Nothing under `scripts/` touched; VERSION untouched.

## Read-first (Builder)
1. Spec §1 (the height), §3 (defects D1–D3 are the load-bearing ones), §6–§7 (extent and
   anchors) — that is the whole design; §10 is the exit criterion.
2. `scripts/dimension-booth.rb` 173-330 — keep its identification and `vents_from_model`
   regexes; discard its `draw`, `HEIGHTS`, `BASE_Z`, `VENT_PROUD`-as-drawn, and the label.
3. `scripts/auto-dimension.rb` 1.17.0 attachment code (resolve to vertex / ConstructionPoint,
   count `:loose`) — the precedent for §7.
4. `scripts/build-booth-components.rb` 2440-2460, 2660-2680, 1262-1270; `scripts/wr-deck.rb`
   `NAME` / `ENH_NAME` (318, 346); `scripts/wr-overlays.rb` `add` (650) and 1416 — the part
   names the extent rules key on.
5. `scripts/proposal-scenes.rb` 40-115 — the tag stays `WR-Dims-Booth`; nothing there changes.
6. `scripts/sketchup-bridge.py` header — every acceptance check runs through it.
7. Benton's answers to Q1–Q10 (spec §11), which override the defaults.

## Assumptions
- **observed (code):** all three current tools, their tags, colours, settings, placement,
  `clear` scope; the 7296/96120 data; the part-naming conventions; the 46VNT / door part
  sizes in `P:\Sketchup\NewMasterComponentList\_component-probe.tsv`; the bridge exists.
- **derived:** the reference image's three strings = 98 / 74+5.5 / 84.3125 → a 7296 with
  Enhanced height; 84.3125 = mat underside → tray top from the builder's own datums (mat
  −1.3125, ceiling top 82.0, tray drop 0.75, tray box 1.75); the current Enhanced height
  string floats 5/16" at both ends after the 1.33.0 lift; a built 96120 once had its E vent
  ~6 7/16" proud, so measured geometry and the 5.5" rule can disagree.
- **reported:** the reference image itself (operator's description — I have not seen it);
  the `InstancePath` overload of `add_dimension_linear` for nested vertices (API memory —
  Builder verifies on the bridge first; ConstructionPoint fallback is specified).
- **assumed:** Benton's usual camera is front-right three-quarter (the proposal plates lead
  with one); "click a whisperroom" means a pick, not a selection observer.
- Not verified: anything in a live SketchUp. I cannot run it; the Builder must, via the
  bridge, on a 7296 E, a 96120 S and a 96120 E.

## Open-questions (for Benton — the mockup carries the short form)
1. Q1 height off the rear (A) or the side (A′), or auto by what is behind the booth.
2. Q2 three only (A) or also the plan/interior set (B).
3. Q3 was the reference hand-drawn with SketchUp's own tool, or the old tool's output moved.
4. Q4 drawn geometry vs the 5 1/2" vent rule when they disagree — and whether the builder's
   vent seating should be fixed to 5 1/2" (separate job).
5. Q5 Enhanced interior clear height (only if B).
6. Q6 24" standoff. Q7 pick tool + select-then-button. Q8 clear per booth / Esc = all.
   Q9 auto-dimension after Booth-from-link (default no). Q10 black confirmed.

## Blockers
- None for approval. For the build: Q4 decides whether acceptance check 1 is expected to pass
  clean or to print the mismatch block on the first 7296 E.
