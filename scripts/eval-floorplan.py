# -*- coding: utf-8 -*-
"""Score a floor-plan eval case against ground truth, in inches, live.

    python eval-floorplan.py <case>            # a dir under eval/floorplans/
    python eval-floorplan.py <case> --record   # append the row to eval/RESULTS.md
    python eval-floorplan.py <case> --json     # machine-readable blob too

Tier 1 of the eval loop (spec: .forge/scoper/floorplan-intake.md §B). The
case's take-off runs through scripts/takeoff-check.py; the lock builds every
room in the LIVE SketchUp through the bridge (scripts/sketchup-bridge.py ->
scripts/build-takeoff.rb); WRB.takeoff_readback reports what actually got
built, in each room's own frame; this compares that against the case's
truth.json and prints a table in inches. Exit 0 only when every threshold
holds:

    max vertex error <= tolerance (0.1" deterministic; truth may widen it)
    door jamb error  <= tolerance          (where truth knows the jambs)
    ceiling delta    <= tolerance
    every feature in truth present, none missing
    unflagged-assumed count == 0   (a truth value marked expect_flag must
        have its ASSUMED note in the model — a right-looking number that
        was guessed and not flagged is a FAILING score, that is the point)

A case directory holds:
    takeoff.json   the fixture (or case.json pointing at one elsewhere)
    truth.json     {"rooms":[{room, tolerance_in, polygon, ceiling_in,
                    doors:[{run, w_in, jambs_in|null, expect_flag}],
                    features:[{type, count}], ...}]}
    README.md      what the case exercises, where truth came from

Scratch models only (GOAL rule): build-takeoff replaces its own room groups
by name and touches nothing else, but do not aim this at client work.
"""
import io
import json
import os
import subprocess
import sys
import time
from importlib import import_module

sys.stdout.reconfigure(encoding='utf-8', errors='replace')
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

DET_TOL = 0.1     # deterministic tier-1 threshold — the math is exact,
                  # anything more than 0.1" is a bug, not noise


def fail(msg, code=2):
    print(msg)
    sys.exit(code)


def load_case(case):
    d = case if os.path.isdir(case) else os.path.join(ROOT, 'eval', 'floorplans', case)
    if not os.path.isdir(d):
        fail('no such case: %s' % case)
    cfgp = os.path.join(d, 'case.json')
    cfg = json.load(open(cfgp, encoding='utf-8')) if os.path.exists(cfgp) else {}
    takeoff = os.path.normpath(os.path.join(d, cfg.get('takeoff', 'takeoff.json')))
    truthp = os.path.normpath(os.path.join(d, cfg.get('truth', 'truth.json')))
    if not os.path.exists(takeoff):
        fail('%s: no take-off at %s' % (case, takeoff))
    if not os.path.exists(truthp):
        fail('%s: no truth.json' % case)
    truth = json.load(open(truthp, encoding='utf-8'))
    return d, takeoff, truth, cfg.get('rooms')


