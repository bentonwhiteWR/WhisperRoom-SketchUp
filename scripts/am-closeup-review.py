# -*- coding: utf-8 -*-
"""BUILD a self-contained review page of the close-up pilot.

    python scripts/am-closeup-review.py OUT.html [--folder DIR] [--spec JSON] [--shots pilot]

Reads the export folder's _closeups.json and PNGs (default
Z:/Sketchup/BoothBuilderViews/AssemblyCloseups) and scripts/am-closeups.json,
and writes one HTML file with every image embedded (downscaled to 1600 px wide)
and the anchor points drawn over it as an SVG layer in the image's own pixel
space, so the overlay is exactly what the app will receive. Shots that have no
image yet appear as a "not rendered" card naming their anchors and the steps
to render them. Re-run it after every pilot pass; it never touches the folder.
"""
import base64
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


def embed(path, width=1600):
    im = Image.open(path).convert('RGBA')
    if im.width > width:
        im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, 'PNG', optimize=True)
    return 'data:image/png;base64,' + base64.b64encode(buf.getvalue()).decode('ascii')


CSS = r'''
:root {
  /* Layout: one column of shot sheets, each a picture on paper with its data beside it. */
  --bg: #f3f2ef; --fg: #1d1f22; --muted: #5d636b; --rule: #d9d6cf;
  --sheet: #ffffff; --paper: #ffffff; --grid: #e7e4dd;
  --accent: #ee6216; --accent-ink: #b8460a;
  --ok: #2f7d4f; --warn: #a86a00; --bad: #b3261e;
  --display: "Barlow Semi Condensed", "Arial Narrow", Arial, sans-serif;
  --body: "Barlow", "Segoe UI", Arial, sans-serif;
  --mono: "JetBrains Mono", Consolas, "Courier New", monospace;
}
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --bg: #17191c; --fg: #e9e7e3; --muted: #a3a8af; --rule: #33373d;
  --sheet: #1f2226; --paper: #eceae6; --grid: #d6d3cc;
  --accent: #ff7a33; --accent-ink: #ff9a5e;
  --ok: #5fbf86; --warn: #e0a640; --bad: #f2867d; color-scheme: dark } }
:root[data-theme="dark"] {
  --bg: #17191c; --fg: #e9e7e3; --muted: #a3a8af; --rule: #33373d;
  --sheet: #1f2226; --paper: #eceae6; --grid: #d6d3cc;
  --accent: #ff7a33; --accent-ink: #ff9a5e;
  --ok: #5fbf86; --warn: #e0a640; --bad: #f2867d; color-scheme: dark }
body { background: var(--bg); color: var(--fg); font: 15px/1.5 var(--body); }
.wrap { max-width: 1180px; margin: 0 auto; padding-inline: 16px; padding-block: 28px 64px; display: grid; grid-template-columns: minmax(0, 1fr); gap: 28px; }
header { display: grid; gap: 6px; }
.eyebrow { font: 600 12px/1 var(--display); letter-spacing: .12em; text-transform: uppercase; color: var(--accent-ink); }
h1 { font: 700 34px/1.1 var(--display); margin: 0; text-wrap: balance; }
h2 { font: 700 22px/1.2 var(--display); margin: 0; text-wrap: balance; }
h3 { font: 600 13px/1.2 var(--display); letter-spacing: .08em; text-transform: uppercase; color: var(--muted); margin: 0; }
p { margin: 0; max-width: 70ch; }
.lede { color: var(--muted); }
.tally { display: flex; flex-wrap: wrap; gap: 8px; }
.pill { font: 600 12px/1 var(--display); letter-spacing: .06em; text-transform: uppercase; padding: 6px 10px; border-radius: 999px; border: 1px solid var(--rule); }
.pill.ok { color: var(--ok); border-color: currentColor; }
.pill.wait { color: var(--warn); border-color: currentColor; }
.pill.bad { color: var(--bad); border-color: currentColor; }
.sheet { min-width: 0; background: var(--sheet); border: 1px solid var(--rule); border-radius: 6px; padding: 18px; display: grid; gap: 14px; }
.sheet-head { display: flex; flex-wrap: wrap; align-items: baseline; gap: 8px 14px; }
.sid { font: 700 14px/1 var(--mono); color: var(--accent-ink); }
.body { display: grid; grid-template-columns: minmax(0, 1.7fr) minmax(0, 1fr); gap: 18px; }
@media (max-width: 820px) { .body { grid-template-columns: minmax(0, 1fr); } }
figure { margin: 0; display: grid; grid-template-columns: minmax(0, 1fr); gap: 6px; min-width: 0; }
.paper { position: relative; background: var(--paper); border: 1px solid var(--rule); border-radius: 4px; overflow: hidden;
  background-image: linear-gradient(var(--grid) 1px, transparent 1px), linear-gradient(90deg, var(--grid) 1px, transparent 1px);
  background-size: 24px 24px; aspect-ratio: 2400 / 1553; max-width: 100%; }
.paper img, .paper svg { position: absolute; inset: 0; width: 100%; height: 100%; }
.paper .empty { position: absolute; inset: 0; display: grid; place-content: center; text-align: center; gap: 6px; color: #5d636b; padding: 16px; }
.paper .empty b { font: 700 18px/1.2 var(--display); color: #1d1f22; }
.anchor-dot { fill: var(--accent); stroke: #fff; stroke-width: 4; }
.anchor-ring { fill: none; stroke: var(--accent); stroke-width: 3; }
.anchor-label { font: 600 44px var(--mono); fill: #1d1f22; paint-order: stroke; stroke: #fff; stroke-width: 8; }
.hide-overlay svg { display: none; }
figcaption { overflow-wrap: anywhere; font-size: 13px; color: var(--muted); display: flex; flex-wrap: wrap; gap: 6px 14px; align-items: center; }
label.toggle { display: inline-flex; gap: 6px; align-items: center; cursor: pointer; color: var(--fg); }
input[type=checkbox] { accent-color: var(--accent); }
input[type=checkbox]:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
.side { display: grid; grid-template-columns: minmax(0, 1fr); gap: 14px; align-content: start; min-width: 0; }
table { border-collapse: collapse; width: 100%; font: 13px/1.4 var(--mono); font-variant-numeric: tabular-nums; }
th, td { text-align: left; padding: 5px 6px; border-bottom: 1px solid var(--rule); vertical-align: top; }
th { font: 600 11px/1.2 var(--display); letter-spacing: .08em; text-transform: uppercase; color: var(--muted); }
.tbl { overflow-x: auto; }
.note { font-size: 14px; overflow-wrap: anywhere; }
.sheet-head h2 { min-width: 0; overflow-wrap: anywhere; }
.note.differs { border-left: 3px solid var(--accent); padding-left: 10px; }
.steps { min-width: 0; background: var(--sheet); border: 1px solid var(--rule); border-radius: 6px; padding: 18px; display: grid; grid-template-columns: minmax(0, 1fr); gap: 10px; }
.steps ol { margin: 0; padding-left: 20px; display: grid; grid-template-columns: minmax(0, 1fr); gap: 8px; }
.steps li { min-width: 0; }
code, pre { font: 12.5px/1.5 var(--mono); }
pre { margin: 0; padding: 10px 12px; background: var(--bg); border: 1px solid var(--rule); border-radius: 4px; overflow-x: auto; white-space: pre; }
.muted { color: var(--muted); }
'''


