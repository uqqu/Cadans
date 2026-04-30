form := false
func_form := false
init_drawing := false
from_prev := false
gest_as_base := false
child_behavior_opts := [
    "Backsearch", "Send current + backsearch", "To root", "Send current + to root", "Ignore"
]


OpenForm(save_type, _path:=false, _mod_val:=false, _entries:=false, *) {
    ; 0 – base value, 1 – hold value, 2 – chord, 3 – gesture
    global form, func_form, from_prev, gest_as_base

    if _path is Array {
        _current_path := _path
        _gui_mod_val := _mod_val
        _gui_entries := _entries
    } else {  ; use global
        _current_path := current_path.Clone()
        _gui_mod_val := gui_mod_val
        _gui_entries := gui_entries.Clone()
    }

    if save_type == 3 && _current_path.Length && _current_path[-1][2] & 1 {
        _gui_entries := _GetUnholdEntries()
        p := _current_path[-1]
        _current_path.Length -= 1
        _current_path.Push([p[1], p[2] & ~1, p[3], p[4]])
    }

    try form.Destroy()
    try func_form.Destroy()
    func_form := false

    form := Gui("-SysMenu", "Set assignment")
    form.OnEvent("Close", CloseForm)
    form.OnEvent("Escape", CloseForm)

    chord_as_base := false
    gest_as_base := false
    paired := false
    ; check and correct if it "base" from chord/gesture
    if !save_type && _current_path.Length && (_current_path[-1][3] || _current_path[-1][4]) {
        entries := {ubase: ROOTS[gui_lang], uhold: false, umod: false}
        path := _current_path.Clone()
        path.Length -= 1

        for arr in path {
            entries := entries.ubase.GetBaseHoldMod(arr*)
        }

        if _current_path[-1][3] {
            chord_as_base := true
            save_type := 2
            unode := entries.ubase.GetBaseHoldMod(selected_chord, _gui_mod_val, true).ubase
        } else {
            gest_as_base := true
            save_type := 3
            unode := entries.ubase.GetBaseHoldMod(selected_gesture, _gui_mod_val, false, true).ubase
        }
    } else {
        unode := save_type == 1 ? _gui_entries.uhold : save_type == 2
            ? _gui_entries.ubase.GetBaseHoldMod(selected_chord, _gui_mod_val, true).ubase
            : save_type == 3
                ? _gui_entries.ubase.GetBaseHoldMod(selected_gesture, _gui_mod_val, false, true)
                    .ubase
                : _gui_entries.ubase
        paired := save_type == 1 ? _gui_entries.ubase : false
    }

    layers := layer_editing ? [selected_layer] : GetLayerList()
    prior_layer := false
    if unode {
        for layer in layers {
            if unode.layers.map.Has(layer) && unode.layers[layer][0] {
                prior_layer := layer
                break
            }
        }
    }
    curr_val := prior_layer ? unode.layers[prior_layer][0] : false

    if !layer_editing {
        form.Add("Text", "x10 y+10 w60", "Layer:")
        form.Add("DropDownList", "x+5 yp-2 w235 vLayersDDL Choose1", layers)
        form["LayersDDL"].OnEvent("Change",
            ChangeFormPlaceholder.Bind(unode, paired, layers, save_type, 0, 1, 0)
        )
        try form["LayersDDL"].Text := prior_layer
    }

    ;LMB/RMB
    if save_type < 2 && CheckLRMB(_current_path) {
        form.Add("Text", "x10 y+10 w150 vLHText", "Live hint position:")
        form.Add("DDL", "x+0 yp-3 w150 Choose1 vLiveHint",
            ["Follow global setting", "Top", "Center", "Bottom", "Disabled"])
        form.color_buttons := [
            form.Add("Button", "x10 y+10 w100 vColorGeneral", "General"),
            form.Add("Button", "x+0 yp0 w100 vColorEdges", "Edges"),
            form.Add("Button", "x+0 yp0 w100 vColorCorners", "Corners"),
        ]
        for i, btn in form.color_buttons {
            btn.OnEvent("Click", _FormToggleColors.Bind(i))
        }
        form["ColorGeneral"].Enabled := false

        form["ColorGeneral"].GetPos(, &cy, , &ch)

        form.colors := [[], [], []]
        for i, name in ["", "Edges", "Corners"] {
            form.colors[i].Push(
                form.Add("Text", "x10 y" . (8 + cy + ch) . " w150 h20", "Gesture colors:"),
                form.Add("Edit", "Center x+0 yp0 w130 h20 vColorInp" . name),
                form.Add("Button", "x+0 yp+0 w20 h20 vColor" . name . "Pick", "🎨"),
                form.Add("Text", "x10 y+5 w150 h20", "Gradient cycle length:"),
                form.Add("Edit", "Center x+0 yp0 w150 h20 vGradLenInp" . name),
                form.Add("CheckBox", "x10 y+5 w300 vGradCycle" . name, "Gradient cycling"),
            )
            SendMessage(0x1501, true, StrPtr(CONF.gest_colors[i].v), form["ColorInp" . name].Hwnd)
            SendMessage(0x1501, true,
                StrPtr("" . CONF.grad_len[i].v), form["GradLenInp" . name].Hwnd)
            form["Color" . name . "Pick"].OnEvent(
                "Click", PasteColorFromPick.Bind(form.Hwnd, form["ColorInp" . name], true)
            )
            if i !== 1 {
                ToggleVisibility(false, form.colors[i])
            }
        }
        form.Add("Button", "x10 y+10 w100 h20 vCancel", "❌ Cancel")
        form.Add("Button", "x+0 yp+0 w100 h20 Default vSave", "💾 Save")
        form.Add("Button", "x+0 yp+0 w100 h20 vSaveWithReturn", "↩ Save and back")
        form.SetFont("Italic cGray")
        form.Add("Text", "x10 y+13 w300 Center",
            "LMB and RMB from root level without mods`ncan only be configured as gesture triggers")
        form.Add("Edit", "x-1000 y-1000 w0 h0 vValInp")
        form.Add("Edit", "x-1000 y-1000 w0 h0 vValText")
        form.Add("Edit", "x-1000 y-1000 w0 h0 vUpValInp")
        form.Add("Edit", "x-1000 y-1000 w0 h0 vUpValText")
        form.Add("Edit", "x-1000 y-1000 w0 h0 vShortname")
        form.Add("Edit", "x-1000 y-1000 w0 h0 vCustomLP")
        form.Add("Edit", "x-1000 y-1000 w0 h0 vCustomNK")
        form.Add("DropDownList", "x-1000 y-1000 w0 h0 vTypeDDL Choose1", ["Default"])
        form.Add("DropDownList", "x-1000 y-1000 w0 h0 vUpTypeDDL Choose1", ["Disabled"])
        form.Add("DropDownList", "x-1000 y-1000 w0 h0 vChildBehaviorDDL Choose4", child_behavior_opts)
        form.Add("CheckBox", "x-1000 y-1000 w0 h0 vCBInstant")
        form.Add("CheckBox", "x-1000 y-1000 w0 h0 vCBIrrevocable")

        form["Cancel"].OnEvent("Click", CloseForm)
        form["Save"].OnEvent("Click", WriteValue.Bind(save_type, false, false))
        form["SaveWithReturn"].OnEvent("Click",
            (*) => (WriteValue(save_type, false, false), ChangePath(current_path.Length - 1)))
        form.Show("w320")
        ChangeFormPlaceholder(unode, paired, layers, 1, , , 1)
        return
    }

    ; action types for different events
    type_list := [
        ["Disabled", "Default", "Text", "KeySimulation", "Function"],  ; base / hold under mods
        ["Disabled", "Default", "Text", "KeySimulation", "Function", "Modifier"],  ; hold
        ["Disabled", "Text", "KeySimulation", "Function"],  ; chords
        ["Text", "KeySimulation", "Function"]  ; gestures
    ][save_type == 1 && _current_path[-1][2] ? 1 : save_type + 1]

    form.Add("Text", "x10 y+10 w60", "Action type:")
    form.Add("DropDownList", "x+5 yp-2 w235 vTypeDDL", type_list)
    form.Add("Text", "x10 y+10 w60 vValText", "Value:")
    form.Add("Edit", "x+5 yp-2 w235 vValInp")
    form.color_buttons := []
    form.colors := [[]]

    if save_type < 2 {
        form.Add("Text", "x10 y+10 w150", "Tap🡒hold threshold (ms):")
        form.Add("Edit", "x+0 yp-3 w150 vCustomLP Number +Center")
        SendMessage(0x1501, true, StrPtr("Empty – follow global"), form["CustomLP"].Hwnd)
    } else if save_type == 2 {
        form.Add("Text", "x10 y+10 w150", "Hold confirmation (ms):")
        form.Add("Edit", "x+0 yp-3 w150 vCustomLP Number +Center")
        SendMessage(0x1501, true, StrPtr("Empty – instant triggering"), form["CustomLP"].Hwnd)
    }

    ; gesture
    if save_type == 3 {
        form.Add("Button", "x10 y+10 w280 vSetGesture", "Set gesture pattern")
            .OnEvent("Click", SetGesture)
        form.Add("Button", "x+0 yp+0 w20 vShowGesture", "🙈")
            .OnEvent("Click", ShowGesture.Bind(_gui_entries))

        form.Add("Text", "x10 y+7 w150", "Scale impact:")
        form.Add("Edit", "x+0 yp-3 w150 vScaling +Center")
        SendMessage(0x1501, true, StrPtr("0–0.99 (0 – size-independent)"), form["Scaling"].Hwnd)
        form.Add("Text", "x10 y+7 w150", "Rotate:")
        form.Add("DDL", "x+0 yp-3 w150 Choose1 vRotate", 
            ["Follow global setting", "None", "Reduce orientation noise", "Rotation invariance"])
        form.Add("CheckBox", "x10 y+7 w300 vDirection", "Direction invariance")
        form.Add("CheckBox", "x10 y+7 w300 vPhase",
            "Any start point (for closed figures only)").Enabled := false
        if !selected_gesture {
            form["ShowGesture"].Enabled := false
        } else {
            form["ShowGesture"].Text := "👀"
        }
    }
    if save_type > 1 {
        form.Add("Button", "x10 y+10 w300 vBtnChainOptions", "In-chain behavior ▾")
            .OnEvent("Click", ShowChainOptions)
        form["BtnChainOptions"].GetPos(, &y, , &h)
        _AddChainOptions(y)

    } else {
        form.Add("Button", "x10 y+10 w100 vInChainToggle", "In-chain behavior")
            .OnEvent("Click", ShowHideButtons)
        form.Add("Button", "x+0 yp0 w100 vUpToggle", "Add. key-up action")
            .OnEvent("Click", ShowHideButtons)
        form.Add("Button", "x+0 yp0 w100 vColorToggle", "Gesture overlay")
            .OnEvent("Click", ShowHideButtons)
        form["InChainToggle"].GetPos(, &y, , &h)
        _AddChainOptions(y+h)
        form.chain_options.RemoveAt(1)

        form.up_fields := [
            form.Add("Text", "x10 y" . (13 + y + h) . " w60", "Action type:"),
            form.Add("DropDownList", "x+5 yp-2 w235 vUpTypeDDL", type_list),
            form.Add("Text", "x10 y+10 w60 vUpValText", "Value:"),
            form.Add("Edit", "x+5 yp-2 w235 vUpValInp")
        ]
        ToggleVisibility(0, form.up_fields)


        form.Add("Text", "x10 y" . (13 + y + h) . " w150 vLHText", "Live hint position:")
            .Visible := false
        form.Add("DDL", "x+0 yp-3 w150 Choose1 vLiveHint",
            ["Follow global setting", "Top", "Center", "Bottom", "Disabled"]).Visible := false
        form.color_buttons := [
            form.Add("Button", "x10 y+10 w100 vColorGeneral", "General"),
            form.Add("Button", "x+0 yp0 w100 vColorEdges", "Edges"),
            form.Add("Button", "x+0 yp0 w100 vColorCorners", "Corners"),
        ]
        for i, btn in form.color_buttons {
            btn.OnEvent("Click", _FormToggleColors.Bind(i))
            btn.Visible := false
        }
        form["ColorGeneral"].Enabled := false

        form["ColorGeneral"].GetPos(, &cy, , &ch)

        form.colors := [[], [], []]
        for i, name in ["", "Edges", "Corners"] {
            form.colors[i].Push(
                form.Add("Text", "x10 y" . (8 + cy + ch) . " w150 h20", "Gesture colors:"),
                form.Add("Edit", "Center x+0 yp0 w130 h20 vColorInp" . name),
                form.Add("Button", "x+0 yp+0 w20 h20 vColor" . name . "Pick", "🎨"),
                form.Add("Text", "x10 y+5 w150 h20", "Gradient cycle length:"),
                form.Add("Edit", "Center x+0 yp0 w150 h20 vGradLenInp" . name),
                form.Add("CheckBox", "x10 y+5 w300 vGradCycle" . name, "Gradient cycling"),
            )
            SendMessage(0x1501, true, StrPtr(CONF.gest_colors[i].v), form["ColorInp" . name].Hwnd)
            SendMessage(0x1501, true,
                StrPtr("" . CONF.grad_len[i].v), form["GradLenInp" . name].Hwnd)
            form["Color" . name . "Pick"].OnEvent(
                "Click", PasteColorFromPick.Bind(form.Hwnd, form["ColorInp" . name], true)
            )
            ToggleVisibility(false, form.colors[i])
        }

        form["UpTypeDDL"]
            .OnEvent("Change", ChangeFormPlaceholder.Bind(unode, false, layers, save_type, 1, 0, 0))
        form["UpTypeDDL"].Text := curr_val ? TYPES_R[curr_val.up_type] : "Disabled"
    }
    form.bottom := []
    if save_type !== 2 {
        form.bottom.Push(form.Add("Text", "x10 y" . (8 + y + h) . " w60", "Shortname:"))
        form.bottom.Push(form.Add("Edit", "x+5 yp-2 w235 vShortname"))
        form["Shortname"].GetPos(, &y, , &h)
    }

    ; control
    fn := (save_type == 2
            ? (chord_as_base ? WriteChord.Bind(_current_path[-1][1]) : WriteChord.Bind(0))
            : save_type == 3 ? (gest_as_base ? WriteGesture.Bind(_current_path[-1][1], _gui_entries, _current_path)
                : WriteGesture.Bind(0, _gui_entries, _current_path)) : WriteValue.Bind(save_type, false, paired))
    form.Add("Button", "x10 y" . (8 + y + h) . " w100 h20 vCancel", "❌ Cancel").OnEvent("Click", CloseForm)
    form.Add("Button", "x+0 yp+0 w100 h20 Default vSave", "💾 Save").OnEvent("Click", fn)
    form.Add("Button", "x+0 yp+0 w100 h20 Default vSaveWithReturn", "↩ Save and back")
        .OnEvent("Click", (*) => (fn(), ChangePath(current_path.Length - 1)))
    form.bottom.Push(form["Cancel"], form["Save"], form["SaveWithReturn"])
    if save_type == 3 {
        if !selected_gesture {
            ToggleEnabled(0, form["Save"], form["SaveWithReturn"])
        } else {
            from_prev := true
        }
    }

    form["TypeDDL"].OnEvent("Change",
        ChangeFormPlaceholder.Bind(unode, false, layers, save_type, 0, 0, 0))
    form["TypeDDL"].Text := curr_val ? TYPES_R[curr_val.down_type] : "Text"
    form["Save"].GetPos(, &y, , &h)
    form.Show("w320 h" . y+h+10)
    ChangeFormPlaceholder(unode, paired, layers, save_type, , , 1)
    if curr_val {
        if curr_val.custom_nk_time || curr_val.child_behavior !== 4
            || curr_val.is_instant || curr_val.is_irrevocable {
            if save_type > 1 {
                ShowChainOptions()
            } else {
                ShowHideButtons(form["InChainToggle"])
            }
        } else if curr_val.up_type !== TYPES.Disabled {
            ShowHideButtons(form["UpToggle"])
        } else if save_type < 2 && curr_val.gesture_opts {
            ShowHideButtons(form["ColorToggle"])
        }
    }
}


