"""Read a .skp with SketchUp 2026's own SketchUpAPI.dll (C SDK) via ctypes.

Dumps, for the model root entities (what definitions.load turns into the
definition): bounding box, edge-endpoint centroid (the exact point set
build-booth-components.rb collect_points uses), face count, nested
groups/instances with transforms, and the model axes transform.

usage: python -I skprobe.py file.skp [--faces] [--json out.json]
"""
import ctypes as C
import json
import os
import sys

SU_DIR = r"C:\Program Files\SketchUp\SketchUp 2026\SketchUp"
os.add_dll_directory(SU_DIR)
api = C.CDLL(os.path.join(SU_DIR, "SketchUpAPI.dll"))


class Ref(C.Structure):
    _fields_ = [("ptr", C.c_void_p)]


class P3(C.Structure):
    _fields_ = [("x", C.c_double), ("y", C.c_double), ("z", C.c_double)]


class V3(C.Structure):
    _fields_ = [("x", C.c_double), ("y", C.c_double), ("z", C.c_double)]


class BB(C.Structure):
    _fields_ = [("min", P3), ("max", P3)]


class TR(C.Structure):
    _fields_ = [("v", C.c_double * 16)]


def ok(r, what):
    if r != 0:
        raise RuntimeError(f"{what} -> SUResult {r}")


def su_string(fn, ref):
    s = Ref()
    ok(api.SUStringCreate(C.byref(s)), "SUStringCreate")
    ok(fn(ref, C.byref(s)), "get string")
    n = C.c_size_t()
    api.SUStringGetUTF8Length(s, C.byref(n))
    buf = C.create_string_buffer(n.value + 1)
    got = C.c_size_t()
    api.SUStringGetUTF8(s, n.value + 1, buf, C.byref(got))
    api.SUStringRelease(C.byref(s))
    return buf.value.decode("utf-8", "replace")


def mat(t):
    # column-major 4x4
    return [list(t.v[0:4]), list(t.v[4:8]), list(t.v[8:12]), list(t.v[12:16])]


def mul(a, b):
    # a, b: column-major as list of 16; return a*b
    r = [0.0] * 16
    for col in range(4):
        for row in range(4):
            r[col * 4 + row] = sum(a[k * 4 + row] * b[col * 4 + k] for k in range(4))
    return r


IDENT = [1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0]


def xf(m, p):
    x, y, z = p
    w = m[3] * x + m[7] * y + m[11] * z + m[15]
    return ((m[0] * x + m[4] * y + m[8] * z + m[12]) / w,
            (m[1] * x + m[5] * y + m[9] * z + m[13]) / w,
            (m[2] * x + m[6] * y + m[10] * z + m[14]) / w)


def get_list(numfn, getfn, ents, extra=None):
    n = C.c_size_t()
    if extra is None:
        ok(numfn(ents, C.byref(n)), "num")
    else:
        ok(numfn(ents, extra, C.byref(n)), "num")
    arr = (Ref * max(n.value, 1))()
    got = C.c_size_t()
    if n.value:
        if extra is None:
            ok(getfn(ents, n.value, arr, C.byref(got)), "get")
        else:
            ok(getfn(ents, extra, n.value, arr, C.byref(got)), "get")
    return [arr[i] for i in range(got.value)]


def vpos(vref):
    p = P3()
    ok(api.SUVertexGetPosition(vref, C.byref(p)), "vpos")
    return (p.x, p.y, p.z)


