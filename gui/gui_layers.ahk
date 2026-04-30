LVLayerClick(lv, row, is_right_click:=false, *) {
    global last_selected_layer, selected_layer_priority

    _UnhighlightSelectedChord()
    ToggleEnabled(0, UI.chs_toggles, UI.gest_toggles)

    if GetColumnAtCursor(lv) == 1 {
        LVLayerCheck(lv, row, is_right_click)
        return
    }

    if layer_editing || GetRowIconIndex(lv, row) > 1 {
        ToggleEnabled(0, UI.layer_move_btns, UI.layer_ctrl_btns)
        return
    }

    selected_layer_priority := 0
    if row {
        last_selected_layer := ""
        for folder in layer_path {
            last_selected_layer .= folder . "\"
        }
        last_selected_layer .= lv.GetText(row, 3)
        ToggleEnabled(1, UI.layer_ctrl_btns)
        if lv.GetText(row, 2) {
            selected_layer_priority := lv.GetText(row, 2)
            ToggleEnabled(1, UI.layer_move_btns)
        } else {
            ToggleEnabled(0, UI.layer_move_btns)
        }
    } else {
        last_selected_layer := ""
        ToggleEnabled(0, UI.layer_move_btns, UI.layer_ctrl_btns)
    }
}


LVLayerDoubleClick(lv, row, from_selected:=false) {
    global layer_editing, root_text, selected_layer, last_selected_layer, buffer_view, layer_path

    if (!row && !from_selected) || temp_chord {
        return
    }

    i := from_selected || GetRowIconIndex(lv, row)

    if i == 3 {  ; 'back' icon
        layer_path.Length -= 1
    } else if i == 2 {  ; 'folder' icon
        layer_path.Push(lv.GetText(row, 3))
        if layer_path.Length == 1 && layer_path[-1] == "custom layouts" {
            cnt := IniRead("config.ini", "Main", "CustomLayoutWarningsCnt", 0)
            if cnt < 2 {
                MsgBox("It is strongly not recommended to use this program for permanent "
                    . "reassignments at the basic level. But it can be useful for familiarizing "
                    . "yourself with different layouts, or serve as a temporary solution.",
                    "Warning")
            } else if cnt < 4 || cnt == 7 || !Mod(cnt, 10) {
                ToolTip("Do not use for permanent default key reassignments")
                SetTimer(ToolTip, -2222)
            }
            IniWrite(cnt + 1, "config.ini", "Main", "CustomLayoutWarningsCnt")
        }
    } else {  ; just layer
        buffer_view := 0
        layer_editing := true
        if !from_selected {
            last_selected_layer := ""
            for folder in layer_path {
                last_selected_layer .= folder . "\"
            }
            last_selected_layer .= lv.GetText(row, 3)
        }
        selected_layer := last_selected_layer
        root_text := StrSplit(last_selected_layer, "\")[-1]

        UI["DdlProcCtx"].Enabled := false
        UI["DdlProcCtx"].Delete()
        UI["DdlProcCtx"].Add([LayersMeta[selected_layer]["rprocesses"], "*"])
        UI["DdlProcCtx"].Text := LayersMeta[selected_layer]["rprocesses"] || "*"

        ToggleVisibility(1, UI["BtnBackToRoot"])
        ToggleVisibility(0, UI.layer_move_btns, UI.layer_ctrl_btns, UI["BtnAddNewLayer"])

        if AllLayers.map[selected_layer] is Integer {
            MergeLayer(selected_layer)
        }
    }

    ChangePath(, false)
}


LVLayerCheck(lv, row, is_right_click) {
    if !row {
        return
    }

    icon_type := GetRowIconIndex(lv, row)
    if icon_type > 1 {  ; folder
        LVLayerDoubleClick(lv, row)
        return
    }

    layer_name := ""
    for folder in layer_path {
        layer_name .= folder . "\"
    }
    layer_name .= lv.GetText(row, 3)

    if !icon_type {  ; inactive
        is_right_click ? ActiveLayers.Add(layer_name, , 1) : ActiveLayers.Add(layer_name)
        if AllLayers.map[layer_name] is Integer {
            MergeLayer(layer_name)
        }
    } else {  ; active
        ActiveLayers.Remove(layer_name)
    }
    for i, name in ActiveLayers.order {
        ActiveLayers.map[name] := i
    }

    _WriteActiveLayersToConfig()
}


_WriteActiveLayersToConfig(without_upd:=false) {
    str_value := ""
    for layer in ActiveLayers.order {
        str_value .= layer . ", "
    }

    IniWrite(SubStr(str_value, 1, -2), "config.ini", "Main", "ActiveLayers")
    if !without_upd {
        UpdLayers()
        ChangePath()
    }
}


AddNewLayer(*) {
    name := "new layer"
    layer_str := "layers\"
    for folder in layer_path {
        layer_str .= folder . "\"
    }
    if FileExist(layer_str . "new layer.json") {
        i := 2
        while FileExist(layer_str . "new layer (" . i . ").json") {
            i++
        }
        name := "new layer (" . i . ")"
    }
    LayersMeta[name] := Map("version", 0.8, "rtags", "", "rdescription", "", "rprocesses", "",
        "tags", [], "processes", Map("*", true))
    SerializeMap(Map(), name)
    AllLayers.Add(name, Map())
    UpdLayers()
    UpdateKeys()
}


EditSelectedLayer(*) {
    static prev:=false

    try prev.Destroy()
    r_gui := Gui("-SysMenu", "Edit meta for `"" . last_selected_layer . "`"")
    prev := r_gui
    r_gui.SetFont("s9")

    label_w := 70
    edit_x := label_w + 10
    edit_w := 320
    row_h := 24
    gap_y := 4

    y := 16
    r_gui.Add("Text", "+0x200 x14 y" . y . " w" . label_w . " h" . row_h, "Name")
    name_edit := r_gui.Add("Edit", "vName h20 x" . edit_x . " yp+2 w" . edit_w)
    name_edit.Text := last_selected_layer

    y += row_h + gap_y
    r_gui.Add("Text", "+0x200 x14 y" . y . " w" . label_w . " h" . row_h, "Description")
    descr_edit := r_gui.Add("Edit", "vDescr h20 x" . edit_x . " yp+2 w" . edit_w)
    descr_edit.Text := LayersMeta[last_selected_layer]["rdescription"]

    y += row_h + gap_y
    r_gui.Add("Text", "+0x200 x14 y" . y . " w" . label_w . " h" . row_h, "Tags")
    tags_edit := r_gui.Add("Edit", "vTags h20 x" . edit_x . " yp+2 w" . edit_w)
    tags_edit.Text := LayersMeta[last_selected_layer]["rtags"]

    y += row_h + gap_y
    r_gui.Add("Text", "+0x200 x14 y" . y . " w" . label_w . " h" . row_h, "Processes")
    proc_edit := r_gui.Add("Edit", "vProcesses h20 x" . edit_x . " yp+2 w" . (edit_w - 24))
    proc_edit.Text := LayersMeta[last_selected_layer]["rprocesses"]
    r_gui.Add("Button", "x+4 yp+0 h20 w20", "?").OnEvent("Click", (*) => MsgBox(
        "You can limit assignments from this layer to work only in specific applications"
        . " or, conversely, exclude those applications."
        . "`nUse process names (as in Task Manager) or the groups associated with them,"
        . " as you define it in a special section of the settings."
        . "`nUse a comma as a separator. Case-insensitive."
        . "`n`nExamples`nThe layer is active only in "
        . "certain processes: `"+firefox.exe, chrome.exe`""
        . "`nThe layer is disabled only in specific group: `"-games`""
        . "`nCan be combined to specifically exclude from the group: `"-browsers, +firefox.exe`""
        . "`nLeave blank to keep the layer always active.", "Help"
    ))

    y += row_h + 8

    save_btn := r_gui.Add("Button", "x260 y" . y . " w66 h20 Default", "Save")
    cancel_btn := r_gui.Add("Button", "x+8 yp+0 w66 h20", "Cancel")

    save_btn.OnEvent("Click", Save)
    cancel_btn.OnEvent("Click", Cancel)
    r_gui.OnEvent("Escape", Cancel)
    r_gui.OnEvent("Close", Cancel)

    r_gui.Show("AutoSize Center")

    Save(*) {
        new_filepath := "layers/" . r_gui["Name"].Text . ".json"
        old_filepath := "layers/" . last_selected_layer . ".json"
        if new_filepath !== old_filepath {
            if FileExist(new_filepath) && MsgBox(
                "File with this name already exists. Do you want to overwrite it?",
                "Confirmation", "YesNo Icon?") == "No" {
                return
            }
            FileMove("layers/" . last_selected_layer . ".json", new_filepath, true)
        }

        n_tags := r_gui["Tags"].Text
        n_descr := r_gui["Descr"].Text
        n_proc := r_gui["Processes"].Text
        m := LayersMeta[last_selected_layer]
        if n_tags == m["rtags"] && n_descr == m["rdescription"] && n_proc == m["rprocesses"] {
            r_gui.Destroy()
            if new_filepath !== old_filepath {
                ToggleFreeze(1)
                ReadLayers()
                FillRoots()
                UpdLayers()
                FillLayerTags()
                FillLayers()
                FillOther()
            }
            return
        }
        ToggleFreeze(1)

        src := FileOpen(new_filepath, "r", "UTF-8")
        first_line := RTrim(src.ReadLine(), "`r`n")
        src.Pos := 0

        while !src.AtEOF {
            _pos := src.Pos
            if !RegExMatch(LTrim(src.ReadLine(), Chr(0xFEFF) . "`r`n`t "), "^\s*//") {
                break
            }
        }
        src.Close()

        res := first_line . "`r`n// " . n_tags . "`r`n// " . n_descr . "`r`n// " . n_proc

        tmp := new_filepath . ".tmp"
        trg := FileOpen(tmp, "w", "UTF-8")
        trg.Write(RTrim(res, "`r`n") . "`r`n")
        trg.Close()

        src_bin := FileOpen(new_filepath, "r")
        trg_bin := FileOpen(tmp, "a")

        src_bin.Pos := _pos

        buf := Buffer(65536)
        while (n := src_bin.RawRead(buf, buf.Size)) {
            trg_bin.RawWrite(buf, n)
        }

        src_bin.Close()
        trg_bin.Close()

        FileMove(tmp, new_filepath, 1)

        if ActiveLayers.Has(last_selected_layer) {
            p := ActiveLayers[last_selected_layer]
            ActiveLayers.Remove(last_selected_layer)
            ActiveLayers.Add(r_gui["Name"].Text, , p)
            _WriteActiveLayersToConfig(true)
        }

        r_gui.Destroy()

        ReadLayers()
        FillRoots()
        UpdLayers()
        FillLayerTags()
        FillLayers()
        FillOther()
    }

    Cancel(*) {
        r_gui.Destroy()
    }
}