_AddChainOptions(y) {
    form.chain_options := [
        form.Add("Text", "x10 y" . y . " w300 h1 0x10"),
        form.Add("Text", "x10 y+10 w150", "Next event timeout (ms):"),
        form.Add("Edit", "x+0 yp-3 w150 vCustomNK Number +Center"),

        form.Add("Text", "x10 y+10 w150", "Unassigned child behavior:"),
        form.Add("DropDownList", "x+0 yp-2 w150 vChildBehaviorDDL Choose4", child_behavior_opts),

        form.Add("Button", "x10 y+10 w15 h15 vHelpInstant", "?"),
        form.Add("CheckBox", "x+3 yp+1 w130 vCBInstant", "Instant"),

        form.Add("Button", "x160 yp-1 w15 h15 vHelpIrrevocable", "?"),
        form.Add("CheckBox", "x+3 yp+1 w130 vCBIrrevocable", "Irrevocable")
    ]
    form["HelpInstant"].OnEvent("Click", (*) => MsgBox(
        "The action will be performed immediately upon reaching the assignment.`n"
        . "It doesn't break the chain of transitions, and you can go deeper,`n"
        . "just as without this option.`nInterrupting at this assignment or treating as "
        . "the final node will not trigger a repeat action.", "Help"))
    form["HelpIrrevocable"].OnEvent("Click", (*) => MsgBox(
        "Interrupting the chain at this assignment or executing it as the final node"
        . "`nwill not return to the root."
        . "`nYou will remain at your current transition level until the next event."
        , "Help"))

    SendMessage(0x1501, true, StrPtr("Empty – follow global"), form["CustomNK"].Hwnd)
    ToggleVisibility(0, form.chain_options)
}


