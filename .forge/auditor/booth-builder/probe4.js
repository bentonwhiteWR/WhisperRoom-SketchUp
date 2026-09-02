'use strict';
const puppeteer = require('C:/Users/bento/Documents/Claude/WhisperRoomQuote/node_modules/puppeteer');
const sleep = ms => new Promise(r => setTimeout(r, ms));
(async () => {
  const browser = await puppeteer.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: 'new', args: ['--no-sandbox', '--disable-gpu'] });
  const page = await browser.newPage();
  await page.emulate({ userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1', viewport: { width: 375, height: 667, deviceScaleFactor: 2, isMobile: true, hasTouch: true } });
  await page.goto('http://127.0.0.1:8766/booth-builder?product=Bogus%20Booth', { waitUntil: 'networkidle0', timeout: 60000 });
  await page.waitForFunction(() => typeof state !== 'undefined' && !document.querySelector('#app > .loading'));
  for (const t of [300, 1500, 3500]) { await sleep(t === 300 ? 300 : t === 1500 ? 1200 : 2000);
    console.log('t=' + t, await page.evaluate(() => { const el = document.getElementById('toast'); const r = el.getBoundingClientRect(); const cs = getComputedStyle(el); const g = document.getElementById('bbGallery'); const gz = getComputedStyle(g).zIndex; const hit = document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2); return { text: el.textContent, shown: el.className, top: Math.round(r.top), bottom: Math.round(r.bottom), innerH: innerHeight, opacity: cs.opacity, z: cs.zIndex, galleryZ: gz, galleryHidden: g.hidden, elementAtToastCentre: hit && (hit.id || hit.className || hit.tagName).toString().slice(0, 30) }; }));
    await page.screenshot({ path: 'mobile-shots/probe-bogus-toast-' + t + '.png' });
  }
  await browser.close();
})();
