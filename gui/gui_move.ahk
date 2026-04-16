ButtonLMB(sc, *) {
    UI["Hidden"].Focus()

    if !is_updating {
        _Move(sc, 0)
    }
}


ButtonRMB(sc, *) {
    global gui_mod_val, gui_sysmods

    UI["Hidden"].Focus()

    if ONLY_BASE_SCS.Has(sc) || is_updating {
        return
    }

    res := gui_entries.ubase.GetBaseHoldMod(sc, gui_mod_val, false, false, false, false)

    h_node := _GetFirst(res.uhold)
    if h_node && h_node.down_type == TYPES.Chord {
        return
    }

    m_node := _GetFirst(res.umod)
    md := h_node && h_node.down_type == TYPES.Modifier ? h_node
        : m_node && m_node.down_type == TYPES.Modifier ? m_node : false
    if md {
        if gui_mod_val & (1 << md.down_val) {
            gui_sysmods &= ~SM_SCS.Get(sc, 0)
        } else {
            gui_sysmods |= SM_SCS.Get(sc, 0)
        }
        gui_mod_val ^= 1 << md.down_val
        UpdateKeys()
        return
    }

    _Move(sc, 1)
}


_Move(sc, is_hold) {
    global gui_mod_val

    if temp_chord {
        HandleKeyPress(sc)
        return
    }
    if CheckLRMB(current_path) {
        return
    }
    if SYS_MODIFIERS.Has(sc) {
        if buffer_view {
            return
        }
        path := current_path.Clone()
        path.Push([sc, 0, 0, 0])
        OpenForm(1, path, 0, gui_entries.ubase.GetBaseHoldMod(sc, 0, 0, 0))
        return
    }
    OneNodeDeeper(sc, gui_mod_val + is_hold)
}


OneNodeDeeper(schex, md:=-1, is_chord:=false, is_gesture:=false) {
    global gui_entries, gui_mod_val, gui_sysmods

    if md == -1 {
        md := gui_mod_val
    }
    path := buffer_view ? buffer_path : current_path
    path.Push([schex, md, is_chord, is_gesture])
    gui_mod_val := 0
    gui_sysmods := 0
    gui_entries := gui_entries.ubase.GetBaseHoldMod(schex, md, is_chord, is_gesture)
    CloseForm()
    UpdateKeys()
}


ChangePath(len:=-1, discard_md:=true, *) {
    global gui_mod_val, gui_entries, gui_sysmods

    UI["Hidden"].Focus()
    if temp_chord || is_updating {
        return
    }

    path := buffer_view ? buffer_path : current_path

    if len == -1 {
        len := path.Length
    } else {
        CloseForm()
    }

    ToggleVisibility(0, UI.path)
    UI.path := []

    gui_entries := {
        ubase: ROOTS[buffer_view ? (buffer_view == 1 ? "buffer" : "buffer_h") : gui_lang],
        uhold: (buffer_view == 1 ? ROOTS["buffer_h"] : false),
        umod: false
    }
    gui_mod_val := len < path.Length ? path[len + 1][2] & ~1
        : discard_md ? 0 : gui_mod_val

    path.Length := len

    for arr in path {
        gui_entries := gui_entries.ubase.GetBaseHoldMod(arr*)
    }

    if gui_mod_val {
        _TransferModifiers()
    } else {
        gui_sysmods := 0
    }

    UpdateKeys()
}


_TransferModifiers() {
    global gui_mod_val, gui_sysmods

    temp_mod_val := 0
    temp_sysmods := 0
    for sc in ALL_SCANCODES {
        res := gui_entries.ubase.GetBaseHoldMod(sc, gui_mod_val, false, false, false, false)
        h_node := _GetFirst(res.uhold)
        m_node := _GetFirst(res.umod)
        md := h_node && h_node.down_type == TYPES.Modifier ? h_node
            : m_node && m_node.down_type == TYPES.Modifier ? m_node : false
        if md && (gui_mod_val & (1 << md.down_val)) {
            temp_mod_val |= 1 << md.down_val
            temp_sysmods |= SM_SCS.Get(sc, 0)
        }
    }
    gui_mod_val := temp_mod_val
    gui_sysmods := temp_sysmods
}


_WalkJson(json_node, path, is_hold:=false, soft_mode:=false) {
    if !path.Length {
        return json_node
    }

    if !(path[1] is Array) {
        path := [path]
    }

    last_i := path.Length
    for i, arr in path {
        sc := arr[1]
        md := arr[2] + (i == last_i ? is_hold : 0)
        is_chord := arr[3]
        is_gesture := arr[4]
        curr_map := json_node[-3 + (is_chord is String) + (is_gesture is String) * 2]

        if !curr_map.Has(sc) {
            if soft_mode {
                return false
            }
            curr_map[sc] := Map()
        }
        entry := curr_map[sc]
        if !entry.Has(md) {
            if soft_mode {
                return false
            }
            entry[md] := GetDefaultJsonNode(, (md || is_chord ? TYPES.Disabled : TYPES.Default))
        }

        json_node := entry[md]
    }
    return json_node
}