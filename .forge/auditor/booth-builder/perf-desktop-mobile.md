# Booth Builder — measured performance and memory, desktop and mobile

Lane A of the Booth Builder audit. Target: `C:\Users\bento\Documents\Claude\WhisperRoomQuote\booth-builder.html` (930,552 bytes) served with the same feature-flag injection as the researcher rig (top-down art, angled view, Booth Builder 2.0 all ON) plus gzip, from a read-only local server. Everything below was measured with Puppeteer 21.11 + Chrome DevTools Protocol, headless Chrome (`--disable-gpu`), browser cache disabled (a true first visit). Raw data: `.forge/auditor/booth-builder/out/*.json`, traces `*.trace.json`, heap snapshots `*.heapsnapshot`. Harness: `.forge/auditor/booth-builder/rig/perf.js`, server `rig/serve-perf.js`, retainer walker `rig/retainers.js`.

## Outcome

On a phone over a mediocre connection the booth does not appear until **~48 seconds** after tapping the link (Pixel 5 emulation, 4× CPU, 1.6 Mbps / 150 ms RTT; two runs, 48.3 s and 48.7 s). The shell paints at ~4.5–4.9 s and the customer then looks at a spinner for 43 s. The cause is not the 930 KB HTML (310 KB gzipped; parse+compile+eval is ~125 ms of main thread on desktop) — it is **9.18 MB / 136 requests of images on a cold load, of which 5.30 MB / 97 files (the walk-around art warmed by `preloadElevArt`, `layout-render.js:3667`) are never drawn on the landing view and are queued *ahead of* the 24 angled-view sprites the booth actually needs.** Second, the angled renderer (`assets/iso-render.js`) costs 0.5–2.5 s of main thread per interaction on the throttled phone profile (every option toggle, corner rotate, roof rung, room eye), all inside `go`/`draw`/`buildMasks`/`rasterIds`; nothing in `booth-builder.html` itself is expensive except one 224 ms (desktop) pixel-scan in `findIsoDoorRect`. Third, memory: JS heap is flat across 20 model switches (no leak, no detached nodes), but the renderer's `MASK_CACHE` holds **143 MB of off-heap ArrayBuffers on desktop (36 MB on the phone profile)** — bounded at six models, not growing, but invisible to `JSHeapUsedSize` and paid by every session that browses six booths.

===DETAIL===

## 0. Conditions, and what each number is

| Profile | Viewport / device | CPU | Network | Samples |
|---|---|---|---|---|
| **desktop** | 1440×900 @1× | none | localhost, gzip on text | load ×3 (`desktop-np2` ×2, `desktop-smoke` ×1, no profiler) + ×3 with sampling profiler (`desktop`, attribution only) |
| **mobile** | Pixel 5 emulation, 393×851 css @3× DPR (page caps canvas DPR at 2), Android UA, touch | **4× slowdown** (`Emulation.setCPUThrottlingRate`) | **Lighthouse mobile preset: 1.6 Mbps down / 750 Kbps up / 150 ms RTT** (`Network.emulateNetworkConditions`) | load ×2 (`mobile-np`, no profiler) + ×1 with profiler (`mobile-prof`, attribution only) |

Tags: **observed** = I ran it and read the number; **derived** = arithmetic on observed numbers; **reported** = a code comment or doc; **assumed** = not checked.

Caveats that apply to everything:
- `--disable-gpu` headless: Canvas 2D is software-rasterised. Real phones accelerate `drawImage`; the pure-JS typed-array loops (`rasterIds`, `buildMasks`) are unaffected. Treat `drawImage` self-time as an upper bound. I did not complete a GPU-on comparison run (it was in the chain I accidentally killed; see Gaps).
- Flags ON (tdArt / angled / bb2) is **assumed** to match production — it is what the researcher rig injects; the real values live in `kv_store` per host and I could not read them.
- Cache disabled = first visit. Production booth-art is served with a day-long cache (**reported**, `quote-server.js:14028` comment "day-long cache, like the booth art"), so a *returning* customer within 24 h skips most of §3. First visits are the ones that turn into quotes.
- Numbers taken with the sampling profiler on are inflated ~1.5–2× and are used only for *attribution* (which function), never for the headline figures.
- Interaction numbers are single-sample per profile unless stated.

