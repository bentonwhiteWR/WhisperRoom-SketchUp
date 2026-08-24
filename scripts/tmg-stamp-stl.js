#!/usr/bin/env node
/*
 * TMG pottery stamp — STL generator.
 *
 * There is no CAD source for this part. The design lives in the reviewed Claude
 * Artifact "TMG Pottery Stamp" (f1b6983f), which carries the whole parametric
 * model in plain JavaScript but has no export. So this script reads the saved
 * artifact HTML and lifts the geometry data straight out of it — the LOGO
 * polygons, the PROF lathe profile, Y_FACE / RELIEF, and the artifact's own
 * ringArea() and faceQuads() functions, evaluated from the page's own source
 * rather than retyped. Nothing here is a transcription; if the artifact and
 * this file ever disagree, the artifact is right and this file is stale.
 *
 * Node, not Python, unlike scripts/spray-guide-stl.py and
 * scripts/pendant-jig-stl.py — because the design data is JavaScript and the
 * scanline tessellator is reused verbatim from the page instead of being
 * ported. Same folder, same shape, same self-audit.
 *
 *     node scripts/tmg-stamp-stl.js [-o out.stl] [--size 14] [--seg 256] [--svg]
 *
 * Writes a binary STL in millimetres, then self-audits:
 *   * every directed edge used exactly once  ->  closed, orientable, manifold
 *   * mesh volume by the divergence theorem  vs  the artifact's own figure
 *   * bounding box and degenerate-triangle count
 * A manifold failure or a negative volume refuses to write the file.
 *
 * ORIENTATION, and it is the one thing that cannot be fixed after printing:
 * the relief on the stamp face is the MIRROR of the logo as drawn, so the
 * impression pressed into the clay reads correctly. See mirroring notes below.
 */

'use strict';

const fs = require('fs');
const path = require('path');

// ------------------------------------------------------------------ paths --
const REPO = path.resolve(__dirname, '..');
const ARTIFACT = path.join(
  process.env.USERPROFILE || process.env.HOME || '',
  '.claude', 'projects', 'C--Users-bento-Documents-Claude-Sketchup',
  '28e6a9e7-0bff-44ac-9475-ea99bda58ca6', 'tool-results',
  'artifact-f1b6983f-1787441161-c136.html'
);

// --------------------------------------------------------------- CLI args --
function args(argv) {
  const o = { out: null, size: 14, seg: 256, svg: false, src: ARTIFACT };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === '-o' || a === '--out') o.out = argv[++i];
    else if (a === '--size') o.size = +argv[++i];
    else if (a === '--seg') o.seg = +argv[++i];
    else if (a === '--src') o.src = argv[++i];
    else if (a === '--svg') o.svg = true;
    else { console.error('unknown argument: ' + a); process.exit(2); }
  }
  if (!o.out) o.out = path.join(REPO, 'exports', `tmg-stamp-${o.size}mm.stl`);
  return o;
}

// ------------------------------------------------------- artifact reading --
/* Scan forward from `from` and return the balanced {...} or [...] literal. */
function balanced(text, from, open, close) {
  const s = text.indexOf(open, from);
  if (s < 0) throw new Error('literal not found');
  let depth = 0;
  for (let i = s; i < text.length; i++) {
    if (text[i] === open) depth++;
    else if (text[i] === close && --depth === 0) return text.slice(s, i + 1);
  }
  throw new Error('unbalanced literal');
}

function readArtifact(file) {
  const html = fs.readFileSync(file, 'utf8');

  const logoSrc = balanced(html, html.indexOf('const LOGO'), '{', '}');
  const profSrc = balanced(html, html.indexOf('const PROF'), '[', ']');
  const LOGO = JSON.parse(logoSrc);              // the page emits strict JSON here
  const PROF = JSON.parse(profSrc);

  const num = (name) => {
    const m = html.match(new RegExp('\\b' + name + '\\s*=\\s*(-?[0-9.]+)'));
    if (!m) throw new Error('constant not found: ' + name);
    return parseFloat(m[1]);
  };
  const Y_FACE = num('Y_FACE'), RELIEF = num('RELIEF'), BASE_D = num('BASE_D');

  // The page's own tessellator and area helper, evaluated from its own source.
  const ringAreaSrc = html.slice(
    html.indexOf('const ringArea'),
    html.indexOf('\n', html.indexOf('const ringArea')) + 1);
  const fqStart = html.indexOf('function faceQuads');
  const fqSrc = 'function faceQuads(rings)' +
    balanced(html, fqStart, '{', '}').slice(balanced(html, fqStart, '{', '}').indexOf('{'));
  const mod = new Function(
    ringAreaSrc + '\n' + fqSrc + '\nreturn {ringArea, faceQuads};')();

  return { LOGO, PROF, Y_FACE, RELIEF, BASE_D, ...mod, html };
}

