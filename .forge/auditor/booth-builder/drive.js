// Lane C driver: behave like a customer on a phone. Taps go through the
// touchscreen so hit-testing, overlays and touch-action are all exercised.
// usage: node drive.js <device> <scenario> [port]
'use strict';
const puppeteer = require('C:/Users/bento/Documents/Claude/WhisperRoomQuote/node_modules/puppeteer');
const fs = require('fs'), path = require('path');
const OUT = 'C:/Users/bento/Documents/Claude/Sketchup/.forge/auditor/booth-builder/mobile-shots';
const [,, DEV = 'se', SCEN = 'flow', PORT = '8766'] = process.argv;
const BASE = 'http://127.0.0.1:' + PORT;
const sleep = ms => new Promise(r => setTimeout(r, ms));

const UA_IOS = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1';
const UA_AND = 'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';
const DEVICES = {
  se:      { name: 'iPhone SE 375x667',        userAgent: UA_IOS, viewport: { width: 375, height: 667, deviceScaleFactor: 2, isMobile: true, hasTouch: true } },
  seland:  { name: 'iPhone SE landscape',      userAgent: UA_IOS, viewport: { width: 667, height: 375, deviceScaleFactor: 2, isMobile: true, hasTouch: true, isLandscape: true } },
  i14:     { name: 'iPhone 14 Pro Max 430x932', userAgent: UA_IOS, viewport: { width: 430, height: 932, deviceScaleFactor: 3, isMobile: true, hasTouch: true } },
  i14land: { name: 'iPhone 14 Pro Max landscape', userAgent: UA_IOS, viewport: { width: 932, height: 430, deviceScaleFactor: 3, isMobile: true, hasTouch: true, isLandscape: true } },
  px7:     { name: 'Pixel 7 412x915',          userAgent: UA_AND, viewport: { width: 412, height: 915, deviceScaleFactor: 2.625, isMobile: true, hasTouch: true } },
  fold:    { name: 'Galaxy Fold 280x653',      userAgent: UA_AND, viewport: { width: 280, height: 653, deviceScaleFactor: 3, isMobile: true, hasTouch: true } },
  ipad:    { name: 'iPad Mini 768x1024',       userAgent: UA_IOS, viewport: { width: 768, height: 1024, deviceScaleFactor: 2, isMobile: true, hasTouch: true } },
  ipadland:{ name: 'iPad landscape 1024x768',  userAgent: UA_IOS, viewport: { width: 1024, height: 768, deviceScaleFactor: 2, isMobile: true, hasTouch: true, isLandscape: true } },
  desk:    { name: 'Desktop 1440x900', userAgent: null, viewport: { width: 1440, height: 900, deviceScaleFactor: 1 } },
  desksm:  { name: 'Desktop 1280x720', userAgent: null, viewport: { width: 1280, height: 720, deviceScaleFactor: 1 } },
};
const D = DEVICES[DEV]; if (!D) throw new Error('unknown device ' + DEV);
const log = [];
const say = (...a) => { const s = a.map(x => typeof x === 'string' ? x : JSON.stringify(x)).join(' '); console.log(s); log.push(s); };

