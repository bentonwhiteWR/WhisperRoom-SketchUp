# QuickSnip

A fixed-region screen grab bound to a single key. Point it at the SketchUp
viewport once and every press captures that exact rectangle — no dragging, no
Snipping Tool, no cropping afterwards.

Built for the loop where you grab the same view repeatedly to paste into a
proposal, a message, or a Claude session.

## Hotkeys

| Key | Action |
|---|---|
| `F5` | Snip the saved region → clipboard **and** a timestamped PNG |
| `Shift+F5` | Set the region (drag a box, `Esc` keeps the current one) |
| `F6` | Open the snips folder |
| `Shift+F8` | Settings — rebind any of the above |

All four are rebindable from the settings window; changes apply on Save with no
restart.

## Running it

Needs [AutoHotkey v2](https://www.autohotkey.com/) (`winget install
AutoHotkey.AutoHotkey`). Then double-click `QuickSnip.ahk`, or run
`start-quicksnip.cmd`.

To have it always available, put a shortcut to `start-quicksnip.cmd` in
`shell:startup`.

## What happens on a snip

1. The region is captured to a memory bitmap before anything is drawn on
   screen — otherwise the feedback overlay lands inside your image.
2. A copy goes to the clipboard as `CF_BITMAP`; Windows synthesises the DIB
   formats, so it pastes into Outlook, Word, Slack and browsers.
3. A PNG is written via GDI+, named `snip-YYYY-MM-DD_HHMMSS.png`.
4. A thumbnail of what was grabbed appears over the region, then eases to the
   bottom-right corner and fades — so you know what is on the clipboard before
   you paste it.

Feedback is drawn by the script rather than using Windows tray balloons, which
play a notification sound that cannot be muted per-app.

## Configuration

`quicksnip.ini` sits next to the script and holds the region, the hotkeys and
the output folder. It is **gitignored** — the region is screen coordinates, so
it is specific to one machine's monitor layout. Set the region again on a new
machine with `Shift+F5`.

Snips default to `%USERPROFILE%\Pictures\QuickSnip`, deliberately outside the
repo. Change it in the settings window.
