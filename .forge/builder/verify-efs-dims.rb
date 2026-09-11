# verify-efs-dims.rb — the LIVE half of the EFS dimension fix (11 Sep 2026).
#
# WHY IT EXISTS. Benton, 11 Sep 2026, on a booth with a caster plate and
# exterior fan silencers: "the dimension tool is not currently accounting for
# the EFS. The dimensions should extend 10" total from the booth corner on
# booths with EFS." The 1.42.0 rule measured every wall part to the outboard
# face carrying the MOST area — the vent duct faces — and set the silencer
# box aside as a fitting, so the string stopped at the vent box (5 1/2 in)
# on an EFS wall. dimension-whisperroom.rb now measures a part named _EFS to
# its assembly's outboard edge (WR_BoothDims.measure_to, rule :assembly).
#
# The RULE is proven offline (scripts/rbtest-boothdims.py, 147 checks, two
# mutants killed). What CANNOT be known outside SketchUp is how far the real
# EFS part reaches past the corner seals as the builder places it. The probe
# on the share says the part is 12.125 in thick against 8.5468 for a plain
# vent — 10 1/8 past the seals IF all of that is outboard — while the 1.42.0
# record implied 6 7/16 on a 7296 E. This script reads the placed part and
# says which. Nothing in it draws a number of its own.
#
#   1. Open a model holding a booth built from a link WITH EFS (any model;
#      this script draws only that booth's dimension set, which Ctrl+Z
#      reverses — it does not build or erase anything).
#   2. Select the booth (or leave nothing selected and it takes the first
#      booth with an EFS part it finds).
#   3. Extensions > Developer > Ruby Console, then
#      load "<CLAUDE>/Sketchup/.forge/builder/verify-efs-dims.rb"
#      (on the desktop: .../Sketchup/WhisperRoom-SketchUp/.forge/builder/...)
#
# It prints one PASS/FAIL line per check and a JSON summary line. Paste the
# whole output back, along with the tool's own "EFS:" console lines.
#
# WHAT IT CHECKS
#   - the booth carries at least one _EFS wall part (else it stops: nothing
#     to verify on this booth);
#   - for every EFS wall part: the seal line on that wall, the vent box face
#     level, the assembly edge, and the reach past the seals — REPORTED, with
#     a PASS only if the reach is within 1/4 in of Benton's 10, otherwise a
#     FAIL that names the real figure (that is the answer he needs, not a
#     defect in the tool);
#   - the dimension string on each EFS wall's axis reads the extent to the
#     assembly edge (the tool's own extent, measured back off the drawn
#     Dimension entities);
#   - a vented wall WITHOUT an EFS part still reads to its vent box (the
#     1.42.0 rule is kept there) and a wall with no vent reads to the seals —
#     an EFS on one wall never grows the other axis;
#   - the height is untouched by any of this (the CP datum from 1.49.0).

require 'json'

