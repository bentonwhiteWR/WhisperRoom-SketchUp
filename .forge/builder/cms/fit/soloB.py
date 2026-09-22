import json, numpy as np, sys
sys.path.insert(0,'.')
from cam import rot, project
from lm import lm, line_resid
import joint as J
pk=json.load(open('picksB_room.json'))
obs={'ceilA1':'A_top','ceilA2':'A_top','chairB':'B_chair','chairA1':'A_chair','chairA2':'A_chair','floorA1':'A_floor',
     'vertDA':'DA','floorD':'D_floor','vertAB':'AB','ceilB':'B_top'}
def resid(p,skip=(),det=False):
    x,y,yaw,pitch,roll,L,W,H,zc,f=p
    C=np.array([x,y,1.0]); R=rot(yaw,pitch,roll); ln=J.lines3d(L,W,H,zc); out=[]; d={}
    for k,lab in obs.items():
        if k in skip: continue
        a,b=ln[lab]; ab,_=project(np.array([a,b],float),C,R,f,2016,1512)
        r=line_resid(pk[k],ab[0],ab[1]); out.append(r); d[k]=round(float(np.sqrt(np.mean(r**2))),1)
    r=np.concatenate(out); return (r,d) if det else r
best=None
for x0 in (0.1,0.5,1.0):
  for y0 in (0.2,0.6,1.0):
    p0=[x0,y0,0.8,0.18,0.0,4.9,3.4,2.3,1.0,1665]
    p,r,_=lm(resid,p0,fixed=(9,),iters=300); c=float(np.sqrt(np.mean(r**2)))
    if best is None or c<best[0]: best=(c,p)
c,p=best; r,d=resid(p,det=True)
print('f fixed rms',round(c,2),d); print('  ',dict(zip(['x','y','yaw','pitch','roll','L','W','H','zc','f'],np.round(p,3).tolist())),' H/W',round(p[7]/p[6],3),' zc/W',round(p[8]/p[6],3))
for sk in obs:
    p2,r2,_=lm(lambda q: resid(q,(sk,)),p,fixed=(9,),iters=200)
    print('   drop',sk.ljust(8),'rms',round(float(np.sqrt(np.mean(r2**2))),2),' H/W',round(p2[7]/p2[6],3),' zc/W',round(p2[8]/p2[6],3),' W',round(p2[6],3),'x,y',np.round(p2[:2],2))
