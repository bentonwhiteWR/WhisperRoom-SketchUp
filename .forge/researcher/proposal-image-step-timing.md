# Research — Where the proposal image step's 45 minutes actually went

2026-08-31, Researcher. Read-only; nothing built, nothing rendered, no file outside
`.forge/researcher/` touched. SketchUp is down (bridge heartbeat ~18 h stale), so the
export half was not exercised live; every path and machine-fact check below was run on
this machine today.

## Question

Benton, 31 Aug 2026: Gabe says an agent spent ~45 minutes on "just grab all the images
and put it in the proposal." Where did the time go, and what would cut it? Diagnose only.

## Answer, short version

**The 45 minutes is not a lost agent wandering — it is roughly what the written
procedure costs when followed exactly, because the procedure makes the agent re-derive,
by eye, per job, information the pipeline already has in machine form.** Reconstructing
the budget from the playbook's own mandatory steps (the actual run left no log in this
repo — see §1), a 6–12-plate pack demands on the order of **40–60 separate image
inspections**: a full build-print-rasterize-inspect of the reference pack *before the
client job even starts*, a 300–700 dpi crop-and-transcribe pass over every render for
captions, and a rasterize-every-page-plus-every-bottom-edge verification pass at the
end. Each inspection is an agent vision read plus reasoning; none of it is scripted.

Two aggravators sit on top of that, both verified today:

1. **The docs' reference materials do not exist on this machine.** The playbook's step 1
   — "open the newest shipped pack" — points at
   `C:\Users\bento\Desktop\ProposalFiles\PeoplesSpace\PeoplesSpace-Booth-Renderings.pdf`;
   that folder holds only `PartArt` (observed). CLAUDE.md's path table points at
   `WhisperRoom Proposals\build-v2.js` and prior client configs there — the folder holds
   only the superseded v1 system (observed). Every "copy the newest example / start
   warm" instruction dead-ends; the only reachable example is the sanitized
   `proposals/examples/example-client/`.
2. **If any V-Ray rendering happened inside the 45 minutes, that alone could be most of
   it** — the parked look-dev mission records ~6 minutes a frame
   (`.forge/GOAL-prev-render-lookdev.md:30`), and the 28 Aug Elangovan pack's renders
   were made *manually* because the render lane was not trusted (`DEVLOG.md:1265`).
   Whether the 31 Aug job included rendering is an open question — no session log
   exists in this repo (see §1).

The caption/verification discipline itself should not be weakened — but most of its
*inputs* (dimension text, scene identity, plate order) exist as data inside SketchUp at
export time and are currently thrown away, leaving the agent to read them back off
pixels. That is the structural fix. Ranked proposals in §5.

---

## 1. Evidence of the actual run: there is none in this repo

- `git log` for 31 Aug 2026 contains only deck-orientation, ceiling-light, and
  Proposal-Package-window work (commits `fa373e4`…`722992c`, observed). No proposal
  build, no client folder, no config was committed.
- The 31 Aug `DEVLOG.md` entry (lines 3–105, read in full) never mentions a proposal
  PDF, a client pack, or an image-assembly session.
