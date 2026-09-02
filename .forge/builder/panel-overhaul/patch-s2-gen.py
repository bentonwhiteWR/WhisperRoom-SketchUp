# One-shot patch for slice 2: the 22 new symbols, the map, the coverage rule
# and the label merge in .forge/builder-icons/gen-icons.py. Kept so the edit
# is reviewable; running it twice asserts and stops.
import re
ROOT = "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp"
p = ROOT + "/.forge/builder-icons/gen-icons.py"
s = open(p, encoding="utf-8").read()

def sub(a, b):
    global s
    assert s.count(a) == 1, (a[:60], s.count(a))
    s = s.replace(a, b)

NEW = '''# ----------------------------------------------- 2 Sep 2026: panel overhaul slice 2
# The 22 symbols the overhaul spec briefs (.forge/scoper/panel-overhaul.md 6.8):
# every tool that fell to wr-default, plus three that shared a glyph. Same
# grammar: graphite subject, one orange element = what the tool makes or moves.
("takeoff", "Build the room from a take-off", "authored",
 [("M6 3.5h8.5l4 4v13H6z M14.5 3.5v4h4", "")],
 [("M9 11h6.5v6.5H9z M13 17.5v-2.6h2.5", "")]),
("reorient", "Make this view the Front", "authored",
 [("M4 9h10.5v10.5H4z", "")],
 [("M9 5.5h6a4.5 4.5 0 0 1 4.5 4.5v4 M17.3 12l2.2 2.2 2.2-2.2", "")]),
("prefix", "Prefix every scene name", "authored",
 [("M11.5 6.5h8.5 M11.5 12h8.5 M11.5 17.5h8.5", "")],
 [("M3.5 18l2.8-10 2.8 10 M4.7 14.2h3.2", "")]),
("probe-place", "Probe placement of the selection", "authored",
 [("M4.5 4.5h15v15h-15z", "")],
 [("M9 12a3 3 0 1 0 6 0a3 3 0 1 0-6 0 M12 6.5V9 M12 15v2.5 M6.5 12H9 M15 12h2.5", "")]),
("mode", "Toggle draft / render mode", "authored",
 [("M4.5 5h15v14h-15z M12 5v14", "")],
 [("M13 6h5.5v12H13z", 'fill="#ee6216" stroke="none"')]),
("sun", "Light it from here (sun to camera)", "authored",
 [("M4 10.5h9v9H4z", "")],
 [("M14.6 7a2.4 2.4 0 1 0 4.8 0a2.4 2.4 0 1 0-4.8 0 M17 2.5v1.5 M17 11v1.5 M12.5 7H14 "
   "M20 7h1.5 M13.8 3.8l1.1 1.1 M19.1 9.1l1.1 1.1 M13.8 10.2l1.1-1.1 M19.1 4.9l1.1-1.1", "")]),
("lights", "Drop the interior lights", "authored",
 [("M4 4.5h16v15H4z", "")],
 [("M12 4.5v3.5 M9.6 11a2.4 2.4 0 0 1 4.8 0c0 1.4-1.1 1.9-1.1 3h-2.6c0-1.1-1.1-1.6-1.1-3z M11 16h2", "")]),
("materials", "Swap draft / render materials", "authored",
 [("M4 4h9.5v9.5H4z", "")],
 [("M10.5 10.5H20V20h-9.5z M13.5 13.5h3.5V17h-3.5z", "")]),
("preflight", "Pre-render checklist", "authored",
 [("M6 3h12v18H6z M12.5 8h3.5 M12.5 12h3.5 M12.5 16h3.5", "")],
 [("M8.5 8l1 1 1.8-2 M8.5 12l1 1 1.8-2 M8.5 16l1 1 1.8-2", "")]),
("pack", "Export the client pack", "authored",
 [("M4 8.5h11.5V20H4z M4 12.5h11.5", "")],
 [("M13.5 4h6.5v6.5 M20 4l-5.5 5.5", "")]),
("scene-walls", "Hide walls per scene", "authored",
 [("M4.5 4.5v15h15v-15", "")],
 [("M4.5 4.5h15", 'stroke-dasharray="2.4 2.4"')]),
("name-walls", "Name walls for the scene picker", "authored",
 [("M4.5 7h15v13h-15z", "")],
 [("M8 3h8l1.6 2-1.6 2H8z", "")]),
("lower-walls", "Lower selected walls to a curb", "authored",
 [("M4.5 4.5v15 M19.5 4.5v15 M4.5 4.5h15", 'stroke-dasharray="2.4 2.4"')],
 [("M4.5 19.5v-6h15v6 M12 4.5v6 M9.5 8l2.5 2.5L14.5 8", "")]),
("split-walls", "Split walls at sill", "authored",
 [("M5.5 4.5h13v15h-13z", "")],
 [("M3 12.5h18", 'stroke-dasharray="3 2"')]),
("lookdev", "Look-development matrix", "authored",
 [("M4.5 4.5h15v15h-15z M9.5 4.5v15 M14.5 4.5v15 M4.5 9.5h15 M4.5 14.5h15", "")],
 [("M10.4 10.4h3.2v3.2h-3.2z", 'fill="#ee6216" stroke="none"')]),
("probe-color", "Probe V-Ray colour settings", "authored",
 [("M4 20l6.5-6.5", "")],
 [("M15.5 3.5s4.5 4.7 4.5 7.6a4.5 4.5 0 0 1-9 0c0-2.9 4.5-7.6 4.5-7.6z", "")]),
("probe-vray", "Probe V-Ray API", "authored",
 [("M4 20l5.5-5.5", "")],
 [("M8.5 9.5a5.5 5.5 0 1 0 11 0a5.5 5.5 0 1 0-11 0 M11.5 7.5l2.5 5 2.5-5", "")]),
("probe-enh", "Probe the Enhanced shell", "authored",
 [("M4 4.5h10.5v15H4z", "")],
 [("M21 7.5h-4v9h4 M17 12h3", "")]),
("probe-seal", "Probe the seam seals", "authored",
 [("M4.5 9v11h15V9", "")],
 [("M3.5 6.5h17 M9.5 14l1.8 1.8 3.4-3.6", "")]),
("names-bulk", "Name parts after their scenes (bulk)", "authored",
 [("M4 6h5 M4 12h5 M4 18h5", "")],
 [("M12 4h6l1.5 2-1.5 2h-6z M12 10h6l1.5 2-1.5 2h-6z M12 16h6l1.5 2-1.5 2h-6z", "")]),
("name-one", "Name the selection after its scene", "authored",
 [("M4 9.5h9.5V20H4z", 'stroke-dasharray="2.4 2.4"')],
 [("M11 3.5h7.5l2 2.5-2 2.5H11z", "")]),
("package", "Proposal package", "authored",
 [("M3.5 3.5h4.5V8H3.5z M9.5 3.5H14V8H9.5z M3.5 9.5h4.5V14H3.5z M9.5 9.5H14V14H9.5z", "")],
 [("M16 11h5v9.5h-5z M6 17.5h7.5 M11.5 15.5l2 2-2 2", "")]),
# ------------------------------------------------------------------------- spare
'''
sub("# ------------------------------------------------------------------------- spare\n", NEW)

