#Include "_grad_colors.ahk"

track_period := 8
live_hint_period := 40
idle_feedback_delay := 100
w_max := 20

gdip_token := 0
gdip_state := false
gest_overlay := false
g_mem_dc := 0
g_hbm := 0
g_bits := 0
g_overlay_w := 0
g_overlay_h := 0
g_overlay_bottom_gap := 0
idle_feedback_overlay := false
idle_fb_mem_dc := 0
idle_fb_hbm := 0
idle_fb_bits := 0
idle_fb_size := 0

pool_gestures := false
is_drawing := false
overlay_opts := false
zone_preview_mode := "Off"
live_hint_bbox := false
live_hint_start_shown := false
live_hint_last_tick := 0
live_hint_last_len := 0.0
live_hint_icon_cache := Map()
live_hint_draw_sig := ""
live_hint_res := false
live_hint_chain_text := ""
gesture_cancelled := false
gesture_last_move_tick := 0
gesture_segments := []
gesture_opacity_factor := 1.0
shake_cancel_points := []
gesture_waiting_first_move := false
points := []
prev_x := 0
prev_y := 0
cum_len := 0.0
cur_grad_len := 0.0
prev_width := 0

OnExit(GdipShutdown)


GdipStartup() {
    global gdip_token, gdip_state

    if gdip_state {
        return true
    }

    DllCall("LoadLibrary", "str", "gdiplus", "ptr")
    si := Buffer(A_PtrSize == 8 ? 24 : 16, 0)
    NumPut("UInt", 1, si, 0)  ; GdiplusVersion = 1
    NumPut("Ptr",  0, si, 4)  ; DebugEventCallback = null
    NumPut("Int",  0, si, 4 + A_PtrSize)  ; SuppressBackgroundThread = false
    NumPut("Int",  0, si, 8 + A_PtrSize)  ; SuppressExternalCodecs = false

    loop 5 {  ; in case of a startup error
        if !DllCall("gdiplus\GdiplusStartup", "ptr*", &token:=0, "ptr", si, "ptr", 0, "UInt") {
            gdip_token := token
            gdip_state := true
            return true
        }
        Sleep(100)
    }
    return false
}


GdipShutdown(*) {
    global gdip_token, gdip_state

    if gdip_state {
        DllCall("gdiplus\GdiplusShutdown", "ptr", gdip_token)
        gdip_token := 0
        gdip_state := false
    }
}


CreateGestOverlay(bottom_gap:=0) {
    global gest_overlay, g_mem_dc, g_hbm, g_bits, g_overlay_w, g_overlay_h, g_overlay_bottom_gap

    DestroyGestOverlay()

    if !GdipStartup() {
        return
    }

    g_overlay_w := A_ScreenWidth
    g_overlay_h := A_ScreenHeight - bottom_gap
    g_overlay_bottom_gap := bottom_gap

    gest_overlay := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x80020 -DPIScale")
    gest_overlay.Show("Hide x0 y0 w" . g_overlay_w . " h" . g_overlay_h)

    hdc := DllCall("GetDC", "ptr", 0, "ptr")
    g_mem_dc := DllCall("gdi32\CreateCompatibleDC", "ptr", hdc, "ptr")
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdc)

    bi := Buffer(40, 0)
    NumPut("UInt", 40, bi, 0)
    NumPut("Int", g_overlay_w, bi, 4)
    NumPut("Int", -g_overlay_h, bi, 8)
    NumPut("UShort", 1, bi, 12)
    NumPut("UShort", 32, bi, 14)
    NumPut("UInt", 0, bi, 16)

    g_hbm := DllCall("gdi32\CreateDIBSection",
        "ptr", 0, "ptr", bi, "UInt", 0, "ptr*", &g_bits:=0, "ptr", 0, "UInt", 0, "ptr")
    if g_hbm {
        DllCall("gdi32\SelectObject", "ptr", g_mem_dc, "ptr", g_hbm, "ptr")
        ClearOverlay()
        PresentOverlay()
    }
}


ClearOverlay() {
    if !g_bits {
        return
    }
    DllCall("msvcrt\memset", "ptr", g_bits, "int", 0, "uptr", g_overlay_w * g_overlay_h * 4)
}


GetOverlayGraphics(reset:=false) {
    global g_bits, g_overlay_w, g_overlay_h
    static bmp:=0, g:=0, cached_bits:=0

    if reset {
        if g {
            DllCall("gdiplus\GdipDeleteGraphics", "ptr", g)
            g := 0
        }
        if bmp {
            DllCall("gdiplus\GdipDisposeImage", "ptr", bmp)
            bmp := 0
        }
        cached_bits := 0
        return 0
    }

    if !g_bits {
        return 0
    }

    if g_bits !== cached_bits || !g {
        if g {
            DllCall("gdiplus\GdipDeleteGraphics", "ptr", g)
            g := 0
        }
        if bmp {
            DllCall("gdiplus\GdipDisposeImage", "ptr", bmp)
            bmp := 0
        }

        if DllCall(
            "gdiplus\GdipCreateBitmapFromScan0", "int", g_overlay_w, "int", g_overlay_h,
            "int", g_overlay_w*4, "int", 0xE200B, "ptr", g_bits, "ptr*", &bmp:=0
        ) {
            return 0
        }

        if DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", bmp, "ptr*", &g:=0) {
            DllCall("gdiplus\GdipDisposeImage", "ptr", bmp)
            bmp := 0
            return 0
        }
        DllCall("gdiplus\GdipSetCompositingMode", "ptr", g, "int", 0)  ; SourceOver
        DllCall("gdiplus\GdipSetCompositingQuality", "ptr", g, "int", 4)  ; HighQuality
        DllCall("gdiplus\GdipSetSmoothingMode", "ptr", g, "int", 4)  ; AntiAlias
        DllCall("gdiplus\GdipSetTextRenderingHint", "ptr", g, "int", 4)  ; AntiAliasGridFit
        DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", g, "int", 3)  ; Half

        cached_bits := g_bits
    }
    return g
}


PresentOverlay(opacity:=false) {
    global gest_overlay, g_overlay_w, g_overlay_h
    static size:=0, blend:=0, last_opacity:=-1, last_w:=0, last_h:=0, pt_zero:=Buffer(8, 0)

    if !(gest_overlay && g_mem_dc) {
        return
    }

    if !size || last_w !== g_overlay_w || last_h !== g_overlay_h {
        size := Buffer(8, 0)
        NumPut("Int", g_overlay_w, size, 0)
        NumPut("Int", g_overlay_h, size, 4)
        last_w := g_overlay_w
        last_h := g_overlay_h
    }

    opacity := opacity == false ? 255 : _ClampAlpha(opacity)
    if !blend || (last_opacity !== opacity) {
        blend := Buffer(4, 0)
        NumPut("UChar", 0, blend, 0)
        NumPut("UChar", 0, blend, 1)
        NumPut("UChar", opacity, blend, 2)
        NumPut("UChar", 1, blend, 3)
        last_opacity := opacity
    }

    DllCall(
        "user32\UpdateLayeredWindow", "ptr", gest_overlay.Hwnd, "ptr", 0, "ptr", 0,
        "ptr", size, "ptr", g_mem_dc, "ptr", pt_zero, "UInt", 0, "ptr", blend, "UInt", 2
    )
}


DestroyGestOverlay() {
    global gest_overlay, g_mem_dc, g_hbm, g_bits, g_overlay_w, g_overlay_h, g_overlay_bottom_gap

    SetTimer(TrackMouse, 0)
    SetTimer(CheckGestureIdlePause, 0)
    SetTimer(DestroyGestOverlay, 0)

    DestroyIdleFeedbackOverlay()
    ClearLiveHintIconCache()
    ClearLiveHintResources()
    GetOverlayGraphics(true)

    if gest_overlay {
        try gest_overlay.Destroy()
        gest_overlay := false
    }

    g_bits := 0
    g_overlay_w := 0
    g_overlay_h := 0
    g_overlay_bottom_gap := 0

    if g_hbm {
        DllCall("gdi32\DeleteObject", "ptr", g_hbm)
        g_hbm := 0
    }

    if g_mem_dc {
        DllCall("gdi32\DeleteDC", "ptr", g_mem_dc)
        g_mem_dc := 0
    }
}


CreateIdleFeedbackOverlay(size:=72) {
    global idle_feedback_overlay, idle_fb_mem_dc, idle_fb_hbm, idle_fb_bits, idle_fb_size

    if idle_feedback_overlay && idle_fb_size == size {
        return true
    }

    DestroyIdleFeedbackOverlay()
    if !GdipStartup() {
        return false
    }

    idle_fb_size := size
    idle_feedback_overlay := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x80020 -DPIScale")
    idle_feedback_overlay.Show("Hide x0 y0 w" . size . " h" . size)

    hdc := DllCall("GetDC", "ptr", 0, "ptr")
    idle_fb_mem_dc := DllCall("gdi32\CreateCompatibleDC", "ptr", hdc, "ptr")
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdc)

    bi := Buffer(40, 0)
    NumPut("UInt", 40, bi, 0)
    NumPut("Int", size, bi, 4)
    NumPut("Int", -size, bi, 8)
    NumPut("UShort", 1, bi, 12)
    NumPut("UShort", 32, bi, 14)
    NumPut("UInt", 0, bi, 16)

    idle_fb_hbm := DllCall("gdi32\CreateDIBSection",
        "ptr", 0, "ptr", bi, "UInt", 0, "ptr*", &idle_fb_bits:=0, "ptr", 0, "UInt", 0, "ptr")
    if !idle_fb_hbm {
        DestroyIdleFeedbackOverlay()
        return false
    }
    DllCall("gdi32\SelectObject", "ptr", idle_fb_mem_dc, "ptr", idle_fb_hbm, "ptr")
    return true
}


DestroyIdleFeedbackOverlay() {
    global idle_feedback_overlay, idle_fb_mem_dc, idle_fb_hbm, idle_fb_bits, idle_fb_size

    GetIdleFeedbackGraphics(true)
    if idle_feedback_overlay {
        try idle_feedback_overlay.Destroy()
        idle_feedback_overlay := false
    }
    idle_fb_bits := 0
    idle_fb_size := 0
    if idle_fb_hbm {
        DllCall("gdi32\DeleteObject", "ptr", idle_fb_hbm)
        idle_fb_hbm := 0
    }
    if idle_fb_mem_dc {
        DllCall("gdi32\DeleteDC", "ptr", idle_fb_mem_dc)
        idle_fb_mem_dc := 0
    }
}


