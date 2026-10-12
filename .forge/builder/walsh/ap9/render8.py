"""Render the v8 review page and per-wall elevation PNGs from layout-v8*.json.

    python render8.py            # writes review-v8.html, elev/<wall>.png (+ elev/<wall>-opt2.png)

Elevations are drawn to one scale, as seen from INSIDE the booth (S and E run right-to-left in booth
coordinates). Grey = fixed items from the observed survey; colour = the derived layout.
"""
import json, os, html, subprocess, tempfile
from v8model import fixed, RUN, FLOOR, TILE, CENTRE, usable

HERE = os.path.dirname(os.path.abspath(__file__))
CHROME = r'C:\Program Files\Google\Chrome\Application\chrome.exe'
PX = 4.8                       # px per inch, same for every wall
FONT = 2.1                     # label size, inches
VIEW_FLIP = {'S': True, 'E': True, 'W': False, 'N': False}
TITLE = {'S': 'Back wall (S)', 'E': 'Left wall (E)', 'W': 'Right wall (W)', 'N': 'Front wall (N, door)'}
FIXLABEL = {'trap': 'trap', 'cover': None, 'beam': None, 'ceiling seal': None, 'window trim': None, 'door': 'door (N3)',
            'door frame return': None, 'window panel return': None, 'corner': None}

def load(fn): return json.load(open(os.path.join(HERE, fn)))

def esc(s): return html.escape(str(s), quote=True)

def fmt(v):
    s = f'{v:.3f}'.rstrip('0').rstrip('.')
    return s