sub('''    "pendant-jig.rb": "jig-pendant",
    "tube-drying-stand.rb": "jig-tube-stand",
    # SKIP libraries - never rendered as rows, mapped only so the map is total.
    "wr-booth-data.rb": "booth-blockout",
    "wr-deck.rb": "probe-levels",
    "wr-folder.rb": "scenes-export",
    "wr-shading.rb": "art-flat",
    "wr_tools.rb": "booth-blockout",
}
SKIP_LIBS = {"wr-booth-data.rb", "wr-deck.rb", "wr-folder.rb", "wr-shading.rb", "wr_tools.rb"}
''', '''    "pendant-jig.rb": "jig-pendant",
    "tube-drying-stand.rb": "jig-tube-stand",
    # 2 Sep 2026, panel overhaul slice 2
    "build-takeoff.rb": "takeoff",
    "reorient-model.rb": "reorient",
    "prefix-scenes.rb": "prefix",
    "probe-placement.rb": "probe-place",
    "wr-mode.rb": "mode",
    "wr-sun-aim.rb": "sun",
    "wr-drop-lights.rb": "lights",
    "wr-materials-swap.rb": "materials",
    "wr-preflight.rb": "preflight",
    "wr-pack-export.rb": "pack",
    "wr-scene-walls.rb": "scene-walls",
    "wr-name-walls.rb": "name-walls",
    "wr-lower-walls.rb": "lower-walls",
    "wr-split-walls.rb": "split-walls",
    "lookdev-matrix.rb": "lookdev",
    "probe-vray-color.rb": "probe-color",
    "probe-vray.rb": "probe-vray",
    "probe-enhanced.rb": "probe-enh",
    "probe-seam-seal.rb": "probe-seal",
    "bulk-name-after-scenes.rb": "names-bulk",
    "name-selection-after-scene.rb": "name-one",
    "proposal-package.rb": "package",
}
# main.rb's SKIP list: libraries other scripts load, never panel rows. They
# used to carry dead map entries "so the map is total"; the panel now falls
# back to the category glyph, so nothing needs an entry it does not draw.
SKIP_LIBS = {"wr_tools.rb", "wr-booth-data.rb", "wr-shading.rb", "wr-folder.rb", "wr-deck.rb",
             "wr-overlays.rb", "wr-roof-vent.rb", "wr-bridge-lib.rb", "wr-png-srgb.rb"}
''')

