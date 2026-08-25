#!/usr/bin/env node
/* ============================================================
   WhisperRoom Proposal Generator — v2 (render pack)
   ------------------------------------------------------------
   Turns a folder of V-Ray / SketchUp renders + a JSON config
   into ONE self-contained, print-ready HTML render pack (images,
   wordmark and CSS all base64-inlined, nothing external).

   v2 vs v1 (build.js): v1 is the OLD WhisperRoom format —
   landscape, Arial on plain white, one big centered orange
   heading per page. v2 rebuilds the pack in the CURRENT design
   language, the "ent-mvp" system used by the in-app Client
   Proposal document (WhisperRoomQuote/proposal.html): portrait
   US-Letter sheets, the .rh running header + .ft footer, the
   numbered orange .sec section header for booth chapters, and
   the dark .band-cta closing band. See assets/proposal-v2.css.

   v1 (build.js, assets/proposal.css, template/, docs/) is
   untouched and still works — v2 is purely additive.

   Usage:
     node build-v2.js <config.json> [output.html]

   Then open the output and Print -> Save as PDF
   (PORTRAIT, US Letter, Margins: None, Background graphics ON).

   Config shape (see examples/client-name/proposal-v2.json):
     {
       "client":  "CLIENT NAME",          // single field, swaps in seconds
       "docType": "Booth Renderings",
       "date":    "July 2026",
       "contact": { "phone":"", "email":"", "web":"" },
       "cover":   { "eyebrow":"", "headlineLead":"", "sub":"",
                    "image":"renders-web/01-....jpg", "caption":"",
                    "cards":[{ "label":"", "value":"", "sub":"" }],
                    "callout":"" },
       "sections":[{ "num":"01", "model":"MDL 9696 E", "lead":"",
                     "plates":[{ "image":"", "view":"", "caption":"" }] }],
       "closing": { "heading":"", "body":"" }
     }
   Image paths resolve relative to the config file.

   Plate sizing: the sheet is a FIXED-height print page, so each
   plate's width is computed here from the render's real pixel
   dimensions and the space left on its page. The frame therefore
   HUGS the render — never letterboxed, never cropped, never
   stretched — and a sheet can never overflow onto a blank page.
   ============================================================ */

const fs = require("fs");
const path = require("path");

function die(msg){ console.error("ERROR: " + msg); process.exit(1); }

const cfgPath = process.argv[2];
if (!cfgPath) die("usage: node build-v2.js <config.json> [output.html]");
if (!fs.existsSync(cfgPath)) die("config not found: " + cfgPath);

const ROOT   = __dirname;
const cfgDir = path.dirname(path.resolve(cfgPath));
const cfg    = JSON.parse(fs.readFileSync(cfgPath, "utf8"));

const MIME = { ".png":"image/png", ".jpg":"image/jpeg", ".jpeg":"image/jpeg",
               ".webp":"image/webp", ".gif":"image/gif", ".svg":"image/svg+xml" };

function dataURI(file){
  if (!fs.existsSync(file)) die("image not found: " + file);
  const ext = path.extname(file).toLowerCase();
  const mime = MIME[ext] || "application/octet-stream";
  return `data:${mime};base64,${fs.readFileSync(file).toString("base64")}`;
}
function esc(s){ return String(s == null ? "" : s)
  .replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;"); }

/* Intrinsic pixel size of a JPEG / PNG, zero dependencies.
   JPEG: walk the marker chain to the first SOFn frame header.
   PNG:  IHDR is always the first chunk. */
function imageSize(file){
  const b = fs.readFileSync(file);
  if (b[0] === 0x89 && b[1] === 0x50) {                    // PNG
    return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) };
  }
  if (b[0] === 0xFF && b[1] === 0xD8) {                    // JPEG
    let i = 2;
    while (i < b.length - 9) {
      if (b[i] !== 0xFF) { i++; continue; }
      const marker = b[i + 1];
      // SOF0..SOF15 except DHT(C4) / JPG(C8) / DAC(CC) carry the frame size
      if (marker >= 0xC0 && marker <= 0xCF &&
          marker !== 0xC4 && marker !== 0xC8 && marker !== 0xCC) {
        return { h: b.readUInt16BE(i + 5), w: b.readUInt16BE(i + 7) };
      }
      i += 2 + b.readUInt16BE(i + 2);
    }
  }
  die("could not read image dimensions: " + file);
}

/* ── print-sheet geometry (must mirror assets/proposal-v2.css) ──
   8.5in x 10.98in sheet, padding .5in .6in .45in, at 96 CSS px/in.
   The measured block heights below are the rendered heights of the
   fixed page furniture; they are what leaves room for the plate.
   Verified in headless Chrome (see the fit report build-v2 prints). */
