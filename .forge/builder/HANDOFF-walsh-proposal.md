# Builder handoff: Walsh Construction booth-renderings proposal (12 Oct 2026)

`HANDOFF.md` in this folder is the CCU Sands Hall handoff and was left in place.

## Produced
- `C:\Users\bento\Desktop\ProposalFiles\Walsh Construction\Walsh Construction-Booth-Renderings.pdf`:
  9 pages, US Letter portrait, 3,332,279 bytes, plates 1-9 in Benton's export order (plate 1 is the cover hero).
- Config and web plates in the PRIVATE proposals repo, not committed:
  `C:\Users\bento\OneDrive\Documents\Claude\WhisperRoom Proposals\examples\walsh-construction\proposal-v2.json`
  and `...\walsh-construction\renders-web\01..09-*.jpg`.
- Check rasters, prep and check scripts: session scratchpad `walsh-proposal\` (`check-final\` is the final set).

## Read-first
- Renders and the export tool's manifest: `Z:\Sketchup\Proposals\Walsh Construction Tech Lab MDL 96168 E\`.
- Generator: `proposals/build-v2.js`. Drawings were trimmed to a shared crop box per Ramp/Platform pair, so the two
  layouts print at the same scale. Renders are whole 1600x900.
- Dimension strings in the captions carry `\u00a0` so a callout never splits across a line.

## Assumptions
- The pack says "ramp layout" and "platform layout" with no option numbers, because `.forge/GOAL.md` numbered them
  the other way round (Option 1 = platform) before the scenes were renamed Ramp/Platform.
- Section 03 (ventilation and interior) is labelled as drawn from the ramp-layout model. That matches the scene
  names and the manifest; whether the platform booth's interior is identical was not checked.
- No acoustic figure appears: no proposal boilerplate carries the ASTM E336 range.

## Open-questions
- Floor finish: not captioned. The V-Ray plates (1, 4) show a wood-plank room floor; the plain drawings show white.
- In both top-down plans the 14' 2" callout's extension lines sit about 20 px (about 10.7 in at plan scale) to one
  side of the booth body. The value is right (catalog length); the placement looks stale.
- Order conflicts with the playbook (kept Benton's order): the pack ends on interior renders, not the plan, and each
  layout's plan comes before the ventilation view.
- `proposals/examples/peoplesspace/proposal-v2.json` is a real client config tracked in this public repo.
