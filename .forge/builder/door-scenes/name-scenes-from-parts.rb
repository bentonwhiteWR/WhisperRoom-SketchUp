# Renames scene POSITIONS 355..422 of "Master Component List AM" to the name
# of the part each one looks at -- the COMPONENT IT LOOKS AT column of the
# Master Component List, resolved by the same rule (list-scenes.rb): nearest
# top-level instance to the camera target; definition name, else instance name.
# Only scenes whose name differs are touched. Duplicate or already-taken names
# refuse the whole run. Table first, Yes to apply, one undo step.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/.forge/builder/door-scenes/name-scenes-from-parts.rb"
module DSR
  TITLE = 'Master Component List AM'
  FIRST, LAST = 355, 422
  AUTONAME = /\A(Component|Group)#\d+\z/

  def self.subject(m, page)
    t = page.camera.target
    m.entities.select { |e| e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group) }
     .select { |e| e.bounds.valid? }
     .min_by { |e| e.bounds.contains?(t) ? 0.0 : t.distance(e.bounds.center).to_f }
  end

  def self.part_name(e)
    return nil if e.nil?
    if e.is_a?(Sketchup::ComponentInstance)
      n = e.definition.name.to_s.strip
      return n unless n.empty? || n =~ AUTONAME
    end
    n = e.name.to_s.strip
    n.empty? || n =~ AUTONAME ? nil : n
  end

  def self.run
    m = Sketchup.active_model
    raise "Bring #{TITLE} to the front (got #{m.title.inspect})" unless m.title == TITLE
    pages = m.pages.to_a
    raise "Model has only #{pages.size} scenes" if pages.size < LAST
    rows = (FIRST..LAST).map { |i| pg = pages[i - 1]; [i, pg, part_name(subject(m, pg))] }
    todo = rows.select { |_, pg, n| n && n != pg.name }
    newnames = rows.map { |_, pg, n| n || pg.name }
    bad = todo.select do |_, pg, n|
      newnames.count(n) > 1 || pages.any? { |p| p.name == n && !rows.any? { |r| r[1] == p } }
    end
    unres = rows.select { |_, _, n| n.nil? }
    lines = todo.map { |i, pg, n| format('%3d  %-34s -> %s%s', i, pg.name, n, bad.include?([i, pg, n]) ? '   << REFUSED: name clash' : '') }
    lines += unres.map { |i, pg, _| format('%3d  %-34s    (no named part in view -- left alone)', i, pg.name) }
    puts lines
    return 'All scenes already match their parts.' if todo.empty?
    return 'Name clash above. Nothing renamed.' unless bad.empty?
    ok = UI.messagebox("Rename #{todo.size} scenes to the part they look at?\n\n" + lines.join("\n"), MB_YESNO)
    return 'Cancelled. Nothing renamed.' unless ok == IDYES
    m.start_operation('Name scenes 355-422 after their parts', true)
    begin
      # two passes so a swap (A->B, B->A) never collides mid-way
      todo.each_with_index { |(_, pg, _), k| pg.name = "__tmp_rename_#{k}" }
      todo.each { |_, pg, n| pg.name = n }
      m.commit_operation
    rescue Exception
      m.abort_operation
      raise
    end
    "Renamed #{todo.size} scenes. Ctrl+Z undoes all of them."
  end
end
puts DSR.run
