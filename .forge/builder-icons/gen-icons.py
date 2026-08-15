# -*- coding: utf-8 -*-
"""Single source of truth for the WhisperRoom icon system.

Emits, into scripts/wr_tools/:
  wr-ico-<id>.svg   standalone (SketchUp toolbar) - graphite resolved to a hex
  wr-icons.svg      sprite of <symbol id="wr-<id>"> - graphite stays currentColor
  icon-map.json     <script>.rb -> <icon-id>
and .forge/builder-icons/contact-sheet.html

Geometry contract: 24 grid, 20 live area (2..22), 1.8 centred stroke, round
caps/joins, exactly one #ee6216 group per icon.
"""
import json, os, re, sys, xml.etree.ElementTree as ET

ROOT = r"C:\Users\bento\OneDrive\Documents\Claude\Sketchup\WhisperRoom-SketchUp"
OUT = os.path.join(ROOT, "scripts", "wr_tools")
NOTES = os.path.join(ROOT, ".forge", "builder-icons")

ORANGE = "#ee6216"
# Graphite for standalone toolbar copies: the panel's own light-theme --p-ink.
INK = "#20262a"

G = 'fill="none" stroke="%s" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"'

# id, tool label, provenance, grey paths [(d, extra)], orange paths [(d, extra)]
ICONS = [
# ---------------------------------------------------------------- draw the room
("room-takeoff", "Build a room from a take-off", "extracted",
 [("M9.5 19.5H4.5V4.5h15v15h-4.5", "")],
 [("M15 19.5V14 M15 14a5.5 5.5 0 0 1-5.5 5.5", "")]),
# --------------------------------------------------------------- build the booth
("booth-link", "Build the customer's booth (share link)", "extracted",
 [("M3.5 3.5h12v11h-12z M11 14.5v-5h4.5", "")],
 [("M16.2 15.6l1.2-1.2a2.2 2.2 0 0 1 3.1 3.1l-1.2 1.2", ""),
  ("M18.4 17.8l-1.2 1.2a2.2 2.2 0 0 1-3.1-3.1l1.2-1.2", ""),
  ("M15.9 18.1l2.2-2.2", "")]),
("booth-parts", "Build a booth from real parts", "extracted",
 [("M4 5.5h11.5v13H4z M8.2 5.5v13", "")],
 [("M19 5.5h1.5v13H19z M18 12h-1.6 M17.4 10.8L16.2 12l1.2 1.2", "")]),
("booth-blockout", "Block-out booth (plain boxes, fast)", "extracted",
 [("M3.5 6.5h12.5v12H3.5z M12.2 18.5v-6.2h3.8", "")],
 [("M19.3 4v5 M16.8 6.5h5", 'stroke-linejoin="round"')]),
# --------------------------------------------------------------- add dimensions
("dim-room", "Dimension the room", "revised",
 [("M4.5 3.4h15v8.6h-15z", ""),
  ("M9.5 3.4v8.6 M14.5 3.4v8.6", 'stroke-width="1.2"'),
  ("M4.5 12.6v1.6 M9.5 12.6v1.6 M14.5 12.6v1.6 M19.5 12.6v1.6", 'stroke-width="1.2"')],
 [("M4.5 15.8h15 M4.9 16.9l1.7-2.2 M9.9 16.9l1.7-2.2 M14.9 16.9l1.7-2.2 "
   "M4.5 19.6h15 M4.9 20.7l1.7-2.2 M18.5 20.7l1.7-2.2", "")]),
("dim-booth", "Dimension the booth (catalogue figures)", "revised",
 [("M4.5 3.4h11.5v9.2h-11.5z M12.4 12.6v-5.4h3.6", ""),
  ("M17.6 4.4h3.6v3.6h-3.6z", 'stroke-width="1.4"'),
  ("M18.5 6.2h1.8", 'stroke-width="1.2"'),
  ("M4.5 14v2.1 M16 14v2.1", 'stroke-width="1.2"')],
 [("M4 17.6h12.5 M4.6 18.7l1.8-2.2 M14.1 18.7l1.8-2.2", "")]),
("dim-selection", "Measure whatever is selected", "revised",
 [("M3.4 3.4h13.8v13.8H3.4z", 'stroke-dasharray="2.8 2.4"'),
  ("M7.4 6.2l4.2-1 2.6 3.2-1 4.4-4.6.6-2.4-3.4z", "")],
 [("M4.6 19.2h13.4 M5.2 20.3l1.8-2.2 M15.6 20.3l1.8-2.2 "
   "M20.4 4.4v11.6 M19.3 5.4l2.2-1.6 M19.3 15l2.2-1.6", "")]),
# ------------------------------------------------------------ scenes and images
("scenes-proposal", "Set up the five proposal plates", "revised",
 [("M5.15 7.6h11.4v10.2 M6.4 6.35h11.4v8.9 M7.65 5.1h11.4v7.6 M8.9 3.85h11.4v6.3", "")],
 [("M4 9h11.4v11.2H4z M6.4 12.8h6.6v5.2h-6.6z M11.3 18v-3h1.7", "")]),
("scenes-list", "List and number the scenes", "authored",
 [("M4.2 6.5h1.8 M4.2 12h1.8 M4.2 17.5h1.8", ""),
  ("M8.4 6.5h7.6 M8.4 12h7.6 M8.4 17.5h7.6", 'stroke-width="1.4"')],
 [("M18.2 4.6h2.4v14.8h-2.4", "")]),
("scenes-export", "Export the proposal plates", "extracted",
 [("M4.5 4.5h10v8h-10z M9.5 8.5h10v8h-10z", "")],
 [("M14.5 17.5v3.6 M12.3 19l2.2 2.2 2.2-2.2", "")]),
("view-export", "Export just this view", "extracted",
 [("M4.5 5.5h15v10h-15z", "")],
 [("M12 17v4 M9.8 18.8l2.2 2.2 2.2-2.2", "")]),
# ------------------------------------------------------------------ component art
("art-angled", "Component art - Iso30 angles", "authored",
 [("M4.4 8.6l6.6 3.8v7.2", 'stroke-width="1.4"'),
  ("M7.7 7.6l6.6 3.8v7.2", 'stroke-width="1.4"')],
 [("M11 6.6l7 4v7.4l-7-4z", "")]),
("art-flat", "Component art - flat views", "authored",
 [("M4.5 4.5h15v15h-15z", ""),
  ("M4.5 4.5h7.5v7.5h-7.5z M12 12h7.5v7.5h-7.5z",
   'fill="CURRENTFILL" stroke="none" opacity=".22"')],
 [("M9 6.5h6v11h-6z", "")]),
("art-elevations", "Component art - six elevations", "extracted",
 [("M4.5 4.5h11v15h-11z M8.2 4.5v15 M11.9 4.5v15", "")],
 [("M16.8 12h4.7 M19.3 9.8l2.2 2.2-2.2 2.2", "")]),
("art-orbit", "Orbit a part for the assembly manual", "extracted",
 [("M8.5 7.5h7v8.5h-7z M13 16v-4h2.5", "")],
 [("M2.8 11.5C2.8 15.2 7 17.8 12 17.8c5 0 9.2-2.6 9.2-6.3", ""),
  ("M21.2 11.5l-1.9.7 M21.2 11.5l-.4 2", "")]),
("explode", "Explode an assembly", "extracted",
 [("M3.5 7h4v12h-4z M16.5 7h4v12h-4z", "")],
 [("M10 4h4v12h-4z", "")]),
("scene-parts", "Save each scene's part as a .skp", "extracted",
 [("M4 7.5V4h3.5 M16.5 4H20v3.5 M4 16.5V20h3.5 M16.5 20H20v-3.5", "")],
 [("M12 7.8l3.6 2.1v4.2L12 16.2l-3.6-2.1V9.9z M8.4 9.9l3.6 2.1 3.6-2.1 M12 12v4.2", "")]),
# ------------------------------------------------------------- tidy up the model
("names-replace", "Find and replace names", "extracted",
 [("M4 4.5h6l7 7-6.5 6.5-7-7z", ""), ("M7 7.5m-1.1 0a1.1 1.1 0 1 0 2.2 0a1.1 1.1 0 1 0-2.2 0", "")],
 [("M15 4.8h5.8 M18.8 2.8l2 2-2 2 M20.8 9.2H15 M17 7.2l-2 2 2 2", "")]),
("materials-merge", "Merge two materials into one", "extracted",
 [("M8.9 12m-5.4 0a5.4 5.4 0 1 0 10.8 0a5.4 5.4 0 1 0-10.8 0", ""),
  ("M15.1 12m-5.4 0a5.4 5.4 0 1 0 10.8 0a5.4 5.4 0 1 0-10.8 0", "")],
 [("M12 7.58A5.4 5.4 0 0 1 12 16.42 5.4 5.4 0 0 1 12 7.58z", "")]),
("scenes-import", "Import a .skp and keep its scenes", "revised",
 [("M3.4 3.4h6.6v8.8H3.4z", ""), ("M9.6 10h11v10.6h-11z", "")],
 [("M10.2 10V7.6h2.7V10 M13.5 10V7.6h2.7V10 M16.8 10V7.6h2.7V10", "")]),
# --------------------------------------------------------------- developer shelf
("probe-components", "Probe Component Files", "extracted",
 [("M10.5 10.5m-5.8 0a5.8 5.8 0 1 0 11.6 0a5.8 5.8 0 1 0-11.6 0", ""),
  ("M14.7 14.7l4.6 4.6", "")],
 [("M10.5 7.5v4.8 M8.2 12.3h4.6", "")]),
("probe-levels", "Probe Face Levels", "authored",
 [("M5.5 3.5h8v17h-8z", ""),
  ("M5.5 8h8 M5.5 12.5h8 M5.5 17h8", 'stroke-width="1.2"')],
 [("M15.6 8h4.6 M18.4 6.4l1.8 1.6-1.8 1.6", "")]),
("diag-favourites", "Diag Favourites", "authored",
 [("M2.8 8.5h5v7h-5z M8.6 8.5h5v7h-5z", "")],
 [("M14.4 8.5h5v7h-5z M15.7 12l1.4 1.5 2.7-3.2", "")]),
("rooms-csusb", "CSUSB rooms (one-off job)", "authored",
 [("M3.5 4.5h9v6.6h-9z M3.5 12.9h9v6.6h-9z", "")],
 [("M14.6 8.4h6.2v7.2h-6.2z M16.2 10.8h3 M16.2 13.2h3", "")]),
("booth-preset-small", "Build Booth MDL 4260 S", "authored",
 [("M3.4 3.4h17.2v17.2H3.4z", 'stroke-dasharray="2.6 2.4"')],
 [("M6.6 10.6h6.4v7.4H6.6z M10.8 18v-3.6h2.2", "")]),
("booth-preset-large", "Build Booth MDL 96168 S", "authored",
 [("M3.4 3.4h17.2v17.2H3.4z", 'stroke-dasharray="2.6 2.4"')],
 [("M6 6.4h12v11.6H6z M13.6 18v-5.6h4.4", "")]),
# ------------------------------------------------------------------ workshop shelf
("jig-pendant", "Pendant Curing Jig", "authored",
 [("M3 18.6h18", ""), ("M5 18.6l1.6-2.2h10.8l1.6 2.2", 'stroke-width="1.4"')],
 [("M7.6 16.4h8.8 M10 16.4V11a2 2 0 0 1 4 0v5.4", "")]),
("jig-tube-stand", "Tube Drying Stand", "authored",
 [("M3 18.6h18", ""), ("M5 18.6l1.6-2.2h10.8l1.6 2.2", 'stroke-width="1.4"')],
 [("M7 16.4h10 M9 16.4V7.8 M12 16.4V7.8 M15 16.4V7.8", "")]),
# ------------------------------------------------------------------------- spare
("ghost", "(reserve - ghost/reference geometry)", "extracted",
 [("M4.5 6.5h11v11h-11z", 'stroke-dasharray="2.6 2.2"')],
 [("M8.5 3.5h11v11", "")]),
]

