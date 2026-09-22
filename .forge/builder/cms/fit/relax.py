import json, numpy as np, sys
sys.path.insert(0,'.')
from cam import rot, project
from lm import lm, line_resid
import joint4 as J4
pA,pB,obsA,obsB=J4.pA,J4.pB,J4.obsA,J4.obsB
def lines(L,W,H,zc,HA=None,HC=None,cang=0.0):
    HA=H if HA is None else HA; HC=H if HC is None else HC
    # wall C may be skewed by angle cang: y = x*tan(cang)
    t=np.tan(cang)
    return {'B_top':([L,L*t,HC],[L,W,HA]),'B_chair':([L,L*t,zc],[L,W,zc]),'B_floor':([L,L*t,0],[L,W,0]),
            'C_top':([0,0,HC],[L,L*t,HC]),'C_chair':([0,0,zc],[L,L*t,zc]),'C_floor':([0,0,0],[L,L*t,0]),
            'A_top':([0,W,HA],[L,W,HA]),'A_chair':([0,W,zc],[L,W,zc]),'A_floor':([0,W,0],[L,W,0]),
            'D_floor':([0,0,0],[0,W,0]),'BC':([L,L*t,0],[L,L*t,HC]),'AB':([L,W,0],[L,W,HA]),'DA':([0,W,0],[0,W,HA])}
def make(mode):
    def resid(p,det=False):
        L,W,H,zc,f,Ax,Ay,Ayaw,Ap,Ar,Bx,By,Bz,Byaw,Bp,Br,ex=p
        fA,fB=f,f; HA=HC=None; cang=0.0
        if mode=='fB': fB=ex
        if mode=='slope': HA=H+ex; HC=H
        if mode=='skewC': cang=ex
        ln=lines(L,W,H,zc,HA,HC,cang); out=[]; d={}
        for picks,obs,(C,R,cx,cy,ff),tag in ((pA,obsA,(np.array([Ax,Ay,1.0]),rot(Ayaw,Ap,Ar),1512,2016,fA),'A'),
                                              (pB,obsB,(np.array([Bx,By,Bz]),rot(Byaw,Bp,Br),2016,1512,fB),'B')):
            for k,(lab,w) in obs.items():
                a,b=ln[lab]; ab,_=project(np.array([a,b],float),C,R,ff,cx,cy)
                r=line_resid(picks[k],ab[0],ab[1]); out.append(w*r); d[tag+':'+k]=round(float(np.sqrt(np.mean(r**2))),1)
        r=np.concatenate(out); return (r,d) if det else r
    return resid
base=json.load(open('joint.json'))['p']
for mode,ex0 in (('none',0.0),('fB',1665.0),('slope',0.0),('skewC',0.0)):
    fn=make(mode); best=None
    for byy in (0.15,0.45):
        p0=list(base)+[ex0]; p0[11]=byy
        fixed=(16,) if mode=='none' else ()
        p,r,_=lm(fn,p0,iters=300,fixed=fixed); c=float(np.sqrt(np.mean(r**2)))
        if best is None or c<best[0]: best=(c,p)
    c,p=best; r,d=fn(p,True)
    print(mode,'rms',round(c,2),'extra',round(p[16],4),' L W H zc f',np.round(p[:5],3).tolist(),' A cam',np.round(p[5:7],2).tolist(),' B cam',np.round(p[10:13],2).tolist())
    print('    ',d)
