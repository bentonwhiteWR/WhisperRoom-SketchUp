# HANDOFF — Lane A (measured performance and memory), Booth Builder audit

## Produced
- `perf-desktop-mobile.md` — the report. Outcome first, then §0 conditions, §1 cold load (desktop + Pixel 5 / 4× CPU / 1.6 Mbps), §2 what the 930 KB costs, §3 asset weight incl. fetched-vs-drawn accounting, §4 per-interaction main-thread cost with profiler attribution, §5 memory (20-switch series + heap-snapshot retainer walk), §6 long tasks / forced layout, §7 ranked findings, §8 gaps.
- `out/desktop-smoke.json`, `out/desktop-np2.json` — desktop loads without profiler (headline desktop numbers). `out/desktop.json` — desktop with sampling profiler (attribution + heap snapshot `out/desktop-heap.heapsnapshot`).
- `out/mobile-np.json` — mobile ×2 loads + interactions + memory, no profiler (headline mobile numbers; heap snapshot `out/mobile-np-heap.heapsnapshot`). `out/mobile-prof.json` — mobile with profiler (attribution).
- `out/*-load-N.trace.json` — Chrome traces per load (40 MB each; can be opened in DevTools Performance panel).
- `rig/serve-perf.js` — read-only static server (port 8791) with the researcher rig's flag injection plus gzip on text types. `rig/perf.js` — the harness (`--profile desktop|mobile --runs N --out name [--no-profile] [--no-interactions] [--gpu]`). `rig/retainers.js` — heap-snapshot retainer walker for ArrayBuffer memory. `rig/run-*.log` — console logs of each run.
- Nothing written inside `WhisperRoomQuote`.

## Read-first
1. `perf-desktop-mobile.md` "Outcome" and §1.3 (the request-order table) — the whole mobile story is there.
2. §7 ranked findings — each names the file:line it indicts.
3. §8 gaps before quoting any number: interactions are single-sample; `--disable-gpu`; flags assumed ON.
4. If reproducing: start `node rig/serve-perf.js` with `PORT=8791`, then `PORT=8791 node rig/perf.js --profile mobile --runs 2 --out x --no-profile`. Do not run two harness instances at once — CPU numbers contaminate. Do not kill headless chrome processes by start time while a run is going (I did, and lost a chain).

## Assumptions
- Production has `topdown_art`, `angled_view` and `booth_builder2` flags ON (the researcher rig injects these; real values are in `kv_store` per host, unread). If BB2 is OFF the landing view is the floor plan and findings 1–3 move to the "Angled" tap.
- Lighthouse mobile preset (1.6 Mbps / 750 Kbps / 150 ms, 4× CPU) is a fair "phone on a mediocre connection". Pixel 5 emulation; the page caps canvas DPR at 2.
- Cache disabled = first visit. Production booth-art carries a day-long cache per a `quote-server.js` comment (reported, not observed), so returning visitors within 24 h skip most image cost.
- Software canvas (`--disable-gpu`) overstates `drawImage`/`putImageData` cost relative to a real phone GPU; typed-array scene-build cost is unaffected.
- Profiler-on numbers are inflated ~1.5–2× and were used only for attribution.
- The 20-switch memory loop called `bb2CommitModel` directly to bypass the migration-confirm sheet.

## Open-questions
- What is the real flag state per host (`kv_store.angled_view_enabled:<host>` etc.)? It decides whether the 48 s is the landing experience or a tap away.
- GPU-on run: how much of the 0.5–1.7 s per-gesture cost survives hardware canvas? (`--gpu` flag exists in `perf.js`; not run.)
- The 1.1–1.3 s of `requestAnimationFrame` callbacks during the 43 s mobile spinner — which loop is that (spinner? peek-lift? hue cycle?) and does it run on a phone's battery while nothing is visible? Belongs to the mobile-behaviour lane.
- Is the `preloadElevArt` warm still wanted at all on BB2, or only when the walk-around opens? Product call for Benton.
- Should `MASK_CACHE` be capped by bytes rather than six entries, given 143 MB resident on desktop?
- Real-device numbers: nothing here ran on a phone. A single field run on Benton's own phone against `sales.whisperroom.com` (DevTools remote, Network panel) would confirm or refute the 48 s in ten minutes.