# script filename -> icon id. Covers every .rb in scripts/.
MAP = {
    "build-room.rb": "room-takeoff",
    "booth-from-link.rb": "booth-link",
    "build-booth-components.rb": "booth-parts",
    "build-booth.rb": "booth-blockout",
    "auto-dimension.rb": "dim-room",
    "dimension-booth.rb": "dim-booth",
    "dimension-selection.rb": "dim-selection",
    "proposal-scenes.rb": "scenes-proposal",
    "list-scenes.rb": "scenes-list",
    "export-scenes.rb": "scenes-export",
    "export-this-view.rb": "view-export",
    "angled-component-art.rb": "art-angled",
    "export-component-art.rb": "art-flat",
    "elevation-export.rb": "art-elevations",
    "orbit-export.rb": "art-orbit",
    "explode-view.rb": "explode",
    "save-scene-components.rb": "scene-parts",
    "find-replace-names.rb": "names-replace",
    "merge-materials.rb": "materials-merge",
    "merge-scenes.rb": "scenes-import",
    "probe-components.rb": "probe-components",
    "probe-levels.rb": "probe-levels",
    "diag-favourites.rb": "diag-favourites",
    "csusb-rooms.rb": "rooms-csusb",
    "booth-4260-s.rb": "booth-preset-small",
    "booth-96168-s.rb": "booth-preset-large",
    "pendant-jig.rb": "jig-pendant",
    "tube-drying-stand.rb": "jig-tube-stand",
    # SKIP libraries - never rendered as rows, mapped only so the map is total.
    "wr-booth-data.rb": "booth-blockout",
    "wr-deck.rb": "probe-levels",
    "wr-folder.rb": "scenes-export",
    "wr-shading.rb": "art-flat",
    "wr_tools.rb": "booth-blockout",
}
SKIP_LIBS = {"wr-booth-data.rb", "wr-deck.rb", "wr-folder.rb", "wr-shading.rb", "wr_tools.rb"}