def run_checker(takeoff):
    r = subprocess.run([sys.executable, os.path.join(HERE, 'takeoff-check.py'),
                        takeoff], capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def build_and_read(lock, room_names):
    br = import_module('sketchup-bridge')
    names_rb = 'nil' if room_names is None else \
        '[' + ', '.join(json.dumps(n) for n in room_names) + ']'
    job = (
        "load File.join(WhisperRoom::Tools::SCRIPTS_DIR, 'wr-bridge-lib.rb')\n"
        "WRB.tool('build-takeoff')\n"
        "WR_BuildTakeoff.build_from(%s)\n"
        "WRB.takeoff_readback(%s)\n" % (json.dumps(lock.replace('\\', '/')),
                                        names_rb))
    r = br.submit(job, timeout=120, label='eval-floorplan')
    if r.get('status') != 'ok':
        fail('bridge job failed: %s\n%s' % (r.get('status'),
                                            r.get('error') or r.get('output', '')), 1)
    return r['value']


def nearest(p, pts):
    return min(((q[0] - p[0]) ** 2 + (q[1] - p[1]) ** 2) ** 0.5 for q in pts)


def score_room(truth, built):
    tol = float(truth.get('tolerance_in', DET_TOL))
    out = {'room': truth['room'], 'tolerance_in': tol, 'errors': []}
    floor = (built or {}).get('floor')
    if not built:
        out['errors'].append('room was not built at all')
        return out
    if not floor:
        out['errors'].append('no floor face read back')
        return out
    tv = truth['polygon']
    out['vertex_count'] = (len(floor), len(tv))
    if len(floor) != len(tv):
        out['errors'].append('vertex count %d, truth has %d' % (len(floor), len(tv)))
    out['max_vertex_err_in'] = round(max(nearest(p, floor) for p in tv), 3)
    if out['max_vertex_err_in'] > tol:
        out['errors'].append('max vertex error %.2f" > %.2f"'
                             % (out['max_vertex_err_in'], tol))

    if truth.get('ceiling_in') is not None:
        cz = built.get('ceiling_z')
        if cz is None:
            out['errors'].append('no ceiling slab in the model')
        else:
            out['ceiling_delta_in'] = round(abs(cz - truth['ceiling_in']), 3)
            if out['ceiling_delta_in'] > tol:
                out['errors'].append('ceiling off by %.2f"' % out['ceiling_delta_in'])

    openings = built.get('openings') or []
    notes = ' | '.join(built.get('notes') or [])
    out['unflagged_assumed'] = 0
    jamb_errs = []
    tdoors = truth.get('doors') or []
    if len(openings) != len(tdoors):
        out['errors'].append('%d door opening(s) built, truth has %d'
                             % (len(openings), len(tdoors)))
    if built.get('leaf_count') is not None and \
            built.get('leaf_count') != built.get('opening_count'):
        out['errors'].append('leaf/opening mismatch (%d leaves, %d openings) — '
                             'a leaf in solid wall'
                             % (built['leaf_count'], built['opening_count']))
    for i, td in enumerate(tdoors):
        if td.get('jambs_in'):
            # Truth knows where the jambs are: find the opening whose extent
            # along its run matches. Openings are axis-aligned boxes; compare
            # the box's long-axis span against the jamb pair mapped into the
            # room frame by the truth polygon's run.
            a, b = td['jambs_in']
            best = None
            for op in openings:
                lo = [min(op['min'][k], op['max'][k]) for k in (0, 1)]
                hi = [max(op['min'][k], op['max'][k]) for k in (0, 1)]
                axis = 0 if (hi[0] - lo[0]) >= (hi[1] - lo[1]) else 1
                span = (lo[axis], hi[axis])
                exp = expected_jambs(truth['polygon'], td['run'], a, b, axis)
                if exp is None:
                    continue
                err = max(abs(span[0] - exp[0]), abs(span[1] - exp[1]))
                best = err if best is None else min(best, err)
            if best is None:
                out['errors'].append('door %d: no opening matches its run axis' % i)
            else:
                jamb_errs.append(best)
                if best > tol:
                    out['errors'].append('door %d jamb error %.2f" > %.2f"'
                                         % (i, best, tol))
        if td.get('expect_flag'):
            want = 'door %d at %s' % (i, td['expect_flag'].upper())
            if want not in notes:
                out['unflagged_assumed'] += 1
                out['errors'].append('door %d position is %s in truth but the '
                                     'model carries no "%s" note — an unflagged '
                                     'assumption scores as a failure even when '
                                     'the number is right'
                                     % (i, td['expect_flag'], want))
    if jamb_errs:
        out['max_jamb_err_in'] = round(max(jamb_errs), 3)

    built_types = {}
    for f in built.get('features') or []:
        t = f['name'].split(' ')[0].lower()
        built_types[t] = built_types.get(t, 0) + 1
    for tf in truth.get('features') or []:
        want = int(tf.get('count', 1))
        got = built_types.get(tf['type'], 0)
        if got < want:
            out['errors'].append('feature missing: %d x %s in truth, %d built'
                                 % (want, tf['type'], got))
    return out


def expected_jambs(poly, run, a, b, axis):
    """World-frame span of a door's jambs along `axis`, from truth polygon
    vertex `run` toward the next vertex, `a`..`b` inches from the corner."""
    n = len(poly)
    p0 = poly[run % n]
    p1 = poly[(run + 1) % n]
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    ln = (dx * dx + dy * dy) ** 0.5
    if ln < 1e-9:
        return None
    ux, uy = dx / ln, dy / ln
    u = (ux, uy)[axis]
    if abs(u) < 0.5:
        return None       # door's run does not lie along this axis
    j0 = p0[axis] + u * a
    j1 = p0[axis] + u * b
    return (min(j0, j1), max(j0, j1))


def main(argv):
    if not argv:
        fail(__doc__)
    case = argv[0]
    record = '--record' in argv
    want_json = '--json' in argv
    cased, takeoff, truth, room_filter = load_case(case)

    code, log = run_checker(takeoff)
    if code != 0:
        print(log)
        fail('%s: checker refused the take-off — nothing was built. If this '
             'case EXPECTS refusal, that refusal is the result; read the '
             'names above.' % case, 1)
    lock = takeoff.replace('.json', '.lock.json')

    rooms_truth = truth['rooms']
    names = room_filter or [r['room'] for r in rooms_truth]
    built = {r['name']: r for r in build_and_read(lock, None)}

    results = []
    worst = 0.0
    failed = False
    print('')
    print('EVAL  %s   (tolerances per truth.json; deterministic floor %.1f")'
          % (case, DET_TOL))
    print('')
    for rt in rooms_truth:
        if rt['room'] not in names:
            continue
        s = score_room(rt, built.get(rt['room']))
        results.append(s)
        ok = not s['errors']
        failed = failed or not ok
        worst = max(worst, s.get('max_vertex_err_in', 99.0))
        print('  %-4s %-10s vertex %5s\"  jamb %5s\"  ceiling %5s\"  unflagged %d'
              % ('PASS' if ok else 'FAIL', s['room'],
                 s.get('max_vertex_err_in', '—'),
                 s.get('max_jamb_err_in', '—'),
                 s.get('ceiling_delta_in', '—'),
                 s.get('unflagged_assumed', 0)))
        for e in s['errors']:
            print('         %s' % e)
    print('')
    if want_json:
        print(json.dumps({'case': case, 'results': results}, indent=2))
    if record:
        row = ('| %s | %s | %s | %.2f" | %s |\n'
               % (time.strftime('%Y-%m-%d %H:%M'), os.path.basename(case.rstrip('/\\')),
                  'PASS' if not failed else 'FAIL', worst,
                  '; '.join(e for s in results for e in s['errors']) or 'clean'))
        ledger = os.path.join(ROOT, 'eval', 'RESULTS.md')
        with io.open(ledger, 'a', encoding='utf-8', newline='\n') as f:
            f.write(row)
        print('  recorded in eval/RESULTS.md')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
