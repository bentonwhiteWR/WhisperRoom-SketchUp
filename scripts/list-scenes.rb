# @title List Scenes...
# @cat Model tools
#
# Prints every scene with its NUMBER, so "scenes 1-40" can be typed into the
# exporters with some idea of what it will actually cover. Two hundred scenes
# named "(Left46Door)" are impossible to count by eye, and guessing the range is
# how half a run comes out wrong.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/list-scenes.rb"
#
# The numbers are the SAME ones the exporters use: position in model.pages,
# counting from 1, in the order the scene tabs run left to right. Reorder the
# tabs and the numbers change — this is a snapshot, not an identifier.
#
# For each scene it also resolves WHICH COMPONENT that scene is looking at, by
# the same camera-target rule angled-component-art.rb uses, so the list answers
# "which numbers do I need" rather than only "what are they called".
#
# READ ONLY. No camera moves, no scene is activated, nothing is written to the
# model. It optionally saves the table as a text file so it can be searched.

require 'sketchup.rb'

module WR_ListScenes
  AUTONAME = /\A(Component|Group)#\d+\z/.freeze

  # Same rule as the exporters: a scene's camera target names its subject, and
  # the nearest top-level instance to that target is what the scene is about.
  def self.subject_for(model, page)
    cam = (page.camera rescue nil)
    return nil if cam.nil?
    t = cam.target
    best = nil
    bestd = nil
    model.entities.each do |e|
      next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
      bb = e.bounds
      next unless bb.valid?
      d = bb.contains?(t) ? 0.0 : t.distance(bb.center).to_f
      if bestd.nil? || d < bestd
        bestd = d
        best = e
      end
    end
    best
  end

  def self.component_name(e)
    return '(unresolved)' if e.nil?
    if e.is_a?(Sketchup::ComponentInstance)
      n = (e.definition.name.to_s.strip rescue '')
      return n unless n.empty? || n =~ AUTONAME
    end
    n = (e.name.to_s.strip rescue '')
    return n unless n.empty? || n =~ AUTONAME
    '(unnamed)'
  end

  def self.size_of(e)
    return '' if e.nil?
    bb = e.bounds
    return '' unless bb.valid?
    format('%.1f x %.1f x %.1f', bb.width.to_f, bb.height.to_f, bb.depth.to_f)
  end

  def self.run
    model = Sketchup.active_model
    if model.nil? || model.pages.count.zero?
      UI.messagebox('This model has no scenes.')
      return
    end

    pages = model.pages.to_a
    rows = pages.each_with_index.map do |page, i|
      subj = subject_for(model, page)
      { :n => i + 1, :scene => page.name.to_s, :comp => component_name(subj),
        :size => size_of(subj) }
    end

    wn = [rows.map { |r| r[:scene].length }.max || 5, 5].max
    wc = [rows.map { |r| r[:comp].length }.max  || 9, 9].max

    lines = []
    lines << ''
    lines << "SCENES IN #{model.title.to_s.empty? ? '(unsaved model)' : model.title}"
    lines << "  #{pages.length} scenes. Type these numbers into the exporters' Scenes field,"
    lines << '  singly (7), as a range (1-40), or comma separated (1-7,12,30-33).'
    lines << ''
    lines << format("  %-4s %-#{wn}s  %-#{wc}s  %s", '#', 'SCENE', 'COMPONENT IT LOOKS AT', 'SIZE in (w x h x d)')
    lines << '  ' + '-' * (4 + wn + wc + 26)
    rows.each do |r|
      lines << format("  %-4d %-#{wn}s  %-#{wc}s  %s", r[:n], r[:scene], r[:comp], r[:size])
    end

    unresolved = rows.count { |r| r[:comp] == '(unresolved)' }
    lines << '  ' + '-' * (4 + wn + wc + 26)
    lines << "  #{rows.length} scenes, #{unresolved} of which resolve to no component."
    lines << ''

    lines.each { |l| puts l }

    # Two hundred lines scroll off the Ruby Console fast, so offer a copy on disk.
    if UI.messagebox("#{rows.length} scenes listed in the Ruby Console.\n\n" \
                     'Save the list as a text file as well?', MB_YESNO) == IDYES
      dir = (UI.select_directory(:title => 'Where should the scene list go?') rescue nil)
      unless dir.nil? || dir.to_s.empty?
        path = File.join(dir.to_s.tr('\\', '/'), '_scene-list.txt')
        begin
          File.open(path, 'w') { |f| lines.each { |l| f.puts l } }
          puts "  saved #{path}"
        rescue StandardError => e
          puts "  could not save: #{e.class}: #{e.message}"
        end
      end
    end
    nil
  end
end

begin
  WR_ListScenes.run
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(10).map { |l| "  #{l}" }.join("\n")
end