DeleteSelectedLayer(*) {
    global selected_layer_priority, last_selected_layer

    if MsgBox("Do you really want to delete that layer?", "Confirmation", "YesNo Icon?") == "No" {
        return
    }

    FileDelete("layers/" . last_selected_layer . ".json")
    AllLayers.Remove(last_selected_layer)
    if selected_layer_priority {
        ActiveLayers.Remove(last_selected_layer)
        _WriteActiveLayersToConfig()
        selected_layer_priority := 0
    }
    if !AllLayers.Length {
        AddNewLayer()
    }
    last_selected_layer := ""
    UpdateKeys()
}


MoveUpSelectedLayer(*) {
    _MoveSelectedLayer(-1)
}


MoveDownSelectedLayer(*) {
    _MoveSelectedLayer(1)
}


_MoveSelectedLayer(sign, to_the_end:=false, *) {
    global selected_layer_priority

    prior := selected_layer_priority
    if prior == (sign == -1 ? 1 : ActiveLayers.Length) {
        _FocusLastLayerLV()
        return
    }

    fin := to_the_end ? (sign == -1 ? 1 : ActiveLayers.order.Length) : prior + 1 * sign
    while selected_layer_priority !== fin {
        n := prior + 1 * sign
        from := ActiveLayers.order[prior]
        to := ActiveLayers.order[n]
        ActiveLayers.map[from] := n
        ActiveLayers.map[to] := prior
        ActiveLayers.order[prior] := ActiveLayers.order[n]
        ActiveLayers.order[n] := from
        selected_layer_priority := n
        prior := selected_layer_priority
    }

    _WriteActiveLayersToConfig()
    _FocusLastLayerLV()
}


