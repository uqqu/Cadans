AltHelp() {
    static prev_hwnd:=0

    if !GetKeyState("Alt") {
        SetTimer(AltHelp, 0)
        prev_hwnd := 0
        ToolTip()
        return
    }

    MouseGetPos(,, &win_id, &ctrl_hwnd, 2)
    if !ctrl_hwnd || ctrl_hwnd == prev_hwnd {
        return
    }

    by_cursor_pos := false
    txt := ""
    if win_id !== UI.Hwnd {
        prev_hwnd := 0
        ToolTip()
        return
    }
    obj := GuiCtrlFromHwnd(ctrl_hwnd)
    if !obj {
        return
    }
    i_sc := obj.Name
    try i_sc := Integer(i_sc)
    path := buffer_view ? buffer_path : current_path

    if i_sc == "CurrMod" {
        txt := "Not a real key – just a hint showing the current modifier value.`n"
            . "This modifier is used when adding and triggering assignments "
            . "in the current view.`n`n"
        if !gui_mod_val {
            txt .= "Is not used for the current view."
        } else {
            mods := DecomposeMods(gui_mod_val, true)
            if StrLen(mods) > 1 {
                txt .= "Calculated as the sum of 2^(modifier) for the following modifiers: " . mods
            } else {
                txt .= "Calculated as 2^(current modifier) (" . mods . ")."
            }
            txt .= "`nResets when pressed."
        }
    } else if i_sc == "DdlProcCtx" {
        txt := "List of process groups (contexts) with their own assignments.`n"
            . "They are determined by the rules of active layers.`n`n"
        if obj.Enabled {
            txt .= "Now you see assignments for"
            if obj.Text == "*" {
                txt .= " all processes that do not have their own rules."
            } else {
                txt .= ":`n" . JoinArr(PROC_CTX.id_to_names[gui_proc_ctx], ", ")
                txt .= "`n`nThis context is derived from the following layers "
                    . "(in addition to the global ones):`n"
                    . JoinArr(GetLayersDifferFromOther(gui_proc_ctx), ", ")
            }
        } else {
            txt .= "In layer editing mode, this shows only the raw rule of the layer"
            if obj.Text == "*" {
                txt .= ", but this layer has no rule for processes.`nIt is always active."
            } else {
                txt .= ":`n" . obj.Text
                b := false
                for n in StrSplit(obj.Text, ",", " `n`r`t") {
                    if CONF.ProcessGroups.Has(n) {
                        if !b {
                            txt .= "`n`nThe rule refers to the groups defined in the settings:"
                            b := true
                        }
                        txt .= "`n" . n . " = " . CONF.ProcessGroups[n]
                    }
                }
            }
        }
    } else if i_sc == "LV_gestures" {
        res := GetColumnAtCursor(UI[i_sc], true)
        c := res[1]
        r := res[2]
        if r == 0 {
            prev_hwnd := 0
            ToolTip()
            return
        } else if r == -1 {
            fake_hwnd := "1" . c . r
            if prev_hwnd == fake_hwnd {
                return
            }
            by_cursor_pos := true
            prev_hwnd := fake_hwnd
            if obj.GetText(0, 1) == "Has nested gestures" {
                if c == 1 {
                    txt := "On levels where gestures cannot be added, "
                        . "shows key-triggers that have assigned gestures."
                } else if c == 2 {
                    txt := "Number of nested gestures for the key."
                }
            } else if c < 3 {
                txt := "List of gestures assigned for the current path."
                    . "`nDouble-click a gesture to go deeper and add nested assignments."
            } else if c == 3 {
                txt := "Pool and recognition options for gestures.`nOptions are shown only if "
                    . "they differ from global settings.`nHold Alt to see all options.`n"
                    . "`nPool: TopLeft, Top, TopRight, Left, Center, Right, BottomLeft, "
                    . "Bottom, BottomRight`nRotation:`n- None (strict angle)`n- Limited (snap to "
                    . "8 directions for noise smoothing)`n- Full (rotation invariance)"
                    . "`nScale impact: from 0 (no effect) to 1 (perfect matching)"
                    . "`nBidirectional matching (on/off)"
                    . "`nStart-point invariance, only for closed figures (on/off)"
            } else if c == 4 {
                txt := "Number of nested assignments for this gesture.`n"
                    . "Gestures (and chords as well) can have any child assignments,`n"
                    . "including new key-triggers with own gestures."
            } else if c == 6 {
                txt := "Seriously, you don't need this"
            }
        } else {
            fake_hwnd := "1" . r
            if prev_hwnd == fake_hwnd {
                return
            }
            by_cursor_pos := true
            prev_hwnd := fake_hwnd
            res := StrSplit(obj.GetText(r, 6), ";")
            gst := res[1]
            md := 0
            try md := Integer(res[2])
            try gst := Integer(gst)
            b := StrLen(gst) > 64
            res := gui_entries.ubase.GetBaseHoldMod(gst, md, false, b, false, false)
            txt := _GetKeyInfo(gst, md & ~1, res, gui_entries, true, , , b)
        }
    } else if i_sc == "LV_layers" {
        res := GetColumnAtCursor(UI[i_sc], true)
        c := res[1]
        r := res[2]
        if r == 0 {
            prev_hwnd := 0
            ToolTip()
            return
        } else if r == -1 {
            fake_hwnd := "2" . c . r
            if prev_hwnd == fake_hwnd {
                return
            }
            by_cursor_pos := true
            prev_hwnd := fake_hwnd
            if c == 1 {
                txt := "Each layer contains assignments grouped by functionality, "
                    . "with any number of nesting levels.`nHere you can toggle their activity "
                    . "with checkboxes (right-click to activate with the highest priority).`n"
                    . "Some related layers are grouped into folders with corresponding icon."
            } else if c == 2 {
                txt := "Active layers have priorities. This matters only when assignments from "
                    . "different layers overlap at the same level.`n"
                    . "In this case the assignment from the highest-priority layer is used."
                    . "`nIdentical assignments are merged, including their nested assignments."
            } else if c == 3 {
                txt := "Layers and subfolders, as named in the 'layers' directory.`nWith Alt it "
                    . "shows meta information, such as description, tags and process rule."
            } else if !path.Length {
                if c == 4 {
                    txt := "At the root level, this column shows the total number of assignments "
                        . "across layers for the current language/layout.`n"
                        . "Try to switch it in the right drop-down list."
                        . "`nFor folders this column diplays number of sublayers."
                } else if c == 6 {
                    txt := "At the root level, this column shows the total number of assignments "
                        . "across layers from all other languages/layouts."
                }
            } else if c == 4 {
                txt := "Tap assignments from different layers for event by "
                    . "your current path (chain of transitions)"
                    . "`nFor folders this column diplays number of sublayers."
            } else if c == 5 {
                txt := "Number of nested assignments for tap event by current "
                    . "path from different layers."
            } else if c == 6 {
                txt := "Hold assignments from different layers for event by "
                    . "your current path (chain of transitions)"
            } else if c == 7 {
                txt := "Number of nested assignments for hold event by current "
                    . "path from different layers."
            }
        } else {
            if c < 4 || !path.Length {
                c := 3
            }
            fake_hwnd := "2" . c . r
            if prev_hwnd == fake_hwnd {
                return
            }
            by_cursor_pos := true
            prev_hwnd := fake_hwnd
            i := GetRowIconIndex(UI["LV_layers"], r)
            if i > 1 {
                prev_hwnd := 0
                ToolTip()
                return
            } else {
                layer := ""
                for folder in layer_path {
                    layer .= folder . "\"
                }
                layer .= obj.GetText(r, 3)
                val := obj.GetText(r, c)
                if c == 3 || !path.Length {
                    m := LayersMeta[layer]
                    txt := ""
                    if m["rdescription"] {
                        txt .= m["rdescription"] . "`n`n"
                    }
                    if m["rtags"] {
                        txt .= "Tags: " . m["rtags"] . "`n"
                    }
                    if m["rprocesses"] {
                        txt .= "Has process rule: " . m["rprocesses"]
                    }
                } else if c == 4 && val {
                    entries := _GetUnholdEntries()
                    txt := _GetKeyInfo(path[-1][1], path[-1][2] & ~1, entries, entries,
                        true, , path[-1][3], path[-1][4], layer)
                } else if c == 6 && val {
                    entries := _GetUnholdEntries()
                    txt := _GetKeyInfo(path[-1][1], path[-1][2] & ~1, entries, entries,
                        , true, , , layer)
                }
            }
        }
    } else if i_sc == "LV_chords" {
        res := GetColumnAtCursor(UI[i_sc], true)
        c := res[1]
        r := res[2]
        if r == 0 {
            prev_hwnd := 0
            ToolTip()
            return
        } else if r == -1 {
            fake_hwnd := "3" . c . r
            if prev_hwnd == fake_hwnd {
                return
            }
            by_cursor_pos := true
            prev_hwnd := fake_hwnd
            if c == 1 {
                txt := "Chord keys in string representation."
                    . "`nClick on the chord once to see these keys on the view."
            } else if c == 2 {
                txt := "Just chord action, as in all other cases."
            } else if c == 3 {
                txt := "Number of nested assignments for this chord.`n"
                    . "Chords (and gestures as well) can have any child assignments,`n"
                    . "including new chords or gesture triggers."
            }
        } else {
            fake_hwnd := "3" . r
            if prev_hwnd == fake_hwnd {
                return
            }
            by_cursor_pos := true
            prev_hwnd := fake_hwnd

            val := ChordToStr(obj.GetText(r, 1))
            res := gui_entries.ubase.GetBaseHoldMod(val, gui_mod_val, true)
            txt := _GetKeyInfo(val, gui_mod_val & ~1, res, gui_entries, true, , true)
        }

    } else if i_sc == "BtnEnableDragMode" {
        txt := "Enter drag-and-drop mode to quickly swap assignments on the current view."
    } else if i_sc == "BtnShowBuffer" {
        txt := "Show the buffer. Assignments replaced or left after pasting are stay stored here."
    } else if i_sc == "BtnShowCopyMenu" {
        txt := "Options for copying to the buffer.`n"
            . "Available only in layer editing mode.`n`nCurrent view – all visible assignments "
            . "with their nested,`nexcludes assignments under modifiers "
            . "(these are siblings, not children)"
        if path.Length {
            txt .= "Entire level – current tap assignment with all nested assignments across "
                . "modifiers.`nExtended level – current tap and hold assignments "
                . "with all their nested assignments."
        } else {
            txt .= "Entire level – all level assignments under all modifiers with their nested."
        }
    } else if i_sc == "BtnShowPasteMenu" {
        txt := "Several options for pasting buffer to the current view.`n`n"
            . "Append – add assignments from the buffer to the current view, without replacing."
            . "`nMerge – add assignments from the buffer to the current view, with replacement "
            . "of conflicting ones. Replaced assignments are saved to the buffer.`n"
            . "Replace – delete the entire view and paste the buffer. "
            . "The replaced view is saved to the buffer."
    } else if i_sc == "Langs" {
        txt := "List of layouts. Each layout on each layer can have its own assignments.`n"
            . "System layouts are named using their system description.`nLayouts found in layers "
            . "(but not installed on your system) – by language name with layout code.`n"
            . "'Global' contains layout-independent assignments.`nIf both global and "
            . "layout-specific assignments exist for the same event, the layout-specific "
            . "assignment takes priority.`nThe global assignment applies to all other layouts.`n`n"
        lang_cnt := []
        for code, lang in LANGS.map {
            if CONF.LayoutAliases.Has(code) {
                lang_cnt.Push([code, -1])
                continue
            }
            entries := {ubase: ROOTS[code], uhold: false, umod: false}
            for arr in path {
                entries := entries.ubase.GetBaseHoldMod(arr*)
            }
            cnt := _CountChild(
                "", 0, 0, entries.ubase.scancodes, entries.ubase.chords, entries.ubase.gestures
            )
            if cnt {
                lang_cnt.Push([lang, cnt])
            }
        }
        if lang_cnt.Length {
            txt .= "Number of assignments per layout for current view:`n"
            n := lang_cnt.Length
            loop n - 1 {
                i := A_Index
                loop n - i {
                    j := A_Index
                    if lang_cnt[j][2] < lang_cnt[j+1][2] {
                        tmp := lang_cnt[j]
                        lang_cnt[j] := lang_cnt[j+1]
                        lang_cnt[j+1] := tmp
                    }
                }
            }
            for arr in lang_cnt {
                if arr[2] == -1 {
                    txt .= LANGS[arr[1]] . " aliased with "
                        . LANGS[CONF.LayoutAliases[arr[1]]] . "`n"
                } else {
                    txt .= arr[1] . ": " . arr[2] . "`n"
                }
            }
        } else {
            txt .= "There are no assignments for the current view on any layout."
        }

    } else if i_sc == "Settings" {
        txt := "Settings"
    } else if i_sc == "BtnAddNewChord" {
        txt := "Add a new chord to the current view.`nAfter pressing, select keys by clicking in "
            . "the interface with clicks in the interface,`nor by pressing physical keys, then "
            . "save and set the assignment action.`nKeys used in the chord will get the "
            . "'part of chord' hold type`n(This may overwrite existing hold assignments!)"
    } else if i_sc == "BtnChangeSelectedChord" {
        txt := "Change selected chord.`nAfter pressing you will enter the key selection mode.`n"
            . "Change the chord keys, or just press Save to update its action."
    } else if i_sc == "BtnDeleteSelectedChord" {
        txt := "Delete selected chord.`nAll keys used in the chord will lose the hold "
            . "type 'part of chord',`nif they are not used in other chords."
    } else if i_sc == "BtnAddNewGesture" {
        if UI["LV_gestures"].GetText(0, 1) == "Has nested gestures" {
            txt := "Gestures can be added 'under' its drawing-trigger key.`n"
                . "Select the desired key first."
                . "`nGestures are independent of tap/hold branching, and technically form "
                . "a third branch,`nbut, conventionally, they are placed under tap events "
                . "as base part of the overall key event."
        } else {
            txt := "Add a new gesture under the current trigger key.`n`n"
                . "Gestures under each trigger are divided into 9 separate pools: "
                . "4 edges, 4 corners and 1 center pool.`n"
                . "Drawing mode starts when you press a key that has gestures assigned "
                . "for the pool at the current cursor position.`nThis does not override the "
                . "standard behavior of the key or its tap/hold assignments.`n"
                . "…if you press trigger key without drawing, the standard/default assignments "
                . "are performed`n…if you draw, gesture recognition is applied.`n`n"
                . "Note that if you assign gestures only to some pools, drawing mode will "
                . "not even start when the cursor is in other pools.`n"
                . "This can be used for partial assignments.`n`n"
                . "When adding a gesture, you can also set additional recognition options:"
                . "`nsize, direction, rotation, and start-point dependency."
                . "`nGesture color settings are defined by the 'parent' trigger key assignment."
                . "`nPool settings are global and configured in the general settings."
        }
    } else if i_sc == "BtnShowSelectedGesture" {
        txt := "Show the gesture drawing.`nDrawing starts from the center of the pool where the "
            . "gesture is defined,`nusing the color defined for the trigger key (if any)."
    } else if i_sc == "BtnChangeSelectedGesture" {
        txt := "Change the assignment for the selected gesture.`n"
            . "Optionally, you can redraw the gesture here."
    } else if i_sc == "BtnDeleteSelectedGesture" {
        txt := "Without notes. Just delete the selected gesture."
    } else if i_sc == "BtnBackToRoot" {
        txt := "End layout editing mode and return to assignments from all active layers."
    } else if i_sc == "BtnAddNewLayer" {
        txt := "Add a new empty layer."
    } else if i_sc == "BtnDeleteSelectedLayer" {
        txt := "Completely delete the selected layer. This action cannot be undone."
    } else if i_sc == "BtnEditSelectedLayer" {
        txt := "View and edit the layer [path/]name, description, tags and process rule."
    } else if i_sc == "BtnMoveUpSelectedLayer" {
        txt := "Raise the priority of the selected layer.`nIf different layers have "
            . "assignments for the same event,`nthe one from the highest-priority layer is used."
            . "`nThe 'layout-specific > global assignments' rule is secondary."
            . "`nLayer priority is applied first, then layout priority."
            . "`n`nRight-click to move the layer to the top priority."
    } else if i_sc == "BtnMoveDownSelectedLayer" {
        txt := "Lower the priority of the selected layer.`nIf different layers have "
            . "assignments for the same event,`nthe one from the highest-priority layer is used."
            . "`nThe 'layout-specific > global assignments' rule is secondary."
            . "`nLayer priority is applied first, then layout priority."
            . "`n`nRight-click to move the layer to the lowest priority."
    } else if i_sc == "BtnBase" {
        entries := _GetUnholdEntries()
        txt := _GetKeyInfo(path[-1][1], path[-1][2] & ~1, entries, entries,
            true, , path[-1][3], path[-1][4])
    } else if i_sc == "TextBase" {
        t := path[-1][3] ? "chord" : path[-1][4] ? "gesture" : "tap event"
        txt := "Assignment for the " . t . " on the current path.`nClick to change it."
    } else if i_sc == "BtnBaseClear" {
        t := path[-1][3] ? "chord" : path[-1][4] ? "gesture" : "tap"
        txt := "Delete this " . t . " assignment"
        if obj.Enabled == false && UI["TextBase"].Text !== "Base" {
            txt .= "`n`nThis is an automatically generated value for the working of the chains."
                . "`nIt cannot be deleted as long as there are child assignments."
        }
    } else if i_sc == "BtnBaseClearNest" {
        t := path[-1][3] ? "chord" : path[-1][4] ? "gesture" : "tap"
        txt := "Delete nested assignments under this " . t . " assignment"
        if path[-1][2] & 1 {
            txt .= "`n(The current view shows hold-side nested assignments!)"
        }
    } else if i_sc == "BtnHold" {
        if path[-1][3] || path[-1][4] {
            txt := "Chords and gestures don't have a hold event"
        } else {
            entries := _GetUnholdEntries()
            txt := _GetKeyInfo(path[-1][1], path[-1][2] & ~1, entries, entries, , true)
        }
    } else if i_sc == "TextHold" {
        if path[-1][3] || path[-1][4] {
            prev_hwnd := 0
            ToolTip()
            return
        }
        txt := "Assignment for the hold event on the current path.`nClick to change it."
    } else if i_sc == "BtnHoldClear" {
        if path[-1][3] || path[-1][4] {
            prev_hwnd := 0
            ToolTip()
            return
        }
        txt := "Delete this hold assignment"
        if obj.Enabled == false && UI["TextHold"].Text !== "Hold" {
            txt .= "`n`nThis is an automatically generated value for the working of the chains."
                . "`nIt cannot be deleted as long as there are child assignments."
        }
    } else if i_sc == "BtnHoldClearNest" {
        if path[-1][3] || path[-1][4] {
            prev_hwnd := 0
            ToolTip()
            return
        }
        txt := "Delete nested assignments under this hold assignment"
        if !(path[-1][2] & 1) {
            txt .= "`n(The current view shows tap-side nested assignments!)"
        }
    } else if UI && UI.extra_tags.Length && obj == UI.extra_tags[1] {
        txt := (obj.Text == "▴" ? "Hide" : "Show") . " all tags"
    } else if SubStr(i_sc, 1, 8) == "LayerTag" {
        tag := obj.Text
        if tag == "Active" {
            txt := "Toggle visibility of all active layers"
            cnt := ActiveLayers.Length
        } else if tag == "Inactive" {
            txt := "Toggle visibility of all inactive layers"
            cnt := AllLayers.Length - ActiveLayers.Length
        } else {
            if tag == "<untagged>" {
                txt := "Toggle visibility of all layers without tags"
            } else {
                txt := "Toggle visibility of layers with tag '" . tag . "'"
            }
            cnt := 0
            for layer in AllLayers.order {
                for tg in LayersMeta[layer]["tags"] {
                    if tg == tag {
                        cnt += 1
                        break
                    }
                }
            }
        }
        txt .= " (" . cnt . " layer" . (cnt == 1 ? "" : "s") . ")"
    } else if UI.buttons.Has(i_sc) {
        res := gui_entries.ubase.GetBaseHoldMod(i_sc, gui_mod_val, false, false, false, false)
        txt := _GetKeyInfo(i_sc, gui_mod_val, res, gui_entries)
    } else {  ; path
        if type(obj) == "Gui.Text" {
            if obj.Text == "|" {
                prev_hwnd := 0
                ToolTip()
                return
            }
            t := SubStr(obj.Text, -1)
            t := t == "➤" ? "tap"
                : t == "▲" ? "hold"
                    : t == "▼" ? "chord"
                        : t == "•" ? "gesture"
                            : 0
            if !t {
                if obj.Gui.Hwnd == UI.Hwnd {
                    txt := "Current active modifiers for the view and the next transition"
                }
            } else {
                md := Integer(SubStr(obj.Text, 1, -1) || 0)
                md := md ? DecomposeMods(md, true) : false
                txt := "Transition by the " . t . " event with"
                    . (md ? StrLen(md) > 1 ? (" modifiers " . md) : (" modifier " . md)
                        : "out modifiers")
            }
        } else {
            if obj.Text == root_text {
                txt := "Root level for all assignments on the current layout/language."
            } else {
                i := UI.path.Length
                while type(UI.path[i]) !== "Gui.Button" {
                    i -= 1
                }
                if UI.path[i].Text == obj.Text {
                    txt := "Last level of the current transition chain."
                    if i !== UI.path.Length {
                        txt .= "`nClick it to reset the active modifiers."
                    }
                } else {
                    txt := "One of the levels in the current transition chain.`nClick to go to it."
                }
            }
        }
    }

    if by_cursor_pos {
        ToolTip(txt)
    } else {
        prev_hwnd := ctrl_hwnd
        obj.GetPos(&x, &y, &w, &h)
        ToolTip(txt, x+w, y+h)
    }
}


