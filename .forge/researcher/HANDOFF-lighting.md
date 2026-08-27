# HANDOFF — interior lighting research (2026-08-27)

## Produced

- `.forge/researcher/interior-lighting-options.md` — the four options weighed, the
  recommendation (a seed-component light dropper, `scripts/wr-drop-lights.rb`, pure SketchUp
  Ruby, no V-Ray API), and a Builder-ready implementation sketch with defaults, refusal
  behaviour, and a verification checklist.
- This file. Nothing else was created or modified; the pass was read-only outside
  `.forge/researcher/`.

## Read-first

1. `.forge/researcher/interior-lighting-options.md` — the whole finding.
2. `reference/vray-ruby-api.md` — why the scripted-API route is out: the documented class
   surface has **no light class**, and `ModelExporter#subscribe` is the docs' own admission
   that non-model scene objects are wiped on every re-export.
3. `scripts/wr-shading.rb` — the existing `Dark`/`DisplayShadows` machinery that is the ONLY
   possible fix for plain (non-V-Ray) exports; the new tool deliberately does not duplicate it.
4. `scripts/wr_tools/main.rb` header-parsing region (`@title`/`@cat`/`@rank`) and
   `scripts/merge-scenes.rb:294` (`model.definitions.load`) — the two idioms the Builder reuses.

## Assumptions

- Today's dark images are **V-Ray renders of the UTHSC room drawings** (derived from
  DEVLOG 2026-08-27 + git `45cb5ee`; the images themselves are not on this machine and V-Ray
  is not installed here). GOAL item 5 adds booth interiors; the recommended tool serves both.
- A V-Ray light component saved as a `.skp`, re-imported via `model.definitions.load`, and
  instanced still emits — reported community behaviour across V-Ray versions, never observed
  here. **This is the single load-bearing unverified claim**; step 2 of the verification list
  tests it first.
- Defaults `DROP = 6"` below bbox top, 24"×48" seed, split-to-two-lights above 12' plan run —
  assumed starting values, each one constant, each light hand-movable afterward.

## Open-questions (for Benton / the render machine — record, do not block)

1. Which V-Ray version is on the render machine, and does a `definitions.load`-placed copy of a
   rectangle-light component emit? (Five-minute check; decides everything.)
2. Does hiding the `WR Lights` tag disable the lights in a render? Expected yes; matters once
   wr-mode snapshots the tag.
3. Were any of today's disappointing images plain SketchUp exports? If so the fix for those is
   shadow `Dark`/`DisplayShadows` in the stream-4 skill's plain pass — no light can ever reach
   them.
4. Benton must author `scripts/vray-seeds/WR Interior Light.skp` once (V-Ray toolbar →
   Rectangle Light, facing down, drawn at origin, Save As). The tool refuses by name until it
   exists — authoring `.skp` files is his per GOAL.
5. While in the render seat: run `scripts/probe-vray.rb` (written, never run) — it answers the
   cold-context question stream 4 needs.
