"""Headless-Chrome acceptance test for the Draw floor plan dialog (1.72.0).

    python .forge/builder/floorplan-uitest.py          # prints PASS/FAIL lines
    python .forge/builder/floorplan-uitest.py shot     # also saves a screenshot

Copies scripts/build-room.html into a temp folder with a stubbed
window.sketchup ahead of the dialog's script and a DOM-level scenario after
it: 12'-0" x 5'-6", hover + click the north wall, drag the door (whole-inch
snap, corner clamp), width 36, Rotate door x4 (state returns), R key, Build
(payload: runs as drawn with NO N/S flip, swing + placed on the door), typed
offset, Delete, WR_setMode. Replaces build-room-uitest.py, which tested the
old two-mode dialog. Exit 1 on any FAIL."""
import io, os, re, subprocess, sys, html, tempfile

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(REPO, 'scripts', 'build-room.html')
HERE = tempfile.mkdtemp(prefix='floorplan-uitest-')
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

STUB = r'''<script>
window.__errs=[]; window.__calls=[];
window.addEventListener("error",function(e){__errs.push("error: "+e.message+" @"+e.lineno);});
(function(){var ce=console.error;console.error=function(){__errs.push("console.error: "+[].join.call(arguments," "));ce.apply(console,arguments);};})();
window.sketchup={
  ready:function(){__calls.push(["ready"]);},
  build:function(json){__calls.push(["build",json]);},
  cancel:function(){__calls.push(["cancel"]);}
};
</script>
'''

