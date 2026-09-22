import sys, cv2, numpy as np, json
P='C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/clients/community-music-school/plans/'
photo, out, minlen = sys.argv[1], sys.argv[2], float(sys.argv[3])
im=cv2.imread(P+photo); g=cv2.cvtColor(im, cv2.COLOR_BGR2GRAY)
g=cv2.GaussianBlur(g,(5,5),1.5)
try:
    lsd=cv2.createLineSegmentDetector(cv2.LSD_REFINE_STD)
    lines=lsd.detect(g)[0].reshape(-1,4)
except Exception as e:
    print('LSD failed', e)
    ed=cv2.Canny(g,30,90)
    lines=cv2.HoughLinesP(ed,1,np.pi/720,80,minLineLength=minlen,maxLineGap=6).reshape(-1,4).astype(float)
L=np.hypot(lines[:,2]-lines[:,0], lines[:,3]-lines[:,1])
keep=lines[L>=minlen]
print(len(lines), 'segments;', len(keep), 'long')
vis=(im*0.6).astype(np.uint8)
res=[]
for i,(x1,y1,x2,y2) in enumerate(keep):
    c=tuple(int(v) for v in np.random.RandomState(i).randint(80,255,3))
    cv2.line(vis,(int(x1),int(y1)),(int(x2),int(y2)),c,4)
    mx,my=int((x1+x2)/2),int((y1+y2)/2)
    cv2.putText(vis,str(i),(mx+4,my-4),cv2.FONT_HERSHEY_SIMPLEX,1.3,(255,255,255),5)
    cv2.putText(vis,str(i),(mx+4,my-4),cv2.FONT_HERSHEY_SIMPLEX,1.3,c,2)
    res.append([i]+[round(float(v),1) for v in (x1,y1,x2,y2)])
cv2.imwrite(out, vis)
json.dump(res, open(out.replace('.png','.json'),'w'))
