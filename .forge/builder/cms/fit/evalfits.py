"""Score fit.json's source (joint6) and final_fit.json on the SAME evidence:
every room-edge pick in both photos against the room box that room.rb builds,
plus the 12 cross-photo tie points triangulated with each fit's cameras frozen."""
import json, numpy as np, sys
sys.path.insert(0,'.')
from cam import project
from lm import lm, line_resid
import joint5 as J
import bundle as B
pA=json.load(open('picksA_room.json')); pB=json.load(open('picksB_room.json'))
MAPA={'ceilB':'B_top','floorB':'B_floor','chairB':'B_chair','chairC1':'C_chair','chairC2':'C_chair','chairA1':'A_chair',
      'ceilC':'C_top','ceilA':'A_top','floorC1':'C_floor','floorC0':'C_floor','vertBC':'BC','vertAB':'AB'}
MAPB={'ceilA1':'A_top','ceilA2':'A_top','ceilB':'B_top','floorB':'B_floor','chairB':'B_chair','chairA1':'A1_chair',
      'chairA2':'A_chair','floorA1':'A1_floor','vertDA':'DA1','vertAB':'AB','vertBC':'BC','floorD':'D_floor'}
def lines(L,W,H,zc,s1):
    d=J.lines3d(L,W,H,zc,s1); d['A_chair']=([0,W,zc],[L,W,zc]); return d
def score(p,s1_override=None):
    L,W,H,zc,f=p[:5]; s1=p[16] if s1_override is None else s1_override
    ln=lines(L,W,H,zc,s1); ca,cb=J.cams(p); res={}
    for picks,mp,(C,R,cx,cy),tag in ((pA,MAPA,ca,'A'),(pB,MAPB,cb,'B')):
        allr=[]
        for k,lab in mp.items():
            a,b=ln[lab]; ab,_=project(np.array([a,b],float),C,R,f,cx,cy)
            r=line_resid(picks[k],ab[0],ab[1]); allr.append(r); res[tag+':'+k]=round(float(np.sqrt(np.mean(r**2))),1)
        allr=np.concatenate(allr); res[tag+'_rms']=round(float(np.sqrt(np.mean(allr**2))),2); res[tag+'_max']=round(float(np.abs(allr).max()),1)
    return res
def ties(p):
    (CA,RA,cxa,cya),(CB,RB,cxb,cyb)=J.cams(p); f=p[4]; errs=[]
    for n in B.names:
        (ua,va),(ub,vb),pl=B.TIES[n]
        X0=np.array(json.load(open('bundle.json'))['ties'][n])
        def r(X):
            qa,_=project(X[None],CA,RA,f,cxa,cya); qb,_=project(X[None],CB,RB,f,cxb,cyb)
            return np.array([qa[0,0]-ua,qa[0,1]-va,qb[0,0]-ub,qb[0,1]-vb])
        X,rr,_=lm(r,X0,iters=100); errs.append(rr)
    e=np.concatenate(errs); return round(float(np.sqrt(np.mean(e**2))),2), round(float(np.abs(e).max()),1)
h_old=json.load(open('../fit.json'))['h_in']; h_new=json.load(open('scale.json'))['h']
for name,fn,h in (('fit.json (joint6)','joint6.json',h_old),('final_fit.json','final_fit.json',h_new)):
    p=np.array(json.load(open(fn))['p'])
    print('==',name,'L W H zc in:',[round(v*h,1) for v in p[:4]],'s1 in',round(p[16]*h,1),'f',round(p[4],1))
    s=score(p); print('  as fitted : A rms',s['A_rms'],'max',s['A_max'],'| B rms',s['B_rms'],'max',s['B_max'])
    s0=score(p,0.0); print('  plain box : A rms',s0['A_rms'],'max',s0['A_max'],'| B rms',s0['B_rms'],'max',s0['B_max'])
    print('  per line (plain box):',{k:v for k,v in s0.items() if ':' in k})
    print('  ties (12 pts, 2 photos, px): rms/max',ties(p))

def ties_on_plane(p):
    (CA,RA,cxa,cya),(CB,RB,cxb,cyb)=J.cams(p); f=p[4]; L,W,H=p[:3]; out={}
    for n in B.names:
        (ua,va),(ub,vb),pl=B.TIES[n]
        ax,val={'B':(0,L),'A':(1,W),'C':(2,H)}[pl]; free=[i for i in range(3) if i!=ax]
        X0=np.array(json.load(open('bundle.json'))['ties'][n]); X0[ax]=val
        def r(q):
            X=np.zeros(3); X[ax]=val; X[free]=q
            qa,_=project(X[None],CA,RA,f,cxa,cya); qb,_=project(X[None],CB,RB,f,cxb,cyb)
            return np.array([qa[0,0]-ua,qa[0,1]-va,qb[0,0]-ub,qb[0,1]-vb])
        q,rr,_=lm(r,X0[free],iters=100); out[n]=round(float(np.sqrt(np.mean(rr**2))),1)
    v=np.array(list(out.values())); return round(float(np.sqrt(np.mean(v**2))),2), out
print()
for name,fn in (('fit.json (joint6)','joint6.json'),('final_fit.json','final_fit.json')):
    p=np.array(json.load(open(fn))['p']); s0=score(p)
    lines_=[v for k,v in s0.items() if ':' in k]
    print('==',name,'median per-line rms px',np.median(lines_),' lines excl. B:vertBC rms-of-rms',round(float(np.sqrt(np.mean([v**2 for k,v in s0.items() if ':' in k and k!='B:vertBC']))),2))
    r,d=ties_on_plane(p); print('   ties on their planes rms',r,d)
