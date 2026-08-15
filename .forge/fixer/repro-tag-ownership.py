# Repro for the auto-dimension.rb tag-ownership defect, and proof of the fix.
#
# No Ruby interpreter exists outside SketchUp on this machine, so the selection
# predicate is transcribed into Python and run over the four REAL tag names that
# exist in scripts/ today. The defect is entirely in the predicate.
#
#   python .forge/fixer/repro-tag-ownership.py

TAG_DIM = 'WR-Dims'
TAG_DOOR = 'WR-Dims-Doors'
OWN_TAGS = [TAG_DIM, TAG_DOOR]

# Every WR-Dims* tag drawn by any script in scripts/ (grep-confirmed).
TAGS_IN_MODEL = [
    ('WR-Dims',           'auto-dimension.rb'),
    ('WR-Dims-Doors',     'auto-dimension.rb'),
    ('WR-Dims-Booth',     'dimension-booth.rb'),
    ('WR-Dims-Selection', 'dimension-selection.rb'),
]


def old_predicate(name):          # what own_dims / run() used to do
    return name.startswith(TAG_DIM)


def new_predicate(name):          # own_tag? — exact membership
    return name in OWN_TAGS


def main():
    old = [t for t, _ in TAGS_IN_MODEL if old_predicate(t)]
    new = [t for t, _ in TAGS_IN_MODEL if new_predicate(t)]

    print('tag                 owner                    OLD prefix test   NEW exact test')
    for tag, owner in TAGS_IN_MODEL:
        print('%-19s %-24s %-17s %s' % (
            tag, owner,
            'ERASES' if old_predicate(tag) else 'leaves',
            'ERASES' if new_predicate(tag) else 'leaves'))

    print()
    print('OLD matched %d tags: %s' % (len(old), ', '.join(old)))
    print('NEW matched %d tags: %s' % (len(new), ', '.join(new)))

    # All four names start with "WR-Dims", so the old test claimed every one of
    # them: its own two plus two belonging to other tools.
    assert len(old) == 4, 'expected the old prefix test to claim all four tags'
    assert 'WR-Dims-Booth' in old and 'WR-Dims-Selection' in old
    assert new == OWN_TAGS, 'new test must match exactly this script own two tags'
    print()
    print('PASS: old test erased two other tools work; new test erases only its own.')


if __name__ == '__main__':
    main()
