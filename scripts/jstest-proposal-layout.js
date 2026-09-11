// jstest-proposal-layout.js - LAY OUT the proposal package's dialog in a real
// browser at a real window size, and check that the scene grid is on screen.
//   node scripts/jstest-proposal-layout.js
//
// WHY THIS EXISTS. 10 Sep 2026, 1.49.2: Benton ran AUTO-SET, it wrote five
// scenes, and the window showed NO ROWS - while its own header said "5 scenes
// 2 render 3 image". Nothing had failed. The rows were in the DOM, correct,
// and had ZERO HEIGHT: #scenesect was the only item in the body's flex column
// that could shrink (every other .sect is flex:0 0 auto) and .sect.grow's
// min-height:0 let it shrink to nothing, so an expanded FOLDER & DETAILS -
// taller than the whole window on its own - squeezed the table out of
// existence. Maximise the window and the rows appeared, which is what told
// Benton it was a sizing bug: "oh fyi it shows in full screen, but should
// show always".
//
// jstest-proposal-dialog.js could never have caught that. It runs the script
// under a FAKE DOM: there is no layout, no viewport and no CSS, so a table
// with five correct rows and no height looks identical to a table with five
// correct rows. This file is the other half - it does no logic checking at
// all, only geometry:
//   1. builds the page the way the browser receives it (the same heredoc
//      unescape jstest-proposal-dialog.js applies, plus the HTML itself);
//   2. lays it out in headless Chrome inside an iframe of an EXACT size, so
//      the dialog's real :width/:height and :min_width/:min_height from
//      UI::HtmlDialog.new are the viewport;
//   3. measures how many scene rows are actually visible inside .wrap, and
//      whether the bar carrying Export package is still on screen.
//
// IT PROVES ITSELF. The last case re-runs the worst layout with the 1.49.2
// CSS block CUT BACK OUT of the stylesheet, and FAILS if that mutant still
// shows rows - so these checks can never pass by not testing anything.
//
// Mutation-checked when added, RUN not assumed. Each of these was put back
// into scripts/proposal-package.rb and each was killed by the NAMED check
// beside it (10 Sep 2026):
//   the whole 1.49.2 CSS block removed (i.e. 1.48.1) -> 'scene rows are
//     actually VISIBLE', 'the grid keeps a readable floor' and 'Export
//     package is still on screen' all FAIL, at both sizes;
//   ONLY #scenesect.open{min-height} removed         -> the two MINIMUM-size
//     checks FAIL (measured: 150px/2 rows becomes 78px/1 row). This is why
//     the floor is asserted by size - at 700x760 the yielding rules alone
//     would have hidden its absence;
//   ONLY the .sect.open:not(.grow) yielding rules removed -> 'Export package
//     is still on screen' FAILS at both sizes (the grid keeps its floor and
//     the bar is pushed off the bottom instead - the 1.23.x bug .grow exists
//     to prevent);
//   the outsum line dropped from updateDest()        -> 'a collapsed FOLDER &
//     DETAILS still says where the package lands' FAILS.
// The Ruby half - which state FOLDER & DETAILS starts in - is mutation-checked
// in scripts/rbtest-proposal.py (dt1-4, outsect).
//
// Chrome is already a requirement on this machine (CLAUDE.md: the proposal
// generator prints with headless Chrome). If it is not found this prints
// SKIPPED and exits 0 rather than failing a machine that cannot run it.
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const SRC = path.join(__dirname, 'proposal-package.rb');
const src = fs.readFileSync(SRC, 'utf8');

const CHROMES = [
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
  process.env.CHROME || ''
];
const CHROME = CHROMES.find(p => p && fs.existsSync(p));
if (!CHROME) {
  console.log('SKIPPED - no Chrome found, so the dialog cannot be laid out here.');
  console.log('          Set CHROME=<path to chrome.exe> to run this.');
  process.exit(0);
}

