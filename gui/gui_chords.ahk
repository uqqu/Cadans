LVChordClick(lv, row) {
    global selected_chord

    ToggleEnabled(0, UI.layer_move_btns, UI.layer_ctrl_btns, UI.gest_toggles)
    if start_temp_chord {
        return
    }

    _UnhighlightSelectedChord()
    if row {
        selected_chord := ChordToStr(lv.GetText(row, 1))
        ToggleEnabled(1, UI.chs_toggles)
        for sc in StrSplit(selected_chord, "-") {
            UI[sc].Opt("+Background" . CONF.selected_chord_color.v)
            UI[sc].Text .= ""
        }
    } else {
        selected_chord := ""
        ToggleEnabled(0, UI.chs_toggles)
    }
}


_UnhighlightSelectedChord() {
    if selected_chord {
        for sc in StrSplit(selected_chord, "-") {
            isc := sc
            try isc := Integer(sc)
            FillOneButton(isc, UI[sc], isc)
        }
    }
}


LVChordDoubleClick(lv, row, from_selected:=false) {
    if row && !start_temp_chord {
        OneNodeDeeper(ChordToStr(lv.GetText(row, 1)), gui_mod_val, lv.GetText(row, 1))
    }
}


_CheckUnsavedChord() {
    equal := true
    if temp_chord.Count == start_temp_chord.Count {
        for key, value in temp_chord {
            if !start_temp_chord.Has(key) {
                equal := false
                break
            }
        }
    } else {
        equal := false
    }

    if !equal && MsgBox("The chord has been changed. Do you really want to undo the changes?",
        "Confirmation", "YesNo Icon?") == "No" {
        return false
    }
    return true
}


AddNewChord(*) {
    ChordEditing(true)
}


ChangeSelectedChord(*) {
    ChordEditing(false)
}


ChordEditing(new:=true) {
    global temp_chord, start_temp_chord, selected_chord

    if start_temp_chord && !_CheckUnsavedChord() {
        return
    }

    temp_chord := Map()
    start_temp_chord := Map()
    if new {
        UI.Title := "Adding a new chord"
        selected_chord := ""
    } else {
        UI.Title := "Editing a chord"
        for sc in StrSplit(selected_chord, "-") {
            temp_chord[sc] := true
            start_temp_chord[sc] := true
        }
    }

    ToggleVisibility(2, UI.chs_back, UI.chs_front)
    UpdateKeys()
}


DeleteSelectedChord(_, without_confirmation:=false, without_upd:=false) {
    global selected_chord

    if !without_confirmation && MsgBox("Do you really want to delete this chord?",
        "Confirmation", "YesNo Icon?") == "No" {
        return
    }

    layers := []
    checked_layers := layer_editing ? [selected_layer] : ActiveLayers.order
    ubase := gui_entries.ubase.GetBaseHoldMod(selected_chord, gui_mod_val, true).ubase
    child_node := _GetFirst(ubase)
    for layer in checked_layers {
        if EqualNodes(child_node, _GetFirst(ubase, layer)) {
            layers.Push(layer)
        }
    }

    if layers.Length > 1 {
    	selected_layers := []
    	for idx in ChooseLayers(layers) {
    		selected_layers.Push(layers[idx])
    	}
    	layers := selected_layers
    }

    for layer in layers {
	    json_root := DeserializeMap(layer)
        res := current_path.Length ? _WalkJson(json_root[gui_lang], current_path)
            : json_root[gui_lang]
        json_scancodes := res[-3]
        json_chords := res[-2]
        if json_chords[selected_chord].Count !== 1 {
            json_chords[selected_chord].Delete(gui_mod_val)
        } else {
            json_chords.Delete(selected_chord)
        }
        scancodes := Map()
        for sc in StrSplit(selected_chord, "-") {
            scancodes[sc] := true
        }
        if json_chords.Count {
            for buf, mods in json_chords {
                if mods.Has(gui_mod_val) {
                    for sc in StrSplit(buf, "-") {
                        try scancodes.Delete(sc)
                    }
                }
            }
        }

        for sc in scancodes {
            try {
                sc_node := json_scancodes[Integer(sc)][gui_mod_val+1]
            } catch {
                sc_node := json_scancodes[sc][gui_mod_val+1]
            }
            sc_node[1] := TYPES.Disabled
            sc_node[2] := ""
        }

	    SerializeMap(json_root, layer)
    }
    selected_chord := ""
    ReadLayers()
    if !without_upd {
        FillRoots()
        UpdLayers()
        ChangePath()
    }
}


CancelChordEditing(_, without_confirmation:=false) {
    global temp_chord, start_temp_chord

    if !without_confirmation && !_CheckUnsavedChord() {
        return
    }

    temp_chord := 0
    start_temp_chord := 0

    ToggleVisibility(2, UI.chs_back, UI.chs_front)
    UI.Title := proj_name

    UpdateKeys()
}


DiscardChordEditing(*) {
    global temp_chord

    temp_chord := Map()
    for key, _ in start_temp_chord {
        temp_chord[key] := true
    }

    UpdateKeys()
}


SaveEditedChord(*) {
    if temp_chord.Count < 2 {
        MsgBox("Chord must include at least 2 keys.", "Not enough keys", "Icon!")
        return
    }
    equal := true
    if temp_chord.Count == start_temp_chord.Count {
        for key, value in temp_chord {
            if !start_temp_chord.Has(key) {
                equal := false
                break
            }
        }
    } else {
        equal := false
    }
    if !equal && (layer_editing || ActiveLayers.order.Length == 1) {
        layer := layer_editing ? selected_layer : ActiveLayers.order[1]
        chord_txt := ChordToStr(temp_chord)
        if gui_entries.ubase.chords.Has(chord_txt)
            && gui_entries.ubase.chords[chord_txt].Has(gui_mod_val)
            && gui_entries.ubase.chords[chord_txt][gui_mod_val].layers.Has(layer)
            && _GetFirst(gui_entries.ubase.GetBaseHoldMod(chord_txt, gui_mod_val, true).ubase)
            && MsgBox("Chord with these keys already exists on this layer. "
                . "Do you want to overwrite it?", "Confirmation", "YesNo Icon?") == "No" {
            return
        }
    }
    OpenForm(2)
}


ChordToStr(scs) {
    res := ""
    if scs is String {
        for key in StrSplit(scs, " ") {
            key := LTrim(key, "&")
            if key {
                int_sc := GetKeySC(key)
                res .= (int_sc || key) . "-"
            }
        }
    } else {
        for sc in scs {
            res .= LTrim(sc, "&") . "-"
        }
    }
    return SubStr(Sort(res, "D-"), 1, -1)
}