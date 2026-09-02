# Python port of main.rb meta_of/cat_of/tab_of/shelf_of/icon_of + scan(), to build a
# realistic DATA payload for panel.html without SketchUp.
import os, re, glob, json, sys, time
ROOT = "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp"
D = ROOT + "/scripts"
WT = ROOT + "/scripts/wr_tools"
SKIP = ['wr_tools.rb','wr-booth-data.rb','wr-shading.rb','wr-folder.rb','wr-deck.rb','wr-overlays.rb','wr-roof-vent.rb','wr-bridge-lib.rb','wr-png-srgb.rb']
SHELVES = ['dev','workshop','archive']; TABS=['tools','client']
icon_map = json.load(open(WT+"/icon-map.json"))
def wr_id(s):
    s=(s or "").strip()
    if not s: return None
    if s.startswith("mono:"): return s
    return s if s.startswith("wr-") else "wr-"+s
def pretty(b): return " ".join(w.capitalize() for w in re.sub(r"\.rb$","",b,flags=re.I).replace("-"," ").replace("_"," ").split())
def meta_of(path):
    title=None; blurb=[]; started=False; abil=None; icon=None; rank=None; dialog=False
    for i,line in enumerate(open(path,encoding="utf-8",errors="replace")):
        if i>60: break
        if not re.match(r"^\s*#",line):
            if line.strip()=="": continue
            break
        text=re.sub(r"^\s*#\s?","",line).rstrip()
        m=re.match(r"^@title\s+(.+)$",text)
        if m:
            raw=m.group(1).strip(); dialog=bool(re.search(r"(\.\.\.|…)$",raw)); title=re.sub(r"(\.\.\.|…)$","",raw).strip(); continue
        m=re.match(r"^@icon\s+(\S+)",text)
        if m: icon=m.group(1); continue
        m=re.match(r"^@rank\s+(-?\d+)\s*$",text)
        if m: rank=int(m.group(1)); continue
        def A():
            nonlocal abil
            if abil is None: abil={'label':None,'blurb':'','settings':[],'on':None,'off':None}
        m=re.match(r"^@ability\s+(.+)$",text)
        if m: A(); abil['label']=m.group(1).strip(); continue
        m=re.match(r"^@ability-blurb\s+(.+)$",text)
        if m: A(); abil['blurb']=m.group(1).strip(); continue
        m=re.match(r"^@setting\s+(\S+)\s+(\S+)\s+(\S+)\s*(.*)$",text)
        if m:
            A(); key,kind,dflt,lbl=m.group(1),m.group(2),m.group(3),m.group(4).strip()
            st={'key':key,'kind':kind,'default':dflt,'label':lbl or key,'choices':dflt.split('|') if kind=='choice' else []}
            if kind=='choice': st['default']=dflt.split('|')[0]
            abil['settings'].append(st); continue
        m=re.match(r"^@(on|off)\s+(.+)$",text)
        if m: A(); abil[m.group(1)]=m.group(2).strip(); continue
        if text.startswith("@"): continue
        if text=="":
            if started: break
            continue
        started=True; blurb.append(text)
        if len(" ".join(blurb))>200: break
    if not (abil and abil['label'] and abil['on'] and abil['off']): abil=None
    return title," ".join(blurb),abil,icon,dialog,rank
def hdr(path,key,valid=None,default=None):
    for i,line in enumerate(open(path,encoding="utf-8",errors="replace")):
        if i>60: break
        if not re.match(r"^\s*#",line): continue
        m=re.match(r"^\s*#\s*@"+key+r"\s+(\S+)",line) if key!="cat" else re.match(r"^\s*#\s*@cat\s+(.+)$",line)
        if not m: continue
        v=m.group(1).strip()
        if key=="cat": return v
        v=v.lower()
        if valid: return v if v in valid else default
        return v
    return default
def ago(t):
    s=int(time.time()-t)
    if s<60: return "just now"
    m=s//60
    if m<60: return f"{m} min ago"
    h=m//60
    if h<24: return f"{h} hr ago"
    d=h//24
    if d<30: return f"{d} d ago"
    return f"{round(d/30)} mo ago"
scripts=[]
for p in sorted(glob.glob(D+"/*.rb")):
    n=os.path.basename(p)
    if n in SKIP: continue
    title,blurb,abil,icon,dialog,rank=meta_of(p)
    mt=os.path.getmtime(p)
    scripts.append({'file':p,'name':n,'title':title or pretty(n),'cat':hdr(p,'cat'),
        'shelf':hdr(p,'shelf',SHELVES,None),'tab':hdr(p,'tab',TABS,'tools'),
        'icon':wr_id(icon) or wr_id(icon_map.get(n)) or 'wr-default','dialog':dialog,'rank':rank,
        'blurb':blurb,'ago':ago(mt),'fresh':(time.time()-mt)<24*3600,'stamp':int(mt),'ability':abil})
scripts.sort(key=lambda s:-s['stamp'])
json.dump(scripts,open(os.path.dirname(os.path.abspath(__file__))+"/scripts.json","w"),indent=1)
print(len(scripts),"tools")
from collections import Counter
print("tabs",Counter(s['tab'] for s in scripts))
print("shelves",Counter(s['shelf'] for s in scripts))
print("cats",Counter((s['tab'],s['cat']) for s in scripts))
print("default-icon:",[s['name'] for s in scripts if s['icon']=='wr-default'])
ic=Counter(s['icon'] for s in scripts); print("shared icons:",{k:v for k,v in ic.items() if v>1})
print("abilities:",[s['name'] for s in scripts if s['ability']])
print("dialog:",sum(1 for s in scripts if s['dialog']),"of",len(scripts))
print("no blurb:",[s['name'] for s in scripts if not s['blurb']])
