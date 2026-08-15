# @title Find and Replace Names...
# @cat Tidy up the model
#
# Find-and-replace across scene names, component definition names, tag names or
# material names. Built for the job of cleaning up a naming scheme after the
# fact — turning every " (2)" into "_HX", stripping a prefix off two hundred
# scenes, fixing a typo that got copied everywhere.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/find-replace-names.rb"
#
# THIS ONE CHANGES THE MODEL. Everything else in this folder either reads or
# writes files; this renames things inside the file you have open. So:
#
#   * It runs a PREVIEW FIRST by default. Nothing is renamed until you set
#     "Preview only" to No and confirm a second dialog that states the count.
#   * The whole rename is ONE undo step. Ctrl+Z puts every name back.
#   * It REFUSES to run if the result would collide. SketchUp silently appends
#     " (2)" when two scenes end up with the same name, which is exactly the
#     mess this script exists to clean up — so a rename that would create one is
#     reported and the whole run is abandoned rather than half-applied.

require 'sketchup.rb'

module WR_FindReplace
  PREF = 'WR_FindReplace'.freeze

  DEFAULTS = {
    'find'  => '',
    'repl'  => '',
    'scope' => 'Scene names',
    'mode'  => 'Plain text',
    'case'  => 'Yes',
    'dry'   => 'Yes'
  }.freeze

  SCOPES = ['Scene names', 'Component definition names', 'Tag (layer) names',
            'Material names'].freeze

  # ------------------------------------------------------------------- input --

  def self.ask
    keys = %w[find repl scope mode case dry]
    prompts = ['Find',
               'Replace with — leave blank to delete it',
               'Where',
               'Match as',
               'Match case',
               'Preview only — change nothing']
    defaults = keys.map do |k|
      v = read_pref(k)
      v.empty? ? DEFAULTS[k] : v
    end
    lists = ['', '', SCOPES.join('|'), 'Plain text|Regular expression', 'Yes|No', 'Yes|No']
    res = UI.inputbox(prompts, defaults, lists, 'Find and Replace Names')
    return nil unless res

    cfg = {}
    keys.each_with_index { |k, i| cfg[k] = res[i].to_s }
    cfg['find'] = cfg['find'].to_s        # NOT stripped — leading and trailing
    cfg['repl'] = cfg['repl'].to_s        # spaces are usually the whole point
    if cfg['find'].empty?
      UI.messagebox("Nothing to find.\n\nType the text to search for.")
      return nil
    end
    keys.each { |k| write_pref(k, cfg[k]) }
    cfg
  end

  # read_default EVALS the stored string and write_default does not escape quotes
  # inside it, so a stored value containing a quote comes back as a SyntaxError —
  # which is not a StandardError and escapes an ordinary rescue. A find/replace
  # box is exactly where someone types a quote, so this matters here.
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

  # ------------------------------------------------------------------ matching --

  def self.pattern(cfg)
    src = cfg['mode'].to_s.start_with?('Regular') ? cfg['find'] : Regexp.escape(cfg['find'])
    flags = cfg['case'] == 'Yes' ? 0 : Regexp::IGNORECASE
    Regexp.new(src, flags)
  end

  # Plain text goes through the BLOCK form of gsub so that a replacement
  # containing \1 or \\ is inserted literally. Regular-expression mode uses the
  # string form, where \1 is a backreference on purpose.
  def self.apply_to(name, re, cfg)
    if cfg['mode'].to_s.start_with?('Regular')
      name.gsub(re, cfg['repl'])
    else
      repl = cfg['repl']
      name.gsub(re) { repl }
    end
  end

  # ------------------------------------------------------------------- targets --
  #
  # Each scope returns [object, current_name, setter]. Keeping the setter with
  # the object means the apply loop does not care what kind of thing it is.
  def self.targets(model, scope)
    case scope
    when 'Component definition names'
      model.definitions.reject(&:image?).map do |d|
        [d, d.name.to_s, lambda { |n| d.name = n }]
      end
    when 'Tag (layer) names'
      model.layers.map { |l| [l, l.name.to_s, lambda { |n| l.name = n }] }
    when 'Material names'
      model.materials.map { |m| [m, m.name.to_s, lambda { |n| m.name = n }] }
    else
      model.pages.to_a.map { |p| [p, p.name.to_s, lambda { |n| p.name = n }] }
    end
  end

  # -------------------------------------------------------------------- run --

  def self.run
    model = Sketchup.active_model
    if model.nil?
      UI.messagebox('No model is open.')
      return
    end

    cfg = ask
    return if cfg.nil?

    scope = SCOPES.include?(cfg['scope']) ? cfg['scope'] : 'Scene names'
    dry   = cfg['dry'] == 'Yes'

    begin
      re = pattern(cfg)
    rescue RegexpError => e
      UI.messagebox("That is not a valid regular expression:\n\n#{e.message}")
      return
    end

    all = targets(model, scope)
    if all.empty?
      UI.messagebox("This model has no #{scope.downcase}.")
      return
    end

    changes = []
    all.each do |obj, name, setter|
      nn = apply_to(name, re, cfg)
      next if nn == name
      changes << { :obj => obj, :old => name, :new => nn, :set => setter }
    end

    puts ''
    puts '=' * 74
    puts "FIND AND REPLACE — #{scope}#{dry ? '   (PREVIEW, nothing changed)' : ''}"
    puts "  find      #{cfg['find'].inspect}   (#{cfg['mode']}, #{cfg['case'] == 'Yes' ? 'case sensitive' : 'any case'})"
    puts "  replace   #{cfg['repl'].inspect}"
    puts "  scanned   #{all.length}"
    puts "  matching  #{changes.length}"
    puts '=' * 74

    if changes.empty?
      UI.messagebox("Nothing matched.\n\n#{all.length} #{scope.downcase} scanned, " \
                    "none contain #{cfg['find'].inspect}.")
      return
    end

    # ---- collisions. SketchUp will happily let two things end up with the same
    # name and quietly disambiguate, which is how " (2)" gets into a model in the
    # first place. Refuse the whole run rather than create more of them.
    untouched = {}
    all.each do |_o, name, _s|
      untouched[name.downcase] = name
    end
    changes.each { |c| untouched.delete(c[:old].downcase) }

    seen = {}
    clashes = []
    changes.each do |c|
      k = c[:new].downcase
      if untouched.key?(k)
        clashes << "#{c[:old].inspect} -> #{c[:new].inspect}  collides with an existing #{untouched[k].inspect}"
      elsif seen.key?(k)
        clashes << "#{c[:old].inspect} -> #{c[:new].inspect}  collides with #{seen[k].inspect}"
      else
        seen[k] = c[:old]
      end
    end

    wo = [changes.map { |c| c[:old].length }.max || 3, 3].max
    puts ''
    puts format("  %-#{wo}s     %s", 'FROM', 'TO')
    puts '  ' + '-' * (wo + 5 + 30)
    changes.each { |c| puts format("  %-#{wo}s  -> %s", c[:old], c[:new]) }

    unless clashes.empty?
      puts ''
      puts "  *** #{clashes.length} COLLISION(S). Nothing has been changed."
      clashes.each { |c| puts "      #{c}" }
      puts ''
      UI.messagebox("#{clashes.length} of these renames would collide with another " \
                    "name.\n\nNothing has been changed. The full list is in the Ruby " \
                    "Console.\n\nSketchUp would silently append \" (2)\" to resolve " \
                    'them, which is the problem this script is for — so it refuses ' \
                    'instead.')
      return
    end

    if dry
      puts ''
      puts "  PREVIEW — nothing changed. #{changes.length} would be renamed."
      puts '  Set "Preview only" to No to apply.'
      puts ''
      UI.messagebox("Preview: #{changes.length} of #{all.length} #{scope.downcase} " \
                    "would be renamed.\n\nThe full list is in the Ruby Console. " \
                    "Set \"Preview only\" to No to apply it.")
      return
    end

    ok = UI.messagebox("Rename #{changes.length} #{scope.downcase}?\n\n" \
                       "#{changes.first[:old]}  ->  #{changes.first[:new]}\n" \
                       "#{changes.length > 1 ? "...and #{changes.length - 1} more.\n" : ''}" \
                       "\nThis is one undo step — Ctrl+Z puts them all back.", MB_OKCANCEL)
    if ok != IDOK
      puts '  cancelled — nothing changed.'
      return
    end

    # One operation so the whole rename is a single Ctrl+Z. The `true` suppresses
    # the UI refresh per change, which matters at a few hundred scenes.
    done = 0
    failed = []
    model.start_operation('Find and Replace Names', true)
    begin
      changes.each do |c|
        begin
          c[:set].call(c[:new])
          done += 1
        rescue StandardError => e
          failed << "#{c[:old]}: #{e.class}: #{e.message}"
        end
      end
      model.commit_operation
    rescue Exception => e
      model.abort_operation
      raise e
    end

    puts ''
    puts "  renamed #{done} of #{changes.length}"
    failed.each { |f| puts "  FAILED  #{f}" }
    puts '  Ctrl+Z undoes the whole run.'
    puts ''
    UI.messagebox("Renamed #{done} #{scope.downcase}." \
                  "#{failed.empty? ? '' : "\n\n#{failed.length} failed — see the Ruby Console."}" \
                  "\n\nCtrl+Z undoes the whole run.")
    nil
  end
end

begin
  WR_FindReplace.run
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(12).map { |l| "  #{l}" }.join("\n")
  UI.messagebox("Find and Replace failed:\n\n#{e.class}: #{e.message}\n\n" \
                'Full backtrace is in the Ruby Console.')
end
