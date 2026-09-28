# Restacks the 56 _Open / _NoDoor door copies into 8 rows GAP apart, starting GAP
# above the highest original door row. Each scene's camera moves with its door
# (only the camera is updated). Benton's own copies of these doors are not moved.
load File.join(File.dirname(__FILE__), 'build.rb')
module DS
  GAP = 240.0 # 20'
  def self.row_of(n) = (n.start_with?('ENH') ? 2 : 0) + (n.end_with?('_HX') ? 1 : 0)
  def self.restack(dry)
    m = model!
    names = STD + ENH
    origs = names.to_h { |n| [n, top(m, n)] }
    row_z = (0..3).map { |r| names.select { |n| row_of(n) == r }.map { |n| origs[n].bounds.min.z }.min }
    top_z = names.map { |n| origs[n].bounds.max.z }.max
    base = top_z + GAP
    plan = []
    [['Open', 0], ['NoDoor', 1]].each do |suf, vi|
      names.each do |n|
        pn = "#{n}_#{suf}"
        pg = m.pages[pn] or raise "#{pn}: no scene"
        e = pg.camera.eye
        copy = m.entities.select { |i| i.respond_to?(:definition) && i.name == pn }
                .min_by { |i| c = i.bounds.center; (c.x - e.x)**2 + (c.z - e.z)**2 }
        raise "#{pn}: copy not found" unless copy
        r = row_of(n)
        target = base + (vi * 4 + r) * GAP + (origs[n].bounds.min.z - row_z[r])
        plan << [pn, copy, pg, target - copy.bounds.min.z]
      end
    end
    return plan.map { |pn, _, _, dz| format('%-30s move %+.1f ft', pn, dz / 12.0) } + ["base #{(base / 12).round(1)} ft"] if dry
    m.start_operation('Restack door copies 20 ft apart', true)
    tt = m.options['PageOptions']['TransitionTime']
    sel = m.pages.selected_page
    begin
      m.options['PageOptions']['TransitionTime'] = 0
      plan.each do |pn, copy, pg, dz|
        v = Geom::Vector3d.new(0, 0, dz)
        copy.transform!(Geom::Transformation.translation(v))
        m.pages.selected_page = pg
        c = pg.camera
        cam = Sketchup::Camera.new(c.eye.offset(v), c.target.offset(v), c.up, c.perspective?)
        if c.perspective? then cam.fov = c.fov else cam.height = c.height end
        m.active_view.camera = cam
        pg.update(1) # PAGE_USE_CAMERA only
      end
      m.commit_operation
    rescue Exception
      m.abort_operation
      raise
    ensure
      m.options['PageOptions']['TransitionTime'] = tt
      m.pages.selected_page = sel if sel && sel.valid?
    end
    ["restacked #{plan.size} copies; rows start at #{(base / 12).round(1)} ft"]
  end
end
puts DS.restack($DS_RDRY != false) if $DS_RGO
$DS_RGO = false