const PX          = 96;
const CONTENT_W   = Math.floor((8.5 - 0.6 * 2) * PX);        // 700 px
const CONTENT_H   = Math.floor((10.98 - 0.5 - 0.45) * PX);   // 962 px
// Rendered heights of the fixed page furniture, measured in headless Chrome
// with the @media print rules forced on. Change the CSS -> re-measure these.
const H_HEADER      = 65;    // .rh
const H_HEADER_COVER= 73;    // .rh with the cover's larger wordmark
const H_SECTION     = 60;    // .sec (26 top margin + 19 + 15 bottom margin)
const H_FOOTER      = 62;    // .ft (16 pad + 1px rule + org block)
const H_BAND        = 126;   // .band-cta in flow (26 margin + box - .45in bleed)
const H_SAFETY      = 12;    // sub-pixel + font-metric slack
// text blocks: [line height, block padding, chars that fit on one line]
const T_LEAD    = { lh: 21,   pad: 18, cpl: 68  };  // 12.5px / max-width 70ch
const T_CAP     = { lh: 17,   pad: 10, cpl: 125 };  // 11px across the plate width
const T_SUB     = { lh: 22.4, pad: 14, cpl: 62  };  // 14px / max-width 62ch
const T_CALLOUT = { lh: 20.6, pad: 46, cpl: 82  };  // 12.5px + 30 padding + 16 margin
const H_EYEBROW   = 39;   // 14 margin + 13 + 10 margin (measured)
const H_COVER_LINE= 41;   // .cover-h 37px / 1.1
const H_HEROCAP   = 28;   // 16 line + 12 margin
const H_CARDS     = 84;   // .cards strip
const H_HERO_CHROME = 24; // 14 top margin + 8 bottom margin + 2px border

// how tall a text block renders, from its (tag-stripped) length
function textH(t, spec, extra){
  const n = String(t || "").replace(/<[^>]*>/g, "").length + (extra || 0);
  if (!n) return 0;
  return Math.ceil(Math.ceil(n / spec.cpl) * spec.lh) + spec.pad;
}

/* ── assets ── */
const css      = fs.readFileSync(path.join(ROOT, "assets", "proposal-v2.css"), "utf8");
// The CURRENT brand lockup: the app's vector wordmark (dark ink #262626),
// same file the in-app proposal serves at /assets/whisperroom-logo.svg.
// NOT assets/whisperroom-logo*.png — those are the old raster orange lockup.
// Inlined ONCE, as a CSS background on .wm (see proposal-v2.css).
const wordmark = dataURI(path.join(ROOT, "assets", "whisperroom-wordmark.svg"));
const wordmarkCss = `\n.wm{background-image:url("${wordmark}")}\n`;
const mark = `<span class="wm" role="img" aria-label="WhisperRoom"></span>`;

/* ── config ── */
const client  = cfg.client  || "CLIENT NAME";
const docType = cfg.docType || "Booth Renderings";
const date    = cfg.date    || "";
const c       = cfg.contact || {};
const phone   = c.phone || "(865) 558-5364";
const email   = c.email || "info@whisperroom.com";
const web     = c.web   || "www.whisperroom.com";
const cover   = cfg.cover || {};
const sections = cfg.sections || [];
if (!sections.length) die("config has no sections[]");

const plateCount = sections.reduce((n, s) => n + (s.plates || []).length, 0);
// An optional pricing sheet is the LAST page when present, so it - not the last
// plate - carries the closing band. Added August 2026; a config without a
// `pricing` block builds exactly as it always did.
const pricing = cfg.pricing || null;
const totalPages = 1 + plateCount + (pricing ? 1 : 0);
const pad2 = n => String(n).padStart(2, "0");

/* ── page furniture ── */
function rh(metaLines){
  return `<header class="rh">`
    + `<div class="rh-brand">${mark}`
    +   `<div class="rh-tag">Sound Isolation Enclosures</div></div>`
    + `<div class="rh-meta">${metaLines.filter(Boolean).join("<br>")}</div>`
    + `</header>`;
}
function ft(){
  return `<footer class="ft">`
    + `<div class="ft-note"><span class="ft-orange">Phone:</span> ${esc(phone)} &middot; `
    +   `<span class="ft-orange">Email:</span> ${esc(email)} &middot; ${esc(web)}</div>`
    + `<div class="ft-org"><strong>WhisperRoom, Inc.&trade;</strong>322 Nancy Lynn Lane, Suite 14<br>`
    +   `Knoxville, TN 37919 USA</div>`
    + `</footer>`;
}
function sec(num, title, extra){
  return `<div class="sec"><span class="sec-bar"></span><span class="sec-num">${esc(num)}</span>`
    + `<h2 class="sec-h">${title}</h2>`
    + (extra ? `<span class="sec-extra">${esc(extra)}</span>` : "")
    + `</div>`;
}
function band(){
  const cl = cfg.closing || {};
  return `<div class="band-cta"><div>`
    + `<h3>${esc(cl.heading || "Questions about this configuration")}<span class="o">?</span></h3>`
    + (cl.body ? `<p>${esc(cl.body)}</p>` : "")
    + `<div class="band-contact"><b>Phone:</b> ${esc(phone)} &middot; <b>Email:</b> ${esc(email)} &middot; ${esc(web)}</div>`
    + `</div>`
    + `<div class="band-logo">${mark}`
    +   `<span class="c">322 Nancy Lynn Lane, Suite 14<br>Knoxville, TN 37919 USA</span></div></div>`;
}

