# Names the combined-set scenes "Scene 412" .. "Scene 422" in "Master Component
# List AM" after the pattern Benton set by hand on scene 383:
#   ENH SET RightWADoor_HX_Open   (Enhanced: "ENH SET <door>_Open")
#   SET Right46Door_HX_Open       (Standard: "SET <door>_Open")
#
# The door is read off what each scene's camera looks at (nearest top-level
# instance to the camera target -- the list-scenes.rb rule), in this order:
#   1. that instance already carries a SET name  -> use it (e.g. scene 412)
#   2. an existing "<door>_Open" scene looks at the same instance -> <door>
#   3. its definition name minus "#n"; a mirrored Left copy reads as Right
# A ramp anywhere in the frame turns "WADoor" into "WADoorRamp" (Benton's own
# spelling on scene 412). Nothing is renamed until the table has been shown
# and Yes clicked; duplicates and taken names are refused. One undo step.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/.forge/builder/door-scenes/name-sets.rb"
module DSN
  TITLE   = 'Master Component List AM'
  TARGETS = (412..422).map { |i| "Scene #{i}" }

  def self.subject(m, page)
    t = page.camera.target
    m.entities.select { |e| e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group) }
     .select { |e| e.bounds.valid? }
     .min_by { |e| e.bounds.contains?(t) ? 0.0 : t.distance(e.bounds.center).to_f }
  end

  def self.label(e)
    [(e.name.to_s rescue ''), (e.definition.name.to_s rescue '')].find { |s| s =~ /\bSET\b/ } ||
      e.definition.name.to_s
  end

  def self.mirrored?(e)
    t = e.transformation
    t.xaxis.cross(t.yaxis).dot(t.zaxis) < 0
  end

  # Everything top-level whose centre sits inside the scene's frame.
  def self.in_frame(m, page)
    c = page.camera
    h = (c.perspective? ? 120.0 : c.height.to_f)
    t = c.target
    m.entities.select do |e|
      next false unless e.respond_to?(:definition) && e.bounds.valid?
      b = e.bounds.center
      (b.x - t.x).abs < h && (b.z - t.z).abs < h / 2 + 12
    end
  end

  def self.ramp?(list)
    seen = {}
    walk = lambda do |e|
      return true if "#{(e.name rescue '')} #{e.definition.name}" =~ /ramp/i
      d = e.definition
      return false if seen[d]
      seen[d] = true
      d.entities.any? { |x| x.respond_to?(:definition) && walk.call(x) }
    end
    list.any? { |e| walk.call(e) }
  end

  def self.plan(m)
    targets = TARGETS.map { |n| m.pages[n] or raise "#{n}: no scene by that name" }
    by_subject = {}
    m.pages.each do |pg|
      next if TARGETS.include?(pg.name) || pg.name !~ /_Open\z/ || pg.name =~ /\bSET\b/
      s = subject(m, pg)
      by_subject[s] ||= pg.name if s
    end
    targets.map do |pg|
      s = subject(m, pg) or next [pg, nil, 'no component in view']
      l = label(s)
      if l =~ /\bSET\b/
        name = l.sub(/#\d+\z/, '').sub('RIght', 'Right')
        name += '_Open' unless name.end_with?('_Open')
        next [pg, name, "set named in model (#{l})"]
      end
      if (sib = by_subject[s])
        base = sib.sub(/_Open\z/, ''); why = "same door as scene \"#{sib}\""
      else
        base = s.definition.name.sub(/#\d+\z/, '')
        base = base.sub('Left', 'Right') if mirrored?(s) && base.include?('Left')
        why = "from #{s.definition.name}#{mirrored?(s) ? ' (mirrored)' : ''}"
      end
      if ramp?(in_frame(m, pg)) && base.include?('WADoor') && base !~ /Ramp/
        base = base.sub('WADoor', 'WADoorRamp'); why += ', ramp in frame'
      end
      name = base.start_with?('ENH ') ? base.sub('ENH ', 'ENH SET ') : "SET #{base}"
      name += '_Open'
      why += ', door NOT open (depth <30")' if s.bounds.depth.to_f < 30
      [pg, name, why]
    end
  end

  def self.run
    m = Sketchup.active_model
    raise "Bring #{TITLE} to the front (got #{m.title.inspect})" unless m.title == TITLE
    rows = plan(m)
    names = rows.map { |_, n, _| n }
    bad = rows.select do |pg, n, _|
      n.nil? || names.count(n) > 1 || (m.pages[n] && m.pages[n] != pg)
    end
    lines = rows.map { |pg, n, why| format('%-10s -> %-34s %s%s', pg.name, n || '?', why, bad.any? { |b| b[0] == pg } ? '   << REFUSED' : '') }
    puts lines
    return 'Refused rows above (duplicate, taken, or unresolved). Nothing renamed.' unless bad.empty?
    ok = UI.messagebox("Rename these #{rows.size} scenes?\n\n" + lines.join("\n"), MB_YESNO)
    return 'Cancelled. Nothing renamed.' unless ok == IDYES
    m.start_operation('Name combined-set scenes', true)
    begin
      rows.each { |pg, n, _| pg.name = n }
      m.commit_operation
    rescue Exception
      m.abort_operation
      raise
    end
    "Renamed #{rows.size} scenes. Ctrl+Z undoes all of them."
  end
end
puts DSN.run
