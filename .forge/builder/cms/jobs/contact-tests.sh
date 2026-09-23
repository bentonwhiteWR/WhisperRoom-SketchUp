#!/bin/sh
# One 800 px V-Ray test per distinct scene camera, hero-tuned settings, lights frozen (22 Sep).
cd "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp/.forge/builder/cms"
T="Z:/Sketchup/ClientDrawings/Community Music School - renders/tests"
while IFS='|' read -r F N; do
  [ -z "$F" ] && continue
  python rt.py "$T/c-$F.png" --page "$N" --w 800 --h 600 --min 1.0 --thr 0.05 --ev 14.73 --sunmult 0 2>&1 | tail -1 > "$T/c-$F.json"
  echo "$F done"
done <<'LIST'
01-angled|MDL 96144 E (components) 01-angled r
02-front|MDL 96144 E (components) 02-front r
03-high|MDL 96144 E (components) 03-high r
04-side|MDL 96144 E (components) 04-side r
05-ventilation|MDL 96144 E (components) 05-ventilation r
06-plan|MDL 96144 E (components) 06-plan r
07-interior|MDL 96144 E (components) 07-interior
L01-exterior|01-exterior
L02-dimensioned|02-dimensioned
L03-side|03-side
L04-ventilation|04-ventilation
L05-plan|05-plan
PA-photo-A|Photo A - long view
PB-photo-B|Photo B - corner view
LIST
echo ALL DONE