const fit = [];   // fit report, printed after the build

/* ── cover sheet ── */
function coverSheet(){
  const heroFile = path.resolve(cfgDir, cover.image);
  const hero = dataURI(heroFile);
  const hs = imageSize(heroFile);
  const heroAr = hs.w / hs.h;
  // everything on the cover except the hero itself
  const used = H_HEADER_COVER + H_EYEBROW
    + (cover.headlineLines || 2) * H_COVER_LINE
    + textH(cover.sub, T_SUB)
    + (cover.caption ? H_HEROCAP : 0)
    + ((cover.cards || []).length ? H_CARDS : 0)
    + textH(cover.callout, T_CALLOUT, (cover.calloutLead || "").length)
    + H_FOOTER + H_SAFETY + H_HERO_CHROME;
  const heroW = Math.min(CONTENT_W, Math.floor((CONTENT_H - used) * heroAr));
  fit.push({ page: 1, img: path.basename(heroFile), px: `${hs.w}x${hs.h}`,
             aspect: heroAr.toFixed(3), plate: `${heroW}x${Math.round(heroW / heroAr)}`,
             free: CONTENT_H - used - Math.round(heroW / heroAr) });
  const cards = (cover.cards || []).map(k =>
      `<div class="card"><div class="card-l">${esc(k.label)}</div>`
    + `<div class="card-b">${esc(k.value)}`
    + (k.sub ? `<div class="sm">${esc(k.sub)}</div>` : "")
    + `</div></div>`).join("");
  return `<section class="sheet cover">`
    + rh([esc(docType), esc(client), esc(date)])
    + `<div class="eyebrow">${esc(cover.eyebrow || docType)}</div>`
    + `<h1 class="cover-h">${esc(cover.headlineLead || "Booth renderings for")} `
    +   `<span class="o">${esc(client)}</span></h1>`
    + (cover.sub ? `<p class="cover-sub">${esc(cover.sub)}</p>` : "")
    + `<figure class="hero" style="width:${heroW}px"><img src="${hero}" alt="${esc(client)} render"></figure>`
    + (cover.caption
        ? `<p class="hero-cap" style="width:${heroW}px"><b>${esc(cover.captionLead || "")}</b> ${esc(cover.caption)}</p>` : "")
    + (cards ? `<div class="cards">${cards}</div>` : "")
    + (cover.callout
        ? `<div class="callout"><p><strong>${esc(cover.calloutLead || "About these renderings.")}</strong> `
          + `${esc(cover.callout)}</p></div>` : "")
    + ft()
    + `</section>`;
}

/* ── render plates ── */
let pageNo = 1;

function plateSheet(section, plate, plateIdxInSection, isLastPage){
  pageNo++;
  const file = path.resolve(cfgDir, plate.image);
  const { w, h } = imageSize(file);
  const aspect = w / h;
  const isChapterOpen = plateIdxInSection === 0 && !!section.lead;

  // how much vertical room is left for the plate on THIS page
  let used = H_HEADER + H_SECTION + H_SAFETY
    + textH(plate.caption, T_CAP, 9)              // 9 = the "Image NN " prefix
    + (isLastPage ? H_BAND : H_FOOTER)            // the band replaces the footer
    + (isChapterOpen ? textH(section.lead, T_LEAD) : 0);
  const availH = CONTENT_H - used;
  const plateW = Math.min(CONTENT_W, Math.floor(availH * aspect));
  const plateH = Math.round(plateW / aspect);

  fit.push({ page: pageNo, img: path.basename(file), px: `${w}x${h}`,
             aspect: aspect.toFixed(3), plate: `${plateW}x${plateH}`,
             free: CONTENT_H - used - plateH });

  return `<section class="sheet${isLastPage ? " closing" : ""}">`
    + rh([`Booth ${section.boothOf || ""}`.trim(), esc(section.model),
          `Page <span class="pnum">${pad2(pageNo)}</span> / ${totalPages}`])
    + sec(section.num, `${esc(section.model)} &mdash; ${esc(plate.view)}`, section.extra || "")
    + (isChapterOpen ? `<p class="lead">${section.lead}</p>` : "")
    + `<figure class="plate">`
    +   `<div class="fig-img" style="width:${plateW}px"><img src="${dataURI(file)}" `
    +     `alt="${esc(section.model)} ${esc(plate.view)}"></div>`
    +   `<figcaption style="width:${plateW}px"><span class="fig-n">Image ${pad2(pageNo - 1)}</span>`
    +     `${esc(plate.caption)}</figcaption>`
    + `</figure>`
    + (isLastPage ? band() : ft())
    + `</section>`;
}