GetIdleFeedbackGraphics(reset:=false) {
    global idle_fb_bits, idle_fb_size
    static bmp:=0, g:=0, cached_bits:=0

    if reset {
        if g {
            DllCall("gdiplus\GdipDeleteGraphics", "ptr", g)
            g := 0
        }
        if bmp {
            DllCall("gdiplus\GdipDisposeImage", "ptr", bmp)
            bmp := 0
        }
        cached_bits := 0
        return 0
    }

    if !idle_fb_bits {
        return 0
    }

    if idle_fb_bits !== cached_bits || !g {
        if g {
            DllCall("gdiplus\GdipDeleteGraphics", "ptr", g)
            g := 0
        }
        if bmp {
            DllCall("gdiplus\GdipDisposeImage", "ptr", bmp)
            bmp := 0
        }
        if DllCall(
            "gdiplus\GdipCreateBitmapFromScan0", "int", idle_fb_size, "int", idle_fb_size,
            "int", idle_fb_size * 4, "int", 0xE200B, "ptr", idle_fb_bits, "ptr*", &bmp:=0
        ) {
            return 0
        }
        if DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", bmp, "ptr*", &g:=0) {
            DllCall("gdiplus\GdipDisposeImage", "ptr", bmp)
            bmp := 0
            return 0
        }
        DllCall("gdiplus\GdipSetCompositingMode", "ptr", g, "int", 0)
        DllCall("gdiplus\GdipSetCompositingQuality", "ptr", g, "int", 4)
        DllCall("gdiplus\GdipSetSmoothingMode", "ptr", g, "int", 4)
        DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", g, "int", 3)
        cached_bits := idle_fb_bits
    }
    return g
}


DrawIdleFeedback(kind, progress) {
    global idle_feedback_overlay, idle_fb_mem_dc, idle_fb_bits, idle_fb_size

    mode := GetIdleFeedbackMode(kind)
    if mode == 1 {
        HideIdleFeedback()
        return
    }

    try {
        size := Max(24, Integer(CONF.gesture_idle_feedback_size.v))
    } catch {
        size := 72
    }
    if !CreateIdleFeedbackOverlay(size) || !idle_fb_bits {
        return
    }

    DllCall("msvcrt\memset", "ptr", idle_fb_bits, "int", 0, "uptr", size * size * 4)
    g := GetIdleFeedbackGraphics()
    if !g {
        return
    }

    feedback_rgb := GetIdleFeedbackColor(kind)
    cx := size / 2
    cy := size / 2
    radius := Max(8, size * 0.32)
    pen_w := Max(2.0, size * 0.055)

    if mode == 2 {
        DrawIdleFeedbackBackground(g, cx, cy, radius, pen_w)
        DrawIdleFeedbackRing(g, cx, cy, radius, pen_w, feedback_rgb, progress)
    } else if mode == 3 {
        DrawIdleFeedbackBackground(g, cx, cy, radius, pen_w)
        DrawIdleFeedbackPie(g, cx, cy, radius, feedback_rgb, progress)
    } else if mode == 4 {
        DrawIdleFeedbackShrink(g, cx, cy, radius, feedback_rgb, progress)
    } else {
        DrawIdleFeedbackBar(g, cx, cy, size, pen_w, feedback_rgb, progress)
    }

    MouseGetPos(&mx, &my)
    dst := Buffer(8, 0)
    NumPut("Int", Round(mx - cx), dst, 0)
    NumPut("Int", Round(my - cy), dst, 4)
    dims := Buffer(8, 0)
    NumPut("Int", size, dims, 0)
    NumPut("Int", size, dims, 4)
    src := Buffer(8, 0)
    overlay_opacity := _ClampAlpha(255 * Max(0, Min(1, progress)))
    blend := Buffer(4, 0)
    NumPut("UChar", 0, blend, 0)
    NumPut("UChar", 0, blend, 1)
    NumPut("UChar", overlay_opacity, blend, 2)
    NumPut("UChar", 1, blend, 3)

    idle_feedback_overlay.Show("NA")
    DllCall(
        "user32\UpdateLayeredWindow", "ptr", idle_feedback_overlay.Hwnd, "ptr", 0,
        "ptr", dst, "ptr", dims, "ptr", idle_fb_mem_dc, "ptr", src,
        "UInt", 0, "ptr", blend, "UInt", 2
    )
}


GetIdleFeedbackMode(kind) {
    try return kind == "confirm" ? CONF.gesture_idle_confirm_mode.v : CONF.gesture_idle_cancel_mode.v
    return 2
}


GetIdleFeedbackColor(kind) {
    try {
        colour := kind == "confirm" ? CONF.gesture_idle_confirm_color.v : CONF.gesture_idle_cancel_color.v
        colors := ParseAhkColorList(colour)
        if colors.Length {
            return colors[1]
        }
    }
    return kind == "confirm" ? 0x47CD7C : 0xEF6868
}


DrawIdleFeedbackBackground(g, cx, cy, radius, pen_w) {
    if !DllCall("gdiplus\GdipCreatePen1", "uint", 0x44303030,
        "float", pen_w, "int", 2, "ptr*", &pen_bg:=0) {
        DllCall("gdiplus\GdipDrawEllipse", "ptr", g, "ptr", pen_bg,
            "float", cx - radius, "float", cy - radius, "float", radius * 2, "float", radius * 2)
        DllCall("gdiplus\GdipDeletePen", "ptr", pen_bg)
    }
}


DrawIdleFeedbackRing(g, cx, cy, radius, pen_w, feedback_rgb, progress) {
    if !DllCall("gdiplus\GdipCreatePen1", "uint", (210 << 24) | feedback_rgb,
        "float", pen_w, "int", 2, "ptr*", &pen_fg:=0) {
        DllCall("gdiplus\GdipSetPenStartCap", "ptr", pen_fg, "int", 2)
        DllCall("gdiplus\GdipSetPenEndCap", "ptr", pen_fg, "int", 2)
        DllCall("gdiplus\GdipDrawArc", "ptr", g, "ptr", pen_fg,
            "float", cx - radius, "float", cy - radius, "float", radius * 2, "float", radius * 2,
            "float", -90, "float", 360 * Max(0, Min(1, progress)))
        DllCall("gdiplus\GdipDeletePen", "ptr", pen_fg)
    }
}


DrawIdleFeedbackPie(g, cx, cy, radius, feedback_rgb, progress) {
    if !DllCall("gdiplus\GdipCreateSolidFill", "uint", (118 << 24) | feedback_rgb,
        "ptr*", &brush_fg:=0) {
        DllCall("gdiplus\GdipFillPie", "ptr", g, "ptr", brush_fg,
            "float", cx - radius, "float", cy - radius, "float", radius * 2, "float", radius * 2,
            "float", -90, "float", 360 * Max(0, Min(1, progress)))
        DllCall("gdiplus\GdipDeleteBrush", "ptr", brush_fg)
    }
}


DrawIdleFeedbackShrink(g, cx, cy, radius, feedback_rgb, progress) {
    progress := Max(0, Min(1, progress))
    cur_radius := Max(3, radius * (1 - progress))
    if !DllCall("gdiplus\GdipCreateSolidFill", "uint", (132 << 24) | feedback_rgb,
        "ptr*", &brush_fg:=0) {
        DllCall("gdiplus\GdipFillEllipse", "ptr", g, "ptr", brush_fg,
            "float", cx - cur_radius, "float", cy - cur_radius,
            "float", cur_radius * 2, "float", cur_radius * 2)
        DllCall("gdiplus\GdipDeleteBrush", "ptr", brush_fg)
    }
}


DrawIdleFeedbackBar(g, cx, cy, size, pen_w, feedback_rgb, progress) {
    bar_w := size * 0.70
    x1 := cx - bar_w / 2
    x2 := cx + bar_w / 2
    y := cy + size * 0.23
    if !DllCall("gdiplus\GdipCreatePen1", "uint", 0x66303030,
        "float", pen_w, "int", 2, "ptr*", &pen_bg:=0) {
        DllCall("gdiplus\GdipSetPenStartCap", "ptr", pen_bg, "int", 2)
        DllCall("gdiplus\GdipSetPenEndCap", "ptr", pen_bg, "int", 2)
        DllCall("gdiplus\GdipDrawLine", "ptr", g, "ptr", pen_bg,
            "float", x1, "float", y, "float", x2, "float", y)
        DllCall("gdiplus\GdipDeletePen", "ptr", pen_bg)
    }
    if !DllCall("gdiplus\GdipCreatePen1", "uint", (220 << 24) | feedback_rgb,
        "float", pen_w, "int", 2, "ptr*", &pen_fg:=0) {
        DllCall("gdiplus\GdipSetPenStartCap", "ptr", pen_fg, "int", 2)
        DllCall("gdiplus\GdipSetPenEndCap", "ptr", pen_fg, "int", 2)
        DllCall("gdiplus\GdipDrawLine", "ptr", g, "ptr", pen_fg,
            "float", x1, "float", y,
            "float", x1 + bar_w * Max(0, Min(1, progress)), "float", y)
        DllCall("gdiplus\GdipDeletePen", "ptr", pen_fg)
    }
}


HideIdleFeedback() {
    global idle_feedback_overlay

    if idle_feedback_overlay {
        try idle_feedback_overlay.Hide()
    }
}


CollectPool(gestures) {
    global pool_gestures

    MouseGetPos(&x, &y)
    pool := GetPool(x, y)
    pool_gestures := []
    for _, mod_mp in gestures {
        node := mod_mp.Has(0) ? _GetFin(mod_mp[0]) : false
        if IsGestureFin(node) && node.opts.pool == pool {
            pool_gestures.Push(mod_mp[0])
        }
    }
}


CollectAllGestures(gestures) {
    global pool_gestures

    pool_gestures := []
    for _, mod_mp in gestures {
        node := mod_mp.Has(0) ? _GetFin(mod_mp[0]) : false
        if IsGestureFin(node) {
            pool_gestures.Push(mod_mp[0])
        }
    }
}


IsGestureFin(node) {
    return node is Object && node.HasOwnProp("opts")
}


