FillPathline() {
    UI.SetFont("Italic")
    root := UI.Add("Button", "+0x80 -Wrap" . Scale(10, 5), root_text)
    ToggleVisibility(0, UI.path)
    UI.path := []
    UI.path.Push(root)
    root.OnEvent("Click", ChangePath.Bind(0))
    UI.SetFont("Norm")

    path := buffer_view ? buffer_path : current_path

    if path.Length {
        for i, val in path {
            dir_text := UI.Add("Text", "x+3 yp" . (6 * CONF.gui_scale.v),
                (val[2] > 1 ? val[2] : "")
                . (val[4] ? "•" : val[3] ? "▼" : ["➤", "▲"][(val[2] & 1) + 1])
            )
            UI.path.Push(dir_text)

            UI.path.Push(UI.Add("Button", "x+3 yp-"
                . (6 * CONF.gui_scale.v), val[3] || val[4] || _GetKeyName(val[1], true, true)))
            UI.path[-1].OnEvent("Click", ChangePath.Bind(i))
        }
    }

    if gui_mod_val && UI.path[-1].Text != "²" {
        txt := ""
        for n in DecomposeMods(gui_mod_val) {
            txt .= n . "+"
        }
        UI.SetFont("c808080")
        UI.path.Push(UI.Add("Text", "x+7 yp" . (6 * CONF.gui_scale.v), RTrim(txt, "+")))
        UI.SetFont("cD3D3D3")
        UI.path.Push(UI.Add("Text", "xp-5 yp+13", "²"))
        UI.SetFont("cBlack")
    }
}


FillSetButtons() {
    UI["SwapBufferView"].Visible := false
    if !current_path.Length && !buffer_view {
        ToggleVisibility(0, UI.current_values)
        return
    }

    if buffer_view {
        ToggleVisibility(0, UI.current_values)
        ToggleEnabled(0, UI["BtnBase"], UI["BtnHold"])
        if buffer_path.Length {
            ToggleVisibility(1, UI["TextBase"], UI["BtnBase"], UI["TextHold"], UI["BtnHold"])
        } else if saved_level[1] == 1 {
            ToggleVisibility(1, UI["TextBase"], UI["BtnBase"])
        } else if saved_level[1] == 2 {
            ToggleVisibility(1, UI["TextBase"], UI["BtnBase"], UI["TextHold"], UI["BtnHold"])
        }
        if saved_level[1] == 2 {
            UI["SwapBufferView"].Visible := true
        }
        path := buffer_path
    } else {
        ToggleVisibility(1, UI.current_values)
        ToggleEnabled(1, UI["BtnBase"], UI["BtnBaseClear"], UI["BtnHold"], UI["BtnHoldClear"])
        path := current_path
    }

    if CheckLRMB(path) || (path.Length && (path[-1][3] || path[-1][4])) {
        ToggleVisibility(0, UI["TextHold"], UI["BtnHold"], UI["BtnHoldClear"], UI["BtnHoldClearNest"])
    }

    entries := _GetUnholdEntries()
    hnode := _GetFirst(entries.uhold)
    ignore_hold_count := buffer_view && !path.Length && hnode && hnode.down_type == TYPES.Modifier

    if !buffer_view || saved_level[1] || path.Length {
        for arr in [["Base", entries.ubase], ["Hold", entries.uhold]] {
            txt := arr[1]
            curr_node := _GetFirst(arr[2])
            UI["Text" . txt].Text := txt
            UI["Btn" . txt].Text := ""
            if txt == "Hold" && path.Length && ONLY_BASE_SCS.Has(path[-1][1]) {
                ToggleEnabled(
                    0, UI["Btn" . txt], UI["Btn" . txt . "Clear"], UI["Btn" . txt . "ClearNest"])
                continue
            }
            md := (path[-1][2] & ~1) + A_Index - 1
            if !curr_node {
                ToggleEnabled(false, UI["Btn" . txt . "Clear"], UI["Btn" . txt . "ClearNest"])
                continue
            } else if !curr_node.down_type {
                ToggleVisibility(false, [UI["Text" . txt], UI["Btn" . txt]])
                continue
            } else if curr_node.down_type == (md ? 1 : 2) && curr_node.up_type == 1
                && !curr_node.custom_lp_time && !curr_node.custom_nk_time && !curr_node.is_instant
                && !curr_node.is_irrevocable && curr_node.child_behavior == 4 {
                ToggleEnabled(false, UI["Btn" . txt . "Clear"], UI["Btn" . txt . "ClearNest"])
            }
            _AddIndicators(arr[2], UI["Btn" . txt], false, ignore_hold_count)

            UI["Text" . txt].Text .= " ("
                . ["-", "D", "T", "S", "F", "M", "C"][curr_node.down_type]
                . ")"
            switch curr_node.down_type {
                case TYPES.Default:
                    UI["Btn" . txt].Text := "{Default}"
                    try UI["Btn" . txt].Text := _GetKeyName(path[-1][1], true, true)
                case TYPES.Text:
                    UI["Btn" . txt].Text := CheckDiacr(curr_node.down_val)
                case TYPES.Function:
                    UI["Btn" . txt].Text := curr_node.down_val
                case TYPES.KeySimulation:
                    UI["Btn" . txt].Text := _GetKeyName(false, false, true, curr_node.down_val)
                case TYPES.Modifier:
                    UI["Btn" . txt].Text := "Mod " . curr_node.down_val
                case TYPES.Chord:
                    UI["Btn" . txt].Text := "Chord"
                    ToggleEnabled(false, UI["Btn" . txt], UI["Btn" . txt . "Clear"])
            }
            if curr_node.gui_shortname {
                UI["Btn" . txt].Text := curr_node.gui_shortname
            }
        }
    }

    if path.Length && AWMods.Has(path[-1][1]) {
        UI["BtnBase"].Enabled := false
    }
    UI.SetFont("Norm")
}


