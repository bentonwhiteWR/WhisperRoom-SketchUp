# Drawing rooms in SketchUp

The pipeline this workspace exists to serve:

```
client floor plan (PDF)  →  take-off        (reference/scale-estimation.md)
                         →  SketchUp model  (this file)
                         →  renders
                         →  proposal PDF    (reference/proposal-brand.md)
```

The dimensioned view in a WhisperRoom proposal is a **SketchUp export carrying SketchUp
dimension entities**. So the model and the proposal are the same pipeline — get the model
right and that plate comes almost free.

Working example: `scripts/csusb-rooms.rb`.

---

## Running a script

Benton runs these himself; I can't drive SketchUp.

1. **Extensions → Developer → Ruby Console.** (It moved there in SketchUp 2018 — it is *not*
   under Window any more.)
2. Paste one line and press Enter:
   ```
   load "C:/Users/bento/Documents/Claude/Sketchup/scripts/<name>.rb"
   ```
3. Ctrl+Z first if re-running — `load` re-reads the file, but a second run adds a second copy.

- **Forward slashes in the path.** Backslashes are Ruby escape characters and the load fails.
- **Never tell him to drop an auto-running script in the Plugins folder** — it would rebuild
  on every launch. `load` is the right mechanism.
- SketchUp 2023 and 2024 are installed. Plugins folders exist at
  `%APPDATA%\SketchUp\SketchUp <year>\SketchUp\Plugins\`.
- There is **no Ruby interpreter on this machine outside SketchUp**, so I cannot run or
  syntax-check anything I write. Say so, and wrap the build in a rescue that prints one
  `FAILED:` line rather than leaving a half-built model.

---

## Model standards

| Thing | Standard |
|---|---|
| Units | **Imperial**, Architectural. Set it in the script: `model.options["UnitsOptions"]["LengthFormat"] = Length::Architectural` |
| Internal unit | inches — SketchUp's native unit, and every catalog dimension is inches |
| Ceiling | **8'-0" default** unless the client states otherwise. Label it as the house default and keep asking for the real number |
| Wall thickness | 5" reads true on most plans; Benton usually draws 4". Cosmetic either way — see below |
| Undo | one `model.start_operation(name, true)` / `commit_operation` so Ctrl+Z reverses the whole build |
| Tags | everything on `WR-*` tags (`WR-Room`, `WR-Floor`, `WR-Doors`, `WR-Booth`, `WR-Notes`) so pieces switch off for a render |

### Default materials

Names are from SketchUp's built-in **Colors-Named** collection, so load the real `.skm`
rather than a look-alike; fall back to an identically-named colour if the file isn't found.

| Element | Material | RGB fallback |
|---|---|---|
| Floor | `0128_White` | 255, 255, 255 |
| Walls | `0099_LightSteelBlue` | 176, 196, 222 |
| Door leaf | `0043_SaddleBrown` | 139, 69, 19 |

White floor is deliberate — dimensions read against it.

Library lives at
`C:\ProgramData\SketchUp\SketchUp <year>\SketchUp\Materials\Colors-Named\`.

---

## Geometry rules

- **The measured interior polygon is the truth.** Everything else is drawn relative to it.
- **Build walls outward from that polygon**, never inward. Wall thickness then stays cosmetic
  and changing it never moves a dimension I have reported to a client.
- **Mitre the outer corners.** Compute the outer polygon by intersecting adjacent offset
  edges. Do not extend each wall by its thickness at both ends — that makes walls cross and
  overshoot into an X at every corner.
- **Doors are real openings**, not marks on the floor: split the wall around the opening,
  put a header over it, draw the leaf open 90° on the correct hinge side, and add the swing
  arc. Default leaf height 6'-8" unless the drawings say otherwise.
- **Curved walls** get traced as a polyline off the inner face, with a note on how faithful
  the trace is. Never fake a radius.

---

## Dimensioning

Same standard as the artifacts — **every in-line wall run, on all four sides.** A model with
dimensions on two sides is half-finished; that has already come back once.

- Chain each side, and add the overall outside the chain.
- **Dimension every door off its wall corner**: corner → near jamb, then the opening width.
  This is how a booth actually gets placed against a wall, so it is not optional.
- Chains must close on the overall. If one doesn't, a wall face was misread.
- A chain line means **segment lengths, never running totals**. Use a separate ordinate
  dimension for distance from a datum.
- Curved walls have no single in-line dimension — run a depth datum down one side and give
  the clear width at each depth.
- Let SketchUp report full precision (`51' 3 15/16"`). I round to the nearest inch in prose;
  the model stays honest about what the drawing said. Don't "tidy" the model to round numbers.

