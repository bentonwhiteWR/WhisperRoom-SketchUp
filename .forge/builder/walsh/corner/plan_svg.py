# Offline to-scale top-down of the corner layout, drawn from the SAME geometry as geom.rb / arch_geom.py.
# Fallback for when SketchUp is not reachable. Usage: python plan_svg.py out.svg [json-cfg]
import math, sys, json, subprocess, os
A = (104.409, 332.713); P1 = (292.958, 178.397); WTOP = (0.0, 205.12)
WEST = 227.0; Y_S = WTOP[1] - WEST; T = 4.0
L = math.hypot(P1[0]-A[0], P1[1]-A[1]); u = ((P1[0]-A[0])/L, (P1[1]-A[1])/L)
SH = (-u[0], -u[1]); NH = (u[1], -u[0]); C = (A[0]+384*u[0], A[1]+384*u[1])
c = dict(FP=0.0, SHELL_OFF=11.625, BL=170.0, BD=98.0, PLAT=(122.0, 166.0), RAMP=48.0, PLAT_D=46.0, RAMP_DIR='open',
         S_STEP_ARCH=84.0, S_ANG_ARCH=139.6, D_F_ARCH=109.0, D_Z_ARCH=148.0, PD_G=12.0, PD_W=36.0)
if len(sys.argv) > 2: c.update(json.loads(sys.argv[2]))
def P(s, d): return (C[0]+s*SH[0]+d*NH[0], C[1]+s*SH[1]+d*NH[1])
def d_on_y(s, y): return (C[1]+s*SH[1]-y)/(-NH[1])
so = c['SHELL_OFF']; ds = so + c['BD']; se = so + c['BL']
d_f = max(c['D_F_ARCH'], ds + c['FP'] + 1); pw, pe = so + c['PLAT'][0], so + c['PLAT'][1]
zw, ze = (pw, pe + c['RAMP']) if c['RAMP_DIR'] == 'open' else (pw - c['RAMP'], pe)
s_step = min(c['S_STEP_ARCH'], zw - 1); sa = c['S_ANG_ARCH']
d_z = max(c['D_Z_ARCH'], ds + c['PLAT_D'] + 1) if sa > zw - 1 else c['D_Z_ARCH']
foot = P(sa, d_on_y(sa, Y_S)); G = P(0, d_on_y(0, Y_S))
TL = [A, C, P(0, d_f), P(s_step, d_f), P(s_step, d_z), P(sa, d_z), foot, (0.0, Y_S), WTOP]
NEW = {1, 2, 3, 4, 5}
def sub(a, b): return (a[0]-b[0], a[1]-b[1])
def add(a, b, k=1.0): return (a[0]+k*b[0], a[1]+k*b[1])
def nrm(v): l = math.hypot(*v); return (v[0]/l, v[1]/l)
def area(p): return sum(p[i][0]*p[(i+1)%len(p)][1]-p[(i+1)%len(p)][0]*p[i][1] for i in range(len(p)))/2
ccw = area(TL) > 0
def outn(p, i):
    v = sub(p[(i+1) % len(p)], p[i]); return nrm((v[1], -v[0]) if ccw else (-v[1], v[0]))
def isect(p0, d0, p1, d1):
    den = d0[0]*d1[1]-d0[1]*d1[0]
    if abs(den) < 1e-9: return None
    t = ((p1[0]-p0[0])*d1[1]-(p1[1]-p0[1])*d1[0])/den; return add(p0, d0, t)
n = len(TL); OUT = []
for i in range(n):
    pv = (i-1) % n; a0 = add(TL[pv], outn(TL, pv), T); b0 = add(TL[i], outn(TL, i), T)
    h = isect(a0, sub(TL[i], TL[pv]), b0, sub(TL[(i+1) % n], TL[i])); OUT.append(h or b0)
walls = []
for i in range(n):
    j = (i+1) % n; walls.append(([TL[i], TL[j], OUT[j], OUT[i]], i in NEW))
