"""Textures for the CMS room: carpet fleck tile (colours from photo A's carpet), and
window backdrops = photo B's view through each window, mullions inpainted, unwarped."""
import cv2, numpy as np
PH='C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/clients/community-music-school/plans/'
OUT='C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/builder/cms/tex/'
B=cv2.imread(PH+'photo-B-corner-view.jpg')
def backdrop(quad, size, name):
    g=cv2.cvtColor(B,cv2.COLOR_BGR2GRAY)
    bh=cv2.morphologyEx(g,cv2.MORPH_BLACKHAT,cv2.getStructuringElement(cv2.MORPH_RECT,(71,71)))
    m=((bh>28)&(g<150)).astype(np.uint8)*255
    m=cv2.dilate(m,np.ones((5,5),np.uint8))
    x0,y0=np.min(quad,0).astype(int)-40; x1,y1=np.max(quad,0).astype(int)+40
    sub=B[y0:y1,x0:x1].copy(); ms=m[y0:y1,x0:x1]
    inp=cv2.inpaint(sub,ms,9,cv2.INPAINT_TELEA)
    q=(np.float32(quad)-np.float32([x0,y0])).astype(np.float32); w,h=size
    H=cv2.getPerspectiveTransform(q,np.float32([[0,0],[w,0],[w,h],[0,h]]))
    out=cv2.warpPerspective(inp,H,(w,h),flags=cv2.INTER_CUBIC,borderMode=cv2.BORDER_REPLICATE)
    out=cv2.GaussianBlur(out,(0,0),1.2)
    cv2.imwrite(OUT+name,out); print(name,out.shape)
# glass quads in photo B (TL, TR, BR, BL), full-res px, read from gridded crops c3/c4
backdrop([(796,634),(1409,745),(1446,1400),(903,1441)],(520,680),'backdrop-w1.jpg')
backdrop([(2021,857),(2221,900),(2218,1343),(2021,1350)],(520,680),'backdrop-w2.jpg')
# carpet: blue-gray loop with light fleck (photo A carpet median 98,102,109; p10 71,73,79; p90 158,161,169)
rng=np.random.default_rng(7); n=512
base=np.array([116,106,96],np.float32)  # BGR, lifted from the photo median to a reflectance
img=np.ones((n,n,3),np.float32)*base
img+=cv2.GaussianBlur(rng.normal(0,14,(n,n,1)).astype(np.float32),(0,0),0.8)[...,None] if False else cv2.GaussianBlur(rng.normal(0,14,(n,n)).astype(np.float32),(0,0),0.8)[...,None]
# loop rows
yy=np.arange(n)[:,None]; img+=((np.sin(yy*np.pi/3.0)*6)[...,None]).astype(np.float32)
fl=rng.random((n,n))<0.035; img[fl]=[205,198,190]
dk=rng.random((n,n))<0.05; img[dk]=[70,64,58]
img=cv2.GaussianBlur(np.clip(img,0,255),(0,0),0.6)
cv2.imwrite(OUT+'carpet-fleck.png',img.astype(np.uint8)); print('carpet ok')
