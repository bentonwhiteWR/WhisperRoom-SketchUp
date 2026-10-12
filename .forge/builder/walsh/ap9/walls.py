# Shared wall model (booth-local inches, wall-local 2D: s along the wall, z up). Observed values from ap9 survey.
G=0.5            # min gap piece-piece and piece-keepout
ZMIN, ZMAX = 3.25, 79.75   # 0.5 above the EFP top (2.75), 0.5 below the tile (80.25)
WALLS={
 'S':{'s':(16.88,153.19), 'K':[
    ('cover lo S0',16.88,28.75,2.75,17.57),('cover lo S1',60.16,72.04,2.75,17.57),('cover lo S3',132.16,144.04,2.75,17.57),
    ('cover hi S0',25.91,37.79,65.43,80.25),('cover hi S1',73.91,85.79,65.43,80.25),('cover hi S3',141.31,153.19,65.43,80.25),
    ('beam 1',48.25,49.75,76.25,79.25),('beam 2',96.25,97.75,76.25,79.25),('beam 3',120.25,121.75,76.25,79.25),
    ('seal 1',45.75,52.25,79.25,81.0),('seal 2',93.75,100.25,79.25,81.0),('seal 3',117.75,124.25,79.25,81.0)]},
 'E':{'s':(16.88,92.5), 'K':[]},
 'W':{'s':(16.88,92.0), 'K':[('cover hi W0',16.88,28.75,65.43,80.25),('cover lo W0',25.96,37.84,2.75,17.57)]},
 'N':{'s':(6.88,120.75), 'K':[
    ('window N0',7.5,42.5,37.2,76.1),('window N1',55.5,90.5,37.2,76.1),
    ('beam 1',48.25,49.75,76.25,79.25),('beam 2',96.25,97.75,76.25,79.25),('beam 3',120.25,121.75,76.25,79.25),
    ('seal 1',45.75,52.25,79.25,81.0),('seal 2',93.75,100.25,79.25,81.0),('seal 3',117.75,124.25,79.25,81.0)]},
}
# trap boxes per wall in wall-local (for drawing): S both ends, E/W back end
TRAPS={'S':[(4.38,16.38),(153.69,165.69)],'E':[(4.38,16.38)],'W':[(4.38,16.38)],'N':[]}
TRAPZ=[(2.75,26.75),(29.5,53.5),(56.25,80.25)]
# piece kinds: name -> (w, h, count-key)
KINDS={'Bv':(24,48,'B'),'Bh':(48,24,'B'),'Q':(24,24,'Q'),'F4v':(12,48,'F4'),'F4h':(48,12,'F4'),'Hh':(24,12,'H'),'Hv':(12,24,'H')}
def free_z(wall,s0,s1,zmin=ZMIN,zmax=ZMAX):
    """free z intervals for a block spanning s0..s1 (keep-outs within G in s block it)."""
    bl=[]
    for k in WALLS[wall]['K']:
        _,a,b,c,d=k
        if s1 > a-G+1e-9 and s0 < b+G-1e-9:
            bl.append((c-G,d+G))
    bl.sort(); iv=[]; cur=zmin
    for c,d in bl:
        if c>cur+1e-9: iv.append((cur,min(c,zmax)))
        cur=max(cur,d)
        if cur>=zmax: break
    if cur<zmax-1e-9: iv.append((cur,zmax))
    return [(a,b) for a,b in iv if b-a>1e-6]
def gap(a,b):
    return max(b[0]-a[1],a[0]-b[1],b[2]-a[3],a[2]-b[3])
