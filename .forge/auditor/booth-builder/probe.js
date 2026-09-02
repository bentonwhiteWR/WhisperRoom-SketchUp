// Auditor lane B — instrument booth-builder.html and count work per action.
'use strict';
const puppeteer = require('C:/Users/bento/Documents/Claude/WhisperRoomQuote/node_modules/puppeteer');
const { spawn } = require('child_process');
const PORT = 8791;
const BASE = 'http://127.0.0.1:' + PORT + '/booth-builder';

const COUNTED = ['render', 'rebuild', 'resolveLayout', 'paintIso', 'redrawIso', 'bb2DrawRoomStage',
  'renderLayoutSvg', 'renderElevationSvg', 'fitStageToColumn', 'computeFitHtml', 'bb2SideHtml',
  'bb2Card3Html', 'galleryHtml', 'bb2RecRows', 'bbWithScratch', 'updateBoothPrice', 'preloadElevArt',
  'applyFormIntent', 'applyPackage', 'bb2CommitModel', 'fitVerdictB', 'bb2EffRoom'];

const INJECT = `
window.__cnt = {}; window.__timers = { st: 0, raf: 0 };
(function () {
  const _st = window.setTimeout, _si = window.setInterval, _raf = window.requestAnimationFrame;
  window.setTimeout = function () { window.__timers.st++; return _st.apply(window, arguments); };
  window.setInterval = function () { window.__timers.si = (window.__timers.si || 0) + 1; return _si.apply(window, arguments); };
  window.requestAnimationFrame = function () { window.__timers.raf++; return _raf.apply(window, arguments); };
})();
document.addEventListener('DOMContentLoaded', function () {
  for (const n of ${JSON.stringify(COUNTED)}) {
    const f = window[n]; if (typeof f !== 'function') { window.__cnt['!' + n] = 'missing'; continue; }
    window.__cnt[n] = 0;
    window[n] = function () { window.__cnt[n]++; return f.apply(this, arguments); };
  }
});
`;

function b64url(o) { return Buffer.from(JSON.stringify(o), 'utf8').toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, ''); }

async function listenerCounts(page) {
  const cdp = await page.target().createCDPSession();
  const out = {};
  for (const expr of ['window', 'document', 'document.body']) {
    const { result } = await cdp.send('Runtime.evaluate', { expression: expr });
    const { listeners } = await cdp.send('DOMDebugger.getEventListeners', { objectId: result.objectId });
    out[expr] = listeners.length;
  }
  await cdp.detach();
  return out;
}

async function snap(page) {
  const c = await page.evaluate(() => JSON.parse(JSON.stringify(window.__cnt)));
  const t = await page.evaluate(() => JSON.parse(JSON.stringify(window.__timers)));
  return { c, t };
}
function diff(a, b) { const d = {}; for (const k in b.c) if (typeof b.c[k] === 'number' && b.c[k] - (a.c[k] || 0)) d[k] = b.c[k] - (a.c[k] || 0); d.__st = b.t.st - a.t.st; d.__raf = b.t.raf - a.t.raf; return d; }

