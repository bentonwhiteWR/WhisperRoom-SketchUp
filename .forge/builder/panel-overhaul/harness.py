# Builder's runner for the Scoper's panel harness. Renders the REAL
# scripts/wr_tools/panel.html in headless Chrome with a payload shaped like
# main.rb#payload, at 330 / 430 / 520 wide, into .forge/builder/panel-overhaul/.
#
#   python .forge/scoper/panel-harness/scan.py      # refresh scripts.json first
#   python .forge/builder/panel-overhaul/harness.py [slice-tag]
#
# Every stubbed sketchup.* call is recorded in window.__CALLS so a DOM dump can
# prove which callback a click reached. "measure" states append a <pre id="__m">
# with offsetTop of the first row / tile and the scroll width, then dump the DOM.
import json, os, glob, re, subprocess, sys
ROOT = "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp"
WT = ROOT + "/scripts/wr_tools"
SP = ROOT + "/.forge/scoper/panel-harness"
OUT = ROOT + "/.forge/builder/panel-overhaul"
TAG = sys.argv[1] if len(sys.argv) > 1 else "s"
CH = "C:/Program Files/Google/Chrome/Application/chrome.exe"

scripts = json.load(open(SP + "/scripts.json"))
defaults = json.load(open(WT + "/defaults.json"))
PIN_N = 6; SLOT_N = 18
BARS = [{'key': 'w', 'name': 'WhisperRoom', 'label': 'WhisperRoom'},
        {'key': 'v', 'name': 'WhisperRoom V-Ray', 'label': 'V-Ray'},
        {'key': 't', 'name': 'WhisperRoom Tech', 'label': 'Tech'}]
FAV_ICONS = {'save-scene-components.rb': 'scenecomps', 'build-booth-components.rb': 'boothbuild',
             'booth-from-link.rb': 'boothlink', 'elevation-export.rb': 'elevation',
             'angled-component-art.rb': 'angled'}

def pad(l):
    l = [v if v else '-' for v in l[:SLOT_N]]; return l + ['-'] * (SLOT_N - len(l))
slots = pad(defaults['slots'].split('|')); slot_icons = pad(defaults['slot_icons'].split('|'))
def blank(v): return v in (None, '', '-')
def icon_file(i):
    bare = re.sub(r'^wr-', '', i)
    for p in ["ico-%s.svg" % i, "wr-ico-%s.svg" % bare, "icon-%s.svg" % i]:
        if os.path.exists(WT + "/" + p): return p
