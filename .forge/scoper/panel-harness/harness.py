# Build harness HTML files that render the REAL panel.html with a fake payload shaped
# like main.rb#payload, then screenshot them in headless Chrome.
import json, os, glob, re, subprocess, sys
ROOT="C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp"
WT=ROOT+"/scripts/wr_tools"; SP=os.path.dirname(os.path.abspath(__file__))
scripts=json.load(open(SP+"/scripts.json"))
defaults=json.load(open(WT+"/defaults.json"))
PIN_N=6; SLOT_N=18
BARS=[{'key':'w','name':'WhisperRoom','label':'WhisperRoom'},{'key':'v','name':'WhisperRoom V-Ray','label':'V-Ray'},{'key':'t','name':'WhisperRoom Tech','label':'Tech'}]
FAV_ICONS={'save-scene-components.rb':'scenecomps','build-booth-components.rb':'boothbuild','booth-from-link.rb':'boothlink','elevation-export.rb':'elevation','angled-component-art.rb':'angled'}
def pad(l):
    l=[v if v else '-' for v in l[:SLOT_N]]; return l+['-']*(SLOT_N-len(l))
slots=pad(defaults['slots'].split('|')); slot_icons=pad(defaults['slot_icons'].split('|'))
def blank(v): return v in (None,'','-')
def icon_file(i):
    bare=re.sub(r'^wr-','',i)
    for p in [f"ico-{i}.svg",f"wr-ico-{bare}.svg",f"icon-{i}.svg"]:
        if os.path.exists(WT+"/"+p): return p
def face(i,names,icons):
    if not blank(icons[i]):
        p=icon_file(icons[i])
        if p: return p
    if not blank(names[i]) and names[i] in FAV_ICONS and os.path.exists(WT+f"/icon-{FAV_ICONS[names[i]]}.svg"):
        return f"icon-{FAV_ICONS[names[i]]}.svg"
    return f"icon-fav-{BARS[i//PIN_N]['key']}{i%PIN_N+1}.svg"
URL="file:///"+WT+"/"
faces=[URL+face(i,slots,slot_icons) for i in range(SLOT_N)]
def pretty(s): return " ".join(w.capitalize() for w in s.replace('-',' ').split())
labels={}
for line in open(WT+"/ico-labels.txt"):
    if '\t' in line: k,v=line.rstrip('\n').split('\t',1); labels[k]=v
lib=[]
for p in sorted(glob.glob(WT+"/wr-ico-*.svg")):
    b=os.path.basename(p); i="wr-"+b[7:-4]; lib.append({'id':i,'label':labels.get(i) or pretty(i[3:]),'file':URL+b,'wr':True})
for p in sorted(glob.glob(WT+"/ico-*.svg")):
    b=os.path.basename(p); i=b[4:-4]; lib.append({'id':i,'label':labels.get(i) or pretty(i),'file':URL+b,'wr':False})
ON={'dimension-booth.rb','proposal-scenes.rb'}
abils=[{'id':'ghost','label':'Reference geometry','blurb':'Show the ghost parts and leader lines every script draws for reference — tubes, housings, explode leaders, notes.','settings':[],'builtin':True,'cat':'Add dimensions','icon':'wr-ghost','on_now':False,'values':{}}]
for s in scripts:
    a=s['ability']
    if not a: continue
    a=dict(a); a.update({'id':s['name'],'file':s['file'],'script':s['title'],'builtin':False,'cat':s['cat'],'icon':s['icon'],'shelf':s['shelf'],'on_now':s['name'] in ON,'values':{st['key']:st['default'] for st in a['settings']}})
    abils.append(a)
def payload(update=None, note=None, dev=False, collapsed=()):
    return {'dir':ROOT+"/scripts",'bundled':False,'version':'1.19.3','update':update,'can_update':True,
     'sprite':open(WT+"/wr-icons.svg",encoding='utf-8').read(),'collapsed':list(collapsed),'dev':dev,
     'scripts':scripts,'abilities':abils,'recent':[],'pinned':[n for n in slots if not blank(n)],'note':note,
     'slots':slots,'slot_icons':slot_icons,'icons':lib,'pin_n':PIN_N,'bars':[{'name':b['name'],'label':b['label']} for b in BARS],
     'slot_n':SLOT_N,'faces':faces,'bound_faces':faces,'bound':slots,'pending':[]}
panel=open(WT+"/panel.html",encoding='utf-8').read()
def harness(name,pl,after=""):
    stub="<script>\nwindow.__PAYLOAD=%s;\nwindow.sketchup={ready:function(){window.WR.render(window.__PAYLOAD);%s},rescan:function(){},run:function(){},pin:function(){},rename:function(){},setslot:function(){},buildlink:function(){},ability:function(){},setting:function(){},collapse:function(){},devtools:function(){},shopdefaults:function(){},folder:function(){},console:function(){},update:function(){}};\n</script>\n" % (json.dumps(pl),after)
    html=panel.replace("<script>\n(function () {",stub+"<script>\n(function () {",1)
    assert html!=panel
    open(f"{SP}/{name}.html","w",encoding='utf-8').write(html); return f"{SP}/{name}.html"
h1=harness("cur-default",payload(update="1.19.4"))
h2=harness("cur-search",payload(),after="var q=document.getElementById('q');q.value='csusb';q.dispatchEvent(new Event('input'));")
h3=harness("cur-tall",payload(update=None))
h4=harness("cur-search2",payload(),after="var q=document.getElementById('q');q.value='wall';q.dispatchEvent(new Event('input'));")
CH="C:/Program Files/Google/Chrome/Application/chrome.exe"
OUT=ROOT+"/.forge/scoper"
shots=[(h1,430,640,"panel-current-430x640.png"),(h3,430,2600,"panel-current-full-list.png"),(h2,430,640,"panel-current-search-csusb.png"),(h4,430,640,"panel-current-search-wall.png"),(h1,330,640,"panel-current-330.png")]
for f,w,h,o in shots:
    subprocess.run([CH,"--headless=new","--disable-gpu","--no-first-run","--virtual-time-budget=3000",f"--window-size={w},{h}",f"--screenshot={OUT}/{o}","file:///"+f],capture_output=True,timeout=90)
    print(o, os.path.exists(f"{OUT}/{o}"), os.path.getsize(f"{OUT}/{o}") if os.path.exists(f"{OUT}/{o}") else 0)
