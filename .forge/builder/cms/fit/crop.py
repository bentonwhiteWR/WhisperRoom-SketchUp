"""crop.py A|B x0 y0 x1 y1 out.jpg [step]  -> gridded crop, full-res photo px labels"""
import sys, cv2
PH='C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/clients/community-music-school/plans/'
k,x0,y0,x1,y1,out=sys.argv[1],*map(int,sys.argv[2:6]),sys.argv[6]; step=int(sys.argv[7]) if len(sys.argv)>7 else 50
im=cv2.imread(PH+{'A':'photo-A-long-view.jpg','B':'photo-B-corner-view.jpg'}[k])[y0:y1,x0:x1]
z=min(1400/(x1-x0),1400/(y1-y0),3.0); t=cv2.resize(im,None,fx=z,fy=z,interpolation=cv2.INTER_CUBIC)
for gx in range((x0//step+1)*step,x1,step):
    X=int((gx-x0)*z); big=gx%(step*2)==0; cv2.line(t,(X,0),(X,t.shape[0]),(0,0,255) if big else (160,160,255),1)
    if big: cv2.putText(t,str(gx),(X+2,14),cv2.FONT_HERSHEY_SIMPLEX,0.45,(0,0,255),1)
for gy in range((y0//step+1)*step,y1,step):
    Y=int((gy-y0)*z); big=gy%(step*2)==0; cv2.line(t,(0,Y),(t.shape[1],Y),(255,0,0) if big else (255,190,190),1)
    if big: cv2.putText(t,str(gy),(2,Y+14),cv2.FONT_HERSHEY_SIMPLEX,0.45,(255,0,0),1)
cv2.imwrite(out,t)
