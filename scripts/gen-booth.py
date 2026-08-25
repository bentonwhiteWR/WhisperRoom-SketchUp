# -*- coding: utf-8 -*-
"""Generate a SketchUp Ruby script that assembles a booth from real part geometry.

    python gen-booth.py "MDL 4872" S
    python gen-booth.py --design "<booth-builder #d= link>"

GEOMETRY — see reference/booth-components.md. Panels do NOT touch: at every joint
the two panels butt into the interior of a mid-wall seam seal whose 2" stem fills
the gap. So a wall's interior run is

    run = sum(panel lengths) + 2" * joints

Panels are 1" thick and 81" tall. Wall assembly is 1" panel + 1" seal plate = 2"
per side, so exterior = interior + 4" on a Standard.

booth-layouts.json is used ONLY for the exterior envelope, the variant interiors
and the panel ORDER. Its slot sizes are not panel lengths — the 4872 records its
22" panel as 24 (seal absorbed) and the 96120's sides as 47+47 where the real
build is 46 + seal + 46. Panel lengths are solved from the run instead.

components-master.json is NOT used for geometry — its L/W/T are shipping sizes.
"""
import json, os, re, sys, base64, itertools

def _claude_root():
    """The Claude workspace root. Documents is local on the laptop and
    redirected into OneDrive on the desktop, so resolve it rather than
    hard-code one machine. WR_CLAUDE_ROOT overrides on a new one."""
    env = os.environ.get('WR_CLAUDE_ROOT')
    if env and os.path.isdir(env):
        return env
    home = os.environ.get('USERPROFILE') or os.path.expanduser('~')
    for c in (os.path.join(home, 'Documents', 'Claude'),
              os.path.join(home, 'OneDrive', 'Documents', 'Claude')):
        if os.path.isdir(c):
            return c
    return os.path.join(home, 'Documents', 'Claude')


QUOTE = os.path.join(_claude_root(), 'WhisperRoomQuote', 'lib', 'pl-data')
# wr-booth-data.rb belongs beside this script, wherever the repo is cloned.
OUT_DIR = os.path.dirname(os.path.abspath(__file__))

PANEL_T = 1.0      # every wall panel
PANEL_H = 81.0     # every wall panel
SEAL_W = 2.0       # mid-wall seam-seal stem — the gap between two panels
SEAL_PLATE = 7.75  # mid-wall seal base plate, along the wall
SEAL_D = 1.0       # seal plate thickness, outboard of the panel
CORNER = 4.875     # corner seam seal leg length
CORNER_T = 1.0     # corner seam seal leg thickness

# Panel lengths the factory actually makes, longest first.
STOCK = [46.0, 43.0, 40.0, 31.0, 28.0, 22.0, 19.0, 16.0, 7.0]
sys.stdout.reconfigure(encoding='utf-8', errors='replace')


def load(name):
    with open(os.path.join(QUOTE, name), encoding='utf-8') as f:
        return json.load(f)


def decode_design(h):
    h = h.split('#d=')[-1].split('?d=')[-1].strip()
    h = h.replace('-', '+').replace('_', '/')
    h += '=' * (-len(h) % 4)
    return json.loads(base64.b64decode(h).decode('utf-8'))


def solve_panels(run, slot_sizes):
    """Panel lengths satisfying run = sum(panels) + 2*(joints), IN SLOT ORDER.

    Order matters — it decides which panel carries the vent or the door — so we
    start from the layout's own sizes and correct them, rather than packing
    largest-first and silently rearranging the wall.

    booth-layouts.json's sizes are unreliable in two known ways: some absorb the
    2" seal into the panel (the 4872's "24" is really a 22), and some split a run
    evenly (the 96120's "47 + 47" is really 46 + seal + 46). Snapping each size to
    the nearest stock length fixes both.
    """
    n = len(slot_sizes)
    target = run - SEAL_W * (n - 1)
    listed = [float(s) for s in slot_sizes]

    if abs(sum(listed) - target) < 0.01 and all(any(abs(s - k) < 0.01 for k in STOCK) for s in listed):
        return listed, 'as listed'

    # Search real stock lengths, in slot order, totalling the target — choosing the
    # combination closest to what the layout lists. This handles both ways the data
    # goes wrong: a seal absorbed into one panel (4872's 24 is a 22, 4260's 18 is a
    # 16) and a run split evenly across panels (96120's 47+47 is 46+46).
    best = None

    def walk(i, acc, cost):
        nonlocal best
        if best is not None and cost >= best[1]:
            return
        if i == n:
            if abs(sum(acc) - target) < 0.01:
                best = (list(acc), cost)
            return
        rest = n - i - 1
        for s in STOCK:
            rem = target - sum(acc) - s
            if rem < rest * min(STOCK) - 0.01 or rem > rest * max(STOCK) + 0.01:
                continue
            acc.append(s)
            walk(i + 1, acc, cost + abs(s - listed[i]))
            acc.pop()

    walk(0, [], 0.0)
    if best:
        exact = all(abs(a - b) < 0.01 for a, b in zip(best[0], listed))
        return best[0], ('as listed' if exact else 'solved from stock')

    total = sum(listed) or 1.0
    return [round(s * target / total, 3) for s in listed], 'scaled'


