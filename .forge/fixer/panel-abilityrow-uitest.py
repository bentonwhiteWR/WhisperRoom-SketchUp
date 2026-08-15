# Repro + regression test for the dead ability row.
#
# Symptom: clicking "Dimension the room" (or any of the five ability tools) did
# nothing. abilityRow() emits data-ab; wire() only ever selected .row[data-i].
#
# Builds a standalone page from scripts/wr_tools/panel.html with the sketchup
# bridge stubbed, drives it, and prints PASS/FAIL into <pre id="OUT">.
#
#   python .forge/fixer/panel-abilityrow-uitest.py
#   chrome --headless=new --dump-dom file:///<printed path>
#
# Same approach as .forge/builder/build-room-uitest.py.

import pathlib

src = pathlib.Path(__file__).resolve().parents[2] / "scripts" / "wr_tools" / "panel.html"
out = pathlib.Path(__file__).with_name("panel-test-page.html")
s = src.read_text(encoding="utf-8")

stub = """<script>
window.__calls = [];
window.sketchup = {
  ability:  function (id, on) { window.__calls.push(["ability", id, on]); },
  run:      function (f)      { window.__calls.push(["run", f]); },
  pin:      function (n)      { window.__calls.push(["pin", n]); },
  rename:   function (n, t)   { window.__calls.push(["rename", n, t]); },
  setting:  function (i,k,v)  { window.__calls.push(["setting", i, k, v]); },
  setslot:  function (i,n,c)  { window.__calls.push(["setslot", i, n, c]); },
  collapse: function (l)      { window.__calls.push(["collapse", l]); },
  devtools: function (v)      { window.__calls.push(["devtools", v]); },
  rescan:   function ()       { window.__calls.push(["rescan"]); },
  folder:   function ()       { window.__calls.push(["folder"]); },
  console:  function ()       { window.__calls.push(["console"]); },
  buildlink:function (l)      { window.__calls.push(["buildlink", l]); },
  ready:    function ()       { window.__calls.push(["ready"]); }
};
</script>
"""
i = s.index("<script>\n(function () {")
s = s[:i] + stub + s[i:]