CATEGORY = [
    ("Draw the room", ["room-takeoff"]),
    ("Build the booth", ["booth-link", "booth-parts", "booth-blockout"]),
    ("Add dimensions", ["dim-room", "dim-booth", "dim-selection"]),
    ("Scenes and images", ["scenes-proposal", "scenes-list", "scenes-export", "view-export"]),
    ("Component art (web catalog)",
     ["art-angled", "art-flat", "art-elevations", "art-orbit", "explode", "scene-parts"]),
    ("Tidy up the model", ["names-replace", "materials-merge", "scenes-import"]),
    ("Developer probes", ["probe-components", "probe-levels", "diag-favourites",
                          "rooms-csusb", "booth-preset-small", "booth-preset-large"]),
    ("Workshop (3D printing)", ["jig-pendant", "jig-tube-stand"]),
    ("Reserve", ["ghost"]),
]


def body(ic, ink):
    grey, orange = ic[3], ic[4]
    out = []
    plain = [p for p in grey if "stroke=\"none\"" not in p[1]]
    fills = [p for p in grey if "stroke=\"none\"" in p[1]]
    if plain:
        out.append("  <g %s>" % (G % ink))
        for d, extra in plain:
            out.append('    <path d="%s"%s/>' % (d, (" " + extra) if extra else ""))
        out.append("  </g>")
    for d, extra in fills:
        out.append("  <path d=\"%s\" %s/>" % (d, extra.replace("CURRENTFILL", ink)))
    out.append("  <g %s>" % (G % ORANGE))
    for d, extra in orange:
        out.append('    <path d="%s"%s/>' % (d, (" " + extra) if extra else ""))
    out.append("  </g>")
    return "\n".join(out)


