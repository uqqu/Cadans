DecomposeMods(n, str_output:=false) {
    ; return the indices of the significant bits
    n &= ~1
    res := str_output ? "" : []
    bit := 0
    while n {
        if n & 1 {
            if str_output {
                res .= bit . "&"
            } else {
                res.Push(bit)
            }
        }
        n >>= 1
        bit++
    }
    return str_output ? SubStr(res, 1, -1) : res
}


CheckLRMB(path) {
    return path.Length == 1 && path[-1][2] < 2
        && (path[-1][1] == "LButton" || path[-1][1] == "RButton")
}


ToggleEnabled(state, arrs*) {
    for arr in arrs {
        if !(arr is Array) {
            arr.Enabled := state == 2 ? !arr.Enabled : state
            continue
        }
        for elem in arr {
            elem.Enabled := state == 2 ? !elem.Enabled : state
        }
    }
}


ToggleVisibility(state, arrs*) {
    for arr in arrs {
        if !(arr is Array) {
            arr.Visible := state == 2 ? !arr.Visible : state
            continue
        }
        for elem in arr {
            elem.Visible := state == 2 ? !elem.Visible : state
        }
    }
}


ColorPick(parent_hwnd, start_color:="") {
    static cust_colors:=Buffer(16 * 4, 0)

    start_color := AHK_COLORS.Get(start_color, start_color)

    if RegExMatch(start_color, "i)^[0-9A-F]{6}$") {
        _rgb := Integer("0x" . start_color)
        bgr := ((_rgb & 0xFF) << 16) | (((_rgb >> 8) & 0xFF) << 8) | ((_rgb >> 16) & 0xFF)
    } else {
        bgr := 0x00FFFFFF
    }

    is64 := A_PtrSize == 8
    rgb_res := is64 ? 24 : 12

    buf := Buffer(is64 ? 72 : 36, 0)

    NumPut("UInt", buf.Size, buf, 0)
    NumPut("Ptr", parent_hwnd, buf, is64 ? 8 : 4)
    NumPut("UInt", bgr, buf, rgb_res)
    NumPut("Ptr", cust_colors.Ptr, buf, is64 ? 32 : 16)
    NumPut("UInt", 3, buf, is64 ? 40 : 20)

    if !DllCall("Comdlg32\ChooseColorW", "Ptr", buf, "Int") {
        return ""
    }

    bgr := NumGet(buf, rgb_res, "UInt")
    _rgb := ((bgr & 0xFF) << 16) | (((bgr >> 8) & 0xFF) << 8) | ((bgr >> 16) & 0xFF)

    res := Format("{:06X}", _rgb)

    for name, val in AHK_COLORS {
        if val == res {
            return name
        }
    }
    return res
}


PasteColorFromPick(parent_hwnd, elem, append_mode:=false, *) {
    last_color := ""
    try last_color := StrSplit(elem.Text, ",")[-1]
    new_color := ColorPick(parent_hwnd, last_color)
    if new_color && new_color != last_color {
        if RegExMatch(elem.Text, "random\((\d+)\)", &m) {
            elem.Text := ""
        }
        if append_mode {
            elem.Text .= (elem.Text ? "," : "") . new_color
        } else {
            elem.Text := new_color
        }
    }
}


GetRowIconIndex(lv, row) {
    item := Buffer(64, 0)
    NumPut("uint", 0x0002, item, 0)
    NumPut("int", row - 1, item, 4)
    NumPut("int", 0, item, 8)
    SendMessage(0x104B, 0, item, lv)
    offset := (A_PtrSize = 8) ? 36 : 32
    return NumGet(item, offset, "int")
}


GetColumnAtCursor(lv, with_row:=false) {
    MouseGetPos(&mx, &my, , &ctrl_hwnd)

    row := 0
    if SubStr(ctrl_hwnd, 1, 9) == "SysHeader" {
        row := -1
    }

    pt := Buffer(8, 0)
    NumPut("int", mx, pt, 0)
    NumPut("int", my, pt, 4)
    DllCall("ScreenToClient", "ptr", lv.Hwnd, "ptr", pt)

    hti := Buffer(48, 0)
    NumPut("int", NumGet(pt, 0, "int"), hti, 0)
    NumPut("int", NumGet(pt, 4, "int"), hti, 4)

    SendMessage(0x1039, 0, hti, lv)

    if with_row {
        row := row || (NumGet(hti, 12, "int") + 1)
        return [NumGet(hti, 16, "int") + 1, row]
    }
    return NumGet(hti, 16, "int") + 1
}


