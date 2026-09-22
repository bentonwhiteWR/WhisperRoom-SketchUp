import sys, cv2, numpy as np, json
P='C:/Users/bento/Documents/Claude/Sketchup/clients/community-music-school/plans/'
def tile(im, cx, cy, half, zoom, step, clahe, label):
    h,w=im.shape[:2]
    x0,y0=max(0,cx-half),max(0,cy-half); x1,y1=min(w,cx+half),min(h,cy+half)
    t=im[y0:y1,x0:x1].copy()
    if clahe:
        lab=cv2.cvtColor(t,cv2.COLOR_BGR2LAB); c=cv2.createCLAHE(clipLimit=3.0,tileGridSize=(4,4))
        lab[:,:,0]=c.apply(lab[:,:,0]); t=cv2.cvtColor(lab,cv2.COLOR_LAB2BGR)
    t=cv2.resize(t,None,fx=zoom,fy=zoom,interpolation=cv2.INTER_CUBIC)
    for gx in range((x0//step+1)*step,x1,step):
        X=int((gx-x0)*zoom); big=gx%(step*2)==0
        cv2.line(t,(X,0),(X,t.shape[0]),(0,0,255) if big else (190,190,255),1)
        if big: cv2.putText(t,str(gx),(X+2,12),cv2.FONT_HERSHEY_SIMPLEX,0.4,(0,0,255),1)
    for gy in range((y0//step+1)*step,y1,step):
        Y=int((gy-y0)*zoom); big=gy%(step*2)==0
        cv2.line(t,(0,Y),(t.shape[1],Y),(255,0,0) if big else (255,200,200),1)
        if big: cv2.putText(t,str(gy),(2,Y+12),cv2.FONT_HERSHEY_SIMPLEX,0.4,(255,0,0),1)
    cv2.rectangle(t,(0,t.shape[0]-22),(t.shape[1],t.shape[0]),(0,0,0),-1)
    cv2.putText(t,label,(4,t.shape[0]-6),cv2.FONT_HERSHEY_SIMPLEX,0.5,(255,255,255),1)
    return t
def run(photo, specs, out, cols=3):
    im=cv2.imread(P+photo)
    tiles=[tile(im,*s) for s in specs]
    H=max(t.shape[0] for t in tiles); W=max(t.shape[1] for t in tiles)
    tiles=[cv2.copyMakeBorder(t,0,H-t.shape[0]+4,0,W-t.shape[1]+4,cv2.BORDER_CONSTANT,value=(40,40,40)) for t in tiles]
    rows=[np.hstack(tiles[i:i+cols]+[np.zeros_like(tiles[0])]*(cols-len(tiles[i:i+cols]))) for i in range(0,len(tiles),cols)]
    cv2.imwrite(out,np.vstack(rows))
if __name__=='__main__':
    spec=json.loads(sys.argv[3]); run(sys.argv[1], [tuple(s) for s in spec], sys.argv[2], int(sys.argv[4]) if len(sys.argv)>4 else 3)
