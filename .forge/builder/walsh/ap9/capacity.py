import itertools, functools, json
from walls import *
# count vector: (B, F4, H, Q)
def add(a,b): return tuple(x+y for x,y in zip(a,b))
def pareto(S):
    S=set(S); out=[]
    for v in S:
        if not any(u!=v and all(x>=y for x,y in zip(u,v)) for u in S): out.append(v)
    return out
# block types: list of sub-column widths; rows: tuples of items per sub-col, or a full-width item
SUB={24:['Bv','Q','Hh',None],12:['F4v','Hv',None]}
BLOCKS={'24':[24],'12':[12],'48':[48],'24|24':[24,24],'24|12':[24,12],'12|24':[12,24],'12|12':[12,12]}
def width(bt): 
    ws=BLOCKS[bt]; return sum(ws)+G*(len(ws)-1) if bt!='48' else 48
def rows_for(bt):
    ws=BLOCKS[bt]; R=[]
    if bt=='48':
        R=[('Bh',),('F4h',)]
    else:
        for combo in itertools.product(*[SUB[w] for w in ws]):
            if all(c is None for c in combo): continue
            R.append(combo)
        if width(bt)>=48: R+= [('Bh',),('F4h',)]
    out=[]
    for r in R:
        h=max(KINDS[c][1] for c in r if c)
        v=[0,0,0,0]
        for c in r:
            if c: v[['B','F4','H','Q'].index(KINDS[c][2])]+=1
        out.append((h,tuple(v),r))
    return out
@functools.lru_cache(None)
def stack(bt,L):
    """pareto count vectors achievable stacking rows into a free interval of length L (gaps G between rows)."""
    rows=rows_for(bt)
    res={(0,0,0,0)}
    # dp over remaining length, rows with gap: each row costs h+G, total <= L+G
    @functools.lru_cache(None)
    def go(rem):
        best={(0,0,0,0)}
        for h,v,_ in rows:
            if h+G<=rem+1e-9:
                for u in go(round(rem-h-G,4)): best.add(add(u,v))
        return frozenset(pareto(best))
    return go(round(L+G,4))
def block_caps(wall,bt,s0):
    s1=s0+width(bt)
    tot={(0,0,0,0)}
    for a,b in free_z(wall,s0,s1):
        new=set()
        for u in tot:
            for v in stack(bt,round(b-a,4)): new.add(add(u,v))
        tot=set(pareto(new))
    return tot
def wall_caps(wall):
    lo,hi=WALLS[wall]['s']
    edges=sorted(set([lo]+[round(k[2]+G,4) for k in WALLS[wall]['K'] if lo<k[2]+G<hi]))
    @functools.lru_cache(None)
    def go(cur):
        best={(0,0,0,0)}
        cands=[cur]+[e for e in edges if e>cur+1e-9]
        for s0 in cands:
            for bt in BLOCKS:
                w=width(bt)
                if s0+w>hi+1e-9: continue
                bc=block_caps(wall,bt,round(s0,4))
                rest=go(round(s0+w+G,4))
                for u in bc:
                    for v in rest: best.add(add(u,v))
            best=set(pareto(best))
        return frozenset(best)
    return go(lo)
if __name__=='__main__':
    caps={}
    for w in 'SEWN':
        c=wall_caps(w); caps[w]=sorted(c)
        cells=max(2*b+f+0.5*h+q for b,f,h,q in c)
        print(w,'pareto size',len(c),' max cells',cells)
    json.dump(caps,open('caps.json','w'))
