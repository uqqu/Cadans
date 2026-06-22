r_gui := false

LVLayerClick(lv, row, is_right_click:=false, *) {
    global last_selected_layer

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

    if row {
        last_selected_layer := ""
        for folder in layer_path {
            last_selected_layer .= folder . "\"
        }
        last_selected_layer .= lv.GetText(row, 3)
        ToggleEnabled(1, UI.layer_ctrl_btns)
        if lv.GetText(row, 2) {
            ToggleEnabled(1, UI.layer_move_btns)
        } else {
            ToggleEnabled(0, UI.layer_move_btns)
        }
    } else {
        last_selected_layer := ""
        ToggleEnabled(0, UI.layer_move_btns, UI.layer_ctrl_btns)
    }
}


LVLayerColClick(lv, col, *) {
    global layer_sort_col, layer_sort_desc

    if layer_sort_col == col {
        layer_sort_desc := !layer_sort_desc
    } else {
        layer_sort_col := col
        layer_sort_desc := false
    }
    FillLayers()
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

        if AllLayers[selected_layer] is Integer {
            MergeLayer(selected_layer)
        }
        SelectFirstLayerLayoutIfCurrentEmpty()
    }

    ChangePath(, false)
}


SelectFirstLayerLayoutIfCurrentEmpty() {
    global gui_lang

    counts := AllLayers[selected_layer]
    if counts.Get(gui_lang, 0) {
        return false
    }

    for lang in LANGS.order {
        if counts.Get(lang, 0) {
            gui_lang := lang
            UI["Langs"].Delete()
            UI["Langs"].Add(LANGS.GetAll())
            UI["Langs"].Text := LANGS[lang]
            FlashLayoutDDL()
            return true
        }
    }
    return false
}


FlashLayoutDDL() {
    SetTimer(RestoreLayoutDDL, 0)
    UI["Langs"].SetFont("Bold")
    UI["Langs"].Redraw()
    SetTimer(RestoreLayoutDDL, -1000)
}


RestoreLayoutDDL(*) {
    try {
        UI["Langs"].SetFont("Norm")
        UI["Langs"].Redraw()
    }
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

    ToggleFreeze(1)

    layer_name := ""
    for folder in layer_path {
        layer_name .= folder . "\"
    }
    layer_name .= lv.GetText(row, 3)

    if !icon_type {  ; inactive
        is_right_click ? ActiveLayers.Add(layer_name, , 1) : ActiveLayers.Add(layer_name)
        if AllLayers[layer_name] is Integer {
            MergeLayer(layer_name)
        }
    } else {  ; active
        ActiveLayers.Remove(layer_name)
    }
    for i, name in ActiveLayers.order {
        ActiveLayers.Set(name, i)
    }

    _WriteActiveLayersToConfig()
    ToggleFreeze(0)
}


_WriteActiveLayersToConfig(without_upd:=false) {
    str_value := ""
    for layer in ActiveLayers.order {
        str_value .= layer . ", "
    }

    IniWrite(SubStr(str_value, 1, -2), "config.ini", "Main", "ActiveLayers")
    if !without_upd {
        ToggleFreeze(1)
        UpdLayers()
        ChangePath()
        ToggleFreeze(0)
    }
}


AddNewLayer(*) {
    ToggleFreeze(1)
    name := "new layer"
    layer_prefix := ""
    for folder in layer_path {
        layer_prefix .= folder . "\"
    }
    if FileExist("layers\" . layer_prefix . "new layer.json") {
        i := 2
        while FileExist("layers\" . layer_prefix . "new layer (" . i . ").json") {
            i++
        }
        name := "new layer (" . i . ")"
    }
    layer_name := layer_prefix . name
    LayersMeta[layer_name] := Map("version", 0.83, "rtags", "", "rdescription", "", "rprocesses", "",
        "tags", [], "processes", [{invert: false, kind: "*", val: "*", children: []}])
    SerializeMap(Map(), layer_name)
    AllLayers.Add(layer_name, true)
    UpdLayers()
    UpdateKeys()
    ToggleFreeze(0)
}

