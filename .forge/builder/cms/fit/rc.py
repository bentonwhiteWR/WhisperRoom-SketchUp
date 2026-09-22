"""Ray-cast picked pixels onto room planes, answer in SketchUp inches.
Planes (SU frame): 'E' X=W (Wall A), 'W' X=0 (Wall C), 'S' Y=0 (Wall B), 'N' Y=L (Wall D), 'F' Z=0, 'C' Z=H,
or ('X',val) / ('Y',val) / ('Z',val)."""
import json, numpy as np, sys
sys.path.insert(0,'.')
from cam import rot, ray, hit_plane, project
import joint5 as J
_p=np.array(json.load(open('joint7.json'))['p']); h=json.load(open('scale_joint7.json'))['h']
L,W,H,zc,f=_p[:5]
CAMS=dict(zip('AB',J.cams(_p)))
Li,Wi,Hi=L*h,W*h,H*h
def su(v): return np.array([v[1]*h, Li-v[0]*h, v[2]*h])
def room(P): return np.array([(Li-P[1])/h, P[0]/h, P[2]/h])
def plane(pl):
    if pl=='E': return ('X',Wi)
    if pl=='W': return ('X',0.0)
    if pl=='S': return ('Y',0.0)
    if pl=='N': return ('Y',Li)
    if pl=='F': return ('Z',0.0)
    if pl=='C': return ('Z',Hi)
    return pl
def cast(photo,u,v,pl):
    C,R,cx,cy=CAMS[photo]; w=ray(u,v,R,f,cx,cy)
    ax,val=plane(pl)
    # room-frame axis/value
    if ax=='X': rax,rval=1,val/h
    elif ax=='Y': rax,rval=0,(Li-val)/h
    else: rax,rval=2,val/h
    P=hit_plane(C,w,rax,rval); return su(P)
def proj(photo,P):
    C,R,cx,cy=CAMS[photo]; q,_=project(np.atleast_2d(room(P)),C,R,f,cx,cy); return q[0]
def show(photo,pts,pl):
    for k,(u,v) in pts.items():
        P=cast(photo,u,v,pl); print(f'  {k:28s} X={P[0]:7.1f} Y={P[1]:7.1f} Z={P[2]:6.1f}')
def tri(uvA, uvB):
    """least-squares intersection of the two photo rays -> SU inches, plus miss distance (in)"""
    CA,RA,cxa,cya=CAMS['A']; CB,RB,cxb,cyb=CAMS['B']
    wa=ray(*uvA,RA,f,cxa,cya); wb=ray(*uvB,RB,f,cxb,cyb)
    A=np.zeros((3,3)); b=np.zeros(3)
    for C,w in ((CA,wa),(CB,wb)):
        P=np.eye(3)-np.outer(w,w); A+=P; b+=P@C
    X=np.linalg.solve(A,b)
    miss=sum(np.linalg.norm((np.eye(3)-np.outer(w,w))@(X-C)) for C,w in ((CA,wa),(CB,wb)))*h/2
    return su(X), miss
def showtri(d):
    for k,(a,b) in d.items():
        P,m=tri(a,b); print(f'  {k:24s} X={P[0]:7.1f} Y={P[1]:7.1f} Z={P[2]:6.1f}   miss {m:4.1f} in')