## 1. Cold load

### 1.1 Desktop (observed, no profiler)

| Milestone | smoke run | np2 run 0 | np2 run 1 |
|---|---|---|---|
| TTFB / HTML fully received | 13 / 41 ms | — | — |
| DOMContentLoaded | 331 ms | 331 | 331 |
| First contentful paint | 348 ms | | |
| First app shell in `#app` (MutationObserver) | 462 ms | | |
| LCP (a `div.bb-fit-hint`, not the booth) | 888 ms | | |
| **First `drawImage` onto the on-screen angled canvas = booth visible** | **1,734 ms** | | |
| `waitDrawn` wall (harness) | 2,162 ms | 2,996 | 2,477 |
| Network idle (preloads finished) | 5,729 ms | 6,563 | 6,054 |
| Main-thread busy inside that span (trace `RunTask` sum) | 2,340 ms of 5,732 | | |

Long tasks during desktop load (trace, smoke run; **observed**):

| start | dur | what |
|---|---|---|
| 344 ms | **462 ms** | boot → `applyFormIntent` → `rebuild` → `render()`; includes a 55 ms forced synchronous layout at `render` :8210 and the first `sceneFor` (see §6) |
| 915 ms | **957 ms** | `EventDispatch` = sprite `onload` (`iso-render.js:3914`) → `go` :6620 → `draw` :3933; 24 × `Decode Image` inside |
| 1,883 ms | **224 ms** | `TimerFire` → `showDoorCoach` :7434 → `findIsoDoorRect` :7386 (§4.4) |

### 1.2 Mobile (observed, 2 runs, no profiler)

| Milestone | run 0 | run 1 |
|---|---|---|
| HTML `responseEnd` (310 KB gz at 1.6 Mbps) | 3,571 ms | 3,554 |
| DOMContentLoaded | 3,757 | 3,768 |
| First paint / FCP | 1,512 / 1,568 | 500 / 560 |
| First app shell in `#app` | 4,854 | 4,513 |
| LCP (a text `div`, not the booth) | 6,048 | 5,304 |
| **Booth visible (first on-screen canvas draw)** | **47,908** | **48,184** |
| Network idle | 51,819 | 52,240 |
| Main-thread busy in span (`RunTask` sum) | 12,951 ms | 13,277 |

Long tasks during mobile load (PerformanceObserver, run 0 / run 1; **observed**):
- **1,902 / 1,198 ms** at ~4.0 s — boot render. Inside: a single **246 ms forced synchronous layout** at `render` :8210 (run with profiler; 379 ms in run 0 without), stack `render:8210 ← rebuild:3716 ← applyFormIntent:4529 ← boot:13580`, plus `sceneFor` for the first scene.
- **3,085 / 3,533 ms** at ~45 s — the sprite `onload` → `go`/`draw` pass; Decode Image 150–165 ms per sprite inside it. This is the frame in which the booth finally appears, and the phone is frozen for the whole of it.
- Total main-thread time in `requestAnimationFrame` callbacks across the 52 s: 1.1–1.3 s (`FireAnimationFrame` ×2,341) — a rAF loop runs while the spinner shows (**observed**, `byName`; not attributed to a line — the mobile-behaviour lane should look at which loop).

### 1.3 Where the 48 s goes on mobile (derived from the run-0 trace `ResourceSendRequest`/`ResourceFinish`)

| group | n | first request sent | first finished | last finished |
|---|---|---|---|---|
| HTML | 1 | 0.20 s | 3.60 s | 3.60 s |
| JS (4 files, 322 KB gz) | 4 | 0.49 s | 0.80 s | 3.27 s |
| Google Fonts css + 2 woff2 | 3 | 0.24 / 1.50 s | | 2.90 s |
| `/api/booth-layouts`, `/api/booth-iso-geometry` | 2 | 3.74 s | 3.93 s | 3.96 s |
| **walk-around art `/assets/booth-art/*` (`preloadElevArt`)** | **97** | **3.95 s** | 5.93 s | **30.9 s** |
| **angled sprites `/assets/booth-art-iso30/*` (what the booth is drawn from)** | **24** | **5.91 s** | **32.5 s** | **45.0 s** |

