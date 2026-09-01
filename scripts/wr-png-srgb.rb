# wr-png-srgb.rb — bake the sRGB transfer curve into a linear PNG, in Ruby.
#
# NOT A COMMAND. A library, `load`ed by proposal-package.rb and listed in
# wr_tools' SKIP so it never shows up in the panel as something to run.
#
# WHY THIS EXISTS. MEASURED 1 Sep 2026: the proposal package's V-Ray lane
# saves the VFB's LINEAR buffer. `Scene 4 render.png` (batch) read mean
# luminance 0.1585 with a MAXIMUM of 0.682 — it never reaches white — while
# the same frame saved by hand read ~0.35 mean, max 1.000. Apply an sRGB
# transfer curve to the batch file and it lands on 0.397, i.e. exactly on the
# hand render. The file carries NO gAMA/sRGB/iCCP chunk, so every viewer
# treats the linear data as sRGB and shows it dark. Camera EV was 14.229 in
# BOTH files, so exposure is not the cause; and save_vfb_image with
# :apply_color_corrections => true changed NOTHING measurable (retry file
# byte-different, luminance identical) — that option bakes only the VFB's
# correction LAYERS (exposure/curve/LUT, all at default here), not the
# display transform. So the fix is applied here, deterministically, to the
# saved file itself: decode the PNG, run every colour byte through the sRGB
# encode curve
#
#     v <= 0.0031308 ? v * 12.92 : 1.055 * v**(1/2.4) - 0.055
#
# re-encode, and DECLARE the colour space (sRGB + gAMA chunks) so no viewer
# ever has to guess again. Alpha bytes are never touched.
#
# SAFETY DOCTRINE (proposal-package.rb's own): nothing fails silently and a
# file is never corrupted. encode_file writes to a TEMP path, re-decodes the
# temp and compares it pixel-for-pixel against the intended output, and only
# then replaces the original. Any refusal or failure returns :ok => false
# with a named :why; the original file is left exactly as it was (the one
# narrow exception — a rename that fails after the delete — names the temp
# path that still holds the corrected file). A PNG that already DECLARES a
# colour space (gAMA/sRGB/iCCP present) is refused by name: encoding it
# again would double-correct.
#
# OFFLINE-TESTABLE BY CONSTRUCTION. rbtest-srgb.py runs this file end to end
# in the CRuby 3.2 VM rbparse.py boots from SketchUp's own DLL. That VM has
# no zlib, no Array#pack, no Float#to_f and no Object#class, so:
#   - zlib sits behind three seams (inflate / deflate / crc32) the test
#     replaces with pure-Ruby stand-ins (stored-block streams, table CRC);
#   - byte-array <-> string conversion goes through bytes_to_str, which
#     uses Array#pack when it exists and chr-join when it does not;
#   - no `.to_f`, no `.class` anywhere in this file.
# Everything else — the LUT, the five PNG filters, the chunk parser and
# builder, encode_file itself — is the very code SketchUp runs.
#
# COST: pure-Ruby per-byte loops. A 2400x1350 RGB frame is ~10M byte visits
# per pass; expect a few seconds per render row inside SketchUp. That is
# noise next to a multi-minute render, and it buys determinism.