_GetKeyInfo(sc, md, cur_entries, prev_entries,
    only_base:=false, only_hold:=false, is_chord:=false, is_gesture:=false, layer:="") {
    if !is_chord && !is_gesture {
        txt := "Key '" . _GetKeyName(sc, , true) . "'"
        if sc is Number {
            txt .= " (sc " . sc . ")"
        }
    } else if is_chord {
        txt := "Chord '" . sc . "'"
    } else if is_gesture {
        txt := ""
    }
    if !is_gesture {
        mods := DecomposeMods(md, true)
        if md {
            txt .= " with modifier " . mods
        } else {
            txt .= " without modifiers"
        }
    }
    b_node := only_hold ? false : _GetFirst(cur_entries.ubase, layer)
    h_node := only_base ? false : _GetFirst(cur_entries.uhold, layer)
    m_node := only_base ? false : _GetFirst(cur_entries.umod, layer)

    if !b_node && !h_node && !m_node {
        txt .= "`n`nUnassigned" . (only_base ? " tap event" : only_hold ? " hold event" : "")
    } else {
        if b_node {
            txt .= _GetNodeStrInfo(is_chord || is_gesture ? "Action" : "Tap",
                b_node, cur_entries.ubase, is_gesture, layer)
        }
        if h_node && h_node.down_type == TYPES.Modifier {
            cnt := _CountChild("", 0, 1 << h_node.down_val,
                prev_entries.ubase.scancodes,
                prev_entries.ubase.chords,
                prev_entries.ubase.gestures)
            cnt_combined := _CountChild("", 0, 1 << h_node.down_val,
                prev_entries.ubase.scancodes,
                prev_entries.ubase.chords,
                prev_entries.ubase.gestures, true)
            txt .= "`n`nHold: modifier " . h_node.down_val
                . " with " . cnt . " assignments under it"
            if cnt_combined > cnt {
                txt .= " (+" . cnt_combined - cnt . " from combined modifiers)"
            }
            if !layer_editing {
                act_cnt := 1
                inact_cnt := 0
                if layer {
                    layers := layer
                } else {
                    act_layers := ""
                    inact_layers := ""
                    act_cnt := 0
                    t_unode := cur_entries.uhold
                    for l in t_unode.layers.order {
                        t_node := _GetFirst(t_unode, l)
                        if t_node.down_type == TYPES.Default || EqualNodes(t_node, h_node) {
                            if ActiveLayers.Has(l) {
                                act_layers .= l . ", "
                                act_cnt += 1
                            } else {
                                inact_layers .= l . ", "
                                inact_cnt += 1
                            }
                        }
                    }
                    act_layers := SubStr(act_layers, 1, -2)
                    inact_layers := SubStr(inact_layers, 1, -2)
                }
                if !buffer_view {
                    txt .= "`nAssigned on the active layer" . (act_cnt == 1 ? ": " : "s: ")
                        . act_layers
                    if inact_cnt {
                        txt .= "`n… and on the inactive layer" . (inact_cnt == 1 ? ": " : "s: ")
                            . inact_layers
                    }
                }
            }
            txt .= _GetNodeExtraInfo(h_node) . "`n"
        } else if h_node {
            txt .= _GetNodeStrInfo("Hold", h_node, cur_entries.uhold, , layer)
        }
    }

    if !m_node {
        l := selected_layer ? selected_layer : buffer_view ? "buffer" : false
        mp := l ? GetLayerScancodes(prev_entries.ubase, l)
            : _GetScancodes(prev_entries.ubase, gui_proc_ctx)
        other_mods := mp.Get(sc, Map()).Clone()
        try other_mods.Delete(md)
        try other_mods.Delete(md+1)
        if other_mods.Count {
            seen := Map()
            t := ""
            b := false
            for md, val in other_mods {
                if !seen.Has(md & ~1) {
                    if !layer_editing || val.layers.map.Has(selected_layer) {
                        mods := DecomposeMods(md, true)
                        if !mods {
                            b := true
                        } else {
                            t .= " " . mods . ","
                        }
                    }
                }
                seen[md & ~1] := true
            }
            if b && StrLen(t) {
                txt .= "`n`nAlso has other assignments without modifiers and with modifiers"
                . SubStr(t, 1, -1)
            } else if b {
                txt .= "`n`nAlso has other assignment without modifiers"
            } else if t {
                plural := (StrLen(t) == 3 ? "" : "s")
                txt .= "`n`nAlso has other assignment" . plural . " with modifier" . plural
                . SubStr(t, 1, -1)
            }
        }
    }
    return Trim(txt, "`n")
}