ShowChainOptions(*) {
    ToggleVisibility(2, form.chain_options, form["BtnChainOptions"])
    for elem in form.bottom {
        elem.GetPos(, &y)
        elem.Move(, y + 65)
    }
    form.Show("AutoSize")
}


ShowHideButtons(ctrl, *) {
    ToggleEnabled(1, form["InChainToggle"], form["UpToggle"])
    try form["ColorToggle"].Enabled := true
    ctrl.Enabled := false
    if ctrl.Name == "InChainToggle" {
        ToggleVisibility(0, form["LiveHint"], form["LHText"], form.color_buttons, form.colors*)
        ToggleVisibility(0, form.up_fields)
        ToggleVisibility(1, form.chain_options)
        form["CBIrrevocable"].GetPos(, &sh)
    } else if ctrl.Name == "UpToggle" {
        ToggleVisibility(0, form["LiveHint"], form["LHText"], form.color_buttons, form.colors*)
        ToggleVisibility(1, form.up_fields)
        if form["UpTypeDDL"].Value < 3 {
            ToggleVisibility(0, form["UpValInp"], form["UpValText"])
        }
        ToggleVisibility(0, form.chain_options)
        form["UpValInp"].GetPos(, &sh)
    } else {
        ToggleVisibility(1, form["LiveHint"], form["LHText"], form.color_buttons)
        ToggleVisibility(0, form.up_fields)
        ToggleVisibility(0, form.chain_options)
        for i, btn in form.color_buttons {
            if !btn.Enabled {
                for elem in form.colors[i] {
                    elem.Visible := true
                }
                break
            }
        }
        form["GradCycle"].GetPos(, &sh)
    }
    sh += 30

    b := true
    for elem in form.bottom {
        if b {
            b := false
            elem.GetPos(, &y)
            elem.Move(, sh)
            sh := y - sh
        } else {
            elem.GetPos(, &y)
            elem.Move(, y - sh)
        }
        elem.Text := elem.Text
    }

    form.Show("AutoSize")
}