// ------------------------------------------------------------------- mesh --
class Mesh {
  constructor() { this.V = []; this.T = []; this.idx = new Map(); }
  v(p) {
    const k = Math.round(p[0] * 1e7) + ',' + Math.round(p[1] * 1e7) + ',' +
              Math.round(p[2] * 1e7);
    let i = this.idx.get(k);
    if (i === undefined) { i = this.V.length; this.V.push(p); this.idx.set(k, i); }
    return i;
  }
  /* Triangle by index, wound so its normal agrees with `expect`. */
  tri(ia, ib, ic, expect) {
    if (ia === ib || ib === ic || ic === ia) return;
    const A = this.V[ia], B = this.V[ib], C = this.V[ic];
    const ux = B[0] - A[0], uy = B[1] - A[1], uz = B[2] - A[2];
    const wx = C[0] - A[0], wy = C[1] - A[1], wz = C[2] - A[2];
    const nx = uy * wz - uz * wy, ny = uz * wx - ux * wz, nz = ux * wy - uy * wx;
    if (nx * expect[0] + ny * expect[1] + nz * expect[2] < 0) this.T.push([ia, ic, ib]);
    else this.T.push([ia, ib, ic]);
  }
  quad(a, b, c, d, expect) { this.tri(a, b, c, expect); this.tri(a, c, d, expect); }
}

// ------------------------------------------------------------- 2D helpers --
const EPSY = 1e-6;

/* Insert a vertex wherever a scanline y crosses an edge, so that no edge of any
 * ring spans more than one band. This is what keeps the face tessellation and
 * the relief side walls sharing identical boundary vertices — without it the
 * scanline splits long edges and leaves T-junctions, which is fine for the
 * artifact's renderer and fatal for a printable solid. */
function refine(ring, ys) {
  const pts = [], param = [];
  for (let i = 0; i < ring.length; i++) {
    const a = ring[i], b = ring[(i + 1) % ring.length];
    pts.push(a); param.push([i, 0]);
    const lo = Math.min(a[1], b[1]), hi = Math.max(a[1], b[1]);
    if (hi - lo <= EPSY) continue;
    const cut = ys.filter(y => y > lo + EPSY && y < hi - EPSY);
    if (a[1] > b[1]) cut.reverse();
    for (const y of cut) {
      const t = (y - a[1]) / (b[1] - a[1]);
      pts.push([a[0] + t * (b[0] - a[0]), y]);   // y set exactly, not interpolated
      param.push([i, t]);
    }
  }
  return { pts, param };
}

function orient(ring, wantCCW, ringArea) {
  return (ringArea(ring) < 0) === wantCCW ? ring.slice().reverse() : ring;
}

