# -*- coding: utf-8 -*-
"""WHICH END OF THE SIDE WALL THE WIDE PANEL LANDS ON -- both build paths, every key.

    python scripts/rbtest-side-wall-order.py

THE DEFECT THIS PINS (audit 2026-09-01 finding 1, C-1)
------------------------------------------------------
The four split-run booths - MDL 6060, 6084, 7272, 7296 - have an E and a W
wall made of exactly two panels of unequal width (40+16 or 46+22). Reverse
that pair and nothing measurable changes: the wall still closes, every panel
still reports `exact`, and the window, the vent and the seam seal are at the
other end of the booth. Two build paths reach WR_BuildBoothComponents
.build_booth:

    standalone   the panel's "Build from real components" button, which passes
                 ASSIGN[key] (build-booth-components.rb)
    share link   booth-from-link.rb, which passes the customer's own slot map
                 and never touches ASSIGN

On 2026-08-30 they disagreed with each other on all four models - one of the
two mirrored each booth - and no offline case noticed, because no offline case
exercised either path end to end. This file does.

BENTON'S RULING, 2026-09-02, which is the expectation here
-----------------------------------------------------------
"The wide floor section, the door frame and the wide side-wall panel all sit
at the same end - the door end - on every split-run model." One rule, both
families, both side walls, both shells:

    MDL 7272 / 7296  S and E    46 at y 2..48  (door end)   22 at y 50..72
    MDL 6060 / 6084  S and E    40 at y 2..42  (door end)   16 at y 44..60

WHAT RUNS
---------
SketchUp's own CRuby 3.2 (scripts/rbparse.py). The methods that decide the
outcome are LIFTED VERBATIM from the two scripts, so this harness cannot drift
from them:

    build-booth-components.rb   ASSIGN, guess_component, iep_nominal_width,
                                rebalance_walls, and the constants they read
    booth-from-link.rb          component_for, enh_width, v3_snap, v3_sku,
                                ENH_WIDTH, PANEL_WIDTHS, V3_MODELS (the module)

and scripts/wr-booth-data.rb is `load`ed as-is. Per catalogue key and per path
the harness does what build_booth's pass 1 does - resolve a name for every
slot, ASSIGN-or-guess on the standalone path, the customer's pack through
component_for on the link path - then hands the rows to the real
rebalance_walls and reads back where every E/W panel ended up.

The link path's packs are built the way a `#3=` link's are: every slot takes
its OWN drawn width, snapped by v3_snap and named by v3_sku (SOLID -> code 0,
VNT -> 1, DRFRM -> 3, right hinge). That is the catalogue-default booth with
no packages, which is what the standalone path is meant to build too.

THE ONE STAND-IN. There is no component library here, so classify()'s
measured width is replaced by the NOMINAL width the part's name declares -
'46VNT_VSS' is 46, 'ENH 41.5VNT' is 41.5 (iep_nominal_width, lifted). On a
Standard part that is exactly what wall_slab measures; on an ENH part it is
what rebalance_walls itself falls back to when the slab is not found. Nothing
else is stubbed.

WHAT IT ASSERTS
  1. DATA: on every E/W wall of every key, both shells, slot ids ascend with
     y. E0/W0 is the door-end slot everywhere - the id/position split that let
     an id-keyed ASSIGN and a position-keyed generator fight is gone.
  2. DATA: on every two-panel unequal E/W wall the wide slot is at low y, the
     door end, and the door frame (the S wall's DRFRM slot) is itself at low y.
  3. ASSIGN can never move a panel: every E/W name it assigns has the nominal
     width of the slot it is assigned to. Position is owned by the generator;
     ASSIGN only says WHICH part fills a slot.
  4. BOTH PATHS: for every key, every E/W wall, both shells, the standalone
     build and the link build put a panel of the same width at the same
     y-range, and the wide one is at the door end. rebalance_walls moves
     nothing on either path (no `rebalanced` line is printed).

Exit 0 when every check passes, 1 otherwise. The report lists the eight
split-run keys per path with the panel that landed at the door end.

MUTATION-CHECKED when written: put `'E0' => '22PanelSolid', 'E1' => '46VNT_VSS'`
back into ASSIGN['MDL 7272 S'] and check 3 fails on both slots and check 4
reports the 22 at the door end on the standalone path; put
SWAP_TWO_PANEL_SIDE_WALL = {40,16} back into gen-booth.py, regenerate, and
checks 1 and 2 fail on all four 60-series keys and the link path puts the 16
at the door end.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbparse  # noqa: E402
from rbtest import method_source  # noqa: E402

DATA_RB = os.path.join(HERE, 'wr-booth-data.rb').replace('\\', '/')
BUILDER = os.path.join(HERE, 'build-booth-components.rb')
LINK = os.path.join(HERE, 'booth-from-link.rb')

SPLIT_RUN = ['MDL 6060 S', 'MDL 6060 E', 'MDL 6084 S', 'MDL 6084 E',
             'MDL 7272 S', 'MDL 7272 E', 'MDL 7296 S', 'MDL 7296 E']

PROG = r'''
class Float
  def to_f; self; end
end
class Integer
  def to_f; self * 1.0; end
end

# rebalance_walls reports through puts. Captured so a move on either path is
# evidence in the report rather than noise on stdout.
$rb_log = []
module Kernel
  def puts(*a)
    a.flatten.each { |x| $rb_log << x.to_s }
    nil
  end
end

module WR_BuildBoothComponents
@@BUILDER_CONSTS@@

@@ASSIGN@@

  def self.inner?(part)
    part[:sh].to_s == 'in'
  end

@@IEP_NOMINAL_WIDTH@@

@@GUESS_COMPONENT@@

@@REBALANCE_WALLS@@
end

module WR_BoothLink
@@LINK_CONSTS@@

@@ENH_WIDTH_FN@@

@@COMPONENT_FOR@@

@@V3_SNAP@@

@@V3_SKU@@
end

load '@@DATA_RB@@'

module Harness
  B = WR_BuildBoothComponents
  L = WR_BoothLink
  NO_OPTS = { :vss => false, :efs => false, :casters => false, :ramp => false }

  def self.extent(poly, axis)
    vs = poly.map { |q| q[axis].to_f }
    [vs.min, vs.max]
  end

  def self.slot_run(p)
    xs = extent(p[:poly], 0)
    ys = extent(p[:poly], 1)
    [xs[1] - xs[0], ys[1] - ys[0]].max
  end

  # classify()'s measured width, stood in for by the nominal the name declares.
  def self.nominal_width(name)
    B.iep_nominal_width(name) || (name.to_s[/\d+(?:\.\d+)?/] || '0').to_f
  end

  # The share-link path's slot map for the catalogue-default booth: every
  # OUTER slot takes its own drawn width, snapped and named exactly as a #3=
  # link would carry it, and an Enhanced key translates each slot twice.
  def self.link_assign(key, spec)
    model = key.sub(/ [SE]\z/, '')
    mod = (L::V3_MODELS.find { |m, _| m == model } || [nil, nil])[1]
    raise "#{key}: not in V3_MODELS, no module width" if mod.nil?
    enh = key.end_with?(' E')
    assign = {}
    spec[:parts].each do |p|
      next unless p[:k] == 'panel' && !B.inner?(p)
      code = case p[:sk]
             when 'VNT' then 1
             when 'DRFRM' then 3
             else 0
             end
      pack = L.v3_sku(code, L.v3_snap(slot_run(p), mod), mod, 'R')
      assign[p[:id]] = L.component_for(pack, NO_OPTS, false)
      assign["#{p[:id]}i"] = L.component_for(pack, NO_OPTS, true) if enh
    end
    assign
  end

  # build_booth pass 1, minus the library: a name per slot, then the rows
  # rebalance_walls reads.
  def self.rows_for(spec, assign)
    spec[:parts].map do |p|
      inn = B.inner?(p)
      name = if p[:k] == 'corner' then (inn ? B::ENH_CORNER_COMP : B::CORNER_COMP)
             elsif p[:k] == 'seal' then (inn ? B::ENH_SEAL_COMP : B::SEAL_COMP)
             else assign[p[:id]]
             end
      name = B.guess_component(p[:sk], slot_run(p), inn) if name.nil?
      poly = p[:poly].map { |q| [q[0].to_f, q[1].to_f] }
      { :part => { :k => p[:k], :id => p[:id], :sh => p[:sh], :sk => p[:sk], :poly => poly },
        :name => name, :cls => { :w => nominal_width(name) }, :slab => nil }
    end
  end

  # One line per E/W panel: key|path|id|shell|name|w|y0|y1
  def self.walk(key, path, assign)
    spec = WR_BOOTH_DATA::BOOTHS[key]
    rows = rows_for(spec, assign)
    $rb_log.clear
    B.rebalance_walls(rows)
    moved = $rb_log.select { |l| l.include?('rebalanced') || l.include?('does not close') }
    out = rows.select { |r| r[:part][:k] == 'panel' && %w[E W].include?(r[:part][:id][0, 1]) }
              .map do |r|
      p = r[:part]
      y = extent(p[:poly], 1)
      format('%s|%s|%s|%s|%s|%.3f|%.3f|%.3f', key, path, p[:id], p[:sh], r[:name],
             r[:cls][:w], y[0], y[1])
    end
    out + moved.map { |l| format('%s|%s|MOVED|%s', key, path, l.strip) }
  end

  def self.door_lines
    WR_BOOTH_DATA::BOOTHS.map do |key, spec|
      d = spec[:parts].find { |p| p[:k] == 'panel' && p[:sk] == 'DRFRM' && !B.inner?(p) }
      y = d ? extent(d[:poly], 1) : [-1, -1]
      x = d ? extent(d[:poly], 0) : [-1, -1]
      format('%s|DOOR|%s|%.3f|%.3f|%.3f|%.3f', key, d ? d[:id] : '-', x[0], x[1], y[0], y[1])
    end
  end

  def self.assign_lines
    B::ASSIGN.flat_map do |key, map|
      spec = WR_BOOTH_DATA::BOOTHS[key]
      map.select { |id, _| %w[E W].include?(id[0, 1]) }.map do |id, name|
        p = spec[:parts].find { |q| q[:id] == id }
        format('%s|ASSIGN|%s|%s|%.3f|%.3f', key, id, name,
               nominal_width(name), p ? slot_run(p) : -1.0)
      end
    end
  end

  def self.run
    lines = door_lines + assign_lines
    WR_BOOTH_DATA::BOOTHS.keys.sort.each do |key|
      spec = WR_BOOTH_DATA::BOOTHS[key]
      lines += walk(key, 'standalone', B::ASSIGN[key] || {})
      lines += walk(key, 'link', link_assign(key, spec))
    end
    lines.join("\n")
  end
end

(begin
  Harness.run
rescue Exception => e
  'FAIL ' + e.message + "\n" + e.backtrace.to_a.first(8).join("\n")
end).dup
'''

FAILS = []
CHECKS = [0]


def ck(label, got, want):
    CHECKS[0] += 1
    if got != want:
        FAILS.append('%s\n      got  %r\n      want %r' % (label, got, want))


def const_lines(path, names):
    text = open(path, encoding='utf-8').read()
    out = []
    for name in names:
        m = re.search(r'^  %s\s*=.*?(?:\.freeze)?$' % re.escape(name), text, re.M)
        if not m:
            raise SystemExit('%s: constant %s not found' % (os.path.basename(path), name))
        out.append(m.group(0))
    return '\n'.join(out)


def multiline_const(path, name):
    """A constant whose literal spans lines, up to the line ending `.freeze`."""
    text = open(path, encoding='utf-8').read()
    m = re.search(r'^  %s\s*=.*?\}\.freeze$' % re.escape(name), text, re.M | re.S)
    if not m:
        raise SystemExit('%s: constant %s not found' % (os.path.basename(path), name))
    return m.group(0)


def array_const(path, name):
    """A constant whose array literal spans lines, up to the line `].freeze`."""
    text = open(path, encoding='utf-8').read()
    m = re.search(r'^  %s\s*=.*?\]\.freeze$' % re.escape(name), text, re.M | re.S)
    if not m:
        raise SystemExit('%s: constant %s not found' % (os.path.basename(path), name))
    return m.group(0)


def build_program():
    prog = (PROG
            .replace('@@DATA_RB@@', DATA_RB)
            .replace('@@BUILDER_CONSTS@@',
                     const_lines(BUILDER, ['SEAL_COMP', 'CORNER_COMP', 'ENH_SEAL_COMP',
                                           'ENH_CORNER_COMP', 'ENH_PLAIN_PANEL',
                                           'IEP_SEAL_W', 'SLAB_NOISE']))
            .replace('@@ASSIGN@@', multiline_const(BUILDER, 'ASSIGN'))
            .replace('@@IEP_NOMINAL_WIDTH@@', method_source(BUILDER, 'iep_nominal_width'))
            .replace('@@GUESS_COMPONENT@@', method_source(BUILDER, 'guess_component'))
            .replace('@@REBALANCE_WALLS@@', method_source(BUILDER, 'rebalance_walls'))
            .replace('@@LINK_CONSTS@@',
                     multiline_const(LINK, 'ENH_WIDTH') + '\n' +
                     const_lines(LINK, ['PANEL_WIDTHS']) + '\n' +
                     array_const(LINK, 'V3_MODELS'))
            .replace('@@ENH_WIDTH_FN@@', method_source(LINK, 'enh_width'))
            .replace('@@COMPONENT_FOR@@', method_source(LINK, 'component_for'))
            .replace('@@V3_SNAP@@', method_source(LINK, 'v3_snap'))
            .replace('@@V3_SKU@@', method_source(LINK, 'v3_sku')))
    return prog


def main():
    got = rbparse.rb_eval(rbparse.boot(), build_program())
    if got.startswith('FAIL '):
        print(got)
        return 1

    doors, assigns, walls, moved = {}, [], {}, []
    for line in got.split('\n'):
        f = line.split('|')
        if len(f) > 1 and f[1] == 'DOOR':
            doors[f[0]] = (f[2], float(f[3]), float(f[4]), float(f[5]), float(f[6]))
        elif len(f) > 1 and f[1] == 'ASSIGN':
            assigns.append((f[0], f[2], f[3], float(f[4]), float(f[5])))
        elif len(f) > 2 and f[2] == 'MOVED':
            moved.append((f[0], f[1], f[3]))
        elif len(f) == 8:
            key, path, pid, shell, name, w, y0, y1 = f
            walls.setdefault((key, path, pid[0], shell), []).append(
                (pid, name, float(w), float(y0), float(y1)))

    keys = sorted(doors)
    ck('the data file loaded and every key reports its door', len(keys) >= 50, True)

    # 1 + 2: the generated data itself.
    for key in keys:
        did, _x0, _x1, dy0, _dy1 = doors[key]
        # The door is an S-wall slot on every catalogue model (layout.door.wall),
        # but not always slot 0: the 84102 carries it in S2, the 84126 in S1.
        ck('%s: door frame (%s, DRFRM) sits on the low-y S wall' % (key, did),
           (did[0], dy0 < 10.0), ('S', True))
        for wall in ('E', 'W'):
            for shell in ('out', 'in'):
                panels = walls.get((key, 'link', wall, shell))
                if panels is None:
                    continue
                by_y = sorted(panels, key=lambda r: r[3])
                ids = [int(re.sub(r'\D', '', r[0])) for r in by_y]
                ck('%s %s %s: slot ids ascend with y (slot 0 at the door end)' % (key, wall, shell),
                   ids, sorted(ids))
                if len(by_y) == 2 and abs(by_y[0][4] - by_y[0][3] - (by_y[1][4] - by_y[1][3])) > 0.01:
                    wide = max(by_y, key=lambda r: r[4] - r[3])
                    ck('%s %s %s: the WIDE slot is at the door end' % (key, wall, shell),
                       wide[0], by_y[0][0])

    # 3: ASSIGN names a part of the slot's own width, so it can never move one.
    ck('ASSIGN still carries E/W entries to check (the 7272 window and VSS vent)',
       len(assigns) > 0, True)
    for key, pid, name, w, slot_w in assigns:
        ck('ASSIGN[%r][%r] = %r: nominal %g matches its slot %g' % (key, pid, name, w, slot_w),
           abs(w - slot_w) < 0.01, True)

    # 4: both paths, every key, every side wall, both shells.
    ck('rebalance_walls moved nothing on either path', moved, [])
    for key in keys:
        for wall in ('E', 'W'):
            for shell in ('out', 'in'):
                a = walls.get((key, 'standalone', wall, shell))
                b = walls.get((key, 'link', wall, shell))
                if a is None and b is None:
                    continue
                pos_a = sorted((r[3], r[4], r[2]) for r in (a or []))
                pos_b = sorted((r[3], r[4], r[2]) for r in (b or []))
                ck('%s %s %s: standalone and link put the same widths at the same y'
                   % (key, wall, shell), pos_a, pos_b)
                if len(pos_a) == 2 and abs((pos_a[0][1] - pos_a[0][0]) - (pos_a[1][1] - pos_a[1][0])) > 0.01:
                    wide_a = max(pos_a, key=lambda r: r[1] - r[0])
                    ck('%s %s %s: STANDALONE puts the wide panel (%g) at the door end'
                       % (key, wall, shell, wide_a[2]), wide_a[0], pos_a[0][0])
                if len(pos_b) == 2 and abs((pos_b[0][1] - pos_b[0][0]) - (pos_b[1][1] - pos_b[1][0])) > 0.01:
                    wide_b = max(pos_b, key=lambda r: r[1] - r[0])
                    ck('%s %s %s: LINK puts the wide panel (%g) at the door end'
                       % (key, wall, shell, wide_b[2]), wide_b[0], pos_b[0][0])

    # The report: what landed at the door end on the eight split-run keys.
    print('SIDE-WALL ORDER - the panel at the DOOR end of each side wall (outer shell)')
    print('')
    print('  %-12s %-11s %-28s %-28s' % ('key', 'path', 'E wall, door end', 'W wall, door end'))
    for key in SPLIT_RUN:
        for path in ('standalone', 'link'):
            cells = []
            for wall in ('E', 'W'):
                panels = sorted(walls.get((key, path, wall, 'out'), []), key=lambda r: r[3])
                if panels:
                    p = panels[0]
                    cells.append('%s %s y %g..%g' % (p[0], p[1], p[3], p[4]))
                else:
                    cells.append('-')
            print('  %-12s %-11s %-28s %-28s' % (key, path, cells[0], cells[1]))
    if moved:
        print('')
        print('  rebalance_walls MOVED panels:')
        for key, path, line in moved:
            print('    %-12s %-11s %s' % (key, path, line))
    print('')
    if FAILS:
        print('%d of %d checks FAILED:' % (len(FAILS), CHECKS[0]))
        for f in FAILS:
            print('  ' + f)
        return 1
    print('%d checks PASS' % CHECKS[0])
    return 0


if __name__ == '__main__':
    sys.exit(main())
