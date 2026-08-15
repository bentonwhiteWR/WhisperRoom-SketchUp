#Requires AutoHotkey v2.0
#SingleInstance Force

; ─── QuickSnip ────────────────────────────────────────────────────────────
;   F5              capture the saved region -> clipboard + PNG in Snips\
;   F6              open the Snips folder
;   Shift+F5        redefine the region (drag a box, Esc to cancel)
;   Shift+F8        settings window - rebind any of the above
;
;   Defaults only; every hotkey is rebindable and stored in quicksnip.ini.
;
;   Settings live in quicksnip.ini next to this script, so the region and
;   the save folder survive restarts. Double-clicking the tray icon snips.
; ──────────────────────────────────────────────────────────────────────────

try DllCall("SetProcessDpiAwarenessContext", "ptr", -4)   ; per-monitor DPI aware

global ConfigFile := A_ScriptDir "\quicksnip.ini"
; Default the output outside the repo - generated PNGs do not belong in git.
global SaveFolder := IniRead(ConfigFile, "Settings", "SaveFolder",
                             EnvGet("USERPROFILE") "\Pictures\QuickSnip")
global SaveToFile := Integer(IniRead(ConfigFile, "Settings", "SaveToFile", "1"))
global AnimMs     := Integer(IniRead(ConfigFile, "Settings", "AnimMs", "1300"))
global AnimGui    := ""    ; live preview window, so a fast second snip can kill it
global ToastGui   := ""    ; silent status chip above the taskbar
global SettingsGui := ""   ; built once, then hidden/reshown
global Keys       := Map() ; action name -> hotkey string
global Bound      := Map() ; hotkey string -> callback, whatever is live right now

Persistent
LoadHotkeys()
ApplyHotkeys()

A_TrayMenu.Delete()
A_TrayMenu.Add("Snip now", DoSnip)
A_TrayMenu.Add("Open snips folder", DoOpenFolder)
A_TrayMenu.Add("Set region...", DoSetRegion)
A_TrayMenu.Add("Show current region", (*) => ShowRegionInfo())
A_TrayMenu.Add()
A_TrayMenu.Add("Settings...", DoSettings)
A_TrayMenu.Add("Reload", (*) => Reload())
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "Snip now"

if LoadRegion(&sx, &sy, &sw, &sh)
    Notify("Ready - region " sw "x" sh ". " Keys["Snip"] " to snip, " Keys["Settings"] " for settings.")
else {
    Notify("No region saved yet - drag a box to pick one.")
    SetTimer(DoSetRegion, -1500)
}

; ─── Hotkey registration ──────────────────────────────────────────────────

; Nothing is bound statically - every hotkey comes from the ini so the settings
; window can rewrite it without a restart.
LoadHotkeys() {
    global Keys, ConfigFile
    Keys := Map(
        "Snip",     IniRead(ConfigFile, "Hotkeys", "Snip",     "F5"),
        "Region",   IniRead(ConfigFile, "Hotkeys", "Region",   "+F5"),
        "Folder",   IniRead(ConfigFile, "Hotkeys", "Folder",   "F6"),
        "Settings", IniRead(ConfigFile, "Hotkeys", "Settings", "+F8"))
}

ActionMap() {
    return Map("Snip", DoSnip, "Region", DoSetRegion,
               "Folder", DoOpenFolder, "Settings", DoSettings)
}

ApplyHotkeys() {
    global Keys, Bound
    for hk, fn in Bound
        try Hotkey(hk, fn, "Off")
    Bound := Map()

    actions := ActionMap()
    failed := ""
    for name, hk in Keys {
        if (hk = "" || !actions.Has(name))
            continue
        try {
            Hotkey(hk, actions[name], "On")
            Bound[hk] := actions[name]
        } catch
            failed .= (failed ? ", " : "") hk
    }
    if failed
        Notify("Windows refused these hotkeys: " failed)
}


; ─── Actions ──────────────────────────────────────────────────────────────