sub('''    ("Tidy up the model", ["names-replace", "materials-merge", "scenes-import"]),
    ("Developer probes", ["probe-components", "probe-levels", "diag-favourites",
                          "rooms-csusb", "booth-preset-small", "booth-preset-large"]),
''', '''    ("V-Ray renders", ["package", "mode", "sun", "lights", "materials", "preflight", "pack",
                       "scene-walls", "name-walls", "lower-walls", "split-walls", "probe-color"]),
    ("Tidy up the model", ["names-replace", "names-bulk", "name-one", "materials-merge",
                           "scenes-import", "prefix"]),
    ("Draw the room, more", ["takeoff", "reorient"]),
    ("Build the booth, more", ["probe-place"]),
    ("Developer probes", ["probe-components", "probe-levels", "diag-favourites",
                          "rooms-csusb", "booth-preset-small", "booth-preset-large",
                          "lookdev", "probe-vray", "probe-enh", "probe-seal"]),
''')

sub('''    # 4. contact sheet
    contact_sheet()
''', '''    # 3b. labels for the slot picker: "wr-<id> TAB <tool>" lines merged into
    # ico-labels.txt, which make-icons.py owns for the legacy ico-* set. Both
    # generators keep the other's lines.
    lp = os.path.join(OUT, "ico-labels.txt")
    keep = [l for l in open(lp, encoding="utf-8").read().splitlines()
            if l.strip() and not l.startswith("wr-")] if os.path.exists(lp) else []
    keep += ["wr-%s\\t%s" % (ic[0], ic[1]) for ic in ICONS]
    open(lp, "w", encoding="utf-8", newline="\\n").write("\\n".join(keep) + "\\n")

    # 4. contact sheet
    contact_sheet()
''')

sub('''    # every script covered
    scripts = sorted(x for x in os.listdir(os.path.join(ROOT, "scripts")) if x.endswith(".rb"))
    for s in scripts:
        if s not in MAP:
            bad.append("icon-map: script %s not covered" % s)
''', '''    # every panel row has a glyph of its own: a map entry, or an "@icon" line in
    # its header (which main.rb's icon_of reads first). Libraries never draw.
    scripts = sorted(x for x in os.listdir(os.path.join(ROOT, "scripts")) if x.endswith(".rb"))
    for s in scripts:
        if s in MAP or s in SKIP_LIBS:
            continue
        head = open(os.path.join(ROOT, "scripts", s), encoding="utf-8", errors="replace").read(4000)
        if not re.search(r"^\\s*#\\s*@icon\\s+\\S", head, re.M):
            bad.append("icon-map: script %s not covered" % s)
''')
open(p, "w", encoding="utf-8", newline="\n").write(s)
print("gen-icons.py patched")