// ---- the page, as the browser receives it ---------------------------------
const start = src.indexOf('def self.html(');
const hd = src.indexOf('<<-HTML', start);
const end = src.indexOf('\n    HTML', start);
if (start < 0 || hd < 0 || end < 0) { console.log('FAIL: could not find the html heredoc'); process.exit(1); }
let doc = src.slice(src.indexOf('\n', hd) + 1, end);

const BS = String.fromCharCode(92);
// The interpolating heredoc's own unescape - identical to the one in
// jstest-proposal-dialog.js and for the same reason.
function rubyUnescape(t) {
  const named = { n: '\n', t: '\t', s: ' ', r: '\r', e: '\x1b', a: '\x07', b: '\b', f: '\f', v: '\v', '0': '\0' };
  let out = '';
  for (let i = 0; i < t.length; i++) {
    const c = t[i];
    if (c !== BS || i + 1 >= t.length) { out += c; continue; }
    const d = t[++i];
    if (d === BS) out += BS; else if (d in named) out += named[d]; else out += d;
  }
  return out;
}

// Benton's model on 10 Sep 2026: AUTO-SET on MDL 4872 E (components), five
// plates, two Render and three Image. The exact state that drew nothing.
const NAMES = ['01-exterior', '02-front', '03-ventilation', '04-dimensioned', '05-plan'];
const MODES = ['render', 'render', 'image', 'image', 'image'];
const ST = {
  deep: true,
  rows: NAMES.map((s, i) => ({
    n: i + 1, scene: 'MDL 4872 E (components) ' + s, mode: MODES[i],
    file: (i + 1) + '_MDL 4872 E (components) ' + s + (MODES[i] === 'render' ? ' render' : '') + '.png',
    walls: { total: 4, hidden: i < 4 ? 1 : 0, names: i < 4 ? ['Room Wall 1'] : [] },
    annots: { label: i === 4 ? 'dims + doors' : 'all hidden', warn: false, loose: 0, tip: 'Shown: WR-Dims' }
  })),
  slots: [{ slot: 'WR-Floor-Render', draft: '0128_White', house: '0128_White', missing: false, label: 'Floor', fill: '' },
          { slot: 'WR-Wall-Render', draft: '0099_LightSteelBlue', house: '0099_LightSteelBlue', missing: false, label: 'Walls', fill: '' }],
  mode: 'draft', undo: null, materials: ['0128_White', '0099_LightSteelBlue']
};
const DIR = 'C:/Users/bento/Desktop/ProposalFiles';

