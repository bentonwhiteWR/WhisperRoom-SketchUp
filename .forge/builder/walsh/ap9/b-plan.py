"""Phase B plan: which existing instance (persistent id) fills each layout-v8.json slot, per wall job.

    python b-plan.py      # writes b-plan.json for b-wall.rb

Sources are chosen so that every slot is free when its job runs (no temporary staging):
  S job borrows 6 1x2s: E's two high ones, W's two high ones, N's between-window one and N's upper flat one.
  E job also drops E's 1x4 into N04, whose slot the S job emptied (breaks the E03 -> N04 -> N02 -> E03 cycle).
Pids are from b-probe.rb (observed 12 Oct). New foam = copy of the Foam definition, tag WR-Booth-Foam.
"""
import json, os
from v8model import fixed

HERE = os.path.dirname(os.path.abspath(__file__))
L = json.load(open(os.path.join(HERE, 'layout-v8.json')))
WN = {'S': 'back', 'E': 'left', 'W': 'right', 'N': 'front'}

SRC = {
 # S (back)
 'S01': 3390488, 'S02': 3390489, 'S03': 3390490,           # the three v7 back 1x2s
 'S04': (3325139, 'Foam  S0i'), 'S05': 3390493, 'S06': 3390494, 'S07': 3390499,
 'S08': 3390487, 'S09': (3325141, 'Foam  S3i'), 'S10': 3390500,
 'S11': 3390505, 'S12': 3390507, 'S13': ('new', 'Foam  S1i'),
 # E (left)
 'E01': 3390491, 'E02': (3325142, 'Foam  E0i'), 'E03': 3390504, 'E04': 3390495,
 'E05': (3325143, 'Foam  E1i'), 'E06': 3390496,
 # W (right)
 'W01': 3390501, 'W02': 3390502, 'W03': 3390498, 'W04': (3325144, 'Foam  W0i'), 'W05': 3390497,
 'W06': (3325145, 'Foam  W1i'),
 # N (front)
 'N01': ('new', 'Foam  N0i'), 'N02': 3390506, 'N03': ('new', 'Foam  N1i'), 'N04': 3390492, 'N05': 3390503,
}
# which job places each slot (N04 rides with E, see above)
JOB = {sid: sid[0] for sid in SRC}
JOB['N04'] = 'E'

plan = {'layout': 'layout-v8.json', 'jobs': {}, 'fixed': {}, 'all_slots': {}}
for w, W in L['walls'].items():
    plan['fixed'][w] = [[k[0], k[1]] + list(k[2:]) for k in fixed(w)]
    for p in W['pieces']:
        src = SRC[p['id']]
        pid, name = (src, f"{p['part']} {WN[w]}") if isinstance(src, int) else src
        slot = {'id': p['id'], 'wall': w, 'part': p['part'], 'orient': p['orient'],
                's0': p['s0'], 's1': p['s1'], 'z0': p['z0'], 'z1': p['z1'], 'w': p['w'], 'h': p['h'],
                'pid': pid, 'name': name}
        plan['all_slots'][p['id']] = slot
        plan['jobs'].setdefault(JOB[p['id']], []).append(slot)
pids = [s['pid'] for s in plan['all_slots'].values() if s['pid'] != 'new']
LIVE = {3325139, 3325141, 3325142, 3325143, 3325144, 3325145} | set(range(3390487, 3390508))   # probe: 6 Foam + 21 Audimute
assert len(pids) == len(set(pids)) == 27 and set(pids) == LIVE, sorted(set(pids) ^ LIVE)
assert sum(1 for s in plan['all_slots'].values() if s['pid'] == 'new') == 3
json.dump(plan, open(os.path.join(HERE, 'b-plan.json'), 'w'), indent=1)
for j in 'SEWN':
    print(j, [s['id'] for s in plan['jobs'][j]])
