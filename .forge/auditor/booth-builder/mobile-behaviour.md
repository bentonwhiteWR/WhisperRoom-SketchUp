# Booth Builder — Lane C: mobile behaviour and real bugs on a phone (2026-09-02)

**Target:** `C:\Users\bento\Documents\Claude\WhisperRoomQuote\booth-builder.html` served by my
stub (`serve.js` here, a copy of the researcher rig plus FAIL / DROP / SLOW switches; BB2,
angled view and top-down art flags forced ON as production does). Driven with Puppeteer
21.11 through the touchscreen (`page.touchscreen.tap`, CDP touch events for swipe/pinch),
not by calling page functions. Devices emulated: iPhone SE 375×667, iPhone 14 Pro Max
430×932, Galaxy Fold cover 280×653, iPad Mini 768×1024, SE landscape 667×375, desktop
1440×900 with a width sweep to 480. Scripts: `drive.js` (flow / entries / rotate / fail /
desk), `probe2.js`, `probe3.js`, `probe4.js`. Logs: `log-<device>-<scenario>.txt`.
Screenshots: `mobile-shots/` (every one referenced below was looked at).

## Headline

The customer flow holds up on a phone. On 375 px, 430 px, 280 px and 768 px a customer
can land, pick a size from the gallery, switch all three views, open Customize, switch to
Enhanced, draw a room, and submit a quote request — every step through real taps, model
and view state verified after each (observed). No horizontal overflow at any width tested,
no page zoom, no history pollution (URL is written with `replaceState`; Back leaves the
page in one press — observed). Rotation to landscape raises the portrait gate; the
"use it sideways" escape now scrolls and keeps the nav reachable (observed, the fix for the
earlier F2 is in).

What is actually broken is the **failure states**: a customer on a bad connection can
lose their quote request into a permanent "Sending…" button, and a hung or failed API
shows either an infinite "Loading booth designer…" or a raw server error string with
nothing to tap. Those are the findings that cost leads. Everything else is polish.

## Findings, by severity

### C1 — HIGH · Quote request stuck on "Sending…" forever if the request never returns (observed)
`submitRequest()` at `booth-builder.html:8417` does `await fetch('/api/booth-request', …)`
with no timeout and no AbortController (`grep AbortController` → 0 hits in the file).
`state.sending = true` is set before the fetch and only cleared after it resolves.

Repro (iPhone SE, `probe2.js quotehang`): load `?product=MDL 7272 S`, make
`/api/booth-request` hang (a dropped mobile connection — I stubbed `fetch` to never
resolve), fill name + email, tap **Request my quote →**.
- t = 2 s / 10 s / 30 s: button reads **Sending…**, `disabled`, no toast, no message.
- Close the modal, tap **Quote** again: still **Sending…**, still disabled. The customer
  can never retry without a full reload, and nothing tells them to.
Screenshots: `mobile-shots/probe-quote-hang-30s.png`, `probe-quote-hang-reopen.png`.

A real phone on a flaky LTE link will hit this: the request is queued, the radio drops,
and the browser can wait minutes before `fetch` rejects (if it ever does). Direction: a
client-side timeout (AbortController, ~15 s) that resets `sending` and toasts "couldn't
send — try again", and a way out of the sending state on modal close.

### C2 — HIGH · API that never answers = "Loading booth designer…" forever (observed)
Boot (`:13514`) awaits `/api/booth-layouts` with no timeout. With the stub set to never
respond (DROP), the page still shows the loading shell at 15 s and at 20 s, no message,
no retry, no buttons in `#app` (0). Screenshot: `mobile-shots/probe-outage-hang-20s.png`.
This is exactly the state a customer in a lift or on a train sees; they have no way of
knowing whether to wait. Direction: same timeout idea plus a "still loading… / reload"
message after a few seconds.

### C3 — HIGH-MEDIUM · API 500 shows the server's raw error text and nothing else (observed)
With the layouts route returning 500, `#app` becomes `Failed to load: simulated outage`
(the `catch` at `:13696` prints `e.message`, which is the server's `error` field or
`HTTP 500`). Zero buttons or links on the page (`probe2.js outage` counted 0). A customer
sees a grey screen with a sentence and no reload affordance; the text is whatever the
server said, which in production could be a stack-ish message. Screenshot:
`mobile-shots/probe-outage-500.png`. Direction: a customer-worded message with a
**Reload** button, and never echo `e.message` to the customer.

