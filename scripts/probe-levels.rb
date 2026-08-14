# @title Probe Face Levels...
# @cat Model tools
#
# For each part, the HEIGHTS OF ITS HORIZONTAL FACES and how much area sits at
# each one. That is how a floor panel's perimeter strip gets measured, and a
# bounding box cannot do it.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/probe-levels.rb"
#
# WHY THIS EXISTS, AND WHY probe-components.rb IS NOT ENOUGH
#
# The stack-up is: floor panels butt against each other, the walls sit on the
# floor's perimeter STRIP, ceilings butt against each other and sit on top of
# the walls on a similar strip. So the number the builder needs is the height of
# that strip's top face inside the panel — the Z the wall's underside lands on.
#
# probe-components.rb reports a bounding box. A panel with a recessed field and
# a raised perimeter has EXACTLY the same bounding box as a plain slab of the
# same outside size. The strip is invisible to it. Trusting the box would drop
# every wall onto the panel's outer top face and leave the whole booth sitting
# proud by the depth of the recess — a wrong answer that looks plausible.
#
# So this walks the actual faces, keeps the ones lying flat, and bins them by
# height. A plain slab reports two levels, bottom and top. A panel with a strip
# reports three, and the gap between the top two IS the recess depth.
#
# READ ONLY, but it LOADS definitions into the open model, so run it on a
# scratch file. It purges afterwards, and a purge cannot remove a definition
# something in your model already uses.
#
# The filter is there because 237 parts is a long wait for an answer about
# floors: type FL to get the floors, CL the ceilings, or leave it blank for all.

require 'sketchup.rb'

# The folder field is a dropdown of folders used before, plus a Browse entry.
load File.join(File.dirname(__FILE__), 'wr-folder.rb')

