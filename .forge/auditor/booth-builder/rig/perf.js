// Perf harness for booth-builder.html. Usage:
//   node perf.js --profile desktop|mobile [--runs N] [--out name] [--product "MDL 7272 S"]
// Writes JSON + trace into ../out/. Read-only against WhisperRoomQuote.
'use strict';
const puppeteer = require('C:/Users/bento/Documents/Claude/WhisperRoomQuote/node_modules/puppeteer');
const fs = require('fs'), path = require('path');
const argv = process.argv.slice(2);
const args = {};
for (let i = 0; i < argv.length; i++) if (argv[i].startsWith('--')) { const v = argv[i + 1]; args[argv[i].slice(2)] = (v && !v.startsWith('--')) ? v : true; }
const PROFILE = args.profile || 'desktop';
const RUNS = +(args.runs || 1);
const OUT = path.resolve(__dirname, '..', 'out'); fs.mkdirSync(OUT, { recursive: true });
const NAME = args.out || PROFILE;
const BASE = 'http://127.0.0.1:' + (+process.env.PORT || 8766);
const PRODUCT = args.product || 'MDL 7272 S';
const SKIP_INTER = !!args['no-interactions'];
const NO_PROFILE = !!args['no-profile'];
const USE_GPU = !!args.gpu;
const sleep = ms => new Promise(r => setTimeout(r, ms));

// Lighthouse mobile defaults: 4x CPU slowdown, 1.6 Mbps down / 750 Kbps up / 150 ms RTT
const MOBILE_NET = { offline: false, latency: 150, downloadThroughput: 1.6 * 1024 * 1024 / 8, uploadThroughput: 750 * 1024 / 8 };
const MOBILE_CPU = 4;

// page-side instrumentation, installed before any page script runs
const INSTRUMENT = () => {
  const P = window.__perf = { paints: {}, lcp: null, longtasks: [], firstApp: null, firstCanvasDraw: null, drawImage: [], canvases: [], getImageData: { calls: 0, px: 0 }, di: {}, phase: 'load' };
  try {
    new PerformanceObserver(l => l.getEntries().forEach(e => { P.paints[e.name] = e.startTime; })).observe({ type: 'paint', buffered: true });
    new PerformanceObserver(l => l.getEntries().forEach(e => { P.lcp = { t: e.startTime, size: e.size, tag: e.element && e.element.tagName, id: e.element && e.element.id, cls: e.element && e.element.className && String(e.element.className).slice(0, 60), url: e.url }; })).observe({ type: 'largest-contentful-paint', buffered: true });
    new PerformanceObserver(l => l.getEntries().forEach(e => { P.longtasks.push({ t: +e.startTime.toFixed(1), d: +e.duration.toFixed(1), phase: P.phase }); })).observe({ type: 'longtask', buffered: true });
  } catch (e) {}
  const mo = new MutationObserver(() => {
    const app = document.getElementById('app');
    if (app && P.firstApp == null && app.querySelector('svg, canvas, .stage')) P.firstApp = performance.now();
    if (P.firstApp != null) mo.disconnect();
  });
  document.addEventListener('DOMContentLoaded', () => mo.observe(document.documentElement, { childList: true, subtree: true }));
  const C2D = CanvasRenderingContext2D.prototype;
  const oDraw = C2D.drawImage;
  C2D.drawImage = function (im) {
    { const a = arguments; const dw = a.length === 9 ? a[7] : a.length === 5 ? a[3] : (im && (im.naturalWidth || im.width)) || 0; const dh = a.length === 9 ? a[8] : a.length === 5 ? a[4] : (im && (im.naturalHeight || im.height)) || 0; const k = P.phase; const o = P.di[k] || (P.di[k] = { n: 0, px: 0, img: 0, cv: 0 }); o.n++; o.px += Math.abs(dw * dh) || 0; if (im && im.tagName === 'IMG') o.img++; else o.cv++; }
    if (P.firstCanvasDraw == null && this.canvas && this.canvas.isConnected) P.firstCanvasDraw = performance.now();
    if (im && im.tagName === 'IMG' && P.drawImage.length < 6000) {
      const a = arguments; let dw, dh;
      if (a.length === 9) { dw = a[7]; dh = a[8]; } else if (a.length === 5) { dw = a[3]; dh = a[4]; } else { dw = im.naturalWidth; dh = im.naturalHeight; }
      P.drawImage.push({ src: (im.currentSrc || im.src || '').replace(location.origin, '').replace(/\?.*$/, ''), nw: im.naturalWidth, nh: im.naturalHeight, dw: Math.round(dw), dh: Math.round(dh), onscreen: !!(this.canvas && this.canvas.isConnected), phase: P.phase });
    }
    return oDraw.apply(this, arguments);
  };
  const oGID = C2D.getImageData;
  C2D.getImageData = function (x, y, w, h) { P.getImageData.calls++; P.getImageData.px += (w * h) || 0; return oGID.apply(this, arguments); };
  const oGetCtx = HTMLCanvasElement.prototype.getContext;
  HTMLCanvasElement.prototype.getContext = function () {
    if (!this.__perfSeen) { this.__perfSeen = 1; P.canvases.push({ w: this.width, h: this.height, phase: P.phase, el: new WeakRef(this) }); }
    return oGetCtx.apply(this, arguments);
  };
};

