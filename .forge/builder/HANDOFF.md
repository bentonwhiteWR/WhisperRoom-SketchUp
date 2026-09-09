# HANDOFF — Builder → Auditor (PeoplesSpace alcove room script)

## Produced
- `scripts/peoplesspace-alcove.rb` — the room script, `@tab client`. Builds the alcove
  to the two stated interior faces, east side open, cloud + structure + pipes + grille
  massed, MDL 96120 E + ADA placed twice (door south / door north) on WR-Booth-Opt1 /
  WR-Booth-Opt2, invented context around it on WR-Context-INVENTED, site-sampled room
  materials, ten scenes in proposal plate order, and a report HtmlDialog. **Unrun by
  me** — Benton loaded 1.19.15; nothing since has been executed.

## Changed after Benton ran 1.19.15 (now 1.19.16)
- **In-model paragraph text is gone.** `Sketchup::Text` has no font-size API, which is
  why it rendered enormous. Short labels only now, via `add_3d_text` at
  `LABEL_H = ROOM_W / 64.0`, all on **WR-Notes, off by default** (the WR Lights pattern).
- **The explanation lives in an HtmlDialog** the build opens — height stack, headroom,
  caster warning, handedness conflict, palette, the thirteen-item estimated list — with
  buttons that switch options, labels, dimensions and context. Console `puts` unchanged.
- **Context added**, all INVENTED, on its own tag: floor 20 ft east, elevator recess in
  the continuing concrete wall, glass door and room behind the storefront, mullions,
  deck, pipes carried east. The `-02-dimensioned` and `-05-plan` scenes drop it.
- **Room materials sampled off the site photo**, deliberately replacing CLAUDE.md's
  drawing palette for this model (Benton's call). Booth materials untouched.
  `SITE_MATERIALS = false` restores the drawing palette; `BUILD_CONTEXT = false` drops
  the context.
- `.forge/builder/peoplesspace-check.py` — the arithmetic cross-check, independent of the
  Ruby: chain closure, ramp fit, height stack, roof-unit seating. Passes.
- `DEVLOG.md` entry and `scripts/wr_tools/VERSION` bumped 1.19.14 → 1.19.15.

## Read-first
1. The header of `scripts/peoplesspace-alcove.rb` — it carries the whole argument
   (measured / not measured, the height stack, why the ramp cannot run inward, hinge).
2. `.forge/builder/peoplesspace-check.py` output — run it, it takes a second.
3. `scripts/wr-overlays.rb` `place_efp` (~line 1168) and `scripts/wr-deck.rb`
   `DECK_TOP_Z` — the two lines that settle the raised-floor question.

## Assumptions
- z = 0 is LEVEL 01 FF taken as the TOP of the raised floor as drawn. A reading of the
  elevation fragment, not a statement by the architect.
- Hinge on the SOUTH jamb in both options, leaf opening south so the ramp approach is
  clear from the glass-wall side. Nobody has stated a hinge side.
- Pipe plan positions (three, dia 5.5", centres 3.5 / 10.5 / 17.5 off the concrete face)
  and the cloud's 22" setback and the grille box are pixel reads, ±2".
- Booth is a PLACEHOLDER BOX at the catalogue exterior — no sales link exists yet.
- No casters. If a quote ever carries them the roof unit hits the pipe (see below).

## Open questions
1. **The ramp cannot run inward.** It needs 45.625"; the alcove leaves 16.75" east and
   6.75" north. Drawn running EAST into the open space, toe 2'-5 7/8" past the alcove
   line. Benton has to accept that or the layout changes.
2. **Roof-mount is not on a sales quote.** Drawn, labelled UNCONFIRMED everywhere. Get
   the `sales.whisperroom.com/q/W-…` link before anything ships.
3. **"Left side" vs "against the glass wall" conflict.** Answer 4 says south = left
   (option 1); answer 5 says the ramp opens against the glass wall, which is the north
   end (option 2). Both are built; Benton picks.
4. Ramp rise and slope are still unknown — the plate is flat and is not a ramp profile.
5. The script is UNRUN in its current form. Benton loaded 1.19.15; the text fix, the
   context and the site palette have not been seen in SketchUp by anyone.
6. The context dimensions (20 ft east, 12 ft glazed room, 84" elevator, 48" mullion
   spacing) are all invented for the render. If anyone measures the real lobby, replace
   the `CTX_*` / `EV_*` / `MULL_SP` constants — they are grouped at the top of the file.
7. The sampled colours carry the photo's lighting. They are a lookdev starting point,
   not a spec.
