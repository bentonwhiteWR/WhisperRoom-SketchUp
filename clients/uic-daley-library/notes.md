# UIC Richard J. Daley Library — rooms 3190F / 3190G+H / 3190J

The 31 Aug 2026 job, entered into the repo's own protocol after the fact —
this is the job whose pipeline failure drove the floor-plan intake mission.
801 South Morgan Street, Chicago; third floor; dept 699000 (Computer
Science); plan S609-3 (UIC Planning, 12/8/2025, stamped NOT TO SCALE but
drawn proportionally true).

## Inputs (in `plans/`, gitignored — machine-local, never committed)

- `IMG_7594.jpeg` — phone photo, printed plan excerpt, rooms 3190G+H, pen
  field measurements (observed 31 Aug 2026)
- `IMG_7595.jpeg` — same, room 3190J
- `IMG_7596.jpeg` — same, room 3190F
- `S609-3.pdf` — pure vector plot of the whole floor (18,337 paths, no
  raster, no extractable text)
- `S609-3.dwg` — AutoCAD 2024 source of that plot (not used; Q4 deferred
  the scripted DWG path)

Originals stay in `C:\Users\bento\Downloads\` — these are copies.

## Scale anchor

Pen 18'11" = combined G+H interior width, spanning PDF wall faces
x 245.46..289.14 pt -> 5.1969 in/pt. Re-derivable any time with
`python eval/floorplans/derive-s609.py`, which cross-checks the PDF numbers
against the pen (G width 111.0" vs pen 9'3"; partition center 113.5" vs pen
9'5"; band depth 174.6" PDF vs pen 14'4" — truth uses the pen) and writes
the eval truth files.

## The take-off

`takeoff.json` here is the transcription of record AND the worked example of
`reference/takeoff-format.md`. Key calls, all recorded in its
`interpretations` block:

- **17'3" is the clear width between the two 10" heaters**, not the room
  width; the chain 10" + 17'3" + 10" = 18'11" is recorded as `parts` and
  enforced. Misapplying it was the likely ~20" error of the original job.
- **G+H is one room** (pen: wall removed, bulkhead at 8'3" AFF — pen beats
  print, Benton 31 Aug 2026).
- **J's 8'10" is corner -> door jamb on the west wall** (vertical pen
  bracket, observed on the photo), not a second width. J's depth and
  ceiling are ASSUMED with reasons — measure them.
- **F's 9'3"/9'6"** modeled as a 3" jog at the heater's end — UNCONFIRMED,
  ask Gabe.

Every dimension carries `{v, src}`; the ASSUMED inventory (10 values: 4 door
positions/heights per room, J's depth and ceiling) prints from
`python scripts/takeoff-check.py clients/uic-daley-library/takeoff.json`
and is flagged in the model when built. Confirm each with a tape before
anything reaches a proposal.
