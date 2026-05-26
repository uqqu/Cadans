#Include "_grad_colors.ahk"

track_period := 8
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

pool_gestures := false
is_drawing := false
overlay_opts := false
zone_preview_mode := "Off"
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

    opacity := opacity || CONF.overlay_opacity.v
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
    SetTimer(DestroyGestOverlay, 0)

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


CollectPool(gestures) {
    global pool_gestures

    MouseGetPos(&x, &y)
    pool := GetPool(x, y)
    pool_gestures := []
    for _, mod_mp in gestures {
        if mod_mp.Has(0) && _GetFin(mod_mp[0]).opts.pool == pool {
            pool_gestures.Push(mod_mp[0])
        }
    }
}


StartDraw(gestures:=false, *) {
    global is_drawing, prev_x, prev_y, points, cum_len, prev_width, cur_grad_len

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
}


SetOverlayOpts(opts, pool) {
    global overlay_opts

    vals := StrSplit(opts, ";")
    color_key := GetGestureColorKey(pool)
    overlay_opts := {pool: pool, live_hints: (vals.Length && vals[1]
        ? (vals[1] == 1 ? CONF.gest_live_hint.v : vals[1] - 1)
        : CONF.gest_live_hint.v)
    }
    for arr in [
        ["gest_colors", "gest_zone_colors", 0],
        ["grad_len", "gest_zone_grad_len", 1],
        ["grad_loop", "gest_zone_grad_loop", 2],
    ] {
        try {
            zi := GetGestureZoneOverrideIndex(color_key, arr[3])
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
                for colour in StrSplit(v, ",") {
                    overlay_opts.%arr[1]%.Push(ParseAhkColor(colour))
                }
            }
            if !overlay_opts.%arr[1]%.Length {
                overlay_opts.%arr[1]% := [0xFF0000]
            }
        }
    }
}