The booth's own 24 sprites are enqueued 2 s *after* 97 files it will not draw, so with six connections per host they wait behind the entire preload. First angled sprite lands at 32.5 s; last at 45.0 s; render at 47.9 s. Without the preload the 2.94 MB of sprites alone is ~15 s at 1.6 Mbps (derived), so the floor for this design on this connection is roughly 20 s, and lower if the sprites were sized to the 742 px canvas (§3.3).

Indicting lines (**observed** in source):
- `booth-builder.html:13530` — `if (typeof preloadElevArt === 'function') preloadElevArt(state.model);` runs in `boot()` *before* the first `render()`, so the preload requests are queued before the angled sprites.
- `assets/layout-render.js:3667–3699` — `preloadElevArt` enumerates every `ELEV_ART`/`WDO_ART` file, all `SOLID_W` widths, 40/46 vent variants, doors, CP — 97 files on this model — and fires `new Image().src` for each. Its comment says it exists because "images are slow to load" on the *walk-around*; on BB2 the landing view is the angled canvas, which never reads this folder.
- `booth-builder.html:8848` (`bb2CommitModel`) — calls `preloadElevArt(m)` again on every model change (§3.4).

## 2. What the 930 KB HTML costs

Composition (**observed**, byte count by line range; the code lane reports the same split): style 202,796 B (lines 25–2510), markup 4,484 B, inline script 9,309 + 712,317 B (lines 2576–13698). Of the 712 KB main script, **338,903 B are `//` comment lines** and 27,943 B leading indentation. Wire size 310 KB gzip (241 KB brotli; production serves gzip only, **reported** from `sendCachedEntry`).

Main-thread cost of the script itself on desktop (**observed**, smoke trace, all threads):

| phase | ms | thread |
|---|---|---|
| `ParseHTML` (29 chunks) | 48.3 | main |
| `EvaluateScript` inline booth-builder (13 blocks) | 30.8 | main |
| `V8.CompileCode` 384 + `CompileScript` 26 + `ParseFunction` 358 + `CompileIgnition` 420 (lazy compiles during boot) | ~44 | main |
| `v8.parseOnBackground` iso-render 17.5 / layout-render 14.1 / iso30-manifest 11.0 / engage 0.5 + background compile 18 + wait 28 | ~90 | ThreadPool (off main) |

Total main-thread parse+compile+eval ≈ **125 ms desktop; ×4 ≈ 0.5 s on the phone profile** (derived; mobile trace shows `ParseHTML` 142–177 ms as a single long task at 3.6 s, **observed**). The external scripts stream-compile off the main thread. The `/api/booth-layouts` fetch is 66 KB raw / 2.7 KB gzipped, geometry 166 KB / 6.5 KB — trivial. **Verdict: the file's size is a bandwidth cost (1.6 s of the 3.6 s HTML arrival at 1.6 Mbps, derived) and a maintenance cost, not a CPU cost.** Stripping the 339 KB of comments would cut the gzipped HTML by an estimated 60–90 KB (assumed — comments compress well; not measured) — worth doing for phones, but it is a tenth of the image problem.

Parsed-but-unused on a cold visit: everything the walk-around and floor-plan views need (`layout-render.js`, 127 KB gz; the SVG elevation/plan code in the inline script) is evaluated even though the landing view is the canvas. Eval of `layout-render.js` is 0.4 ms (**observed**) because it is all function declarations; the cost is bytes, not time.

## 3. Asset weight

### 3.1 Cold load, both profiles (identical — the same requests; **observed**, `network.by`)

| class | requests | bytes |
|---|---|---|
| HTML | 1 | 310,325 (gz) |
| JS | 4 | 321,828 (gz) |
| Google Fonts (css + 2 woff2) | 3 | 73,209 |
| API JSON | 3 | 9,684 (gz) |
| **images** | **122** | **8,469,347** |
| other (engage beacon, favicon data URI) | 3 | 0 |
| **total** | **136** | **9,184,393** |