FillKeyboard() {
    b := CheckLRMB(current_path) || current_path.Length
        && !(current_path[-1][2] & 1) && AWMods.Has(current_path[-1][1])
    for sc, btn in UI.buttons {
        if sc == "CurrMod" {
            btn.SetFont("Italic")
            btn.Opt(gui_mod_val
                ? "-Disabled +BackgroundRed"
                : "+Disabled +Background" . CONF.default_unassigned_color.v
            )
            btn.Text := "Mod:`n" . gui_mod_val
            continue
        }
        btn.dragged_sc := sc
        try btn.dragged_sc := Integer(sc)
        FillOneButton(sc, btn, sc, b)
    }
}


FillOneButton(sc, btn, d_sc, is_disabled:=false) {
    backgr := CONF.default_assigned_color.v
    btn.Enabled := true
    btn.SetFont("Norm")

    res := gui_entries.ubase.GetBaseHoldMod(d_sc, gui_mod_val, false, false, false, false)
    b_node := _GetFirst(res.ubase)
    h_node := _GetFirst(res.uhold)
    m_node := _GetFirst(res.umod)

    btxt := _GetKeyName(sc, true)
    if b_node {
        l := selected_layer ? selected_layer : buffer_view ? "buffer" : false
        gsts := l ? GetLayerGestures(res.ubase, l) : _GetGestures(res.ubase, gui_proc_ctx)
        if gsts.Count {
            opts := StrSplit(b_node.gesture_opts, ";")
            backgr := CONF.has_gestures_color.v
            try backgr := Format("{:#06x}", Integer("0x"
                . Trim(StrSplit(CONF.gest_colors[1].v, ",")[1])))
            try backgr := Format("{:#06x}", Integer("0x" . opts[8]))
            try backgr := Format("{:#06x}", Integer("0x" . opts[5]))
            try backgr := Format("{:#06x}", Integer("0x" . opts[2]))
        }
        _AddIndicators(res.ubase, btn)
        switch b_node.down_type {
            case TYPES.Default:
                btxt := _GetKeyName(sc, true)
            case TYPES.Disabled:
                btn.SetFont("Italic")
                btxt := "{D}"
            case TYPES.KeySimulation:
                btn.SetFont("Italic")
                btxt := _GetKeyName(d_sc, false, false, b_node.down_val)
            default:
                btxt := CheckDiacr(b_node.down_val)
        }
        if b_node.gui_shortname {
            btxt := b_node.gui_shortname
        }
    }

    htxt := ""
    sep := SubStr(sc, 1, 2) == "vk" ? " / " : "`n"
    if m_node {
        v := 1 << m_node.down_val
        if gui_mod_val && gui_mod_val & v == v {
            backgr := CONF.active_modifier_color.v
        } else {
            _AddIndicators(res.umod, btn, true)
            backgr := CONF.modifier_color.v
        }
        htxt := sep . (m_node.gui_shortname ? m_node.gui_shortname : m_node.down_val)
    } else if h_node {
        _AddIndicators(res.uhold, btn, true)
        switch h_node.down_type {
            case TYPES.Default:
                htxt := sep . _GetKeyName(sc)
            case TYPES.Text:
                htxt := sep . CheckDiacr(h_node.down_val)
            case TYPES.KeySimulation:
                htxt := sep . _GetKeyName(d_sc, false, false, h_node.down_val)
            case TYPES.Function:
                htxt := sep . h_node.down_val
            case TYPES.Chord:
                backgr := CONF.chord_part_color.v
        }
        if h_node.gui_shortname {
            htxt := sep . h_node.gui_shortname
        }
    }

    if !b_node && !h_node && !m_node {
        backgr := CONF.default_unassigned_color.v
    }

    if temp_chord {
        if ONLY_BASE_SCS.Has(sc)
            || !h_node && m_node && m_node.down_type == TYPES.Modifier
            || !current_path.Length && (sc == "LButton" || sc == "RButton") {
            btn.Enabled := false
        }
        if temp_chord.Has(String(sc)) {
            backgr := CONF.selected_chord_color.v
        }
    }

    btn.Opt("+Background" . backgr)
    btn.Text := btxt . htxt
    if is_disabled {
        btn.Enabled := false
    }
}


