# Fixer handoff — the dead ability row

## Produced

- `scripts/wr_tools/panel.html` — the fix. `flipAbility(sw)` is now the single
  toggle path; `wire()` gained a `.row[data-ab]` handler that calls it, the
  `.sw` handler calls the same function behind `e.stopPropagation()`, and
  `.row.ab` no longer forces `cursor: default`.
- `.forge/fixer/panel-abilityrow-uitest.py` — regenerable repro/regression page.
  `python .forge/fixer/panel-abilityrow-uitest.py` prints a path; run
  `chrome --headless=new --disable-gpu --dump-dom file:///<path>` and read
  `<pre id="OUT">`. 33 assertions, all passing. Point its `src` at a copy of the
  pre-fix `panel.html` to watch 10 of them fail.
- `DEVLOG.md` — entry at the top.

## Read first

- `.forge/scoper/panel-redesign.md` step 3 — "an ability row has no RUN
  affordance, the switch is the action". That rule is intact: the row body does
  not bypass the switch, it *is* the switch.
- The comment above `abilityRow()` in `scripts/wr_tools/panel.html`, which now
  records the trap: ability rows carry `data-ab`, action rows carry `data-i`.

## Assumptions

- Real payloads give every script-backed ability a `file` key (read from
  `abilities()` in `scripts/wr_tools/main.rb`); only the built-in `ghost` lacks
  one and renders as an orphan row. The test payload mirrors that.
- Not verified inside SketchUp. Everything here is headless Chrome against the
  real `panel.html` with the `sketchup` bridge stubbed; Benton runs
  `install-plugin.py` himself.

## Open questions

- Nothing blocking. The one judgement worth a second opinion is whether a click
  anywhere on an ability row is *too* easy to trigger — there is no undo prompt,
  though toggling back off undoes the work by design.
