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
import json, os, re, sys, base64

QUOTE = r'C:\Users\bento\Documents\Claude\WhisperRoomQuote\lib\pl-data'
OUT_DIR = r'C:\Users\bento\Documents\Claude\Sketchup\scripts'

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
    t = float(L['variants'][variant]['wallThickness'])
    inner = L['variants'][variant]['interior']
    iw, ih = float(inner['w']), float(inner['h'])

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
                x, y = (W - t if side == 'E' else t - PANEL_T), cursor
                dx, dy = PANEL_T, ln
            parts.append(dict(kind='panel', id=slot['id'], side=side, slot_kind=slot['kind'],
                              pack=pack, length=ln,
                              x=round(x, 3), y=round(y, 3), dx=round(dx, 3), dy=round(dy, 3)))
            cursor += ln
            if i < len(lengths) - 1:
                # Mid-wall seam seal, in two pieces:
                #   stem  — 2" wide, fills the gap; the panels butt into its sides
                #   plate — 7 3/4" wide, in the 1" band outboard of the panel face
                band = t - PANEL_T
                mid = cursor + SEAL_W / 2.0
                half = SEAL_PLATE / 2.0
                if side in ('N', 'S'):
                    py = (H - band) if side == 'N' else 0.0
                    parts.append(dict(kind='seal', id='%s-seal%d stem' % (side, i), side=side,
                                      slot_kind='SEAL', pack='Std mid-wall seam seal (stem)',
                                      length=SEAL_W, x=round(cursor, 3), y=round(y, 3),
                                      dx=SEAL_W, dy=PANEL_T))
                    parts.append(dict(kind='seal', id='%s-seal%d plate' % (side, i), side=side,
                                      slot_kind='SEAL', pack='Std mid-wall seam seal (plate)',
                                      length=SEAL_PLATE, x=round(mid - half, 3), y=round(py, 3),
                                      dx=SEAL_PLATE, dy=band))
                else:
                    px = (W - band) if side == 'E' else 0.0
                    parts.append(dict(kind='seal', id='%s-seal%d stem' % (side, i), side=side,
                                      slot_kind='SEAL', pack='Std mid-wall seam seal (stem)',
                                      length=SEAL_W, x=round(x, 3), y=round(cursor, 3),
                                      dx=PANEL_T, dy=SEAL_W))
                    parts.append(dict(kind='seal', id='%s-seal%d plate' % (side, i), side=side,
                                      slot_kind='SEAL', pack='Std mid-wall seam seal (plate)',
                                      length=SEAL_PLATE, x=round(px, 3), y=round(mid - half, 3),
                                      dx=band, dy=SEAL_PLATE))
                cursor += SEAL_W

    # Corner seam seals — L-shaped, 4 7/8" legs, sitting in the same outboard band
    # as the mid-wall plates. Modelled as two rectangular legs meeting at the
    # corner: the outer profile is exact; the small inner step on the drawing is
    # not modelled.
    band = t - PANEL_T
    for cx, cy, sx, sy, name in ((0.0, 0.0, 1, 1, 'SW'), (W, 0.0, -1, 1, 'SE'),
                                 (0.0, H, 1, -1, 'NW'), (W, H, -1, -1, 'NE')):
        ax = cx if sx > 0 else cx - CORNER
        ay = cy if sy > 0 else cy - band
        parts.append(dict(kind='corner', id='%s corner' % name, side=name, slot_kind='CORNER',
                          pack='Std corner seam seal', length=CORNER,
                          x=round(ax, 3), y=round(ay, 3), dx=CORNER, dy=band))
        bx = cx if sx > 0 else cx - band
        by = cy if sy > 0 else cy - CORNER
        parts.append(dict(kind='corner', id='%s corner' % name, side=name, slot_kind='CORNER',
                          pack='Std corner seam seal', length=CORNER,
                          x=round(bx, 3), y=round(by, 3), dx=band, dy=CORNER))

    # The BOM counts BOXES, and some boxes hold two panels — the 16" wall ships
    # 2-per-box. components-master's desc starts with that count ("2 - STD WALL
    # COMPONENT"), so expand by it. layout-render.js does the same thing in
    # expandWallBoxes(); without it every 40-module booth looks short by the
    # number of 2-packs it carries.
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
    placed = sum(1 for p in parts if p['kind'] == 'panel')

    return dict(model=model, variant=variant, W=W, H=H, t=t, iw=iw, ih=ih,
                parts=parts, notes=notes, bom_panels=bom_panels, placed=placed,
                label=L.get('label', ''))


def emit_ruby(b):
    slug = (b['model'].replace('MDL ', '').strip() + '-' + b['variant']).lower()
    path = os.path.join(OUT_DIR, 'booth-%s.rb' % slug)
    rows = ',\n'.join(
        '    { :k=>%r, :id=>%r, :side=>%r, :sk=>%r, :pack=>%s, :x=>%s, :y=>%s, :dx=>%s, :dy=>%s }'
        % (p['kind'], p['id'], p['side'], p['slot_kind'],
           ('%r' % p['pack']) if p['pack'] else 'nil', p['x'], p['y'], p['dx'], p['dy'])
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
            '{ :k=>%r, :id=>%r, :sk=>%r, :x=>%s, :y=>%s, :dx=>%s, :dy=>%s }'
            % (p['kind'], p['id'], p['slot_kind'], p['x'], p['y'], p['dx'], p['dy'])
            for p in b['parts'])
        rows.append('''    %r => { :label=>%r, :w=>%s, :h=>%s, :iw=>%s, :ih=>%s, :ph=>81.0,
      :parts => [
        %s
      ] }''' % (key, b['label'], b['W'], b['H'], b['iw'], b['ih'], parts))

    path = os.path.join(OUT_DIR, 'wr-booth-data.rb')
    with open(path, 'w', encoding='utf-8') as f:
        f.write('# GENERATED by scripts/gen-booth.py --all — do not hand-edit.\n'
                '# Every booth whose assembly the run rule can prove:\n'
                '#   interior run = sum(panel lengths) + 2" per joint\n'
                '# Panels 1" thick, 81" tall. Read by build-booth.rb.\n'
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
    print('\n  %-10s %-5s %-7s %-28s %8s %8s %7s %7s'
          % ('PART', 'SIDE', 'KIND', 'PACK', 'X', 'Y', 'DX', 'DY'))
    for p in b['parts']:
        print('  %-10s %-5s %-7s %-28s %8.3f %8.3f %7.3f %7.3f'
              % (p['id'], p['side'], p['slot_kind'], p['pack'] or '(default)',
                 p['x'], p['y'], p['dx'], p['dy']))
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