### 3.2 Which images, and whether they were displayed (**observed**: fetched set vs. every `drawImage` source and every `<img>`/`<image>` in the DOM after network idle)

| folder | fetched | bytes | drawn or in DOM |
|---|---|---|---|
| `/assets/booth-art/` (walk-around elevation art, `preloadElevArt`) | **97** | **5,296 KB** | **0 / 0 KB** |
| `/assets/booth-art-iso30/` (angled sprites) | 24 | 2,937 KB | 24 / 2,937 KB |
| `cdn.prod.website-files.com/...7272 S - 0.avif` (model photo) | 1 | 37 KB | 1 — a 1080×1080 image rendered at **62×48 css px** in the header pill, plus two hidden copies |

Largest single files on load (**observed**): `wall-46-vnt-iso30-intr.webp` 403 KB, `door-46-right-iso30-extl.webp` 359 KB, `wall-46-iso30-intl.webp` 281 KB, `wall-46-vnt-iso30-extr.webp` 278 KB, `wall-22-iso30-intr.webp` 202 KB, `foam-gray-iso30-intr.png` 159 KB (one of the 20 PNGs still in the iso30 folder; the other 1,188 are webp).

### 3.3 Resolution vs. display size (**observed**, drawImage natural → destination, on-screen canvas)

| sprite | natural | drawn at, desktop (1080² canvas) | drawn at, mobile (742² canvas) |
|---|---|---|---|
| `wall-46-vnt-iso30-intr.webp` (403 KB) | 693×1590 | 306×703 | **211×483** |
| `wall-22-iso30-intr.webp` | 338×1452 | 150×642 | 103×441 |
| `seal-mid-iso30-intr.webp` | 128×1369 | 57×605 | 39×416 |
| `floor-7248-iso30-intr.webp` | 771×413 | 681×367 | 468×252 |

On the phone the wall sprites are decoded at **3.3× linear / ~11× the pixel count** they are drawn at (derived). `buildScene` clamps scale at "sprite-native" (`iso-render.js:2293`) so this is by design for zoom, but the phone pays for it on every first paint: decode is 150–165 ms per sprite on the 4× profile (**observed**, `Decode Image` inside the 3.1–3.5 s long task).

### 3.4 Interaction-driven fetches (**observed**, requests attributed to each phase; bytes are what completed inside the settle window, so mobile bytes under-count)

| interaction | desktop requests / bytes | mobile requests |
|---|---|---|
| `setModel('MDL 96120')` | **105 / 6,349 KB** | 106–107 |
| `setModel('MDL 6084')` | 16–107 / 1.3–6.4 MB (varies with which run preceded it) | 16–17 |
| `setModel('MDL 4848')` | 3 / 106 KB | 3 |
| `setModel('MDL 7272')` | 9 / 430 KB | 55–58 |
| open gallery | 43 / 1,241 KB (43 Webflow thumbnails, 1080×1080 avif each, **observed** natural size of the one inspected) | 18–30 |
| `setOpt('vss', true)` | 2–3 / 668 KB | 2 |
| corner rotate | 6–7 / 552 KB | 6 |
| roof rung off | 2 / 664 KB | 2 |
| view top / view elev | 9 / 515 KB and 13 / 625 KB | 9 / 13 |

The 105 on 96120 is `bb2CommitModel` → `preloadElevArt(m)` (`booth-builder.html:8848`) re-firing the whole 97-file walk-around set plus 8 roof-mount sprites. With cache disabled that is a full re-download; in production the files carry a day-long cache (**reported**) so a warm browser serves them locally — but a customer whose first-ever action is "pick a bigger booth" on a cold cache eats another 6 MB. The gallery thumbnails are 1080² for tiles a few hundred px wide; the model pill uses the same 1080² photo at 62×48.

## 4. Interaction cost (main-thread)

`task_ms` = delta of CDP `Performance.getMetrics().TaskDuration` from just before the call to 1.5–4 s after (includes the async repaint chain); `long` = PerformanceObserver long-task durations in that window. No profiler. Single sample each.

