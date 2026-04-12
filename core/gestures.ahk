#Include "_grad_colors.ahk"

track_period := 8
w_max := 20

gdip_token := 0
gdip_state := false
gest_overlay := false
g_mem_dc := 0
g_hbm := 0
g_bits := 0

pool_gestures := false
is_drawing := false
overlay_opts := false
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


CreateGestOverlay() {
    global gest_overlay, g_mem_dc, g_hbm, g_bits

    try gest_overlay.Destroy()

    if !GdipStartup() {
        return
    }

    gest_overlay := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x80020 -DPIScale")
    gest_overlay.Show("Hide x0 y0 w" . A_ScreenWidth . " h" . A_ScreenHeight)

    hdc := DllCall("GetDC", "ptr", 0, "ptr")
    g_mem_dc := DllCall("gdi32\CreateCompatibleDC", "ptr", hdc, "ptr")
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdc)

    bi := Buffer(40, 0)
    NumPut("UInt", 40, bi, 0)
    NumPut("Int", A_ScreenWidth, bi, 4)
    NumPut("Int", -A_ScreenHeight, bi, 8)
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
    DllCall("msvcrt\memset", "ptr", g_bits, "int", 0, "uptr", A_ScreenWidth * A_ScreenHeight * 4)
}


GetOverlayGraphics() {
    global g_bits
    static bmp:=0, g:=0, cached_bits:=0

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
            "gdiplus\GdipCreateBitmapFromScan0", "int", A_ScreenWidth, "int", A_ScreenHeight,
            "int", A_ScreenWidth*4, "int", 0xE200B, "ptr", g_bits, "ptr*", &bmp:=0
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


PresentOverlay() {
    global gest_overlay
    static size:=0, blend:=0, last_opacity:=-1, pt_zero:=Buffer(8, 0)

    if !(gest_overlay && g_mem_dc) {
        return
    }

    if !size {
        size := Buffer(8, 0)
        NumPut("Int", A_ScreenWidth, size, 0)
        NumPut("Int", A_ScreenHeight, size, 4)
    }

    if !blend || (last_opacity !== CONF.overlay_opacity.v) {
        blend := Buffer(4, 0)
        NumPut("UChar", 0, blend, 0)
        NumPut("UChar", 0, blend, 1)
        NumPut("UChar", CONF.overlay_opacity.v, blend, 2)
        NumPut("UChar", 1, blend, 3)
        last_opacity := CONF.overlay_opacity.v
    }

    DllCall(
        "user32\UpdateLayeredWindow", "ptr", gest_overlay.Hwnd, "ptr", 0, "ptr", 0,
        "ptr", size, "ptr", g_mem_dc, "ptr", pt_zero, "UInt", 0, "ptr", blend, "UInt", 2
    )
}


DestroyGestOverlay() {
    global gest_overlay, g_mem_dc, g_hbm

    if gest_overlay {
        try gest_overlay.Destroy()
        gest_overlay := false
    }
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
    SetOverlayOpts(
        (await_gest ? _GetFin(await_gest[1]).gesture_opts : ""),
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
    sh := pool == 5 ? 0 : (Mod(pool, 2) ? 6 : 3)
    overlay_opts := {pool: pool, live_hints: (vals.Length && vals[1]
        ? (vals[1] == 1 ? CONF.gest_live_hint.v : vals[1] - 1)
        : CONF.gest_live_hint.v)
    }
    for arr in [["gest_colors", 2+sh], ["grad_len", 3+sh], ["grad_loop", 4+sh]] {
        try {
            overlay_opts.%arr[1]% := vals[arr[2]] !== "" ? vals[arr[2]]
                : CONF.%arr[1]%[Integer(sh/3) + 1].v
        } catch {
            overlay_opts.%arr[1]% := CONF.%arr[1]%[Integer(sh/3) + 1].v
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
                    overlay_opts.%arr[1]%.Push(Integer("0x" . Trim(colour)))
                }
            }
            if !overlay_opts.%arr[1]%.Length {
                overlay_opts.%arr[1]% := [0xFF0000]
            }
        }
    }
}


EndDraw(*) {
    global is_drawing, init_drawing, points, overlay_opts, pool_gestures

    if !is_drawing {
        return
    }

    SetTimer(TrackMouse, 0)
    is_drawing := false
    DestroyGestOverlay()

    if init_drawing {
        init_drawing := false
        try form["Save"].Enabled := true
        try form["SaveWithReturn"].Enabled := true
        try form["SetGesture"].Text := "Saved!"
        SetTimer(_ReturnButtonText, -2000)

        res := Resample(points)
        pts := res[1]
        if Sqrt((pts[1][1]-pts[-1][1])**2 + (pts[1][2]-pts[-1][2])**2) < (res[2] / 10) {
            try form["Phase"].Enabled := true
        }
        try WinActivate "ahk_id " . form.Hwnd
        return -1
    } else {
        ret := cum_len > Max(CONF.min_gesture_len.v, 10) ? Recognize(points, pool_gestures) : false
    }

    overlay_opts := false
    pool_gestures := false
    return ret
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
            return
        }
        if DllCall("gdiplus\GdipCreateFont",
            "ptr", fam, "float", CONF.font_size_lh.v, "int", 1, "int", 2, "ptr*", &fnt:=0) {
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
        return
    }

    fs := CONF.font_size_lh.v
    if fs !== last_fs {
        if fnt {
            DllCall("gdiplus\GdipDeleteFont", "ptr", fnt)
        }
        if DllCall("gdiplus\GdipCreateFont", "ptr", fam,
            "float", fs, "int", 1, "int", 2, "ptr*", &fnt:=0) {
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
    CreateGestOverlay()
    ClearOverlay()
    gest_overlay.Show("NA")

    e := CONF.edge_size.v // 2
    hx := Mod(gesture_obj.opts.pool, 3)
    hx := hx == 1 ? e : hx == 2 ? A_ScreenWidth // 2 : A_ScreenWidth - e
    hy := (gesture_obj.opts.pool - 1) // 3
    hy := !hy ? e : hy == 1 ? A_ScreenHeight // 2 : A_ScreenHeight - e
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
    SetTimer(DestroyGestOverlay, -2000)
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