/* ── pricing sheet ──
   Quoted figures, laid out in the same page furniture as every other sheet.
   The generator does no arithmetic: every number here comes from the config,
   which comes from a real quote. A total this file computed itself would be a
   total nobody had checked against the quote it claims to reproduce. */
function money(v){
  return v === null || v === undefined || v === "" ? "&mdash;" : esc(String(v));
}
function pricingSheet(pr){
  pageNo++;
  const cols = pr.columns || [];
  const head = `<tr><th>${esc(pr.itemHead || "Item")}</th>`
    + cols.map(c => `<th>${esc(c.name)}`
        + (c.sub ? `<span class="pq">${esc(c.sub)}</span>` : "")
        + (c.quote ? `<span class="pq">${esc(c.quote)}</span>` : "")
        + `</th>`).join("") + `</tr>`;
  const body = (pr.rows || []).map(r =>
      `<tr><td><span class="pit">${esc(r.item)}</span>`
    + (r.desc ? `<span class="pds">${esc(r.desc)}</span>` : "")
    + `</td>`
    + (r.values || []).map(v => `<td>${money(v)}</td>`).join("")
    + `</tr>`).join("");
  const foot = (pr.summary || []).map(r =>
      `<tr class="${r.total ? "ptot" : "psum"}"><td>${esc(r.label)}</td>`
    + (r.values || []).map(v => `<td>${money(v)}</td>`).join("")
    + `</tr>`).join("");
  return `<section class="sheet closing">`
    + rh([esc(pr.boothOf || "Pricing"), esc(pr.model || ""),
          `Page <span class="pnum">${pad2(pageNo)}</span> / ${totalPages}`])
    + sec(pr.num, esc(pr.title || "Pricing"), pr.extra || "")
    + (pr.lead ? `<p class="lead">${pr.lead}</p>` : "")
    + `<table class="ptab"><thead>${head}</thead><tbody>${body}</tbody>`
    +   `<tfoot>${foot}</tfoot></table>`
    + (pr.note ? `<div class="pnote">${pr.note}</div>` : "")
    + band()
    + `</section>`;
}

/* ── assemble ── */
const sheets = [coverSheet()];
sections.forEach((s, si) => {
  (s.plates || []).forEach((p, pi) => {
    const isLastPage = !pricing
      && si === sections.length - 1 && pi === s.plates.length - 1;
    sheets.push(plateSheet(s, p, pi, isLastPage));
  });
});
if (pricing) sheets.push(pricingSheet(pricing));

const html =
`<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>WhisperRoom ${esc(docType)} &mdash; ${esc(client)}</title>
<link rel="icon" type="image/svg+xml" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'><rect width='32' height='32' rx='7' fill='%23ee6216'/><text x='50%25' y='58%25' dominant-baseline='middle' text-anchor='middle' font-size='19' font-weight='800' font-family='Arial,Helvetica,sans-serif' fill='%23fff'>W</text></svg>">
<style>
${css}${wordmarkCss}</style>
</head>
<body>
<div class="print-bar no-print"><button onclick="window.print()">&#128424; Print</button></div>
${sheets.join("\n")}
</body>
</html>`;

const outPath = process.argv[3]
  || path.join(cfgDir, `${client.replace(/[^\w]+/g,"-")}-${docType.replace(/[^\w]+/g,"-")}-v2.html`);
fs.writeFileSync(outPath, html, "utf8");

const kb = Math.round(Buffer.byteLength(html) / 1024);
console.log(`Built ${totalPages}-page ${docType.toLowerCase()} -> ${outPath} (${kb} KB)`);
console.log(`Plate fit (content box ${CONTENT_W}x${CONTENT_H}px):`);
fit.forEach(f => console.log(
  `  p${pad2(f.page)}  ${f.img.padEnd(30)} ${f.px.padStart(9)}  ar ${f.aspect}  ->  `
  + `${f.plate.padStart(9)}  ${f.free >= 0 ? "free " + f.free + "px" : "OVERFLOW " + f.free + "px"}`));
console.log(`Open it and Print -> Save as PDF (Portrait, Letter, Margins: None, Background graphics ON).`);
