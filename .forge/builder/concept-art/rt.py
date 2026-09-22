# -*- coding: utf-8 -*-
"""Render one V-Ray frame through the bridge, without ever blocking a job.

    python rt.py run OUT.png [--page NAME | --cam "ex,ey,ez;tx,ty,tz;fov"]
                 [--w 960 --h 540 --min 2.5 --thr 0.03 --ev 14.23 --az 195 --el 14
                  --sunmult 1.0 --stops 0 --shoulder 0.8 --timeout 3600 --jpg OUT.jpg]
    python rt.py wait-save OUT.png [--timeout 1800]

run: one short job sets the frame's globals and runs rt-start.rb (size, EV,
the page's hidden room pieces + camera or an explicit camera, the sun, then
render_production and the running-state latch). Then WR_ConceptRender.poll in
SHORT separate jobs until :idleDone, then save! (PNG + EXR + HDR and V-Ray's
own render elements, e.g. OUT.denoiser.png), then finish.py -> OUT-final.png.
Prints one JSON line.
"""
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'scripts'))
from importlib import import_module  # noqa: E402
br = import_module('sketchup-bridge')

RB = ("load 'C:/Users/bento/Documents/Claude/Sketchup/.forge/builder/concept-art/render.rb' "
      "unless defined?(WR_ConceptRender)\n")


def opt(argv, k, d):
    return argv[argv.index(k) + 1] if k in argv else d


def job(ruby, timeout=60, roots=None, label='rt'):
    return br.submit(RB + ruby, timeout=timeout, label=label, write_roots=roots or [])


def wait_save(out, timeout):
    t0 = time.time()
    last = None
    while True:
        try:
            r = job('WR_ConceptRender.poll', timeout=45)
        except Exception as e:  # noqa: BLE001 - a busy SketchUp is not fatal here
            r = {'status': 'busy', 'error': str(e)}
        v = r.get('value') if isinstance(r, dict) else None
        if isinstance(v, dict):
            last = v
            if v.get('done'):
                break
            if not v.get('latched'):
                return {'error': 'render never latched', 'poll': v}
        if time.time() - t0 > timeout:
            return {'error': 'timeout', 'last': last}
        time.sleep(8)
    d = os.path.dirname(out)
    os.makedirs(d, exist_ok=True)
    r = job('WR_ConceptRender.save!(%s)' % json.dumps(out), timeout=180, roots=[d])
    res = {'poll': last, 'save': r.get('value'), 'status': r.get('status')}
    if r.get('status') != 'ok':
        res['error'] = r.get('error') or r.get('stderr')
    return res


def run(argv):
    out = os.path.abspath(argv[1]).replace('\\', '/')
    g = {'$rt_w': int(opt(argv, '--w', 960)), '$rt_h': int(opt(argv, '--h', 540)),
         '$rt_min': float(opt(argv, '--min', 2.5)), '$rt_thr': float(opt(argv, '--thr', 0.03)),
         '$rt_ev': float(opt(argv, '--ev', 14.23)), '$rt_az': float(opt(argv, '--az', 195)),
         '$rt_el': float(opt(argv, '--el', 14)), '$rt_sun_mult': float(opt(argv, '--sunmult', 1.0))}
    page = opt(argv, '--page', None)
    cam = opt(argv, '--cam', None)
    lines = ['%s = %s' % (k, json.dumps(v)) for k, v in g.items()]
    lines.append('$rt_page = %s' % (json.dumps(page) if page else 'nil'))
    if cam:
        e, t, f = cam.split(';')
        lines.append('$rt_eye = [%s]; $rt_tgt = [%s]; $rt_fov = %s' % (e, t, f))
    with open(os.path.join(HERE, 'rt-start.rb'), encoding='utf-8') as fh:
        start = fh.read()
    r = br.submit('\n'.join(lines) + '\n' + start, timeout=120, label='rt-start')
    if r.get('status') != 'ok':
        print(json.dumps({'error': 'start failed', 'detail': r.get('error') or r}))
        return 1
    started = r.get('value')
    saved = wait_save(out, float(opt(argv, '--timeout', 3600)))
    if saved.get('error'):
        print(json.dumps({'started': started, 'saved': saved}))
        return 1
    base = out[:-4]
    cmd = [sys.executable, os.path.join(HERE, 'finish.py'), base, base + '-final.png',
           '--stops', opt(argv, '--stops', '0'), '--shoulder', opt(argv, '--shoulder', '0.8')]
    if '--jpg' in argv:
        cmd += ['--jpg', opt(argv, '--jpg', None)]
    fin = subprocess.run(cmd, capture_output=True, text=True)
    print(json.dumps({'started': started, 'saved': saved,
                      'finish': (fin.stdout.strip() or fin.stderr.strip())[-800:]}))
    return 0


def main(argv):
    if argv and argv[0] == 'run' and len(argv) >= 2:
        return run(argv)
    if argv and argv[0] == 'wait-save' and len(argv) >= 2:
        res = wait_save(os.path.abspath(argv[1]).replace('\\', '/'),
                        float(opt(argv, '--timeout', 1800)))
        print(json.dumps(res))
        return 1 if res.get('error') else 0
    print(__doc__)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