# ------------------------------------------------------------- ENHANCED --
#
# An Enhanced booth is NOT a Standard booth with thicker walls. It is the
# Standard shell with a SECOND shell built inside it — the IEP (inner enhanced
# package). base-bom.json proves it rather than implying it: 'MDL 4872 E'
# carries the entire Standard wall set (C101/C102/C111/C114) AND a full IEP set
# (K101/K102/K112/K116), with IEP corner and mid-wall seam seals (N01/O01)
# alongside the Standard ones (D01/D02).
#
# So the 4.5 that shows up in every E interior is not a per-panel shrink and
# never was. It is one whole inner shell standing 2.25" inboard of the Standard
# interior face on all four sides. A one-for-one "Standard width minus 4.5"
# substitution names the right PARTS and cannot place them; this places them.
#
# THE INNER RUN RULE, which is the thing that blocked every Enhanced booth:
#
#     inner run = sum(IEP panel widths) + 6.5" per joint
#
# 6.5, where Standard is 2. Derived twice, independently:
#   * all 25 Enhanced BOMs close on it exactly. Sum the IEP walls each one
#     ships and it equals that model's E interior perimeter less 6.5 per joint,
#     25 of 25, no residue.
#   * ENH MidWallSeamSeal measures 12.25 across the wall (P: library probe)
#     against the Standard seal's 7.75. The Standard plate laps 2.875 past its
#     2" stem on each side; 12.25 - 2 x 2.875 = 6.5 — the same flange on a
#     wider stem.
#
# WHICH panel goes in which slot is not guessed either. The BOM fixes the
# multiset of IEP widths a model ships; solve_inner searches partitions of that
# multiset across the four walls and keeps only those satisfying every wall's
# run equation. For all 25 models exactly ONE partition survives.
IEP_STOCK = [41.5, 38.5, 35.5, 26.5, 23.5, 17.5, 14.5, 11.5]
IEP_SEAL_W = 6.5        # inner mid-wall seam-seal stem — see above
IEP_SEAL_PLATE = 12.25  # measured, ENH MidWallSeamSeal
IEP_SEAL_D = 0.5        # plate stands proud INTO THE ROOM: 2.5 part - 2.0 wall
IEP_CORNER = 5.375      # measured, ENH CornerSeamSeal
IEP_PANEL_T = 2.0       # nominal. The ENH panel measures 2.0625 with its 1/16
                        # inboard finish layer; 2.0 is what closes the
                        # arithmetic: 2.0 std + 0.25 gap + 2.0 IEP = 4.25, the
                        # E wallThickness booth-layouts.json carries.
IEP_FACE = 4.25         # room face of the inner shell, from the booth exterior


def iep_widths(model, boms, comps):
    """The multiset of IEP wall widths a model's Enhanced BOM actually ships.

    Door jambs count as walls — an IEPJAMB 46 fills a 41.5 slot. Height
    extensions, seam seals, beams and the door leaf itself are not walls.
    """
    out = []
    for code, qty in boms.get('%s E' % model, {}).get('components', {}).items():
        c = comps.get(code)
        if not c:
            continue
        pack = c['pack']
        if 'EXT' in pack or 'SS ' in pack or 'BEAM' in pack:
            continue
        m = re.match(r'IEPWL(\d+(?:\.\d+)?)', pack)
        if m:
            out += [float(m.group(1))] * qty
        elif 'IEPJAMB 46' in pack or 'IN DRFRM 46' in pack:
            out += [41.5] * qty
        elif pack.strip() == 'IEPJAMB' or 'IN DRFRM 40' in pack:
            out += [35.5] * qty
        elif 'IEPJAMB' in pack:          # WA / ADA jamb
            out += [44.5] * qty
    return sorted(out, reverse=True)


