# Slice 5, the copy pass (.forge/scoper/panel-overhaul.md 6.10). Label-only:
# twelve @title lines to sentence case, verb first; thirteen blurbs lose the
# "name.rb - " prefix that repeats the filename already in the tooltip.
# Filenames untouched, header grammar untouched.
import re
ROOT = "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/scripts/"

TITLES = {
    "list-scenes.rb":                 ("List Scenes...",                  "List the scenes..."),
    "merge-materials.rb":             ("Merge Materials...",              "Merge duplicate materials..."),
    "orbit-export.rb":                ("Orbit Export...",                 "Orbit export (turntable frames)..."),
    "explode-view.rb":                ("Exploded View...",                "Exploded view..."),
    "save-scene-components.rb":       ("Save Scene Components...",        "Save each scene's component..."),
    "prefix-scenes.rb":               ("Prefix Every Scene...",           "Prefix every scene name..."),
    "bulk-name-after-scenes.rb":      ("Bulk Name After Scenes...",       "Name parts after their scenes (bulk)..."),
    "name-selection-after-scene.rb":  ("Name Selection After Scene",      "Name the selection after its scene"),
    "wr-drop-lights.rb":              ("Drop Interior Lights",            "Drop the interior lights"),
    "wr-sun-aim.rb":                  ("Light It From Here...",           "Light it from here (sun to camera)..."),
    "wr-mode.rb":                     ("Toggle Draft / Render mode...",   "Toggle draft / render mode..."),
    "export-component-art.rb":        ("Scene PIctures...",               "Scene pictures (flat art)..."),
}
BLURBS = ["wr-drop-lights.rb", "lookdev-matrix.rb", "wr-sun-aim.rb", "uthsc-audiology-rooms.rb",
          "csusb-106.rb", "csusb-rooms.rb", "dowaly-kuwait-tv.rb", "fvrl-podcast-alcove.rb",
          "prefix-scenes.rb", "probe-vray.rb", "smith-studio.rb", "reorient-model.rb",
          "diag-favourites.rb"]

for f, (old, new) in TITLES.items():
    p = ROOT + f
    s = open(p, encoding="utf-8").read()
    a = "# @title %s\n" % old
    assert s.count(a) == 1 and s.startswith(a), (f, s[:60])
    open(p, "w", encoding="utf-8", newline="\n").write(s.replace(a, "# @title %s\n" % new, 1))
    print("title  %-32s %s" % (f, new))

for f in BLURBS:
    p = ROOT + f
    s = open(p, encoding="utf-8").read()
    # The first blurb line is the first comment line that is neither a header
    # tag nor blank; it must open with the filename and an em dash.
    pat = re.compile(r"^# %s \u2014 (\S)(.*)$" % re.escape(f), re.M)
    m = pat.search(s)
    assert m and m.start() < 600, (f, "no 'name.rb - ' first line in the header")
    s = s[:m.start()] + "# " + m.group(1).upper() + m.group(2) + s[m.end():]
    open(p, "w", encoding="utf-8", newline="\n").write(s)
    print("blurb  %-32s %s" % (f, (m.group(1).upper() + m.group(2))[:60]))
