# Walsh corner-platform: PROVISIONAL geometry from the 12 Oct notes + the old Platform TopDown,
# computed before the bridge was up. Every booth/platform number here must be re-read live.
import math
A = (104.409, 332.713)          # apex (take-off)
P1 = (292.958, 178.397)         # old east-angled x exterior (take-off) - only for direction
L = math.hypot(P1[0]-A[0], P1[1]-A[1])
u = ((P1[0]-A[0])/L, (P1[1]-A[1])/L)       # along exterior wall, apex -> SE
S_HAT = (-u[0], -u[1])                     # s: from corner wall back toward the apex
N_HAT = (u[1], -u[0])                      # d: into the room, off the exterior wall
CORNER_T = 384.0                           # ASSUMED: 32'-0" apex -> corner wall, interior face
C = (A[0]+CORNER_T*u[0], A[1]+CORNER_T*u[1])
def P(s, d): return (C[0]+s*S_HAT[0]+d*N_HAT[0], C[1]+s*S_HAT[1]+d*N_HAT[1])
def d_at_south(s):  # depth at which the line s=const meets the south wall face y=0
    return (C[1]+s*S_HAT[1])/(-N_HAT[1])

HW = 10.625      # EFS overhang past the shell, S face and W0 end (observed 12 Oct)
GAP = 1.0
SH = HW+GAP      # shell offset from exterior wall and from corner wall = 11.625
BL, BD = 170.0, 98.0
FP = 0.0         # UNKNOWN front projection past the N shell face (door hardware) - read live
PLAT_X = (122.0, 166.0)   # platform along booth x, scaled off old TopDown PNG (+/-1 in)
RAMP_LEN = 47.6           # ramp length along booth x, scaled (+/-1 in); platform+ramp = 91.625 (dim text)
ZONE_D = 46.0             # 3'-10" out from the shell front (dim text)
d_f = SH+BD+FP+GAP
s_step = SH+PLAT_X[0]-GAP
d_z = SH+BD+ZONE_D+GAP
s_z = SH+PLAT_X[1]+RAMP_LEN+GAP           # flipped ramp runs +x past the booth E end
foot = P(s_z, d_at_south(s_z))
def arch(v):
    ft = int(v//12); i = v-12*ft
    return f"{ft}'-{i:.2f}\""
print("u", u, "C", C)
print("corner wall C->front:", arch(d_f), d_f)
print("front wall corner->step:", arch(s_step), s_step)
print("step out:", arch(d_z-d_f), d_z-d_f)
print("zone wall:", arch(s_z-s_step), s_z-s_step)
print("angled wall zone->south:", arch(d_at_south(s_z)-d_z), d_at_south(s_z)-d_z, "foot", foot)
print("corner->angled wall along ext:", arch(s_z), "corner->booth E shell", arch(SH+BL))
print("zone wall meets y=0 at s", (N_HAT[1]*-d_z - C[1]) / S_HAT[1])
for x in (4.0, 40.0):
    dx, dy = x-C[0], -C[1]
    print("door24 jamb x", x, "-> s", dx*S_HAT[0]+dy*S_HAT[1])
# south wall extension: from the angled-wall foot east to the front-wall outer face (d_f+4)
s_meet = (N_HAT[1]*-(d_f+4) - C[1]) / S_HAT[1]
print("front outer face meets y=0 at s", s_meet, "pt", P(s_meet, d_f+4))
print("south wall ext length", foot[0]-P(s_meet, d_f+4)[0])
