# -*- coding: utf-8 -*-
"""RUN WR_ExplodeView.booth_plan outside SketchUp and check the exploded booth.

    python rbtest-explode.py

Same discipline as rbtest.py: boots SketchUp's own CRuby 3.2 through
rbparse.py, lifts `booth_plan`, `bp_shift` and the BP_* / OUTWARD constants
VERBATIM out of explode-view.rb (so the test cannot drift from the code), and
runs them against the home bounding boxes of two real booths.

WHY IT EXISTS
-------------
Reported 24 Sep 2026 by Benton, with screenshots: exploding a booth gave a
scramble. Wall panels crossed, each wall's two skins interpenetrated, the door
frame was left behind by its door, the floor scattered sideways, the ceiling
panels piled up at different heights, seals flew off alone. Root cause: every
part was planned ALONE - its own direction off its own flattest axis, its own
distance growing with its distance from the centre, then a fan that scaled it
about whatever co-planar run it landed in. booth_plan plans by assembly.

THE FIXTURES are the top-level parts of two booths read out of a live model
over the SketchUp bridge on 24 Sep 2026, at home, in the booth's own frame:
  ENH144  a 144144 E brought in as ONE component (100 parts, door standing
          open, both skins, duct-box walls) - the reported case;
  STD7272 a 7272 S built by the booth builder as a group (28 parts).

WHAT IT ASSERTS, per booth:
  1. every part is planned; no part is left unplaced
  2. the group counts (floor / each wall / corners / ceiling) are as read
  3. the FLOOR does not rise or drop, and opens out less than one wall gap
  4. every WALL part travels exactly the wall travel along its own outward
     normal and not at all vertically; the CEILING lifts exactly that far
  5. a follower (seal, strip, lockset, bracket) moves exactly with its owner
  6. no two parts that were clear of each other at home overlap exploded
  7. no two parts from DIFFERENT groups overlap exploded
  8. along each wall, panel columns open by the same gap at every joint
  9. named pairs move together (door leaf with its frame, lockset with door)
 10. the same input gives the same answer, and travel scales with Spread

MUTATION-CHECKED: see .forge/fixer/explode-view/HANDOFF.md for which
deliberate breaks of booth_plan this was seen to catch.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbparse  # noqa: E402
from rbtest import method_source  # noqa: E402

SHIMS = r'''
class Float
  def to_f; self; end
end
class Integer
  def to_f; self * 1.0; end
  def to_i; self; end
end
'''

# Plain str.replace markers rather than % formatting: the Ruby below is full
# of format strings of its own.
CHECK = r'''
module WR_ExplodeView
@@CONSTS@@

@@BOOTH_PLAN@@

@@BP_SHIFT@@
end

module T
@@FIXTURES@@

  def self.ov(a, b)
    (0..2).all? { |i| [a[1][i], b[1][i]].min - [a[0][i], b[0][i]].max > 0.05 }
  end

  def self.moved(b, o)
    [(0..2).map { |i| b[0][i] + o[i] }, (0..2).map { |i| b[1][i] + o[i] }]
  end

  def self.run(label, rows, spread, fan, want_counts, same)
    boxes = rows.map { |r| [r[1], r[2]] }
    bp = WR_ExplodeView.booth_plan(boxes, spread, fan)
    return label + ': FAIL not read as a booth' if bp.nil?
    n = rows.length
    off = bp[:off]
    d = bp[:d]
    g = bp[:g]
    kind = bp[:kind]
    own = bp[:owner]
    fails = []
    eff = (0...n).map { |i| kind[i] == :attached && own[i] ? kind[own[i]] : kind[i] }
    sid = (0...n).map { |i| bp[:side][own[i] || i] }
    key = (0...n).map { |i| eff[i] == :wall ? 'wall ' + sid[i].to_s : eff[i].to_s }

    # 1 + 2
    un = (0...n).select { |i| eff[i] == :attached }
    fails << "unplaced: #{un.map { |i| rows[i][0] }.join(', ')}" unless un.empty?
    tally = Hash.new(0)
    key.each { |k| tally[k] += 1 }
    got_counts = tally.keys.sort.map { |k| "#{k}=#{tally[k]}" }.join(' ')
    fails << "groups #{got_counts} (want #{want_counts})" if got_counts != want_counts

    (0...n).each do |i|
      o = off[i]
      nm = rows[i][0]
      case eff[i]
      when :floor
        fails << "floor moves vertically: #{nm}" if o[2] != 0.0
        fails << "floor drifts #{o[0].round(1)},#{o[1].round(1)}: #{nm}" if o[0].abs > g || o[1].abs > g
      when :ceiling
        fails << "ceiling lift #{o[2]} != #{d}: #{nm}" if (o[2] - d).abs > 1e-9
      when :wall
        u = WR_ExplodeView::OUTWARD[sid[i]]
        out = o[0] * u[0] + o[1] * u[1]
        fails << "wall travel #{out.round(3)} != #{d.round(3)}: #{nm}" if (out - d).abs > 1e-9
        fails << "wall part moves vertically: #{nm}" if o[2] != 0.0
      end
      fails << "follower off its owner: #{nm}" if own[i] && off[i] != off[own[i]]
    end

    # 6 + 7
    exp = (0...n).map { |i| moved(boxes[i], off[i]) }
    newov = []
    cross = []
    (0...n).each do |i|
      ((i + 1)...n).each do |j|
        next unless ov(exp[i], exp[j])
        newov << "#{rows[i][0]} X #{rows[j][0]}" unless ov(boxes[i], boxes[j])
        cross << "#{rows[i][0]} [#{key[i]}] X #{rows[j][0]} [#{key[j]}]" if key[i] != key[j]
      end
    end
    fails << "new overlaps (#{newov.length}): #{newov.first(4).join('; ')}" unless newov.empty?
    fails << "cross-group overlaps (#{cross.length}): #{cross.first(4).join('; ')}" unless cross.empty?

    # 8
    [:w, :e, :s, :n].each do |sd|
      ax = WR_ExplodeView::OUTWARD[sd][0] == 0.0 ? 0 : 1
      mem = (0...n).select do |i|
        kind[i] == :wall && sid[i] == sd &&
          (boxes[i][1][ax] - boxes[i][0][ax]) >= WR_ExplodeView::BP_PANEL_MIN
      end
      sh = mem.map { |i| off[i][ax].round(9) }.uniq.sort
      steps = sh.each_cons(2).map { |a, b| b - a }
      bad = steps.reject { |s| (s - g).abs < 1e-6 }
      fails << "wall #{sd} joints open unevenly: #{steps.map { |s| s.round(2) }.inspect}" unless bad.empty?
    end

    # 9
    same.each do |a, b|
      ia = rows.index { |r| r[0] == a }
      ib = rows.index { |r| r[0] == b }
      if ia.nil? || ib.nil?
        fails << "fixture has no #{a} / #{b}"
      elsif off[ia] != off[ib]
        fails << "#{a} and #{b} part company"
      end
    end

    # 10
    fails << 'not deterministic' if WR_ExplodeView.booth_plan(boxes, spread, fan)[:off] != off
    d2 = WR_ExplodeView.booth_plan(boxes, spread * 1.5, fan)[:d]
    fails << 'travel does not scale with spread' if (d2 - 1.5 * d).abs > 1e-9

    head = format('%s: %d parts, walls out %.1f in, ceiling up %.1f in, joint gap %.1f in',
                  label, n, d, d, g)
    fails.empty? ? head + ' - PASS' : head + ' - FAIL ' + fails.join(' | ')
  end

  ENH_COUNTS = 'ceiling=12 corner=8 floor=34 wall e=10 wall n=11 wall s=15 wall w=10'.freeze

  def self.all
    [run('ENH144', ENH144, 0.6, 1.5, ENH_COUNTS,
         [['WA door', 'WA door frame with HX'], ['WA IEP door', 'WA door frame with HX'],
          ['Lockset with IEP spacer', 'WA door'],
          ['WA door frame adaptor (right)', 'WA door frame with HX'],
          ['WA IEP jamb', 'WA door frame with HX']]),
     run('ENH144 spread 150 fan 0', ENH144, 1.5, 0.0, ENH_COUNTS, []),
     run('ENH144 spread 20 fan 400', ENH144, 0.2, 4.0, ENH_COUNTS, []),
     # Fan at the tool's own ceiling (1000%): only the gap cap keeps each
     # wall's end panels out of the next wall.
     run('ENH144 spread 20 fan 1000', ENH144, 0.2, 10.0, ENH_COUNTS, []),
     run('STD7272', STD7272, 0.6, 1.5,
         'ceiling=3 corner=4 floor=3 wall e=6 wall n=6 wall s=3 wall w=3',
         [['Duct Cover lo  N0', 'N0  46VNT_VSS'], ['Foam  E0', 'E0  46VNT_VSS']])].join("\n")
  end
end

(begin
  T.all
rescue Exception => e
  'FAIL ' + e.message
end).dup
'''


def consts(path):
    """The BP_* and OUTWARD constant lines, verbatim."""
    out = []
    for ln in open(path, encoding='utf-8').read().split('\n'):
        if re.match(r'^  (BP_[A-Z_]+|OUTWARD)\s*=', ln):
            out.append(ln)
    if not out:
        raise SystemExit('explode-view.rb: no BP_* constants found')
    return '\n'.join(out)


def main():
    src = os.path.join(HERE, 'explode-view.rb')
    prog = SHIMS + (CHECK
                    .replace('@@CONSTS@@', consts(src))
                    .replace('@@BOOTH_PLAN@@', method_source(src, 'booth_plan'))
                    .replace('@@BP_SHIFT@@', method_source(src, 'bp_shift'))
                    .replace('@@FIXTURES@@', FIXTURES))
    lib = rbparse.boot()
    got = rbparse.rb_eval(lib, prog)
    print('booth_plan: two real booths exploded by assembly')
    lines = got.split('\n')
    for ln in lines:
        print('  ' + ln)
    ok = bool(got) and all(ln.endswith('PASS') for ln in lines)
    print('  PASS' if ok else '  FAIL')
    return 0 if ok else 1


# Home boxes, [name, [min xyz], [max xyz]], inches, in each booth's own frame.
FIXTURES = r'''
  ENH144 = [
    ['GoPro Iep ceiling (192192) assembled', [13.333, 34.279, 93.563], [159.333, 180.279, 95.313]],
    ['WA door frame with HX', [108.333, 34.779, 2.312], [157.333, 37.529, 93.313]],
    ['WA IEP jamb', [110.583, 37.553, 3.062], [155.083, 38.553, 92.562]],
    ['Standard mid-wall seam seal#2', [157.333, 127.404, 2.312], [159.333, 135.154, 93.312]],
    ['Std wall (46 in Vnt)#3', [157.333, 84.279, 2.312], [158.333, 130.279, 93.312]],
    ['GoPro Std wall for TVs', [111.333, 178.154, 2.312], [157.333, 193.612, 93.312]],
    ['Std wall (46 in Vnt)#3', [157.333, 132.279, 2.312], [158.333, 178.279, 93.312]],
    ['GoPro Std wall for TVs#2', [63.333, 35.279, 2.313], [106.333, 36.279, 93.313]],
    ['GoPro Std wall for TVs', [15.333, 178.154, 2.312], [61.333, 193.612, 93.312]],
    ['GoPro Std wall for TVs', [-0.000, 84.279, 2.313], [15.458, 130.279, 93.313]],
    ['WA door frame adaptor (right)', [113.458, 36.529, 2.562], [152.208, 37.529, 4.812]],
    ['Standard mid-wall seam seal#2', [103.458, 34.279, 2.313], [111.208, 36.279, 93.313]],
    ['Standard corner seam seal#2', [154.458, 34.279, 2.312], [159.333, 39.154, 93.312]],
    ['GoPro Std wall for TVs', [-0.000, 36.279, 2.313], [15.458, 82.279, 93.313]],
    ['Standard mid-wall seam seal#2', [13.333, 127.404, 2.313], [15.333, 135.154, 93.313]],
    ['Standard corner seam seal#2', [13.333, 175.404, 2.312], [18.208, 180.279, 93.312]],
    ['GoPro Std wall for TVs', [63.333, 178.154, 2.312], [109.333, 193.612, 93.312]],
    ['Standard mid-wall seam seal#2', [13.333, 79.404, 2.313], [15.333, 87.154, 93.313]],
    ['Standard mid-wall seam seal#2', [106.458, 178.279, 2.312], [114.208, 180.279, 93.312]],
    ['WA door', [148.511, -0.000, 7.262], [151.011, 35.373, 82.513]],
    ['GoPro Std wall for TVs', [-0.000, 132.279, 2.312], [15.458, 178.279, 93.313]],
    ['Standard corner seam seal#2', [154.458, 175.404, 2.312], [159.333, 180.279, 93.312]],
    ['Std wall (46 in Vnt)#3', [15.333, 35.279, 2.313], [61.333, 36.279, 93.313]],
    ['Standard mid-wall seam seal#2', [58.458, 34.279, 2.313], [66.208, 36.279, 93.313]],
    ['Std wall (46 in Vnt)#3', [157.333, 36.279, 2.312], [158.333, 82.279, 93.312]],
    ['Standard mid-wall seam seal#2', [157.333, 79.404, 2.312], [159.333, 87.154, 93.312]],
    ['Lockset with IEP spacer', [146.136, 0.437, 41.950], [152.511, 7.487, 47.950]],
    ['Standard corner seam seal#2', [13.333, 34.279, 2.313], [18.208, 39.154, 93.313]],
    ['Standard mid-wall seam seal#2', [58.458, 178.279, 2.312], [66.208, 180.279, 93.312]],
    ['Component#7', [14.458, 130.533, 1.312], [85.646, 132.033, 2.375]],
    ['Component#7', [87.021, 130.498, 1.312], [158.208, 131.998, 2.375]],
    ['Floor seam seal system 96 in Assembled#1', [85.631, 35.404, 1.312], [87.131, 179.154, 2.378]],
    ['Component#7', [14.475, 82.533, 1.312], [85.662, 84.033, 2.375]],
    ['Component#7', [87.021, 82.498, 1.312], [158.208, 83.998, 2.375]],
    ['GoPro IEP Wall Window solid for TVs', [113.591, 175.904, 3.062], [155.208, 178.279, 92.562]],
    ['IEP mid-wall seam seal (tall)', [15.608, 125.162, 3.062], [17.608, 137.412, 92.562]],
    ['IEP mid-wall seam seal (tall)', [104.216, 176.029, 3.062], [116.466, 178.029, 92.562]],
    ['WA IEP door', [146.745, 1.487, 8.262], [148.495, 33.987, 81.513]],
    ['GoPro IEP Wall Window solid for TVs#4', [155.083, 38.428, 3.062], [157.083, 80.045, 92.562]],
    ['GoPro IEP Wall Window solid for TVs', [15.358, 134.537, 3.062], [17.733, 176.154, 92.562]],
    ['GoPro IEP Wall Window solid for TVs#3', [65.583, 37.553, 3.062], [104.083, 38.553, 92.562]],
    ['GoPro IEP Wall Window solid for TVs#4', [155.083, 134.412, 3.062], [157.083, 176.029, 92.562]],
    ['IEP corner seam seal (tall)', [152.208, 173.154, 3.062], [157.083, 178.029, 92.562]],
    ['IEP corner seam seal (tall)', [15.608, 173.154, 3.062], [20.483, 178.029, 92.562]],
    ['GoPro IEP Wall Window solid for TVs#4', [155.083, 86.420, 3.062], [157.083, 128.037, 92.562]],
    ['IEP mid-wall seam seal (tall)', [155.083, 77.170, 3.062], [157.083, 89.420, 92.562]],
    ['GoPro IEP Wall Window solid for TVs#4', [17.466, 36.553, 3.062], [59.083, 38.553, 92.562]],
    ['GoPro IEP Wall Window solid for TVs#6', [65.599, 175.904, 3.062], [107.216, 178.279, 92.562]],
    ['IEP corner seam seal (tall)', [15.591, 36.553, 3.062], [20.466, 41.428, 92.562]],
    ['IEP mid-wall seam seal (tall)', [56.224, 176.029, 3.062], [68.474, 178.029, 92.562]],
    ['IEP corner seam seal (tall)', [152.208, 36.553, 3.062], [157.083, 41.428, 92.562]],
    ['IEP mid-wall seam seal (tall)', [101.208, 36.553, 3.062], [113.458, 38.553, 92.562]],
    ['IEP mid-wall seam seal (tall)', [15.608, 77.170, 3.062], [17.608, 89.420, 92.562]],
    ['IEP mid-wall seam seal (tall)', [56.208, 36.553, 3.062], [68.458, 38.553, 92.562]],
    ['IEP mid-wall seam seal (tall)', [155.083, 125.162, 3.062], [157.083, 137.412, 92.562]],
    ['GoPro IEP Wall Window solid for TVs', [15.358, 86.545, 3.062], [17.733, 128.162, 92.562]],
    ['GoPro IEP Wall Window solid for TVs', [17.608, 175.904, 3.062], [59.224, 178.279, 92.562]],
    ['GoPro IEP Wall Window solid for TVs', [15.358, 38.553, 3.062], [17.733, 80.170, 92.562]],
    ['GoPro IEP FLOOR (192192)#1', [68.333, 35.279, 1.000], [104.333, 179.279, 1.313]],
    ['GoPro IEP FLOOR (192192)', [14.333, 35.279, 1.000], [68.333, 179.279, 1.313]],
    ['GoPro IEP FLOOR (192192)', [104.333, 35.279, 1.000], [158.333, 179.279, 1.313]],
    ['Ceiling component (4896) CNR', [110.333, 35.279, 91.205], [158.333, 107.279, 94.313]],
    ['Ceiling component (4896) CNR', [110.333, 107.279, 91.205], [158.333, 179.279, 94.313]],
    ['Ceiling component (4896) CTR', [62.333, 35.279, 91.205], [110.333, 107.279, 94.313]],
    ['Ceiling component (4896) CNR', [14.333, 107.279, 91.205], [62.333, 179.279, 94.313]],
    ['Ceiling component (4896) CNR', [14.333, 35.279, 91.205], [62.333, 107.279, 94.313]],
    ['Ceiling component (4896) CTR', [62.333, 107.279, 91.205], [110.333, 179.279, 94.313]],
    ['Ceiling Seam Seal 8', [87.333, 80.029, 91.563], [157.333, 86.529, 93.563]],
    ['Ceiling Seam Seal 8', [15.321, 128.029, 91.563], [85.321, 134.529, 93.563]],
    ['Ceiling Seam Seal 8', [87.321, 128.029, 91.563], [157.321, 134.529, 93.563]],
    ['Component#6', [69.821, 174.546, 0.813], [98.321, 176.046, 88.563]],
    ['Component#6', [69.821, 38.529, 0.813], [98.321, 40.029, 88.563]],
    ['Component#16', [83.071, 36.279, 85.563], [89.571, 178.279, 93.563]],
    ['Ceiling Seam Seal 8', [15.333, 80.029, 91.563], [85.333, 86.529, 93.563]],
    ['Floor component (9648 cnr) bottom SS', [14.333, 127.654, 1.313], [90.023, 179.279, 4.420]],
    ['Floor component (9648 cnr) bottom SS#1', [82.643, 35.279, 1.312], [158.333, 86.904, 4.420]],
    ['Floor component (9648 cnr) bottom SS', [14.350, 35.279, 1.312], [90.039, 86.904, 4.420]],
    ['Floor component (9648 cnr) bottom SS', [82.643, 127.654, 1.312], [158.333, 179.279, 4.420]],
    ['Floor component (9648 ctr) bottom SS', [14.350, 83.279, 1.312], [86.350, 131.279, 4.410]],
    ['Floor component (9648 ctr) bottom SS', [86.333, 83.279, 1.312], [158.333, 131.279, 4.410]],
    ['Caster plate (9648 cnr) exploded', [13.333, 34.279, 0.000], [110.333, 83.279, 1.750]],
    ['Caster plate (9648 cnr) exploded', [62.333, 34.279, 0.000], [159.333, 83.279, 1.750]],
    ['Caster plate (9648 cnr) exploded', [62.333, 131.279, -0.000], [159.333, 180.279, 1.750]],
    ['Caster plate (9648 cnr) exploded', [13.333, 131.279, 0.000], [110.333, 180.279, 1.750]],
    ['Caster plate (9648 ctr) exploded', [86.333, 83.279, 0.000], [159.333, 131.279, 1.750]],
    ['Caster plate (9648 ctr) exploded', [13.333, 83.279, 0.000], [86.333, 131.279, 1.750]],
    ['Caster plate bracket', [147.827, 81.272, 0.750], [151.840, 85.285, 1.000]],
    ['Caster plate bracket', [92.827, 81.272, 0.770], [96.840, 85.285, 1.020]],
    ['Caster plate bracket', [75.827, 81.272, 0.770], [79.840, 85.285, 1.020]],
    ['Caster plate bracket', [20.827, 81.272, 0.770], [24.840, 85.285, 1.020]],
    ['Caster plate bracket', [92.827, 129.272, 0.770], [96.840, 133.285, 1.020]],
    ['Caster plate bracket', [147.827, 129.272, 0.750], [151.840, 133.285, 1.000]],
    ['Caster plate bracket', [75.827, 129.272, 0.770], [79.840, 133.285, 1.020]],
    ['Caster plate bracket', [20.827, 129.272, 0.770], [24.840, 133.285, 1.020]],
    ['Caster plate bracket', [84.327, 41.772, 0.750], [88.340, 45.785, 1.000]],
    ['Caster plate bracket', [84.327, 72.772, 0.750], [88.340, 76.785, 1.000]],
    ['Caster plate bracket', [84.327, 89.772, 0.750], [88.340, 93.785, 1.000]],
    ['Caster plate bracket', [84.327, 120.772, 0.750], [88.340, 124.785, 1.000]],
    ['Caster plate bracket', [84.327, 137.772, 0.750], [88.340, 141.785, 1.000]],
    ['Caster plate bracket', [84.327, 168.772, 0.750], [88.340, 172.785, 1.000]],
  ].freeze

  STD7272 = [
    ['N0  46VNT_VSS', [2.000, 71.875, -1.170], [48.000, 80.475, 81.000]],
    ['N-seal0  MidWallSeamSeal', [45.125, 72.000, 0.000], [52.875, 74.000, 81.000]],
    ['N1  22PanelSolid', [50.000, 72.000, -0.000], [72.000, 73.000, 81.000]],
    ['S0  Right46Door', [2.000, -1.274, 0.000], [48.000, 3.851, 81.000]],
    ['S-seal0  MidWallSeamSeal', [45.125, 0.000, 0.000], [52.875, 2.000, 81.000]],
    ['S1  22PanelSolid', [50.000, 1.000, -0.000], [72.000, 2.000, 81.000]],
    ['E0  46VNT_VSS', [71.875, 2.000, -1.170], [80.475, 48.000, 81.000]],
    ['E-seal0  MidWallSeamSeal', [72.000, 45.125, 0.000], [74.000, 52.875, 81.000]],
    ['E1  22PanelSolid', [72.000, 50.000, -0.000], [73.000, 72.000, 81.000]],
    ['W0  46Panel3236WDO', [0.250, 2.000, -0.000], [2.000, 48.000, 81.000]],
    ['W-seal0  MidWallSeamSeal', [0.000, 45.125, 0.000], [2.000, 52.875, 81.000]],
    ['W1  22PanelSolid', [1.000, 50.000, -0.000], [2.000, 72.000, 81.000]],
    ['SW corner seal  CornerSeamSeal', [-0.000, 0.000, -0.000], [4.875, 4.875, 81.000]],
    ['SE corner seal  CornerSeamSeal', [69.125, -0.000, -0.000], [74.000, 4.875, 81.000]],
    ['NW corner seal  CornerSeamSeal', [-0.000, 69.125, -0.000], [4.875, 74.000, 81.000]],
    ['NE corner seal  CornerSeamSeal', [69.125, 69.125, -0.000], [74.000, 74.000, 81.000]],
    ['STD7248FL SIDE L', [1.000, 1.000, -1.000], [48.969, 73.000, 2.108]],
    ['STD7224FL SIDE R', [35.062, 1.000, -1.000], [73.000, 73.000, 2.108]],
    ['STD7248CL SIDE L', [1.000, 1.000, 78.892], [49.000, 73.000, 82.000]],
    ['STD7224CL SIDE R', [49.000, 1.000, 78.892], [73.000, 73.000, 82.000]],
    ['STDSS CL6', [45.750, 2.000, 79.250], [52.250, 72.000, 81.000]],
    ['STDSS FL6', [45.405, 1.000, -1.003], [52.595, 73.000, 0.688]],
    ['Foam  N0', [13.000, 70.000, 16.500], [37.000, 72.000, 64.500]],
    ['Foam  E0', [70.000, 13.000, 16.500], [72.000, 37.000, 64.500]],
    ['Duct Cover hi  N0', [12.212, 68.881, 64.039], [24.088, 72.000, 78.861]],
    ['Duct Cover lo  N0', [25.962, 68.881, 2.039], [37.838, 72.000, 16.861]],
    ['Duct Cover hi  E0', [68.881, 25.912, 64.039], [72.000, 37.788, 78.861]],
    ['Duct Cover lo  E0', [68.881, 12.162, 2.039], [72.000, 24.038, 16.861]],
  ].freeze
'''

if __name__ == '__main__':
    sys.exit(main())
