# HANDOFF — List Scenes search box

Task: fix the search box in `scripts/list-scenes.rb`. Benton reported he could not
search the middle of a component name.

**This is NOT the Enhanced-booth mission in `.forge/GOAL.md`.** Nothing here touches
`booth-from-link.rb`, `wr-booth-data.rb`, `wr-deck.rb` or `gen-booth.py`. The previous
handoff (bulk scene naming) is preserved at `.forge/builder/HANDOFF-bulk-name.md`.

## Produced

| File | What |
|---|---|
| `scripts/list-scenes.rb` | The fix. Header doc, `placeholder`, `hl()`, new `terms()`/`textHit()`, `parseNums()`, `draw()`. |
| `scripts/wr_tools/VERSION` | 1.6.19 → 1.6.20 (required for any change under `scripts/`). |
| `.forge/builder/emit.py` | Reproduces the `<<-HTML` heredoc's OUTPUT (Ruby escape processing + `#{}` substitution) so the emitted JavaScript can be checked and run. |
| `.forge/builder/emitted-list-scenes.html` | The emitted page, with fixture rows. Scratch — regenerate, do not edit. |
| `.forge/builder/emitted-filter.js` | The `<script>` block lifted out of the above. Scratch. |
| `.forge/builder/filter-test.js` | 21 Node assertions driven through the REAL emitted `draw()`. |

Re-run the whole check with:

```
python .forge/builder/emit.py && node .forge/builder/filter-test.js
```

## What was actually wrong

Not the text filter — that was already `indexOf(...) >= 0`, a substring match.
The bug was `parseNums(q)`: `/^[\d\s,\-]+$/` matched any all-digits query and
`draw()` then filtered by SCENE NUMBER only, discarding the text search. Benton's
component names are heavily numeric (`ENH 10242FL SIDE`, `4896`, `1648`), so
typing `1648` meant "scene 1648" and matched nothing. `26.5` contains a period,
fell through to text search, and worked — which is why the failure looked random.

## The rule now

- `parseNums` returns `{ want: …, only: … }`. `only` is true only when the query
  carries a comma or a hyphen — an unambiguous list/range like `1-40` or `3,7,12`.
  That case still filters by scene number alone, unchanged.
- A **bare** number is the **union**: scene-number match OR text match. `12` returns
  scene 12 *and* `ENH 1264CL`. `48` returns everything containing "48" even though
  no scene is numbered 48.
- Search terms are whitespace-split and **ANDed, order-independent**.
  `wdo panel` = `panel wdo` = `ENH 26.5Panel1648WDO_HX`.

## Highlighting — what I chose

**Every matching term is highlighted, every occurrence**, not degraded. `hl()` now
takes the term array, collects match spans on the RAW string, merges overlaps, and
escapes each slice as it is emitted (escaping first then slicing would cut `&amp;`
in half — that was a real hazard in the old code, which escaped then `indexOf`'d).
When the query is a pure range (`only`), `draw()` passes `[]` and nothing is marked,
matching the old `var term = nums ? "" : q` behaviour for that case.

## Assumptions

- `<<-HTML` at line 177 is an **interpolating** heredoc, so `\\d` in the Ruby source
  becomes `\d` in the emitted JavaScript. Verified against the emitted file, not
  assumed: every regex in the emitted HTML is single-backslash and no `\\` survives.
- Fixture scene numbers are invented; the component/scene NAMES are real ones from
  this project's `ENH` library.
- A whitespace-split AND search means a query containing a literal space inside one
  token (`"ENH 10242FL SIDE"` typed whole) still matches, because each word is
  present — but as separate terms, so word order in the name no longer matters.
  Judged a feature, not a regression.

## Open questions

- **Unrun in SketchUp.** There is no Ruby interpreter on this machine outside
  SketchUp. The Ruby parses (`rbparse.py`) and the emitted JavaScript passes 21 Node
  assertions, but nobody has opened the actual dialog. Benton should run
  `load ".../scripts/list-scenes.rb"` once and try `1648`, `wdo panel`, and `1-40`.
- The `RANGE` / tick-to-build-a-spec feature was not touched and was not exercised by
  the Node harness (row click handlers are stubbed out) — it is untouched code, but
  it is untested here too.
- Not committed, per instruction. `scripts/wr_tools/` was not changed, so no
  `install-plugin.py` reinstall is needed for the panel itself; `list-scenes.rb`
  is a tool script, so a `git pull` reaches repo-checkout machines and everyone
  else needs the installer.