_FocusLastLayerLV() {
    lv := UI["LV_layers"]
    lv.Focus()
    loop lv.GetCount() {
        if lv.GetText(A_Index, 2) == selected_layer_priority {
            lv.Modify(A_Index, "Select Focus")
            LVLayerClick(UI["LV_layers"], A_Index)
            return
        }
    }
}


ChooseLayers(layers) {
    selected := []
    layers_form := Gui("+AlwaysOnTop", "")
    checkboxes := []

    for i, val in layers {
        checkboxes.Push(layers_form.Add("CheckBox", "vCB" . i, val))
    }

    layers_form.Add("Button", "Default w80", "OK").OnEvent("Click", (*) => layers_form.Submit())
    layers_form.Show("w200")

    WinWaitClose(layers_form.Hwnd)

    for i, cb in checkboxes {
        if cb.Value {
            selected.Push(cb.Text)
        }
    }

    return selected
}


BackToRoot(*) {
    global layer_editing, selected_layer, root_text, buffer_view

    if buffer_view {
        buffer_view := 0
    }
    layer_editing := false
    selected_layer := ""
    root_text := "root"
    uncat := [UI["BtnBackToRoot"], UI["BtnAddNewLayer"]]
    ToggleVisibility(2, UI.layer_move_btns, UI.layer_ctrl_btns, uncat)

    ChangePath(, false)
}


