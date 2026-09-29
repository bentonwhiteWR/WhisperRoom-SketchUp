# Renames the part each scene looks at to that scene's name, for scene
# POSITIONS 355..422 (the # column in the Master Component List) of
# "Master Component List AM". Run name-sets.rb first so Scene 412..422 carry
# real names -- any scene still called "Scene nnn" is skipped.
#
# Subject = nearest top-level instance to the camera target (list-scenes.rb rule).
# Component -> its DEFINITION is renamed (what the list and exporters read).
# Group     -> definition AND instance name (name-selection-after-scene.rb rule).
# Refused (whole run stops, nothing renamed):
#   - two scenes resolving to the same part
#   - a definition shared by other instances (renaming would rename those too)
#   - a name already used by a different definition
# Names are read back after assignment; a silent "#1" uniquing aborts the lot.
# Table first, Yes to apply, one undo step.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/.forge/builder/door-scenes/name-parts.rb"
module DSP
  TITLE = 'Master Component List AM'
  FIRST, LAST = 355, 422

  def self.subject(m, page)
    t = page.camera.target
    m.entities.select { |e| e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group) }
     .select { |e| e.bounds.valid? }
     .min_by { |e| e.bounds.contains?(t) ? 0.0 : t.distance(e.bounds.center).to_f }
  end

  def self.run
    m = Sketchup.active_model
    raise "Bring #{TITLE} to the front (got #{m.title.inspect})" unless m.title == TITLE
    pages = m.pages.to_a
    raise "Model has only #{pages.size} scenes" if pages.size < LAST
    rows = (FIRST..LAST).map do |i|
      pg = pages[i - 1]
      next [i, pg, nil, 'SKIP: scene still has a placeholder name'] if pg.name =~ /\AScene \d+\z/
      s = subject(m, pg)
      next [i, pg, nil, 'SKIP: no part in view'] unless s
      [i, pg, s, nil]
    end
    live = rows.select { |r| r[2] }
    live.each do |r|
      _, pg, s, _ = r
      d = s.definition
      others = d.instances.size
      twin = live.count { |x| x[2] == s }
      taken = m.definitions.find { |x| x.name == pg.name && x != d }
      r[3] = if twin > 1 then 'REFUSED: another scene resolves to the same part'
             elsif others > 1 then "REFUSED: definition shared by #{others} instances"
             elsif taken then 'REFUSED: name already used by another definition'
             elsif d.name == pg.name then 'already named'
             end
    end
    lines = rows.map { |i, pg, s, note| format('%3d %-34s <- %-34s %s', i, pg.name, s ? s.definition.name : '-', note.to_s) }
    puts lines
    return 'Refused rows above. Nothing renamed.' if rows.any? { |r| r[3].to_s.start_with?('REFUSED') }
    todo = live.reject { |r| r[3] }
    return 'Nothing to rename.' if todo.empty?
    ok = UI.messagebox("Rename #{todo.size} parts to their scene names?\n\n" +
                       lines.first(40).join("\n") + (lines.size > 40 ? "\n... (full list in Ruby Console)" : ''), MB_YESNO)
    return 'Cancelled. Nothing renamed.' unless ok == IDYES
    m.start_operation('Name parts after scenes 355-422', true)
    begin
      todo.each do |_, pg, s, _|
        s.definition.name = pg.name
        raise "#{pg.name}: SketchUp stored #{s.definition.name.inspect}" unless s.definition.name == pg.name
        s.name = pg.name if s.is_a?(Sketchup::Group)
      end
      m.commit_operation
    rescue Exception
      m.abort_operation
      raise
    end
    "Renamed #{todo.size} parts. Ctrl+Z undoes all of them."
  end
end
puts DSP.run
