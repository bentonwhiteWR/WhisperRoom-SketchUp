# -*- coding: utf-8 -*-
"""Generate the WhisperRoom toolbar icon library.

    python make-icons.py

Writes wr_tools/ico-<id>.svg, one file per icon. The plugin GLOBS that pattern,
so adding an entry to ICONS here and re-running is the whole job of adding an
icon — no edit to main.rb, no edit to panel.html.

WHY A GENERATOR AND NOT FORTY HAND-WRITTEN FILES

Every icon shares a viewBox, a stroke width, a colour and a cap style. Forty
copies of that boilerplate is forty chances for one of them to drift, and a
drifted stroke width is visible on a toolbar where the icons sit shoulder to
shoulder. Here the frame is written once and only the glyph body varies.

DRAWING RULES, learned from what reads badly at 24 px:
  - 24x24 viewBox, glyph inside 3..21. SketchUp draws these at 24 and 32 px.
  - Stroke, not fill. A filled glyph turns into a blob at 24 px.
  - Stroke width 1.8. Thinner disappears against SketchUp's light toolbar.
  - At most two "ideas" per icon. A booth AND a door AND an arrow is mush.
  - Orange is the whole palette. A second colour at this size just muddies.
"""
import os

ORANGE = '#ee6216'
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'wr_tools')

FRAME = (
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
    'width="24" height="24" fill="none" stroke="%s" stroke-width="1.8" '
    'stroke-linecap="round" stroke-linejoin="round">%s</svg>\n'
)