_FormToggleColors(trg, *) {
    for i, arr in form.colors {
        ToggleVisibility(i == trg, arr)
        form.color_buttons[i].Enabled := i !== trg
    }
}


SetGesture(*) {
    global init_drawing, from_prev

    from_prev := false
    form["SetGesture"].Text := "Draw a gesture while holding RMB"
    init_drawing := true
    ToggleEnabled(false, form["Phase"], form["Save"], form["SaveWithReturn"], form["ShowGesture"])
    form["ShowGesture"].Text := "🙈"
    form["Phase"].Value := 0
}


ShowGesture(entries, *) {
    try {
        scal := form["Scaling"].Text == "" ? CONF.scale_impact.v : Float(form["Scaling"].Text)
    } catch {
        scal := 0
    }
    rot := form["Rotate"].Value == 1 ? CONF.gest_rotate.v : (form["Rotate"].Value - 1)
    dirs := form["Direction"].Value
    phase := form["Phase"].Value

    par := false
    if current_path[-1][-1] {
        par := {ubase: ROOTS[gui_lang]}
        for arr in current_path {
            if A_Index == current_path.Length {
                break
            } else if (A_Index - 1) == current_path.Length {
                par := par.ubase.GetBaseHoldMod(arr[1], arr[2] & ~1, arr[3], arr[4])
            } else {
                par := par.ubase.GetBaseHoldMod(arr*)
            }
        }
    }

    if from_prev {
        if gest_as_base {
            gest := _GetFirst(entries.ubase)
        } else {
            gest := _GetFirst(
                entries.ubase.GetBaseHoldMod(selected_gesture, gui_mod_val, false, true).ubase
            )
        }
        SetOverlayOpts(_GetFirst(par ? par.ubase : entries.ubase).gesture_opts, gest.opts.pool)

        if gest.opts.dirs = dirs && gest.opts.closed = phase {
            _gest := gest
        } else {
            _gest := {
                vec: gest.vec,
                opts: {
                    pool: gest.opts.pool,
                    scaling: Format("{:0.2f}", scal),
                    dirs: dirs,
                    closed: phase
                }
            }
        }
        DrawExisting(_gest)
        return
    }

    default_opts:={
        pool: 5, rotate: CONF.gest_rotate.v, scaling: CONF.scale_impact.v,
        dirs: 0, closed: 0, len: 1
    }

    gest_str := GestureToStr(points, rot, scal, dirs, phase)
    node_obj := {opts: {}, gesture_opts: gest_str[2]}
    vals := StrSplit(node_obj.gesture_opts, ";")
    for i, name in ["pool", "rotate", "scaling", "dirs", "closed", "len"] {
        try {
            node_obj.opts.%name% := name == "scaling" ? Float(vals[i]) : Integer(vals[i])
        } catch {
            node_obj.opts.%name% := default_opts.%name%
        }
    }

    SetOverlayOpts(_GetFirst(par ? par.ubase : entries.ubase).gesture_opts, node_obj.opts.pool)
    vals := StrSplit(gest_str[1], " ")
    node_obj.vec := []
    for v in vals {
        if A_Index == 1 && StrLen(v) == 1 {
            continue
        }
        if v !== "" {
            node_obj.vec.Push(Float(v))
        }
    }
    DrawExisting(node_obj)
}


