#!/usr/bin/env python3
"""
replay-side-wall-order.py  --  make a side-wall slot REVERSAL visible in TEXT.

=============================================================================
WHY THIS FILE WAS REWRITTEN (2026-08-26).  READ THIS BEFORE TRUSTING IT.
=============================================================================
The previous version of this harness printed "200 walls, 0 mirrored" while the
model was visibly wrong in SketchUp.  It lied, and it lied in the worst
possible way: its verdict was CIRCULAR.

It computed

    want  = ids                       for an N/S wall
    want  = list(reversed(ids))       for an E/W wall
    agree = (geo_order == want)

where `ids` was wr-booth-data.rb's OWN slot ids in slot-number order and
`geo_order` was wr-booth-data.rb's OWN parts in coordinate order.  The portal's
slot list (`pids`) was read, printed, and then never used in the comparison.

So the verdict tested one file against a HARD-CODED ASSUMPTION about the other
("portal slot 0 sits at the N end of a side wall").  That assumption is the very
rule gen-booth.py adopted on 2026-08-11 when it flipped the E/W walk.  The
harness therefore asserted the change under test, and could only have failed if
wr-booth-data.rb's own slot numbering were non-monotonic.  200/200 was
guaranteed before it read a single byte of portal data.

WHAT IT COMPARES NOW
--------------------
An INDEPENDENT witness that this repo did not derive:

    WhisperRoomQuote/lib/pl-data/booth-iso-geometry.json

That file is a straight extract of wr-booth-data.rb taken 2026-08-07T22:57Z,
i.e. BEFORE gen-booth.py's 2026-08-11 E/W walk flip.  It is what the portal's
ANGLED ("YOUR BOOTH") view still renders from today, and it is the order in
Benton's portal render: on MDL 102144 the window slot W0 sits at the DOOR end.
Comparing per-SLOT-ID along-wall extents against it is falsifiable, and it fails
loudly on exactly the walls Benton can see are wrong.

It carries all 25 Standard layouts, so an " E" key is checked shell by shell:
the outer (:sh=>'out') parts against the iso entry for the same model, and the
inner (:sh=>'in') parts against the DIRECTION the outer run walks.

WHAT IT STILL CANNOT SEE
------------------------
Per-part FACING and the width-axis family split (40Panel2636WDO runs X while
16PanelSolid / 40PanelSolid run Y).  Those come out of wall_slab(), which
measures real .skp geometry; there is no Ruby and no SketchUp here.  That is a
SEPARATE defect - it turns a panel end-for-end IN PLACE.  This harness reports
only ORDER: which END of the wall a slot id lands on.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = os.path.join(ROOT, 'scripts', 'wr-booth-data.rb')
QUOTE = os.path.join(os.path.dirname(ROOT), 'WhisperRoomQuote', 'lib', 'pl-data')
PORTAL = os.path.join(QUOTE, 'booth-layouts.json')
ISO = os.path.join(QUOTE, 'booth-iso-geometry.json')

PART_RE = re.compile(
    r":k=>'(?P<k>[a-z]+)',\s*:id=>'(?P<id>[^']+)',\s*:sk=>'(?P<sk>[^']+)',"
    r"\s*:sh=>'(?P<sh>[^']+)',\s*:poly=>(?P<poly>.+)")
PT_RE = re.compile(r"\[\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\]")

WALL_WORD = {'N': 'Back', 'S': 'Front', 'E': 'Right', 'W': 'Left'}
TOL = 0.01


def run_axis(wall):
    return 0 if wall in ('N', 'S') else 1


def load_booths(path):
    src = open(path, encoding='utf-8', errors='replace').read()
    booths, cur = {}, None
    for line in src.splitlines():
        m = re.match(r"\s*'(MDL [^']+)' => \{.*?:w=>([\d.]+), :h=>([\d.]+)", line)
        if m:
            cur = {'w': float(m.group(2)), 'h': float(m.group(3)), 'parts': []}
            booths[m.group(1)] = cur
            continue
        if cur is None:
            continue
        pm = PART_RE.search(line)
        if pm:
            pts = [(float(a), float(b)) for a, b in PT_RE.findall(pm.group('poly'))]
            cur['parts'].append({'k': pm.group('k'), 'id': pm.group('id'),
                                 'sk': pm.group('sk'), 'sh': pm.group('sh'),
                                 'poly': pts})
    return booths


def load_iso(path):
    """{'MDL 102144 S': {'W0': (lo, hi) along its own run axis, ...}}"""
    doc = json.load(open(path, encoding='utf-8'))
    out = {}
    for e in doc['booths']:
        d = {}
        for p in e['parts']:
            if p['k'] != 'panel':
                continue
            ax = run_axis(p['id'][0])
            v = [q[ax] for q in p['poly']]
            d[p['id']] = (min(v), max(v))
        out[e['key']] = d
    return out, doc.get('generated', '?'), doc.get('source', '?')


ENH_PLAIN_PANEL = {'14.5', '23.5', '26.5', '38.5'}
STD_PLAIN_PANEL = {'7', '19', '28', '31', '43'}


def guess_component(kind, run, inner):
    if inner:
        ws = '%g' % (round(run * 2) / 2.0)
        return {'VNT': 'ENH %sVNT' % ws, 'NV': 'ENH %sNV' % ws,
                'DRFRM': 'ENH Right%sDoor' % ws, 'CBL': 'ENH %sPanelCBL' % ws,
                'SEAL': 'ENH MidWallSeamSeal', 'CORNER': 'ENH CornerSeamSeal'
                }.get(kind, 'ENH %sPanel' % ws if ws in ENH_PLAIN_PANEL
                      else 'ENH %sPanelSolid' % ws)
    w = int(round(run))
    return {'VNT': '%dVNT' % w, 'DRFRM': 'Right%dDoor' % w,
            'CBL': '%dPanelCBL' % w, 'SEAL': 'MidWallSeamSeal',
            'CORNER': 'CornerSeamSeal'
            }.get(kind, '%dPanel' % w if str(w) in STD_PLAIN_PANEL
                  else '%dPanelSolid' % w)


def extents(poly, axis):
    v = [p[axis] for p in poly]
    return min(v), max(v)


def slot_num(sid):
    return int(re.sub(r'\D', '', sid) or 0)


def report(key, spec, portal, iso, out, tally):
    p = out.append
    base = key.rsplit(' ', 1)[0]
    iso_key = base + ' S'
    iso_walls = iso.get(iso_key)
    p('=' * 100)
    p('%s     exterior %g x %g     witness: %s'
      % (key, spec['w'], spec['h'],
         iso_key if iso_walls else '!! NO ISO ENTRY - order NOT checked'))
    p('=' * 100)

    door_wall = ((portal or {}).get('door') or {}).get('wall', '?')
    p('  door wall: %s   (on an E/W run the door end is the %s end of the y axis)'
      % (door_wall, 'LOW' if door_wall == 'S' else 'HIGH' if door_wall == 'N' else '?'))

    for shell, shell_word in (('out', 'OUTER (Standard shell)'),
                              ('in', 'INNER (IEP shell)')):
        parts = [x for x in spec['parts'] if x['sh'] == shell]
        if not parts:
            continue
        p('')
        p('  ---- %s ----' % shell_word)
        for wall in 'NSEW':
            wp = [x for x in parts
                  if x['id'].startswith(wall) and x['k'] == 'panel']
            if not wp:
                continue
            ax = run_axis(wall)
            rows = sorted([(x,) + extents(x['poly'], ax) for x in wp],
                          key=lambda r: slot_num(r[0]['id']))
            lo_all = min(r[1] for r in rows)
            hi_all = max(r[2] for r in rows)
            p('')
            p('    wall %s   (%s)   run along %s'
              % (wall, WALL_WORD[wall], 'x' if ax == 0 else 'y'))
            p('      %-8s %-7s %8s %8s %7s  %-26s %-5s %s'
              % ('SLOT', 'KIND', 'from', 'to', 'width', 'DEFAULT COMPONENT',
                 'END', 'vs WITNESS'))

            # The witness row for this wall.
            #   outer shell : the iso file's own extents for the same slot id.
            #   inner shell : the outer shell's iso extents mapped onto the
            #                 inner ids and compared by END only - the inner run
            #                 is inset, so its numbers are not the outer's.
            wit = {}
            if iso_walls:
                for x, lo, hi in rows:
                    oid = x['id'][:-1] if shell == 'in' else x['id']
                    if oid in iso_walls:
                        wit[x['id']] = iso_walls[oid]
            wlo_all = min((v[0] for v in wit.values()), default=0.0)
            whi_all = max((v[1] for v in wit.values()), default=0.0)

            n_bad = 0
            for x, lo, hi in rows:
                nm = guess_component(x['sk'], hi - lo, shell == 'in')
                end = ('LOW' if abs(lo - lo_all) < TOL else
                       'HIGH' if abs(hi - hi_all) < TOL else 'mid')
                verdict = '(no witness)'
                if x['id'] in wit:
                    wa, wb = wit[x['id']]
                    wend = ('LOW' if abs(wa - wlo_all) < TOL else
                            'HIGH' if abs(wb - whi_all) < TOL else 'mid')
                    if shell == 'out':
                        verdict = ('same' if abs(wa - lo) < TOL and abs(wb - hi) < TOL
                                   else 'MOVED  witness %.3f..%.3f (%s end)'
                                   % (wa, wb, wend))
                    else:
                        verdict = ('same end (%s)' % wend if wend == end
                                   else 'MOVED  witness end %s' % wend)
                    if verdict.startswith('MOVED'):
                        n_bad += 1
                p('      %-8s %-7s %8.3f %8.3f %7.3f  %-26s %-5s %s'
                  % (x['id'], x['sk'], lo, hi, hi - lo, nm, end, verdict))

            ids = [r[0]['id'] for r in rows]
            geo_order = [r[0]['id'] for r in sorted(rows, key=lambda r: r[1])]
            p('      layout, low->high coordinate : %s' % ' '.join(geo_order))
            if wit:
                wit_order = sorted(wit, key=lambda i: wit[i][0])
                p('      WITNESS, low->high           : %s' % ' '.join(wit_order))
                tally['walls'] += 1
                if n_bad == 0:
                    p('      => AGREE - every slot lands on the end the witness puts it on')
                elif geo_order == list(reversed(wit_order)):
                    tally['reversed'] += 1
                    tally['bad_walls'].append('%s %s %s' % (key, shell, wall))
                    p('      => *** REVERSED - the whole run is walked end for end.')
                    p('         Slot %s sits at the %s end here, at the %s end in the witness.'
                      % (ids[0],
                         'HIGH' if geo_order[-1] == ids[0] else 'LOW',
                         'HIGH' if wit_order[-1] == ids[0] else 'LOW'))
                else:
                    tally['differ'] += 1
                    tally['bad_walls'].append('%s %s %s' % (key, shell, wall))
                    p('      => *** DIFFERS on %d slot(s), and not as a clean reversal'
                      % n_bad)
            else:
                tally['nowitness'] += 1
                p('      => no witness for this wall - NOT checked')

            pw = (portal or {}).get('walls', {}).get(wall, {}).get('slots', [])
            if pw:
                p('      context only, booth-layouts.json slot row: %s   kinds: %s'
                  % (' '.join(s['id'] for s in pw),
                     ' '.join(s['kind'] for s in pw)))
                p('      (NOT a verdict.  That file carries slot ORDER and SIZE and no')
                p('       end-of-wall geometry; wallPanelRun() lays it out from aIn=0,')
                p('       which IS the assumption under test.  The old harness compared')
                p('       against it and therefore could not fail.)')


def main():
    booths = load_booths(DATA)
    portal = json.load(open(PORTAL, encoding='utf-8'))['layouts']
    iso, gen, src = load_iso(ISO)
    argv = sys.argv[1:]
    args = [a for a in argv if not a.startswith('--')]
    if '--all' in argv:
        keys = sorted(booths)
    else:
        keys = args or ['MDL 96144 S', 'MDL 96144 E',
                        'MDL 102144 S', 'MDL 102144 E']
    quiet = '--summary' in argv
    tally = {'walls': 0, 'reversed': 0, 'differ': 0, 'nowitness': 0,
             'bad_walls': []}
    out = ['witness  : %s' % ISO,
           '           extracted %s from %s' % (gen, src),
           '           i.e. wr-booth-data.rb BEFORE gen-booth.py flipped the E/W',
           '           walk on 2026-08-11, and the order the portal angled view',
           '           still draws today.',
           '']
    for k in keys:
        if k not in booths:
            out.append('!! %s not in wr-booth-data.rb' % k)
            continue
        report(k, booths[k], portal.get(k.rsplit(' ', 1)[0]), iso, out, tally)
        out.append('')
    out.append('=' * 100)
    out.append('%d wall(s) checked against the witness: %d REVERSED, %d DIFFER, '
               '%d with no witness'
               % (tally['walls'], tally['reversed'], tally['differ'],
                  tally['nowitness']))
    for w in tally['bad_walls']:
        out.append('    %s' % w)
    if quiet:
        print('\n'.join(out[:5] + out[-(len(tally['bad_walls']) + 2):]))
    else:
        print('\n'.join(out))
    return 1 if (tally['reversed'] or tally['differ']) else 0


if __name__ == '__main__':
    sys.exit(main())
