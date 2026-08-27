#!/usr/bin/env python
r"""Verify iep_vent_yaw() against an INDEPENDENT witness.

INDEPENDENT WITNESS -- named, per the harness rule:
  1. P:\Sketchup\NewMasterComponentList\_component-probe.tsv  (measured x/y/z
     of every .skp, written by scripts/probe-components.rb inside SketchUp).
     This is a MEASUREMENT of the component files. It is not derived from
     build-booth-components.rb and does not know the yaw rule exists.
  2. scripts/wr-booth-data.rb -- the generated layout table (inner VNT slot
     polygons). Also not derived from the placement code.

This harness re-implements classify()+rotation()'s parity from (1) and the
component naming from guess_component()'s rule, then prints the turn each of
the 25 E layouts' inner vents would get, non-HX and HX. It then checks that
against Benton's five in-SketchUp reports, which are transcribed here as data.

Usage:  python .forge/fixer/verify-vent-yaw.py [path-to-tsv]
"""
import re, sys, os, collections

TSV = sys.argv[1] if len(sys.argv) > 1 else r"P:\Sketchup\NewMasterComponentList\_component-probe.tsv"
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = os.path.join(ROOT, "scripts", "wr-booth-data.rb")

EVEN = {(0,1,2),(1,2,0),(2,0,1)}

def classify(e, want):
    """Port of build-booth-components.rb classify(): hi = axis nearest `want`,
    then wi = larger of the rest, ti = smaller."""
    hi = min(range(3), key=lambda i: abs(e[i]-want))
    if abs(e[hi]-want) > 6.0:
        return None
    rest = [i for i in range(3) if i != hi]
    wi, ti = (rest[0], rest[1]) if e[rest[0]] >= e[rest[1]] else (rest[1], rest[0])
    return hi, ti, wi

def yaw(e, want):
    c = classify(e, want)
    if c is None:
        return None
    return 0.0 if tuple(c) in EVEN else 180.0

# ---- 1. read the measured axes -------------------------------------------
parts = {}
with open(TSV) as fh:
    hdr = fh.readline().rstrip("\n").split("\t")
    ix = {n: i for i, n in enumerate(hdr)}
    for line in fh:
        f = line.rstrip("\n").split("\t")
        if len(f) < 6:
            continue
        parts[f[ix["definition"]]] = (float(f[ix["x"]]), float(f[ix["y"]]), float(f[ix["z"]]))

# ---- 2. read the inner VNT slots per layout ------------------------------
src = open(DATA, encoding="utf-8", errors="replace").read()
chunks = re.split(r"\n\s*'([^']+)'\s*=>\s*\{", src)
layouts = collections.OrderedDict()
for i in range(1, len(chunks), 2):
    key, body = chunks[i], chunks[i+1]
    for m in re.finditer(r":k=>'panel',\s*:id=>'([^']+)',\s*:sk=>'(VNT|NV)',\s*:sh=>'in',\s*:poly=>\[(.*?)\]\s*\}", body):
        pid, sk, poly = m.groups()
        pts = [tuple(map(float, q.split(','))) for q in re.findall(r"\[([-\d.]+,[-\d.]+)\]", poly)]
        xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
        run = max(max(xs)-min(xs), max(ys)-min(ys))
        w = round(run*2)/2.0
        ws = ("%g" % w)
        layouts.setdefault(key, set()).add("ENH %s%s" % (ws, sk))

# ---- 3. report -----------------------------------------------------------
ENH_WALL_H, ENH_WALL_H_HX = 79.5, 89.5
print("layout                 part                     runs  yaw   was(1.6.31)  CHANGE")
rows = []
missing = []
for key in sorted(layouts):
    for hx in (False, True):
        want = ENH_WALL_H_HX if hx else ENH_WALL_H
        for base in sorted(layouts[key]):
            name = base + "_HX" if hx else base
            if name not in parts:
                missing.append(name); continue
            e = parts[name]
            c = classify(e, want)
            y = yaw(e, want)
            runs = "X" if c[2] == 0 else ("Y" if c[2] == 1 else "Z")
            rows.append((key, name, runs, y))
            print("%-22s %-24s  %s   %5.1f   %5.1f       %s"
                  % (key, name, runs, y, 180.0, "" if y == 180.0 else "<-- FLIPPED BY THIS FIX"))
if missing:
    print("\nMISSING FROM TSV: %s" % sorted(set(missing)))

changed = sorted({(k, n) for k, n, r, y in rows if y != 180.0})
print("\n%d of %d (layout, part) pairs change; %d keep the old 180."
      % (len(changed), len(rows), len(rows)-len(changed)))

# ---- 4. check against Benton's in-SketchUp reports -----------------------
# (booth, part it resolves to, yaw LIVE at the time, his verdict)
REPORTS = [
    ("MDL 6060 E",   "ENH 35.5VNT",    0.0,   "wrong"),   # -> v1.6.21 set 180
    ("MDL 96144 E",  "ENH 41.5VNT",  180.0,   "wrong"),   # -> v1.6.24 set 0
    ("MDL 102144 E", "ENH 35.5VNT",    0.0,   "wrong"),   # -> v1.6.25 set 180
    ("MDL 4872 E",   "ENH 41.5VNT",    0.0,   "right"),   # signed off 2026-08-25, constant absent
    ("HX booth",     "ENH 35.5VNT_HX",180.0,  "wrong"),   # 2026-08-26, v1.6.31 live
]
print("\nBenton's reports vs the derived rule")
print("booth            part               live yaw  verdict  rule says  fits?")
allfit = True
for booth, part, live, verdict in REPORTS:
    want = ENH_WALL_H_HX if part.endswith("_HX") else ENH_WALL_H
    y = yaw(parts[part], want)
    # "wrong at live" means the rule must NOT equal live; "right" means it must.
    fits = (y != live) if verdict == "wrong" else (y == live)
    allfit &= fits
    print("%-16s %-18s %6.1f   %-7s  %6.1f     %s"
          % (booth, part, live, verdict, y, "yes" if fits else "NO"))
print("\nAll five reports fit the derived rule: %s" % ("YES" if allfit else "NO"))
sys.exit(0 if allfit else 1)