ChangeFormPlaceholder(unode, paired, layers, save_type:=0, is_up:=0, is_layer_editing:=0, fresh:=0, *) {
    static placeholders:=[
        "Disabled",
        "Default key value",
        "Value (plain text)",
        "Key simulation in ahk syntax, e.g. '+{SC010}', '{Volume_Up}'",
        "Function name",
        "Modifier number"
    ]
    static prev_layer:=""

    if fresh {
        prev_layer := ""
    }

    layer := layers.Length > 1 ? form["LayersDDL"].Text : layers[1]
    name := [" value ", " value ", " chord ", " gesture "][save_type + 1]

    is_type := false
    try is_type := form["TypeDDL"]
    if !is_type {  ; sysmod
        form["ValInp"].Text := ""
        form["Shortname"].Text := ""
        try form["ValInp"].Text := unode.layers[layer][0].down_val
        try form["Shortname"].Text := unode.layers[layer][0].gui_shortname
        form["ValInp"].Focus()
        return
    }

    if !is_up && unode && unode.layers.Length && unode.layers.Has(layer) && unode.layers[layer][0]
        && (prev_layer !== layer || unode.layers[layer][0].down_type == form["TypeDDL"].Value) {

        val := unode.layers[layer][0]

        if is_layer_editing {
            form["TypeDDL"].Text := TYPES_R[val.down_type]
        }
        if TYPES.%form["TypeDDL"].Text% == val.down_type {
            form["ValInp"].Text := val.down_val

            if val.HasOwnProp("opts") {  ; gesture
                form["Scaling"].Text := Round(val.opts.scaling, 2)
                form["Rotate"].Value := val.opts.rotate + 2
                form["Direction"].Value := val.opts.dirs
                if val.opts.closed {
                    form["Phase"].Value := val.opts.closed
                    form["Phase"].Enabled := true
                }
            } else if val.gesture_opts {
                opts := StrSplit(val.gesture_opts, ";")
                for i, name in [
                    "LiveHint", "ColorInp", "GradLenInp", "GradCycle",
                    "ColorInpEdges", "GradLenInpEdges", "GradCycleEdges",
                    "ColorInpCorners", "GradLenInpCorners", "GradCycleCorners",
                ] {
                    if i > opts.Length {
                        break
                    }
                    if !opts[i] {
                        continue
                    }
                    form[name].Value := opts[i]
                }
            }

            try form["CustomLP"].Text := val.custom_lp_time || ""
            try form["CustomNK"].Text := val.custom_nk_time || ""

            if save_type !== 2 {
                form["Shortname"].Text := val.gui_shortname
            }
            form["ChildBehaviorDDL"].Value := val.child_behavior

            form["CBIrrevocable"].Value := val.is_irrevocable
            form["CBInstant"].Value := val.is_instant

            try {
                if is_layer_editing {
                    form["UpTypeDDL"].Text := TYPES_R[val.up_type]
                }
                form["UpValInp"].Text := val.up_val
                form["UpTypeDDL"].Text == "Function" ? SetUpFunction(1) : 0
                if form["UpTypeDDL"].Text == "Default" || form["UpTypeDDL"].Text == "Disabled" {
                    form["UpValInp"].Text := ""
                    ToggleVisibility(0, form["UpValInp"], form["UpValText"])
                } else {
                    ToggleVisibility(form["UpTypeDDL"].Visible, form["UpValInp"], form["UpValText"])
                }
            }
        }
        title := "Existing" . name . "for layer '" . layer . "'"
    }

    if !is_up && paired && paired.layers.Length
        && paired.layers.Has(layer) && paired.layers[layer][0] {
        p := paired.layers[layer][0]
        try form["CustomLP"].Text := p.custom_lp_time || ""
        opts := StrSplit(p.gesture_opts, ";")
        for i, name in [
            "LiveHint", "ColorInp", "GradLenInp", "GradCycle",
            "ColorInpEdges", "GradLenInpEdges", "GradCycleEdges",
            "ColorInpCorners", "GradLenInpCorners", "GradCycleCorners",
        ] {
            if i > opts.Length {
                break
            }
            if !opts[i] {
                continue
            }
            form[name].Value := opts[i]
        }
    }

    if !is_up && prev_layer !== layer {
        form.Title := title ?? "New" . name . "for layer '" . layer . "'"
    }

    if is_up {
        t := form["UpTypeDDL"]
        v := form["UpValInp"]
        h := form["UpValText"]
    } else {
        t := form["TypeDDL"]
        v := form["ValInp"]
        h := form["ValText"]
    }
    SendMessage(0x1501, true, StrPtr(placeholders[TYPES.%t.Text%]), v.Hwnd)
    (t.Text == "Function") ? SetUpFunction(is_up) : v.Focus()
    if t.Text == "Default" || t.Text == "Disabled" {
        v.Text := ""
        ToggleVisibility(0, v, h)
    } else {
        ToggleVisibility(1, v, h)
    }
    prev_layer := layer
}


SetUpFunction(is_up) {
    global func_form, func_fields, func_params

    if func_form {
        return
    }

    func_fields := []
    func_params := []

    args := false
    name := false
    func_str := is_up ? form["UpValInp"].Text : form["ValInp"].Text
    try {
        if func_str && RegExMatch(func_str, "^(?<name>\w+)(?:\((?<args>.*)\))?$", &m) {
            name := m["name"]
            args := _ParseFuncArgs(m["args"])
            arg_fields := custom_funcs[name]
            if arg_fields[2] is Array {
                l := arg_fields[2].Length
                for arg in args {
                    idx := A_Index // l + 1
                    if func_params.Length < idx {
                        func_params.Push([])
                    }
                    func_params[idx].Push(arg)
                }
            } else {
                func_params.Push(args)
            }
        }
    }

    func_form := Gui(, "Function Selector (" . (is_up ? "up" : "down") . " action)")
    func_form.OnEvent("Close", FuncFormClose)

    func_form.Add("Button", "x10 y10 w160 h19 vBtnPrev", "-")
        .OnEvent("Click", PrevFields.Bind(is_up))
    func_form.Add("Button", "x170 yp+0 w160 h19 vBtnNext", "+")
        .OnEvent("Click", NextFields.Bind(is_up))

    func_form.Add("DropDownList", "x10 y40 w240 vFuncDDL Choose1", custom_func_keys)
        .OnEvent("Change", ChangeFields)

    func_form.Add("Button", "x250 yp+0 w80 h19 vSave", "✔ Assign")
        .OnEvent("Click", SaveAssignedFunction.Bind(is_up))
    func_form.Add("Text", "x10 y+10 w320 h42 vDescription +0x1000", "")
    WinGetPos(&x, &y, &w, &h, "ahk_id " . form.Hwnd)
    if name {
        try func_form["FuncDDL"].Text := name
    }
    func_form.Show("w340 h" . 291 + (layer_editing ? 0 : 28) . " x" . x + w . " y" . y)
    RefreshFields()
}


ChangeFields(*) {
    global func_params

    func_params := []
    RefreshFields()
}


