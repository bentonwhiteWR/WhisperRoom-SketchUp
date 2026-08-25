# -*- coding: utf-8 -*-
"""Replay booth-from-link.rb's component_for + resolve_part against the REAL
component folder, for every pack string the portal can emit, in both variants,
with every option-flag combination and both height settings.

This is the check that can be run without SketchUp. It proves which resolutions
land on a file that exists and which do not, and names the misses.

Pack vocabulary is taken from WhisperRoomQuote/booth-builder.html:
  solidPack / ventPack / doorPack / waPack / shrinkPack / windowPack /
  companionWindowPack  (lines ~1983-2009).

Usage:  python .forge/builder/replay-component-for.py [component-folder]
"""
import os
import re
import sys
import itertools

DIR = sys.argv[1] if len(sys.argv) > 1 else r'P:/Sketchup/NewMasterComponentList'

# ---------------------------------------------------------------- the library
def norm(n):
    return n.lower().replace('_', '').replace(' ', '')

INDEX = {}
for f in os.listdir(DIR):
    if f.lower().endswith('.skp'):
        b = f[:-4]
        INDEX[norm(b)] = b
print('library: %d .skp files, %d distinct normalised keys' % (len(INDEX), len(set(INDEX))))

# ------------------------------------------------- component_for, ported 1:1
ENH_WIDTH = {'7': '2.5', '16': '11.5', '19': '14.5', '22': '17.5', '28': '23.5',
             '31': '26.5', '40': '35.5', '43': '38.5', '46': '41.5'}
PANEL_WIDTHS = ['7', '19', '28', '31', '43']


def component_for(pack, o, enh=False):
    s = pack.strip()
    p = 'ENH ' if enh else ''

    m = re.match(r'\AWA\s+STDDRFRM\s+([RL])\b', s, re.I)
    if m:
        hand = 'Left' if m.group(1).upper() == 'L' else 'Right'
        return '%s%sWADoor%s' % (p, hand, 'WithRamp' if o['ramp'] else '')

    m = re.match(r'\ASTDWL(\d+)\s+DRFRM\s+([RL])\b', s, re.I)
    if m:
        hand = 'Left' if m.group(2).upper() == 'L' else 'Right'
        w = ENH_WIDTH.get(m.group(1)) if enh else m.group(1)
        return '%s%s%sDoor' % (p, hand, w) if w else None

    m = re.match(r'\ASTDWL(\d+)\s+WDO(\d{4})\b', s, re.I)
    if m:
        w = ENH_WIDTH.get(m.group(1)) if enh else m.group(1)
        return '%s%sPanel%sWDO' % (p, w, m.group(2)) if w else None

    m = re.match(r'\ASTDWL(\d+)\s+VNT\b', s, re.I)
    if m:
        w = ENH_WIDTH.get(m.group(1)) if enh else m.group(1)
        if not w:
            return None
        n = '%s%sVNT' % (p, w)
        if enh:
            return n
        if o['vss']:
            n += '_VSS'
        if o['efs']:
            n += '_EFS'
        if o['casters']:
            n += '_CP'
        return n

    m = re.match(r'\ASTDWL(\d+)\s+NV\b', s, re.I)
    if m:
        w = ENH_WIDTH.get(m.group(1)) if enh else m.group(1)
        return '%s%sNV' % (p, w) if w else None

    m = re.match(r'\ASTDWL(\d+)\Z', s, re.I)
    if m:
        std = m.group(1)
        w = ENH_WIDTH.get(std) if enh else std
        if not w:
            return None
        return '%s%s%s' % (p, w, 'Panel' if std in PANEL_WIDTHS else 'PanelSolid')

    return None


def resolve_part(base, hx):
    want = base + '_HX' if hx else base
    hit = INDEX.get(norm(want))
    return (hit, None) if hit else (None, want + '.skp')


# -------------------------------------------------- the portal's pack strings
MODULES = ['16', '22', '28', '40', '46']          # realSize() output
COMPANIONS = ['STDWL19', 'STDWL31', 'STDWL43', 'STDWL7 / WL16']

PACKS = []
PACKS += ['STDWL' + w for w in MODULES]                        # solidPack
PACKS += COMPANIONS                                            # shrinkPack
# Vents, no-vent blanks and doors only ever land on a MODULE wall (40 or 46).
# realSize() snaps a door/vent slot to the module, and the library carries no
# 16/22/28 door or vent part in EITHER variant - that is a pre-existing library
# fact, not something this change introduces.
DOORVENT = ['40', '46']
PACKS += ['STDWL%s VNT' % w for w in DOORVENT]                 # ventPack
PACKS += ['STDWL%s NV' % w for w in DOORVENT]                  # no-vent blank
PACKS += ['STDWL%s DRFRM %s' % (w, h) for w in DOORVENT for h in 'RL']  # doorPack
PACKS += ['WA STDDRFRM %s' % h for h in 'RL']                  # waPack
PACKS += ['STDWL40 WDO26%s' % h for h in ('30', '36', '42', '48')]      # windowPack, 40 module
PACKS += ['STDWL46 WDO32%s' % h for h in ('30', '36', '42', '48')]      # windowPack, 46 module
PACKS += ['STDWL43 WDO2636', 'STDWL43 WDO2648', 'STDWL31 WDO1648']      # companionWindowPack

FLAGS = list(itertools.product([False, True], repeat=3))       # vss, efs, casters

rows = []
for enh in (False, True):
    for pack in PACKS:
        for vss, efs, cs in FLAGS:
            for ramp in (False, True):
                for hx in (False, True):
                    o = {'vss': vss, 'efs': efs, 'casters': cs, 'ramp': ramp}
                    base = component_for(pack, o, enh)
                    if base is None:
                        rows.append((enh, pack, o, hx, None, 'UNTRANSLATED'))
                        continue
                    hit, gone = resolve_part(base, hx)
                    rows.append((enh, pack, o, hx, base, gone or 'ok'))

# ------------------------------------------------------------------- reporting
def flagstr(o, hx):
    f = [k for k in ('vss', 'efs', 'casters', 'ramp') if o[k]]
    if hx:
        f.append('hx')
    return ','.join(f) or '-'


for enh in (False, True):
    sub = [r for r in rows if r[0] is enh]
    ok = [r for r in sub if r[5] == 'ok']
    bad = [r for r in sub if r[5] != 'ok']
    label = 'ENHANCED' if enh else 'STANDARD'
    print('')
    print('=' * 78)
    print('%s   %d combinations   %d resolve   %d do not'
          % (label, len(sub), len(ok), len(bad)))
    print('=' * 78)
    # collapse the misses: one line per distinct (pack, missing-file)
    seen = {}
    for r in bad:
        k = (r[1], r[5], r[4])
        seen.setdefault(k, []).append(flagstr(r[2], r[3]))
    for (pack, miss, base), fl in sorted(seen.items()):
        print('  %-22s -> %-26s %s' % (pack, base or '(no mapping)', miss))
        print('  %-22s    under flags: %s' % ('', ', '.join(sorted(set(fl)))))
