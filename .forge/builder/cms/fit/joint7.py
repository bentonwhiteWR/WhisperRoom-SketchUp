"""Joint refit on ALL the evidence the two candidates split between them: every room-edge
pick in both photos against the PLAIN box room.rb builds (s1 = 0), plus the 12 cross-photo
ties as free 3D points. B:vertBC (grazing right edge of the ultrawide B; misses by 80-130 px
under every fit, with or without a distortion term) is down-weighted to 0.25.
Scale afterwards from the fluorescent run (fix1_east_top -> fix1_west_top) = 97 in."""
import json, numpy as np, sys
sys.path.insert(0,'.')
from cam import project
from lm import lm, line_resid
import joint5 as J, bundle as B
from evalfits import MAPA, MAPB, lines, score, ties_on_plane
pA=json.load(open('picksA_room.json')); pB=json.load(open('picksB_room.json'))
names=list(B.TIES); WT={'B:vertBC':0.25}
def resid(q):
    p=q[:17].copy(); p[16]=0.0; X=q[17:].reshape(-1,3)
    L,W,H,zc,f=p[:5]; ln=lines(L,W,H,zc,0.0); ca,cb=J.cams(p); out=[]
    for picks,mp,(C,R,cx,cy),tag in ((pA,MAPA,ca,'A'),(pB,MAPB,cb,'B')):
        for k,lab in mp.items():
            a,b=ln[lab]; ab,_=project(np.array([a,b],float),C,R,f,cx,cy)
            out.append(WT.get(tag+':'+k,1.0)*line_resid(picks[k],ab[0],ab[1]))
    (CA,RA,cxa,cya),(CB,RB,cxb,cyb)=ca,cb
    for i,n in enumerate(names):
        (ua,va),(ub,vb),_=B.TIES[n]
        qa,_=project(X[i:i+1],CA,RA,f,cxa,cya); qb,_=project(X[i:i+1],CB,RB,f,cxb,cyb)
        out.append([qa[0,0]-ua,qa[0,1]-va,qb[0,0]-ub,qb[0,1]-vb])
    return np.concatenate([np.ravel(o) for o in out])
best=None
for src in ('joint6.json','final_fit.json'):
    ff=json.load(open('final_fit.json')); p0=np.array(json.load(open(src))['p']); p0[16]=0.0
    q0=np.concatenate([p0,np.array([ff['ties'][n] for n in names]).ravel()])
    q,r,_=lm(resid,q0,iters=300,fixed=(16,)); c=float(np.sqrt(np.mean(r**2)))
    print('start',src,'cost rms',round(c,2))
    if best is None or c<best[0]: best=(c,q)
q=best[1]; p=q[:17]; X=q[17:].reshape(-1,3)
run=float(np.linalg.norm(X[names.index('fix1_east_top')]-X[names.index('fix1_west_top')])); h=97.0/run
json.dump({'p':[float(v) for v in p],'names':J.NAMES,'ties':{n:X[i].tolist() for i,n in enumerate(names)},'run_h':run},open('joint7.json','w'))
json.dump({'h':h,'run':run,'anchor':'fluorescent run, two 4-ft wraparounds end to end, taken as 97 in'},open('scale_joint7.json','w'))
print('joint7 L W H zc in',[round(v*h,1) for v in p[:4]],'h',round(h,2),'f',round(p[4],1))
for nm,fn in (('fit.json','joint6.json'),('final_fit','final_fit.json'),('joint7','joint7.json')):
    pp=np.array(json.load(open(fn))['p']); s=score(pp,0.0); t,_=ties_on_plane(pp)
    lv=[v for k,v in s.items() if ':' in k]
    ex=[v for k,v in s.items() if ':' in k and k!='B:vertBC']
    print(f'{nm:10s} plain box: A rms {s["A_rms"]:5.1f} | B rms {s["B_rms"]:5.1f} | median line {np.median(lv):4.1f} | rms excl B:vertBC {np.sqrt(np.mean(np.square(ex))):5.1f} | plane-pinned ties {t:5.2f}')
