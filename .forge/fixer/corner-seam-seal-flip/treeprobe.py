"""Find every instance of a definition whose name matches PATTERN anywhere in a
model, report its world box, and which way its L faces in the world.

'Which way the L faces' is read from the AREA centroid of the part's horizontal
faces (top faces, normal +z): an L's area sits hard in the corner where its legs
meet, a ~0.9 in lean on a 4.875 box, so it cannot be flipped by a few screw-mark
edges the way the edge-endpoint centroid (corner_yaw's input) can.

usage: python -I treeprobe.py model.skp PATTERN"""
import ctypes as C, sys, os, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import skprobe as K
api = K.api

def area_centroid(faces, m):
    ax = ay = at = 0.0
    for f in faces:
        if f["n"][2] < 0.9:  # top faces only (normal +z in definition space)
            continue
        vs = [K.xf(m, v) for v in f["v"]]
        a = cx = cy = 0.0
        for i in range(len(vs)):
            x0, y0 = vs[i][0], vs[i][1]
            x1, y1 = vs[(i + 1) % len(vs)][0], vs[(i + 1) % len(vs)][1]
            cr = x0 * y1 - x1 * y0
            a += cr; cx += (x0 + x1) * cr; cy += (y0 + y1) * cr
        if abs(a) < 1e-9:
            continue
        a /= 2.0; cx /= (6 * a); cy /= (6 * a)
        aa = abs(a)
        ax += cx * aa; ay += cy * aa; at += aa
    return (ax / at, ay / at) if at else None

found = []
def walk(ents, m, path, pat, depth):
    if depth > 10: return
    for g in K.get_list(api.SUEntitiesGetNumGroups, api.SUEntitiesGetGroups, ents):
        t = K.TR(); api.SUGroupGetTransform(g, C.byref(t))
        ge = K.Ref(); api.SUGroupGetEntities(g, C.byref(ge))
        nm = K.su_string(api.SUGroupGetName, g)
        walk(ge, K.mul(m, list(t.v)), path + f"/G[{nm}]", pat, depth + 1)
    for ins in K.get_list(api.SUEntitiesGetNumInstances, api.SUEntitiesGetInstances, ents):
        t = K.TR(); api.SUComponentInstanceGetTransform(ins, C.byref(t))
        d = K.Ref(); api.SUComponentInstanceGetDefinition(ins, C.byref(d))
        dn = K.su_string(api.SUComponentDefinitionGetName, d)
        iname = K.su_string(api.SUComponentInstanceGetName, ins)
        de = K.Ref(); api.SUComponentDefinitionGetEntities(d, C.byref(de))
        mm = K.mul(m, list(t.v))
        if re.search(pat, dn):
            out = {"pts": [], "faces": []}; log = []
            K.walk(de, K.IDENT, out, 0, "", log)
            found.append((path, dn, iname, list(t.v), mm, out))
        else:
            walk(de, mm, path + f"/C[{dn}|{iname}]", pat, depth + 1)

def main():
    api.SUInitialize()
    path, pat = sys.argv[1], sys.argv[2]
    m = K.Ref(); st = C.c_int()
    K.ok(api.SUModelCreateFromFileWithStatus(C.byref(m), path.encode(), C.byref(st)), "open")
    root = K.Ref(); api.SUModelGetEntities(m, C.byref(root))
    walk(root, K.IDENT, "", pat, 0)
    print(f"FILE {path}: {len(found)} instances matching /{pat}/")
    defs_seen = {}
    for (p, dn, iname, lt, mm, out) in found:
        pts = out["pts"]
        if dn not in defs_seen:
            xs=[q[0] for q in pts]; ys=[q[1] for q in pts]
            bx=(min(xs)+max(xs))/2; by=(min(ys)+max(ys))/2
            cx=sum(xs)/len(xs); cy=sum(ys)/len(ys)
            ac = area_centroid(out["faces"], K.IDENT)
            defs_seen[dn] = 1
            print(f"  DEF {dn}: edges={len(pts)//2} faces={len(out['faces'])} box x {min(xs):.4f}..{max(xs):.4f} y {min(ys):.4f}..{max(ys):.4f}"
                  f"  edge-centroid lean ({cx-bx:+.4f},{cy-by:+.4f})  AREA-centroid lean ({ac[0]-bx:+.4f},{ac[1]-by:+.4f})")
        wp = [K.xf(mm, q) for q in pts]
        xs=[q[0] for q in wp]; ys=[q[1] for q in wp]
        bx=(min(xs)+max(xs))/2; by=(min(ys)+max(ys))/2
        ac = area_centroid(out["faces"], mm)
        print(f"   inst '{iname}' in {p[-90:]}")
        print(f"      local T={[round(v,3) for v in lt[:2]+lt[4:6]+lt[12:14]]}  world box x {min(xs):.3f}..{max(xs):.3f} y {min(ys):.3f}..{max(ys):.3f}  L-vertex lean ({ac[0]-bx:+.3f},{ac[1]-by:+.3f})")
    api.SUTerminate()
main()