### C4 — MEDIUM · Unrecognised `?product=` "fails loudly" for about one second (observed)
`:13637` opens the picker and toasts "We couldn't find that model — pick your booth
here." The toast is visible at 0.3 s and has `opacity:0` by 1.5 s (`probe4.js`). The
timer in `toast()` (`:10174`) is 2600 ms, so something later in boot clears it early —
observed fact is 1.5 s, the cause is not pinned down. Because it fires the instant the loading
shell is replaced, a phone user still looking at the loading text never sees it — the
entry screenshot taken ~1.5 s after ready (`se-entries-entry-product-bogus.png`) shows the
picker with no message at all, identical to a cold landing. So the "loud" failure the
v2.477.7 comment describes is, on a phone, silent. Direction: put the message in the
picker's own header while the product is unresolved, not in a toast.

### C5 — MEDIUM · Dimension callouts sit under the camera buttons (observed, 375 / 430 / 280)
- Floor plan: the overall-width dimension **7' 2"** is drawn exactly where the − / +
  zoom buttons float, so it reads as `7'  2"` with two circles over it
  (`se-flow-04-floorplan.png`). This is the plan the customer reads for "will it fit".
- Walk-around: the **6'-11"** height dimension runs under the left **‹** side chevron
  (`se-flow-05-walkaround.png`, chevron 40×64 at x≈40–80).
With a room drawn the plan is laid out taller and the width dimension clears the
buttons (`i14-flow-16b-room-floorplan.png`), so the collision is the no-room case only.
Direction: reserve the button lane below the drawing, or offset the dimension strings.

### C6 — LOW-MEDIUM · First-visit coach bubble overlays PEEK INSIDE and DIMENSIONS (observed)
After the first model pick, "Tap any wall to move it" sits at x 12–260, y 141–275 (SE),
covering half of PEEK INSIDE and reaching the DIMENSIONS toggle; on the 280 px Fold it
also covers the bottom of the view tabs (`fold-flow-03-picked.png`). I tested the
customer's most likely first tap — **Floor plan** — on both devices: the tap goes
through and the bubble dismisses (`probe-coach-*-after-tap.png`), so it does not trap.
Taps landing on the covered part of PEEK INSIDE hit the bubble instead (the bubble is a
fixed element above the stage). Cosmetic-to-minor.

### C7 — LOW · "Dimensions" / "Wall labels" toggles are 21 px tall (observed)
`label.bb-tog` measures 115×21 with 0 padding on every phone; a tap 14 px below the
text does nothing (`probe2.js dims`). They are the only sub-44 controls on the golden
path that the previous 44-px passes missed (everything else on the stage, sheet, nav
and quote form measured ≥44 — see "clean"). Also the gallery **✕** on the 280 px Fold is
30×44 and "Show the room" eye is 34×44.

### C8 — LOW · 280 px (Fold cover screen): popup and swatches spill 8–17 px (observed)
- Room popup `.sizepop` is 288 px wide in a 280 px viewport (left 8, right 296); the
  "Draw my room" button and the ceiling hint are clipped on the right
  (`probe-fold-roompop.png`).
- Customize sheet: foam swatch row reaches x = 297 (`probe-fold-sheet.png`); the sheet
  title truncates to "Customize Y…" and the booth card wraps "MDL / 7272 / S" one word
  per line. Nothing is unreachable; the flow completed. Niche device; flagged so it is
  a known state, not a surprise.

### C9 — LOW (data) · Every cold visit is logged as entry `hash`, never `fresh` (observed)
`dataLayer` / `wrEngage` `entry` for a bare visit, `?src=homepage`, `?room=10x12`
(without `start=room`) and `?d=` all came back `hash`, because boot's own render writes
`#d=` before the sniff at `:13675`. The code comment on `:13669` already admits this;
recording it here because the "Entry source" report is therefore wrong for the largest
bucket. `?src=` itself works (`from: homepage`, junk → `other`).