// ------------------------------------------------------------------ build --
function build(A, size, seg) {
  const { LOGO, PROF, Y_FACE, RELIEF, BASE_D, ringArea, faceQuads } = A;
  const key = String(size);
  if (!LOGO[key]) throw new Error('no artwork for size ' + size);
  const k = size / BASE_D;
  const Z_FACE = Y_FACE * k, Z_TOP = (Y_FACE + RELIEF) * k;

  /* MIRRORING. The artifact draws the mark at (u, v). Its own flat previews use
   * paintFlat(faceCv, /*mirror*\/ true) for the stamp face and
   * paintFlat(clayCv, /*mirror*\/ false) for the impression, and its 3D mesh maps
   * the artwork with toXZ = (u,v) => [-u,-v] which, under the page's "face" camera
   * (rx=PI/2, ry=0, looking down +Y), lands on screen at (-u, -v) — x negated
   * against the drawn mark. Both say the same thing: the relief on the stamp is
   * the left-right mirror of the logo. Here, Z-up, that is X = -u, Y = +v. */
  const map = (q) => [-q[0] * k, q[1] * k];

  const polys = LOGO[key].polys.map(p => ({
    e: p.e.map(map),
    h: (p.h || []).map(r => r.map(map)),
  }));

  // Body rings are one N-gon template scaled by each profile radius.
  const N = seg;
  const unit = [];
  for (let i = 0; i < N; i++) {
    const a = i / N * 2 * Math.PI;
    unit.push([Math.cos(a), Math.sin(a)]);
  }
  const rTop = PROF[PROF.length - 2][0] * k;      // 7.7 mm — the face's outer edge

  /* Every y the scanline will see, canonicalised. These have to be canonical:
   * the lathe ring's y values come out of Math.sin, so mirror-image angles land
   * ~1e-16 apart instead of equal; faceQuads then skips those hair-thin bands
   * and orphans the vertices sitting on them. So cluster every y within a micron
   * and elect one representative per cluster — an artwork y when the cluster has
   * one, so the mark's own coordinates never move, otherwise the lathe's. */
  const SNAP = 1e-6;
  const raw = [];
  for (const p of polys) {
    for (const r of [p.e].concat(p.h)) for (const q of r) raw.push([q[1], -1]);
  }
  const circleY = unit.map(c => c[1] * rTop);
  circleY.forEach((y, i) => raw.push([y, i]));
  raw.sort((x, y) => x[0] - y[0]);

  const rep = new Array(circleY.length);
  const ys = [];
  for (let i = 0; i < raw.length;) {
    let j = i, art = null;
    while (j < raw.length && raw[j][0] - raw[i][0] <= SNAP) {
      if (raw[j][1] < 0 && art === null) art = raw[j][0];
      j++;
    }
    const r = art !== null ? art : raw[i][0];
    ys.push(r);
    for (let m = i; m < j; m++) if (raw[m][1] >= 0) rep[raw[m][1]] = r;
    i = j;
  }
  const topRingRaw = unit.map((c, i) => [c[0] * rTop, rep[i]]);
  let collisions = 0;
  for (let i = 1; i < ys.length; i++) if (ys[i] - ys[i - 1] < 1e-7) collisions++;

  // Refine every ring against that y set.
  const topR = refine(topRingRaw, ys);
  const topRing = topR.pts;
  const rings = polys.map(p => ({
    e: refine(p.e, ys).pts,
    h: p.h.map(h => refine(h, ys).pts),
  }));

  /* The top ring gained vertices; every other body ring has to gain the same
   * ones at the same parametric places, or the side quads stop lining up. The
   * refinement hands back exactly that (segment, fraction) list. */
  const tmpl = topR.param;
  const M = tmpl.length;
  const ringAt = (r) => tmpl.map(([s, t]) => {
    const a = unit[s % N], b = unit[(s + 1) % N];
    return [(a[0] + t * (b[0] - a[0])) * r, (a[1] + t * (b[1] - a[1])) * r];
  });

  const mesh = new Mesh();
  const artRmax = Math.max(...polys.flatMap(p => p.e.map(q => Math.hypot(q[0], q[1]))));
  if (artRmax >= rTop * Math.cos(Math.PI / N)) {
    throw new Error(`artwork radius ${artRmax.toFixed(3)} spills past the face edge`);
  }

  // --- body: bottom cap, then one band per profile segment ------------------
  const prof = PROF.map(p => [p[0] * k, p[1] * k]);
  const r0 = prof[1][0];
  const base = ringAt(r0).map(c => mesh.v([c[0], c[1], 0]));
  const ctr = mesh.v([0, 0, 0]);
  for (let i = 0; i < M; i++) mesh.tri(ctr, base[i], base[(i + 1) % M], [0, 0, -1]);

  let lower = base, lowerP = prof[1];
  for (let s = 2; s < prof.length - 1; s++) {
    const [r, z] = prof[s];
    const upper = (s === prof.length - 2 ? topRing : ringAt(r))
      .map(c => mesh.v([c[0], c[1], z]));
    const dz = z - lowerP[1], dr = r - lowerP[0];
    for (let i = 0; i < M; i++) {
      const j = (i + 1) % M;
      const cx = (mesh.V[lower[i]][0] + mesh.V[lower[j]][0]) / 2;
      const cy = (mesh.V[lower[i]][1] + mesh.V[lower[j]][1]) / 2;
      const L = Math.hypot(cx, cy) || 1;
      mesh.quad(lower[i], lower[j], upper[j], upper[i],
                [dz * cx / L, dz * cy / L, -dr]);
    }
    lower = upper; lowerP = [r, z];
  }
  // the topmost body ring must BE the refined face boundary, not a fresh N-gon
  const faceRing = topRing.map(c => mesh.v([c[0], c[1], Z_FACE]));
  for (let i = 0; i < M; i++) {
    if (faceRing[i] !== lower[i]) throw new Error('face ring / body ring mismatch');
  }

  // --- the flat face at z = Z_FACE: disc minus the artwork footprint --------
  const faceRings = [topRing];
  for (const p of rings) { faceRings.push(p.e); for (const h of p.h) faceRings.push(h); }
  let faceQ = 0;
  for (const q of faceQuads(faceRings)) {
    const v = q.map(c => mesh.v([c[0], c[1], Z_FACE]));
    mesh.quad(v[0], v[1], v[2], v[3], [0, 0, 1]); faceQ++;
  }

  // --- the relief: side walls on every ring, plus the top at z = Z_TOP ------
  let topQ = 0, wallE = 0;
  for (const p of rings) {
    for (const q of faceQuads([p.e].concat(p.h))) {
      const v = q.map(c => mesh.v([c[0], c[1], Z_TOP]));
      mesh.quad(v[0], v[1], v[2], v[3], [0, 0, 1]); topQ++;
    }
    for (const raw of [[p.e, true]].concat(p.h.map(h => [h, false]))) {
      const r = orient(raw[0], raw[1], ringArea);   // outer CCW, holes CW
      const b = r.map(c => mesh.v([c[0], c[1], Z_FACE]));
      const t = r.map(c => mesh.v([c[0], c[1], Z_TOP]));
      for (let i = 0; i < r.length; i++) {
        const j = (i + 1) % r.length;
        mesh.quad(b[i], b[j], t[j], t[i],
                  [r[j][1] - r[i][1], -(r[j][0] - r[i][0]), 0]); wallE++;
      }
    }
  }

  // The artifact's own volume figure, its formula, its numbers.
  let BODYVOL = 0;
  for (let i = 0; i < PROF.length - 1; i++) {
    const a = PROF[i], b = PROF[i + 1];
    BODYVOL += Math.PI * Math.abs(b[1] - a[1]) / 3 *
               (a[0] * a[0] + a[0] * b[0] + b[0] * b[0]);
  }
  let artArea = 0;
  for (const p of LOGO[key].polys) {
    artArea += Math.abs(ringArea(p.e));
    for (const h of (p.h || [])) artArea -= Math.abs(ringArea(h));
  }
  const refVol = (BODYVOL + artArea * RELIEF) * k * k * k;

  return { mesh, refVol, stats: { N, M, faceQ, topQ, wallE, collisions, artRmax,
                                  Z_FACE, Z_TOP, polys, rTop } };
}