DoSnip(*) {
    global SaveToFile
    KillPreview()          ; never let a previous preview land inside this capture
    KillToast()            ; ...or a lingering status chip

    if !LoadRegion(&x, &y, &w, &h) {
        Notify("No region set - press " Keys["Region"] " to pick one.")
        return
    }

    hbm := CaptureRegion(x, y, w, h)
    if !hbm {
        Notify("Capture failed.")
        return
    }

    ; Clipboard takes its own copy so we keep `hbm` for the file and the preview.
    onClipboard := PutBitmapOnClipboard(hbm)

    saved := ""
    if SaveToFile
        saved := SaveSnipToDisk(hbm, w, h)

    msg := onClipboard ? "Copied " w "x" h : "Clipboard busy - not copied"
    if saved
        msg .= " - saved " RegExReplace(saved, ".*\\")
    Notify(msg)

    ShowFlyAway(hbm, x, y, w, h)   ; consumes hbm
}

DoOpenFolder(*) {
    global SaveFolder
    EnsureFolder()
    Run('explorer.exe "' SaveFolder '"')
}

DoSetRegion(*) {
    global ConfigFile
    KillPreview()
    r := SelectRegion()
    if !IsObject(r) {
        Notify("Region unchanged.")
        return
    }
    IniWrite(r.x, ConfigFile, "Region", "X")
    IniWrite(r.y, ConfigFile, "Region", "Y")
    IniWrite(r.w, ConfigFile, "Region", "W")
    IniWrite(r.h, ConfigFile, "Region", "H")
    Notify("Region set: " r.w "x" r.h " at " r.x "," r.y)
    FlashRegion(r.x, r.y, r.w, r.h)
}

ShowRegionInfo() {
    if !LoadRegion(&x, &y, &w, &h) {
        Notify("No region set yet.")
        return
    }
    Notify("Region: " w "x" h " at " x "," y)
    FlashRegion(x, y, w, h)
}


; ─── Region storage ───────────────────────────────────────────────────────

LoadRegion(&x, &y, &w, &h) {
    global ConfigFile
    x := IniRead(ConfigFile, "Region", "X", "")
    y := IniRead(ConfigFile, "Region", "Y", "")
    w := IniRead(ConfigFile, "Region", "W", "")
    h := IniRead(ConfigFile, "Region", "H", "")
    if (x = "" || y = "" || w = "" || h = "")
        return false
    x := Integer(x), y := Integer(y), w := Integer(w), h := Integer(h)
    return (w > 0 && h > 0)
}

EnsureFolder() {
    global SaveFolder
    if !DirExist(SaveFolder)
        DirCreate(SaveFolder)
}


; ─── Drag-to-select overlay ───────────────────────────────────────────────

