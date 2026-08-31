# @title Swap draft / render materials...
# @cat V-Ray renders
# @rank 3
#
# The ONE place that knows how a drafting material and a render material trade
# places. wr-mode.rb calls this for the materials half of Draft <-> Render; it
# is also a small panel command in its own right for fixing one job's fills or
# swapping without touching tags, style or shadows.
#
# WHY BY NAME, NOT BY OBJECT
#
# Holding a Sketchup::Material reference across a save is a trap — merge two
# models, purge unused materials, or just close and reopen, and the object you
# held is gone even though a material with the same name still exists. Every
# lookup here goes through a NAME, the same way build-room.rb's own
# floor/wall/door materials are named constants rather than cached objects.
#
# NAMED SLOTS, FILLED PER JOB
#
# There are three drafting materials in this shop (CLAUDE.md): the floor
# (0128_White), the walls (0099_LightSteelBlue) and the door leaf
# (0043_SaddleBrown). Those are the DEFAULT source of each slot, not a fixed
# one -- a model that did not come out of build-room.rb still has a floor,
# but it is not called 0128_White, and each slot's source is therefore
# per-model and pickable from the model's own materials (see `source`). Each
# maps to a RENDER SLOT — WR-Floor-Render,
# WR-Wall-Render, WR-Door-Render — that starts empty. This script does not
# know or care what V-Ray material fills a slot; the operator imports whatever
# real material the client's room needs and points the slot at it by name.
# That is the whole reason slots exist instead of one hard-coded render
# material per drafting material: two jobs never share a floor finish, but
# every job still has exactly one thing called "the floor."
#
# The fill for each slot is stored PER MODEL, in an attribute dictionary, so
# it survives a save and a reopen. Re-run this script on the same model next
# week and it remembers what was filling WR-Floor-Render.
#
# ATOMIC APPLY AND REVERT
#
# Both directions run inside one start_operation/commit_operation. If
# something raises partway through the sweep, the operation is aborted rather
# than committed, so a crash mid-swap cannot leave some surfaces on render
# materials and others still drafting with no way back in one Ctrl+Z. This is
# NOT the same thing as "every mappable surface must map or nothing happens" —
# a slot with no fill yet is an expected, everyday state, not an error to
# abort over. It is reported instead. See below.
#
# THE PART THAT EARNS ITS KEEP
#
# A surface that WOULD be on a render material but has no fill configured for
# its slot — or a fill that no longer exists in this model — is named
# explicitly in the result, not left silently drafting. Nothing here is
# allowed to fail quietly into "still the wrong colour and nobody said so."
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/wr-materials-swap.rb"
#
# THIS FILE HAS NOT BEEN RUN. There is no ruby.exe on this machine outside
# SketchUp itself, so nothing here has executed — it has only been parsed with
# scripts/rbparse.py, which is a real syntax check but not a behaviour check.

require 'sketchup.rb'