doc = doc.replace('#{st.to_json}', JSON.stringify(ST))
         .replace('#{fname.to_json}', JSON.stringify('MDL 4872 E (components)'))
         .replace('#{escHtml(title)}', 'MDL 4872 E (components)')
         .replace(/#\{escAttr\(dir\)\}/g, DIR)
         .replace(/#\{escAttr\(fname\)\}/g, 'MDL 4872 E (components)')
         .replace(/#\{[^{}]*\}/g, '');          // every other interpolation
doc = rubyUnescape(doc);

// The two knobs the cases turn. FOLDER & DETAILS starts collapsed whenever a
// folder is remembered (details_open?), so forcing it OPEN is how the worst
// case - and the case Benton actually hit - is reached.
const CSS_HEAD = '  /* THE SCENE GRID MUST NEVER BE SQUEEZED TO NOTHING (1.49.2).';
const CSS_TAIL = '.sect.open:not(.grow) > .bodyy { flex:0 1 auto; min-height:0; overflow:auto; }';
function variant(detailsOpen, dropFix) {
  let h = doc;
  if (detailsOpen) {
    const before = h;
    h = h.replace('<div class="sect" id="outsect">', '<div class="sect open" id="outsect">');
    if (h === before) { console.log('FAIL: could not force FOLDER & DETAILS open - has #outsect changed?'); process.exit(1); }
  }
  if (dropFix) {
    const i = h.indexOf(CSS_HEAD), j = h.indexOf(CSS_TAIL);
    // Already absent: the page IS the mutant. Do not abort - let the named
    // visibility checks below fail, which is the symptom Benton reported.
    if (i >= 0 && j >= 0) h = h.slice(0, i) + h.slice(j + CSS_TAIL.length);
  }
  return '<!doctype html>\n' + h;
}

// ---- lay it out -----------------------------------------------------------
// An IFRAME of an exact pixel size, not --window-size: the dialog's own
// html,body{height:100%} then resolves against precisely the height
// UI::HtmlDialog.new asks for, with no browser chrome to subtract. srcdoc
// inherits the parent's origin, so the measurements are readable.
const CASES = [
  { key: 'default',      w: 700, h: 760, detailsOpen: false, dropFix: false },
  { key: 'detailsopen',  w: 700, h: 760, detailsOpen: true,  dropFix: false },
  { key: 'minsize',      w: 520, h: 480, detailsOpen: true,  dropFix: false },
  { key: 'mutant',       w: 700, h: 760, detailsOpen: true,  dropFix: true  }
];

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'wr-layout-'));
const runner = path.join(tmp, 'runner.html');
fs.writeFileSync(runner, `<!doctype html><meta charset="utf-8">
<style>html,body{margin:0}</style>
<iframe id="f" style="border:0;display:block"></iframe>
<div id="PROBE">pending</div>
<script>
var CASES = ${JSON.stringify(CASES.map(c => ({ key: c.key, w: c.w, h: c.h })))};
var DOCS  = ${JSON.stringify(CASES.map(c => variant(c.detailsOpen, c.dropFix)))
                .replace(/<\//g, '<\\/').replace(/<!--/g, '<\\!--')};
var out = {}, i = 0;
var f = document.getElementById("f");
function measure(){
  var d = f.contentDocument, win = f.contentWindow;
  var sect = d.getElementById("scenesect"), wrap = sect.querySelector(".wrap");
  var tb = d.getElementById("body"), rows = tb.querySelectorAll("tr");
  var w = wrap.getBoundingClientRect(), vis = 0;
  Array.prototype.forEach.call(rows, function(tr){
    var r = tr.getBoundingClientRect();
    if (Math.min(r.bottom, w.bottom) - Math.max(r.top, w.top) > 4) vis++;
  });
  var bar = d.querySelector(".bar").getBoundingClientRect();
  return { viewport: win.innerHeight,
           sectH: Math.round(sect.getBoundingClientRect().height),
           wrapH: Math.round(w.height),
           rowsInDom: rows.length, rowsVisible: vis,
           wrapScrollable: wrap.scrollHeight > wrap.clientHeight + 1,
           outsum: (d.getElementById("outsum")||{}).textContent || "",
           countLine: (d.getElementById("count")||{}).textContent || "",
           barOnScreen: bar.bottom <= win.innerHeight + 1 };
}
function next(){
  if (i >= CASES.length) { document.getElementById("PROBE").textContent = JSON.stringify(out); return; }
  var c = CASES[i];
  f.style.width = c.w + "px"; f.style.height = c.h + "px";
  f.onload = function(){ setTimeout(function(){
    try { out[c.key] = measure(); } catch (e) { out[c.key] = { error: String(e) }; }
    i++; next();
  }, 60); };
  f.srcdoc = DOCS[i];
}
next();
</script>`, 'utf8');

let dom;
try {
  dom = execFileSync(CHROME, ['--headless=new', '--disable-gpu', '--no-sandbox',
                              '--virtual-time-budget=15000', '--window-size=1400,1000',
                              '--dump-dom', 'file:///' + runner.replace(/\\/g, '/')],
                     { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], maxBuffer: 64 * 1024 * 1024 });
} catch (e) {
  console.log('FAIL: Chrome did not lay the page out: ' + (e && e.message));
  process.exit(1);
}
const m = dom.match(/<div id="PROBE">([\s\S]*?)<\/div>/);
if (!m || m[1] === 'pending') { console.log('FAIL: the layout probe never reported (Chrome returned no measurement)'); process.exit(1); }
let R;
try { R = JSON.parse(m[1].replace(/&quot;/g, '"').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')); }
catch (e) { console.log('FAIL: unreadable probe output: ' + m[1].slice(0, 400)); process.exit(1); }

let failed = 0;
function check(label, ok, ctx) {
  if (ok) console.log('ok   ' + label);
  else { failed++; console.log('FAIL ' + label + (ctx ? '\n     ' + ctx : '')); }
}
function show(k) { const r = R[k] || {}; return JSON.stringify(r); }

for (const c of CASES) if (!R[c.key] || R[c.key].error) {
  failed++; console.log('FAIL case "' + c.key + '" did not measure: ' + JSON.stringify((R[c.key] || {}).error));
}
if (failed) { console.log('FAIL - the layout probe could not run'); process.exit(1); }

// THE BUG, NAMED. A header that says five scenes over a table showing none is
// the exact thing Benton saw, so it is the exact thing asserted against.
const D = R.detailsopen;
check('the window says 5 scenes and the grid HAS five rows to show',
      D.rowsInDom === 5 && /5 scenes/.test(D.countLine), show('detailsopen'));
check('700x760 with FOLDER & DETAILS OPEN: scene rows are actually VISIBLE',
      D.rowsVisible > 0, show('detailsopen'));
check('700x760 with FOLDER & DETAILS OPEN: the grid keeps a readable floor (>=120px)',
      D.sectH >= 120, show('detailsopen'));
check('700x760 with FOLDER & DETAILS OPEN: the rows that do not fit SCROLL',
      D.rowsVisible === D.rowsInDom || D.wrapScrollable, show('detailsopen'));
check('700x760 with FOLDER & DETAILS OPEN: Export package is still on screen',
      D.barOnScreen === true, show('detailsopen'));

const F = R.default;
check('700x760 as it opens (details collapsed): every scene row is visible',
      F.rowsVisible === F.rowsInDom, show('default'));
check('a collapsed FOLDER & DETAILS still says where the package lands',
      /Files go to:/.test(F.outsum) && F.outsum.indexOf(DIR) >= 0,
      'outsum: ' + JSON.stringify(F.outsum));
check('700x760 as it opens: Export package is on screen', F.barOnScreen === true, show('default'));

// THE FLOOR, WHERE IT IS LOAD-BEARING. At 700x760 the yielding rules alone
// happen to leave the grid room; at the dialog's MINIMUM size they do not -
// measured 10 Sep 2026, dropping #scenesect.open{min-height} alone takes this
// from 150px/2 rows to 78px/1 row. So the floor is asserted here, by size,
// rather than assumed to be doing something everywhere.
const M = R.minsize;
check('at the dialog MINIMUM size (520x480) MORE THAN ONE scene row is visible',
      M.rowsVisible >= 2, show('minsize'));
check('at the dialog MINIMUM size the grid still holds its floor (>=120px)',
      M.sectH >= 120, show('minsize'));
check('at the dialog MINIMUM size Export package is still on screen',
      M.barOnScreen === true, show('minsize'));

// THE MUTANT. Same page, same size, 1.49.2's CSS block cut out - i.e. 1.48.1.
// If this still shows rows then every check above is measuring nothing.
const X = R.mutant;
check('MUTANT (1.49.2 layout CSS removed) reproduces the bug: rows drawn, NONE visible',
      X.rowsInDom === 5 && X.rowsVisible === 0,
      'mutant: ' + show('mutant') + '\n     If this passes rows, the checks above prove nothing.');

try { fs.rmSync(tmp, { recursive: true, force: true }); } catch (e) { /* leave it */ }
console.log(failed ? 'FAIL - the scene grid is not reliably on screen'
                   : 'PASS - the scene grid is on screen and scrollable at every dialog size');
process.exit(failed ? 1 : 0);