_GetKeyName(sc, with_keytype:=false, to_short:=false, from_sc_str:=false) {
    static fixed_names:=Map(
        "PrintScreen", "Print`nScreen", "ScrollLock", "Scroll`nLock", "Numlock", "Num`nLock",
        "Volume_Mute", "Mute", "Volume_Down", "VolD", "Volume_Up", "VolU", "Media_Next", "Next",
        "Media_Prev", "Prev", "Media_Stop", "Stop", "Media_Play_Pause", "Play",
        "Browser_Back", "Back", "Browser_Forward", "Forw", "Browser_Refresh", "Refr",
        "Browser_Stop", "Stop", "Browser_Search", "Srch", "Browser_Favorites", "Fav",
        "Browser_Home", "Home", "Launch_Mail", "Mail", "Launch_Media", "Media",
        "Launch_App1", "App1", "Launch_App2", "App2", "LButton", "LMB", "RButton", "RMB",
        "MButton", "Wheel`nClick", "XButton1", "XMB1", "XButton2", "XMB2", "WheelLeft", "Wheel`n🡐",
        "WheelDown", "Wheel`n🡓", "WheelUp", "Wheel`n🡑", "WheelRight", "Wheel`n🡒"
    )
    static short_names:=Map(
        "PrintScreen", "PrtSc", "ScrollLock", "ScrLk", "Numlock", "NumLk",
        "Backspace", "BS", "LControl", "LCtrl", "RControl", "RCtrl", "AppsKey", "Menu",
        "WheelLeft", "WhLeft", "WheelDown", "WhDown", "WheelUp", "WhUp", "WheelRight", "WhRight",
        "MButton", "WhClick"
    )

    if with_keytype && CONF.keyname_type.v == 2 {
        return "&" . sc
    }

    res := sc
    if from_sc_str {
        res := GetKeyName(SubStr(from_sc_str, 2, -1))
        if !res {
            return from_sc_str
        }
    } else if IsNumber(sc) {
        if gui_sysmods {
            res := GetKeyNameWithMods(Integer(sc)) || GetKeyName(SC_STR[Integer(sc)])
        } else {
            res := GetKeyName(SC_STR[Integer(sc)])
        }
    }

    return res == "RAlt" && CONF.layout_format.v == "ISO" ? "AltGr"
        : to_short && short_names.Has(res) ? short_names[res]
        : fixed_names.Has(res) ? fixed_names[res]
        : InStr(res, "Numpad") ? "n" . SubStr(res, 7)
        : with_keytype && CONF.keyname_type.v == 3 && !res ? "&" . sc
        : res
}


GetKeyNameWithMods(sc) {
    hkl := DllCall("GetKeyboardLayout", "uint", 0, "ptr")
    vk := DllCall("MapVirtualKeyEx", "uint", sc, "uint", 3, "ptr", hkl, "uint")

    if vk >= 0x60 && vk <= 0x6F {
        return ""
    }

    state := Buffer(256, 0)

    if gui_sysmods & 1 {
        NumPut("UChar", 0x80, state, 0x10)
    } else if CONF.layout_format.v == "ISO" && (gui_sysmods & 8)
        || (gui_sysmods & 6) == 6 || (gui_sysmods & 10) == 10 {
        NumPut("UChar", 0x80, state, 0x11)
        NumPut("UChar", 0x80, state, 0x12)
    } else {
        return ""
    }

    buf := Buffer(8, 0)

    if DllCall(
        "ToUnicodeEx", "uint", vk, "uint", sc, "ptr", state, "ptr",
        buf, "int", 4, "uint", 0, "ptr", hkl, "int"
    ) {
        ch := StrGet(buf, "UTF-16")
        if Ord(ch) > 31 {
            return ch
        }
    }
    return ""
}


CheckDiacr(value) {
    if StrLen(value) !== 1 {
        return value
    }
    code := Ord(value)
    if code >= 0x0300 && code <= 0x036F
        || code >= 0x1AB0 && code <= 0x1AFF
        || code >= 0x1DC0 && code <= 0x1DFF
        || code >= 0x20D0 && code <= 0x20FF
        || code >= 0xFE20 && code <= 0xFE2F
    {
        return "◌" . value
    }
    return value == "&" ? "&&" : value
}