PrevFields(is_up, *) {
    global func_params

    func_params.Length -= 1

    PasteToInput(is_up)
    RefreshFields()
}


NextFields(is_up, *) {
    global func_params

    if func_fields.Length == 1 {
        func_params.Push(func_fields[1].Text)
    } else {
        func_params.Push([])
        for elem in func_fields {
            func_params[-1].Push(elem.Text)
        }
    }

    PasteToInput(is_up)
    RefreshFields()
}


RefreshFields(*) {
    global func_fields

    additional_field := false
    name := func_form["FuncDDL"].Text
    arg_fields := custom_funcs[name]

    ToggleVisibility(false, func_form["BtnPrev"], func_form["BtnNext"], func_fields*)
    func_fields := []

    y := 130

    for arg in arg_fields {
        if A_Index == 1 {
            func_form["Description"].Text := arg
            continue
        }

        if arg is Array {
            for elem in arg {
                func_fields.Push(func_form.Add("Edit", "w320 x10 y" . y))
                SendMessage(0x1501, true, StrPtr(elem), func_fields[-1].Hwnd)
                try func_fields[-1].Text := func_params[-1][A_Index]
                y += 30
            }
            ToggleVisibility(true, func_form["BtnPrev"], func_form["BtnNext"])
        } else if arg is Integer {
            func_fields.Push(
                func_form.Add("DDL", "w320 x10 y" . y . " Choose1", custom_func_ddls[arg])
            )
            try func_fields[-1].Text := func_params[-1][A_Index-1]
            if arg == 2 {  ; outputs
                func_fields[-1].OnEvent("Change", OutputChange)
                additional_field := func_fields[-1].Value == 3 ? 2 : 1
            }
            y += 30
        } else {
            func_fields.Push(func_form.Add("Edit", "w320 x10 y" . y))
            SendMessage(0x1501, true, StrPtr(arg), func_fields[-1].Hwnd)
            try func_fields[-1].Text := func_params[-1][A_Index-1]
            y += 30
        }
    }
    if additional_field {
        func_fields.Push(func_form.Add("Edit", "w320 x10 y" . y))
        SendMessage(0x1501, true, StrPtr("Tooltip display time (default: 3000 ms)"),
            func_fields[-1].Hwnd)
        if func_params.Length && func_params[-1].Length == arg_fields.Length {
            try func_fields[-1].Text := func_params[-1][-1]
        }
        if additional_field == 1 {
            func_fields[-1].Visible := false
        }
    }
    func_form["BtnPrev"].Enabled := func_params.Length
    func_form.Show()
}


OutputChange(ddl_obj, *) {
    func_fields[-1].Visible := ddl_obj.Value == 3
}


PasteToInput(is_up:=false) {
    global func_form

    form[is_up ? "UpTypeDDL" : "TypeDDL"].Text := "Function"
    inp := form[is_up ? "UpValInp" : "ValInp"]
    inp.Enabled := true
    if !func_params.Length {
        inp.Text := func_form["FuncDDL"].Text
    } else {
        str_val := "("
        for val in func_params {
            if val is Array {
                if val.Length == 1 {
                    str_val .= val[1] . ", "
                    continue
                }
                arr_val := "["
                for elem in val {
                    arr_val .= elem . ", "
                }
                str_val .= SubStr(arr_val, 1, -2) . "], "
            } else {
                str_val .= val . ", "
            }
        }
        str_val := RegExReplace(str_val, "[,\s]+$") . ")"
        inp.Text := func_form["FuncDDL"].Text . (str_val !== "()" ? str_val : "")
    }
}


SaveAssignedFunction(is_up:=false, *) {
    global func_params

    additional_field := false
    func_name := func_form["FuncDDL"].Text
    args := custom_funcs[func_name]
    if args.Length > 1 && !(args[2] is Array) {
        func_params := []
    }

    idx := 1
    for i, arg in args {
        if i == 1 {
            continue
        }
        if arg is Array {
            func_params.Push([])
            for elem in arg {
                func_params[-1].Push(func_fields[idx].Text)
                idx += 1
            }
        } else {
            func_params.Push(func_fields[idx].Text)
            if arg == 2 && func_fields[idx].Value == 3 {
                additional_field := true
            }
            idx += 1
        }
    }
    if additional_field {
        func_params.Push(func_fields[-1].Text)
    }

    PasteToInput(is_up)
    FuncFormClose()
}


FuncFormClose(*) {
    global func_form

    func_form.Destroy()
    func_form := false
}