def main():
    os.makedirs(NOTES, exist_ok=True)
    ids = [i[0] for i in ICONS]
    assert len(ids) == len(set(ids)), "duplicate icon id"

    # 1. standalone files (graphite resolved to hex)
    for ic in ICONS:
        p = os.path.join(OUT, "wr-ico-%s.svg" % ic[0])
        svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" '
               'viewBox="0 0 24 24" role="img" aria-label="%s">\n%s\n</svg>\n'
               % (ic[1].replace("&", "and"), body(ic, INK)))
        open(p, "w", encoding="utf-8", newline="\n").write(svg)

    # 2. sprite (graphite stays currentColor)
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="0" height="0" '
             'style="position:absolute" aria-hidden="true">',
             "<!-- WhisperRoom icon system. 24 grid, 20 live area, 1.8 centred stroke,",
             "     round caps/joins. Graphite = currentColor; #ee6216 marks the one",
             "     element the tool creates or changes. Generated - see",
             "     .forge/builder-icons/HANDOFF.md -->",
             "  <defs>"]
    for ic in ICONS:
        parts.append('    <symbol id="wr-%s" viewBox="0 0 24 24"><title>%s</title>'
                     % (ic[0], ic[1].replace("&", "and")))
        parts.append("\n".join("  " + l for l in body(ic, "currentColor").splitlines()))
        parts.append("    </symbol>")
    parts += ["  </defs>", "</svg>", ""]
    open(os.path.join(OUT, "wr-icons.svg"), "w", encoding="utf-8", newline="\n").write("\n".join(parts))

    # 3. icon map
    open(os.path.join(OUT, "icon-map.json"), "w", encoding="utf-8", newline="\n").write(
        json.dumps({k: MAP[k] for k in sorted(MAP)}, indent=2) + "\n")

    # 4. contact sheet
    contact_sheet()

    # 5. verification
    return verify()


