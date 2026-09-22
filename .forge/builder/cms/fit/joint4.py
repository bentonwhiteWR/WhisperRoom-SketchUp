import json, numpy as np, sys
sys.path.insert(0,'.')
from cam import rot, project
from lm import lm, line_resid
import joint as J
pA=json.load(open('picksA_room.json')); pB=json.load(open('picksB_room.json'))
obsA={'ceilB':('B_top',1),'chairB':('B_chair',1),'chairC1':('C_chair',1),'ceilC':('C_top',1),'ceilA':('A_top',1),
      'floorC1':('C_floor',1),'vertBC':('BC',1),'vertAB':('AB',1),'floorB':('B_floor',1)}
obsB={'ceilA1':('A_top',1),'ceilA2':('A_top',1),'chairB':('B_chair',1),'chairA1':('A_chair',1),'chairA2':('A_chair',1),
      'floorA1':('A_floor',1),'vertDA':('DA',1),'floorD':('D_floor',0.5),'vertAB':('AB',0.5),'ceilB':('B_top',0.5)}
NAMES=J.NAMES+['dxs','dys']
def cams(p):
    L,W,H,zc,f,Ax,Ay,Ayaw,Ap,Ar,Bx,By,Bz,Byaw,Bp,Br,dxs,dys=p
    return (np.array([Ax,Ay,1.0]),rot(Ayaw,Ap,Ar),1512-dys,2016+dxs),(np.array([Bx,By,Bz]),rot(Byaw,Bp,Br),2016+dxs,1512+dys)
def resid(p,det=False,prior=0.02):
    L,W,H,zc,f=p[:5]; ln=J.lines3d(L,W,H,zc); ca,cb=cams(p); out=[]; d={}
    for picks,obs,(C,R,cx,cy),tag in ((pA,obsA,ca,'A'),(pB,obsB,cb,'B')):
        for k,(lab,w) in obs.items():
            a,b=ln[lab]; ab,_=project(np.array([a,b],float),C,R,f,cx,cy)
            r=line_resid(picks[k],ab[0],ab[1]); out.append(w*r); d[tag+':'+k]=round(float(np.sqrt(np.mean(r**2))),1)
    out.append(np.array([prior*p[16],prior*p[17]]))
    r=np.concatenate(out); return (r,d) if det else r
if __name__=='__main__':
    best=None
    for byy in (0.15,0.4):
        for dys in (-150,0,150):
            p0=list(json.load(open('joint.json'))['p'])+[0.0,float(dys)]; p0[11]=byy
            p,r,_=lm(resid,p0,iters=400); c=float(np.sqrt(np.mean(r[:-2]**2)))
            if best is None or c<best[0]: best=(c,p)
    c,p=best; r,d=resid(p,True)
    print('rms',round(c,2),d); print(dict(zip(NAMES,np.round(p,3).tolist())))
    json.dump({'p':[float(v) for v in p],'names':NAMES},open('joint4.json','w'))