EditSelectedLayer(*) {
    global r_gui

    RDestroy()
    r_gui := Gui("-SysMenu", "Edit meta for `"" . last_selected_layer . "`"")
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
    r_gui.Add("Text", "+0x200 x14 y" . y . " w" . label_w . " h" . row_h, "Window rule")
    proc_edit := r_gui.Add("Edit", "vProcesses h20 x" . edit_x . " yp+2 w" . (edit_w - 24))
    proc_edit.Text := LayersMeta[last_selected_layer]["rprocesses"]
    r_gui.Add("Button", "x+4 yp+0 h20 w20", "?").OnEvent("Click", (*) => MsgBox(
        "You can limit assignments from this layer to work only in specific windows."
        . "`nUse process names, ahk-groups, title regular expressions,"
        . "`nand predefined groups from the settings – all with the same syntax."
        . "`n`nExamples:"
        . "`n`nOnly in certain groups/applications:`n  'browsers, totalcmd.exe'"
        . "`n`nWith the 'c:' prefix – only when the class matches:`n  'c:XamlExplorerHostIslandWindow'"
        . "`n`nWith the 't:' prefix – only when the title matches (Google: ahk regex quickRef):"
        . "`n  't:^Cadans|^Commits'"
        . "`n`nUse them to refine conditions:"
        . "`n  'explorer.exe[c:XamlExplorerHostIslandWindow]',"
        . "`n  'explorer.exe[t:^Task View$]',"
        . "`n  'browsers[t:i)Google]',"
        . "`n  'c:XamlExplorerHostIslandWindow[t:^Task View$]'"
        . "`nNested rules are also supported:"
        . "`n  'explorer.exe[c:XamlExplorerHostIslandWindow[t:^Task View$]]'"
        . "`n`n'-' at any level acts as inversion:"
        . "`n  '-games, -explorer.exe' = 'everywhere except this group and app'"
        . "`n  'explorer.exe[-t:^Task View$]' = 'all explorer windows except Task View'"
        . "`n  '-explorer.exe[-t:^Task View$]' = 'everywhere outside explorer, BUT including Task View'"
        . "`n  'browsers[-t:Google]' = 'all browser processes while the title does not contain Google'"
        . "`n`nLeave blank to keep the layer always active.", "Help"
    ))

    y += row_h + 8

    save_btn := r_gui.Add("Button", "x260 y" . y . " w66 h20 Default", "Save")
    cancel_btn := r_gui.Add("Button", "x+8 yp+0 w66 h20", "Cancel")

    save_btn.OnEvent("Click", Save)
    cancel_btn.OnEvent("Click", RDestroy)
    r_gui.OnEvent("Escape", RDestroy)
    r_gui.OnEvent("Close", RDestroy)

    r_gui.Show("AutoSize Center")

    Save(*) {
        n_proc := r_gui["Processes"].Text
        err := GetWindowRuleValidationError(n_proc)
        if err {
            MsgBox(err, "Invalid window rule", "Icon!")
            return
        }

        ToggleFreeze(1)
        new_name := NormalizeLayerName(r_gui["Name"].Text)
        new_filepath := "layers/" . new_name . ".json"
        old_filepath := "layers/" . last_selected_layer . ".json"
        if new_filepath !== old_filepath {
            if FileExist(new_filepath) && MsgBox(
                "File with this name already exists. Do you want to overwrite it?",
                "Confirmation", "YesNo Icon?") == "No" {
                ToggleFreeze(0)
                return
            }
            SplitPath(new_filepath, , &new_dir)
            if new_dir && !DirExist(new_dir) {
                DirCreate(new_dir)
            }
            FileMove("layers/" . last_selected_layer . ".json", new_filepath, true)
        }

        n_tags := r_gui["Tags"].Text
        n_descr := r_gui["Descr"].Text
        m := LayersMeta[last_selected_layer]
        if n_tags == m["rtags"] && n_descr == m["rdescription"] && n_proc == m["rprocesses"] {
            if new_filepath !== old_filepath {
                Refresh()
                FillLayerTags()
                FillLayers()
                FillOther()
            }
            ToggleFreeze(0)
            RDestroy()
            return
        }

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

        if new_filepath !== old_filepath && ActiveLayers.Has(last_selected_layer) {
            p := ActiveLayers[last_selected_layer]
            ActiveLayers.Remove(last_selected_layer)
            ActiveLayers.Add(new_name, , p)
            _WriteActiveLayersToConfig(true)
        }

        Refresh(2)
        RDestroy()
    }
}

RDestroy(*) {
    global r_gui

    if r_gui {
        try r_gui.Destroy()
        r_gui := false
    }
}


DeleteSelectedLayer(*) {
    global last_selected_layer

    if MsgBox("Do you really want to delete that layer?", "Confirmation", "YesNo Icon?") == "No" {
        return
    }
    ToggleFreeze(1)

    FileDelete("layers/" . last_selected_layer . ".json")
    AllLayers.Remove(last_selected_layer)
    if ActiveLayers.Has(last_selected_layer) {
        ActiveLayers.Remove(last_selected_layer)
        _WriteActiveLayersToConfig(true)
    }
    if !AllLayers.count {
        AddNewLayer()
    }
    last_selected_layer := ""
    Refresh()
    FillLayerTags()
    FillLayers()
    FillOther()
}


MoveUpSelectedLayer(*) {
    _MoveSelectedLayer(-1)
}


MoveDownSelectedLayer(*) {
    _MoveSelectedLayer(1)
}


_MoveSelectedLayer(sign, to_the_end:=false, *) {
    lv := UI["LV_layers"]
    loop lv.GetCount() {
        if _GetLayerNameFromLVRow(A_Index) == last_selected_layer {
            try {
                prior := Integer(UI["LV_layers"].GetText(A_Index, 2))
            } catch {
                return
            }
            break
        }
    }

    if prior == (sign == -1 ? 1 : ActiveLayers.count) {
        _FocusLastLayerLV()
        return
    }

    fin := to_the_end ? (sign == -1 ? 1 : ActiveLayers.count) : prior + 1 * sign
    while prior !== fin {
        n := prior + 1 * sign
        from := ActiveLayers.order[prior]
        to := ActiveLayers.order[n]
        ActiveLayers.map[from] := n
        ActiveLayers.map[to] := prior
        ActiveLayers.order[prior] := ActiveLayers.order[n]
        ActiveLayers.order[n] := from
        prior := n
    }

    _WriteActiveLayersToConfig()
    _FocusLastLayerLV()
}


_FocusLastLayerLV() {
    if last_selected_layer {
        lv := UI["LV_layers"]
        lv.Focus()
        loop lv.GetCount() {
            if _GetLayerNameFromLVRow(A_Index) == last_selected_layer {
                p := lv.GetText(A_Index, 2) != ""
                lv.Modify(0, "-Select")
                lv.Modify(A_Index, "Select Focus Vis")
                break
            }
        }
        ToggleEnabled(p, UI.layer_move_btns)
        ToggleEnabled(1, UI.layer_ctrl_btns)
    }
}


_GetLayerNameFromLVRow(row) {
    layer_name := ""
    for folder in layer_path {
        layer_name .= folder . "\"
    }
    return layer_name . UI["LV_layers"].GetText(row, 3)
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
