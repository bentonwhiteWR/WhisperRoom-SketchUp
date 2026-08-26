#!/usr/bin/env python
"""Build a fixture _dimensions.json in the EXACT shape angled-component-art.rb
emits, so the real ingest contract can be run against it without SketchUp.

There is no Ruby interpreter on this machine outside SketchUp, so the rows below
are a hand transcription of `dump_dimensions` (scripts/angled-component-art.rb).
A transcription can drift from its source, so this script does not just trust
itself: `cross_check()` pulls every JSON key literal out of the Ruby and every
JSON key out of the fixture and insists the two sets match. That catches the one
failure mode a hand-written fixture actually has — a key renamed on one side.

    python .forge/builder/emit-dimensions-fixture.py
    node   .forge/builder/check-dimensions-ingest.js

Rows chosen to exercise every branch in the emitter:
  1  CornerSeamSeal   clean visible row, the brief's own example
  2  Left46Door       the rule-2 case: raw_bbox carries 61.9 in of swing that
                      the visible bbox does not
  3  Duct Cover       assembly -> `parts`, two parts with their own z_base
  4  GoPro foam (24"x48")  a component name with inch marks in it, which is
                      what makes jstr load-bearing
  5  ENH 40 WALL      an ENH row: `scene` is the PNG stem, `scene_name` keeps
                      the "ENH " scene label
  6  BrokenScene      a scene with no subject -> zero box, kind "unresolved"
  7  EdgesOnly        a component with no visible face -> raw fallback, and a
                      kind that is deliberately NOT "visible"
"""

import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
RUBY = os.path.join(REPO, "scripts", "angled-component-art.rb")
OUT = os.path.join(HERE, "fixture", "_dimensions.json")


def f3(v):
    """Ruby's j3: three decimals, and never '-0.000'."""
    s = "%.3f" % float(v)
    return "0.000" if s == "-0.000" else s


def box(w, d, h):
    return '{ "w": %s, "d": %s, "h": %s }' % (f3(w), f3(d), f3(h))


def jstr(s):
    out = re.sub(r'([\\"])', r"\\\1", s)
    out = re.sub(r"[\x00-\x1f]", lambda m: "\\u%04x" % ord(m.group(0)), out)
    return '"' + out + '"'


def row(fields):
    return "  { " + ", ".join(fields) + " }"


