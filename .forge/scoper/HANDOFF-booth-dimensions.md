# HANDOFF — Scoper → Builder: click a WhisperRoom, get its dimensions (rev 2)

2026-09-10. Prior mission's handoff preserved as `.forge/scoper/HANDOFF-scene-annotations.md`.
**Benton approved the layout (rev 1's "A′", now A) and asked for a ROTATE button.** Q2 (the
optional plan/interior set B) is still being asked; build A only, B is a bolt-on.

## Produced
- `.forge/scoper/booth-dimensions-spec.md` rev 2 — §7 is now one corner table (FR/FL/RL/RR);
  §7b ROTATE: a rotation through the four corners (first press = the other side), a second
  pick-then-do panel button, always rebuilt from the model (never transformed), corner stored
  per booth on the group, comply-and-say when a side is blocked; §9 three scripts; §10 adds
  rotation acceptance (5, 5b); §11 records Benton's Q1 and the coordinator's Q4/Q6.
- `.forge/scoper/booth-dimensions-mockup.html` rev 2 — A (chosen, front-right corner, side
  push) drawn from a front-right camera; ROTATE panel drawn from a **front-left camera** with
  its own projection and face order (not a mirror); a plan compass of the four corners and
  the press order; the rear-push layout demoted to a "not chosen" note; B unchanged.
  Rendered in headless Chrome and inspected. Same file path — republish to the same URL.
- Nothing under `scripts/` touched; VERSION untouched.

## Read-first (Builder)
1. Spec §7 + §7b (the corner table and ROTATE are the whole placement design), §6 (extent),
   §7 attachment, §8 ownership; §10 is the exit criterion — checks 5 and 5b are new.
2. `scripts/dimension-booth.rb` 173-330 — keep its identification and `vents_from_model`
   regexes; discard `draw`, `HEIGHTS`, `BASE_Z`, the label, all `@setting`s.
3. `scripts/auto-dimension.rb` 1.17.0 attachment code (vertex / ConstructionPoint, `:loose`
   counted) — the precedent for the anchors.
4. `scripts/build-booth-components.rb` 2440-2460, 2660-2680, 1262-1270; `scripts/wr-deck.rb`
   `NAME` / `ENH_NAME` (318, 346); `scripts/wr-overlays.rb` `add` (650), 1416 — part names
   the extent rules key on.
5. `scripts/proposal-scenes.rb` 40-115 — the tag stays `WR-Dims-Booth`; nothing changes.
6. `scripts/sketchup-bridge.py` header — every acceptance check runs through it.
7. Benton's answer to Q2 when it arrives (adds script B; changes nothing in A).

## Assumptions
- **observed (code):** the three current tools, their tags, colours, settings, placement,
  `clear` scope; the 7296/96120 data; part-naming conventions; the 46VNT / door sizes in
  `P:\Sketchup\NewMasterComponentList\_component-probe.tsv`; the bridge exists.
- **derived:** the reference image = 98 / 74+5.5 / 84.3125 → a 7296 with Enhanced height;
  84.3125 = mat underside → tray top from the builder's own datums; the current Enhanced
  height string floats 5/16" at both ends after the 1.33.0 lift; a built 96120 once had its E
  vent ~6 7/16" proud, so measured geometry and the 5.5" rule can disagree (Q4 decided: the
  dimension reads what is drawn).
- **reported:** Benton's rev-2 words (via the coordinator); the reference image itself; the
  `InstancePath` overload of `add_dimension_linear` for nested vertices (API memory — verify
  on the bridge first; ConstructionPoint fallback is specified).
- **assumed:** Benton's cameras are front-right and front-left three-quarters; "rotate" means
  the whole set moves to another corner (his description: right side → left side), and the
  rear corners are wanted for rear/ventilation plates — cheap either way (same table).
- Not verified: anything in a live SketchUp. I cannot run it.

## Open-questions
1. **Q2** three strings only, or also the plan set B with interior clear — being asked now;
   build A, keep B as its own script/tag.
2. Q3 hand-drawn reference or moved tool output — not blocking.
3. Q5 Enhanced interior clear height — only if B; not blocking.
4. Nicety, not asked: arrow-key rotation while the Dimension pick tool is live. Left out of
   this build deliberately (spec §7b); raise with Benton only if the button feels slow.

## Blockers
- None. Q4 is decided, so acceptance check 1 on a 7296 E is expected to either read
  `8' 2" / 6' 7 1/2" / 7' 5/16"` or print the `***` vent-seat mismatch block — both pass;
  a silent wrong number is the only fail. The vent seat itself is a separate builder fix.