ToggleLayersTag(obj, *) {
    tag := obj.Text
    if !CONF.tags.Has(tag) || ((tag == "Active" || tag == "Inactive") && !CONF.tags[tag]) {
        CONF.tags[tag] := true
        obj.Opt("cGreen")
        obj.Text .= ""
    } else if CONF.tags[tag] {
        CONF.tags[tag] := false
        obj.Opt("cRed")
        obj.Text .= ""
    } else {
        CONF.tags.Delete(tag)
        obj.Opt("cGray")
        obj.Text .= ""
    }

    str_val := ""
    for chosen_tag, v in CONF.tags {
        if chosen_tag {
            str_val .= (v ? "" : "-") . chosen_tag . ", "
        }
    }
    IniWrite(SubStr(str_val, 1, -2), "config.ini", "Main", "ChosenTags")
    FillLayers()
}


ExpandTags(*) {
    static expanded:=-1

    UI["LV_layers"].GetPos(&x, &y, &w, &h)
    UI["LV_layers"].Move(
        x, y - (extra_tags_height * expanded), w, h + (extra_tags_height * expanded)
    )
    UI.extra_tags[1].Text := ["▴", "▾"][(expanded > 0) + 1]
    ToggleVisibility(2, UI.extra_tags)
    ToggleVisibility(1, UI.extra_tags[1])
    expanded *= -1
}