_AddIndicators(unode, btn, is_hold:=false, ignore_hold_count:=false) {
    if CONF.overlay_type.v == 1 {
        return
    }
    btn.GetPos(&x, &y, &w, &h)
    x += 1
    y += 1
    w -= 2
    h -= 2
    p := 3 * CONF.gui_scale.v
    node := _GetFirst(unode)
    if node.down_type == TYPES.Modifier {
        cnt := ignore_hold_count ? 0 : _CountChild("", 0, gui_mod_val + (1 << node.down_val),
            gui_entries.ubase.scancodes, gui_entries.ubase.chords,
            gui_entries.ubase.gestures, true)
    } else {
        cnt := _CountChild("", 0, 0, unode.scancodes, unode.chords, unode.gestures)
    }
    if cnt {
        l := StrLen(String(cnt)) * 5 * CONF.font_scale.v + 4
        c := CONF.nested_counter_ind_color.v
        res := (CONF.overlay_type.v == 3)
            ? _AddOverlayItem(x + w - l, y + (is_hold ? h - 12 * CONF.font_scale.v : 0), c, cnt)
            : _AddOverlayItem(x + w - p, y + (is_hold ? h - p : 0), c)
        btn.indicators.Push(res)
    }
    try UI[btn.Name . "ClearNest"].Enabled := cnt
    if is_hold {
        y += h - p
    }
    for arr in [
        [node.gui_shortname, CONF.changed_name_ind_color.v],
        [node.is_irrevocable, CONF.irrevocable_ind_color.v],
        [node.is_instant, CONF.instant_ind_color.v],
        [node.up_type !== TYPES.Disabled, CONF.additional_up_ind_color.v],
        [node.custom_lp_time, CONF.custom_hold_time_ind_color.v],
        [node.custom_nk_time, CONF.custom_child_time_ind_color.v]
    ] {
        if arr[1] {
            res := _AddOverlayItem(x + p * (A_Index - 1), y, arr[2])
            btn.indicators.Push(res)
        }
    }
}