## Entry paths (iPhone SE, `drive.js se entries`, all observed)
| Link | Result |
|---|---|
| `?product=MDL 7272 S` | lands on 7272 S, steps size/quiet/color pre-marked, no picker |
| `?product=MDL 7272 E&acc=Caster Plate,Step,Office Desk,ADA Package` | casters, step, desk, wide door applied (HubSpot labels; `ada` false on 7272 by rule) |
| `?product=Unsure` | default booth, quiet, no picker (deliberate) |
| `?product=Bogus`, `?product=`, `?product=<script>` | default booth + picker + the 1-second toast (C4); no script execution, `esc()` holds |
| `?product=…&page=/sound-booths/mdl-7272` | "Starting from" bar with a whisperroom.com Back link |
| `…&page=javascript:alert(1)` | bar suppressed — good |
| `?d=nope` (404) / `?d=` | default booth + picker, no error surfaced |
| `#d=<garbage>`, `#d=%%%`, `#3=zzzz` | default booth + picker, no blank screen |
| `?start=room` / `&room=10x12` / `10x12x7` | picker with room strip; dims prefilled; ceiling honoured |
| `?start=room&room=abc` / `0x0` / `1e3x12` | ignored cleanly, strip still invites |
| `?room=10x12` alone | ignored — the door requires `start=room` (documented; the brief listed `?room=` as an entry path, it is not one on its own) |
No entry produced a blank screen or a page error (0 `pageerror` across all runs).

## Rotation (SE 375×667 → 667×375 → back, `drive.js se rotate`, observed)
Landscape raises the portrait gate (`gate:true`). After "Use it sideways anyway" the
document scrolls (scrollHeight 662 in a 375 viewport), the canvas is reachable, the
Customize / Room fit / Quote bar is sticky at the bottom (321–375), the sheet and the
quote modal both open and lay out without spill. Rotating back restores the portrait
frame (`r6-portrait-again.png`). No state lost.

## Gestures on the angled stage (SE, 430, observed)
One-finger swipe across the canvas: camera corner unchanged, page scroll unchanged — a
swipe does nothing, which matches the tap-to-rotate design (the four camera buttons are
the way to rotate). Pinch via CDP touch: `visualViewport.scale` stayed 1 — but headless
Chrome does not implement browser pinch-zoom, so **this is not evidence** either way about
iOS Safari, where the meta `maximum-scale=1` + `gesturestart` guards are the defence
(reported by the code, not verified here). Double-tap on the canvas: scale 1, nothing
selected. Prior audits already cover tap-slop and seal-deselect; not re-tested.

## Clean (checked, no finding)
- Horizontal overflow: none at 280 / 375 / 412 / 430 / 768 / 1024 / 1440 and the desktop
  sweep 1200→480, in every state (landing, booth, each view, sheet, room-fit, popup,
  quote modal). `documentElement.scrollWidth === innerWidth` throughout.
- Tap targets: all stage, sheet, nav, gallery and quote-form controls ≥44 px on phones
  (exceptions in C7/C8). Quote inputs are 16 px font (no iOS focus-zoom); room popup
  inputs are 12 px and rely on `maximum-scale=1` for the same (assumed, iOS not testable).
- Quote form happy path: name + email, submit → `/api/booth-request` POST received by the
  stub, "Request sent" screen, on every device.
- Slow API (7 s): loading text for 7 s then the normal landing; the page never painted a
  half state. Quote submit under a 7 s delay resolves normally.
- Room draw: 10 ft 14 in typed → normalised to 11' 2" and the verdict "✓ Fits · 3' 10" to
  spare" appears in the header and floor plan; the room survives view switches.
- Back button / history: `history.length` unchanged after eight option and view taps.
- Desktop 1440×900: pick, three views, Enhanced, Add-ons, room popup, quote modal all
  fine; no page errors. The 901–1023 band (known C5 in the UX audit) was not re-tested.
- Console: only the stub's 404 on `/api/engage` (my stub, not the page).

## Not checked / limits
- Real iOS Safari (pinch, focus-zoom, 100vh/dvh chrome collapse, keyboard pushing the
  room popup) — headless Chrome with an iPhone UA is not Safari. C1–C3 are engine-independent.
- Pricing flag OFF here (`__WR_BOOTH_PRICE_ENABLED__` not forced), so the nav price slot
  and price bubble were not exercised.
- The tap-slop / `pointercancel` findings from the Android audit are assumed still open.

===REPORT===
findings: 9 (C1–C9); highest severity HIGH (C1 quote stuck "Sending…", C2 infinite
loading on hung API). Reviewed: booth-builder.html driven headlessly on 6 device
profiles + desktop across cold flow, 22 entry-path cases, rotation, 3 failure modes;
code read for the boot, submit, toast, hash and form-intent paths. Blockers: none.
Real-Safari behaviour unverifiable on this rig.
