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
| `Shift+F5` | Set the snip region (drag a box, `Esc` keeps the current one) |
| `F6` | Start / stop recording the record region → MP4 |
| `Shift+F6` | Set the record region |
| `F7` | Open the snips folder |
| `Shift+F8` | Settings — rebind any of the above |

All of them are rebindable from the settings window; changes apply on Save with
no restart. Snipping and recording keep **separate** regions, so the clip area
and the still area do not have to match.

## Running it

Needs [AutoHotkey v2](https://www.autohotkey.com/) (`winget install
AutoHotkey.AutoHotkey`). Then double-click `QuickSnip.ahk`, or run
`start-quicksnip.cmd`.

Recording additionally needs ffmpeg (`winget install Gyan.FFmpeg`). Its path is
resolved once and cached in the ini, since the winget install path carries a
version number.

## What happens on a recording

`F6` starts, `F6` stops — one key, not two to remember. While it runs, a red
hairline frame sits just **outside** the region (so it never lands in the
picture) and a `REC 00:12` clock counts up beside it.

Three details that are easy to get wrong:

- ffmpeg is stopped by writing `q` to its stdin, not by killing it. A killed
  encoder leaves an MP4 with no index that most players refuse to open. The
  process is spawned through `CreateProcess` with a pipe on stdin, because
  `Run` cannot hand back a stdin handle and `WScript.Shell.Exec` cannot hide
  the console window.
- H.264 requires even dimensions, so the region is rounded down rather than
  allowed to fail with an ffmpeg error.
- On stop the file goes on the clipboard as `CF_HDROP`, so `Ctrl+V` pastes the
  **video itself** into Outlook or Explorer, not its path as text.

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