SelectRegion() {
    vx := SysGet(76), vy := SysGet(77)          ; virtual screen origin
    vw := SysGet(78), vh := SysGet(79)          ; virtual screen size

    ; Dimmer over every monitor.
    ov := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")   ; NOACTIVATE
    ov.BackColor := "000000"
    ov.Show("NoActivate x" vx " y" vy " w" vw " h" vh)
    WinSetTransparent(110, ov)

    ; Instructions live in their own opaque panel - text drawn inside the dimmer
    ; inherits its transparency and ends up too faint to read.
    tip := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000020")   ; + click-through
    tip.BackColor := "1B1B1B"
    tip.MarginX := 26, tip.MarginY := 18
    tip.SetFont("s14 bold cWhite", "Segoe UI")
    tip.AddText("BackgroundTrans Center w440", "Drag a box around the area you want to snip")
    tip.SetFont("s10 norm c9AA0A6", "Segoe UI")
    tip.AddText("BackgroundTrans Center w440 y+10",
        "This becomes the fixed area F5 captures from now on.`nPress Esc to keep the current one.")
    tip.Show("NoActivate AutoSize x-9000 y-9000")
    tip.GetPos(, , &tipW, &tipH)
    MonitorGetWorkArea(MonitorGetPrimary(), &pl, &pt, &pr, &pb)
    tip.Move((pl + pr - tipW) // 2, pt + 90)

    ; Live pixel readout that trails the cursor while dragging.
    dim := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000020")
    dim.BackColor := "1B1B1B"
    dim.MarginX := 10, dim.MarginY := 6
    dim.SetFont("s10 cWhite", "Consolas")
    dimTxt := dim.AddText("BackgroundTrans Center w120", "0 x 0")

    rect := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000020")
    rect.BackColor := "4DA3FF"

    CoordMode("Mouse", "Screen")
    result := ""

    loop {
        if GetKeyState("Escape", "P")
            break
        if GetKeyState("LButton", "P") {
            MouseGetPos(&x1, &y1)
            rect.Show("NoActivate x" x1 " y" y1 " w1 h1")
            WinSetTransparent(110, rect)
            dim.Show("NoActivate AutoSize x-9000 y-9000")
            dim.GetPos(, , &dimW, &dimH)

            while GetKeyState("LButton", "P") {
                MouseGetPos(&x2, &y2)
                rw := Max(Abs(x2 - x1), 1), rh := Max(Abs(y2 - y1), 1)
                rect.Move(Min(x1, x2), Min(y1, y2), rw, rh)
                dimTxt.Value := rw " x " rh
                dim.Move(Min(x2 + 18, vx + vw - dimW - 4),
                         Min(y2 + 18, vy + vh - dimH - 4))
                Sleep 8
            }

            MouseGetPos(&x2, &y2)
            fw := Abs(x2 - x1), fh := Abs(y2 - y1)
            if (fw >= 4 && fh >= 4)
                result := {x: Min(x1, x2), y: Min(y1, y2), w: fw, h: fh}
            break
        }
        Sleep 10
    }

    rect.Destroy()
    dim.Destroy()
    tip.Destroy()
    ov.Destroy()
    Sleep 80        ; let the overlay fully clear the screen before any capture
    return result
}


; ─── Capture ──────────────────────────────────────────────────────────────

CaptureRegion(x, y, w, h) {
    static SRCCOPY_CAPTUREBLT := 0x40CC0020

    hdcScreen := DllCall("GetDC", "ptr", 0, "ptr")
    hdcMem    := DllCall("CreateCompatibleDC", "ptr", hdcScreen, "ptr")
    hbm       := DllCall("CreateCompatibleBitmap", "ptr", hdcScreen,
                         "int", w, "int", h, "ptr")
    hbmOld    := DllCall("SelectObject", "ptr", hdcMem, "ptr", hbm, "ptr")

    DllCall("BitBlt", "ptr", hdcMem, "int", 0, "int", 0, "int", w, "int", h,
                      "ptr", hdcScreen, "int", x, "int", y,
                      "uint", SRCCOPY_CAPTUREBLT)

    DllCall("SelectObject", "ptr", hdcMem, "ptr", hbmOld)
    DllCall("DeleteDC", "ptr", hdcMem)
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdcScreen)
    return hbm
}

PutBitmapOnClipboard(hbm) {
    static CF_BITMAP := 2, IMAGE_BITMAP := 0

    copy := DllCall("CopyImage", "ptr", hbm, "uint", IMAGE_BITMAP,
                    "int", 0, "int", 0, "uint", 0, "ptr")
    if !copy
        return false

    opened := false
    loop 8 {                                   ; another app may hold the clipboard
        if DllCall("OpenClipboard", "ptr", 0) {
            opened := true
            break
        }
        Sleep 40
    }
    if !opened {
        DllCall("DeleteObject", "ptr", copy)
        return false
    }

    DllCall("EmptyClipboard")
    DllCall("SetClipboardData", "uint", CF_BITMAP, "ptr", copy)  ; clipboard owns it
    DllCall("CloseClipboard")
    return true
}


; ─── PNG output (GDI+) ────────────────────────────────────────────────────

GdipStartup() {
    static token := 0
    if token
        return token
    DllCall("LoadLibrary", "str", "gdiplus.dll")
    input := Buffer(24, 0)
    NumPut("uint", 1, input, 0)                ; GdiplusVersion
    DllCall("gdiplus\GdiplusStartup", "ptr*", &token, "ptr", input, "ptr", 0)
    return token
}

