ShowSaveOptionsMenu(*) {
    UI["Hidden"].Focus()
    UI.save_options_menu.Show()
}


ShowCopyMenu(*) {
    UI.copy_options_menu.Show()
}


ShowPasteMenu(*) {
    UI.paste_options_menu.Show()
}


PhysicalDrag(sc) {
    global drag_physical

    if drag_physical {
        if UI.buttons[sc].Enabled {
            _SwapButtons(UI.buttons[sc], UI.buttons[drag_physical])
            dn := UI.buttons[drag_physical].dragged_sc
            mn := UI.buttons[sc].dragged_sc
            t := drag_map[dn]
            drag_map[dn] := drag_map[mn]
            drag_map[mn] := t
            drag_physical := false
            for name, btn in UI.buttons {
                if name !== "CurrMod" {
                    try btn.Enabled := true
                }
            }
        }
    } else {
        drag_physical := sc
        UI.buttons[sc].Opt("BackgroundBlack")
        UI.buttons[sc].Text .= ""
        HideInappropriate(sc)
    }
}


EnableDragMode(*) {
    global drag_map, is_drag_mode

    drag_map := Map()
    is_drag_mode := true
    for sc in ALL_SCANCODES {
        drag_map[sc] := sc
    }

    UI.Title := "Drag mode"
    ToggleEnabled(0, UI.path, UI.current_values)
    ToggleVisibility(2, UI.drag_btns)
    ToggleVisibility(0, UI.buffer, UI["BtnShowBuffer"])
}


SaveDrag(_, all_mods:=false, all_langs:=false, *) {
    global drag_map, is_drag_mode

    ClearEquals(drag_map)

    if !drag_map.Count {
        EndDragMode()
        return
    }

    if !buffer_view && !layer_editing && ActiveLayers.order.Length !== 1 {
        inp := MsgBox("You're not in layer editing mode. "
            . "Do you want to apply the changes to all of them? "
            . "(press 'no' to manually select layers)",
            "Confirmation", "YesNoCancel Icon?")
        if inp == "Cancel" {
            return
        } else if inp == "No" {
            layers := ChooseLayers(ActiveLayers.order)
            if !layers.Length {
                return
            }
        } else {
            layers := ActiveLayers.order
        }
    } else {
        layers := layer_editing || buffer_view ? [selected_layer] : ActiveLayers.order
    }

    ToggleEnabled(0, UI.drag_btns)
    ToggleFreeze(1)

    is_changed := false
    for layer in layers {
        if buffer_view {
            json_root := saved_level[2]
            ApplyDragsToLayer(json_root, drag_map, all_mods)
            is_changed := true
            break
        }
        json_root := DeserializeMap(layer)
        is_curr_changed := false
        if all_langs {
            for _, root in json_root {
                is_curr_changed := ApplyDragsToLayer(root, drag_map, all_mods) || is_curr_changed
            }
        } else if json_root.Has(gui_lang) {
            is_curr_changed := ApplyDragsToLayer(json_root[gui_lang], drag_map, all_mods)
                || is_curr_changed
        }
        if is_curr_changed && !buffer_view {
            SerializeMap(json_root, layer)
            is_changed := true
        }
    }

    if is_changed {
        FillRoots()
        if layer_editing {
            AllLayers.map[selected_layer] := true
            MergeLayer(selected_layer)
        }
        UpdLayers()
    } else {
        ToggleFreeze(0)
    }

    EndDragMode()
}