def solve_inner(L, model, runs, boms, comps):
    """{side: [width per slot, in slot order]} for the inner shell, or None.

    Constrained by the BOM, not fitted to it: only partitions of the shipped
    multiset that satisfy every wall's run equation are considered. Returns
    None if that leaves zero or more than one answer, because a guess here is
    an inner shell of the wrong width that looks perfectly fine.
    """
    sides = [s for s in ('N', 'S', 'E', 'W') if s in L['walls']]
    opts = {}
    for s in sides:
        n = len(L['walls'][s]['slots'])
        target = runs[s] - IEP_SEAL_W * (n - 1)
        opts[s] = [c for c in itertools.combinations_with_replacement(IEP_STOCK, n)
                   if abs(sum(c) - target) < 0.001]
        if not opts[s]:
            return None
    want = iep_widths(model, boms, comps)
    found = []
    for combo in itertools.product(*[opts[s] for s in sides]):
        got = sorted([w for c in combo for w in c], reverse=True)
        if got == want:
            found.append(dict(zip(sides, combo)))
            if len(found) > 1:
                return None
    if len(found) != 1:
        return None

    # Widest inner panel to the widest Standard slot. That is what keeps the
    # inner door and vent facing the same way as the outer ones: the 46 slot
    # carrying the door frame takes the 41.5 jamb, not the 17.5 filler. Ties
    # keep slot order.
    out = {}
    for s in sides:
        slots = L['walls'][s]['slots']
        order = sorted(range(len(slots)), key=lambda i: (-float(slots[i]['size']), i))
        widths = sorted(found[0][s], reverse=True)
        row = [None] * len(slots)
        for rank, i in enumerate(order):
            row[i] = widths[rank]
        out[s] = row
    return out


def inner_parts(L, W, H, inner, assign=None):
    """The IEP shell as plan polygons, in the same language as the outer one.

    Written separately rather than folded into the outer loop on purpose. The
    two shells are not mirror images: the Standard seals face OUT and wrap a
    convex corner, the IEP seals face INTO THE ROOM and sit in a concave one.
    Sharing the code would mean a sign flag in six places and a real chance of
    silently moving the Standard geometry, which is the one part of this file
    that has actually been looked at in SketchUp.
    """
    f = IEP_FACE                 # room face of the inner shell
    b = f - IEP_PANEL_T          # back face of the inner panel (2.25)
    parts = []
    for side in ('N', 'S', 'E', 'W'):
        wall = L['walls'].get(side)
        if not wall:
            continue
        slots = wall['slots']
        cursor = f
        for i, (slot, ln) in enumerate(zip(slots, inner[side])):
            if side in ('N', 'S'):
                x, dx = cursor, ln
                y, dy = (H - f if side == 'N' else b), IEP_PANEL_T
            else:
                # Same N->S walk as the outer shell, for the same reason.
                x, dx = (W - f if side == 'E' else b), IEP_PANEL_T
                y, dy = H - cursor - ln, ln
            parts.append(dict(kind='panel', id='%si' % slot['id'], side=side,
                              slot_kind=slot['kind'], shell='in',
                              pack=(assign or {}).get('%si' % slot['id']), length=ln,
                              x=round(x, 4), y=round(y, 4),
                              dx=round(dx, 4), dy=round(dy, 4)))
            cursor += ln
            if i < len(inner[side]) - 1:
                mid = cursor + IEP_SEAL_W / 2.0
                if side in ('E', 'W'):
                    mid = H - cursor - IEP_SEAL_W / 2.0
                h = IEP_SEAL_PLATE / 2.0
                s = IEP_SEAL_W / 2.0
                # A T on its side: the 6.5 stem fills the joint through the
                # full 2" panel depth, the 12.25 plate laps 0.5 into the room.
                if side == 'N':
                    o, p = H - f - IEP_SEAL_D, H - f
                    poly = [(mid - s, p + IEP_PANEL_T), (mid + s, p + IEP_PANEL_T),
                            (mid + s, p), (mid + h, p), (mid + h, o), (mid - h, o),
                            (mid - h, p), (mid - s, p)]
                elif side == 'S':
                    o, p = f + IEP_SEAL_D, f
                    poly = [(mid - s, p - IEP_PANEL_T), (mid - s, p), (mid - h, p),
                            (mid - h, o), (mid + h, o), (mid + h, p), (mid + s, p),
                            (mid + s, p - IEP_PANEL_T)]
                elif side == 'E':
                    o, p = W - f - IEP_SEAL_D, W - f
                    poly = [(p + IEP_PANEL_T, mid - s), (p, mid - s), (p, mid - h),
                            (o, mid - h), (o, mid + h), (p, mid + h), (p, mid + s),
                            (p + IEP_PANEL_T, mid + s)]
                else:
                    o, p = f + IEP_SEAL_D, f
                    poly = [(p - IEP_PANEL_T, mid - s), (p - IEP_PANEL_T, mid + s),
                            (p, mid + s), (p, mid + h), (o, mid + h), (o, mid - h),
                            (p, mid - h), (p, mid - s)]
                parts.append(dict(kind='seal', id='%s-seal%di' % (side, i), side=side,
                                  slot_kind='SEAL', shell='in',
                                  pack='ENH mid-wall seam seal', length=IEP_SEAL_PLATE,
                                  poly=[(round(a, 4), round(c, 4)) for a, c in poly]))
                cursor += IEP_SEAL_W

    # IEP corner seam seal: a plain L in the concave room corner, legs 5.375
    # long and 0.5 proud. The step where the panel ends tuck behind it is not
    # modelled, exactly as on the Standard corner — there is no dimensioned
    # corner detail for either.
    for cx, cy, sx, sy, name in ((f, f, 1, 1, 'SW'), (W - f, f, -1, 1, 'SE'),
                                 (f, H - f, 1, -1, 'NW'), (W - f, H - f, -1, -1, 'NE')):
        poly = [(cx, cy),
                (cx + sx * IEP_CORNER, cy),
                (cx + sx * IEP_CORNER, cy + sy * IEP_SEAL_D),
                (cx + sx * IEP_SEAL_D, cy + sy * IEP_SEAL_D),
                (cx + sx * IEP_SEAL_D, cy + sy * IEP_CORNER),
                (cx, cy + sy * IEP_CORNER)]
        parts.append(dict(kind='corner', id='%s corner seal i' % name, side=name,
                          slot_kind='CORNER', shell='in', pack='ENH corner seam seal',
                          length=IEP_CORNER,
                          poly=[(round(a, 4), round(c, 4)) for a, c in poly]))
    return parts