WriteValue(is_hold, custom_path:=false, paired:=false, *) {
    vals := Map()
    for name in [
        "LayersDDL", "TypeDDL", "ValInp", "UpTypeDDL", "UpValInp", "CustomLP", "CustomNK",
        "Shortname", "ColorInp", "ColorInpEdges", "ColorInpCorners",
        "GradLenInp", "GradLenInpEdges", "GradLenInpCorners",
    ] {
        vals[name] := false
        try vals[name] := form[name].Text
    }
    for name in [
        "CBIrrevocable", "CBInstant", "ChildBehaviorDDL", "LiveHint",
        "GradCycle", "GradCycleEdges", "GradCycleCorners",
    ] {
        vals[name] := false
        try vals[name] := form[name].Value
    }
    vals["TypeDDL"] := vals["TypeDDL"] || "Modifier"
    vals["LiveHint"] := vals["LiveHint"] == 1 ? "" : vals["LiveHint"]

    if vals["CBIrrevocable"] && vals["ChildBehaviorDDL"] == 5
        && MsgBox("You set irrevocable option with ignoring unassigned children.`n"
            . "If you don't add an assignment for exiting from this level, "
            . "you'll be stuck there permanently.`n`n"
            . "Proceed with this setting?", "Confirmation", "YesNo Icon?") == "No" {
        return
    }

    if !StrLen(vals["ValInp"]) && vals["TypeDDL"] !== "Default" && vals["TypeDDL"] !== "Disabled" {
        MsgBox("Enter a value. To leave it empty, use the 'Disabled' type.",
            "Invalid value", "Icon!")
        return
    }
    if vals["TypeDDL"] == "Modifier" {
        try {
            int := Integer(form["ValInp"].Text)
            if 0 > int || int > 60 {
                throw
            }
        } catch {
            MsgBox("The modifier value must be a number from 1 to 60.", "Invalid value", "Icon!")
            return
        }
        if Integer(form["ValInp"].Text) == 0 {
            vals["TypeDDL"] := "Disabled"
        }
    }
    layers := GetLayerList()
    gest_opts := ""
    for name in [
        "LiveHint", "ColorInp", "GradLenInp", "GradCycle",
        "ColorInpEdges", "GradLenInpEdges", "GradCycleEdges",
        "ColorInpCorners", "GradLenInpCorners", "GradCycleCorners",
    ] {
        gest_opts .= (vals[name] ? vals[name] : "") . ";"
    }

    CloseForm()

    layer := layer_editing ? selected_layer : (layers.Length == 1 ? layers[1] : vals["LayersDDL"])
    new_lp := vals["CustomLP"] != CONF.MS_LP.v ? vals["CustomLP"] : false
    new_gest_opts := RTrim(gest_opts, ";")

    if paired {
        p := GetDefaultNode(current_path[-1][1], current_path[-1][2] & ~1)
        try p := paired.layers[layer][0]
        if p.custom_lp_time != new_lp || p.gesture_opts != new_gest_opts {
            SaveValue(
                0, layer,
                p.down_type, p.down_val,
                p.up_type, p.up_val,
                p.is_instant, p.is_irrevocable,
                new_lp,
                p.custom_nk_time,
                p.child_behavior, p.gui_shortname,
                new_gest_opts, custom_path
            )
        }

        SaveValue(
            1, layer,
            TYPES.%vals["TypeDDL"]%, vals["ValInp"],
            TYPES.%vals["UpTypeDDL"] || "Disabled"%, vals["UpValInp"],
            vals["CBInstant"], vals["CBIrrevocable"],
            0,
            (vals["CustomNK"] != CONF.MS_NK.v ? vals["CustomNK"] : false),
            vals["ChildBehaviorDDL"], vals["Shortname"],
            "", custom_path
        )
    } else {
        SaveValue(
            is_hold, layer,
            TYPES.%vals["TypeDDL"]%, vals["ValInp"],
            TYPES.%vals["UpTypeDDL"] || "Disabled"%, vals["UpValInp"],
            vals["CBInstant"], vals["CBIrrevocable"],
            new_lp,
            (vals["CustomNK"] != CONF.MS_NK.v ? vals["CustomNK"] : false),
            vals["ChildBehaviorDDL"], vals["Shortname"],
            new_gest_opts, custom_path
        )
    }
}


CloseForm(*) {
    global form, func_form, init_drawing

    try form.Destroy()
    try func_form.Destroy()
    form := false
    func_form := false
    init_drawing := false
}


WriteChord(chord:=false, *) {
    global form, temp_chord, start_temp_chord

    if Integer(form["CBIrrevocable"].Value) && Integer(form["ChildBehaviorDDL"].Value) == 5
        && MsgBox("You set irrevocable option with ignoring unassigned children.`n"
            . "If you don't add an assignment for exiting from this level, "
            . "you'll be stuck there permanently.`n`n"
            . "Proceed with this setting?", "Confirmation", "YesNo Icon?") == "No" {
        return
    }

    chord_txt := chord || ChordToStr(temp_chord)
    chord_scs := chord ? StrSplit(chord, "-") : temp_chord

    layers := GetLayerList()
    temp_layer := layer_editing ? selected_layer
        : (layers.Length == 1 ? layers[1] : form["LayersDDL"].Text)
    json_root := DeserializeMap(temp_layer)
    if !json_root.Has(gui_lang) {
        json_root[gui_lang] := ["", Map(), Map(), Map()]
    }
    if chord {
        path := current_path.Clone()
        path.Length -= 1
        res := current_path.Length > 1 ? _WalkJson(json_root[gui_lang], path)
            : json_root[gui_lang]
    } else {
        res := current_path.Length ? _WalkJson(json_root[gui_lang], current_path)
            : json_root[gui_lang]
    }
    json_scancodes := res[-3]
    json_chords := res[-2]
    if json_chords.Has(chord_txt) && json_chords[chord_txt].Has(gui_mod_val)
        && SubStr(form.Title, 1, 8) !== "Existing"
        && MsgBox("A chord with these keys already exists on the selected layer. "
            . "Do you want to overwrite it?", "Confirmation", "YesNo Icon?") == "No" {
        return
    }

    UI.Title := proj_name
    ToggleFreeze(1)

    for sc, _ in chord_scs {
        try sc := Integer(sc)
        if !json_scancodes.Has(sc) {
            json_scancodes[sc] := Map()
        }
        if json_scancodes[sc].Has(gui_mod_val+1) {
            json_scancodes[sc][gui_mod_val+1][1] := TYPES.Chord
            json_scancodes[sc][gui_mod_val+1][2] := ""
        } else {
            json_scancodes[sc][gui_mod_val+1] := GetDefaultJsonNode(, TYPES.Chord)
        }
    }

    if !json_chords.Has(chord_txt) {
        json_chords[chord_txt] := Map()
    }
    try sc_mp := json_chords[chord_txt][gui_mod_val][-3]
    try ch_mp := json_chords[chord_txt][gui_mod_val][-2]
    lp := Integer(form["CustomLP"].Value || 0)
    nk := Integer(form["CustomNK"].Value || 0)
    json_chords[chord_txt][gui_mod_val] := [
        TYPES.%form["TypeDDL"].Text%, form["ValInp"].Text . "", TYPES.Disabled, "",
        Integer(form["CBInstant"].Value), Integer(form["CBIrrevocable"].Value),
        (lp != CONF.MS_LP.v ? lp : false),
        (nk != CONF.MS_NK.v ? nk : false),
        Integer(form["ChildBehaviorDDL"].Value),
        "", "", sc_mp ?? Map(), ch_mp ?? Map(), Map(),
    ]

    SerializeMap(json_root, temp_layer)

    equal := true
    if temp_chord && start_temp_chord && temp_chord.Count == start_temp_chord.Count {
        for key, value in temp_chord {
            if !start_temp_chord.Has(key) {
                equal := false
                break
            }
        }
    } else if temp_chord && start_temp_chord {
        equal := false
    }

    if selected_chord !== "" && !equal {
        DeleteSelectedChord(0, true, true)
    }

    temp_chord := 0
    start_temp_chord := 0

    ToggleVisibility(0, UI.chs_back)
    ToggleVisibility(1, UI.chs_front)

    FillRoots()
    if layer_editing {
        AllLayers.map[selected_layer] := true
        MergeLayer(selected_layer)
    }
    UpdLayers()
    ChangePath()

    try form.Destroy()
    form := false
}


