"""Snap a rough line to the real image edge.
mode 'dark' = darkest crease, 'edge' = strongest step, 'bright' = brightest line.
Returns refined sample points and a fitted line; writes a check tile."""
import cv2, numpy as np, json, sys
P='C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/clients/community-music-school/plans/'
_cache={}
def gray(photo):
    if photo not in _cache:
        g=cv2.cvtColor(cv2.imread(P+photo),cv2.COLOR_BGR2GRAY).astype(np.float32)
        _cache[photo]=cv2.GaussianBlur(g,(0,0),2.0)
    return _cache[photo]
def refine(photo,p1,p2,mode='dark',hw=25,k=15,trim=0.08):
    g=gray(photo); p1=np.array(p1,float); p2=np.array(p2,float)
    d=p2-p1; L=np.linalg.norm(d); t=d/L; n=np.array([-t[1],t[0]])
    pts=[]
    for s in np.linspace(trim,1-trim,k):
        c=p1+d*s; offs=np.arange(-hw,hw+1,0.5)
        xy=c[None,:]+offs[:,None]*n[None,:]
        prof=cv2.remap(g,xy[:,0].astype(np.float32).reshape(1,-1),xy[:,1].astype(np.float32).reshape(1,-1),cv2.INTER_LINEAR).ravel()
        if mode=='dark': i=int(np.argmin(prof))
        elif mode=='bright': i=int(np.argmax(prof))
        else:
            gr=np.abs(np.gradient(prof)); i=int(np.argmax(gr))
        if 2<i<len(offs)-3: pts.append(c+offs[i]*n)
    pts=np.array(pts)
    # robust line fit
    for _ in range(3):
        m=pts.mean(0); u,s,vt=np.linalg.svd(pts-m); dirv=vt[0]; nn=np.array([-dirv[1],dirv[0]])
        r=(pts-m)@nn
        keep=np.abs(r)<max(2.0,2.5*np.median(np.abs(r))+0.5)
        if keep.all(): break
        pts=pts[keep]
    return pts, float(np.sqrt(np.mean(r[keep]**2)) if keep.any() else -1)
_cc={}
def carpetmap(photo):
    if photo not in _cc:
        im=cv2.imread(P+photo).astype(np.float32)
        d=im[:,:,0]-im[:,:,2]          # blue minus red: carpet high, oak low
        _cc[photo]=cv2.GaussianBlur(d,(0,0),1.5)
    return _cc[photo]
def refine_carpet(photo,p1,p2,hw=40,k=15,trim=0.08,side=1):
    """side=+1: carpet lies on the +normal side. Finds the oak->carpet step."""
    g=carpetmap(photo); p1=np.array(p1,float); p2=np.array(p2,float)
    d=p2-p1; L=np.linalg.norm(d); t=d/L; n=np.array([-t[1],t[0]])
    pts=[]
    for s in np.linspace(trim,1-trim,k):
        c=p1+d*s; offs=np.arange(-hw,hw+1,0.5); xy=c[None,:]+offs[:,None]*n[None,:]
        prof=cv2.remap(g,xy[:,0].astype(np.float32).reshape(1,-1),xy[:,1].astype(np.float32).reshape(1,-1),cv2.INTER_LINEAR).ravel()
        gr=np.gradient(prof)*side; i=int(np.argmax(gr))
        if 2<i<len(offs)-3: pts.append(c+offs[i]*n)
    pts=np.array(pts)
    m=pts.mean(0); u,s_,vt=np.linalg.svd(pts-m); dv=vt[0]; nn=np.array([-dv[1],dv[0]]); r=(pts-m)@nn
    keep=np.abs(r)<max(2.0,2.5*np.median(np.abs(r))+0.5)
    return pts[keep], float(np.sqrt(np.mean(r[keep]**2)))
