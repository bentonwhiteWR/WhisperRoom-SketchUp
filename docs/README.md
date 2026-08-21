# Docs

Self-contained pages — open any of them straight off disk in a browser, no
build step and no network. Each one carries a working demo rather than a
screenshot, because the demo is usually the argument.

| Page | What it is |
|---|---|
| [`exploded-views.html`](exploded-views.html) | Pull a booth apart with a slider. Switch Direction to **Radial** to see why one-axis-per-part is the default — that comparison is the decision `explode-view.rb` turns on. |
| [`room-tools-scope.html`](room-tools-scope.html) | The scope for the three room tools. The wall-run editor at the top **is** `build-room.html`'s interface — change a run and watch the chain close or fail. |
| [`assembly-manual-plan.html`](assembly-manual-plan.html) | The plan for the per-customer assembly manual. Drag the pendant jig; the filename underneath changes as it turns, which is what `orbit-export.rb` writes. |
| [`tube-drying-stand.html`](tube-drying-stand.html) | **Design sheet.** The 60-up drying stand, now two 5 × 6 parts sized to a 92 × 135 silicone tray — tray-fit plan, live three-quarter view, section, lean trade-off, printability audit. |
| [`pendant-jig.html`](pendant-jig.html) | **Design sheet.** Rev B of the curing jig — section on the axis, live cutaway, and the two fit-tested changes that came off the printed Rev A. |
| [`spray-guide.html`](spray-guide.html) | **Design sheet.** Rev C of the Studio Light spray guide — plan, centreline section, live view, and the Rev A correction that turned a "slot" back into the raised step it always was. |

These are also published as Artifacts on claude.ai. **The copies here are the
ones under version control**, so if the two disagree, this folder is the record.

## Design sheets

The sheets marked above are the standard format for anything we design from
here on. `reference/design-sheet.md` is the spec: structure, the provenance
ranking, the drawing rules, and what the live 3D view has to do. **Copy the
newest sheet and edit it — never start one from scratch.**

## Why they're in the repo

They hold reasoning that isn't recoverable from the code: why the jig prints
socket-up, why a square pocket beats a round one, why chains have to close
before anything is built. `DEVLOG.md` carries the same decisions in prose;
these carry them in a form you can poke at.
