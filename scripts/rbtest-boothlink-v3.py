# -*- coding: utf-8 -*-
"""RUN booth-from-link's #3= structural decoder outside SketchUp.

    python rbtest-boothlink-v3.py

Same discipline as rbtest-boothlink-cbl.py: boots SketchUp's own CRuby 3.2
through rbparse.py and lifts the decoder VERBATIM out of booth-from-link.rb
(`v3_hash`, `v3_bytes`, `v3_slots`, `v3_snap`, `v3_sku`, `v3_payload`, and the
old-path `hash_payload`, plus the frozen wire-format tables), so this test
cannot drift from the code it tests.

WHY IT EXISTS
-------------
Portal v2.502.0 (2026-09-01) ships a third link form, `#3=`: a base64url byte
array 15-39 characters long where `#d=` ran 407-764. The wire-format guide
("The #3= booth-design link") gives three worked examples produced by the
shipping encoder itself and pinned by the portal's 135-check suite. This file
decodes all three and asserts every value the guide states, plus every refusal
the guide requires — because the decoder's whole contract is "a complete
payload or a named refusal, never half a booth".

WHAT IT ASSERTS
  1. the guide's primary worked example (MDL 96120 E, right door, Gray foam,
     VSS+EFS+studio light+MJP+desk small/inside+bass traps, room 14'6" x 16'
     x 9', no corner) decodes to exactly the guide's stated values
  2. the guide's bone-stock example (MDL 4230 S, no options, no room) and
     fully-loaded example (MDL 102186 E, left door, Burgundy, package
     "Audiology Premium", SE corner, 20' x 24'6" x 10') do too
  3. every named refusal: bad alphabet, impossible base64 length, truncated
     payload, trailing bytes, unknown format version, unknown model index,
     unknown foam, reserved flag bits, unknown corner, unknown package,
     out-of-range desk/MJP ordinals, unknown wall-map vocabulary byte
  4. the wall-map byte 255 means "slot default", i.e. the slot is simply
     absent from `a`
  5. the canonical slot enumeration derived from wr-booth-data.rb matches the
     guide's frozen table for all 25 models, Standard and Enhanced alike
  6. the OLD `#d=` path still decodes — same regex, same alphabet swap, same
     padding — and still returns nil for a link with no hash

The harness stubs exactly one platform fact: the minimal VM rbparse boots has
no stdlib `json`, so a 30-line JSON.parse stand-in (objects, plain strings,
integers — everything a booth payload contains) is defined here. hash_payload
itself is lifted verbatim.

MUTATION-CHECKED when written. Swap V3_MODELS indexes 16 and 17 and the
primary example decodes MDL 96144 and fails on `m`; drop the reserved-bits
raise and the reserved-bit check fails; change the room nibble order and the
14'6" room reads 6'14".
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbparse  # noqa: E402
from rbtest import method_source  # noqa: E402

DATA_RB = os.path.join(HERE, 'wr-booth-data.rb').replace('\\', '/')

PROG = r'''
# Platform shim: the minimal VM has no String#unpack/unpack1 (it exists in
# SketchUp's full VM, where hash_payload has run in production for weeks).
# Only the 'm' directive hash_payload uses is provided, with 'm' semantics:
# characters outside the alphabet, '=' included, are skipped.
class String
  def unpack1(fmt)
    raise "shim supports only 'm', got #{fmt}" unless fmt == 'm'
    tbl = {}
    (('A'..'Z').to_a + ('a'..'z').to_a + ('0'..'9').to_a + ['+', '/'])
      .each_with_index { |c, i| tbl[c] = i }
    acc = 0
    n = 0
    out = []
    each_char do |c|
      next unless tbl.key?(c)
      acc = (acc << 6) | tbl[c]
      n += 6
      next if n < 8
      n -= 8
      out << ((acc >> n) & 0xFF)
    end
    out.map(&:chr).join   # the minimal VM has no Array#pack either
  end
end

# Minimal JSON stand-in: the harness VM has no stdlib json (native ext).
# Parses only what a booth payload contains: objects, escape-free strings,
# integers. hash_payload itself is the lifted original.
module JSON
  def self.parse(s)
    toks = s.scan(/"[^"]*"|-?\d+|[{}\[\]:,]/)
    v = value(toks)
    raise 'trailing tokens' unless toks.empty?
    v
  end
  def self.value(t)
    tok = t.shift
    case tok
    when '{'
      h = {}
      if t.first == '}'
        t.shift
      else
        loop do
          k = t.shift
          raise 'bad key' unless k.is_a?(String) && k.start_with?('"')
          raise 'expected :' unless t.shift == ':'
          h[k[1..-2]] = value(t)
          d = t.shift
          break if d == '}'
          raise 'expected ,' unless d == ','
        end
      end
      h
    when /\A"/ then tok[1..-2]
    when /\A-?\d+\z/ then tok.to_i
    else raise "unexpected token #{tok.inspect}"
    end
  end
end

module WR_BoothLink
  DATA = '@@DATA_RB@@'

@@V3REFUSAL@@

@@CONSTS@@

@@V3_HASH@@

@@V3_BYTES@@

@@V3_SLOTS@@

@@V3_SNAP@@

@@V3_SKU@@

@@V3_PAYLOAD@@

@@HASH_PAYLOAD@@
end

$results = []
def check(name, got, want)
  $results << [name, got == want, "got #{got.inspect}, wanted #{want.inspect}"]
end

def refuses(name, hash, *needles)
  begin
    WR_BoothLink.v3_payload(hash)
    $results << [name, false, 'decoded without complaint']
  rescue WR_BoothLink::V3Refusal => e
    miss = needles.reject { |n| e.message.include?(n) }
    $results << [name, miss.empty?,
                 "message #{e.message.inspect} lacks #{miss.inspect}"]
  rescue Exception => e
    $results << [name, false, "wrong error class: #{e.message}"]
  end
end

# bytes -> unpadded base64url, for crafting refusal vectors. Hand-rolled:
# the minimal VM has neither Array#pack nor String#unpack.
B64CH = ('A'..'Z').to_a + ('a'..'z').to_a + ('0'..'9').to_a + ['-', '_']
def enc(bytes)
  acc = 0
  n = 0
  out = ''
  bytes.each do |b|
    acc = (acc << 8) | b
    n += 8
    while n >= 6
      n -= 6
      out << B64CH[(acc >> n) & 63]
    end
  end
  out << B64CH[(acc << (6 - n)) & 63] if n > 0
  out
end

FLAG_KEYS = %w[wd rp hx cs vs ef rv sl jp bt dk sp nv ac ad ep dl hp dox re]

# ---- 1: the guide's primary worked example -------------------------------
# MDL 96120, Enhanced, right-hand door, Gray foam. VSS on, EFS on, studio
# light on, MJP on, office desk on (small, inside), LENRD bass traps on,
# everything else off. Room 14'6" x 16' x 9', no corner. Hash 30 chars.
p1 = WR_BoothLink.v3_payload('ARAFsAcwAA4QCW_wAQABAwAAAQAAAA')
check('ex1 model',    p1['m'], 'MDL 96120')
check('ex1 variant',  p1['v'], 'E')
check('ex1 hinge',    p1['h'], 'R')
check('ex1 foam',     p1['f'], 'Gray')
check('ex1 facing',   p1['fc'], 'S')
check('ex1 ver',      p1['ver'], 2)
on1 = %w[vs ef sl jp bt dk]
FLAG_KEYS.each do |k|
  check("ex1 flag #{k}", p1[k], on1.include?(k) ? 1 : 0)
end
check('ex1 desk is the small one (dl clear)',   p1['dl'], 0)
check('ex1 desk is inside (dox clear)',         p1['dox'], 0)
check('ex1 room', p1['rm'],
      { 'wFt' => '14', 'wIn' => '6', 'lFt' => '16', 'lIn' => '',
        'cFt' => '9', 'cIn' => '' })
check('ex1 no corner',    p1.key?('rc'), false)
check('ex1 no package',   p1.key?('pk'), false)
check('ex1 no desk slot', p1.key?('ds'), false)
check('ex1 no MJP slot',  p1.key?('ms'), false)
check('ex1 wall map', p1['a'],
      { 'N0' => 'STDWL46 VNT', 'N1' => 'STDWL22', 'N2' => 'STDWL46 VNT',
        'S0' => 'STDWL46 DRFRM R', 'S1' => 'STDWL22', 'S2' => 'STDWL46',
        'E0' => 'STDWL46 VNT', 'E1' => 'STDWL46',
        'W0' => 'STDWL46', 'W1' => 'STDWL46' })

# ---- 2a: the bone-stock small booth --------------------------------------
# MDL 4230, Standard, right door, Gray, no options, no room. 15-char hash.
p2 = WR_BoothLink.v3_payload('AQAEAAAgAAEDAAA')
check('ex2 model',   p2['m'], 'MDL 4230')
check('ex2 variant', p2['v'], 'S')
check('ex2 hinge',   p2['h'], 'R')
check('ex2 foam',    p2['f'], 'Gray')
check('ex2 all option flags off', FLAG_KEYS.map { |k| p2[k] }.uniq, [0])
check('ex2 no room', p2.key?('rm'), false)
check('ex2 wall map', p2['a'],
      { 'N0' => 'STDWL40 VNT', 'S0' => 'STDWL40 DRFRM R',
        'E0' => 'STDWL28', 'W0' => 'STDWL28' })

# ---- 2b: the fully loaded large booth ------------------------------------
# MDL 102186, Enhanced, LEFT door, Burgundy, facing the left (W) wall.
# wd rp hx vs ef sl jp bt dk ac ad ep dl hp on; cs rv sp nv dox re off.
# Package "Audiology Premium", SE corner, room 20' x 24'6" x 10'. 39 chars.
p3 = WR_BoothLink.v3_payload('ARhPt-czCQoUGAr28AEBAAEBAwAAAAAAAAAAAAA')
check('ex3 model',   p3['m'], 'MDL 102186')
check('ex3 variant', p3['v'], 'E')
check('ex3 hinge',   p3['h'], 'L')
check('ex3 foam',    p3['f'], 'Burgundy')
check('ex3 facing',  p3['fc'], 'W')
on3 = %w[wd rp hx vs ef sl jp bt dk ac ad ep dl hp]
FLAG_KEYS.each do |k|
  check("ex3 flag #{k}", p3[k], on3.include?(k) ? 1 : 0)
end
check('ex3 package', p3['pk'], 'Audiology Premium')
check('ex3 corner',  p3['rc'], 'SE')
check('ex3 room', p3['rm'],
      { 'wFt' => '20', 'wIn' => '', 'lFt' => '24', 'lIn' => '6',
        'cFt' => '10', 'cIn' => '' })
check('ex3 wall map', p3['a'],
      { 'N0' => 'STDWL40 VNT', 'N1' => 'STDWL40 VNT', 'N2' => 'STDWL16',
        'N3' => 'STDWL40 VNT', 'N4' => 'STDWL40 VNT',
        'S0' => 'STDWL40 DRFRM L', 'S1' => 'STDWL40', 'S2' => 'STDWL16',
        'S3' => 'STDWL40', 'S4' => 'STDWL40',
        'E0' => 'STDWL40', 'E1' => 'STDWL16', 'E2' => 'STDWL40',
        'W0' => 'STDWL40', 'W1' => 'STDWL16', 'W2' => 'STDWL40' })

# ---- 3: every refusal is by name -----------------------------------------
refuses('bad alphabet char',  'AR+FsA', 'base64url')
refuses('impossible length',  'AAAAA', 'lost characters')
refuses('shorter than the 7-byte header', enc([1, 0, 4]), 'truncated')
refuses('truncated wall map', enc([1, 0, 4, 0, 0, 32, 0, 1, 3, 0]),
        'truncated', 'MDL 4230')
refuses('trailing byte',      enc([1, 0, 4, 0, 0, 32, 0, 1, 3, 0, 0, 0]),
        'trailing')
refuses('unknown format version', enc([2, 0, 4, 0, 0, 0, 0]),
        'format version 2')
refuses('unknown model index',    enc([1, 200, 4, 0, 0, 0, 0]),
        'model index 200')
refuses('unknown foam index',     enc([1, 0, 4 | (5 << 4), 0, 0, 0, 0]),
        'foam colour index 5')
refuses('reserved flag bit set',  enc([1, 0, 4, 0, 0, 0, 128]),
        'reserved')
refuses('unknown corner value',   enc([1, 0, 4, 0, 0, 0, 10]),
        'room-corner value 5')
refuses('unknown package index',  enc([1, 0, 4, 0, 0, 0, 1, 19]),
        'package index 19')
refuses('desk ordinal 0',         enc([1, 0, 4, 0, 0, 64, 0, 0]),
        'desk-slot ordinal 0')
refuses('desk ordinal past the slot count', enc([1, 0, 4, 0, 0, 64, 0, 5]),
        'desk-slot ordinal 5', '1..4')
refuses('MJP ordinal past the slot count',  enc([1, 0, 4, 0, 0, 128, 0, 9]),
        'MJP-slot ordinal 9')
refuses('wall-map byte outside the vocabulary',
        enc([1, 0, 4, 0, 0, 32, 0, 16, 3, 0, 0]), 'slot vocabulary', 'N0')

# ---- 4: 255 in the wall map means "slot default", i.e. absent from a -----
p255 = WR_BoothLink.v3_payload(enc([1, 0, 4, 0, 0, 32, 0, 255, 3, 255, 255]))
check('255 slots fall to the layout default', p255['a'],
      { 'S0' => 'STDWL40 DRFRM R' })

# desk/MJP ordinals translate to slot ID STRINGS, as #d= carries them
pds = WR_BoothLink.v3_payload(enc([1, 0, 4, 0, 4, 64, 0, 3]))
check('desk ordinal 3 -> slot id E0', pds['ds'], 'E0')
pms = WR_BoothLink.v3_payload(enc([1, 0, 4, 0, 1, 128, 0, 2]))
check('MJP ordinal 2 -> slot id S0', pms['ms'], 'S0')

# ---- 5: the derived slot order matches the guide's frozen table ----------
GUIDE_ORDER = {
  'MDL 4230'   => 'N0 S0 E0 W0',
  'MDL 4242'   => 'N0 S0 E0 W0',
  'MDL 4260'   => 'N0 N1 S0 S1 E0 W0',
  'MDL 4284'   => 'N0 N1 S0 S1 E0 W0',
  'MDL 4848'   => 'N0 S0 E0 W0',
  'MDL 4872'   => 'N0 N1 S0 S1 E0 W0',
  'MDL 4896'   => 'N0 N1 S0 S1 E0 W0',
  'MDL 6060'   => 'N0 N1 S0 S1 E0 E1 W0 W1',
  'MDL 6084'   => 'N0 N1 S0 S1 E0 E1 W0 W1',
  'MDL 7272'   => 'N0 N1 S0 S1 E0 E1 W0 W1',
  'MDL 7296'   => 'N0 N1 S0 S1 E0 E1 W0 W1',
  'MDL 8484'   => 'N0 N1 S0 S1 E0 E1 W0 W1',
  'MDL 9696'   => 'N0 N1 S0 S1 E0 E1 W0 W1',
  'MDL 10284'  => 'N0 N1 S0 S1 E0 E1 E2 W0 W1 W2',
  'MDL 84102'  => 'N0 N1 N2 S0 S1 S2 E0 E1 W0 W1',
  'MDL 84126'  => 'N0 N1 N2 S0 S1 S2 E0 E1 W0 W1',
  'MDL 96120'  => 'N0 N1 N2 S0 S1 S2 E0 E1 W0 W1',
  'MDL 96144'  => 'N0 N1 N2 S0 S1 S2 E0 E1 W0 W1',
  'MDL 96168'  => 'N0 N1 N2 N3 S0 S1 S2 S3 E0 E1 W0 W1',
  'MDL 96192'  => 'N0 N1 N2 N3 S0 S1 S2 S3 E0 E1 W0 W1',
  'MDL 102102' => 'N0 N1 N2 S0 S1 S2 E0 E1 E2 W0 W1 W2',
  'MDL 102126' => 'N0 N1 N2 S0 S1 S2 E0 E1 E2 W0 W1 W2',
  'MDL 102144' => 'N0 N1 N2 N3 S0 S1 S2 S3 E0 E1 E2 W0 W1 W2',
  'MDL 102168' => 'N0 N1 N2 N3 S0 S1 S2 S3 E0 E1 E2 W0 W1 W2',
  'MDL 102186' => 'N0 N1 N2 N3 N4 S0 S1 S2 S3 S4 E0 E1 E2 W0 W1 W2'
}
check('model table names all 25 guide models, in guide order',
      WR_BoothLink::V3_MODELS.map { |m, _| m }, GUIDE_ORDER.keys)
GUIDE_ORDER.each do |model, order|
  %w[S E].each do |var|
    got = WR_BoothLink.v3_slots("#{model} #{var}")
    check("slot order #{model} #{var}",
          got && got.map { |sid, _| sid }.join(' '), order)
  end
end

# ---- 6: the OLD #d= path still decodes -----------------------------------
json = '{"m":"MDL 7272","v":"S","h":"R","f":"Gray","vs":1,"ef":0,' \
       '"a":{"N0":"STDWL46 VNT","S0":"STDWL46 DRFRM R"},"ver":2}'
d_hash = enc(json.bytes)   # enc already writes the url alphabet, unpadded
old = WR_BoothLink.hash_payload("https://sales.whisperroom.com/booth-builder#d=#{d_hash}")
check('#d= still decodes: model',  old && old['m'], 'MDL 7272')
check('#d= still decodes: vs',     old && old['vs'], 1)
check('#d= still decodes: a',      old && old['a'],
      { 'N0' => 'STDWL46 VNT', 'S0' => 'STDWL46 DRFRM R' })
check('#d= absent -> nil, not an error',
      WR_BoothLink.hash_payload('https://sales.whisperroom.com/booth-builder?d=abc'), nil)
check('#3= link is not mistaken for #d=',
      WR_BoothLink.hash_payload('https://x/booth-builder#3=AQAEAAAgAAEDAAA'), nil)
check('v3_hash finds the new hash',
      WR_BoothLink.v3_hash('https://x/booth-builder#3=AQAEAAAgAAEDAAA'),
      'AQAEAAAgAAEDAAA')
check('v3_hash leaves a #d= link alone',
      WR_BoothLink.v3_hash("https://x/booth-builder#d=#{d_hash}"), nil)

out = $results.map { |(n, ok, d)| (ok ? 'PASS ' : 'FAIL ') + n + (ok ? '' : '   ' + d) }
(out.join("\n") + "\n" + $results.count { |r| !r[1] }.to_s + ' failure(s)').dup
'''


def consts(path):
    """The frozen wire-format tables, lifted verbatim so they cannot drift
    from the ones the decoder actually indexes."""
    text = open(path, encoding='utf-8').read()
    out = []
    for name in ('V3_MODELS', 'V3_FOAM', 'V3_FACING', 'V3_CORNER',
                 'V3_FLAGS', 'V3_PACKAGES', 'V3_B64'):
        m = re.search(r'^  %s\s+= .*?\.freeze$' % name, text, re.S | re.M)
        if not m:
            raise SystemExit('booth-from-link.rb: %s not found' % name)
        out.append(m.group(0))
    return '\n\n'.join(out)


def refusal_class(path):
    text = open(path, encoding='utf-8').read()
    m = re.search(r'^  class V3Refusal.*$', text, re.M)
    if not m:
        raise SystemExit('booth-from-link.rb: class V3Refusal not found')
    return m.group(0)


def main():
    src = os.path.join(HERE, 'booth-from-link.rb')
    prog = (PROG
            .replace('@@DATA_RB@@', DATA_RB)
            .replace('@@V3REFUSAL@@', refusal_class(src))
            .replace('@@CONSTS@@', consts(src)))
    for token, name in (('@@V3_HASH@@', 'v3_hash'),
                        ('@@V3_BYTES@@', 'v3_bytes'),
                        ('@@V3_SLOTS@@', 'v3_slots'),
                        ('@@V3_SNAP@@', 'v3_snap'),
                        ('@@V3_SKU@@', 'v3_sku'),
                        ('@@V3_PAYLOAD@@', 'v3_payload'),
                        ('@@HASH_PAYLOAD@@', 'hash_payload')):
        prog = prog.replace(token, method_source(src, name))
    got = rbparse.rb_eval(rbparse.boot(), prog)
    print(got)
    if got.startswith('FAIL ') or 'error' in got[:40].lower():
        return 1
    return 0 if got.rstrip().endswith('0 failure(s)') else 1


if __name__ == '__main__':
    sys.exit(main())