# id, human label, glyph body. Label is what the picker shows, so it has to say
# what the picture is, not what a script does with it.
ICONS = [
    # ---- the booth itself -------------------------------------------------
    ('booth', 'Booth',
     '<rect x="3.5" y="4" width="17" height="16" rx="1.5"/><path d="M3.5 8.5h17"/>'),
    ('booth-door', 'Booth with door',
     '<rect x="3.5" y="4" width="17" height="16" rx="1.5"/>'
     '<rect x="12" y="9" width="6.5" height="11"/><circle cx="13.7" cy="14.6" r=".9"/>'),
    ('door', 'Door and swing',
     '<path d="M6 20V4h6v16"/><path d="M12 4a12 12 0 0 1 8 8"/><path d="M6 20h14"/>'),
    ('window', 'Window',
     '<rect x="4" y="5" width="16" height="14" rx="1"/><path d="M12 5v14M4 12h16"/>'),
    ('vent', 'Vent panel',
     '<rect x="4" y="4" width="16" height="16" rx="1.5"/>'
     '<path d="M7 9h10M7 12h10M7 15h10"/>'),
    ('fan', 'Fan unit',
     '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="2"/>'
     '<path d="M12 4v4M12 16v4M4 12h4M16 12h4"/>'),
    ('wall', 'Wall panels',
     '<rect x="4" y="3.5" width="6" height="17" rx="1"/>'
     '<rect x="14" y="3.5" width="6" height="17" rx="1"/>'),
    ('floor', 'Floor',
     '<path d="M2 16l10-5 10 5-10 5z"/><path d="M7 13.5l10 5M17 13.5l-10 5"/>'),
    ('ceiling', 'Ceiling',
     '<path d="M2 8l10 5 10-5-10-5z"/><path d="M7 10.5l10-5M17 10.5l-10-5"/>'),
    ('ramp', 'ADA ramp',
     '<path d="M3 19h18L3 8z"/><path d="M9 19v-4.2M15 19v-7.8"/>'),
    ('seal', 'Seam seal',
     '<path d="M9 3v18M15 3v18"/><path d="M9 8h6M9 16h6"/>'),

    # ---- assembling -------------------------------------------------------
    ('link', 'Link / share URL',
     '<path d="M10.5 13.5a4 4 0 0 0 6 .5l2.5-2.5a4 4 0 0 0-5.7-5.7L12 7.1"/>'
     '<path d="M13.5 10.5a4 4 0 0 0-6-.5L5 12.5a4 4 0 0 0 5.7 5.7L12 16.9"/>'),
    ('cube', 'Isometric part',
     '<path d="M12 3l8 4.5v9L12 21l-8-4.5v-9z"/><path d="M12 12v9M12 12l8-4.5M12 12L4 7.5"/>'),
    ('blocks', 'Components',
     '<rect x="3" y="3" width="8" height="8" rx="1"/><rect x="13" y="3" width="8" height="8" rx="1"/>'
     '<rect x="3" y="13" width="8" height="8" rx="1"/><rect x="13" y="13" width="8" height="8" rx="1"/>'),
    ('layers', 'Layers / tags',
     '<path d="M12 3l9 4.5-9 4.5-9-4.5z"/><path d="M3 12l9 4.5 9-4.5"/>'
     '<path d="M3 16.5L12 21l9-4.5"/>'),
    ('explode', 'Explode assembly',
     '<rect x="9.5" y="9.5" width="5" height="5"/>'
     '<path d="M8 8L4 4m0 0v4m0-4h4"/><path d="M16 8l4-4m0 0v4m0-4h-4"/>'
     '<path d="M8 16l-4 4m0 0v-4m0 4h4"/><path d="M16 16l4 4m0 0v-4m0 4h-4"/>'),
    ('swap', 'Find and replace',
     '<path d="M4 8h13m0 0l-3.5-3.5M17 8l-3.5 3.5"/>'
     '<path d="M20 16H7m0 0l3.5-3.5M7 16l3.5 3.5"/>'),
    ('rotate', 'Rotate / re-run',
     '<path d="M20.5 12a8.5 8.5 0 1 1-2.5-6"/><path d="M20.5 3.5v6h-6"/>'),

    # ---- measuring and drawing -------------------------------------------
    ('ruler', 'Ruler',
     '<rect x="1.5" y="8" width="21" height="8" rx="1" transform="rotate(-45 12 12)"/>'
     '<path d="M8.4 8.4l1.8 1.8M11.2 5.6l1.8 1.8M13.9 13.9l1.8 1.8M11.2 16.6l1.8 1.8"/>'),
    ('dimension', 'Dimension string',
     '<path d="M3 6v12M21 6v12"/><path d="M5 12h14"/>'
     '<path d="M5 12l2.5-2.5M5 12l2.5 2.5M19 12l-2.5-2.5M19 12l-2.5 2.5"/>'),
    ('plan', 'Floor plan',
     '<rect x="3.5" y="3.5" width="17" height="17" rx="1"/>'
     '<path d="M3.5 13h7v7.5M10.5 3.5V9h10"/>'),
    ('room', 'Room outline',
     '<path d="M3 21V5h9v6h9v10z"/><path d="M14 21v-5h4v5"/>'),
    ('grid', 'Grid',
     '<rect x="3.5" y="3.5" width="17" height="17" rx="1"/>'
     '<path d="M9.2 3.5v17M14.8 3.5v17M3.5 9.2h17M3.5 14.8h17"/>'),
    ('elevation', 'Elevation view',
     '<rect x="6" y="7" width="12" height="12"/><rect x="9" y="11" width="6" height="8"/>'
     '<path d="M3 19h18M3 4h18"/>'),
    ('section', 'Section / cut',
     '<rect x="4" y="4" width="16" height="16" rx="1"/>'
     '<path d="M4 20L20 4M9 20L20 9M14 20l6-6"/>'),

    # ---- output -----------------------------------------------------------
    ('camera', 'Camera',
     '<path d="M3 8.5A1.5 1.5 0 0 1 4.5 7h3L9 4.8h6L16.5 7h3A1.5 1.5 0 0 1 21 8.5v9A1.5 1.5 0 0 1 '
     '19.5 19h-15A1.5 1.5 0 0 1 3 17.5z"/><circle cx="12" cy="12.8" r="3.6"/>'),
    ('photo', 'Image',
     '<rect x="3" y="5" width="18" height="14" rx="1.5"/><circle cx="8.5" cy="10" r="1.7"/>'
     '<path d="M3 16.5l5-4.5 4.5 4 3-2.6L21 17"/>'),
    ('scenes', 'Scenes',
     '<rect x="3" y="7" width="13" height="12" rx="1.5"/>'
     '<path d="M6.5 4.5h11.5A1.5 1.5 0 0 1 19.5 6v10"/>'
     '<path d="M9.5 2h9A2.5 2.5 0 0 1 21 4.5v9"/>'),
    ('export', 'Export files',
     '<path d="M12 3v11m0 0l-4-4m4 4l4-4"/>'
     '<path d="M4 16v3a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-3"/>'),
    ('import', 'Import files',
     '<path d="M12 14V3m0 0L8 7m4-4l4 4"/>'
     '<path d="M4 16v3a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-3"/>'),
    ('save', 'Save',
     '<path d="M4 5.5A1.5 1.5 0 0 1 5.5 4h10L20 8.5v10a1.5 1.5 0 0 1-1.5 1.5h-13A1.5 1.5 0 0 1 4 18.5z"/>'
     '<path d="M8 4v5h7"/><rect x="8" y="13" width="8" height="7"/>'),
    ('folder', 'Folder',
     '<path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>'),
    ('printer', 'Print / PDF',
     '<path d="M7 9V4h10v5"/><rect x="3" y="9" width="18" height="7" rx="1.5"/>'
     '<rect x="7" y="14" width="10" height="6"/>'),
    ('doc', 'Document',
     '<path d="M6 3h8l4 4v14H6z"/><path d="M14 3v4h4"/><path d="M9 12h6M9 16h6"/>'),
    ('list', 'List',
     '<path d="M9 6h11M9 12h11M9 18h11"/><circle cx="5" cy="6" r="1.3"/>'
     '<circle cx="5" cy="12" r="1.3"/><circle cx="5" cy="18" r="1.3"/>'),

    # ---- generic actions --------------------------------------------------
    ('play', 'Run',
     '<path d="M7 4.5l13 7.5-13 7.5z"/>'),
    ('bolt', 'Fast action',
     '<path d="M13.5 2.5L5 13.5h6L10.5 21.5 19 10.5h-6z"/>'),
    ('wand', 'Generate',
     '<path d="M4.5 19.5L15 9"/><path d="M13 7l4 4"/>'
     '<path d="M18.5 3v3.5M18.5 3l-2.2 1.3M18.5 3l2.2 1.3"/><path d="M6 4v3M4.5 5.5h3"/>'),
    ('gear', 'Settings',
     '<circle cx="12" cy="12" r="3.4"/>'
     '<path d="M12 2.5v3M12 18.5v3M21.5 12h-3M5.5 12h-3'
     'M18.7 5.3l-2.1 2.1M7.4 16.6l-2.1 2.1M18.7 18.7l-2.1-2.1M7.4 7.4L5.3 5.3"/>'),
    ('search', 'Search / probe',
     '<circle cx="10.5" cy="10.5" r="6.5"/><path d="M21 21l-5.8-5.8"/>'),
    ('check', 'Verify',
     '<circle cx="12" cy="12" r="8.5"/><path d="M8 12.3l2.8 2.7L16 9.5"/>'),
    ('star', 'Favourite',
     '<path d="M12 3.2l2.8 5.7 6.2.9-4.5 4.4 1.1 6.2L12 17.5 6.4 20.4l1.1-6.2L3 9.8l6.2-.9z"/>'),
    ('pin', 'Pin',
     '<path d="M9 3h6l-1 6 3.5 3.5H6.5L10 9z"/><path d="M12 12.5V21"/>'),
    ('clock', 'Timing',
     '<circle cx="12" cy="12" r="8.5"/><path d="M12 7v5.3l3.5 2"/>'),
    ('tag', 'Tag / rename',
     '<path d="M3 11.5V4h7.5L21 14.5 14.5 21z"/><circle cx="7.5" cy="7.5" r="1.4"/>'),
    ('text', 'Text',
     '<path d="M5 19l6-14 6 14"/><path d="M7.6 13.5h6.8"/>'),
    ('drill', 'Machining / jig',
     '<rect x="8" y="3" width="8" height="9" rx="1"/><path d="M12 12v5"/>'
     '<path d="M9.5 17h5l-2.5 4z"/>'),
]