def pt_s(s, d): return P(s, d)
fe = P(sa-T, d_on_y(sa-T, Y_S)); fo = P(sa-T, d_on_y(sa-T, Y_S-T)); cs = P(-T, d_on_y(-T, Y_S)); go = P(-T, d_on_y(-T, Y_S-T))
dx1 = G[0]-c['PD_G']; dx0 = dx1-c['PD_W']
walls.append(([P(0, d_f+T), G, cs, P(-T, d_f+T)], True))
walls.append(([fe, (dx0, Y_S), (dx0, Y_S-T), fo], False))
walls.append(([(dx1, Y_S), cs, go, (dx1, Y_S-T)], False))
# ---- svg
K = 2.2
allp = [q for w, _ in walls for q in w]
minx = min(q[0] for q in allp)-140; maxx = max(q[0] for q in allp)+120
miny = min(q[1] for q in allp)-230; maxy = max(q[1] for q in allp)+110
Wd = (maxx-minx)*K; Ht = (maxy-miny)*K
def X(q): return ((q[0]-minx)*K, (maxy-q[1])*K)
def poly(pts, **kw):
    a = ' '.join(f'{X(q)[0]:.1f},{X(q)[1]:.1f}' for q in pts)
    at = ' '.join(f'{k.replace("_", "-")}="{v}"' for k, v in kw.items()); return f'<polygon points="{a}" {at}/>'
def line(a, b, **kw):
    at = ' '.join(f'{k.replace("_", "-")}="{v}"' for k, v in kw.items())
    return f'<line x1="{X(a)[0]:.1f}" y1="{X(a)[1]:.1f}" x2="{X(b)[0]:.1f}" y2="{X(b)[1]:.1f}" {at}/>'
def ftin(v):
    e = int(round(v*8)); f, r = divmod(e, 96); i, k = divmod(r, 8)
    from math import gcd
    fr = '' if k == 0 else f" {k//gcd(k,8)}/{8//gcd(k,8)}"
    return f"{f}'-{i}{fr}\""
svg = []; rows = []
COL = {'wall': '#111111', 'door': '#ee6216', 'booth': '#2a5aa8'}
def dim(a, b, off_dir, dist, kind='wall', label=None, ext=True, before=False):
    v = nrm(off_dir); a2 = add(a, v, dist); b2 = add(b, v, dist); col = COL[kind]
    if ext:
        svg.append(line(add(a, v, 2), add(a2, v, 3), stroke=col, stroke_width=0.7))
        svg.append(line(add(b, v, 2), add(b2, v, 3), stroke=col, stroke_width=0.7))
    svg.append(line(a2, b2, stroke=col, stroke_width=1.0))
    dd = nrm(sub(b, a)); tk = (dd[0]+v[0], dd[1]+v[1])
    for q in (a2, b2): svg.append(line(add(q, tk, -2.5), add(q, tk, 2.5), stroke=col, stroke_width=1.4))
    m = ((a2[0]+b2[0])/2, (a2[1]+b2[1])/2); val = math.hypot(*sub(b, a))
    ang = -math.degrees(math.atan2(dd[1], dd[0]))
    if ang > 90: ang -= 180
    if ang < -90: ang += 180
    tp = add(m, v, 3.5); tw = len(ftin(val)) * 6.8
    if tw > val * K - 6:                                                     # short run: text outside the run
        tp = add(add(a2, v, 3.5), dd, -(tw / 2 + 8) / K) if before else add(add(b2, v, 3.5), dd, (tw / 2 + 8) / K)
    x, y = X(tp)
    svg.append(f'<text x="{x:.1f}" y="{y:.1f}" transform="rotate({ang:.2f} {x:.1f} {y:.1f})" text-anchor="middle" '
               f'font-size="12" fill="{col}" font-family="Arial" font-weight="bold">{ftin(val)}</text>')
    rows.append((label or '', kind, val))
# room fill
svg.append(poly(TL, fill='#ffffff', stroke='none'))
pk = [P(0, d_f+T), P(s_step-T, d_f+T), P(s_step-T, d_z+T), P(sa-T, d_z+T), fe, G]
svg.append(poly(pk, fill='#f3f3f3', stroke='none'))
for w, new in walls: svg.append(poly(w, fill='#111111' if new else '#b0c4de', stroke='#333', stroke_width=0.6))
# booth, platform, ramp
R = lambda s0, s1, d0, d1: [P(s0, d0), P(s1, d0), P(s1, d1), P(s0, d1)]
svg.append(poly(R(so, se, so, ds), fill='#dfe8f5', stroke='#2a5aa8', stroke_width=1.4))
svg.append(poly(R(pw, pe, ds, ds+c['PLAT_D']), fill='#fde3d3', stroke='#ee6216', stroke_width=1.2))
r0, r1 = (pe, pe+c['RAMP']) if c['RAMP_DIR'] == 'open' else (pw-c['RAMP'], pw)
svg.append(poly(R(r0, r1, ds, ds+c['PLAT_D']), fill='#fff3ea', stroke='#ee6216', stroke_width=1.0, stroke_dasharray='4 3'))
def label(q, txt, size=11, col='#333', ang=None):
    x, y = X(q); a = -math.degrees(math.atan2(SH[1], SH[0])) if ang is None else ang
    if a > 90: a -= 180
    if a < -90: a += 180
    return f'<text x="{x:.1f}" y="{y:.1f}" transform="rotate({a:.2f} {x:.1f} {y:.1f})" text-anchor="middle" font-size="{size}" fill="{col}" font-family="Arial">{txt}</text>'
