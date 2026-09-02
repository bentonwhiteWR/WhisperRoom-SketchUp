// Read-only static server for WhisperRoomQuote so booth-builder.html can be driven
// headlessly. Mimics the two public data routes and the flag rewrites quote-server.js
// applies to /booth-builder (top-down art, angled view scripts, BB2). Never writes.
'use strict';
const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = 'C:/Users/bento/Documents/Claude/WhisperRoomQuote';
const PORT = +process.env.PORT || 8765;
const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css',
  '.json': 'application/json', '.png': 'image/png', '.webp': 'image/webp', '.avif': 'image/avif',
  '.svg': 'image/svg+xml', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.woff2': 'font/woff2',
  '.woff': 'font/woff', '.ico': 'image/x-icon', '.txt': 'text/plain'
};

function builderHtml() {
  let html = fs.readFileSync(path.join(ROOT, 'booth-builder.html'), 'utf8');
  const tag = '<script src="/assets/layout-render.js"></script>';
  html = html.replace(tag, '<script>window.__WR_TOPDOWN_ART__=true;</script>\n' + tag);
  html = html.replace('window.__WR_ANGLED_VIEW_ENABLED__ = false;', () => 'window.__WR_ANGLED_VIEW_ENABLED__ = true;');
  html = html.replace(tag, tag + '\n<script src="/assets/iso30-manifest.js"></script>\n<script src="/assets/iso-render.js"></script>');
  html = html.replace('window.__WR_BB2_ENABLED__ = false;', () => 'window.__WR_BB2_ENABLED__ = true;');
  return html;
}

http.createServer((req, res) => {
  const u = new URL(req.url, 'http://x');
  const p = decodeURIComponent(u.pathname);
  const send = (code, type, body) => { res.writeHead(code, { 'content-type': type, 'cache-control': 'no-cache' }); res.end(body); };
  try {
    if (p === '/booth-builder' || p === '/booth-builder.html') return send(200, MIME['.html'], builderHtml());
    if (p === '/api/booth-layouts') return send(200, MIME['.json'], fs.readFileSync(path.join(ROOT, 'lib/pl-data/booth-layouts.json')));
    if (p === '/api/booth-iso-geometry') return send(200, MIME['.json'], fs.readFileSync(path.join(ROOT, 'lib/pl-data/booth-iso-geometry.json')));
    if (p.startsWith('/api/')) return send(404, MIME['.json'], '{"error":"not served by research stub"}');
    const f = path.join(ROOT, p);
    if (!f.startsWith(ROOT.replace(/\//g, path.sep)) && !f.startsWith(ROOT)) return send(403, 'text/plain', 'no');
    if (!fs.existsSync(f) || fs.statSync(f).isDirectory()) return send(404, 'text/plain', 'not found: ' + p);
    return send(200, MIME[path.extname(f).toLowerCase()] || 'application/octet-stream', fs.readFileSync(f));
  } catch (e) { return send(500, 'text/plain', String(e && e.stack || e)); }
}).listen(PORT, '127.0.0.1', () => console.log('serving ' + ROOT + ' on http://127.0.0.1:' + PORT));
