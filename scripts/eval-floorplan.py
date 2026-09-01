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

case.json may also carry expectations — the negative cases the generator
authors on purpose (spec §B4: "cases 4 and 5 score behavior, not inches"):

    {"expects": {"refusal": ["runs do not close"]}}
        The checker MUST refuse, and every listed phrase must appear in its
        output. PASS = the named refusal; anything that builds is FAIL.
        These rows exist so a future change cannot silently un-fix a refusal.
    {"expects": {"score_fail": ["max vertex error"]}}
        The take-off validates and builds, but scoring MUST fail with every
        listed phrase — a planted defect (mis-transcription, fabricated
        provenance) that only the scorer can catch. PASS = defect detected.
    {"probe": true}
        Behavior unknown when authored; the run reports whatever happened
        and the verdict is recorded verbatim. Exit 0 either way — a probe
        has no pass condition until its README assigns one.

Scratch models only, and now ENFORCED rather than asked for: every build job
carries a guard that raises inside SketchUp, before any geometry is created,
unless the active model is Untitled — naming the model it refused. The run
also erases the groups it created and reads back to confirm they are gone.
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


def emit_json(want_json, obj):
    # --json must produce a blob on EVERY outcome — refusals and score-fail
    # verdicts included; a machine consumer that gets silence cannot tell a
    # refusal from a crash.
    if want_json:
        print(json.dumps(obj, indent=2))


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
    truth = None
    if os.path.exists(truthp):
        truth = json.load(open(truthp, encoding='utf-8'))
    elif not cfg.get('expects', {}).get('refusal'):
        fail('%s: no truth.json' % case)
    return d, takeoff, truth, cfg


def run_checker(takeoff):
    # WR_TAKEOFF_CHECK overrides the checker path — used when the working-tree
    # checker is mid-edit by someone else and the eval must pin a known build.
    # A pinned run says so out loud (and record_row stamps the ledger): a run
    # silently scoring a stale checker is exactly the unaccounted-for result
    # this scorer exists to prevent.
    pin = os.environ.get('WR_TAKEOFF_CHECK')
    chk = pin or os.path.join(HERE, 'takeoff-check.py')
    if pin:
        print('  CHECKER PINNED  WR_TAKEOFF_CHECK=%s' % pin)
    # encoding pinned to utf-8: the checker reconfigures its stdout to utf-8,
    # and text=True alone decodes with the locale (cp1252 here), which mangles
    # the checker's em-dashes and can raise outright on curly quotes.
    r = subprocess.run([sys.executable, chk, takeoff],
                       capture_output=True, text=True,
                       encoding='utf-8', errors='replace')
    return r.returncode, r.stdout + r.stderr


# Top-level groups THIS process built, [entityID, name]. Registered at build
# time and erased by the cleanup pass in main()'s finally, so a run that
# fails, refuses or raises still takes its debris with it.
_BUILT = []

# The scratch-model fence. `.forge/GOAL.md` has said "scratch models only,
# never run bridge jobs against live client work" since the mission started
# and nothing enforced it; on 31 Aug 2026 a suite run was very nearly issued
# while Benton had RoofMountedVentilation.skp open and dirty, which would have
# dropped 26 case rooms into his unsaved work.
#
# The check has to be INSIDE the job, not a separate probe before it. The
# active model can change between two bridge calls — it changed under this
# session in the minutes between one agent reading the model and the next —
# so a Python-side pre-flight proves only what was true a moment ago.
# SketchUp's Ruby is single-threaded, so a guard in the same job as the build
# is atomic with it: the model cannot change between the assert and the first
# entity created. An Untitled model is one whose `path` is empty.
SCRATCH_GUARD = (
    "_m = Sketchup.active_model\n"
    "if !_m.path.to_s.strip.empty?\n"
    "  raise \"refusing to build: the active model is a SAVED file - \" \\\n"
    "        \"title #{_m.title.inspect}, path #{_m.path.inspect}. That is \" \\\n"
    "        \"the window in front of you now. The eval suite builds and \" \\\n"
    "        \"erases geometry and runs only against an Untitled scratch \" \\\n"
    "        \"model. Open a new model in SketchUp and re-run; do not \" \\\n"
    "        \"switch models on anyone's behalf while they are working.\"\n"
    "end\n")


