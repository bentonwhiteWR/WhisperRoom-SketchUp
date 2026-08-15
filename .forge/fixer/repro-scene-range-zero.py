#!/usr/bin/env python3
"""Reproduce audit finding 4: a scene range starting at 0 silently includes the LAST scene.

There is no Ruby interpreter on this machine outside SketchUp, so this is a
line-faithful Python reimplementation of the `select_pages` token parser shared by
the five exporters:

    scripts/export-scenes.rb
    scripts/save-scene-components.rb
    scripts/angled-component-art.rb
    scripts/elevation-export.rb
    scripts/export-component-art.rb

The one behaviour that matters for the bug is that Python and Ruby agree on negative
list indexing: for both languages `pages[-1]` is the LAST element, not an error.
That is the whole defect.

Run:  python .forge/fixer/repro-scene-range-zero.py
Exits non-zero if any case fails.
"""

import re
import sys

RANGE = re.compile(r"\A(\d+)\s*-\s*(\d+)\Z")
NUM = re.compile(r"\A\d+\Z")

# A known scene list: eight scenes, named so a wrong pick is obvious on sight.
PAGES = ["01-exterior", "02-dimensioned", "03-side", "04-ventilation",
         "05-plan", "06-detail", "07-door", "08-LAST"]


def parse_old(pages, spec):
    """The parser as it shipped. Returns (picked, misses)."""
    picked, misses = [], []
    for tok in [t.strip() for t in str(spec).strip().lower().split(",")]:
        if not tok:
            continue
        m = RANGE.match(tok)
        if m:
            a, b = int(m.group(1)), int(m.group(2))
            if a > b:
                a, b = b, a
            # (a..b).map { |n| pages[n - 1] }.compact  -- no lower guard
            hit = [pages[n - 1] for n in range(a, b + 1)
                   if -len(pages) <= n - 1 < len(pages)]
        elif NUM.match(tok):
            n = int(tok)
            hit = [pages[n - 1]] if (n >= 1 and n - 1 < len(pages)) else []
        else:
            hit = [p for p in pages if tok in p.lower()]
        if hit:
            picked.extend(hit)
        else:
            misses.append(tok)
    # picked.compact.uniq -- order-preserving dedupe
    return list(dict.fromkeys(picked)), misses


def parse_new(pages, spec):
    """The parser after the fix. Returns (picked, misses)."""
    picked, misses = [], []
    for tok in [t.strip() for t in str(spec).strip().lower().split(",")]:
        if not tok:
            continue
        m = RANGE.match(tok)
        if m:
            a, b = int(m.group(1)), int(m.group(2))
            if a > b:
                a, b = b, a
            lo, hi = max(a, 1), min(b, len(pages))
            if lo > hi:
                hit = []
            else:
                if a < lo:
                    misses.append("%d-%d" % (a, lo - 1))
                if b > hi:
                    misses.append("%d-%d" % (hi + 1, b))
                hit = [pages[n - 1] for n in range(lo, hi + 1)]
        elif NUM.match(tok):
            n = int(tok)
            hit = [pages[n - 1]] if (n >= 1 and n - 1 < len(pages)) else []
        else:
            hit = [p for p in pages if tok in p.lower()]
        if hit:
            picked.extend(hit)
        else:
            misses.append(tok)
    return list(dict.fromkeys(picked)), misses


