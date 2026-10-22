---
name: whisperroom-client-job
description: Run a whole WhisperRoom client booth-proposal job end to end, with as few questions as possible, the way the October 2026 jobs were run (Trout Lake rev 3, University of Tennessee, SJSU EEG Lab, Virsono Holmdel v1/v2, The Weather Company, UVic Library, KCUR Radio). Invoke when Benton or Gabe hands over a client job (a plan or room photos plus a quote link) and wants the photoreal V-Ray renders, dimensioned views and the finished PDF, or says "do the whole job", "client job", "run it like Holmdel". It is the conductor; it routes the room build to whisperroom-takeoff (dimensioned or marked-up plan) or whisperroom-photo-job (photos, no dimensions) and the PDF to whisperroom-proposal. Not for building only a room (use those skills directly), only a PDF from existing renders (use whisperroom-proposal), an acoustic treatment pack (use whisperroom-acoustic-package), or the catalog product renders (a separate project).
---

# WhisperRoom client job: intake to opened PDF

This packages the process as it was actually run on the October 2026 jobs. It adds
only what the sibling skills lack: the **autonomy posture**, the **realism floor** and
the **render recipe** (`reference/render-recipe.md`). Everything else points at the
skill or script that already does it. Write no new tools to run a job; copy the last
job's per-client script and job files and rename them.

Evidence base, newest first (all in this repo, read the HANDOFF of the closest match
before starting):
`.forge/builder/kcur-radio/HANDOFF.md` (22 Oct, two rooms x two options, a non-catalog 60126),
`.forge/builder/uvic-library/HANDOFF.md` (21 Oct, the v1 trial of this skill: 55 min, round-one realism),
`.forge/builder/weather-company/HANDOFF.md` (14 Oct, **the realism reference: round 3**),
`.forge/builder/holmdel/HANDOFF.md` (v1 7 Oct, v2 14 Oct),
`.forge/builder/sjsu-eeg-lab/HANDOFF.md`,
`.forge/builder/university-of-tennessee/HANDOFF.md` (5 Oct),
`.forge/builder/trout-lake-rev3/HANDOFF.md` (1 Oct).

## Paths: resolve once, never hard-code one person's

