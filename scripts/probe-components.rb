# @title Probe Component Files...
# @cat Model tools
#
# Loads every .skp in a folder, measures it, and writes a table. This is the
# step that has to happen BEFORE a booth can be assembled from real components
# instead of extruded boxes.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/probe-components.rb"
#
# RUN IT ON AN EMPTY MODEL. It loads ~180 definitions into whatever model is
# open. It purges them again at the end, but a purge cannot remove a definition
# that something in your model already uses, so a scratch file is the safe place.
#
# WHY THIS EXISTS
#
# build-booth.rb currently draws each panel as a rectangle and push-pulls it into
# a featureless slab. The data behind it (wr-booth-data.rb) knows every panel's
# position, length and kind, which is enough for boxes. It is NOT enough to drop
# in a real component, because placing a component needs two things the data
# does not carry:
#
#   1. HOW BIG the component actually is, so it can be checked against the slot
#      the layout expects it to fill. A 40 inch panel that measures 40.0625 will
#      accumulate a quarter inch of error over six panels.
#   2. WHERE ITS ORIGIN SITS relative to its own geometry. save_as writes a
#      definition in its own axes, and if the origin is a corner on some parts
#      and a centre on others, a single placement rule cannot be right for both.
#
# Both are measurable, and neither is guessable. Hence this.
#
# The table it writes also answers the orientation question: comparing the X and
# Y extents says whether the panel's length runs along its own X or its own Y,
# which is what an assembler needs in order to rotate it onto a wall.

require 'sketchup.rb'

# The folder field is a dropdown of folders used before, plus a Browse entry.
load File.join(File.dirname(__FILE__), 'wr-folder.rb')