module WR_MaterialsSwap
  %w[DICT SRC_PREFIX DRAFT_FLOOR DRAFT_WALL DRAFT_DOOR SLOT_FOR DRAFT_FOR
     DRAFT_RGB].each do |c|
    remove_const(c) if const_defined?(c, false)
  end

  DICT = 'WR_MaterialsSwap'.freeze

  # Per-model SOURCE override, stored in the same dictionary as the fills under
  # a prefixed key so one dictionary still holds the whole mapping.
  SRC_PREFIX = 'src:'.freeze

  # The house drafting materials — CLAUDE.md and build-room.rb's own MAT_*
  # constants. Kept as plain strings here on purpose: this file must never
  # need build-room.rb loaded to know what "the floor material" is called.
  DRAFT_FLOOR = '0128_White'.freeze
  DRAFT_WALL  = '0099_LightSteelBlue'.freeze
  DRAFT_DOOR  = '0043_SaddleBrown'.freeze

  DRAFT_RGB = { DRAFT_FLOOR => [255, 255, 255],
                DRAFT_WALL  => [176, 196, 222],
                DRAFT_DOOR  => [139, 69, 19] }.freeze

  # Drafting material name -> the render slot it swaps into. One line per
  # material; every lookup in this file goes through this table so adding a
  # fourth drafting material later is a one-line change.
  SLOT_FOR = { DRAFT_FLOOR => 'WR-Floor-Render',
               DRAFT_WALL  => 'WR-Wall-Render',
               DRAFT_DOOR  => 'WR-Door-Render' }.freeze

  # Slot name -> drafting name, the reverse lookup revert needs.
  DRAFT_FOR = SLOT_FOR.invert.freeze

  # ------------------------------------------------------------- materials --

  # Same loader build-room.rb uses: pull the real .skm from SketchUp's
  # Colors-Named library if the model doesn't already have the material, and
  # fall back to a flat RGB swatch if the library isn't on this machine.
  # Duplicated here rather than shared, because build-room.rb belongs to a
  # different builder right now and this file must stand alone.
  def self.drafting_material(model, name)
    m = model.materials[name]
    return m if m
    pd = (ENV['ProgramData'] || 'C:/ProgramData').tr('\\', '/')
    %w[2026 2025 2024 2023].each do |v|
      path = File.join(pd, 'SketchUp', "SketchUp #{v}", 'SketchUp', 'Materials',
                       'Colors-Named', "#{name}.skm")
      next unless File.exist?(path)
      begin
        loaded = model.materials.load(path)
        return loaded if loaded
      rescue StandardError
        nil
      end
    end
    m = model.materials.add(name)
    m.color = Sketchup::Color.new(*(DRAFT_RGB[name] || [200, 200, 200]))
    m
  end

  # --------------------------------------------------------------- storage --

  def self.fill(model, slot)
    d = model.attribute_dictionary(DICT)
    d ? d[slot].to_s : ''
  rescue StandardError
    ''
  end

  def self.set_fill(model, slot, name)
    # Sketchup::AttributeDictionaries has NO #add — set_attribute creates the
    # dictionary on demand and is what the rest of this toolset uses.
    model.set_attribute(DICT, slot, name.to_s.strip)
  end

  def self.fills(model)
    SLOT_FOR.values.each_with_object({}) { |s, h| h[s] = fill(model, s) }
  end

  # ----------------------------------------------------------- sources --
  #
  # WHICH MATERIAL EACH SLOT SWAPS *FROM*, PER MODEL.
  #
  # The three house drafting materials above are the DEFAULTS, not the law. A
  # model that did not come out of build-room.rb -- a client's own file, an
  # imported booth, a room someone painted by hand -- has a floor, walls and a
  # door like any other, but they are not called 0128_White. Before this was
  # configurable the sweep simply found nothing in such a model and said so,
  # which was honest and useless: there was no way to point it at the right
  # material without editing this file.
  #
  # So each slot's SOURCE is stored per model, exactly like its fill, and
  # falls back to the house name when unset. Set it in the Proposal Package
  # window or in this script's own panel -- both write the same dictionary.

  def self.source(model, slot)
    d = model.attribute_dictionary(DICT)
    v = d ? d[SRC_PREFIX + slot].to_s.strip : ''
    v.empty? ? DRAFT_FOR[slot].to_s : v
  rescue StandardError
    DRAFT_FOR[slot].to_s
  end

  def self.set_source(model, slot, name)
    # '' clears the override and restores the house default -- storing the
    # house name itself would look identical but would silently pin the slot
    # if the default ever changed.
    n = name.to_s.strip
    n = '' if n == DRAFT_FOR[slot].to_s
    model.set_attribute(DICT, SRC_PREFIX + slot, n)
  end

  def self.sources(model)
    SLOT_FOR.values.each_with_object({}) { |s, h| h[s] = source(model, s) }
  end

  # source name -> slot, this model's live replacement for SLOT_FOR.
  #
  # Two slots CAN be pointed at the same material, and that is not a mapping
  # -- a surface on it has two possible destinations and no way to choose. The
  # conflicting name is left OUT of the map and returned separately so the
  # sweep can name it rather than quietly letting the last slot win.
  def self.slot_for(model)
    map = {}
    dupes = {}
    SLOT_FOR.values.each do |slot|
      src = source(model, slot)
      next if src.empty?
      if dupes.key?(src)
        dupes[src] << slot
      elsif map.key?(src)
        dupes[src] = [map.delete(src), slot]
      else
        map[src] = slot
      end
    end
    [map, dupes]
  end

  # ----------------------------------------------------------------- walk --

  # Any entity that carries an explicit material and whose material's NAME is
  # in `names`. Groups and component instances are checked as themselves (a
  # painted group, build-room.rb's own pattern) as well as walked into, so a
  # face painted directly is found too.
  def self.walk(ents, names, out, chain, depth)
    return if depth > 8
    ents.each do |e|
      if e.respond_to?(:material)
        m = (e.material rescue nil)
        out << [e, chain + [e]] if m && names.include?(m.name)
      end
      case e
      when Sketchup::Group
        walk(e.entities, names, out, chain + [e], depth + 1)
      when Sketchup::ComponentInstance
        walk(e.definition.entities, names, out, chain + [e], depth + 1)
      end
    end
  end

  def self.find(model, names)
    out = []
    walk(model.entities, names, out, [], 0)
    out
  end

  def self.describe(chain)
    chain.map do |e|
      n = ((e.name.to_s rescue '')).strip
      n = ((e.definition.name.to_s rescue '')).strip if n.empty? && e.is_a?(Sketchup::ComponentInstance)
      n.empty? ? e.class.to_s.sub('Sketchup::', '') : n
    end.join(' > ')
  end

  # --------------------------------------------------------------- to_render --

  # Draft -> render, for every surface currently on one of the three drafting
  # materials. A surface whose slot has no fill, or whose fill no longer
  # resolves to a material in this model, is left exactly where it was and
  # named in :unmapped — never silently left "swapped" when it wasn't.
  def self.to_render(model)
    result = { :applied => Hash.new(0), :unmapped => [] }
    map, dupes = slot_for(model)
    hits = find(model, map.keys + dupes.keys)
    model.start_operation('WR Materials: Draft -> Render', true)
    begin
      hits.each do |e, chain|
        draft_name = e.material.name
        if dupes.key?(draft_name)
          two = dupes[draft_name].join(' and ')
          result[:unmapped] << "#{describe(chain)}  (#{draft_name} is the source for " \
                               "#{two} — pick a different material for one of them)"
          next
        end
        slot = map[draft_name]
        fill_name = fill(model, slot)
        if fill_name.empty?
          result[:unmapped] << "#{describe(chain)}  (#{draft_name} -> #{slot}: no fill set)"
          next
        end
        mat = model.materials[fill_name]
        if mat.nil?
          result[:unmapped] << "#{describe(chain)}  (#{draft_name} -> #{slot}: fill " \
                               "#{fill_name.inspect} not found in this model)"
          next
        end
        e.material = mat
        result[:applied][slot] += 1
      end
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      raise e
    end
    result
  end

  # ---------------------------------------------------------------- to_draft --

  # Render -> draft. Only ever touches surfaces currently on a material that
  # is a CONFIGURED FILL for one of the three slots, so a surface painted with
  # some unrelated material (a client's V-Ray wallpaper on a feature wall, say)
  # is never mistaken for one of ours and dragged back to drafting blue.
  def self.to_draft(model)
    result = { :reverted => Hash.new(0), :left => [] }
    fillmap = fills(model)
    render_names = fillmap.values.reject(&:empty?)
    hits = find(model, render_names)
    model.start_operation('WR Materials: Render -> Draft', true)
    begin
      hits.each do |e, chain|
        cur = e.material.name
        slot = fillmap.key(cur)
        draft_name = slot ? source(model, slot) : nil
        draft_name = nil if draft_name.to_s.empty?
        if draft_name.nil?
          result[:left] << "#{describe(chain)}  (on #{cur.inspect}, no drafting material known for it)"
          next
        end
        e.material = drafting_material(model, draft_name)
        result[:reverted][slot] += 1
      end
      model.commit_operation
    rescue StandardError => e
      model.abort_operation
      raise e
    end
    result
  end

  # -------------------------------------------------------------- reporting --

  def self.report_lines(action, result)
    lines = ["MATERIALS — #{action}"]
    counts = result[:applied] || result[:reverted] || {}
    if counts.empty?
      lines << '  nothing on a matching material was found.'
    else
      counts.each { |slot, n| lines << "  #{slot}: #{n} surface(s)" }
    end
    problems = result[:unmapped] || result[:left] || []
    unless problems.empty?
      lines << "  *** #{problems.size} surface(s) NOT swapped:"
      problems.first(20).each { |s| lines << "        #{s}" }
      lines << "        ...and #{problems.size - 20} more (see console)" if problems.size > 20
    end
    lines
  end

  # ------------------------------------------------------------------ panel --

  # Two rows per slot: the material it swaps FROM (defaults to the house
  # drafting name, and the list is this model's own materials) and the render
  # material it swaps TO. The Proposal Package window writes the same two
  # values, so either surface can set them.
  def self.ask(model)
    mats = (model.materials.map(&:name).sort rescue [])
    fill_list = (['(unset)'] + mats).join('|')
    src_list  = mats.join('|')
    slots = SLOT_FOR.values
    prompts  = slots.flat_map { |s| ["#{s} from", "#{s} fill"] } + ['Direction']
    current  = slots.flat_map do |s|
      f = fill(model, s)
      [source(model, s), f.empty? ? '(unset)' : f]
    end
    lists    = slots.flat_map { [src_list, fill_list] } + ['Apply Render|Revert to Draft']
    defaults = current + ['Apply Render']
    UI.inputbox(prompts, defaults, lists, 'Materials — Draft / Render')
  end

  def self.run
    model = Sketchup.active_model
    res = ask(model)
    return unless res
    slots = SLOT_FOR.values
    slots.each_with_index do |s, i|
      set_source(model, s, res[i * 2].to_s)
      v = res[(i * 2) + 1].to_s
      set_fill(model, s, v == '(unset)' ? '' : v)
    end
    action = res.last.to_s
    result = action.start_with?('Revert') ? to_draft(model) : to_render(model)
    lines = report_lines(action, result)
    puts ''
    lines.each { |l| puts l }
    puts ''
    UI.messagebox(lines.join("\n"))
  rescue StandardError => e
    UI.messagebox("Materials swap failed:\n\n#{e.class}: #{e.message}")
    puts "FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(5)
  end
end

WR_MaterialsSwap.run unless $wr_no_autorun