TEST = r'''<script>
(function(){
  var log=[]; function ok(c,m){log.push((c?"PASS ":"FAIL ")+m);}
  var sv=document.getElementById("sv");
  function client(x,y){var p=sv.createSVGPoint();p.x=x;p.y=y;var q=p.matrixTransform(sv.getScreenCTM());return [q.x,q.y];}
  function pe(type,target,x,y,extra){var c=client(x,y);var o={bubbles:true,cancelable:true,clientX:c[0],clientY:c[1],pointerId:1,pointerType:"mouse",isPrimary:true};
    for(var k in (extra||{}))o[k]=extra[k];
    var E=type==="click"?MouseEvent:PointerEvent; target.dispatchEvent(new E(type,o));}
  function type(id,v){var f=document.getElementById(id);f.focus();f.value=v;f.dispatchEvent(new Event("input",{bubbles:true}));document.activeElement.blur();}
  function key(k,extra){var o={key:k,bubbles:true};for(var x in (extra||{}))o[x]=extra[x];document.dispatchEvent(new KeyboardEvent("keydown",o));}
  try{
    ok(__calls.length&&__calls[0][0]==="ready","sketchup.ready() called on load");
    type("slen","12'-0\""); type("swid","5'-6\"");
    var dims=[].map.call(document.querySelectorAll(".dimtxt"),function(t){return t.textContent;});
    ok(dims.join("|")==="12'-0\"|5'-6\"|12'-0\"|5'-6\"","plan dims read 12'-0\" x 5'-6\": "+dims.join("|"));
    // wall 0 is the TOP edge of the preview (y=0, screen-up = north)
    var hit0=document.querySelector('.w-hit[data-wall="0"]');
    var bb=hit0.getBBox();
    ok(Math.abs(bb.y+bb.height/2)<0.5,"run 0 is drawn along y=0, the top (north) edge");
    // hover -> ghost + tooltip
    pe("pointermove",document.querySelector('.w-hit[data-wall="0"]'),54,0);
    ok(!!document.querySelector("g.ghost"),"hover on north wall shows a ghost door");
    ok(document.getElementById("tip").classList.contains("on")&&/click to add/.test(document.getElementById("tip").textContent),"tooltip: "+document.getElementById("tip").textContent);
    // click -> door at 36
    pe("click",document.querySelector('.w-hit[data-wall="0"]'),54,0);
    var off=document.getElementById("doff");
    ok(off&&off.value==="3'-0\"","click at x=54 drops a 36\" door at 3'-0\" (field "+(off&&off.value)+")");
    ok(/north wall/.test(document.getElementById("insp").textContent),"inspector names the north wall");
    ok(/placed by eye/i.test(document.getElementById("insp").textContent),"badge PLACED BY EYE");
    // drag 54 -> 66.4 (snaps to whole inch)
    var dh=document.querySelector('.door-hit[data-door="0"]');
    pe("pointerdown",dh,54,0); pe("pointermove",sv,60,0); pe("pointermove",sv,66.4,0); pe("pointerup",sv,66.4,0); pe("click",sv,66.4,0);
    off=document.getElementById("doff");
    ok(off&&off.value==="4'-0\"","drag moves the door to 4'-0\" in whole inches (field "+(off&&off.value)+")");
    ok(!document.getElementById("insp").hidden,"door stays selected after drag");
    // drag clamps 1" short of the corner
    dh=document.querySelector('.door-hit[data-door="0"]');
    pe("pointerdown",dh,66,0); pe("pointermove",sv,500,0); pe("pointerup",sv,500,0); pe("click",sv,500,0);
    ok(document.getElementById("doff").value==="8'-11\"","drag past the corner clamps to 144-36-1 = 8'-11\" ("+document.getElementById("doff").value+")");
    dh=document.querySelector('.door-hit[data-door="0"]');
    pe("pointerdown",dh,125,0); pe("pointermove",sv,125-(107-48),0); pe("pointerup",sv,0,0); pe("click",sv,0,0);
    ok(document.getElementById("doff").value==="4'-0\"","dragged back to 4'-0\" ("+document.getElementById("doff").value+")");
    // width 36
    var dw=document.getElementById("dw"); dw.focus(); dw.value="36"; dw.dispatchEvent(new Event("input",{bubbles:true}));
    ok(document.getElementById("dw").value==="36","width field keeps typed 36 while focused");
    document.activeElement.blur();
    // rotate x4
    var seen=[document.getElementById("drot-e").textContent];
    for(var k=0;k<4;k++){document.getElementById("drot").click();seen.push(document.getElementById("drot-e").textContent);}
    ok(seen[0]==="hinge W jamb \u00b7 opens in","start state: "+seen[0]);
    ok(seen[4]===seen[0],"4 rotations return to start: "+seen.join(" > "));
    ok(new Set(seen.slice(0,4)).size===4,"4 distinct states");
    // leaf goes outside for an 'out' state (screen y < 0 is outside the north wall)
    document.getElementById("drot").click(); document.getElementById("drot").click();   // -> far/out
    var lbl=document.getElementById("drot-e").textContent;
    var paths=[].filter.call(document.querySelectorAll("g.sel path"),function(){return true;});
    var leaf=paths[paths.length-2].getAttribute("d");
    var ys=leaf.match(/-?\d+(\.\d+)?/g).map(Number);
    ok(/opens out/.test(lbl)&&ys[1]<0&&ys[3]<0,"outward state draws the leaf outside the north wall ("+lbl+"; leaf "+leaf+")");
    // R key cycles too
    key("r"); key("r");
    ok(document.getElementById("drot-e").textContent===seen[0],"R key x2 continues the cycle back to start");
    // R inside a field does nothing
    var dwf=document.getElementById("dw"); dwf.focus(); key("r"); document.activeElement.blur();
    ok(document.getElementById("drot-e").textContent===seen[0],"R typed inside a field is ignored");
    // Build with placed door (warn, not block)
    var go=document.getElementById("go");
    ok(!go.disabled,"Build enabled with a placed-by-eye door (warn, not block)");
    ok(/placed by eye/.test(document.getElementById("hint").textContent)&&document.getElementById("hint").classList.contains("warn"),"footer warns: "+document.getElementById("hint").textContent);
    go.click();
    var b=__calls.filter(function(c){return c[0]==="build";});
    var pl=b.length?JSON.parse(b[0][1]):null;
    var want={mode:"detail",name:"Room",runs:[{d:"E",v:144},{d:"S",v:66},{d:"W",v:144},{d:"N",v:66}],
      doors:[{run:0,at:48,w:36,hinge:"near",swing:"in",placed:true}],thick:4,ceil:96,door_h:80};
    ok(pl&&JSON.stringify(pl)===JSON.stringify(want),"payload: "+(b.length?b[0][1]:"none"));
    // rotate to out and typed offset -> placed dropped, swing out
    document.getElementById("drot").click(); document.getElementById("drot").click();
    type("doff","3'0");
    ok(/typed/i.test(document.getElementById("insp").textContent),"typing the offset flips the badge to TYPED");
    go.click(); b=__calls.filter(function(c){return c[0]==="build";});
    var pl2=JSON.parse(b[1][1]);
    ok(JSON.stringify(pl2.doors)==='[{"run":0,"at":36,"w":36,"hinge":"far","swing":"out"}]',"second build doors: "+JSON.stringify(pl2.doors));
    // Delete
    key("Delete");
    ok(document.querySelectorAll(".door-hit").length===0,"Delete removes the selected door");
    // WR_setMode
    WR_setMode("detail"); ok(document.getElementById("more").open,"WR_setMode(detail) opens More");
    WR_setMode("simple"); ok(!document.getElementById("more").open,"WR_setMode(simple) closes it");
    // plain rectangle payload
    go.click(); b=__calls.filter(function(c){return c[0]==="build";});
    ok(b[2][1]==='{"mode":"simple","name":"Room","runs":[{"d":"E","v":144},{"d":"S","v":66},{"d":"W","v":144},{"d":"N","v":66}],"doors":[],"thick":4,"ceil":96,"door_h":80}',"rectangle payload: "+b[2][1]);
  }catch(e){ log.push("FAIL exception: "+e.message+"\n"+e.stack); }
  __errs.forEach(function(e){log.push("FAIL js error: "+e);});
  if(!__errs.length)log.push("PASS no JS errors");
  var pre=document.createElement("pre"); pre.id="RESULT"; pre.textContent=log.join("\n"); document.body.appendChild(pre);
})();
</script>
'''

src = io.open(SRC, encoding='utf-8').read()
i = src.index('<script>')
out = src[:i] + STUB + src[i:]
j = out.rindex('</body>')
out = out[:j] + TEST + out[j:]
test_path = os.path.join(HERE, 'shipped-test.html')
io.open(test_path, 'w', encoding='utf-8').write(out)

prof = os.path.join(HERE, 'chrome-prof')
r = subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--no-first-run',
                    '--user-data-dir=' + prof, '--window-size=1280,800',
                    '--virtual-time-budget=3000', '--dump-dom',
                    'file:///' + test_path.replace('\\', '/')],
                   capture_output=True, timeout=90)
dom = r.stdout.decode('utf-8', 'replace')
m = re.search(r'<pre id="RESULT">([\s\S]*?)</pre>', dom)
res = html.unescape(m.group(1)) if m else 'FAIL no result\n' + dom[-2000:]
print(res)
if len(sys.argv) > 1:
    shot = os.path.join(HERE, 'shipped.png')
    subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--no-first-run',
                    '--user-data-dir=' + prof, '--window-size=1100,700',
                    '--virtual-time-budget=3000', '--screenshot=' + shot,
                    'file:///' + test_path.replace('\\', '/')], capture_output=True, timeout=90)
    print('shot', shot)
sys.exit(1 if 'FAIL' in res else 0)