SaveSnipToDisk(hbm, w, h) {
    global SaveFolder
    EnsureFolder()
    path := SaveFolder "\snip-" FormatTime(A_Now, "yyyy-MM-dd_HHmmss") ".png"
    if FileExist(path)                         ; two snips inside one second
        path := SaveFolder "\snip-" FormatTime(A_Now, "yyyy-MM-dd_HHmmss")
                 . "-" A_MSec ".png"

    GdipStartup()
    pBitmap := 0
    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hbm, "ptr", 0, "ptr*", &pBitmap)
    if !pBitmap
        return ""

    clsid := Buffer(16, 0)                     ; PNG encoder
    DllCall("ole32\CLSIDFromString", "wstr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}",
            "ptr", clsid)
    status := DllCall("gdiplus\GdipSaveImageToFile", "ptr", pBitmap, "wstr", path,
                      "ptr", clsid, "ptr", 0)
    DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)
    return (status = 0) ? path : ""
}


; ─── "Flew to the corner" preview ─────────────────────────────────────────

; Shows a thumbnail of what was just grabbed and slides it to the bottom-right
; of the monitor the region lives on, fading out as it goes. Takes ownership of
; hbmFull and frees it.
ShowFlyAway(hbmFull, x, y, w, h) {
    global AnimGui, AnimMs
    static MAX_W := 340, MAX_H := 260, PAD := 24

    hbmThumb := MakeThumb(hbmFull, w, h, MAX_W, MAX_H, &tw, &th)
    DllCall("DeleteObject", "ptr", hbmFull)
    if !hbmThumb
        return

    GetWorkAreaFor(x + w // 2, y + h // 2, &ml, &mt, &mr, &mb)
    startX := x + (w - tw) // 2, startY := y + (h - th) // 2
    endX   := mr - tw - PAD,     endY   := mb - th - PAD - 46   ; clear of the status chip

    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000020")  ; NOACTIVATE + click-through
    g.MarginX := 0, g.MarginY := 0
    g.BackColor := "1E1E1E"
    g.AddPicture("x0 y0 w" tw " h" th, "HBITMAP:*" hbmThumb)    ; control owns hbmThumb
    g.Show("NoActivate x" startX " y" startY " w" tw " h" th)
    WinSetTransparent(255, g)
    AnimGui := g

    Sleep 180                                   ; beat of "here's what you got"
    t0 := A_TickCount
    loop {
        if (AnimGui !== g)                      ; a newer snip took over
            return
        p := (A_TickCount - t0) / AnimMs
        if (p >= 1)
            break
        e := 1 - (1 - p) ** 3                   ; ease-out
        g.Move(Round(startX + (endX - startX) * e), Round(startY + (endY - startY) * e))
        WinSetTransparent(Round(255 - 205 * e), g)
        Sleep 15
    }
    KillPreview()
}

KillPreview() {
    global AnimGui
    if IsObject(AnimGui) {
        try AnimGui.Destroy()
        AnimGui := ""
        Sleep 30                                ; make sure it is off-screen
    }
}

MakeThumb(hbmSrc, w, h, maxW, maxH, &tw, &th) {
    static SRCCOPY := 0x00CC0020, HALFTONE := 4

    scale := Min(maxW / w, maxH / h, 1.0)
    tw := Max(Round(w * scale), 1), th := Max(Round(h * scale), 1)

    hdcScreen := DllCall("GetDC", "ptr", 0, "ptr")
    hdcSrc := DllCall("CreateCompatibleDC", "ptr", hdcScreen, "ptr")
    hdcDst := DllCall("CreateCompatibleDC", "ptr", hdcScreen, "ptr")
    hbmDst := DllCall("CreateCompatibleBitmap", "ptr", hdcScreen,
                      "int", tw, "int", th, "ptr")
    oldS := DllCall("SelectObject", "ptr", hdcSrc, "ptr", hbmSrc, "ptr")
    oldD := DllCall("SelectObject", "ptr", hdcDst, "ptr", hbmDst, "ptr")

    DllCall("SetStretchBltMode", "ptr", hdcDst, "int", HALFTONE)
    DllCall("SetBrushOrgEx", "ptr", hdcDst, "int", 0, "int", 0, "ptr", 0)
    DllCall("StretchBlt", "ptr", hdcDst, "int", 0, "int", 0, "int", tw, "int", th,
                          "ptr", hdcSrc, "int", 0, "int", 0, "int", w, "int", h,
                          "uint", SRCCOPY)

    DllCall("SelectObject", "ptr", hdcSrc, "ptr", oldS)
    DllCall("SelectObject", "ptr", hdcDst, "ptr", oldD)
    DllCall("DeleteDC", "ptr", hdcSrc)
    DllCall("DeleteDC", "ptr", hdcDst)
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdcScreen)
    return hbmDst
}