svg.append(label(P((so+se)/2, (so+ds)/2+4), 'MDL 96168 E', 13, '#2a5aa8'))
svg.append(label(P((so+se)/2, (so+ds)/2-8), '14\'-2" x 8\'-2" exterior', 10, '#2a5aa8'))
svg.append(label(P((pw+pe)/2, ds+21), 'PLATFORM', 10, '#b5480c'))
svg.append(label(P((r0+r1)/2, ds+21), 'RAMP', 10, '#b5480c'))
# booth door N3 (hinge at its E jamb, swings out over the platform)
dj0, dj1 = so+121.25, so+165.75; hinge = P(dj1, ds); rr = dj1-dj0
arc = [P(dj1-rr*math.cos(t), ds+rr*math.sin(t)) for t in [k*math.pi/24 for k in range(13)]]
svg.append('<polyline points="' + ' '.join(f'{X(q)[0]:.1f},{X(q)[1]:.1f}' for q in arc) + '" fill="none" stroke="#ee6216" stroke-width="0.9" stroke-dasharray="3 2"/>')
svg.append(line(hinge, P(dj1, ds+rr), stroke='#ee6216', stroke_width=2))
# door 24 and pocket door
svg.append(line((4, Y_S), (4, Y_S+36), stroke='#8b4513', stroke_width=2))
arc = [(4+36*math.cos(t), Y_S+36*math.sin(t)) for t in [k*math.pi/24 for k in range(13)]]
svg.append('<polyline points="' + ' '.join(f'{X(q)[0]:.1f},{X(q)[1]:.1f}' for q in arc) + '" fill="none" stroke="#8b4513" stroke-width="0.9" stroke-dasharray="3 2"/>')
svg.append(poly([(4, Y_S), (40, Y_S), (40, Y_S-T), (4, Y_S-T)], fill='#ffffff', stroke='none'))
svg.append(poly([(dx0, Y_S), (dx1, Y_S), (dx1, Y_S-T), (dx0, Y_S-T)], fill='#ffffff', stroke='none'))
svg.append(line((dx1, Y_S), (dx1, Y_S+36), stroke='#8b4513', stroke_width=2))
arc = [(dx1-36*math.cos(t), Y_S+36*math.sin(t)) for t in [k*math.pi/24 for k in range(13)]]
svg.append('<polyline points="' + ' '.join(f'{X(q)[0]:.1f},{X(q)[1]:.1f}' for q in arc) + '" fill="none" stroke="#8b4513" stroke-width="0.9" stroke-dasharray="3 2"/>')
# ---- dims (same set and placement as s6-dims.rb)
outc = (-SH[0], -SH[1]); dG = d_on_y(0, Y_S); dA = d_on_y(sa, Y_S)
dim(P(0, 0), P(0, d_f), outc, 20, label='NEW corner wall, exterior -> front wall')
dim(P(0, d_f), P(0, dG), outc, 20, label='NEW corner wall, front wall -> south wall')
dim(P(0, 0), P(0, dG), outc, 48, label='NEW corner wall overall')
dim(P(0, d_f), P(s_step, d_f), NH, 14, label='NEW front wall')
dim(P(s_step, d_f), P(s_step, d_z), SH, 20, label='NEW step wall')
dim(P(s_step, d_z), P(sa, d_z), NH, 20, label='NEW zone wall')
dim(P(sa, d_z), P(sa, dA), SH, 20, label='NEW angled wall, zone wall -> south wall face')
dn = (0, -1)
dim((0, Y_S), (4, Y_S), dn, 20, 'door', 'SW corner -> door 24 jamb', before=True)
dim((4, Y_S), (40, Y_S), dn, 20, 'door', 'door 24 opening')
dim((dx0, Y_S), (dx1, Y_S), dn, 20, 'door', 'pocket door opening (approx)')
dim((dx1, Y_S), G, dn, 20, 'door', 'pocket door jamb -> corner wall (approx)')
dim((0, Y_S), foot, dn, 48, label='south wall, SW corner -> angled wall')
dim(foot, G, dn, 48, label='south wall, angled wall -> corner wall (pocket)')
dim((0, Y_S), G, dn, 76, label='south wall overall to corner wall')
dim((0, Y_S), WTOP, (-1, 0), 20, label='west wall')
nwv = (-(A[1]-WTOP[1]), A[0]-WTOP[0]); dim(WTOP, A, nwv, 20, label='NW angled wall')
ext = (-NH[0], -NH[1])
dim(P(0, 0), P(so, 0), ext, 20, 'booth', 'corner wall -> booth W end')
dim(P(so, 0), P(se, 0), ext, 20, 'booth', 'booth length')
dim(P(se, 0), A, ext, 20, 'booth', 'booth E end -> apex')
dim(P(0, 0), A, ext, 48, label='exterior wall, corner wall -> apex')
dim(P(se, 0), P(se, so), SH, 30, 'booth', 'exterior wall -> booth back')
dim(P(se, so), P(se, ds), SH, 30, 'booth', 'booth depth')
dim(P(dj1, ds+6), P(se, ds+6), NH, 1, 'door', 'booth NE corner -> door jamb', ext=False)   # on the platform top
dim(P(dj0, ds+6), P(dj1, ds+6), NH, 1, 'door', 'booth door opening', ext=False)
d1 = ds + c['PLAT_D']; z0, z1 = min(pw, r0), max(pe, r1); pb = pe if c['RAMP_DIR'] == 'open' else pw
dim(P(z0, ds+36), P(pb, ds+36), NH, 1, 'booth', 'platform' if c['RAMP_DIR'] == 'open' else 'ramp', ext=False)
dim(P(pb, ds+36), P(z1, ds+36), NH, 1, 'booth', 'ramp' if c['RAMP_DIR'] == 'open' else 'platform', ext=False)
dim(P(z1, ds), P(z1, d1), SH, 20, 'booth', 'platform/ramp depth')
# note, north/scale, legend
nx, ny = X((0, Y_S-120))
svg.append(f'<text x="{nx:.1f}" y="{ny:.1f}" font-size="13" font-family="Arial" fill="#333">New walls square to the exterior wall. Walls the architect did not dimension are approximate. Ceiling 8\'-0" assumed.</text>')
sx, sy = X((0, Y_S-150))
svg.append(f'<line x1="{sx}" y1="{sy}" x2="{sx+120*K}" y2="{sy}" stroke="#111" stroke-width="3"/>'
           f'<text x="{sx+120*K+8}" y="{sy+4}" font-size="12" font-family="Arial">10\'-0"  (scale bar)</text>')
