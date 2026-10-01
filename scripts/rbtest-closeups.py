# -*- coding: utf-8 -*-
"""RUN am-closeup-export.rb's pure methods outside SketchUp.

    python scripts/rbtest-closeups.py

Lifts every method in the file's PURE block verbatim (rbtest.py's method), runs
them in SketchUp's own CRuby against fixtures, and checks:

  1. cam_dir reproduces the Iso30 rig: at azimuth 45 the frozen 0.6124 table,
     and at azimuth 38 the ExtR vector the DoorCombos _diagnostics.txt printed
     (+0.6824, +0.5332, +0.5000).
  2. basis is orthonormal and right-handed, up has +z, and looking straight
     down does not collapse.
  3. parallel project: the target lands on the centre pixel; a point half a
     view height up lands on row 0; half a view width right lands on the last
     column — on the WIDE 2400 x 1553 canvas, not a square.
  4. perspective project: the target is the centre; a point on the top edge of
     the vertical field of view lands on row 0.
  5. fit_height puts every fitted point inside the frame.
  6. name_hit? matches a definition across the inch-mark/underscore spelling
     and SketchUp's "#1" suffix; same_name? likewise.
  7. rank_pick: z_desc first / mid / last, negative index, view_near/far.
  8. pick_shots on the REAL am-closeups.json: 'pilot' gives the 7 pilot images
     in order, a single variant resolves, an unknown token is reported.
  9. merge_pose: a variant replaces base keys wholesale; "_" keys drop.
 10. box_gap / bbox_at / safe_name on small fixtures.

Then it MUTATES the source (flips the sign of the image y axis in project, and
breaks name_hit?'s underscore fallback) and requires the suite to FAIL on each
— a test that cannot fail proves nothing.

What it cannot check: that SketchUp's Camera#height really is the vertical
extent of a non-square export. The pilot's anchor-check images and
scripts/am-closeup-check.py are the evidence for that.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbparse  # noqa: E402

SRC = os.path.join(HERE, 'am-closeup-export.rb')
SPEC = os.path.join(HERE, 'am-closeups.json')

# The VM rbparse boots is minimal: methods Ruby 3.2 defines in its own .rb
# preludes are absent. These are the ones the pure block touches.
SHIMS = r'''
$VERBOSE = nil
class Float
  def to_f; self; end
  def abs; self < 0.0 ? -self : self; end
  def finite?; self == self && self != 1.0 / 0.0 && self != -1.0 / 0.0; end
end
class Integer
  def to_f; self * 1.0; end
  def to_i; self; end
  def abs; self < 0 ? -self : self; end
end
class NilClass
  def to_i; 0; end
  def to_f; 0.0; end
end
'''


def pure_block(text):
    a = text.index('# =================================================== PURE (rbtest-lifted) ==')
    b = text.index('# ================================================= END OF THE PURE BLOCK ==')
    return text[a:b]


def to_rb(v):
    """JSON value -> Ruby literal with STRING keys (JSON's {"k": v} would be symbols)."""
    if isinstance(v, dict):
        return '{' + ', '.join('%s => %s' % (to_rb(k), to_rb(x)) for k, x in v.items()) + '}'
    if isinstance(v, list):
        return '[' + ', '.join(to_rb(x) for x in v) + ']'
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if v is None:
        return 'nil'
    if isinstance(v, (int, float)):
        return repr(v)
    return '"' + str(v).replace('\\', '\\\\').replace('"', '\\"').replace('#', '\\#') + '"'


CHECK = r'''
module WR_AmCloseups
@@PURE@@
end

module T
  M = WR_AmCloseups
  def self.near(a, b, tol = 1e-6)
    (a - b).abs <= tol
  end

  def self.run
    f = []
    # 1
    v45 = M.cam_dir(45, 30).map { |x| x.round(4) }
    f << "cam_dir 45 #{v45.inspect}" unless v45 == [0.6124, 0.6124, 0.5]
    v38 = M.cam_dir(38, 30).map { |x| x.round(4) }
    f << "cam_dir 38 #{v38.inspect} != DoorCombos ExtR" unless v38 == [0.6824, 0.5332, 0.5]
    # 2
    [[38, 30], [218, 30], [10, -20], [0, 90], [0, -90], [123, 8]].each do |az, el|
      fw, rt, up = M.basis(M.cam_dir(az, el))
      [fw, rt, up].each { |v| f << "basis #{az}/#{el} not unit" unless near(M.vlen(v), 1.0, 1e-9) }
      f << "basis #{az}/#{el} not orthogonal" unless near(M.vdot(fw, rt), 0, 1e-9) && near(M.vdot(fw, up), 0, 1e-9) && near(M.vdot(rt, up), 0, 1e-9)
      f << "basis #{az}/#{el} not right-handed" unless near(M.vdot(M.vcross(rt, up), M.vscale(fw, -1.0)), 1.0, 1e-9)
      f << "basis #{az}/#{el} up points down" if el.abs < 90 && up[2] <= 0
    end
    # 3
    fw, rt, up = M.basis(M.cam_dir(38, 30))
    t = [10.0, -4.0, 40.0]
    cam = { :w => 2400, :h => 1553, :target => t, :right => rt, :up => up, :height => 96.0, :persp => false }
    c = M.project(t, cam)
    f << "parallel centre #{c.inspect}" unless near(c[0], 1200.0) && near(c[1], 776.5)
    top = M.project(M.vadd(t, M.vscale(up, 48.0)), cam)
    f << "parallel top #{top.inspect}" unless near(top[1], 0.0, 1e-6) && near(top[0], 1200.0)
    wide = 96.0 * 2400.0 / 1553.0
    rgt = M.project(M.vadd(t, M.vscale(rt, wide / 2.0)), cam)
    f << "parallel right edge #{rgt.inspect}" unless near(rgt[0], 2400.0, 1e-6) && near(rgt[1], 776.5)
    depth = M.project(M.vadd(t, M.vscale(fw, 500.0)), cam)
    f << "parallel depth moved the pixel #{depth.inspect}" unless near(depth[0], 1200.0) && near(depth[1], 776.5)
    # 4
    eye = M.vadd(t, M.vscale(M.cam_dir(38, 30), 100.0))
    pc = { :w => 2400, :h => 1553, :target => t, :eye => eye, :fwd => fw, :right => rt, :up => up, :fov => 40.0, :persp => true }
    c = M.project(t, pc)
    f << "persp centre #{c.inspect}" unless near(c[0], 1200.0, 1e-6) && near(c[1], 776.5, 1e-6)
    half = 100.0 * Math.tan(20.0 * Math::PI / 180.0)
    tp = M.project(M.vadd(t, M.vscale(up, half)), pc)
    f << "persp top edge #{tp.inspect}" unless near(tp[1], 0.0, 1e-6)
    f << 'persp behind the eye should be nil' unless M.project(M.vadd(eye, M.vscale(fw, -5.0)), pc).nil?
    # 5
    pts = [[0, 0, 0], [46, 3, 81], [46, 0, 0], [0, 3, 81], [20, 40, 10]].map { |p| p.map(&:to_f) }
    tg = [23.0, 1.5, 40.5]
    h = M.fit_height(pts, tg, rt, up, 2400, 1553, 0.08)
    fc = cam.merge(:target => tg, :height => h)
    bad = pts.map { |p| M.project(p, fc) }.reject { |xy| M.in_frame?(xy, 2400, 1553) }
    f << "fit_height left #{bad.length} point(s) outside" unless bad.empty?
    # 6
    f << 'name_hit? inch mark + #1' unless M.name_hit?(Regexp.new('^Std door frame 46"$', Regexp::IGNORECASE), 'Std door frame 46"#1')
    f << 'name_hit? underscore spelling' unless M.name_hit?(Regexp.new('Std door frame 46_ adaptor', Regexp::IGNORECASE), 'Std door frame 46" adaptor (bottom)#1')
    f << 'name_hit? matched what it should not' if M.name_hit?(Regexp.new('^Std door frame 46"$', Regexp::IGNORECASE), 'Std door frame 46" adaptor (top)')
    f << 'same_name? file vs definition' unless M.same_name?('Std wall (46_) with HX', 'Std wall (46") with HX#2')
    # 7
    items = [[0, 8], [0, 72], [0, 40], [0, 9], [0, 41], [0, 73]].each_with_index.map do |(x, z), i|
      { :id => i, :box => [[x.to_f, 0.0, z.to_f], [x + 1.0, 1.0, z + 3.0]] }
    end
    zf = M.rank_pick(items, 'z_desc', 0).map { |i| i[:id] }
    zl = M.rank_pick(items, 'z_desc', 'last').map { |i| i[:id] }
    zm = M.rank_pick(items, 'z_desc', 'mid').map { |i| i[:id] }
    zn = M.rank_pick(items, 'z_desc', -2).map { |i| i[:id] }
    f << "rank z_desc first #{zf.inspect}" unless zf == [5]
    f << "rank z_desc last #{zl.inspect}" unless zl == [0]
    f << "rank z_desc mid #{zm.inspect}" unless zm == [2]
    f << "rank z_desc -2 #{zn.inspect}" unless zn == [3]
    f << 'rank out of range should be empty' unless M.rank_pick(items, 'z_desc', 9).empty?
    vn = M.rank_pick(items, 'view_near', 0, [0.0, 0.0, -1.0], [0.0, 0.0, 500.0]).map { |i| i[:id] }
    vf = M.rank_pick(items, 'view_far', 0, [0.0, 0.0, -1.0], [0.0, 0.0, 500.0]).map { |i| i[:id] }
    f << "rank view_near #{vn.inspect} (camera above, nearest is the highest)" unless vn == [5]
    f << "rank view_far #{vf.inspect}" unless vf == [0]
    # 8
    poses = {}
    SPEC['shots'].each { |id, s| poses[id] = s['pose'] if s['pose'] }
    pl, miss = M.pick_shots(poses, 'pilot')
    # Expected = each posed shot's pilot_variants, in id order (derived from the spec, not hard-coded).
    want = poses.keys.sort.flat_map { |id| (Array(poses[id]['pilot_variants']) & (poses[id]['variants'] || {}).keys).map { |v| [id, v] } }
    f << "pick_shots pilot #{pl.inspect}" unless pl == want && miss.empty?
    one, m1 = M.pick_shots(poses, 'cu-06:seated, CU-99, CU-03:w99')
    f << "pick_shots tokens #{one.inspect} #{m1.inspect}" unless one == [['CU-06', 'seated']] && m1 == ['CU-99', 'CU-03:w99']
    every, = M.pick_shots(poses, 'CU-08')
    f << "pick_shots all variants of CU-08 #{every.inspect}" unless every.length == (poses['CU-08']['variants'] || {}).length
    # 9
    mp = M.merge_pose({ 'scale' => 'M', 'parts' => [1], '_c' => 'x' }, { 'parts' => [2], '_d' => 1, 'scale' => 'L' })
    f << "merge_pose #{mp.inspect}" unless mp == { 'scale' => 'L', 'parts' => [2] }
    # 10
    f << 'box_gap touching' unless near(M.box_gap([[0.0, 0.0, 0.0], [1.0, 1.0, 1.0]], [[1.0, 0.0, 0.0], [2.0, 1.0, 1.0]]), 0.0)
    f << 'box_gap apart' unless near(M.box_gap([[0.0, 0.0, 0.0], [1.0, 1.0, 1.0]], [[4.0, 5.0, 0.0], [5.0, 6.0, 1.0]]), 5.0)
    f << 'bbox_at' unless M.bbox_at([0.0, 0.0, 0.0], [10.0, 20.0, 30.0], [0.5, 0.25, 1.0]) == [5.0, 5.0, 30.0]
    f << 'safe_name' unless M.safe_name('CU-03') + '_' + M.safe_name('w46') == 'CU-03_w46' && M.safe_name('a"b:c') == 'a-b-c'
    f.empty? ? 'PASS' : 'FAIL ' + f.join(' | ')
  end
end
T.run.dup
'''


def suite(lib, src_text):
    spec = json.load(open(SPEC, encoding='utf-8'))
    prog = SHIMS + CHECK.replace('@@PURE@@', pure_block(src_text)).replace(
        'module T\n', 'module T\n  SPEC = ' + to_rb(spec) + '\n', 1)
    return rbparse.rb_eval(lib, prog)


MUTANTS = [
    ('image y axis flipped in project',
     'h / 2.0 - vdot(v, cam[:up]) * s]', 'h / 2.0 + vdot(v, cam[:up]) * s]'),
    ('name_hit? underscore fallback removed',
     "|| !(b.tr('\"', '_') =~ re).nil?", ''),
    ('rank_pick mid off by one', "when 'mid'   then [sorted[n / 2]]", "when 'mid'   then [sorted[n / 2 - 1]]"),
]


def main():
    text = open(SRC, encoding='utf-8').read()
    lib = rbparse.boot()
    got = suite(lib, text)
    print('am-closeup-export.rb pure block: ' + got)
    ok = got == 'PASS'
    for label, a, b in MUTANTS:
        if a not in text:
            print('  MUTANT NOT APPLIED (source changed?): ' + label)
            ok = False
            continue
        r = suite(lib, text.replace(a, b, 1))
        caught = r.startswith('FAIL')
        print('  mutant %-40s %s' % (label, 'caught' if caught else 'NOT CAUGHT'))
        ok = ok and caught
    print('PASS' if ok else 'FAIL')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