### 4.1 Mobile (Pixel 5, 4× CPU) — **observed**, `mobile-np`

| interaction | task ms | long tasks ms | layouts | note |
|---|---|---|---|---|
| `setOpt('studioLight', true)` | **1,485** | **793** | 7 | `glowLayer` getImageData pass + full `draw` |
| `bb2SetRung(0)` roof back on | **1,685** | **1,375** | 7 | full `draw` + `bb2RunPeekLift` |
| `bb2ToggleRoomEye()` on | **904** | **548** | 15 | full scene rebuild (`sceneFor`→`buildMasks`→`rasterIds`) + 49 ms layout |
| corner rotate (`setIsoCorner`) | **953** | — | 3 | scene rebuild for the new corner |
| `setModel` ×4 | 455–925 | — | 2–5 | scene rebuild + `preloadElevArt` |
| `bb2SetRung(1)` roof off | 805 | — | 3 | |
| `setOpt('vss', true)` | 630 | — | 3 | rebuild (vent wall pack changes) |
| `setView('iso')` | 493 | — | 6 | |
| open gallery | 456 | — | **23** | 77 ms layout; 30 thumbnail requests |
| `setOpt('studioLight', false)` | 431 | — | 7 | |
| `setView('top')` | 258 | — | 2 | 76 ms layout (SVG floor plan) |
| `setView('elev')` | 254 | — | 2 | 48 ms layout |
| `setOpt('vss', false)` | 106 | — | 7 | |
| close gallery / room eye off | 66 / 29 | — | | |

With the profiler on (`mobile-prof`, inflated ~1.5×) the same gestures show 851 / 2,551 / 895 ms long tasks and `iso corner rotate` 751 ms — same ordering, confirming the attribution below.

### 4.2 Desktop (unthrottled) — **observed**, `desktop-np2`

| interaction | task ms | long tasks |
|---|---|---|
| `setOpt('vss', true)` | 776 | 429 |
| roof rung off | 774 | 404 |
| `setModel('MDL 96120')` | 732 | 332 |
| `setModel('MDL 6084')` | 527 | 192 |
| corner rotate | 496 | 170 |
| `setOpt('studioLight', true)` | 310 | — |
| roof rung on | 305 | — |
| `setModel('MDL 4848')` / `('MDL 7272')` | 301 / 209 | 111 / — |
| `setView('iso')` | 196 | — |
| room eye on / open gallery / view top | 69 / 69 / 60 | — |
| view elev / close gallery / room eye off | 20 / 3 / 11 | — |

Everything over 100 ms on the throttled profile is on the canvas path. The SVG views (`view top`, `view elev`) and the DOM-only gestures are cheap even on the phone.

### 4.3 Attribution (sampling profiler, inclusive ms; **observed** in `mobile-prof` / `desktop` — inflated, use ratios)

| gesture (mobile) | top inclusive frames |
|---|---|
| studioLight on | `go` :6620 1,800 → `draw` :3933 1,282 → native `drawImage` 460, `putImageData` 68, `glowLayer` :1601 48 |
| roof on | `go` 2,537 → `draw` 1,691 → `drawImage` 717; `bb2RunPeekLift` :13258 136 |
| room eye on | `go` 1,199 → `draw` 1,085; **`sceneFor` :3302 587 → `buildMasks` :3003 570 → `rasterIds` :1745 326**; `render` :7824 120 |
| corner rotate | `go` 731; `sceneFor` 556 → `buildMasks` 549 → `rasterIds` 311 |
| setModel 96120 | `sceneFor` 347 → `buildMasks` 318 → `rasterIds` 187; `render` 32 |
| vss on | `sceneFor` 463 → `buildMasks` 443 → `rasterIds` 254; `render` 32 |