ApplyDragsToLayer(root, mp, all_mods:=false) {
    path := buffer_view ? buffer_path : current_path
    if path.Length {
        root := _WalkJson(root, path, false, true)
        if !root {
            return false
        }
    }
    scs_map := root[-3]
    chs_map := root[-2]
    cloned_scs := DeepClone(scs_map)

    is_changed := false
    is_chord_changed := false

    for src_sc, trg_sc in mp {
        src := cloned_scs.Get(src_sc, Map())

        if all_mods {
            if !src.Count {
                if scs_map.Has(trg_sc) {
                    scs_map.Delete(trg_sc)
                    is_changed := true
                }
            } else {
                scs_map[trg_sc] := src
                is_changed := true
            }
            continue
        }

        if !scs_map.Has(trg_sc) {
            scs_map[trg_sc] := Map()
        }

        loop 2 {
            i := gui_mod_val + A_Index - 1
            val := src.Get(i, false)
            if val {
                scs_map[trg_sc][i] := val
                is_changed := true
            } else if scs_map[trg_sc].Has(i) {
                scs_map[trg_sc].Delete(i)
                is_changed := true
            }
        }
    }

    new_chords := Map()
    for chord_str, mds in chs_map {
        if !all_mods && !mds.Has(gui_mod_val) {
            new_chords[chord_str] := MapUnion(new_chords.Get(chord_str, Map()), mds)
            continue
        }

        new_chords[chord_str] := new_chords.Get(chord_str, Map())
        new_scs := []
        for sc in StrSplit(chord_str, "-") {
            try sc := Integer(sc)
            if mp.Has(sc) {
                is_chord_changed := true
                new_scs.Push(mp[sc])
            } else {
                new_scs.Push(sc)
            }
        }

        if all_mods {
            new_chords[ChordToStr(new_scs)] := mds
            continue
        }

        for md, vals in mds {
            if md !== gui_mod_val {
                new_chords[chord_str][md] := vals
            } else {
                is_changed := true
            }
        }

        new_chord_str := ChordToStr(new_scs)
        new_chords[new_chord_str] := MapUnion(
            new_chords.Get(new_chord_str, Map()),
            Map(gui_mod_val, mds[gui_mod_val])
        )
    }

    if is_chord_changed {
        root[-2] := new_chords
    }

    if is_changed || is_chord_changed {
        return true
    }
    return false
}


CancelDrag(*) {
    ClearEquals(drag_map)

    if drag_map.Count && MsgBox(
        "Do you want to undo the changes?", "Confirmation", "YesNo Icon?"
    ) == "No" {
        return
    }

    EndDragMode()
}


EndDragMode() {
    global drag_map, is_drag_mode

    ChangePath(-1, false)
    drag_map := Map()
    is_drag_mode := false
    UI.Title := proj_name
    ToggleVisibility(2, UI.drag_btns, UI["BtnShowBuffer"], UI.buffer)
    ToggleEnabled(1, UI.drag_btns, UI.current_values, UI.path)
}


StartDragButtons(obj) {
    global init_obj, curr_obj

    init_obj := obj
    sc := obj.Name
    try sc := Integer(sc)
    HideInappropriate(sc)
    curr_obj := false
    SetTimer(TrackDrag, 8)
}


HideInappropriate(sc) {
    if ONLY_BASE_SCS.Has(sc) {
        for name, btn in UI.buttons {
            if name == "CurrMod" {
                btn.Enabled := false
            } else if ONLY_BASE_SCS.Has(name) {
                btn.Enabled := true
            } else {
                res := gui_entries.ubase.GetBaseHoldMod(name, gui_mod_val, 0, 0, 0, 0)
                h_node := _GetFirst(res.uhold)
                btn.Enabled := !h_node && !res.ubase.gestures.Count
            }
        }
    } else if AWMods.Has(sc) {
        for name, btn in UI.buttons {
            if name == "CurrMod" {
                btn.Enabled := false
            } else if AWMods.Has(name) {
                btn.Enabled := true
            } else {
                res := gui_entries.ubase.GetBaseHoldMod(name, gui_mod_val, 0, 0, 0, 0)
                b_node := _GetFirst(res.ubase)
                btn.Enabled := !b_node && !res.ubase.gestures.Count
            }
        }
    } else {
        res := gui_entries.ubase.GetBaseHoldMod(sc, gui_mod_val, 0, 0, 0, 0)
        b_node := _GetFirst(res.ubase)
        h_node := _GetFirst(res.uhold)

        b := !h_node && !res.ubase.gestures.Count
        for name in ONLY_BASE_SCS {
            try UI[String(name)].Enabled := b
        }
        b := !b_node && !res.ubase.gestures.Count
        for name in AWMods {
            try UI[String(name)].Enabled := b
        }
    }
}