// ---------------------------------------------------------- T-junction fix --
/* faceQuads conserves area but not topology. At every band boundary where the
 * crossing set changes — a ring's local extremum, or a horizontal ring edge —
 * the quad below spans a horizontal edge that the quads above split in two, and
 * the mesh gets a T-junction: an edge with no single partner. Harmless in the
 * artifact's renderer, fatal in a printable solid.
 *
 * Every such edge is horizontal and lies in one of the two flat planes, so the
 * repair is local: find each horizontal triangle edge, insert every mesh vertex
 * that sits strictly inside it, and re-fan the triangle from its own centroid
 * (an apex corner would give collinear slivers when the split edge touches it).
 * The surface does not move — only its subdivision does. */
function fixTJunctions(mesh) {
  const Q = v => Math.round(v * 1e7);
  const rows = new Map();
  mesh.V.forEach((p, i) => {
    const k = Q(p[2]) + '|' + Q(p[1]);
    if (!rows.has(k)) rows.set(k, []);
    rows.get(k).push([p[0], i]);
  });
  for (const g of rows.values()) g.sort((a, b) => a[0] - b[0]);

  const out = [];
  let split = 0;
  for (const t of mesh.T) {
    const ins = [[], [], []];
    let any = false;
    for (let e = 0; e < 3; e++) {
      const A = mesh.V[t[e]], B = mesh.V[t[(e + 1) % 3]];
      if (Q(A[1]) !== Q(B[1]) || Q(A[2]) !== Q(B[2])) continue;
      const g = rows.get(Q(A[2]) + '|' + Q(A[1]));
      if (!g) continue;
      const lo = Math.min(A[0], B[0]), hi = Math.max(A[0], B[0]);
      const hit = g.filter(([x]) => x > lo + 1e-9 && x < hi - 1e-9).map(([, i]) => i);
      if (!hit.length) continue;
      if (A[0] > B[0]) hit.reverse();
      ins[e] = hit; any = true;
    }
    if (!any) { out.push(t); continue; }
    const poly = [];
    for (let e = 0; e < 3; e++) { poly.push(t[e]); for (const i of ins[e]) poly.push(i); }
    const c = [0, 0, 0];
    for (const i of poly) for (let d = 0; d < 3; d++) c[d] += mesh.V[i][d] / poly.length;
    const ic = mesh.v(c);
    for (let i = 0; i < poly.length; i++) {
      out.push([ic, poly[i], poly[(i + 1) % poly.length]]);
    }
    split++;
  }
  mesh.T = out;
  return split;
}