# token -> (expected old picked, expected new picked, expected new misses)
CASES = [
    # THE HEADLINE CASE: 0-5 wraps to the last scene before the fix.
    ("0-5", PAGES[7:8] + PAGES[0:5], PAGES[0:5], ["0-0"]),
    ("0",   [],                      [],          ["0"]),
    # the swap path: 5-0 normalises to 0-5 and inherits the same wrap
    ("5-0", PAGES[7:8] + PAGES[0:5], PAGES[0:5], ["0-0"]),
    # upper end past the list: silently short before, reported after
    ("3-999", PAGES[2:8],            PAGES[2:8], ["9-999"]),
    ("1-3",  PAGES[0:3],             PAGES[0:3], []),
    ("4",    PAGES[3:4],             PAGES[3:4], []),
    # wholly outside on the low end: reported as the whole token, once
    ("0-0",  PAGES[7:8],             [],          ["0-0"]),
    ("999",  [],                     [],          ["999"]),
    ("",     PAGES,                  PAGES,       []),   # empty -> 'all', see note
    ("!!",   [],                     [],          ["!!"]),  # malformed -> name search
    # wholly outside on the high end
    ("99-100", [],                   [],          ["99-100"]),
    # mixed list, the shape a real user types
    ("0-2,door", PAGES[7:8] + PAGES[0:2] + PAGES[6:7],
                 PAGES[0:2] + PAGES[6:7], ["0-0"]),
]


def show(picked):
    return "[" + ", ".join(picked) + "]" if picked else "[]"


def main():
    failures = 0
    print("scene list (8 scenes): " + ", ".join(PAGES))
    print()
    hdr = "%-10s %-46s %-38s %s" % ("token", "OLD picked", "NEW picked", "NEW reported")
    print(hdr)
    print("-" * len(hdr))
    for tok, exp_old, exp_new, exp_miss in CASES:
        if tok == "":
            # The callers short-circuit an empty spec to 'all' before the token
            # loop is ever reached; recorded here so the table is complete.
            old_p, new_p, new_m = PAGES, PAGES, []
        else:
            old_p, _ = parse_old(PAGES, tok)
            new_p, new_m = parse_new(PAGES, tok)
        print("%-10s %-46s %-38s %s" % (repr(tok), show(old_p), show(new_p),
                                        ", ".join(new_m) or "-"))
        for label, got, want in (("old", old_p, exp_old),
                                 ("new", new_p, exp_new),
                                 ("misses", new_m, exp_miss)):
            if got != want:
                print("    FAIL %s for %r: got %r, wanted %r" % (label, tok, got, want))
                failures += 1
    print()

    # The headline assertion, stated on its own so it cannot be lost in the table.
    old_05, _ = parse_old(PAGES, "0-5")
    new_05, miss_05 = parse_new(PAGES, "0-5")
    print("headline: '0-5' OLD includes %r -> %s" % (PAGES[-1], PAGES[-1] in old_05))
    print("headline: '0-5' NEW includes %r -> %s" % (PAGES[-1], PAGES[-1] in new_05))
    if PAGES[-1] not in old_05:
        print("    FAIL: the bug did not reproduce in the OLD parser")
        failures += 1
    if PAGES[-1] in new_05:
        print("    FAIL: the last scene is still picked up by the NEW parser")
        failures += 1
    if miss_05 != ["0-0"]:
        print("    FAIL: '0-5' should report 0-0 as unmatched, got %r" % miss_05)
        failures += 1

    # No input may ever reach a negative index in the fixed parser. A wrap shows
    # up as a picked list whose scene indices are not strictly ascending (the
    # last scene arriving before the first ones), so test for that directly.
    for tok in ("0-5", "0", "0-0", "5-0", "0-999", "00-3", "0-1", "999-0"):
        picked, _ = parse_new(PAGES, tok)
        idx = [PAGES.index(p) for p in picked]
        if idx != sorted(idx):
            print("    FAIL: %r wrapped — picked order %r" % (tok, idx))
            failures += 1
        old_picked, _ = parse_old(PAGES, tok)
        old_idx = [PAGES.index(p) for p in old_picked]
        print("wrap check %-8s old %-22s new %s"
              % (repr(tok), old_idx, idx))

    print()
    if failures:
        print("FAILED: %d assertion(s)" % failures)
        return 1
    print("PASSED: %d cases, old-vs-new behaviour is as described" % len(CASES))
    return 0


if __name__ == "__main__":
    sys.exit(main())
