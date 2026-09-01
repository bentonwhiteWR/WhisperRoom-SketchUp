# -*- coding: utf-8 -*-
"""RUN wr-png-srgb.rb — the render lane's sRGB post-encode — outside SketchUp.

    python rbtest-srgb.py

WHY THIS EXISTS
---------------
MEASURED 1 Sep 2026: the proposal package's V-Ray lane saves the LINEAR frame
buffer (batch file mean 0.1585, max 0.682; the same frame by hand ~0.35 and
1.000; an sRGB curve maps one onto the other exactly). wr-png-srgb.rb fixes
the saved file deterministically — decode, sRGB-encode every colour byte,
declare the colour space, verify, replace. That module runs on client
deliverables and CANNOT be executed in SketchUp before it ships, so this
harness runs it END TO END in the same CRuby 3.2 VM rbparse.py boots from
SketchUp's own DLL — encode_file itself, temp-verify and replace included,
on real PNG files this script builds and then independently re-verifies.

WHAT IS REAL AND WHAT IS SHIMMED
--------------------------------
The minimal VM has no zlib, so the module's three zlib seams (inflate /
deflate / crc32) are replaced here with pure-Ruby stand-ins: a STORED-BLOCK
zlib stream writer/reader (the fixtures are compressed with Python
zlib.compress(level=0), which emits stored blocks) and a table CRC-32. Both
produce REAL zlib streams and REAL CRCs — Python's zlib validates every byte
of the Ruby output below, so the only code not exercised is stdlib zlib
itself. Everything else — the LUT, all five PNG filters, the chunk
parser/builder, refusal(), encode_file(), measure_file() — is the very code
SketchUp runs, loaded from wr-png-srgb.rb on every run.

WHAT IT PROVES
--------------
  lut       all 256 LUT entries equal the independently computed sRGB curve
            (round half away from zero), 0 -> 0 and 255 -> 255 exact
  paeth     the spec's predictor on hand vectors
  rgb       encode_file on an RGB fixture whose five rows use filter types
            0,1,2,3,4: returns ok, the file re-decodes (in Python, with real
            zlib) to exactly LUT(pixel) per channel, sRGB+gAMA chunks are
            stamped right after IHDR, every chunk CRC is valid, ancillary
            chunks (pHYs, tEXt) survive in order, and the temp file is gone
  rgba      same, and every ALPHA byte is byte-identical to the original
  means     encode_file's before/after means and maxes equal the Python-
            computed values for the fixture
  measure   measure_file on a pristine fixture reports the Python-computed
            mean/max and the declared-colour-chunk list
  refusals  16-bit, palette, interlaced, gAMA-present, truncated, bad-CRC
            files each refuse BY NAME and the file on disk is byte-untouched

MUTATION-CHECKED when written (run, not assumed, 1 Sep 2026) — each of these
reintroduced bugs makes the named check FAIL:

    LUT threshold 0.0031308 -> 0.31308        -> lut + both pixel checks FAIL
    Paeth 2nd tie-break `pb <= pc` -> `<`     -> paeth FAIL (vector (0,3,1);
                                                 the FIRST tie-break is
                                                 mathematically immune — a
                                                 pa==pb tie forces a==b or
                                                 pc==0, same answer both ways)
    alpha byte run through the LUT            -> rgba-pixels + rgba-alpha FAIL
    deflate output corrupted before verify    -> both ENC rows FAIL with
                                                 'verify failed', originals
                                                 left untouched
    gAMA refusal deleted                      -> refuse-gamma FAIL

NOTE the module was written for this VM's gaps on purpose: no Float#to_f, no
Object#class, no Array#pack anywhere in it (bytes_to_str falls back to
chr-join when pack is missing, which is exercised here; the pack fast path
runs only inside SketchUp).
"""
import os
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rbparse  # noqa: E402

SRC = os.path.join(HERE, 'wr-png-srgb.rb').replace('\\', '/')

SCRATCH = os.environ.get('WR_SRGB_TEST_DIR') or os.path.join(
    os.environ.get('TEMP', HERE), 'wr-srgb-test')


# ---------------------------------------------------------------- fixtures --

def srgb_byte(i):
    v = i / 255.0
    s = v * 12.92 if v <= 0.0031308 else 1.055 * (v ** (1.0 / 2.4)) - 0.055
    s = min(max(s, 0.0), 1.0)
    return int(s * 255.0 + 0.5)   # round half AWAY from zero, like Ruby


def paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def filter_row(ftype, cur, prev, bpp):
    out = [ftype]
    for i, x in enumerate(cur):
        a = cur[i - bpp] if i >= bpp else 0
        b = prev[i]
        c = prev[i - bpp] if i >= bpp else 0
        if ftype == 0:
            out.append(x)
        elif ftype == 1:
            out.append((x - a) & 255)
        elif ftype == 2:
            out.append((x - b) & 255)
        elif ftype == 3:
            out.append((x - ((a + b) >> 1)) & 255)
        else:
            out.append((x - paeth(a, b, c)) & 255)
    return out


def chunk(ctype, data):
    body = ctype + data
    return struct.pack('>I', len(data)) + body + struct.pack('>I', zlib.crc32(body))


def build_png(w, h, ctype_code, rows_pixels, filters, extra_before_idat=(),
              extra_after_idat=(), level=0, bit_depth=8, interlace=0,
              corrupt_crc=False, truncate_idat=False):
    """rows_pixels: list of rows, each a flat list of channel bytes."""
    bpp = 4 if ctype_code == 6 else 3
    raw = []
    prev = [0] * (w * bpp)
    for row, ft in zip(rows_pixels, filters):
        raw += filter_row(ft, row, prev, bpp)
        prev = row
    comp = zlib.compress(bytes(raw), level)
    if truncate_idat:
        comp = comp[:len(comp) // 2]
    ihdr = struct.pack('>IIBBBBB', w, h, bit_depth, ctype_code, 0, 0, interlace)
    out = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', ihdr)
    for t, d in extra_before_idat:
        out += chunk(t, d)
    idat = chunk(b'IDAT', comp)
    if corrupt_crc:
        idat = idat[:-1] + bytes([idat[-1] ^ 0xFF])
    out += idat
    for t, d in extra_after_idat:
        out += chunk(t, d)
    out += chunk(b'IEND', b'')
    return out


def decode_png(data):
    """Full decode with real zlib — validates CRCs. Returns (ihdr, chunks, rows)."""
    assert data[:8] == b'\x89PNG\r\n\x1a\n', 'bad signature'
    pos = 8
    chunks = []
    while pos < len(data):
        ln = struct.unpack('>I', data[pos:pos + 4])[0]
        ct = data[pos + 4:pos + 8]
        cd = data[pos + 8:pos + 8 + ln]
        crc = struct.unpack('>I', data[pos + 8 + ln:pos + 12 + ln])[0]
        assert crc == zlib.crc32(ct + cd), 'CRC bad in %s' % ct
        chunks.append((ct, cd))
        pos += 12 + ln
        if ct == b'IEND':
            break
    ihdr = struct.unpack('>IIBBBBB', dict(chunks)[b'IHDR'])
    w, h, depth, ctype = ihdr[0], ihdr[1], ihdr[2], ihdr[3]
    assert depth == 8
    bpp = 4 if ctype == 6 else 3
    raw = zlib.decompress(b''.join(d for t, d in chunks if t == b'IDAT'))
    stride = w * bpp
    rows = []
    prev = [0] * stride
    p = 0
    for _ in range(h):
        ft = raw[p]
        line = list(raw[p + 1:p + 1 + stride])
        cur = []
        for i, x in enumerate(line):
            a = cur[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if ft == 0:
                cur.append(x)
            elif ft == 1:
                cur.append((x + a) & 255)
            elif ft == 2:
                cur.append((x + b) & 255)
            elif ft == 3:
                cur.append((x + ((a + b) >> 1)) & 255)
            else:
                cur.append((x + paeth(a, b, c)) & 255)
        rows.append(cur)
        prev = cur
        p += 1 + stride
    return (ihdr, chunks, rows)


def mean_max(rows, bpp):
    total, mx, n = 0, 0, 0
    for r in rows:
        for i, v in enumerate(r):
            if bpp == 4 and (i & 3) == 3:
                continue
            total += v
            mx = max(mx, v)
            n += 1
    return (total / (255.0 * n), mx / 255.0)


# The RGB fixture: 4x5, one row per filter type, values chosen to exercise
# wraparound and both LUT branches (0 stays 0; low values brighten a lot).
W, H = 4, 5
RGB_ROWS = [
    [0, 1, 2, 3, 40, 41, 250, 251, 252, 13, 128, 255],
    [10, 200, 30, 90, 90, 90, 5, 250, 100, 7, 8, 9],
    [255, 0, 255, 0, 255, 0, 128, 127, 126, 1, 2, 3],
    [17, 34, 51, 68, 85, 102, 119, 136, 153, 170, 187, 204],
    [200, 100, 50, 25, 12, 6, 3, 1, 0, 255, 254, 253],
]
RGB_FILTERS = [0, 1, 2, 3, 4]

# The RGBA fixture: 3x3 with distinctive alphas (must come through untouched).
WA, HA = 3, 3
RGBA_ROWS = [
    [10, 20, 30, 0, 40, 50, 60, 128, 70, 80, 90, 255],
    [200, 210, 220, 17, 230, 240, 250, 34, 5, 15, 25, 51],
    [1, 2, 3, 68, 100, 110, 120, 85, 130, 140, 150, 102],
]
RGBA_FILTERS = [0, 2, 4]


def build_fixtures():
    os.makedirs(SCRATCH, exist_ok=True)
    f = {}

    def put(name, data):
        p = os.path.join(SCRATCH, name)
        with open(p, 'wb') as fh:
            fh.write(data)
        f[name] = data
        return p

    put('rgb.png', build_png(W, H, 2, RGB_ROWS, RGB_FILTERS,
                             extra_before_idat=[(b'pHYs', struct.pack('>IIB', 2835, 2835, 1))],
                             extra_after_idat=[(b'tEXt', b'Comment\x00wr-test')]))
    put('rgba.png', build_png(WA, HA, 6, RGBA_ROWS, RGBA_FILTERS))
    put('measure.png', build_png(W, H, 2, RGB_ROWS, RGB_FILTERS))
    # refusals — every one must come back byte-identical afterwards
    put('depth16.png', build_png(2, 1, 2, [[0, 1, 2, 3, 4, 5]], [0], bit_depth=16))
    put('palette.png', build_png(2, 1, 3, [[0, 1, 2, 3, 4, 5]], [0]))
    put('interlaced.png', build_png(W, H, 2, RGB_ROWS, RGB_FILTERS, interlace=1))
    put('gamma.png', build_png(W, H, 2, RGB_ROWS, RGB_FILTERS,
                               extra_before_idat=[(b'gAMA', struct.pack('>I', 45455))]))
    put('truncated.png', build_png(W, H, 2, RGB_ROWS, RGB_FILTERS, truncate_idat=True))
    put('badcrc.png', build_png(W, H, 2, RGB_ROWS, RGB_FILTERS, corrupt_crc=True))
    return f


# ------------------------------------------------------------ ruby program --

RUBY = r'''
(begin
  out = []
  load %(src)r

  # ---- shims for the three zlib seams: REAL zlib streams, pure Ruby ----
  module WR_PNGSRGB
    CRC_TABLE = (0..255).map do |n|
      c = n
      8.times { c = (c & 1) == 1 ? 0xEDB88320 ^ (c >> 1) : c >> 1 }
      c
    end
    def self.crc32(str)
      c = 0xFFFFFFFF
      str.bytes.each { |b| c = CRC_TABLE[(c ^ b) & 0xFF] ^ (c >> 8) }
      c ^ 0xFFFFFFFF
    end
    def self.adler32(bytes)
      a = 1
      b = 0
      bytes.each do |x|
        a = (a + x) %% 65521
        b = (b + a) %% 65521
      end
      (b << 16) | a
    end
    def self.deflate(str)
      data = str.bytes
      out = [0x78, 0x01]
      pos = 0
      loop do
        part = data[pos, 65535] || []
        pos += part.size
        final = pos >= data.size ? 1 : 0
        out << final
        out << (part.size & 0xFF) << ((part.size >> 8) & 0xFF)
        n = part.size ^ 0xFFFF
        out << (n & 0xFF) << ((n >> 8) & 0xFF)
        out.concat(part)
        break if final == 1
      end
      ad = adler32(data)
      out << ((ad >> 24) & 0xFF) << ((ad >> 16) & 0xFF) << ((ad >> 8) & 0xFF) << (ad & 0xFF)
      bytes_to_str(out)
    end
    def self.inflate(str)
      d = str.bytes
      raise 'shim: not a zlib stream' if d.size < 6
      pos = 2
      outb = []
      loop do
        hdr = d[pos]
        raise 'shim: truncated' if hdr.nil?
        raise 'shim inflate handles only stored blocks' unless (hdr >> 1) & 3 == 0
        len = d[pos + 1] | (d[pos + 2] << 8)
        nlen = d[pos + 3] | (d[pos + 4] << 8)
        raise 'shim: LEN/NLEN mismatch' unless (len ^ 0xFFFF) == nlen
        part = d[pos + 5, len]
        raise 'shim: truncated stored block' if part.nil? || part.size < len
        outb.concat(part)
        pos += 5 + len
        break if (hdr & 1) == 1
      end
      ad = (d[pos] << 24) | (d[pos + 1] << 16) | (d[pos + 2] << 8) | d[pos + 3]
      raise 'shim: adler mismatch' unless ad == adler32(outb)
      bytes_to_str(outb)
    end
  end

  dir = %(dir)r

  out << ('LUT ' + WR_PNGSRGB.srgb_lut.join(','))

  pv = [WR_PNGSRGB.paeth(0, 0, 0), WR_PNGSRGB.paeth(10, 20, 30),
        WR_PNGSRGB.paeth(100, 90, 95), WR_PNGSRGB.paeth(5, 200, 100),
        WR_PNGSRGB.paeth(50, 50, 50), WR_PNGSRGB.paeth(200, 10, 10),
        WR_PNGSRGB.paeth(0, 3, 1)]
  out << ('PAETH ' + pv.join(','))

  %%w[rgb rgba].each do |nm|
    p = dir + '/' + nm + '.png'
    r = WR_PNGSRGB.encode_file(p)
    if r[:ok]
      out << format('ENC %%s ok before=%%.6f after=%%.6f maxb=%%.6f maxa=%%.6f tmp=%%s',
                    nm, r[:before], r[:after], r[:max_before], r[:max_after],
                    File.exist?(p + '.srgb-tmp') ? 'LEFT' : 'gone')
    else
      out << ('ENC ' + nm + ' FAIL ' + r[:why].to_s)
    end
  end

  m = WR_PNGSRGB.measure_file(dir + '/measure.png')
  if m[:ok]
    out << format('MEASURE ok mean=%%.6f max=%%.6f w=%%d h=%%d declared=[%%s]',
                  m[:mean], m[:max], m[:w], m[:h], m[:declared].join(','))
  else
    out << ('MEASURE FAIL ' + m[:why].to_s)
  end

  %%w[depth16 palette interlaced gamma truncated badcrc].each do |nm|
    r = WR_PNGSRGB.encode_file(dir + '/' + nm + '.png')
    out << (r[:ok] ? ('REF ' + nm + ' WRONGLY-OK') : ('REF ' + nm + ' refused: ' + r[:why].to_s))
  end

  out.join("\n").dup
rescue Exception => e
  ('HARNESS FAIL ' + e.message +
   (e.backtrace ? "\n" + e.backtrace.first(4).join("\n") : '')).dup
end)
'''


def main():
    fixtures = build_fixtures()
    lib = rbparse.boot()
    prog = RUBY % {'src': SRC, 'dir': SCRATCH.replace('\\', '/')}
    out = rbparse.rb_eval(lib, prog)
    lines = out.split('\n')
    if lines and lines[0].startswith('HARNESS FAIL'):
        print(out)
        return 1

    fails = []
    checks = 0

    def check(name, ok, detail=''):
        nonlocal checks
        checks += 1
        if ok:
            print('ok    %s' % name)
        else:
            fails.append(name)
            print('FAIL  %s%s' % (name, (' -- ' + detail) if detail else ''))

    def line_for(prefix):
        for ln in lines:
            if ln.startswith(prefix):
                return ln
        return ''

    # 1. the LUT, all 256 entries
    lut_line = line_for('LUT ')
    got = [int(x) for x in lut_line[4:].split(',')] if lut_line else []
    want = [srgb_byte(i) for i in range(256)]
    check('lut', got == want,
          'first mismatch at %s' % next((i for i in range(256)
                                         if i >= len(got) or got[i] != want[i]), '?'))

    # 2. paeth vectors
    pv = line_for('PAETH ')
    want_p = [paeth(0, 0, 0), paeth(10, 20, 30), paeth(100, 90, 95),
              paeth(5, 200, 100), paeth(50, 50, 50), paeth(200, 10, 10),
              paeth(0, 3, 1)]
    check('paeth', pv[6:] == ','.join(str(x) for x in want_p), pv)

    # 3/4. the two encodes -- Ruby-side report
    for nm, rows, filters, w, h, bpp in (
            ('rgb', RGB_ROWS, RGB_FILTERS, W, H, 3),
            ('rgba', RGBA_ROWS, RGBA_FILTERS, WA, HA, 4)):
        ln = line_for('ENC %s ' % nm)
        check('enc-%s-ran' % nm, ' ok ' in ln, ln)
        if ' ok ' not in ln:
            continue
        check('enc-%s-tmp-gone' % nm, 'tmp=gone' in ln, ln)
        bm, bx = mean_max(rows, bpp)
        enc_rows = [[v if (bpp == 4 and (i & 3) == 3) else srgb_byte(v)
                     for i, v in enumerate(r)] for r in rows]
        am, ax = mean_max(enc_rows, bpp)
        import re as _re
        vals = dict(_re.findall(r'(\w+)=([\d.]+)', ln))
        check('enc-%s-means' % nm,
              abs(float(vals['before']) - bm) < 1e-4 and
              abs(float(vals['after']) - am) < 1e-4 and
              abs(float(vals['maxb']) - bx) < 1e-4 and
              abs(float(vals['maxa']) - ax) < 1e-4,
              'ruby %s python before=%.6f after=%.6f' % (ln, bm, am))

        # full independent re-decode of the file Ruby wrote, with real zlib
        data = open(os.path.join(SCRATCH, nm + '.png'), 'rb').read()
        try:
            ihdr, chunks, rows_out = decode_png(data)
        except AssertionError as e:
            check('enc-%s-file-valid' % nm, False, str(e))
            continue
        check('enc-%s-file-valid' % nm, True)
        types = [t for t, d in chunks]
        check('enc-%s-declares' % nm,
              types[:3] == [b'IHDR', b'sRGB', b'gAMA'] and
              dict(chunks)[b'gAMA'] == struct.pack('>I', 45455) and
              dict(chunks)[b'sRGB'] == b'\x00',
              str(types[:4]))
        check('enc-%s-pixels' % nm, rows_out == enc_rows,
              'decoded pixels differ from LUT(original)')
        if bpp == 4:
            alpha_ok = all(rows_out[y][i] == RGBA_ROWS[y][i]
                           for y in range(HA) for i in range(3, WA * 4, 4))
            check('enc-rgba-alpha-untouched', alpha_ok)

    # ancillary chunks survive on the rgb file
    data = open(os.path.join(SCRATCH, 'rgb.png'), 'rb').read()
    _, chunks, _ = decode_png(data)
    types = [t for t, d in chunks]
    check('enc-rgb-ancillary-kept',
          b'pHYs' in types and b'tEXt' in types and
          types.index(b'pHYs') < types.index(b'IDAT') and
          dict(chunks)[b'tEXt'] == b'Comment\x00wr-test',
          str(types))

    # 5. measure_file agrees with Python on the pristine fixture
    ln = line_for('MEASURE ')
    bm, bx = mean_max(RGB_ROWS, 3)
    import re as _re
    mv = dict(_re.findall(r'(mean|max)=([\d.]+)', ln))
    check('measure', ' ok ' in ln and
          abs(float(mv.get('mean', -1)) - bm) < 1e-4 and
          abs(float(mv.get('max', -1)) - bx) < 1e-4 and
          'w=%d h=%d' % (W, H) in ln and 'declared=[]' in ln,
          '%s (python mean=%.6f max=%.6f)' % (ln, bm, bx))

    # 6. every refusal refuses BY NAME and leaves its file byte-untouched
    want_why = {
        'depth16':    'bit depth 16',
        'palette':    'colour type 3',
        'interlaced': 'interlaced',
        'gamma':      'declares a colour space (gAMA',
        'truncated':  '',            # any named reason; must just refuse
        'badcrc':     'CRC mismatch',
    }
    for nm, why in want_why.items():
        ln = line_for('REF %s ' % nm)
        check('refuse-%s' % nm, 'refused:' in ln and why in ln, ln)
        now = open(os.path.join(SCRATCH, nm + '.png'), 'rb').read()
        check('refuse-%s-untouched' % nm, now == fixtures[nm + '.png'])

    print('')
    if fails:
        print('%d of %d checks FAILED: %s' % (len(fails), checks, ', '.join(fails)))
        return 1
    print('%d checks pass. encode_file ran END TO END in SketchUp\'s own '
          'CRuby (zlib seams shimmed with real stored-block streams); every '
          'output byte was re-verified in Python with real zlib.' % checks)
    return 0


if __name__ == '__main__':
    sys.exit(main())
