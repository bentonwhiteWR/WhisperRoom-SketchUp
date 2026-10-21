# Walsh corner-platform (21 Oct, brief rev 2): ARCHITECT-MATCHED geometry. Pure math; mirrors arch_geom.py.
# Frame: the 12 Oct take-off (origin = OLD interior SW corner, inches, +y plan-up). World = O + take-off.
# Corner frame: s along the exterior wall from the corner wall toward the apex, d from the exterior wall
# into the room. P(s, d) = C + s*SH + d*NH.
#
# Provenance: A, P1, WTOP (take-off, observed vector); WEST 227 = 18'-11" and EXT 384 = 32'-0" (architect,
# stated); D_F_ARCH 109 = 9'-1" MIN CLR (stated); S_STEP 84, S_ANG 139.6, D_Z 148 (derived/scaled from the
# 239 px markup capture, ~+/-6"); booth/platform (observed 12 Oct model + 6_Platform 06 TopDown scaled).
module WalshCorner
  A    = [104.409, 332.713]
  P1   = [292.958, 178.397]
  WTOP = [0.0, 205.12]
  WEST = 227.0
  Y_S  = WTOP[1] - WEST
  EXT  = 384.0
  THICK = 4.0
  CEIL  = 96.0
  SLAB  = 4.0
  DOOR_H = 80.0

  CFG = { 'FP' => 0.0, 'SHELL_OFF' => 11.625, 'BL' => 170.0, 'BD' => 98.0, 'PLAT' => [122.0, 166.0],
          'RAMP' => 48.0, 'PLAT_D' => 46.0, 'RAMP_DIR' => 'open', 'S_STEP_ARCH' => 84.0,
          'S_ANG_ARCH' => 139.6, 'D_F_ARCH' => 109.0, 'D_Z_ARCH' => 148.0,
          'POCKET_DOOR_FROM_G' => 12.0, 'POCKET_DOOR_W' => 36.0 }
  # Set $walsh_cfg = { 'RAMP_DIR' => 'corner', 'FP' => 1.5, ... } before loading to override.
  CFG.merge!($walsh_cfg) if defined?($walsh_cfg) && $walsh_cfg.is_a?(Hash)

  L  = Math.hypot(P1[0] - A[0], P1[1] - A[1])
  U  = [(P1[0] - A[0]) / L, (P1[1] - A[1]) / L]
  SH = [-U[0], -U[1]]
  NH = [U[1], -U[0]]
  C  = [A[0] + EXT * U[0], A[1] + EXT * U[1]]

  def self.p(s, d) [C[0] + s * SH[0] + d * NH[0], C[1] + s * SH[1] + d * NH[1]] end
  def self.d_on_y(s, y) (C[1] + s * SH[1] - y) / -NH[1] end

  def self.solve
    c = CFG
    d_shell = c['SHELL_OFF'] + c['BD']
    d_f = [c['D_F_ARCH'], d_shell + c['FP'] + 1.0].max
    pw = c['SHELL_OFF'] + c['PLAT'][0]
    pe = c['SHELL_OFF'] + c['PLAT'][1]
    zw, ze = c['RAMP_DIR'] == 'open' ? [pw, pe + c['RAMP']] : [pw - c['RAMP'], pe]
    s_step = [c['S_STEP_ARCH'], zw - 1.0].min
    s_ang = c['S_ANG_ARCH']
    zone_under = s_ang > zw - 1.0
    d_z = zone_under ? [c['D_Z_ARCH'], d_shell + c['PLAT_D'] + 1.0].max : c['D_Z_ARCH']
    { d_f: d_f, d_z: d_z, s_step: s_step, s_ang: s_ang, zone: [zw, ze], plat: [pw, pe], d_shell: d_shell }
  end

  # Tech Lab interior polygon (clockwise), take-off frame.
  def self.techlab
    g = solve
    foot = p(g[:s_ang], d_on_y(g[:s_ang], Y_S))
    [A, C, p(0, g[:d_f]), p(g[:s_step], g[:d_f]), p(g[:s_step], g[:d_z]), p(g[:s_ang], g[:d_z]),
     foot, [0.0, Y_S], WTOP]
  end

  # Pocket (behind the zigzag) pieces the Tech Lab walls do not already build. Take-off frame.
  def self.pocket
    g = solve
    t = THICK
    sa = g[:s_ang]
    fe   = p(sa - t, d_on_y(sa - t, Y_S))          # angled wall pocket face at the south wall face
    fo   = p(sa - t, d_on_y(sa - t, Y_S - t))      # outer mitre of the Tech Lab at the foot
    cs   = p(-t, d_on_y(-t, Y_S))                  # corner wall outer face at the south wall face
    go   = p(-t, d_on_y(-t, Y_S - t))              # pocket outer SE corner
    gi   = p(0, d_on_y(0, Y_S))                    # pocket interior SE corner (G)
    floor = [p(0, g[:d_f] + t), p(g[:s_step] - t, g[:d_f] + t), p(g[:s_step] - t, g[:d_z] + t),
             p(sa - t, g[:d_z] + t), fe, gi]
    stub = [p(0, g[:d_f] + t), gi, cs, p(-t, g[:d_f] + t)]
    { fe: fe, fo: fo, cs: cs, go: go, gi: gi, floor: floor, stub: stub }
  end

  def self.ft(v)
    neg = v < 0
    v = v.abs
    f = (v / 12).floor
    i = v - 12 * f
    format('%s%d\'-%.2f"', neg ? '-' : '', f, i)
  end

  def self.table
    g = solve
    k = pocket
    tl = techlab
    rows = [
      ['exterior wall, apex -> corner wall (existing)', EXT, %(32'-0" stated)],
      ['corner wall, exterior -> front wall', g[:d_f], %(9'-1" MIN CLR)],
      ['corner wall, front wall -> south wall', d_on_y(0, Y_S) - g[:d_f], 'not dimensioned'],
      ['front wall, corner -> step', g[:s_step], %(~7'-0" derived)],
      ['step wall', g[:d_z] - g[:d_f], %(~3'-3" derived)],
      ['zone wall, step -> angled wall', g[:s_ang] - g[:s_step], 'not dimensioned'],
      ['angled wall, zone -> south wall', d_on_y(g[:s_ang], Y_S) - g[:d_z], 'not dimensioned'],
      ['south wall, SW -> angled wall foot', tl[6][0], 'not dimensioned'],
      ['south wall, angled foot -> corner wall (pocket)', k[:gi][0] - tl[6][0], 'not dimensioned'],
      ['west wall', WEST, %(18'-11" stated)],
      ['NW angled wall', Math.hypot(A[0] - WTOP[0], A[1] - WTOP[1]), 'take-off']
    ]
    rows.map { |n, v, a| format('%-50s %12s %8.2f  arch %s', n, ft(v), v, a) }
  end
end