_GetNodeStrInfo(base, node, unode, is_gesture:=false, layer:="") {
    res := "`n`n" . base . ": " . _SwitchByActionType(node.down_type, node.down_val)
    if !layer_editing {
        if !layer {
            act_cnt := 1
            inact_cnt := 0
            act_layers := ""
            inact_layers := ""
            act_cnt := 0
            for l in unode.layers.order {
                t_node := _GetFirst(unode, l)
                if t_node.down_type == TYPES.Default || EqualNodes(t_node, node) {
                    if ActiveLayers.Has(l) {
                        act_layers .= l . ", "
                        act_cnt += 1
                    } else {
                        inact_layers .= l . ", "
                        inact_cnt += 1
                    }
                }
            }
            act_layers := SubStr(act_layers, 1, -2)
            inact_layers := SubStr(inact_layers, 1, -2)
            if !buffer_view {
                res .= "`nAssigned on the active layer" . (act_cnt == 1 ? ": " : "s: ")
                    . act_layers
                if inact_cnt {
                    res .= "`n… and on the inactive layer" . (inact_cnt == 1 ? ": " : "s: ")
                        . inact_layers
                }
            }
        }
    }
    res .= _GetNodeExtraInfo(node, is_gesture)
    scs_cnt := _CountChild(layer, 0, 0, unode.scancodes, Map(), Map())
    chs_cnt := _CountChild(layer, 0, 0, Map(), unode.chords, Map())
    gst_cnt := _CountChild(layer, 0, 0, Map(), Map(), unode.gestures)
    if scs_cnt || chs_cnt || gst_cnt {
        t := (scs_cnt ? (scs_cnt . " scancode" . (scs_cnt > 1 ? "s" : "") . "; ") : "")
            . (chs_cnt ? (chs_cnt . " chord" . (chs_cnt > 1 ? "s" : "") . "; ") : "")
            . (gst_cnt ? (gst_cnt . " gesture" . (gst_cnt > 1 ? "s" : "") . "; ") : "")
        res .= "`n`nHas " . SubStr(t, 1, -2) . " nested on the next level"
    }
    return res
}