WriteGesture(as_base, entries, path, *) {
    global form

    try {
        scal := form["Scaling"].Text == "" ? CONF.scale_impact.v : Float(form["Scaling"].Text)
    } catch {
        MsgBox("Scale must be a decimal number or left empty.", "Invalid scale value", "Icon!")
        return
    }
    rot := form["Rotate"].Value == 1 ? CONF.gest_rotate.v : (form["Rotate"].Value - 1)
    dirs := form["Direction"].Value
    phase := form["Phase"].Value

    if !from_prev {
        gest_str := GestureToStr(points, rot, scal, dirs, phase)
    } else {
        if as_base {
            gest := _GetFirst(entries.ubase)
        } else {
            gest := _GetFirst(
                entries.ubase.GetBaseHoldMod(selected_gesture, gui_mod_val, false, true).ubase
            )
        }
        vals := StrSplit(gest.gesture_opts, ";")
        if scal != 0 && vals[-1] = 1 {
            MsgBox("To enable scale impact, the gesture must be redrawn.",
                "Outdated pattern", "Icon!")
            return
        }
        opts := vals[1] . ";" . rot - 1 . ";" . scal . ";" . dirs . ";" . phase . ";" . vals[-1]
        if StrLen(StrSplit(selected_gesture, " ")[1]) !== 1 {
            gest_str := [vals[1] . " " . selected_gesture, opts]
        } else {
            gest_str := [selected_gesture, opts]
        }
    }

    layers := GetLayerList()
    temp_layer := layer_editing ? selected_layer
        : (layers.Length == 1 ? layers[1] : form["LayersDDL"].Text)
    json_root := DeserializeMap(temp_layer)
    if !json_root.Has(gui_lang) {
        json_root[gui_lang] := ["", Map(), Map(), Map()]
    }
    if as_base {
        _path := path.Clone()
        _path.Length -= 1
        res := path.Length > 1 ? _WalkJson(json_root[gui_lang], _path)
            : json_root[gui_lang]
    } else {
        res := path.Length ? _WalkJson(json_root[gui_lang], path)
            : json_root[gui_lang]
    }
    json_gestures := res[-1]

    if json_gestures.Has(gest_str[1])
        && SubStr(form.Title, 1, 8) !== "Existing"
        && MsgBox("An identical gesture already exists on this layer. "
        . "Do you want to overwrite it?", "Confirmation", "YesNo Icon?") == "No" {
        return
    }

    try sc_mp := json_gestures[gest_str[1]][gui_mod_val][-3]
    try ch_mp := json_gestures[gest_str[1]][gui_mod_val][-2]

    if selected_gesture {
        if json_gestures[selected_gesture].Count !== 1 {
            json_gestures[selected_gesture].Delete(gui_mod_val)
        } else {
            json_gestures.Delete(selected_gesture)
        }
    }

    if !json_gestures.Has(gest_str[1]) {
        json_gestures[gest_str[1]] := Map()
    }
    json_gestures[gest_str[1]][gui_mod_val] := [
        TYPES.%form["TypeDDL"].Text%, form["ValInp"].Text . "", TYPES.Disabled, "",
        Integer(form["CBInstant"].Value), Integer(form["CBIrrevocable"].Value),
        0, (form["CustomNK"].Text != CONF.MS_NK.v ? Integer(form["CustomNK"].Text || 0) : 0),
        Integer(form["ChildBehaviorDDL"].Value), form["Shortname"].Text || form["ValInp"].Text,
        gest_str[2], sc_mp ?? Map(), ch_mp ?? Map(), Map(),
    ]

    SerializeMap(json_root, temp_layer)

    FillRoots()
    if layer_editing {
        AllLayers.map[selected_layer] := true
        MergeLayer(selected_layer)
    }
    UpdLayers()
    ChangePath()
    CloseForm()
}


SaveValue(
    is_hold, layer, down_type, down_val:="", up_type:=false, up_val:="",
    is_instant:=false, is_irrevocable:=false, custom_lp_time:=false, custom_nk_time:=false,
    child_behavior:=false, shortname:="", gest_opts:="", custom_path:=false
) {
    ToggleFreeze(1)
    json_root := DeserializeMap(layer)

    if !json_root.Has(gui_lang) {
        json_root[gui_lang] := ["", Map(), Map(), Map()]
    }
    json_node := _WalkJson(json_root[gui_lang], (custom_path || current_path), is_hold)
    json_node[1] := down_type
    json_node[2] := down_type == TYPES.Default || down_type == TYPES.Disabled ? "" : down_val . ""
    json_node[3] := up_type || TYPES.Disabled
    json_node[4] := up_type == TYPES.Default || json_node[3] == TYPES.Disabled ? "" : up_val . ""
    json_node[5] := Integer(is_instant)
    json_node[6] := Integer(is_irrevocable)
    json_node[7] := Integer(custom_lp_time || 0)
    json_node[8] := Integer(custom_nk_time || 0)
    json_node[9] := child_behavior == false ? 4 : Integer(child_behavior)
    json_node[10] := shortname
    json_node[11] := gest_opts
    SerializeMap(json_root, layer)

    FillRoots()
    if layer_editing {
        AllLayers.map[selected_layer] := true
        MergeLayer(selected_layer)
    }
    UpdLayers()
    ChangePath()
}


_ReturnButtonText(*) {
    try form["SetGesture"].Text := "Redraw saved gesture"
}