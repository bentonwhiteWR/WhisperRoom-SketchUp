#!/usr/bin/env python3
"""
replay-side-wall-order.py  --  make a side-wall mirror visible in TEXT.

Reads, offline, with no SketchUp:
  * scripts/wr-booth-data.rb                           the layout the BUILDER places from
  * WhisperRoomQuote/lib/pl-data/booth-layouts.json    the layout the PORTAL draws from

and prints, per model / per shell / per wall:

  - every slot in SLOT-ID order, with its along-wall extents taken from the
    layout polygon, and the default component the builder would resolve
  - the portal's own slot order for the same wall
  - AGREE / MIRRORED, decided on which physical end slot 0 sits at. That is the
    only thing that can mirror a run when the customer's packs arrive keyed by
    slot id, which is what booth-from-link.rb does.
  - which of the builder's Enhanced-only half-turn rules would fire on each
    inner slot (IEP_VENT_YAW / IEP_DOOR_YAW / IEP_SEAL_YAW), and which inner
    parts get NO half turn at all.

This does NOT and CANNOT report per-part FACING. Facing comes out of
wall_slab(), which measures the real .skp geometry, and there is no Ruby and no
SketchUp here. The builder itself prints a FACING column; that is the reading
this harness deliberately leaves to a real build.

Convention taken from the portal's own source (assets/layout-render.js,
wallPanelRun): pieces are laid out with aIn growing from startIn, and for an
E/W wall the comment reads "aIn grows DOWNWARD -> high aIn is the S end".
So the portal's slot index 0 is at the N end of a side wall, and at the low-x
end of an N/S wall.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = os.path.join(ROOT, 'scripts', 'wr-booth-data.rb')
PORTAL = os.path.join(os.path.dirname(ROOT),
                      'WhisperRoomQuote', 'lib', 'pl-data', 'booth-layouts.json')

PART_RE = re.compile(
    r":k=>'(?P<k>[a-z]+)',\s*:id=>'(?P<id>[^']+)',\s*:sk=>'(?P<sk>[^']+)',"
    r"\s*:sh=>'(?P<sh>[^']+)',\s*:poly=>(?P<poly>.+)")
PT_RE = re.compile(r"\[\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\]")

WALL_WORD = {'N': 'Back', 'S': 'Front', 'E': 'Right', 'W': 'Left'}


def load_booths(path):
    """{key: {'w':,'h':,'parts':[...]}} - parsed straight off the generated file."""
    src = open(path, encoding='utf-8', errors='replace').read()
    booths = {}
    cur = None
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


# --- the builder's own rules, transcribed from build-booth-components.rb -----
ENH_PLAIN_PANEL = {'14.5', '23.5', '26.5', '38.5'}
STD_PLAIN_PANEL = {'7', '19', '28', '31', '43'}


def guess_component(kind, run, inner):
    """build-booth-components.rb self.guess_component, transcribed."""
    if inner:
        w = round(run * 2) / 2.0
        ws = ('%g' % w)
        return {'VNT': 'ENH %sVNT' % ws, 'NV': 'ENH %sNV' % ws,
                'DRFRM': 'ENH Right%sDoor' % ws, 'CBL': 'ENH %sPanelCBL' % ws,
                'SEAL': 'ENH MidWallSeamSeal', 'CORNER': 'ENH CornerSeamSeal'
                }.get(kind,
                      'ENH %sPanel' % ws if ws in ENH_PLAIN_PANEL
                      else 'ENH %sPanelSolid' % ws)
    w = int(round(run))
    return {'VNT': '%dVNT' % w, 'DRFRM': 'Right%dDoor' % w,
            'CBL': '%dPanelCBL' % w, 'SEAL': 'MidWallSeamSeal',
            'CORNER': 'CornerSeamSeal'
            }.get(kind,
                  '%dPanel' % w if str(w) in STD_PLAIN_PANEL else '%dPanelSolid' % w)


def half_turn(part, name):
    """Which Enhanced-only half turn the builder applies (lines ~1991-2027)."""
    if part['sh'] != 'in':
        return '-'
    if part['k'] == 'seal':
        return 'IEP_SEAL_YAW 180'
    if re.search(r'Door', name, re.I):
        return 'IEP_DOOR_YAW 180 (+0.5 in)'
    if part['k'] == 'panel' and re.search(r'VNT|NV', name, re.I):
        return 'IEP_VENT_YAW 180'
    if part['k'] == 'corner':
        return 'placed direct (SW0/SE90/NE180/NW270)'
    return 'NONE'


def run_axis(wall):
    return 0 if wall in ('N', 'S') else 1     # 0 = along x, 1 = along y


def extents(poly, axis):
    v = [p[axis] for p in poly]
    return min(v), max(v)


def slot_num(sid):
    return int(re.sub(r'\D', '', sid) or 0)


def report(key, spec, portal, out):
    p = out.append
    p('=' * 100)
    p('%s     exterior %g x %g' % (key, spec['w'], spec['h']))
    p('=' * 100)
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
            rows = [(x,) + extents(x['poly'], ax) for x in wp]
            rows_id = sorted(rows, key=lambda r: slot_num(r[0]['id']))
            p('')
            p('    wall %s   (%s)   run along %s'
              % (wall, WALL_WORD[wall], 'x' if ax == 0 else 'y'))
            p('      %-8s %-7s %8s %8s %7s  %-26s %s'
              % ('SLOT', 'KIND', 'from', 'to', 'width', 'DEFAULT COMPONENT',
                 'ENHANCED HALF TURN'))
            for x, lo, hi in rows_id:
                nm = guess_component(x['sk'], hi - lo, shell == 'in')
                p('      %-8s %-7s %8.3f %8.3f %7.3f  %-26s %s'
                  % (x['id'], x['sk'], lo, hi, hi - lo, nm, half_turn(x, nm)))
            geo_order = [r[0]['id'] for r in sorted(rows, key=lambda r: r[1])]
            ids = [r[0]['id'] for r in rows_id]
            pw = (portal or {}).get('walls', {}).get(wall, {}).get('slots', [])
            pids = [s['id'] for s in pw]
            pkinds = [s['kind'] for s in pw]
            # Portal index 0 sits at the low-x end of N/S and at the N (high-y)
            # end of E/W. Express the portal order as ascending coordinate order
            # so it can be compared with the layout's own.
            want = ids if wall in ('N', 'S') else list(reversed(ids))
            agree = (geo_order == want)
            p('      layout, low->high coordinate : %s' % ' '.join(geo_order))
            p('      portal, index 0 -> n         : %s   kinds: %s'
              % (' '.join(pids) or '(no portal row)', ' '.join(pkinds)))
            p('      => %s' % ('AGREE - slot 0 sits on the same physical end in both'
                               if agree else
                               '*** MIRRORED - the portal and the layout put slot 0 at opposite ends'))
            lk = [x[0]['sk'] for x in rows_id]
            if pids and lk != list(pkinds):
                p('      note: slot KINDS differ from the portal row - layout %s'
                  % ' '.join(lk))
            # --- the portal's OWN big-run-at-the-door-end flip -----------------
            # assets/layout-render.js wallPanelRun(): on an E/W wall of exactly
            # two pieces whose REAL widths differ, the portal swaps the two
            # pieces' along-wall extents so the big run sits at the door end.
            # The builder has no equivalent; build-booth-components' ASSIGN
            # table hard-codes the same swap, but ASSIGN is read ONLY by
            # self.run (the standalone dialog). booth-from-link.rb calls
            # build_booth with the LINK's assign, so the swap never fires on
            # the customer path.
            if wall in ('E', 'W') and len(rows_id) == 2:
                w0 = rows_id[0][2] - rows_id[0][1]
                w1 = rows_id[1][2] - rows_id[1][1]
                if abs(w0 - w1) > 0.01:
                    big_end = 'N' if w0 > w1 else 'S'
                    p('      PORTAL FLIP FIRES (2 unequal pieces): the portal draws the '
                      'BIG run at the S (door) end;')
                    p('                          this layout puts it at the %s end.  %s'
                      % (big_end,
                         'AGREE' if big_end == 'S' else
                         '*** the builder needs the ASSIGN swap here - and ASSIGN is '
                         'NOT read on the booth-from-link path'))


def main():
    booths = load_booths(DATA)
    portal = json.load(open(PORTAL, encoding='utf-8'))['layouts']
    keys = sys.argv[1:] or ['MDL 96144 S', 'MDL 96144 E',
                            'MDL 102144 S', 'MDL 102144 E']
    out = []
    for k in keys:
        if k not in booths:
            out.append('!! %s not in wr-booth-data.rb' % k)
            continue
        report(k, booths[k], portal.get(k.rsplit(' ', 1)[0]), out)
        out.append('')
    print('\n'.join(out))


if __name__ == '__main__':
    main()
