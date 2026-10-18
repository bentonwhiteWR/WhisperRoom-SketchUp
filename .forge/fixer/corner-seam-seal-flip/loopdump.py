"""Dump a part's FULL geometry with face loops kept apart, via SketchUpAPI.dll.

usage: python -I loopdump.py file.skp out.json              (root entities of a part file)
       python -I loopdump.py master.skp out.json NAME        (a named definition in a model)

JSON: {"edges": [[p, q], ...], "faces": [{"n": [x,y,z], "loops": [{"outer": bool, "v": [[x,y,z],...]}]}]}
Nested groups/instances are flattened with their transforms (none expected in a seal).
"""
import ctypes as C, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import skprobe as K
api = K.api


def loop_pts(lp, m):
    n = C.c_size_t()
    api.SULoopGetNumVertices(lp, C.byref(n))
    arr = (K.Ref * max(n.value, 1))()
    got = C.c_size_t()
    api.SULoopGetVertices(lp, n.value, arr, C.byref(got))
    return [K.xf(m, K.vpos(arr[i])) for i in range(got.value)]


def walk(ents, m, out, depth=0):
    for e in K.get_list(api.SUEntitiesGetNumEdges, api.SUEntitiesGetEdges, ents, C.c_bool(False)):
        a = K.Ref(); b = K.Ref()
        api.SUEdgeGetStartVertex(e, C.byref(a)); api.SUEdgeGetEndVertex(e, C.byref(b))
        out["edges"].append([K.xf(m, K.vpos(a)), K.xf(m, K.vpos(b))])
    for f in K.get_list(api.SUEntitiesGetNumFaces, api.SUEntitiesGetFaces, ents):
        nrm = K.V3(); api.SUFaceGetNormal(f, C.byref(nrm))
        lp = K.Ref(); K.ok(api.SUFaceGetOuterLoop(f, C.byref(lp)), "outer loop")
        loops = [{"outer": True, "v": loop_pts(lp, m)}]
        for il in K.get_list(api.SUFaceGetNumInnerLoops, api.SUFaceGetInnerLoops, f):
            loops.append({"outer": False, "v": loop_pts(il, m)})
        out["faces"].append({"n": [nrm.x, nrm.y, nrm.z], "loops": loops})
    if depth > 8:
        return
    for g in K.get_list(api.SUEntitiesGetNumGroups, api.SUEntitiesGetGroups, ents):
        t = K.TR(); api.SUGroupGetTransform(g, C.byref(t))
        ge = K.Ref(); api.SUGroupGetEntities(g, C.byref(ge))
        out["nested"] += 1
        walk(ge, K.mul(m, list(t.v)), out, depth + 1)
    for ins in K.get_list(api.SUEntitiesGetNumInstances, api.SUEntitiesGetInstances, ents):
        t = K.TR(); api.SUComponentInstanceGetTransform(ins, C.byref(t))
        d = K.Ref(); api.SUComponentInstanceGetDefinition(ins, C.byref(d))
        de = K.Ref(); api.SUComponentDefinitionGetEntities(d, C.byref(de))
        out["nested"] += 1
        walk(de, K.mul(m, list(t.v)), out, depth + 1)


def main():
    api.SUInitialize()
    path, dst = sys.argv[1], sys.argv[2]
    name = sys.argv[3] if len(sys.argv) > 3 else None
    m = K.Ref(); st = C.c_int()
    K.ok(api.SUModelCreateFromFileWithStatus(C.byref(m), path.encode(), C.byref(st)), "open")
    if name is None:
        ents = K.Ref(); api.SUModelGetEntities(m, C.byref(ents))
    else:
        byname = {K.su_string(api.SUComponentDefinitionGetName, d): d
                  for d in K.get_list(api.SUModelGetNumComponentDefinitions,
                                      api.SUModelGetComponentDefinitions, m)}
        ents = K.Ref(); api.SUComponentDefinitionGetEntities(byname[name], C.byref(ents))
    out = {"edges": [], "faces": [], "nested": 0, "src": path, "name": name}
    walk(ents, K.IDENT, out)
    holes = sum(len(f["loops"]) - 1 for f in out["faces"])
    print(f"{os.path.basename(path)} {name or '<root>'}: edges={len(out['edges'])} faces={len(out['faces'])} "
          f"inner loops={holes} nested={out['nested']}")
    json.dump(out, open(dst, "w"))
    api.SUTerminate()


main()