def svg_wall(wall, W, uid):
    lo, hi = RUN[wall]
    flip = VIEW_FLIP[wall]
    ML, MR, MT, MB = 15.0, 5.0, 9.0, 13.0
    ZT, ZB = TILE + 2.0, FLOOR - 2.75
    vw = (hi - lo) + ML + MR
    vh = (ZT - ZB) + MT + MB
    X = lambda s: ML + ((hi - s) if flip else (s - lo))
    Y = lambda z: MT + (ZT - z)
    def rx(s0, s1): a, b = X(s0), X(s1); return min(a, b), abs(b - a)
    pct = 100 * vw / ((RUN['S'][1] - RUN['S'][0]) + ML + MR)     # same scale on every wall, S fills the card
    o = [f'<svg class="elev" viewBox="0 0 {vw:.2f} {vh:.2f}" width="{vw * PX:.0f}" height="{vh * PX:.0f}" '
         f'style="width:{pct:.2f}%;height:auto;min-width:{vw * 3.6:.0f}px" role="img" '
         f'aria-label="{esc(TITLE[wall])} elevation seen from inside the booth" xmlns="http://www.w3.org/2000/svg">']
    o.append(f'<defs><pattern id="h{uid}" width="1.6" height="1.6" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">'
             f'<rect width="1.6" height="1.6" class="fx-bg"/><line x1="0" y1="0" x2="0" y2="1.6" class="fx-hatch"/></pattern></defs>')
    # wall face, floor and tile
    x0, w0 = rx(lo, hi)
    o.append(f'<rect x="{x0:.3f}" y="{Y(TILE):.3f}" width="{w0:.3f}" height="{TILE - FLOOR:.3f}" class="face"/>')
    o.append(f'<rect x="{x0:.3f}" y="{Y(FLOOR):.3f}" width="{w0:.3f}" height="2.75" class="slab"/>')
    o.append(f'<rect x="{x0:.3f}" y="{Y(TILE + 1.6):.3f}" width="{w0:.3f}" height="1.6" class="slab"/>')
    o.append(f'<text x="{x0 + 0.6:.2f}" y="{Y(TILE + 1.6) - 0.9:.2f}" class="t-small">ceiling tile 80.25</text>')
    o.append(f'<text x="{x0 + 0.6:.2f}" y="{Y(0.2):.2f}" class="t-small">floor (EFP top) 2.75</text>')
    # fixed items (observed)
    labelled_trap = False
    for kind, name, s0, s1, z0, z1 in fixed(wall):
        x, w = rx(max(s0, lo), min(s1, hi))
        if w <= 0: continue
        z0c, z1c = max(z0, FLOOR), min(z1, TILE)
        cls = 'fx-dark' if kind in ('beam', 'ceiling seal') else ('fx-ghost' if kind == 'corner' else 'fx')
        fill = '' if cls != 'fx' else f' fill="url(#h{uid})"'
        o.append(f'<rect x="{x:.3f}" y="{Y(z1c):.3f}" width="{w:.3f}" height="{z1c - z0c:.3f}" class="{cls}"{fill}><title>{esc(name)}: '
                 f'{fmt(s0)}-{fmt(s1)}, z {fmt(z0)}-{fmt(z1)} (observed)</title></rect>')
        lab = None
        if kind == 'cover':
            lab = name.split()[-1].replace('i', '') + (' hi' if ' hi ' in name else ' lo')
        elif kind == 'window trim':
            lab = 'window ' + name.split()[0].replace('i', '')
        elif kind == 'trap' and not labelled_trap and z0 > 20 and z1 < 60:
            lab = 'traps'
        elif kind == 'door':
            lab = 'door frame N3'
        if lab and w > 5:
            o.append(f'<text x="{x + w / 2:.2f}" y="{Y((z0c + z1c) / 2) + FONT * 0.35:.2f}" class="t-fix t-mid">{esc(lab)}</text>')
            if kind == 'trap': labelled_trap = True
    # pieces (derived): fills first, then the axis, then labels on top
    labels = []
    for p in W['pieces']:
        x, w = rx(p['s0'], p['s1'])
        h = p['z1'] - p['z0']
        cls = 'pc-foam' if p['material'] == 'foam' else 'pc-ap'
        typ = {'Foam': 'Foam', 'Audimute2x4': 'AP 2x4', 'Audimute1x4': 'AP 1x4', 'Audimute1x2': 'AP 1x2'}[p['part']]
        o.append(f'<g><title>{p["id"]} {typ} {p["orient"]}: {fmt(p["s0"])}-{fmt(p["s1"])}, z {fmt(p["z0"])}-{fmt(p["z1"])} '
                 f'(nearest fixed: {esc(p["nearest_fixed"])} {p["gap_fixed"]:.2f})</title>'
                 f'<rect x="{x:.3f}" y="{Y(p["z1"]):.3f}" width="{w:.3f}" height="{h:.3f}" class="{cls}"/></g>')
        cxp, cyp = x + w / 2, Y(p['z1']) + h / 2
        size = f'{p["w"]:.0f}×{p["h"]:.0f}'
        if h >= 20 and w >= 20:
            lines = [(p['id'], 't-id'), (typ, 't-pc'), (size, 't-dim')]
        elif h >= 20:            # narrow standing piece
            lines = [(p['id'], 't-id'), (typ.replace('AP ', ''), 't-pc'), (size, 't-dim')]
        else:                    # flat 1x2
            lines = [(f'{p["id"]} · {typ.replace("AP ", "")}', 't-id')]
        step = FONT * 1.15
        y = cyp - step * (len(lines) - 1) / 2 + FONT * 0.35
        for t, c in lines:
            labels.append(f'<text x="{cxp:.2f}" y="{y:.2f}" class="{c} t-mid halo-{cls[3:]}">{esc(t)}</text>')
            y += step
    # mirror axis, over the pieces
    cx = X(W['centre'])
    o.append(f'<line x1="{cx:.3f}" y1="{Y(TILE):.3f}" x2="{cx:.3f}" y2="{Y(FLOOR):.3f}" class="axis"/>')
    o.append(f'<text x="{cx:.2f}" y="{Y(FLOOR) + 9.6:.2f}" class="t-small t-mid">centre {fmt(W["centre"])}</text>')
    o += labels
    # z ordinates (left), merged where labels would collide
    zs = sorted({FLOOR, TILE} | {v for p in W['pieces'] for v in (p['z0'], p['z1'])})
    groups = []
    for z in zs:
        if groups and z - groups[-1][-1] < FONT * 1.25: groups[-1].append(z)
        else: groups.append([z])
    for g in groups:
        for z in g:
            o.append(f'<line x1="{ML - 2.2:.2f}" y1="{Y(z):.3f}" x2="{ML - 0.4:.2f}" y2="{Y(z):.3f}" class="tick"/>')
        zc = sum(g) / len(g)
        o.append(f'<text x="{ML - 2.8:.2f}" y="{Y(zc) + FONT * 0.33:.2f}" class="t-ord t-end">{fmt(g[0]) if len(g) == 1 else fmt(g[0]) + "–" + fmt(g[-1])}</text>')
    o.append(f'<text x="{ML - 2.8:.2f}" y="{MT - 4.2:.2f}" class="t-small t-end">z</text>')
    # s ticks (bottom), booth coordinates
    yb = Y(FLOOR) + 3.2
    o.append(f'<line x1="{X(lo):.2f}" y1="{yb:.2f}" x2="{X(hi):.2f}" y2="{yb:.2f}" class="tick"/>')
    s = (int(lo // 12) + 1) * 12
    while s < hi:
        big = s % 24 == 0
        o.append(f'<line x1="{X(s):.2f}" y1="{yb:.2f}" x2="{X(s):.2f}" y2="{yb + (1.6 if big else 0.9):.2f}" class="tick"/>')
        if big: o.append(f'<text x="{X(s):.2f}" y="{yb + 4.2:.2f}" class="t-ord t-mid">{s}</text>')
        s += 12
    axis = 'booth x' if wall in 'SN' else 'booth y'
    arrow = '←' if flip else '→'
    o.append(f'<text x="{X(lo) if flip else X(hi):.2f}" y="{yb + 8.4:.2f}" class="t-small t-end">'
             f'{axis} increases {arrow}</text>')
    # 24 in scale bar
    sx = X(lo) if flip else X(lo)
    o.append(f'<g class="scalebar"><rect x="{ML:.2f}" y="{MT - 6.2:.2f}" width="12" height="1" class="sb1"/>'
             f'<rect x="{ML + 12:.2f}" y="{MT - 6.2:.2f}" width="12" height="1" class="sb2"/>'
             f'<text x="{ML + 25.2:.2f}" y="{MT - 5.0:.2f}" class="t-small">24 in</text></g>')
    o.append('</svg>')
    return '\n'.join(o)

def table(W):
    r = ['<div class="tbl"><table><thead><tr><th>Id</th><th>Part</th><th>Hangs</th><th class="n">s from–to</th><th class="n">z from–to</th>'
         '<th>Nearest fixed item</th><th class="n">Gap</th><th class="n">Next piece</th></tr></thead><tbody>']
    for p in W['pieces']:
        tight = ' class="n tight"' if p['gap_fixed'] < 0.76 else ' class="n"'
        tp = ' class="n tight"' if p['gap_piece'] is not None and p['gap_piece'] < 0.76 else ' class="n"'
        sw = 'sw-foam' if p['material'] == 'foam' else 'sw-ap'
        r.append(f'<tr><td><span class="sw {sw}"></span>{p["id"]}</td><td>{p["part"]}</td><td>{p["orient"]}</td>'
                 f'<td class="n">{p["s0"]:.3f}–{p["s1"]:.3f}</td><td class="n">{p["z0"]:.3f}–{p["z1"]:.3f}</td>'
                 f'<td>{esc(p["nearest_fixed"])}</td><td{tight}>{p["gap_fixed"]:.3f}</td><td{tp}>{p["gap_piece"]:.3f}</td></tr>')
    r.append('</tbody></table></div>')
    return '\n'.join(r)

CSS = r"""
/* Working drawing: one column of to-scale wall elevations, each followed by its review controls. */
:root{
  --bg:#f5f7f8; --surface:#ffffff; --ink:#1b2228; --muted:#5a6670; --rule:#d3dae0;
  --accent:#ee6216; --accent-ink:#ffffff;
  --face:#eef2f4; --slab:#c9d1d7; --fx:#a7b0b8; --fx-bg:#dfe4e8; --fx-dark:#6e7881; --fx-hatch:#8a949c;
  --foam:#46657f; --foam-fill:#bccddb; --ap:#ee6216; --ap-fill:#f8c7a7; --tight:#b9480c; --ok:#2f7d4f;
  --f-head:"Barlow Semi Condensed","Arial Narrow",Arial,sans-serif;
  --f-body:"Barlow",Arial,sans-serif;
  --f-mono:"IBM Plex Mono",Consolas,monospace;
}
@media (prefers-color-scheme: dark){ :root:not([data-theme="light"]){
  --bg:#12171b; --surface:#192026; --ink:#e4e9ed; --muted:#9ba7b1; --rule:#2e3842;
  --accent:#f47a3a; --accent-ink:#12171b;
  --face:#1e262d; --slab:#3a444d; --fx:#56616b; --fx-bg:#2a333b; --fx-dark:#8a959f; --fx-hatch:#4a545d;
  --foam:#9dbad2; --foam-fill:#304a60; --ap:#f47a3a; --ap-fill:#6b3313; --tight:#ff9a5c; --ok:#6cc290; color-scheme:dark; } }
:root[data-theme="dark"]{
  --bg:#12171b; --surface:#192026; --ink:#e4e9ed; --muted:#9ba7b1; --rule:#2e3842;
  --accent:#f47a3a; --accent-ink:#12171b;
  --face:#1e262d; --slab:#3a444d; --fx:#56616b; --fx-bg:#2a333b; --fx-dark:#8a959f; --fx-hatch:#4a545d;
  --foam:#9dbad2; --foam-fill:#304a60; --ap:#f47a3a; --ap-fill:#6b3313; --tight:#ff9a5c; --ok:#6cc290; color-scheme:dark; }
body{background:var(--bg);color:var(--ink);font:15px/1.5 var(--f-body);}
.wrap{max-width:1000px;margin:0 auto;padding-inline:16px;padding-block:20px 48px;display:grid;gap:28px;}
h1,h2,h3{font-family:var(--f-head);font-weight:600;line-height:1.15;text-wrap:balance;margin:0}
h1{font-size:1.9rem} h2{font-size:1.35rem} h3{font-size:1.05rem}
p{margin:0;max-width:68ch}
.eyebrow{font:600 .78rem/1 var(--f-head);letter-spacing:.09em;text-transform:uppercase;color:var(--accent)}
.head{display:grid;gap:10px}
.meta{font-family:var(--f-mono);font-size:.8rem;color:var(--muted)}
.facts{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:12px}
.fact{background:var(--surface);border:1px solid var(--rule);border-radius:4px;padding:10px 12px;display:grid;gap:2px;min-width:0}
.fact b{font:600 1.15rem/1.2 var(--f-head)} .fact span{font-size:.85rem;color:var(--muted)}
.legend{display:flex;flex-wrap:wrap;gap:8px 18px;font-size:.85rem;color:var(--muted);align-items:center}
.legend i{display:inline-block;width:18px;height:12px;border:1.5px solid;vertical-align:-2px;margin-right:6px}
.lg-foam{background:var(--foam-fill);border-color:var(--foam)!important}
.lg-ap{background:var(--ap-fill);border-color:var(--ap)!important}
.lg-fx{background:repeating-linear-gradient(45deg,var(--fx-bg) 0 3px,var(--fx-hatch) 3px 4px);border-color:var(--fx)!important}
.lg-dk{background:var(--fx-dark);border-color:var(--fx-dark)!important}
.lg-ax{border:0!important;border-top:1.5px dashed var(--muted)!important;height:0!important}
.wall{background:var(--surface);border:1px solid var(--rule);border-radius:4px;padding:16px;display:grid;gap:12px;min-width:0}
.wall-h{display:flex;flex-wrap:wrap;gap:6px 16px;align-items:baseline;justify-content:space-between}
.wall-h .meta{white-space:normal}
.why{font-size:.92rem;color:var(--ink)} .why li{margin-block:2px}
.why ul{margin:0;padding-left:1.1rem;display:grid;gap:2px;max-width:75ch}
.draw{overflow-x:auto;border:1px solid var(--rule);background:var(--bg);border-radius:3px}
.elev{display:block;max-width:none}
.elev .face{fill:var(--face)} .elev .slab{fill:var(--slab)}
.elev .fx{stroke:var(--fx);stroke-width:.25} .elev .fx-bg{fill:var(--fx-bg)} .elev .fx-hatch{stroke:var(--fx-hatch);stroke-width:.35}
.elev .fx-dark{fill:var(--fx-dark)} .elev .fx-ghost{fill:none;stroke:var(--fx-dark);stroke-width:.25;stroke-dasharray:.8 .6}
.elev .pc-foam{fill:var(--foam-fill);stroke:var(--foam);stroke-width:.35}
.elev .pc-ap{fill:var(--ap-fill);stroke:var(--ap);stroke-width:.35}
.elev .axis{stroke:var(--ink);stroke-width:.2;stroke-dasharray:2.2 1 .4 1;opacity:.55}
.elev .tick{stroke:var(--muted);stroke-width:.2}
.elev .sb1{fill:var(--ink)} .elev .sb2{fill:none;stroke:var(--ink);stroke-width:.2}
.elev text{font-family:var(--f-head);fill:var(--ink)}
.elev .t-mid{text-anchor:middle}
.elev .halo-foam,.elev .halo-ap{paint-order:stroke;stroke-width:.7px;stroke-linejoin:round}
.elev .halo-foam{stroke:var(--foam-fill)} .elev .halo-ap{stroke:var(--ap-fill)} .elev .t-end{text-anchor:end}
.elev .t-id{font-size:2.1px;font-weight:600} .elev .t-pc{font-size:2.0px} .elev .t-dim{font-family:var(--f-mono);font-size:1.75px;fill:var(--muted)}
.elev .t-fix{font-size:1.9px;fill:var(--muted);font-style:italic} .elev .t-small{font-size:1.8px;fill:var(--muted)}
.elev .t-ord{font-family:var(--f-mono);font-size:1.6px;fill:var(--muted)}
.tbl{overflow-x:auto} table{border-collapse:collapse;font-size:.82rem;width:100%;min-width:720px}
th,td{padding:4px 8px;border-bottom:1px solid var(--rule);text-align:left;white-space:nowrap}
th{font:600 .74rem/1.2 var(--f-head);letter-spacing:.06em;text-transform:uppercase;color:var(--muted)}
td.n,th.n{text-align:right;font-family:var(--f-mono);font-variant-numeric:tabular-nums}
td.tight{color:var(--tight);font-weight:600}
.sw{display:inline-block;width:10px;height:10px;border:1.5px solid;margin-right:6px;vertical-align:-1px}
.sw-foam{background:var(--foam-fill);border-color:var(--foam)} .sw-ap{background:var(--ap-fill);border-color:var(--ap)}
.ctl{display:flex;flex-wrap:wrap;gap:10px 18px;align-items:flex-start;border-top:1px solid var(--rule);padding-top:12px}
.seg{display:inline-flex;border:1px solid var(--rule);border-radius:4px;overflow:hidden}
.seg button{font:600 .85rem/1 var(--f-head);letter-spacing:.03em;padding:9px 12px;border:0;background:var(--surface);color:var(--ink);cursor:pointer}
.seg button+button{border-left:1px solid var(--rule)}
.seg button[aria-pressed="true"]{background:var(--accent);color:var(--accent-ink)}
.seg button.chg[aria-pressed="true"]{background:var(--ink);color:var(--bg)}
button:focus-visible,textarea:focus-visible,select:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
.pick{display:grid;gap:4px;min-width:0} .pick label,.note label{font:600 .74rem/1 var(--f-head);letter-spacing:.06em;text-transform:uppercase;color:var(--muted)}
select,textarea{font:inherit;font-size:.9rem;color:var(--ink);background:var(--bg);border:1px solid var(--rule);border-radius:4px;padding:7px 8px;max-width:100%}
.note{display:grid;gap:4px;flex:1 1 260px;min-width:0} textarea{min-height:58px;resize:vertical;width:100%;box-sizing:border-box}
.opt-desc{font-size:.88rem;color:var(--muted);max-width:70ch}
.panel{background:var(--surface);border:1px solid var(--rule);border-radius:4px;padding:16px;display:grid;gap:10px;min-width:0}
.panel ul{margin:0;padding-left:1.1rem;display:grid;gap:4px;max-width:78ch;font-size:.92rem}
.copy textarea{font-family:var(--f-mono);font-size:.8rem;min-height:190px}
.copy .row{display:flex;gap:10px;align-items:center;flex-wrap:wrap}
.btn{font:600 .9rem/1 var(--f-head);padding:10px 16px;border-radius:4px;border:0;background:var(--accent);color:var(--accent-ink);cursor:pointer}
.status{font-size:.85rem;color:var(--ok)}
.prov{font-family:var(--f-mono);font-size:.72rem;letter-spacing:.04em;text-transform:uppercase;padding:2px 6px;border-radius:3px;border:1px solid var(--rule);color:var(--muted)}
@media (prefers-reduced-motion: reduce){*{transition:none!important}}
"""

FONTS = ('<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>'
         '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow:wght@400;500;600&family=Barlow+Semi+Condensed:wght@500;600&family=IBM+Plex+Mono:wght@400;500&display=swap">')

WHY = {
 'S': ['Holds 4 sheets + 9 1x2s, the most this wall takes (proved). Of the two ways to fit the whole package, this is the only one where the back wall can keep a clean bottom row and band (solver check).',
       'Two tiers like the other walls: a 24 in bottom row (z 3.25-27.25) and a band from z 27.75. The band tops out at 75.75, 0.50 under the IEP beams.',
       'The three high duct covers decide the rhythm: a stack of three flat 1x2s hangs under the S0 and S1 high covers and one standing 1x2 under S3 (tops 64.75, 0.68 under each cover). Sheets fill the gaps between.',
       'Not mirror-symmetric: the vent columns are not mirror-placed (S1 sits 12 in left of centre). Every band gap, including to the trap stacks, is the same 0.76 in.',
       '1x2s sit high (directly under the high covers) and low (the bottom-row pair). A row of 1x2s across the top is impossible here: the high covers and beams leave no 24 in slot above z 64.9.'],
 'E': ['Symmetric about its centre (y 54.69): Audimute 2x4 | foam | Audimute 2x4 over a row of 1x2 | foam 2x4 lying flat | 1x2.',
       'Same column grid as the right wall, with Audimute at both ends and foam in the middle, so the two side walls read as a pair.',
       'All gaps 1.0 in; 1.31 in to the trap stack and to the door-frame return.'],
 'W': ['The W0 duct covers take the back corner, so the back column is a cluster of small Audimute pieces: a flat 1x2 just above the low cover, then a standing 1x2 and the 1x4.',
       'That flat 1x2 is why this band starts at z 30.625, the lowest band that clears it (0.55 above the low cover). At full count no layout of this wall has a clean bottom row and band (solver check), so it cannot match the back wall levels.',
       'Columns line up with the left wall: Audimute | foam | Audimute 2x4, foam 2x4 lying flat under the two sheets.'],
 'N': ['Bottom row under the windows: foam 2x4 | standing 1x2 | foam 2x4, symmetric about its own centre (x 63.875). Right edge 0.50 off the door frame; the left foam edge lines up with the 1x4 above.',
       'The 1x4 fills the 13.0 in between the windows (0.50 to each trim, 0.50 under beam 1).',
       'Audimute 2x4 beside the door, flush with the row below, top 0.50 under the beams.'],
}
OPTS = {
 'S': [('S1', 'Audimute 2x4 in the band (recommended)', 'Band from inside, left to right: AP 1x2 | foam | AP 2x4 | AP 1x2 stack | foam | AP 1x2 stack. Foam 2x4 lies in the bottom row. Close to the People\'s Space back band (AP | foam | 2x4 | foam | AP).'),
       ('S2', 'Foam band, Audimute 2x4 in the bottom row', 'All three band sheets foam, so the band alternates foam with the Audimute stacks under each cover. The Audimute 2x4 lies flat in the bottom row, which then reads as all Audimute.')],
 'E': [('E1', 'Band level with the right wall (recommended)', 'Band z 30.625-78.625, the same as the right wall, so the two side walls frame the back wall evenly.'),
       ('E2', 'Band level with the back and front walls', 'Band z 27.75-75.75, the same as S and N. The right wall cannot drop to this height, so the side walls then differ by 2.875 in.')],
}

def build():
    v8 = load('layout-v8.json'); a1 = load('layout-v8-alt1.json'); a2 = load('layout-v8-alt2.json')
    walls = {'S': [('S1', v8), ('S2', a1)], 'E': [('E1', v8), ('E2', a2)], 'W': [('W1', v8)], 'N': [('N1', v8)]}
    order = ['S', 'E', 'W', 'N']
    svgs = {}
    parts = []
    for w in order:
        opts = walls[w]
        blocks = []
        for k, (oid, lay) in enumerate(opts):
            W = lay['walls'][w]
            svg = svg_wall(w, W, f'{w}{k}')
            svgs[(w, k)] = svg
            desc = ''
            if w in OPTS:
                desc = f'<p class="opt-desc"><b>{esc(OPTS[w][k][1])}.</b> {esc(OPTS[w][k][2])}</p>'
            blocks.append(f'<div class="opt" data-wall="{w}" data-opt="{oid}"{"" if k == 0 else " hidden"}>{desc}'
                          f'<div class="draw">{svg}</div>{table(W)}</div>')
        W0 = opts[0][1]['walls'][w]
        cnt = ', '.join(f'{v} {k}' for k, v in sorted(W0['counts'].items()))
        picker = ''
        if len(opts) > 1:
            o = ''.join(f'<option value="{oid}">{esc(OPTS[w][k][1])}</option>' for k, (oid, _) in enumerate(opts))
            picker = f'<div class="pick"><label for="pick-{w}">Option</label><select id="pick-{w}" data-wall="{w}">{o}</select></div>'
        parts.append(f'''<section class="wall" id="wall-{w}">
<div class="wall-h"><h2>{TITLE[w]}</h2><span class="meta">seen from inside · {esc(W0["viewed_from_inside"])} · {cnt}</span></div>
<div class="why"><ul>{"".join(f"<li>{esc(t)}</li>" for t in WHY[w])}</ul></div>
{"".join(blocks)}
<div class="ctl">
 {picker}
 <div class="pick"><label>Verdict</label><div class="seg" role="group" aria-label="Verdict for {TITLE[w]}">
  <button type="button" id="ok-{w}" data-wall="{w}" data-v="approve" aria-pressed="false">Approve</button>
  <button type="button" id="chg-{w}" class="chg" data-wall="{w}" data-v="change" aria-pressed="false">Needs change</button></div></div>
 <div class="note"><label for="note-{w}">Note</label><textarea id="note-{w}" data-wall="{w}" placeholder="What to change on this wall"></textarea></div>
</div></section>''')
    chk = v8['check']
    body = f'''<title>Walsh Booth Acoustic Layout</title>
<style>{CSS}</style>
{FONTS}
<main class="wrap">
<header class="head">
 <span class="eyebrow">Walsh Construction · Tech Lab · MDL 96168 E</span>
 <h1>Foam and Audimute layout v8, for review</h1>
 <p>All 9 foam sheets and the full Audimute package (5 × 2x4, 2 × 1x4, 14 × 1x2) fit inside the booth with no foam cut. Every wall is at its proven maximum, so there is no slack anywhere: the choices below are about pattern, not about what fits. Nothing has been changed in the SketchUp model yet.</p>
 <span class="meta">Layout v8 · {esc(v8["model"])} · offline check {"PASSED" if chk["ok"] else "FAILED"} · min gap piece to piece {chk["min_gaps"]["piece-piece"]:.2f} in, piece to fixed item {chk["min_gaps"]["piece-fixed"]:.2f} in</span>
</header>
<div class="facts">
 <div class="fact"><b>9 foam</b><span>6 already in the model, 3 copies to add</span></div>
 <div class="fact"><b>5 · 2 · 14</b><span>Audimute 2x4 · 1x4 · 1x2, all placed</span></div>
 <div class="fact"><b>0.50 in</b><span>smallest gap anywhere (rule: at least 0.50)</span></div>
 <div class="fact"><b>0 cut</b><span>full sheets only; squares not needed</span></div>
</div>
<div class="panel">
 <h3>How to read the drawings</h3>
 <div class="legend"><span><i class="lg-foam"></i>Foam (derived layout)</span><span><i class="lg-ap"></i>Audimute (derived layout)</span>
 <span><i class="lg-fx"></i>Fixed: traps, duct covers, windows, door frame <span class="prov">measured</span></span>
 <span><i class="lg-dk"></i>IEP beams and ceiling seals <span class="prov">measured</span></span><span><i class="lg-ax"></i>Wall centre</span></div>
 <p class="opt-desc">Each wall is drawn to the same scale as seen standing inside the booth. Grey items are the survey: measured by ray and bounds on the live model and re-checked against it on 12 Oct. Coloured pieces are the proposed layout, computed offline. Coordinates are booth inches (s along the wall, z up from the booth origin); gaps under 0.76 in are marked in the tables.</p>
</div>
{"".join(parts)}
<section class="panel">
 <h3>Rules, and where they bend</h3>
 <ul>
  <li>All 9 foam sheets inside, full Audimute package: met on every wall.</li>
  <li>At least 0.50 in between pieces and to every fixed item, z 3.25 to 79.75: met. The tightest spots are exactly 0.50 (sheet tops under the IEP beams, the 1x2 stacks, the bottom row under the band).</li>
  <li>Full sheets first, no cuts: met. The S1i sheet that v7 cut into two squares comes back as a full sheet.</li>
  <li>Mirror symmetry: the left wall exactly; the front wall's bottom row. The back wall cannot be: its three vent columns are not mirror-placed. The right wall's back corner is set by the W0 covers.</li>
  <li>Back wall foam and Audimute interleaved, 1x2s high and low: met as far as the covers allow. The 1x2s sit directly under the high covers and in the bottom row; no top row fits.</li>
  <li>Seven of the fourteen 1x2s stand on end (12 wide × 24 tall). Five is the minimum that fits; the other two keep the left wall symmetric.</li>
 </ul>
</section>
<section class="panel copy">
 <h3>Send your choices back</h3>
 <p class="opt-desc">Set a verdict on each wall, pick options, add notes, then copy this block and paste it into the chat.</p>
 <div class="note"><label for="note-all">General note</label><textarea id="note-all" placeholder="Anything that applies to the whole booth"></textarea></div>
 <textarea id="out" readonly aria-label="Choices to paste back"></textarea>
 <div class="row"><button type="button" class="btn" id="copy">Copy choices</button><span class="status" id="status" role="status"></span></div>
</section>
</main>
<script>
(function(){{
  var walls=["S","E","W","N"], state={{}};
  walls.forEach(function(w){{ var sel=document.getElementById("pick-"+w); state[w]={{option: sel? sel.value : w+"1", verdict:null, note:""}}; }});
  function render(){{
    var out={{walsh_ap_review:"v8", layout_files:["layout-v8.json","layout-v8-alt1.json","layout-v8-alt2.json"], walls:{{}}, general_note: document.getElementById("note-all").value.trim()}};
    walls.forEach(function(w){{ out.walls[w]={{option:state[w].option, verdict:state[w].verdict||"not set", note:state[w].note}}; }});
    document.getElementById("out").value=JSON.stringify(out,null,2);
  }}
  document.querySelectorAll("select[data-wall]").forEach(function(sel){{
    sel.addEventListener("change",function(){{ var w=sel.dataset.wall; state[w].option=sel.value;
      document.querySelectorAll('.opt[data-wall="'+w+'"]').forEach(function(d){{ d.hidden = d.dataset.opt!==sel.value; }}); render(); }});
  }});
  document.querySelectorAll(".seg button").forEach(function(b){{
    b.addEventListener("click",function(){{ var w=b.dataset.wall; var on=b.getAttribute("aria-pressed")!=="true";
      b.parentNode.querySelectorAll("button").forEach(function(x){{ x.setAttribute("aria-pressed","false"); }});
      if(on) b.setAttribute("aria-pressed","true"); state[w].verdict= on? b.dataset.v : null; render(); }});
  }});
  document.querySelectorAll("textarea[data-wall]").forEach(function(t){{ t.addEventListener("input",function(){{ state[t.dataset.wall].note=t.value.trim(); render(); }}); }});
  document.getElementById("note-all").addEventListener("input",render);
  document.getElementById("copy").addEventListener("click",function(){{
    var ta=document.getElementById("out"), st=document.getElementById("status");
    function fallback(){{ ta.focus(); ta.select(); st.textContent="Selected. Press Ctrl+C to copy."; }}
    try{{ navigator.clipboard.writeText(ta.value).then(function(){{ st.textContent="Copied. Paste it into the chat."; }}, fallback); }}catch(e){{ fallback(); }}
  }});
  render();
}})();
</script>'''
    open(os.path.join(HERE, 'review-v8.html'), 'w', encoding='utf-8').write(body)
    return svgs

def pngs(svgs):
    os.makedirs(os.path.join(HERE, 'elev'), exist_ok=True)
    tmp = tempfile.mkdtemp(prefix='elev8_')
    for (w, k), svg in svgs.items():
        name = w if k == 0 else f'{w}-opt{k + 1}'
        vw = float(svg.split('width="')[1].split('"')[0]); vh = float(svg.split('height="')[1].split('"')[0])
        page = (f'<!doctype html><html data-theme="light"><meta charset="utf-8">{FONTS}<style>{CSS} body{{margin:0;padding:12px;background:var(--bg)}}</style>'
                f'<div style="font:600 18px var(--f-head);margin:0 0 6px">{TITLE[w]}{"" if k == 0 else " · option " + str(k + 1)} · layout v8 · seen from inside</div>{svg}')
        fn = os.path.join(tmp, f'{name}.html'); open(fn, 'w', encoding='utf-8').write(page)
        out = os.path.join(HERE, 'elev', f'{name}.png')
        subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=2',
                        '--virtual-time-budget=4000', f'--window-size={int(vw) + 24},{int(vh) + 48}', f'--screenshot={out}', 'file:///' + fn.replace('\\', '/')],
                       check=True, capture_output=True, timeout=120)
        print('wrote', out)

if __name__ == '__main__':
    svgs = build()
    print('wrote', os.path.join(HERE, 'review-v8.html'))
    pngs(svgs)