def contact_sheet():
    label = {ic[0]: (ic[1], ic[2]) for ic in ICONS}
    rev = {}
    for f, i in MAP.items():
        rev.setdefault(i, []).append(f)
    sprite = open(os.path.join(OUT, "wr-icons.svg"), encoding="utf-8").read()
    sprite = sprite.replace('width="0" height="0" style="position:absolute"',
                            'width="0" height="0" style="position:absolute;width:0;height:0"')

    def cell(i):
        tools = ", ".join(sorted(x for x in rev.get(i, []) if x not in SKIP_LIBS)) or "-"
        return ("""    <figure class="c">
      <div class="sizes"><svg class="s40"><use href="#wr-%s"/></svg>
        <svg class="s20"><use href="#wr-%s"/></svg></div>
      <figcaption><b>%s</b><span class="t">%s</span>
        <span class="f">%s</span><span class="p %s">%s</span></figcaption>
    </figure>""" % (i, i, i, label[i][0], tools, label[i][1], label[i][1]))

    secs = []
    for name, members in CATEGORY:
        secs.append('  <section><h2>%s</h2><div class="grid">\n%s\n  </div></section>'
                    % (name, "\n".join(cell(i) for i in members)))

    pair = """  <section class="pair"><h2>Hard case &mdash; the dimension pair at 20&nbsp;px</h2>
    <p>Benton has run the wrong one of these by mistake. Solid booth + door return + name
    badge + one string, against dashed marquee + irregular blob + two-axis string.</p>
    <div class="prow">
      <div><svg class="s20"><use href="#wr-dim-booth"/></svg>
        <svg class="s20"><use href="#wr-dim-selection"/></svg>
        <svg class="s20"><use href="#wr-dim-room"/></svg><br><small>20 px</small></div>
      <div><svg class="s40"><use href="#wr-dim-booth"/></svg>
        <svg class="s40"><use href="#wr-dim-selection"/></svg>
        <svg class="s40"><use href="#wr-dim-room"/></svg><br><small>40 px</small></div>
    </div>
    <div class="prow"><div><svg class="s20"><use href="#wr-scenes-export"/></svg>
      <svg class="s20"><use href="#wr-view-export"/></svg><br>
      <small>sanctioned plural/singular pair: export the plates vs export this view</small></div></div>
  </section>"""

    html = """<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>WhisperRoom icon contact sheet</title>
<style>
  :root{ --bg:#f2f3f4; --sur:#fff; --ink:#20262a; --mut:#68737b; --line:#dfe3e6; }
  *{box-sizing:border-box}
  body{margin:0;padding:24px;background:var(--bg);color:var(--ink);
    font:13px/1.45 "Segoe UI",system-ui,sans-serif}
  h1{font-size:19px;margin:0 0 4px} h2{font-size:12px;letter-spacing:.09em;
    text-transform:uppercase;color:var(--mut);margin:26px 0 10px;
    border-bottom:1px solid var(--line);padding-bottom:5px}
  .lede{color:var(--mut);max-width:70ch;margin:0 0 8px}
  .grid{display:grid;gap:10px;grid-template-columns:repeat(auto-fill,minmax(210px,1fr))}
  .c{margin:0;background:var(--sur);border:1px solid var(--line);border-radius:6px;
    padding:10px;display:flex;gap:10px;align-items:flex-start}
  .sizes{display:flex;align-items:center;gap:8px;flex:0 0 auto}
  .s40{width:40px;height:40px;color:var(--ink)} .s20{width:20px;height:20px;color:var(--ink)}
  figcaption{display:flex;flex-direction:column;gap:1px;min-width:0}
  figcaption b{font-size:11.5px;font-family:Consolas,monospace}
  .t{color:var(--ink);font-size:11.5px} .f{color:var(--mut);font-size:10.5px;
    font-family:Consolas,monospace;word-break:break-all}
  .p{font-size:9px;letter-spacing:.08em;text-transform:uppercase;align-self:flex-start;
    border:1px solid var(--line);border-radius:4px;padding:0 4px;margin-top:3px;color:var(--mut)}
  .p.authored{border-color:#ee6216;color:#ee6216}
  .p.revised{border-color:#b0771f;color:#b0771f}
  .pair{background:var(--sur);border:1px solid var(--line);border-radius:6px;padding:14px}
  .pair h2{margin-top:0} .pair p{color:var(--mut);max-width:66ch}
  .prow{display:flex;gap:34px;align-items:flex-end;margin-top:10px}
  .prow div{display:flex;flex-direction:column;gap:6px} .prow small{color:var(--mut)}
  .themes{display:flex;gap:0;margin-top:24px;border:1px solid var(--line);border-radius:6px;
    overflow:hidden}
  .themes>div{flex:1;padding:14px;display:flex;gap:12px;flex-wrap:wrap;align-items:center}
  .lt{background:#f2f3f4;color:#20262a} .dk{background:#24292d;color:#e7eaec}
</style></head><body>
<h1>WhisperRoom icon system &mdash; contact sheet</h1>
<p class="lede">Every icon at 40&nbsp;px and 20&nbsp;px, grouped by the category it serves,
labelled with its id, its tool, and whether it was extracted from the approved mockup,
revised against the Researcher's brief, or newly authored. Graphite is
<code>currentColor</code>; the single orange element is what the tool creates or changes.
Nothing here has been eyeballed by a human yet &mdash; that is what this page is for.</p>
__SPRITE__
__SECTIONS__
__PAIR__
<h2>Light and dark, every icon at 20&nbsp;px</h2>
<div class="themes">
  <div class="lt">__STRIP__</div>
  <div class="dk">__STRIP__</div>
</div>
</body></html>"""
    strip = "".join('<svg class="s20"><use href="#wr-%s"/></svg>' % i[0] for i in ICONS)
    html = (html.replace("__SPRITE__", sprite)
                .replace("__SECTIONS__", "\n".join(secs))
                .replace("__PAIR__", pair)
                .replace("__STRIP__", strip))
    open(os.path.join(NOTES, "contact-sheet.html"), "w", encoding="utf-8", newline="\n").write(html)