def poly_of(p):
    """Every part as a plan polygon — rectangles expand, T and L shapes pass through."""
    if 'poly' in p:
        return p['poly']
    x, y, dx, dy = p['x'], p['y'], p['dx'], p['dy']
    return [(x, y), (x + dx, y), (x + dx, y + dy), (x, y + dy)]


def build(model, variant, assign=None):
    layouts = load('booth-layouts.json')['layouts']
    boms = load('base-bom.json')['models']
    comps = load('components-master.json')['components']

    if model not in layouts:
        sys.exit('unknown model %r. known: %s' % (model, ', '.join(sorted(layouts))))
    L = layouts[model]
    if variant not in L['variants']:
        sys.exit('unknown variant %r' % variant)

    ext = L['exterior']
    W, H = float(ext['w']), float(ext['h'])

    # THE OUTER SHELL OF AN ENHANCED BOOTH IS A STANDARD SHELL. Reading E's own
    # wallThickness and interior here is what made every Enhanced booth
    # unbuildable: it fed the 65.5 inner run and the 4.25 wall into a solver
    # holding Standard 46/22/16 stock, which cannot close, and the run came out
    # 'scaled' — invented. The Standard numbers belong to the outer shell; the
    # E numbers describe the INNER one, and it is built separately below.
    shell_v = 'S' if variant == 'E' else variant
    t = float(L['variants'][shell_v]['wallThickness'])
    outer = L['variants'][shell_v]['interior']
    iw, ih = float(outer['w']), float(outer['h'])
    e_int = L['variants'].get('E', {}).get('interior')

    parts, notes = [], []
    runs = {'N': iw, 'S': iw, 'E': ih, 'W': ih}

    for side in ('N', 'S', 'E', 'W'):
        wall = L['walls'].get(side)
        if not wall:
            continue
        slots = wall['slots']
        lengths, how = solve_panels(runs[side], [s['size'] for s in slots])
        if how != 'as listed':
            notes.append('%s wall %s -> %s (%s), + %d seal(s) = %.2f" run'
                         % (side, [s['size'] for s in slots], [int(x) if x == int(x) else x for x in lengths],
                            how, len(slots) - 1, runs[side]))

        cursor = t
        for i, (slot, ln) in enumerate(zip(slots, lengths)):
            pack = (assign or {}).get(slot['id'])
            if side in ('N', 'S'):
                x, y = cursor, (H - t if side == 'N' else t - PANEL_T)
                dx, dy = ln, PANEL_T
            else:
                # E/W slot lists run NORTH -> SOUTH. That is the booth builder's own
                # convention (layout-render.js top-down: ay = runY(aIn), y-down from
                # the N wall), and this walked them south->north until 2026-08-11 —
                # which put every E/W wall's panels at the mirrored end. N/S run
                # west->east in both, so only these two flip.
                x, y = (W - t if side == 'E' else t - PANEL_T), H - cursor - ln
                dx, dy = PANEL_T, ln
            parts.append(dict(kind='panel', id=slot['id'], side=side, shell='out', slot_kind=slot['kind'],
                              pack=pack, length=ln,
                              x=round(x, 3), y=round(y, 3), dx=round(dx, 3), dy=round(dy, 3)))
            cursor += ln
            if i < len(lengths) - 1:
                # Mid-wall seam seal — ONE T-shaped piece. The 7 3/4" x 1" base sits
                # in the outboard band; the 2" stem fills the gap and the two panels
                # butt into its sides.
                band = t - PANEL_T
                mid = cursor + SEAL_W / 2.0
                if side in ('E', 'W'):
                    mid = H - cursor - SEAL_W / 2.0   # same N->S flip as the panels
                h = SEAL_PLATE / 2.0
                s = SEAL_W / 2.0
                if side == 'N':
                    o, p = H, H - band          # o = exterior face, p = base/stem line
                    poly = [(mid - s, p - PANEL_T), (mid + s, p - PANEL_T), (mid + s, p),
                            (mid + h, p), (mid + h, o), (mid - h, o), (mid - h, p), (mid - s, p)]
                elif side == 'S':
                    o, p = 0.0, band
                    poly = [(mid - s, p + PANEL_T), (mid - s, p), (mid - h, p), (mid - h, o),
                            (mid + h, o), (mid + h, p), (mid + s, p), (mid + s, p + PANEL_T)]
                elif side == 'E':
                    o, p = W, W - band
                    poly = [(p - PANEL_T, mid - s), (p, mid - s), (p, mid - h), (o, mid - h),
                            (o, mid + h), (p, mid + h), (p, mid + s), (p - PANEL_T, mid + s)]
                else:
                    o, p = 0.0, band
                    poly = [(p + PANEL_T, mid - s), (p + PANEL_T, mid + s), (p, mid + s),
                            (p, mid + h), (o, mid + h), (o, mid - h), (p, mid - h), (p, mid - s)]
                parts.append(dict(kind='seal', id='%s-seal%d' % (side, i), side=side, shell='out',
                                  slot_kind='SEAL', pack='Std mid-wall seam seal', length=SEAL_PLATE,
                                  poly=[(round(a, 3), round(b, 3)) for a, b in poly]))
                cursor += SEAL_W

    # Corner seam seals — L-shaped, 4 7/8" legs, sitting in the same outboard band
    # as the mid-wall plates. Modelled as two rectangular legs meeting at the
    # corner: the outer profile is exact; the small inner step on the drawing is
    # not modelled.
    # Corner seam seal — ONE piece: an L of 4 7/8" legs in the outboard band, PLUS
    # the 1" x 1" block at the inside corner that the two panel ends butt into.
    # Eight points, mirrored per corner.
    band = t - PANEL_T
    for cx, cy, sx, sy, name in ((0.0, 0.0, 1, 1, 'SW'), (W, 0.0, -1, 1, 'SE'),
                                 (0.0, H, 1, -1, 'NW'), (W, H, -1, -1, 'NE')):
        poly = [(cx, cy),
                (cx + sx * CORNER, cy),
                (cx + sx * CORNER, cy + sy * band),
                (cx + sx * t,      cy + sy * band),
                (cx + sx * t,      cy + sy * t),
                (cx + sx * band,   cy + sy * t),
                (cx + sx * band,   cy + sy * CORNER),
                (cx,               cy + sy * CORNER)]
        parts.append(dict(kind='corner', id='%s corner seal' % name, side=name, shell='out',
                          slot_kind='CORNER', pack='Std corner seam seal', length=CORNER,
                          poly=[(round(a, 3), round(b, 3)) for a, b in poly]))

    # The BOM counts BOXES, and some boxes hold two panels — the 16" wall ships
    # 2-per-box. components-master's desc starts with that count ("2 - STD WALL
    # COMPONENT"), so expand by it. layout-render.js does the same thing in
    # expandWallBoxes(); without it every 40-module booth looks short by the
    # number of 2-packs it carries.
    # ---- the inner (IEP) shell, Enhanced only -------------------------------
    if variant == 'E':
        e_runs = {'N': float(e_int['w']), 'S': float(e_int['w']),
                  'E': float(e_int['h']), 'W': float(e_int['h'])}
        solved = solve_inner(L, model, e_runs, boms, comps)
        if solved is None:
            notes.append('inner shell UNRESOLVED (scaled) - no single IEP panel '
                         'arrangement satisfies both the BOM and the run rule')
        else:
            parts += inner_parts(L, W, H, solved, assign)
            for side in ('N', 'S', 'E', 'W'):
                if side not in solved:
                    continue
                n = len(solved[side])
                got = sum(solved[side]) + IEP_SEAL_W * (n - 1)
                if abs(got - e_runs[side]) > 0.001:
                    notes.append('%s inner run %.4f != %.4f (scaled)'
                                 % (side, got, e_runs[side]))
            notes.append('inner shell %s, %.2f" face, %g" seal stem'
                         % ({k: [int(x) if x == int(x) else x for x in v]
                             for k, v in sorted(solved.items())}, IEP_FACE, IEP_SEAL_W))

    bom_key = '%s %s' % (model, variant)
    bom = boms.get(bom_key, {}).get('components', {})
    bom_panels = 0
    for code, qty in bom.items():
        c = comps.get(code, {})
        if not c.get('pack', '').startswith(('STDWL', 'WA STD', 'ADA STD')):
            continue
        if 'EXT' in c.get('pack', ''):        # height extensions are not walls
            continue
        m = re.match(r'\s*(\d+)\s*-', c.get('desc', ''))
        per_box = int(m.group(1)) if m else 1
        bom_panels += qty * per_box
    # bom_panels counts STDWL boxes, so it is the OUTER shell's panel count on
    # both variants. Compare like with like or every Enhanced booth reports a
    # mismatch for the inner shell the BOM counts under K-codes instead.
    placed = sum(1 for p in parts if p['kind'] == 'panel' and p.get('shell') != 'in')
    placed_in = sum(1 for p in parts if p['kind'] == 'panel' and p.get('shell') == 'in')

    return dict(model=model, variant=variant, W=W, H=H, t=t, iw=iw, ih=ih,
                eiw=(float(e_int['w']) if e_int else None),
                eih=(float(e_int['h']) if e_int else None),
                parts=parts, notes=notes, bom_panels=bom_panels, placed=placed,
                placed_in=placed_in, label=L.get('label', ''))


