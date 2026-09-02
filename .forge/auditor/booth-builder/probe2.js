// Targeted repros for lane C. usage: node probe2.js <test>
'use strict';
const puppeteer = require('C:/Users/bento/Documents/Claude/WhisperRoomQuote/node_modules/puppeteer');
const path = require('path');
const OUT = 'C:/Users/bento/Documents/Claude/Sketchup/.forge/auditor/booth-builder/mobile-shots';
const sleep = ms => new Promise(r => setTimeout(r, ms));
const UA_IOS = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1';
const VP = { se: { width: 375, height: 667, deviceScaleFactor: 2, isMobile: true, hasTouch: true }, fold: { width: 280, height: 653, deviceScaleFactor: 3, isMobile: true, hasTouch: true }, ipad: { width: 768, height: 1024, deviceScaleFactor: 2, isMobile: true, hasTouch: true } };
const TEST = process.argv[2];
const say = (...a) => console.log(...a.map(x => typeof x === 'string' ? x : JSON.stringify(x)));

(async () => {
  const browser = await puppeteer.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: 'new', args: ['--no-sandbox', '--disable-gpu'] });
  const page = await browser.newPage();
  const errors = []; page.on('pageerror', e => errors.push('pageerror: ' + e.message));
  const emu = async (k) => page.emulate({ userAgent: UA_IOS, viewport: VP[k] });
  const shot = async (n) => { const f = path.join(OUT, 'probe-' + n + '.png'); await page.screenshot({ path: f }); say('shot', path.basename(f)); };
  const ready = async () => { await page.waitForFunction(() => typeof state !== 'undefined' && !document.querySelector('#app > .loading'), { timeout: 30000 }).catch(e => say('ready timeout')); await sleep(1500); };
  const tapEl = async (sel, re) => { const h = await page.evaluateHandle((sel, src) => { const re = new RegExp(src, 'i'); return Array.from(document.querySelectorAll(sel)).find(e => e.getBoundingClientRect().width > 0 && re.test((e.getAttribute('aria-label') || '') + ' ' + e.textContent)) || null; }, sel, re.source); const el = h.asElement(); if (!el) { say('no el', sel, re.source); return null; } const b = await el.boundingBox(); await page.touchscreen.tap(b.x + b.width / 2, b.y + b.height / 2); await sleep(800); return b; };

  const T = {};
  T.outage = async () => {
    await emu('se');
    await page.goto('http://127.0.0.1:8767/booth-builder', { waitUntil: 'networkidle0', timeout: 60000 }).catch(e => say(e.message)); await sleep(2500);
    say('FAIL page text:', await page.evaluate(() => document.body.innerText.replace(/\s+/g, ' ').slice(0, 200)));
    say('  any button/link on page:', await page.evaluate(() => document.querySelectorAll('button,a[href]').length));
    await shot('outage-500');
    await page.goto('http://127.0.0.1:8768/booth-builder', { waitUntil: 'domcontentloaded', timeout: 60000 }).catch(e => say(e.message)); await sleep(20000);
    say('DROP page text after 20s:', await page.evaluate(() => document.body.innerText.replace(/\s+/g, ' ').slice(0, 200)));
    await shot('outage-hang-20s');
  };
  T.quotehang = async () => {
    await emu('se');
    await page.goto('http://127.0.0.1:8766/booth-builder?product=MDL%207272%20S', { waitUntil: 'networkidle0', timeout: 60000 }); await ready();
    // the connection dies right after the page loaded: booth-request never answers
    await page.evaluate(() => { const f = window.fetch; window.fetch = function (u, o) { if (String(u).indexOf('/api/booth-request') >= 0) return new Promise(() => {}); return f.apply(this, arguments); }; });
    await tapEl('.bb-customize button', /Quote/);
    const fi = await page.$$('#bb2QuoteModal input.fi'); await fi[0].tap(); await page.keyboard.type('Test'); await fi[1].tap(); await page.keyboard.type('t@t.com');
    await tapEl('#bb2QuoteModal button', /request my quote/);
    for (const t of [2, 10, 30]) { await sleep(t === 2 ? 2000 : t === 10 ? 8000 : 20000); say('t=' + t + 's', await page.evaluate(() => { const b = Array.from(document.querySelectorAll('#bb2QuoteModal button')).find(b => /request|send|sending/i.test(b.textContent)); return { sending: state.sending, requested: state.requested, btn: b && b.textContent.trim(), disabled: b && b.disabled, toast: document.getElementById('toast').textContent, modal: !document.getElementById('bb2QuoteModal').hidden }; })); }
    await shot('quote-hang-30s');
    // can the customer close and retry?
    await page.evaluate(() => closeQuoteModal()); await tapEl('.bb-customize button', /Quote/);
    say('after reopen:', await page.evaluate(() => { const b = Array.from(document.querySelectorAll('#bb2QuoteModal button')).find(b => /request|send|sending/i.test(b.textContent)); return { sending: state.sending, btn: b && b.textContent.trim(), disabled: b && b.disabled }; }));
    await shot('quote-hang-reopen');
  };
  T.coach = async () => {
    for (const k of ['se', 'fold']) {
      await emu(k);
      // fresh visitor: clear the coach's "seen" flags
      await page.goto('http://127.0.0.1:8766/booth-builder', { waitUntil: 'networkidle0', timeout: 60000 }); await page.evaluate(() => { try { localStorage.clear(); sessionStorage.clear(); } catch (e) {} });
      await page.goto('http://127.0.0.1:8766/booth-builder', { waitUntil: 'networkidle0', timeout: 60000 }); await ready();
      await page.evaluate(() => { document.querySelector('#bbGallery .gcard[onclick*="MDL 6084"]').scrollIntoView({ block: 'center' }); }); await sleep(300);
      const c = await page.$('#bbGallery .gcard[onclick*="MDL 6084"]'); const cb = await c.boundingBox(); await page.touchscreen.tap(cb.x + cb.width / 2, cb.y + cb.height / 2); await sleep(3000);
      const geo = await page.evaluate(() => { const rb = e => { if (!e) return null; const r = e.getBoundingClientRect(); return { l: Math.round(r.left), t: Math.round(r.top), r: Math.round(r.right), b: Math.round(r.bottom) }; }; return { bubble: rb(document.querySelector('.bb-coach-bubble')), floorplan: rb(Array.from(document.querySelectorAll('.vswbtn')).find(b => /Floor/.test(b.textContent))), peek: rb(document.querySelector('.bb-peek')), dims: rb(document.querySelector('label.bb-tog')) }; });
      say(k, 'geometry', geo); await shot('coach-' + k);
      // first tap: FLOOR PLAN tab, as a customer would
      const fp = geo.floorplan; const hit = await page.evaluate((x, y) => { const h = document.elementFromPoint(x, y); return h && (h.className || h.tagName).toString().slice(0, 40); }, (fp.l + fp.r) / 2, (fp.t + fp.b) / 2);
      await page.touchscreen.tap((fp.l + fp.r) / 2, (fp.t + fp.b) / 2); await sleep(1200);
      say(k, 'tap Floor plan centre hit:', hit, '→ view', await page.evaluate(() => state.view), 'bubble still up:', await page.evaluate(() => !!document.querySelector('.bb-coach-bubble')));
      await shot('coach-' + k + '-after-tap');
    }
  };
  T.acc = async () => {
    await emu('se');
    await page.goto('http://127.0.0.1:8766/booth-builder?product=MDL%207272%20S&acc=' + encodeURIComponent('Caster Plate,Step,Office Desk,ADA Package'), { waitUntil: 'networkidle0', timeout: 60000 }); await ready();
    say('acc applied:', await page.evaluate(() => ({ model: state.model, casters: state.casters, step: state.step, desk: state.desk, wideDoor: state.wideDoor, ramp: state.ramp, ada: state.ada })));
    await shot('acc-se');
  };
  T.foldpop = async () => {
    await emu('fold');
    await page.goto('http://127.0.0.1:8766/booth-builder?product=MDL%207272%20S', { waitUntil: 'networkidle0', timeout: 60000 }); await ready();
    await tapEl('.bb-customize button', /Room fit/); await tapEl('button', /Draw your room/); await sleep(800);
    say('popup geometry:', await page.evaluate(() => { const p = document.querySelector('.sizepop'); const r = p.getBoundingClientRect(); const btn = p.querySelector('button.hot').getBoundingClientRect(); return { innerW: innerWidth, popL: Math.round(r.left), popR: Math.round(r.right), popW: Math.round(r.width), btnR: Math.round(btn.right), docScrollW: document.documentElement.scrollWidth }; }));
    await shot('fold-roompop');
    // sheet (Customize) at 280 — spill inside?
    await page.evaluate(() => bb2ClosePop()); await tapEl('.bb-customize button', /Customize/); await sleep(800);
    say('sheet spill:', await page.evaluate(() => { const W = innerWidth; return Array.from(document.querySelectorAll('.side *')).filter(e => { const r = e.getBoundingClientRect(); return r.width > 2 && r.right > W + 2; }).slice(0, 8).map(e => e.tagName + '.' + (typeof e.className === 'string' ? e.className.split(' ')[0] : '') + ' r=' + Math.round(e.getBoundingClientRect().right)); }));
    await shot('fold-sheet');
    await tapEl('.side .accrow', /Ventilation/); await sleep(600); await shot('fold-sheet-vent');
    say('vent rows spill:', await page.evaluate(() => { const W = innerWidth; return Array.from(document.querySelectorAll('.side *')).filter(e => { const r = e.getBoundingClientRect(); return r.width > 2 && r.right > W + 2; }).slice(0, 8).map(e => e.tagName + '.' + (typeof e.className === 'string' ? e.className.split(' ')[0] : '') + ' r=' + Math.round(e.getBoundingClientRect().right)); }));
  };
  T.dims = async () => {
    await emu('se');
    await page.goto('http://127.0.0.1:8766/booth-builder?product=MDL%207272%20S', { waitUntil: 'networkidle0', timeout: 60000 }); await ready();
    await page.evaluate(() => { const b = document.querySelector('.bb-coach-x'); if (b) b.click(); });
    const g = await page.evaluate(() => { const l = document.querySelector('label.bb-tog'); const sw = l.querySelector('.bb-sw'); const r = l.getBoundingClientRect(), s = sw.getBoundingClientRect(); return { label: { w: Math.round(r.width), h: Math.round(r.height), t: Math.round(r.top) }, switch: { w: Math.round(s.width), h: Math.round(s.height) }, pad: getComputedStyle(l).padding }; });
    say('Dimensions toggle geometry', g);
    const before = await page.evaluate(() => !!(state.showDims || state.isoDims || state.dims));
    const b = await (await page.$('label.bb-tog')).boundingBox();
    await page.touchscreen.tap(b.x + b.width - 30, b.y + b.height / 2); await sleep(800);   // tap the word
    say('tap on label text → checked:', await page.evaluate(() => document.querySelector('label.bb-tog input').checked));
    await page.touchscreen.tap(b.x + b.width - 30, b.y + b.height + 14); await sleep(800);   // 14px below — a thumb-miss
    say('tap 14px below → checked:', await page.evaluate(() => document.querySelector('label.bb-tog input').checked));
  };
  T.ipad = async () => {
    await emu('ipad');
    await page.goto('http://127.0.0.1:8766/booth-builder?product=MDL%206084%20S', { waitUntil: 'networkidle0', timeout: 60000 }); await ready();
    page.on('framenavigated', f => say('NAVIGATED', f.url()));
    say('href', await page.evaluate(() => location.href.slice(0, 80)));
    for (const re of [/Floor plan/, /Walk-around/, /Angled/]) { await tapEl('.viewswitch .vswbtn', re); await sleep(1200); say(re.source, await page.evaluate(() => ({ view: state.view, href: location.href.slice(0, 60) })).catch(e => 'EVAL ERR ' + e.message)); }
    await shot('ipad-iso');
    say('state check', await page.evaluate(() => ({ corner: state.isoCorner, sy: scrollY })).catch(e => 'EVAL ERR ' + e.message));
    await tapEl('.bb-customize button', /Customize/); await shot('ipad-sheet');
    say('sheet', await page.evaluate(() => ({ sheet: !!document.querySelector('#app.sheet-open'), sideW: document.querySelector('.side').getBoundingClientRect().width })));
    await tapEl('.side button', /Done/); await tapEl('.bb-customize button', /Quote/); await shot('ipad-quote');
    say('quote', await page.evaluate(() => ({ modal: !document.getElementById('bb2QuoteModal').hidden })));
  };
  try { await T[TEST](); } catch (e) { say('THREW', e.stack); await shot('ERR-' + TEST).catch(() => {}); }
  say('pageerrors', errors);
  await browser.close();
})();