StartDraw(gestures:=false, *) {
    global is_drawing, prev_x, prev_y, points, cum_len, prev_width, cur_grad_len, pool_gestures,
        live_hint_start_shown, live_hint_last_tick, live_hint_last_len, live_hint_draw_sig,
        live_hint_chain_text, gesture_cancelled, gesture_last_move_tick, gesture_segments,
        gesture_opacity_factor, gesture_waiting_first_move

    if is_drawing {
        return
    }

    CreateGestOverlay()
    if !gest_overlay {
        return
    }
    is_drawing := true
    ClearOverlay()
    PresentOverlay()
    gest_overlay.Show("NA")
    MouseGetPos(&prev_x, &prev_y)
    g_opts := ""

    if init_drawing {
        if !current_path[-1][4] {
            try g_opts := _GetFirst(_GetUnholdEntries().ubase).gesture_opts
        } else {
            ubase := ROOTS[gui_lang]
            for arr in current_path {
                if A_Index == current_path.Length {
                    break
                } else if (A_Index - 1) == current_path.Length {
                    ubase := ubase.GetBaseHoldMod(arr[1], arr[2] & ~1, arr[3], arr[4]).ubase
                } else {
                    ubase := ubase.GetBaseHoldMod(arr*).ubase
                }
            }
            try g_opts := _GetFirst(ubase).gesture_opts
        }
    }

    SetOverlayOpts(
        (g_opts || (await_gest ? _GetFin(await_gest[1]).gesture_opts : "")),
        GetPool(prev_x, prev_y)
    )
    SetTimer(TrackMouse, track_period)
    points := [[prev_x, prev_y]]
    cum_len := 0.0
    cur_grad_len := 0.0
    prev_width := 0
    live_hint_start_shown := false
    live_hint_last_tick := 0
    live_hint_last_len := 0.0
    live_hint_draw_sig := ""
    live_hint_chain_text := ""
    gesture_cancelled := false
    gesture_last_move_tick := A_TickCount
    gesture_segments := []
    gesture_opacity_factor := 1.0
    gesture_waiting_first_move := false
    ResetShakeCancel(prev_x, prev_y)
    SetTimer(CheckGestureIdlePause, -track_period)
    if !GetLiveHintStartMove() {
        ShowStartLiveHint(pool_gestures, prev_x, prev_y)
        live_hint_start_shown := true
    }
}


_ClampAlpha(value) {
    return Max(0, Min(255, Integer(value)))
}


SetOverlayOpts(opts, pool) {
    global overlay_opts

    vals := StrSplit(opts, ";")
    color_key := GetGestureColorKey(pool)
    base_i := GestureOverlayOptsBaseIndex(vals)
    overlay_opts := {pool: pool}
    for arr in [
        ["gest_colors", "gest_zone_colors", 0],
        ["grad_len", "gest_zone_grad_len", 1],
        ["grad_loop", "gest_zone_grad_loop", 2],
    ] {
        try {
            zi := base_i + GetGestureZoneOverrideIndex(color_key, arr[3])
            overlay_opts.%arr[1]% := vals.Has(zi) && vals[zi] !== "" ? vals[zi]
                : CONF.%arr[2]%[color_key].v
        } catch {
            overlay_opts.%arr[1]% := CONF.%arr[2]%[color_key].v
        }
        if A_Index == 1 {
            v := overlay_opts.%arr[1]%
            overlay_opts.%arr[1]% := []
            if RegExMatch(v, "random\((\d+)\)", &m) {
                loop m[1] {
                    overlay_opts.%arr[1]%.Push(
                        (Random(0, 255) << 16) | (Random(0, 255) << 8) | Random(0, 255)
                    )
                }
            } else {
                overlay_opts.%arr[1]% := ParseAhkColorList(v)
            }
            if !overlay_opts.%arr[1]%.Length {
                overlay_opts.%arr[1]% := [0xFF0000]
            }
        }
    }
}


GestureOverlayOptsBaseIndex(vals) {
    if vals.Length >= 6 && IsGesturePatternOpts(vals) {
        return GesturePatternHasUnrecognizedBehavior(vals) ? 6 : 5
    }
    return 0
}


IsGesturePatternOpts(vals) {
    try {
        ParseGesturePool(vals[1])
        Integer(vals[2])
        Float(vals[3])
        Integer(vals[4])
        Integer(vals[5])
        return true
    }
    return false
}


GesturePatternHasUnrecognizedBehavior(vals) {
    return vals.Has(7) && Trim(vals[7]) ~= "^[3-5]$"
}


GetGestureUnrecognizedBehavior(opts, fallback:=5) {
    vals := StrSplit(opts, ";")
    if IsGesturePatternOpts(vals) {
        if GesturePatternHasUnrecognizedBehavior(vals) {
            return Integer(vals[7])
        }
        return fallback || 5
    }
    try {
        behavior := Integer(vals[1])
        return behavior >= 1 && behavior <= 5 ? behavior : (fallback || 5)
    }
    return fallback || 5
}


EndDraw(*) {
    global is_drawing, init_drawing, points, overlay_opts, pool_gestures, form_points,
        gesture_cancelled, gesture_segments

    if !is_drawing {
        return
    }

    SetTimer(TrackMouse, 0)
    SetTimer(CheckGestureIdlePause, 0)
    is_drawing := false
    DestroyGestOverlay()

    if gesture_cancelled {
        if init_drawing {
            init_drawing := false
            form_points := false
            try form["SetGesture"].Text := "Cancelled"
            try form["ShowGesture"].Text := "🙈"
            SetTimer(_ReturnButtonText, -1200)
            try WinActivate "ahk_id " . form.Hwnd
            return -1
        }
        overlay_opts := false
        pool_gestures := false
        SetTimer(RestoreSettingsGestureZonePreview, -50)
        return -1
    }

    if init_drawing {
        form_points := []
        for pair in points {
            form_points.Push([pair[1], pair[2]])
        }

        init_drawing := false
        try form["Save"].Enabled := true
        try form["SaveWithReturn"].Enabled := true
        try form["ShowGesture"].Enabled := true
        try form["ShowGesture"].Text := "👀"
        try form["SetGesture"].Text := "Saved!"
        SetTimer(_ReturnButtonText, -2000)

        res := Resample(points)
        pts := res[1]
        if Sqrt((pts[1][1]-pts[-1][1])**2 + (pts[1][2]-pts[-1][2])**2) < (res[2] / 10) {
            try form["Phase"].Enabled := true
        }
        try WinActivate "ahk_id " . form.Hwnd
        return -1
    }

    ret := cum_len > Max(CONF.min_gesture_len.v, 10) ? Recognize(points, pool_gestures) : false
    overlay_opts := false
    pool_gestures := false
    gesture_segments := []
    SetTimer(RestoreSettingsGestureZonePreview, -50)
    return ret
}


ParseAhkColor(colour) {
    colour := Trim(colour)
    try {
        for name, val in AHK_COLORS {
            if StrLower(colour) == StrLower(name) {
                colour := val
                break
            }
        }
    }
    colour := RegExReplace(colour, "i)^0x")
    return Integer("0x" . colour)
}


ParseAhkColorList(colors) {
    out := []
    for colour in StrSplit(colors, ",") {
        try out.Push(ParseAhkColor(colour))
    }
    return out
}


DrawLine(x1, y1, x2, y2, width) {
    global cur_grad_len, gesture_opacity_factor
    static pen:=0

    SetTimer(DestroyGestOverlay, 0)

    if !g_bits {
        return
    }

    g := GetOverlayGraphics()
    if !g {
        return
    }

    if !pen {
        if DllCall("gdiplus\GdipCreatePen1",
            "uint", (_ClampAlpha(CONF.gest_opacity.v * gesture_opacity_factor)<<24)|0,
            "float", width, "int", 2, "ptr*", &pen:=0) {
            return
        }
        DllCall("gdiplus\GdipSetPenLineJoin", "ptr", pen, "int", 2)
        DllCall("gdiplus\GdipSetPenStartCap", "ptr", pen, "int", 2)
        DllCall("gdiplus\GdipSetPenEndCap", "ptr", pen, "int", 2)
    } else {
        DllCall("gdiplus\GdipSetPenWidth", "ptr", pen, "float", width)
    }

    dx := x2 - x1
    dy := y2 - y1
    seg_len := Sqrt(dx*dx + dy*dy)
    parts := Max(Ceil(seg_len / 3), 1)

    loop parts {
        try {
            t0 := (A_Index - 1) / parts
            t1 := A_Index / parts
            mid := (A_Index - 0.5) / parts

            line_colour := ColorAtProgress((cur_grad_len + seg_len * mid) / overlay_opts.grad_len)
            DllCall("gdiplus\GdipSetPenColor", "ptr", pen,
                "uint", (_ClampAlpha(CONF.gest_opacity.v * gesture_opacity_factor)<<24)|line_colour)

            xa := x1 + dx * t0
            ya := y1 + dy * t0
            xb := x1 + dx * t1
            yb := y1 + dy * t1

            DllCall("gdiplus\GdipSetPenStartCap", "ptr", pen, "int", 2)
            DllCall("gdiplus\GdipSetPenEndCap", "ptr", pen, "int", 2)
            DllCall("gdiplus\GdipDrawLine", "ptr", g, "ptr", pen,
                "float", xa, "float", ya, "float", xb, "float", yb)
        }
    }
    cur_grad_len += seg_len
}


TrackMouse() {
    global prev_x, prev_y, cum_len, prev_width, live_hint_start_shown, live_hint_last_tick, live_hint_last_len
        , gesture_last_move_tick, gesture_waiting_first_move

    if !is_drawing {
        SetTimer(TrackMouse, 0)
        SetTimer(CheckGestureIdlePause, 0)
        return
    }

    MouseGetPos(&x, &y)
    if x !== prev_x || y !== prev_y {
        HideIdleFeedback()
        dx := x - prev_x
        dy := y - prev_y
        d := Sqrt(dx*dx + dy*dy)
        cum_len += d
        if d >= 3 {
            gesture_last_move_tick := A_TickCount
            gesture_waiting_first_move := false
        }

        target := BrushWidth(cum_len)
        width := target
        if target > prev_width {
            width := Min(target, prev_width + 1)
        }

        DrawLine(prev_x, prev_y, x, y, width)

        prev_x := x
        prev_y := y
        prev_width := width
        points.Push([x, y])

        if CheckShakeCancel(x, y, dx, dy, d) {
            return
        }

        if pool_gestures && CONF.live_hint_enabled.v {
            if cum_len > Max(CONF.min_gesture_len.v, 10) {
                live_hint_start_shown := true
                if CONF.live_hint_move_count.v && ShouldRefreshLiveHint(cum_len) {
                    live_hint_last_tick := A_TickCount
                    live_hint_last_len := cum_len
                    SetTimer(LiveHint.Bind(points, pool_gestures, points[1][1], points[1][2]), -1)
                    return
                }
            } else if !live_hint_start_shown && cum_len >= GetLiveHintStartMove() {
                ShowStartLiveHint(pool_gestures, points[1][1], points[1][2])
                live_hint_start_shown := true
                return
            }
        }
        PresentOverlay()
    }
}


ResetShakeCancel(x, y) {
    global shake_cancel_points

    shake_cancel_points := [[x, y, 0, 0, 0.0]]
}