harness = r"""
<pre id="OUT" style="white-space:pre-wrap;font-size:11px"></pre>
<script>
(function () {
  var L = [], pass = 0, fail = 0;
  function ok(name, cond, extra) {
    if (cond) { pass++; L.push("PASS  " + name); }
    else { fail++; L.push("FAIL  " + name + "   " + (extra === undefined ? "" : extra)); }
  }
  function click(el) { el.dispatchEvent(new MouseEvent("click", {bubbles: true})); }
  function calls(kind) {
    return window.__calls.filter(function (c) { return c[0] === kind; });
  }
  function reset() { window.__calls = []; }

  // A payload shaped like the real one: the five ability tools Benton uses,
  // one of them pinned (so it renders twice), one with settings (a gear), and
  // a plain action script alongside so the two row kinds sit in one list.
  var PAYLOAD = {
    dir: "C:/scripts", bundled: false, dev: false, pin_n: 8,
    slots: [], slot_icons: [], bound: [], bound_faces: [], pending: [],
    icons: [], collapsed: [], pinned: ["dim-room.rb"],
    scripts: [
      {name:"dim-room.rb",   file:"C:/s/dim-room.rb",   title:"Dimension the room",
       blurb:"Chain dimensions on every wall run", cat:"Add dimensions", ago:"2h"},
      {name:"dim-booth.rb",  file:"C:/s/dim-booth.rb",  title:"Dimensioned booth",
       blurb:"", cat:"Add dimensions", ago:"3h"},
      {name:"dim-sel.rb",    file:"C:/s/dim-sel.rb",    title:"Dimensioned selection",
       blurb:"", cat:"Add dimensions", ago:"3h"},
      {name:"exploded.rb",   file:"C:/s/exploded.rb",   title:"Exploded",
       blurb:"", cat:"Scenes and images", ago:"1d"},
      {name:"scenes.rb",     file:"C:/s/scenes.rb",     title:"Proposal scenes",
       blurb:"", cat:"Scenes and images", ago:"1d"},
      {name:"build-room.rb", file:"C:/s/build-room.rb", title:"Draw a room",
       blurb:"", cat:"Draw the room", ago:"5m"}
    ],
    // main.rb's abilities(): a script-backed ability carries "file"; the one
    // built-in ("ghost") does not, and the panel draws it as an orphan row.
    // Both kinds are .row[data-ab], so both are in scope here.
    abilities: [
      {id:"ghost", label:"Reference geometry", on_now:false, builtin:true,
       cat:"Add dimensions", settings:[]},
      {id:"dim-room.rb",  file:"C:/s/dim-room.rb",  label:"Room dimensions",
       on_now:false, cat:"Add dimensions",
       settings:[{key:"units", kind:"choice", label:"Units", choices:["ft","in"]}],
       values:{units:"ft"}},
      {id:"dim-booth.rb", file:"C:/s/dim-booth.rb", label:"Booth dimensions", on_now:false},
      {id:"dim-sel.rb",   file:"C:/s/dim-sel.rb",   label:"Selection dimensions", on_now:false},
      {id:"exploded.rb",  file:"C:/s/exploded.rb",  label:"Exploded", on_now:false},
      {id:"scenes.rb",    file:"C:/s/scenes.rb",    label:"Proposal scenes", on_now:false}
    ]
  };
  var ABIL = ["dim-room.rb","dim-booth.rb","dim-sel.rb","exploded.rb","scenes.rb","ghost"];

  window.WR.render(PAYLOAD);

  var $scroll = document.getElementById("scroll");
  function abRows(id) {
    return [].slice.call($scroll.querySelectorAll('.row[data-ab="' + id + '"]'));
  }

  // --- 0. the defect itself ---------------------------------------------------
  ok("all five ability tools plus the built-in rendered as ability rows",
     ABIL.every(function (id) { return abRows(id).length >= 1; }),
     ABIL.map(function (id) { return id + "=" + abRows(id).length; }).join(" "));
  ok("an ability row carries data-ab and NOT data-i",
     abRows("dim-booth.rb")[0].dataset.ab === "dim-booth.rb" &&
     abRows("dim-booth.rb")[0].dataset.i === undefined);

  // --- 1. clicking the row BODY flips the ability ------------------------------
  ABIL.forEach(function (id) {
    reset();
    var row = abRows(id)[0];
    click(row.querySelector(".body .nm"));   // the words Benton actually clicks
    var c = calls("ability");
    ok("row body flips " + id + " exactly once",
       c.length === 1 && c[0][1] === id && c[0][2] === "true", JSON.stringify(c));
  });

  // --- 2. the switch flips it once, not twice ---------------------------------
  window.WR.render(PAYLOAD);
  ABIL.forEach(function (id) {
    reset();
    click(abRows(id)[0].querySelector(".sw"));
    var c = calls("ability");
    ok("switch flips " + id + " exactly once (no double-fire)",
       c.length === 1 && c[0][1] === id && c[0][2] === "true", JSON.stringify(c));
  });

  // --- 3. row body and switch are the SAME call --------------------------------
  window.WR.render(PAYLOAD);
  reset(); click(abRows("dim-room.rb")[0].querySelector(".body"));
  var viaBody = JSON.stringify(window.__calls);
  window.WR.render(PAYLOAD);
  reset(); click(abRows("dim-room.rb")[0].querySelector(".sw"));
  var viaSw = JSON.stringify(window.__calls);
  ok("row body and switch produce identical calls", viaBody === viaSw, viaBody + " vs " + viaSw);

  // --- 4. optimistic flip still paints every copy of a pinned ability ----------
  window.WR.render(PAYLOAD);
  ok("pinned ability renders twice", abRows("dim-room.rb").length === 2,
     abRows("dim-room.rb").length);
  click(abRows("dim-room.rb")[1].querySelector(".body"));   // click the category copy
  ok("both copies flipped ON from a row-body click",
     abRows("dim-room.rb").every(function (r) {
       return r.classList.contains("on") &&
              r.querySelector(".sw").getAttribute("aria-checked") === "true" &&
              r.querySelector(".stat").textContent === "ON";
     }));

  // --- 5. flipping back off ----------------------------------------------------
  reset();
  click(abRows("dim-room.rb")[0].querySelector(".body"));
  ok("row body flips it back OFF", JSON.stringify(calls("ability")) ===
     JSON.stringify([["ability","dim-room.rb","false"]]), JSON.stringify(window.__calls));
  ok("both copies painted OFF", abRows("dim-room.rb").every(function (r) {
       return !r.classList.contains("on") &&
              r.querySelector(".stat").textContent === "OFF"; }));

  // --- 6. in-row controls must NOT toggle the ability --------------------------
  window.WR.render(PAYLOAD);
  reset();
  var gear = abRows("dim-room.rb")[0].querySelector("[data-g]");
  ok("the settings gear exists", !!gear);
  click(gear);
  ok("gear does not toggle the ability", calls("ability").length === 0,
     JSON.stringify(window.__calls));
  ok("gear opened the settings pane",
     !!$scroll.querySelector(".settings select[data-id='dim-room.rb']"));

  reset();
  click(abRows("dim-booth.rb")[0].querySelector(".star[data-n]"));
  ok("star pins without toggling the ability",
     calls("ability").length === 0 && calls("pin").length === 1,
     JSON.stringify(window.__calls));

  reset();
  var fld = $scroll.querySelector(".settings select[data-id='dim-room.rb']");
  click(fld);
  ok("clicking a settings field does not toggle the ability",
     calls("ability").length === 0, JSON.stringify(window.__calls));

  // --- 7. action rows still run --------------------------------------------------
  reset();
  var arow = $scroll.querySelector(".row[data-i]");
  ok("an action row is still rendered", !!arow);
  click(arow.querySelector(".body"));
  ok("action row body still runs its script",
     calls("run").length === 1 && calls("ability").length === 0,
     JSON.stringify(window.__calls));

  // --- 8. every interactive element the renderers emit has wiring ---------------
  // A control that renders but is selected by nothing is the bug class we are in.
  reset();
  click($scroll.querySelector(".slot[data-s]"));
  ok("toolbar slot opens the editor",
     document.getElementById("ovl").className.indexOf("on") >= 0);
  document.getElementById("edcancel").dispatchEvent(new MouseEvent("click",{bubbles:true}));

  reset();
  var sect = $scroll.querySelector(".sect[data-sec]");
  click(sect);
  ok("section header collapses", sect.classList.contains("closed") &&
     calls("collapse").length === 1, JSON.stringify(window.__calls));
  click(sect);

  window.WR.render(PAYLOAD);
  reset();
  var chip = document.getElementById("statebar").querySelector(".chip");
  ok("no state chip while everything is off", !chip);
  var onPayload = JSON.parse(JSON.stringify(PAYLOAD));
  onPayload.abilities[0].on_now = true;
  window.WR.render(onPayload);
  chip = document.getElementById("statebar").querySelector(".chip");
  ok("state chip renders for an ability that is on", !!chip);
  if (chip) { click(chip); ok("state chip click does not throw", true); }

  reset();
  click($scroll.querySelector(".star[data-r]"));
  ok("pencil opens the rename sheet",
     document.getElementById("rovl").className.indexOf("on") >= 0 &&
     calls("ability").length === 0);
  document.getElementById("rncancel").dispatchEvent(new MouseEvent("click",{bubbles:true}));

  // --- 9. the row reads as clickable ------------------------------------------
  window.WR.render(PAYLOAD);
  var cs = getComputedStyle(abRows("dim-room.rb")[0]);
  ok("ability row has a pointer cursor", cs.cursor === "pointer", cs.cursor);

  L.push(""); L.push("RESULT " + pass + " passed, " + fail + " failed");
  document.getElementById("OUT").textContent = L.join("\n");
})();
</script>
"""

s = s.replace("</body>", harness + "</body>")
out.write_text(s, encoding="utf-8")
print(out)
