# -*- coding: utf-8 -*-
"""MJP orientation: the transform chain, transcribed and run offline.

    python .forge/fixer/mjp-transform-repro.py

No SketchUp, no Ruby. Transcribes (and names the source line of) every step
that decides where MJP.skp's own X/Y/Z end up in the booth:

  build-booth-components.rb:1572  rotation(cls, nrm)   height->up, thickness->nrm,
                                                        width derived by parity
  wr-overlays.rb:558-567          wall_transform        room / face_sign / room_flip /
                                                        spin180, then the seating
  wr-overlays.rb:464-473          axes_for              which def axis is which

Inputs are OBSERVED: MJP.skp bounds from P:\\Sketchup\\NewMasterComponentList\\
_component-probe.tsv (8.7500 x 3.0306 x 18.3839, origin_z 8.8839 => z spans
-8.8839..9.5000) and the horizontal-face levels from _face-levels.tsv (2.125 ..
9.5 = the box; nothing horizontal below 2.125 = the two cable tails).
"""
import itertools

# ---- observed part ----------------------------------------------------------
E = [8.75, 3.0306, 18.3839]          # def-space extents x, y, z
LO = [0.0, 0.0, -8.8839]             # bounds.min  (origin_x/y = 0, origin_z = -min.z)
HI = [8.75, 3.0306, 9.5]             # bounds.max
BOX_Z = (2.125, 9.5)                 # horizontal-face band = the jack box
MJP_W, MJP_T = 8.39, 3.01            # wr-overlays.rb:161-162
MJP_TOP_Z = 27.25 + 3.64 / 2.0       # wr-overlays.rb:160  = 29.07

# ---- vector helpers ---------------------------------------------------------
def cross(a, b):
    return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]

def det3(c0, c1, c2):
    return (c0[0]*(c1[1]*c2[2]-c1[2]*c2[1]) - c1[0]*(c0[1]*c2[2]-c0[2]*c2[1])
            + c2[0]*(c0[1]*c1[2]-c0[2]*c1[1]))

def apply(cols, p):
    """cols = image of def X, Y, Z (Transformation.axes semantics)."""
    return [cols[0][i]*p[0] + cols[1][i]*p[1] + cols[2][i]*p[2] for i in range(3)]

def name(v):
    for lab, vec in (('+X', [1,0,0]), ('-X', [-1,0,0]), ('+Y', [0,1,0]),
                     ('-Y', [0,-1,0]), ('+Z(up)', [0,0,1]), ('-Z(down)', [0,0,-1])):
        if all(abs(v[i]-vec[i]) < 1e-9 for i in range(3)):
            return lab
    return str(v)

# ---- axes_for, wr-overlays.rb:464 (verbatim scoring, verbatim iteration order)
def axes_for(e, want_w, want_h, want_t):
    best = None
    for wi, hi, ti in itertools.permutations([0, 1, 2]):
        err = abs(e[wi]-want_w) + abs(e[ti]-want_t)
        if want_h is not None:
            err += abs(e[hi]-want_h)
        if best is None or err < best['err']:
            best = {'wi': wi, 'hi': hi, 'ti': ti, 'err': err}
    return best

# ---- rotation, build-booth-components.rb:1572 ------------------------------
EVEN = [[0,1,2], [1,2,0], [2,0,1]]
VZ = [0,0,1]

def rotation(cls, nrm):
    hi, ti, wi = cls['hi'], cls['ti'], cls['wi']
    s = 1 if [hi, ti, wi] in EVEN else -1
    ax = [None, None, None]
    ax[hi] = VZ
    ax[ti] = nrm
    ax[wi] = cross(VZ, nrm) if s > 0 else cross(nrm, VZ)
    return ax                        # columns: where def X, Y, Z go

def rot180_about(n, cols):
    """Geom::Transformation.rotation(ORIGIN, nrm, 180deg) * rot  — applied AFTER
    rot, in world space (SketchUp: A*B applies B first; wall_transform's own
    `translation * rot` relies on the same reading)."""
    def r(v):                        # Rodrigues at 180: v -> 2(n.v)n - v
        d = sum(n[i]*v[i] for i in range(3))
        return [2*d*n[i] - v[i] for i in range(3)]
    return [r(c) for c in cols]

# ---- slot_frame's :room per wall, wr-overlays.rb:284 -----------------------
# room = +1 when the wall's band lies on the LOW side of the booth centre along
# its normal axis, i.e. the room is at +naxis from the wall.
WALLS = {'S': ('y', +1.0), 'N': ('y', -1.0), 'W': ('x', +1.0), 'E': ('x', -1.0)}

def wall_transform(ax, wall, face_sign, room_flip, spin180):
    naxis, room0 = WALLS[wall]
    room = room0 * (-1.0 if room_flip else 1.0)
    o = room * face_sign
    nrm = [o, 0, 0] if naxis == 'x' else [0, o, 0]
    cols = rotation({'hi': ax['hi'], 'ti': ax['ti'], 'wi': ax['wi']}, nrm)
    if spin180:
        cols = rot180_about(nrm, cols)
    # the eight corners, rotated (wr-overlays.rb:570-582)
    zs = []
    for px in (LO, HI):
        for py in (LO, HI):
            for pz in (LO, HI):
                zs.append(apply(cols, [px[0], py[1], pz[2]])[2])
    d_z = MJP_TOP_Z - max(zs)                     # :z_top anchoring
    # where the BOX (def z 2.125..9.5) and the TAIL TIPS (def z -8.88) land
    box = sorted(apply(cols, [0, 0, z])[2] + d_z for z in BOX_Z)
    tips = apply(cols, [0, 0, LO[2]])[2] + d_z
    return cols, nrm, box, tips

