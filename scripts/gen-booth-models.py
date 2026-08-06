import json, sys
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

SRC = r'C:\Users\bento\Documents\Claude\WhisperRoomQuote\whisperroom-catalog\data\models.json'
DST = r'C:\Users\bento\Documents\Claude\Sketchup\reference\booth-models.md'

d = json.load(open(SRC, encoding='utf-8'))

header = """# WhisperRoom booth models — quick lookup

**Source of truth:** `C:\\Users\\bento\\Documents\\Claude\\WhisperRoomQuote\\whisperroom-catalog\\data\\models.json`
(catalog v{ver} — verbatim from the 2026 WhisperRoom Product Catalog v37, prices locked by
Gabe; HubSpot's price book is a downstream copy). **Re-read the JSON before quoting a price
or a weight** — this table is a convenience copy and will drift.

**Prices are internal.** Never put one in a client-facing artifact unless Benton asks.

Dimensions are **exterior** — width x depth x height — which is what you check fit against.
Std ceiling is 6'-11", Enhanced is 7'-1".

| Model | Std dims (W x D x H) | Std lbs | Std price | Enh dims | Enh lbs | Enh price | Window | Vents | Foam | Cables | LEDs |
|---|---|---|---|---|---|---|---|---|---|---|---|
""".format(ver=d.get('version'))

rows = []
for m in d['models']:
    n, sd, sl, sp, ed, el, ep, win, v, f, c, l = m
    rows.append('| **{}** | {} | {} | {} | {} | {} | {} | {} | {} | {} | {} | {} |'.format(
        n, sd, sl, sp, ed, el, ep, win, v, f, c, l))

footer = """
## Reading this table

- **Window / Vents / Foam / Cables / LEDs** are the standard-configuration counts included
  with that model, not maximums. Options and package rules live in `options.json`,
  `packages.json`, and `compatibility.json` in the same folder — check compatibility before
  promising an option on a given model.
- **Enhanced** is the higher-isolation build: heavier, 2 in taller, and roughly 1.6–1.9x the
  standard price. If a client is choosing on acoustics, that is the axis.
- Booths ship as flat panels and assemble in place, so the **delivery path** constrains fit
  as much as the room does.
- Top-down plan art for walls, doors, and vents is in
  `...\\WhisperRoomQuote\\assets\\topdown\\`; elevation art in `...\\assets\\booth-art\\`.

## Acoustics

The only defensible customer-facing figure is the website's **ASTM E336 dB range**. Never
cite STC. Never use the word "soundproof."
"""

open(DST, 'w', encoding='utf-8').write(header + '\n'.join(rows) + '\n' + footer)
print('wrote', DST, len(d['models']), 'models')