// ------------------------------------------------------------------ audit --
function audit(mesh) {
  const seen = new Map();
  let degenerate = 0, vol = 0, minA = Infinity;
  const bb = [[Infinity, Infinity, Infinity], [-Infinity, -Infinity, -Infinity]];
  for (const p of mesh.V) for (let d = 0; d < 3; d++) {
    if (p[d] < bb[0][d]) bb[0][d] = p[d];
    if (p[d] > bb[1][d]) bb[1][d] = p[d];
  }
  for (const [a, b, c] of mesh.T) {
    for (const e of [[a, b], [b, c], [c, a]]) {
      const k = e[0] + ':' + e[1];
      seen.set(k, (seen.get(k) || 0) + 1);
    }
    const A = mesh.V[a], B = mesh.V[b], C = mesh.V[c];
    vol += (A[0] * (B[1] * C[2] - B[2] * C[1]) +
            A[1] * (B[2] * C[0] - B[0] * C[2]) +
            A[2] * (B[0] * C[1] - B[1] * C[0])) / 6;
    const ux = B[0] - A[0], uy = B[1] - A[1], uz = B[2] - A[2];
    const wx = C[0] - A[0], wy = C[1] - A[1], wz = C[2] - A[2];
    const area = Math.hypot(uy * wz - uz * wy, uz * wx - ux * wz,
                            ux * wy - uy * wx) / 2;
    if (area < 1e-9) degenerate++;
    if (area < minA) minA = area;
  }
  let dup = 0, unpaired = 0;
  for (const [k, n] of seen) {
    if (n !== 1) dup++;
    const [a, b] = k.split(':');
    if (!seen.has(b + ':' + a)) unpaired++;
  }
  return { vol, bb, degenerate, minArea: minA, dup, unpaired, edges: seen.size };
}

// -------------------------------------------------------------- STL write --
function writeSTL(file, mesh, header) {
  const n = mesh.T.length;
  const buf = Buffer.alloc(84 + n * 50);
  buf.write(header.slice(0, 79).padEnd(80, ' '), 0, 80, 'ascii');
  buf.writeUInt32LE(n, 80);
  let o = 84;
  for (const [ia, ib, ic] of mesh.T) {
    const A = mesh.V[ia], B = mesh.V[ib], C = mesh.V[ic];
    const ux = B[0] - A[0], uy = B[1] - A[1], uz = B[2] - A[2];
    const wx = C[0] - A[0], wy = C[1] - A[1], wz = C[2] - A[2];
    let nx = uy * wz - uz * wy, ny = uz * wx - ux * wz, nz = ux * wy - uy * wx;
    const m = Math.hypot(nx, ny, nz) || 1;
    buf.writeFloatLE(nx / m, o); buf.writeFloatLE(ny / m, o + 4);
    buf.writeFloatLE(nz / m, o + 8); o += 12;
    for (const p of [A, B, C]) {
      buf.writeFloatLE(p[0], o); buf.writeFloatLE(p[1], o + 4);
      buf.writeFloatLE(p[2], o + 8); o += 12;
    }
    buf.writeUInt16LE(0, o); o += 2;
  }
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, buf);
  return buf.length;
}

