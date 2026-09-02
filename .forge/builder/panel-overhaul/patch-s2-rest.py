# Slice 2, the non-generator edits: make-icons.py keeps wr- label lines,
# six script headers, wr_id in main.rb and in the harness's scan.py.
ROOT = "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp"

def patch(path, a, b):
    p = ROOT + "/" + path
    s = open(p, encoding="utf-8").read()
    assert s.count(a) == 1, (path, s.count(a))
    open(p, "w", encoding="utf-8", newline="\n").write(s.replace(a, b))
    print("patched", path)

patch("scripts/make-icons.py",
"""    with open(os.path.join(OUT, 'ico-labels.txt'), 'w', encoding='utf-8') as f:
        for name, label, _b in ICONS:
            f.write('%s\\t%s\\n' % (name, label))
""",
"""    # The wr-* lines belong to .forge/builder-icons/gen-icons.py (the
    # WhisperRoom symbol set); keep them, rewrite only this set's.
    lp = os.path.join(OUT, 'ico-labels.txt')
    wr = []
    if os.path.exists(lp):
        with open(lp, encoding='utf-8') as f:
            wr = [l for l in f.read().splitlines() if l.startswith('wr-')]
    with open(lp, 'w', encoding='utf-8') as f:
        for name, label, _b in ICONS:
            f.write('%s\\t%s\\n' % (name, label))
        for l in wr:
            f.write(l + '\\n')
""")

patch("scripts/bulk-name-after-scenes.rb", "# @icon names-replace\n", "# @icon names-bulk\n")

for f, mono in [("csusb-106.rb", "CS"), ("uthsc-audiology-rooms.rb", "UT"), ("dowaly-kuwait-tv.rb", "DK"),
                ("fvrl-podcast-alcove.rb", "FV"), ("smith-studio.rb", "DS")]:
    s = open(ROOT + "/scripts/" + f, encoding="utf-8").read()
    assert s.startswith("# @title") and "@icon" not in s[:300], f
    patch("scripts/" + f, "\n# @cat Draw the room\n", "\n# @cat Draw the room\n# @icon mono:%s\n" % mono)

patch("scripts/wr_tools/main.rb",
"""    def self.wr_id(id)
      s = id.to_s.strip
      return nil if s.empty?
      s.start_with?('wr-') ? s : "wr-#{s}"
    end
""",
"""    def self.wr_id(id)
      s = id.to_s.strip
      return nil if s.empty?
      # "mono:CS" is a two-letter monogram, not a sprite symbol: the panel
      # draws the letters in the icon well. Client one-offs use it — two
      # initials beat any picture of a room nobody else will draw again.
      return s if s.start_with?('mono:')
      s.start_with?('wr-') ? s : "wr-#{s}"
    end
""")

patch(".forge/scoper/panel-harness/scan.py",
"""    if not s: return None
    return s if s.startswith("wr-") else "wr-"+s""",
"""    if not s: return None
    if s.startswith("mono:"): return s
    return s if s.startswith("wr-") else "wr-"+s""")
