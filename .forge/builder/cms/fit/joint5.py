import json, numpy as np, sys
sys.path.insert(0,'.')
from cam import rot, project
from lm import lm, line_resid
pA=json.load(open('picksA_room.json')); pB=json.load(open('picksB_room.json'))
obsA={'ceilB':('B_top',1),'chairB':('B_chair',1),'chairC1':('C_chair',1),'ceilC':('C_top',1),'ceilA':('A_top',1),
      'floorC1':('C_floor',1),'vertBC':('BC',1),'vertAB':('AB',1),'floorB':('B_floor',1)}
obsB={'ceilA1':('A_top',1),'ceilA2':('A_top',1),'chairB':('B_chair',1),'chairA1':('A1_chair',1),
      'floorA1':('A1_floor',1),'vertDA':('DA1',1),'floorD':('D_floor',0.5),'ceilB':('B_top',0.5)}
NAMES=['L','W','H','zc','f','Ax','Ay','Ayaw','Apitch','Aroll','Bx','By','Bz','Byaw','Bpitch','Broll','s1']
def lines3d(L,W,H,zc,s1):
    return {'B_top':([L,0,H],[L,W,H]),'B_chair':([L,0,zc],[L,W,zc]),'B_floor':([L,0,0],[L,W,0]),
            'C_top':([0,0,H],[L,0,H]),'C_chair':([0,0,zc],[L,0,zc]),'C_floor':([0,0,0],[L,0,0]),
            'A_top':([0,W,H],[L,W,H]),'A1_chair':([0,W+s1,zc],[L,W+s1,zc]),'A1_floor':([0,W+s1,0],[L,W+s1,0]),
            'D_floor':([0,0,0],[0,W,0]),'BC':([L,0,0],[L,0,H]),'AB':([L,W,0],[L,W,H]),'DA1':([0,W+s1,0],[0,W+s1,H])}
def cams(p):
    L,W,H,zc,f,Ax,Ay,Ayaw,Ap,Ar,Bx,By,Bz,Byaw,Bp,Br,s1=p
    return (np.array([Ax,Ay,1.0]),rot(Ayaw,Ap,Ar),1512,2016),(np.array([Bx,By,Bz]),rot(Byaw,Bp,Br),2016,1512)
def resid(p,det=False):
    L,W,H,zc,f=p[:5]; ln=lines3d(L,W,H,zc,p[16]); ca,cb=cams(p); out=[]; d={}
    for picks,obs,(C,R,cx,cy),tag in ((pA,obsA,ca,'A'),(pB,obsB,cb,'B')):
        for k,(lab,w) in obs.items():
            a,b=ln[lab]; ab,_=project(np.array([a,b],float),C,R,f,cx,cy)
            r=line_resid(picks[k],ab[0],ab[1]); out.append(w*r); d[tag+':'+k]=round(float(np.sqrt(np.mean(r**2))),1)
    r=np.concatenate(out); return (r,d) if det else r
if __name__=='__main__':
    best=None
    base=json.load(open('joint.json'))['p']
    for byy in (0.2,0.5,0.8):
        for s1 in (0.0,0.3):
            p0=list(base)+[s1]; p0[11]=byy; p0[4]=1665
            p,r,_=lm(resid,p0,iters=400); c=float(np.sqrt(np.mean(r**2)))
            if best is None or c<best[0]: best=(c,p)
    c,p=best; r,d=resid(p,True)
    print('rms',round(c,2),d); print(dict(zip(NAMES,np.round(p,4).tolist())))
    print('H/W',round(p[2]/p[1],3),'L/W',round(p[0]/p[1],3),'H/zc',round(p[2]/p[3],3))
    json.dump({'p':[float(v) for v in p],'names':NAMES},open('joint5.json','w'))