Two distinct costs:
1. **Scene build** (`sceneFor` → `buildMasks` → `rasterIds`, `iso-render.js:3302 / 3003 / 1745`): a per-pixel z-buffer raster at `SS = 2` supersampling (`iso-render.js:649`) — four `w*h` typed arrays (`Int32Array`, `Float32Array`, `Int16Array`, `Float32Array` at :1747–1750, 14 bytes/px) filled and scanned. At desktop W=1080 that is 2160² = 4.67 Mpx × 14 B = **65 MB allocated and filled per scene build** (derived); mobile 1484² = 2.2 Mpx = 31 MB. It is cached per `model|corner|W|flags` key (`MASK_CACHE`, :106/:3397), which is why the *second* toggle of the same option is cheaper, but any change to the key — corner, roof, vent, room eye, model — rebuilds. 250–550 ms on the phone per build, pure JS.
2. **Composite** (`go` → `draw`, :6620 / :3933): 524 `drawImage` calls on load (168 from `<img>`, 356 canvas→canvas; **observed** `drawImageStats`), 43 Mpx of destination area on the mobile canvas, across 53 scratch canvases (33 of them full-size W×W). Native `drawImage` + `putImageData` dominate self time. This is the part `--disable-gpu` may overstate.

Every option toggle goes through `render()` → full `innerHTML` rebuild (DOM node delta swings ±600–700 nodes and ±100 listeners per gesture, **observed** `nodesDelta`/`listenersDelta`) *and* a full canvas repaint; the DOM half costs 15–120 ms on the phone (`render` :7824 self), the canvas half costs the rest. Partial repaint is the win, not partial DOM.

### 4.4 A cost that is entirely in `booth-builder.html`

`findIsoDoorRect` (:7383) walks the on-screen canvas on a 6-px grid and calls `stats.hitTest` (iso-render :6029) at every point — ~17,000 calls for a 782-px canvas — to find the door for the first-visit coach bubble. `hitTest` on a miss runs a radius-12 neighbourhood search (`for dy… for dx…` :6038). **224 ms on unthrottled desktop, ~530 ms inclusive with the profiler; on the 4× phone profile that is roughly 0.9 s (derived), fired from a `setTimeout` 900 ms after first paint, right when the customer first tries to touch the page.** The renderer already knows every part's screen-space polygon (`sc.parts[q]`); the rectangle could come from there instead of a pixel scan.

## 5. Memory

Twenty `bb2CommitModel` switches through ten models, `HeapProfiler.collectGarbage` twice before each sample, then a real heap snapshot (**observed**, both profiles).

| | desktop | mobile |
|---|---|---|
| `JSHeapUsedSize` after GC, sample 0 → 20 | 4.00 → 4.15 MB (max 4.24) | 4.09 → 4.32 MB (max 4.48) |
| DOM nodes | 812 → 833 (plateau by switch 8) | 1,067–2,506, fluctuates with the sheet, no trend |
| JS event listeners | 253 → 284 (plateau by switch 8) | 283–467, no trend |
| Detached DOM nodes in snapshot | **0** | **0** |
| `HTMLCanvasElement` created in session / still alive | 473 / **3** | 458 / **3** |
| snapshot: `system / JSArrayBufferData` | **280 buffers, 143.4 MB** | 280 buffers, 36.4 MB |

So: **no leak** — heap, nodes, listeners and canvases all plateau (the +31 listeners in the first eight switches is the gallery/sheet reaching steady state). The code lane's "no listener/DOM leak" holds under GC-forced measurement too.

But `JSHeapUsedSize` does not count ArrayBuffer backing stores. Retainer walk of the desktop snapshot (`rig/retainers.js`, **observed**):

```
17.8 MB ×6   <backing_store> ← ArrayBuffer ← Int32Array ← .idHi ← Object "MDL 7296 S|BR|1080"
             ← MASK_CACHE (closure scope of loadGeometry, iso-render.js:106)
 0.5 MB ×~120  … ← Uint8Array ← .cov / .bg ← masks[i] / masks2[i] ← "MDL 96120 S|BR|1080" ← MASK_CACHE
```

Each cached scene holds an `idHi` `Int32Array` of (2W)² = 18.66 MB at W=1080, plus per-part `cov`/`bg` `Uint8Array` masks of ~0.36–0.5 MB each (20–25 parts × 2). `MASK_MAX = 6` (`iso-render.js:108`) caps it, so it is **bounded at ~145 MB desktop / ~36 MB at the phone's W=742**, not monotonic — but it is resident for the life of the tab once six booths have been viewed, and it is off-heap, so nobody watching the JS heap would see it. The transient side is larger: each build allocates four more (2W)² arrays (~65 MB desktop) that are garbage a few hundred ms later (GC self-time 67–179 ms shows up in the profiles).