def walk(ents, m, out, depth, path, log):
    edges = get_list(api.SUEntitiesGetNumEdges, api.SUEntitiesGetEdges, ents, C.c_bool(False))
    for e in edges:
        a = Ref(); b = Ref()
        api.SUEdgeGetStartVertex(e, C.byref(a))
        api.SUEdgeGetEndVertex(e, C.byref(b))
        out["pts"].append(xf(m, vpos(a)))
        out["pts"].append(xf(m, vpos(b)))
    faces = get_list(api.SUEntitiesGetNumFaces, api.SUEntitiesGetFaces, ents)
    for f in faces:
        nv = C.c_size_t()
        api.SUFaceGetNumVertices(f, C.byref(nv))
        arr = (Ref * max(nv.value, 1))()
        got = C.c_size_t()
        api.SUFaceGetVertices(f, nv.value, arr, C.byref(got))
        vs = [xf(m, vpos(arr[i])) for i in range(got.value)]
        nrm = V3()
        api.SUFaceGetNormal(f, C.byref(nrm))
        area = C.c_double()
        api.SUFaceGetArea(f, C.byref(area))
        out["faces"].append({"v": vs, "n": (nrm.x, nrm.y, nrm.z), "area": area.value, "depth": depth, "path": path})
    log.append(f"{'  '*depth}{path or '<root>'}: edges={len(edges)} faces={len(faces)}")
    if depth > 8:
        return
    groups = get_list(api.SUEntitiesGetNumGroups, api.SUEntitiesGetGroups, ents)
    for g in groups:
        t = TR()
        api.SUGroupGetTransform(g, C.byref(t))
        ge = Ref()
        api.SUGroupGetEntities(g, C.byref(ge))
        nm = su_string(api.SUGroupGetName, g)
        log.append(f"{'  '*depth} group '{nm}' T={[round(x,4) for x in t.v]}")
        walk(ge, mul(m, list(t.v)), out, depth + 1, path + f"/G[{nm}]", log)
    insts = get_list(api.SUEntitiesGetNumInstances, api.SUEntitiesGetInstances, ents)
    for ins in insts:
        t = TR()
        api.SUComponentInstanceGetTransform(ins, C.byref(t))
        d = Ref()
        api.SUComponentInstanceGetDefinition(ins, C.byref(d))
        de = Ref()
        api.SUComponentDefinitionGetEntities(d, C.byref(de))
        dn = su_string(api.SUComponentDefinitionGetName, d)
        log.append(f"{'  '*depth} inst of '{dn}' T={[round(x,4) for x in t.v]}")
        walk(de, mul(m, list(t.v)), out, depth + 1, path + f"/C[{dn}]", log)


def probe(path):
    m = Ref()
    st = C.c_int()
    r = api.SUModelCreateFromFileWithStatus(C.byref(m), path.encode("utf-8"), C.byref(st))
    ok(r, f"open {path}")
    root = Ref()
    ok(api.SUModelGetEntities(m, C.byref(root)), "entities")
    out = {"pts": [], "faces": []}
    log = []
    walk(root, IDENT, out, 0, "", log)
    # model axes
    axes = Ref()
    axt = None
    if api.SUModelGetAxes(m, C.byref(axes)) == 0:
        t = TR()
        if api.SUAxesGetTransform(axes, C.byref(t)) == 0:
            axt = list(t.v)
    # definitions in the file
    defs = get_list(api.SUModelGetNumComponentDefinitions, api.SUModelGetComponentDefinitions, m)
    dnames = [su_string(api.SUComponentDefinitionGetName, d) for d in defs]
    name = su_string(api.SUModelGetName, m)
    # bbox of root entities via API
    bb = BB()
    rb = api.SUEntitiesGetBoundingBox(root, C.byref(bb))
    api.SUModelRelease(C.byref(m))
    return out, log, axt, dnames, name, (rb, (bb.min.x, bb.min.y, bb.min.z, bb.max.x, bb.max.y, bb.max.z))


def main():
    api.SUInitialize()
    path = sys.argv[1]
    out, log, axt, dnames, name, bb = probe(path)
    pts = out["pts"]
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]; zs = [p[2] for p in pts]
    print(f"FILE {path}")
    print(f" model name '{name}'  defs in file: {dnames}")
    print(f" axes transform: {None if axt is None else [round(x,4) for x in axt]}")
    print(f" API root bbox (rc {bb[0]}): {[round(x,4) for x in bb[1]]}")
    print("\n".join(" " + l for l in log))
    if pts:
        cx = sum(xs) / len(xs); cy = sum(ys) / len(ys); cz = sum(zs) / len(zs)
        print(f" edge-endpoint pts={len(pts)}")
        print(f" box x {min(xs):.4f}..{max(xs):.4f}  y {min(ys):.4f}..{max(ys):.4f}  z {min(zs):.4f}..{max(zs):.4f}")
        bx = (min(xs) + max(xs)) / 2; by = (min(ys) + max(ys)) / 2
        print(f" box centre ({bx:.4f}, {by:.4f})   endpoint centroid ({cx:.4f}, {cy:.4f}, {cz:.4f})  lean ({cx-bx:+.4f}, {cy-by:+.4f})")
    if "--json" in sys.argv:
        jp = sys.argv[sys.argv.index("--json") + 1]
        with open(jp, "w") as f:
            json.dump(out, f)
    api.SUTerminate()


if __name__ == "__main__":
    main()
