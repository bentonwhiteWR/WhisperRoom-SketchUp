---
name: whisperroom-proposal
description: Build a client-facing WhisperRoom booth-renderings proposal PDF from a folder of SketchUp renders. Invoke when Benton says "make a proposal", "new client proposal", "another version of the proposal", names a folder under Desktop\ProposalFiles, or asks to swap the photos in an existing pack. Covers the generator, the caption-accuracy discipline, and the verification pass.
---

# WhisperRoom booth-renderings proposal

**Full procedure: `reference/proposal-playbook.md` in this repo. Read it first —
this skill is the short form of the same thing.**

The operator names a FOLDER OF RENDERS and a client — read the renders from whatever
folder is given; the deliverable is a print-ready
PDF he forwards to a real customer. Accuracy matters more than speed — these go out
under WhisperRoom's name, and a caption that contradicts the drawing is worse than no
caption.

## Use the existing generator. Never invent a layout.

- Generator: `proposals/build-v2.js` **in the WhisperRoom-SketchUp repo**. Needs Node;
  no `npm install`. It reads its CSS and wordmark from `proposals/assets/`.
- Worked example: `proposals/examples/example-client/proposal-v2.json`. Copy its shape.
  On Benton's machine the shipped client packs are also in the private
  `whisperroom-proposals` repo (branch `master`); you do not need them.
- The `-v2` in those filenames is the *generator format* version, not a proposal
  version. Do not put "V2" in a client-facing filename unless it really is a revision.

Author a new `proposal-v2.json` for the client, save it under `proposals/examples/<client-slug>/`
(with a `renders-web\` copy of the images) so the next job starts warm, and build.

## Machine facts — reuse these, don't rediscover them

- **No poppler / pdftoppm.** Rasterize PDFs for checking with **PyMuPDF (`fitz`)**.
- **Puppeteer is not installed locally** (no `node_modules` in the repo clone).
  Print with **headless Chrome**.
- Python stdout is cp1252 — `sys.stdout.reconfigure(encoding='utf-8', errors='replace')`
  before printing extracted PDF text, or dimension marks (′ ″) crash the script.

## Image order

Benton usually specifies the hero and sometimes the second image; the rest is your
call. The established slot order is: **hero render → dimensioned view → side →
rear/ventilation → top-down plan** — walk around the booth, end on the plan. Say why
you ordered them as you did.

## Caption discipline — this is where the real risk is

- **Read each render's geometry and callouts. Write only what the image shows.**
  A draft once told a client their work surface was on the "right-hand wall" when the
  new renders were mirrored. **Avoid left/right spatial claims entirely** unless the
  drawing makes them unambiguous.
- **Transcribe dimension callouts exactly.** If one is cut off or unreadable, leave it
  out of the text — never round, guess, or infer what it measures. If a number is
  visible but unlabeled, you may cite it "as drawn" without saying what it measures.
- **Never state a model number, dimension, price, or acoustic claim you cannot source
  from the renders or the boilerplate.** On acoustics the only defensible
  customer-facing figure is the website's **ASTM E336 dB range — never STC, never the
  word "soundproof."**
- **Cross-check the product name.** Benton reports it; the renders usually carry a
  legible label. If they disagree, trust the renders and flag it.
- **Individual vs organization.** Copy written for a clinic reads wrong for a person.
  Check the client name before reusing an example's boilerplate.

## Verify before declaring done

Rasterize the finished PDF back to PNG and **look at every page**, including a crop of
every **bottom edge** — a headline that wraps to three lines against a two-line budget
silently pushes the footer off the page, and a pass that only checks the middle of each
page will miss it. Confirm the hero is the right image, nothing is stretched or cropped
wrong, no text overflows, and the page count matches the comparable prior pack.

Keep output in the 2.5–3.6 MB range. Downsample only if well past, never at visible
cost to print quality.

## Output

- PDF → on Benton's machine, `C:\Users\bento\Desktop\ProposalFiles\<Client>\`.
  On any other machine, a `ProposalFiles/<Client>/` folder wherever the operator says.
  Named `<Client>-Booth-Renderings.pdf`. Do **not** overwrite or delete anything already
  in that folder unless the operator says to override in place.
- Working files (HTML, check rasters) stay in the scratchpad, never on the Desktop.
- Do **not** touch the `WhisperRoomQuote` git repo. This is filesystem-only work.

## Always report

**Every line you invented.** You have images and a client name — no quote, no spec
sheet. Anything not readable from a render or lifted verbatim from the boilerplate goes
in an explicit list for Benton to check before it goes out. Include what you chose *not*
to mention because you couldn't identify it.
