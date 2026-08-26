/* Run the fixture _dimensions.json through the REAL ingest contract.
 *
 * `loadDimensionsJson` below is copied VERBATIM from
 * C:\Users\bento\Documents\Claude\WhisperRoomQuote\scripts\prism-audit.js:127-148
 * (v2.380.0, read 2026-08-26). Copied rather than required for two reasons: the
 * WhisperRoomQuote repo is read-only from here, and prism-audit.js runs its
 * whole sweep at require time and needs the art root mounted.
 *
 * The brief says the code is the contract wherever the prose and the code
 * disagree, so the assertions below are written against what this function
 * does, not against the spec table. Two of them exist only because reading it
 * changed the design:
 *   - `out.set(r.scene, ...)` keys on scene, so two rows sharing a scene name
 *     silently overwrite each other. That is why a multi-part scene emits a
 *     `parts` array instead of two rows.
 *   - `r.bbox.w` is read unconditionally, so a row with no `bbox` throws and
 *     takes the whole audit down. That is why an unresolved row still carries
 *     a zero box.
 *
 *     node .forge/builder/check-dimensions-ingest.js
 */
'use strict';
const fs = require('fs');
const path = require('path');

/* ─── verbatim from prism-audit.js:127-148 ─────────────────────────────── */
/* `_dimensions.json` (spec §6, "declared (future)") — preferred over the
   diagnostics when present beside them. Expected: an array of
   { scene, component, bbox:{w,d,h}, bbox_kind, z_base, anchor,
     body:{w,d,h}?, proud? } per .forge/researcher/declared-vs-prism.md §3.
   `proud` may be the spec'd {left,right,top,bottom} distances or a future
   array of positioned boxes [{name, w,d,h, off:{x,y,z}}] — both are carried
   through; only the positioned-box form can feed the crossing flag. */
function loadDimensionsJson(file) {
  if (!fs.existsSync(file)) return null;
  const rows = JSON.parse(fs.readFileSync(file, 'utf8'));
  const out = new Map();
  for (const r of (Array.isArray(rows) ? rows : rows.scenes || [])) {
    out.set(r.scene, {
      comp: r.component || r.scene,
      w: r.bbox.w, d: r.bbox.d, h: r.bbox.h,
      kind: r.bbox_kind, zBase: r.z_base,
      body: r.body || null, proud: r.proud || null,
      src: 'dimensions.json',
    });
  }
  return out;
}
/* ─── end verbatim ─────────────────────────────────────────────────────── */

const FILE = path.join(__dirname, 'fixture', '_dimensions.json');
const raw = fs.readFileSync(FILE, 'utf8');
const rows = JSON.parse(raw);

let fails = 0;
function ok(cond, label, detail) {
  if (cond) { console.log('  ok    ' + label); return; }
  fails++;
  console.log('  FAIL  ' + label + (detail ? '  — ' + detail : ''));
}

console.log('\n_dimensions.json contract check');
console.log('  file  ' + FILE + '  (' + rows.length + ' rows)\n');

/* 1. It survives the ingest at all. */
let map = null;
try { map = loadDimensionsJson(FILE); } catch (e) { }
ok(map instanceof Map, 'the real ingest parses it without throwing');
ok(map && map.size === rows.length,
   'every row lands its own key — no scene collision',
   map ? map.size + ' keys for ' + rows.length + ' rows' : 'no map');

/* 2. Array of objects. */
ok(Array.isArray(rows), 'top level is an array');
ok(rows.every(r => r && typeof r === 'object' && !Array.isArray(r)),
   'every element is an object');

/* 3. Every required field, on every row, of the right type. */
const need = ['scene', 'component', 'bbox', 'bbox_kind', 'z_base'];
for (const k of need) {
  ok(rows.every(r => r[k] !== undefined), 'every row has `' + k + '`',
     rows.filter(r => r[k] === undefined).map(r => r.scene).join(', '));
}
ok(rows.every(r => typeof r.scene === 'string' && r.scene.length),
   '`scene` is a non-empty string on every row');
ok(rows.every(r => r.bbox && ['w', 'd', 'h'].every(a => typeof r.bbox[a] === 'number')),
   '`bbox` is {w,d,h} numbers on every row — r.bbox.w never throws');