def emit_ruby(b):
    slug = (b['model'].replace('MDL ', '').strip() + '-' + b['variant']).lower()
    path = os.path.join(OUT_DIR, 'booth-%s.rb' % slug)
    rows = ',\n'.join(
        '    { :k=>%r, :id=>%r, :sk=>%r, :sh=>%r, :poly=>[%s] }'
        % (p['kind'], p['id'], p['slot_kind'], p.get('shell', 'out'),
           ','.join('[%s,%s]' % (a, c) for a, c in poly_of(p)))
        for p in b['parts'])
    notes = '\n'.join('    puts "  NOTE: %s"' % n.replace('"', "'") for n in b['notes']) or '    # none'
    const = (b['model'].replace('MDL ', '').strip() + '_' + b['variant']).replace(' ', '_')

    rb = '''# @title Build Booth %(model)s %(variant)s
# GENERATED by scripts/gen-booth.py — regenerate, don't hand-edit.
#
# %(model)s %(variant)s  ("%(label)s")
#   exterior  %(W)s" x %(H)s"      interior %(iw)s" x %(ih)s"
#   panels    1" thick, 81" tall, separated by the 2" mid-wall seam-seal stem
#   run rule  interior = sum(panels) + 2" per joint
#
# Panel kinds are interchangeable — the door frame, vent, cable and window walls
# all swap into any position. What's drawn here is one arrangement, not a rule.

module WR_BOOTH_%(const)s
  W = %(W)s
  H = %(H)s
  T = %(t)s
  PH = 81.0

  PARTS = [
%(parts)s
  ]

  def self.pt(x, y, z = 0.0); Geom::Point3d.new(x, y, z); end

  def self.build
    model = Sketchup.active_model
    begin
      model.options["UnitsOptions"]["LengthFormat"] = Length::Architectural
    rescue StandardError
    end
    model.start_operation("Build %(model)s %(variant)s", true)

    tag = lambda do |name, rgb|
      l = model.layers[name] || model.layers.add(name)
      (l.color = Sketchup::Color.new(*rgb)) rescue nil
      l
    end
    t_wall = tag.call("WR-Booth-Walls", [120, 128, 140])
    t_door = tag.call("WR-Booth-Door",  [238,  98,  22])
    t_vent = tag.call("WR-Booth-Vent",  [ 64, 102, 124])
    t_seal = tag.call("WR-Booth-Seals", [ 90,  90,  96])
    t_flr  = tag.call("WR-Booth-Floor", [210, 210, 210])

    booth = model.entities.add_group
    booth.name = "%(model)s %(variant)s"

    f = booth.entities.add_group
    fc = f.entities.add_face([pt(0,0), pt(W,0), pt(W,H), pt(0,H)])
    fc.reverse! if fc && fc.normal.z < 0
    f.name = "floor"; f.layer = t_flr

    PARTS.each do |p|
      g = booth.entities.add_group
      face = g.entities.add_face([ pt(p[:x], p[:y]),
                                   pt(p[:x] + p[:dx], p[:y]),
                                   pt(p[:x] + p[:dx], p[:y] + p[:dy]),
                                   pt(p[:x], p[:y] + p[:dy]) ])
      next if face.nil?
      face.reverse! if face.normal.z < 0
      face.pushpull(PH)
      g.name  = p[:pack] ? "#{p[:id]}  #{p[:pack]}" : "#{p[:id]}  #{p[:sk]}"
      g.layer = if p[:k] == "seal" then t_seal
                elsif p[:sk] == "DRFRM" then t_door
                elsif p[:sk] == "VNT"   then t_vent
                else t_wall
                end
    end

    model.commit_operation
    model.active_view.zoom_extents

    puts ""
    puts "%(model)s %(variant)s built."
    puts "  exterior %(W)s\\" x %(H)s\\"   interior %(iw)s\\" x %(ih)s\\""
    puts "  %(placed)d wall panels + %(seals)d mid-wall seam seals, panels 1\\" x 81\\" tall"
    puts "  packing list lists %(bom)d wall panels%(agree)s"
%(notes)s
    puts "  Corner seam seals are NOT modelled yet — no dimensioned corner detail."
    puts ""
  rescue StandardError => e
    model.abort_operation if model
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(5)
  end
end

WR_BOOTH_%(const)s.build
''' % dict(model=b['model'], variant=b['variant'], label=b['label'], const=const,
           W=b['W'], H=b['H'], t=b['t'], iw=b['iw'], ih=b['ih'], parts=rows, notes=notes,
           placed=b['placed'], seals=sum(1 for p in b['parts'] if p['kind'] == 'seal'),
           bom=b['bom_panels'],
           agree=(' — agrees' if b['bom_panels'] == b['placed'] else ' — MISMATCH'))

    with open(path, 'w', encoding='utf-8') as fh:
        fh.write(rb)
    return path


