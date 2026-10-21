# Walsh corner-platform, ARCHITECT-MATCHED geometry (brief rev 2, 21 Oct). Mirrors corner/geom.rb.
# Coordinates: the 12 Oct take-off frame (origin = OLD interior SW corner, inches). The architect's
# 18'-11" west wall puts the new south wall face at y = 205.12 - 227 = -21.88.
import math, sys, json
A = (104.409, 332.713); P1 = (292.958, 178.397); WTOP = (0.0, 205.12)
WEST = 227.0                                  # 18'-11" architect (stated)
Y_S = WTOP[1] - WEST                          # south wall face
L = math.hypot(P1[0]-A[0], P1[1]-A[1]); u = ((P1[0]-A[0])/L, (P1[1]-A[1])/L)
SH_ = (-u[0], -u[1]); NH = (u[1], -u[0])
C = (A[0]+384.0*u[0], A[1]+384.0*u[1])        # 32'-0" architect (stated), apex -> corner wall face (ASSUMED ends)
def P(s, d): return (C[0]+s*SH_[0]+d*NH[0], C[1]+s*SH_[1]+d*NH[1])
def d_on_y(s, y): return (C[1]+s*SH_[1]-y)/(-NH[1])
def s_on_y(d, y): return (y - C[1] - d*NH[1])/SH_[1]

cfg = dict(FP=0.0, SHELL_OFF=11.625, BL=170.0, BD=98.0, PLAT=(122.0, 166.0), RAMP=48.0, PLAT_D=46.0,
           RAMP_DIR='open', S_STEP_ARCH=84.0, S_ANG_ARCH=139.6, D_F_ARCH=109.0, D_Z_ARCH=148.0)
if len(sys.argv) > 1: cfg.update(json.loads(sys.argv[1]))
c = cfg
d_shell = c['SHELL_OFF'] + c['BD']
d_f = max(c['D_F_ARCH'], d_shell + c['FP'] + 1.0)
pw, pe = c['SHELL_OFF'] + c['PLAT'][0], c['SHELL_OFF'] + c['PLAT'][1]
if c['RAMP_DIR'] == 'open': zw, ze = pw, pe + c['RAMP']
else: zw, ze = pw - c['RAMP'], pe
s_step = min(c['S_STEP_ARCH'], zw - 1.0)       # step wall must clear the zone's corner-side end by 1"
s_ang = c['S_ANG_ARCH']
zone_under = s_ang > zw - 1.0                  # zone wall overlaps the platform/ramp in s
d_z = max(c['D_Z_ARCH'], d_shell + c['PLAT_D'] + 1.0) if zone_under else c['D_Z_ARCH']
foot = P(s_ang, d_on_y(s_ang, Y_S)); G = P(0, d_on_y(0, Y_S))
def ft(v):
    neg = v < 0; v = abs(v); f = int(v // 12); i = v - 12*f
    return ('-' if neg else '') + f"{f}'-{i:.2f}\""
rows = [
  ("exterior wall apex -> corner wall (existing)", 384.0, "32'-0\" (stated)"),
  ("corner wall, exterior -> front wall", d_f, "9'-1\" MIN CLR"),
  ("corner wall, front wall -> south wall", d_on_y(0, Y_S) - d_f, "not dimensioned"),
  ("front wall, corner -> step", s_step, "~7'-0\" (14'-8\" - 7'-8\", derived)"),
  ("step wall", d_z - d_f, "~3'-3\" (12'-4\" - 9'-1\", derived)"),
  ("zone wall, step -> angled wall", s_ang - s_step, "not dimensioned (~4'-8\" scaled)"),
  ("angled wall, zone -> south wall", d_on_y(s_ang, Y_S) - d_z, "not dimensioned"),
  ("south wall, SW -> angled wall foot (Tech Lab)", foot[0], "not dimensioned"),
  ("south wall, angled foot -> corner wall (pocket)", G[0] - foot[0], "not dimensioned"),
  ("west wall", WEST, "18'-11\" (stated)"),
  ("NW angled wall", math.hypot(A[0]-WTOP[0], A[1]-WTOP[1]), "not dimensioned (take-off)"),
]
print(json.dumps(dict(cfg=c, d_f=d_f, d_z=d_z, s_step=s_step, s_ang=s_ang, zone=(zw, ze), foot=foot, G=G, C=C, Y_S=Y_S)))
for n, v, a in rows: print(f"{n:52s} {ft(v):>12s}  {v:8.2f}   arch {a}")
print("booth shell: corner wall ->", ft(c['SHELL_OFF']), "to", ft(c['SHELL_OFF']+c['BL']), "| arch booth zone 14'-8\"")
print("door 24 jambs x 4..40 (old frame) ; angled wall foot x", round(foot[0], 1), "(pocket face x", round(P(s_ang-4, d_on_y(s_ang-4, Y_S))[0], 1), ")")
print("zone (platform+ramp) s", zw, "->", ze, "; zone wall overlaps it:", zone_under)
