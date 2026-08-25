# -*- coding: utf-8 -*-
"""RUN a pure-logic Ruby method from these scripts, outside SketchUp.

    python rbtest.py

WHY THIS EXISTS
---------------
`rbparse.py` proves a file PARSES. It cannot prove a method RUNS, and the gap
between those two is exactly where this repo has been bitten:

    by_wall.each do |w, list|          # `inn` never bound here
      ...
      puts inn ? 'inner' : 'outer'     # parses perfectly. NameError at run time.

Ruby resolves a bare identifier to a method call when no local of that name is
in scope, so an unbound local is a clean parse and a crash on the first real
booth. That shipped once, on 2026-08-25, and cost a SketchUp round trip.

WHAT IT DOES
------------
Boots the same CRuby 3.2 VM `rbparse.py` borrows out of SketchUp 2024, lifts a
named method verbatim out of a .rb file by text, drops it into a stub module
with just enough around it to run, and executes it against synthetic input.

The method's SOURCE IS NOT COPIED into this file. It is read from the script on
every run, so the test cannot quietly drift from the code it is testing - if the
method is edited, the next run tests the edit.

WHAT IT DOES NOT DO
-------------------
It does not touch the SketchUp API. Only methods that are pure data in, data out
can be tested this way; `place`, `load_def` and the deck pass all need a real
model and are still verified by building a booth and looking at it.

CHECKED AGAINST ITSELF
----------------------
A test that cannot fail proves nothing, so this one was mutation-checked when it
was written. Reintroduce either bug it exists to catch and it reports FAIL:

    w, inn = key      -> w = key[0]          FAIL undefined local variable `inn'
    joint = inn ? IEP_SEAL_W : 2.0 -> 2.0    inner run lands 3.5 in short

Do that again if you ever doubt it.
"""
import ctypes
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbparse  # noqa: E402  - reuse its DLL discovery and VM boot


def method_source(path, name):
    """The verbatim text of `def self.<name>` ... its closing `end`.

    Found by indentation: the method opens at two spaces and closes at the
    first line that is exactly two spaces then `end`. Every method in these
    files sits at module level, so that is unambiguous.
    """
    lines = open(path, encoding='utf-8').read().split('\n')
    start = None
    for i, ln in enumerate(lines):
        if re.match(r'^  def self\.%s\b' % re.escape(name), ln):
            start = i
            break
    if start is None:
        raise SystemExit('%s: no method self.%s' % (os.path.basename(path), name))
    for j in range(start + 1, len(lines)):
        if lines[j] == '  end':
            return '\n'.join(lines[start:j + 1])
    raise SystemExit('%s: self.%s never closes' % (os.path.basename(path), name))


# --------------------------------------------------------------------------
# The one test: rebalance_walls on an Enhanced booth.
#
# An Enhanced booth has two runs on every wall whose slot ids differ only by a
# trailing 'i'. rebalance_walls groups parts by wall and re-walks each run from
# the real part widths, so it has to keep the shells apart and use each shell's
# own joint - 2.0 outer, 6.5 inner. Keyed on the wall alone the two interleave
# and neither run closes.
#
# The fixture is one wall of a 4872 E, both shells, with the outer door frame
# widened 46 -> 49 the way a wide-access door arrives from the portal. That is
# the only condition under which rebalance_walls does anything at all, so it is
# the only fixture that tests it.
# --------------------------------------------------------------------------
# The embedded VM comes up minimal - it is the parser plus enough runtime to
# compile, not a full Ruby. A few core methods the real interpreter has are
# simply absent (rbparse's own notes flag Object#class and RUBY_DESCRIPTION).
# These shims add back only what the method under test calls. They are core
# semantics, defined here rather than worked around in the fixture, so the
# method's own source still runs exactly as written.
SHIMS = r'''
class Float
  def to_f; self; end
end
class Integer
  def to_f; self * 1.0; end
end
'''

FIXTURE = r'''
module WR_BuildBoothComponents
  IEP_SEAL_W = 6.5

  def self.inner?(part)
    part[:sh].to_s == 'in'
  end

%(rebalance)s

  # S wall of a 4872 E with a WIDE-ACCESS door on both shells.
  #
  # The LAYOUT still holds the module widths - outer 46 + 2 + 22 = 70 from x=2,
  # inner 41.5 + 6.5 + 17.5 = 65.5 from x=4.25 - because the layout is generated
  # from the catalogue arrangement and knows nothing about the customer's door.
  # The real parts are wider and their companions narrower: outer 49 + 19, inner
  # 44.5 + 14.5. Both runs still close on their original end, which is the
  # condition rebalance_walls insists on before it will move anything.
  #
  # The inner run is the part that matters here. It closes ONLY on a 6.5 joint:
  # 4.25 + 44.5 + 6.5 + 14.5 = 69.75. Re-walk it with the Standard 2.0 and it
  # lands at 65.25, misses by 3.5, and bails out - so a test that passes proves
  # the joint is being taken per shell rather than hardcoded.
  def self.fixture
    mk = lambda do |id, kind, sh, x0, x1, w|
      { :part => { :k => kind, :id => id, :sh => sh,
                   :poly => [[x0, 0.0], [x1, 0.0], [x1, 1.0], [x0, 1.0]] },
        :cls => { :w => w }, :slab => nil, :name => id }
    end
    [mk.call('S0',       'panel', 'out',  2.0,  48.0, 49.0),
     mk.call('S-seal0',  'seal',  'out', 48.0,  50.0,  2.0),
     mk.call('S1',       'panel', 'out', 50.0,  72.0, 19.0),
     mk.call('S0i',      'panel', 'in',   4.25, 45.75, 44.5),
     mk.call('S-seal0i', 'seal',  'in',  45.75, 52.25,  6.5),
     mk.call('S1i',      'panel', 'in',  52.25, 69.75, 14.5)]
  end

  def self.check
    rows = fixture
    rebalance_walls(rows)
    out = rows.map do |r|
      p = r[:part]
      xs = p[:poly].map { |q| q[0].to_f }
      format('%%s %%.3f..%%.3f', p[:id], xs.min, xs.max)
    end
    out.join(' | ')
  end
end

(begin
  WR_BuildBoothComponents.check
rescue Exception => e
  'FAIL ' + e.message
end).dup
'''

# What the run must produce. Both shells re-walk from their real part widths
# and both still close on their original end.
#
#   outer  2 + 49 = 51, seal shifts 3 in to 51..53, 19 in panel 53..72
#   inner  4.25 + 44.5 = 48.75, seal shifts 3 in to 48.75..55.25, 14.5 in
#          panel 55.25..69.75          <- only reachable on a 6.5 joint
EXPECT = ('S0 2.000..51.000 | S-seal0 51.000..53.000 | S1 53.000..72.000 | '
          'S0i 4.250..48.750 | S-seal0i 48.750..55.250 | S1i 55.250..69.750')


def main():
    src = os.path.join(HERE, 'build-booth-components.rb')
    prog = SHIMS + FIXTURE % {'rebalance': method_source(src, 'rebalance_walls')}
    lib = rbparse.boot()
    got = rbparse.rb_eval(lib, prog)
    print('rebalance_walls, Enhanced S wall, wide-access door on both shells')
    print('  got      %s' % got)
    if got == EXPECT:
        print('  PASS - both shells re-walked independently, each on its own joint')
        return 0
    print('  expected %s' % EXPECT)
    print('  FAIL')
    return 1


if __name__ == '__main__':
    sys.exit(main())