def main(argv):
    if not argv or argv[0].startswith('--'):
        print(__doc__)
        return 2
    out = argv[0]
    opt = {'--folder': DEF_FOLDER, '--spec': os.path.join(HERE, 'am-closeups.json'), '--shots': 'pilot'}
    i = 1
    while i < len(argv):
        opt[argv[i]] = argv[i + 1]
        i += 2
    spec = json.load(open(opt['--spec'], encoding='utf-8'))
    jpath = os.path.join(opt['--folder'], '_closeups.json')
    rows = {}
    if os.path.isfile(jpath):
        for r in json.load(open(jpath, encoding='utf-8')).get('images', []):
            rows[(r['shot'], r['variant'])] = r

    jobs = []
    for sid in sorted(spec['shots']):
        pose = spec['shots'][sid].get('pose')
        if not pose:
            continue
        vs = pose.get('pilot_variants', []) if opt['--shots'] == 'pilot' else list(pose['variants'])
        for v in vs:
            jobs.append((sid, v))

    sheets = []
    done = 0
    for sid, var in jobs:
        shot = spec['shots'][sid]
        pose = shot['pose']
        vp = pose['variants'][var]
        base = pose.get('base', {})
        anchors_spec = dict(base.get('anchors', {}))
        anchors_spec.update(vp.get('anchors', {}))
        r = rows.get((sid, var))
        png = os.path.join(opt['--folder'], r['file']) if r else None
        if r and os.path.isfile(png):
            done += 1
            w, h = r['w'], r['h']
            marks = []
            for nm, xy in (r.get('anchors') or {}).items():
                if xy is None:
                    continue
                x, y = xy
                anchor = 'end' if x > w * 0.75 else 'start'
                dx = -22 if anchor == 'end' else 22
                marks.append('<circle class="anchor-ring" cx="%.1f" cy="%.1f" r="22"/>'
                             '<circle class="anchor-dot" cx="%.1f" cy="%.1f" r="9"/>'
                             '<text class="anchor-label" x="%.1f" y="%.1f" text-anchor="%s">%s</text>'
                             % (x, y, x, y, x + dx, y - 26, anchor, esc(nm)))
            pic = ('<img src="%s" alt="%s %s close-up render">'
                   '<svg viewBox="0 0 %d %d" aria-hidden="true">%s</svg>'
                   % (embed(png), esc(sid), esc(var), w, h, ''.join(marks)))
            state = '<span class="pill ok">rendered</span>'
            rows_html = ''.join(
                '<tr><td>%s</td><td>%s</td><td>%s</td></tr>'
                % (esc(nm), esc('%.1f, %.1f' % tuple(xy)) if xy else '-',
                   'in frame' if (r.get('anchors_meta', {}).get(nm, {}).get('in_frame')) else 'OUTSIDE')
                for nm, xy in (r.get('anchors') or {}).items())
            rows_html += ''.join('<tr><td>%s</td><td>-</td><td>did not resolve</td></tr>' % esc(nm)
                                 for nm in r.get('anchors_missing') or [])
            cam = r.get('camera') or {}
            ipp = r.get('in_per_px')
            capt = '%s x %s px' % (w, h)
            if ipp:
                capt += ' &middot; %.4f in/px (%.0f in view)' % (ipp, ipp * h)
            if cam.get('azimuth') is not None:
                capt += ' &middot; azimuth %.0f, elevation %.0f' % (cam['azimuth'], cam['elevation'])
            warn = ''.join('<li>%s</li>' % esc(x) for x in r.get('warnings') or [])
        else:
            blocked = vp.get('blocked')
            pic = ('<div class="empty"><b>%s</b><span>%s</span></div>'
                   % ('Blocked' if blocked else 'Not rendered yet',
                      esc(blocked) if blocked else 'Run the pilot (steps at the bottom), then rebuild this page.'))
            state = '<span class="pill wait">waiting</span>' if not blocked else '<span class="pill bad">blocked</span>'
            rows_html = ''.join('<tr><td>%s</td><td>-</td><td>pending</td></tr>' % esc(nm) for nm in anchors_spec)
            capt = '2400 x 1553 px canvas, transparent PNG'
            warn = ''
        file_name = '%s_%s.png' % (sid, var)
        sheets.append('''
<section class="sheet" id="%(id)s">
  <div class="sheet-head"><span class="sid">%(sid)s &middot; %(var)s</span><h2>%(title)s</h2>%(state)s</div>
  <div class="body">
    <figure>
      <div class="paper">%(pic)s</div>
      <figcaption><span>%(file)s &middot; %(capt)s</span>
        <label class="toggle"><input type="checkbox" id="ov-%(id)s" checked> anchor points</label></figcaption>
    </figure>
    <div class="side">
      <div class="tbl"><table><thead><tr><th>Anchor</th><th>Pixel x, y</th><th>State</th></tr></thead><tbody>%(rows)s</tbody></table></div>
      <div><h3>Model vs storyboard</h3><p class="note differs">%(differs)s</p></div>
      <div><h3>Storyboard</h3><p class="note muted">%(story)s</p></div>
      %(warn)s
    </div>
  </div>
</section>''' % {
            'id': esc((sid + '-' + var).lower()), 'sid': esc(sid), 'var': esc(var), 'title': esc(shot['title']),
            'state': state, 'pic': pic, 'file': esc(file_name), 'capt': capt, 'rows': rows_html,
            'differs': esc(pose.get('_differs', '')), 'story': esc(pose.get('_storyboard', '')),
            'warn': ('<div><h3>Warnings from the run</h3><ul class="note">%s</ul></div>' % warn) if warn else ''})

    total = len(jobs)
    pills = ('<span class="pill %s">%d of %d rendered</span>' % ('ok' if done == total else 'wait', done, total))
    page = '''<title>Close-up Pilot</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow:wght@400;600&family=Barlow+Semi+Condensed:wght@600;700&family=JetBrains+Mono:wght@400;600&display=swap">
<style>%(css)s</style>
<div class="wrap">
<header>
  <span class="eyebrow">Assembly manual &middot; close-up insets</span>
  <h1>Close-up Pilot</h1>
  <p class="lede">The five pilot shots from the SketchUp close-up rig: CU-03 door-frame adaptors, CU-01 seam-seal bolt line,
  CU-06 HX H-strip and extension, CU-08 hanging the door, CU-19 roof-mount duct box on the port tube.
  Orange points are the anchor pixels the app will draw its callout labels at. No text is baked into the renders.</p>
  <div class="tally">%(pills)s</div>
</header>
%(sheets)s
<section class="steps" id="run">
  <h2>Render the pilot</h2>
  <p>SketchUp 2026 must be open with the WhisperRoom bridge on. Each command runs only the shots that belong to the open model and restores the model exactly. Nothing is saved.</p>
  <ol>
    <li>Open <code>Z:\\Sketchup\\BoothBuilderClaude\\Master Component List AM.skp</code> (CU-03, CU-06, CU-08). Dry run first, then render:
<pre>python scripts/sketchup-bridge.py eval "load File.join(WhisperRoom::Tools::SCRIPTS_DIR, 'am-closeup-export.rb'); WR_AmCloseups.run('shots' =&gt; 'pilot', 'dry' =&gt; true)" --timeout 600 --write-root "Z:/Sketchup/BoothBuilderViews/AssemblyCloseups"
python scripts/sketchup-bridge.py eval "load File.join(WhisperRoom::Tools::SCRIPTS_DIR, 'am-closeup-export.rb'); WR_AmCloseups.run('shots' =&gt; 'pilot', 'dry' =&gt; false)" --timeout 900 --write-root "Z:/Sketchup/BoothBuilderViews/AssemblyCloseups"</pre></li>
    <li>Open <code>Z:\\Sketchup\\Assembly\\RM Detailed Assembly.skp</code> (CU-01, CU-19) and run the same two commands.</li>
    <li>Check the folder, then rebuild this page:
<pre>python scripts/am-closeup-check.py
python scripts/am-closeup-review.py "&lt;this file&gt;"</pre></li>
  </ol>
</section>
</div>
<script>
document.querySelectorAll('.toggle input').forEach(function (cb) {
  cb.addEventListener('change', function () {
    cb.closest('figure').classList.toggle('hide-overlay', !cb.checked);
  });
});
</script>
''' % {'css': CSS, 'pills': pills, 'sheets': ''.join(sheets)}
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    with open(out, 'w', encoding='utf-8', newline='\n') as f:
        f.write(page)
    print('wrote %s  (%d of %d pilot images embedded, %.0f KB)' % (out, done, total, os.path.getsize(out) / 1024))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
