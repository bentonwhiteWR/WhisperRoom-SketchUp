#Requires AutoHotkey v2.0
#SingleInstance Force

; ─── QuickSnip ────────────────────────────────────────────────────────────
;   F5              capture region A -> clipboard + PNG
;   Shift+F5        redefine region A (drag a box, Esc to cancel)
;   F6              start / stop recording the record region -> MP4
;   Shift+F6        redefine the record region
;   F7              add a frame to a burst (starts one if none is running)
;   Shift+F7        finish the burst -> contact sheet + full-size frames
;   F8              open the snips folder
;   Shift+F8        settings window - rebind any of the above
;
;   Defaults only; every hotkey is rebindable and stored in quicksnip.ini.
;
;   Recording shells out to ffmpeg's gdigrab, because AutoHotkey can capture
;   a bitmap but cannot encode video. ffmpeg is stopped by writing "q" to its
;   stdin rather than killing it - a killed encoder leaves a file with no
;   index, which most players refuse to open.
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

; Resolved once and cached in the ini - the winget path carries a version
; number, so hunting for it on every start would be wasted work.
global FfmpegPath := IniRead(ConfigFile, "Settings", "Ffmpeg", "")
if (FfmpegPath = "") {
    FfmpegPath := FindFfmpeg()
    IniWrite(FfmpegPath, ConfigFile, "Settings", "Ffmpeg")
}
global RecFps     := Integer(IniRead(ConfigFile, "Settings", "RecFps", "30"))
global RecActive  := false
global RecProc    := 0     ; process handle
global RecThread  := 0     ; thread handle from CreateProcess
global RecStdIn   := 0     ; write end of the pipe - how we ask ffmpeg to stop
global RecPath    := ""    ; file being written
global RecStart   := 0     ; tick count at start
global RecBadge   := ""    ; the "REC 00:12" readout
global RecEdges   := []    ; four hairlines drawn just outside the region

global BurstMax      := Integer(IniRead(ConfigFile, "Settings", "BurstMax", "12"))
global BurstInterval := Integer(IniRead(ConfigFile, "Settings", "BurstInterval", "0"))
global BurstActive   := false
global BurstFrames   := []   ; captured bitmaps, held until the sheet is built
global BurstTimes    := []   ; seconds since the burst started, per frame
global BurstStart    := 0
global BurstBadge    := ""

Persistent
OnExit(FinishRecordingOnExit)      ; never leave a half-written MP4 behind
LoadHotkeys()
ApplyHotkeys()

A_TrayMenu.Delete()
A_TrayMenu.Add("Snip now", DoSnip)
A_TrayMenu.Add("Open snips folder", DoOpenFolder)
A_TrayMenu.Add("Set region...", (*) => DoSetRegion("Region"))
A_TrayMenu.Add("Start / stop recording", DoRecordToggle)
A_TrayMenu.Add("Set record region...", (*) => DoSetRegion("RecRegion"))
A_TrayMenu.Add("Add burst frame", DoBurstFrame)
A_TrayMenu.Add("Finish burst", DoBurstFinish)
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

    ; The snips folder has been pushed along twice as capture keys claimed F6
    ; and then F7. Migrate rather than making the user resolve a clash.
    if (IniRead(ConfigFile, "Hotkeys", "Folder", "") = "F6")
        IniWrite("F7", ConfigFile, "Hotkeys", "Folder")
    if (IniRead(ConfigFile, "Hotkeys", "Folder", "") = "F7")
        IniWrite("F8", ConfigFile, "Hotkeys", "Folder")

    Keys := Map(
        "Snip",      IniRead(ConfigFile, "Hotkeys", "Snip",      "F5"),
        "Region",    IniRead(ConfigFile, "Hotkeys", "Region",    "+F5"),
        "Record",    IniRead(ConfigFile, "Hotkeys", "Record",    "F6"),
        "RecRegion", IniRead(ConfigFile, "Hotkeys", "RecRegion", "+F6"),
        "Burst",     IniRead(ConfigFile, "Hotkeys", "Burst",     "F7"),
        "BurstEnd",  IniRead(ConfigFile, "Hotkeys", "BurstEnd",  "+F7"),
        "Folder",    IniRead(ConfigFile, "Hotkeys", "Folder",    "F8"),
        "Settings",  IniRead(ConfigFile, "Hotkeys", "Settings",  "+F8"))
}

