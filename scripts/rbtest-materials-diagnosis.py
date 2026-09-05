# -*- coding: utf-8 -*-
"""A ZERO-MATCH MATERIAL SWAP MUST EXPLAIN ITSELF -- the wording, run for real.

    python scripts/rbtest-materials-diagnosis.py

THE DEFECT THIS PINS (reported 2026-09-05)
------------------------------------------
Benton pressed the Proposal Package window's Draft <-> Render toggle nine
times. The panel log read, in full:

    MODE -> DRAFT / MODE -> RENDER / ... nine of them
      WR-Floor-Render: 1 surface(s)

Eight toggles printed NOTHING after the MODE line. Both log sites
(proposal-package.rb unit_mode and its togglemode callback) only iterated
`applied`/`reverted` and `unmapped`/`left`; when a sweep matches zero surfaces
BOTH are empty, so a swap that did nothing at all was byte-identical in the log
to a swap that worked. There was no way to tell a working toggle from a no-op.

WR_MaterialsSwap.diagnose_lines is the fix: given each slot's SOURCE, FILL and
the live count of surfaces on each, it says which of the four causes applies.
That method is PURE -- rows in, strings out, no SketchUp API -- so the exact
sentence an operator will read can be run here.

WHAT RUNS
---------
SketchUp's own CRuby 3.2 (scripts/rbparse.py). `diagnose_lines` is LIFTED
VERBATIM out of scripts/wr-materials-swap.rb on every run, so this harness
cannot drift from the code it tests -- edit the method and the next run tests
the edit. Nothing is stubbed: the method touches no model.

The half that DOES touch the model, `diagnosis`, is not tested here and is
UNRUN -- it needs a real Sketchup::Model. It is a hash-build around the same
`find` walk the swap itself already uses.

WHAT IT ASSERTS
  1. All three slots empty (house sources, nothing painted with them, no
     fills): three lines, one per slot, each naming the slot, its source, the
     zero count and the missing fill. This is Benton's case.
  2. A source carrying surfaces but no fill: the line says how many surfaces
     and that the FILL is what is missing.
  3. A fill naming a material not in the model: the line says NOT a material
     in this model, and still reports the source count.
  4. Healthy: counts on both sides are reported and the line says which mode
     the slot is already in, rather than claiming a swap happened.
  5. No line is ever empty, and every line names its slot -- the whole
     complaint was lines that were not there.

Exit 0 when every check passes, 1 otherwise.

MUTATION-CHECKED when written, and both mutations were RUN: make
diagnose_lines return `[]` and every content check fails with `lines: []` --
which is precisely the bug, a log site printing nothing; drop `#{sn}` from the
no-fill branch and check 2 fails on the missing count alone.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbparse  # noqa: E402
from rbtest import method_source  # noqa: E402

SWAP = os.path.join(HERE, 'wr-materials-swap.rb')

FLOOR = 'WR-Floor-Render'
WALL = 'WR-Wall-Render'
DOOR = 'WR-Door-Render'

# slot, source, source_count, fill, fill_count, fill_exists
CASES = [
    # 1. Benton's model: house sources, nothing painted with them, no fills.
    ('all-empty', [
        (FLOOR, '0128_White', 0, '', 0, False),
        (WALL, '0099_LightSteelBlue', 0, '', 0, False),
        (DOOR, '0043_SaddleBrown', 0, '', 0, False),
    ]),
    # 2. Surfaces are on the source, but the slot was never filled.
    ('no-fill', [(WALL, '0099_LightSteelBlue', 14, '', 0, False)]),
    # 3. Filled with a material that is not in this model.
    ('missing-fill', [(FLOOR, '0128_White', 1, 'Oak Plank VR', 0, False)]),
    # 4. Healthy, both directions.
    ('healthy-draft', [(FLOOR, '0128_White', 1, 'Oak Plank VR', 0, True)]),
    ('healthy-render', [(FLOOR, '0128_White', 0, 'Oak Plank VR', 1, True)]),
    # A slot with no source configured at all.
    ('no-source', [(DOOR, '', 0, '', 0, False)]),
]

PROG = r'''
# The bare VM rbparse boots has no ruby prelude, so a handful of core methods
# the real SketchUp Ruby has are simply absent -- Integer#to_i is one, exactly
# as Integer#to_f is in rbtest-side-wall-order.py. Supplied here so the LIFTED
# method runs unmodified; it is not a stand-in for any logic under test.
class Integer
  def to_i; self; end
end

module WR_MaterialsSwap
@@DIAGNOSE_LINES@@
end

module Harness
  CASES = @@CASES@@

  def self.run
    out = []
    CASES.each do |name, rows|
      rows = rows.map do |r|
        { :slot => r[0], :source => r[1], :source_count => r[2],
          :fill => r[3], :fill_count => r[4], :fill_exists => r[5] }
      end
      WR_MaterialsSwap.diagnose_lines(rows).each { |l| out << "#{name}|#{l}" }
    end
    out.join("\n")
  end
end

begin
  Harness.run
rescue Exception => e
  "FAIL #{e.class}: #{e.message}"
end
'''


def rb_cases():
    parts = []
    for name, rows in CASES:
        rs = ', '.join(
            '["%s", "%s", %d, "%s", %d, %s]'
            % (s, src, sn, fl, fn, 'true' if fe else 'false')
            for (s, src, sn, fl, fn, fe) in rows)
        parts.append('["%s", [%s]]' % (name, rs))
    return '[' + ', '.join(parts) + ']'


CHECKS = [0]
FAILS = []


def ck(label, got, want):
    CHECKS[0] += 1
    if got != want:
        FAILS.append('%s\n      got  %r\n      want %r' % (label, got, want))


def has(label, lines, needle):
    CHECKS[0] += 1
    if not any(needle in l for l in lines):
        FAILS.append('%s\n      no line contains %r\n      lines: %r'
                     % (label, needle, lines))


def main():
    prog = (PROG
            .replace('@@DIAGNOSE_LINES@@', method_source(SWAP, 'diagnose_lines'))
            .replace('@@CASES@@', rb_cases()))
    got = rbparse.rb_eval(rbparse.boot(), prog)
    if got.startswith('FAIL '):
        print(got)
        return 1

    by = {}
    for line in got.split('\n'):
        if not line.strip():
            continue
        name, _, text = line.partition('|')
        by.setdefault(name, []).append(text)

    # 1. All three slots empty -- Benton's nine silent toggles.
    a = by.get('all-empty', [])
    ck('all-empty: one line per slot, three lines', len(a), 3)
    for slot in (FLOOR, WALL, DOOR):
        has('all-empty: names %s' % slot, a, slot)
    has('all-empty: names the wall source the model does not carry',
        a, '"0099_LightSteelBlue"')
    has('all-empty: says zero surfaces carry it', a, '0 surface(s)')
    has('all-empty: also says the fill is missing', a, 'no FILL is set')

    # 2. Source has surfaces, no fill set.
    b = by.get('no-fill', [])
    ck('no-fill: one line', len(b), 1)
    has('no-fill: reports the real surface count', b, '14 surface(s)')
    has('no-fill: blames the FILL, not the source', b, 'no FILL is set')

    # 3. Fill names a material this model does not have.
    c = by.get('missing-fill', [])
    ck('missing-fill: one line', len(c), 1)
    has('missing-fill: names the missing fill', c, '"Oak Plank VR"')
    has('missing-fill: says it is not in this model', c,
        'NOT a material in this model')
    has('missing-fill: still reports the source count', c, '1 surface(s)')

    # 4. Healthy -- never claims a swap happened, says which mode it is in.
    d = by.get('healthy-draft', [])
    ck('healthy-draft: one line', len(d), 1)
    has('healthy-draft: says already DRAFT', d, 'already DRAFT')
    e = by.get('healthy-render', [])
    has('healthy-render: says already RENDER', e, 'already RENDER')

    # A slot with no source at all.
    f = by.get('no-source', [])
    ck('no-source: one line', len(f), 1)
    has('no-source: says no SOURCE is set', f, 'no SOURCE material is set')

    # 5. The original complaint: nothing may be blank, everything names a slot.
    allslots = (FLOOR, WALL, DOOR)
    for name, lines in by.items():
        for l in lines:
            ck('%s: line is not blank' % name, bool(l.strip()), True)
            ck('%s: line names a slot (%r)' % (name, l[:40]),
               any(s in l for s in allslots), True)

    print('MATERIALS DIAGNOSIS - what the panel log now says on a zero-match toggle')
    print('')
    for name, _rows in CASES:
        print('  %s' % name)
        for l in by.get(name, ['(NOTHING PRINTED)']):
            print('    %s' % l.strip())
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