CheckShakeCancel(x, y, dx, dy, seg_len) {
    global shake_cancel_points, gesture_cancelled

    if !CONF.shake_cancel_enabled.v || gesture_cancelled {
        return false
    }

    samples := Max(4, Integer(CONF.shake_cancel_samples.v))
    shake_cancel_points.Push([x, y, dx, dy, seg_len])
    while shake_cancel_points.Length > samples {
        shake_cancel_points.RemoveAt(1)
    }
    if shake_cancel_points.Length < samples {
        return false
    }

    min_x := max_x := shake_cancel_points[1][1]
    min_y := max_y := shake_cancel_points[1][2]
    path_len := 0.0
    turns := 0
    prev_vec := false
    for pt in shake_cancel_points {
        min_x := Min(min_x, pt[1])
        max_x := Max(max_x, pt[1])
        min_y := Min(min_y, pt[2])
        max_y := Max(max_y, pt[2])
        path_len += pt[5]
        if prev_vec && prev_vec[3] >= 3 && pt[5] >= 3 {
            dot := prev_vec[1] * pt[3] + prev_vec[2] * pt[4]
            if dot < -prev_vec[3] * pt[5] * 0.35 {
                turns += 1
            }
        }
        if pt[5] >= 3 {
            prev_vec := [pt[3], pt[4], pt[5]]
        }
    }

    if Max(max_x - min_x, max_y - min_y) <= CONF.shake_cancel_box.v
        && path_len >= CONF.shake_cancel_len.v
        && turns >= CONF.shake_cancel_turns.v {
        CancelCurrentGesture()
        return true
    }
    return false
}


CancelCurrentGesture() {
    global gesture_cancelled

    gesture_cancelled := true
    SetTimer(TrackMouse, 0)
    SetTimer(CheckGestureIdlePause, 0)
    ClearLiveHintBox()
    DestroyGestOverlay()
}


CheckGestureIdlePause() {
    global is_drawing, gesture_cancelled, gesture_last_move_tick, pool_gestures, points, cum_len
        , gesture_waiting_first_move

    if !is_drawing || gesture_cancelled {
        HideIdleFeedback()
        return
    }

    if gesture_waiting_first_move {
        HideIdleFeedback()
        SetTimer(CheckGestureIdlePause, -track_period)
        return
    }

    elapsed := A_TickCount - gesture_last_move_tick
    confirm_ms := Max(0, CONF.gesture_idle_confirm_ms.v)
    cancel_ms := Max(0, CONF.gesture_idle_cancel_ms.v)

    res := cum_len > Max(CONF.min_gesture_len.v, 10) && pool_gestures
        ? Recognize(points, pool_gestures)
        : false
    recognized := res && res[2] !== "" && res[1] >= CONF.min_cos_similarity.v
    has_child_gestures := recognized && GestureHasChildGestures(res[2])
    idle_target_ms := 0
    idle_kind := ""
    if has_child_gestures && confirm_ms {
        idle_target_ms := confirm_ms
        idle_kind := "confirm"
    } else if !recognized && cancel_ms {
        idle_target_ms := cancel_ms
        idle_kind := "cancel"
    }

    if idle_target_ms && elapsed >= idle_feedback_delay {
        visual_ms := Max(1, idle_target_ms - idle_feedback_delay)
        DrawIdleFeedback(idle_kind, (elapsed - idle_feedback_delay) / visual_ms)
    } else if idle_target_ms {
        HideIdleFeedback()
    } else {
        HideIdleFeedback()
        reset_ms := confirm_ms || cancel_ms
        if recognized && reset_ms && elapsed >= reset_ms {
            gesture_last_move_tick := A_TickCount
        }
    }

    if !idle_target_ms || elapsed < idle_target_ms {
        SetTimer(CheckGestureIdlePause, -track_period)
        return
    }

    if has_child_gestures && idle_kind == "confirm" {
        HideIdleFeedback()
        if ConfirmGestureIdleTransition(res[2]) {
            SetTimer(CheckGestureIdlePause, -track_period)
            return
        }
    } else if !recognized && idle_kind == "cancel" {
        CancelCurrentGesture()
        return
    }

    if recognized && (!has_child_gestures || !confirm_ms || elapsed >= confirm_ms) {
        gesture_last_move_tick := A_TickCount
    }
    SetTimer(CheckGestureIdlePause, -track_period)
}


ConfirmGestureIdleTransition(gesture) {
    global await_gest, prev_x, prev_y, points, cum_len, prev_width, cur_grad_len,
        live_hint_start_shown, live_hint_last_tick, live_hint_last_len, live_hint_draw_sig,
        live_hint_chain_text, gesture_last_move_tick, overlay_opts, pool_gestures,
        gesture_waiting_first_move

    node := _GetFin(gesture)
    if !node || !GestureHasChildGestures(gesture) {
        return false
    }

    HideIdleFeedback()
    CollectAllGestures(gesture.gestures)
    if !pool_gestures.Length {
        return false
    }
    if node.is_instant {
        snapshot := await_gest ? await_gest[3] : false
        SendKbd(node.down_type,
            snapshot && node.down_type == TYPES.Default ? snapshot : node.down_val)
    }

    if await_gest {
        await_gest[1] := gesture
    }
    FadeGestureSegments()
    live_hint_chain_text .= node.gui_shortname . " → "
    SetOverlayOpts(node.gesture_opts, 5)
    MouseGetPos(&prev_x, &prev_y)
    points := [[prev_x, prev_y]]
    cum_len := 0.0
    cur_grad_len := 0.0
    prev_width := 0
    live_hint_start_shown := false
    live_hint_last_tick := 0
    live_hint_last_len := 0.0
    live_hint_draw_sig := ""
    gesture_last_move_tick := A_TickCount
    gesture_waiting_first_move := true
    ResetShakeCancel(prev_x, prev_y)
    ClearLiveHintBox()
    if CONF.live_hint_enabled.v && !GetLiveHintStartMove() {
        ShowStartLiveHint(pool_gestures, prev_x, prev_y)
        live_hint_start_shown := true
    } else if CONF.live_hint_enabled.v && live_hint_chain_text {
        DrawLiveHintList([], 0, prev_x, prev_y)
    }
    PresentOverlay()
    return true
}


FadeGestureSegments() {
    global gesture_segments, points, overlay_opts, cur_grad_len, prev_width, gesture_opacity_factor

    if points.Length > 1 {
        gesture_segments.Push({
            pts: CloneGesturePoints(points),
            opts: CloneGestureOverlayOpts(overlay_opts),
            fade: 1.0,
        })
    }
    for segment in gesture_segments {
        segment.fade *= 0.333
    }

    ClearOverlay()
    for segment in gesture_segments {
        overlay_opts := segment.opts
        gesture_opacity_factor := segment.fade
        cur_grad_len := 0.0
        prev_width := 0
        seg_len := 0.0
        for i, pt in segment.pts {
            if i == 1 {
                continue
            }
            prev_pt := segment.pts[i - 1]
            dx := pt[1] - prev_pt[1]
            dy := pt[2] - prev_pt[2]
            seg_len += Sqrt(dx*dx + dy*dy)
            target := BrushWidth(seg_len)
            width := target > prev_width ? Min(target, prev_width + 1) : target
            DrawLine(prev_pt[1], prev_pt[2], pt[1], pt[2], width)
            prev_width := width
        }
    }
    gesture_opacity_factor := 1.0
}


CloneGesturePoints(src) {
    out := []
    for pt in src {
        out.Push([pt[1], pt[2]])
    }
    return out
}


CloneGestureOverlayOpts(src) {
    colors := []
    for item in src.gest_colors {
        colors.Push(item)
    }
    return {
        pool: src.pool,
        gest_colors: colors,
        grad_len: src.grad_len,
        grad_loop: src.grad_loop,
    }
}


GestureHasChildGestures(gesture) {
    try {
        for _, mod_mp in gesture.gestures {
            if mod_mp.Has(0) && IsGestureFin(_GetFin(mod_mp[0])) {
                return true
            }
        }
    }
    return false
}


ShouldRefreshLiveHint(len) {
    global live_hint_last_tick, live_hint_last_len, live_hint_period

    if !live_hint_last_tick {
        return true
    }
    return A_TickCount - live_hint_last_tick >= live_hint_period
        || len - live_hint_last_len >= 60
}


BrushWidth(len) {
    t := 0.01 * (len - A_ScreenHeight / 6)
    w := w_max * ((t > 30) ? 1.0 : (t < -30) ? 0.0 : 1.0 / (1.0 + Exp(-t)))
    if w > w_max {
        w := w_max
    }
    return Round(w)
}


LiveHint(pts, gestures, hint_x:=0, hint_y:=0) {
    static busy:=false
    global live_hint_draw_sig, live_hint_bbox, live_hint_chain_text

    if busy || !CONF.live_hint_enabled.v {
        return
    }

    busy := true

    items := GetLiveHintMovingItems(pts, gestures)
    if !items.Length && !live_hint_chain_text {
        ClearLiveHintBox()
        busy := false
        return
    }
    sig := GetLiveHintDrawSignature(items, 0)
    if live_hint_bbox && sig == live_hint_draw_sig {
        PresentOverlay()
        busy := false
        return
    }
    DrawLiveHintList(items, 0, hint_x, hint_y)
    live_hint_draw_sig := sig
    busy := false
}


GetLiveHintMovingItems(pts, gestures) {
    res := []
    if !CONF.live_hint_move_count.v {
        return res
    }

    for candidate in RankGestures(pts, gestures, CONF.live_hint_move_count.v, CONF.live_hint_min_score.v) {
        node := _GetFin(candidate.gesture)
        if IsGestureFin(node) {
            res.Push({
                node: node,
                name: GetLiveHintGestureName(candidate.gesture, node),
                score: Round(candidate.score, 2),
            })
        }
    }
    return res
}


ShowStartLiveHint(gestures, start_x, start_y) {
    global live_hint_draw_sig

    if !CONF.live_hint_enabled.v || !CONF.live_hint_start_count.v || !gestures || !gestures.Length {
        return
    }

    items := []
    for gesture in gestures {
        node := _GetFin(gesture)
        if !IsGestureFin(node) {
            continue
        }
        items.Push({node: node, name: GetLiveHintGestureName(gesture, node)})
        if items.Length >= CONF.live_hint_start_count.v {
            break
        }
    }
    if !items.Length {
        return
    }

    more := gestures.Length - items.Length
    live_hint_draw_sig := GetLiveHintDrawSignature(items, more)
    DrawLiveHintList(items, more, start_x, start_y)
}


GetLiveHintDrawSignature(items, more_count) {
    global live_hint_chain_text

    sig := more_count . "|" . live_hint_chain_text . "|"
    for item in items {
        sig .= ObjPtr(item.node) . ":"
        sig .= item.HasProp("score") ? Format("{:.2f}", item.score) : ""
        sig .= ":" . item.name
        sig .= ";"
    }
    return sig
}


GetLiveHintGestureName(gesture, node:=false) {
    if !node {
        node := _GetFin(gesture)
    }
    if !node {
        return ""
    }

    child_count := GetLiveHintChildGestureCount(gesture)
    return node.gui_shortname . (child_count ? "  → " . child_count : "")
}


