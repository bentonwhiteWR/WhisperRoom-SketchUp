# @title Block-out booth (plain boxes, fast)...
# @cat Build the booth
# @rank 3
#
# Pick a booth from a dropdown and build it. This replaces the one-script-per-
# booth arrangement — new booths appear in the list as soon as the data file is
# regenerated, with no new script and no SketchUp restart.
#
# Data comes from wr-booth-data.rb in this folder, written by
#   python gen-booth.py --all
# which only includes booths whose assembly the run rule can actually prove.

module WR_BuildBooth
  DATA = File.join(File.dirname(__FILE__), 'wr-booth-data.rb')

  # Booth panels and seam seals are finished in this. Loads the real .skm from
  # SketchUp's own library; falls back to a same-named colour if it isn't found.
  # How far the IEP inner shell's underside sits above the outer shell's. The
  # 1.5 an Enhanced wall gives up splits between the floor lip and the ceiling
  # lip and THAT SPLIT IS NOT MEASURED. 0.3125 is the measured thickness of
  # every ENH floor part in the library, on the reading that the inner wall
  # stands on that sheet. Kept in step with IEP_WALL_LIFT in
  # build-booth-components.rb - change both together.
  IEP_LIFT = 0.3125

  PANEL_MATERIAL = 'Carpet Plush Charcoal'
  MAT_COLLECTION = 'Carpet, Fabrics, Leathers, Textiles and Wallpaper'

  def self.pt(x, y, z = 0.0)
    Geom::Point3d.new(x, y, z)
  end

  # Load the REAL .skm so the panels get the carpet texture, not a flat grey.
  # Sketchup.find_support_file doesn't reach the shared library, which lives under
  # ProgramData — so look there directly, newest SketchUp first.
  def self.material_roots
    roots = []
    begin
      b = Sketchup.find_support_file('Materials')
      roots << b if b
    rescue StandardError
    end
    pd = ENV['ProgramData'] || 'C:/ProgramData'
    %w[2026 2025 2024 2023 2022].each do |v|
      roots << File.join(pd.tr('\\', '/'), 'SketchUp', "SketchUp #{v}", 'SketchUp', 'Materials')
    end
    roots
  end

  def self.material(model, name)
    m = model.materials[name]
    return m if m && m.texture           # already here WITH its texture

    material_roots.each do |root|
      next unless File.directory?(root)
      [MAT_COLLECTION, 'Colors-Named', ''].each do |sub|
        path = sub.empty? ? File.join(root, "#{name}.skm") : File.join(root, sub, "#{name}.skm")
        next unless File.exist?(path)
        begin
          loaded = model.materials.load(path)
          return loaded if loaded
        rescue StandardError
        end
      end
    end

    puts "  (couldn't find #{name}.skm — falling back to a flat colour)"
    m ||= model.materials.add(name)
    m.color = Sketchup::Color.new(64, 62, 60)
    m
  end

  def self.run
    unless File.exist?(DATA)
      UI.messagebox("Booth data not found:\n#{DATA}\n\nRun:  python gen-booth.py --all")
      return
    end
    load DATA                      # re-read every time, so regenerating is enough

    keys = WR_BOOTH_DATA::BOOTHS.keys.sort_by do |k|
      m = k[/\d+/]
      [m ? m.to_i : 0, k]
    end
    if keys.empty?
      UI.messagebox("No booths in the data file.")
      return
    end

    last = Sketchup.read_default('WR_BuildBooth', 'last', keys.first)
    last = keys.first unless keys.include?(last)

    res = UI.inputbox(['Booth'], [last], [keys.join('|')], 'Build WhisperRoom Booth')
    return unless res
    key = res[0]
    Sketchup.write_default('WR_BuildBooth', 'last', key)
    build(key)
  end

  def self.build(key)
    spec  = WR_BOOTH_DATA::BOOTHS[key]
    model = Sketchup.active_model
    begin
      model.options['UnitsOptions']['LengthFormat'] = Length::Architectural
    rescue StandardError
    end
    model.start_operation("Build #{key}", true)

    tag = lambda do |name, rgb|
      l = model.layers[name] || model.layers.add(name)
      (l.color = Sketchup::Color.new(*rgb)) rescue nil
      l
    end
    t_wall = tag.call('WR-Booth-Walls', [120, 128, 140])
    t_door = tag.call('WR-Booth-Door',  [238,  98,  22])
    t_vent = tag.call('WR-Booth-Vent',  [ 64, 102, 124])
    t_seal = tag.call('WR-Booth-Seals', [ 90,  90,  96])
    t_corn = tag.call('WR-Booth-Corners', [70, 70, 76])

    mat = material(model, PANEL_MATERIAL)

    booth = model.entities.add_group
    booth.name = key

    walls = 0
    seal_n = 0
    corner_n = 0
    inner_n = 0
    spec[:parts].each do |p|
      g = booth.entities.add_group
      # Every part is a plan polygon — panels are rectangles, the mid-wall seal is
      # one T and the corner seal is one L, each extruded as a single solid.
      face = g.entities.add_face(p[:poly].map { |q| pt(q[0], q[1]) })
      next if face.nil?
      face.reverse! if face.normal.z < 0
      # An Enhanced booth's inner (IEP) shell is 1.5 shorter than its outer
      # one and its underside sits on the floor lip, so it is extruded from
      # its own height, not the booth's. Extruding both at :ph puts the
      # inner shell 1.5 too tall and standing on the deck - which looks
      # almost right, and is the dangerous kind of wrong.
      inner = p[:sh].to_s == 'in'
      ph = (inner && spec[:phi]) ? spec[:phi].to_f : spec[:ph].to_f
      face.pushpull(ph)
      if inner
        inner_n += 1
        g.transform!(Geom::Transformation.translation([0, 0, IEP_LIFT]))
      end
      g.name  = "#{p[:id]}  #{p[:sk]}" + (inner ? "  (IEP inner shell)" : "")
      g.layer = if p[:k] == 'corner' then (corner_n += 1; t_corn)
                elsif p[:k] == 'seal' then (seal_n += 1; t_seal)
                elsif p[:sk] == 'DRFRM' then (walls += 1; t_door)
                elsif p[:sk] == 'VNT'   then (walls += 1; t_vent)
                else (walls += 1; t_wall)
                end
      g.material = mat
    end

    model.commit_operation
    model.active_view.zoom_extents

    puts ''
    puts "#{key} — #{spec[:label]}"
    puts "  exterior #{spec[:w]}\" x #{spec[:h]}\"   interior #{spec[:iw]}\" x #{spec[:ih]}\""
    puts "  #{walls} wall panels, #{seal_n} mid-wall seam seals, #{corner_n} corner seam seals"
    puts "  panels 1\" thick, #{spec[:ph]}\" tall, finished in #{PANEL_MATERIAL}"
    if inner_n > 0
      puts "  #{inner_n} of those parts are the IEP inner shell - room #{spec[:eiw]}\" x #{spec[:eih]}\""
      puts "  inner walls #{spec[:phi]}\" tall, lifted #{IEP_LIFT}\" - THAT LIFT IS UNMEASURED"
    end
    puts ''
  rescue StandardError => e
    model.abort_operation if model
    UI.messagebox("Build failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(5)
  end
end

WR_BuildBooth.run