---

## Traps that have already cost time

- **Polygon winding.** Which side is "outside" cannot be hard-coded. Two rooms in the same
  script wound in opposite directions, and the hard-coded normal built one room's walls
  *inward*, quietly eating 5" off every interior face. Compute the signed area and derive the
  normal from it.
- **Back faces.** A floor face created from a polygon may point down and render as SketchUp's
  default blue. `face.reverse! if face.normal.z < 0` before painting.
- **Centre vs corner.** A column stored as a centre point but used as a rectangle corner is
  off by half its width in both axes. Store what you use.
- **Group materials.** Painting a group paints faces carrying the default material — easier
  and cleaner than painting faces individually.

---

## Getting images out — the scene exporter

`C:\Users\bento\Documents\Claude\WhisperRoomQuote\tools\sketchup-scene-export\`

Batch-exports **every scene in the model to one PNG named after the scene**. Use it instead
of hand-cranking File > Export > 2D Graphic per view.

Two ways in:

- **Installed** — Extension Manager > Install Extension > `wr_scene_export.rbz`. Adds
  **File > Export All Scenes as PNGs…**; prompts for folder, width, anti-alias, transparency,
  overwrite, and remembers folder + width between runs.
- **One-shot** — edit the constants at the top of `quick-export.rb` and paste it into the
  Ruby Console. Same logic, no install.

What it takes care of: transitions forced to 0 so `write_image` can't catch a mid-tween
frame; ground/horizon/fog re-killed *after* each scene switch (a scene can restore its own
style); Windows-illegal characters stripped from names with collisions suffixed rather than
overwritten; already-exported files skipped so an interrupted run resumes cheaply; and
rendering options, transition time and selected scene restored in an `ensure` block.

**The filename is the scene name — so name the scenes, not the files.**

- For **booth component art** the names must match the MAP keys in
  `bot/specsheet-work/import-art.py`. Run `check-scene-names.rb` first — it's read-only and
  catches near-misses, which are the dangerous ones because they export happily to a filename
  the importer then ignores. `expected-scene-names.txt` holds the current 92 keys.
- For **proposal plates** name the scenes in plate order — `01-exterior`,
  `02-dimensioned`, `03-side`, `04-ventilation`, `05-plan` — and they come out ready for
  `proposal-v2.json`.

Two things to set before a run:

1. **Resize the SketchUp window to the aspect you want.** Height is derived from the current
   viewport aspect, and every image in a run shares it.
2. **Transparency.** `write_image` is always called with `:transparent => true`; the
   "Force transparent background" answer actually controls whether ground/horizon/fog are
   *drawn*. Yes → nothing behind the model → real alpha (right for component art). No → sky
   and ground render → effectively opaque (right for a proposal plate showing a room).

Test on one or two scenes into a throwaway folder before a long run. Widths above ~4000 px
can fail on some GPUs — `write_image` returns false and the scene lands in the failed list
rather than aborting the run.

## What to hand back

A script, plus in the reply: the load line, what got built, and an explicit list of
**everything in the model that is not measured** — ceiling heights, door heights, assumed
leaf widths, placeholder positions. The script should print that same list to the console so
it travels with the model.