module WR_VerifyEfsDims
  HERE    = File.dirname(File.expand_path(__FILE__)).freeze
  SCRIPTS = File.expand_path('../../scripts', HERE).freeze
  TOOL    = File.join(SCRIPTS, 'dimension-whisperroom.rb').freeze
  TOL     = 0.001
  # Benton's figure and the cross-check's; a reach off it by more than the
  # tool's own CAT_TOL is reported by name, not hidden.
  WANT    = 10.0
  CAT_TOL = 0.25

  @results = []

  def self.check(name, ok, detail = nil)
    @results << [name, ok ? true : false, detail]
    puts format('  %-4s %s%s', ok ? 'PASS' : 'FAIL', name, detail ? " — #{detail}" : '')
    ok
  end

  def self.arch(x)
    Sketchup.format_length(x.to_f).to_s
  rescue StandardError
    format('%.4f', x)
  end

  def self.load_tool
    $wr_no_autorun = true
    load TOOL
  ensure
    $wr_no_autorun = false
  end

  def self.find_booth(model)
    sel = model.selection.to_a.find { |e| WR_BoothDims.booth?(e) }
    return sel if sel
    model.entities.to_a.find do |e|
      WR_BoothDims.booth?(e) &&
        WR_BoothDims.named_children(e).any? { |n, _x| WR_BoothDims.efs_part?(n) && WR_BoothDims.classify(n) == :wall }
    end
  end

  def self.run
    model = Sketchup.active_model
    load_tool
    inst = find_booth(model)
    if inst.nil?
      puts '  STOP: no WhisperRoom with an _EFS wall part in this model (select one, or build one from a link with EFS)'
      return
    end
    puts "verify-efs-dims — booth \"#{inst.name}\""
    kids  = WR_BoothDims.named_children(inst)
    names = kids.map { |n, _e| n }
    parts = kids.map { |n, e| [n, WR_BoothDims.local_box(e), e] }.reject { |_n, b, _e| b.nil? }
    efs_faces = WR_BoothDims.efs_faces_from_names(names)
    faces, _efs = WR_BoothDims.vents_from_names(names)
    check('booth carries at least one EFS wall part', !efs_faces.empty?, "EFS on #{efs_faces.join(' ')}; vents on #{faces.join(' ')}")
    return if efs_faces.empty?

    # The shell, from the corner seals alone.
    seals = parts.select { |n, _b, _e| WR_BoothDims.classify(n) == :corner }.map { |n, b, _e| [n, b] }
    shell = WR_BoothDims.extent_from_parts(seals)
    check('corner seals present (the shell the reach is measured from)', !shell.nil?,
          shell ? format('X %.4f..%.4f  Y %.4f..%.4f', shell[:x0], shell[:x1], shell[:y0], shell[:y1]) : 'no seals — reach cannot be told from the shell')

    # Every vent part, read the way the tool reads it.
    reach = {}
    parts.each do |n, b, e|
      next unless WR_BoothDims.classify(n) == :wall && n =~ WR_BoothDims::VENT_RE
      nb, info = WR_BoothDims.vent_box_bound(n, e, b)
      if info.nil?
        check("#{n}: faces readable", false, 'no wall-parallel faces read — measured by assembly box')
        next
      end
      k = info[:bound]
      sign = WR_BoothDims.outward?(k) ? 1.0 : -1.0
      f = info[:face]
      line = shell ? shell[k] : nil
      past = line ? (info[:level] - line) * sign : nil
      box_past = line ? (f[:box] - line) * sign : nil
      puts format('  %s: rule %s; panel %.4f, vent box %.4f (%.0f sq in), assembly edge %.4f -> measured to %.4f',
                  n, info[:rule], f[:panel], f[:box], f[:box_area], info[:box_edge], info[:level])
      f[:beyond].each { |l, a| puts format('      face beyond the vent box at %.4f (%.0f sq in)', l, a) }
      if WR_BoothDims.efs_part?(n)
        check("#{n}: measured to the assembly (rule :assembly)", info[:rule] == :assembly, info[:rule].to_s)
        check("#{n}: the string reaches PAST the vent box", (info[:level] - f[:box]) * sign > WR_BoothDims::PANEL_CLEAR,
              format('%s beyond the vent box face', arch((info[:level] - f[:box]) * sign)))
        if past
          reach[info[:letter]] = past
          check(format('%s: reach past the seals is Benton\'s 10 in (±%s)', n, arch(CAT_TOL)), (past - WANT).abs <= CAT_TOL,
                format('REACH %s past the seals (vent box %s past) — if this FAILs, the part reaches what it reaches; tell Benton this number', arch(past), arch(box_past)))
        end
      else
        check("#{n}: no EFS, still measured to the vent box (1.42.0 kept)", info[:rule] == :vent_box,
              format('rule %s, %s past the seals', info[:rule], box_past ? arch(box_past) : '?'))
      end
    end

    # Draw, then read the strings back off the Dimension entities.
    dims = WR_BoothDims.dimension(inst)
    check('three dimensions drawn', dims.length == 3, "#{dims.length} drawn")
    lens = dims.map do |d|
      a = WR_BoothDims.landed(d.start)
      b = WR_BoothDims.landed(d.end)
      (a && b) ? a.distance(b).to_f : nil
    end.compact
    pboxes = parts.map do |n, bx, e|
      if WR_BoothDims.classify(n) == :wall
        nb, _i = WR_BoothDims.vent_box_bound(n, e, bx)
        [n, nb]
      else
        [n, bx]
      end
    end
    ext = WR_BoothDims.extent_from_parts(pboxes)
    if ext && shell
      { 'X' => [:x0, :x1, %w[W E]], 'Y' => [:y0, :y1, %w[S N]] }.each do |ax, (k0, k1, walls)|
        want = ext[k1] - ext[k0]
        hit = lens.find { |l| (l - want).abs <= TOL }
        efs_here = walls.any? { |w| efs_faces.include?(w) }
        vent_here = walls.any? { |w| faces.include?(w) }
        what = efs_here ? 'EFS wall — assembly edge' : vent_here ? 'vented, no EFS — vent box' : 'no vent — the seals'
        check("across #{ax}: a drawn string reads the tool's extent (#{what})", !hit.nil?,
              format('extent %s (%s), set by %s / %s; strings read %s', arch(want), what, ext[(k0.to_s + '_by').to_sym], ext[(k1.to_s + '_by').to_sym],
                     lens.map { |l| arch(l) }.join(', ')))
        grow = [ext[k1] - shell[k1], shell[k0] - ext[k0]].max
        if !efs_here
          check("across #{ax}: no EFS on this axis — it grew no more than a vent box (#{arch(WR_BoothDims::VENT_PROUD + 1.0)})", grow <= WR_BoothDims::VENT_PROUD + 1.0,
                format('%s past the seals', arch(grow)))
        end
      end
      h = ext[:z1] - ext[:z0]
      hs = lens.find { |l| (l - h).abs <= TOL }
      check('height string untouched by the EFS rule (reads the floor-stack/plate to ceiling figure)', !hs.nil?,
            format('height %s%s', arch(h), ext[:plate] ? format(', %s of it plate', arch(ext[:plate])) : ''))
    else
      check('extent from parts', false, 'no extent or no shell — see the tool console')
    end
  rescue StandardError => e
    puts "  FAIL run aborted — #{e.class}: #{e.message}"
    puts e.backtrace.first(6).map { |l| "    #{l}" }.join("\n") if e.backtrace
  ensure
    fails = @results.count { |r| !r[1] }
    puts JSON.generate('script' => 'verify-efs-dims', 'checks' => @results.length, 'failed' => fails,
                       'reach_past_seals' => (reach || {}))
    puts '  Ctrl+Z removes the dimension set this run drew.'
  end
end

WR_VerifyEfsDims.run