TrackDrag() {
    global curr_obj

    MouseGetPos(,, &win_id, &ctrl_hwnd, 2)
    if ctrl_hwnd && win_id == UI.Hwnd {
        obj := GuiCtrlFromHwnd(ctrl_hwnd)
        if obj {
            is_btn := UI.buttons.Has(obj.Name)
            try is_btn := UI.buttons.Has(Integer(obj.Name))
            if is_btn && obj.Enabled && obj !== curr_obj {
                if curr_obj {  ; return prev moved
                    _SwapButtons(curr_obj, init_obj)
                }
                if obj !== init_obj {
                    _SwapButtons(obj, init_obj)
                    curr_obj := obj
                } else {
                    curr_obj := false
                }
            }
        }
    }
}


_SwapButtons(a, b) {
    for ind in a.indicators {
        try ind.Visible := false
    }
    for ind in b.indicators {
        try ind.Visible := false
    }
    a.indicators := []
    b.indicators := []
    an := a.dragged_sc
    bn := b.dragged_sc
    a.dragged_sc := bn
    b.dragged_sc := an
    FillOneButton(a.Name, a, bn)
    FillOneButton(b.Name, b, an)
}


StopDragButtons(*) {
    global init_obj, curr_obj, drag_map

    SetTimer(TrackDrag, 0)
    if curr_obj {
        dn := init_obj.dragged_sc
        mn := curr_obj.dragged_sc
        t := drag_map[dn]
        drag_map[dn] := drag_map[mn]
        drag_map[mn] := t
        curr_obj := false
    }
    init_obj := false
    for name, btn in UI.buttons {
        if name !== "CurrMod" {
            try btn.Enabled := true
        }
    }
}


