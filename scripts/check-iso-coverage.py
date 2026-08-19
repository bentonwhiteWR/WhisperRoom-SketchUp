"""Iso30 coverage check: does the rendered folder cover every scene?

Compares three things that should agree and usually do not:

  1. the scene list exported from the master file,
  2. the components the exporter says it shot (its own _diagnostics.txt),
  3. the PNGs actually on disk.

The exporter names files after the COMPONENT DEFINITION, not the scene, so a
scene aimed at the wrong neighbour in the master row renders a correct-looking
image under the wrong name. Section D below is what catches that.

    python scripts/check-iso-coverage.py [image-dir] [scene-list.txt]
"""

import collections
import os
import re
import sys

DIR = sys.argv[1] if len(sys.argv) > 1 else r"P:\Sketchup\BoothBuilderViews\AngledISOViews"
SCENES = sys.argv[2] if len(sys.argv) > 2 else r"C:\Users\bento\Downloads\_scene-list.txt"

CAMERAS = ("ExtL", "ExtR", "IntL", "IntR")


def safe_name(name):
    """Mirror of safe_name in angled-component-art.rb. Keep the two in step:
    spaces and dots survive, the Windows-forbidden set becomes a dash, and an
    empty name becomes the literal 'unnamed'."""
    out = re.sub(r'[\/:*?"<>|]', "-", name.strip())
    out = re.sub(r"[. ]+$", "", out)
    return out or "unnamed"


def read_scenes(path):
    """Rows look like:  12   SceneName   ComponentName   40.0 x 1.8 x 81.0"""
    rows = []
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            m = re.match(r"\s+(\d+)\s{2,}(.+?)\s{2,}(.+?)\s{2,}[\d.]+ x ", line)
            if m:
                rows.append((int(m.group(1)), m.group(2).strip(), m.group(3).strip()))
    return rows


def read_images(directory):
    found = collections.defaultdict(set)
    for name in os.listdir(directory):
        m = re.match(r"(.+)_Iso30_(\w+)\.png$", name)
        if m:
            found[m.group(1)].add(m.group(2))
    return found


def main():
    rows = read_scenes(SCENES)
    files = read_images(DIR)
    expected = collections.defaultdict(list)
    for num, scene, comp in rows:
        expected[safe_name(comp)].append((num, scene, comp))

    print("scenes %d   distinct components %d   components with images %d   images %d"
          % (len(rows), len(expected), len(files), sum(len(v) for v in files.values())))

    print("\nA. scenes whose component has NO images")
    for key in sorted(expected):
        if key not in files:
            for num, scene, comp in expected[key]:
                print("   #%-4d %-26s -> %s" % (num, scene, comp))

    print("\nB. components missing one or more cameras")
    for key in sorted(expected):
        if key in files and len(files[key]) < len(CAMERAS):
            print("   %-26s missing %s" % (key, sorted(set(CAMERAS) - files[key])))

    print("\nC. images no scene points at")
    for key in sorted(set(files) - set(expected)):
        print("   %-26s %s" % (key, sorted(files[key])))

    print("\nD. scenes that resolve to a differently-named component")
    for num, scene, comp in rows:
        if safe_name(scene) != safe_name(comp):
            print("   #%-4d %-26s -> %s" % (num, scene, comp))

    print("\nE. components shared by several scenes")
    for key in sorted(expected):
        if len(expected[key]) > 1:
            print("   %-26s <- %s" % (key, ", ".join("#%d %s" % (n, s) for n, s, _ in expected[key])))


if __name__ == "__main__":
    main()