(async () => {
  const browser = await puppeteer.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: 'new', args: ['--no-sandbox', '--disable-gpu'] });
  const page = await browser.newPage();
  if (D.userAgent) await page.emulate({ userAgent: D.userAgent, viewport: D.viewport }); else await page.setViewport(D.viewport);
  const errors = [];
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));
  page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') errors.push(m.type() + ': ' + m.text().slice(0, 300)); });
  page.on('requestfailed', r => errors.push('reqfail: ' + r.url() + ' ' + (r.failure() && r.failure().errorText)));
  page.on('response', r => { if (r.status() >= 400) errors.push('http ' + r.status() + ' ' + r.url()); });

  const shot = async (name, full) => { const f = path.join(OUT, DEV + '-' + SCEN + '-' + name + '.png'); await page.screenshot({ path: f, fullPage: !!full }); say('  shot', path.basename(f)); return f; };
  const ready = async (t = 30000) => {
    await page.waitForFunction(() => typeof state !== 'undefined' && document.getElementById('app') && !document.querySelector('#app > .loading'), { timeout: t }).catch(e => say('  !! ready timeout:', e.message));
    await sleep(1500);
  };
  const st = () => page.evaluate(() => ({ model: state.model, variant: state.variant, view: state.view, sheet: !!document.querySelector('#app.sheet-open'), gallery: !(document.getElementById('bbGallery') || { hidden: true }).hidden, quoteModal: !(document.getElementById('bb2QuoteModal') || { hidden: true }).hidden, roomfit: document.body.classList.contains('bb-roomfit-open'), loading: (document.querySelector('#app .loading') || {}).textContent || null, toast: (document.getElementById('toast') || {}).textContent || '', gate: !!document.getElementById('wrPortraitGate') }));
  // layout audit: page-level horizontal overflow and elements poking past the viewport edge
  const layoutAudit = async (label) => {
    const r = await page.evaluate(() => {
      const W = innerWidth, H = innerHeight;
      const de = document.documentElement;
      const out = { innerW: W, innerH: H, docScrollW: de.scrollWidth, bodyScrollW: document.body.scrollWidth, docScrollH: de.scrollHeight, vvScale: (visualViewport && visualViewport.scale) || null, vvW: visualViewport && visualViewport.width, spill: [] };
      const desc = el => (el.tagName.toLowerCase() + (el.id ? '#' + el.id : '') + (el.className && typeof el.className === 'string' ? '.' + el.className.trim().split(/\s+/).slice(0, 3).join('.') : '')) + ' "' + (el.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 40) + '"';
      const seen = new Set();
      for (const el of document.querySelectorAll('body *')) {
        const cs = getComputedStyle(el); if (cs.display === 'none' || cs.visibility === 'hidden' || cs.opacity === '0') continue;
        const r = el.getBoundingClientRect(); if (r.width < 2 || r.height < 2) continue;
        if (r.right > W + 2 || r.left < -2) {
          // skip if an ancestor already reported (only report outermost)
          let a = el.parentElement, dup = false; while (a) { if (seen.has(a)) { dup = true; break; } a = a.parentElement; }
          if (dup) continue; seen.add(el);
          // skip overflow-clipped by ancestors: check whether any ancestor clips
          let clip = false; a = el.parentElement; while (a && a !== document.body) { const c = getComputedStyle(a); if (/(hidden|auto|scroll|clip)/.test(c.overflowX)) { const ar = a.getBoundingClientRect(); if (ar.right <= W + 2 && ar.left >= -2) { clip = true; break; } } a = a.parentElement; }
          out.spill.push({ el: desc(el), left: Math.round(r.left), right: Math.round(r.right), w: Math.round(r.width), clipped: clip });
        }
      }
      out.spill = out.spill.slice(0, 20);
      return out;
    });
    say('  layout[' + label + ']', { innerW: r.innerW, innerH: r.innerH, docScrollW: r.docScrollW, docScrollH: r.docScrollH, vvScale: r.vvScale });
    const real = r.spill.filter(s => !s.clipped);
    if (real.length) say('  SPILL[' + label + ']', real); else say('  no horizontal spill (' + r.spill.length + ' clipped-only)');
    return r;
  };
  // tap targets: visible, reachable interactive elements smaller than 44px in either axis
  const targetAudit = async (label) => {
    const r = await page.evaluate(() => {
      const W = innerWidth, H = innerHeight, res = [];
      const desc = el => (el.tagName.toLowerCase() + (el.id ? '#' + el.id : '') + (el.className && typeof el.className === 'string' ? '.' + el.className.trim().split(/\s+/).slice(0, 2).join('.') : '')) + ' "' + ((el.getAttribute('aria-label') || el.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 30)) + '"';
      for (const el of document.querySelectorAll('button,a[href],input,select,textarea,[role=button],[role=tab],[onclick],summary,label')) {
        const cs = getComputedStyle(el); if (cs.display === 'none' || cs.visibility === 'hidden' || cs.pointerEvents === 'none') continue;
        const r = el.getBoundingClientRect(); if (r.width < 1 || r.height < 1) continue;
        if (r.bottom < 0 || r.top > H || r.right < 0 || r.left > W) continue;
        const cx = Math.min(W - 1, Math.max(0, r.left + r.width / 2)), cy = Math.min(H - 1, Math.max(0, r.top + r.height / 2));
        const hit = document.elementFromPoint(cx, cy); const reach = hit && (hit === el || el.contains(hit) || hit.contains(el));
        // effective size: union with padding already in rect; also check ::before/after? skip
        if (r.width < 44 || r.height < 44) res.push({ el: desc(el), w: Math.round(r.width), h: Math.round(r.height), reachable: !!reach, coveredBy: reach ? null : (hit ? hit.tagName.toLowerCase() + '.' + (typeof hit.className === 'string' ? hit.className.split(/\s+/)[0] : '') : 'none') });
      }
      return res;
    });
    const small = r.filter(x => (x.w < 40 || x.h < 40));
    say('  targets[' + label + '] <44px:', r.length, ' <40px:', small.length);
    say('  small:', small.slice(0, 40));
    return r;
  };
  const tap = async (sel, what) => {
    const ok = await page.evaluate((sel) => { const el = typeof sel === 'string' ? document.querySelector(sel) : null; if (!el) return null; const r = el.getBoundingClientRect(); return { x: r.left + r.width / 2, y: r.top + r.height / 2, w: r.width, h: r.height, off: r.bottom > innerHeight || r.top < 0 || r.right > innerWidth || r.left < 0 }; }, sel);
    if (!ok) { say('  !! tap: no element for', sel, what || ''); return false; }
    if (ok.off) say('  !! tap target off-screen:', sel, ok);
    await page.touchscreen.tap(ok.x, ok.y); await sleep(700); say('  tap', what || sel, '@', Math.round(ok.x) + ',' + Math.round(ok.y));
    return true;
  };
  // tap the first element matching selector whose text matches regex
  const tapText = async (sel, re, what) => {
    const h = await page.evaluateHandle((sel, src, flags) => { const re = new RegExp(src, flags); return Array.from(document.querySelectorAll(sel)).find(e => { const cs = getComputedStyle(e); if (cs.display === 'none' || cs.visibility === 'hidden') return null; const r = e.getBoundingClientRect(); return r.width > 0 && re.test((e.getAttribute('aria-label') || '') + ' ' + (e.textContent || '').replace(/\s+/g, ' ')); }) || null; }, sel, re.source, re.flags);
    const el = h.asElement(); if (!el) { say('  !! tapText: nothing matches', sel, re.source, what || ''); return false; }
    let box = await el.boundingBox(); if (!box) { say('  !! tapText: no box', re.source); return false; }
    const vp = page.viewport();
    if (box.y + box.height / 2 > vp.height || box.y < 0) { await el.evaluate(e => e.scrollIntoView({ block: 'center' })); await sleep(400); box = await el.boundingBox(); say('  (scrolled', what || re.source, 'into view)'); }
    const cx = box.x + box.width / 2, cy = box.y + box.height / 2;
    if (cy > vp.height || cy < 0 || cx > vp.width) say('  !! tapText target off-screen:', what || re.source, { x: Math.round(cx), y: Math.round(cy) });
    const hit = await page.evaluate((x, y) => { const h = document.elementFromPoint(x, y); return h ? h.tagName.toLowerCase() + '.' + (typeof h.className === 'string' ? h.className.split(/\s+/).slice(0, 2).join('.') : '') : 'none'; }, Math.min(cx, vp.width - 1), Math.min(cy, vp.height - 1));
    await page.touchscreen.tap(cx, cy); await sleep(700);
    say('  tap', what || re.source, '@', Math.round(cx) + ',' + Math.round(cy), 'size', Math.round(box.width) + 'x' + Math.round(box.height), 'hit:', hit);
    return true;
  };
  const listInteractive = (root) => page.evaluate((root) => Array.from(document.querySelectorAll(root + ' button,' + root + ' a[href],' + root + ' input,' + root + ' select,' + root + ' [role=button],' + root + ' [onclick]')).filter(e => { const cs = getComputedStyle(e); const r = e.getBoundingClientRect(); return cs.display !== 'none' && r.width > 0; }).map(e => { const r = e.getBoundingClientRect(); return e.tagName.toLowerCase() + (e.type ? ':' + e.type : '') + '.' + (typeof e.className === 'string' ? e.className.split(/\s+/).slice(0, 2).join('.') : '') + ' "' + (e.getAttribute('aria-label') || e.textContent || e.placeholder || '').trim().replace(/\s+/g, ' ').slice(0, 28) + '" ' + Math.round(r.width) + 'x' + Math.round(r.height) + '@' + Math.round(r.top); }), root);
  const swipe = async (x0, y0, x1, y1, steps = 12) => {
    const cdp = await page.target().createCDPSession();
    const pt = (x, y) => ({ x, y, radiusX: 2, radiusY: 2, force: 1, id: 1 });
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [pt(x0, y0)] });
    for (let i = 1; i <= steps; i++) { await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [pt(x0 + (x1 - x0) * i / steps, y0 + (y1 - y0) * i / steps)] }); await sleep(16); }
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await sleep(500); await cdp.detach();
  };
  const pinch = async (cx, cy, r0, r1, steps = 10) => {
    const cdp = await page.target().createCDPSession();
    const pts = r => [{ x: cx - r, y: cy, radiusX: 2, radiusY: 2, force: 1, id: 1 }, { x: cx + r, y: cy, radiusX: 2, radiusY: 2, force: 1, id: 2 }];
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: pts(r0) });
    for (let i = 1; i <= steps; i++) { await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: pts(r0 + (r1 - r0) * i / steps) }); await sleep(16); }
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await sleep(500); await cdp.detach();
  };

  say('=== device', D.name, 'scenario', SCEN, 'base', BASE);
  const S = {};

  // ─── cold customer flow ────────────────────────────────────────────────
  S.flow = async () => {
    await page.goto(BASE + '/booth-builder', { waitUntil: 'networkidle0', timeout: 90000 }); await ready();
    say('landing', await st()); await shot('01-landing'); await layoutAudit('landing'); await targetAudit('landing');
    say('  gallery controls:', (await listInteractive('#bbGallery')).slice(0, 30));
    // pick a size (a non-default one)
    await tapText('#bbGallery [role=tab]', /Sizes/, 'Sizes tab');
    // scroll the gallery grid so a card is on-screen, then tap it
    const cardSel = '#bbGallery .gcard[onclick*="MDL 6084"]';
    await page.evaluate((sel) => { const c = document.querySelector(sel); if (c) c.scrollIntoView({ block: 'center' }); }, cardSel); await sleep(400);
    await shot('02-gallery-sizes');
    await tap(cardSel, 'card MDL 6084');
    await sleep(2500);
    let s = await st(); say('after pick', s); await shot('03-picked');
    if (s.model !== 'MDL 6084') say('  !! MODEL DID NOT SWITCH via tap');
    await layoutAudit('booth'); await targetAudit('booth');
    say('  stage controls:', await listInteractive('.stage'));
    say('  nav controls:', await listInteractive('.bb-customize'));
    // views
    for (const [re, want, n] of [[/Floor plan/, 'top', '04-floorplan'], [/Walk-around/, 'elev', '05-walkaround'], [/Angled/, 'iso', '06-angled']]) {
      await tapText('.viewswitch .vswbtn', re, 'view ' + want); await sleep(1500); s = await st();
      if (s.view !== want) say('  !! VIEW DID NOT SWITCH to', want, 'state.view=', s.view);
      await shot(n); await layoutAudit(want); await targetAudit(want);
      if (want === 'elev') say('  elev controls:', await listInteractive('.stage'));
    }
    // gestures on the angled stage: one-finger swipe (should it rotate or scroll?), pinch
    const before = await page.evaluate(() => ({ corner: state.isoCorner, scrollY, zoom: (typeof state.isoZoom !== 'undefined' ? state.isoZoom : null), rung: (typeof state.bb2Rung !== 'undefined' ? state.bb2Rung : null) }));
    const cv = await page.$('.bb2-isowrap canvas, #bbIsoCanvas, .bb-isostage');
    const cb = cv && await cv.boundingBox(); say('  canvas box', cb && { x: Math.round(cb.x), y: Math.round(cb.y), w: Math.round(cb.width), h: Math.round(cb.height) });
    if (cb) {
      await swipe(cb.x + cb.width * 0.3, cb.y + cb.height / 2, cb.x + cb.width * 0.8, cb.y + cb.height / 2);
      const afterSw = await page.evaluate(() => ({ corner: state.isoCorner, scrollY, stageScroll: (document.querySelector('.bb-isozoom, .bb2-isowrap') || {}).scrollLeft }));
      say('  swipe on canvas: before', before, 'after', afterSw);
      await pinch(cb.x + cb.width / 2, cb.y + cb.height / 2, 30, 110);
      const afterP = await page.evaluate(() => ({ vvScale: visualViewport.scale, zoom: (typeof state.isoZoom !== 'undefined' ? state.isoZoom : null), zoomEl: (document.querySelector('.bb-isozoom') || {}).dataset }));
      say('  pinch on canvas:', afterP); await shot('07-after-pinch');
      // double-tap on canvas
      await page.touchscreen.tap(cb.x + cb.width / 2, cb.y + cb.height / 2); await sleep(90); await page.touchscreen.tap(cb.x + cb.width / 2, cb.y + cb.height / 2); await sleep(700);
      say('  dbl-tap canvas: vvScale', await page.evaluate(() => visualViewport.scale), 'sel', await page.evaluate(() => typeof _isoSel !== 'undefined' ? (_isoSel && (_isoSel.id || JSON.stringify(_isoSel)).toString().slice(0, 40)) : 'n/a'));
      await shot('08-after-dbltap');
    }
    // customize sheet
    await tapText('.bb-customize button', /^\s*Customize/, 'nav Customize'); await sleep(900); s = await st(); say('customize', s); await shot('09-customize');
    if (!s.sheet) say('  !! sheet did not open');
    await layoutAudit('sheet'); await targetAudit('sheet');
    say('  sheet controls:', (await listInteractive('.side')).slice(0, 60));
    await tapText('.side .pill2 button', /Enhanced/, 'Enhanced'); await sleep(2500); s = await st(); say('  variant now', s.variant); await shot('10-enhanced');
    if (s.variant !== 'E') say('  !! Enhanced toggle did not take');
    // an option: open Add-ons accordion and toggle something
    await tapText('.side .accrow, .side button, .side summary', /Add-ons|Add ons|Options|Extras/, 'Add-ons row'); await sleep(900); await shot('11-addons');
    say('  sheet controls after addons:', (await listInteractive('.side')).slice(0, 80));
    const optBefore = await page.evaluate(() => ({ casters: state.casters, light: state.studioLight, desk: state.desk, step: state.step }));
    say('  addon rows:', await page.evaluate(() => Array.from(document.querySelectorAll('.side .optrow, .side .opt, .side label, .side input[type=checkbox]')).filter(e => e.getBoundingClientRect().width > 0).map(e => e.tagName + '.' + (typeof e.className === 'string' ? e.className.split(/\s+/).slice(0,2).join('.') : '') + ' "' + (e.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 40) + '" ' + Math.round(e.getBoundingClientRect().width) + 'x' + Math.round(e.getBoundingClientRect().height)).slice(0, 30)));
    await tapText('.side .optrow, .side label, .side button, .side [onclick]', /Casters|Step|Desk/i, 'option toggle'); await sleep(1500);
    const optAfter = await page.evaluate(() => ({ casters: state.casters, light: state.studioLight, desk: state.desk, step: state.step }));
    say('  option before', optBefore, 'after', optAfter); await shot('12-option');
    // close sheet
    await tapText('.side .bb-sheet-head .x, .side button', /Done|Close|✕/, 'sheet Done'); await sleep(800); s = await st(); say('after Done', s);
    if (s.sheet) say('  !! sheet still open after Done');
    // room fit
    await tapText('.bb-customize button', /Room fit/, 'nav Room fit'); await sleep(1000); s = await st(); say('roomfit', s); await shot('13-roomfit');
    await layoutAudit('roomfit'); await targetAudit('roomfit');
    say('  roomfit controls:', (await listInteractive('body')).filter(x => /room|Draw|Change|Done|ft|in/i.test(x)).slice(0, 40));
    await tapText('button, a, [onclick]', /Draw your room|Change your room|Enter your room/i, 'Draw your room'); await sleep(1000); await shot('14-roompop');
    say('  roompop controls:', (await listInteractive('.sizepop, .bb2-roompop, .bb-roomfit, body')).filter(x => /input|ft|in|Draw|Show|Apply|Done|\+|−|-/.test(x)).slice(0, 40));
    // type feet into the room inputs if present
    const wf = await page.$('.sizepop input[aria-label="Width feet"]'), wi = await page.$('.sizepop input[aria-label="Width inches"]'), lf = await page.$('.sizepop input[aria-label="Length feet"]');
    say('  room inputs found:', !!wf, !!wi, !!lf, await page.evaluate(() => Array.from(document.querySelectorAll('.sizepop input')).map(i => i.getAttribute('aria-label') + ':' + i.type + ':' + i.inputMode + ':' + getComputedStyle(i).fontSize).join(' | ')));
    if (wf && lf) {
      await wf.tap(); await sleep(300); await page.keyboard.type('10'); await wi.tap(); await sleep(200); await page.keyboard.type('14'); await lf.tap(); await sleep(300); await page.keyboard.type('12'); await sleep(500);
      await shot('15-room-typed'); say('  values after typing (14in typed into Width inches):', await page.evaluate(() => Array.from(document.querySelectorAll('.sizepop input')).map(i => i.value).join(',')), 'state.room', await page.evaluate(() => JSON.stringify(state.room)));
      say('  keyboard-clearance: input bottom vs viewport', await page.evaluate(() => { const i = document.querySelector('.sizepop input[aria-label="Length feet"]'); const r = i.getBoundingClientRect(); return { top: Math.round(r.top), bottom: Math.round(r.bottom), innerH: innerHeight }; }));
      await tapText('.sizepop button.hot', /Draw my room/i, 'Draw my room'); await sleep(2500);
    }
    s = await st(); say('after room', s, await page.evaluate(() => ({ room: state.room, showRoom: state.showRoom, fitText: Array.from(document.querySelectorAll('.bb2-fitverdict, .bb-fitchip, .bb2-roompill, [class*=fit]')).map(e => (e.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 60)).filter(Boolean).slice(0, 6) }))); await shot('16-room-drawn');
    // does the room survive a view change and a model change?
    await tapText('.viewswitch .vswbtn', /Floor plan/, 'view top (with room)'); await sleep(1500); await shot('16b-room-floorplan');
    await tapText('.viewswitch .vswbtn', /Angled/, 'view iso (with room)'); await sleep(1500);
    await layoutAudit('room'); await targetAudit('room');
    // quote
    await tapText('.bb-customize button', /Quote/, 'nav Quote'); await sleep(1200); s = await st(); say('quote', s); await shot('17-quote');
    if (!s.quoteModal) say('  !! quote modal did not open');
    await layoutAudit('quote'); await targetAudit('quote');
    say('  quote controls:', (await listInteractive('#bb2QuoteModal')).slice(0, 40));
    const fi = await page.$$('#bb2QuoteModal input.fi, #bb2QuoteModal textarea.fi');
    say('  quote fields:', fi.length, await page.evaluate(() => Array.from(document.querySelectorAll('#bb2QuoteModal input,#bb2QuoteModal textarea')).map(i => i.name || i.placeholder || i.id).join(', ')));
    say('  field font-size (iOS auto-zoom if <16px):', await page.evaluate(() => Array.from(document.querySelectorAll('#bb2QuoteModal input.fi,#bb2QuoteModal textarea.fi')).map(i => getComputedStyle(i).fontSize).join(',')));
    if (fi.length >= 2) {
      await fi[0].tap(); await page.keyboard.type('Test Customer'); await fi[1].tap(); await page.keyboard.type('test@example.com'); await sleep(400);
      await shot('18-quote-filled');
      // find the submit
      await page.evaluate(() => { const b = Array.from(document.querySelectorAll('#bb2QuoteModal button')).find(b => /send|request|submit/i.test(b.textContent)); if (b) b.scrollIntoView({ block: 'center' }); }); await sleep(300);
      await tapText('#bb2QuoteModal button', /send|request|submit/i, 'submit'); await sleep(2500);
      say('  requested:', await page.evaluate(() => ({ requested: state.requested, sending: state.sending, toast: document.getElementById('toast').textContent })));
      await shot('19-quote-sent');
    }
    // hash after all this
    say('  final url hash length', await page.evaluate(() => location.hash.length), 'errors:', errors.length);
  };

  // ─── entry paths ───────────────────────────────────────────────────────
  S.entries = async () => {
    const cases = [
      ['?product=' + encodeURIComponent('MDL 7272 S'), 'product-ok'],
      ['?product=' + encodeURIComponent('MDL 7272 E') + '&acc=' + encodeURIComponent('Casters,Studio Light'), 'product-acc'],
      ['?product=Unsure', 'product-unsure'],
      ['?product=' + encodeURIComponent('Bogus Booth 9000'), 'product-bogus'],
      ['?product=', 'product-empty'],
      ['?product=%3Cscript%3Ealert(1)%3C/script%3E', 'product-xss'],
      ['?product=MDL%207272%20S&page=/sound-booths/mdl-7272', 'product-page'],
      ['?product=MDL%207272%20S&page=javascript:alert(1)', 'product-badpage'],
      ['?d=nope', 'd-unknown'],
      ['?d=', 'd-empty'],
      ['#d=' + Buffer.from('garbage!!').toString('base64'), 'hash-garbage'],
      ['#d=%%%', 'hash-percent'],
      ['#3=zzzz', 'hash-3-garbage'],
      ['?start=room', 'room-start'],
      ['?start=room&room=10x12', 'room-10x12'],
      ['?start=room&room=10x12x7', 'room-ceiling'],
      ['?start=room&room=abc', 'room-bad'],
      ['?start=room&room=0x0', 'room-zero'],
      ['?start=room&room=1e3x12', 'room-exp'],
      ['?room=10x12', 'room-nostart'],
      ['?src=homepage', 'src-home'],
      ['?src=<b>x', 'src-junk'],
    ];
    for (const [q, name] of cases) {
      errors.length = 0;
      await page.goto('about:blank');
      await page.goto(BASE + '/booth-builder' + q, { waitUntil: 'networkidle0', timeout: 90000 }); await ready(20000);
      const s = await st();
      const extra = await page.evaluate(() => ({ pkg: state.pkg, steps: state.stepsDone && Object.keys(state.stepsDone).filter(k => state.stepsDone[k]), room: state.room && (state.room.wFt + 'x' + state.room.lFt + ' c' + state.room.cFt), showRoom: state.showRoom, roomEntry: state.roomEntry, startbar: !(document.getElementById('bbStartBar') || { hidden: true }).hidden, startbarHref: (document.querySelector('#bbStartBar a') || {}).href || null, opts: { casters: state.casters, light: state.studioLight }, dl: (window.dataLayer || []).slice(-1)[0], appText: (document.getElementById('app').innerText || '').slice(0, 80).replace(/\n/g, ' | ') }));
      say('ENTRY', name, q.slice(0, 60), s, extra, 'errors:', errors.slice(0, 4));
      await shot('entry-' + name);
    }
  };

  // ─── failure states (point at a server started with FAIL/DROP/SLOW) ───
  S.fail = async () => {
    errors.length = 0;
    const t0 = Date.now();
    try { await page.goto(BASE + '/booth-builder', { waitUntil: 'domcontentloaded', timeout: 60000 }); } catch (e) { say('goto:', e.message); }
    for (const t of [1500, 4000, 8000, 15000]) {
      await sleep(t - (Date.now() - t0) > 0 ? t - (Date.now() - t0) : 0);
      const v = await page.evaluate(() => ({ app: (document.getElementById('app').innerText || '').slice(0, 120).replace(/\n/g, ' | '), hasState: typeof state !== 'undefined', model: typeof state !== 'undefined' ? state.model : null, layouts: typeof LAYOUTS !== 'undefined' && !!LAYOUTS, gallery: !(document.getElementById('bbGallery') || { hidden: true }).hidden, view: typeof state !== 'undefined' ? state.view : null, buttons: document.querySelectorAll('#app button').length })).catch(e => ({ err: e.message }));
      say('t=' + t + 'ms', v);
      await shot('fail-t' + t);
    }
    say('errors:', errors.slice(0, 10));
    // if the page is alive, try the quote submission and the share link under the outage
    const alive = await page.evaluate(() => typeof state !== 'undefined' && !!LAYOUTS).catch(() => false);
    if (alive) {
      await page.evaluate(() => { try { closeGallery(); } catch (e) {} });
      await tapText('.bb-customize button', /Quote/, 'nav Quote'); await sleep(1000);
      const fi = await page.$$('#bb2QuoteModal input.fi');
      if (fi.length >= 2) { await fi[0].tap(); await page.keyboard.type('T'); await fi[1].tap(); await page.keyboard.type('t@t.com'); await tapText('#bb2QuoteModal button', /send|request|submit/i, 'submit'); await sleep(3000); say('  quote under outage:', await page.evaluate(() => ({ requested: state.requested, sending: state.sending, toast: document.getElementById('toast').textContent, modal: !document.getElementById('bb2QuoteModal').hidden }))); await shot('fail-quote'); }
    }
  };

  // ─── rotation: start portrait, rotate to landscape, back ──────────────
  S.rotate = async () => {
    await page.goto(BASE + '/booth-builder?product=MDL%207272%20S', { waitUntil: 'networkidle0', timeout: 90000 }); await ready();
    say('portrait', await st()); await shot('r1-portrait');
    const vp = D.viewport;
    await page.setViewport(Object.assign({}, vp, { width: vp.height, height: vp.width, isLandscape: true })); await sleep(1500);
    say('landscape', await st()); await shot('r2-landscape'); await layoutAudit('landscape');
    // dismiss gate if present
    const g = await page.$('#wrPortraitGate .wrpg-x');
    if (g) { const b = await g.boundingBox(); await page.touchscreen.tap(b.x + b.width / 2, b.y + b.height / 2); await sleep(1200); say('gate dismissed', await st()); await shot('r3-landscape-escape'); await layoutAudit('landscape-escape'); await targetAudit('landscape-escape'); await shot('r3b-landscape-escape-full', true);
      say('  landscape controls:', await listInteractive('.stage, .bb-customize'));
      // can the customer reach the nav and the canvas?
      const reach = await page.evaluate(() => { const nav = document.querySelector('.bb-customize'); const cv = document.querySelector('.bb2-isowrap canvas,#bbIsoCanvas'); const rb = e => { if (!e) return null; const r = e.getBoundingClientRect(); return { top: Math.round(r.top), bottom: Math.round(r.bottom), h: Math.round(r.height) }; }; return { innerH: innerHeight, scrollH: document.documentElement.scrollHeight, nav: rb(nav), canvas: rb(cv) }; });
      say('  reach', reach);
      // try the flow in landscape: open customize, then quote
      await tapText('.bb-customize button', /Customize/, 'Customize (landscape)'); await sleep(900); say('  ', await st()); await shot('r4-landscape-sheet'); await layoutAudit('landscape-sheet');
      await tapText('.side .bb-sheet-head .x, .side button', /Done|Close|✕/, 'Done'); await sleep(600);
      await tapText('.bb-customize button', /Quote/, 'Quote (landscape)'); await sleep(900); say('  ', await st()); await shot('r5-landscape-quote'); await layoutAudit('landscape-quote');
      await page.evaluate(() => { try { closeQuoteModal(); } catch (e) {} });
    }
    await page.setViewport(vp); await sleep(1500);
    say('back to portrait', await st()); await shot('r6-portrait-again'); await layoutAudit('portrait-again');
  };

  // ─── desktop quick walk ───────────────────────────────────────────────
  S.desk = async () => {
    await page.goto(BASE + '/booth-builder', { waitUntil: 'networkidle0', timeout: 90000 }); await ready();
    say('landing', await st()); await shot('01-landing'); await layoutAudit('landing');
    await page.click('#bbGallery .gcard[onclick*="MDL 6084"]'); await sleep(2500); say('picked', await st()); await shot('02-picked'); await layoutAudit('picked');
    for (const [v, n] of [['top', '03-top'], ['elev', '04-elev'], ['iso', '05-iso']]) { await page.evaluate(v => setView(v), v); await sleep(1500); await shot(n); await layoutAudit(v); }
    // enhanced + option + room + quote via clicks
    const clickText = async (sel, re, what) => { const ok = await page.evaluate((sel, src) => { const re = new RegExp(src, 'i'); const e = Array.from(document.querySelectorAll(sel)).find(e => { const r = e.getBoundingClientRect(); return r.width > 0 && re.test((e.getAttribute('aria-label') || '') + ' ' + e.textContent); }); if (!e) return false; e.scrollIntoView({ block: 'center' }); const r = e.getBoundingClientRect(); return { x: r.left + r.width / 2, y: r.top + r.height / 2 }; }, sel, re.source); if (!ok) { say('  !! no', what); return; } await page.mouse.click(ok.x, ok.y); await sleep(900); say('  click', what); };
    await clickText('.pill2 button', /Enhanced/, 'Enhanced'); await sleep(2000); say('variant', (await st()).variant);
    await clickText('.side .accrow, .side button', /Add-ons/, 'Add-ons'); await shot('06-addons');
    await clickText('button, a, [onclick]', /Draw your room/, 'Draw your room'); await sleep(800); await shot('07-roompop'); await layoutAudit('roompop');
    await clickText('button', /Request my quote|Quote/, 'quote CTA'); await sleep(1000); say('quote', await st()); await shot('08-quote'); await layoutAudit('quote');
    say('  quote field font sizes:', await page.evaluate(() => Array.from(document.querySelectorAll('#bb2QuoteModal input.fi,#bb2QuoteModal textarea.fi')).map(i => getComputedStyle(i).fontSize).join(',')));
    // resize down through the bands and look for spill
    for (const w of [1200, 1100, 1023, 950, 900, 820, 768, 640, 560, 480]) { await page.setViewport({ width: w, height: 800, deviceScaleFactor: 1 }); await sleep(900); await page.evaluate(() => { try { closeQuoteModal(); } catch (e) {} }); const s = await st(); const r = await layoutAudit('w' + w); await shot('09-w' + w); }
  };

  const fn = S[SCEN]; if (!fn) throw new Error('unknown scenario ' + SCEN);
  try { await fn(); } catch (e) { say('!! scenario threw:', e.stack || e.message); await shot('ERROR').catch(() => {}); }
  say('page errors/warnings:', errors.slice(0, 25));
  fs.writeFileSync(path.join(OUT, '..', 'log-' + DEV + '-' + SCEN + '.txt'), log.join('\n'));
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });
