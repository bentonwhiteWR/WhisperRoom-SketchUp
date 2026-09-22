import json, numpy as np, sys
sys.path.insert(0,'.')
from cam import rot, project, F0
from lm import lm, line_resid
pk=json.load(open('picksA_room.json'))
use={'ceilB':'B_top','chairB':'B_chair','floorB':'B_floor','chairC1':'C_chair','chairC2':'C_chair','chairA1':'A_chair',
     'ceilC':'C_top','ceilA':'A_top','floorC1':'C_floor','floorC0':'C_floor','vertBC':'BC','vertAB':'AB'}
cx,cy=1512,2016
def lines3d(L,W,H,zc):
    return {'B_top':([L,0,H],[L,W,H]),'B_chair':([L,0,zc],[L,W,zc]),'B_floor':([L,0,0],[L,W,0]),
            'C_top':([0,0,H],[L,0,H]),'C_chair':([0,0,zc],[L,0,zc]),'C_floor':([0,0,0],[L,0,0]),
            'A_top':([0,W,H],[L,W,H]),'A_chair':([0,W,zc],[L,W,zc]),'A_floor':([0,W,0],[L,W,0]),
            'BC':([L,0,0],[L,0,H]),'AB':([L,W,0],[L,W,H])}
def resid(p, skip=()):
    yaw,pitch,roll,Y,L,W,H,zc,f=p
    C=np.array([0.0,Y,1.0]); R=rot(yaw,pitch,roll); ln=lines3d(L,W,H,zc); out=[]
    for k,lab in use.items():
        if k in skip: continue
        a,b=ln[lab]; ab,_=project(np.array([a,b],float),C,R,f,cx,cy)
        out.append(line_resid(pk[k],ab[0],ab[1]))
    return np.concatenate(out)
p0=[np.radians(-2),np.radians(13.6),0.0, 1.2, 4.5, 3.4, 2.1, 1.0, F0]
skip=('floorB','chairC2','chairA1')
fn=lambda p: resid(p,skip)
p,r,J=lm(fn,p0,fixed=(8,))
print('fixed f  rms px', np.sqrt(np.mean(r**2)).round(2))
print(dict(zip(['yaw','pitch','roll','Y','L','W','H','zc','f'],[round(float(v),4) for v in p])))
print('deg', np.degrees(p[:3]).round(2))
p2,r2,J2=lm(fn,p)
print('free f   rms px', np.sqrt(np.mean(r2**2)).round(2))
print(dict(zip(['yaw','pitch','roll','Y','L','W','H','zc','f'],[round(float(v),4) for v in p2])))
json.dump({'pA':p.tolist(),'pA_freef':p2.tolist()},open('solA.json','w'))