def build_and_read(lock, room_names):
    """Build the lock's rooms and read them back. Returns (rooms, created_ids)
    where created_ids are the top-level groups THIS call added — the only
    entities the cleanup pass is allowed to touch."""
    br = import_module('sketchup-bridge')
    names_rb = 'nil' if room_names is None else \
        '[' + ', '.join(json.dumps(n) for n in room_names) + ']'
    job = (
        SCRATCH_GUARD +
        "_before = Sketchup.active_model.entities.grep(Sketchup::Group)"
        ".map(&:entityID)\n"
        "load File.join(WhisperRoom::Tools::SCRIPTS_DIR, 'wr-bridge-lib.rb')\n"
        "WRB.tool('build-takeoff')\n"
        "WR_BuildTakeoff.build_from(%s)\n"
        "_after = Sketchup.active_model.entities.grep(Sketchup::Group)\n"
        "{'rooms' => WRB.takeoff_readback(%s),\n"
        " 'created' => _after.reject { |g| _before.include?(g.entityID) }\n"
        "               .map { |g| [g.entityID, g.name.to_s] }}\n"
        % (json.dumps(lock.replace('\\', '/')), names_rb))
    r = br.submit(job, timeout=120, label='eval-floorplan')
    if r.get('status') != 'ok':
        fail('bridge job failed: %s\n%s' % (r.get('status'),
                                            r.get('error') or r.get('output', '')), 1)
    v = r['value']
    created = v.get('created') or []
    _BUILT.extend(created)
    return v['rooms'], created


def cleanup_built():
    """Erase exactly the groups this run created, then READ BACK to confirm
    they are gone. Do not skip the read-back and do not widen the scope.

    Both halves are paid for. A previous session's handoff reported its seven
    trial groups erased and read back empty, and on 31 Aug 2026 they were
    still sitting in the scratch model — a cleanup claim that did not hold is
    the same failure class as a wrong dimension that validates. And the debris
    is somebody else's until proven otherwise, so this erases by entityID
    captured at build time, never by name and never everything that looks like
    a room."""
    created = list(_BUILT)
    del _BUILT[:]
    if not created:
        return
    br = import_module('sketchup-bridge')
    ids = '[' + ', '.join(str(int(c[0])) for c in created) + ']'
    job = (
        "_want = %s\n"
        "_m = Sketchup.active_model\n"
        "_hit = _m.entities.grep(Sketchup::Group)"
        ".select { |g| _want.include?(g.entityID) }\n"
        "_named = _hit.map { |g| [g.entityID, g.name.to_s] }\n"
        "_m.entities.erase_entities(_hit) unless _hit.empty?\n"
        "_left = _m.entities.grep(Sketchup::Group)"
        ".select { |g| _want.include?(g.entityID) }\n"
        "{'erased' => _named,\n"
        " 'left' => _left.map { |g| [g.entityID, g.name.to_s] }}\n" % ids)
    r = br.submit(job, timeout=120, label='eval-floorplan cleanup')
    if r.get('status') != 'ok':
        print('  CLEANUP FAILED — %s built group(s) may still be in the model: '
              '%s' % (len(created), ', '.join(c[1] for c in created)))
        return
    left = r['value'].get('left') or []
    if left:
        print('  CLEANUP INCOMPLETE — %d group(s) survived the erase and are '
              'still in the model: %s'
              % (len(left), ', '.join('%s (#%s)' % (n, i) for i, n in left)))
    else:
        print('  cleanup: %d built group(s) erased, read back gone'
              % len(r['value'].get('erased') or []))


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
    truth_types = {}
    for tf in truth.get('features') or []:
        truth_types[tf['type']] = truth_types.get(tf['type'], 0) \
            + int(tf.get('count', 1))
        want = truth_types[tf['type']]
        got = built_types.get(tf['type'], 0)
        if got < want:
            out['errors'].append('feature missing: %d x %s in truth, %d built'
                                 % (want, tf['type'], got))
    for t, got in sorted(built_types.items()):
        if got > truth_types.get(t, 0):
            out['errors'].append('feature extra: %d x %s built, truth has %d'
                                 % (got, t, truth_types.get(t, 0)))
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