module WR_ProbeLevels
  # remove_const, NOT `unless defined?`. The guard silences the reload warning
  # and also freezes the value for the session, so editing a threshold and
  # re-running would quietly do nothing. Same trap that cost four rounds on
  # wr-deck.rb.
  %w[PREF DEFAULT_DIR FLAT_DOT BIN MIN_SHARE].each do |c|
    remove_const(c) if const_defined?(c, false)
  end

  PREF        = 'WR_ProbeLevels'.freeze
  DEFAULT_DIR = 'P:/Sketchup/NewMasterComponentList'.freeze

  # A face counts as horizontal when its normal is within this of straight up or
  # straight down. Generous, because a panel face modelled a hair off level is
  # still the face a wall sits on.
  FLAT_DOT = 0.999

  # Heights are binned to this before grouping, so a face split into two
  # coplanar halves does not report as two levels 0.0001 apart.
  BIN = 1.0 / 64.0

  # A level holding less area than this SHARE of the panel's biggest level is a
  # chamfer, a screw boss or a bracket, not a surface anything sits on.
  #
  # This was an absolute 4 square inches and that was far too generous: on the
  # 48x96 ceilings it let through levels of 4.6 and 10.3 sq in beside real faces
  # of 4300, and the "step" it then reported was the gap between two screw
  # bosses — a confident number describing nothing. A fraction scales with the
  # panel, which an absolute figure cannot.
  MIN_SHARE = 0.05

  def self.read_pref(k, fallback = '')
    v = Sketchup.read_default(PREF, k, fallback).to_s
    v.empty? ? fallback : v
  rescue Exception
    fallback
  end

  def self.write_pref(k, v)
    Sketchup.write_default(PREF, k, v.to_s.delete('"'))
  rescue Exception
    nil
  end

  def self.ask
    dir, list = WR_Folder.field('parts', DEFAULT_DIR)
    res = UI.inputbox(['Folder of .skp files',
                       'Only names containing (blank = all)',
                       'Purge the definitions afterwards'],
                      [dir, read_pref('filter', 'FL'), 'Yes'],
                      [list, '', 'Yes|No'],
                      'Probe Face Levels')
    return nil unless res
    d = WR_Folder.resolve(res[0], 'parts', 'Folder of component .skp files', false)
    return nil if d.nil?
    write_pref('filter', res[1])
    { 'dir' => d, 'filter' => res[1].to_s.strip, 'purge' => res[2].to_s }
  end

  # ------------------------------------------------------------------ walking --

  # Every face in the definition, in the DEFINITION'S own coordinates, following
  # nested groups and components. A floor panel's strip may well be a separate
  # nested group, so not descending would miss the very thing being measured.
  def self.each_face(entities, tr, depth = 0, &blk)
    return if depth > 8
    entities.each do |e|
      case e
      when Sketchup::Face
        blk.call(e, tr)
      when Sketchup::ComponentInstance
        each_face(e.definition.entities, tr * e.transformation, depth + 1, &blk)
      when Sketchup::Group
        each_face(e.entities, tr * e.transformation, depth + 1, &blk)
      end
    end
  end

  # ---------------------------------------------------------------- brackets --
  #
  # WHERE THE HINGE BRACKETS SIT ALONG THE PANEL, which is what decides SIDE L
  # from SIDE R.
  #
  # A SIDE panel's wall run is one large wall (40 or 46 in) plus one small one
  # (16 or 22). The brackets land where those walls land, so the pattern is
  # asymmetric, and which END the small one is at IS the difference between L
  # and R. Reading it off the geometry means the handing is derived per part
  # rather than tabulated — and a tabulated one would have to be re-checked
  # every time a part is re-exported.
  #
  # WHAT THE GAPS MEAN, from Benton — this is the whole point of measuring them.
  #
  # On a 72 in panel the hinges sit either side of each wall, and the SPACING
  # between a pair says which wall drops into that slot:
  #
  #     2' 1/8   (24.125)  -> the slot for the LARGER wall  (46 in)
  #     1' 9 1/8 (21.125)  -> the slot for the SMALLER wall (22 in)
  #
  # READ THAT FIRST FIGURE CAREFULLY. It is TWO FEET and an eighth, not two and
  # an eighth. I had it as 2.125 and built the tagging around that, which would
  # have matched nothing and looked like the gaps were not there.
  #
  # The two are only 3 in apart, so the tolerance below has to be tight enough to
  # tell them apart and no tighter.
  #
  # Customers get this wrong constantly, and the give-away is that the hinge
  # pockets do not line up when the panel is the wrong way round. Which means the
  # panel carries its own orientation, and the builder should read it rather than
  # be told — no handing constant, no per-part table.
  #
  # ONLY BOOTHS WITH A SPLIT WALL RUN ARE AFFECTED: 6060, 6084, 7272, 7296.
  #
  # MEASURE ABOVE THE RIM, NOT ABOVE THE DECK. The first attempt at this took
  # every face above the deck and merged the spans, which produced one run
  # spanning the whole panel — because the perimeter rim at z 1.75 runs the full
  # length and overlaps every hinge. The hinges stand proud of the RIM, so that
  # is the floor to measure from.
  def self.brackets(defn, deck_z)
    long_is_y = (defn.bounds.max.y - defn.bounds.min.y) >=
                (defn.bounds.max.x - defn.bounds.min.x)
    spans = []
    each_face(defn.entities, Geom::Transformation.new) do |f, tr|
      begin
        pts = f.vertices.map { |v| v.position.transform(tr) }
        next if pts.all? { |p| p.z.to_f <= deck_z + 0.02 }
        vals = pts.map { |p| (long_is_y ? p.y : p.x).to_f }
        spans << [vals.min, vals.max]
      rescue StandardError
        next
      end
    end
    return [long_is_y, []] if spans.empty?

    # Merge overlapping spans into runs. Two faces of the same bracket overlap;
    # two different brackets do not.
    spans.sort!
    runs = [spans.first.dup]
    spans.each do |a, b|
      if a <= runs.last[1] + 0.05
        runs.last[1] = b if b > runs.last[1]
      else
        runs << [a, b]
      end
    end
    [long_is_y, runs.reject { |a, b| (b - a) < 0.25 }]
  rescue StandardError
    [true, []]
  end

  def self.levels(defn)
    up = Geom::Vector3d.new(0, 0, 1)
    tally = Hash.new(0.0)
    total = 0.0
    each_face(defn.entities, Geom::Transformation.new) do |f, tr|
      begin
        n = f.normal.transform(tr)
        n.normalize!
        next if n.dot(up).abs < FLAT_DOT
        pt = f.vertices.first.position.transform(tr)
        z  = (pt.z.to_f / BIN).round * BIN
        a  = f.area.to_f
        tally[z] += a
        total += a
      rescue StandardError
        next
      end
    end
    [tally, total]
  end

  # ------------------------------------------------------------------- report --

  def self.run
    model = Sketchup.active_model
    if model.nil?
      UI.messagebox('No model is open.')
      return
    end
    cfg = ask
    return if cfg.nil?

    files = Dir.glob(File.join(cfg['dir'], '*.skp')).sort
    unless cfg['filter'].empty?
      f = cfg['filter'].downcase
      files = files.select { |p| File.basename(p).downcase.include?(f) }
    end
    if files.empty?
      UI.messagebox("Nothing matches \"#{cfg['filter']}\" in\n#{cfg['dir']}")
      return
    end

    puts ''
    puts '=' * 78
    puts "PROBE FACE LEVELS — #{files.length} part(s)#{cfg['filter'].empty? ? '' : " matching \"#{cfg['filter']}\""}"
    puts "  #{cfg['dir']}"
    puts '=' * 78
    puts ''
    puts '  Z is height in the DEFINITION\'S own coordinates. For a floor panel the'
    puts '  TOP level is the perimeter strip the walls sit on, and the level just'
    puts '  below it is the recessed field. The gap between them is what the'
    puts '  builder needs.'
    puts ''

    rows = []
    files.each_with_index do |path, i|
      Sketchup.status_text = "Levels #{i + 1}/#{files.length}: #{File.basename(path)}"
      begin
        defn = model.definitions.load(path)
        next if defn.nil?
        tally, total = levels(defn)
        bb = defn.bounds
        # Measure hinges above the RIM, not above the deck.
        #
        # The rim is the highest level with any real area — 5% is enough, it is
        # a narrow border. Taking the deck instead (the near-full-area level)
        # left the rim itself in the sample, and since it runs the whole length
        # of the panel every hinge merged into it and the answer was one span.
        peak = tally.values.max.to_f
        rim = tally.select { |_z, a| a >= peak * 0.05 }.keys.max
        rim = bb.min.z.to_f if rim.nil?
        long_is_y, runs = brackets(defn, rim)
        rows << { :file => File.basename(path, '.skp'), :tally => tally,
                  :total => total, :bb => bb, :rim => rim,
                  :long_is_y => long_is_y, :runs => runs }
      rescue StandardError => e
        puts format('  %-28s FAILED %s: %s', File.basename(path), e.class, e.message)
      end
    end
    Sketchup.status_text = ''

    rows.each do |r|
      bb = r[:bb]
      puts format('  %-30s  box %.3f x %.3f x %.3f in   z %.4f .. %.4f',
                  r[:file], (bb.max.x - bb.min.x).to_f,
                  (bb.max.y - bb.min.y).to_f, (bb.max.z - bb.min.z).to_f,
                  bb.min.z.to_f, bb.max.z.to_f)
      peak = r[:tally].values.max.to_f
      big = r[:tally].select { |_z, a| a >= peak * MIN_SHARE }.sort_by { |z, _a| -z }
      small = r[:tally].length - big.length
      big.each do |z, a|
        puts format('        z %8.4f   %9.1f sq in  (%3.0f%%)  %s',
                    z, a, 100.0 * a / peak, bar(a, peak))
      end
      # BOTH ENDS get reported, because which one matters depends on which way
      # up the part is used. A FLOOR is sat on, so its TOP two levels are the
      # strip and the recess. A CEILING is sat UNDER, so the wall meets its
      # BOTTOM two. Reporting only the top made the ceiling numbers describe the
      # wrong face.
      if big.length >= 2
        puts format('        -> TOP    %.4f, next down %.4f, step %.4f in',
                    big[0][0], big[1][0], big[0][0] - big[1][0])
        puts format('        -> BOTTOM %.4f, next up   %.4f, step %.4f in',
                    big[-1][0], big[-2][0], big[-2][0] - big[-1][0])
      elsif big.length == 1
        puts '        -> ONE level only: a plain slab, no strip to find.'
      end
      puts format('        (%d level(s) under %d%% of the largest ignored)',
                  small, (MIN_SHARE * 100).round) if small > 0

      # The bracket runs, and the ONE number that decides SIDE L from SIDE R:
      # whether the biggest gap between brackets sits nearer the low or the high
      # end of the panel's long axis. That gap is the wall seam, and the short
      # side of it is where the small wall (16/22) goes.
      runs = r[:runs] || []
      unless runs.empty?
        axis = r[:long_is_y] ? 'Y' : 'X'
        len  = r[:long_is_y] ? (bb.max.y - bb.min.y).to_f : (bb.max.x - bb.min.x).to_f
        lo   = r[:long_is_y] ? bb.min.y.to_f : bb.min.x.to_f
        puts format('        hinges (z > %.4f), along %s over %.2f in:', r[:rim], axis, len)
        runs.each { |a, b| puts format('           %8.3f .. %-8.3f  (%.3f wide, %.0f%% along)',
                                       a, b, b - a, 100.0 * ((a + b) / 2.0 - lo) / len) }

        # THE GAPS BETWEEN HINGES ARE THE ANSWER, not the hinges themselves.
        # 24.125 in is the 46 in wall's slot, 21.125 in the 22 in wall's. Only
        # 3 in apart, so the tolerance is 1 in — wide enough for bracket
        # thickness, tight enough that the two cannot both match.
        if runs.length >= 2
          puts '        gaps between them:'
          runs.each_cons(2) do |x, y|
            g  = y[0] - x[1]
            at = 100.0 * ((x[1] + y[0]) / 2.0 - lo) / len
            tag = ''
            tag = "  <- 2'1/8, the 46 in slot"      if (g - 24.125).abs < 1.0
            tag = "  <- 1'9 1/8, the 22 in slot"    if (g - 21.125).abs < 1.0
            puts format('           %7.3f in at %3.0f%% along%s', g, at, tag)
          end
        end
      end
      puts ''
    end

    write_tsv(cfg, rows)

    if cfg['purge'] == 'Yes'
      n = model.definitions.length
      begin
        model.definitions.purge_unused
        puts "  purged — definitions #{n} -> #{model.definitions.length}"
      rescue StandardError => e
        puts "  purge failed: #{e.class}: #{e.message}"
      end
    end
    puts ''
    puts "  #{rows.length} part(s) measured."
    puts ''
  end

  def self.bar(a, total)
    return '' if total <= 0
    '#' * [(30.0 * a / total).round, 1].max
  end

  def self.write_tsv(cfg, rows)
    path = File.join(cfg['dir'], '_face-levels.tsv')
    File.open(path, 'w') do |f|
      f.puts %w[file box_x box_y box_z z area_sq_in].join("\t")
      rows.each do |r|
        bb = r[:bb]
        r[:tally].sort_by { |z, _a| -z }.each do |z, a|
          f.puts [r[:file],
                  format('%.4f', (bb.max.x - bb.min.x).to_f),
                  format('%.4f', (bb.max.y - bb.min.y).to_f),
                  format('%.4f', (bb.max.z - bb.min.z).to_f),
                  format('%.4f', z), format('%.2f', a)].join("\t")
        end
      end
    end
    puts "  table  #{path}"
  rescue StandardError => e
    puts "  table NOT written: #{e.class}: #{e.message}"
  end
end

begin
  WR_ProbeLevels.run
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(10).map { |l| "  #{l}" }.join("\n")
  UI.messagebox("Probe Face Levels failed:\n\n#{e.class}: #{e.message}\n\nSee the Ruby Console.")
end
