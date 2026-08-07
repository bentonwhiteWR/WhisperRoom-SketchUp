# Docs

Self-contained pages — open any of them straight off disk in a browser, no
build step and no network. Each one carries a working demo rather than a
screenshot, because the demo is usually the argument.

| Page | What it is |
|---|---|
| [`exploded-views.html`](exploded-views.html) | Pull a booth apart with a slider. Switch Direction to **Radial** to see why one-axis-per-part is the default — that comparison is the decision `explode-view.rb` turns on. |
| [`room-tools-scope.html`](room-tools-scope.html) | The scope for the three room tools. The wall-run editor at the top **is** `build-room.html`'s interface — change a run and watch the chain close or fail. |
| [`assembly-manual-plan.html`](assembly-manual-plan.html) | The plan for the per-customer assembly manual. Drag the pendant jig; the filename underneath changes as it turns, which is what `orbit-export.rb` writes. |
| [`tube-drying-stand.html`](tube-drying-stand.html) | Drawing sheet for the 60-up drying stand — plan, section, lean trade-off, and the printability audit. |

These are also published as Artifacts on claude.ai. **The copies here are the
ones under version control**, so if the two disagree, this folder is the record.

## Why they're in the repo

They hold reasoning that isn't recoverable from the code: why the jig prints
socket-up, why a square pocket beats a round one, why chains have to close
before anything is built. `DEVLOG.md` carries the same decisions in prose;
these carry them in a form you can poke at.
