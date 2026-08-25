# @title Probe Enhanced Components...
# @shelf dev
#
#   load "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/probe-enhanced.rb"
#
# THIS SCRIPT HAS NOT BEEN RUN. There is no Ruby outside SketchUp on this
# machine, so it has been syntax-checked with scripts/rbparse.py (the CRuby 3.2
# library SketchUp ships) and nothing more. Every number it is meant to produce
# is still unknown. Do not quote a gap, a thickness or a height from this
# file's comments as if it were measured -- the file measures, it does not know.
#
# DRY-RUN SAFE. It loads component DEFINITIONS, reads their geometry, and
# purges them again. It places no instances, draws nothing, moves nothing,
# deletes nothing, and never calls save. The only side effect outside the model
# is the two TSV files it writes into the component folder.
#
# Still: RUN IT ON AN EMPTY SCRATCH MODEL. purge_unused cannot remove a
# definition that something already in your model uses.
#
# ---------------------------------------------------------------------------
# WHY THIS EXISTS, AND WHAT IT HAS TO SETTLE
#
# probe-components.rb measured the Standard library and answered "how big" and
# "where is the origin". It cannot answer the Enhanced question, because the
# Enhanced question is about what is INSIDE a part.
#
# An Enhanced booth is described in the DEVLOG as a booth inside a booth with a
# gap. The intent recorded there was to author COMBINED components -- exterior
# shell + interior shell + foam grouped into one part, with the relationship
# baked in -- so the assembler places one part per wall slot instead of solving
# a two-shell layout itself.
#
# Whether the shipped ENH files actually are combined is UNKNOWN, and it is the
# single assumption that invalidates the most downstream work:
#
#   * If ENH parts are COMBINED, the Enhanced build is mostly a naming and
#     stock-width problem. It is also an immediate BUG in
#     build-booth-components.rb#wall_slab, which is written on the premise that
#     a part contains exactly one tall slab. See WALL_SLAB WARNING below.
#
#   * If ENH parts are SINGLE narrow shells, then combining is still to be
#     done, the gap lives in the layout rather than in the part, and the build
#     plan is a very different piece of work.
#
# So this probe reports, per part and from geometry alone:
#
#   1. The NESTING TREE -- every nested group and component instance, its name,
#      its depth, and its extents in the top definition's coordinates. A
#      combined part authored as exterior / interior / foam groups will say so
#      here in plain sight.
#
#   2. The SLAB PROFILE along the thickness axis -- how many wall-like sheets
#      the part contains, where each starts and stops, and THE GAP between
#      them. That gap is the number the Enhanced build has been waiting on. It
#      is measured from face geometry, not from group names, so it is right
#      even if the part is one flat soup of faces with no grouping at all.
#
#   3. Extents, origin and anchor corner -- the same fields
#      probe-components.rb emits, because the Standard probe found 73 of 182
#      parts anchored at their box minimum and 34 at no recognisable anchor at
#      all. Placement has to go by bounding geometry, and that stays true for
#      Enhanced until measured otherwise.
#
#   4. The STANDARD COUNTERPART's thickness beside each Enhanced part, loaded
#      and measured in the same pass, so the Enhanced-minus-Standard delta is a
#      measurement rather than a subtraction of two numbers from two sources.
#
# ---------------------------------------------------------------------------
# TWO DEFECTS IN probe-components.rb THAT ARE FIXED HERE
#
# Do not port these back into the old probe without re-reading its output; the
# _component-probe.tsv already on the share was written under the old
# behaviour and anything downstream has been reading it as-is.
#
#   a. The old probe labels its Z column "height". For a wall panel Z is the
#      WIDTH. 16PanelSolid measures x=1.0000 y=81.0000 z=16.0000: the height is
#      81 and it is on Y. Anything reading `height` out of that TSV for a wall
#      part has been reading the panel's width.
#
#   b. The old probe computes length and thickness from X and Y only, ignoring
#      Z. On a vent that is wrong: 40VNT measures x=40 y=82 z=8.5468 and the
#      old probe calls its thickness 40.0000, when 40 is the panel's width and
#      the thickness axis is Z.
#
#   Here the three axes are assigned by extent -- thickness = smallest,
#   height = largest, width = the remaining one -- and the assignment is
#   PRINTED for every part so a wrong pick is visible rather than silent. That
#   rule reproduces the correct answer for every Standard part checked by hand
#   against the old TSV (panels 1/81/16, vents 8.5468/82/40, doors 31.99/81/46).
#   It is an INFERENCE for Enhanced parts and is reported as one.
#
# ---------------------------------------------------------------------------
# HEIGHT: THE NUMBER TO WATCH
#
# Standard wall panels measure 81.0000 tall and HX panels 91.0000. That is
# observed, in _component-probe.tsv on the share: 33 parts at 81.0000 and 32 at
# 91.0000 on the Y axis.
#
# Enhanced panel height has been quoted elsewhere as 84.3125 against a Standard
# 83.0000. NEITHER of those figures appears anywhere in the 182-part Standard
# measurement. They may be measuring something the panel alone is not -- a
# panel plus a rail, or an assembly height. This probe assumes none of them. It
# reports the measured tall-axis extent per part and tallies the distinct
# values, and that tally is what settles it.
#
# ---------------------------------------------------------------------------
# WALL_SLAB WARNING -- read this before touching build-booth-components.rb
#
# build-booth-components.rb#wall_slab (around line 433) finds the wall panel
# inside a thick part by taking every face that spans the height, keeping the
# widest cluster, and then spanning t0..t1 across ALL of them. It then bails:
#
#     return nil if (t1 - t0) > 3.0        # caught something that is not a panel
#
# On a combined two-shell part BOTH shells span the height and BOTH are the
# full width, so both land in that cluster and t1 - t0 becomes the whole part
# thickness. Depending on how thick the combined part turns out to be, the
# finder either returns nil -- dropping the part back to bounding-box
# placement, the same failure that once shoved the 102126's vent panels
# sideways -- or returns a span covering both shells, after which the facing
# logic downstream is reasoning about the wrong slab.
#
# The DEVLOG files this as a future "prefer-outermost-slab tweak". If this
# probe reports two shells, it is a live bug today, not a future one.
#
# This probe's slab profile is deliberately the shape of the fix: the same
# question answered per-bin instead of per-cluster.