def emit_data():
    """One data file with every booth the rule can prove, for the picker script."""
    layouts = load('booth-layouts.json')['layouts']
    good, skipped = {}, []
    for model in sorted(layouts):
        for variant in ('S', 'E'):
            if variant not in layouts[model]['variants']:
                continue
            b = build(model, variant, {})
            why = None
            if any('(scaled)' in n for n in b['notes']):
                why = 'panel lengths unresolved'
            elif b['placed'] != b['bom_panels']:
                why = 'layout %d panels vs BOM %d' % (b['placed'], b['bom_panels'])
            if why:
                skipped.append(('%s %s' % (model, variant), why))
                continue
            good['%s %s' % (model, variant)] = b

    rows = []
    for key, b in good.items():
        parts = ',\n        '.join(
            '{ :k=>%r, :id=>%r, :sk=>%r, :sh=>%r, :poly=>[%s] }'
            % (p['kind'], p['id'], p['slot_kind'], p.get('shell', 'out'),
               ','.join('[%s,%s]' % (a, c) for a, c in poly_of(p)))
            for p in b['parts'])
        # :iw/:ih are the OUTER shell's interior on both variants. An Enhanced
        # booth adds :eiw/:eih (the room inside the inner shell) and :phi, the
        # IEP panel height - 1.5 shorter than a Standard panel because an
        # Enhanced wall is captured between the floor and ceiling lips instead
        # of standing on the deck. Nothing may reuse :ph for an inner part.
        extra = ''
        if b['variant'] == 'E':
            extra = ', :eiw=>%s, :eih=>%s, :phi=>79.5' % (b['eiw'], b['eih'])
        rows.append('''    %r => { :label=>%r, :w=>%s, :h=>%s, :iw=>%s, :ih=>%s, :ph=>81.0%s,
      :parts => [
        %s
      ] }''' % (key, b['label'], b['W'], b['H'], b['iw'], b['ih'], extra, parts))

    path = os.path.join(OUT_DIR, 'wr-booth-data.rb')
    with open(path, 'w', encoding='utf-8') as f:
        f.write('# GENERATED by scripts/gen-booth.py --all — do not hand-edit.\n'
                '# Every booth whose assembly the run rule can prove:\n'
                '#   interior run = sum(panel lengths) + 2" per joint\n'
                '# Outer panels 1\" thick, 81\" tall. Read by build-booth.rb.\n'
                '#\n'
                '# An \" E\" key carries TWO shells. :sh=>out parts are the Standard\n'
                '# outer shell. :sh=>in parts are the IEP inner shell: 2\" thick,\n'
                '# 79.5\" tall, standing 2.25\" inboard of the outer interior face,\n'
                '# with a 6.5\" seam-seal stem instead of 2\".\n'
                '#\n# Skipped, and why:\n'
                + ''.join('#   %-16s %s\n' % (k, w) for k, w in skipped) +
                '\nmodule WR_BOOTH_DATA\n  BOOTHS = {\n'
                + ',\n'.join(rows) + '\n  }\nend\n')
    return path, good, skipped