ActionMap() {
    return Map("Snip", DoSnip, "Region", (*) => DoSetRegion("Region"),
               "Record", DoRecordToggle, "RecRegion", (*) => DoSetRegion("RecRegion"),
               "Burst", DoBurstFrame, "BurstEnd", DoBurstFinish,
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

DoSetRegion(section := "Region") {
    global ConfigFile
    if (section = "RecRegion" && RecActive) {
        Notify("Stop the recording first.")
        return
    }
    KillPreview()
    r := SelectRegion(section)
    if !IsObject(r) {
        Notify("Region unchanged.")
        return
    }
    IniWrite(r.x, ConfigFile, section, "X")
    IniWrite(r.y, ConfigFile, section, "Y")
    IniWrite(r.w, ConfigFile, section, "W")
    IniWrite(r.h, ConfigFile, section, "H")
    Notify((section = "RecRegion" ? "Record region" : "Region") " set: " r.w "x" r.h)
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

LoadRegion(&x, &y, &w, &h, section := "Region") {
    global ConfigFile
    x := IniRead(ConfigFile, section, "X", "")
    y := IniRead(ConfigFile, section, "Y", "")
    w := IniRead(ConfigFile, section, "W", "")
    h := IniRead(ConfigFile, section, "H", "")
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

SelectRegion(section := "Region") {
    vx := SysGet(76), vy := SysGet(77)          ; virtual screen origin
    vw := SysGet(78), vh := SysGet(79)          ; virtual screen size
    recording := (section = "RecRegion")

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
    if recording {
        headline := "Drag a box around the area you want to record"
        subline  := "This becomes the fixed area " Keys["Record"] " records."
    } else {
        headline := "Drag a box around the area you want to snip"
        subline  := "This becomes the fixed area " Keys["Snip"] " captures."
    }
    subline .= "`nPress Esc to keep the current one."

    tip.SetFont("s14 bold cWhite", "Segoe UI")
    tip.AddText("BackgroundTrans Center w440", headline)
    tip.SetFont("s10 norm c9AA0A6", "Segoe UI")
    tip.AddText("BackgroundTrans Center w440 y+10", subline)
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

    return SaveBitmapPng(hbm, path) ? path : ""
}

SaveBitmapPng(hbm, path) {
    GdipStartup()
    pBitmap := 0
    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hbm, "ptr", 0, "ptr*", &pBitmap)
    if !pBitmap
        return false

    clsid := Buffer(16, 0)                     ; PNG encoder
    DllCall("ole32\CLSIDFromString", "wstr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}",
            "ptr", clsid)
    status := DllCall("gdiplus\GdipSaveImageToFile", "ptr", pBitmap, "wstr", path,
                      "ptr", clsid, "ptr", 0)
    DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)
    return (status = 0)
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


; ─── Burst -> contact sheet ───────────────────────────────────────────────
;
; Frames are taken by hand rather than on a timer, because the thing worth
; capturing is usually a sequence of UI steps, and those happen when you do
; them. Set BurstInterval above zero in the ini for a timed burst instead.
;
; Both outputs are kept: the stitched sheet is what you paste, and the
; full-size frames survive alongside it, because tiling six frames into one
; image leaves each of them too small to read.

DoBurstFrame(*) {
    global BurstActive
    if !BurstActive
        StartBurst()
    AddBurstFrame()
}

StartBurst() {
    global BurstActive, BurstFrames, BurstTimes, BurstStart, BurstInterval

    if !LoadRegion(&x, &y, &w, &h) {
        Notify("No region set - press " Keys["Region"] " to pick one.")
        return
    }
    BurstActive := true
    BurstFrames := [], BurstTimes := []
    BurstStart := A_TickCount

    ShowBurstBadge(x, y)
    Hotkey("~Escape", BurstEscape, "On")        ; ~ so Esc still reaches the app
    if (BurstInterval > 0)
        SetTimer(BurstTick, BurstInterval * 1000)
    SetTimer(BurstIdleCheck, 5000)
}

AddBurstFrame() {
    global BurstFrames, BurstTimes, BurstStart, BurstMax

    if !LoadRegion(&x, &y, &w, &h)
        return
    KillPreview(), KillToast()

    hbm := CaptureRegion(x, y, w, h)
    if !hbm
        return
    BurstFrames.Push(hbm)
    BurstTimes.Push(Round((A_TickCount - BurstStart) / 1000))
    UpdateBurstBadge()
    FlashRegion(x, y, w, h)                     ; a beat of feedback per frame

    if (BurstFrames.Length >= BurstMax)
        DoBurstFinish()
}

BurstTick() {
    global BurstActive
    if BurstActive
        AddBurstFrame()
}

BurstEscape(*) {
    global BurstActive
    if BurstActive
        DoBurstFinish()
}

; Safety net: a burst you walked away from finishes itself rather than holding
; a pile of bitmaps open forever.
BurstIdleCheck() {
    global BurstActive, BurstTimes, BurstStart
    if !BurstActive
        return
    last := BurstTimes.Length ? BurstTimes[BurstTimes.Length] : 0
    if ((A_TickCount - BurstStart) / 1000 - last > 90)
        DoBurstFinish()
}

DoBurstFinish(*) {
    global BurstActive, BurstFrames, BurstTimes, SaveFolder

    if !BurstActive
        return
    BurstActive := false
    SetTimer(BurstTick, 0)
    SetTimer(BurstIdleCheck, 0)
    try Hotkey("~Escape", BurstEscape, "Off")
    HideBurstBadge()

    n := BurstFrames.Length
    if !n {
        Notify("Burst cancelled - no frames.")
        return
    }

    LoadRegion(&rx, &ry, &rw, &rh)
    stamp := FormatTime(A_Now, "yyyy-MM-dd_HHmmss")

    ; Full-size originals first, so nothing is lost if the stitch fails.
    EnsureFolder()
    dir := SaveFolder "\burst-" stamp
    try DirCreate(dir)
    saved := 0
    for i, hbm in BurstFrames {
        if SaveBitmapPng(hbm, Format("{1}\frame-{2:02}.png", dir, i))
            saved++
    }

    sheet := MakeContactSheet(BurstFrames, BurstTimes, rw, rh)
    for hbm in BurstFrames
        DllCall("DeleteObject", "ptr", hbm)
    BurstFrames := [], BurstTimes := []

    if !sheet {
        Notify("Saved " saved " frames, but the sheet could not be built.")
        return
    }

    sheetPath := SaveFolder "\burst-" stamp ".png"
    PutBitmapOnClipboard(sheet)                 ; takes its own copy
    SaveBitmapPng(sheet, sheetPath)
    Notify(n " frames - sheet on clipboard, originals in burst-" stamp)
    ShowFlyAway(sheet, rx, ry, rw, rh)          ; consumes sheet
}

; Tiles the frames into one image with a numbered, time-stamped caption above
; each. Never upscales - a small region stays small rather than going soft.
MakeContactSheet(frames, times, srcW, srcH) {
    static SRCCOPY := 0x00CC0020, HALFTONE := 4, TARGET_W := 1600
    static PAD := 14, LABEL_H := 26

    n := frames.Length
    if (!n || srcW < 1 || srcH < 1)
        return 0

    cols := Min(Ceil(Sqrt(n)), 4)
    rows := Ceil(n / cols)

    cellW := Floor((TARGET_W - PAD * (cols + 1)) / cols)
    cellW := Max(Min(cellW, srcW), 80)
    cellH := Max(Floor(cellW * srcH / srcW), 40)

    sheetW := cellW * cols + PAD * (cols + 1)
    sheetH := (cellH + LABEL_H) * rows + PAD * (rows + 1)

    hdcScreen := DllCall("GetDC", "ptr", 0, "ptr")
    hdcSheet  := DllCall("CreateCompatibleDC", "ptr", hdcScreen, "ptr")
    hbmSheet  := DllCall("CreateCompatibleBitmap", "ptr", hdcScreen,
                         "int", sheetW, "int", sheetH, "ptr")
    oldSheet  := DllCall("SelectObject", "ptr", hdcSheet, "ptr", hbmSheet, "ptr")

    rc := Buffer(16, 0)
    NumPut("int", 0, "int", 0, "int", sheetW, "int", sheetH, rc)
    brush := DllCall("CreateSolidBrush", "uint", 0x1E1E1E, "ptr")   ; BGR
    DllCall("FillRect", "ptr", hdcSheet, "ptr", rc, "ptr", brush)
    DllCall("DeleteObject", "ptr", brush)

    font := DllCall("CreateFontW", "int", -15, "int", 0, "int", 0, "int", 0,
                    "int", 600, "uint", 0, "uint", 0, "uint", 0, "uint", 1,
                    "uint", 0, "uint", 0, "uint", 4, "uint", 0,
                    "wstr", "Segoe UI", "ptr")
    oldFont := DllCall("SelectObject", "ptr", hdcSheet, "ptr", font, "ptr")
    DllCall("SetBkMode", "ptr", hdcSheet, "int", 1)                 ; TRANSPARENT
    DllCall("SetTextColor", "ptr", hdcSheet, "uint", 0xC9C9C9)

    hdcSrc := DllCall("CreateCompatibleDC", "ptr", hdcScreen, "ptr")
    DllCall("SetStretchBltMode", "ptr", hdcSheet, "int", HALFTONE)
    DllCall("SetBrushOrgEx", "ptr", hdcSheet, "int", 0, "int", 0, "ptr", 0)

    for i, hbm in frames {
        col := Mod(i - 1, cols), row := (i - 1) // cols
        cx := PAD + col * (cellW + PAD)
        cy := PAD + row * (cellH + LABEL_H + PAD)

        label := Format("{1}  ·  +{2}s", i, times.Has(i) ? times[i] : 0)
        DllCall("TextOutW", "ptr", hdcSheet, "int", cx + 2, "int", cy + 4,
                "wstr", label, "int", StrLen(label))

        oldSrc := DllCall("SelectObject", "ptr", hdcSrc, "ptr", hbm, "ptr")
        DllCall("StretchBlt", "ptr", hdcSheet, "int", cx, "int", cy + LABEL_H,
                              "int", cellW, "int", cellH,
                              "ptr", hdcSrc, "int", 0, "int", 0,
                              "int", srcW, "int", srcH, "uint", SRCCOPY)
        DllCall("SelectObject", "ptr", hdcSrc, "ptr", oldSrc)
    }

    DllCall("DeleteDC", "ptr", hdcSrc)
    DllCall("SelectObject", "ptr", hdcSheet, "ptr", oldFont)
    DllCall("DeleteObject", "ptr", font)
    DllCall("SelectObject", "ptr", hdcSheet, "ptr", oldSheet)
    DllCall("DeleteDC", "ptr", hdcSheet)
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdcScreen)
    return hbmSheet
}

ShowBurstBadge(x, y) {
    global BurstBadge
    HideBurstBadge()
    b := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000020")
    b.BackColor := "1B1B1B"
    b.MarginX := 12, b.MarginY := 7
    b.SetFont("s10 bold c4DA3FF", "Consolas")
    b.txt := b.AddText("BackgroundTrans w150", "BURST  0/" BurstMax)
    b.Show("NoActivate AutoSize x-9000 y-9000")
    b.GetPos(, , &bw, &bh)
    b.Move(x, Max(y - bh - 6, 0))
    WinSetTransparent(235, b)
    BurstBadge := b
}

UpdateBurstBadge() {
    global BurstBadge, BurstFrames, BurstMax
    if !IsObject(BurstBadge)
        return
    try BurstBadge.txt.Value := "BURST  " BurstFrames.Length "/" BurstMax
}

HideBurstBadge() {
    global BurstBadge
    if IsObject(BurstBadge) {
        try BurstBadge.Destroy()
        BurstBadge := ""
        Sleep 30
    }
}


; ─── Screen recording ─────────────────────────────────────────────────────

FindFfmpeg() {
    if (found := FileExist("ffmpeg.exe") ? "ffmpeg.exe" : "")
        return found
    for base in [EnvGet("LOCALAPPDATA") "\Microsoft\WinGet\Packages",
                 EnvGet("ProgramFiles") "\ffmpeg\bin"] {
        loop files, base "\*ffmpeg.exe", "FR" {
            return A_LoopFileFullPath
        }
    }
    return "ffmpeg.exe"                        ; fall back to PATH
}

DoRecordToggle(*) {
    global RecActive
    if RecActive
        StopRecording()
    else
        StartRecording()
}

FinishRecordingOnExit(*) {
    global RecActive, BurstActive
    if RecActive
        StopRecording()
    if BurstActive
        DoBurstFinish()
}

StartRecording() {
    global RecActive, RecPath, RecStart, FfmpegPath, RecFps

    if !LoadRegion(&x, &y, &w, &h, "RecRegion") {
        Notify("No record region yet - press " Keys["RecRegion"] " to pick one.")
        return
    }

    ; H.264 needs even dimensions. Round down rather than let ffmpeg fail with
    ; an error the user would have to go looking for.
    w -= Mod(w, 2), h -= Mod(h, 2)
    if (w < 2 || h < 2) {
        Notify("Record region is too small.")
        return
    }

    EnsureFolder()
    RecPath := SaveFolder "\rec-" FormatTime(A_Now, "yyyy-MM-dd_HHmmss") ".mp4"

    cmd := '"' FfmpegPath '" -hide_banner -loglevel error -y'
         . ' -f gdigrab -framerate ' RecFps
         . ' -offset_x ' x ' -offset_y ' y ' -video_size ' w 'x' h
         . ' -draw_mouse 1 -i desktop'
         . ' -c:v libx264 -preset veryfast -crf 22 -pix_fmt yuv420p'
         . ' -movflags +faststart "' RecPath '"'

    if !SpawnWithStdin(cmd) {
        Notify("Could not start ffmpeg - check the path in settings.")
        return
    }

    RecActive := true
    RecStart := A_TickCount
    ShowRecIndicator(x, y, w, h)
    SetTimer(TickRecIndicator, 500)
}

StopRecording() {
    global RecActive, RecProc, RecThread, RecStdIn, RecPath

    SetTimer(TickRecIndicator, 0)
    RecActive := false

    ; "q" on stdin is ffmpeg's graceful stop: it flushes and writes the moov
    ; atom. TerminateProcess would leave an unplayable file.
    if RecStdIn {
        q := Buffer(1, 0)
        NumPut("uchar", 0x71, q, 0)             ; 'q'
        written := 0
        DllCall("WriteFile", "ptr", RecStdIn, "ptr", q, "uint", 1,
                "uint*", &written, "ptr", 0)
        DllCall("FlushFileBuffers", "ptr", RecStdIn)
    }

    finished := false
    if RecProc
        finished := (DllCall("WaitForSingleObject", "ptr", RecProc, "uint", 6000) = 0)

    if (!finished && RecProc) {
        DllCall("TerminateProcess", "ptr", RecProc, "uint", 1)
        DllCall("WaitForSingleObject", "ptr", RecProc, "uint", 2000)
    }

    if RecStdIn
        DllCall("CloseHandle", "ptr", RecStdIn)
    if RecThread
        DllCall("CloseHandle", "ptr", RecThread)
    if RecProc
        DllCall("CloseHandle", "ptr", RecProc)
    RecStdIn := 0, RecThread := 0, RecProc := 0

    HideRecIndicator()

    secs := Round((A_TickCount - RecStart) / 1000)
    if (FileExist(RecPath) && FileGetSize(RecPath) > 0) {
        PutFileOnClipboard(RecPath)             ; Ctrl+V now pastes the video file
        Notify("Recorded " FormatSecs(secs) " - " RegExReplace(RecPath, ".*\\")
               . (finished ? " - on clipboard" : " - forced stop, check the file"))
    } else {
        Notify("Recording produced no file.")
    }
}

; CreateProcess with an inherited pipe on stdin. Run() cannot give us a stdin
; handle, and WScript.Shell.Exec cannot hide the console window - this does both.
SpawnWithStdin(cmdLine) {
    global RecProc, RecThread, RecStdIn
    static CREATE_NO_WINDOW := 0x08000000, STARTF_USESTDHANDLES := 0x100

    sa := Buffer(24, 0)                         ; SECURITY_ATTRIBUTES
    NumPut("uint", 24, sa, 0)
    NumPut("ptr", 0, sa, 8)
    NumPut("int", 1, sa, 16)                    ; bInheritHandle

    hRead := 0, hWrite := 0
    if !DllCall("CreatePipe", "ptr*", &hRead, "ptr*", &hWrite, "ptr", sa, "uint", 0)
        return false
    DllCall("SetHandleInformation", "ptr", hWrite, "uint", 1, "uint", 0)  ; keep our end private

    ; Send ffmpeg's chatter to NUL; an unread pipe would fill and stall it.
    hNul := DllCall("CreateFileW", "wstr", "NUL", "uint", 0x40000000, "uint", 3,
                    "ptr", sa, "uint", 3, "uint", 0, "ptr", 0, "ptr")

    si := Buffer(104, 0)                        ; STARTUPINFOW (x64)
    NumPut("uint", 104, si, 0)
    NumPut("uint", STARTF_USESTDHANDLES, si, 60)
    NumPut("ptr", hRead, si, 80)                ; hStdInput
    NumPut("ptr", hNul,  si, 88)                ; hStdOutput
    NumPut("ptr", hNul,  si, 96)                ; hStdError

    pi := Buffer(24, 0)                         ; PROCESS_INFORMATION
    sz := StrPut(cmdLine, "UTF-16") * 2
    buf := Buffer(sz, 0)                        ; CreateProcessW may write to this
    StrPut(cmdLine, buf, "UTF-16")

    ok := DllCall("CreateProcessW", "ptr", 0, "ptr", buf, "ptr", 0, "ptr", 0,
                  "int", 1, "uint", CREATE_NO_WINDOW, "ptr", 0, "ptr", 0,
                  "ptr", si, "ptr", pi)

    DllCall("CloseHandle", "ptr", hRead)        ; the child owns its copy now
    DllCall("CloseHandle", "ptr", hNul)

    if !ok {
        DllCall("CloseHandle", "ptr", hWrite)
        return false
    }

    RecProc   := NumGet(pi, 0, "ptr")
    RecThread := NumGet(pi, 8, "ptr")
    RecStdIn  := hWrite
    return true
}

; Four hairlines just OUTSIDE the region, so the indicator never lands in the
; frame, plus a running clock.
ShowRecIndicator(x, y, w, h) {
    global RecEdges, RecBadge
    static T := 3

    HideRecIndicator()
    for spec in [[x - T, y - T, w + T * 2, T], [x - T, y + h, w + T * 2, T],
                 [x - T, y, T, h], [x + w, y, T, h]] {
        e := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000020")
        e.BackColor := "D6453C"
        e.Show("NoActivate x" spec[1] " y" spec[2] " w" spec[3] " h" spec[4])
        WinSetTransparent(220, e)
        RecEdges.Push(e)
    }

    b := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000020")
    b.BackColor := "1B1B1B"
    b.MarginX := 12, b.MarginY := 7
    b.SetFont("s10 bold cD6453C", "Consolas")
    b.txt := b.AddText("BackgroundTrans w120", "REC  00:00")
    b.Show("NoActivate AutoSize x-9000 y-9000")
    b.GetPos(, , &bw, &bh)
    b.Move(x, Max(y - bh - T - 4, 0))
    WinSetTransparent(235, b)
    RecBadge := b
}

TickRecIndicator() {
    global RecBadge, RecStart
    if !IsObject(RecBadge)
        return
    try RecBadge.txt.Value := "REC  " FormatSecs(Round((A_TickCount - RecStart) / 1000))
}

HideRecIndicator() {
    global RecEdges, RecBadge
    for e in RecEdges
        try e.Destroy()
    RecEdges := []
    if IsObject(RecBadge) {
        try RecBadge.Destroy()
        RecBadge := ""
    }
    Sleep 30
}

FormatSecs(s) {
    return Format("{:02}:{:02}", s // 60, Mod(s, 60))
}

; Puts the file itself on the clipboard (CF_HDROP), so Ctrl+V in Outlook or
; Explorer pastes the video rather than its path as text.
PutFileOnClipboard(path) {
    static CF_HDROP := 15, DROPFILES := 20

    chars := StrLen(path)
    total := DROPFILES + (chars + 2) * 2        ; double-null terminated
    hMem := DllCall("GlobalAlloc", "uint", 0x42, "ptr", total, "ptr")   ; MOVEABLE|ZEROINIT
    if !hMem
        return false
    ptr := DllCall("GlobalLock", "ptr", hMem, "ptr")
    NumPut("uint", DROPFILES, ptr, 0)           ; offset to the file list
    NumPut("int", 1, ptr, 16)                   ; fWide = TRUE
    StrPut(path, ptr + DROPFILES, chars + 1, "UTF-16")
    DllCall("GlobalUnlock", "ptr", hMem)

    if !OpenClipboardRetry() {
        DllCall("GlobalFree", "ptr", hMem)
        return false
    }
    DllCall("EmptyClipboard")
    DllCall("SetClipboardData", "uint", CF_HDROP, "ptr", hMem)
    DllCall("CloseClipboard")
    return true
}

OpenClipboardRetry() {
    loop 8 {
        if DllCall("OpenClipboard", "ptr", 0)
            return true
        Sleep 40
    }
    return false
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
                ["Record", "Start / stop recording"], ["RecRegion", "Set the record region"],
                ["Burst", "Add a burst frame"], ["BurstEnd", "Finish the burst"],
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
    g.AddText("xm y+22", "Recording")
    g.SetFont("s10 norm", "Segoe UI")

    g.AddText("xm y+12 w170 h23 0x200", "ffmpeg")
    edFfmpeg := g.AddEdit("x+10 yp w200", FfmpegPath)
    btnFfmpeg := g.AddButton("x+8 yp-1 w90", "Browse...")

    g.AddText("xm y+12 w170 h23 0x200", "Frame rate")
    edFps := g.AddEdit("x+10 yp w80 Number", RecFps)
    g.SetFont("s9 c606060", "Segoe UI")
    g.AddText("x+8 yp+4", "fps")
    g.SetFont("s10 norm c000000", "Segoe UI")

    g.SetFont("s12 bold", "Segoe UI")
    g.AddText("xm y+22", "Burst")
    g.SetFont("s10 norm", "Segoe UI")

    g.AddText("xm y+12 w170 h23 0x200", "Max frames")
    edBurstMax := g.AddEdit("x+10 yp w80 Number", BurstMax)

    g.AddText("xm y+12 w170 h23 0x200", "Auto interval")
    edBurstInt := g.AddEdit("x+10 yp w80 Number", BurstInterval)
    g.SetFont("s9 c606060", "Segoe UI")
    g.AddText("x+8 yp+4", "seconds - 0 means capture by hand")
    g.SetFont("s10 norm c000000", "Segoe UI")

    g.SetFont("s12 bold", "Segoe UI")
    g.AddText("xm y+22", "Regions")
    g.SetFont("s10 norm", "Segoe UI")
    g.AddText("xm y+12 w80 h25 0x200", "Snip")
    txtRegion := g.AddText("x+6 yp w200 h25 0x200", RegionSummary("Region"))
    btnPick := g.AddButton("x+10 yp-1 w140", "Pick region...")

    g.AddText("xm y+8 w80 h25 0x200", "Record")
    txtRecRegion := g.AddText("x+6 yp w200 h25 0x200", RegionSummary("RecRegion"))
    btnPickRec := g.AddButton("x+10 yp-1 w140", "Pick region...")

    btnSave := g.AddButton("xm y+26 w120 Default", "Save")
    btnCancel := g.AddButton("x+10 w120", "Cancel")

    btnBrowse.OnEvent("Click", (*) => BrowseSnipFolder(edFolder))
    btnFfmpeg.OnEvent("Click", (*) => BrowseFfmpeg(edFfmpeg))
    btnPick.OnEvent("Click", (*) => PickRegionFromSettings(g, txtRegion, "Region"))
    btnPickRec.OnEvent("Click", (*) => PickRegionFromSettings(g, txtRecRegion, "RecRegion"))
    btnSave.OnEvent("Click", (*) => SaveSettings(g, ctl, edFolder, cbSave, edAnim,
                                                 edFfmpeg, edFps, edBurstMax, edBurstInt))
    btnCancel.OnEvent("Click", (*) => g.Hide())
    g.OnEvent("Escape", (*) => g.Hide())
    g.OnEvent("Close", (*) => g.Hide())

    SettingsGui := g
    g.Show("AutoSize Center")
}

RegionSummary(section := "Region") {
    if LoadRegion(&x, &y, &w, &h, section)
        return w " x " h " at " x "," y
    return "not set yet"
}

BrowseSnipFolder(edFolder) {
    picked := DirSelect("*" edFolder.Value, 3, "Where should snips be saved?")
    if picked
        edFolder.Value := picked
}

BrowseFfmpeg(edFfmpeg) {
    picked := FileSelect(1, edFfmpeg.Value, "Where is ffmpeg.exe?", "ffmpeg (ffmpeg.exe)")
    if picked
        edFfmpeg.Value := picked
}

PickRegionFromSettings(g, txtRegion, section) {
    g.Hide()                                    ; the window would land in the shot
    Sleep 150
    DoSetRegion(section)
    txtRegion.Value := RegionSummary(section)
    g.Show()
}

SaveSettings(g, ctl, edFolder, cbSave, edAnim, edFfmpeg, edFps, edBurstMax, edBurstInt) {
    global Keys, ConfigFile, SaveFolder, SaveToFile, AnimMs, FfmpegPath, RecFps
    global BurstMax, BurstInterval

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
    FfmpegPath := Trim(edFfmpeg.Value)
    RecFps     := Min(Max(Integer(edFps.Value = "" ? 30 : edFps.Value), 5), 60)
    IniWrite(SaveFolder, ConfigFile, "Settings", "SaveFolder")
    IniWrite(SaveToFile, ConfigFile, "Settings", "SaveToFile")
    IniWrite(AnimMs,     ConfigFile, "Settings", "AnimMs")
    BurstMax      := Min(Max(Integer(edBurstMax.Value = "" ? 12 : edBurstMax.Value), 2), 24)
    BurstInterval := Min(Max(Integer(edBurstInt.Value = "" ? 0 : edBurstInt.Value), 0), 60)
    IniWrite(FfmpegPath,    ConfigFile, "Settings", "Ffmpeg")
    IniWrite(RecFps,        ConfigFile, "Settings", "RecFps")
    IniWrite(BurstMax,      ConfigFile, "Settings", "BurstMax")
    IniWrite(BurstInterval, ConfigFile, "Settings", "BurstInterval")

    ApplyHotkeys()
    g.Hide()
    Notify("Saved - " Keys["Snip"] " snips, " Keys["Record"] " records")
}

NoOp(*) {
}
