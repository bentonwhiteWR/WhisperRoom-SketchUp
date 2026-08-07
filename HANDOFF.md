# HANDOFF — 2026-08-06, end of day

## Read this first

**Fourteen Ruby scripts were written today and none of them has been run.**
`rbcheck.py` says every one balances and both HtmlDialogs' JavaScript parses.
That is the whole of what is verified — no SketchUp API call in any of it has
executed. Treat all of it as unproven until the checks below pass.

## Tomorrow, in this order

Cheapest and most load-bearing first, so a failure stops you early rather than
after an hour.

1. **Open SketchUp 2024.** The WhisperRoom panel should already be there from
   today. If a script is missing from it, hit **Rescan** — the panel rereads
   `scripts/` every time, no restart needed.

2. **Run `Pendant Curing Jig`.** Console should end with `0 naked edges`.
   Tests the panel's run path and a fixture in one go.

3. **Run `Build Room`.** The dialog opens seeded with an L-shaped room that
   already closes; just press **Build room**. This is the best single test —
   it exercises `build-room.rb` *and* `auto-dimension.rb`, and the console
   prints the run table plus a per-axis chain closure. Expect `-> CLOSES`.

4. **Run `Orbit Export`** on the jig with azimuth step 90 and elevations `30`.
   Four images. Confirms the framing before committing to a real run.

5. **Run `Exploded View`** on a built booth, then **Reset**, and check every
   part lands back exactly where it started.

Paste the console output — good or bad. A `FAILED:` line carries the class,
message and backtrace, which is usually enough to fix it outright.

## On the laptop

```
git pull
python scripts/install-plugin.py     # wr_tools changed today — this is required
```

The plugin and both Python generators now resolve their own paths, so the
laptop's `Documents\Claude\...` and the desktop's OneDrive-redirected copy both
work with no edits. That was previously broken on the desktop.

## What is blocked, and on what

- **25 Enhanced booth variants do not build.** All of them are skipped in
  `wr-booth-data.rb` for unresolved panel lengths, so half the catalogue cannot
  be modelled at all. Everything on the assembly-manual track sits behind this.
  It starts as an investigation of how `gen-booth.py` solves Standard runs and
  where that rule fails for Enhanced — not yet scoped, because I have not
  looked.

- **Assembly step order is unknown and is not mine to invent.** The manifest
  `orbit-export.rb` writes has a null `step` per part. Somebody who actually
  assembles a booth needs to say the sequence — floor, corner seals, wall
  panels in what order, mid-wall seals, door, ceiling. Without it the manual
  has pictures and no sequence.

- **`build-v2.js` and `tools/sketchup-scene-export/` exist only on the laptop.**
  Neither is in any branch of any repo on GitHub, so proposals cannot be built
  on the desktop. Push them from the laptop when convenient.

## Where things stand

- The **manual pipeline** is: `booth-builder #d=` link → `gen-booth.py --design`
  → `wr-booth-data.rb` → `build-booth.rb` → `orbit-export.rb` → `manifest.json`
  → the manual. Everything up to and including the manifest exists. The manual
  generator does not.
- `docs/` holds four self-contained pages with working demos. Open them in a
  browser — they carry the reasoning behind the fixtures and the room tools.
- Nothing has been printed either. Every clearance in `reference/3d-printing.md`
  is still built on the 0.25 mm allowance and unconfirmed. Print the jig before
  the drying stand — an hour and 18 g calibrates the figure before 94 g.
