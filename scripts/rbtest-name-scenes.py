# -*- coding: utf-8 -*-
"""RUN name-scenes-after-parts.rb's pure methods outside SketchUp.

    python scripts/rbtest-name-scenes.py

Lifts the file's PURE block verbatim (rbtest.py's method), runs it in
SketchUp's own CRuby against fixtures, and checks:

  1. unnamed_scene?: "Scene 12" and "Scene 12 (2)" are unnamed; "scene 12",
     "Scene 12 copy", "Door", "Scene" are not; blank is unnamed.
  2. parse_positions: ranges, singles, reversed ranges, de-duplication, order
     kept, 0 never wraps to the last scene, what falls off either end is
     reported, junk tokens are reported.
  3. part_label: definition name first, instance name next, Component#/Group#
     placeholders are no name.
  4. assign_names: three scenes on one part get "Door", "Door (2)",
     "Door (3)"; a name held by a scene not being renamed is skipped over
     (case-insensitively); a scene already called "Door (2)" keeps it so a
     second run is a no-op; unresolved rows get nothing.
  5. The resolver block is still VERBATIM bulk-name-after-scenes.rb's.

Then it MUTATES the source and requires the suite to FAIL on each — a test
that cannot fail proves nothing.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbparse  # noqa: E402

SRC = os.path.join(HERE, 'name-scenes-after-parts.rb')
BULK = os.path.join(HERE, 'bulk-name-after-scenes.rb')

SHIMS = r'''
$VERBOSE = nil
class Integer
  def to_i; self; end
end
'''


def pure_block(text):
    a = text.index('# =================================================== PURE (rbtest-lifted) ==')
    b = text.index('# ================================================= END OF THE PURE BLOCK ==')
    return text[a:b]


def copy_block(text, start, stop):
    text = text.replace('\r\n', '\n')
    return text[text.index(start):text.index(stop)]


CHECK = r'''
module WR_NameScenesAfterParts
  AUTONAME = /\A(Component|Group)#\d+\z/.freeze
@@PURE@@
end

module T
  M = WR_NameScenesAfterParts
  def self.run
    f = []
    # 1
    ['Scene 12', 'Scene 1', ' Scene 7 ', 'Scene 12 (2)', ''].each do |n|
      f << "unnamed? #{n.inspect} should be true" unless M.unnamed_scene?(n)
    end
    ['scene 12', 'Scene 12 copy', 'Door', 'Scene', 'Scene 12 (x)', 'My Scene 3'].each do |n|
      f << "unnamed? #{n.inspect} should be false" if M.unnamed_scene?(n)
    end
    # 2
    p1, m1 = M.parse_positions('355-358, 430, 356', 500)
    f << "positions basic #{p1.inspect} #{m1.inspect}" unless p1 == [355, 356, 357, 358, 430] && m1.empty?
    p2, m2 = M.parse_positions('5-3', 10)
    f << "positions reversed #{p2.inspect}" unless p2 == [3, 4, 5] && m2.empty?
    p3, m3 = M.parse_positions('0-2, 9-12', 10)
    f << "positions clamp #{p3.inspect} #{m3.inspect}" unless p3 == [1, 2, 9, 10] && m3 == ['0-0', '11-12']
    p4, m4 = M.parse_positions('0, 11, abc, 20-30', 10)
    f << "positions misses #{p4.inspect} #{m4.inspect}" unless p4.empty? && m4 == ['0', '11', 'abc', '20-30']
    p5, = M.parse_positions('', 10)
    f << 'positions empty' unless p5.empty?
    p6, = M.parse_positions('2 - 4;7', 10)
    f << "positions spaces/semicolon #{p6.inspect}" unless p6 == [2, 3, 4, 7]
    # 3
    f << 'part_label defn' unless M.part_label('Std door', 'whatever') == 'Std door'
    f << 'part_label inst' unless M.part_label('Group#3', 'Left wall') == 'Left wall'
    f << 'part_label both auto' unless M.part_label('Component#12', 'Group#1').nil?
    f << 'part_label blank' unless M.part_label('  ', '').nil?
    # 4
    rows = [[10, 'Scene 10', 'Door'], [11, 'Scene 11', 'Door'], [12, 'Scene 12', 'Door'],
            [13, 'Scene 13', nil], [14, 'Scene 14', 'Wall']]
    a = M.assign_names(rows, [])
    f << "assign three on one part #{a.inspect}" unless a == { 10 => 'Door', 11 => 'Door (2)', 12 => 'Door (3)', 14 => 'Wall' }
    b = M.assign_names(rows, ['door', 'Wall'])
    f << "assign reserved #{b.inspect}" unless b[10] == 'Door (2)' && b[11] == 'Door (3)' && b[14] == 'Wall (2)'
    rerun = [[10, 'Door', 'Door'], [11, 'Door (2)', 'Door'], [12, 'Scene 12', 'Door']]
    c = M.assign_names(rerun, [])
    f << "assign stable rerun #{c.inspect}" unless c == { 10 => 'Door', 11 => 'Door (2)', 12 => 'Door (3)' }
    swap = [[1, 'B', 'A'], [2, 'A', 'B']]
    d = M.assign_names(swap, [])
    f << "assign swap #{d.inspect}" unless d == { 1 => 'A', 2 => 'B' }
    held = [[1, 'Door (2)', 'Door'], [2, 'Scene 2', 'Door']]
    e = M.assign_names(held, ['Door (2)'])
    f << "assign own name held elsewhere #{e.inspect}" unless e == { 1 => 'Door', 2 => 'Door (3)' }
    rx = [[1, 'Std wall (46") (2)', 'Std wall (46")'], [2, 'Scene 2', 'Std wall (46")']]
    g = M.assign_names(rx, [])
    f << "assign regex-special base #{g.inspect}" unless g == { 1 => 'Std wall (46") (2)', 2 => 'Std wall (46")' }
    f.empty? ? 'PASS' : 'FAIL ' + f.join(' | ')
  end
end
T.run.dup
'''


def suite(lib, src_text):
    return rbparse.rb_eval(lib, SHIMS + CHECK.replace('@@PURE@@', pure_block(src_text)))


MUTANTS = [
    ('unnamed regex drops the (2) suffix',
     r"UNNAMED_SCENE = /\AScene \d+(?: \(\d+\))?\z/", r"UNNAMED_SCENE = /\AScene \d+\z/"),
    ('position 0 not clamped',
     'lo = a < 1 ? 1 : a', 'lo = a'),
    ('reserved names ignored',
     'reserved.each { |n| taken[n.to_s.downcase] = true }', ''),
    ('stability pass removed',
     'next unless own', 'next'),
    ('instance-name fallback removed',
     '[defn_name, inst_name].each do |raw|', '[defn_name].each do |raw|'),
]

START = '  # "(LeftWADoorWithRamp)"'
STOP = '  # ------------------------------------------------------- end of copy -------'


def main():
    text = open(SRC, encoding='utf-8').read()
    ok = True
    same = copy_block(text, START, STOP) == copy_block(open(BULK, encoding='utf-8').read(), START, STOP)
    print('resolver copy verbatim from bulk-name-after-scenes.rb: ' + ('yes' if same else 'NO — DRIFTED'))
    ok = ok and same
    lib = rbparse.boot()
    got = suite(lib, text)
    print('name-scenes-after-parts.rb pure block: ' + got)
    ok = ok and got == 'PASS'
    for label, a, b in MUTANTS:
        if a not in text:
            print('  MUTANT NOT APPLIED (source changed?): ' + label)
            ok = False
            continue
        try:
            r = suite(lib, text.replace(a, b, 1))
        except RuntimeError as e:
            r = 'FAIL (raised) ' + str(e)
        caught = r.startswith('FAIL')
        print('  mutant %-40s %s' % (label, 'caught' if caught else 'NOT CAUGHT'))
        ok = ok and caught
    print('PASS' if ok else 'FAIL')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
