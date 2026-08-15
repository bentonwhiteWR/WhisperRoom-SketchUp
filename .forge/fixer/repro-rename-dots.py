# Repro for the wr_tools/main.rb rename() "..." round-trip defect, and proof of
# the fix. meta_of() strips the trailing dots and returns a separate dialog flag;
# rename() tested the STRIPPED title, so the test was always false.
#
#   python .forge/fixer/repro-rename-dots.py

import re

TRAILING = re.compile(r'(\.\.\.|…)\Z')


def meta_of(title_line):
    """The two values rename() cares about: [0] title, [4] dialog."""
    raw = title_line.strip()
    dialog = TRAILING.search(raw) is not None
    title = TRAILING.sub('', raw).strip()
    return [title, None, None, None, dialog, None]


def rename_old(title_line, wanted):
    want = ' '.join(wanted.strip().split())
    old = meta_of(title_line)[0]
    if old.endswith('...') and want and not want.endswith('...'):
        want += '...'
    return want


def rename_new(title_line, wanted):
    want = ' '.join(wanted.strip().split())
    dialog = meta_of(title_line)[4]
    if dialog and want and not TRAILING.search(want):
        want += '...'
    return want


CASES = [
    # existing @title line,        typed name,        expected after fix
    ('# @title Dimension the room...', 'Room dimensions', 'Room dimensions...'),
    ('# @title Build a booth…',   'Booth',           'Booth...'),
    ('# @title Explode the view',      'Exploded view',   'Exploded view'),
    ('# @title Dimension the room...', 'Room dims...',    'Room dims...'),
]


def main():
    ok = True
    print('existing title                    typed            OLD result        NEW result        expected')
    for line, typed, expect in CASES:
        o = rename_old(line, typed)
        n = rename_new(line, typed)
        print('%-33s %-16s %-17s %-17s %s' % (line[9:], typed, o, n, expect))
        if n != expect:
            ok = False
    print()
    # The defect, stated as an assertion.
    assert rename_old('# @title Dimension the room...', 'Room dimensions') == 'Room dimensions', \
        'old code should have dropped the dots'
    assert rename_new('# @title Dimension the room...', 'Room dimensions') == 'Room dimensions...'
    assert rename_new('# @title Explode the view', 'Exploded view') == 'Exploded view', \
        'a non-dialog tool must not gain dots'
    assert rename_new('# @title Dimension the room...', 'Room dims...') == 'Room dims...', \
        'dots typed by hand must not be doubled'
    print('PASS' if ok else 'FAIL')
    assert ok


if __name__ == '__main__':
    main()
