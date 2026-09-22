"""Diagnostic only: does a per-photo radial term (k1) absorb the edge-of-frame misses,
and does the wall-A setback s1 survive once it does?"""
import json, numpy as np, sys
sys.path.insert(0,'.')
from cam import project
from lm import lm, line_resid
import joint5 as J, bundle as B
exec(open('evalfits.py').read().split("def score")[0].split("pA=json")[1].join(["pA=json",""]) if False else "")
pA=json.load(open('picksA_room.json')); pB=json.load(open('picksB_room.json'))
from evalfits import MAPA, MAPB, lines
def undist(uv,cx,cy,f,k):   # map observed (distorted) pixel -> ideal pinhole pixel
    uv=np.asarray(uv,float); d=(uv-[cx,cy])/f; r2=(d**2).sum(1,keepdims=True); return [cx,cy]+f*d*(1+k*r2)
names=list(B.TIES)
def resid(q, fix_s1=None, det=False):
    p=q[:17].copy(); kA,kB=q[17],q[18]; X=q[19:].reshape(-1,3)
    if fix_s1 is not None: p[16]=fix_s1
    L,W,H,zc,f=p[:5]; ln=lines(L,W,H,zc,p[16]); ca,cb=J.cams(p); out=[]; d={}
    for picks,mp,(C,R,cx,cy),k,tag in ((pA,MAPA,ca,kA,'A'),(pB,MAPB,cb,kB,'B')):
        for key,lab in mp.items():
            a,b=ln[lab]; ab,_=project(np.array([a,b],float),C,R,f,cx,cy)
            r=line_resid(undist(picks[key],cx,cy,f,k),ab[0],ab[1]); out.append(r); d[tag+':'+key]=round(float(np.sqrt(np.mean(r**2))),1)
    (CA,RA,cxa,cya),(CB,RB,cxb,cyb)=ca,cb
    for i,n in enumerate(names):
        (ua,va),(ub,vb),pl=B.TIES[n]
        qa,_=project(X[i:i+1],CA,RA,f,cxa,cya); qb,_=project(X[i:i+1],CB,RB,f,cxb,cyb)
        ia=undist([[ua,va]],cxa,cya,f,kA)[0]; ib=undist([[ub,vb]],cxb,cyb,f,kB)[0]
        e=np.array([qa[0,0]-ia[0],qa[0,1]-ia[1],qb[0,0]-ib[0],qb[0,1]-ib[1]]); out.append(e); d['tie:'+n]=round(float(np.sqrt(np.mean(e**2))),1)
    r=np.concatenate(out); return (r,d) if det else r
ff=json.load(open('final_fit.json'))
X0=np.array([ff['ties'][n] for n in names]).ravel()
p0=np.array(ff['p'])
for label,kfree,fs1 in (('no k, s1 free',False,None),('k free, s1 free',True,None),('k free, s1=0',True,0.0)):
    q0=np.concatenate([p0,[0.0,0.0],X0])
    fixed=(17,18) if not kfree else ()
    if fs1 is not None: fixed=fixed+(16,)
    q,r,_=lm(lambda v: resid(v,fs1),q0,iters=250,fixed=fixed)
    r,d=resid(q,fs1,True); h=97.0/np.linalg.norm(q[19:].reshape(-1,3)[names.index('fix1_east_top')]-q[19:].reshape(-1,3)[names.index('fix1_west_top')])
    lines_=[v for k,v in d.items() if not k.startswith('tie')]; ties_=[v for k,v in d.items() if k.startswith('tie')]
    print(f'{label:18s} rms {np.sqrt(np.mean(r**2)):.2f}  lines med {np.median(lines_):.1f} max {max(lines_):.1f}  ties rms {np.sqrt(np.mean(np.square(ties_))):.2f}  kA {q[17]:+.4f} kB {q[18]:+.4f}  s1 {(q[16] if fs1 is None else fs1)*h:.1f} in')
    print(f'{"":18s} L {q[0]*h:.1f}  W {q[1]*h:.1f}  H {q[2]*h:.1f}  zc {q[3]*h:.1f}  h {h:.2f}  worst: {sorted(d.items(),key=lambda kv:-kv[1])[:5]}')
