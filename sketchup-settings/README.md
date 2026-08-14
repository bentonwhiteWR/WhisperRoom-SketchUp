# SketchUp settings backup

Benton's SketchUp preferences, keyboard shortcuts and templates. Regenerate with

    python scripts/backup-sketchup-settings.py

## Restoring on a new machine

**Shortcuts — do this one first, it is the clean path.** SketchUp can be open.

> Window → Preferences → Shortcuts → **Import** → `Preferences.dat`

That is SketchUp's own export format and it applies the 35 shortcuts and
nothing else.

**Everything else** — units, tool behaviour, drawing preferences:

    python scripts/backup-sketchup-settings.py --restore

**Close SketchUp first.** It rewrites `SharedPreferences.json` when it exits, so
restoring while it is running gets silently undone the moment you quit.

## What is in here

| | |
|---|---|
| `Preferences.dat` | SketchUp's own shortcuts export, 35 accelerators. **The restore path.** |
| `SketchUp 20xx/SharedPreferences.json` | Every preference, and the shortcuts again as `Shortcut_1..35` |
| `SketchUp 20xx/shortcuts.txt` | The shortcuts as readable lines. A REPORT — it diffs, so a change shows up in a commit. Not a restore source. |
| `SketchUp 2024/Templates/` | 5 templates, ~14 MB, including the Assembly Manual ones |

## What is deliberately NOT in here

- **`login_session.dat`** — the signed-in session. A credential, and it never
  goes in a repo.
- **`WebCache-*/`** — browser cache. Large and worthless.
- **`Plugins/`** — already here as `scripts/`, and `install-plugin.py` writes it.
  Two sources of truth for the same files is how they drift apart.
- **`Classifications/`** — the stock IFC files, identical on every install.

## A note on the templates

They are `.skp`, so git stores them whole on every change rather than as a diff —
14 MB now, and another 14 MB each time one is re-saved. Fine at this scale; worth
remembering before adding a lot more.