CopyLevel(_, copy_type, *) {
    global saved_level

    UI["Hidden"].Focus()
    json_root := DeserializeMap(selected_layer)

    if !json_root.Has(gui_lang) {
        ToolTip("There are no assignments for copying.")
        SetTimer(ToolTip, -2000)
        return
    }

    res_hold := false
    if current_path.Length {
        res := _WalkJson(json_root[gui_lang], current_path, false, true)
        if copy_type == 2 {
            path := current_path.Clone()
            path.Length -= 1
            path.Push(
                [current_path[-1][1], current_path[-1][2]+1,
                current_path[-1][3], current_path[-1][4]]
            )
            res_hold := _WalkJson(json_root[gui_lang], path, false, true)
        }
        if !res && !res_hold {
            ToolTip("There are no assignments for copying.")
            SetTimer(ToolTip, -2000)
            return
        }
    } else {
        res := json_root[gui_lang]
    }

    if !copy_type {
        loop 3 {
            tmp := Map()
            i := A_Index
            for schex, mds in res[-A_Index] {
                if mds.Has(gui_mod_val) {
                    tmp[schex] := Map(0, mds[gui_mod_val])
                }
                if mds.Has(gui_mod_val+1) {
                    if !tmp.Has(schex) {
                        tmp[schex] := Map()
                    }
                    tmp[schex][1] := mds[gui_mod_val+1]
                }
            }
            res[-A_Index] := tmp
        }
    }

    saved_level := [copy_type, res, res_hold]

    cnt := [[[0, 0], [0, 0], [0, 0]], [[0, 0], [0, 0], [0, 0]]]
    mds_map := [Map(), Map()]
    txts := ["nothing", "nothing"]
    vals := [false, false]
    for v in [res, res_hold] {
        t := A_Index
        if v {
            loop 3 {
                i := A_Index
                curr_mds_map := Map()
                for _, mds in v[-i]{
                    cnt[t][-i][1] += 1
                    for md in mds {
                        mds_map[t][md & ~1] := true
                        curr_mds_map[md & ~1] := true
                    }
                    cnt[t][-i][2] := curr_mds_map.Count
                }
            }
            if v.Length !== 4 {
                switch v[1] {
                    case TYPES.Disabled:
                        vals[t] := "{Disabled}"
                    case TYPES.Default:
                        vals[t] := "{Default}"
                    case TYPES.Text:
                        vals[t] := "'" . CheckDiacr(v[2]) . "'"
                    case TYPES.Function:
                        vals[t] := "(" . v[2] . ")"
                    case TYPES.KeySimulation:
                        vals[t] := _GetKeyName(false, false, true, v[2])
                    case TYPES.Modifier:
                        vals[t] := "Mod " . v[2]
                    case TYPES.Chord:
                        vals[t] := "Chord part"
                }
            }

            if cnt[t][1][1] || cnt[t][2][1] || cnt[t][3][1] {
                txts[t] := (cnt[t][1][1] ? (cnt[t][1][1] . " scancodes"
                        . (copy_type && cnt[t][1][2] > 1 ? " on "
                            . cnt[t][1][2] . " mods" : "") . "; ") : "")
                    . (cnt[t][2][1] ? (cnt[t][2][1] . " chords"
                        . (copy_type && cnt[t][2][2] > 1 ? " on "
                            . cnt[t][2][2] . " mods" : "") . "; ") : "")
                    . (cnt[t][3][1] ? (cnt[t][3][1] . " gestures; ") : "")
                    . (copy_type && mds_map[t].Count > 1
                        ? (" Total " . mds_map[t].Count . " mods used.") : "")
            }
        }
    }

    if !copy_type {
        ToolTip("View saved to the internal buffer.`nOn the view assigned: " . txts[1])
    } else if copy_type == 1 {
        ToolTip("Level saved to the internal buffer."
            . (current_path.Length ? ("`nTap value: " . (vals[1] || "unassigned")) : "")
            . "`nOn the level assigned: " . txts[1])
    } else {
        ToolTip("Extended level saved to the internal buffer."
            . (current_path.Length ? ("`nTap value: " . (vals[1] || "unassigned")
                . "; Hold value: " . (vals[2] || "unassigned")) : "")
            . "`nOn the level assigned: " . (txts[1] || "nothing.")
            . "`nAssigned on adjacent hold: " . (txts[2] || "nothing."))
    }
    SetTimer(ToolTip, -6666)
    ToggleEnabled(saved_level, UI["BtnShowPasteMenu"])

    ROOTS["buffer"] := UnifiedNode()
    ROOTS["buffer"].MergeNodeRecursive(res, 0, 0, "buffer")
    ROOTS["buffer_h"] := UnifiedNode()
    if copy_type == 2 {
        ROOTS["buffer_h"].MergeNodeRecursive(res_hold, 0, 0, "buffer")
    }
}


PasteLevel(_, paste_type, *) {
    global saved_level

    UI["Hidden"].Focus()
    copy_type := saved_level[1]
    src := saved_level[2] || GetDefaultJsonNode(gui_mod_val)
    src_h := saved_level[3] || GetDefaultJsonNode(1)
    if src.Length == 4 {
        t := GetDefaultJsonNode(gui_mod_val)
        loop 4 {
            t[-A_Index] := src[-A_Index]
        }
        src := t
    }
    if src_h.Length == 4 {
        t := GetDefaultJsonNode(1)
        loop 4 {
            t[-A_Index] := src_h[-A_Index]
        }
        src_h := t
    }

    if src[-1].Count && UI["LV_gestures"].GetText(0, 1) == "Has nested gestures" {
        MsgBox("The value from the clipboard contains gestures "
            . "that cannot be inserted at this position.", "Error")
        return
    }
    ToggleFreeze(1)
    json_root := DeserializeMap(selected_layer)

    if !json_root.Has(gui_lang) {
        json_root[gui_lang] := ["", Map(), Map(), Map()]
    }

    trg_h := false
    if current_path.Length {
        trg := _WalkJson(json_root[gui_lang], current_path)
        if copy_type == 2 {
            path := current_path.Clone()
            path.Length -= 1
            path.Push(
                [current_path[-1][1], current_path[-1][2]+1,
                current_path[-1][3], current_path[-1][4]]
            )
            trg_h := _WalkJson(json_root[gui_lang], path)
        }

        if copy_type {
            _SwapBaseValues(src, trg, paste_type, gui_mod_val)
            if copy_type == 2 {
                _SwapBaseValues(src_h, trg_h, paste_type, 1)
            }
        }
    } else {
        trg := json_root[gui_lang]
    }

    _SwapAssignments(src, trg, paste_type)
    if copy_type == 2 {
        _SwapAssignments(src_h, trg_h, paste_type)
    }

    _CleanSaved()

    SerializeMap(json_root, selected_layer)
    FillRoots()
    AllLayers.map[selected_layer] := true
    MergeLayer(selected_layer)
    UpdLayers()
    ChangePath()
}


