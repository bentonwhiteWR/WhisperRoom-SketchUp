import json, numpy as np, sys
sys.path.insert(0,'.')
from cam import rot, project
from lm import lm, line_resid
import joint as J
pk=json.load(open('picksA_room.json'))
obs={'ceilB':'B_top','chairB':'B_chair','floorB':'B_floor','chairC1':'C_chair','ceilC':'C_top','ceilA':'A_top',
     'floorC1':'C_floor','vertBC':'BC','vertAB':'AB'}
def resid(p,skip=(),det=False):
    yaw,pitch,roll,Y,L,W,H,zc,f,dx,dy=p
    C=np.array([0,Y,1.0]); R=rot(yaw,pitch,roll); ln=J.lines3d(L,W,H,zc); out=[]; d={}
    for k,lab in obs.items():
        if k in skip: continue
        a,b=ln[lab]; ab,_=project(np.array([a,b],float),C,R,f,1512+dx,2016+dy)
        r=line_resid(pk[k],ab[0],ab[1]); out.append(r); d[k]=round(float(np.sqrt(np.mean(r**2))),1)
    r=np.concatenate(out); return (r,d) if det else r
p0=[-0.03,0.2258,-0.035,1.35,4.9,3.4,2.2,1.0,1665,0,0]
for fixed,lab in (((8,9,10),'f fixed 1665, pp centre'),((9,10),'f free, pp centre'),((),'f + pp free')):
    p,r,_=lm(resid,p0,fixed=fixed,iters=400)
    r,d=resid(p,det=True)
    print(lab,'rms',round(float(np.sqrt(np.mean(r**2))),2),d)
    print('   ',dict(zip(['yaw','pitch','roll','Y','L','W','H','zc','f','dx','dy'],np.round(p,3).tolist())))
    for sk in ('ceilB','floorB','chairC1','ceilC','ceilA','floorC1','vertBC'):
        p2,r2,_=lm(lambda q: resid(q,(sk,)),p,fixed=fixed,iters=200)
        print('      drop',sk.ljust(8),'rms',round(float(np.sqrt(np.mean(r2**2))),2),' H/W',round(p2[6]/p2[5],3),' L/W',round(p2[4]/p2[5],3))
