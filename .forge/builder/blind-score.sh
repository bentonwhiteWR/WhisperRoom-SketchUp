#!/bin/sh
# Blind-trial pipeline: copy the isolated transcription into its case dir,
# then score live with --record. Usage: blind-score.sh <x>  (e.g. a-office)
set -e
S="C:/Users/bento/AppData/Local/Temp/claude/C--Users-bento-OneDrive-Documents-Claude-Sketchup/87da3f21-6f6b-4dcc-8750-75cbeb1a22ca/scratchpad"
R="C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp"
cp "$S/blind/$1/takeoff.json" "$R/eval/floorplans/blind-$1/takeoff.json"
python "$R/scripts/eval-floorplan.py" "blind-$1" --record
