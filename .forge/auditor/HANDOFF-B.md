# HANDOFF-B — Auditor, lane B (proposal package and render lane), 2026-09-01

## Produced

- `.forge/auditor/full-audit-B-proposal-render.md` — 14 ranked findings with file:line,
  trigger, failure, provenance and fix direction; disposition of every finding from the
  30 Aug proposal-package audit, the 28 Aug render-lane audit and the 28 Aug lighting
  audit; the Untitled-guard / mutation-restoration trace; the dialog-JS check; harness
  results; what is solid; what could not be checked.
- Scratch (session scratchpad, not in the repo): `lights-diag.py` (prints the real Ruby
  exception behind `rbtest-lights.py`), `lights-patched.py` (the harness with
  `LUMEN_GAIN` lifted — 43/44 pass, the one failure is the 10x gain), `html-extract.py`
  (evaluates `proposal-package.rb`'s real `html()` in SketchUp's CRuby and `node --check`s
  the scripts), `pp-dialog.html`, `pp-script-full.js`, `lights-panel.js`.
- No source file, VERSION, or git state was touched.

## Read-first

1. The "answer to Benton, up front" and findings 1–4 in the audit. Finding 1 is the
   owed root cause (`rbtest-lights.py` is stale against 1.10.0 in two places; the tool
   is fine). Findings 2 and 3 are the two silent, customer-facing ones and both are
   the same mechanism the codebase has already fixed twice for tags: a scene switch
   re-applies the scene's saved state on top of what the batch just set.
2. `scripts/proposal-package.rb:1090-1101` (unit order), `:1575-1629` (shading push and
   image rows), `:2426-2441` (mode fallback in `finish`); `scripts/proposal-scenes.rb:236-237`;
   `scripts/wr-mode.rb:135-151` and `:293-353`.
3. `scripts/wr-png-srgb.rb:259-274` and `scripts/proposal-package.rb:2039-2062` for
   finding 4.

## Assumptions

- **Page activation re-applies saved shadow_info and rendering_options** the same way it
  re-applies saved tag visibility (finding 2). Documented Page contract; observed live for
  tags (DEVLOG 1.9.12); not observed here for shadows. A one-scene check settles it.
- **SketchUp operations do not nest** (finding 9). Reported across three audits, never
  verified.
- **Ruby's `JSON.generate` does not escape `/`** — true of the stdlib default; my CRuby
  evaluation shimmed `to_json` with the same rule because the minimal VM has no json ext.
- **The dark-render diagnosis (linear buffer saved) is correct and stable** — reported from
  one measured pair on 1 Sep; finding 4 is about what happens if it is not stable.
- Every live-behaviour statement (render_production exports, sidecars, manifest vs pixels,
  hidden walls per scene) is **reported** from the builder handoffs.

## Open-questions

1. Has Benton ever run the package through the real button on a SAVED, never-toggled
   client model and then looked at the tags, shadows and `WR Lights` state? (Finding 3.)
   Every recorded run was on a scratch `Untitled`.
2. Run `probe-vray-color.rb` with a frame in the VFB — it decides whether `wr-png-srgb.rb`
   can retire or must stay, and whether finding 4's guard needs to be a refusal.
3. Should the GOAL's "Untitled only" rule apply to the per-scene / per-model tools at all?
   None of the 19 lane-B scripts asserts `model.path` empty, and most cannot do their job
   on an Untitled model. The rule that matters is "no unrequested persistent change";
   finding 3 is the one place that rule is broken.
4. `camera.clone` aliasing (F8, 28 Aug) — still one console line away from settled.
5. The Fixer should decide whether the `rbtest-lights.py` `lm` expectation is re-pinned at
   10x or the gain is divided out in the check; either way `rbparse.rb_eval` should print
   `$!.message`.
