# -*- coding: utf-8 -*-
"""Measure the 25 Standard layouts in scripts/wr-booth-data.rb, to test whether an
Enhanced inner shell can be DERIVED from them by the -4.5-per-panel rule.

Tests, per booth:
  1. Do opposite walls carry the same number of panels? (If not, the per-panel
     shrink gives N and S different runs and the inner shell is not a rectangle.)
  2. Does every panel width have an Enhanced counterpart?
  3. Where would the inner shell's door land, versus the outer door opening?
"""
import re
import sys
import os

SRC = os.path.join(os.path.dirname(__file__), '..', '..', 'scripts', 'wr-booth-data.rb')
txt = open(SRC).read()

ENH_WIDTH = {7: None, 16: 11.5, 19: 14.5, 22: 17.5, 28: 23.5,
             31: 26.5, 40: 35.5, 43: 38.5, 46: 41.5}

booth_re = re.compile(r"'(MDL [^']+)' => \{ :label=>\"([^\"]*)\", :w=>([\d.]+), :h=>([\d.]+),"
                      r" :iw=>([\d.]+), :ih=>([\d.]+), :ph=>([\d.]+),")
part_re = re.compile(r"\{ :k=>'(\w+)', :id=>'([^']+)', :sk=>'(\w+)', :poly=>(\[\[.*?\]\]) \}")
pt_re = re.compile(r"\[([-\d.]+),([-\d.]+)\]")

booths = []
for m in booth_re.finditer(txt):
    start = m.end()
    nxt = booth_re.search(txt, start)
    body = txt[start:nxt.start() if nxt else len(txt)]
    parts = []
    for pm in part_re.finditer(body):
        pts = [(float(a), float(b)) for a, b in pt_re.findall(pm.group(4))]
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        parts.append({'k': pm.group(1), 'id': pm.group(2), 'sk': pm.group(3),
                      'x0': min(xs), 'x1': max(xs), 'y0': min(ys), 'y1': max(ys)})
    booths.append({'key': m.group(1), 'w': float(m.group(3)), 'h': float(m.group(4)),
                   'iw': float(m.group(5)), 'ih': float(m.group(6)), 'parts': parts})

print('parsed %d booths' % len(booths))

bad_count = []
bad_width = []
door_rows = []

for b in booths:
    sides = {'N': [], 'S': [], 'E': [], 'W': []}
    for p in b['parts']:
        if p['k'] != 'panel':
            continue
        side = p['id'][0]
        # N/S walls run along x; E/W walls run along y
        wdt = (p['x1'] - p['x0']) if side in 'NS' else (p['y1'] - p['y0'])
        sides[side].append((p['id'], p['sk'], wdt, p))
    counts = {s: len(v) for s, v in sides.items()}
    if counts['N'] != counts['S'] or counts['E'] != counts['W']:
        bad_count.append((b['key'], counts))
    for s, v in sides.items():
        for pid, sk, wdt, p in v:
            iw = int(round(wdt))
            if iw not in ENH_WIDTH or ENH_WIDTH[iw] is None:
                bad_width.append((b['key'], pid, sk, wdt))

    # where the door sits in its wall run
    for s, v in sides.items():
        for pid, sk, wdt, p in v:
            if sk != 'DRFRM':
                continue
            run0 = min(q[3]['x0'] if s in 'NS' else q[3]['y0'] for q in v)
            run1 = max(q[3]['x1'] if s in 'NS' else q[3]['y1'] for q in v)
            d0 = p['x0'] if s in 'NS' else p['y0']
            d1 = p['x1'] if s in 'NS' else p['y1']
            n = len(v)
            shrink = 4.5 * n
            # concentric inner shell: the run shrinks by `shrink`, centred
            g = shrink / 2.0
            # door index within the run, and its offset from the run start
            before = sum(q[2] for q in sorted(v, key=lambda q: q[3]['x0'] if s in 'NS' else q[3]['y0'])
                         if (q[3]['x0'] if s in 'NS' else q[3]['y0']) < d0)
            k = len([q for q in v if (q[3]['x0'] if s in 'NS' else q[3]['y0']) < d0])
            inner_d0 = run0 + g + before - 4.5 * k + 2 * k
            inner_d1 = inner_d0 + (wdt - 4.5)
            door_rows.append((b['key'], s, pid, run0, run1, d0, d1,
                              inner_d0, inner_d1,
                              (inner_d0 >= d0 - 1e-6 and inner_d1 <= d1 + 1e-6)))

print('')
print('TEST 1 - opposite walls with UNEQUAL panel counts (breaks a rectangular inner shell):')
if bad_count:
    for k, c in bad_count:
        print('   %-16s %s' % (k, c))
else:
    print('   none - every booth has N==S and E==W panel counts')

print('')
print('TEST 2 - panels with NO Enhanced counterpart:')
if bad_width:
    seen = {}
    for k, pid, sk, wdt in bad_width:
        seen.setdefault(round(wdt, 3), []).append(k)
    for wdt, ks in sorted(seen.items()):
        print('   width %-6s  %d booth(s): %s' % (wdt, len(set(ks)), ', '.join(sorted(set(ks)))))
else:
    print('   none')

print('')
print('TEST 3 - CONCENTRIC inner shell: does the inner door stay inside the outer opening?')
okc = [r for r in door_rows if r[9]]
badc = [r for r in door_rows if not r[9]]
print('   %d door(s) checked: %d fit, %d DO NOT' % (len(door_rows), len(okc), len(badc)))
for r in badc[:8]:
    print('     %-16s %s %-4s outer opening %.1f..%.1f   inner door %.2f..%.2f'
          % (r[0], r[1], r[2], r[5], r[6], r[7], r[8]))

print('')
print('Per-side panel widths, first 4 booths:')
for b in booths[:4]:
    sides = {}
    for p in b['parts']:
        if p['k'] != 'panel':
            continue
        s = p['id'][0]
        wdt = (p['x1'] - p['x0']) if s in 'NS' else (p['y1'] - p['y0'])
        sides.setdefault(s, []).append((p['id'], p['sk'], wdt))
    print('  %-16s iw=%.0f ih=%.0f' % (b['key'], b['iw'], b['ih']))
    for s in 'NSEW':
        v = sorted(sides.get(s, []))
        run = sum(q[2] for q in v) + 2 * (len(v) - 1)
        enh = sum((ENH_WIDTH.get(int(round(q[2]))) or 0) for q in v) + 2 * (len(v) - 1)
        print('     %s  %-34s run=%.1f  enhanced run=%.1f  delta=%.1f'
              % (s, ' '.join('%s:%g' % (q[1], q[2]) for q in v), run, enh, run - enh))
