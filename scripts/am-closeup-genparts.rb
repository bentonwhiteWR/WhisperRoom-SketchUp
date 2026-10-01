# @title Assembly close-ups — generate stand-in hardware...
# @cat Component art (web catalog)
# @icon art-angled
#
# STAND-IN PARTS FOR THE CLOSE-UPS. A close-up that needs a small part the
# component library does not have (a loose bolt, a black plastic insert plug,
# a shim, a dollar bill) gets a simple modelled stand-in from here, saved as
# its own file:
#
#     Z:\Sketchup\BoothBuilderViews\AssemblyCloseups\_generated\GEN <part>.skp
#
# and NEVER into NewMasterComponentList or MasterComponentFolder. Benton
# reviews a stand-in and moves it into the library himself if he likes it.
# Every image that uses one is tagged GENERATED on the review page.
#
# Dimensions: SOURCE says where a number came from. "guess" means nobody has
# measured it — the close-up shows the part's role, not its spec.
#
# Every part is drawn in the open model inside one operation, written with
# ComponentDefinition#save_as, and the operation is ABORTED, so the open model
# is left as it was. Nothing else is saved.
#
# Bridge:
#   python scripts/sketchup-bridge.py eval "load File.join(WhisperRoom::Tools::SCRIPTS_DIR, 'am-closeup-genparts.rb'); WR_AmGenParts.run" --timeout 300
#
# Conventions (so the poses can place them):
#   bolts   axis along +X; the head sits in x = [-head, 0] and the shank in
#           x = [0, length]. The origin is the centre of the head's bearing
#           face, so a bolt placed at a hole points its shank down +X.
#   plug    same axis rule: cap in x = [-cap, 0], stem in x = [0, stem].
#   flat    shim, bill: lying in XY on z = 0, origin at a corner.

require 'sketchup.rb'
require 'json'
require 'fileutils'