module WR_PNGSRGB
  PNG_SIG = [137, 80, 78, 71, 13, 10, 26, 10].freeze

  # Chunks that declare a colour space. If any is present the file is NOT
  # bare linear data by its own account, and encoding it would be a guess.
  COLOR_CHUNKS = %w[gAMA sRGB iCCP].freeze

  # ------------------------------------------------------------ zlib seams --
  # The ONLY places this file touches zlib. rbtest-srgb.py substitutes all
  # three; at runtime they are stdlib zlib, which SketchUp's full VM ships.

  def self.inflate(str)
    require 'zlib' unless defined?(Zlib)
    Zlib::Inflate.inflate(str)
  end

  def self.deflate(str)
    require 'zlib' unless defined?(Zlib)
    Zlib::Deflate.deflate(str)
  end

  def self.crc32(str)
    require 'zlib' unless defined?(Zlib)
    Zlib.crc32(str)
  end

  # ------------------------------------------------------------- pure core --

  # 256-entry linear-byte -> sRGB-byte lookup. Round half-away-from-zero
  # (Ruby's Float#round), pinned by rbtest-srgb.py against independently
  # computed values.
  def self.srgb_lut
    @srgb_lut ||= (0..255).map do |i|
      v = i / 255.0
      s = v <= 0.0031308 ? v * 12.92 : 1.055 * (v**(1.0 / 2.4)) - 0.055
      s = 0.0 if s < 0.0
      s = 1.0 if s > 1.0
      (s * 255.0).round
    end.freeze
  end

  # PNG Paeth predictor, verbatim from the spec.
  def self.paeth(a, b, c)
    p  = a + b - c
    pa = (p - a).abs
    pb = (p - b).abs
    pc = (p - c).abs
    return a if pa <= pb && pa <= pc
    return b if pb <= pc
    c
  end

  # raw: Array<Integer> — the inflated IDAT stream. Returns Array of rows
  # (each Array<Integer>, stride = width * bpp bytes). Raises with a named
  # reason on any malformation; the caller turns that into a refusal.
  def self.unfilter(raw, width, height, bpp)
    stride = width * bpp
    expect = height * (1 + stride)
    if raw.size != expect
      raise "IDAT decodes to #{raw.size} bytes, expected #{expect} " \
            "(#{width}x#{height}, #{bpp} bytes/px)"
    end
    rows = []
    prev = Array.new(stride, 0)
    pos  = 0
    height.times do |y|
      ft = raw[pos]
      raise "row #{y} has invalid filter type #{ft.inspect}" if ft.nil? || ft > 4
      cur = Array.new(stride)
      i = 0
      while i < stride
        x = raw[pos + 1 + i]
        a = i >= bpp ? cur[i - bpp] : 0
        b = prev[i]
        cur[i] = case ft
                 when 0 then x
                 when 1 then (x + a) & 255
                 when 2 then (x + b) & 255
                 when 3 then (x + ((a + b) >> 1)) & 255
                 else        (x + paeth(a, b, i >= bpp ? prev[i - bpp] : 0)) & 255
                 end
        i += 1
      end
      rows << cur
      prev = cur
      pos += 1 + stride
    end
    rows
  end

  # LUT every COLOUR byte; alpha (byte 4 of 4) passes through untouched.
  def self.encode_rows(rows, bpp)
    l = srgb_lut
    rows.map do |r|
      out = Array.new(r.size)
      i = 0
      while i < r.size
        out[i] = (bpp == 4 && (i & 3) == 3) ? r[i] : l[r[i]]
        i += 1
      end
      out
    end
  end

  # [mean, max] over the COLOUR bytes only, both as 0..1 fractions. This is
  # the plain RGB-byte mean — an auditing number for the log (before ~0.16,
  # after ~0.40 on the measured file), not a photometric luminance.
  def self.mean_max(rows, bpp)
    sum = 0
    max = 0
    n   = 0
    rows.each do |r|
      i = 0
      while i < r.size
        unless bpp == 4 && (i & 3) == 3
          v = r[i]
          sum += v
          max = v if v > max
          n += 1
        end
        i += 1
      end
    end
    return [0.0, 0.0] if n == 0
    [sum / (255.0 * n), max / 255.0]
  end

  # Rows back into a filtered raw stream. Filter type 0 (None) on every row:
  # always valid, fully deterministic, slightly larger on disk than adaptive
  # filtering — an accepted trade for simplicity that cannot be wrong.
  def self.filter_rows(rows)
    out = []
    rows.each do |r|
      out << 0
      out.concat(r)
    end
    out
  end

  # ------------------------------------------------- bytes <-> strings --

  def self.bytes_to_str(arr)
    if arr.respond_to?(:pack)
      begin
        return arr.pack('C*')
      rescue StandardError
        nil # fall through to the portable path
      end
    end
    arr.map(&:chr).join
  end

  def self.be32(n)
    [(n >> 24) & 255, (n >> 16) & 255, (n >> 8) & 255, n & 255]
  end

  def self.read_be32(bytes, pos)
    (bytes[pos] << 24) | (bytes[pos + 1] << 16) | (bytes[pos + 2] << 8) |
      bytes[pos + 3]
  end

  # ---------------------------------------------------------- PNG chunks --

  # bytes: Array<Integer> of the whole file. Returns Array of
  # { :type => 'IHDR', :data => Array<Integer> } in file order, CRC-checked.
  # Raises with a named reason on any malformation.
  def self.parse_chunks(bytes)
    raise 'not a PNG (bad signature)' if bytes[0, 8] != PNG_SIG
    chunks = []
    pos = 8
    loop do
      raise 'truncated PNG (no IEND chunk)' if pos + 8 > bytes.size
      len  = read_be32(bytes, pos)
      type = bytes_to_str(bytes[pos + 4, 4])
      raise "truncated #{type} chunk" if pos + 12 + len > bytes.size
      data = bytes[pos + 8, len]
      crc  = read_be32(bytes, pos + 8 + len)
      have = crc32(bytes_to_str(bytes[pos + 4, 4 + len]))
      raise "CRC mismatch in #{type} chunk" unless crc == have
      chunks << { :type => type, :data => data }
      pos += 12 + len
      break if type == 'IEND'
    end
    chunks
  end

  def self.build_chunk(type, data)
    body = type.bytes + data
    be32(data.size) + body + be32(crc32(bytes_to_str(body)))
  end

  # IHDR data -> hash, or raise.
  def self.parse_ihdr(data)
    raise 'IHDR is not 13 bytes' unless data && data.size == 13
    { :width       => read_be32(data, 0),
      :height      => read_be32(data, 4),
      :bit_depth   => data[8],
      :color_type  => data[9],
      :compression => data[10],
      :filter      => data[11],
      :interlace   => data[12] }
  end

  # nil when the file is one this module knows how to encode, else the
  # refusal string. PURE — pinned offline. allow_declared is the VERIFY
  # path's flag: the temp file this module just wrote DOES declare sRGB+gAMA
  # (that is half the fix), so re-decoding it to check the pixels must not
  # trip the double-correct refusal that protects INPUT files.
  def self.refusal(ihdr, chunk_types, allow_declared = false)
    return "bit depth #{ihdr[:bit_depth]} (only 8-bit supported)" unless ihdr[:bit_depth] == 8
    unless ihdr[:color_type] == 2 || ihdr[:color_type] == 6
      return "colour type #{ihdr[:color_type]} (only RGB(2)/RGBA(6) supported)"
    end
    return 'interlaced PNG (not supported)' unless ihdr[:interlace] == 0
    return "compression method #{ihdr[:compression]}" unless ihdr[:compression] == 0
    return "filter method #{ihdr[:filter]}" unless ihdr[:filter] == 0
    declared = chunk_types & COLOR_CHUNKS
    if !allow_declared && !declared.empty?
      return "file already declares a colour space (#{declared.join(', ')} " \
             'chunk present) - encoding again would double-correct'
    end
    return 'no IDAT chunk' unless chunk_types.include?('IDAT')
    nil
  end

  # The output file, as one byte array: original chunk order preserved,
  # sRGB (rendering intent 0: perceptual) + gAMA 45455 inserted right after
  # IHDR, the original IDAT run replaced in place by ONE IDAT holding
  # comp_bytes. refusal() has already guaranteed no gAMA/sRGB/iCCP exists.
  def self.build_png(chunks, comp_bytes)
    out = PNG_SIG.dup
    idat_done = false
    chunks.each do |c|
      case c[:type]
      when 'IHDR'
        out.concat(build_chunk('IHDR', c[:data]))
        out.concat(build_chunk('sRGB', [0]))
        out.concat(build_chunk('gAMA', be32(45_455)))
      when 'IDAT'
        unless idat_done
          out.concat(build_chunk('IDAT', comp_bytes))
          idat_done = true
        end
      else
        out.concat(build_chunk(c[:type], c[:data]))
      end
    end
    out
  end

  # ------------------------------------------------------------ the verbs --

  # Decode a PNG byte array all the way to unfiltered rows.
  # Returns [ihdr, chunks, rows]; raises with a named reason.
  def self.decode(bytes, allow_declared = false)
    chunks = parse_chunks(bytes)
    ihdr_c = chunks.find { |c| c[:type] == 'IHDR' }
    raise 'no IHDR chunk' if ihdr_c.nil?
    ihdr = parse_ihdr(ihdr_c[:data])
    why  = refusal(ihdr, chunks.map { |c| c[:type] }, allow_declared)
    raise why if why
    idat = []
    chunks.each { |c| idat.concat(c[:data]) if c[:type] == 'IDAT' }
    raw  = inflate(bytes_to_str(idat)).bytes
    bpp  = ihdr[:color_type] == 6 ? 4 : 3
    rows = unfilter(raw, ihdr[:width], ihdr[:height], bpp)
    [ihdr, chunks, rows]
  end

  # THE ENTRY POINT. Encode the PNG at `path` from linear to sRGB, in place,
  # via `tmp`. Never raises; returns a hash:
  #   :ok => true,  :before => f, :after => f,        (mean colour, 0..1)
  #                 :max_before => f, :max_after => f
  #   :ok => false, :why => 'named reason'            (file left untouched,
  #                 except the one rename-after-delete case, which :why
  #                 names in full)
  def self.encode_file(path, tmp = nil)
    tmp ||= "#{path}.srgb-tmp"
    bytes = begin
      File.binread(path).bytes
    rescue Exception => e
      return { :ok => false, :why => "could not read #{path}: #{e.message}" }
    end

    ihdr = chunks = rows = nil
    begin
      ihdr, chunks, rows = decode(bytes)
    rescue Exception => e
      return { :ok => false, :why => e.message }
    end
    bpp = ihdr[:color_type] == 6 ? 4 : 3

    before_mean, before_max = mean_max(rows, bpp)
    out_rows = encode_rows(rows, bpp)
    after_mean, after_max = mean_max(out_rows, bpp)

    out_bytes = begin
      comp = deflate(bytes_to_str(filter_rows(out_rows))).bytes
      build_png(chunks, comp)
    rescue Exception => e
      return { :ok => false, :why => "re-encode failed: #{e.message}" }
    end

    begin
      File.binwrite(tmp, bytes_to_str(out_bytes))
    rescue Exception => e
      return { :ok => false, :why => "could not write temp #{tmp}: #{e.message}" }
    end

    # VERIFY: the temp must decode, decode to EXACTLY the rows we meant to
    # write, and carry the colour-space declaration. Only then may it
    # replace the original. (allow_declared: the sRGB+gAMA chunks this
    # module just stamped are the point, not a refusal.)
    begin
      _ihdr2, chunks2, rows2 = decode(File.binread(tmp).bytes, true)
      declared2 = chunks2.map { |c| c[:type] } & COLOR_CHUNKS
      unless declared2.include?('sRGB') && declared2.include?('gAMA')
        File.delete(tmp) rescue nil
        return { :ok => false,
                 :why => 'verify failed - the temp file does not carry the ' \
                         'sRGB/gAMA declaration; original left untouched' }
      end
      unless rows2 == out_rows
        File.delete(tmp) rescue nil
        return { :ok => false,
                 :why => 'verify failed - the temp file did not decode back ' \
                         'to the intended pixels; original left untouched' }
      end
    rescue Exception => e
      File.delete(tmp) rescue nil
      return { :ok => false,
               :why => "verify failed - temp did not re-decode " \
                       "(#{e.message}); original left untouched" }
    end

    begin
      File.delete(path)
    rescue Exception => e
      File.delete(tmp) rescue nil
      return { :ok => false,
               :why => "could not replace #{path} (#{e.message}); " \
                       'original left untouched' }
    end
    begin
      File.rename(tmp, path)
    rescue Exception => e
      # The one non-restoring failure: the original is gone but the verified
      # corrected file exists at tmp. Name both, hide nothing.
      return { :ok => false,
               :why => "the original was removed but the corrected file " \
                       "could not be renamed into place (#{e.message}) - " \
                       "the corrected file is at #{tmp}" }
    end

    { :ok => true,
      :before => before_mean, :after => after_mean,
      :max_before => before_max, :max_after => after_max }
  end

  # Read-only report for a PNG on disk — used by probe-vray-color.rb to
  # measure saved variants. Never raises.
  #   { :ok => true, :mean => f, :max => f, :w =>, :h =>, :declared => [...] }
  #   { :ok => false, :why => '...' }
  def self.measure_file(path)
    bytes = File.binread(path).bytes
    chunks = parse_chunks(bytes)
    ihdr_c = chunks.find { |c| c[:type] == 'IHDR' }
    raise 'no IHDR chunk' if ihdr_c.nil?
    ihdr = parse_ihdr(ihdr_c[:data])
    unless ihdr[:bit_depth] == 8 && (ihdr[:color_type] == 2 || ihdr[:color_type] == 6) &&
           ihdr[:interlace] == 0
      raise "unmeasurable shape (depth #{ihdr[:bit_depth]}, colour type " \
            "#{ihdr[:color_type]}, interlace #{ihdr[:interlace]})"
    end
    idat = []
    chunks.each { |c| idat.concat(c[:data]) if c[:type] == 'IDAT' }
    raise 'no IDAT chunk' if idat.empty?
    bpp  = ihdr[:color_type] == 6 ? 4 : 3
    rows = unfilter(inflate(bytes_to_str(idat)).bytes, ihdr[:width], ihdr[:height], bpp)
    mean, mx = mean_max(rows, bpp)
    { :ok => true, :mean => mean, :max => mx,
      :w => ihdr[:width], :h => ihdr[:height],
      :declared => chunks.map { |c| c[:type] } & COLOR_CHUNKS }
  rescue Exception => e
    { :ok => false, :why => e.message }
  end
end