GetLiveHintChildGestureCount(gesture) {
    cnt := 0
    try {
        for _, mod_mp in gesture.gestures {
            for _, child in mod_mp {
                if IsGestureFin(_GetFin(child)) {
                    cnt += 1
                }
            }
        }
    }
    return cnt
}


GetLiveHintStartMove() {
    try return Max(0, CONF.live_hint_start_move.v)
    return 0
}


DrawLiveHintList(items, more_count, start_x, start_y) {
    global live_hint_bbox, g_mem_dc, live_hint_chain_text

    g := GetOverlayGraphics()
    if !g {
        return
    }

    _ClearLiveHintBox(g)

    fs := CONF.font_size_lh.v
    has_items := items.Length > 0
    preview_w := has_items ? Round(Max(fs * 2.18, 44)) : 0
    preview_h := Round(Max(fs * 1.15, 23))
    gap := has_items ? Round(Max(fs * 0.40, 8)) : 0
    score_w := HasLiveHintScores(items) ? Round(Max(fs * 2.48, 53)) : 0
    pad_x := Round(Max(fs * 0.55, 10))
    pad_y := Round(Max(fs * 0.35, 7))
    row_h := Max(preview_h, Round(fs * 1.36))
    header_h := live_hint_chain_text ? Round(fs * 1.18) : 0
    footer_h := more_count > 0 ? Round(fs * 1.12) : 0

    res := GetLiveHintResources(fs)
    if !res {
        return
    }
    fnt := res.fnt
    fnt_bold := res.fnt_bold
    fmt := res.fmt
    brush_fg := res.brush_fg
    single_item := items.Length == 1
    DllCall("gdiplus\GdipSetStringFormatAlign", "ptr", fmt, "int", single_item ? 1 : 0)
    DllCall("gdiplus\GdipSetStringFormatLineAlign", "ptr", fmt, "int", 1)
    DllCall("gdiplus\GdipSetStringFormatTrimming", "ptr", fmt, "int", 3)

    text_w := GetLiveHintTextWidth(g, fnt, fnt_bold, fmt, items, more_count, live_hint_chain_text)
    try {
        fixed_w := Max(0, Integer(CONF.live_hint_box_width.v))
    } catch {
        fixed_w := 0
    }
    if fixed_w {
        try {
            box_w := Max(Integer(fixed_w), preview_w + score_w + gap * 2 + pad_x * 2 + 40)
        } catch {
            box_w := preview_w + score_w + gap * 2 + text_w + pad_x * 2
        }
    } else {
        box_w := preview_w + score_w + gap * (score_w ? 2 : 1) + text_w + pad_x * 2
    }
    max_text_w := Max(box_w - preview_w - score_w - gap * (score_w ? 2 : 1) - pad_x * 2, 20)
    box_h := header_h + items.Length * row_h + footer_h + pad_y * 2
    box_pt := GetLiveHintBoxPos(box_w, box_h, start_x, start_y)
    x := box_pt[1]
    y := box_pt[2]

    bg := Trim(CONF.live_hint_bg_color.v)
    if bg {
        try {
            DllCall("gdiplus\GdipCreateSolidFill",
                "uint", (_ClampAlpha(CONF.live_hint_opacity.v) << 24) | ParseAhkColor(bg),
                "ptr*", &brush_bg:=0)
            FillLiveHintBackground(g, brush_bg, x, y, box_w, box_h)
            DllCall("gdiplus\GdipDeleteBrush", "ptr", brush_bg)
        }
    }

    tx := x + pad_x + preview_w + gap
    score_x := tx
    if score_w {
        tx += score_w + gap
    }
    ty := y + pad_y
    if live_hint_chain_text {
        rect_header := Buffer(16, 0)
        NumPut("float", x + pad_x, rect_header, 0)
        NumPut("float", ty, rect_header, 4)
        NumPut("float", box_w - pad_x * 2, rect_header, 8)
        NumPut("float", header_h, rect_header, 12)
        DllCall("gdiplus\GdipSetStringFormatAlign", "ptr", fmt, "int", 1)
        DllCall("gdiplus\GdipDrawString", "ptr", g, "wstr", live_hint_chain_text,
            "int", StrLen(live_hint_chain_text), "ptr", fnt_bold, "ptr", rect_header,
            "ptr", fmt, "ptr", brush_fg)
        ty += header_h
    }
    preview_colors := GetLiveHintThumbnailColors()
    for item in items {
        text_font := A_Index == 1 && item.HasProp("score") && item.score >= CONF.min_cos_similarity.v
            ? fnt_bold : fnt
        icon := GetLiveHintPreviewIcon(item.node, preview_w, preview_h, preview_colors)
        if icon {
            DllCall("DrawIconEx", "ptr", g_mem_dc,
                "int", x + pad_x, "int", ty + (row_h - preview_h) // 2,
                "ptr", icon, "int", preview_w, "int", preview_h, "uint", 0, "ptr", 0, "uint", 3)
        }
        if item.HasProp("score") {
            score_text := Format("{:.2f}", item.score)
            rect_score := Buffer(16, 0)
            NumPut("float", score_x, rect_score, 0)
            NumPut("float", ty, rect_score, 4)
            NumPut("float", score_w, rect_score, 8)
            NumPut("float", row_h, rect_score, 12)
            DllCall("gdiplus\GdipDrawString", "ptr", g, "wstr", score_text, "int", StrLen(score_text),
                "ptr", text_font, "ptr", rect_score, "ptr", fmt, "ptr", brush_fg)
        }
        rect := Buffer(16, 0)
        NumPut("float", tx, rect, 0)
        NumPut("float", ty, rect, 4)
        NumPut("float", max_text_w, rect, 8)
        NumPut("float", row_h, rect, 12)
        DllCall("gdiplus\GdipSetStringFormatAlign", "ptr", fmt, "int", single_item ? 1 : 0)
        DllCall("gdiplus\GdipDrawString", "ptr", g, "wstr", item.name, "int", StrLen(item.name),
            "ptr", text_font, "ptr", rect, "ptr", fmt, "ptr", brush_fg)
        ty += row_h
    }
    if more_count > 0 {
        footer := "...and " . more_count . " more"
        rect := Buffer(16, 0)
        NumPut("float", x + pad_x, rect, 0)
        NumPut("float", ty, rect, 4)
        NumPut("float", box_w - pad_x * 2, rect, 8)
        NumPut("float", footer_h, rect, 12)
        DllCall("gdiplus\GdipSetStringFormatAlign", "ptr", fmt, "int", single_item ? 1 : 0)
        DllCall("gdiplus\GdipDrawString", "ptr", g, "wstr", footer, "int", StrLen(footer),
            "ptr", fnt, "ptr", rect, "ptr", fmt, "ptr", brush_fg)
    }

    live_hint_bbox := [x, y, box_w, box_h]
    PresentOverlay()
}


GetLiveHintResources(fs) {
    global live_hint_res

    try {
        fg := ParseAhkColor(CONF.live_hint_text_color.v)
    } catch {
        fg := 0xFFFFFF
    }
    sig := fs . "|" . fg
    if live_hint_res && live_hint_res.sig == sig {
        return live_hint_res
    }

    ClearLiveHintResources()
    fam := 0
    fam_bold := 0
    fnt := 0
    fnt_bold := 0
    fmt := 0
    brush_fg := 0
    if DllCall("gdiplus\GdipCreateFontFamilyFromName", "wstr", "Segoe UI Semibold", "ptr", 0, "ptr*", &fam:=0) {
        DllCall("gdiplus\GdipCreateFontFamilyFromName", "wstr", "Segoe UI", "ptr", 0, "ptr*", &fam:=0)
    }
    if DllCall("gdiplus\GdipCreateFontFamilyFromName", "wstr", "Segoe UI", "ptr", 0, "ptr*", &fam_bold:=0) {
        fam_bold := fam
    }
    if DllCall("gdiplus\GdipCreateFont", "ptr", fam, "float", fs, "int", 0, "int", 2, "ptr*", &fnt:=0) {
        ClearLiveHintResourceHandles(fam, fam_bold, fnt, fnt_bold, fmt, brush_fg)
        return false
    }
    if DllCall("gdiplus\GdipCreateFont", "ptr", fam_bold, "float", fs, "int", 1, "int", 2, "ptr*", &fnt_bold:=0) {
        ClearLiveHintResourceHandles(fam, fam_bold, fnt, fnt_bold, fmt, brush_fg)
        return false
    }
    DllCall("gdiplus\GdipStringFormatGetGenericDefault", "ptr*", &fmt:=0)
    DllCall("gdiplus\GdipSetStringFormatLineAlign", "ptr", fmt, "int", 1)
    DllCall("gdiplus\GdipSetStringFormatTrimming", "ptr", fmt, "int", 3)
    DllCall("gdiplus\GdipCreateSolidFill", "uint", (255 << 24) | fg, "ptr*", &brush_fg:=0)

    live_hint_res := {
        sig: sig,
        fam: fam,
        fam_bold: fam_bold,
        fnt: fnt,
        fnt_bold: fnt_bold,
        fmt: fmt,
        brush_fg: brush_fg,
    }
    return live_hint_res
}


ClearLiveHintResources() {
    global live_hint_res

    if !live_hint_res {
        return
    }
    ClearLiveHintResourceHandles(
        live_hint_res.fam,
        live_hint_res.fam_bold,
        live_hint_res.fnt,
        live_hint_res.fnt_bold,
        live_hint_res.fmt,
        live_hint_res.brush_fg
    )
    live_hint_res := false
}


ClearLiveHintResourceHandles(fam, fam_bold, fnt, fnt_bold, fmt, brush_fg) {
    if brush_fg {
        try DllCall("gdiplus\GdipDeleteBrush", "ptr", brush_fg)
    }
    if fmt {
        try DllCall("gdiplus\GdipDeleteStringFormat", "ptr", fmt)
    }
    if fnt_bold {
        try DllCall("gdiplus\GdipDeleteFont", "ptr", fnt_bold)
    }
    if fnt {
        try DllCall("gdiplus\GdipDeleteFont", "ptr", fnt)
    }
    if fam_bold && fam_bold != fam {
        try DllCall("gdiplus\GdipDeleteFontFamily", "ptr", fam_bold)
    }
    if fam {
        try DllCall("gdiplus\GdipDeleteFontFamily", "ptr", fam)
    }
}


GetLiveHintPreviewIcon(node, w, h, colors) {
    global live_hint_icon_cache

    key := ObjPtr(node) . "|" . w . "x" . h . "|" . GestureColorSignature(colors)
    if !live_hint_icon_cache.Has(key) {
        live_hint_icon_cache[key] := CreateGesturePreviewHIcon(node, w, h, false, false, colors)
    }
    return live_hint_icon_cache[key]
}