GetWorkAreaFor(cx, cy, &l, &t, &r, &b) {
    loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &ml, &mt, &mr, &mb)
        if (cx >= ml && cx < mr && cy >= mt && cy < mb) {
            l := ml, t := mt, r := mr, b := mb
            return
        }
    }
    MonitorGetWorkArea(MonitorGetPrimary(), &l, &t, &r, &b)
}


; ─── Feedback ─────────────────────────────────────────────────────────────

FlashRegion(x, y, w, h) {
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000020")
    g.BackColor := "FFFFFF"
    g.Show("NoActivate x" x " y" y " w" w " h" h)
    WinSetTransparent(90, g)
    Sleep 110
    g.Destroy()
}

; A silent status chip that sits just above the taskbar, bottom-right. Windows
; tray balloons play a notification sound and there is no reliable way to mute
; them per-app, so we draw our own instead.
Notify(text, ms := 1800) {
    global ToastGui
    KillToast()

    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000020")  ; NOACTIVATE + click-through
    g.BackColor := "1B1B1B"
    g.MarginX := 14, g.MarginY := 9
    g.SetFont("s10 cWhite", "Segoe UI")
    g.AddText("BackgroundTrans", text)
    g.Show("NoActivate AutoSize x-9000 y-9000")      ; size it off-screen first
    g.GetPos(, , &gw, &gh)

    MonitorGetWorkArea(MonitorGetPrimary(), &ml, &mt, &mr, &mb)
    g.Move(mr - gw - 16, mb - gh - 12)
    WinSetTransparent(230, g)

    ToastGui := g
    SetTimer(KillToast, -ms)
}

KillToast(*) {
    global ToastGui
    if IsObject(ToastGui) {
        try ToastGui.Destroy()
        ToastGui := ""
    }
}


; ─── Settings window ──────────────────────────────────────────────────────