_TOK = re.compile(r'([MmLlHhVvCcSsQqTtAaZz])|(-?\d*\.?\d+(?:e-?\d+)?)')
# args consumed per command, and which arg pairs are (x,y) points
_SPEC = {"M": (2, [(0, 1)]), "L": (2, [(0, 1)]), "H": (1, []), "V": (1, []),
         "C": (6, [(0, 1), (2, 3), (4, 5)]), "S": (4, [(0, 1), (2, 3)]),
         "Q": (4, [(0, 1), (2, 3)]), "T": (2, [(0, 1)]),
         "A": (7, [(5, 6)]), "Z": (0, [])}


def trace(d):
    """Return every anchor/control point of a path in absolute user units.

    Control points bound the true curve from outside, so this is a safe
    (conservative) bounding set rather than an exact one.
    """
    toks = [(c, n) for c, n in _TOK.findall(d)]
    i, cmd, cur, start, pts = 0, None, (0.0, 0.0), (0.0, 0.0), []
    nums = []
    seq = []
    for c, n in toks:
        seq.append(("c", c) if c else ("n", float(n)))
    i = 0
    while i < len(seq):
        if seq[i][0] == "c":
            cmd = seq[i][1]; i += 1
        elif cmd is None:
            raise ValueError("path starts with a number: " + d)
        up = cmd.upper(); rel = cmd.islower()
        cnt, pairs = _SPEC[up]
        args = []
        for _ in range(cnt):
            if i >= len(seq) or seq[i][0] != "n":
                raise ValueError("short arg list for %s in %s" % (cmd, d))
            args.append(seq[i][1]); i += 1
        if up == "Z":
            cur = start
        elif up == "H":
            cur = (cur[0] + args[0] if rel else args[0], cur[1]); pts.append(cur)
        elif up == "V":
            cur = (cur[0], cur[1] + args[0] if rel else args[0]); pts.append(cur)
        else:
            for a, b in pairs:
                p = (cur[0] + args[a], cur[1] + args[b]) if rel else (args[a], args[b])
                pts.append(p)
            last = pairs[-1]
            cur = (cur[0] + args[last[0]], cur[1] + args[last[1]]) if rel \
                else (args[last[0]], args[last[1]])
            if up == "M":
                start = cur
        # implicit repeats: a bare number list after M means L, otherwise same cmd
        if up == "M" and i < len(seq) and seq[i][0] == "n":
            cmd = "l" if rel else "L"
    return pts or [(12.0, 12.0)]


