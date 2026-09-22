import numpy as np
F0=1631.0
def rot(yaw,pitch,roll):
    """World: x toward Wall B, y toward Wall A, z up. Camera: x right, y down, z forward.
    yaw = heading from +x toward +y (left), pitch = down positive, roll = clockwise positive."""
    cy,sy=np.cos(yaw),np.sin(yaw); cp,sp=np.cos(pitch),np.sin(pitch); cr,sr=np.cos(roll),np.sin(roll)
    fwd=np.array([cp*cy, cp*sy, -sp])
    right0=np.array([sy,-cy,0.0])              # horizontal right
    down0=np.cross(fwd,right0)                  # completes right-handed (x right, y down, z fwd)
    right= cr*right0 + sr*down0
    down = -sr*right0 + cr*down0
    return np.vstack([right,down,fwd])
def project(Xw,C,R,f,cx,cy):
    Xc=(np.atleast_2d(Xw)-C)@R.T
    return np.c_[cx+f*Xc[:,0]/Xc[:,2], cy+f*Xc[:,1]/Xc[:,2]], Xc[:,2]
def ray(u,v,R,f,cx,cy):
    d=np.array([(u-cx)/f,(v-cy)/f,1.0]); w=R.T@d; return w/np.linalg.norm(w)
def hit_plane(C,w,axis,val):
    t=(val-C[axis])/w[axis]; return C+t*w