module WR_Probe
  PREF = 'WR_Probe'.freeze
  DEFAULT_DIR = 'P:/Sketchup/NewMasterComponentList'.freeze

  def self.ask
    dir, list = WR_Folder.field('parts', DEFAULT_DIR)

    res = UI.inputbox(['Folder of .skp files', 'Purge the definitions afterwards'],
                      [dir, 'Yes'], [list, 'Yes|No'], 'Probe Component Files')
    return nil unless res

    # create = false, because this folder is an INPUT. Silently creating an empty
    # one and then reporting "no .skp files in it" would hide a mistyped drive
    # letter as an empty-folder problem.
    d = WR_Folder.resolve(res[0], 'parts', 'Folder of component .skp files', false)
    return nil if d.nil?
    { 'dir' => d, 'purge' => res[1].to_s }
  end

  # Everything reported here is in the DEFINITION's own coordinates, which is
  # what an instance placement has to reason about.
  def self.measure(defn)
    bb = defn.bounds
    return nil unless bb.valid?
    mn = bb.min
    mx = bb.max
    # max minus min per axis, NOT BoundingBox#width/height/depth — which of those
    # means Y and which means Z is a coin-flip, and getting it backwards reports
    # a part's height as its width.
    row = {
      :name => defn.name.to_s,
      :w  => mx.x.to_f - mn.x.to_f,   # X extent
      :d  => mx.y.to_f - mn.y.to_f,   # Y extent
      :h  => mx.z.to_f - mn.z.to_f,   # Z extent
      :ox => -mn.x.to_f,         # where the origin sits inside the box,
      :oy => -mn.y.to_f,         # measured from the box's own minimum corner
      :oz => -mn.z.to_f,
      :ents => defn.entities.length
    }
    # Long horizontal axis: which way the part runs when it is lying in place.
    row[:runs] = row[:w] >= row[:d] ? 'X' : 'Y'
    row[:len]  = [row[:w], row[:d]].max
    row[:thk]  = [row[:w], row[:d]].min
    # Is the origin a corner of the box, its centre, or neither? A mixed answer
    # across the set is the thing that would break a single placement rule.
    row[:anchor] = anchor_of(row)
    row
  end

  TOL = 0.01

  def self.anchor_of(r)
    cx = near(r[:ox], 0) ? 'min' : (near(r[:ox], r[:w]) ? 'max' : (near(r[:ox], r[:w] / 2.0) ? 'mid' : '?'))
    cy = near(r[:oy], 0) ? 'min' : (near(r[:oy], r[:d]) ? 'max' : (near(r[:oy], r[:d] / 2.0) ? 'mid' : '?'))
    cz = near(r[:oz], 0) ? 'min' : (near(r[:oz], r[:h]) ? 'max' : (near(r[:oz], r[:h] / 2.0) ? 'mid' : '?'))
    "#{cx}/#{cy}/#{cz}"
  end

  def self.near(a, b)
    (a - b).abs < TOL
  end

  def self.run
    model = Sketchup.active_model
    if model.nil?
      UI.messagebox('No model is open.')
      return
    end

    cfg = ask
    return if cfg.nil?

    files = Dir.glob(File.join(cfg['dir'], '*.skp')).sort
    if files.empty?
      UI.messagebox("No .skp files in\n#{cfg['dir']}")
      return
    end

    if model.entities.length > 0
      go = UI.messagebox("This model is not empty.\n\n#{files.length} definitions are about " \
                         "to be loaded into it. A purge cannot remove any that your model " \
                         "already uses.\n\nCarry on anyway?", MB_OKCANCEL)
      return if go != IDOK
    end

    puts ''
    puts "PROBE — #{files.length} files in #{cfg['dir']}"
    puts ''

    rows = []
    failed = []
    before = model.definitions.map { |d| d.name }

    files.each_with_index do |path, i|
      Sketchup.status_text = "Probing #{i + 1}/#{files.length}: #{File.basename(path)}"
      begin
        defn = model.definitions.load(path)
        if defn.nil?
          failed << [File.basename(path), 'load returned nil']
          next
        end
        r = measure(defn)
        if r.nil?
          failed << [File.basename(path), 'no valid bounds']
          next
        end
        r[:file] = File.basename(path)
        rows << r
      rescue StandardError => e
        failed << [File.basename(path), "#{e.class}: #{e.message}"]
      end
    end
    Sketchup.status_text = ''

    report(cfg, rows, failed, before)
  end

  def self.report(cfg, rows, failed, before)
    wf = [rows.map { |r| r[:file].length }.max || 4, 4].max
    wn = [rows.map { |r| r[:name].length }.max || 4, 4].max

    puts format("  %-#{wf}s  %-#{wn}s  %8s %8s %8s   %6s %5s  %-11s  %s",
                'FILE', 'DEFINITION', 'X', 'Y', 'Z', 'LENGTH', 'RUNS', 'ORIGIN', 'THICK')
    puts '  ' + '-' * (wf + wn + 66)
    rows.each do |r|
      puts format("  %-#{wf}s  %-#{wn}s  %8.4f %8.4f %8.4f   %6.3f %5s  %-11s  %.4f",
                  r[:file], r[:name], r[:w], r[:d], r[:h], r[:len], r[:runs], r[:anchor], r[:thk])
    end

    # ---- the summaries that actually decide whether an assembler can be written
    puts ''
    puts '  ---- heights ----'
    tally(rows.map { |r| format('%.4f', r[:h]) })

    puts ''
    puts '  ---- thicknesses ----'
    tally(rows.map { |r| format('%.4f', r[:thk]) })

    puts ''
    puts '  ---- origin anchor, definition space ----'
    tally(rows.map { |r| r[:anchor] })
    puts '    A SINGLE anchor across the set means one placement rule works for'
    puts '    everything. A mix means placement has to go by bounding box.'

    puts ''
    puts '  ---- length vs the number in the name ----'
    off = []
    rows.each do |r|
      m = r[:file][/\A(\d+)/]
      next if m.nil?
      want = m.to_f
      next if want < 5
      d = r[:len] - want
      off << format('%-34s name says %-6.1f measures %.4f  (%+.4f)', r[:file], want, r[:len], d) if d.abs > 0.02
    end
    if off.empty?
      puts '    every numbered part measures its name, within 0.02 in.'
    else
      puts "    #{off.length} part(s) do not measure their name:"
      off.first(25).each { |l| puts "    #{l}" }
      puts "    ...and #{off.length - 25} more" if off.length > 25
    end

    unless failed.empty?
      puts ''
      puts "  ---- #{failed.length} failed to load ----"
      failed.each { |f, why| puts format('    %-40s %s', f, why) }
    end

    write_tsv(cfg, rows, failed)

    if cfg['purge'] == 'Yes'
      model = Sketchup.active_model
      n = model.definitions.length
      begin
        model.definitions.purge_unused
        puts ''
        puts "  purged — definitions #{n} -> #{model.definitions.length}"
      rescue StandardError => e
        puts "  purge failed: #{e.class}: #{e.message}"
      end
    end

    puts ''
    puts "  #{rows.length} measured, #{failed.length} failed."
    puts ''
  end

  def self.tally(vals)
    vals.group_by { |v| v }.map { |v, a| [v, a.length] }.sort_by { |_v, n| -n }.each do |v, n|
      puts format('    %-14s %d', v, n)
    end
  end

  def self.write_tsv(cfg, rows, failed)
    path = File.join(cfg['dir'], '_component-probe.tsv')
    File.open(path, 'w') do |f|
      f.puts %w[file definition x y z length thickness height runs origin_anchor
                origin_x origin_y origin_z entities].join("\t")
      rows.each do |r|
        f.puts [r[:file], r[:name], format('%.4f', r[:w]), format('%.4f', r[:d]),
                format('%.4f', r[:h]), format('%.4f', r[:len]), format('%.4f', r[:thk]),
                format('%.4f', r[:h]), r[:runs], r[:anchor],
                format('%.4f', r[:ox]), format('%.4f', r[:oy]), format('%.4f', r[:oz]),
                r[:ents]].join("\t")
      end
      failed.each { |fl, why| f.puts [fl, 'FAILED', why].join("\t") }
    end
    puts ''
    puts "  table  #{path}"
  rescue StandardError => e
    puts "  table NOT written: #{e.class}: #{e.message}"
  end
end

begin
  WR_Probe.run
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(12).map { |l| "  #{l}" }.join("\n")
  UI.messagebox("Probe failed:\n\n#{e.class}: #{e.message}\n\nSee the Ruby Console.")
end