DoSettings(*) {
    global SettingsGui, Keys, SaveFolder, SaveToFile, AnimMs

    if IsObject(SettingsGui) {                  ; already built - just bring it back
        try {
            SettingsGui.Show()
            WinActivate("ahk_id " SettingsGui.Hwnd)
            return
        }
        SettingsGui := ""
    }

    ; Native colours on purpose: a custom BackColor behind themed Win32 controls
    ; is where checkbox/button rendering starts fighting back.
    g := Gui("+AlwaysOnTop +OwnDialogs", "QuickSnip Settings")
    g.MarginX := 20, g.MarginY := 16

    g.SetFont("s12 bold", "Segoe UI")
    g.AddText("", "Hotkeys")
    g.SetFont("s9 norm c606060", "Segoe UI")
    g.AddText("y+4 w420",
        "Click a field and press the combination you want. Changes apply on Save - no restart.")

    g.SetFont("s10 norm c000000", "Segoe UI")
    ctl := Map()
    for row in [["Snip", "Snip the region"], ["Region", "Set the region"],
                ["Folder", "Open snips folder"], ["Settings", "Open this window"]] {
        g.AddText("xm y+12 w170 h23 0x200", row[2])              ; 0x200 = vcenter
        ctl[row[1]] := g.AddHotkey("x+10 yp w200", Keys[row[1]])
    }

    g.SetFont("s12 bold", "Segoe UI")
    g.AddText("xm y+22", "Saving")
    g.SetFont("s10 norm", "Segoe UI")

    g.AddText("xm y+12 w170 h23 0x200", "Snips folder")
    edFolder := g.AddEdit("x+10 yp w200 ReadOnly", SaveFolder)
    btnBrowse := g.AddButton("x+8 yp-1 w90", "Browse...")

    cbSave := g.AddCheckbox("xm y+14 Checked" (SaveToFile ? 1 : 0),
        "Save a PNG of every snip (uncheck for clipboard only)")

    g.AddText("xm y+14 w170 h23 0x200", "Fly-away length")
    edAnim := g.AddEdit("x+10 yp w80 Number", AnimMs)
    g.SetFont("s9 c606060", "Segoe UI")
    g.AddText("x+8 yp+4", "milliseconds")

    g.SetFont("s12 bold", "Segoe UI")
    g.AddText("xm y+22", "Capture region")
    g.SetFont("s10 norm", "Segoe UI")
    txtRegion := g.AddText("xm y+12 w240 h25 0x200", RegionSummary())
    btnPick := g.AddButton("x+10 yp-1 w140", "Pick region...")

    btnSave := g.AddButton("xm y+26 w120 Default", "Save")
    btnCancel := g.AddButton("x+10 w120", "Cancel")

    btnBrowse.OnEvent("Click", (*) => BrowseSnipFolder(edFolder))
    btnPick.OnEvent("Click", (*) => PickRegionFromSettings(g, txtRegion))
    btnSave.OnEvent("Click", (*) => SaveSettings(g, ctl, edFolder, cbSave, edAnim))
    btnCancel.OnEvent("Click", (*) => g.Hide())
    g.OnEvent("Escape", (*) => g.Hide())
    g.OnEvent("Close", (*) => g.Hide())

    SettingsGui := g
    g.Show("AutoSize Center")
}

RegionSummary() {
    if LoadRegion(&x, &y, &w, &h)
        return w " x " h " at " x "," y
    return "not set yet"
}

BrowseSnipFolder(edFolder) {
    picked := DirSelect("*" edFolder.Value, 3, "Where should snips be saved?")
    if picked
        edFolder.Value := picked
}

PickRegionFromSettings(g, txtRegion) {
    g.Hide()                                    ; the window would land in the shot
    Sleep 150
    DoSetRegion()
    txtRegion.Value := RegionSummary()
    g.Show()
}

SaveSettings(g, ctl, edFolder, cbSave, edAnim) {
    global Keys, ConfigFile, SaveFolder, SaveToFile, AnimMs

    ; Validate everything before writing anything, so a bad field cannot leave
    ; the script half-rebound.
    seen := Map(), fresh := Map()
    for name, c in ctl {
        combo := Trim(c.Value)
        if (combo = "") {
            MsgBox("Every action needs a hotkey.`n`nMissing: " name, "QuickSnip", 0x1030)
            return
        }
        if seen.Has(combo) {
            MsgBox(combo " is assigned to two actions.`n`nPick a different combination.",
                   "QuickSnip", 0x1030)
            return
        }
        try
            Hotkey(combo, NoOp, "Off")          ; will throw if Windows won't allow it
        catch {
            MsgBox("Windows will not let QuickSnip use " combo ".`n`nTry another one.",
                   "QuickSnip", 0x1030)
            return
        }
        seen[combo] := true, fresh[name] := combo
    }

    folder := Trim(edFolder.Value)
    if (folder = "") {
        MsgBox("Pick a folder for saved snips.", "QuickSnip", 0x1030)
        return
    }

    Keys := fresh
    for name, combo in Keys
        IniWrite(combo, ConfigFile, "Hotkeys", name)

    SaveFolder := folder
    SaveToFile := cbSave.Value
    AnimMs     := Max(Integer(edAnim.Value = "" ? 1300 : edAnim.Value), 200)
    IniWrite(SaveFolder, ConfigFile, "Settings", "SaveFolder")
    IniWrite(SaveToFile, ConfigFile, "Settings", "SaveToFile")
    IniWrite(AnimMs,     ConfigFile, "Settings", "AnimMs")

    ApplyHotkeys()
    g.Hide()
    Notify("Saved - " Keys["Snip"] " snips, " Keys["Region"] " sets the region")
}

NoOp(*) {
}
