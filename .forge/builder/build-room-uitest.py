import re, pathlib, sys
src = pathlib.Path(r"C:\Users\bento\OneDrive\Documents\Claude\Sketchup\WhisperRoom-SketchUp\scripts\build-room.html")
out = pathlib.Path(__file__).with_name("test-page.html")
s = src.read_text(encoding="utf-8")

stub = """<script>
window.__calls=[];
window.sketchup={build:function(p){window.__payload=p;window.__calls.push("build");},
                 cancel:function(){window.__calls.push("cancel");},
                 ready:function(){window.__calls.push("ready");}};
</script>
"""
i = s.index("<script>\n(function(){")
s = s[:i] + stub + s[i:]

harness = r"""
<pre id="OUT" style="white-space:pre-wrap;font-size:11px"></pre>
<script>
(function(){
  var L=[], pass=0, fail=0;
  function say(s){L.push(s);}
  function ok(name,cond,extra){ if(cond){pass++;say("PASS  "+name);} else {fail++;say("FAIL  "+name+"   "+(extra||""));} }
  function $(id){return document.getElementById(id);}
  function set(id,val){var e=$(id);e.value=val;e.dispatchEvent(new Event("input",{bubbles:true}));}
  function blur(id){$(id).dispatchEvent(new Event("blur",{bubbles:true}));}
  function click(id){$(id).dispatchEvent(new MouseEvent("click",{bubbles:true}));}
  function hint(){return $("hint").textContent;}
  function payload(){return JSON.parse(window.__payload);}

  // --- 1. opens simple, build works immediately -----------------------------
  ok("opens in simple mode", !$("simple").hidden && $("detail").hidden);
  ok("build enabled on open", $("go").disabled===false);
  ok("ready() called for mode restore", window.__calls.indexOf("ready")>=0, window.__calls.join(","));
  ok("default hint 12x10 ceiling 8", hint()==="12'-0\" \u00d7 10'-0\", ceiling 8'-0\"", hint());

  // --- 2. input formats ------------------------------------------------------
  var fmts=[["150",150],["150\"",150],["12'6\"",150],["12'-6\"",150],["12' 6\"",150],
            ["12.5",12.5],["12.5'",150],["12'",144],["12 1/2",12.5],["12' 6 1/2\"",150.5],
            ["1/2",0.5],["12ft 6in",150],["12\u20326\u2033",150],["12\u2032-6\u2033",150],
            ["  12'6\"  ",150],["12'0\"",144],["0.5",0.5]];
  fmts.forEach(function(f){
    set("slen",f[0]);
    var got=$("slen-e").textContent;
    var want=(function(n){var ft=Math.floor(n/12),i=Math.round((n-ft*12)*10)/10;
      if(i>=12){ft+=1;i-=12;} return ft+"'-"+(i%1===0?i:i.toFixed(1))+'"';})(f[1]);
    ok("parse "+JSON.stringify(f[0])+" -> "+f[1]+"in", got===want, "echo="+got+" want="+want);
  });
  ["abc","","--","1/0x",".."].forEach(function(bad){
    set("slen",bad);
    ok("rejects "+JSON.stringify(bad), $("slen").classList.contains("bad") && $("go").disabled===true,
       "bad="+$("slen").classList.contains("bad")+" goDisabled="+$("go").disabled);
  });
  set("slen","12'-0\""); ok("recovers after bad input", !$("slen").classList.contains("bad") && $("go").disabled===false);

  // blur rewrites the field into the canonical reading
  set("slen","150"); blur("slen");
  ok("blur normalises 150 -> 12'-6\"", $("slen").value==="12'-6\"", $("slen").value);

  // --- 3. simple payload: four runs that close -------------------------------
  set("slen","12'6\""); set("swid","10'3\""); set("sceil","9'");
  click("go");
  var p=payload();
  ok("payload mode simple", p.mode==="simple", p.mode);
  ok("payload no doors", Array.isArray(p.doors)&&p.doors.length===0);
  ok("payload thick 4 (default)", p.thick===4, p.thick);
  ok("payload ceil 108", p.ceil===108, p.ceil);
  ok("payload 4 runs", p.runs.length===4, JSON.stringify(p.runs));
  var DIRSU={E:[1,0],W:[-1,0],N:[0,1],S:[0,-1]};   // SketchUp: y is up
  function closure(rs){var x=0,y=0;rs.forEach(function(r){var v=DIRSU[r.d];x+=v[0]*r.v;y+=v[1]*r.v;});return [x,y];}
  var c=closure(p.runs);
  ok("rectangle closes at zero", Math.abs(c[0])<1e-9&&Math.abs(c[1])<1e-9, JSON.stringify(c));
  ok("runs are E/N/W/S in SketchUp coords",
     p.runs.map(function(r){return r.d;}).join("")==="ENWS", p.runs.map(function(r){return r.d;}).join(""));
  ok("run lengths match typed", p.runs[0].v===150&&p.runs[1].v===123&&p.runs[2].v===150&&p.runs[3].v===123,
     JSON.stringify(p.runs));
  // signed area (shoelace) must be non-zero and equal len*wid
  var pts=[[0,0]],x=0,y=0;
  p.runs.forEach(function(r){var v=DIRSU[r.d];x+=v[0]*r.v;y+=v[1]*r.v;pts.push([x,y]);});
  pts.pop();
  var A=0; for(var k=0;k<pts.length;k++){var j=(k+1)%pts.length;A+=pts[k][0]*pts[j][1]-pts[j][0]*pts[k][1];}
  A/=2;
  ok("signed area = len*wid (CCW, non-degenerate)", Math.abs(A-150*123)<1e-6, "A="+A);

  // --- 4. expand carries the values across ------------------------------------
  click("tomore");
  ok("detail pane shown", $("detail").hidden===false && $("simple").hidden===true);
  var rowVals=[].map.call(document.querySelectorAll("#runs tr"),function(tr){
    return tr.querySelector("select").value+":"+tr.querySelector("input[data-len]").value;});
  ok("expand carried 4 runs across", rowVals.join(" ")==="E:12'-6\" S:10'-3\" W:12'-6\" N:10'-3\"", rowVals.join(" "));
  ok("expand carried ceiling", $("ceil").value==="9'-0\"", $("ceil").value);
  ok("detail wall thickness defaults to 4\"", $("thick").value==='4"', $("thick").value);
  ok("detail has no doors by default", document.querySelectorAll("#doors tr").length===0);
  ok("chain closes card", $("cl").className.indexOf("good")>=0, $("cl").className);
  ok("collapse offered while still a rectangle", $("toless").disabled===false, $("toless").textContent);

  // --- 5. collapse back preserves ---------------------------------------------
  click("toless");
  ok("back to simple", $("simple").hidden===false && $("detail").hidden===true);
  ok("collapse preserved length", $("slen").value==="12'-6\"", $("slen").value);
  ok("collapse preserved width", $("swid").value==="10'-3\"", $("swid").value);
  ok("collapse preserved ceiling", $("sceil").value==="9'-0\"", $("sceil").value);

  // --- 6. collapse is refused on a non-rectangle -------------------------------
  click("tomore"); click("addrun");
  ok("5 runs now", document.querySelectorAll("#runs tr").length===5);
  ok("collapse disabled on non-rectangle", $("toless").disabled===true, $("toless").textContent);
  ok("collapse says why", $("toless").textContent.indexOf("no longer a rectangle")>0, $("toless").textContent);
  ok("build blocked, chain does not close", $("go").disabled===true && hint()==="fix the closure to build", hint());
  // remove it again
  document.querySelectorAll("#runs .x")[4].dispatchEvent(new MouseEvent("click",{bubbles:true}));
  ok("closure restored after removing the run", $("go").disabled===false, hint());
  ok("collapse offered again", $("toless").disabled===false, $("toless").textContent);

  // --- 7. a door blocks collapse rather than being dropped ---------------------
  click("adddoor");
  ok("door added", document.querySelectorAll("#doors tr").length===1);
  ok("collapse disabled with a door", $("toless").disabled===true, $("toless").textContent);
  ok("collapse says remove the door", $("toless").textContent.indexOf("remove the door")>0, $("toless").textContent);

  // --- 8. detail take-off: L-shape, feet-inches typed into runs ----------------
  document.querySelectorAll("#doors .x")[0].dispatchEvent(new MouseEvent("click",{bubbles:true}));
  // rebuild the original demo L: E216 S96 W84 S60 W132 N156
  var want=[["E","18'"],["S","8'"],["W","7'"],["S","5'"],["W","11'"],["N","13'"]];
  while(document.querySelectorAll("#runs tr").length<want.length) click("addrun");
  want.forEach(function(w,i){
    var tr=document.querySelectorAll("#runs tr")[i];
    var sel=tr.querySelector("select"); sel.value=w[0]; sel.dispatchEvent(new Event("change",{bubbles:true}));
    var inp=tr.querySelector("input[data-len]"); inp.value=w[1]; inp.dispatchEvent(new Event("input",{bubbles:true}));
  });
  ok("L-shape take-off closes", $("cl").className.indexOf("good")>=0 && $("go").disabled===false,
     $("cl").textContent);
  ok("collapse refused on the L", $("toless").disabled===true);
  $("nm").value="Studio B"; $("nm").dispatchEvent(new Event("input",{bubbles:true}));
  set("thick","5"); set("ceil","7'-6\"");
  click("go");
  var q=payload();
  ok("detail payload mode", q.mode==="detail", q.mode);
  ok("detail payload name", q.name==="Studio B", q.name);
  ok("detail payload thick 5", q.thick===5, q.thick);
  ok("detail payload ceil 90", q.ceil===90, q.ceil);
  var c2=closure(q.runs);
  ok("L-shape closes at zero in SketchUp coords", Math.abs(c2[0])<1e-9&&Math.abs(c2[1])<1e-9, JSON.stringify(c2));
  ok("N/S flipped on the way out", q.runs.map(function(r){return r.d;}).join("")==="ENWNWS",
     q.runs.map(function(r){return r.d;}).join(""));

  // --- 9. WR_setMode from Ruby ------------------------------------------------
  window.WR_setMode("detail");
  ok("WR_setMode('detail') opens detail", $("detail").hidden===false);
  window.WR_setMode("simple");
  ok("WR_setMode('simple') opens simple", $("simple").hidden===false);
  window.WR_setMode("garbage");
  ok("WR_setMode(garbage) falls back to simple", $("simple").hidden===false);

  // --- 10. a red field in the hidden pane must not block the build -------------
  window.WR_setMode("detail"); set("ceil","zzz");
  ok("bad detail ceiling blocks build", $("go").disabled===true);
  window.WR_setMode("simple");
  ok("switching modes clears the stale red field", $("go").disabled===false && !$("ceil").classList.contains("bad"));

  L.push(""); L.push("RESULT "+pass+" passed, "+fail+" failed");
  document.getElementById("OUT").textContent=L.join("\n");
})();
</script>
"""
s = s.replace("</body>", harness + "</body>")
out.write_text(s, encoding="utf-8")
print(out)