def verify():
    bad = []
    log = []
    ns = "{http://www.w3.org/2000/svg}"
    files = ["wr-ico-%s.svg" % i[0] for i in ICONS] + ["wr-icons.svg"]
    for f in files:
        p = os.path.join(OUT, f)
        txt = open(p, encoding="utf-8").read()
        try:
            ET.parse(p)
        except Exception as e:
            bad.append("%s: XML parse failed: %s" % (f, e)); continue
        n = txt.count('stroke="%s"' % ORANGE)
        expect = len(ICONS) if f == "wr-icons.svg" else 1
        if n != expect:
            bad.append("%s: %d orange groups, expected %d" % (f, n, expect))
        for vb in re.findall(r'viewBox="([^"]+)"', txt):
            if vb != "0 0 24 24":
                bad.append("%s: viewBox %s" % (f, vb))
        for sw in set(re.findall(r'stroke-width="([^"]+)"', txt)):
            if sw not in ("1.8", "1.4", "1.2"):
                bad.append("%s: stroke-width %s" % (f, sw))
    # sprite ids vs map
    sprite = open(os.path.join(OUT, "wr-icons.svg"), encoding="utf-8").read()
    sym = set(re.findall(r'<symbol id="wr-([a-z0-9-]+)"', sprite))
    for f, i in MAP.items():
        if i not in sym:
            bad.append("icon-map: %s -> wr-%s missing from sprite" % (f, i))
    # every script covered
    scripts = sorted(x for x in os.listdir(os.path.join(ROOT, "scripts")) if x.endswith(".rb"))
    for s in scripts:
        if s not in MAP:
            bad.append("icon-map: script %s not covered" % s)
    for k in MAP:
        if k not in scripts:
            bad.append("icon-map: %s is not a script in scripts/" % k)
    # collisions among real (non-library) tools
    seen = {}
    for f, i in sorted(MAP.items()):
        if f in SKIP_LIBS:
            continue
        if i in seen:
            bad.append("COLLISION: %s and %s both use wr-%s" % (seen[i], f, i))
        seen[i] = f
    # geometry bounds: trace every path, all points must sit in the 2..22 live area
    for ic in ICONS:
        pts = []
        for d, _ in ic[3] + ic[4]:
            pts += trace(d)
        xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
        lo, hi = min(xs + ys), max(xs + ys)
        if lo < 1.999 or hi > 22.001:
            bad.append("%s: geometry %.2f..%.2f leaves the 2..22 live area "
                       "(x %.2f..%.2f, y %.2f..%.2f)"
                       % (ic[0], lo, hi, min(xs), max(xs), min(ys), max(ys)))
        else:
            log.append("  %-19s live area ok  x %.1f..%.1f  y %.1f..%.1f"
                       % (ic[0], min(xs), max(xs), min(ys), max(ys)))
    log.append("icons: %d   standalone files: %d   scripts mapped: %d/%d"
               % (len(ICONS), len(ICONS), len(MAP), len(scripts)))
    log.append("distinct icons across %d runnable scripts: %d"
               % (len(seen), len(set(seen))))
    print("\n".join(log))
    if bad:
        print("\nFAIL:"); print("\n".join(" - " + b for b in bad)); return 1
    print("\nOK: all checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