Not measured: renderer process RSS. I sampled `Get-Process chrome` working-set totals but the user's own Chrome was running, so the series is meaningless and I have dropped it.

## 6. Long tasks and layout thrash

Forced synchronous layouts during load (trace `Layout` events carrying a JS stack; **observed**):

| profile | count | total | dominant |
|---|---|---|---|
| desktop | 18 | 73 ms | `render` :8210 ×4 = 59.5 ms |
| mobile run 0 / run 1 / prof | 11 / 11 / 11 | 445 / 255 / 271 ms | **`render` :8210 ×4 = 438 / 251 / 271 ms** (one call of 246–380 ms), stack `render:8210 ← rebuild:3716 ← applyFormIntent:4529 ← boot:13580` |

`render()` writes the whole `#app` via `innerHTML` and then, at :8199–:8207, reads `.scrollTop`/queries and sets `minHeight`, `scrollTop` on the new tree — the first read after the write forces a full layout of the freshly built page. It happens four times in boot because `applyFormIntent` renders more than once (:4529, :4551, :4559 in the stacks). `bb2MonitorShift` :6657 (×5) and `fitStageToColumn` :7169 also force layout but at ≤1 ms each. No layout-in-a-loop was found; the thrash is one big forced layout per render, repeated per render.

Long tasks ≥ 50 ms, complete list on the mobile profile during load: 52–65 ms ×2 (initial parse/layout), 143–178 ms (`ParseHTML` of the 930 KB at 3.6 s), 75 ms (layout at 3.77 s), **1,198–1,910 ms** (boot render + first scene build at 4.0 s), 85–104 ms (~30 s), **3,085–3,619 ms** (sprite onload composite at 45 s). Per interaction, see §4.1.

## 7. Ranked findings

1. **[mobile, ~28 s of the 48 s]** `preloadElevArt` (`layout-render.js:3667`, called from `booth-builder.html:13530` in `boot()` and `:8848` in `bb2CommitModel`) fetches 97 walk-around files / 5.3 MB that the landing (angled) view never draws, queued *ahead* of the 24 sprites it does draw. Trigger: any cold load with BB2 on. Direction: don't warm the elevation set until the customer opens the walk-around (or warm it after the angled sprites, on `requestIdleCallback`, and only the widths the current model uses). **observed**.
2. **[mobile, ~15 s]** Angled sprites are 2.9 MB at sprite-native resolution and decoded at 3× the drawn size on a phone (`wall-46-vnt-iso30-intr.webp` 403 KB drawn at 211×483). Trigger: every first paint of each model/corner. Direction: a half-scale sprite set served when `maxPx` ≤ ~800; the largest four files are 45 % of the set. **observed**.
3. **[mobile, 0.5–1.7 s per gesture]** `iso-render.js` scene build (`sceneFor`/`buildMasks`/`rasterIds` :3302/:3003/:1745, 2× supersampled z-buffer, 14 B/px) plus full composite (`go`/`draw` :6620/:3933, 524 drawImage / 43 Mpx). Trigger: studio light, roof rung, room eye, corner, model, vent toggle — all measured 0.9–1.7 s task time with 0.5–1.4 s single long tasks on the 4× profile. Direction: SS=1 below a canvas size threshold; reuse the composite and redraw only the changed layer for light/roof; move the build to a worker/OffscreenCanvas. **observed**.
4. **[both, 224 ms desktop / ~0.9 s phone, once per first visit]** `findIsoDoorRect` (`booth-builder.html:7383`) pixel-scans the canvas via ~17k `hitTest` calls. Trigger: first visit, 900 ms after paint. Direction: read the door part's projected polygon from the scene. **observed** desktop, **derived** mobile.
5. **[both, 143 MB desktop / 36 MB phone, steady state]** `MASK_CACHE` (`iso-render.js:106`, `MASK_MAX = 6` :108) retains six (2W)² `Int32Array` id buffers plus per-part masks, off-heap. Not a leak; bounded. Trigger: view six model/corner combinations. Direction: cache only the compact `masks`, rebuild `idHi` on demand, or store it at 1× and cap by bytes not entries. **observed**.
6. **[mobile, 250–440 ms at boot; 60 ms desktop]** `render()` :8210 forces a synchronous layout after each `innerHTML` rebuild, ×4 during boot because `applyFormIntent` renders repeatedly. Direction: one render at the end of boot; batch the post-render reads. **observed**.
7. **[both, 6.3 MB on a cold cache]** `bb2CommitModel` re-runs the full preload on every model change (105 requests for 96120). Same fix as (1). **observed**.
8. **[both, 1.2 MB / 43 requests]** Gallery thumbnails and the header model pill use 1080×1080 Webflow AVIFs, the pill at 62×48 css px. Direction: request Webflow's resized variants. **observed**.
9. **[mobile, ~1.6 s of the 3.6 s HTML arrival]** 339 KB of the inline script is comment lines; gzip hides most of it but not all. Direction: strip at serve time in `sendCachedVariant`. **observed** size, **assumed** gzip saving.

