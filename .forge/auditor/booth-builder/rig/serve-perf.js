// Read-only static server for WhisperRoomQuote used by the perf audit. Same route
// stubs as researcher/tools/serve.js, plus gzip for text types (production
// sendCachedEntry gzips) and env toggles for the injected feature flags.
// FLAGS=all (default) => tdArt+angled+bb2 on, like the researcher rig. FLAGS=none => raw file.
'use strict';
const http = require('http'), fs = require('fs'), path = require('path'), zlib = require('zlib');
const ROOT = 'C:/Users/bento/Documents/Claude/WhisperRoomQuote';
const PORT = +process.env.PORT || 8766;
const FLAGS = process.env.FLAGS || 'all';
const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.png': 'image/png', '.webp': 'image/webp', '.avif': 'image/avif', '.svg': 'image/svg+xml', '.jpg': 'image/jpeg', '.woff2': 'font/woff2', '.woff': 'font/woff', '.ico': 'image/x-icon', '.txt': 'text/plain' };
const COMPRESSIBLE = /^(text\/|application\/json|image\/svg)/;
function builderHtml() {
  let html = fs.readFileSync(path.join(ROOT, 'booth-builder.html'), 'utf8');
  if (FLAGS === 'none') return html;
  const tag = '<script src="/assets/layout-render.js"></script>';
  html = html.replace(tag, '<script>window.__WR_TOPDOWN_ART__=true;</script>\n' + tag);
  html = html.replace('window.__WR_ANGLED_VIEW_ENABLED__ = false;', () => 'window.__WR_ANGLED_VIEW_ENABLED__ = true;');
  html = html.replace(tag, tag + '\n<script src="/assets/iso30-manifest.js"></script>\n<script src="/assets/iso-render.js"></script>');
  html = html.replace('window.__WR_BB2_ENABLED__ = false;', () => 'window.__WR_BB2_ENABLED__ = true;');
  return html;
}
const gzCache = new Map();
http.createServer((req, res) => {
  const u = new URL(req.url, 'http://x'); const p = decodeURIComponent(u.pathname);
  const send = (code, type, body) => {
    const h = { 'content-type': type, 'cache-control': 'no-cache' };
    if (code === 200 && COMPRESSIBLE.test(type) && /gzip/.test(req.headers['accept-encoding'] || '')) {
      const key = p + '|' + body.length; let gz = gzCache.get(key);
      if (!gz) { gz = zlib.gzipSync(body, { level: 6 }); gzCache.set(key, gz); }
      h['content-encoding'] = 'gzip'; body = gz;
    }
    res.writeHead(code, h); res.end(body);
  };
  try {
    if (p === '/booth-builder' || p === '/booth-builder.html') return send(200, MIME['.html'], Buffer.from(builderHtml()));
    if (p === '/api/booth-layouts') return send(200, MIME['.json'], fs.readFileSync(path.join(ROOT, 'lib/pl-data/booth-layouts.json')));
    if (p === '/api/booth-iso-geometry') return send(200, MIME['.json'], fs.readFileSync(path.join(ROOT, 'lib/pl-data/booth-iso-geometry.json')));
    if (p === '/api/engage') { res.writeHead(204); return res.end(); }
    if (p.startsWith('/api/')) return send(404, MIME['.json'], Buffer.from('{"error":"stub"}'));
    const f = path.join(ROOT, p);
    if (!f.startsWith(ROOT) && !f.startsWith(ROOT.replace(/\//g, path.sep))) return send(403, 'text/plain', Buffer.from('no'));
    if (!fs.existsSync(f) || fs.statSync(f).isDirectory()) return send(404, 'text/plain', Buffer.from('not found: ' + p));
    return send(200, MIME[path.extname(f).toLowerCase()] || 'application/octet-stream', fs.readFileSync(f));
  } catch (e) { return send(500, 'text/plain', Buffer.from(String(e && e.stack || e))); }
}).listen(PORT, '127.0.0.1', () => console.log('perf rig serving ' + ROOT + ' on http://127.0.0.1:' + PORT + ' FLAGS=' + FLAGS));