lx = sx + 260*K
svg.append(f'<rect x="{lx}" y="{sy-10}" width="22" height="10" fill="#111"/><text x="{lx+28}" y="{sy}" font-size="12" font-family="Arial">new construction (black walls)</text>')
svg.append(f'<rect x="{lx+230}" y="{sy-10}" width="22" height="10" fill="#b0c4de" stroke="#333" stroke-width="0.6"/><text x="{lx+258}" y="{sy}" font-size="12" font-family="Arial">existing</text>')
svg.append(f'<text x="{lx+330}" y="{sy}" font-size="12" font-family="Arial"><tspan fill="#111" font-weight="bold">wall</tspan> / <tspan fill="#ee6216" font-weight="bold">door</tspan> / <tspan fill="#2a5aa8" font-weight="bold">booth</tspan> dims</text>')
ttl = f'<text x="20" y="28" font-size="18" font-family="Arial" font-weight="bold">Walsh Construction Tech Lab: MDL 96168 E corner platform layout (21 Oct)</text>' \
      f'<text x="20" y="48" font-size="12" font-family="Arial" fill="#555">Top-down, plan-up. Interior faces dimensioned. Drawn offline from the layout geometry; ramp toward {"the open end" if c["RAMP_DIR"]=="open" else "the corner"}.</text>'
doc = f'<svg xmlns="http://www.w3.org/2000/svg" width="{Wd:.0f}" height="{Ht+60:.0f}" viewBox="0 -60 {Wd:.0f} {Ht+60:.0f}"><rect x="0" y="-60" width="{Wd:.0f}" height="{Ht+60:.0f}" fill="#fff"/>' \
      + f'<g transform="translate(0,-60)">{ttl}</g>' + ''.join(svg) + '</svg>'
open(sys.argv[1], 'w', encoding='utf-8').write(doc)
print(f'{Wd:.0f}x{Ht+60:.0f}')
for lab, k, v in rows: print(f'{k:6s} {lab:48s} {ftin(v):>9s} {v:8.1f}')