ROWS = [
    # 1 — the brief's own example line, clean.
    row([
        '"scene": %s' % jstr("CornerSeamSeal"),
        '"scene_name": %s' % jstr("(CornerSeamSeal)"),
        '"component": %s' % jstr("CornerSeamSeal"),
        '"bbox": %s' % box(4.875, 4.875, 81.0),
        '"bbox_kind": "visible"',
        '"z_base": %s' % f3(0),
        '"anchor": { "x": %s, "y": %s, "z": %s }' % (f3(0), f3(0), f3(40.5)),
        '"cams": ["ExtNear", "ExtL", "ExtR", "IntFar"]',
        '"facing": { "cams": ["ExtNear"], "basis": %s, "ratio": %s }'
        % (jstr("front-face projected area; assumes front-face-out modelling"), f3(1.412)),
        '"raw_bbox": %s' % box(4.875, 4.875, 81.0),
    ]),
    # 2 — rule 2. The visible box is the 1-in slot; raw bounds carry the swing.
    row([
        '"scene": %s' % jstr("Left46Door"),
        '"scene_name": %s' % jstr("(Left46Door)"),
        '"component": %s' % jstr("Left46Door"),
        '"bbox": %s' % box(46.0, 1.062, 81.0),
        '"bbox_kind": "visible"',
        '"z_base": %s' % f3(0),
        '"anchor": { "x": %s, "y": %s, "z": %s }' % (f3(0), f3(0), f3(40.5)),
        '"cams": ["ExtL", "ExtR", "IntL", "IntR"]',
        '"facing": { "cams": ["ExtR"], "basis": %s, "ratio": %s }'
        % (jstr("front-face projected area; assumes front-face-out modelling"), f3(3.04)),
        '"raw_bbox": %s' % box(46.0, 61.9, 81.0),
    ]),
    # 3 — rule 3. One scene, two parts, each with its own z_base.
    row([
        '"scene": %s' % jstr("Duct Cover"),
        '"scene_name": %s' % jstr("(Duct Cover)"),
        '"component": %s' % jstr("Duct Cover"),
        '"bbox": %s' % box(14.0, 9.5, 30.25),
        '"bbox_kind": "visible"',
        '"z_base": %s' % f3(50.75),
        '"anchor": { "x": %s, "y": %s, "z": %s }' % (f3(0), f3(0), f3(65.875)),
        '"cams": ["ExtL", "ExtR"]',
        '"raw_bbox": %s' % box(14.0, 9.5, 30.25),
        '"parts": [{ "name": %s, "bbox": %s, "bbox_kind": "visible", "z_base": %s }, '
        '{ "name": %s, "bbox": %s, "bbox_kind": "visible", "z_base": %s }]'
        % (jstr("DuctCoverLower"), box(14.0, 9.5, 12.0), f3(50.75),
           jstr("DuctCoverUpper"), box(14.0, 9.5, 12.0), f3(69.0)),
    ]),
    # 4 — the name that is not a filename. jstr is what keeps the file parseable.
    row([
        '"scene": %s' % jstr("GoPro foam (24-x48-)"),
        '"scene_name": %s' % jstr('(GoPro foam (24"x48"))'),
        '"component": %s' % jstr('GoPro foam (24"x48")'),
        '"bbox": %s' % box(24.0, 48.0, 2.0),
        '"bbox_kind": "visible"',
        '"z_base": %s' % f3(0),
        '"anchor": { "x": %s, "y": %s, "z": %s }' % (f3(0), f3(0), f3(1.0)),
        '"cams": ["ExtL", "ExtR", "IntL", "IntR"]',
        '"raw_bbox": %s' % box(24.0, 48.0, 2.0),
    ]),
    # 5 — the ENH join. `scene` is the stem the PNG carries, not the "ENH "
    #     scene label, because loadDimensionsJson does no prefix stripping.
    row([
        '"scene": %s' % jstr("ENH40WL"),
        '"scene_name": %s' % jstr("ENH 40 WALL"),
        '"component": %s' % jstr("ENH40WL"),
        '"bbox": %s' % box(40.0, 2.125, 79.5),
        '"bbox_kind": "visible"',
        '"z_base": %s' % f3(0),
        '"anchor": { "x": %s, "y": %s, "z": %s }' % (f3(0), f3(0), f3(39.75)),
        '"cams": ["ExtL", "ExtR", "IntL", "IntR"]',
        '"raw_bbox": %s' % box(40.0, 2.125, 79.5),
    ]),
    # 6 — rule 4. A scene that measured nothing still gets a row.
    row([
        '"scene": %s' % jstr("(BrokenScene)"),
        '"scene_name": %s' % jstr("(BrokenScene)"),
        '"component": ""',
        '"bbox": %s' % box(0, 0, 0),
        '"bbox_kind": "unresolved"',
        '"z_base": %s' % f3(0),
        '"anchor": { "x": %s, "y": %s, "z": %s }' % (f3(0), f3(0), f3(0)),
        '"note": %s' % jstr("nothing measured: scene has no camera"),
    ]),
    # 7 — the guard the brief calls the single most important instruction: a
    #     part whose visible bounds cannot be computed cleanly is NOT emitted
    #     as a silent raw bound.
    row([
        '"scene": %s' % jstr("EdgesOnly"),
        '"scene_name": %s' % jstr("(EdgesOnly)"),
        '"component": %s' % jstr("EdgesOnly"),
        '"bbox": %s' % box(31.0, 1.0, 81.0),
        '"bbox_kind": "no-visible-faces"',
        '"z_base": %s' % f3(0),
        '"anchor": { "x": %s, "y": %s, "z": %s }' % (f3(0), f3(0), f3(40.5)),
        '"cams": ["ExtL", "ExtR", "IntL", "IntR"]',
        '"raw_bbox": %s' % box(31.0, 1.0, 81.0),
        '"note": %s' % jstr(
            "no visible face found inside this component — it may be edges only, "
            "or everything in it is hidden; raw bounds emitted, do not trust for masking"),
    ]),
]


# The keys the Ruby emitter can write, and the keys the fixture writes, must be
# the same set. Anything else means this transcription has drifted.
RUBY_KEY_RE = re.compile(r'"([a-z_]+)":')


def cross_check(text):
    src = io.open(RUBY, encoding="utf-8").read()
    lo = src.index("def self.dump_dimensions")
    body = src[src.index("def self.jstr"):src.index("# One part, one camera")]
    ruby_keys = set(RUBY_KEY_RE.findall(body))
    ruby_keys -= {"w", "d", "h", "x", "y", "z"}      # inside jbox / the anchor literal
    fix_keys = set()

    def walk(o):
        if isinstance(o, dict):
            for k, v in o.items():
                fix_keys.add(k)
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)

    for r in json.loads(text):
        walk(r)
    fix_keys -= {"w", "d", "h", "x", "y", "z"}
    assert lo > 0
    missing = ruby_keys - fix_keys
    extra = fix_keys - ruby_keys
    if missing or extra:
        print("KEY CROSS-CHECK FAILED")
        print("  in the Ruby, not in the fixture:", sorted(missing))
        print("  in the fixture, not in the Ruby:", sorted(extra))
        return False
    print("key cross-check ok  (%d keys, both sides): %s"
          % (len(ruby_keys), " ".join(sorted(ruby_keys))))
    return True


def main():
    text = "[\n" + ",\n".join(ROWS) + "\n]\n"
    try:
        json.loads(text)
    except ValueError as e:
        print("the emitted text is not valid JSON: %s" % e)
        return 1
    if not cross_check(text):
        return 1
    d = os.path.dirname(OUT)
    if not os.path.isdir(d):
        os.makedirs(d)
    io.open(OUT, "w", encoding="utf-8", newline="").write(text)
    print("wrote %s  (%d rows)" % (OUT, len(ROWS)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
