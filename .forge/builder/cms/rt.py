# -*- coding: utf-8 -*-
"""Community Music School: render ONE V-Ray frame of a scene through the bridge, never blocking a job.
A copy of ../concept-art/rt.py pointed at cms/render.rb (WR_CMSRender); the sun is never touched.

    python rt.py OUT.png --page "SCENE NAME" [--w 800 --h 600 --min 1.0 --thr 0.05 --ev 14.23
                                             --stops 0 --shoulder 0.8 --timeout 1800]

NEVER OVERWRITES: if OUT.png (or its .hdr) exists, -2, -3 ... is appended before anything starts.
Start job: size/budget, exposure, the page's hidden room pieces + camera (without selecting the page),
render_production, running-state latch. Then WR_CMSRender.poll in SHORT jobs until :idleDone, save!
(PNG + EXR + HDR + V-Ray render elements), then ../concept-art/finish.py -> OUT-final.png.
Prints one JSON line."""
import json, os, subprocess, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'scripts'))
from importlib import import_module  # noqa: E402
br = import_module('sketchup-bridge')
RBP = os.path.join(HERE, 'render.rb').replace('\\', '/')
RB = "load '%s' unless defined?(WR_CMSRender)\n" % RBP


def opt(a, k, d):
    return a[a.index(k) + 1] if k in a else d


def job(ruby, timeout=60, roots=None, label='cms-rt'):
    return br.submit(RB + ruby, timeout=timeout, label=label, write_roots=roots or [])


def unique(out):
    base, ext = out[:-4], out[-4:]
    k, cand = 2, out
    while any(os.path.exists(cand[:-4] + s) for s in ('.png', '.hdr', '.exr', '-final.png')):
        cand = '%s-%d%s' % (base, k, ext)
        k += 1
    return cand


def main(a):
    out = unique(os.path.abspath(a[0]).replace('\\', '/'))
    page = opt(a, '--page', None)
    w, h = int(opt(a, '--w', 800)), int(opt(a, '--h', 600))
    start = ("R = WR_CMSRender\nout = {}\n"
             "out['settings'] = R.settings!(%d, %d, %s, %s)\n"
             "out['ev'] = R.ev!(%s).round(2)\n"
             "out['stage'] = R.stage_page!(%s)\n"
             + ("out['sun_mult'] = R.sun_intensity!(%s)\n" % float(opt(a, '--sunmult', 0)) if '--sunmult' in a else '') +
             "out['start'] = R.start!\nout\n") % (w, h, float(opt(a, '--min', 1.0)), float(opt(a, '--thr', 0.05)),
                                                   float(opt(a, '--ev', 14.23)), json.dumps(page))
    # the start job always RE-loads render.rb, so an edited driver is never shadowed by the copy
    # SketchUp already holds (the polls keep the `unless defined?` load)
    r = br.submit("load '%s'\n" % RBP + start, timeout=120, label='cms-rt-start', write_roots=[])
    if r.get('status') != 'ok':
        print(json.dumps({'error': 'start failed', 'detail': r.get('error') or r}))
        return 1
    started = r.get('value')
    t0, last = time.time(), None
    while True:
        try:
            p = job('WR_CMSRender.poll', timeout=45)
        except Exception as e:  # noqa: BLE001
            p = {'status': 'busy', 'error': str(e)}
        v = p.get('value') if isinstance(p, dict) else None
        if isinstance(v, dict):
            last = v
            if v.get('done'):
                break
            if not v.get('latched'):
                print(json.dumps({'error': 'render never latched', 'poll': v, 'started': started}))
                return 1
        if time.time() - t0 > float(opt(a, '--timeout', 1800)):
            print(json.dumps({'error': 'timeout', 'last': last}))
            return 1
        time.sleep(6)
    d = os.path.dirname(out)
    os.makedirs(d, exist_ok=True)
    s = job('WR_CMSRender.save!(%s)' % json.dumps(out), timeout=180, roots=[d])
    base = out[:-4]
    fin = subprocess.run([sys.executable, os.path.join(HERE, '..', 'concept-art', 'finish.py'), base, base + '-final.png',
                          '--stops', opt(a, '--stops', '0'), '--shoulder', opt(a, '--shoulder', '0.8')],
                         capture_output=True, text=True)
    print(json.dumps({'out': out, 'started': started, 'poll': last, 'save': s.get('value'), 'save_status': s.get('status'),
                      'finish': (fin.stdout.strip() or fin.stderr.strip())[-600:]}))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