GestureColorSignature(colors) {
    if !(colors is Array) {
        return ""
    }

    out := ""
    for clr in colors {
        out .= Format("{:06X}", clr) . ","
    }
    return out
}


ClearLiveHintIconCache() {
    global live_hint_icon_cache

    for _, icon in live_hint_icon_cache {
        if icon {
            DllCall("DestroyIcon", "ptr", icon)
        }
    }
    live_hint_icon_cache := Map()
}


GetLiveHintThumbnailColors() {
    global overlay_opts

    colour := Trim(CONF.live_hint_thumbnail_color.v)
    if colour {
        colors := ParseAhkColorList(colour)
        if colors.Length {
            return colors
        }
        return [0x202020]
    }

    try {
        if overlay_opts is Object && overlay_opts.HasOwnProp("gest_colors") {
            return overlay_opts.gest_colors
        }
    }
    return [0x202020]
}


HasLiveHintScores(items) {
    for item in items {
        if item.HasProp("score") {
            return true
        }
    }
    return false
}


GetLiveHintTextWidth(g, fnt, fnt_bold, fmt, items, more_count, chain_text:="") {
    max_w := 0
    if chain_text {
        max_w := Max(max_w, MeasureLiveHintTextWidth(g, fnt_bold, fmt, chain_text))
    }
    for i, item in items {
        font := i == 1 && item.HasProp("score") && item.score >= CONF.min_cos_similarity.v
            ? fnt_bold : fnt
        max_w := Max(max_w, MeasureLiveHintTextWidth(g, font, fmt, item.name))
    }
    if more_count > 0 {
        max_w := Max(max_w, MeasureLiveHintTextWidth(g, fnt, fmt, "...and " . more_count . " more"))
    }
    return Ceil(Max(max_w, 20))
}


FillLiveHintBackground(g, brush, x, y, w, h) {
    r := Min(10, Floor(Min(w, h) / 3))
    if r < 2 {
        DllCall("gdiplus\GdipFillRectangle", "ptr", g, "ptr", brush,
            "float", x, "float", y, "float", w, "float", h)
        return
    }

    tl := x >= 6 && y >= 6
    tr := x + w <= A_ScreenWidth - 6 && y >= 6
    br := x + w <= A_ScreenWidth - 6 && y + h <= A_ScreenHeight - 6
    bl := x >= 6 && y + h <= A_ScreenHeight - 6

    DllCall("gdiplus\GdipCreatePath", "int", 0, "ptr*", &path:=0)
    DllCall("gdiplus\GdipStartPathFigure", "ptr", path)

    if tl {
        DllCall("gdiplus\GdipAddPathArc", "ptr", path,
            "float", x, "float", y, "float", r * 2, "float", r * 2, "float", 180, "float", 90)
    } else {
        DllCall("gdiplus\GdipAddPathLine", "ptr", path, "float", x, "float", y, "float", x, "float", y)
    }

    DllCall("gdiplus\GdipAddPathLine", "ptr", path,
        "float", x + (tl ? r : 0), "float", y, "float", x + w - (tr ? r : 0), "float", y)
    if tr {
        DllCall("gdiplus\GdipAddPathArc", "ptr", path,
            "float", x + w - r * 2, "float", y, "float", r * 2, "float", r * 2,
            "float", 270, "float", 90)
    }

    DllCall("gdiplus\GdipAddPathLine", "ptr", path,
        "float", x + w, "float", y + (tr ? r : 0), "float", x + w, "float", y + h - (br ? r : 0))
    if br {
        DllCall("gdiplus\GdipAddPathArc", "ptr", path,
            "float", x + w - r * 2, "float", y + h - r * 2, "float", r * 2, "float", r * 2,
            "float", 0, "float", 90)
    }

    DllCall("gdiplus\GdipAddPathLine", "ptr", path,
        "float", x + w - (br ? r : 0), "float", y + h, "float", x + (bl ? r : 0), "float", y + h)
    if bl {
        DllCall("gdiplus\GdipAddPathArc", "ptr", path,
            "float", x, "float", y + h - r * 2, "float", r * 2, "float", r * 2,
            "float", 90, "float", 90)
    }

    DllCall("gdiplus\GdipAddPathLine", "ptr", path,
        "float", x, "float", y + h - (bl ? r : 0), "float", x, "float", y + (tl ? r : 0))
    DllCall("gdiplus\GdipClosePathFigure", "ptr", path)
    DllCall("gdiplus\GdipFillPath", "ptr", g, "ptr", brush, "ptr", path)
    DllCall("gdiplus\GdipDeletePath", "ptr", path)
}


MeasureLiveHintTextWidth(g, fnt, fmt, text) {
    rect := Buffer(16, 0)
    NumPut("float", 0, rect, 0)
    NumPut("float", 0, rect, 4)
    NumPut("float", 2000, rect, 8)
    NumPut("float", 200, rect, 12)
    bbox := Buffer(16, 0)
    DllCall("gdiplus\GdipMeasureString", "ptr", g, "wstr", text, "int", StrLen(text),
        "ptr", fnt, "ptr", rect, "ptr", fmt, "ptr", bbox, "uint*", &cp:=0, "uint*", &lns:=0)
    return NumGet(bbox, 8, "float")
}


GetLiveHintBoxPos(w, h, start_x, start_y) {
    primary_i := CONF.gest_live_hint.v
    start_pool := GetCoarseLiveHintPool(GetPool(start_x, start_y))
    if start_pool == GetCoarseLiveHintPool(primary_i) {
        return GetLiveHintBoxPosByIndex(CONF.live_hint_alt.v, w, h)
    }
    return GetLiveHintBoxPosByIndex(primary_i, w, h)
}


GetLiveHintBoxPosByIndex(placement_i, w, h) {
    margin := Max(CONF.live_hint_margin.v, 0)
    col := Mod(placement_i - 1, 3)
    row := (placement_i - 1) // 3
    x := col == 0 ? margin : col == 1 ? (A_ScreenWidth - w) / 2 : A_ScreenWidth - w - margin
    y := row == 0 ? margin : row == 1 ? (A_ScreenHeight - h) / 2 : A_ScreenHeight - h - margin
    return [Floor(x), Floor(y), x + w / 2, y + h / 2]
}


GetCoarseLiveHintPool(pool) {
    pool := ParseGesturePool(pool)
    return pool ~= "i)^[a-d]$" ? 5 : pool
}


ClearLiveHintBox() {
    global live_hint_draw_sig

    g := GetOverlayGraphics()
    if g {
        _ClearLiveHintBox(g)
        PresentOverlay()
    }
    live_hint_draw_sig := ""
}


_ClearLiveHintBox(g) {
    global live_hint_bbox

    if !live_hint_bbox {
        return
    }
    DllCall("gdiplus\GdipCreateSolidFill", "uint", 0x00000000, "ptr*", &brush_clear:=0)
    DllCall("gdiplus\GdipSetCompositingMode", "ptr", g, "int", 1)  ; SourceCopy
    DllCall("gdiplus\GdipFillRectangle", "ptr", g, "ptr", brush_clear,
        "float", live_hint_bbox[1] - 1, "float", live_hint_bbox[2] - 1,
        "float", live_hint_bbox[3] + 2, "float", live_hint_bbox[4] + 2)
    DllCall("gdiplus\GdipSetCompositingMode", "ptr", g, "int", 0)  ; SourceOver
    DllCall("gdiplus\GdipDeleteBrush", "ptr", brush_clear)
    live_hint_bbox := false
}


DrawExisting(gesture_obj) {
    global cur_grad_len

    SetTimer(DestroyGestOverlay, 0)
    ResetGestureOverlayFade(FadeGestureOverlay)
    CreateGestOverlay()
    ClearOverlay()
    gest_overlay.Show("NA")

    anchor := GetGesturePoolAnchor(gesture_obj.opts.pool)
    hx := anchor[1]
    hy := anchor[2]
    h := gesture_obj.opts.scaling = 0 ? A_ScreenHeight : 1
    vec := gesture_obj.vec.Clone()

    if gesture_obj.opts.closed {  ; show phase shift
        pts_cnt := vec.Length // 2
        if pts_cnt > 2 {
            sh := Random(0, pts_cnt - 1)
            if sh {
                vec := _RotateVecStart(vec, sh)
            }
        }
    }

    if gesture_obj.opts.dirs && Random(0, 1) > 0.5 {  ; show bidir
        rev := []
        i := vec.Length
        while i >= 2 {
            rev.Push(vec[i - 1], vec[i])
            i -= 2
        }
        vec := rev
    }

    if !GetGesturePoolGroup(gesture_obj.opts.pool) {
        min_x := max_x := vec[1]
        min_y := max_y := vec[2]
        i := 3
        while i <= vec.Length {
            x := vec[i]
            y := vec[i+1]

            if x < min_x {
                min_x := x
            } else if x > max_x {
                max_x := x
            }

            if y < min_y {
                min_y := y
            } else if y > max_y {
                max_y := y
            }

            i += 2
        }

        cx := (min_x + max_x) / 2
        cy := (min_y + max_y) / 2

        i := 1
        while i <= vec.Length {
            vec[i] -= cx
            vec[i+1] -= cy
            i += 2
        }
    }

    prev_x := vec[1] * h + hx
    prev_y := vec[2] * h + hy
    prev_w := 0
    len := 0
    i := 3
    b := true
    Critical
    while i < vec.Length {
        if !gest_overlay {
            return
        }
        x := vec[i] * h + hx
        y := vec[i+1] * h + hy
        dx := x - prev_x
        dy := y - prev_y
        d := Sqrt(dx*dx + dy*dy)
        len += d

        if gesture_obj.opts.closed {
            prog := (i - 3) / Max(vec.Length - 3, 1)
            target := Round(1 + (w_max - 1) * Sin(prog * PI))
            width := target
        } else {
            target := BrushWidth(len)
            width := target
            if target > prev_w {
                width := Min(target, prev_w + 1)
            }
        }

        try {
            DrawLine(prev_x, prev_y, x, y, width)
        } catch {
            SetTimer(DestroyGestOverlay, 0)
            return
        }
        prev_x := x
        prev_y := y
        prev_w := width
        i += 2
        PresentOverlay()
        if b {
            Sleep(1)
        }
        b := !b
    }
    cur_grad_len := 0
    SetTimer(FadeGestureOverlay, -300)
}


FadeGestureOverlay(*) {
    FadeGestureOverlayStep(FadeGestureOverlay, DestroyGestOverlay)
}


