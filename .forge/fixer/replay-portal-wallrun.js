#!/usr/bin/env node
/*
 * replay-portal-wallrun.js — compare scripts/wr-booth-data.rb against the
 * PORTAL'S OWN wallPanelRun(), EXECUTED, not paraphrased.
 *
 * WHY THIS EXISTS
 * ---------------
 * Two earlier witnesses were both wrong to trust:
 *
 *   1. The first harness (.forge/fixer/replay-side-wall-order.py, v1) compared
 *      wr-booth-data.rb against a HARD-CODED restatement of the portal's rule.
 *      Circular. It could not fail. It reported 200/200 clean on a model Benton
 *      could see was wrong.
 *
 *   2. The second (v2) compared against lib/pl-data/booth-iso-geometry.json.
 *      That file is NOT independent ground truth: its own header says it is
 *      PARSED FROM wr-booth-data.rb. It is a stale COPY of the file under test,
 *      taken 2026-08-07, four days before gen-booth.py changed the E/W walk.
 *      Comparing a file to an old copy of itself measures drift, not truth.
 *
 * This one runs the real function out of the real portal source:
 *
 *      require('WhisperRoomQuote/assets/layout-render.js').wallPanelRun(...)
 *
 * so whatever the portal's 2D top-down plan actually does — including the
 * big-run-at-the-door-end flip at layout-render.js:265-277 — is what is
 * compared. WhisperRoomQuote is READ ONLY; this only requires it.
 *
 * THREE SOURCES, NOT TWO. The report prints all three, because they do not all
 * agree with each other and knowing WHICH pair disagrees is the whole diagnosis:
 *
 *   layout   scripts/wr-booth-data.rb          what SketchUp builds
 *   portal   wallPanelRun(), executed          the portal 2D top-down plan
 *   angled   booth-iso-geometry.json           the portal ANGLED ("YOUR BOOTH")
 *                                              3D view, assets/iso-render.js
 *
 * ⚠ EXPECTED STATE CHANGED 2026-08-27 (v1.6.34). gen-booth.py's E/W walk was
 * reverted to S->N — slot 0 at the model's own door-wall end — on Benton's
 * twice-repeated report (Standard, Enhanced and HX builds of the 102144) that
 * the side-wall window built at the wrong end, against the customer-facing
 * booth-builder view. So a DISAGREE from this harness is no longer evidence
 * against the builder: `--all` now reads 84 DISAGREE, and those 84 are the 14
 * symmetric multi-slot models x 2 walls x 3 shell rows where the portal 2D
 * plan draws its RAW N-first order (its door-end flip cannot fire there).
 * On those walls the portal 2D plan is the odd one out — it contradicts the
 * portal's own angled view and Benton — and fixing it is a WhisperRoomQuote
 * change, not one that can be made from this repo. The four split-run booths
 * (6060/6084/7272/7296) must AGREE; if one of those ever disagrees again,
 * THAT is a real defect.
 *
 * The VERDICT is layout vs portal. `angled` is reported but never judged: it is
 * a snapshot of wr-booth-data.rb parsed on 2026-08-07 (see the header of
 * lib/pl-data/extract-booth-iso-geometry.js), so where it differs from `portal`
 * the angled view is simply STALE, and where it differs from `layout` it is
 * stale by exactly the 2026-08-11 gen-booth.py change. It is NOT ground truth
 * and must never be used as one.
 *
 * COORDINATE MAP (derived, and stated so it can be checked)
 * --------------------------------------------------------
 * layout-render.js:1003-1004   runX = x0 + in*PX ;  runY = y0 + in*PX
 * layout-render.js:1562-1565   N drawn at y0 + t (TOP), S at y0 + H - t (BOTTOM)
 *                              W drawn at x0 + t (LEFT), E at x0 + W - t (RIGHT)
 * wr-booth-data.rb             S panels at low y, N panels at high y,
 *                              W panels at low x, E panels at high x
 * therefore
 *      N/S wall :  builder x  ==  aIn           (both grow the same way)
 *      E/W wall :  builder y  ==  H - bIn .. H - aIn   (SVG y is down, builder y is up)
 *
 * THE ASSIGN FED IN
 * -----------------
 * wallPanelRun's door-end flip keys on REAL part widths, not slot sizes, so a
 * null assign would misfire (MDL 6060's W slots are digitised 40 + 18, but the
 * real parts are 40 + 16). The assign here is built from wr-booth-data.rb's OWN
 * resolved panel lengths — the widths the generator already proved close on the
 * run — as `STDWL<len>` plus the slot's kind. Those are the widths a real BOM
 * delivers, and they are stated here so the input is auditable.
 *
 * Run:  node .forge/fixer/replay-portal-wallrun.js [--all] ["MDL 102144 S" …]
 * Exit: 1 if any wall disagrees.
 */
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');
const DATA = path.join(ROOT, 'scripts', 'wr-booth-data.rb');
const QUOTE = path.resolve(ROOT, '..', 'WhisperRoomQuote');
const LR = path.join(QUOTE, 'assets', 'layout-render.js');
const LAYOUTS = path.join(QUOTE, 'lib', 'pl-data', 'booth-layouts.json');