def main():
    if not os.path.isdir(OUT):
        raise SystemExit('No wr_tools folder at %s' % OUT)
    ids = [i for i, _l, _b in ICONS]
    dupes = set(x for x in ids if ids.count(x) > 1)
    if dupes:
        raise SystemExit('Duplicate icon ids: %s' % ', '.join(sorted(dupes)))
    for name, label, body in ICONS:
        path = os.path.join(OUT, 'ico-%s.svg' % name)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(FRAME % (ORANGE, body))
    print('%d icons -> %s' % (len(ICONS), OUT.replace('\\', '/')))
    print('')
    print('The plugin globs ico-*.svg, so they are live after the next')
    print('install-plugin.py + SketchUp restart. Labels come from this file via')
    print('ico-labels.txt, written alongside them.')
    # The wr-* lines belong to .forge/builder-icons/gen-icons.py (the
    # WhisperRoom symbol set); keep them, rewrite only this set's.
    lp = os.path.join(OUT, 'ico-labels.txt')
    wr = []
    if os.path.exists(lp):
        with open(lp, encoding='utf-8') as f:
            wr = [l for l in f.read().splitlines() if l.startswith('wr-')]
    with open(lp, 'w', encoding='utf-8') as f:
        for name, label, _b in ICONS:
            f.write('%s\t%s\n' % (name, label))
        for l in wr:
            f.write(l + '\n')


if __name__ == '__main__':
    main()