## 8. Gaps — what I did not get

- **No GPU-on comparison.** The `--gpu` run was in a chain I killed by mistake and I did not re-run it. Canvas `drawImage`/`putImageData` self-times (a large share of §4) may be lower on real hardware; the typed-array scene-build times will not.
- **Interaction figures are single-sample** (one per profile, plus one profiled sample that agrees in ordering). Model-switch bytes on mobile under-count because downloads outlast the settle window.
- **Production flag state assumed** (tdArt/angled/bb2 ON). If BB2 is off in production the landing view is the floor plan and findings 1–3 shrink to the moment the customer taps "Angled".
- **Renderer RSS not measured** (contaminated by the user's own Chrome). The off-heap figure comes from the heap snapshot's ArrayBuffer backing stores, which excludes canvas backing stores — 3 live canvases at the end, so small, but the 53 scratch canvases during a paint (43 Mpx desktop ≈ 170 MB RGBA transient, derived) were not measured as memory.
- **Localhost server**: no TLS, no CDN, no real DNS; production TTFB and the Google Fonts round trips would add to every mobile figure, not subtract.
- The 20-switch series used `bb2CommitModel` directly (bypassing the migration-confirm sheet) so the switches would actually happen; the `setModel` interactions used the public entry.

===REPORT===
- Findings: 9, highest severity: a phone on a 1.6 Mbps / 150 ms connection sees the booth at ~48 s (2 runs), ~28 s of it attributable to `preloadElevArt` fetching 97 undrawn walk-around files ahead of the 24 sprites the landing view needs, ~15 s to the sprites' own 2.9 MB at 3× the drawn resolution; per-gesture main-thread cost 0.5–1.7 s on the 4× CPU profile, all in `assets/iso-render.js`.
- Reviewed: cold load ×3 desktop / ×2 mobile without profiler, ×3 / ×1 with sampling profiler; 18 interactions per profile; 20-model-switch heap series with forced GC and a heap snapshot with retainer walk, both profiles; trace-level long-task and forced-layout extraction; byte composition of the HTML; fetched-vs-drawn image accounting.
- Memory: JS heap flat (4.0→4.2 MB), 0 detached nodes, 3 of ~470 canvases alive — no leak; 143 MB (desktop) / 36 MB (mobile) of bounded off-heap ArrayBuffers in `MASK_CACHE`.
- Blockers: none for the report. Not done: GPU-on run; renderer RSS; verification of production flag state.
- Files: report `C:\Users\bento\Documents\Claude\Sketchup\.forge\auditor\booth-builder\perf-desktop-mobile.md`; data `...\out\{desktop-smoke,desktop,desktop-np2,mobile-np,mobile-prof}.json`, `*-heap.heapsnapshot`, `*.trace.json`; rig `...\rig\{perf.js,serve-perf.js,retainers.js}`. Nothing was written inside `WhisperRoomQuote`.
