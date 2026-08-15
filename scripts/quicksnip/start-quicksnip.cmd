@echo off
rem Launch QuickSnip with whichever AutoHotkey v2 install is present.
setlocal
set "AHK=%LOCALAPPDATA%\Programs\AutoHotkey\v2\AutoHotkey64.exe"
if not exist "%AHK%" set "AHK=%ProgramFiles%\AutoHotkey\v2\AutoHotkey64.exe"
if not exist "%AHK%" (
  echo AutoHotkey v2 not found. Install it with:
  echo     winget install AutoHotkey.AutoHotkey
  pause
  exit /b 1
)
start "" "%AHK%" "%~dp0QuickSnip.ahk"
