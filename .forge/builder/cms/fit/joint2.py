import json, numpy as np, sys
sys.path.insert(0,'.')
from cam import rot
from lm import lm
import joint as J0
pA,pB,lines3d=J0.pA,J0.pB,J0.lines3d
obsA=dict(J0.obsA); obsA.pop('floorC0')
obsB=dict(J0.obsB)
NAMES=J0.NAMES+['k1','k2']
def proj(X,C,R,f,cx,cy,k1,k2):
    Xc=(np.atleast_2d(X)-C)@R.T; x=Xc[:,0]/Xc[:,2]; y=Xc[:,1]/Xc[:,2]; r2=x*x+y*y; s=1+k1*r2+k2*r2*r2
    return np.c_[cx+f*x*s, cy+f*y*s]
def seg_dist(pts,X0,X1,C,R,f,cx,cy,k1,k2,n=60):
    """distance of each pick to the (curved) projected 3D line, sampled densely"""
    t=np.linspace(-0.5,1.5,n*2)[:,None]; P=X0[None,:]*(1-t)+X1[None,:]*t
    Xc=(P-C)@R.T; P=P[Xc[:,2]>0.05]
    q=proj(P,C,R,f,cx,cy,k1,k2)
    out=[]
    for pt in np.asarray(pts):
        d=np.hypot(q[:,0]-pt[0],q[:,1]-pt[1]); i=int(np.argmin(d))
        j=min(i+1,len(q)-1); i0=max(i-1,0); a,b=q[i0],q[j]; v=b-a; nrm=np.array([-v[1],v[0]])/(np.linalg.norm(v)+1e-9)
        out.append((pt-a)@nrm)
    return np.array(out)
def cams(p):
    L,W,H,zc,f,Ax,Ay,Ayaw,Ap,Ar,Bx,By,Bz,Byaw,Bp,Br,k1,k2=p
    return (np.array([Ax,Ay,1.0]),rot(Ayaw,Ap,Ar),1512,2016),(np.array([Bx,By,Bz]),rot(Byaw,Bp,Br),2016,1512)
def resid(p, detail=False, per=False):
    L,W,H,zc,f=p[:5]; k1,k2=p[16],p[17]; ln=lines3d(L,W,H,zc); ca,cb=cams(p); out=[]; det={}
    for picks,obs,(C,R,cx,cy),tag in ((pA,obsA,ca,'A'),(pB,obsB,cb,'B')):
        for k,(lab,w) in obs.items():
            a,b=ln[lab]; r=seg_dist(picks[k],np.array(a,float),np.array(b,float),C,R,f,cx,cy,k1,k2)
            out.append(w*r); det[tag+':'+k]=r if per else float(np.sqrt(np.mean(r**2)))
    r=np.concatenate(out)
    return (r,det) if detail else r
if __name__=='__main__':
    p0=json.load(open('joint.json'))['p']+[0.0,0.0]
    p,r,Jm=lm(resid,p0,iters=200)
    r,det=resid(p,True,True)
    print('rms px', round(float(np.sqrt(np.mean(r**2))),2))
    for k,v in det.items(): print('  ',k.ljust(10),' '.join(f'{x:+5.1f}' for x in v))
    d=dict(zip(NAMES,[float(v) for v in p]))
    for k in ('Ayaw','Apitch','Aroll','Byaw','Bpitch','Broll'): d[k+'_deg']=float(np.degrees(d[k]))
    print(json.dumps({k:round(v,4) for k,v in d.items()}))
    json.dump({'p':[float(v) for v in p],'names':NAMES},open('joint2.json','w'))
