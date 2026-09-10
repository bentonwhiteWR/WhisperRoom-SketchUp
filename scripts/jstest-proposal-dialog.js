// jstest-proposal-dialog.js - RUN the proposal package's dialog script the
// way the browser receives it, under a fake DOM.  node scripts/jstest-proposal-dialog.js
//
// WHY THIS EXISTS. 10 Sep 2026: `node --check` on the script extracted from
// proposal-package.rb passed, rbparse passed, rbtest passed - and the window
// opened with an empty scene table and "Ready." in the status line. The
// script is inside a Ruby heredoc, which turns `\\` into `\` before the
// browser sees it: a `/\\/g` in the .rb source arrived as `/\/g`, an
// unterminated regex, a SyntaxError for the whole block. --check never saw
// the unescaped text. This does three things --check cannot:
//   1. applies the heredoc unescape (`\\` -> `\`) and substitutes the Ruby
//      interpolations with realistic values, THEN parses;
//   2. RUNS the init path under a fake DOM whose getElementById returns
//      null for any id the HTML does not contain - so a listener hung on a
//      missing element throws here, as it would in the window;
//   3. checks that the functions Ruby calls into (applyState, setDir,
//      showPrompt, logLine, runStarted, runFinished) exist afterwards.
// Exit 1 on any throw. Fake DOM only: layout and events are not exercised.
'use strict';
const fs = require('fs');
const vm = require('vm');
const path = require('path');
const SRC = path.join(__dirname, 'proposal-package.rb');
const src = fs.readFileSync(SRC, 'utf8');

const start = src.indexOf('def self.html(');
const end = src.indexOf('\n    HTML', start);
if (start < 0 || end < 0) { console.log('FAIL: could not find the html heredoc'); process.exit(1); }
const doc = src.slice(start, end);
const ids = new Set();
for (const m of doc.matchAll(/\sid=["']([A-Za-z0-9_-]+)["']/g)) ids.add(m[1]);

// Every <script> block, in order, as ONE program: an onerror block before
// the main IIFE is part of the contract.
const blocks = [...doc.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]);
if (!blocks.length) { console.log('FAIL: no <script> blocks'); process.exit(1); }

const ST = { rows: [ { n: 1, scene: 'Scene 1', mode: 'image',  file: '1_Scene 1.png' },
                     { n: 2, scene: 'Scene 4', mode: 'render', file: '2_Scene 4 render.png' },
                     { n: 3, scene: 'Scene 2', mode: 'skip',   file: '' },
                     { n: 4, scene: 'Scene 3', mode: 'image',  file: '4_Scene 3.png' } ],
             slots: [ { slot: 'WR-Floor-Render', draft: '0128_White', house: '0128_White',
                        missing: false, label: 'Floor', fill: 'x' } ],
             mode: 'draft', undo: null, materials: ['a', 'b'] };
function prepare(js, fname) {
  let code = js.replace('#{st.to_json}', JSON.stringify(ST))
               .replace('#{fname.to_json}', JSON.stringify(fname));
  code = code.replace(/#\{[^}]*\}/g, '0');   // any other interpolation
  return rubyUnescape(code);                  // the heredoc unescape
}
// Ruby double-quoted-string escapes, as the interpolating heredoc applies
// them: `\\` -> `\`, the named ones, and ANY OTHER `\X` -> `X` (so `\/`
// becomes `/`, `\d` becomes `d`, `\s` becomes a SPACE). That last rule is
// the one that turns a JS regex written with single backslashes into
// garbage, and the reason the source writes `\\s+` to get `\s+`.
function rubyUnescape(t) {
  const named = { n: '\n', t: '\t', s: ' ', r: '\r', e: '\x1b', a: '\x07', b: '\b', f: '\f', v: '\v', '0': '\0' };
  let out = '';
  for (let i = 0; i < t.length; i++) {
    const c = t[i];
    if (c !== '\\' || i + 1 >= t.length) { out += c; continue; }
    const d = t[++i];
    if (d === '\\') out += '\\';
    else if (d in named) out += named[d];
    else out += d;
  }
  return out;
}

function el(id) {
  return { id, value: '', checked: false, textContent: '', innerHTML: '', title: '', disabled: false,
    style: {}, dataset: {}, attributes: {},
    classList: { add() {}, remove() {}, toggle() { return true; }, contains() { return false; } },
    addEventListener() {}, setAttribute(k, v) { this.attributes[k] = v; },
    removeAttribute(k) { delete this.attributes[k]; },
    getAttribute(k) { return this.attributes[k] == null ? null : this.attributes[k]; },
    querySelector() { return el('q'); }, querySelectorAll() { return []; },
    focus() {}, select() {}, setSelectionRange() {}, appendChild() {}, insertBefore() {},
    removeChild() {}, scrollIntoView() {}, closest() { return null; }, parentNode: null,
    getBoundingClientRect() { return { top: 0, left: 0, width: 0, height: 0 }; } };
}

let failed = 0;
for (const fname of ['NewTemplate', '']) {          // saved-looking and unsaved
  const asked = [];
  const document = {
    getElementById(id) { asked.push(id); return ids.has(id) ? el(id) : null; },
    querySelectorAll() { return []; }, querySelector() { return null; },
    body: el('body'), addEventListener() {}, execCommand() { return true; },
    createElement() { return el('x'); }
  };
  const window = { addEventListener() {}, document };
  const ctx = { document, window, console, setTimeout, clearTimeout, JSON, String, Array, Object, Math };
  try {
    blocks.forEach((b, i) => vm.runInNewContext(prepare(b, fname), ctx, { filename: 'dialog-block-' + i + '.js' }));
    const need = ['applyState', 'setDir', 'showPrompt', 'logLine', 'runStarted', 'runFinished', 'onerror'];
    const missing = need.filter(k => typeof window[k] !== 'function');
    if (missing.length) { failed++; console.log('FAIL (fname=' + JSON.stringify(fname) + '): missing window functions: ' + missing.join(', ')); }
    else console.log('ok   fname=' + JSON.stringify(fname) + ': every script block parsed and ran; ' + need.length + ' Ruby-facing functions present');
  } catch (e) {
    failed++;
    console.log('FAIL (fname=' + JSON.stringify(fname) + '): ' + (e && e.stack ? e.stack.split('\n').slice(0, 3).join(' | ') : e));
    const absent = [...new Set(asked.filter(id => !ids.has(id)))];
    if (absent.length) console.log('     ids asked for but absent from the HTML: ' + absent.join(', '));
  }
}
console.log(failed ? 'FAIL - the dialog script does not survive the heredoc' : 'PASS - dialog script runs as the browser receives it');
process.exit(failed ? 1 : 0);
