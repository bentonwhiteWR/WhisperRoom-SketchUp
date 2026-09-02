# Booth Builder — Lane B: code structure, leaks, correctness

Target: `C:\Users\bento\Documents\Claude\WhisperRoomQuote\booth-builder.html` (930,552 bytes on disk, 13,700 lines) + `assets\layout-render.js`.
Method: read the file's render/boot/restore/fetch paths, then instrumented the page under Puppeteer (`probe.js` in this folder, raw output `probe-out.json`) served by the research stub with BB2 + angled view ON, the way `quote-server.js` serves it. Every count below is **observed** from that run unless tagged otherwise.

## Outcome

No XSS found: every URL/API/localStorage value I traced reaches `innerHTML` through `esc()` or a whitelist, and eight hostile payloads (attribute-break, `<img onerror>` in pack names, room dims, product, page, src) all rendered inert. No listener, DOM, or timer leak: 65 full re-renders plus 10 gallery open/close cycles left window/document listener counts and node counts exactly where they started. The real findings are (1) a one-URL page kill — `?product=constructor` (or any `Object.prototype` name, via `?product=`, `?d=`, or `#d=`) wedges the page on "Failed to load"; (2) a `?product=` / package entry renders the whole app **four times** before first paint; (3) a share link whose design fails to load silently lands on the default booth with no message; and (4) roughly **half of the 930 KB is comments** — ~348 KB of `//` lines in the JS and ~98 KB in the CSS — with only 4.4 KB of actual markup.

===DETAIL===

## 1. Findings, ranked

### F1 — MEDIUM · Prototype-key lookups on `LAYOUTS` / `PACKAGES` kill the page from the URL  (observed)

`booth-builder.html:4516` `if (PACKAGES[pkgName])`, `:2907` `if (!d || !LAYOUTS[d.m]) return false;`, `:8486` `!LAYOUTS[m]`, and 19 other `LAYOUTS[...]` / 6 `PACKAGES[...]` truthiness checks; **zero** `hasOwnProperty`/`Object.hasOwn` in the file. Both tables are plain object literals / `JSON.parse` output, so `LAYOUTS['constructor']`, `['toString']`, `['__proto__']`, `['valueOf']`, `['hasOwnProperty']` are all truthy.

Triggers, all reproduced:

| URL | Result |
|---|---|
| `/booth-builder?product=constructor` | `#app` = "Failed to load: Cannot read properties of undefined (reading 'variants')", `state.model = undefined` |
| `/booth-builder?product=__proto__` | same |
| `/booth-builder#d=<b64 of {"m":"constructor"}>` | "Failed to load: … (reading 'S')", `state.model = 'constructor'` |
| `/booth-builder#d=<b64 of {"m":"MDL 7272","pk":"constructor"}>` | page loads but the header reads **"constructor undefined undefined · 6'×6'"**; `state.pkg='constructor'` then rides into `designPayload()` → every share link, `/api/booth-price`, and `/api/booth-request` summary |

Path for the product case: `applyFormIntent` (4488) → `applyPackage('constructor')` (4435) sets `state.model = p.m` (= `undefined` because `p` is `Object`), `rebuild(true)` → `resolveLayout` (3420) throws on `base.variants`; the boot `try` at 13571 swallows it ("fall through"), `restored` stays false, `rebuild(true)` at 13623 throws again with the already-corrupted `state.model`, and the outer catch at 13695 paints the failure. `applyDesign` (2905) has the same shape: it mutates `state.model` **before** `resolveLayout()` can reject the model, and its own `catch` returns `false` without rolling that mutation back, so the "fall through" that follows runs on poisoned state.

Why it matters: 69 product pages are about to link into `?product=` and `/api/booth-design` POST (`quote-server.js:38627`) accepts any JSON with a string `m`, so a `?d=` short link can carry `{"m":"constructor"}` to anyone. It is a link-borne denial of the page, not code execution.

Fix direction: one guarded lookup helper (`Object.hasOwn(LAYOUTS, k) && LAYOUTS[k]`) used at every site, and have `applyDesign` / `applyFormIntent` validate the model **before** touching `state` (or snapshot-and-restore on failure, the way `bbWithScratch` already does at 4729).