async function launch() {
  return puppeteer.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: 'new', args: ['--no-sandbox'].concat(USE_GPU ? [] : ['--disable-gpu']).concat(['--window-size=1500,1000']) });
}

async function setupPage(browser) {
  const page = await browser.newPage();
  if (PROFILE === 'mobile') await page.emulate(puppeteer.KnownDevices['Pixel 5']);
  else await page.setViewport({ width: 1440, height: 900, deviceScaleFactor: 1 });
  const cdp = await page.target().createCDPSession();
  await cdp.send('Network.enable');
  await cdp.send('Network.setCacheDisabled', { cacheDisabled: true });
  await cdp.send('Performance.enable');
  await cdp.send('HeapProfiler.enable');
  if (PROFILE === 'mobile') {
    await cdp.send('Emulation.setCPUThrottlingRate', { rate: MOBILE_CPU });
    await cdp.send('Network.emulateNetworkConditions', MOBILE_NET);
  }
  const net = new Map();
  cdp.on('Network.requestWillBeSent', e => { net.set(e.requestId, { url: e.request.url, type: e.type, t0: e.timestamp, initiator: e.initiator && e.initiator.type, phase: page.__phase || 'load' }); });
  cdp.on('Network.responseReceived', e => { const r = net.get(e.requestId); if (r) { r.mime = e.response.mimeType; r.status = e.response.status; r.enc = e.response.headers['content-encoding'] || e.response.headers['Content-Encoding'] || ''; } });
  cdp.on('Network.loadingFinished', e => { const r = net.get(e.requestId); if (r) { r.bytes = e.encodedDataLength; r.t1 = e.timestamp; } });
  cdp.on('Network.loadingFailed', e => { const r = net.get(e.requestId); if (r) { r.failed = e.errorText; } });
  page.__errors = [];
  page.on('pageerror', e => page.__errors.push('pageerror: ' + e.message));
  page.on('console', m => { if (m.type() === 'error') page.__errors.push('console: ' + m.text().slice(0, 200)); });
  await page.evaluateOnNewDocument(INSTRUMENT);
  return { page, cdp, net };
}

const metrics = async cdp => Object.fromEntries((await cdp.send('Performance.getMetrics')).metrics.map(m => [m.name, m.value]));