require 'sketchup.rb'

# The folder field is a dropdown of folders used before, plus a Browse entry.
load File.join(File.dirname(__FILE__), 'wr-folder.rb')

module WR_ProbeEnh
  DEFAULT_DIR = 'P:/Sketchup/NewMasterComponentList'.freeze

  IDENTITY = Geom::Transformation.new

  # Bin width for the slab profile. A sixteenth of an inch: fine enough to
  # separate two shells that nearly touch, coarse enough that 116 parts do not
  # take all afternoon.
  BIN = 0.0625

  # A bin counts as SHELL only if the geometry in it spans most of the part in
  # both of the other two axes. A hinge, a duct or a foam block does not.
  SHELL_FRAC = 0.80

  # A bin counts as FILL -- foam, framing, hardware -- at a much lower bar.
  # Reported separately so foam is visible without being mistaken for a shell.
  FILL_FRAC = 0.15

  TOL = 0.01

  # ------------------------------------------------------------------ input --

  def self.ask
    dir, list = WR_Folder.field('parts', DEFAULT_DIR)
    res = UI.inputbox(['Folder of .skp files',
                       'Also load each Standard counterpart',
                       'Purge the definitions afterwards'],
                      [dir, 'Yes', 'Yes'],
                      [list, 'Yes|No', 'Yes|No'],
                      'Probe Enhanced Components')
    return nil unless res

    # create = false. This folder is an INPUT; silently creating an empty one
    # would disguise a mistyped drive letter as an empty-folder problem.
    d = WR_Folder.resolve(res[0], 'parts', 'Folder of component .skp files', false)
    return nil if d.nil?
    { 'dir' => d, 'pair' => res[1].to_s, 'purge' => res[2].to_s }
  end

  # ------------------------------------------------------- name arithmetic --

  # The Enhanced set is named ENH + a space + the Standard name with its leading
  # width reduced by 4.5 inches:  46PanelSolid -> ENH 41.5PanelSolid.
  #
  # WHETHER THAT 4.5 IS THE DOUBLE-WALL GAP IS A HYPOTHESIS, NOT A CONCLUSION.
  # It is used here only to pair each Enhanced part with the Standard part it
  # most likely corresponds to, so the two can be measured side by side. If the
  # pairing is wrong the probe still reports both parts correctly; only the
  # delta column is meaningless, and it prints the name it paired so a wrong
  # pairing is visible.
  DELTA = 4.5

  def self.std_name(enh_base)
    n = enh_base.sub(/\AENH\s*/i, '')
    m = /\A([0-9]+(?:\.[0-9]+)?)/.match(n)
    if m
      w = m[1].to_f + DELTA
      return fmt_num(w) + n[m[1].length..-1].to_s
    end
    # Doors carry their width in the middle: Left41.5Door -> Left46Door.
    m2 = /\A(Left|Right)([0-9]+(?:\.[0-9]+)?)(.*)\z/i.match(n)
    return "#{m2[1]}#{fmt_num(m2[2].to_f + DELTA)}#{m2[3]}" if m2
    # CornerSeamSeal, MidWallSeamSeal, LeftWADoor: same name on both sides.
    n
  end

  def self.fmt_num(v)
    v == v.to_i ? v.to_i.to_s : format('%g', v)
  end

  # -------------------------------------------------------------- geometry --

  # Every face in a definition as an axis-aligned box in that definition's own
  # coordinates, following nested groups and components. A non-recursive walk
  # sees almost nothing on a door or a vent, and would see nothing at all on a
  # combined part whose shells are groups.
  def self.collect_faces(ents, tr, out, depth = 0)
    return if depth > 8
    ents.each do |e|
      if e.is_a?(Sketchup::Face)
        xs = []
        ys = []
        zs = []
        e.vertices.each do |v|
          p = v.position.transform(tr)
          xs << p.x.to_f
          ys << p.y.to_f
          zs << p.z.to_f
        end
        next if xs.empty?
        out << [[xs.min, xs.max], [ys.min, ys.max], [zs.min, zs.max]]
      elsif e.is_a?(Sketchup::ComponentInstance)
        collect_faces(e.definition.entities, tr * e.transformation, out, depth + 1)
      elsif e.is_a?(Sketchup::Group)
        collect_faces(e.entities, tr * e.transformation, out, depth + 1)
      end
    end
  end

  # The nesting tree. Each row is one nested container, with its extents
  # measured in the TOP definition's coordinates so the numbers are directly
  # comparable to the part's own bounds.
  def self.collect_tree(ents, tr, out, depth = 0, path = '')
    return if depth > 8
    ents.each do |e|
      kind = nil
      name = nil
      sub  = nil
      xf   = nil
      if e.is_a?(Sketchup::ComponentInstance)
        kind = 'component'
        name = (e.name.to_s.empty? ? e.definition.name.to_s : e.name.to_s)
        sub  = e.definition.entities
        xf   = e.transformation
      elsif e.is_a?(Sketchup::Group)
        kind = 'group'
        name = (e.name.to_s.empty? ? '(unnamed group)' : e.name.to_s)
        sub  = e.entities
        xf   = e.transformation
      end
      next if kind.nil?

      here = tr * xf
      boxes = []
      collect_faces(sub, here, boxes)
      here_path = path.empty? ? name : "#{path} / #{name}"
      out << { :depth => depth, :kind => kind, :name => name, :path => here_path,
               :faces => boxes.length, :ext => extents_of(boxes) }
      collect_tree(sub, here, out, depth + 1, here_path)
    end
  end

  def self.extents_of(boxes)
    return nil if boxes.empty?
    (0..2).map do |i|
      [boxes.map { |b| b[i][0] }.min, boxes.map { |b| b[i][1] }.max]
    end
  end

  # -------------------------------------------------------- axis assignment --

  # thickness = smallest extent, height = largest, width = the third.
  # See the header note on the two defects this fixes.
  def self.axes(ext)
    e = (0..2).map { |i| ext[i][1] - ext[i][0] }
    order = (0..2).to_a.sort_by { |i| e[i] }
    { :ti => order[0], :wi => order[1], :hi => order[2],
      :t => e[order[0]], :w => e[order[1]], :h => e[order[2]] }
  end

  # ------------------------------------------------------------ slab profile --

  # Walk the thickness axis in BIN steps. For each bin, take every face box that
  # overlaps it and ask how much of the part's width and height that geometry
  # spans. Classify the bin, then merge runs of like bins into bands.
  #
  # This is the whole answer to "one slab, or two shells plus foam", and it does
  # not care whether the part is grouped, flat, or a mixture of the two.
  def self.profile(boxes, ax, ext)
    ti = ax[:ti]
    wi = ax[:wi]
    hi = ax[:hi]
    t0 = ext[ti][0]
    t1 = ext[ti][1]
    span = t1 - t0
    return [] if span <= 0

    wfull = ext[wi][1] - ext[wi][0]
    hfull = ext[hi][1] - ext[hi][0]
    return [] if wfull <= 0 || hfull <= 0

    n = (span / BIN).ceil
    # A runaway part must not hang SketchUp. 4000 bins is 250 inches of
    # thickness, far beyond any real part.
    n = 4000 if n > 4000

    bins = []
    n.times do |k|
      a = t0 + k * BIN
      b = a + BIN
      hit = boxes.select { |bx| bx[ti][1] > a + 1e-9 && bx[ti][0] < b - 1e-9 }
      if hit.empty?
        bins << :void
        next
      end
      wspan = hit.map { |bx| bx[wi][1] }.max - hit.map { |bx| bx[wi][0] }.min
      hspan = hit.map { |bx| bx[hi][1] }.max - hit.map { |bx| bx[hi][0] }.min
      fw = wspan / wfull
      fh = hspan / hfull
      bins << if fw >= SHELL_FRAC && fh >= SHELL_FRAC
                :shell
              elsif fw >= FILL_FRAC || fh >= FILL_FRAC
                :fill
              else
                :trim
              end
    end

    bands = []
    bins.each_with_index do |b, k|
      a = t0 + k * BIN
      if bands.empty? || bands.last[:kind] != b
        bands << { :kind => b, :from => a, :to => a + BIN }
      else
        bands.last[:to] = a + BIN
      end
    end
    bands
  end

  # The gap: clear distance between consecutive shell bands. With fewer than two
  # shell bands there is no gap and the part is a single slab -- which is itself
  # the answer to the question this probe exists for.
  def self.shell_summary(bands)
    shells = bands.select { |b| b[:kind] == :shell }
    return { :n => 0, :gap => nil, :gaps => [], :shells => [] } if shells.empty?
    gaps = []
    (1...shells.length).each { |i| gaps << (shells[i][:from] - shells[i - 1][:to]) }
    { :n => shells.length, :gap => gaps.max, :gaps => gaps, :shells => shells }
  end

  # ---------------------------------------------------------------- one part --

  # Where the definition origin sits relative to the geometry. Reported the same
  # way probe-components.rb reports it so the two tables can be read together.
  def self.anchor_of(ext)
    (0..2).map do |i|
      lo = ext[i][0]
      hi = ext[i][1]
      w = hi - lo
      if near(0.0, lo) then 'min'
      elsif near(0.0, hi) then 'max'
      elsif near(0.0, lo + w / 2.0) then 'mid'
      else '?'
      end
    end.join('/')
  end

  def self.near(a, b)
    (a - b).abs < TOL
  end

  def self.measure(defn, file)
    boxes = []
    collect_faces(defn.entities, IDENTITY, boxes)
    ext = extents_of(boxes)
    if ext.nil?
      bb = defn.bounds
      return nil unless bb.valid?
      ext = [[bb.min.x.to_f, bb.max.x.to_f],
             [bb.min.y.to_f, bb.max.y.to_f],
             [bb.min.z.to_f, bb.max.z.to_f]]
    end
    ax = axes(ext)
    bands = profile(boxes, ax, ext)
    tree = []
    collect_tree(defn.entities, IDENTITY, tree)

    { :file => file, :name => defn.name.to_s, :ext => ext, :ax => ax,
      :bands => bands, :sh => shell_summary(bands), :tree => tree,
      :faces => boxes.length, :ents => defn.entities.length,
      :anchor => anchor_of(ext) }
  end

  # --------------------------------------------------------------------- run --

  def self.run
    model = Sketchup.active_model
    if model.nil?
      UI.messagebox('No model is open.')
      return
    end

    cfg = ask
    return if cfg.nil?

    files = Dir.glob(File.join(cfg['dir'], 'ENH*.skp')).sort
    if files.empty?
      UI.messagebox("No ENH*.skp files in\n#{cfg['dir']}\n\n" \
                    'This probe measures the Enhanced set only. For the ' \
                    'Standard set use probe-components.rb.')
      return
    end

    if model.entities.length > 0
      go = UI.messagebox("This model is not empty.\n\n#{files.length} Enhanced definitions " \
                         "(and their Standard counterparts, if selected) are about to be " \
                         "loaded into it. Nothing is drawn and nothing is moved, but a purge " \
                         "cannot remove a definition your model already uses.\n\n" \
                         'Carry on anyway?', MB_OKCANCEL)
      return if go != IDOK
    end

    puts ''
    puts "ENHANCED PROBE - #{files.length} ENH files in #{cfg['dir']}"
    puts '  nothing is drawn, moved or saved; definitions are loaded, measured and purged'
    puts ''

    rows = []
    failed = []

    files.each_with_index do |path, i|
      base = File.basename(path, '.skp')
      Sketchup.status_text = "Probing #{i + 1}/#{files.length}: #{base}"
      begin
        defn = model.definitions.load(path)
        if defn.nil?
          failed << [base, 'load returned nil']
          next
        end
        r = measure(defn, base)
        if r.nil?
          failed << [base, 'no valid bounds']
          next
        end
        pair_standard(model, cfg, r, base) if cfg['pair'] == 'Yes'
        rows << r
      rescue StandardError => e
        failed << [base, "#{e.class}: #{e.message}"]
      end
    end
    Sketchup.status_text = ''

    report(cfg, rows, failed)
  end

  def self.pair_standard(model, cfg, r, base)
    sname = std_name(base)
    r[:std_name] = sname
    spath = File.join(cfg['dir'], sname + '.skp')
    unless File.exist?(spath)
      # Case-insensitive fallback: the library mixes 46VntCP and 46vnt_VSS_CP.
      spath = Dir.glob(File.join(cfg['dir'], '*.skp')).find do |f|
        File.basename(f, '.skp').downcase == sname.downcase
      end
    end
    if spath.nil? || !File.exist?(spath)
      r[:std_found] = nil
      return
    end
    sd = model.definitions.load(spath)
    return if sd.nil?
    sr = measure(sd, File.basename(spath, '.skp'))
    return if sr.nil?
    r[:std] = sr
    r[:std_found] = File.basename(spath, '.skp')
  rescue StandardError => e
    r[:std_err] = "#{e.class}: #{e.message}"
  end

  # ------------------------------------------------------------------ output --

  def self.axis_letter(i)
    %w[X Y Z][i]
  end

  def self.report(cfg, rows, failed)
    wf = [rows.map { |r| r[:file].length }.max || 4, 4].max

    puts format("  %-#{wf}s %8s %8s %8s  %-5s %6s %8s  %-11s %6s %8s",
                'FILE', 'THICK', 'WIDTH', 'HEIGHT', 'AXES', 'SHELL', 'GAP',
                'ANCHOR', 'FACES', 'STD THK')
    puts '  ' + '-' * (wf + 84)
    rows.each do |r|
      ax = r[:ax]
      sh = r[:sh]
      gap = sh[:gap].nil? ? '       -' : format('%8.4f', sh[:gap])
      sthk = r[:std] ? format('%8.4f', r[:std][:ax][:t]) : '       -'
      puts format("  %-#{wf}s %8.4f %8.4f %8.4f  %s/%s/%s %6d %s  %-11s %6d %s",
                  r[:file], ax[:t], ax[:w], ax[:h],
                  axis_letter(ax[:ti]), axis_letter(ax[:wi]), axis_letter(ax[:hi]),
                  sh[:n], gap, r[:anchor], r[:faces], sthk)
    end

    combined_verdict(rows)
    counterpart_table(rows)

    puts ''
    puts '  ---- heights measured on the tall axis ----'
    tally(rows.map { |r| format('%.4f', r[:ax][:h]) })
    puts '    Standard measures 81.0000, and 91.0000 for HX, in _component-probe.tsv.'
    puts '    The figures 83.0000 and 84.3125 quoted elsewhere appear NOWHERE in that'
    puts '    182-part Standard measurement. Whatever this tally says is the panel'
    puts '    height; if it disagrees with 84.3125 then 84.3125 measures something'
    puts '    other than the panel, and the source that carries it needs correcting.'

    puts ''
    puts '  ---- origin anchor, definition space ----'
    tally(rows.map { |r| r[:anchor] })
    puts '    A single anchor across the set means one placement rule works for'
    puts '    everything. A mix means placement must go by bounding geometry, as it'
    puts '    does for Standard: 73 of 182 at min/min/min, 34 at no anchor at all.'

    name_check(rows)
    nesting_report(rows)

    unless failed.empty?
      puts ''
      puts "  ---- #{failed.length} failed to load ----"
      failed.each { |f, why| puts format('    %-40s %s', f, why) }
    end

    write_tsv(cfg, rows, failed)
    write_tree_tsv(cfg, rows)
    purge(cfg)

    puts ''
    puts "  #{rows.length} measured, #{failed.length} failed."
    puts ''
  end

  # The headline. Everything else in this probe is supporting evidence for it.
  def self.combined_verdict(rows)
    single = rows.select { |r| r[:sh][:n] <= 1 }
    multi  = rows.select { |r| r[:sh][:n] >= 2 }

    puts ''
    puts '  ================ COMBINED, OR SINGLE? ================'
    puts format('    %4d part(s) contain ONE wall-spanning shell   (single slab)', single.length)
    puts format('    %4d part(s) contain TWO OR MORE               (combined / double wall)', multi.length)
    puts ''

    if multi.empty?
      puts '    Every Enhanced part measures as a SINGLE shell. The components as'
      puts '    shipped are narrower single panels, NOT the combined exterior +'
      puts '    interior + foam parts the DEVLOG planned. The gap is therefore not'
      puts '    inside the part and has to come from the layout instead.'
      puts '    build-booth-components.rb#wall_slab is NOT broken by this set.'
      return
    end

    puts '    At least one Enhanced part is COMBINED: two or more wall-spanning'
    puts '    shells inside a single component.'
    puts ''
    puts '    >>> build-booth-components.rb#wall_slab IS BROKEN FOR THESE PARTS.'
    puts '        It spans t0..t1 across every full-height full-width face, so on a'
    puts '        two-shell part that span is the whole part thickness, and its'
    puts '        `return nil if (t1 - t0) > 3.0` guard then decides the outcome.'
    puts '        Compare the THICK column against 3.0 to see which way each part'
    puts '        falls: over 3.0 it returns nil and the part drops back to'
    puts '        bounding-box placement; under 3.0 it returns a span covering both'
    puts '        shells and the facing logic reasons about the wrong slab.'
    puts '        Do not build Enhanced until that finder is fixed.'
    puts ''
    puts '    ---- measured gap, inner shell face to outer shell face ----'
    tally(multi.map { |r| format('%.4f', r[:sh][:gap]) })
    puts '    THIS IS THE NUMBER THE ENHANCED BUILD HAS BEEN WAITING ON.'
    puts ''
    puts '    ---- overall Enhanced part thickness ----'
    tally(multi.map { |r| format('%.4f', r[:ax][:t]) })
    over = multi.count { |r| r[:ax][:t] > 3.0 }
    puts format('    %d of %d combined parts are thicker than the 3.0 guard.', over, multi.length)
  end

  def self.counterpart_table(rows)
    puts ''
    puts '  ---- Enhanced thickness vs its Standard counterpart ----'
    paired = rows.select { |r| r[:std] }
    if paired.empty?
      puts '    no Standard counterparts were loaded (pairing was off, or none matched)'
    else
      paired.each do |r|
        d = r[:ax][:t] - r[:std][:ax][:t]
        puts format('    %-30s %8.4f  vs %-24s %8.4f   (%+.4f)',
                    r[:file], r[:ax][:t], r[:std_found], r[:std][:ax][:t], d)
      end
      puts ''
      puts '    ---- delta tally ----'
      tally(paired.map { |r| format('%.4f', r[:ax][:t] - r[:std][:ax][:t]) })
    end

    unpaired = rows.select { |r| r[:std].nil? && r[:std_name] }
    return if unpaired.empty?
    puts ''
    puts "    #{unpaired.length} Enhanced part(s) had NO Standard counterpart under the"
    puts '    ENH = Standard minus 4.5 naming rule. Either the rule does not hold for'
    puts '    them, or the Standard part genuinely does not exist:'
    unpaired.each { |r| puts format('      %-32s looked for %s', r[:file], r[:std_name]) }
  end

  def self.name_check(rows)
    puts ''
    puts '  ---- width vs the number in the name ----'
    off = []
    rows.each do |r|
      m = /\AENH\s*([0-9]+(?:\.[0-9]+)?)/.match(r[:file])
      next if m.nil?
      want = m[1].to_f
      next if want < 5
      d = r[:ax][:w] - want
      next if d.abs <= 0.02
      off << format('%-32s name says %-8s measures %.4f  (%+.4f)',
                    r[:file], m[1], r[:ax][:w], d)
    end
    if off.empty?
      puts '    every numbered Enhanced part measures its name, within 0.02 in.'
      return
    end
    puts "    #{off.length} part(s) do not measure their name:"
    off.first(30).each { |l| puts "    #{l}" }
    puts "    ...and #{off.length - 30} more" if off.length > 30
  end

  def self.nesting_report(rows)
    puts ''
    puts '  ---- nesting ----'
    nested = rows.select { |r| !r[:tree].empty? }
    puts format('    %d of %d parts contain nested groups or components.',
                nested.length, rows.length)
    if nested.empty?
      puts '    Every part is flat geometry. If shells were found above, they are'
      puts '    modelled as loose faces, not as named exterior / interior groups.'
      return
    end
    puts '    Full tree is in the nesting TSV. First few:'
    nested.first(6).each do |r|
      puts "      #{r[:file]}"
      r[:tree].first(8).each do |t|
        e = t[:ext]
        dims = if e.nil?
                 'no geometry'
               else
                 format('%.4f x %.4f x %.4f',
                        e[0][1] - e[0][0], e[1][1] - e[1][0], e[2][1] - e[2][0])
               end
        puts format('        %s%-9s %-30s %s', '  ' * t[:depth], t[:kind], t[:name], dims)
      end
    end
  end

  def self.tally(vals)
    vals.group_by { |v| v }.map { |v, a| [v, a.length] }.sort_by { |_v, n| -n }.each do |v, n|
      puts format('      %-14s %d', v, n)
    end
  end

  def self.bands_str(bands)
    bands.map { |b| format('%s:%.4f-%.4f', b[:kind], b[:from], b[:to]) }.join(' ')
  end

  def self.purge(cfg)
    return unless cfg['purge'] == 'Yes'
    model = Sketchup.active_model
    n = model.definitions.length
    model.definitions.purge_unused
    puts ''
    puts "  purged - definitions #{n} -> #{model.definitions.length}"
  rescue StandardError => e
    puts "  purge failed: #{e.class}: #{e.message}"
  end

  def self.write_tsv(cfg, rows, failed)
    path = File.join(cfg['dir'], '_enhanced-probe.tsv')
    File.open(path, 'w') do |f|
      f.puts %w[file definition thickness width height
                thick_axis width_axis height_axis
                shells gap all_gaps
                std_counterpart std_found std_thickness delta_thickness
                origin_anchor min_x min_y min_z max_x max_y max_z
                faces top_entities nested_containers bands].join("\t")
      rows.each do |r|
        ax = r[:ax]
        e = r[:ext]
        sh = r[:sh]
        f.puts [r[:file], r[:name],
                format('%.4f', ax[:t]), format('%.4f', ax[:w]), format('%.4f', ax[:h]),
                axis_letter(ax[:ti]), axis_letter(ax[:wi]), axis_letter(ax[:hi]),
                sh[:n],
                sh[:gap].nil? ? '' : format('%.4f', sh[:gap]),
                sh[:gaps].map { |g| format('%.4f', g) }.join(','),
                r[:std_name].to_s, r[:std_found].to_s,
                r[:std] ? format('%.4f', r[:std][:ax][:t]) : '',
                r[:std] ? format('%.4f', ax[:t] - r[:std][:ax][:t]) : '',
                r[:anchor],
                format('%.4f', e[0][0]), format('%.4f', e[1][0]), format('%.4f', e[2][0]),
                format('%.4f', e[0][1]), format('%.4f', e[1][1]), format('%.4f', e[2][1]),
                r[:faces], r[:ents], r[:tree].length,
                bands_str(r[:bands])].join("\t")
      end
      failed.each { |fl, why| f.puts [fl, 'FAILED', why].join("\t") }
    end
    puts ''
    puts "  table  #{path}"
  rescue StandardError => e
    puts "  table NOT written: #{e.class}: #{e.message}"
  end

  def self.write_tree_tsv(cfg, rows)
    path = File.join(cfg['dir'], '_enhanced-nesting.tsv')
    File.open(path, 'w') do |f|
      f.puts %w[file depth kind name path faces
                min_x min_y min_z max_x max_y max_z dx dy dz].join("\t")
      rows.each do |r|
        r[:tree].each do |t|
          e = t[:ext]
          if e.nil?
            f.puts [r[:file], t[:depth], t[:kind], t[:name], t[:path], t[:faces],
                    '', '', '', '', '', '', '', '', ''].join("\t")
          else
            f.puts [r[:file], t[:depth], t[:kind], t[:name], t[:path], t[:faces],
                    format('%.4f', e[0][0]), format('%.4f', e[1][0]), format('%.4f', e[2][0]),
                    format('%.4f', e[0][1]), format('%.4f', e[1][1]), format('%.4f', e[2][1]),
                    format('%.4f', e[0][1] - e[0][0]),
                    format('%.4f', e[1][1] - e[1][0]),
                    format('%.4f', e[2][1] - e[2][0])].join("\t")
          end
        end
      end
    end
    puts "  tree   #{path}"
  rescue StandardError => e
    puts "  tree NOT written: #{e.class}: #{e.message}"
  end
end

begin
  WR_ProbeEnh.run
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(12).map { |l| "  #{l}" }.join("\n")
  UI.messagebox("Enhanced probe failed:\n\n#{e.class}: #{e.message}\n\nSee the Ruby Console.")
end
