"""Feasibility of a wall's piece counts when no piece may cross a horizontal line (a 'row scheme')."""
import sys
from v8solve import feasible, SC, show
def cut(lines):
    def f(m, P):
        for p in P:
            for L in lines:
                b = m.NewBoolVar('')
                m.Add(p['z'] + p['H'] + 25 <= round(L * SC)).OnlyEnforceIf(b)   # top <= L-0.25
                m.Add(p['z'] >= round(L * SC) + 25).OnlyEnforceIf(b.Not())       # bottom >= L+0.25
    return f
if __name__ == '__main__':
    comps = {'E': [(4,0,2)], 'W': [(3,1,2),(3,0,4)], 'N': [(3,1,1)], 'S': [(4,0,9),(4,1,7)]}
    for wall in sys.argv[1]:
        for L in [[27.5],[51.5],[27.5,51.75]]:
            for c in comps[wall]:
                st, p = feasible(wall, {'sheet':c[0],'1x4':c[1],'1x2':c[2]}, tl=float(sys.argv[2]), extra=cut(L))
                print(wall, c, 'no piece crosses z', L, '->', st, flush=True)
                if p and len(sys.argv) > 3: show(wall, p)
