"""Which per-wall Pareto vectors (B, F4, H, Q) cover the piece requirement?

    python combine.py gcaps3.json

Requirement for c foam sheets cut into 2x2 squares: B >= 14-c, F4 >= 2,
H >= 14, Q >= 2c. Walls are folded one at a time into a dict of capped partial
sums (each component capped at its largest need), so the product never blows up.
"""
import json, sys
caps = json.load(open(sys.argv[1]))
W = list(caps)
CAP = (14, 2, 14, 18)

def clip(t):
    return tuple(min(a, b) for a, b in zip(t, CAP))

# partial: capped sum -> one witness (tuple of per-wall vectors)
partial = {(0, 0, 0, 0): ()}
for w in W:
    nxt = {}
    for s, wit in partial.items():
        for v in caps[w]:
            t = clip(tuple(a + b for a, b in zip(s, v)))
            if t not in nxt:
                nxt[t] = wit + (tuple(v),)
    partial = nxt
print('walls', W, 'reachable capped sums', len(partial))

for c in range(0, 10):
    need = (14 - c, 2, 14, 2 * c)
    hits = [(s, wit) for s, wit in partial.items() if all(a >= n for a, n in zip(s, need))]
    print('cut sheets', c, 'need', need, '->', len(hits), 'capped sums')
    for s, wit in hits[:4]:
        print('   ', dict(zip(W, wit)), 'tot', s)
