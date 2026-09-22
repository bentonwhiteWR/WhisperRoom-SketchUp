"""Side-by-side + blended overlay of a SketchUp shot against its photo."""
import sys, cv2, numpy as np
PH='C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/clients/community-music-school/plans/'
def compare(photo, shot, out, label=''):
    a=cv2.imread(PH+photo); b=cv2.imread(shot)
    b=cv2.resize(b,(int(a.shape[1]*b.shape[0]/a.shape[0]) if False else b.shape[1], b.shape[0]))
    a=cv2.resize(a,(b.shape[1],b.shape[0]),interpolation=cv2.INTER_AREA)
    # overlay: photo in grey + shot edges in magenta
    g=cv2.cvtColor(cv2.cvtColor(a,cv2.COLOR_BGR2GRAY),cv2.COLOR_GRAY2BGR)
    e=cv2.Canny(cv2.cvtColor(b,cv2.COLOR_BGR2GRAY),40,120)
    ov=g.copy(); ov[e>0]=(255,0,255)
    row=np.hstack([a,b,ov])
    if label:
        cv2.rectangle(row,(0,0),(row.shape[1],28),(0,0,0),-1)
        cv2.putText(row,label,(8,20),cv2.FONT_HERSHEY_SIMPLEX,0.6,(255,255,255),1)
    cv2.imwrite(out,row)
if __name__=='__main__':
    compare(sys.argv[1],sys.argv[2],sys.argv[3],sys.argv[4] if len(sys.argv)>4 else '')