const ISOF = path.join(QUOTE, 'lib', 'pl-data', 'booth-iso-geometry.json');

const m = require(LR);
const LAY = JSON.parse(fs.readFileSync(LAYOUTS, 'utf8')).layouts;
const ISODOC = JSON.parse(fs.readFileSync(ISOF, 'utf8'));
const ISO = {};
for (const e of ISODOC.booths) {
  const d = {};
  for (const p of e.parts) {
    if (p.k !== 'panel') continue;
    const ax = (p.id[0] === 'N' || p.id[0] === 'S') ? 0 : 1;
    const v = p.poly.map(q => q[ax]);
    d[p.id] = [Math.min.apply(null, v), Math.max.apply(null, v)];
  }
  ISO[e.key] = d;
}

/* ---------- parse wr-booth-data.rb ---------- */
function loadBooths() {
  const src = fs.readFileSync(DATA, 'utf8');
  const booths = {};
  let cur = null;
  for (const line of src.split(/\r?\n/)) {
    const h = line.match(/^\s*'(MDL [^']+)' => \{.*?:w=>([\d.]+), :h=>([\d.]+)/);
    if (h) { cur = { w: +h[2], h: +h[3], parts: [] }; booths[h[1]] = cur; continue; }
    if (!cur) continue;
    const p = line.match(/:k=>'([a-z]+)',\s*:id=>'([^']+)',\s*:sk=>'([^']+)',\s*:sh=>'([^']+)',\s*:poly=>(\[\[.*?\]\])/);
    if (!p) continue;
    const pts = [];
    const re = /\[\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\]/g;
    let q; while ((q = re.exec(p[5])) !== null) pts.push([+q[1], +q[2]]);
    cur.parts.push({ k: p[1], id: p[2], sk: p[3], sh: p[4], poly: pts });
  }
  return booths;
}

const KIND_SUFFIX = { VNT: ' VNT', WDO: ' WDO2636', CBL: ' CBL', DRFRM: ' DRFRM R', SOLID: '' };
const axisOf = w => (w === 'N' || w === 'S') ? 0 : 1;
const num = id => +(id.replace(/\D/g, '') || 0);
const ext = (poly, ax) => {
  const v = poly.map(p => p[ax]);
  return [Math.min.apply(null, v), Math.max.apply(null, v)];
};

function walls(spec, shell, side) {
  return spec.parts
    .filter(x => x.sh === shell && x.k === 'panel' && x.id[0] === side)
    .map(x => { const e = ext(x.poly, axisOf(side)); return { id: x.id, sk: x.sk, lo: e[0], hi: e[1] }; })
    .sort((a, b) => num(a.id) - num(b.id));
}