ok(rows.every(r => typeof r.z_base === 'number'), '`z_base` is a number on every row');
ok(rows.every(r => r.anchor && ['x', 'y', 'z'].every(a => typeof r.anchor[a] === 'number')),
   '`anchor` is {x,y,z} numbers on every row');

/* 4. Inches, three decimals. The literal text is checked, not the parsed
 *    number: 81.0 and 81.000 parse identically and the brief's complaint is
 *    about PRECISION LOST BEFORE the file is written. A number written with
 *    fewer than three decimals is a number that was rounded. */
const nums = raw.match(/:\s*(-?\d+(?:\.\d*)?)/g) || [];
const badPrec = nums.filter(s => !/\.\d{3}$/.test(s.trim().replace(/^:\s*/, '')));
ok(badPrec.length === 0, 'every numeric value is written to exactly three decimals',
   badPrec.slice(0, 6).join(' '));
ok(!/-0\.000/.test(raw), 'no "-0.000" anywhere');
ok(!/(NaN|Infinity)/.test(raw), 'no NaN or Infinity');

/* 5. bbox_kind is the literal "visible" where it is a real measurement, and
 *    something else — never a silent raw bound — where it is not. */
const visible = rows.filter(r => r.bbox_kind === 'visible');
ok(visible.length > 0, '`bbox_kind` is the literal string "visible" on measured rows',
   visible.length + ' of ' + rows.length);
const notVisible = rows.filter(r => r.bbox_kind !== 'visible');
ok(notVisible.every(r => typeof r.note === 'string' && r.note.length),
   'every row that is NOT "visible" carries a note saying why',
   notVisible.filter(r => !r.note).map(r => r.scene).join(', '));
ok(notVisible.every(r => r.bbox_kind !== 'visible'),
   'no row fakes "visible"');

/* 6. body is required whenever proud is present. */
ok(rows.every(r => !r.proud || r.body), '`body` present whenever `proud` is');

/* 7. One row per part even when one scene holds two — carried as `parts`,
 *    because the ingest's Map would swallow a duplicate `scene`. */
const assemblies = rows.filter(r => r.parts);
ok(assemblies.every(r => r.parts.length >= 2),
   'a `parts` array never has fewer than two parts');
ok(assemblies.every(r => r.parts.every(p =>
     p.bbox && typeof p.z_base === 'number' && typeof p.bbox_kind === 'string')),
   'every part carries its own bbox, bbox_kind and z_base');
ok(assemblies.length > 0, 'the multi-part case is exercised at least once');

/* 8. The rule-2 evidence: raw bounds and visible bounds actually differ where
 *    the researcher measured that they should. */
const door = rows.find(r => /Door/.test(r.scene));
ok(door && door.raw_bbox && door.raw_bbox.d > door.bbox.d + 20,
   'the door row shows raw bounds carrying tens of inches the visible box does not',
   door ? door.bbox.d + ' visible vs ' + (door.raw_bbox || {}).d + ' raw' : 'no door row');

/* 9. The join key is the PNG stem. loadDimensionsJson does no "ENH " stripping
 *    (parseDiagnostics does, on the other path), so an ENH row whose `scene`
 *    still carried the scene label would never join. */
const enh = rows.filter(r => /^ENH /.test(r.scene));
ok(enh.length === 0, '`scene` is the PNG stem — no row starts with the "ENH " scene label',
   enh.map(r => r.scene).join(', '));

/* 10. What the ingest actually hands the audit. */
if (map) {
  console.log('\n  as the audit sees it:');
  for (const [scene, v] of map)
    console.log('    ' + scene.padEnd(24) + ' -> ' + v.comp.padEnd(24) +
                (v.w.toFixed(3) + ' x ' + v.d.toFixed(3) + ' x ' + v.h.toFixed(3)).padStart(26) +
                '  z0 ' + v.zBase.toFixed(3) + '  [' + v.kind + ']');
}

console.log('\n' + (fails ? fails + ' CHECK(S) FAILED' : 'all checks passed') + '\n');
process.exit(fails ? 1 : 0);