### F2 — MEDIUM · `?product=` / package entry does the entire build four times before first paint  (observed)

Counts from the instrumented boot, desktop and phone identical:

| Entry | `render()` | `paintIso()` | `resolveLayout()` | `computeFitHtml()` |
|---|---|---|---|---|
| cold visit | 1 | 1 | 12 | 2 |
| `#d=` hash link | 1 | 1 | 25 | 2 |
| `?start=room&room=12x10x8` | 1 | 1 | 21 | 2 |
| **`?product=MDL 7272 S`** | **4** | **4** | **41** | **8** |
| **`?product=Voice-Over Basic`** (package) | **4** | **4** | **41** | **8** |
| `?product=…&acc=…` | 4 | 4 | 42 | 8 |

The four are at `applyFormIntent`: `rebuild(true)` (4522, inside the MDL branch; `applyPackage` 4448 does the same on the package branch) → `rebuild(false)` (4547) → `render()` (4556), then boot's `if (restored) render()` (13623) does it once more. Each `render()` is a wholesale `app.innerHTML = …` of the side panel, stage and modal (7936), followed by `paintIso()` and the async sprite paint, so the customer's first frame waits on four canvases. `render()` has a `_bbQuiet` gate (7822) that is exactly the mechanism to silence the intermediate three; `applyFormIntent` could run its mutations inside it and let boot's render be the only paint. This is the entry path the product-page links will use most.

### F3 — MEDIUM · A share link that fails to load silently becomes the default booth  (observed in code)

`booth-builder.html:13578-13586`: for `?d=<id>`, a network error, a non-2xx (`Design not found`, 503 "No database", 429 rate limit), or a payload `applyDesign` rejects all end in `catch (e) { /* fall through */ }` → `restoreFromHash()` → `rebuild(true)` on the default MDL 7296, and because `restored` is false the landing picker opens over it (13628) exactly as for a cold visit — no toast, nothing saying that *their* design did not load. The same holds for a corrupt `#d=` (3028 `catch → false`). Compare the unresolved-`?product=` path at 13635, which was deliberately made loud (`toast('We couldn't find that model…')`). A customer opening a rep's link and seeing a 6'×8' booth will assume that is what the rep sent. Fix direction: treat a `shortId`/hash that was present but did not restore like `unresolvedProduct` — open the picker and say so.

### F4 — LOW · `esc()` lives in `layout-render.js`, and the boot failure handler depends on it  (derived)

`booth-builder.html:13695` `'Failed to load: ' + esc(e.message)`; `esc` is defined only at `assets/layout-render.js:12`. If that script fails to load (blocked, 5xx, cache miss during a deploy), `boot()` throws early at `resolveLayout` or `render`, the catch calls `esc` → `ReferenceError` inside the async IIFE → unhandled rejection, and the page stays on "Loading booth designer…" forever with nothing in `#app`. Not reproduced (the stub always serves the asset); the dependency is readable. A local `esc` fallback, or `textContent` in that one handler, closes it.

### F5 — LOW · Per-keystroke room entry re-scores all 25 models  (observed)

`setRoomDim('lFt','14')` → 29 × `fitVerdictB`, 33 × `bb2EffRoom`, 9 × `resolveLayout` — `fitsForRoom()` (6013) keys its cache on the exact room dims, so every keystroke in the ft/in fields is a miss and rebuilds the recommendation rows for every model. `addWindow()` costs 32 × `fitVerdictB` for the same reason (the cache key includes the full `state.assign` pack list). It is synchronous and on the typing path on phones, where the fit sheet is the only way to enter dims. Lane A owns whether the milliseconds matter; structurally it is the one hot spot where work scales with catalog size × keystrokes. A short debounce on the rec panel (the verdict card itself only needs the current model) is the direction.

### F6 — LOW · Redundant `resolveLayout()` inside one render  (observed)