// ------------------------------------------------------- visual sanity SVG --
function writeSVG(file, st) {
  const R = st.rTop + 0.4;
  const pane = (flip, label, x0) => {
    const d = st.polys.map(p => [p.e].concat(p.h).map(r =>
      'M' + r.map(q => ((flip ? -q[0] : q[0])).toFixed(3) + ',' +
                       (-q[1]).toFixed(3)).join('L') + 'Z').join('')).join('');
    return `<g transform="translate(${x0},0)">` +
      `<circle r="${st.rTop.toFixed(2)}" fill="#f3f1ee" stroke="#999" stroke-width="0.08"/>` +
      `<circle r="7" fill="none" stroke="#bbb" stroke-width="0.06" stroke-dasharray="0.4 0.35"/>` +
      `<path d="${d}" fill-rule="evenodd" fill="#1b1b1b"/>` +
      `<text y="${(R + 1.2).toFixed(2)}" text-anchor="middle" font-size="0.9"` +
      ` font-family="sans-serif" fill="#444">${label}</text></g>`;
  };
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="620" height="330"` +
    ` viewBox="${-R} ${-R} ${4 * R + 2} ${2 * R + 2}">` +
    pane(false, 'stamp face (looking down at the relief)', 0) +
    pane(true, 'impression in the clay', 2 * R + 2) + '</svg>';
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, svg);
}

// ------------------------------------------------------------------- main --
function main() {
  const o = args(process.argv);
  const A = readArtifact(o.src);
  console.log(`source      ${o.src}`);
  console.log(`artifact    PROF ${A.PROF.length} pts · Y_FACE ${A.Y_FACE} · ` +
              `RELIEF ${A.RELIEF} · sizes ${Object.keys(A.LOGO).join('/')}`);
  const p14 = A.LOGO[String(o.size)];
  console.log(`artwork     size ${o.size} · k=${(o.size / A.BASE_D).toFixed(4)} · ` +
              `${p14.polys.length} polys · ` +
              `${p14.polys.reduce((n, p) => n + p.e.length +
                 (p.h || []).reduce((m, h) => m + h.length, 0), 0)} points · ` +
              `dil ${p14.dil}`);

  const { mesh, refVol, stats } = build(A, o.size, o.seg);
  const split = fixTJunctions(mesh);
  const a = audit(mesh);

  const dx = a.bb[1][0] - a.bb[0][0], dy = a.bb[1][1] - a.bb[0][1],
        dz = a.bb[1][2] - a.bb[0][2];
  const err = 100 * (a.vol - refVol) / refVol;

  console.log(`\nmesh        ${mesh.V.length} verts · ${mesh.T.length} tris ` +
              `(lathe ${stats.N} seg -> ${stats.M} after refinement)`);
  console.log(`            face quads ${stats.faceQ} · relief top ${stats.topQ} ` +
              `· wall quads ${stats.wallE}`);
  console.log(`t-junctions ${split} triangles re-fanned to close them`);
  console.log(`mirroring   X = -u  (stamp face is the mirror of the drawn mark)`);
  console.log(`\nmanifold    ${a.edges} directed edges · ` +
              `${a.dup} used more than once · ${a.unpaired} without a reverse`);
  console.log(`degenerate  ${a.degenerate} tris under 1e-9 mm² ` +
              `(smallest ${a.minArea.toExponential(2)} mm²)`);
  console.log(`volume      mesh ${a.vol.toFixed(2)} mm³ · ` +
              `artifact ${refVol.toFixed(2)} mm³ · ${err.toFixed(3)} %`);
  console.log(`bbox        ${dx.toFixed(3)} x ${dy.toFixed(3)} x ${dz.toFixed(3)} mm ` +
              `· z ${a.bb[0][2].toFixed(3)}..${a.bb[1][2].toFixed(3)}`);
  console.log(`artwork r   ${stats.artRmax.toFixed(3)} mm (face edge ` +
              `${stats.rTop.toFixed(3)} mm) · y-collisions ${stats.collisions}`);

  const bad = [];
  if (a.dup || a.unpaired) bad.push('not manifold');
  if (a.vol <= 0) bad.push('volume not positive');
  if (Math.abs(err) > 2) bad.push('volume disagrees with the artifact by >2 %');
  if (stats.collisions) bad.push('scanline y values collide');
  if (bad.length) {
    console.error('\nREFUSING TO WRITE: ' + bad.join('; '));
    process.exit(1);
  }

  const bytes = writeSTL(o.out, mesh,
    `TMG pottery stamp ${o.size}mm - from artifact f1b6983f - mm - Z up`);
  console.log(`\nwrote       ${o.out}  (${bytes} bytes, binary STL, mm)`);

  if (o.svg) {
    const s = path.join(REPO, '.forge', 'builder', `tmg-stamp-${o.size}mm-check.svg`);
    writeSVG(s, stats);
    console.log(`wrote       ${s}`);
  }
}

main();