EndDraw(*) {
    global is_drawing, init_drawing, points, overlay_opts, pool_gestures, form_points

    if !is_drawing {
        return
    }

    SetTimer(TrackMouse, 0)
    is_drawing := false
    DestroyGestOverlay()

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


DrawLine(x1, y1, x2, y2, width) {
    global cur_grad_len
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
            "uint", (255<<24)|0, "float", width, "int", 2, "ptr*", &pen:=0) {
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
    parts := overlay_opts.gest_colors.Length > 1 ? Max(Ceil(seg_len / 3), 1) : 1

    loop parts {
        try {  ; TODO
            t0 := (A_Index - 1) / parts
            t1 := A_Index / parts
            mid := (A_Index - 0.5) / parts

            colour := ColorAtProgress((cur_grad_len + seg_len * mid) / overlay_opts.grad_len)
            DllCall("gdiplus\GdipSetPenColor", "ptr", pen, "uint", (255<<24)|colour)

            xa := x1 + dx * t0
            ya := y1 + dy * t0
            xb := x1 + dx * t1
            yb := y1 + dy * t1

            DllCall("gdiplus\GdipDrawLine", "ptr", g, "ptr", pen,
                "float", xa, "float", ya, "float", xb, "float", yb)
        }
    }
    cur_grad_len += seg_len
}


TrackMouse() {
    global prev_x, prev_y, cum_len, prev_width

    if !is_drawing {
        SetTimer(TrackMouse, 0)
        return
    }

    MouseGetPos(&x, &y)
    if x !== prev_x || y !== prev_y {
        dx := x - prev_x
        dy := y - prev_y
        d := Sqrt(dx*dx + dy*dy)
        cum_len += d

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

        if pool_gestures && cum_len > Max(CONF.min_gesture_len.v, 10)
            && overlay_opts.live_hints !== 4 {
            SetTimer(LiveHint.Bind(points, pool_gestures), -1)
        } else {
            PresentOverlay()
        }
    }
}


BrushWidth(len) {
    t := 0.01 * (len - A_ScreenHeight / 6)
    w := w_max * ((t > 30) ? 1.0 : (t < -30) ? 0.0 : 1.0 / (1.0 + Exp(-t)))
    if w > w_max {
        w := w_max
    }
    return Round(w)
}


LiveHint(pts, gestures) {
    global g_bits
    static busy:=false, inited:=false, fam:=0, fnt:=0, fmt:=0,
        brush_bg:=0, brush_fg:=0, brush_shad:=0, brush_clear:=0,
        last_sig:="", lbbox:=0, lbx:=-1.0, lby:=-1.0, lbw:=-1.0, lbh:=-1.0, last_fs:=-1.0

    if busy || overlay_opts.live_hints == 4 {
        return
    }

    busy := true

    res := Recognize(pts, gestures)

    txt := ""
    try {
        if res[1] < CONF.min_cos_similarity.v {
            txt := !CONF.live_hint_extended.v ? "" : ("Not recognized. Best match: '"
                . _GetFin(res[2]).gui_shortname . "' " . Round(res[1], 2))
        } else {
            txt := _GetFin(res[2]).gui_shortname
        }
    }

    if !inited {
        if DllCall("gdiplus\GdipCreateFontFamilyFromName",
            "wstr", "Segoe UI", "ptr", 0, "ptr*", &fam:=0) {
            busy := false
            return
        }
        if DllCall("gdiplus\GdipCreateFont",
            "ptr", fam, "float", CONF.font_size_lh.v, "int", 1, "int", 2, "ptr*", &fnt:=0) {
            busy := false
            return
        }

        DllCall("gdiplus\GdipStringFormatGetGenericDefault", "ptr*", &fmt:=0)
        DllCall("gdiplus\GdipSetStringFormatAlign", "ptr", fmt, "int", 1)
        DllCall("gdiplus\GdipSetStringFormatLineAlign", "ptr", fmt, "int", 1)

        bg := (215 << 24) | (0x22 << 16) | (0x22 << 8) | 0x22
        DllCall("gdiplus\GdipCreateSolidFill", "uint", bg, "ptr*", &brush_bg:=0)
        DllCall("gdiplus\GdipCreateSolidFill", "uint", (255<<24)|0x000000, "ptr*", &brush_shad:=0)
        DllCall("gdiplus\GdipCreateSolidFill", "uint", (255<<24)|0xFFFFFF, "ptr*", &brush_fg:=0)
        DllCall("gdiplus\GdipCreateSolidFill", "uint", 0x00000000, "ptr*", &brush_clear:=0)
        inited := true
        last_fs := CONF.font_size_lh.v
    }

    g := GetOverlayGraphics()
    if !g {
        busy := false
        return
    }

    fs := CONF.font_size_lh.v
    if fs !== last_fs {
        if fnt {
            DllCall("gdiplus\GdipDeleteFont", "ptr", fnt)
        }
        if DllCall("gdiplus\GdipCreateFont", "ptr", fam,
            "float", fs, "int", 1, "int", 2, "ptr*", &fnt:=0) {
            busy := false
            return
        }
        last_fs := fs
        lbbox := 0
        last_sig := ""
    }

    DllCall("gdiplus\GdipGetFontHeight", "ptr", fnt, "ptr", g, "float*", &line_h:=0)

    pad_x := Round(Max(fs * 0.60, 10.0))
    pad_y := Round(Max(fs * 0.35,  6.0))
    margin_y := Round(Max(fs * 0.80, 12.0))
    shadow_off := Round(Max(fs * 0.06, 1.0))
    bar_h := line_h + pad_y * 2

    try {
        t := overlay_opts.live_hints
    } catch {
        t := CONF.gest_live_hint.v
    }
    y := t == 1 ? margin_y
        : (t == 2 ? ((A_ScreenHeight - bar_h) / 2.0)
        : (A_ScreenHeight - bar_h - margin_y))

    rect := Buffer(16, 0)
    NumPut("float", 0.0, rect, 0)
    NumPut("float", y, rect, 4)
    NumPut("float", A_ScreenWidth*1.0, rect, 8)
    NumPut("float", bar_h, rect, 12)

    sig := txt . "|" . fs
    if sig !== last_sig || !lbbox {
        lbbox := Buffer(16, 0)
        DllCall("gdiplus\GdipMeasureString", "ptr", g, "wstr", txt, "int", StrLen(txt),
            "ptr", fnt, "ptr", rect, "ptr", fmt, "ptr", lbbox, "uint*", &cp:=0, "uint*", &lns:=0)
        last_sig := sig
    }

    tx := NumGet(lbbox, 0, "float")
    ty := NumGet(lbbox, 4, "float")
    tw := NumGet(lbbox, 8, "float")
    th := NumGet(lbbox, 12, "float")

    bx := Floor(tx - pad_x)
    by := Floor(ty - pad_y)
    bw := Ceil(tw + pad_x * 2)
    bh := Ceil(th + pad_y * 2)

    if lbw > 0 && lbh > 0 {
        DllCall("gdiplus\GdipSetCompositingMode", "ptr", g, "int", 1)  ; SourceCopy
        DllCall("gdiplus\GdipFillRectangle", "ptr", g, "ptr", brush_clear,
            "float", lbx-1, "float", lby-1, "float", lbw+2, "float", lbh+2)
        DllCall("gdiplus\GdipSetCompositingMode", "ptr", g, "int", 0)  ; SourceOver
    }

    DllCall("gdiplus\GdipFillRectangle", "ptr", g, "ptr", brush_bg,
        "float", bx, "float", by, "float", bw, "float", bh)  ; NTT

    if shadow_off > 0 {
        rect_sh := Buffer(16, 0)
        NumPut("float", 0.0 + shadow_off, rect_sh, 0)
        NumPut("float", y + shadow_off, rect_sh, 4)
        NumPut("float", A_ScreenWidth*1.0, rect_sh, 8)
        NumPut("float", bar_h, rect_sh, 12)
        try DllCall("gdiplus\GdipDrawString", "ptr", g, "wstr", txt, "int", StrLen(txt),
            "ptr", fnt, "ptr", rect_sh, "ptr", fmt, "ptr", brush_shad)  ; TODO
    }

    try DllCall("gdiplus\GdipDrawString", "ptr", g, "wstr", txt, "int", StrLen(txt),
        "ptr", fnt, "ptr", rect, "ptr", fmt, "ptr", brush_fg)

    lbx := bx
    lby := by
    lbw := bw
    lbh := bh
    PresentOverlay()
    busy := false
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
    PresentOverlay(Round(CONF.overlay_opacity.v * (steps - step) / steps))
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

    margin := Max(Round(5 * CONF.gui_scale.v), 3)
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
        width := Max((0.75 + 1.25 * smooth_t) * CONF.gui_scale.v, 0.75)
        line_color := GesturePreviewStrokeColor(stroke_colors, t)
        DllCall("gdiplus\GdipCreatePen1", "uint", line_color,
            "float", width, "int", 2, "ptr*", &pen:=0)
        DllCall("gdiplus\GdipSetPenStartCap", "ptr", pen, "int", 2)
        DllCall("gdiplus\GdipSetPenEndCap", "ptr", pen, "int", 2)
        DllCall("gdiplus\GdipSetPenLineJoin", "ptr", pen, "int", 2)
        DllCall("gdiplus\GdipDrawLine", "ptr", g, "ptr", pen,
            "float", prev_x, "float", prev_y, "float", x, "float", y)
        DllCall("gdiplus\GdipDeletePen", "ptr", pen)
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


GesturePreviewStrokeColor(colors, t) {
    if !(colors is Array) || !colors.Length {
        return 0xDD202020
    }
    if colors.Length == 1 {
        return 0xDD000000 | colors[1]
    }

    lerp := (CONF.gest_color_mode.v == "HSV"
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
    return 0xDD000000 | lerp(colors[seg + 1], colors[seg + 2], p - seg)
}


DrawGesturePreviewPoolMarker(g, pool, w, h) {
    pool := ParseGesturePool(pool)
    if pool == 5 {
        return
    }

    r := Max(3 * CONF.gui_scale.v, 2.5)
    pos := GesturePreviewPoolMarkerPos(pool, w, h, r)
    pts := Buffer(4 * 2 * 4, 0)
    NumPut("Float", pos[1], "Float", pos[2] - r, pts, 0)
    NumPut("Float", pos[1] + r, "Float", pos[2], pts, 8)
    NumPut("Float", pos[1], "Float", pos[2] + r, pts, 16)
    NumPut("Float", pos[1] - r, "Float", pos[2], pts, 24)
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
        alpha := t < 0.4 ? Round(peak_alpha * t / 0.4)
            : t < 0.6 ? peak_alpha
            : Round(peak_alpha * (1 - t) / 0.4)
        if !alpha {
            continue
        }
        DllCall("gdiplus\GdipCreatePen1", "uint", (alpha << 24) | 0x777777,
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
            case "Grid":
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
    first_zone_opt_i := 2  ; live-hint position
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
            "uint", (235 << 24) | colour, "float", 2, "int", 2, "ptr*", &pen:=0) {
            return
        }
        last_color := colour
    }

    DllCall("gdiplus\GdipDrawLine", "ptr", g, "ptr", pen,
        "float", x1, "float", y1, "float", x2, "float", y2)
}
