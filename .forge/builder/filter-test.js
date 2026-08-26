// Runs the REAL filter JavaScript emitted by list-scenes.rb's heredoc against
// fixture rows built from real names in this project. No reimplementation: the
// script under test is .forge/builder/emitted-filter.js, produced by emit.py.
var fs = require("fs");

function El(id) {
  this.id = id; this.value = ""; this.innerHTML = ""; this.textContent = "";
  this._h = {};
}
El.prototype.addEventListener = function (t, f) { (this._h[t] = this._h[t] || []).push(f); };
El.prototype.querySelectorAll = function () { return []; };
El.prototype.querySelector = function () { return new El("stub"); };
El.prototype.select = function () {};
El.prototype.setSelectionRange = function () {};

var els = {};
["q", "body", "spec", "pick", "count", "all", "none", "copy", "save"].forEach(function (id) {
  els[id] = new El(id);
});
els.pick.style = {};

global.document = {
  getElementById: function (id) { return els[id]; },
  querySelectorAll: function () { return []; },
  execCommand: function () {},
  addEventListener: function () {}
};
global.window = {};

var js = fs.readFileSync(".forge/builder/emitted-filter.js", "utf8");
eval(js);

function search(q) {
  els.q.value = q;
  els.q._h.input.forEach(function (f) { f(); });
  var html = els.body.innerHTML;
  var ns = (html.match(/data-n="(\d+)"/g) || []).map(function (s) {
    return +s.replace(/\D/g, "");
  });
  return { ns: ns, html: html };
}

var fails = 0, passes = 0;
function ok(label, cond, extra) {
  if (cond) { passes++; console.log("  PASS  " + label); }
  else { fails++; console.log("  FAIL  " + label + (extra ? "   [" + extra + "]" : "")); }
}
function same(a, b) { return a.length === b.length && a.every(function (v, i) { return v === b[i]; }); }

console.log("fixture rows: 1 ENH 26.5Panel1648WDO_HX | 2 ENH 10242FL SIDE | 3 ENH 4896CL |");
console.log("              5 ENH 1264CL | 7 ENH 35.5VNT | 12 16PanelSolid (2) | 40 Overview/(unresolved)");
console.log("");

var r;

r = search("1648");
console.log('  q="1648" -> scenes ' + JSON.stringify(r.ns));
ok('"1648" finds the WDO part (the reported bug)', r.ns.indexOf(1) >= 0);
ok('"1648" is not empty', r.ns.length > 0);
ok('"1648" highlights 1648 inside the name',
   r.html.indexOf("Panel<mark>1648</mark>WDO") >= 0);

r = search("1-3");
console.log('  q="1-3" -> scenes ' + JSON.stringify(r.ns));
ok('"1-3" still filters by scene number only', same(r.ns, [1, 2, 3]));
ok('"1-3" does not highlight anything', r.html.indexOf("<mark>") < 0);

r = search("3,7");
console.log('  q="3,7" -> scenes ' + JSON.stringify(r.ns));
ok('"3,7" still works, and scene 5 is correctly excluded', same(r.ns, [3, 7]));

r = search("1-40");
console.log('  q="1-40" -> scenes ' + JSON.stringify(r.ns));
ok('"1-40" spans the whole list', same(r.ns, [1, 2, 3, 5, 7, 12, 40]));

var a = search("wdo panel"), b = search("panel wdo");
console.log('  q="wdo panel" -> ' + JSON.stringify(a.ns) + '   q="panel wdo" -> ' + JSON.stringify(b.ns));
ok('"wdo panel" finds ENH 26.5Panel1648WDO_HX', a.ns.indexOf(1) >= 0);
ok('"panel wdo" finds the same row, order-independent', same(a.ns, b.ns) && a.ns.indexOf(1) >= 0);
ok('both terms are highlighted',
   a.html.indexOf("<mark>Panel</mark>") >= 0 && a.html.indexOf("<mark>WDO</mark>") >= 0,
   a.html.slice(0, 200));

r = search("12");
console.log('  q="12" -> scenes ' + JSON.stringify(r.ns));
ok('bare "12" returns scene 12 (number match)', r.ns.indexOf(12) >= 0);
ok('bare "12" ALSO returns the text match ENH 1264CL (scene 5)', r.ns.indexOf(5) >= 0);
ok('bare "12" is exactly the union of both', same(r.ns, [5, 12]));

r = search("48");
console.log('  q="48" -> scenes ' + JSON.stringify(r.ns));
ok('bare "48" text-matches ENH 4896CL even though no scene is numbered 48', r.ns.indexOf(3) >= 0);

r = search("35.5");
console.log('  q="35.5" -> scenes ' + JSON.stringify(r.ns));
ok('"35.5" (period, falls through to text) still finds ENH 35.5VNT', same(r.ns, [7]));

r = search("enh side");
console.log('  q="enh side" -> scenes ' + JSON.stringify(r.ns));
ok('"enh side" ANDs both terms -> only ENH 10242FL SIDE', same(r.ns, [2]));

r = search("nosuchthing");
ok('a miss returns nothing rather than throwing', r.ns.length === 0);

r = search("");
ok('empty query shows every row', same(r.ns, [1, 2, 3, 5, 7, 12, 40]));

r = search("panel panel");
ok('a repeated term does not double-mark or corrupt the row',
   r.ns.indexOf(1) >= 0 && r.html.indexOf("<mark><mark>") < 0);

r = search("(2)");
console.log('  q="(2)" -> scenes ' + JSON.stringify(r.ns));
ok('punctuation in the query is treated as literal text', same(r.ns, [12]));

r = search("unresolved");
ok('"(unresolved)" rows are still searchable', r.ns.indexOf(40) >= 0);

console.log("\n" + passes + " passed, " + fails + " failed");
process.exit(fails ? 1 : 0);