def main():
    print('MJP.skp  extents x %.4f  y %.4f  z %.4f   z-range %.4f .. %.4f' % (E[0], E[1], E[2], LO[2], HI[2]))
    print('         jack box = def z %.3f..%.3f (horizontal-face band); tails hang to %.3f' % (BOX_Z[0], BOX_Z[1], LO[2]))
    print()
    # ---- 1. axes_for with the guessed 8.0 ------------------------------------
    print('== axes_for(e, 8.39, 8.0, 3.01) — the call at wr-overlays.rb:910 ==')
    scores = []
    for wi, hi, ti in itertools.permutations([0, 1, 2]):
        err = abs(E[wi]-MJP_W) + abs(E[ti]-MJP_T) + abs(E[hi]-8.0)
        scores.append(((wi, hi, ti), err))
        print('   (wi,hi,ti)=%s  err=%.17g' % ((wi, hi, ti), err))
    a = axes_for(E, MJP_W, 8.0, MJP_T)
    b = axes_for(E, MJP_W, None, MJP_T)
    print('   WINNER with 8.0 : wi=%d hi=%d ti=%d  (err %.17g)' % (a['wi'], a['hi'], a['ti'], a['err']))
    print('   WINNER with nil : wi=%d hi=%d ti=%d  (err %.4f; runner-up %.4f)' % (
        b['wi'], b['hi'], b['ti'], b['err'],
        sorted(abs(E[w]-MJP_W)+abs(E[t]-MJP_T) for w, h, t in itertools.permutations([0,1,2]) if (w, t) != (b['wi'], b['ti']))[0]))
    tie = [s for s in scores if abs(s[1] - a['err']) < 1e-9]
    print('   permutations tied with the winner (to 1e-9): %s' % [t[0] for t in tie])
    print()

    # ---- 2. the chain per wall ------------------------------------------------
    ax = {'wi': 0, 'hi': 2, 'ti': 1}      # the winner above
    hdr = '%-4s %-4s %-5s %-4s | %-9s %-9s %-9s | det | box z          tails-tip z'
    print('== wall_transform: where def +X / +Y(thickness) / +Z(up) land ==')
    print('   ax = wi 0, hi 2, ti 1  =>  (hi,ti,wi) = (2,1,0), NOT in EVEN => s = -1, width = nrm x Z')
    print(hdr % ('wall', 'face', 'spin', 'sign', 'def+X->', 'def+Y->', 'def+Z->'))
    for face_sign in (+1, -1):
        for spin in (True, False):
            for wall in 'SNWE':
                for face, flip in (('int', False), ('ext', True)):
                    cols, nrm, box, tips = wall_transform(ax, wall, face_sign, flip, spin)
                    d = det3(*cols)
                    print('   %-4s %-4s %-5s %+d   | %-9s %-9s %-9s | %+.0f | %5.2f..%5.2f   %5.2f' % (
                        wall, face, 'ON' if spin else 'off', face_sign,
                        name(cols[0]), name(cols[1]), name(cols[2]), d, box[0], box[1], tips))
            print('   -- (spin %s, FACE_ROOM %+d) --' % ('ON' if spin else 'off', face_sign))
    print()
    # ---- 3. the fix as shipped in 1.19.13: spin OFF, FACE_ROOM[:mjp] -1 --------
    print('== 1.19.13 settings (MJP_SPIN180 false, FACE_ROOM[:mjp] -1): resting geometry ==')
    print('   world z is booth-local, off the booth FLOOR (add the 4.75 caster lift if cs):')
    for wall in 'SNWE':
        for face, flip in (('int', False), ('ext', True)):
            cols, nrm, box, tips = wall_transform(ax, wall, -1, flip, False)
            field = [-c for c in cols[1]]
            print('   %s %s  box %.2f..%.2f (top at MJP_TOP_Z)  tails %.2f..%.2f  jack field (def -Y) -> %s  det %+.0f' % (
                wall, face, box[0], box[1], tips, box[0], name(field), det3(*cols)))
    print('   Net change from 1.19.2 = diag(1,-1,-1) about the in-wall horizontal axis:')
    old = wall_transform(ax, 'S', +1, False, True)[0]
    new = wall_transform(ax, 'S', -1, False, False)[0]
    # M = new * old^-1 ; old is orthonormal so old^-1 = old^T
    M = [[sum(new[k][i] * old[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    print('   M (rows) = %s' % [[round(v) for v in r] for r in M])
    print()
    print('Reading: with spin ON (shipped 1.19.2) def +Z lands DOWN on every wall and')
    print('both faces: the box sits at 10.69..18.06 off the floor and the tails rise to')
    print('29.07 — Benton\'s screenshot. The plate is meant to centre at 27.25.')
    print('The chain is UNIFORM across N/S/E/W: det +1 everywhere, no reflection; the')
    print('only thing that varies per wall is a yaw about world Z (the normal itself).')
    print('FACE_ROOM sign changes ONLY which way def +Y points (a yaw), never the vertical.')

if __name__ == '__main__':
    main()
