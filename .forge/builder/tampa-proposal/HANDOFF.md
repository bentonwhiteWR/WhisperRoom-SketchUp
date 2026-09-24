# Tampa proposal build — handoff (procedure notes only; no client material here)

## Produced
- PDF delivered to the Desktop ProposalFiles folder for this client (9 pages, US Letter portrait, 2.64 MB).
- Working files (config, renders-web JPEGs, HTML, check rasters) are in the session scratchpad:
  `C:\Users\bento\AppData\Local\Temp\claude\C--Users-bento-Documents-Claude-Sketchup\a8873de2-e680-4990-9b55-aad73bb1817f\scratchpad\tampa-proposal\`
  Deliberately NOT under proposals/examples/ — this repo is public. Move the config + renders-web into the private
  whisperroom-proposals repo if a warm example is wanted.

## Read-first
- reference/proposal-playbook.md (procedure followed as written).
- Rebuild: `node proposals/build-v2.js <scratch>/proposal-v2.json <scratch>/tampa.html`, then headless Chrome --print-to-pdf.
  The client display name lives only in the config's `client` field; no other text field repeats it.

## Assumptions
- Image order = the operator's filename order (01 hero … 10 plan, 05 skipped); 02 is the same camera as the hero, but a plain dimensioned export.
- Exporter manifest.json only covered the last-exported plate (interior); the other plates were read by eye and the callouts zoomed.
- All source PNGs were already opaque (alpha 255 throughout); technical plates trimmed per playbook §5, the renders and the interior not trimmed.

## Open-questions
- Client display spelling (folder vs school name) — Benton's call.
- The exporter's preflight warning (31 items outside the room) was not reviewed in the model.
- The plan shows the open door leaf but no swing arc.
- The drawn booth height against the drawn room height — clearance not assessed.
