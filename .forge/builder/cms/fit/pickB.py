import json, cv2, numpy as np, sys
sys.path.insert(0,'.')
from refine import refine, P
B='photo-B-corner-view.jpg'
rough={
 'ceilA1': ((150,130),(1650,560),'dark',50),
 'ceilA2': ((1900,610),(2380,780),'dark',40),
 'ceilB':  ((3480,545),(3990,455),'dark',40),
 'floorB': ((2620,1530),(3830,1735),'edge',25),
 'chairB': ((3360,1182),(3990,1190),'dark',15),
 'chairA1':((290,1190),(850,1193),'dark',15),
 'chairA2':((1500,1193),(1680,1193),'dark',12),
 'floorA1':((420,1880),(930,1778),'edge',25),
 'vertDA': ((380,1860),(90,200),'edge',40),
 'vertAB': ((2408,790),(2400,990),'edge',25),
 'vertBC': ((3880,1700),(3975,480),'edge',40),
 'floorD': ((395,2050),(320,2900),'edge',40),
}
out={}
vis=cv2.imread(P+B)
for k,(p1,p2,mode,hw) in rough.items():
    pts,rms=refine(B,p1,p2,mode,hw)
    out[k]=pts.round(1).tolist()
    print(k, len(pts), 'rms', round(rms,2), 'ends', pts[0].round(0).tolist(), pts[-1].round(0).tolist())
    for p in pts: cv2.circle(vis,(int(p[0]),int(p[1])),7,(0,0,255),-1)
    cv2.line(vis,tuple(map(int,p1)),tuple(map(int,p2)),(0,255,0),2)
json.dump(out,open('picksB_room.json','w'))
cv2.imwrite('pickB_vis.png',cv2.resize(vis,None,fx=0.5,fy=0.5,interpolation=cv2.INTER_AREA))
