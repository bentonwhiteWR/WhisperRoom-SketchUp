import sys, cv2, numpy as np
P='C:/Users/bento/Documents/Claude/Sketchup/clients/community-music-school/plans/'
def crop(photo, x0,y0,x1,y1, out, step=25, target=1400, clahe=False):
    im=cv2.imread(P+photo)[y0:y1, x0:x1]
    if clahe:
        lab=cv2.cvtColor(im, cv2.COLOR_BGR2LAB)
        c=cv2.createCLAHE(clipLimit=4.0, tileGridSize=(8,8))
        lab[:,:,0]=c.apply(lab[:,:,0]); im=cv2.cvtColor(lab, cv2.COLOR_LAB2BGR)
    sc=min(target/float(x1-x0), 1500/float(y1-y0))
    im=cv2.resize(im, (int((x1-x0)*sc), int((y1-y0)*sc)), interpolation=cv2.INTER_AREA if sc<1 else cv2.INTER_CUBIC)
    for gx in range((x0//step+1)*step, x1, step):
        X=int((gx-x0)*sc); big=gx%(step*4)==0
        cv2.line(im,(X,0),(X,im.shape[0]),(0,0,255) if big else (170,170,255),1)
        if big: cv2.putText(im,str(gx),(X+2,14),cv2.FONT_HERSHEY_SIMPLEX,0.45,(0,0,255),1)
    for gy in range((y0//step+1)*step, y1, step):
        Y=int((gy-y0)*sc); big=gy%(step*4)==0
        cv2.line(im,(0,Y),(im.shape[1],Y),(255,0,0) if big else (255,190,190),1)
        if big: cv2.putText(im,str(gy),(2,Y+14),cv2.FONT_HERSHEY_SIMPLEX,0.45,(255,0,0),1)
    cv2.imwrite(out, im)
if __name__=='__main__':
    a=sys.argv
    crop(a[1], int(a[2]),int(a[3]),int(a[4]),int(a[5]), a[6], int(a[7]), clahe=(len(a)>8 and a[8]=='c'))