FadeGestureOverlayStep(timer_fn, finish_fn, reset:=false) {
    static steps_by_timer:=Map()

    key := timer_fn.Name

    if reset {
        if steps_by_timer.Has(key) {
            steps_by_timer.Delete(key)
        }
        SetTimer(timer_fn, 0)
        return
    }

    if !gest_overlay {
        if steps_by_timer.Has(key) {
            steps_by_timer.Delete(key)
        }
        return
    }

    step := steps_by_timer.Get(key, 0) + 1
    steps := 8
    if step >= steps {
        if steps_by_timer.Has(key) {
            steps_by_timer.Delete(key)
        }
        finish_fn.Call()
        return
    }

    steps_by_timer[key] := step
    PresentOverlay(Round(255 * (steps - step) / steps))
    SetTimer(timer_fn, -50)
}


ResetGestureOverlayFade(timer_fn) {
    FadeGestureOverlayStep(timer_fn, (*) => 0, true)
}


CreateGesturePreviewHIcon(gesture_obj, w:=58, h:=34, show_pool:=false, bottom_rule:=false, stroke_colors:=false) {
    if !GdipStartup() || !gesture_obj.vec.Length {
        return 0
    }

    if DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", w, "int", h,
        "int", 0, "int", 0xE200B, "ptr", 0, "ptr*", &bmp:=0) {
        return 0
    }
    if DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", bmp, "ptr*", &g:=0) {
        DllCall("gdiplus\GdipDisposeImage", "ptr", bmp)
        return 0
    }

    DllCall("gdiplus\GdipSetSmoothingMode", "ptr", g, "int", 4)
    DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", g, "int", 3)

    DllCall("gdiplus\GdipCreateSolidFill", "uint", 0x00FFFFFF, "ptr*", &brush_bg:=0)
    DllCall("gdiplus\GdipFillRectangle", "ptr", g, "ptr", brush_bg,
        "float", 0, "float", 0, "float", w, "float", h)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", brush_bg)

    vec := gesture_obj.vec
    min_x := max_x := vec[1]
    min_y := max_y := vec[2]
    i := 3
    while i <= vec.Length {
        min_x := Min(min_x, vec[i])
        max_x := Max(max_x, vec[i])
        min_y := Min(min_y, vec[i + 1])
        max_y := Max(max_y, vec[i + 1])
        i += 2
    }

    margin := Max(Round(3.5 * CONF.gui_scale.v), 2)
    span_x := Max(max_x - min_x, 0.001)
    span_y := Max(max_y - min_y, 0.001)
    scale := Min((w - margin * 2) / span_x, (h - margin * 2) / span_y)
    off_x := (w - span_x * scale) / 2
    off_y := (h - span_y * scale) / 2

    map_x(x) => off_x + (x - min_x) * scale
    map_y(y) => off_y + (y - min_y) * scale

    prev_x := map_x(vec[1])
    prev_y := map_y(vec[2])
    total_segments := Max(vec.Length // 2 - 1, 1)
    segment_i := 1
    i := 3
    while i <= vec.Length {
        x := map_x(vec[i])
        y := map_y(vec[i + 1])
        t := (segment_i - 0.5) / total_segments
        smooth_t := t * t * (3 - 2 * t)
        width := Max((0.75 + 1.75 * smooth_t) * CONF.gui_scale.v, 0.75)
        line_color := GesturePreviewStrokeColor(stroke_colors, t)
        DrawGesturePreviewSoftLine(g, prev_x, prev_y, x, y, width, line_color)
        prev_x := x
        prev_y := y
        segment_i += 1
        i += 2
    }

    if show_pool {
        DrawGesturePreviewPoolMarker(g, gesture_obj.opts.pool, w, h)
    }
    if bottom_rule {
        DrawGesturePreviewBottomRule(g, w, h)
    }

    hicon := 0
    DllCall("gdiplus\GdipCreateHICONFromBitmap", "ptr", bmp, "ptr*", &hicon)
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", g)
    DllCall("gdiplus\GdipDisposeImage", "ptr", bmp)
    return hicon
}


DrawGesturePreviewSoftLine(g, x1, y1, x2, y2, width, argb) {
    opacity := (argb >> 24) & 0xFF
    rgb := argb & 0xFFFFFF
    soft_argb := (Round(opacity * 0.3) << 24) | rgb
    dx := x2 - x1
    dy := y2 - y1
    len := Sqrt(dx * dx + dy * dy)
    if len {
        ox := -dy / len
        oy := dx / len
    } else {
        ox := 0
        oy := 0
    }

    for shift in [0, 1] {
        sx := ox * shift
        sy := oy * shift
        DllCall("gdiplus\GdipCreatePen1", "uint", soft_argb,
            "float", width, "int", 2, "ptr*", &pen:=0)
        DllCall("gdiplus\GdipSetPenStartCap", "ptr", pen, "int", 2)
        DllCall("gdiplus\GdipSetPenEndCap", "ptr", pen, "int", 2)
        DllCall("gdiplus\GdipSetPenLineJoin", "ptr", pen, "int", 2)
        DllCall("gdiplus\GdipDrawLine", "ptr", g, "ptr", pen,
            "float", x1 + sx, "float", y1 + sy, "float", x2 + sx, "float", y2 + sy)
        DllCall("gdiplus\GdipDeletePen", "ptr", pen)
    }
}


GesturePreviewStrokeColor(colors, t) {
    if !(colors is Array) || !colors.Length {
        return 0xDD202020
    }
    if colors.Length == 1 {
        return 0xDD000000 | colors[1]
    }

    color_lerp_fn := (CONF.gest_color_mode.v == "HSV"
        ? ColorLerpHsv
        : CONF.gest_color_mode.v == "RGB"
            ? ColorLerp
            : ColorLerpLinRgb)
    seg_count := colors.Length - 1
    p := (t < 0 ? 0 : (t > 1 ? 1 : t)) * seg_count
    seg := Floor(p)
    if seg >= seg_count {
        seg := seg_count - 1
    }
    return 0xDD000000 | color_lerp_fn(colors[seg + 1], colors[seg + 2], p - seg)
}


DrawGesturePreviewPoolMarker(g, pool, w, h) {
    pool := ParseGesturePool(pool)
    if pool == 5 {
        return
    }

    r := Max(3 * CONF.gui_scale.v, 2.5)
    marker_pt := GesturePreviewPoolMarkerPos(pool, w, h, r)
    pts := Buffer(4 * 2 * 4, 0)
    NumPut("Float", marker_pt[1], "Float", marker_pt[2] - r, pts, 0)
    NumPut("Float", marker_pt[1] + r, "Float", marker_pt[2], pts, 8)
    NumPut("Float", marker_pt[1], "Float", marker_pt[2] + r, pts, 16)
    NumPut("Float", marker_pt[1] - r, "Float", marker_pt[2], pts, 24)
    try {
        marker_color := ParseAhkColor(CONF.gest_pool_marker_color.v)
    } catch {
        marker_color := 0x2EAD64
    }
    DllCall("gdiplus\GdipCreateSolidFill", "uint", 0xFF000000 | marker_color, "ptr*", &brush:=0)
    DllCall("gdiplus\GdipFillPolygon", "ptr", g, "ptr", brush, "ptr", pts, "int", 4, "int", 0)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", brush)
}


DrawGesturePreviewBottomRule(g, w, h) {
    peak_alpha := 0x44
    y := h - 0.5
    loop w {
        x := A_Index - 1
        t := x / Max(w - 1, 1)
        opacity := t < 0.4 ? Round(peak_alpha * t / 0.4)
            : t < 0.6 ? peak_alpha
            : Round(peak_alpha * (1 - t) / 0.4)
        if !opacity {
            continue
        }
        DllCall("gdiplus\GdipCreatePen1", "uint", (opacity << 24) | 0x777777,
            "float", 1, "int", 2, "ptr*", &pen:=0)
        DllCall("gdiplus\GdipDrawLine", "ptr", g, "ptr", pen,
            "float", x, "float", y, "float", x + 1, "float", y)
        DllCall("gdiplus\GdipDeletePen", "ptr", pen)
    }
}


GesturePreviewPoolMarkerPos(pool, w, h, r) {
    if pool ~= "i)^[a-d]$" {
        pool := StrLower(pool)
        switch CONF.gest_center_mode.v {
            case "Grid", "Single":
                switch pool {
                    case "a":
                        return [r, r]
                    case "b":
                        return [w - r - 1, r]
                    case "c":
                        return [w - r - 1, h - r - 1]
                    case "d":
                        return [r, h - r - 1]
                }
            case "Diagonal":
                switch pool {
                    case "a":
                        return [w / 2, r]
                    case "b":
                        return [w - r - 1, h / 2]
                    case "c":
                        return [w / 2, h - r - 1]
                    case "d":
                        return [r, h / 2]
                }
        }
    }

    switch pool {
        case 1:
            return [0, 0]
        case 2:
            return [w / 2, -1]
        case 3:
            return [w - 1, 0]
        case 4:
            return [-1, h / 2]
        case 6:
            return [w, h / 2]
        case 7:
            return [0, h - 1]
        case 8:
            return [w / 2, h]
        case 9:
            return [w - 1, h - 1]
    }

    return [w / 2, h / 2]
}


_RotateVecStart(vec, point_shift) {
    pts_cnt := vec.Length // 2
    if pts_cnt <= 1 {
        return vec.Clone()
    }

    point_shift := Mod(point_shift, pts_cnt)
    if point_shift == 0 {
        return vec.Clone()
    }

    out := []
    start := point_shift * 2 + 1
    i := start
    while i <= vec.Length {
        out.Push(vec[i], vec[i + 1])
        i += 2
    }
    i := 1
    while i < start {
        out.Push(vec[i], vec[i + 1])
        i += 2
    }
    return out
}


GetGestureZoneOverrideIndex(key, offset) {
    first_zone_opt_i := 2
    fields_per_zone := 3  ; colors, gradient length, gradient loop
    fallback_zone_i := 5  ; C

    for i, zone in GestureColorZones {
        if zone[2] == key {
            return first_zone_opt_i + (i - 1) * fields_per_zone + offset
        }
    }

    return first_zone_opt_i + (fallback_zone_i - 1) * fields_per_zone + offset
}