_GetNodeExtraInfo(node, is_gesture:=false) {
    res := ""
    if node.gui_shortname && node.gui_shortname !== node.down_val {
        res .= "`nNamed as '" . node.gui_shortname . "'"
    }
    if node.up_type !== TYPES.Disabled {
        res .= "`nAdditional action on release: " . _SwitchByActionType(node.up_type, node.up_val)
    }
    if node.is_instant && node.is_irrevocable {
        res .= "`nInstant and irrevocable execution is indicated"
    } else if node.is_instant {
        res .= "`nInstant execution is indicated"
    } else if node.is_irrevocable {
        res .= "`nIrrevocable execution is indicated"
    }
    if node.custom_lp_time {
        res .= "`nHas a custom hold threshold – " . node.custom_lp_time
    }
    if node.custom_nk_time {
        res .= "`nHas a custom child-event timeout – " . node.custom_nk_time
    }
    if node.child_behavior !== 4 {
        res .= "`nChild behavior is changed to '" . [
            "Backsearch", "Send current + backsearch",
            "To root", "Send current + to root", "Ignore"
        ][node.child_behavior] . "'"
    }
    if node.gesture_opts {
        vals := StrSplit(node.gesture_opts, ";")
        if is_gesture {
            res .= "`n`n" . ["Top-left corner", "Top edge", "Top-right corner", "Left edge",
                "Center", "Right edge", "Bottom-left corner", "Bottom edge",
                "Bottom-right corner"][Integer(vals[1])] . " pool"
            if vals[1] != 5 {
                res .= " (edge size by conf – " . CONF.edge_size.v . "px)"
            }
            sh := 0
            if vals[1] = 2 || vals[1] = 4 || vals[1] = 6 || vals[1] = 7 {
                sh := 3
                if CONF.edge_gestures.v == 1 || CONF.edge_gestures.v == 3 {
                    res .= "`nWarning: edge gestures are disabled in the global settings."
                }
            } else if vals[1] = 1 || vals[1] = 3 || vals[1] = 7 || vals[1] = 9 {
                sh := 6
                if CONF.edge_gestures.v == 1 || CONF.edge_gestures.v == 2 {
                    res .= "`nWarning: corner gestures are disabled in the global settings."
                }
            }
            rot := ["disabled", "noise reduction", "fully rotation-invariance"]
            if vals[2] = 0 {
                res .= "`n`nRotation: " . rot[CONF.gest_rotate.v] . " (by global conf)"
            } else {
                res .= "`n`n> Rotation: " . rot[Integer(vals[2]) + 1]
            }
            if vals[3] {
                res .= "`n> Scale impact: " . vals[3]
            } else {
                res .= "`nScale impact: " . CONF.scale_impact.v . " (by global conf)"
            }
            res .= "`n" . (vals[4] ? "> " : "") . "Bidirectional matching: "
                . ["disabled", "enabled"][vals[4] ? (Integer(vals[4]) + 1) : 1]
            res .= "`n" . (vals[5] ? "> " : "") . "Closed figure start-point invariance: "
                . ["disabled", "enabled"][vals[5] ? (Integer(vals[5]) + 1) : 1]
            parent_opts := StrSplit(_GetFirst(_GetUnholdEntries().ubase).gesture_opts, ";")
            colors := parent_opts.Has(2+sh) ? parent_opts[2+sh] : 0
            grad_len := parent_opts.Has(3+sh) ? parent_opts[3+sh] : 0
            grad_loop := parent_opts.Has(4+sh) ? parent_opts[4+sh] : 0
            if colors || grad_len || grad_loop {
                res .= "`nCustom options from parent trigger key:"
                if colors !== "" {
                    res .= "`n   Color " . colors
                }
                if grad_loop !== "" && grad_loop != CONF.grad_loop[sh/3+1].v {
                    res .= "`n   Gradient cycling is " . ["disabled", "enabled"][grad_loop+1]
                }
                if grad_len !== "" && grad_len != CONF.grad_loop[sh/3+1].v {
                    res .= "`n   Gradient cycle length " . grad_len
                }
            }
        } else {
            res .= "`n`nCustom for nested gestures:"
            p := vals.Get(1, CONF.gest_live_hint.v + 2)
            if p && p !== CONF.gest_live_hint.v + 2 {
                res .= "`nLive hints position – " . ["top", "center", "bottom", "disabled"][p-1]
            }
            loop 3 {
                i := (A_Index - 1) * 3
                colors := vals.Has(2+i) ? vals[2+i] : 0
                grad_len := vals.Has(3+i) ? vals[3+i] : 0
                grad_loop := vals.Has(4+i) ? vals[4+i] : 0
                if colors || grad_len || grad_loop {
                    res .= ["`nCenter pool:", "`nEdges:", "`nCorners:"][A_Index]
                    if colors !== "" {
                        res .= "`n   Color " . colors
                    }
                    if grad_loop !== "" && grad_loop != CONF.grad_loop[A_Index].v {
                        res .= "`n   Gradient cycling is " . ["disabled", "enabled"][grad_loop+1]
                    }
                    if grad_len !== "" && grad_len != CONF.grad_len[A_Index].v {
                        res .= "`n   Gradient cycle length " . grad_len
                    }
                }
            }
        }
    }
    return res
}


_SwitchByActionType(_type, _val) {
    switch _type {
        case TYPES.Disabled:
            return "{Disabled}"
        case TYPES.Default:
            return "{Default}"
        case TYPES.Text:
            return (StrLen(_val) == 1 ? "symbol '" : "text '")
                . CheckDiacr(_val) . "'"
        case TYPES.KeySimulation:
            return "key simulation '" . _val . "'"
        case TYPES.Function:
            return "execute function '" . _val . "'"
        case TYPES.Chord:
            return "part of chord"
    }
}