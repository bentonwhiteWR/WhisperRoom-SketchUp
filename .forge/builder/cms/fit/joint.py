import json, numpy as np, sys
sys.path.insert(0,'.')
from cam import rot, project
from lm import lm, line_resid
pA=json.load(open('picksA_room.json')); pB=json.load(open('picksB_room.json'))
obsA={'ceilB':('B_top',1),'chairB':('B_chair',1),'chairC1':('C_chair',1),'ceilC':('C_top',1),'ceilA':('A_top',1),
      'floorC1':('C_floor',1),'floorC0':('C_floor',0.5),'vertBC':('BC',1),'vertAB':('AB',1)}
obsB={'ceilA1':('A_top',1),'ceilA2':('A_top',1),'chairB':('B_chair',1),'chairA1':('A_chair',1),'chairA2':('A_chair',1),
      'floorA1':('A_floor',1),'vertDA':('DA',1),'floorD':('D_floor',1),'vertAB':('AB',0.5),'ceilB':('B_top',0.5)}
NAMES=['L','W','H','zc','f','Ax','Ay','Ayaw','Apitch','Aroll','Bx','By','Bz','Byaw','Bpitch','Broll']
def lines3d(L,W,H,zc):
    return {'B_top':([L,0,H],[L,W,H]),'B_chair':([L,0,zc],[L,W,zc]),'B_floor':([L,0,0],[L,W,0]),
            'C_top':([0,0,H],[L,0,H]),'C_chair':([0,0,zc],[L,0,zc]),'C_floor':([0,0,0],[L,0,0]),
            'A_top':([0,W,H],[L,W,H]),'A_chair':([0,W,zc],[L,W,zc]),'A_floor':([0,W,0],[L,W,0]),
            'D_floor':([0,0,0],[0,W,0]),'D_top':([0,0,H],[0,W,H]),
            'BC':([L,0,0],[L,0,H]),'AB':([L,W,0],[L,W,H]),'DA':([0,W,0],[0,W,H]),'CD':([0,0,0],[0,0,H])}
def cams(p):
    L,W,H,zc,f,Ax,Ay,Ayaw,Ap,Ar,Bx,By,Bz,Byaw,Bp,Br=p
    return (np.array([Ax,Ay,1.0]),rot(Ayaw,Ap,Ar),1512,2016),(np.array([Bx,By,Bz]),rot(Byaw,Bp,Br),2016,1512)
def resid(p, detail=False):
    L,W,H,zc,f=p[:5]; ln=lines3d(L,W,H,zc); ca,cb=cams(p); out=[]; det={}
    for picks,obs,(C,R,cx,cy),tag in ((pA,obsA,ca,'A'),(pB,obsB,cb,'B')):
        for k,(lab,w) in obs.items():
            a,b=ln[lab]; ab,z=project(np.array([a,b],float),C,R,f,cx,cy)
            r=line_resid(picks[k],ab[0],ab[1]); out.append(w*r); det[tag+':'+k]=float(np.sqrt(np.mean(r**2)))
    r=np.concatenate(out)
    return (r,det) if detail else r
if __name__=='__main__':
    sA=json.load(open('solA.json'))['pA']
    p0=[sA[4]+2.0, sA[5], sA[6], sA[7], 1860.0, 2.0, sA[3], sA[0], sA[1], sA[2],
        3.2, 1.0, 1.0, np.radians(65), np.radians(10), 0.0]
    best=None
    for byaw in (50,60,70,80):
        for bx in (2.0,3.0,4.0):
            q=list(p0); q[13]=np.radians(byaw); q[10]=bx
            p,r,J=lm(resid,q,iters=300)
            c=float(np.sqrt(np.mean(r**2)))
            if best is None or c<best[0]: best=(c,p)
    c,p=best
    r,det=resid(p,True)
    print('rms px', round(c,2))
    for k,v in det.items(): print('  ',k,round(v,2))
    d=dict(zip(NAMES,[float(v) for v in p]))
    for k in ('Ayaw','Apitch','Aroll','Byaw','Bpitch','Broll'): d[k+'_deg']=float(np.degrees(d[k]))
    print(json.dumps({k:round(v,4) for k,v in d.items()},indent=0))
    json.dump({'p':[float(v) for v in p],'names':NAMES},open('joint.json','w'))