| Thing | Benton | Gabe |
|---|---|---|
| Repo `<REPO>` | `<CLAUDE>\Sketchup\` (laptop) or `<CLAUDE>\Sketchup\WhisperRoom-SketchUp\` (desktop), with `<CLAUDE>` resolved by the table in `CLAUDE.md` | `C:\Users\whisp\Desktop\2026 Claude Files\SketchUp\WhisperRoom-SketchUp\` |
| Working folder `<WORK>` (models, textures, renders, proposal build) | not yet observed; ask once | `C:\Users\whisp\Desktop\2026 Claude Files\SketchUp\ClientDrawings\` |
| Finished PDFs `<PF>` | `C:\Users\bento\Desktop\ProposalFiles\<Client>\` (CLAUDE.md) | `C:\Users\whisp\Desktop\ProposalFiles\<Client>\` (every October client job) |

Rule: check `%USERPROFILE%` first and use that person's column. Only when no path in
it exists, ask the operator once. Gabe also has an older `...\SketchUp\ProposalFiles\`
(Aug to Sep jobs and non-client comparisons), but client proposals no longer go there.

**Render lane: `<REPO>\render\`** (portable since 2026-10-22). `render.py` (V-Ray
frames), `plates.py` (SketchUp plates), `sky-fill.py` (03 sky to white),
`vray-render.rb` (the `WR_CMSRender` driver) and `vray-setrefl.rb` (reflection layers).
Each finds the repo from its own location; the output folder is always an argument
(`--out` / `--dir`, `<WORK>` from the table above). Proven on Gabe's machine against
the delivered KCUR frames; **Benton's machine is untested until he runs it**, so say so
on his first job. Per-client job files (`scripts/<client>-gabe.rb`, `jobs/*.rb`,
`prep.py`, `build.py`) stay per client. Needs: SketchUp 2026 with V-Ray for SketchUp
7.30.01, the WhisperRoom plugin with the bridge enabled, Python with numpy, Pillow and
PyMuPDF, Node and Chrome for the PDF.

## Autonomy posture (how these jobs ran nearly hands-off)

- **Ask only for real operator decisions**, all in ONE batched message, before any
  model work. On these jobs those were: placement when the room allows more than one
  sensible spot, door side or hinge when the link and the room disagree, **the link's
  desk wall (`ds`) when it conflicts with the room** (the link is authoritative: never
  move the desk on your own; UVic moved it from S1 to E0 unasked), the ceiling height
  when the client gave none, a missing or wrong quote link, and plan contradictions.
  Everything else is a labelled guess.
- **A guess is labelled where the client will see it.** `ASSUMED` in the fit report,
  `(est.)` on dimensions, a plan note such as WC's "Room dimensions estimated from
  your plan (est.). Please confirm on site, including ceiling height."
  (`NOTE_LINE` in `scripts/weather-company-alpharetta-gabe.rb`). Window heads and
  column positions are scaled from the plan.
- **Ceiling height, one rule** (Gabe confirmed, 22 Oct; it supersedes the repo CLAUDE.md's
  8'-0" house default): the client's figure if given.
  Otherwise 9'-0" for a commercial or institutional room with a drop ceiling, 8'-0" for
  a residential room. Always labelled `(est.)` and always in the intake question batch.
- **The realism floor holds on every first delivery** (`reference/render-recipe.md`
  section 0, reference WC round 3). **A speed request never lowers it**: it trims test
  renders and repeated lighting passes, never furniture or materials. Time target: 20 to
  30 minutes for a one-booth job (UVic v1 took 55).
- **Never re-ask what a handoff or memory note already settled.** Gabe's hand edits
  to a model are final. Never rebuild, re-import or call the client script's `run`
  on a room he has edited (memory: "never call WR_Trout202.run", "never call
  WR_UT.run"). Use the script's check stage (`fit`, `fit_report`) instead.
- **Back up before a scene-changing round** (dated `.skp` copy plus scene JSON; UT
  kept `<WORK>\university-of-tennessee-backups\`, KCUR `<WORK>\kcur-radio-backups\`).
- **Never overwrite a delivered file.** Rename the old PDF `-draft1`, `-draft2` or
  `-superseded` first. If a viewer has it locked (the rename fails "resource busy"),
  copy it to `-draft1`, check the copy byte for byte (`cmp`), write the new build as
  `-NEW.pdf`, and tell the operator to close the viewer and swap it in. Do not close
  his viewer (WC, KCUR). Replaced renders go to a `superseded-<why>\` folder.
- **One render job at a time.** Kill every render process and wait for
  `WR_CMSRender.poll['state']` to read idle before starting the next. A stale run
  sharing the V-Ray session made one KCUR frame a byte copy of another.
- **Finish by opening the PDF and its folder** for the operator (observed:
  `start "" "<pdf>"` then `explorer.exe /select,"<pdf>"`, or `Start-Process <pdf>`).
- **The close-out always lists**: every ASSUMED or estimated dimension, every
  invented line (a feature, finish or caption fact not in the plan, photos or quote),
  quote-link changes sales must make, and "copy the model to P:".

## The job, stage by stage

1. **Intake and orient.** Run `git pull --autostash`. Read the closest prior HANDOFF.
   Write the job's goal to `.forge/builder/<client>/GOAL.md`, never the repo's
   `.forge/GOAL.md` (that is Benton's live mission). Collect the plan or photos, the
   quote link(s) (`?d=<id>` or `#3=<hash>`), client name, booth model(s), and any
   finishes photo. Ask the batched questions above, then proceed.
2. **Room build: route, do not duplicate.** Dimensioned or hand-marked plan: use
   `whisperroom-takeoff` (`clients/<job>/takeoff.json` -> `takeoff.lock.json` +
   `takeoff.review.html` via `scripts/takeoff-check.py`). Photos with no dimensions:
   `whisperroom-photo-job`. The October jobs then drew the room in a per-client script
   `scripts/<client>-gabe.rb`, copied from the last job and renamed. Its header follows
   the client convention: `# @title <Client> / <Job>: <models> (<Author>)` and
   `# @tab client`. Stages, as in WC: `run` (room, finishes, furniture, notes, room dims;
   raises unless `model.path` matches the client), `booths!`, `ap!`, `fit_report`,
   `lights!`, `scenes!`. Textures go in `<WORK>\<client>-textures\`, furniture models in
   `<WORK>\<client>-furniture\`. Check syntax with `scripts/rbparse.py` (on Gabe's
   machine point it at SketchUp 2026; it defaults to 2024).
3. **Save the model locally first.** The bridge (`scripts/sketchup-bridge.py`, fence
   in `scripts/wr_tools/wr_bridge.rb`) refuses every write to `P:`, Desktop\ProposalFiles
   and WhisperRoomQuote, and `Model#save` with no path always raises. Save As to
   `<WORK>\<Client> - <models>.skp` with `--write-root <WORK>`, guarded so it refuses to
   overwrite (`.forge/builder/holmdel/jobs-v2/saveas.rb`). Later saves use
   `m.save(m.path)` (`.forge/builder/weather-company/jobs/rerun.rb`), again with
   `--write-root`. The operator copies the model to `P:\Sketchup\ClientDrawings\` by hand.
4. **Place the booth from the quote link.**
   - `?d=<id>`: fetch `GET https://sales.whisperroom.com/api/booth-design/<id>` and save it
     as `clients/<job>/design-<id>.json`.
   - `#3=<hash>` short link: load `scripts/booth-from-link.rb` first with
     `$wr_no_autorun = true` (the `WR_BoothLink` module does not exist until loaded), then
     `WR_BoothLink.v3_payload(WR_BoothLink.v3_hash(link))`. It raises `V3Refusal` by name on
     a mangled link and never decodes in part. Save `{source, link, payload}` as
     `clients/<job>/design-v3.json` (example: `.forge/builder/uvic-library/jobs/build-booth.rb`).
   - Either way, feed the payload unchanged to `WR_BoothLink.build_from_payload(payload, cfg)`.
     The client script's `booths!` places each booth once, guarded by an attribute.
   - Left and right door parts import geometrically identical, so the door is mirrored
     once about its slot centre to show the quoted hinge (Holmdel, UT, WC; SJSU's
     `RightWADoorWithRamp` needed none). Known importer gap: `ADA STDDRFRM` (wide-access
     door) has no mapping (WC). Audiology booths never get a roof vent.
   - **Wall spacing for vents** (Gabe, KCUR 22 Oct): rear-wall vent sets are 5 1/2" deep,
     so the booth stands 8" off the wall, leaving 2 1/2" from the vent sets to the wall.
     A roof-vent booth stands 2 1/2" off the wall.
   - **Exterior fan silencer (EFS)** (Gabe confirmed, 22 Oct): the 10" is open space
     measured from the back of the silencer to the wall, as WC did. So the booth wall
     stands the silencer's measured depth plus 10" off the wall. Never 10" from the booth
     shell (UVic's reading, which left the silencer 1" from the wall).
   - **Non-catalog size** (KCUR's 60126 = a 6084 E grown 42" in the middle): build the
     nearest catalog booth from the link, move everything past the mid seam out by the
     extra length, copy the seam parts to the new seam, then add each long side's panels
     (solid or vent to match the neighbours, ENH inner panel, foam), a light and one vent
     set per bay. The new bay's floor and ceiling are custom definitions sized to sit
     flush at both seams. Check every joint up close before rendering, and compare each
     new panel's bounds with its neighbours: KCUR's first middle back panels landed on
     top of the next bay's (a transform-order slip) and left the bay open. Guard each
     step with an attribute so it runs once.
   - Run `fit_report` and report the observed tightest clearances. A clearance within
     1/16" of its rule passes as "meets, within rounding" (UVic reported a ramp 0.025"
     short as a failure).
5. **Render prep.** Dress the room to the realism floor (`reference/render-recipe.md`
   section 0). Run the client script's `lights!` and `scenes!`, then the reflection job
   (`jobs/materials*.rb` -> `render/vray-setrefl.rb`) **after** every `run`, because `run`
   resets the materials. Details and every setting: `reference/render-recipe.md`.
6. **V-Ray renders** (01, 02 heroes; 03 overhead cutaway), with `render/render.py --out`, one
   job at a time; then `render/sky-fill.py` on each 03. Read the JSON exposure stats and look at every frame before moving on,
   including the white-surface cast check (recipe section 0).
7. **Dimensioned views** (04 plan, 04b booth-area plan, 05 elevation, 06 booth interior
   plan) as SketchUp plates with `render/plates.py --out`. Dark floor or foam under dimension
   text gets the lightened copy in these views only. Plans of a vent booth carry large,
   client-readable orange callouts (KCUR: `5 1/2" VENT SET DEPTH`, `2 1/2" VENT SET TO
   WALL`, `8" BOOTH TO WALL`; roof vents: `2 1/2" BOOTH TO WALL`, `3 ROOF VENT SETS`).
   **AUTO-SET plates** (`scripts/wr-autoset.rb`; UVic `jobs/autoset.rb`) need Benton's
   16 Oct fixups: the room's tag shown on the plates, the room note on the floor (3D floor
   text, never on the booth), any plate that shows only a blank wall fixed by hiding the
   occluder on that page only (UVic `plates-fix.rb`, `plates-fix2.rb`), and unused plates
   removed. `scenes!` deletes every page, AUTO-SET's included, so **re-run AUTO-SET and
   these fixups after any room or scene rebuild.**
8. **Package.** Everything goes in `<WORK>\<client>-renders\` (numbered PNGs, `raw\`
   for the linear V-Ray output and the unfilled 03). A new round gets a new folder
   (`-r2`, `-r3`, `-v2`) or, for a partial redo, a `superseded-<why>\` folder for the
   replaced files; keep the old ones. Multi-option jobs prefix each file (`R1A-03-...`).
9. **PDF via `whisperroom-proposal`.** The October build folder is
   `<WORK>\<client>-proposal\` holding `prep.py`, `proposal-v2.json`, and `build.py`,
   which runs `proposals/build-v2.js` **unmodified**, swaps its hard-coded em dash in plate
   titles for a middot, prints to PDF with headless Chrome, counts em dash / "soundproof"
   / "eliminat" in the text, renders every page to `check\`, and copies the PDF to `<PF>`.
   Look at every page and every bottom edge.
   - **Cover:** the close hero that shows the booth door, window and ramp; never the wide
     room shot.
   - **Two or more options** (UT 18 pages, KCUR 24): one section per option (`boothOf`
     "Room 1, Option A", `extra` naming the difference) with its own lead and plates, then
     a side-by-side comparison in the `pricing` block with no prices (size, ventilation,
     booth to wall, clearances, height, gap to ceiling). The cover callout says what
     differs between the options.
   - **Standard vs Enhanced:** when the client has not chosen, draw Enhanced and say so on
     the cover and under the comparison: "A Standard model is 2" shorter, and everything
     else is the same."
   - Size: 6 to 8 pages and 2 to 3 MB for one booth; KCUR's 24 pages at 1400 px q84 came
     to 4.9 MB.
10. **Open the PDF and its folder** (see posture).
11. **Close-out.** Update or write `.forge/builder/<client>/HANDOFF.md` (state, file
    paths, open items, never-call list). Put each open item on the Forge project map as a
    decision. Report to the operator: the PDF path, the assumptions and invented lines,
    the sales actions, "copy the model to P:", and a ready-to-send three-line cover email
    in brand voice, for example:
    "Hi <name>, attached are the renderings for your <model> in <room>.
    Dimensions marked (est.) come from your <plan or photos>, so please confirm them on site.
    Happy to adjust the layout or options, just reply here."

## Copy rules (client-facing text)

No "soundproof" (say sound isolation), no STC or other ratings, no prices, no em or en
dashes, "reduce" or "block" noise, never "eliminate". No left or right claims in
captions: they flip with the viewpoint, so name walls by compass or by feature.
Captions state only what the image and quote show; anything else is ASSUMED. When a
change alters a count (vent sets, panels), search every caption, the cover and the
comparison for the old number.

## Repo hygiene

Commit nothing without the operator's OK: the repo is Benton's and public, and client
renders must never land in `proposals/examples/`. Any change under `scripts/` needs a
`scripts/wr_tools/VERSION` bump plus `install-plugin.py` and a SketchUp restart, or
the other machine never sees it. A new client script is not visible to the other
person until it is committed and pushed.