- `clients/` holds only `bohn-music-academy` and `uthsc-audiology` (observed).
- `C:\Users\bento\Desktop\ProposalFiles\` on this machine holds **only `PartArt`**
  (dated Aug 6, observed). Yet the DEVLOG claims deliveries to that same path for
  CSUSB (`DEVLOG.md:5031`), Bohn (`DEVLOG.md:5139`), and Saravanan Elangovan
  (`DEVLOG.md:1261`). Either those packs were built on the *other* machine (the
  laptop — the `<CLAUDE>` split in `CLAUDE.md:31-44`) or the folders were cleaned.
  Either way the machine split makes prior proposal work invisible here — the exact
  failure mode Benton's own memory note records.

So the 45-minute figure is **reported** (Gabe → Benton → GOAL.md:11) and cannot be
decomposed from a log. Everything in §3 is **derived** from the procedure the agent
was following, which is the next-best evidence and is labelled as such.

The nearest logged relative: the Elangovan/UTHSC 4-booth pack shipped 28 Aug — 17
pages, 12 scenes (5 render / 7 image) — with renders made **manually** because the
render tool "was not trusted for the job" (`DEVLOG.md:1258-1266`, observed in the log).
That job is very likely the same *kind* of session Gabe is describing.

## 2. The real sequence, and what is actually automated

| Step | Who does it | Source |
|---|---|---|
| Place 5 proposal cameras / scenes | Script (`scripts/proposal-scenes.rb`) — but cameras are bad; see `.forge/researcher/proposal-scene-generation.md` D1–D4. In practice Benton/Gabe set scenes by hand | proposal-scene-generation.md (observed code) |
| Export scenes → PNG | Script (`scripts/proposal-package.rb`) writes `<Scene Name>.png` / `<Scene Name> render.png` into an operator-picked folder (`scripts/proposal-package.rb:5-8`). Image lane proven live 28 Aug; render lane fixed since but **unrun** (`scripts/proposal-package.rb:47-52`) | observed |
| V-Ray renders (when wanted) | Nominally the render lane; on the one shipped job, done **manually** (`DEVLOG.md:1265`). ~6 min/frame (`.forge/GOAL-prev-render-lookdev.md:30`) | observed/reported |
| Any manifest of what was exported | **Nobody.** `proposal-package.rb` and `export-scenes.rb` write bare PNGs — no sidecar (grep: only `export-component-art.rb:465` and `orbit-export.rb:226` write manifests, and those are the art-library exporters, not the proposal path) | observed |
| Find the images / the current folder | Agent, by hand, from whatever folder the operator names (SKILL.md:12-13); default export dir is `C:/Users/bento/Desktop/ProposalFiles` (`scripts/export-scenes.rb:44`) | observed |
| Flatten transparent PNGs onto white, trim, resize, JPEG | Agent writes throwaway Python per job (playbook §5, `reference/proposal-playbook.md:206-233`). No script in the repo does this | observed absence |
| Select/order/caption images | Agent. Order is mostly fixed by rule (playbook §4:169-200); captions require crop-and-zoom to 300–700 dpi per render and exact transcription (`reference/proposal-playbook.md:244-247`, `CLAUDE.md:219`) | observed |
| Author `proposal-v2.json` | Agent, copying an example (`skills/whisperroom-proposal/SKILL.md:27-28`) | observed |
| Build HTML | Script — `node proposals/build-v2.js` (seconds; prints a plate-fit table, playbook §7:262-266) | observed |
| Print PDF | Headless Chrome (playbook §7:270-283); Chrome "sometimes does not exit after writing the PDF" (`CLAUDE.md:210-211`) — a documented silent timeout cost | observed doc |
| Verify | Agent: PyMuPDF rasterize, **look at every page**, crop **every bottom edge**, re-check callouts at 300–400 dpi (playbook §8:288-306) | observed |
| Report invented lines | Agent (playbook §10:330-343) | observed |

The automated half ends at "PNGs in a folder." Everything from there to the PDF is
agent-by-hand, and the by-hand half is the half Gabe watched.

## 3. Reconstructed time budget (derived, labelled)

For a pack the size of the shipped ones (6–17 pages, 5–12 plates):

| Block | What the docs mandate | Est. minutes | Class |
|---|---|---|---|
| Required reading | playbook (391 ln) + SKILL (88) + brand (93) + CLAUDE.md sections + example config | 3–5 | specification |
| Reference-pack rebuild | "Build it, print it, look at it — that output IS the format" (`reference/proposal-playbook.md:37-42,65-66`; `CLAUDE.md:188-189`): node build + Chrome print + rasterize + inspect ~10 pages **before the client job starts** | 8–12 | specification |
| Path hunting | Step 1 "open the newest shipped pack" → path missing (§4); CLAUDE.md table → missing/superseded targets; three docs name three different config destinations (§4) | 5–10 | stale docs |
| Image prep | Per-job throwaway Python: flatten/trim/resize N images | 3–5 | missing script |
| Captions | 2–4 crop/zoom vision reads per render × 5–12 renders + drafting under the accuracy rules | 10–20 | judgment, but input re-derived from pixels |
| Build + print | node (seconds) + Chrome, possibly waiting out a hang (`CLAUDE.md:210-211`) | 1–4 | automated |
| Verification | rasterize all pages + per-page reads + bottom-edge crops + 300–400 dpi callout re-checks; rework loop if anything overflows | 6–12 | judgment/rework |
| **Total** | | **36–68** | |

45 minutes sits in the middle of that band **with zero rendering and nothing going
wrong**. This is the core finding: the time is mostly *specified*, not wasted. Each
"look at" in the docs is an agent vision call over a 2400×1366 PNG or a rasterized
page, and the docs mandate roughly 40–60 of them per job.

If the job also rendered: 5 frames × ~6 min ≈ 30 min on top (reported figure,
`.forge/GOAL-prev-render-lookdev.md:30`), which would make rendering the majority and
the instructions a minority. **Unknown which applies to the 31 Aug job** — no log.

## 4. Path audit — what resolves on this machine today (all observed)

| Documented path | Status |
|---|---|
| `C:\Users\bento\OneDrive\Documents\Claude\WhisperRoomQuote` (+ `models.json`, `tools\sketchup-scene-export`) | EXISTS |
| `C:\Users\bento\Documents\Claude` (laptop `<CLAUDE>`) | MISSING here (expected — this is the desktop) |
| `C:\Users\bento\OneDrive\Documents\Claude\WhisperRoom Proposals\` | EXISTS — but contains only the **v1** system: `build.js`, `examples\integrated-ent`, superseded `docs\PROPOSAL-GUIDELINES.md` |
| `...\WhisperRoom Proposals\build-v2.js` (CLAUDE.md:50 "Proposal generator") | **MISSING** — the real generator moved into this repo (`proposals/build-v2.js`); CLAUDE.md's table still points at the old home |
| `...\WhisperRoom Proposals\examples\<client>\proposal-v2.json` (CLAUDE.md:51 "copy the newest") | **MISSING** — no v2 config exists there; playbook §9:320 and §12:390 also direct output/reading there |
| `C:\Users\bento\Desktop\ProposalFiles\` | EXISTS — contains **only `PartArt`**; no PeoplesSpace, David Smith, CSUSB, Bohn, or Elangovan pack, though playbook §1:32-34 and DEVLOG deliveries name them |
| `C:\Users\bento\Desktop\WhisperRoom\WR Proposals and Drawings\` (CLAUDE.md:52) | **MISSING** (whole `Desktop\WhisperRoom\` folder absent) |
| `C:\Users\bento\Desktop\WhisperRoom\WhisperRoom - Brand Guideline.pdf` (CLAUDE.md:53) | **MISSING** |
| Local clone of private `whisperroom-proposals` repo (playbook §2:67-71, SKILL:22-24) | **MISSING** — searched `<CLAUDE>` trees, no clone |
| `P:\` share | EXISTS |

Consequence: **every warm-start artifact the docs promise is unreachable on this
machine.** The reference pack, the newest client config, and the shipped-pack archive
all resolve to nothing; the agent falls back to building the sanitized example and
authoring the config from scratch — which the playbook anticipates ("on any other
machine", line 36) but which converts the promised shortcut into the 8–12-minute
reference-rebuild block every single job.

The three current docs also name **three different destinations** for the new client
config: `WhisperRoom Proposals\examples\<slug>\` (playbook §9:320),
`proposals/examples/<client-slug>/` in this repo (SKILL:27-28), and the private
`whisperroom-proposals` repo (playbook §2:67-71). A fresh agent must stop and
reconcile them.

## 5. Machine facts — still true, plus one new one (all observed today)

- No `pdftoppm`/poppler — confirmed missing. PyMuPDF present (1.28.2).
- No `node_modules`/Puppeteer — confirmed. Node v24.14.1 and
  `C:\Program Files\Google\Chrome\Application\chrome.exe` present.
- Python stdout is cp1252 — confirmed.
- New, not yet written down: `import fitz` now emits a deprecation warning ("use
  `import pymupdf`") — harmless today, a future breakage.
- Chrome-not-exiting after `--print-to-pdf` remains documented (`CLAUDE.md:210-211`);
  each occurrence can burn a full tool timeout silently.

## 6. What would actually cut the time, ranked by minutes per effort

1. **Emit a manifest + dimension sidecar from `proposal-package.rb` at export time.**
   The script already knows the scene name, the export order, the file it wrote, which
   lane (image/render), and which dim tags were visible
   (`scripts/proposal-package.rb:5-8`, DIM_TAGS discipline per
   `.forge/researcher/proposal-scene-generation.md`). The model also holds every
   dimension callout as a `DimensionLinear` **text string** — the exact characters the
   agent currently reads back off pixels at 300–700 dpi. Export scene → dimension-text
   list into a `manifest.json` beside the PNGs (precedent already in the repo:
   `scripts/export-component-art.rb:465`, `scripts/orbit-export.rb:226`, and the
   `_dimensions.json` emitter built 26 Aug in `angled-component-art.rb` —
   `.forge/builder/HANDOFF-dimensions-export.md`). Captions then need only a spot-check
   against the render, not a full transcription pass. **Est. save 10–20 min/job;
   moderate Ruby effort.** (The caption *discipline* stays; only its input changes
   from pixels to data. This is a guess as to magnitude, well-grounded in §3's budget.)
2. **Kill the per-job reference-pack rebuild.** Commit the example pack's rendered
   output (PDF or page PNGs — it is sanitized, the repo is already its home) or cache
   it once per machine, and change "build it, print it, look at it" to "open
   `proposals/examples/example-client/reference-pack.pdf`". **Est. save 8–12 min/job;
   trivial effort.**
3. **Fix the path table.** CLAUDE.md:49-55 points at four dead or superseded targets
   (§4). Point the generator row at `proposals/build-v2.js`, drop or annotate the
   Desktop\WhisperRoom rows, and pick **one** destination for client configs across
   playbook §9, SKILL, and CLAUDE.md. **Est. save 5–10 min per fresh agent; trivial
   effort.** (This is the rewrite job the mission already anticipates — GOAL.md item 5.)
4. **A `prepare-renders` script** (flatten/trim/resize/rename per playbook §5) checked
   into `proposals/`, so the per-job throwaway Python stops being rewritten. **Est.
   save 3–5 min/job; small effort.**
5. **Scripted overflow pre-check in the verification pass.** `build-v2.js` already
   prints a plate-fit table; extending it (or a small PyMuPDF checker) to flag
   footer-past-page-bottom would let the human-eye pass concentrate on content rather
   than layout. **Est. save 3–6 min/job; small-moderate effort. Partly a guess** —
   the eye pass must remain for hero/mirroring/caption checks.
6. **If rendering was inside the 45 minutes**, none of the above touches it; that is
   the parked look-dev mission (~6 min/frame, `.forge/GOAL-prev-render-lookdev.md:30`)
   plus finishing the untrusted render lane (`scripts/proposal-package.rb:47-52`,
   `DEVLOG.md:1265`). Not an instructions problem.

Items 1–4 together plausibly take a clean job from ~45 min to ~15–20 min. The
verification and caption-judgment floor — the part that protects a real customer from
a wrong number — is maybe 10 minutes and should not be pushed below that.

## 7. What I would measure if SketchUp were up

- One timed end-to-end assembly run on the example images, logging wall-clock per
  block of §3's table — turning the derived budget into an observed one.
- Whether `proposal-package.rb`'s image lane + a manifest emitter round-trips scene
  dimension text correctly for one dimensioned scene.
- One render-lane row, to see whether "manual renders because the tool isn't trusted"
  is still the operative reality.

## Confidence & gaps

- Path audit, machine facts, absence of any 31 Aug run log, absence of manifests on
  the proposal path: **observed** today, cited above.
- The time budget in §3: **derived** from the mandated procedure; the 36–68 min band
  is an estimate, not a measurement. The actual 45-minute session is **reported**
  (Gabe via Benton) and I could not locate its transcript, machine, or client name.
- Whether the 45 minutes included V-Ray rendering: **unknown** — the single most
  important fact Benton could supply (ask Gabe: did the agent render, or were the
  images already on disk?).
- Minutes-saved figures in §6: labelled guesses grounded in §3; items 1–3 are the
  confident ones.
- The prior proposal packs may exist intact on the laptop: **assumed**, unverifiable
  from this machine.

===REPORT===
Produced: `.forge/researcher/proposal-image-step-timing.md` (this file),
`.forge/researcher/HANDOFF-proposal-speed.md`. Read-only run; no source touched,
nothing executed that builds a proposal. Blockers: the actual 45-min session left no
log here — whether it included rendering needs one question to Gabe.