def face(i, names, icons):
    if not blank(icons[i]):
        p = icon_file(icons[i])
        if p: return p
    if not blank(names[i]) and names[i] in FAV_ICONS and os.path.exists(WT + "/icon-%s.svg" % FAV_ICONS[names[i]]):
        return "icon-%s.svg" % FAV_ICONS[names[i]]
    return "icon-fav-%s%d.svg" % (BARS[i // PIN_N]['key'], i % PIN_N + 1)
URL = "file:///" + WT + "/"
faces = [URL + face(i, slots, slot_icons) for i in range(SLOT_N)]
def pretty(s): return " ".join(w.capitalize() for w in s.replace('-', ' ').split())
labels = {}
for line in open(WT + "/ico-labels.txt", encoding="utf-8"):
    if '\t' in line:
        k, v = line.rstrip('\n').split('\t', 1); labels[k] = v
lib = []
for p in sorted(glob.glob(WT + "/wr-ico-*.svg")):
    b = os.path.basename(p); i = "wr-" + b[7:-4]
    lib.append({'id': i, 'label': labels.get(i) or pretty(i[3:]), 'file': URL + b, 'wr': True})
for p in sorted(glob.glob(WT + "/ico-*.svg")):
    b = os.path.basename(p); i = b[4:-4]
    lib.append({'id': i, 'label': labels.get(i) or pretty(i), 'file': URL + b, 'wr': False})
ON = {'dimension-booth.rb', 'proposal-scenes.rb'}
abils = [{'id': 'ghost', 'label': 'Reference geometry',
          'blurb': 'Show the ghost parts and leader lines every script draws for reference - tubes, housings, explode leaders, notes.',
          'settings': [], 'builtin': True, 'cat': 'Add dimensions', 'icon': 'wr-ghost', 'on_now': False, 'values': {}}]
for s in scripts:
    a = s['ability']
    if not a: continue
    a = dict(a)
    a.update({'id': s['name'], 'file': s['file'], 'script': s['title'], 'builtin': False, 'cat': s['cat'],
              'icon': s['icon'], 'shelf': s['shelf'], 'on_now': s['name'] in ON,
              'values': {st['key']: st['default'] for st in a['settings']}})
    abils.append(a)
RECENT = ['wr-mode.rb', 'export-scenes.rb', 'proposal-package.rb', 'auto-dimension.rb', 'booth-from-link.rb']

def payload(update=None, note=None, dev=False, collapsed=(), recent=RECENT, bundled=False,
            can_update=True, compact=False):
    return {'dir': ROOT + "/scripts", 'bundled': bundled, 'version': '1.19.3', 'update': update,
            'can_update': can_update, 'sprite': open(WT + "/wr-icons.svg", encoding='utf-8').read(),
            'collapsed': list(collapsed), 'dev': dev, 'compact': compact,
            'scripts': scripts, 'abilities': abils, 'recent': list(recent),
            'pinned': [n for n in slots if not blank(n)], 'note': note,
            'slots': slots, 'slot_icons': slot_icons, 'icons': lib, 'pin_n': PIN_N,
            'bars': [{'name': b['name'], 'label': b['label']} for b in BARS],
            'slot_n': SLOT_N, 'bound_faces': faces, 'bound': slots, 'pending': []}

panel = open(WT + "/panel.html", encoding='utf-8').read()
CALLBACKS = ["ready", "rescan", "update", "run", "pin", "rename", "setslot", "buildlink", "ability",
             "setting", "collapse", "devtools", "shopdefaults", "folder", "console", "uipref"]
MEASURE = ("var m=document.createElement('pre');m.id='__m';"
           "var r=document.querySelector('#scroll .row');var t=document.querySelector('#scroll .tile');"
           "var sc=document.getElementById('scroll');"
           "function H(sel){var e=document.querySelector(sel);return e?Math.round(e.getBoundingClientRect().height*10)/10:null;}"
           "function T(sel){var e=document.querySelector(sel);return e?Math.round(e.getBoundingClientRect().top*10)/10:null;}"
           "m.textContent=JSON.stringify({firstRow:r?r.getBoundingClientRect().top:null,"
           "firstTile:t?t.getBoundingClientRect().top:null,rowH:r?r.getBoundingClientRect().height:null,"
           "tileH:t?t.getBoundingClientRect().height:null,"
           "bands:{top:H('.top'),cmd:H('.cmd'),tabs:H('.tabs'),upd:H('.upd'),state:H('.statebar'),sect:H('#scroll .sect'),sectTop:T('#scroll .sect')},"
           "docW:document.documentElement.scrollWidth,winW:window.innerWidth,bodyW:document.body.clientWidth,"
           "scrollW:sc.scrollWidth,scrollClientW:sc.clientWidth,"
           "optgroups:Array.prototype.map.call(document.querySelectorAll('#edscript optgroup'),function(o){return o.label;}),"
           "trace:window.__T||null,calls:window.__CALLS});document.body.appendChild(m);")

# Headless Chrome on Windows will not make a window narrower than ~500 px, so
# --window-size lies below that. The dialog size is forced on the document
# instead; html is positioned so the popover and the sheets, which are
# position:absolute against the viewport in the real dialog, hang off the same
# box here. The capture is then cropped to the dialog.
def stub(pl, after, w, h, theme):
    fns = ",".join("%s:function(){window.__CALLS.push(['%s'].concat(Array.prototype.slice.call(arguments)));%s}"
                   % (c, c, "window.WR.render(window.__PAYLOAD);" if c == "ready" else "") for c in CALLBACKS)
    return ("<style>html{width:%dpx !important;height:%dpx !important;position:relative;overflow:hidden}"
            "body{width:%dpx !important;height:%dpx !important}</style>\n"
            "<script>\ndocument.documentElement.setAttribute('data-theme','%s');"
            "window.__CALLS=[];window.__PAYLOAD=%s;\nwindow.sketchup={%s};\n"
            "window.addEventListener('load',function(){setTimeout(function(){%s},50);});\n</script>\n"
            % (w, h, w, h, theme, json.dumps(pl), fns, after))

def harness(name, pl, after="", w=430, h=640, theme="light"):
    html = panel.replace("<script>\n(function () {", stub(pl, after, w, h, theme) + "<script>\n(function () {", 1)
    assert html != panel
    p = "%s/h-%s.html" % (OUT, name)
    open(p, "w", encoding='utf-8').write(html); return p

def shot(f, w, h, o):
    path = "%s/%s" % (OUT, o)
    subprocess.run([CH, "--headless=new", "--disable-gpu", "--no-first-run", "--hide-scrollbars",
                    "--virtual-time-budget=3000", "--window-size=%d,%d" % (max(w, 600), h),
                    "--screenshot=%s" % path, "file:///" + f], capture_output=True, timeout=90)
    ok = os.path.exists(path)
    if ok:
        try:
            from PIL import Image
            im = Image.open(path); im.crop((0, 0, w, h)).save(path)
        except ImportError:
            pass
    print("%-44s %s" % (o, "ok" if ok else "MISSING"))

def dump(f, w, h):
    r = subprocess.run([CH, "--headless=new", "--disable-gpu", "--no-first-run", "--virtual-time-budget=3000",
                        "--window-size=%d,%d" % (max(w, 600), h), "--dump-dom", "file:///" + f],
                       capture_output=True, timeout=90, text=True, encoding="utf-8", errors="replace")
    m = re.search(r'<pre id="__m">(.*?)</pre>', r.stdout, re.S)
    return json.loads(m.group(1).replace("&quot;", '"').replace("&amp;", "&")) if m else {"error": r.stdout[-400:]}

def q(term):
    return "var q=document.getElementById('q');q.value=%s;q.dispatchEvent(new Event('input'));" % json.dumps(term)

CLIENT = "document.querySelector('#tabs [data-tab=client]').click();"
MENU = "var b=document.getElementById('more');if(b)b.click();"
LINK = q("https://whisperroom.com/booth-builder#3=abcdefghijk")

STATES = [
    # name, payload kwargs, after-script, width, height, theme
    ("430-update", dict(update="1.19.4"), "", 430, 640, "light"),
    ("330-update", dict(update="1.19.4"), "", 330, 640, "light"),
    ("520-update", dict(update="1.19.4"), "", 520, 640, "light"),
    ("430-full-list", dict(), "", 430, 2600, "light"),
    ("430-search-csusb", dict(), q("csusb"), 430, 640, "light"),
    ("430-link-3", dict(), LINK, 430, 640, "light"),
    ("430-client", dict(update="1.19.4"), CLIENT, 430, 640, "light"),
    ("430-menu", dict(update="1.19.4"), MENU, 430, 640, "light"),
    ("330-menu", dict(update="1.19.4"), MENU, 330, 640, "light"),
    ("330-nogit", dict(update="1.19.4", can_update=False, bundled=True), "", 330, 640, "light"),
    ("430-dev-full", dict(dev=True), "", 430, 2600, "light"),
    ("430-compact", dict(update="1.19.4", compact=True), "", 430, 640, "light"),
    ("430-dark", dict(update="1.19.4"), "", 430, 640, "dark"),
    ("430-editor", dict(), "document.querySelector('.slot[data-s]').click();", 430, 640, "light"),
]
PROOF_MENU = (MENU + "document.querySelector('.mi[data-m=rescan]').click();"
              + MENU + "document.querySelector('.mi[data-m=dev]').click();"
              "window.__T=['menuOpenAfterDev',document.getElementById('menu').className,"
              "'devsw',document.getElementById('devsw').getAttribute('aria-checked'),"
              "'devRowsNow',document.querySelectorAll('#scroll .badge-dev').length];"
              "document.querySelector('.mi[data-m=shopdefaults]').click();"
              "window.__T.push('menuAfterShop',document.getElementById('menu').className);"
              + MENU + "document.querySelector('.mi[data-m=folder]').click();"
              + MENU + "document.querySelector('.mi[data-m=console]').click();"
              + MENU + "document.body.dispatchEvent(new MouseEvent('click',{bubbles:true}));"
              "window.__T.push('menuAfterOutsideClick',document.getElementById('menu').className);"
              + MENU + "document.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape'}));"
              "window.__T.push('menuAfterEscape',document.getElementById('menu').className);")
PROOF_UPD = ("window.__T=['updAtStart',document.getElementById('upd').className];"
             "document.getElementById('updx').click();"
             "window.__T.push('afterX',document.getElementById('upd').className,'pill',document.getElementById('ver').className);"
             "document.getElementById('ver').click();"
             "window.__T.push('afterPill',document.getElementById('upd').className);"
             "document.getElementById('updgo').click();"
             "window.__T.push('goText',document.getElementById('updgo').textContent,'goDisabled',document.getElementById('updgo').disabled);")
PROOF_EDITOR = "document.querySelector('.slot[data-s]').click();"
PROOF_LINK = (LINK + "window.__T=['linkgo',document.getElementById('linkgo').style.display];"
              "document.getElementById('linkgo').click();")

PROOF_TILES = ("function rows(){var ys={};Array.prototype.forEach.call(document.querySelectorAll('.tile'),"
               "function(t){ys[Math.round(t.getBoundingClientRect().top)]=1;});return Object.keys(ys).length;}"
               "window.__T=['tiles',document.querySelectorAll('.tile').length,'tileRows',rows(),"
               "'recentChips',document.querySelectorAll('.rc').length,"
               "'pinnedRowsInCats',document.querySelectorAll('#scroll .row').length];"
               "document.querySelector('.tile .un').click();"
               "document.querySelector('.rc').click();"
               "document.querySelector('.tile[data-run]').click();"
               "document.querySelector('.sect[data-sec=Pinned]').click();"
               "window.__T.push('pinnedAfterHeaderClick',document.querySelector('.sect[data-sec=Pinned]').className);"
               + q("csusb") + "window.__T.push('tilesInSearch',document.querySelectorAll('.tile').length,"
               "'recentInSearch',document.querySelectorAll('.rc').length);"
               + q("") + CLIENT + "window.__T.push('tilesOnClient',document.querySelectorAll('.tile').length,"
               "'recentOnClient',document.querySelectorAll('.rc').length);")

PROOF_COMPACT = (MENU + "document.querySelector('.mi[data-m=compact]').click();"
                 "window.__T=['bodyClass',document.body.className,"
                 "'sw',document.getElementById('compactsw').getAttribute('aria-checked'),"
                 "'rowH',document.querySelector('#scroll .row').getBoundingClientRect().height,"
                 "'blurbShown',getComputedStyle(document.querySelector('#scroll .row .b')).display,"
                 "'tipHasBlurb',document.querySelector('#scroll .row').title.split(String.fromCharCode(10)).length>1];"
                 "document.querySelector('.mi[data-m=compact]').click();"
                 "window.__T.push('bodyClassAfter',document.body.className,"
                 "'rowHAfter',document.querySelector('#scroll .row').getBoundingClientRect().height);")

MEASURES = [
    ("p-compact", dict(update="1.19.4"), PROOF_COMPACT, 430),
    ("p-tiles-430", dict(), PROOF_TILES, 430),
    ("p-tiles-330", dict(), PROOF_TILES, 330),
    ("p-tiles-520", dict(), PROOF_TILES, 520),
    ("p-menu", dict(update="1.19.4"), PROOF_MENU, 430),
    ("p-upd", dict(update="1.19.4"), PROOF_UPD, 430),
    ("p-editor", dict(), PROOF_EDITOR, 430),
    ("p-link", dict(), PROOF_LINK, 430),
    ("m-upd-430", dict(update="1.19.4"), "", 430),
    ("m-upd-330", dict(update="1.19.4"), "", 330),
    ("m-upd-520", dict(update="1.19.4"), "", 520),
    ("m-compact-430", dict(update="1.19.4", compact=True), "", 430),
    ("m-search-430", dict(), q("csusb"), 430),
]

if __name__ == "__main__":
    only = sys.argv[2:]   # optional state names to re-run
    for name, kw, after, w, h, theme in STATES:
        if only and name not in only: continue
        f = harness(name, payload(**kw), after=after, w=w, h=h, theme=theme)
        shot(f, w, h, "%s-%s.png" % (TAG, name))
    for name, kw, after, w in MEASURES:
        if only and name not in only: continue
        f = harness(name, payload(**kw), after=after + MEASURE, w=w, h=640)
        print(name, json.dumps(dump(f, w, 640)))
