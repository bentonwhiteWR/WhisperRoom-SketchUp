// Drive booth-builder.html headlessly, capture floor / ceiling / wall views for the
// split-run models and pull the seam numbers out of the page's own state.
'use strict';
const puppeteer = require('C:/Users/bento/Documents/Claude/WhisperRoomQuote/node_modules/puppeteer');
const fs = require('fs');
const path = require('path');

const OUT = 'C:/Users/bento/Documents/Claude/Sketchup/.forge/researcher/builder-captures';
const BASE = 'http://127.0.0.1:' + (+process.env.PORT || 8765);
const MODELS = (process.argv[2] || 'MDL 7272 S,MDL 6060 S,MDL 7296 S,MDL 6084 S').split(',');
const sleep = ms => new Promise(r => setTimeout(r, ms));
const slug = s => s.replace(/[^A-Za-z0-9]+/g, '-').replace(/^-|-$/g, '').toLowerCase();

(async () => {
  const browser = await puppeteer.launch({
    executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe',
    headless: 'new', args: ['--no-sandbox', '--disable-gpu', '--window-size=1500,1100']
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1500, height: 1100, deviceScaleFactor: 2 });
  const errors = [];
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));
  page.on('console', m => { if (m.type() === 'error') errors.push('console: ' + m.text()); });
  page.on('requestfailed', r => errors.push('reqfail: ' + r.url()));
  const results = {};

  for (const product of MODELS) {
    const tag = slug(product);
    const url = BASE + '/booth-builder?product=' + encodeURIComponent(product);
    await page.goto(url, { waitUntil: 'networkidle0', timeout: 120000 });
    await page.waitForFunction(() => typeof LAYOUTS !== 'undefined' && LAYOUTS && typeof state !== 'undefined' && document.getElementById('app') && document.getElementById('app').children.length > 0, { timeout: 60000 });
    await page.waitForFunction(() => window.wrIso && wrIso.ready() && typeof isoAvailable === 'function' && isoAvailable(), { timeout: 60000 });
    await sleep(2500);

    const ident = await page.evaluate(() => ({
      model: state.model, variant: state.variant, view: state.view, corner: state.isoCorner || (window.wrIso && wrIso.defaultCorner),
      title: document.title,
      pill: Array.from(document.querySelectorAll('h1,h2,.bb2-pill,.bb-pill,[class*=model],[class*=title]')).map(e => e.textContent.trim()).filter(t => /MDL|Sound Booth|×/.test(t)).slice(0, 4),
      bodyMdl: (document.body.innerText.match(/MDL\s+\d+\s*[SE]?/g) || []).slice(0, 5)
    }));
    console.log(product, '→', JSON.stringify(ident));
    if (ident.model !== product.replace(/\s+[SE]$/, '')) { console.error('MODEL DID NOT SWITCH for ' + product); results[product] = { error: 'model did not switch', ident }; continue; }

    // ── numbers out of the page's own state ───────────────────────────────
    const nums = await page.evaluate((product) => {
      const layout = resolveLayout();
      const run = side => { const r = wallPanelRun(layout, state.assign, side); return { startIn: r.startIn, spanIn: r.spanIn, exact: r.exact, source: r.source, pieces: r.pieces.map(p => ({ id: p.id, kind: p.slot.kind, slotSize: p.slot.size, aIn: +p.aIn.toFixed(3), bIn: +p.bIn.toFixed(3), wIn: +p.wIn.toFixed(3) })), joints: r.joints.map(j => +j.toFixed(3)) }; };
      const walls = { N: run('N'), S: run('S'), E: run('E'), W: run('W') };
      const grid = { S: wallPanelRun(layout, state.assign, 'S', { moduleGrid: true }).joints, N: wallPanelRun(layout, state.assign, 'N', { moduleGrid: true }).joints };
      const M = wrIso.manifest, key = wrIso.modelKey(state.model, state.variant);
      const fc = M.fc[key];
      const fam = art => M.families.find(f => f.art === art);
      const rot = (th, p) => { const a = th * Math.PI / 180, c = Math.cos(a), s = Math.sin(a); return [p[0] * c - p[1] * s, p[0] * s + p[1] * c]; };
      const world = row => { const F = fam(row.art); if (!F) return { art: row.art, missing: true }; const pts = F.local.map(p => { const q = rot(row.th, p); return [+(q[0] + row.a[0]).toFixed(3), +(q[1] + row.a[1]).toFixed(3)]; }); const xs = pts.map(p => p[0]), ys = pts.map(p => p[1]); return { art: row.art, th: row.th, anchor: row.a, local: F.local, x0: Math.min(...xs), x1: Math.max(...xs), y0: Math.min(...ys), y1: Math.max(...ys) }; };
      const planes = {};
      for (const k of ['fl', 'fs', 'cl', 'cs', 'cle', 'cp']) if (fc && fc[k]) planes[k] = fc[k].map(world);
      const booth = (window.GEO && GEO[key]) || null;
      return { key, layoutDoorWall: layout.door && layout.door.wall, exterior: layout.exterior, walls, moduleGridJoints: grid, fc: planes, fcRaw: fc, isoGeomParts: booth ? booth.parts.filter(p => p.k === 'panel').map(p => ({ id: p.id, sk: p.sk, poly: p.poly })) : 'GEO not global' };
    }, product);
    // the angled view's plan geometry is fetched by iso-render into a closure; read it over HTTP instead
    const geo = await page.evaluate(async (key) => { const d = await (await fetch('/api/booth-iso-geometry')).json(); const b = d.booths.find(x => x.key === key); return b ? b.parts.filter(p => p.k === 'panel').map(p => ({ id: p.id, sk: p.sk, poly: p.poly })) : null; }, nums.key);
    nums.isoGeomParts = geo;
    results[product] = { ident, nums };

    // ── captures: angled view, 4 corners × 3 rungs ───────────────────────
    const corners = await page.evaluate(() => wrIso.corners.map(c => c.id));
    for (const c of corners) {
      for (const rung of [0, 1, 2]) {
        await page.evaluate((c, rung) => { setIsoCorner(c); bb2SetRung(rung); }, c, rung);
        await sleep(2200);
        const el = await page.$('.bb2-isowrap') || await page.$('#bbIsoCanvas');
        const rungName = ['roof-on', 'roof-off', 'walls-open'][rung];
        const f = path.join(OUT, `${tag}-angled-${c}-${rungName}.png`);
        if (el) await el.screenshot({ path: f }); else await page.screenshot({ path: f });
      }
    }
    await page.evaluate(() => bb2SetRung(0));

    // ── floor plan (top) ─────────────────────────────────────────────────
    await page.evaluate(() => { state.showLabels = true; setView('top'); render(); });
    await sleep(2000);
    const shot = async (file) => { for (const sel of ['#bbTop', '.stage', '.zoomwrap']) { const el = await page.$(sel); if (!el) continue; try { await el.screenshot({ path: file }); return sel; } catch (e) {} } await page.screenshot({ path: file }); return 'page'; };
    const topInfo = await page.evaluate(() => {
      const svg = document.querySelector('#bbTop svg, .stage svg, #app svg'); if (!svg) return null;
      const imgs = Array.from(svg.querySelectorAll('image')).map(i => ({ href: (i.getAttribute('href') || '').replace(/\?.*$/, ''), x: i.getAttribute('x'), y: i.getAttribute('y'), w: i.getAttribute('width'), h: i.getAttribute('height'), tf: (i.parentElement.getAttribute('transform') || '') }));
      return { viewBox: svg.getAttribute('viewBox'), floorImgs: imgs.filter(i => /floor-|fseal|flseal/.test(i.href)) };
    });
    results[product].topInfo = topInfo;
    results[product].topShot = await shot(path.join(OUT, `${tag}-floorplan-top.png`));

    // ── walk-around elevations E and W ───────────────────────────────────
    for (const face of ['E', 'W', 'S', 'N']) {
      await page.evaluate((face) => { setView('elev'); state.facing = face; render(); }, face);
      await sleep(1500);
      await shot(path.join(OUT, `${tag}-elevation-${face}.png`));
    }
    await page.screenshot({ path: path.join(OUT, `${tag}-fullpage-elev.png`), fullPage: false });
  }
  fs.writeFileSync(path.join(OUT, 'builder-state.json'), JSON.stringify(results, null, 1));
  fs.writeFileSync(path.join(OUT, 'page-errors.txt'), errors.join('\n'));
  console.log('errors:', errors.length);
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });
