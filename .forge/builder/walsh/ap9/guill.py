# 4-stage guillotine (rows/columns, recursively) max packing per wall, exact coordinates, keep-outs + 0.5 gaps.
import functools, itertools, sys, json, time
from walls import *
KEYS=['B','F4','H','Q']
def add(a,b): return tuple(x+y for x,y in zip(a,b))
def pareto(S):
    S=list(set(S)); S.sort(reverse=True); out=[]
    for v in S:
        if not any(all(x>=y for x,y in zip(u,v)) for u in out): out.append(v)
    return out
def combos(dims,lim):
    out={0.0}; frontier={0.0}
    while frontier:
        nf=set()
        for v in frontier:
            for d in dims:
                n=round(d if v==0 else v+G+d,4)
                if n<=lim+1e-9 and n not in out: nf.add(n)
        out|=nf; frontier=nf
    return sorted(x for x in out if x>0)
def run(wall,depth=4,allowQ=True):
    lo,hi=WALLS[wall]['s']; K=WALLS[wall]['K']
    WS=combos([12,24,48],hi-lo); HS=combos([12,24,48],ZMAX-ZMIN)
    kinds=[k for k in KINDS if allowQ or k!='Q']
    def clear(s0,s1,z0,z1):
        for _,a,b,c,d in K:
            if s1>a-G+1e-9 and s0<b+G-1e-9 and z1>c-G+1e-9 and z0<d+G-1e-9: return False
        return True
    @functools.lru_cache(None)
    def single(s0,s1,z0,z1):
        res=[(0,0,0,0)]
        for k in kinds:
            w,h,key=KINDS[k]
            if w>s1-s0+1e-9 or h>z1-z0+1e-9: continue
            ss={s0,s1-w}|{round(b+G,4) for _,a,b,c,d in K if s0<b+G<s1-w}
            zz={z0,z1-h}|{round(d+G,4) for _,a,b,c,d in K if z0<d+G<z1-h}
            if any(clear(s,s+w,z,z+h) for s in ss for z in zz):
                v=[0,0,0,0]; v[KEYS.index(key)]=1; res.append(tuple(v))
        return tuple(pareto(res))
    @functools.lru_cache(None)
    def solve(s0,s1,z0,z1,axis,dep):
        if dep==0: return single(s0,s1,z0,z1)
        # slices along axis
        if axis=='s': A0,A1,sizes=s0,s1,WS
        else: A0,A1,sizes=z0,z1,HS
        edges=sorted({round((b if axis=='s' else d)+G,4) for _,a,b,c,d in K})
        @functools.lru_cache(None)
        def seq(cur):
            best=[(0,0,0,0)]
            starts=[cur]+[e for e in edges if cur<e<A1]
            for a in starts:
                for w in sizes:
                    if a+w>A1+1e-9: break
                    b=round(a+w,4)
                    sub=solve(a,b,z0,z1,'z',dep-1) if axis=='s' else solve(s0,s1,a,b,'s',dep-1)
                    if sub==((0,0,0,0),): continue
                    rest=seq(round(b+G,4))
                    for u in sub:
                        for v in rest: best.append(add(u,v))
                best=pareto(best)
            return tuple(best)
        r=seq(A0)
        seq.cache_clear()
        return r
    out=pareto(list(solve(lo,hi,ZMIN,ZMAX,'s',depth))+list(solve(lo,hi,ZMIN,ZMAX,'z',depth)))
    return out
if __name__=='__main__':
    dep=int(sys.argv[1]) if len(sys.argv)>1 else 3
    caps={}
    for w in sys.argv[2:] or 'EWNS':
        t=time.time(); c=run(w,dep); caps[w]=c
        cells=max(2*b+f+0.5*h+q for b,f,h,q in c)
        print(w,'depth',dep,'pareto',len(c),'max cells',cells,f'{time.time()-t:.1f}s',flush=True)
    json.dump(caps,open(f'gcaps{dep}.json','w'))
