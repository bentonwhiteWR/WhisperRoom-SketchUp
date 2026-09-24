# -*- coding: utf-8 -*-
"""Tampa: render ONE page through the bridge like the proposal package does.
    python rt.py OUT.png --page "SCENE" [--w 800 --h 450 --timeout 1200]
Never overwrites (appends -2, -3 ...). Finishes with ../concept-art/finish.py --shoulder 1.0 (hard clip,
the VFB / package look) -> OUT-final.png."""
import json, os, subprocess, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'scripts'))
from importlib import import_module  # noqa: E402
br = import_module('sketchup-bridge')
RBP = os.path.join(HERE, 'render.rb').replace(chr(92), '/')


def opt(a, k, d):
    return a[a.index(k) + 1] if k in a else d


def main(a):
    out = os.path.abspath(a[0]).replace(chr(92), '/')
    base, k = out[:-4], 2
    while os.path.exists(out) or os.path.exists(out[:-4] + '-final.png'):
        out = '%s-%d.png' % (base, k); k += 1
    page = opt(a, '--page', None)
    w, h = int(opt(a, '--w', 800)), int(opt(a, '--h', 450))
    r0 = br.submit("load '%s'\nWR_TampaRender.stage!(%s, %d, %d)" % (RBP, json.dumps(page), w, h), timeout=60,
                   label='tampa-rt-stage', write_roots=[])
    if r0.get('status') != 'ok':
        print(json.dumps({'error': 'stage failed', 'detail': r0.get('error')})); return 1
    time.sleep(2)
    r = br.submit("WR_TampaRender.start!", timeout=60, label='tampa-rt-start', write_roots=[])
    if r.get('status') != 'ok' or not (r.get('value') or {}).get('latched'):
        print(json.dumps({'error': 'start failed', 'detail': r.get('error') or r.get('value')})); return 1
    t0, last, capped = time.time(), None, False
    while True:
        time.sleep(5)
        try:
            p = br.submit('WR_TampaRender.poll', timeout=45, label='tampa-poll', write_roots=[])
        except Exception as e:  # noqa: BLE001
            p = {'error': str(e)}
        v = p.get('value') if isinstance(p, dict) else None
        if isinstance(v, dict):
            last = v
            if v.get('done'):
                break
        if time.time() - t0 > float(opt(a, '--cap', 300)):
            # progressive frame: stop at the cap and keep the buffer (logged as capped)
            br.submit('WR_TampaRender.stop!', timeout=30, label='tampa-cap', write_roots=[])
            capped = True
    d = os.path.dirname(out)
    s = br.submit('WR_TampaRender.save!(%s)' % json.dumps(out), timeout=120, label='tampa-save', write_roots=[d])
    fin = subprocess.run([sys.executable, os.path.join(HERE, '..', 'concept-art', 'finish.py'), out[:-4], out[:-4] + '-final.png',
                          '--stops', '0', '--shoulder', '1.0'], capture_output=True, text=True)
    print(json.dumps({'out': out[:-4] + '-final.png', 'poll': last, 'capped': capped, 'save': s.get('value') or s.get('error'),
                      'finish': (fin.stdout.strip() or fin.stderr.strip())[-400:]}))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