12–16 `resolveLayout()` calls per option toggle (`setOpt`, `setVariant`, `setHinge`, `setFoam`), 21 for `addWindow`. Each is an `Object.assign({}, base, v, {~30 fields})` (3420) plus `_wallModule` side-effect; callers `render`, `bb2SideHtml`, `bb2Card3Html`, `computeFitHtml` (×2 — the fit card is rendered twice, dock + sheet), `fitVerdictB`, `bb2EffRoom` (×6), `quoteRecapHtml` each resolve their own copy rather than taking `layout` as a parameter, although `render()` already computes `layout` at 7837 and passes it to some of them. Cheap per call, but the pattern is why one click fans out to ~40 calls of the fit math. Threading the one `layout` through is a mechanical change.

### F7 — INFO · The 930 KB, by composition  (observed, Python byte counts on the LF-normalised file, 916,852 B; +13.7 KB of CRLF on disk)

| Block | Lines | Bytes | Of which comments |
|---|---|---|---|
| `<style>` | 25–2510 | 200,309 | **98,176** (49%) in `/* */` |
| markup (`<body>` shell) | 2511–2575 | 4,418 | — |
| boot/lock script | 2576–2745 | 9,138 | — |
| main script | 2746–13698 | 701,363 | **348,006** full-line `//` (4,625 lines, 50%) + ~22 KB trailing `//` + 4.6 KB `/* */` |

So ≈ **473 KB (51%) of the shipped page is comments**. The UI itself is 100% JS-built: 4.4 KB of markup, 397 top-level functions, the largest being `render` (39 KB), `bb2Card3Html` (27 KB), `paintIso` (19 KB), `setView` (17.5 KB), `bb2AfterRender` (16 KB). Inlined data tables are small (`PACKAGES` ≈ 3.7 KB, `PKG_PHOTOS`/`MODEL_PHOTOS` ≈ 3.6 KB each, the `BL3_*` wire tables < 2 KB); the layouts and iso geometry are already fetched, not inlined.

Dead on production: `__WR_BB2_ENABLED__` appears **140** times in the JS; every `: legacy` branch (the flag-OFF side card in `render()` 7937–8005, `zoomBar`, `.bb-faces`, `railPreviewHtml`, the `wide` rail block 8133–8146, `watchQuoteCard`, the 1200 px `matchMedia` re-render at 8288) is unreachable once `quote-server.js:38479` flips the flag, which it does for the public page. Also flag-gated and unreachable unless the server enables them: art-style-2 (4 sites), dark mode (4), seal debug (4), link-v3 (1). The server gzips text (`quote-server.js:9686–9740`), so wire cost is smaller than 930 KB, but comments and dead branches are still parsed and compiled on every cold visit — Lane A has the timing.

Not a finding, for the record: there is no minifier/build step in front of this file; the comments are the file's design log, and stripping them at serve time (not in the source) is the obvious lever that keeps that.

### F8 — INFO · Same job, three ways  (observed)

- **Scratch state.** `bbWithScratch` (4729) JSON-clones all of `state`; `fitsForRoom` (6033–6060) hand-saves/restores `state.assign` + `_wallModule` in a try/finally; `_bbQuiet` (2863) is a third mechanism that silences `render`/`toast` while either is running. Three ways to say "don't let this mutation show", and `fitsForRoom` mutates globals from inside a read-only-looking getter that `render` calls twice.
- **Escaping.** `esc` (layout-render.js:12, escapes `"`), `_esc` (10120, does **not** escape `"`, clipboard HTML only), and unescaped concatenation where the value is trusted-by-construction (`FOAMS`, `FACE_LABEL[state.facing]` — `state.facing` is whitelisted at 2933, `bb2ShowMoveBar` names are literals or `esc()`ed at 12623). Correct today; the `_esc` variant is the one that will be reached for with a `"` someday.
- **Popover surfaces.** `bb2Pop` (12129), `bb2PopSheet` (12152), `bb2ShowMoveBar` (12277) each create/mount/dismiss their own element with its own `_bb2Pop*` global and its own dismiss-listener arming (`bb2ArmPopDismiss` 12100 / `bb2DisarmPopDismiss` 12118 — those are done correctly, with matching removes).

## 2. What is clean (checked, no finding)

