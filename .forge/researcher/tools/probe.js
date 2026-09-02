const puppeteer = require('C:/Users/bento/Documents/Claude/WhisperRoomQuote/node_modules/puppeteer');
(async () => {
  const browser = await puppeteer.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: 'new', args: ['--no-sandbox'] });
  const page = await browser.newPage(); await page.setViewport({ width: 1500, height: 1100 });
  const errs = []; page.on('pageerror', e => errs.push('pageerror: ' + e.message)); page.on('console', m => errs.push(m.type() + ': ' + m.text().slice(0, 200))); page.on('requestfailed', r => errs.push('reqfail ' + r.url()));
  page.on('response', r => { if (r.status() >= 400) errs.push('HTTP ' + r.status() + ' ' + r.url()); });
  await page.goto('http://127.0.0.1:8765/booth-builder?product=' + encodeURIComponent('MDL 7272 S'), { waitUntil: 'networkidle0', timeout: 120000 });
  await new Promise(r => setTimeout(r, 8000));
  const info = await page.evaluate(() => ({ L: typeof LAYOUTS, Lk: typeof LAYOUTS !== 'undefined' && LAYOUTS ? Object.keys(LAYOUTS).length : null, st: typeof state, model: typeof state !== 'undefined' ? state.model : null, view: typeof state !== 'undefined' ? state.view : null, app: document.getElementById('app') && document.getElementById('app').children.length, iso: !!(window.wrIso && wrIso.ready()), isoAv: typeof isoAvailable === 'function' ? isoAvailable() : 'nofn', text: document.body.innerText.slice(0, 600) }));
  console.log(JSON.stringify(info, null, 1)); console.log(errs.slice(0, 30).join('\n'));
  await page.screenshot({ path: 'C:/Users/bento/Documents/Claude/Sketchup/.forge/researcher/builder-captures/_probe.png' });
  await browser.close();
})();
