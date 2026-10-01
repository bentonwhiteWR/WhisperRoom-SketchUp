# -*- coding: utf-8 -*-
"""BUILD the self-contained close-up review page.

    python scripts/am-closeup-review.py [OUT.html] [--folder DIR] [--spec JSON]

OUT defaults to <folder>/Close-up Review.html. Reads, from the export folder
(default Z:/Sketchup/BoothBuilderViews/AssemblyCloseups):

    _closeups.json          the rig's rows (anchors, generated parts, camera)
    <shot>_<variant>.png    the renders (embedded, downscaled to 1400 px)
    _review/verdicts/       the reviewer's verdicts — THE STATUS COMES FROM THESE
    _review/queue/          attempt numbers
    _review/storyboard/     the storyboard panel per shot (embedded)
    _missing.json           missing-parts table (part, scenes, expected file, state)
    _generated/_generated.json + _generated/thumbs/  the generated stand-ins

and scripts/am-closeups.json for every shot and variant. Status per image:

    rendered               the reviewer passed it
    rendered-needs-tuning  three attempts, last verdict "revise" (issues listed)
    unreviewed             a render exists but no verdict arrived
    skipped                a part is missing (named)
    blocked                any other reason (named)

One HTML file, every image embedded, opens from the Z: drive with no network
(fonts fall back to system fonts).
"""
import base64
import glob
import html
import io
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
DEF_FOLDER = 'Z:/Sketchup/BoothBuilderViews/AssemblyCloseups'


def esc(s):
    return html.escape(str(s if s is not None else ''), quote=True)


def embed(path, width=1400, fmt='PNG'):
    im = Image.open(path).convert('RGBA')
    if im.width > width:
        im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
    bg = Image.new('RGBA', im.size, (255, 255, 255, 255))
    bg.alpha_composite(im)
    buf = io.BytesIO()
    if fmt == 'JPEG':
        bg.convert('RGB').save(buf, 'JPEG', quality=86)
        return 'data:image/jpeg;base64,' + base64.b64encode(buf.getvalue()).decode('ascii')
    bg.save(buf, 'PNG', optimize=True)
    return 'data:image/png;base64,' + base64.b64encode(buf.getvalue()).decode('ascii')


def attempts(qdir, key):
    out = []
    for f in glob.glob(os.path.join(qdir, key + '.a*.json')):
        try:
            out.append(int(f.rsplit('.a', 1)[1].split('.')[0]))
        except ValueError:
            pass
    return sorted(out)


def verdict(folder, key):
    rv = os.path.join(folder, '_review')
    a = attempts(os.path.join(rv, 'queue'), key)
    if not a:
        return 0, None
    f = os.path.join(rv, 'verdicts', '%s.a%d.json' % (key, a[-1]))
    v = json.load(open(f, encoding='utf-8')) if os.path.isfile(f) else None
    return a[-1], v


def status_of(folder, key, vpose, png_exists):
    if vpose.get('blocked'):
        txt = str(vpose['blocked'])
        return ('skipped' if txt.upper().startswith('MISSING PART') else 'blocked'), txt, [], 0
    n, v = verdict(folder, key)
    if v is None:
        return ('unreviewed' if png_exists else 'not-rendered'), ('attempt %d has no verdict' % n if n else ''), [], n
    vd = v.get('verdict')
    if vd == 'pass':
        return 'rendered', '', [], n
    if vd == 'unfixable':
        r = v.get('reason') or '; '.join(v.get('issues') or [])
        return ('skipped' if 'missing' in r.lower() else 'blocked'), r, v.get('issues') or [], n
    return 'rendered-needs-tuning', 'last verdict: revise (attempt %d of 3)' % n, v.get('issues') or [], n


CSS = r'''
:root { --bg:#f3f2ef; --fg:#1d1f22; --muted:#5d636b; --rule:#d9d6cf; --sheet:#fff; --accent:#ee6216;
  --ok:#2f7d4f; --warn:#a86a00; --bad:#b3261e; --gen:#6b3fa0;
  --body: "Segoe UI", Arial, sans-serif; --mono: Consolas, "Courier New", monospace; }
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { --bg:#17191c; --fg:#e9e7e3; --muted:#a3a8af;
  --rule:#33373d; --sheet:#1f2226; --ok:#5fbf86; --warn:#e0a640; --bad:#f2867d; --gen:#c4a2f0; color-scheme: dark } }
:root[data-theme="dark"] { --bg:#17191c; --fg:#e9e7e3; --muted:#a3a8af; --rule:#33373d; --sheet:#1f2226;
  --ok:#5fbf86; --warn:#e0a640; --bad:#f2867d; --gen:#c4a2f0; color-scheme: dark }
* { box-sizing: border-box }
body { margin:0; background: var(--bg); color: var(--fg); font: 15px/1.5 var(--body); overflow-x: hidden }
.wrap { max-width: 1280px; margin: 0 auto; padding: 24px 16px 64px; display: grid; gap: 22px; grid-template-columns: minmax(0,1fr) }
h1 { font-size: 30px; margin: 0 } h2 { font-size: 21px; margin: 0; overflow-wrap: anywhere } h3 { font-size: 13px; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); margin: 0 }
p { margin: 0; max-width: 80ch } .muted { color: var(--muted) }
.tally { display: flex; flex-wrap: wrap; gap: 8px }
.pill { font: 600 12px/1 var(--body); letter-spacing: .04em; text-transform: uppercase; padding: 6px 10px; border-radius: 999px; border: 1px solid currentColor; white-space: nowrap }
.ok { color: var(--ok) } .warn { color: var(--warn) } .bad { color: var(--bad) } .gen { color: var(--gen) } .mut { color: var(--muted) }
.card { background: var(--sheet); border: 1px solid var(--rule); border-radius: 6px; padding: 16px; display: grid; gap: 12px; min-width: 0 }
.head { display: flex; flex-wrap: wrap; gap: 6px 12px; align-items: baseline }
.sid { font: 700 14px var(--mono); color: var(--accent) }
.pair { display: grid; grid-template-columns: minmax(0,1fr) minmax(0,1.6fr); gap: 14px }
@media (max-width: 820px) { .pair { grid-template-columns: minmax(0,1fr) } }
figure { margin: 0; display: grid; gap: 6px; min-width: 0 }
figure img { width: 100%; height: auto; border: 1px solid var(--rule); border-radius: 4px; background: #fff; display: block }
figcaption { font-size: 12.5px; color: var(--muted); overflow-wrap: anywhere }
.empty { border: 1px dashed var(--rule); border-radius: 4px; padding: 18px; aspect-ratio: 2400/1553; display: grid; place-content: center; text-align: center; gap: 6px; overflow-wrap: anywhere }
table { border-collapse: collapse; width: 100%; font-size: 13px }
th, td { text-align: left; padding: 6px; border-bottom: 1px solid var(--rule); vertical-align: top; overflow-wrap: anywhere }
th { font-size: 11px; text-transform: uppercase; letter-spacing: .06em; color: var(--muted) }
.tbl { overflow-x: auto }
ul { margin: 0; padding-left: 18px } li { overflow-wrap: anywhere }
.variants { display: grid; gap: 14px }
.thumbs { display: flex; flex-wrap: wrap; gap: 10px } .thumbs figure { width: 150px }
code { font: 12.5px var(--mono) }
'''


def main(argv):
    opt = {'--folder': DEF_FOLDER, '--spec': os.path.join(HERE, 'am-closeups.json')}
    out = None
    i = 0
    while i < len(argv):
        if argv[i].startswith('--'):
            opt[argv[i]] = argv[i + 1]
            i += 2
        else:
            out = argv[i]
            i += 1
    folder = opt['--folder']
    out = out or os.path.join(folder, 'Close-up Review.html')
    spec = json.load(open(opt['--spec'], encoding='utf-8'))
    rows = {}
    jp = os.path.join(folder, '_closeups.json')
    if os.path.isfile(jp):
        for r in json.load(open(jp, encoding='utf-8')).get('images', []):
            rows[(r['shot'], r['variant'])] = r
    missing = []
    mp = os.path.join(folder, '_missing.json')
    if os.path.isfile(mp):
        missing = json.load(open(mp, encoding='utf-8')).get('parts', [])
    gens = []
    gp = os.path.join(folder, '_generated', '_generated.json')
    if os.path.isfile(gp):
        gens = json.load(open(gp, encoding='utf-8')).get('parts', [])

    counts = {}
    by_pri = {}
    cards = []
    gen_use = {}
    for sid in sorted(spec['shots']):
        shot = spec['shots'][sid]
        pri = shot.get('priority', '')
        pose = shot.get('pose') or {}
        variants = pose.get('variants') or {}
        if not variants:
            variants = {'(all)': {'blocked': shot.get('blocked_by') or 'not posed'}}
        sb = os.path.join(folder, '_review', 'storyboard', sid + '.png')
        sb_html = ('<figure><img src="%s" alt="%s storyboard panel"><figcaption>Storyboard panel</figcaption></figure>'
                   % (embed(sb, 700), esc(sid))) if os.path.isfile(sb) else '<div class="empty">No storyboard panel</div>'
        vblocks = []
        for var, vp in variants.items():
            key = '%s_%s' % (sid, var)
            png = os.path.join(folder, key + '.png')
            st, why, issues, n = status_of(folder, key, vp, os.path.isfile(png))
            counts[st] = counts.get(st, 0) + 1
            by_pri.setdefault(pri, {}).setdefault(st, 0)
            by_pri[pri][st] += 1
            r = rows.get((sid, var)) or {}
            gl = r.get('generated') or []
            for g in gl:
                gen_use.setdefault(g, set()).add(key)
            cls = {'rendered': 'ok', 'rendered-needs-tuning': 'warn', 'unreviewed': 'warn'}.get(st, 'bad')
            tags = '<span class="pill %s">%s</span>' % (cls, esc(st))
            tags += ''.join('<span class="pill gen">GENERATED: %s</span>' % esc(g.replace('GEN ', '')) for g in gl)
            if st in ('skipped', 'blocked', 'not-rendered') or not os.path.isfile(png):
                pic = '<div class="empty"><b>%s</b><span>%s</span></div>' % (esc(st), esc(why))
            else:
                pic = ('<figure><img src="%s" alt="%s render"><figcaption>%s.png &middot; attempt %d%s</figcaption></figure>'
                       % (embed(png, 1400, 'JPEG'), esc(key), esc(key), n, (' &middot; ' + esc(why)) if why else ''))
            iss = ''
            if issues:
                iss = '<div><h3>Reviewer issues (last verdict)</h3><ul>%s</ul></div>' % ''.join('<li>%s</li>' % esc(x) for x in issues)
            vblocks.append('<div class="variant"><div class="head"><span class="sid">%s</span>%s</div>%s%s</div>'
                           % (esc(var), tags, pic, iss))
        cards.append('''<section class="card" id="%(id)s"><div class="head"><span class="sid">%(sid)s</span><span class="pill mut">%(pri)s</span><h2>%(title)s</h2></div>
<div class="pair">%(sb)s<div class="variants">%(v)s</div></div>
<div><h3>Model vs storyboard</h3><p class="muted">%(diff)s</p></div></section>''' % {
            'id': esc(sid.lower()), 'sid': esc(sid), 'pri': esc(pri), 'title': esc(shot.get('title')), 'sb': sb_html,
            'v': ''.join(vblocks), 'diff': esc(pose.get('_differs', '') or shot.get('blocked_by', ''))})

    order = ['rendered', 'rendered-needs-tuning', 'unreviewed', 'skipped', 'blocked', 'not-rendered']
    pills = ''.join('<span class="pill %s">%d %s</span>' % (
        {'rendered': 'ok', 'rendered-needs-tuning': 'warn', 'unreviewed': 'warn'}.get(k, 'bad'), counts[k], k)
        for k in order if counts.get(k))
    pri_rows = ''.join('<tr><td>%s</td>%s</tr>' % (esc(p), ''.join('<td>%d</td>' % by_pri[p].get(k, 0) for k in order))
                       for p in sorted(by_pri))
    miss_rows = ''.join('<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td><code>%s</code></td></tr>' % (
        esc(m.get('part')), esc(', '.join(m.get('scenes', []))), esc(m.get('p1', '')), esc(m.get('state')), esc(m.get('expected_file')))
        for m in missing)
    gen_rows = []
    thumbs = []
    for g in gens:
        nm = g.get('name')
        tp = os.path.join(folder, '_generated', 'thumbs', nm + '.png')
        src = g.get('spec', {}).get('source', {})
        gen_rows.append('<tr><td><code>%s</code></td><td>%s</td><td>%s</td><td>%s</td></tr>' % (
            esc(os.path.basename(g.get('file', ''))), esc(' x '.join('%.3f' % v for v in g.get('size_in', []))),
            esc('; '.join('%s: %s' % (k, v) for k, v in src.items())), esc(', '.join(sorted(gen_use.get(nm, []))) or 'none yet')))
        if os.path.isfile(tp):
            thumbs.append('<figure><img src="%s" alt="%s"><figcaption>%s</figcaption></figure>' % (embed(tp, 300), esc(nm), esc(nm)))

    page = '''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Close-up Review</title><style>%(css)s</style></head><body><div class="wrap">
<header style="display:grid;gap:8px"><h1>Close-up Review</h1>
<p class="muted">Every assembly-manual close-up next to its storyboard panel. Status comes from the reviewer's verdict files
(<code>_review/verdicts</code>); "rendered" means the reviewer passed it. Images tagged GENERATED use a modelled stand-in from
<code>_generated/</code>, not a library part. Components come only from <code>Z:\\Sketchup\\NewMasterComponentList</code>.</p>
<div class="tally">%(pills)s</div>
<div class="tbl"><table><thead><tr><th>Priority</th>%(ph)s</tr></thead><tbody>%(prow)s</tbody></table></div></header>
<section class="card"><h2>Missing parts</h2><p class="muted">Sorted by how many P1 scenes each part unblocks. "Expected file" is the name the rig will load from NewMasterComponentList.</p>
<div class="tbl"><table><thead><tr><th>Part</th><th>Scenes</th><th>P1 unblocked</th><th>State</th><th>Expected file</th></tr></thead><tbody>%(miss)s</tbody></table></div></section>
<section class="card"><h2>Generated stand-in parts</h2><p class="muted">Saved only to <code>AssemblyCloseups\\_generated\\</code>, never to a library. Dimensions marked "guess" are not sourced.</p>
<div class="thumbs">%(thumbs)s</div>
<div class="tbl"><table><thead><tr><th>File</th><th>Size (in)</th><th>Dimension sources</th><th>Used in</th></tr></thead><tbody>%(gens)s</tbody></table></div></section>
%(cards)s
</div></body></html>''' % {'css': CSS, 'pills': pills, 'ph': ''.join('<th>%s</th>' % esc(k) for k in order), 'prow': pri_rows,
                          'miss': miss_rows, 'gens': ''.join(gen_rows), 'thumbs': ''.join(thumbs), 'cards': ''.join(cards)}
    with open(out, 'w', encoding='utf-8', newline='\n') as f:
        f.write(page)
    print('wrote %s (%.0f KB); %s' % (out, os.path.getsize(out) / 1024, json.dumps(counts)))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