GetGesturePoolAnchor(pool) {
    w := A_ScreenWidth
    h := A_ScreenHeight

    switch pool {
        case 1:
            return [GestureZoneInset(CONF.gest_zone_tl.v), GestureZoneInset(CONF.gest_zone_tl.v)]
        case 2:
            return [w // 2, GestureZoneInset(CONF.gest_zone_t.v)]
        case 3:
            e := GestureZoneInset(CONF.gest_zone_tr.v)
            return [w - e, e]
        case 4:
            return [GestureZoneInset(CONF.gest_zone_l.v), h // 2]
        case 6:
            return [w - GestureZoneInset(CONF.gest_zone_r.v), h // 2]
        case 7:
            e := GestureZoneInset(CONF.gest_zone_bl.v)
            return [e, h - e]
        case 8:
            return [w // 2, h - GestureZoneInset(CONF.gest_zone_b.v)]
        case 9:
            e := GestureZoneInset(CONF.gest_zone_br.v)
            return [w - e, h - e]
        case "a":
            return CONF.gest_center_mode.v == "Diagonal" ? [w // 2, h // 4] : [w // 4, h // 4]
        case "b":
            return CONF.gest_center_mode.v == "Diagonal" ? [w * 3 // 4, h // 2]
                : [w * 3 // 4, h // 4]
        case "c":
            return CONF.gest_center_mode.v == "Diagonal" ? [w // 2, h * 3 // 4]
                : [w * 3 // 4, h * 3 // 4]
        case "d":
            return CONF.gest_center_mode.v == "Diagonal" ? [w // 4, h // 2] : [w // 4, h * 3 // 4]
    }

    return [w // 2, h // 2]
}


GestureZoneInset(size) {
    return Max(size // 2, 32)
}


ShowGestureZonePreview(opts, mode:="On") {
    global zone_preview_mode

    SetTimer(HideGestureZonePreview, 0)
    ResetGestureOverlayFade(FadeGestureZonePreview)
    if mode == "Off" {
        HideGestureZonePreview()
        return
    }

    zone_preview_mode := mode
    DrawGestureZonePreview(opts)
    if mode == "Blink" {
        SetTimer(FadeGestureZonePreview, -700)
    }
}


HideGestureZonePreview(*) {
    global zone_preview_mode

    SetTimer(HideGestureZonePreview, 0)
    ResetGestureOverlayFade(FadeGestureZonePreview)
    zone_preview_mode := "Off"
    if !is_drawing {
        DestroyGestOverlay()
    }
}


FadeGestureZonePreview(*) {
    if !gest_overlay || is_drawing {
        HideGestureZonePreview()
        return
    }

    FadeGestureOverlayStep(FadeGestureZonePreview, HideGestureZonePreview)
}


DrawGestureZonePreview(opts) {
    global g_overlay_w, g_overlay_h, g_overlay_bottom_gap

    if is_drawing {
        return
    }

    if !gest_overlay || g_overlay_bottom_gap !== 1 {
        CreateGestOverlay(1)
    }
    if !gest_overlay {
        return
    }

    ClearOverlay()
    gest_overlay.Show("NA")
    w := g_overlay_w
    h := g_overlay_h
    colour := opts.HasProp("color") ? opts.color : 0x00F400

    DrawGesturePreviewCorner(0, 0, opts.tl, "TL", colour)
    DrawGesturePreviewCorner(w, 0, opts.tr, "TR", colour)
    DrawGesturePreviewCorner(w, h, opts.br, "BR", colour)
    DrawGesturePreviewCorner(0, h, opts.bl, "BL", colour)

    DrawGesturePreviewEdges(opts, w, h, colour)

    switch opts.center_mode {
        case "Grid":
            DrawGesturePreviewGridCenter(opts, w, h, colour)
        case "Diagonal":
            DrawGesturePreviewDiagonalCenter(opts, w, h, colour)
    }

    PresentOverlay()
}


DrawGesturePreviewCorner(x, y, size, corner, colour) {
    if !size {
        return
    }

    switch corner {
        case "TL":
            DrawGesturePreviewLine(size, 0, size, size, 1, colour)
            DrawGesturePreviewLine(0, size, size, size, 1, colour)
        case "TR":
            DrawGesturePreviewLine(x - size, 0, x - size, size, 1, colour)
            DrawGesturePreviewLine(x - size, size, x, size, 1, colour)
        case "BR":
            DrawGesturePreviewLine(x - size, y - size, x - size, y, 1, colour)
            DrawGesturePreviewLine(x - size, y - size, x, y - size, 1, colour)
        case "BL":
            DrawGesturePreviewLine(size, y - size, size, y, 1, colour)
            DrawGesturePreviewLine(0, y - size, size, y - size, 1, colour)
    }
}


DrawGesturePreviewEdges(opts, w, h, colour) {
    tl_t := GesturePreviewEdgeCut(opts.tl, opts.t)
    tr_t := GesturePreviewEdgeCut(opts.tr, opts.t)
    br_b := GesturePreviewEdgeCut(opts.br, opts.b)
    bl_b := GesturePreviewEdgeCut(opts.bl, opts.b)

    tl_l := GesturePreviewEdgeCut(opts.tl, opts.l)
    tr_r := GesturePreviewEdgeCut(opts.tr, opts.r)
    br_r := GesturePreviewEdgeCut(opts.br, opts.r)
    bl_l := GesturePreviewEdgeCut(opts.bl, opts.l)

    DrawGesturePreviewLine(tl_t, opts.t, w - tr_t, opts.t, opts.t, colour)
    DrawGesturePreviewLine(w - opts.r, tr_r, w - opts.r, h - br_r, opts.r, colour)
    DrawGesturePreviewLine(bl_b, h - opts.b, w - br_b, h - opts.b, opts.b, colour)
    DrawGesturePreviewLine(opts.l, tl_l, opts.l, h - bl_l, opts.l, colour)

    DrawGesturePreviewCornerJoin(0, 0, 1, 1, opts.tl, opts.l, opts.t, colour)
    DrawGesturePreviewCornerJoin(w, 0, -1, 1, opts.tr, opts.r, opts.t, colour)
    DrawGesturePreviewCornerJoin(w, h, -1, -1, opts.br, opts.r, opts.b, colour)
    DrawGesturePreviewCornerJoin(0, h, 1, -1, opts.bl, opts.l, opts.b, colour)
}


GesturePreviewEdgeCut(corner, own_side) {
    return own_side > corner ? own_side : corner
}


DrawGesturePreviewCornerJoin(x, y, sx, sy, corner, side_x, side_y, colour) {
    far := Max(side_x, side_y)
    if !far || corner >= far {
        return
    }

    DrawGesturePreviewLine(x + sx * corner, y + sy * corner, x + sx * far, y + sy * far, 1, colour)
}


DrawGesturePreviewGridCenter(opts, w, h, colour) {
    x := w / 2
    y := h / 2
    DrawGesturePreviewLine(x, GesturePreviewGridTopCut(opts, x, w),
        x, h - GesturePreviewGridBottomCut(opts, x, w), 1, colour)
    DrawGesturePreviewLine(GesturePreviewGridLeftCut(opts, y, h), y,
        w - GesturePreviewGridRightCut(opts, y, h), y, 1, colour)
}


DrawGesturePreviewDiagonalCenter(opts, w, h, colour) {
    rect := GesturePreviewCenterRect(opts, w, h)
    DrawGesturePreviewClippedLine(0, 0, w, h, rect, colour, "TL", opts.tl, "BR", opts.br)
    DrawGesturePreviewClippedLine(0, h, w, 0, rect, colour, "BL", opts.bl, "TR", opts.tr)
}


GesturePreviewCenterRect(opts, w, h) {
    return [opts.l, opts.t, w - opts.r, h - opts.b]
}


GesturePreviewGridTopCut(opts, x, w) {
    return Max(opts.t, opts.tl > x ? opts.tl : 0, opts.tr > w - x ? opts.tr : 0)
}


GesturePreviewGridBottomCut(opts, x, w) {
    return Max(opts.b, opts.bl > x ? opts.bl : 0, opts.br > w - x ? opts.br : 0)
}


GesturePreviewGridLeftCut(opts, y, h) {
    return Max(opts.l, opts.tl > y ? opts.tl : 0, opts.bl > h - y ? opts.bl : 0)
}


GesturePreviewGridRightCut(opts, y, h) {
    return Max(opts.r, opts.tr > y ? opts.tr : 0, opts.br > h - y ? opts.br : 0)
}


DrawGesturePreviewClippedLine(
    x1, y1, x2, y2, rect, colour, start_corner:="", start_size:=0, end_corner:="", end_size:=0
) {
    x_min := rect[1]
    y_min := rect[2]
    x_max := rect[3]
    y_max := rect[4]
    dx := x2 - x1
    dy := y2 - y1
    w := Max(x1, x2)
    h := Max(y1, y2)
    t0 := 0.0
    t1 := 1.0

    for edge in [
        [-dx, x1 - x_min],
        [dx, x_max - x1],
        [-dy, y1 - y_min],
        [dy, y_max - y1],
    ] {
        p := edge[1]
        q := edge[2]
        if !p {
            if q < 0 {
                return
            }
            continue
        }

        r := q / p
        if p < 0 {
            if r > t1 {
                return
            }
            t0 := Max(t0, r)
        } else {
            if r < t0 {
                return
            }
            t1 := Min(t1, r)
        }
    }

    sx := x1 + dx * t0
    sy := y1 + dy * t0
    ex := x1 + dx * t1
    ey := y1 + dy * t1
    if GesturePreviewPointInCorner(sx, sy, start_corner, start_size, w, h) {
        t0 := Max(t0, GesturePreviewCornerExitT(start_size, dx, dy))
    }
    if GesturePreviewPointInCorner(ex, ey, end_corner, end_size, w, h) {
        t1 := Min(t1, 1 - GesturePreviewCornerExitT(end_size, dx, dy))
    }
    if t0 > t1 {
        return
    }

    DrawGesturePreviewLine(x1 + dx * t0, y1 + dy * t0,
        x1 + dx * t1, y1 + dy * t1, 1, colour)
}


GesturePreviewPointInCorner(x, y, corner, size, w, h) {
    if !size {
        return false
    }

    switch corner {
        case "TL":
            return x <= size && y <= size
        case "TR":
            return x >= w - size && y <= size
        case "BR":
            return x >= w - size && y >= h - size
        case "BL":
            return x <= size && y >= h - size
    }

    return false
}


GesturePreviewCornerExitT(size, dx, dy) {
    if !size {
        return 0
    }

    tx := Abs(dx) ? size / Abs(dx) : 0
    ty := Abs(dy) ? size / Abs(dy) : 0
    return tx && ty ? Min(tx, ty) : Max(tx, ty)
}


DrawGesturePreviewLine(x1, y1, x2, y2, is_enabled, colour) {
    static pen:=0, last_color:=""

    if !is_enabled {
        return
    }

    g := GetOverlayGraphics()
    if !g {
        return
    }

    if !pen || last_color !== colour {
        if pen {
            DllCall("gdiplus\GdipDeletePen", "ptr", pen)
            pen := 0
        }
        if DllCall("gdiplus\GdipCreatePen1",
            "uint", (150 << 24) | colour, "float", 2, "int", 2, "ptr*", &pen:=0) {
            return
        }
        last_color := colour
    }

    DllCall("gdiplus\GdipDrawLine", "ptr", g, "ptr", pen,
        "float", x1, "float", y1, "float", x2, "float", y2)
}
