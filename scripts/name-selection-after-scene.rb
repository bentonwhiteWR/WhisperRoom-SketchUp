# @title Name Selection After Scene
# @cat Tidy up the model
# @rank 1
#
# Point at a part, get it named after the scene. Activate the scene, click the
# component, run this. That is the whole tool.
#
#   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/name-selection-after-scene.rb"
#
# WHY IT EXISTS. save-scene-components.rb resolves a scene to its component by
# EXACT definition-name match. A scene called "ENH 10242FL SIDE" whose part is
# still called "Component#41" is reported as a MODEL GAP and no file is written.
# Seventeen scenes are in that state. This is the button that clears them, one
# click at a time.
#
# DELIBERATELY DUMB. It renames THE THING YOU SELECTED to THE ACTIVE SCENE'S
# name. No raycast, no bounds, no nearest-component tier. Every guessing scheme
# tried in this project has at some point picked the wrong part and written a
# file under someone else's name. You point, it names. Nothing else.
#
# NOTHING IS INFERRED IN BULK. With nothing selected it will SHOW you the list
# of scenes that have no matching definition — the gap list — but it will never
# rename more than the one entity you selected. Working out which component
# belongs to which scene is exactly the inference that has corrupted output here
# twice, and it is not in this file.
#
# NAMES ARE READ BACK. ComponentDefinition#name= does not raise when the name is
# taken; the docs say plainly "if it's not [unique] the name will automatically
# be made unique". That silent uniquing is how "IEP floor (10218)#1" and
# "ENH 26.5Panel1648WDO_HX#2" got into this model. So the name is read back
# after assignment, and if the model handed back something other than what was
# asked for, THE WHOLE OPERATION IS ABORTED and the model is left untouched —
# a "#3" suffix is not a rename, it is a second copy of the same problem. Free
# the name first, then run this again.
#
# GROUPS. Group#definition exists (SU2015+) and save-scene-components.rb indexes
# groups alongside components, so the load-bearing rename for a group is its
# DEFINITION name — that is the string the exporter matches. But a group's
# definition name is not what Entity Info shows; that is the group's INSTANCE
# name. So for a group this sets both, to the same string: the definition
# because the exporter reads it, the instance so the change is visible where
# Benton will look for it. Component instances are left alone — an instance name
# on a component is a separate, meaningful field and is not ours to overwrite.
#
# ONE UNDO STEP. Ctrl+Z reverses the rename.
#
# QUIET WHEN IT WORKS. Success prints one line to the Ruby Console and puts the
# same line in the status bar. Only things needing attention — refusals, a taken
# name, a nested selection — open a dialog. That is on purpose: this gets
# clicked seventeen times in a row.

module WR_NameAfterScene

  TITLE = 'Name Selection After Scene'.freeze

  # SketchUp's own placeholder names. Treated as "no name" for the gap report,
  # the same way save-scene-components.rb treats them.
  AUTONAME = /\A(Component|Group)#\d+\z/.freeze

  # "(LeftWADoorWithRamp)" -> "LeftWADoorWithRamp". Only unwrap when the WHOLE
  # name is wrapped. Same rule as save-scene-components.rb, and it has to stay
  # the same rule or this tool will write names that exporter cannot match.
  def self.scene_label(page)
    n = page.name.to_s.strip
    if n.start_with?('(') && n.end_with?(')') && n.index(')') == n.length - 1
      n = n[1..-2].to_s.strip
    end
    n
  end

  def self.definition_of(ent)
    ent.definition
  rescue Exception
    nil
  end

  def self.definition_name(defn)
    n = (defn.name.to_s.strip rescue '')
    n =~ AUTONAME ? '' : n
  end

  # Lifted from save-scene-components.rb#rename_to, and it must stay lifted:
  # the reason it reads the name back is the reason this whole script exists.
  # Returns [name_now, warning_or_nil].
  def self.rename_to(defn, want)
    was = defn.name.to_s
    return [was, nil] if was == want
    begin
      defn.name = want
    rescue Exception => e
      return [was, "rename failed: #{e.class}: #{e.message.to_s.split("\n").first}"]
    end
    got = defn.name.to_s
    return [got, nil] if got == want
    [got, "NAME TAKEN — wanted \"#{want}\", model gave \"#{got}\""]
  end

  # Definition names of everything at the TOP LEVEL of the model. That is the
  # only place save-scene-components.rb looks, so it is the only place that
  # counts for the gap report.
  def self.top_level_names(model)
    names = {}
    model.entities.each do |e|
      next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
      defn = definition_of(e)
      next if defn.nil?
      n = definition_name(defn)
      names[n] = true unless n.empty?
    end
    names
  end

  # Is this entity at the top level of the model? A part renamed while still
  # nested inside a group keeps its new name but stays invisible to the
  # exporter, which is a confusing round trip worth warning about.
  def self.top_level?(model, ent)
    model.entities.include?(ent)
  rescue Exception
    true
  end

  # Every scene whose label matches no top-level definition name. READ ONLY.
  def self.gaps(model)
    have = top_level_names(model)
    out  = []
    model.pages.each_with_index do |pg, i|
      label = scene_label(pg)
      next if label.empty?
      out << [i + 1, label] unless have.key?(label)
    end
    out
  end

  def self.show_gaps(model, lead)
    list = gaps(model)
    puts ''
    puts "#{TITLE} — scenes with no matching top-level definition: #{list.length}"
    list.each { |n, label| puts format('  %4d  %s', n, label) }
    puts ''
    if list.empty?
      UI.messagebox("#{lead}\n\nEvery scene name matches a top-level definition. " \
                    'Nothing left to name.')
    else
      shown = list.first(30).map { |n, label| "#{n}. #{label}" }.join("\n")
      more  = list.length > 30 ? "\n\n(+#{list.length - 30} more — full list in the Ruby Console.)" : ''
      UI.messagebox("#{lead}\n\n#{list.length} scene#{list.length == 1 ? '' : 's'} " \
                    "still have no component of that name:\n\n#{shown}#{more}\n\n" \
                    'Activate one of those scenes, click its part, and run this again.')
    end
    nil
  end

  def self.run
    model = Sketchup.active_model
    if model.nil?
      UI.messagebox('No model is open.')
      return nil
    end

    page = model.pages.selected_page
    if page.nil?
      UI.messagebox("No active scene.\n\n" \
                    'Click a scene tab first — this tool names the selected part after ' \
                    'whichever scene is active.')
      return nil
    end

    want = scene_label(page)
    if want.empty?
      UI.messagebox("The active scene has no usable name.")
      return nil
    end

    sel = model.selection

    # Nothing selected is not really an error — it is the moment to show what is
    # still outstanding. Read only; renames nothing.
    if sel.empty?
      return show_gaps(model, "Nothing is selected, so nothing was renamed.")
    end

    if sel.count > 1
      UI.messagebox("#{sel.count} things are selected.\n\n" \
                    'Select exactly one component or group. This tool renames one ' \
                    'definition and will not guess which of several you meant.')
      return nil
    end

    ent = sel.first
    unless ent.is_a?(Sketchup::ComponentInstance) || ent.is_a?(Sketchup::Group)
      UI.messagebox("A #{ent.class.name.split('::').last} is selected.\n\n" \
                    'Select a component instance or a group — those are the only things ' \
                    'with a definition to name.')
      return nil
    end

    defn = definition_of(ent)
    if defn.nil?
      UI.messagebox('That entity has no readable definition.')
      return nil
    end

    was = defn.name.to_s
    if was == want
      puts "#{TITLE}: already named \"#{want}\" — nothing changed."
      UI.messagebox("Already named that.\n\n\"#{want}\"\n\nNothing was changed.")
      return nil
    end

    # Notes gathered before the rename, reported after it.
    notes = []
    notes << 'That part is NOT at the top level of the model — it is still nested inside ' \
             'a group or component. It has been renamed, but save-scene-components.rb only ' \
             'scans the top level, so the scene will still read as a MODEL GAP until it is ' \
             'moved or exploded out.' unless top_level?(model, ent)
    count = (defn.instances.length rescue 1)
    notes << "This definition has #{count} instances in the model — renaming it renames " \
             'all of them, because they share the one definition.' if count > 1

    model.start_operation(TITLE, true)
    got, warn = rename_to(defn, want)

    if warn
      # A uniquified name is not what was asked for. Put the model back rather
      # than leaving a "#3" behind — that is the exact mess this tool exists to
      # clear, and creating more of it silently is worse than doing nothing.
      model.abort_operation
      puts "#{TITLE}: #{warn} — ABORTED, model unchanged."
      UI.messagebox("#{warn}\n\nNothing was changed — the rename was rolled back.\n\n" \
                    "Something else in this model already holds \"#{want}\". Rename or delete " \
                    'that one first, then run this again.')
      return nil
    end

    # For a group, also set the INSTANCE name, so Entity Info and the Outliner
    # show what the exporter now matches on. See the header note.
    if ent.is_a?(Sketchup::Group)
      begin
        ent.name = want
      rescue Exception => e
        notes << "Definition renamed, but the group's instance name could not be set " \
                 "(#{e.class}). Entity Info will still show the old label."
      end
    end

    model.commit_operation

    line = "#{TITLE}: OK  \"#{was}\" -> \"#{got}\""
    puts line
    begin
      Sketchup.status_text = line
    rescue Exception
      nil
    end

    unless notes.empty?
      notes.each { |n| puts "  NOTE  #{n}" }
      UI.messagebox("Renamed.\n\n\"#{was}\"\n  ->  \"#{got}\"\n\n#{notes.join("\n\n")}")
    end

    nil
  end
end

begin
  WR_NameAfterScene.run
rescue Exception => e
  puts ''
  puts "FAILED: #{e.class}: #{e.message}"
  puts e.backtrace.first(12).map { |l| "  #{l}" }.join("\n")
  UI.messagebox("Name Selection After Scene failed:\n\n#{e.class}: #{e.message}\n\n" \
                'Full backtrace is in the Ruby Console.')
end
