// Who retains the big ArrayBuffers in a .heapsnapshot? Walk reverse edges from
// every 'system / JSArrayBufferData' node and aggregate retainer paths by bytes.
'use strict';
const fs = require('fs');
const file = process.argv[2];
const snap = JSON.parse(fs.readFileSync(file, 'utf8'));
const meta = snap.snapshot.meta;
const NF = meta.node_fields.length, EF = meta.edge_fields.length;
const nTypeI = meta.node_fields.indexOf('type'), nNameI = meta.node_fields.indexOf('name'), nSizeI = meta.node_fields.indexOf('self_size'), nEdgeCountI = meta.node_fields.indexOf('edge_count');
const eTypeI = meta.edge_fields.indexOf('type'), eNameI = meta.edge_fields.indexOf('name_or_index'), eToI = meta.edge_fields.indexOf('to_node');
const nodeTypes = meta.node_types[0], edgeTypes = meta.edge_types[0];
const N = snap.nodes, E = snap.edges, S = snap.strings;
const nodeCount = N.length / NF;
const name = i => S[N[i * NF + nNameI]];
const type = i => nodeTypes[N[i * NF + nTypeI]];
const size = i => N[i * NF + nSizeI];
// first edge index per node
const firstEdge = new Uint32Array(nodeCount + 1);
for (let i = 0, e = 0; i < nodeCount; i++) { firstEdge[i] = e; e += N[i * NF + nEdgeCountI]; firstEdge[nodeCount] = e; }
// reverse adjacency
const revCount = new Uint32Array(nodeCount);
for (let i = 0; i < nodeCount; i++) for (let e = firstEdge[i]; e < firstEdge[i + 1]; e++) revCount[E[e * EF + eToI] / NF]++;
const revStart = new Uint32Array(nodeCount + 1);
for (let i = 0; i < nodeCount; i++) revStart[i + 1] = revStart[i] + revCount[i];
const revFrom = new Uint32Array(revStart[nodeCount]), revEdge = new Uint32Array(revStart[nodeCount]);
const fill = new Uint32Array(nodeCount);
for (let i = 0; i < nodeCount; i++) for (let e = firstEdge[i]; e < firstEdge[i + 1]; e++) { const to = E[e * EF + eToI] / NF; const k = revStart[to] + fill[to]++; revFrom[k] = i; revEdge[k] = e; }
const edgeLabel = e => { const t = edgeTypes[E[e * EF + eTypeI]]; const n = E[e * EF + eNameI]; return t === 'element' || t === 'hidden' ? '[' + n + ']' : (t === 'internal' ? '<' + S[n] + '>' : (t === 'weak' ? '~' + S[n] : S[n])); };
const isWeak = e => edgeTypes[E[e * EF + eTypeI]] === 'weak';
const isShortcut = e => edgeTypes[E[e * EF + eTypeI]] === 'shortcut';

const targets = [];
for (let i = 0; i < nodeCount; i++) if (name(i) === 'system / JSArrayBufferData') targets.push(i);
const total = targets.reduce((s, i) => s + size(i), 0);
console.log('JSArrayBufferData nodes', targets.length, 'MB', (total / 1048576).toFixed(1));
// size histogram
const hist = {}; for (const t of targets) { const k = size(t); hist[k] = (hist[k] || 0) + 1; }
console.log('size histogram (bytes: count):', Object.entries(hist).sort((a, b) => b[0] * b[1] - a[0] * a[1]).slice(0, 8).map(([k, v]) => k + ':' + v).join(', '));

// path: buffer <- ArrayBuffer <- TypedArray/ImageData <- owner (with edge name) <- owner2 ...
function retPath(i, depth) {
  const path = [];
  let cur = i; const seen = new Set([i]);
  for (let d = 0; d < depth; d++) {
    let best = -1, bestE = -1;
    for (let k = revStart[cur]; k < revStart[cur + 1]; k++) {
      const f = revFrom[k], e = revEdge[k];
      if (isWeak(e) || isShortcut(e) || seen.has(f)) continue;
      const nm = name(f), ty = type(f);
      if (ty === 'synthetic' || nm === '(GC roots)') continue;
      // prefer named object owners over system/hidden
      const score = (ty === 'object' || ty === 'closure' || ty === 'native') ? 2 : (nm.startsWith('system /') ? 0 : 1);
      if (best < 0 || score > best) { best = score; bestE = k; }
    }
    if (bestE < 0) break;
    const f = revFrom[bestE], e = revEdge[bestE];
    path.push(edgeLabel(e) + ' <- ' + type(f) + ':' + name(f).slice(0, 50));
    seen.add(f); cur = f;
  }
  return path;
}
const agg = {};
for (const t of targets) {
  const p = retPath(t, 6);
  const key = p.slice(0, 6).join('  |  ');
  agg[key] = agg[key] || { n: 0, bytes: 0 }; agg[key].n++; agg[key].bytes += size(t);
}
for (const [k, v] of Object.entries(agg).sort((a, b) => b[1].bytes - a[1].bytes).slice(0, 15)) console.log(`\n${(v.bytes / 1048576).toFixed(1)} MB  x${v.n}\n  ${k}`);
