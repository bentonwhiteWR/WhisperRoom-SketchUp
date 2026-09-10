# -*- coding: utf-8 -*-
"""THE CALLOUT-STYLE REQUEST CHECK AND ITS REPORT, run for real.

    python scripts/rbtest-callout-style.py

WHY
---
wr-callout-style.rb sweeps every note, dimension and 3D label in a model in
one undo step. Two of its methods are PURE -- no SketchUp API -- and they are
exactly the ones a typo would turn into a silent no-op or a wrong sentence:

  normalise      the dialog's request in, a checked request or a refusal out.
                 A bad hex or a size of 0 must be REFUSED with a sentence, not
                 handed to Sketchup::Color / Text#font= to raise mid-sweep.
  summary_lines  the counters in, the lines the dialog prints out. Every skip
                 reason must appear -- "30 dims got the colour but not the
                 font" is the whole reason the tool reports instead of just
                 finishing.

WHAT RUNS
---------
SketchUp's own CRuby 3.2 (scripts/rbparse.py). Both methods are LIFTED
VERBATIM out of scripts/wr-callout-style.rb on every run, so this harness
cannot drift from the code it tests. The half that touches the model --
targets, majority, apply -- is NOT tested here and is UNRUN.

MUTATION-CHECKED when written, and both were run: drop the `font.nil? &&
hex.nil?` refusal and check 6 fails; drop the skips loop from summary_lines
and check 10 fails.

Exit 0 when every check passes, 1 otherwise.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbparse  # noqa: E402
from rbtest import method_source  # noqa: E402

RB = os.path.join(HERE, 'wr-callout-style.rb')

PROG = r'''
# The bare VM has no prelude: Integer#to_i and Integer#clamp are absent, as in
# every other rbtest here. Shims only; no logic under test lives here.
class Integer
  def to_i; self; end
end
class NilClass
  def to_i; 0; end
end

module WR_CalloutStyle
  KINDS = %w[text dim 3d].freeze
  KIND_LABEL = { 'text' => 'notes', 'dim' => 'dimensions', '3d' => '3D labels' }.freeze
  SKIP_DIM_FONT  = 'dimension font is not settable from Ruby (Model Info > Dimensions > Fonts, then Select all dimensions > Update)'.freeze
  SKIP_3D_FONT   = '3D label face is fixed geometry — rebuild the label to change it'.freeze
  SKIP_TEXT_FONT = 'this SketchUp cannot set text fonts (needs 2026.2 or later)'.freeze
@@NORMALISE@@
@@SUMMARY@@
end

module Harness
  def self.req(scope, kinds, fon, name, size, bold, italic, con, hex)
    { 'scope' => scope, 'kinds' => kinds,
      'font' => { 'on' => fon, 'name' => name, 'size' => size, 'bold' => bold, 'italic' => italic },
      'color' => { 'on' => con, 'hex' => hex } }
  end

  def self.n(label, r)
    req, err = WR_CalloutStyle.normalise(r)
    if err
      "#{label}|ERR|#{err}"
    else
      "#{label}|OK|#{req[:scope]}|#{req[:tag].inspect}|#{req[:kinds].join(',')}|#{req[:font].inspect}|#{req[:hex].inspect}"
    end
  end

  def self.run
    out = []
    out << n('good-all',   req('all', %w[text dim 3d], true, 'Arial', '12', false, false, true, '#EE6216'))
    out << n('hex-nohash', req('all', %w[text], false, '', '', false, false, true, 'ee6216'))
    out << n('hex-bad',    req('all', %w[text], false, '', '', false, false, true, '#ee62'))
    out << n('size-zero',  req('all', %w[text], true, 'Arial', '0', false, false, false, ''))
    out << n('size-text',  req('all', %w[text], true, 'Arial', 'big', false, false, false, ''))
    out << n('nothing-on', req('all', %w[text], false, '', '', false, false, false, ''))
    out << n('no-kinds',   req('all', [], true, 'Arial', '12', false, false, true, '#000000'))
    out << n('bad-kind',   req('all', %w[text walls], true, 'Arial', '12', true, true, false, ''))
    out << n('tag',        req('tag:WR-Dims-Plan', %w[dim], false, '', '', false, false, true, '#000000'))
    out << n('tag-empty',  req('tag:', %w[dim], false, '', '', false, false, true, '#000000'))
    out << n('sel',        req('sel', %w[dim], false, '', '', false, false, true, '#000000'))
    out << n('scope-junk', req('everywhere', %w[dim], false, '', '', false, false, true, '#000000'))
    out << n('name-blank', req('all', %w[text], true, '   ', '12', false, false, false, ''))
    out << n('not-hash',   'garbage')

    c = { :total => 35, :kinds => { 'text' => 3, 'dim' => 30, '3d' => 2 },
          :font => 3, :color => 35,
          :skips => { WR_CalloutStyle::SKIP_DIM_FONT => 30, WR_CalloutStyle::SKIP_3D_FONT => 2 },
          :errors => [] }
    WR_CalloutStyle.summary_lines(c).each { |l| out << "sum-a|#{l}" }
    c2 = { :total => 4, :kinds => { 'text' => 4, 'dim' => 0, '3d' => 0 }, :color => 3,
           :skips => {}, :errors => ['colour on "x": E: m'] }
    WR_CalloutStyle.summary_lines(c2).each { |l| out << "sum-b|#{l}" }
    out.join("\n")
  end
end

begin
  Harness.run
rescue Exception => e
  "FAIL #{e.class}: #{e.message}\n" + e.backtrace.first(6).join("\n")
end
'''

CHECKS = [0]
FAILS = []


def ck(label, got, want):
    CHECKS[0] += 1
    if got != want:
        FAILS.append('%s\n      got  %r\n      want %r' % (label, got, want))


def has(label, lines, needle):
    CHECKS[0] += 1
    if not any(needle in l for l in lines):
        FAILS.append('%s\n      no line contains %r\n      lines: %r' % (label, needle, lines))


def main():
    prog = (PROG
            .replace('@@NORMALISE@@', method_source(RB, 'normalise'))
            .replace('@@SUMMARY@@', method_source(RB, 'summary_lines')))
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

    def one(name):
        v = by.get(name, [])
        ck('%s: exactly one result' % name, len(v), 1)
        return v[0] if v else ''

    # 1. A good request round-trips with the hex lower-cased and the size an integer.
    ck('good-all', one('good-all'),
       'OK|all|nil|text,dim,3d|{:name=>"Arial", :size=>12, :bold=>false, :italic=>false}|"#ee6216"')
    # 2. Hex without the hash is accepted and normalised.
    ck('hex-nohash', one('hex-nohash'), 'OK|all|nil|text|nil|"#ee6216"')
    # 3-5. Bad hex, size 0, non-numeric size are refused with a sentence.
    ck('hex-bad refused', one('hex-bad').startswith('ERR|Colour must be'), True)
    ck('size-zero refused', one('size-zero').startswith('ERR|Size must be'), True)
    ck('size-text refused', one('size-text').startswith('ERR|Size must be'), True)
    # 6. Neither font nor colour on: refused, not a silent no-op sweep.
    ck('nothing-on refused', one('nothing-on').startswith('ERR|Tick Change font'), True)
    # 7. No kinds: refused.
    ck('no-kinds refused', one('no-kinds').startswith('ERR|Tick at least one'), True)
    # 8. An unknown kind is dropped, the known one kept; bold/italic carried.
    ck('bad-kind', one('bad-kind'),
       'OK|all|nil|text|{:name=>"Arial", :size=>12, :bold=>true, :italic=>true}|nil')
    # 9. Tag scope splits into scope + tag.
    ck('tag', one('tag'), 'OK|tag|"WR-Dims-Plan"|dim|nil|"#000000"')
    ck('tag-empty refused', one('tag-empty').startswith('ERR|Pick a set'), True)
    ck('sel', one('sel'), 'OK|sel|nil|dim|nil|"#000000"')
    ck('scope-junk falls back to all', one('scope-junk'), 'OK|all|nil|dim|nil|"#000000"')
    ck('name-blank refused', one('name-blank').startswith('ERR|Type a font name'), True)
    ck('not-hash refused (kinds first)', one('not-hash').startswith('ERR|Tick at least one'), True)

    # 10. The report names every count and every skip reason.
    a = by.get('sum-a', [])
    has('sum-a: total with kinds', a, 'Touched 35 callout(s) — 3 notes, 30 dimensions, 2 3D labels.')
    has('sum-a: font count', a, 'Font set on 3.')
    has('sum-a: colour count', a, 'Colour set on 35.')
    has('sum-a: dim skip with the manual route', a, 'Skipped 30: dimension font is not settable from Ruby')
    has('sum-a: 3d skip', a, 'Skipped 2: 3D label face is fixed geometry')
    has('sum-a: undo line', a, 'Ctrl+Z undoes the whole sweep.')
    ck('sum-a: no failure lines', any(l.startswith('FAILED') for l in a), False)
    b = by.get('sum-b', [])
    ck('sum-b: no font line when font was off', any(l.startswith('Font set') for l in b), False)
    has('sum-b: failure surfaced', b, 'FAILED colour on "x": E: m')

    print('rbtest-callout-style: %d check(s), %d failed' % (CHECKS[0], len(FAILS)))
    for f in FAILS:
        print('  FAIL ' + f)
    return 1 if FAILS else 0


if __name__ == '__main__':
    sys.exit(main())