async function main() {
  const server = spawn(process.execPath, ['C:/Users/bento/Documents/Claude/Sketchup/.forge/researcher/tools/serve.js'], { env: { ...process.env, PORT: String(PORT) }, stdio: 'ignore' });
  await new Promise(r => setTimeout(r, 800));
  const browser = await puppeteer.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true, args: ['--no-sandbox'] });
  const report = {};
  async function open(url, mobile) {
    const page = await browser.newPage();
    if (mobile) await page.setViewport({ width: 390, height: 844, isMobile: true, hasTouch: true, deviceScaleFactor: 2 });
    else await page.setViewport({ width: 1440, height: 900 });
    page.on('pageerror', e => { (report.errors = report.errors || []).push(url + ' :: ' + String(e && e.message || e)); });
    page.on('console', m => { if (m.type() === 'error') (report.consoleErr = report.consoleErr || []).push(url + ' :: ' + m.text().slice(0, 200)); });
    const reqs = [];
    page.on('request', r => { if (r.url().includes('/api/')) reqs.push(r.url().replace('http://127.0.0.1:' + PORT, '')); });
    await page.evaluateOnNewDocument(INJECT);
    await page.goto(url, { waitUntil: 'networkidle2', timeout: 60000 });
    await new Promise(r => setTimeout(r, 1200));
    page.__reqs = reqs;
    return page;
  }

  // ── 1. boot cost by entry path ──
  for (const [name, url] of [
    ['cold', BASE],
    ['product', BASE + '?product=MDL%207272%20S'],
    ['product+acc', BASE + '?product=MDL%207272%20S&acc=Wall%20Windows;Caster%20Plate;Office%20Desk'],
    ['package', BASE + '?product=Voice-Over%20Basic'],
    ['hash', BASE + '#d=' + b64url({ m: 'MDL 7272', v: 'S', h: 'R', f: 'Gray', a: {}, rm: { wFt: '12', wIn: '', lFt: '10', lIn: '', cFt: '', cIn: '' } })],
    ['room', BASE + '?start=room&room=12x10x8'],
  ]) {
    const page = await open(url);
    const s = await snap(page);
    report['boot:' + name] = { counts: s.c, timers: s.t, api: page.__reqs, appText: (await page.evaluate(() => document.getElementById('app').innerText.slice(0, 80))) };
    await page.close();
  }

  // ── 2. per-action cost on a booth (desktop, BB2, angled default) ──
  {
    const page = await open(BASE + '?product=MDL%207272%20S');
    await page.evaluate(() => { try { closeGallery(); } catch (e) {} });
    await new Promise(r => setTimeout(r, 500));
    const actions = {
      'setOpt vss on': "setOpt('vss', true)",
      'setOpt vss off': "setOpt('vss', false)",
      'setOpt heightExt on': "setHX(true)",
      'setVariant E': "setVariant('E')",
      'setVariant S': "setVariant('S')",
      'setFoam Blue': "setFoam('Blue')",
      'setView top': "setView('top')",
      'setView elev': "setView('elev')",
      'rotate 1 (elev)': "rotate(1)",
      'setView iso': "setView('iso')",
      'setHinge L': "setHinge('L')",
      'setWide true': "setWide(true)",
      'setModel 7296': "setModel('MDL 7296')",
      'setModel 4848': "setModel('MDL 4848')",
      'setRoomDim wFt 12': "setRoomDim('wFt','12')",
      'setRoomDim lFt 14': "setRoomDim('lFt','14')",
      'addWindow': "addWindow()",
      'openGallery': "openGallery()",
      'closeGallery': "closeGallery()",
    };
    const per = {};
    for (const [label, code] of Object.entries(actions)) {
      const before = await snap(page);
      const n0 = page.__reqs.length;
      let err = null;
      try { await page.evaluate(code); } catch (e) { err = String(e.message).slice(0, 160); }
      await new Promise(r => setTimeout(r, 900));
      const after = await snap(page);
      per[label] = diff(before, after);
      per[label].__api = page.__reqs.slice(n0);
      if (err) per[label].__err = err;
      // confirm-sheet may block a model change: dismiss it
      await page.evaluate(() => { const b = document.querySelector('.bb2-mig button, [onclick*="bb2MigCommit"], [onclick*="bb2ConfirmMig"]'); if (b) b.click(); });
    }
    report.perAction = per;

    // ── 3. leak probe: 40 option toggles + 10 model swaps + 10 view flips ──
    const L0 = await listenerCounts(page);
    const nodes0 = await page.evaluate(() => document.getElementsByTagName('*').length);
    const t0 = await snap(page);
    for (let i = 0; i < 20; i++) { await page.evaluate("setOpt('vss', true)"); await page.evaluate("setOpt('vss', false)"); }
    for (let i = 0; i < 5; i++) { await page.evaluate("setView('top')"); await page.evaluate("setView('elev')"); await page.evaluate("setView('iso')"); }
    for (let i = 0; i < 5; i++) { await page.evaluate("bb2CommitModel('MDL 7296', null)"); await new Promise(r => setTimeout(r, 300)); await page.evaluate("bb2CommitModel('MDL 7272', null)"); await new Promise(r => setTimeout(r, 300)); }
    for (let i = 0; i < 10; i++) { await page.evaluate("openGallery()"); await page.evaluate("closeGallery()"); }
    await new Promise(r => setTimeout(r, 1500));
    const L1 = await listenerCounts(page);
    const nodes1 = await page.evaluate(() => document.getElementsByTagName('*').length);
    const t1 = await snap(page);
    report.leak = { listenersBefore: L0, listenersAfter: L1, nodesBefore: nodes0, nodesAfter: nodes1, work: diff(t0, t1),
      globals: await page.evaluate(() => ({ bodyChildren: document.body.children.length, sizepops: document.querySelectorAll('.sizepop').length, movebars: document.querySelectorAll('.bb2-movebar').length, coach: document.querySelectorAll('.bb-coach').length, galleries: document.querySelectorAll('#bbGallery').length })) };
    await page.close();
  }

  // ── 4. hostile / malformed entry paths ──
  for (const [name, url] of [
    ['product=constructor', BASE + '?product=constructor'],
    ['product=__proto__', BASE + '?product=__proto__'],
    ['hash m=constructor', BASE + '#d=' + b64url({ m: 'constructor' })],
    ['hash m=toString', BASE + '#d=' + b64url({ m: 'toString' })],
    ['hash rm object dims', BASE + '#d=' + b64url({ m: 'MDL 7272', rm: { wFt: { x: 1 }, lFt: [1, 2], cFt: '<img src=x onerror=window.__xss=1>' } })],
    ['hash rm extra keys', BASE + '#d=' + b64url({ m: 'MDL 7272', rm: { zz: '<b>x</b>', wFt: '12', lFt: '10' } })],
    ['hash pk=constructor', BASE + '#d=' + b64url({ m: 'MDL 7272', pk: 'constructor' })],
    ['hash a pack xss', BASE + '#d=' + b64url({ m: 'MDL 7272', a: { N0: 'STDWL46 "><img src=x onerror=window.__xss=1>' } })],
    ['hash junk', BASE + '#d=!!!notbase64'],
    ['product xss', BASE + '?product=%3Cimg%20src%3Dx%20onerror%3Dwindow.__xss%3D1%3E&page=/x'],
    ['page attr', BASE + '?product=MDL%207272%20S&page=/foo%22%20onmouseover%3D%22alert(1)'],
    ['page proto-relative', BASE + '?product=MDL%207272%20S&page=//evil.example/x'],
    ['src', BASE + '?src=%3Cscript%3E'],
  ]) {
    const page = await open(url);
    report['hostile:' + name] = {
      appText: await page.evaluate(() => document.getElementById('app').innerText.slice(0, 120).replace(/\s+/g, ' ')),
      model: await page.evaluate(() => state.model + ' | room=' + JSON.stringify(state.room).slice(0, 160)),
      xss: await page.evaluate(() => !!window.__xss),
      startBar: await page.evaluate(() => { const b = document.getElementById('bbStartBar'); return b && !b.hidden ? b.innerHTML.slice(0, 200) : null; }),
      hash: await page.evaluate(() => location.hash.slice(0, 60)),
    };
    await page.close();
  }

  // ── 5. mobile boot + a few actions ──
  {
    const page = await open(BASE + '?product=MDL%207272%20S', true);
    const s0 = await snap(page);
    report['mobile:boot'] = { counts: s0.c, timers: s0.t };
    await page.evaluate(() => { try { closeGallery(); } catch (e) {} });
    const b = await snap(page);
    await page.evaluate("setSheet(true)"); await new Promise(r => setTimeout(r, 400));
    await page.evaluate("setOpt('vss', true)"); await new Promise(r => setTimeout(r, 900));
    const a = await snap(page);
    report['mobile:sheet+opt'] = diff(b, a);
    await page.close();
  }

  await browser.close();
  server.kill();
  require('fs').writeFileSync('C:/Users/bento/Documents/Claude/Sketchup/.forge/auditor/booth-builder/probe-out.json', JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report, null, 1));
}
main().catch(e => { console.error(e); process.exit(1); });
