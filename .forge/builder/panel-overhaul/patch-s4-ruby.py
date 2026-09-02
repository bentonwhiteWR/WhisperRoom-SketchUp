# Slice 4, the Ruby half: main.rb only.
#  1. refresh_fav_labels scans the folder once, not 18 times (audit A11)
#  2. ui_compact pref: compact? / set_ui_pref, the 'uipref' callback with a
#     whitelist, 'compact' in the payload, ui_compact in SHOP_KEYS
#  3. 'faces' dropped from the payload - shipped, never read (audit A11)
ROOT = "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp"
p = ROOT + "/scripts/wr_tools/main.rb"
s = open(p, encoding="utf-8").read()

def sub(a, b):
    global s
    assert s.count(a) == 1, (a[:70], s.count(a))
    s = s.replace(a, b)

sub("""    # Everything this panel remembers about how it is arranged. Recents are
    # left out on purpose: they are one person's history, not a shop setting.
    SHOP_KEYS = %w[slots slot_icons pinned ui_collapsed ui_dev].freeze
""", """    # Everything this panel remembers about how it is arranged. Recents are
    # left out on purpose: they are one person's history, not a shop setting.
    SHOP_KEYS = %w[slots slot_icons pinned ui_collapsed ui_dev ui_compact].freeze
""")

sub("""    # What slot i currently points at, resolved against what is on disk so a
    # slot left behind by a deleted script cannot fire a dead button.
    def self.favourite_at(i)
      name = slots[i]
      return nil if blank?(name)
      scan.find { |s| s['name'] == name }
    end
""", """    # What slot i currently points at, resolved against what is on disk so a
    # slot left behind by a deleted script cannot fire a dead button. A caller
    # that asks for every slot passes one scan in rather than paying for
    # eighteen — each scan reads every script's header four times.
    def self.favourite_at(i, list = nil)
      name = slots[i]
      return nil if blank?(name)
      (list || scan).find { |s| s['name'] == name }
    end
""")

sub("""    def self.refresh_fav_labels
      return if @fav_cmds.nil?
      @fav_cmds.each_with_index do |cmd, i|
        s = favourite_at(i)
""", """    def self.refresh_fav_labels
      return if @fav_cmds.nil?
      # One scan for all eighteen slots. This used to be eighteen scans of the
      # whole folder per star click, rename or slot save (~4,400 file reads),
      # which was the only reason a star felt slow.
      list = scan
      @fav_cmds.each_with_index do |cmd, i|
        s = favourite_at(i, list)
""")

sub("""    def self.dev_shown?
      read_pref('ui_dev', 'false') == 'true'
    end

    def self.set_dev_shown(on)
      write_pref('ui_dev', on ? 'true' : 'false')
    end
""", """    def self.dev_shown?
      read_pref('ui_dev', 'false') == 'true'
    end

    def self.set_dev_shown(on)
      write_pref('ui_dev', on ? 'true' : 'false')
    end

    # Small panel-furniture switches that live in preferences: title-only rows
    # today; anything later goes through the same one callback. The whitelist
    # is the point — the page names a key, Ruby decides whether it is one.
    UI_PREFS = %w[compact].freeze

    def self.compact?
      read_pref('ui_compact', 'false') == 'true'
    end

    def self.set_ui_pref(key, on)
      k = key.to_s
      return unless UI_PREFS.include?(k)
      write_pref("ui_#{k}", on.to_s == 'true' ? 'true' : 'false')
    end
""")

sub("""        'collapsed' => collapsed, 'dev' => dev_shown?,
        'scripts' => scan, 'abilities' => abilities,
""", """        'collapsed' => collapsed, 'dev' => dev_shown?, 'compact' => compact?,
        'scripts' => scan, 'abilities' => abilities,
""")

sub("""        # What the slots WILL wear, and what the native toolbar is wearing right
        # now. They differ between saving a slot and the next launch, and the
        # panel shows that rather than drawing a row that disagrees with the
        # real one.
        'faces' => faces(slots, slot_icons),
        'bound_faces' => faces(bound_slots, bound_icons),
""", """        # What the native toolbar is wearing right now, and which slots differ
        # from what is saved. The panel shows the difference as pending rather
        # than drawing a row that disagrees with the real one. (The saved
        # faces themselves used to ship too, as 'faces'; nothing read them.)
        'bound_faces' => faces(bound_slots, bound_icons),
""")

sub("""      d.add_action_callback('collapse')  { |_c, list| set_collapsed(list) }
      d.add_action_callback('devtools')  { |_c, on| set_dev_shown(on.to_s == 'true') }
""", """      d.add_action_callback('collapse')  { |_c, list| set_collapsed(list) }
      d.add_action_callback('devtools')  { |_c, on| set_dev_shown(on.to_s == 'true') }
      d.add_action_callback('uipref')    { |_c, key, on| set_ui_pref(key, on) }
""")

open(p, "w", encoding="utf-8", newline="\n").write(s)
print("main.rb patched")
