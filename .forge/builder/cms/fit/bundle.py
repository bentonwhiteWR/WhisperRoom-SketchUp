import json, numpy as np, sys
sys.path.insert(0,'.')
from cam import rot, project
from lm import lm
import joint5 as J
TIES={ # name: (photoA uv, photoB uv, plane hint)
 'closet_TL_east':((742,1376),(2419,1002),'B'),
 'closet_TR_west':((1030,1381),(2640,979),'B'),
 'wb_TL_east':((1073,1474),(2672,1052),'B'),
 'wb_TR_west':((1653,1487),(3369,1007),'B'),
 'tray_top_east':((1070,1797),(2641,1367),'B'),
 'tray_top_west':((1651,1806),(3333,1402),'B'),
 'swin_revB_top':((576,1197),(2274,889),'A'),
 'swin_revD_top':((235,1027),(2020,839),'A'),
 'fix1_east_top':((847,895),(2399,629),'C'),
 'fix1_west_top':((1860,940),(3455,316),'C'),
 'fix1_joint_top':((1362,913),(2814,505),'C'),
 'smoke':((1840,855),(3325,272),'C'),
}
names=list(TIES)
base=np.array(json.load(open('joint6.json'))['p'])
NB=len(base)
def unpack(p): return p[:NB], p[NB:].reshape(-1,3)
def resid(p, det=False, wtie=1.0, wplane=0.0):
    q,X=unpack(p)
    r,d=J.resid(q,True)
    (CA,RA,cxa,cya),(CB,RB,cxb,cyb)=J.cams(q); f=q[4]; L,W,H=q[0],q[1],q[2]
    out=[r]; td={}
    for i,n in enumerate(names):
        (ua,va),(ub,vb),pl=TIES[n]
        pa,_=project(X[i:i+1],CA,RA,f,cxa,cya); pb,_=project(X[i:i+1],CB,RB,f,cxb,cyb)
        e=np.array([pa[0,0]-ua,pa[0,1]-va,pb[0,0]-ub,pb[0,1]-vb])*wtie; out.append(e); td[n]=np.round(e,1).tolist()
        if wplane:
            if pl=='B': out.append([wplane*(X[i,0]-L)*100])
            if pl=='A': out.append([wplane*(X[i,1]-W)*100])
            if pl=='C': out.append([wplane*(X[i,2]-H)*100])
    r=np.concatenate([np.ravel(o) for o in out])
    return (r,d,td) if det else r
def init_points(q):
    # triangulate-ish: cast from A onto the hinted plane
    from cam import ray, hit_plane
    (CA,RA,cxa,cya),_=J.cams(q); f=q[4]; L,W,H=q[0],q[1],q[2]; pts=[]
    for n in names:
        (ua,va),_,pl=TIES[n]; w=ray(ua,va,RA,f,cxa,cya)
        ax,val={'B':(0,L),'A':(1,W),'C':(2,H)}[pl]; pts.append(hit_plane(CA,w,ax,val))
    return np.array(pts)
if __name__=='__main__':
    wplane=float(sys.argv[1]) if len(sys.argv)>1 else 0.0
    p0=np.concatenate([base,init_points(base).ravel()])
    p,r,_=lm(lambda q: resid(q,wplane=wplane),p0,iters=300)
    r,d,td=resid(p,True,wplane=wplane)
    q,X=unpack(p)
    print('rms all',round(float(np.sqrt(np.mean(r**2))),2)); print('lines',d)
    for n in names: print('  tie',n.ljust(16),td[n])
    print(dict(zip(J.NAMES,np.round(q,4).tolist())))
    L,W,H=q[:3]
    for n,P in zip(names,X):
        print(f'  {n:16s} room x={P[0]:.3f} (L={L:.3f}) y={P[1]:.3f} (W={W:.3f}) z={P[2]:.3f} (H={H:.3f})')
    json.dump({'p':[float(v) for v in q],'names':J.NAMES,'ties':{n:P.tolist() for n,P in zip(names,X)}},open('bundle.json','w'))
