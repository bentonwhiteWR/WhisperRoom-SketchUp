# Panel render harness (no SketchUp needed)

`python scan.py` ports `main.rb`'s `meta_of`/`cat_of`/`tab_of`/`shelf_of`/`icon_of` and writes
`scripts.json` — the `scripts` array exactly as `payload` ships it. `python harness.py` wraps the
REAL `scripts/wr_tools/panel.html` with a stubbed `window.sketchup` and a payload shaped like
`main.rb#payload` (slots from `defaults.json`, faces resolved the way `face_path` does, the real
icon library and sprite), then screenshots it in headless Chrome at 430x640, 330 wide and a
full-height list. Screenshots land in `.forge/scoper/`. Edit the `shots` list to add states
(search terms, dev on, update pending). Harness HTML files are written next to these scripts.