module WR_AmGenParts
  OUT = 'Z:/Sketchup/BoothBuilderViews/AssemblyCloseups/_generated'.freeze

  MATS = {
    'black'  => [[28, 28, 30], 'WR GEN black (library <Black>)'],
    'chrome' => [[196, 199, 204], 'WR GEN chrome (library [Aluminum])'],
    'wood'   => [[201, 168, 120], 'WR GEN shim wood'],
    'bill'   => [[133, 165, 120], 'WR GEN bill green']
  }.freeze

  # name => spec. Every number carries its source.
  PARTS = [
    { 'name' => 'Bolt 1-5-8 black', 'kind' => 'bolt', 'mat' => 'black',
      'length' => 1.625, 'dia' => 0.3125, 'head_af' => 0.5, 'head' => 0.21,
      'source' => { 'length' => 'sourced: 1 5/8" (HW b158, WhisperRoomQuote lib/am-steps.js:315)',
                    'dia' => 'guess: 5/16"', 'head' => 'guess: 1/2" across flats x 0.21"' } },
    { 'name' => 'Bolt 3-4 black', 'kind' => 'bolt', 'mat' => 'black',
      'length' => 0.75, 'dia' => 0.3125, 'head_af' => 0.5, 'head' => 0.21,
      'source' => { 'length' => 'sourced: 3/4" (HW b34, am-steps.js:316)',
                    'dia' => 'guess: 5/16"', 'head' => 'guess: 1/2" across flats x 0.21"' } },
    { 'name' => 'Bolt 3-4 chrome', 'kind' => 'bolt', 'mat' => 'chrome',
      'length' => 0.75, 'dia' => 0.3125, 'head_af' => 0.5, 'head' => 0.21,
      'source' => { 'length' => 'sourced: 3/4" (HW c34, am-steps.js:317)',
                    'dia' => 'guess: 5/16"', 'head' => 'guess: 1/2" across flats x 0.21"' } },
    { 'name' => 'Bolt 3-1-2 chrome', 'kind' => 'bolt', 'mat' => 'chrome',
      'length' => 3.5, 'dia' => 0.3125, 'head_af' => 0.5, 'head' => 0.21,
      'source' => { 'length' => 'sourced: 3 1/2" (HW c312, am-steps.js:329)',
                    'dia' => 'guess: 5/16"', 'head' => 'guess: 1/2" across flats x 0.21"' } },
    { 'name' => 'Bolt IEP jamb long chrome', 'kind' => 'bolt', 'mat' => 'chrome',
      'length' => 3.0, 'dia' => 0.3125, 'head_af' => 0.5, 'head' => 0.21,
      'source' => { 'length' => 'guess: 3" (am-steps.js:1180 says the length is deliberately not stated; ' \
                                'frame 1" + adaptor 1" + IEP jamb 1" read off the library parts)',
                    'dia' => 'guess: 5/16"', 'head' => 'guess', 'finish' => 'guess: chrome' } },
    { 'name' => 'Insert plug black', 'kind' => 'plug', 'mat' => 'black',
      'cap_dia' => 0.625, 'cap' => 0.09, 'stem_dia' => 0.3, 'stem' => 0.4,
      'source' => { 'all' => 'guess: a black push-in cap for a 5/16" threaded insert, 5/8" cap, 0.4" stem' } },
    { 'name' => 'Shim', 'kind' => 'shim', 'mat' => 'wood',
      'len' => 8.0, 'width' => 1.5, 'thick' => 0.25,
      'source' => { 'all' => 'guess: a tapered shim 8" x 1 1/2", 1/4" to 1/32"' } },
    { 'name' => 'Dollar bill', 'kind' => 'flat', 'mat' => 'bill',
      'len' => 6.14, 'width' => 2.61, 'thick' => 0.0043,
      'source' => { 'all' => 'reported: US banknote 6.14" x 2.61" x 0.0043" (BEP figures, not measured here)' } }
  ].freeze

  def self.mat(model, key)
    rgb, nm = MATS[key]
    m = model.materials[nm] || model.materials.add(nm)
    m.color = Sketchup::Color.new(*rgb)
    m
  end

  # A prism along +X: an n-gon of circumradius r in the YZ plane at x0, pushed to x1.
  def self.prism(ents, x0, x1, r, n, m)
    pts = (0...n).map do |i|
      a = 2.0 * Math::PI * i / n + Math::PI / n
      Geom::Point3d.new(x0, r * Math.cos(a), r * Math.sin(a))
    end
    f = ents.add_face(pts)
    f.reverse! if f.normal.x < 0
    f.pushpull(x1 - x0)
    ents.grep(Sketchup::Face).each { |fc| fc.material = m; fc.back_material = m }
  end

  def self.build(defn, spec, m)
    g = defn.entities
    case spec['kind']
    when 'bolt'
      head = g.add_group
      prism(head.entities, -spec['head'], 0.0, spec['head_af'] / Math.sqrt(3.0), 6, m)
      shank = g.add_group
      prism(shank.entities, 0.0, spec['length'], spec['dia'] / 2.0, 20, m)
      [head, shank].each(&:explode)
    when 'plug'
      cap = g.add_group
      prism(cap.entities, -spec['cap'], 0.0, spec['cap_dia'] / 2.0, 24, m)
      stem = g.add_group
      prism(stem.entities, 0.0, spec['stem'], spec['stem_dia'] / 2.0, 16, m)
      [cap, stem].each(&:explode)
    when 'shim'
      l, w, t = spec['len'], spec['width'], spec['thick']
      tip = 1.0 / 32.0
      prof = [[0, 0, 0], [l, 0, 0], [l, 0, tip], [0, 0, t]].map { |p| Geom::Point3d.new(*p) }
      f = g.add_face(prof)
      f.pushpull(f.normal.y < 0 ? w : -w)
      g.grep(Sketchup::Face).each { |fc| fc.material = m; fc.back_material = m }
    when 'flat'
      l, w, t = spec['len'], spec['width'], spec['thick']
      f = g.add_face([0, 0, 0], [l, 0, 0], [l, w, 0], [0, w, 0])
      f.pushpull(f.normal.z < 0 ? -t : t)
      g.grep(Sketchup::Face).each { |fc| fc.material = m; fc.back_material = m }
    end
  end

  def self.run(opts = {})
    out = (opts['out'] || OUT).to_s
    raise "refusing to write outside _generated: #{out}" unless out.tr('\\', '/') =~ %r{/AssemblyCloseups/_generated\z}i
    FileUtils.mkdir_p(out)
    model = Sketchup.active_model
    only = opts['only'] ? Array(opts['only']) : nil
    rows = []
    model.start_operation('WR generate close-up stand-ins', true)
    begin
      PARTS.each do |spec|
        next if only && !only.include?(spec['name'])
        nm = "GEN #{spec['name']}"
        d = model.definitions.add(nm)
        build(d, spec, mat(model, spec['mat']))
        path = File.join(out, "#{nm}.skp")
        ok = d.save_as(path)
        b = d.bounds
        rows << { 'file' => path, 'name' => nm, 'saved' => ok,
                  'size_in' => [b.width, b.height, b.depth].map { |v| v.to_f.round(3) },
                  'faces' => d.entities.grep(Sketchup::Face).length, 'spec' => spec }
      end
    ensure
      model.abort_operation
    end
    File.open(File.join(out, '_generated.json'), 'w:UTF-8') do |f|
      f.write(JSON.pretty_generate('note' => 'Written by scripts/am-closeup-genparts.rb. Stand-ins, not library parts.',
                                   'parts' => rows))
    end
    rows.map { |r| [r['name'], r['saved'], r['size_in'], r['faces']] }
  end
end