FillLayerTags() {
    global extra_tags_height:=0
    static idx:=0

    is_expanded := UI.extra_tags.Length && UI.extra_tags[1].Text == "▴"

    ToggleVisibility(0, UI.main_tags, UI.extra_tags)
    UI.main_tags := []
    UI.extra_tags := []

    act := UI.Add("Text", "vLayerTag" . idx . Scale(13, CONF.ref_height.v + 7, , 20), "Active")
    act.OnEvent("Click", ToggleLayersTag)
    act.OnEvent("DoubleClick", (*) => 0)
    act.Opt(CONF.tags["Active"] ? "cGreen" : "cRed")
    idx += 1

    inact := UI.Add("Text", "vLayerTag" . idx . " x+10" . Scale(, , , 20), "Inactive")
    inact.OnEvent("Click", ToggleLayersTag)
    inact.OnEvent("DoubleClick", (*) => 0)
    inact.Opt(CONF.tags["Inactive"] ? "cGreen" : "cRed")
    idx += 1

    UI.main_tags.Push(act, inact, UI.Add("Text", "cGray x+10" . Scale(, , , 20), "|"))

    act.GetPos(, &ay, &aw)
    inact.GetPos(,, &iw)

    curr_w := 100 + aw + iw
    max_width := 425 * CONF.gui_scale.v
    first_line := true

    unt := "<untagged>"
    tags := []
    for tag in AllTags {
        if tag !== unt {
            tags.Push(tag)
        }
    }
    if AllTags.Has(unt) {
        tags.Push(unt)
    }

    for tag in tags {
        t := tag
        elem := UI.Add("Text", (CONF.tags.Has(tag) ? CONF.tags[tag] ? "cGreen" : "cRed" : "cGray")
            . " x+10" . Scale(, , , 20), tag)
        elem.GetPos(,, &ew)
        curr_w += ew + 10
        if curr_w > max_width {
            elem.Visible := false
            if first_line {
                first_line := false
                UI.extra_tags.Push(
                    UI.Add("Text", "cGray xp+1" . Scale(, , , 20), (is_expanded ? "▴" : "▾")))
                UI.extra_tags[1].OnEvent("Click", ExpandTags)
            }
            elem := UI.Add("Text", (
                CONF.tags.Has(tag) ? CONF.tags[tag] ? "cGreen" : "cRed" : "cGray"
                ) . " y+1" . Scale(13, , , 20), tag)
            curr_w := ew + 10
        }
        elem.Opt("vLayerTag" . idx)
        idx += 1
        elem.OnEvent("Click", ToggleLayersTag)
        elem.OnEvent("DoubleClick", ToggleLayersTag)
        if !first_line {
            UI.extra_tags.Push(elem)
        } else {
            UI.main_tags.Push(elem)
        }
    }
    elem.GetPos(, &ey)
    extra_tags_height := ey - ay
    if !is_expanded {
        ToggleVisibility(0, UI.extra_tags)
    }
    ToggleVisibility(1, UI.extra_tags[1])
}


