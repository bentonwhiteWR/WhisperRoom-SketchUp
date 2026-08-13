# @title Merge Materials...
# @cat Model tools
#
# Point every face, edge, group and instance that uses one material at another
# one, then delete the emptied material. One material to edit instead of five.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/merge-materials.rb"
#
# WHY THIS EXISTS
#
# The master component list is a few hundred parts that all shared one fabric
# material, so lightening the fabric was a single edit. Then a batch of new
# components came in carrying their own copy of the ORIGINAL material. Now there
# are two, they look different, and every future colour change has to be made
# twice — or three times, or five, as more imports land.
#
# THE NAME YOU EXPECT IS PROBABLY NOT THE NAME THAT ARRIVED. When SketchUp
# imports a component whose material shares a name with an existing one but
# differs in any way, it does NOT reuse yours — it brings its own in under a
# uniquified name: "Carpet Plush Charcoal 1", "Carpet Plush Charcoal #2",
# "Carpet Plush Charcoal(2)". Which suffix depends on the version and on how the
# file was made. So:
#
#   - the FROM field takes a COMMA-SEPARATED LIST and understands * as a
#     wildcard, so "Carpet Plush Charcoal*" catches the whole family at once;
#   - a dry run prints EVERY material in the model with a live use count, which
#     is the only reliable way to find out what the imports actually brought in.
#
# Run it dry first and read that table. It is the point of the dry run.
#
# WHERE MATERIALS HIDE
#
# A material is not only on top-level faces. It can sit on:
#
#   - a face's FRONT and its BACK, independently — a back face painted with the
#     old material is invisible from outside and survives a careless merge;
#   - edges;
#   - a ComponentInstance or Group, which paints every face inside it that is
#     itself unpainted — miss these and a part keeps the old colour with no
#     painted face anywhere to explain why;
#   - geometry nested at any depth inside a component definition.
#
# The walk covers all of it by iterating model.entities AND every definition's
# entities. Every group and component's geometry lives in some definition, so
# that reaches everything at any depth without recursing.
#
# SAFETY. One operation, so a single Ctrl+Z puts the whole merge back — the
# material assignments and the deletions together. Defaults to a dry run.

require 'sketchup.rb'

module WR_MergeMaterials
  PREF = 'WR_MergeMaterials'.freeze

  DEFAULTS = {
    'from' => 'Carpet Plush Charcoal*',
    'to'   => 'Darker Charcoal For Claude',
    'del'  => 'Yes',
    'dry'  => 'Yes'
  }.freeze

  # read_default EVALS the stored string and write_default does not escape quotes
  # inside it, so a quote comes back as a SyntaxError — which is a ScriptError,
  # not a StandardError, and escapes a plain rescue. Same trap that took wr_tools
  # down at load. Strip going in, rescue Exception coming out.
  def self.read_pref(k)
    Sketchup.read_default(PREF, k, DEFAULTS[k].to_s).to_s
  rescue Exception
    DEFAULTS[k].to_s
  end

  def self.write_pref(k, v)
    Sketchup.write_default(PREF, k, v.to_s.delete('"'))
  rescue Exception
    nil
  end

  def self.ask
    keys = %w[from to del dry]
    prompts = ['Merge FROM — outdated material(s), comma separated, * allowed',
               'Merge INTO — the material to keep',
               'Delete the emptied materials afterwards',
               'Dry run — count only, change nothing']
    defaults = keys.map do |k|
      v = read_pref(k)
      v.empty? ? DEFAULTS[k] : v
    end
    lists = ['', '', 'Yes|No', 'Yes|No']
    res = UI.inputbox(prompts, defaults, lists, 'Merge Materials')
    return nil unless res
    cfg = {}
    keys.each_with_index { |k, i| cfg[k] = res[i].to_s.strip }
    return nil if cfg['to'].empty?
    keys.each { |k| write_pref(k, cfg[k]) }
    cfg
  end

  # ----------------------------------------------------------------- matching --

  # "Carpet Plush Charcoal*" -> /\ACarpet\ Plush\ Charcoal.*\z/i
  # Everything except * is escaped, so brackets and # in a real material name
  # cannot turn into regex syntax and match something unintended.
  def self.pattern(spec)
    parts = spec.to_s.split('*', -1).map { |p| Regexp.escape(p) }
    Regexp.new('\A' + parts.join('.*') + '\z', Regexp::IGNORECASE)
  end

  def self.patterns(spec)
    spec.to_s.split(',').map(&:strip).reject(&:empty?).map { |s| pattern(s) }
  end

  def self.matching(model, spec, exclude_name)
    pats = patterns(spec)
    return [] if pats.empty?
    model.materials.select { |m|
      n = m.name.to_s
      n != exclude_name && pats.any? { |p| p =~ n }
    }
  end

  # ------------------------------------------------------------------- walking --

  # Every place a material can be referenced, counted in one pass. Passing a nil
  # target counts without changing anything, which is what the dry run and the
  # after-the-fact verification both need.
  #
  # Materials are keyed by NAME. Names are unique per model, and a name survives
  # the round trip through an entity's material getter, where object identity has
  # been known not to.
  def self.walk(model, names, target, tally)
    lists = [model.entities]
    model.definitions.each { |d| lists << d.entities unless d.image? }

    lists.each do |ents|
      ents.each do |e|
        begin
          if e.respond_to?(:material)
            m = e.material
            if m && names.include?(m.name.to_s)
              tally[kind_of(e)] = tally.fetch(kind_of(e), 0) + 1
              e.material = target if target
            end
          end
          # A face's back is a separate assignment. A back painted with the old
          # material is invisible from outside and would survive a merge that
          # only looked at #material — and then reappear the first time someone
          # reverses a face.
          if e.is_a?(Sketchup::Face)
            b = e.back_material
            if b && names.include?(b.name.to_s)
              tally[:back] = tally.fetch(:back, 0) + 1
              e.back_material = target if target
            end
          end
        rescue Exception
          tally[:errors] = tally.fetch(:errors, 0) + 1
        end
      end
    end
    tally
  end

  def self.kind_of(e)
    case e
    when Sketchup::Face              then :face
    when Sketchup::Edge              then :edge
    when Sketchup::ComponentInstance then :instance
    when Sketchup::Group             then :group
    else :other
    end
  end

  # Use count for EVERY material, so the dry run can show what is actually in
  # the model rather than what someone remembers naming it.
  def self.census(model)
    counts = Hash.new(0)
    lists = [model.entities]
    model.definitions.each { |d| lists << d.entities unless d.image? }
    lists.each do |ents|
      ents.each do |e|
        begin
          m = (e.material if e.respond_to?(:material))
          counts[m.name.to_s] += 1 if m
          if e.is_a?(Sketchup::Face)
            b = e.back_material
            counts[b.name.to_s] += 1 if b
          end
        rescue Exception
          nil
        end
      end
    end
    counts
  end

  # ---------------------------------------------------------------------- run --

  def self.run
    model = Sketchup.active_model
    if model.nil?
      UI.messagebox('No model is open.')
      return
    end

    cfg = ask
    return if cfg.nil?
    dry = cfg['dry'].to_s.downcase.start_with?('y')
    del = cfg['del'].to_s.downcase.start_with?('y')

    keeper  = model.materials.find { |m| m.name.to_s == cfg['to'] }
    counts  = census(model)
    victims = matching(model, cfg['from'], cfg['to'])
    doomed  = victims.map { |m| m.name.to_s }

    puts ''
    puts '=' * 78
    puts "MERGE MATERIALS#{dry ? '  —  DRY RUN, nothing will be changed' : ''}"
    puts "  model    #{model.title.to_s.empty? ? '(unsaved)' : model.title}"
    puts "  from     #{cfg['from']}"
    puts "  into     #{cfg['to']}#{keeper ? '' : '   *** NOT IN THIS MODEL'}"
    puts '=' * 78
    puts ''
    puts '  EVERY MATERIAL IN THIS MODEL, by how many things use it:'
    puts format('    %-46s %8s', 'MATERIAL', 'USES')
    puts '    ' + '-' * 56
    model.materials.sort_by { |m| [-counts[m.name.to_s], m.name.to_s] }.each do |m|
      n = m.name.to_s
      mark = if n == cfg['to'] then ' <- KEEP'
             elsif doomed.include?(n) then ' <- MERGE'
             else ''
             end
      puts format('    %-46s %8d%s', n, counts[n], mark)
    end
    puts ''

    if keeper.nil?
      puts "  *** \"#{cfg['to']}\" is not a material in this model. Nothing done."
      puts '  *** Copy the name exactly from the table above.'
      puts ''
      UI.messagebox("\"#{cfg['to']}\" is not a material in this model.\n\n" \
                    'The Ruby Console lists every material there is — copy the name from there.')
      return
    end

    if victims.empty?
      puts "  Nothing matches \"#{cfg['from']}\". Nothing done."
      puts '  Check the table above — an imported material is often renamed by'
      puts '  SketchUp, so the name you expect may carry a suffix.'
      puts ''
      UI.messagebox("Nothing matches \"#{cfg['from']}\".\n\n" \
                    'See the Ruby Console for every material in this model.')
      return
    end

    names = doomed
    puts "  MERGING #{victims.length} material(s) into \"#{cfg['to']}\":"
    names.each { |n| puts format('    %-46s %d use(s)', n, counts[n]) }
    puts ''

    if dry
      tally = walk(model, names, nil, {})
      report_tally(tally, 'would change')
      puts ''
      puts '  DRY RUN — nothing was changed. Set Dry run to No to do it.'
      puts ''
      UI.messagebox("Dry run: #{victims.length} material(s), #{total(tally)} " \
                    "assignment(s) would move to \"#{cfg['to']}\".\n\nSee the Ruby Console.")
      return
    end

    # One operation covering the reassignments AND the deletions, so Ctrl+Z is a
    # single keystroke and cannot leave the model half-merged.
    model.start_operation('Merge Materials', true)
    begin
      tally = walk(model, names, keeper, {})

      # The current paint-bucket material is a reference too, and pointing at a
      # material about to be deleted is a good way to crash a later click.
      begin
        cur = model.materials.current
        model.materials.current = keeper if cur && names.include?(cur.name.to_s)
      rescue Exception
        nil
      end

      removed = []
      stuck   = []
      if del
        victims.each do |m|
          begin
            model.materials.remove(m)
            removed << m.name.to_s
          rescue Exception => e
            stuck << "#{m.name}: #{e.class}: #{e.message.to_s.split("\n").first}"
          end
        end
      end
      model.commit_operation
    rescue Exception => e
      model.abort_operation
      puts "FAILED: #{e.class}: #{e.message}"
      puts e.backtrace.first(8).map { |l| "  #{l}" }.join("\n")
      UI.messagebox("Merge failed and was rolled back:\n\n#{e.class}: #{e.message}")
      return
    end

    report_tally(tally, 'changed')

    # Verify by re-counting rather than trusting the tally. If anything still
    # references an old material, the merge missed a place materials can hide
    # and that is worth knowing immediately, not at the next colour change.
    left = total(walk(model, names, nil, {}))
    puts ''
    if left.zero?
      puts '  VERIFIED — nothing in the model still uses the merged material(s).'
    else
      puts "  *** #{left} reference(s) SURVIVE. The walk missed somewhere."
      puts '  *** Ctrl+Z and tell Claude, do not paint over it.'
    end

    if del
      puts "  deleted  #{removed.join(', ')}" unless removed.empty?
      unless stuck.empty?
        puts '  COULD NOT DELETE:'
        stuck.each { |s| puts "    #{s}" }
        puts '  -> try Window > Model Info > Statistics > Purge Unused.'
      end
    else
      puts '  kept the emptied material(s) — they now have 0 uses and will'
      puts '  disappear at the next Purge Unused.'
    end

    puts ''
    UI.messagebox("Merged into \"#{cfg['to']}\".\n\n" \
                  "#{total(tally)} assignment(s) moved" \
                  "#{left.zero? ? ', verified clean' : ", #{left} SURVIVED — see the console"}.\n\n" \
                  'Ctrl+Z undoes the whole thing.')
  end

  # Errors are counted but are not assignments, so they never join the total.
  def self.total(t)
    t.reject { |k, _v| k == :errors }.values.reduce(0, :+)
  end

  def self.report_tally(t, verb)
    puts "  #{verb}:"
    [[:face, 'face fronts'], [:back, 'face backs'], [:edge, 'edges'],
     [:instance, 'component instances'], [:group, 'groups'],
     [:other, 'other entities']].each do |k, label|
      puts format('    %-24s %d', label, t[k]) if t[k].to_i.positive?
    end
    puts format('    %-24s %d', 'TOTAL', total(t))
    puts format('    %-24s %d  (entities that refused to repaint)', 'errors', t[:errors]) if t[:errors].to_i.positive?
  end
end

begin
  WR_MergeMaterials.run
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(12).map { |l| "  #{l}" }.join("\n")
  UI.messagebox("Merge Materials failed:\n\n#{e.class}: #{e.message}\n\n" \
                'Full backtrace is in the Ruby Console.')
end