// sampling CPU profile → self / inclusive ms by function
async function profStart(cdp) { if (NO_PROFILE) return; await cdp.send('Profiler.enable'); await cdp.send('Profiler.setSamplingInterval', { interval: 200 }); await cdp.send('Profiler.start'); }
async function profStop(cdp, top = 30) {
  if (NO_PROFILE) return null;
  const { profile } = await cdp.send('Profiler.stop');
  const byId = new Map(); const parent = new Map();
  for (const n of profile.nodes) { byId.set(n.id, n); for (const c of (n.children || [])) parent.set(c, n.id); }
  const key = n => { const f = n.callFrame; const u = (f.url || '').replace(/^.*\//, '').replace(/\?.*$/, ''); return (f.functionName || '(anon)') + ' ' + u + ':' + (f.lineNumber + 1); };
  const self = {}, incl = {}; let total = 0;
  for (let i = 0; i < profile.samples.length; i++) {
    const dt = (profile.timeDeltas[i] || 0) / 1000; total += dt;
    const n = byId.get(profile.samples[i]); if (!n) continue;
    const k = key(n); self[k] = (self[k] || 0) + dt;
    const seen = new Set(); let id = n.id;
    while (id != null) { const nn = byId.get(id); const kk = key(nn); if (!seen.has(kk)) { seen.add(kk); incl[kk] = (incl[kk] || 0) + dt; } id = parent.get(id); }
  }
  const fmt = o => Object.fromEntries(Object.entries(o).sort((a, b) => b[1] - a[1]).slice(0, top).map(([k, v]) => [k, +v.toFixed(1)]));
  // per-file self time
  const byFile = {};
  for (const [k, v] of Object.entries(self)) { const f = k.split(' ').pop().split(':')[0] || '(native)'; byFile[f] = (byFile[f] || 0) + v; }
  return { sampled_ms: +total.toFixed(1), self: fmt(self), inclusive: fmt(incl), byFile: fmt(byFile) };
}
const { execSync } = require('child_process');
function chromeRss() { try { const o = execSync('powershell -NoProfile -Command "(Get-Process chrome | Measure-Object WorkingSet64 -Sum).Sum"', { encoding: 'utf8' }); return +(+o.trim() / 1048576).toFixed(0); } catch (e) { return null; } }
const diffMetrics = (a, b) => { const d = {}; for (const k of ['TaskDuration', 'ScriptDuration', 'LayoutDuration', 'RecalcStyleDuration', 'LayoutCount', 'RecalcStyleCount', 'Nodes', 'JSEventListeners', 'JSHeapUsedSize']) d[k] = +(b[k] - a[k]).toFixed(k.endsWith('Duration') ? 4 : 0); return d; };

async function waitDrawn(page) {
  await page.waitForFunction(() => typeof LAYOUTS !== 'undefined' && LAYOUTS && typeof state !== 'undefined' && document.getElementById('app') && document.getElementById('app').children.length > 0, { timeout: 180000 });
  await page.waitForFunction(() => !window.__WR_ANGLED_VIEW_ENABLED__ || (window.wrIso && wrIso.ready() && (typeof isoAvailable !== 'function' || !isoAvailable() || window.__perf.firstCanvasDraw != null)), { timeout: 180000 });
}

function analyzeTrace(file) {
  const ev = JSON.parse(fs.readFileSync(file, 'utf8')).traceEvents;
  const names = {};
  for (const e of ev) if (e.ph === 'M' && e.name === 'thread_name') names[e.pid + ':' + e.tid] = e.args.name;
  const counts = {};
  for (const e of ev) if (names[e.pid + ':' + e.tid] === 'CrRendererMain') counts[e.pid + ':' + e.tid] = (counts[e.pid + ':' + e.tid] || 0) + 1;
  const main = Object.entries(counts).sort((a, b) => b[1] - a[1])[0][0];
  const [pid, tid] = main.split(':').map(Number);
  const M = ev.filter(e => e.pid === pid && e.tid === tid && e.ph === 'X' && e.dur != null).sort((a, b) => a.ts - b.ts);
  const ns = ev.find(e => e.name === 'navigationStart' && e.pid === pid);
  const t0 = ns ? ns.ts : M[0].ts;
  const byName = {}, compile = {}, evalS = {}, fnCalls = {}, longTasks = [], forced = [];
  const CHILD = new Set(['EvaluateScript', 'FunctionCall', 'ParseHTML', 'Layout', 'UpdateLayoutTree', 'Paint', 'v8.compile', 'TimerFire', 'EventDispatch', 'XHRLoad', 'ResourceReceivedData', 'Decode Image', 'ImageDecodeTask', 'HitTest', 'PrePaint', 'Commit']);
  for (const e of M) {
    byName[e.name] = byName[e.name] || { n: 0, us: 0 };
    byName[e.name].n++; byName[e.name].us += e.dur;
    const d = e.args && e.args.data || {};
    if (e.name === 'v8.compile' || e.name === 'V8.CompileScript' || e.name === 'v8.compileModule') { const u = d.url || '?'; compile[u] = (compile[u] || 0) + e.dur; }
    if (e.name === 'EvaluateScript') { const u = d.url || 'inline'; evalS[u] = (evalS[u] || 0) + e.dur; }
    if (e.name === 'FunctionCall') { const k = (d.functionName || '(anon)') + ' ' + ((d.url || '').replace(/^.*\//, '')) + ':' + d.lineNumber; fnCalls[k] = fnCalls[k] || { n: 0, us: 0 }; fnCalls[k].n++; fnCalls[k].us += e.dur; }
    if (e.name === 'Layout' && e.args.beginData && e.args.beginData.stackTrace && e.args.beginData.stackTrace.length) {
      const s = e.args.beginData.stackTrace[0];
      forced.push({ t: +((e.ts - t0) / 1000).toFixed(1), us: e.dur, fn: (s.functionName || '(anon)') + ' ' + (s.url || '').replace(/^.*\//, '') + ':' + s.lineNumber, dirty: e.args.beginData.dirtyObjects, stack: e.args.beginData.stackTrace.slice(0, 5).map(f => (f.functionName || '(anon)') + ':' + f.lineNumber) });
    }
    if (e.name === 'RunTask' && e.dur >= 50000) {
      const kids = M.filter(k => k.ts >= e.ts && k.ts + k.dur <= e.ts + e.dur && k !== e && CHILD.has(k.name)).sort((a, b) => b.dur - a.dur);
      const top = kids[0]; const td = top && top.args && top.args.data || {};
      longTasks.push({ start_ms: +((e.ts - t0) / 1000).toFixed(1), dur_ms: +(e.dur / 1000).toFixed(1), top: top ? top.name + ' ' + (td.url || td.functionName || '').toString().replace(/^.*\//, '') + (td.lineNumber != null ? ':' + td.lineNumber : '') + ' ' + (top.dur / 1000).toFixed(1) + 'ms' : '', children: kids.slice(0, 5).map(k => k.name + ' ' + ((k.args.data || {}).functionName || (k.args.data || {}).url || '').toString().replace(/^.*\//, '') + ((k.args.data || {}).lineNumber != null ? ':' + (k.args.data || {}).lineNumber : '') + ' ' + (k.dur / 1000).toFixed(1) + 'ms') });
    }
  }
  const ms = o => Object.fromEntries(Object.entries(o).map(([k, v]) => [k, typeof v === 'number' ? +(v / 1000).toFixed(1) : { n: v.n, ms: +(v.us / 1000).toFixed(1) }]));
  const sortObj = o => Object.fromEntries(Object.entries(o).sort((a, b) => (typeof b[1] === 'number' ? b[1] : b[1].us) - (typeof a[1] === 'number' ? a[1] : a[1].us)));
  const forcedBy = {};
  for (const f of forced) { forcedBy[f.fn] = forcedBy[f.fn] || { n: 0, us: 0 }; forcedBy[f.fn].n++; forcedBy[f.fn].us += f.us; }
  const totalMain = M.filter(e => e.name === 'RunTask').reduce((s, e) => s + e.dur, 0);
  const span = M.length ? (M[M.length - 1].ts + M[M.length - 1].dur - t0) / 1000 : 0;
  return { traceSpan_ms: +span.toFixed(0), mainThreadTask_ms: +(totalMain / 1000).toFixed(1), byName: Object.fromEntries(Object.entries(ms(sortObj(byName))).slice(0, 30)), compile_ms: ms(sortObj(compile)), evaluate_ms: ms(sortObj(evalS)), topFunctions: Object.fromEntries(Object.entries(ms(sortObj(fnCalls))).slice(0, 30)), longTasks, forcedLayouts: { count: forced.length, total_ms: +(forced.reduce((s, f) => s + f.us, 0) / 1000).toFixed(1), by: Object.fromEntries(Object.entries(ms(sortObj(forcedBy))).slice(0, 20)), examples: forced.slice(0, 12) } };
}

const cat = r => /booth-builder/.test(r.url) ? 'html' : /\.js(\?|$)/.test(r.url) ? 'js' : /\/api\//.test(r.url) ? 'api-json' : /fonts\.g/.test(r.url) ? 'font/css' : /\.(webp|png|svg|avif|jpg)/.test(r.url) ? 'image' : 'other';
function netSummary(net, filter) {
  const rows = [...net.values()].filter(filter || (() => true));
  const by = {};
  for (const r of rows) { const c = cat(r); by[c] = by[c] || { n: 0, bytes: 0, failed: 0 }; by[c].n++; by[c].bytes += r.bytes || 0; if (r.failed) by[c].failed++; }
  return { total: { n: rows.length, bytes: rows.reduce((s, r) => s + (r.bytes || 0), 0) }, by, images: rows.filter(r => cat(r) === 'image').map(r => ({ url: r.url.replace(BASE, ''), bytes: r.bytes, phase: r.phase })), largest: rows.slice().sort((a, b) => (b.bytes || 0) - (a.bytes || 0)).slice(0, 15).map(r => ({ url: r.url.replace(BASE, '').slice(0, 100), bytes: r.bytes, enc: r.enc, mime: r.mime })) };
}

async function domImages(page) {
  return page.evaluate(() => {
    const dpr = devicePixelRatio; const out = [];
    document.querySelectorAll('img').forEach(im => { const r = im.getBoundingClientRect(); out.push({ kind: 'img', src: (im.currentSrc || im.src).replace(location.origin, '').replace(/\?.*$/, ''), nw: im.naturalWidth, nh: im.naturalHeight, cw: Math.round(r.width * dpr), ch: Math.round(r.height * dpr), visible: r.width > 0 && r.height > 0 && im.offsetParent !== null }); });
    document.querySelectorAll('image').forEach(im => { const r = im.getBoundingClientRect(); const href = (im.getAttribute('href') || im.getAttribute('xlink:href') || '').replace(/\?.*$/, ''); out.push({ kind: 'svg-image', src: href, cw: Math.round(r.width * dpr), ch: Math.round(r.height * dpr), visible: r.width > 0 && r.height > 0 }); });
    document.querySelectorAll('canvas').forEach(c => { const r = c.getBoundingClientRect(); out.push({ kind: 'canvas', src: c.id || c.className, nw: c.width, nh: c.height, cw: Math.round(r.width * dpr), ch: Math.round(r.height * dpr), visible: r.width > 0 && r.height > 0 && c.isConnected }); });
    return out;
  });
}

async function phase(page, cdp, net, name, fn, settle = 1500) {
  page.__phase = name;
  await page.evaluate(n => { window.__perf.phase = n; window.__perf.longtasks.length = 0; }, name);
  const m0 = await metrics(cdp);
  await profStart(cdp);
  const wall0 = await page.evaluate(() => performance.now());
  let err = null;
  try { await page.evaluate(fn); } catch (e) { err = String(e.message || e).slice(0, 200); }
  await page.evaluate(() => new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r))));
  const wallFrame = await page.evaluate(() => performance.now()) - wall0;
  await sleep(settle);
  const cpu = await profStop(cdp, 15);
  const m1 = await metrics(cdp);
  const lt = await page.evaluate(() => window.__perf.longtasks.slice());
  const reqs = [...net.values()].filter(r => r.phase === name);
  const d = diffMetrics(m0, m1);
  return { name, err, wall_to_next_frame_ms: +wallFrame.toFixed(1), task_ms: +(d.TaskDuration * 1000).toFixed(1), script_ms: +(d.ScriptDuration * 1000).toFixed(1), layout_ms: +(d.LayoutDuration * 1000).toFixed(1), style_ms: +(d.RecalcStyleDuration * 1000).toFixed(1), layouts: d.LayoutCount, styleRecalcs: d.RecalcStyleCount, nodesDelta: d.Nodes, listenersDelta: d.JSEventListeners, longtasks: lt.map(x => x.d), longtaskTotal_ms: +lt.reduce((s, x) => s + x.d, 0).toFixed(1), requests: reqs.length, reqBytes: reqs.reduce((s, r) => s + (r.bytes || 0), 0), imgReqs: reqs.filter(r => /\.(webp|png)/.test(r.url)).length, cpu };
}

(async () => {
  const browser = await launch();
  const results = { profile: PROFILE, product: PRODUCT, runs: [], conditions: PROFILE === 'mobile' ? { device: 'Pixel 5 emulation (393x851 css px @3x, Android UA, touch)', cpuThrottle: MOBILE_CPU + 'x', network: 'Lighthouse mobile preset: 1.6 Mbps down / 750 Kbps up / 150 ms RTT' } : { viewport: '1440x900 @1x', cpuThrottle: 'none', network: 'localhost, unthrottled' }, cacheDisabled: true, profiler: !NO_PROFILE, gpu: USE_GPU, server: 'gzip on text types; flags tdArt+angled+bb2 ON' };

  for (let run = 0; run < RUNS; run++) {
    const { page, cdp, net } = await setupPage(browser);
    const traceFile = path.join(OUT, `${NAME}-load-${run}.trace.json`);
    await page.tracing.start({ path: traceFile, categories: ['-*', 'devtools.timeline', 'disabled-by-default-devtools.timeline', 'disabled-by-default-devtools.timeline.stack', 'v8', 'v8.execute', 'disabled-by-default-v8.compile', 'blink', 'blink.user_timing', 'loading', 'toplevel'] });
    await profStart(cdp);
    const T0 = Date.now();
    await page.goto(BASE + '/booth-builder?product=' + encodeURIComponent(PRODUCT), { waitUntil: 'domcontentloaded', timeout: 180000 });
    await waitDrawn(page);
    const drawnWall = Date.now() - T0;
    await page.evaluate(() => new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r))));
    const tDrawn = await page.evaluate(() => performance.now());
    let last = -1, same = 0; while (same < 6) { await sleep(500); const n = [...net.values()].filter(r => r.bytes != null || r.failed).length; if (n === last) same++; else { same = 0; last = n; } }
    const tIdle = await page.evaluate(() => performance.now());
    await page.tracing.stop();
    const cpu = await profStop(cdp, 40);
    const nav = await page.evaluate(() => { const n = performance.getEntriesByType('navigation')[0]; return { ttfb: +n.responseStart.toFixed(0), responseEnd: +n.responseEnd.toFixed(0), domInteractive: +n.domInteractive.toFixed(0), dcl: +n.domContentLoadedEventEnd.toFixed(0), load: +n.loadEventEnd.toFixed(0), transferSize: n.transferSize, decodedBodySize: n.decodedBodySize, encodedBodySize: n.encodedBodySize }; });
    const perf = await page.evaluate(() => ({ paints: window.__perf.paints, lcp: window.__perf.lcp, firstApp: window.__perf.firstApp, firstCanvasDraw: window.__perf.firstCanvasDraw, longtasks: window.__perf.longtasks, getImageData: window.__perf.getImageData, di: window.__perf.di, canvases: window.__perf.canvases.map(c => ({ w: c.w, h: c.h })), drawImage: window.__perf.drawImage, state: { model: state.model, view: state.view, variant: state.variant } }));
    const trace = analyzeTrace(traceFile);
    const m = await metrics(cdp);
    const resTiming = await page.evaluate(() => performance.getEntriesByType('resource').map(r => ({ name: r.name.replace(location.origin, '').replace(/\?.*$/, '').slice(0, 90), start: +r.startTime.toFixed(0), end: +r.responseEnd.toFixed(0), size: r.transferSize, type: r.initiatorType })));
    const scripts = resTiming.filter(r => /\.js$|booth-builder|fonts|api\//.test(r.name));
    results.runs.push({ run, wallToDrawn_ms: drawnWall, nav, paints: perf.paints, lcp: perf.lcp, firstAppPaint_ms: perf.firstApp, firstCanvasDraw_ms: perf.firstCanvasDraw, boothDrawn_ms: +tDrawn.toFixed(0), networkIdle_ms: +tIdle.toFixed(0), state: perf.state, longtasksDuringLoad: perf.longtasks, network: netSummary(net), scriptTimeline: scripts, domImages: await domImages(page), canvases: { count: perf.canvases.length, px: perf.canvases.reduce((s, c) => s + c.w * c.h, 0), sizes: Object.entries(perf.canvases.reduce((o, c) => { const k = c.w + 'x' + c.h; o[k] = (o[k] || 0) + 1; return o; }, {})).sort((a, b) => b[1] - a[1]).slice(0, 10) }, getImageData: perf.getImageData, drawImageStats: perf.di, drawImage: perf.drawImage, metrics: { nodes: m.Nodes, listeners: m.JSEventListeners, heapUsedMB: +(m.JSHeapUsedSize / 1048576).toFixed(1), heapTotalMB: +(m.JSHeapTotalSize / 1048576).toFixed(1), docs: m.Documents, frames: m.Frames, layoutCount: m.LayoutCount, styleCount: m.RecalcStyleCount, script_s: +m.ScriptDuration.toFixed(3), layout_s: +m.LayoutDuration.toFixed(3), style_s: +m.RecalcStyleDuration.toFixed(3), task_s: +m.TaskDuration.toFixed(3) }, trace, cpu, errors: page.__errors });
    console.log(`run ${run}: drawn ${tDrawn.toFixed(0)}ms idle ${tIdle.toFixed(0)}ms bytes ${results.runs[run].network.total.bytes} reqs ${results.runs[run].network.total.n}`);
    if (run < RUNS - 1 || SKIP_INTER) { await page.close(); continue; }

    const inter = [];
    const has = await page.evaluate(() => ({ bb2: !!window.__WR_BB2_ENABLED__, iso: typeof isoAvailable === 'function' && isoAvailable(), models: Object.keys(LAYOUTS) }));
    results.has = has;
    inter.push(await phase(page, cdp, net, 'setOpt vss on', () => setOpt('vss', true)));
    inter.push(await phase(page, cdp, net, 'setOpt vss off', () => setOpt('vss', false)));
    inter.push(await phase(page, cdp, net, 'setOpt studioLight on', () => setOpt('studioLight', true)));
    inter.push(await phase(page, cdp, net, 'setOpt studioLight off', () => setOpt('studioLight', false)));
    inter.push(await phase(page, cdp, net, 'view top', () => setView('top')));
    inter.push(await phase(page, cdp, net, 'view elev', () => setView('elev')));
    if (has.iso) inter.push(await phase(page, cdp, net, 'view iso', () => setView('iso'), 3000));
    if (has.iso) inter.push(await phase(page, cdp, net, 'iso corner rotate', () => { const cs = wrIso.corners.map(c => c.id); const i = cs.indexOf(state.isoCorner || wrIso.defaultCorner); setIsoCorner(cs[(i + 1) % cs.length]); }, 3000));
    if (has.bb2) inter.push(await phase(page, cdp, net, 'rung roof-off', () => bb2SetRung(1), 3000));
    if (has.bb2) inter.push(await phase(page, cdp, net, 'rung roof-on', () => bb2SetRung(0), 3000));
    if (has.bb2) inter.push(await phase(page, cdp, net, 'room eye on', () => bb2ToggleRoomEye(), 3000));
    if (has.bb2) inter.push(await phase(page, cdp, net, 'room eye off', () => bb2ToggleRoomEye(), 3000));
    inter.push(await phase(page, cdp, net, 'open gallery', () => openGallery(false), 2000));
    inter.push(await phase(page, cdp, net, 'close gallery', () => { const g = document.getElementById('bbGallery'); if (typeof closeGallery === 'function') closeGallery(); else { g.hidden = true; document.body.classList.remove('bb-gal-open'); } }, 1000));
    for (const m of ['MDL 96120', 'MDL 6084', 'MDL 4848', 'MDL 7272']) {
      const r = await phase(page, cdp, net, 'setModel ' + m, new Function(`setModel(${JSON.stringify(m)});`), 4000);
      r.modelAfter = await page.evaluate(() => state.model);
      inter.push(r);
    }
    results.interactions = inter;
    for (const r of inter) console.log(`  ${r.name.padEnd(24)} task ${String(r.task_ms).padStart(7)}ms  script ${String(r.script_ms).padStart(7)}  layout ${String(r.layout_ms).padStart(6)} (${r.layouts})  long ${JSON.stringify(r.longtasks)}  req ${r.requests}/${r.reqBytes}B${r.err ? '  ERR ' + r.err : ''}`);

    // memory: 20 model switches with GC between samples
    const gc = async () => { await cdp.send('HeapProfiler.collectGarbage'); await sleep(300); await cdp.send('HeapProfiler.collectGarbage'); await sleep(200); };
    const mem = [];
    await gc(); const m0 = await metrics(cdp);
    mem.push({ i: 0, model: await page.evaluate(() => state.model), heapMB: +(m0.JSHeapUsedSize / 1048576).toFixed(2), nodes: m0.Nodes, listeners: m0.JSEventListeners, chromeRssMB: chromeRss() });
    const cycle = ['MDL 4848', 'MDL 6084', 'MDL 96120', 'MDL 7272', 'MDL 4872', 'MDL 6060', 'MDL 7296', 'MDL 8484', 'MDL 4884', 'MDL 6096'].filter(x => has.models.includes(x));
    page.__phase = 'memory';
    await page.evaluate(() => { window.__perf.phase = 'memory'; });
    for (let i = 1; i <= 20; i++) {
      const m = cycle[(i - 1) % cycle.length];
      await page.evaluate(m => { if (typeof bb2CommitModel === 'function' && window.__WR_BB2_ENABLED__) bb2CommitModel(m, null); else setModel(m); }, m);
      await sleep(PROFILE === 'mobile' ? 3500 : 2000);
      await gc(); const mm = await metrics(cdp);
      mem.push({ i, model: m, heapMB: +(mm.JSHeapUsedSize / 1048576).toFixed(2), nodes: mm.Nodes, listeners: mm.JSEventListeners, docs: mm.Documents, chromeRssMB: chromeRss() });
      console.log(`  mem ${i} ${m} heap ${mem[i].heapMB}MB nodes ${mm.Nodes} listeners ${mm.JSEventListeners} rss ${mem[i].chromeRssMB}MB`);
    }
    const snapFile = path.join(OUT, `${NAME}-heap.heapsnapshot`);
    const chunks = []; const onChunk = e => chunks.push(e.chunk); cdp.on('HeapProfiler.addHeapSnapshotChunk', onChunk);
    await cdp.send('HeapProfiler.takeHeapSnapshot', { reportProgress: false, captureNumericValue: false });
    cdp.off('HeapProfiler.addHeapSnapshotChunk', onChunk);
    const raw = chunks.join(''); fs.writeFileSync(snapFile, raw);
    const snap = JSON.parse(raw);
    const F = snap.snapshot.meta.node_fields, NF = F.length, ti = F.indexOf('type'), ni = F.indexOf('name'), si = F.indexOf('self_size');
    const types = snap.snapshot.meta.node_types[0]; const S = snap.strings; const N = snap.nodes;
    const byCtor = {}; let detached = 0, detachedBytes = 0, canvasN = 0, imgN = 0; const detachedKinds = {};
    for (let i = 0; i < N.length; i += NF) {
      const t = types[N[i + ti]], name = S[N[i + ni]], sz = N[i + si];
      if (t === 'native' || t === 'object') {
        if (/^Detached /.test(name)) { detached++; detachedBytes += sz; const k = name.split(' ').slice(0, 2).join(' '); detachedKinds[k] = (detachedKinds[k] || 0) + 1; }
        if (/HTMLCanvasElement|OffscreenCanvas|ImageData|CanvasRenderingContext2D/.test(name)) canvasN++;
        if (/HTMLImageElement/.test(name)) imgN++;
      }
      const key = (t === 'object' || t === 'native') ? name : t;
      byCtor[key] = byCtor[key] || { n: 0, bytes: 0 }; byCtor[key].n++; byCtor[key].bytes += sz;
    }
    results.memory = { series: mem, snapshot: { file: snapFile, nodeCount: N.length / NF, detachedNodes: detached, detachedBytesSelf: detachedBytes, detachedKinds: Object.entries(detachedKinds).sort((a, b) => b[1] - a[1]).slice(0, 12), canvasRelatedObjects: canvasN, imageElements: imgN, topSelfSize: Object.entries(byCtor).sort((a, b) => b[1].bytes - a[1].bytes).slice(0, 25).map(([k, v]) => ({ name: k.slice(0, 60), n: v.n, MB: +(v.bytes / 1048576).toFixed(2) })) } };
    results.memory.canvasesCreated = await page.evaluate(() => ({ count: window.__perf.canvases.length, alive: window.__perf.canvases.filter(c => c.el.deref()).length, alivePx: window.__perf.canvases.filter(c => c.el.deref()).reduce((s, c) => s + c.w * c.h, 0), byPhase: window.__perf.canvases.reduce((o, c) => { o[c.phase] = (o[c.phase] || 0) + 1; return o; }, {}) }));
    results.memory.getImageData = await page.evaluate(() => window.__perf.getImageData);
    results.memory.drawImageStats = await page.evaluate(() => window.__perf.di);
    results.memory.drawImageByPhase = await page.evaluate(() => window.__perf.drawImage.reduce((o, d) => { o[d.phase] = (o[d.phase] || 0) + 1; return o; }, {}));
    results.errors = page.__errors;
    console.log('detached', detached, 'canvasObjs', canvasN, 'imgs', imgN, 'canvasesAlive', results.memory.canvasesCreated.alive, '/', results.memory.canvasesCreated.count);
    await page.close();
  }
  fs.writeFileSync(path.join(OUT, `${NAME}.json`), JSON.stringify(results, null, 1));
  console.log('wrote', path.join(OUT, `${NAME}.json`));
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });
