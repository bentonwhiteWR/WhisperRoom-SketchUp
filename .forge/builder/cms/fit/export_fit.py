"""Room fit -> SketchUp frame. Room frame: x D->B, y C->A, z up (units of camera-A height).
SketchUp frame (inches): X = y*h (C west at X=0, A east at X=W), Y = L - x*h (D north at Y=L, B south at Y=0)."""
import json, numpy as np, sys
sys.path.insert(0,'.')
from cam import rot
import joint5 as J
p=np.array(json.load(open(sys.argv[1] if len(sys.argv)>1 else 'joint6.json'))['p'])
h=json.load(open(sys.argv[2] if len(sys.argv)>2 else 'scale.json'))['h']
L,W,H,zc,f=p[:5]; Li=L*h
def P(v): return [float(v[1]*h), float(Li - v[0]*h), float(v[2]*h)]
def V(v): return [float(v[1]), float(-v[0]), float(v[2])]
def camd(C,R,w,hh):
    fwd=R[2]; up=-R[1]
    eye=P(C); tgt=[eye[i]+120*V(fwd)[i] for i in range(3)]
    return {'eye':eye,'target':tgt,'up':V(up),'f_px':float(f),'img':[w,hh],
            'fov_v':float(np.degrees(2*np.arctan(hh/2/f))),'fov_h':float(np.degrees(2*np.arctan(w/2/f)))}
(CA,RA,_,_),(CB,RB,_,_)=J.cams(p)
out={'h_in':h,'L':float(Li),'W':float(W*h),'H':float(H*h),'zc':float(zc*h),'frame':'SU X=room y, Y=L-room x',
     'camA':camd(CA,RA,3024,4032),'camB':camd(CB,RB,4032,3024)}
json.dump(out,open('C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/builder/cms/fit.json','w'),indent=1)
print(json.dumps({k:(round(v,2) if isinstance(v,float) else v) for k,v in out.items() if not k.startswith('cam')}))
for k in ('camA','camB'): print(k,'eye',np.round(out[k]['eye'],1).tolist(),'tgt',np.round(out[k]['target'],1).tolist(),'fov_v',round(out[k]['fov_v'],2))