function main() {
  const booths = loadBooths();
  const argv = process.argv.slice(2);
  const args = argv.filter(a => !a.startsWith('--'));
  const keys = argv.includes('--all') ? Object.keys(booths).sort()
    : (args.length ? args : ['MDL 6060 S', 'MDL 96144 S', 'MDL 102144 S', 'MDL 102144 E']);

  let checked = 0, bad = 0;
  const badList = [];
  const staleWalls = [];
  const out = [];
  out.push('witness : ' + LR);
  out.push('          wallPanelRun() EXECUTED, not paraphrased. This is what the');
  out.push('          portal 2D top-down plan actually draws, flip included.');
  out.push('');

  for (const key of keys) {
    const spec = booths[key];
    if (!spec) { out.push('!! ' + key + ' not in wr-booth-data.rb'); continue; }
    const lay = LAY[key.replace(/ [SE]$/, '')];
    if (!lay) { out.push('!! ' + key + ' has no booth-layouts.json entry'); continue; }
    out.push('='.repeat(96));
    out.push(key + '   exterior ' + spec.w + ' x ' + spec.h +
             '   layout door wall: ' + (lay.door && lay.door.wall));
    out.push('='.repeat(96));

    for (const shell of ['out', 'in']) {
      if (!spec.parts.some(x => x.sh === shell)) continue;
      out.push('');
      out.push('  ---- ' + (shell === 'out' ? 'OUTER (Standard shell)' : 'INNER (IEP shell)') + ' ----');
      for (const side of ['N', 'S', 'E', 'W']) {
        const rows = walls(spec, shell, side);
        if (!rows.length) continue;

        // assign from this file's OWN resolved widths
        const assign = {};
        for (const r of rows) {
          const oid = shell === 'in' ? r.id.slice(0, -1) : r.id;
          const w = Math.round(r.hi - r.lo);
          assign[oid] = { pack: 'STDWL' + w + (KIND_SUFFIX[r.sk] || '') };
        }
        const run = m.wallPanelRun(lay, assign, side);
        const H = lay.exterior.h;

        // map the portal run into builder coordinates
        const port = {};
        for (const p of run.pieces) {
          port[p.id] = (side === 'N' || side === 'S')
            ? [p.aIn, p.bIn]
            : [H - p.bIn, H - p.aIn];
        }

        // the inner shell is inset, so compare it by END, not by number
        const bLo = Math.min.apply(null, rows.map(r => r.lo));
        const bHi = Math.max.apply(null, rows.map(r => r.hi));
        const pv = Object.keys(port).map(k => port[k]);
        const pLo = Math.min.apply(null, pv.map(v => v[0]));
        const pHi = Math.max.apply(null, pv.map(v => v[1]));
        const endOf = (lo, hi, a, b) =>
          Math.abs(lo - a) < 0.01 ? 'LOW' : Math.abs(hi - b) < 0.01 ? 'HIGH' : 'mid';

        const iso = ISO[key.replace(/ E$/, ' S')] || {};

        out.push('');
        out.push('    wall ' + side + '   run along ' + (axisOf(side) ? 'y' : 'x') +
                 (run.exact ? '' : '   (portal run NOT exact - widths scaled)'));
        out.push('      SLOT     KIND      layout lo..hi   end     portal lo..hi   end   verdict' +
                 '        angled lo..hi   (stale, never judged)');
        let nbad = 0, nstale = 0;
        for (const r of rows) {
          const oid = shell === 'in' ? r.id.slice(0, -1) : r.id;
          const p = port[oid];
          const be = endOf(r.lo, r.hi, bLo, bHi);
          const pe = p ? endOf(p[0], p[1], pLo, pHi) : '?';
          let verdict = '(no portal piece)';
          if (p) {
            if (shell === 'out') {
              verdict = (Math.abs(p[0] - r.lo) < 0.01 && Math.abs(p[1] - r.hi) < 0.01)
                ? 'same' : 'MOVED';
            } else {
              verdict = (be === pe) ? 'same end' : 'MOVED';
            }
            if (verdict === 'MOVED') nbad++;
          }
          const a = iso[oid];
          // Only the OUTER shell is comparable to the iso snapshot: the inner
          // shell's assign makes wallPanelRun scale widths, so its numbers are
          // not the outer run's and a diff there would be an artefact.
          if (shell === 'out' && a && p && Math.abs(a[0] - p[0]) > 0.01) nstale++;
          out.push('      ' + r.id.padEnd(8) + ' ' + r.sk.padEnd(8) +
                   (r.lo.toFixed(2) + '..' + r.hi.toFixed(2)).padStart(15) + '  ' + be.padEnd(6) +
                   (p ? (p[0].toFixed(2) + '..' + p[1].toFixed(2)).padStart(15) : '      -       ') +
                   '  ' + pe.padEnd(5) + ' ' + verdict.padEnd(14) +
                   (a ? (a[0].toFixed(2) + '..' + a[1].toFixed(2)).padStart(15) : '        -      '));
        }
        if (nstale) {
          staleWalls.push(key + '  ' + shell + '  ' + side);
          out.push('      note: the ANGLED view disagrees with the portal plan on ' + nstale +
                   ' slot(s) here.');
          out.push('            That is the angled view being a 2026-08-07 snapshot of' +
                   ' wr-booth-data.rb,');
          out.push('            not a second opinion. Benton\'s "portal" render is this view.');
        }
        checked++;
        if (nbad) {
          bad++;
          badList.push(key + '  ' + shell + '  ' + side);
          const bOrder = rows.slice().sort((a, b) => a.lo - b.lo).map(r => r.id).join(' ');
          const pOrder = Object.keys(port).sort((a, b) => port[a][0] - port[b][0]).join(' ');
          out.push('      layout, low->high : ' + bOrder);
          out.push('      PORTAL, low->high : ' + pOrder);
          out.push('      => *** DISAGREES on ' + nbad + ' slot(s)');
        } else {
          out.push('      => agrees with the portal plan');
        }
      }
    }
    out.push('');
  }
  out.push('='.repeat(96));
  out.push('VERDICT  layout (wr-booth-data.rb)  vs  portal 2D plan (wallPanelRun executed)');
  out.push('  ' + checked + ' wall(s) compared: ' + bad + ' DISAGREE');
  for (const b of badList) out.push('    ' + b);
  out.push('');
  out.push('CONTEXT  portal ANGLED view (booth-iso-geometry.json, snapshot ' +
           (ISODOC.generated || '?').slice(0, 10) + ')');
  out.push('  ' + staleWalls.length + ' wall(s) where the angled view disagrees with the' +
           ' portal 2D plan.');
  out.push('  This is STALENESS, not a second opinion: that file is parsed from');
  out.push('  wr-booth-data.rb. It is never used as a verdict here.');
  for (const b of staleWalls) out.push('    ' + b);
  console.log(out.join('\n'));
  process.exit(bad ? 1 : 0);
}
main();
