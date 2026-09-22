"""Side-by-side of a SketchUp photo-match shot against its client photo, with a
MEASURED overlay error: each photo pick (room edges, and feature ties) is scored by
its distance to the nearest edge in the rendered shot.  Errors are in full-res photo px.
  python sbs.py A shot.png out.png "label"      -> prints json of errors"""
import sys, json, cv2, numpy as np
sys.path.insert(0,'.')
PH='C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/clients/community-music-school/plans/'
PHOTO={'A':'photo-A-long-view.jpg','B':'photo-B-corner-view.jpg'}
import bundle as B
def measure(key, shot, extra=None):
    ph=cv2.imread(PH+PHOTO[key]); sh=cv2.imread(shot)
    s=sh.shape[1]/ph.shape[1]
    e=cv2.Canny(cv2.cvtColor(sh,cv2.COLOR_BGR2GRAY),30,90)
    dt=cv2.distanceTransform((e==0).astype(np.uint8),cv2.DIST_L2,5)
    picks=json.load(open(f'picks{key}_room.json'))
    if extra: picks.update(extra)
    res={}
    for k,pts in picks.items():
        d=[]
        for u,v in pts:
            x,y=int(round(u*s)),int(round(v*s))
            if 0<=x<dt.shape[1] and 0<=y<dt.shape[0]: d.append(dt[y,x]/s)
        if d: res[k]=round(float(np.sqrt(np.mean(np.square(d)))),1)
    return res, e, ph, sh, s
def ties_for(key):
    i=0 if key=='A' else 1
    return {'tie:'+n:[B.TIES[n][i]] for n in B.TIES}
def sbs(key, shot, out, label=''):
    lines,e,ph,sh,s=measure(key,shot)
    ties,_,_,_,_=measure(key,shot,None) if False else (None,)*5
    tr,_,_,_,_=measure(key,shot,ties_for(key)); tr={k:v for k,v in tr.items() if k.startswith('tie:')}
    a=cv2.resize(ph,(sh.shape[1],sh.shape[0]),interpolation=cv2.INTER_AREA)
    g=cv2.cvtColor(cv2.cvtColor(a,cv2.COLOR_BGR2GRAY),cv2.COLOR_GRAY2BGR)
    ov=(g*0.85).astype(np.uint8); ov[cv2.dilate(e,np.ones((2,2),np.uint8))>0]=(255,0,255)
    row=np.hstack([a,sh,ov])
    lr=np.sqrt(np.mean(np.square(list(lines.values())))); tt=np.sqrt(np.mean(np.square(list(tr.values()))))
    txt=f'{label}   photo | SketchUp | overlay (magenta = model edges)   room-edge err {lr:.1f}px  feature err {tt:.1f}px (full-res photo px)'
    bh=int(40*sh.shape[0]/1512)
    cv2.rectangle(row,(0,0),(row.shape[1],bh),(0,0,0),-1)
    cv2.putText(row,txt,(10,int(bh*0.7)),cv2.FONT_HERSHEY_SIMPLEX,0.8*sh.shape[0]/1512,(255,255,255),2)
    cv2.imwrite(out,row)
    return {'lines_rms':round(float(lr),2),'lines_med':float(np.median(list(lines.values()))),'ties_rms':round(float(tt),2),'lines':lines,'ties':tr}
if __name__=='__main__':
    r=sbs(sys.argv[1],sys.argv[2],sys.argv[3],sys.argv[4] if len(sys.argv)>4 else '')
    print(json.dumps(r))
