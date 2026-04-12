LVGestureClick(lv, row) {
    global selected_gesture

    _UnhighlightSelectedChord()
    ToggleEnabled(0, UI.layer_move_btns, UI.layer_ctrl_btns, UI.chs_toggles)

    if !row || lv.GetText(0, 1) == "Has nested gestures" {
        selected_gesture := ""
        ToggleEnabled(0, UI.gest_toggles)
    } else {
        selected_gesture := lv.GetText(row, 6)
        ToggleEnabled(1, UI.gest_toggles)
    }
}


LVGestureDoubleClick(lv, row, from_selected:=false) {
    global gui_mod_val

    if !row {
        return
    }

    if lv.GetText(0, 1) == "Has nested gestures" {
        t := StrSplit(lv.GetText(row, 6), ";")
        if t.Length > 1 {
            gui_mod_val := Integer(t[2])
        }
        try {
            HandleKeyPress(Integer(t[1]))
        } catch {
            HandleKeyPress(t[1])
        }
    } else {
        OneNodeDeeper(lv.GetText(row, 6), gui_mod_val, false, lv.GetText(row, 1))
    }
}


AddNewGesture(*) {
    global selected_gesture

    ToggleEnabled(0, UI.gest_toggles)
    selected_gesture := false
    OpenForm(3)
}


ShowSelectedGesture(*) {
    parent_opts := _GetFirst(gui_entries.ubase).gesture_opts
    gest := _GetFirst(
        gui_entries.ubase.GetBaseHoldMod(selected_gesture, gui_mod_val, false, true
    ).ubase)
    SetOverlayOpts(parent_opts, gest.opts.pool)
    DrawExisting(gest)
}


ChangeSelectedGesture(*) {
    if !selected_gesture {
        return
    }
    OpenForm(3)
}


DeleteSelectedGesture(*) {
    global selected_gesture

    if MsgBox("Do you really want to delete this gesture?",
        "Confirmation", "YesNo Icon?") == "No" {
        return
    }

    gest_layer := ""
    checked_layers := layer_editing ? [selected_layer] : ActiveLayers.order
    ubase := gui_entries.ubase.GetBaseHoldMod(selected_gesture, gui_mod_val, false, true).ubase
    child_node := _GetFirst(ubase)
    for layer in checked_layers {
        if EqualNodes(child_node, _GetFirst(ubase, layer)) {
            gest_layer := layer
            break
        }
    }

    json_root := DeserializeMap(gest_layer)
    res := current_path.Length ? _WalkJson(json_root[gui_lang], current_path) : json_root[gui_lang]
    json_gestures := res[-1]
    if json_gestures[selected_gesture].Count !== 1 {
        json_gestures[selected_gesture].Delete(gui_mod_val)
    } else {
        json_gestures.Delete(selected_gesture)
    }

    SerializeMap(json_root, gest_layer)
    selected_gesture := ""
    ReadLayers()
    FillRoots()
    UpdLayers()
    ChangePath()
}