import json, numpy as np, sys, cv2
sys.path.insert(0,'.')
from cam import rot, project
PH='C:/Users/bento/Documents/Claude/Sketchup/clients/community-music-school/plans/'
def draw(photo, segs, C, R, f, cx, cy, out, scale=0.5, color=(0,255,255)):
    im=cv2.imread(PH+photo)
    for s in segs:
        a,b=np.array(s[0],float),np.array(s[1],float); col=s[2] if len(s)>2 else color
        t=np.linspace(0,1,80)[:,None]; P=a*(1-t)+b*t
        Xc=(P-C)@R.T; P=P[Xc[:,2]>0.05]
        if len(P)<2: continue
        q,_=project(P,C,R,f,cx,cy)
        q=q[(np.abs(q[:,0])<20000)&(np.abs(q[:,1])<20000)]
        cv2.polylines(im,[q.astype(np.int32).reshape(-1,1,2)],False,col,4,cv2.LINE_AA)
    cv2.imwrite(out, cv2.resize(im,None,fx=scale,fy=scale,interpolation=cv2.INTER_AREA))
def box(L,W,H):
    c=[[0,0,0],[L,0,0],[L,W,0],[0,W,0]]
    segs=[]
    for i in range(4):
        a=c[i]; b=c[(i+1)%4]
        segs.append((a,b,(0,255,255))); segs.append(([a[0],a[1],H],[b[0],b[1],H],(0,255,255))); segs.append((a,[a[0],a[1],H],(0,255,255)))
    return segs
