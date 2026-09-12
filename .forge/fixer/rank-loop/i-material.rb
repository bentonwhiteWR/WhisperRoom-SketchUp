# RUN i, TASK 2 - BUILD A RENDER FLOOR AS A REAL V-RAY MATERIAL.
#
# WHY THIS FILE EXISTS.
#
# Run h's recommended floor, `Wood_Planks_01_1K`, has NO V-RAY MATERIAL. Read
# straight off the live V-Ray scene (observed, 11 Sep 2026) its plugin is:
#
#     /Wood_Planks_01_1K        _HostMaterial
#     /Wood_Floor_12_1K         _HostMaterial
#     /Marble_20_1K             _HostMaterial
#
# `_HostMaterial` is a shim with no BRDF, no diffuse texture plugin, no
# reflection and no roughness - not one of its parameters is even readable.
# It is the same class of object the rubric's scope note names as the blue
# foam's defect. Every other floor tested in runs g and h has a real material:
#
#     /Concrete Simple C01 200cm        MtlSingleBRDF -> BRDFVRayMtl
#     /Oak Honey Semigloss 300cm        MtlSingleBRDF -> BRDFVRayMtl
#     /Wood Tiles Shiny 03 100cm        MtlSingleBRDF -> BRDFVRayMtl
#     /WhisperRoom Floor Carpet         MtlSingleBRDF -> BRDFVRayMtl
#
# The three shims are exactly the three materials loaded from `.skm` files
# whose textures point at `P:/SketchUp projects/2025 PBR Materials/...`, a path
# that DOES NOT EXIST on this machine. The four real ones point at files that
# do. That is the likeliest cause and it is stated as a correlation of three
# against four, not as a proven mechanism.
#
# WHAT THIS DOES. Creates a SketchUp material from a texture file that is in
# the repo (so the path resolves on every machine), sets its texture size, and
# calls V-Ray's own converter - the same one the Asset Editor's "Convert to
# V-Ray material" runs - so V-Ray builds it a real `BRDFVRayMtl` with its own
# diffuse texture. It then reads the BRDF back and prints what V-Ray holds.
#
# WHAT IT CANNOT DO, MEASURED RATHER THAN ASSUMED. It cannot give the material
# a reflection. `reflect` and `reflect_glossiness` were written inside a
# labelled `scene.change` using wr-drop-lights.rb's own proven write form, the
# writes raised nothing, and both read back at V-Ray's defaults (0,0,0) and 1.0.
# V-Ray's SketchUp->V-Ray material syncer owns those slots for a material that
# is bound to a SketchUp material, and resets them. `/WhisperRoom Floor Carpet`
# - WhisperRoom's own shipping material, converted the same way - carries
# reflect (0,0,0) too, so a matte converted material is the NORMAL shape here,
# not a failure of this script. A floor with a real reflection has to come in
# as an imported V-Ray asset (the Cosmos route), not as a converted SketchUp
# material.
#
# DO NOT TRY TO UNBIND THE MATERIAL TO GET AROUND THAT. Writing
# `bind_all_on = 0` on the MtlSingleBRDF raised inside `scene.change`, left the
# bridge listener's re-entrancy flag set, and wedged the job queue until the
# flag was cleared by hand from the Ruby Console. It cost twenty minutes and it
# did not work. Recorded so nobody spends them again.
#
# CONFIG - three keys read from the same `rank-loop-d.json` everything else
# reads, so the settings live in one place:
#
#   "build_name": "WR Plank Grey Wide 48"    the material to end up with
#   "build_tex":  "assets/textures/..."      repo-relative, or absolute
#   "build_size": 48.0                       texture size in INCHES, square
#
# It does NOT paint the floor. `h-floor.rb` does that, from `floor`, and the
# two steps stay separate so "one variable per cycle" is still checkable.
load 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/fixer/rank-loop/d-lib.rb'

module IMAT
  REPO = 'C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp'.freeze

  def self.build!
    c = DCYC.cfg
    m = DCYC.model
    name = c['build_name'].to_s
    raise 'config has no "build_name"' if name.empty?
    tex = c['build_tex'].to_s
    raise 'config has no "build_tex"' if tex.empty?
    tex = File.join(REPO, tex) unless tex =~ /\A[A-Za-z]:/
    raise "no texture at #{tex}" unless File.exist?(tex)
    size = (c['build_size'] || 48.0).to_f

    mat = m.materials[name]
    how = 'already in model'
    if mat.nil?
      m.start_operation('WR i-material: create', true)
      begin
        mat = m.materials.add(name)
        mat.texture = tex
        m.commit_operation
      rescue StandardError => e
        m.abort_operation
        raise e
      end
      how = 'created'
    end
    m.start_operation('WR i-material: texture size', true)
    mat.texture.size = size if mat.texture
    m.commit_operation

    sc = VRay::Context.active.scene
    before = (sc["/#{name}"] rescue nil)
    was = before ? before.type.to_s : 'NONE'

    # V-Ray's own converter. VRay::Material.find returns nil for a material
    # that has no V-Ray material yet, which is precisely the case here, so the
    # module-level MaterialSync entry point is the one that works cold.
    begin
      vm = (VRay::Material.find(mat) rescue nil)
      if vm && vm.respond_to?(:convert_to_vray)
        vm.convert_to_vray
      else
        VRay::MaterialSync.convert_to_vray(mat)
      end
    rescue StandardError => e
      raise "convert_to_vray failed: #{e.class}: #{e.message}"
    end

    top = (sc["/#{name}"] rescue nil)
    brdf = nil
    sc.each { |pl| brdf = pl if pl.name.to_s.start_with?("/#{name}/") && pl.type.to_s == 'BRDFVRayMtl' }
    raise "convert produced no BRDFVRayMtl for #{name.inspect}" if brdf.nil?

    dc = brdf[:diffuse_color]
    dif = (brdf[:diffuse] rescue nil)
    rf = (brdf[:reflect] rescue nil)
    dlum = 0.2126 * dc.r + 0.7152 * dc.g + 0.0722 * dc.b
    col = mat.color
    puts format('MATERIAL: %s (%s)', name, how)
    puts format('  V-Ray plugin  %s -> %s', was, top ? top.type.to_s : 'NONE')
    puts format('  SU colour     rgb(%d,%d,%d)  texture %s  %.2f in',
                col.red, col.green, col.blue,
                File.basename(mat.texture.filename.to_s), mat.texture.width.to_f)
    puts format('  BRDF          %s', brdf.name)
    puts format('  diffuse_color (%.4f, %.4f, %.4f)  linear luminance %.4f  R/B %.3f',
                dc.r, dc.g, dc.b, dlum, dc.b.zero? ? 0.0 : dc.r / dc.b)
    puts format('  diffuse       %s',
                dif.is_a?(VRay::Scene::Plugin) ? dif.name : dif.inspect)
    puts format('  reflect       (%.4f, %.4f, %.4f)  glossiness %s   ' \
                '(V-Ray owns these for a bound SketchUp material - see header)',
                rf.r, rf.g, rf.b, (brdf[:reflect_glossiness] rescue nil).inspect)
    { 'name' => name, 'was' => was, 'now' => (top ? top.type.to_s : nil),
      'brdf' => brdf.name,
      'diffuse_color' => [dc.r.round(4), dc.g.round(4), dc.b.round(4)],
      'diffuse_lum' => dlum.round(4),
      'reflect' => [rf.r.round(4), rf.g.round(4), rf.b.round(4)],
      'tex' => File.basename(mat.texture.filename.to_s),
      'tex_in' => mat.texture.width.to_f.round(2) }
  end
end

IMAT.build!
