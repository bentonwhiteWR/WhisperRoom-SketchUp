import json, cv2, numpy as np, sys
sys.path.insert(0,'.')
from refine import refine, P
A='photo-A-long-view.jpg'
rough={
 'ceilB':  ((760,1128),(1930,1170),'dark',30),
 'floorB': ((1100,2000),(1900,2000),'edge',20),
 'chairB': ((1680,1636),(1920,1640),'dark',15),
 'chairC1':((2030,1640),(2190,1650),'dark',15),
 'chairC2':((2560,1650),(3000,1662),'dark',15),
 'chairA1':((0,1610),(300,1612),'dark',15),
 'ceilC':  ((2100,1099),(2900,435),'edge',40),
 'ceilA':  ((100,700),(690,1110),'dark',60),
 'floorC1':((2500,2470),(3000,2850),'edge',30),
 'floorC0':((1960,2010),(2140,2160),'edge',20),
 'vertBC': ((1940,1985),(2025,1180),'edge',25),
 'vertAB': ((702,1130),(740,1580),'dark',25),
}
out={}
vis=cv2.imread(P+A)
for k,(p1,p2,mode,hw) in rough.items():
    pts,rms=refine(A,p1,p2,mode,hw)
    out[k]=pts.round(1).tolist()
    print(k, len(pts), 'rms', round(rms,2), 'ends', pts[0].round(0).tolist(), pts[-1].round(0).tolist())
    for p in pts: cv2.circle(vis,(int(p[0]),int(p[1])),6,(0,0,255),-1)
    cv2.line(vis,tuple(map(int,p1)),tuple(map(int,p2)),(0,255,0),1)
json.dump(out,open('picksA_room.json','w'))
cv2.imwrite('pickA_vis.png',cv2.resize(vis,None,fx=0.5,fy=0.5,interpolation=cv2.INTER_AREA))