def record_row(case, verdict, worst, detail):
    pin = os.environ.get('WR_TAKEOFF_CHECK')
    if pin:
        # The ledger must say which checker scored the row — a silently
        # pinned (possibly stale) checker would make the row unaccountable.
        detail = '%s [checker PINNED: %s]' % (detail, pin)
    row = ('| %s | %s | %s | %s | %s |\n'
           % (time.strftime('%Y-%m-%d %H:%M'),
              os.path.basename(str(case).rstrip('/\\')), verdict,
              ('%.2f"' % worst) if worst is not None else '—', detail))
    ledger = os.path.join(ROOT, 'eval', 'RESULTS.md')
    with io.open(ledger, 'a', encoding='utf-8', newline='\n') as f:
        f.write(row)
    print('  recorded in eval/RESULTS.md')


def _main(argv):
    if not argv:
        fail(__doc__)
    case = argv[0]
    record = '--record' in argv
    want_json = '--json' in argv
    cased, takeoff, truth, cfg = load_case(case)
    expects = cfg.get('expects') or {}
    probe = bool(cfg.get('probe'))
    room_filter = cfg.get('rooms')

    code, log = run_checker(takeoff)
    if expects.get('refusal'):
        # A passing NEGATIVE case: the checker must refuse, by these names.
        if code == 0:
            print(log)
            if record:
                record_row(case, 'FAIL', None,
                           'checker ACCEPTED a take-off this case expects it '
                           'to refuse — the refusal has been un-fixed')
            emit_json(want_json, {'case': case, 'mode': 'refusal',
                                  'verdict': 'FAIL',
                                  'detail': 'checker accepted a take-off this '
                                            'case expects it to refuse'})
            fail('%s: expected the checker to refuse, and it accepted. The '
                 'named refusal IS this case\'s pass condition.' % case, 1)
        missing = [p for p in expects['refusal'] if p.lower() not in log.lower()]
        print(log)
        if missing:
            if record:
                record_row(case, 'FAIL', None,
                           'refused, but not by the expected name(s): %s'
                           % '; '.join(missing))
            emit_json(want_json, {'case': case, 'mode': 'refusal',
                                  'verdict': 'FAIL', 'missing': missing,
                                  'detail': summarize_refusal(log)})
            fail('%s: checker refused, but these expected phrases are absent: '
                 '%s' % (case, '; '.join(missing)), 1)
        print('  PASS  %s — checker refused by name, nothing built (that is '
              'the pass condition)' % case)
        if record:
            record_row(case, 'PASS', None,
                       'refused by name as designed: %s'
                       % '; '.join(expects['refusal']))
        emit_json(want_json, {'case': case, 'mode': 'refusal',
                              'verdict': 'PASS',
                              'refused_by': expects['refusal']})
        return 0
    if code != 0:
        print(log)
        if probe:
            print('  PROBE %s — checker refused; verdict recorded, see the '
                  'case README' % case)
            if record:
                record_row(case, 'PROBE', None,
                           'checker refused (probe): ' + summarize_refusal(log))
            emit_json(want_json, {'case': case, 'mode': 'probe',
                                  'verdict': 'PROBE',
                                  'detail': 'checker refused: '
                                            + summarize_refusal(log)})
            return 0
        if record:
            record_row(case, 'FAIL', None,
                       'checker refused unexpectedly: ' + summarize_refusal(log))
        emit_json(want_json, {'case': case, 'mode': 'score',
                              'verdict': 'FAIL',
                              'detail': 'checker refused unexpectedly: '
                                        + summarize_refusal(log)})
        fail('%s: checker refused the take-off — nothing was built. If this '
             'case EXPECTS refusal, say so in case.json.' % case, 1)
    lock = takeoff.replace('.json', '.lock.json')

    rooms_truth = truth['rooms']
    names = room_filter or [r['room'] for r in rooms_truth]
    rooms_built, _created = build_and_read(lock, None)
    built = {r['name']: r for r in rooms_built}

    results = []
    worst = None        # None until a room is actually measured — an
                        # unmeasured room must never read as a 0.00" score
    unmeasured = []
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
        if s.get('max_vertex_err_in') is not None:
            worst = max(worst, s['max_vertex_err_in']) if worst is not None \
                else s['max_vertex_err_in']
        else:
            unmeasured.append(s['room'])
        print('  %-4s %-10s vertex %5s\"  jamb %5s\"  ceiling %5s\"  unflagged %d'
              % ('PASS' if ok else 'FAIL', s['room'],
                 s.get('max_vertex_err_in', '—'),
                 s.get('max_jamb_err_in', '—'),
                 s.get('ceiling_delta_in', '—'),
                 s.get('unflagged_assumed', 0)))
        for e in s['errors']:
            print('         %s' % e)
    print('')
    if unmeasured:
        # A room with no vertex readback has no error figure at all. Worst
        # becomes '—' for the whole run (it previously stayed 0.00", which
        # read as a perfect score — the silent-plausible-wrong class).
        worst = None
        print('  UNMEASURED %d room(s): %s — no vertex readback, so this run '
              'has NO worst-error figure (recorded as "—", never 0.00")'
              % (len(unmeasured), ', '.join(unmeasured)))
    detail = '; '.join(e for s in results for e in s['errors']) or 'clean'

    if expects.get('score_fail'):
        # A planted defect the CHECKER cannot see (it validated clean) that
        # the scorer must catch — the 31-Aug-shaped silent-wrong-geometry
        # class. PASS = scoring failed with every expected phrase.
        if not failed:
            print('  FAIL  %s — the planted defect built and scored CLEAN. '
                  'The scorer missed it; that is the silent 31 Aug failure '
                  'mode.' % case)
            if record:
                record_row(case, 'FAIL', worst,
                           'planted defect went UNDETECTED — scored clean')
            emit_json(want_json, {'case': case, 'mode': 'score_fail',
                                  'verdict': 'FAIL', 'results': results,
                                  'detail': 'planted defect went undetected'})
            return 1
        missing = [p for p in expects['score_fail']
                   if p.lower() not in detail.lower()]
        if missing:
            print('  FAIL  %s — scoring failed, but not for the planted '
                  'reason(s): missing %s' % (case, '; '.join(missing)))
            if record:
                record_row(case, 'FAIL', worst,
                           'scorer failed for the wrong reason; expected: %s '
                           '— got: %s' % ('; '.join(missing), detail))
            emit_json(want_json, {'case': case, 'mode': 'score_fail',
                                  'verdict': 'FAIL', 'missing': missing,
                                  'results': results, 'detail': detail})
            return 1
        print('  PASS  %s — planted defect DETECTED by the scorer (checker '
              'was silent by design): %s' % (case, detail))
        if record:
            record_row(case, 'PASS', worst,
                       'planted defect detected (checker-silent by design): '
                       + detail)
        emit_json(want_json, {'case': case, 'mode': 'score_fail',
                              'verdict': 'PASS', 'results': results,
                              'detail': detail})
        return 0

    if want_json:
        print(json.dumps({'case': case, 'results': results,
                          'verdict': 'PASS' if not failed else 'FAIL',
                          'worst_vertex_err_in': worst,
                          'unmeasured_rooms': unmeasured}, indent=2))
    if probe:
        print('  PROBE %s — built and scored; verdict above is informational'
              % case)
        if record:
            record_row(case, 'PROBE', worst, 'built (probe): ' + detail)
        return 0
    if record:
        record_row(case, 'PASS' if not failed else 'FAIL', worst, detail)
    return 1 if failed else 0


def summarize_refusal(log):
    lines = [ln.strip() for ln in log.splitlines() if 'FAIL' in ln]
    tail = log.strip().splitlines()
    # An empty checker log (checker crashed before printing, or was killed)
    # must summarize, not raise — this feeds the ledger's FAIL rows.
    s = '; '.join(lines) or (tail[-1] if tail else '(checker produced no output)')
    return s[:400]


def main(argv):
    """Every exit path runs the cleanup — a refusal, a scoring failure, a
    bridge fault and a raise all leave the scratch model as they found it.
    fail() exits through SystemExit, so the finally still fires."""
    try:
        return _main(argv)
    finally:
        cleanup_built()


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
