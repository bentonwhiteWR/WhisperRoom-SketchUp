# -*- coding: utf-8 -*-
"""Render a list of shots from shots.json, one after another, through rt.py.

    python batch.py ID [ID ...] [--w 2560 --h 1440 --min 5 --thr 0.015 --ev 14.23
                                 --az 195 --el 14 --sunmult 3.0 --prefix final]

Each frame lands in <deliverables>/work/<prefix>-<ID>.png (+ .hdr and V-Ray's
render elements). One JSON line per frame is appended to work/batch.jsonl.
Grading into the delivered PNG / review JPEG is a separate step (grade.py),
done after each frame has been looked at.
"""
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = 'C:/Users/bento/Desktop/WhisperRoom Concept Art/96120-studio/work'


def opt(argv, k, d):
    return argv[argv.index(k) + 1] if k in argv else d


def main(argv):
    ids = [a for i, a in enumerate(argv) if not a.startswith('--') and
           (i == 0 or not argv[i - 1].startswith('--'))]
    shots = {s['id']: s for s in json.load(open(os.path.join(HERE, 'shots.json')))['shots']}
    prefix = opt(argv, '--prefix', 'final')
    os.makedirs(OUT, exist_ok=True)
    for sid in ids:
        s = shots[sid]
        out = '%s/%s-%s.png' % (OUT, prefix, sid)
        cmd = [sys.executable, os.path.join(HERE, 'rt.py'), 'run', out]
        if s.get('page'):
            cmd += ['--page', s['page']]
        else:
            cmd += ['--cam', s['cam']]
        for k, d in (('--w', '2560'), ('--h', '1440'), ('--min', '5'), ('--thr', '0.015'),
                     ('--ev', '14.23'), ('--az', '195'), ('--el', '14'), ('--sunmult', '3.0')):
            cmd += [k, opt(argv, k, d)]
        t0 = time.time()
        p = subprocess.run(cmd, capture_output=True, text=True)
        line = (p.stdout.strip().splitlines() or [''])[-1]
        try:
            rec = json.loads(line)
        except ValueError:
            rec = {'error': 'unparsed', 'stdout': p.stdout[-800:], 'stderr': p.stderr[-800:]}
        rec.update({'id': sid, 'out': out, 'wall_s': round(time.time() - t0, 1), 'cmd': cmd[3:]})
        with open(os.path.join(OUT, 'batch.jsonl'), 'a', encoding='utf-8') as fh:
            fh.write(json.dumps(rec) + '\n')
        print('%s %s %.0fs' % (sid, 'ERROR' if rec.get('error') or (rec.get('saved') or {}).get('error') else 'ok',
                                time.time() - t0), flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