def main():
    args = sys.argv[1:]
    if args and args[0] == '--all':
        path, good, skipped = emit_data()
        print('wrote %s' % path)
        print('  %d booths available in the picker:' % len(good))
        for k in sorted(good):
            print('     %s' % k)
        print('  %d skipped:' % len(skipped))
        for k, w in skipped:
            print('     %-16s %s' % (k, w))
        return
    if args and args[0] == '--design':
        d = decode_design(args[1])
        model, variant, assign = d['m'], d.get('v', 'S'), d.get('a', {})
        print('decoded design: %s %s, %d slot assignments' % (model, variant, len(assign)))
    else:
        model = args[0] if args else 'MDL 4872'
        variant = args[1] if len(args) > 1 else 'S'
        assign = {}

    b = build(model, variant, assign)
    print('\n%s %s  "%s"' % (b['model'], b['variant'], b['label']))
    print('  exterior %g" x %g"   interior %g" x %g"' % (b['W'], b['H'], b['iw'], b['ih']))
    print('\n  %-18s %-5s %-7s %-26s %4s %s'
          % ('PART', 'SIDE', 'KIND', 'PACK', 'PTS', 'PLAN EXTENT'))
    for p in b['parts']:
        poly = poly_of(p)
        xs = [a for a, _ in poly]
        ys = [c for _, c in poly]
        print('  %-18s %-5s %-7s %-26s %4d  x %7.3f..%-7.3f y %7.3f..%-7.3f'
              % (p['id'], p['side'], p['slot_kind'], p['pack'] or '(default)',
                 len(poly), min(xs), max(xs), min(ys), max(ys)))
    print('\n  panels %d   seals %d   packing list %d   %s'
          % (b['placed'], sum(1 for p in b['parts'] if p['kind'] == 'seal'), b['bom_panels'],
             'AGREE' if b['placed'] == b['bom_panels'] else '*** MISMATCH ***'))
    for n in b['notes']:
        print('  NOTE: ' + n)

    scaled = [n for n in b['notes'] if '(scaled)' in n]
    if scaled and '--force' not in args:
        print('\n  REFUSING TO WRITE. %d wall(s) could not be resolved to real panel'
              ' lengths, so the geometry would be invented.' % len(scaled))
        print('  The run rule (panels + 2" per joint) is confirmed for the 46" module')
        print('  in Standard only. Enhanced is a double-wall build the rule does not')
        print('  describe, and the 40" module does not close either.')
        print('  Use --force to write it anyway, knowing the wall lengths are wrong.')
        return
    if b['placed'] != b['bom_panels']:
        print('\n  WARNING: panel count disagrees with the packing list — the layout and'
              ' the BOM are telling different stories for this model.')
    print('\n  wrote %s' % emit_ruby(b))


if __name__ == '__main__':
    main()