FillLayers() {
    UI["LV_layers"].Delete()

    if layer_path.Length {
        UI["LV_layers"].Add("Icon4", "", "", "[…]", "", "", "")
    }

    temp_all_layers := Map()
    for layer in AllLayers.map {
        temp_all_layers[layer] := ActiveLayers[layer]
    }
    if layer_editing && !buffer_view {
        temp_all_layers[selected_layer] := "▶"
    }

    to_del := []
    for tag, _ in CONF.tags {
        if tag !== "Active" && tag !== "Inactive" && !AllTags.Has(tag) {
            to_del.Push(tag)
        }
    }
    for tag in to_del {
        CONF.tags.Delete(tag)
    }

    has_red_tags := false
    has_green_tags := false
    for tag, v in CONF.tags {
        if tag == "Active" || tag == "Inactive" {
            continue
        }
        if v {
            has_green_tags := true
        } else {
            has_red_tags := true
        }
        if has_green_tags && has_red_tags {
            break
        }
    }

    folder_name := ""

    for name, v in temp_all_layers {
        if name !== selected_layer {
            if !CONF.tags["Active"] && ActiveLayers.Has(name)
            || !CONF.tags["Inactive"] && !ActiveLayers.Has(name) {
                continue
            }

            allowed := true
            if has_green_tags {
                allowed := false
                for tag in LayersMeta[name]["tags"] {
                    if CONF.tags.Has(tag) {
                        if CONF.tags[tag] {
                            allowed := true
                        } else {
                            allowed := false
                            break
                        }
                    }
                }
            } else if has_red_tags {
                allowed := true
                for tag in LayersMeta[name]["tags"] {
                    if CONF.tags.Has(tag) {
                        allowed := false
                        break
                    }
                }
            }

            if !allowed {
                continue
            }
        }

        lvl := layer_path.Length + 1
        split := StrSplit(name, "\")
        path := "layers\"
        for i, s in split {
            if i > lvl {
                break
            }
            path .= s . "\"
        }

        b := false
        for folder in layer_path {
            if folder != split[A_Index] {
                b := true
                break
            }
        }
        if b {
            continue
        }

        if split.Length > lvl {
            if !folder_name {
                folder_name := split[lvl]
                folder_cnt := 0
                loop Files, path . "*", "FR" {
                    folder_cnt += 1
                }
            } else if split[lvl] !== folder_name {
                UI["LV_layers"].Add("Icon3", , , folder_name, folder_cnt || "")
                folder_name := split[lvl]
                folder_cnt := 0
                loop Files, path . "*", "FR" {
                    folder_cnt += 1
                }
            }
            continue
        } else if split.Length < lvl {
            continue
        }

        if folder_name {
            UI["LV_layers"].Add("Icon3", , , folder_name, folder_cnt || "")
            folder_name := ""
            folder_cnt := 0
        }

        if CONF.ignore_inactive.v && !v {
            UI["LV_layers"].Add("Icon1", , , split[-1])
            continue
        }
        cnt := [0, 0]
        if buffer_view || !current_path.Length {
            for lang, val in AllLayers.map[name] {
                cnt[2 - (lang == gui_lang)] += val
            }
            lang := UI["Langs"].Text == "Global assignments" ? "Global" : UI["Langs"].Text
            for i, val in [
                ["Layer", 200], [lang, 80], ["", 0], ["Other roots", 80], ["", 0]
            ] {
                UI["LV_layers"].ModifyCol(2+i, val[2] * CONF.gui_scale.v, val[1])
            }
            UI["LV_layers"].Add(
                ActiveLayers.Has(name) ? "Icon2" : "Icon1", "", v || "",
                split[-1], cnt[1] || "", "", cnt[2] || "", ""
            )
            continue
        }

        txt := ["", ""]
        for i, unode in [gui_entries.ubase, gui_entries.uhold] {
            if unode {
                cnt[i] := _CountChild(name, 0, 0, unode.scancodes, unode.chords, unode.gestures)
            }
            node := _GetFirst(unode, name)
            if !node {
                continue
            }
            if node.gui_shortname {
                txt[i] := node.gui_shortname
                continue
            }

            val := node.down_val
            switch node.down_type {
                case TYPES.Disabled:
                    txt[i] := "{-}"
                case TYPES.Default:
                    txt[i] := "{D}"
                case TYPES.Text:
                    txt[i] := "'" . CheckDiacr(val) . "'"
                case TYPES.KeySimulation:
                    txt[i] := val ? _GetKeyName(false, false, true, val) : ""
                case TYPES.Function:
                    txt[i] := "(" . val . ")"
                case TYPES.Modifier:
                    txt[i] := "{M" . val . "}"
                case TYPES.Chord:
                    txt[i] := "{C}"
            }
        }
        for i, val in [["Layer", 110], ["Base", 95], ["→", 30], ["Hold", 95], ["→", 30]] {
            UI["LV_layers"].ModifyCol(2+i, val[2] * CONF.gui_scale.v, val[1])
        }
        UI["LV_layers"].Add(
            ActiveLayers.Has(name) ? "Icon2" : "Icon1", "", v || "",
            split[-1], txt[1], cnt[1] || "", txt[2], cnt[2] || ""
        )
    }

    if folder_name {
        UI["LV_layers"].Add("Icon3", , , folder_name, folder_cnt || "")
    }

    ToggleEnabled(0, UI.layer_move_btns, UI.layer_ctrl_btns)
}


_CountChild(layer, levels, mod_val, scs, chs, gsts, combined:=false) {
    cnt := 0
    if !layer && layer_editing && !buffer_view {
        layer := selected_layer
    }
    for scs in [scs, chs, gsts] {
        for sc, mods in scs {
            for md, unode in mods {
                if !mod_val && combined
                    || !(combined ? ((mod_val & md) == mod_val) : (mod_val == (md & ~1))) {
                    continue
                }
                if layer && unode.layers.Has(layer) && _IsCounted(unode.layers[layer][0]) {
                    cnt += 1
                }
                if !layer {
                    for nlayer in unode.layers.map {
                        if (buffer_view || ActiveLayers.Has(nlayer))
                            && _IsCounted(unode.layers[nlayer][0]) {
                            cnt += 1
                            break
                        }
                    }
                }
                if levels {
                    cnt += _CountChild(layer, levels-1, mod_val, scs, chs, gsts, combined)
                }
            }
        }
    }
    return cnt
}


_IsCounted(node) {
    return node && (node.down_type !== TYPES.Chord || node.up_type !== TYPES.Disabled)
}


FillGestures() {
    UI["LV_gestures"].Delete()

    path := buffer_view ? buffer_path : current_path

    if !path.Length || path[-1][4] || path[-1][3]
        || SubStr(path[-1][1], 1, 2) == "Wh" && path[-1][1] !== "WhClick" || AWMods.Has(path[-1][1]) {
        ToggleEnabled(0, UI["BtnAddNewGesture"], UI.gest_toggles)
        for i, val in [["Has nested gestures", 220], ["→", 190], ["", 0], ["", 0], ["", 0]] {
            UI["LV_gestures"].ModifyCol(i, val[2] * CONF.gui_scale.v, val[1])
        }
        l := selected_layer ? selected_layer : buffer_view ? "buffer" : false
        mp := l ? GetLayerScancodes(gui_entries.ubase, l)
            : _GetScancodes(gui_entries.ubase, gui_proc_ctx)
        for sc, mods in mp {
            for md, node in mods {
                if !_GetFirst(node) {
                    continue
                }
                cnt := 0
                for _, g_mods in node.gestures {
                    for _, g_node in g_mods {
                        if buffer_view || _GetFirst(g_node) {
                            cnt += 1
                        }
                    }
                }
                if cnt {
                    name := ""
                    try name := _GetFin(node, gui_proc_ctx).gui_shortname
                    UI["LV_gestures"].Add(
                        "",
                        (name || _GetKeyName(sc, true))
                            . (md ? (" (mod " . DecomposeMods(md, true) . ")") : ""),
                        cnt, "", "", "",
                        sc . ";" . md
                    )
                }
            }
        }
        return
    }

    for i, val in [["Gesture name", 110], ["Value", 110], ["Options", 95],
        ["→", 30], ["Layer", 65], ["roll it back", 0]] {
        UI["LV_gestures"].ModifyCol(i, val[2] * CONF.gui_scale.v, val[1])
    }
    entries := _GetUnholdEntries()

    ToggleEnabled(1, UI["BtnAddNewGesture"])
    checked_layers := layer_editing ? [selected_layer] : ActiveLayers.order
    for vec_str, mods in entries.ubase.gestures {
        ubase := entries.ubase.GetBaseHoldMod(vec_str, gui_mod_val, false, true).ubase
        child_node := _GetFirst(ubase)
        if !child_node {
            continue
        }

        cnt := ubase ? _CountChild("", 0, 0, ubase.scancodes, ubase.chords, ubase.gestures) : 0
        layer_text := ""
        for layer in checked_layers {
            if EqualNodes(child_node, _GetFirst(ubase, layer)) {
                layer_text .= " & " . layer
            }
        }
        layer_text := SubStr(layer_text, 4)

        switch child_node.down_type {
            case TYPES.Text:
                val := "'" . CheckDiacr(child_node.down_val) . "'"
            case TYPES.KeySimulation:
                val := _GetKeyName(false, false, true, child_node.down_val)
            case TYPES.Function:
                val := "(" . child_node.down_val . ")"
        }

        UI["LV_gestures"].Add(
            "",
            child_node.gui_shortname,
            val,
            _GestOptsToText(child_node.gesture_opts),
            cnt || "",
            layer_text,
            vec_str
        )
    }
    ToggleEnabled(entries && entries.ubase && entries.ubase !== ROOTS[gui_lang],
        UI["BtnAddNewGesture"])
    UI["LV_gestures"].ModifyCol(1, "Sort")
}


_GestOptsToText(opts) {
    vals := StrSplit(opts, ";")
    str := ["TL", "T", "TR", "L", "C", "R", "BL", "B", "BR"][Integer(vals[1])]
    if vals[2] + 1 != CONF.gest_rotate.v {
        str .= ", rotate: " . ["no", "de-noise", "invar."][Integer(vals[2]) + 1]
    }
    if Float(vals[3]) != CONF.scale_impact.v {
        str .= ", scale imp.: " . Round(Float(vals[3]), 2)
    }
    if vals[4] !== "0" {
        str .= ", bidir."
    }
    if vals[5] !== "0" {
        str .= ", closed."
    }
    return str
}


FillChords() {
    UI["LV_chords"].Delete()
    checked_layers := layer_editing ? [selected_layer] : ActiveLayers.order
    for chord_str, mods in gui_entries.ubase.chords {
        ubase := gui_entries.ubase.GetBaseHoldMod(chord_str, gui_mod_val, true).ubase
        child_node := _GetFirst(ubase)
        if !child_node {
            continue
        }

        hl := start_temp_chord && start_temp_chord.Count && chord_str == selected_chord ? "👉 " : ""
        cnt := ubase ? _CountChild("", 0, 0, ubase.scancodes, ubase.chords, ubase.gestures) : 0

        layer_text := ""
        for layer in checked_layers {
            if !buffer_view && EqualNodes(child_node, _GetFirst(ubase, layer)) {
                layer_text .= " & " . layer
            }
        }
        layer_text := SubStr(layer_text, 4)

        switch child_node.down_type {
            case TYPES.Disabled:
                val := "{D}"
            case TYPES.Text:
                val := "'" . CheckDiacr(child_node.down_val) . "'"
            case TYPES.KeySimulation:
                val := _GetKeyName(false, false, true, child_node.down_val)
            case TYPES.Function:
                val := "(" . child_node.down_val . ")"
        }

        chord_txt := ""
        for sc in StrSplit(chord_str, "-") {
            if CONF.keyname_type.v == 2 {
                chord_txt .= "&" . sc . " "
                continue
            }
            try {
                t := GetKeyName(SC_STR[Integer(sc)]) . " "
            } catch {
                t := GetKeyName(SC_STR[sc]) . " "
            }
            chord_txt .= t == " " ? ("&" . sc . " ") : t
        }

        UI["LV_chords"].Add(
            "",
            hl . (child_node.gui_shortname || chord_txt),
            val,
            cnt || "",
            layer_text
        )
    }
    UI["LV_chords"].ModifyCol(1, "Sort")
    UI["BtnAddNewChord"].Enabled := !CheckLRMB(current_path)
}


FillOther() {
    global gui_proc_ctx

    if !current_path.Length {
        UI.copy_options_menu.Disable("3&")
    }

    ToggleEnabled(0, UI.layer_move_btns, UI.layer_ctrl_btns, UI.chs_toggles, UI.gest_toggles)

    ToggleEnabled(saved_level && !buffer_view && !temp_chord && selected_layer
        && (saved_level[1] !== 2 || current_path.Length), UI["BtnShowPasteMenu"])
    ToggleEnabled(!buffer_view && !temp_chord && selected_layer, UI["BtnShowCopyMenu"])
    ToggleEnabled(!temp_chord, UI["BtnEnableDragMode"], UI["BtnShowBuffer"])

    if UI["TextHold"].Text !== "Hold" && current_path.Length {
        UI.copy_options_menu.Enable("3&")
    } else {
        UI.copy_options_menu.Disable("3&")
    }

    if selected_layer {
        return
    }

    UI["DdlProcCtx"].Enabled := true
    UI["DdlProcCtx"].Delete()
    UI["DdlProcCtx"].Add(GetGuiProcessItems())
    UI["DdlProcCtx"].Text := GetGuiProcessTextByCtx(gui_proc_ctx)
    if UI["DdlProcCtx"].Text == "*" {
        gui_proc_ctx := 1
    }
}