"""Check a b-verify.rb result against layout-v8.json.

    python b-verify.py <bridge-result.json> [walls]     # e.g. walls = S  or  SEWN (default: every wall that has slots placed)

Per piece: rect vs its slot (tolerance 0.02), seated (|air| <= 0.05, no burial), fabric/front into the room,
right layer. Per wall: v8model.check on the measured rects (0.5 to pieces and survey keep-outs), plus a 3D
test against the LIVE fixed items (traps, duct covers, IEP beams, ceiling seals). Prints PASS/FAIL lines.
"""
import json, sys, itertools
from v8model import check, NEED

res = json.load(open(sys.argv[1]))
assert res['status'] == 'ok', res.get('error')
v = json.loads(res['value'])
lay = json.load(open('layout-v8.json'))
slots = {p['id']: (w, p) for w, W in lay['walls'].items() for p in W['pieces']}
arg = sys.argv[2] if len(sys.argv) > 2 else 'SEWN'
walls, partial = (arg.split('+') + [''])[:2]          # e.g. 'E+N': E fully, N gaps/seat only (mid-change)
TOL, SEAT = 0.02, 0.05
fails, lines = [], []
KIND = {'Foam': 'sheet', 'Audimute2x4': 'sheet', 'Audimute1x4': '1x4', 'Audimute1x2': '1x2'}
SIZE = {'sheet': (24, 48), '1x4': (12, 48), '1x2': (24, 12)}
measured = {w: [] for w in 'SEWN'}
for p in v['pieces']:
    w = p['wall']
    if w not in measured: continue
    r = p['rect']
    kind = KIND[p['def']]
    wd, ht = r[1] - r[0], r[3] - r[2]
    rot = abs(wd - SIZE[kind][0]) > 0.1
    measured[w].append(dict(kind=kind, mat='foam' if p['def'] == 'Foam' else 'audimute', s=r[0], z=r[2], rot=rot, _p=p))
    if w not in walls + partial: continue
    sid = p['slot']
    if w in partial and not sid: continue                 # a v7 piece not yet moved
    if not sid or sid not in slots or slots[sid][0] != w:
        fails.append(f'{w} {p["name"]} (pid {p["pid"]}) has slot {sid!r}, not a slot on this wall'); continue
    s = slots[sid][1]
    d = max(abs(r[0] - s['s0']), abs(r[1] - s['s1']), abs(r[2] - s['z0']), abs(r[3] - s['z1']))
    ok_part = p['def'] == s['part']
    ok_layer = p['layer'] == ('WR-Booth-Foam' if p['def'] == 'Foam' else 'WR-Booth-Acoustic')
    seated = abs(p['air']) <= SEAT
    lines.append(f"  {sid} {p['name']:<20} pos {d:.4f}  air {p['air']:+.4f}  seat {p['seat']}  front {p['front_dot']}  rays {p['rays']}/{p['misses']} miss")
    if d > TOL: fails.append(f'{sid} position off by {d:.4f}')
    if not seated: fails.append(f"{sid} not seated: air {p['air']:+.4f} (+ = gap, - = buried)")
    if p['front_dot'] < 0.9999: fails.append(f'{sid} front/fabric not into the room ({p["front_dot"]})')
    if not ok_part: fails.append(f'{sid} is {p["def"]}, slot wants {s["part"]}')
    if not ok_layer: fails.append(f'{sid} on layer {p["layer"]}')
    if p['misses']: fails.append(f'{sid} {p["misses"]} seat rays missed')
# every slot of the checked walls present exactly once
for w in walls:
    want = sorted(sid for sid, (ww, _) in slots.items() if ww == w)
    have = sorted(p['_p']['slot'] for p in measured[w] if p['_p']['slot'])
    if want != have: fails.append(f'{w}: slots present {have} != layout {want}')
    extra = [p['_p']['name'] for p in measured[w] if not p['_p']['slot']]
    if extra: fails.append(f'{w}: pieces without a v8 slot still on the wall: {extra}')
# gaps per wall from the measured rects (survey keep-outs), only the checked walls
lay_m = {w: [{k: x for k, x in q.items() if k != '_p'} for q in measured[w]] for w in walls + partial}
ok, cl, st = check(lay_m)
for l in cl: fails.append('check: ' + l)
# 3D vs live fixed items
def gap3(a, b): return max(b[0] - a[1], a[0] - b[1], b[2] - a[3], a[2] - b[3], b[4] - a[5], a[4] - b[5])
mind = (1e9, '')
for w in walls + partial:
    for q in measured[w]:
        p = q['_p']
        for f in v['fixed']:
            g = gap3(p['box3d'], f['box3d'])
            if g < mind[0]: mind = (g, f"{p['name']} ({p['slot']}) vs {f['name']}")
            if g < 0.5 - 1e-4: fails.append(f"{p['slot']} {p['name']} is {g:.3f} from live {f['name']} in 3D")
print(f"walls {walls} (+ partial {partial or "-"}): {sum(len(measured[w]) for w in walls + partial)} pieces")
print('\n'.join(lines))
print(f"min gaps (measured, survey keep-outs): {({k: round(x, 4) for k, x in st['min'].items()})}  where {st['where']}")
print(f"min 3D gap to a live fixed item: {mind[0]:.4f}  ({mind[1]})")
print(f"counts in booth: {v['counts']}  traps {v['traps']}  hidden unchanged {v['hidden_unchanged']}  modified {v['modified_before']}->{v['modified_after']}  scene {v['scene']}")
if not v['hidden_unchanged']: fails.append('hidden state changed by the verify')
print('RESULT', 'PASS' if not fails else 'FAIL')
for f in fails: print('  FAIL', f)