- **Listeners.** 51 `addEventListener` sites; all but five are attached once at module scope on `document`/`window`, and the UI uses inline `onclick=` so the wholesale `innerHTML` rebuild cannot strand handlers. The five dynamic ones (coach mark 7475–7477, hue bar pointer capture 11501, pop dismiss 12112, zoom-wrap scroll 6574 on a node that is replaced, `once` at 2728) each have a matching remove or die with their element. **Measured:** window 5 / document 39 / body 0 listeners before and after 65 renders, 10 model swaps, 10 gallery cycles; DOM 455 → 451 nodes.
- **Observers / timers.** `_fitIO` and `_qcIO` are `disconnect()`ed before re-creation (6299, 6328). The hue cycle (11541–11600) is a self-terminating `setTimeout` chain that checks element presence, `document.hidden`, an IntersectionObserver flag and reduced-motion every tick. rAF handles (`_isoRoomRaf`, `_topRaf`, `_hueRaf`, `_bb2HoverRaf`) are all single-slot and cleared on re-schedule. No `setInterval` in this file (the one `si:1` at boot comes from `engage.js`/`iso-render.js`).
- **Caches.** The only growable cache in the file is `_recCache` (single slot, replaced not appended). `_bbGalPrices` is bounded to `{S,E}`. The image preload in `layout-render.js:3692` creates `Image` objects but keeps no references (browser cache only).
- **Fetch handling.** `/api/booth-price` (7788) uses a sequence guard so late responses cannot overwrite a newer design; `/api/booth-request` (8424) surfaces `d.error` via `toast` → `textContent` (safe); `/api/booth-price/catalog` (4770) is fire-and-forget with a busy flag; `/api/booth-layouts` failure produces the visible "Failed to load" page. Only the `?d=` restore (F3) fails silently.
- **Empty catches.** 20 `catch (e) {}`; every one I read wraps `focus()`, `localStorage`, `matchMedia`, `setPointerCapture`, or an optional cosmetic step — appropriate. The two that hide real failures are the boot "fall through" pair (13573, 13585) covered in F3/F1.
- **XSS sinks.** 31 `innerHTML`/`outerHTML` writes; every dynamic value I traced is `esc()`ed (`state.room[*]` at 5645/5647, pack ids through the `/^[A-Za-z0-9 \/.-]*$/` gate at 2938 then `esc(w.slot.id)`, `_lbl`/`_pg` at 13654, `e.message` at 13695). `?page=` is constrained to a leading `/`, ≤200 chars, no `<>"'\` or whitespace, and `//evil.example` yields `https://www.whisperroom.com//evil.example/x` — still on-host. `?src=` is mapped to a closed vocabulary. `Object.assign(state.room, d.rm)` (3001) accepts arbitrary keys/types from a link (they persist into share links and the quote POST) but every read goes through `parseFloat` or `esc`, and `__proto__` via `Object.assign` only re-parents `state.room`, not `Object.prototype`. Verified inert: `a: {N0: 'STDWL46 "><img onerror>'}`, `rm.cFt: '<img onerror>'`, `product=<img onerror>`, `page=/foo" onmouseover=`, `src=<script>`.
- **Entry-path ordering** at 13554 behaves as documented; cold, `#d=`, `?start=room` each render once.

## 3. Not checked / limits

- Timing and heap numbers are Lane A's; I counted calls, not milliseconds.
- `iso-render.js` (428 KB) and `iso30-manifest.js` (344 KB) were only grepped for caches (`new Image` at 3912, no growing map found) — not audited.
- Flag-OFF (legacy) code paths were not executed; findings above are for the production flag set (BB2 + angled ON, price/dark/art2 OFF).
- `/api/booth-price` and `/api/booth-request` were not exercised (stub returns 404); their handlers were read only.
- F4 is derived from reading, not reproduced.

===REPORT===
Findings: 8 (3 MEDIUM — F1 prototype-key page kill via URL, F2 quadruple render on `?product=`/package entry, F3 silent default booth on a failed share link; 3 LOW; 2 INFO on composition and pattern divergence). No XSS, no leak.
Reviewed: `booth-builder.html` render/rebuild/boot/restore/fetch/listener/timer paths and all `innerHTML` sinks; `layout-render.js` for `esc`; `quote-server.js` for the flag rewrite, gzip, and the `/api/booth-design` handlers. Instrumented run: `probe.js` → `probe-out.json` (this folder), desktop 1440×900 and phone 390×844, BB2 + angled ON.
Blockers: none.