_CleanSaved() {
    global saved_level

    for res in [saved_level[2], saved_level[3]] {
        if !res {
            continue
        }
        if !res[-1].Count && !res[-2].Count && !res[-3].Count
            && (res.Length == 4 || !saved_level
                || ((res[1] == TYPES.Disabled || res[1] == TYPES.Default)
                    && (!res[2] && res[3] == TYPES.Disabled
                        && !res[4] && !res[5] && !res[6] && !res[7] && !res[8]
                        && res[9] == 4 && !res[10] && !res[11])
                    )
                )
        {
            saved_level[1 + A_Index] := false
        }
    }

    if !saved_level[2] && !saved_level[3] {
        saved_level := false
    }
}


_SwapIndValues(a, b, i) {
    t := a[i]
    a[i] := b[i]
    b[i] := t
}


_SwapBaseValues(a, b, t, mod_val) {
    default_value := GetDefaultJsonNode(mod_val)
    flag := true
    loop 11 {
        if b[A_Index] !== default_value[A_Index] {
            flag := false
            break
        }
    }
    if t || flag {
        loop 11 {
            _SwapIndValues(a, b, A_Index)
        }
    }
}


_SwapAssignments(a, b, t) {
    loop 3 {
        i := -A_Index
        if t == 2 {  ; replace
            _SwapIndValues(a, b, i)
        } else if t == 1 {  ; merge
            _MergeMaps(a, b, i, false)
        } else {  ; append
            _MergeMaps(a, b, i, true)
        }
    }
}


_MergeMaps(a, b, i, is_append) {
    to_del_schex := []
    for schex, mods in a[i] {
        if !b[i].Has(schex) {
            b[i][schex] := mods
            to_del_schex.Push(schex)
            continue
        }
        to_del_mds := []
        for md, val in mods {
            if !b[i][schex].Has(md) {
                b[i][schex][md] := val
                to_del_mds.Push(md)
            } else if is_append {
                _SwapBaseValues(val, b[i][schex][md], 0, md)
                loop 3 {
                    _MergeMaps(val, b[i][schex][md], -A_Index, true)
                }
            } else {
                _SwapIndValues(mods, b[i][schex], md)
            }
        }
        for md in to_del_mds {
            mods.Delete(md)
        }
        if !mods.Count {
            to_del_schex.Push(schex)
        }
    }
    for schex in to_del_schex {
        a[i].Delete(schex)
    }
}


ShowBuffer(*) {
    global buffer_view, root_text

    UI["Hidden"].Focus()
    if !ROOTS.Has("buffer") {
        ToolTip("Buffer is empty. First copy the desired level in the layer editing mode.")
        SetTimer(ToolTip, -3000)
        return
    }

    if buffer_view {
        buffer_view := 0
        root_text := selected_layer || "root"
    } else {
        buffer_view := 1
        root_text := "<buffer>"
    }
    ChangePath()
}


SwapBufferView(*) {
    global buffer_view, root_text

    if buffer_view == 1 {
        buffer_view := 2
        root_text := "<buffer_hold>"
    } else {
        buffer_view := 1
        root_text := "<buffer>"
    }
    ChangePath()
}