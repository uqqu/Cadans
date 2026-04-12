#Include "gui_draw.ahk"
#Include "gui_fill.ahk"
#Include "gui_layers.ahk"
#Include "gui_gestures.ahk"
#Include "gui_chords.ahk"
#Include "gui_processes.ahk"
#Include "gui_help.ahk"
#Include "gui_forms.ahk"
#Include "gui_transitions.ahk"
#Include "gui_move.ahk"
#Include "_utils.ahk"

SM_SCS := Map(42, 1, 54, 1, 310, 1, 29, 2, 285, 2, 56, 4, 312, 8)
; shift 1; ctrl 2; lalt 4; ralt/altgr 8

current_path := []
root_text := "root"
overlay := false

gui_mod_val := 0
gui_sysmods := 0
gui_lang := 0
gui_proc_ctx := 1
gui_entries := {ubase: ROOTS[gui_lang], uhold: false, umod: false}

selected_layer := ""
last_selected_layer := ""
selected_layer_priority := 0
layer_editing := 0
layer_path := []

selected_chord := ""
temp_chord := 0
start_temp_chord := 0

selected_gesture := ""

buffer_path := []
is_drag_mode := false
init_obj := false
drag_physical := false
drag_map := Map()

A_IconTip := proj_name . (A_IsCompiled ? "" : " (.ahk)")
A_TrayMenu.Delete()
A_TrayMenu.Add("+10ms hold threshold (to " . CONF.MS_LP.v + 10 . "ms)",
    (*) => ChangeDefaultHoldTime(+10))
A_TrayMenu.Add("-10ms hold threshold (to " . CONF.MS_LP.v - 10 . "ms)",
    (*) => ChangeDefaultHoldTime(-10))
A_TrayMenu.Add()
A_TrayMenu.Add("Show GUI", (*) => TrayClick())
A_TrayMenu.Add("Settings", (*) => ShowSettings())
A_TrayMenu.Add("Suspend hotkeys", (*) => TrayToggleSuspend())
A_TrayMenu.Add("Reload", (*) => Run(A_ScriptFullPath))
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "Show GUI"

A_TrayMenu.Click := TrayClick
A_TrayMenu.ClickCount := 1

DrawLayout(true)

if first_start {
    FirstMessage()
}


TrayClick(*) {
    if !DllCall("IsWindowVisible", "ptr", UI.Hwnd) {
        UI.Show()
        ChangePath(-1, false)
    } else {
        UI.Hide()
    }
}


TrayToggleSuspend() {
    Suspend(-1)
    if A_IsSuspended {
        A_TrayMenu.Check("Suspend hotkeys")
        TraySetIcon(A_ScriptDir . "\ico\icon_suspend.ico", , true)
    } else {
        A_TrayMenu.Uncheck("Suspend hotkeys")
        TraySetIcon(A_ScriptDir . "\ico\icon.ico")
    }
}


ToggleFreeze(state:=2) {
    global is_updating
    static prev_path_txt:="", prev_title:=""

    if state == 0 || state == 2 && is_updating {
        is_updating := false
        try {
            UI.path[1].Text := prev_path_txt
            UI.Title := prev_title
        }
    } else if !is_updating {
        is_updating := true
        try {
            prev_path_txt := UI.path[1].Text
            prev_title := UI.Title
            UI.path[1].Text := "⟳"
            UI.Title := "⟳ Applying changes…"
        }
    }
}


ChangeLang(lang, *) {
    global gui_lang

    UI["Hidden"].Focus()
    gui_lang := LANGS.order[lang]
    ChangePath()
    if !CONF.hide_alias_warnings.v && CONF.LayoutAliases.Has(gui_lang) {
        MsgBox("This layout aliased with `"" . LANGS[CONF.LayoutAliases[gui_lang]] . "`"."
            . "`nChanges for the selected layout will be saved "
            . "`n but won't take effect while the rule is active."
            . "`nYou can edit or clear it in the settings.", "Warning")
    }
}


ClearCurrentValue(is_hold, layer:="", *) {
    ToggleFreeze(1)
    new_dtype := !current_path[-1][2] && !is_hold ? TYPES.Default : TYPES.Disabled
    if layer_editing {
        SaveValue(is_hold, selected_layer, new_dtype)
        return
    }

    if ActiveLayers.Length == 1 {
        selected_layers := ActiveLayers.order
    } else {
        layers := []
        checked_node := _GetFirst(is_hold ? gui_entries.uhold : gui_entries.ubase)
        for comb_node in (is_hold ? gui_entries.uhold : gui_entries.ubase).layers.GetAll() {
            if EqualNodes(comb_node[0], checked_node) {
                layers.Push(comb_node[0].layer_name)
            }
        }
        if !layers.Length {
            return
        }
        selected_layers := layers.Length == 1 ? layers : ChooseLayers(layers)
    }

    for layer in selected_layers {
        SaveValue(is_hold, layer, new_dtype)
    }
}


ClearNested(is_hold, layer:="", *) {
    if MsgBox("Do you want to delete all nested assignments?",
        "Confirmation", "YesNo Icon?") == "No" {
        return
    }
    ToggleFreeze(1)

    if layer_editing {
        selected_layers := [selected_layer]
    } else if ActiveLayers.Length == 1 {
        selected_layers := ActiveLayers.GetAll()
    } else {
        layers := []
        checked_node := _GetFirst(is_hold ? gui_entries.uhold : gui_entries.ubase)
        for comb_node in (is_hold ? gui_entries.uhold : gui_entries.ubase).layers.GetAll() {
            if EqualNodes(comb_node[0], checked_node) {
                layers.Push(comb_node[0].layer_name)
            }
        }
        if !layers.Length {
            return
        }
        selected_layers := layers.Length == 1 ? layers : ChooseLayers(layers)
    }

    for layer in selected_layers {
        json_root := DeserializeMap(layer)

        if !json_root.Has(gui_lang) {
            json_root[gui_lang] := ["", Map(), Map(), Map()]
        }
        json_node := _WalkJson(json_root[gui_lang], current_path, is_hold)
        json_node[-3] := Map()
        json_node[-2] := Map()
        json_node[-1] := Map()
        SerializeMap(json_root, layer)
    }

    FillRoots()
    if layer_editing {
        AllLayers.map[selected_layer] := true
        MergeLayer(selected_layer)
    }
    UpdLayers()
    ChangePath()
}


UpdateKeys() {
    prev_lang := false
    if gui_lang {
        prev_lang := GetCurrentLayout()
        if gui_lang !== prev_lang {
            DllCall("ActivateKeyboardLayout", "ptr", gui_lang, "uint", 0)
        } else {
            prev_lang := false
        }
    }

    CreateOverlay()
    FillOther()
    FillPathline()
    FillSetButtons()
    UI.SetFont("Norm")
    FillKeyboard()
    FillLayerTags()
    FillLayers()
    FillGestures()
    FillChords()

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

    if prev_lang {
        DllCall("ActivateKeyboardLayout", "ptr", prev_lang, "uint", 0)
    }
}


HandleKeyPress(sc) {
    global temp_chord

    if sc == 0x038 || sc == 0x138 {  ; unfocus hidden menubar
        Send("{Alt}")
    }

    if is_updating {
        return
    }

    if is_drag_mode {
        PhysicalDrag(sc)
        return
    }

    name := _GetKeyName(sc)
    path := buffer_view ? buffer_path : current_path
    if name == CONF.gui_back_sc.v && path.Length {
        ChangePath(path.Length - 1)
    } else if name == CONF.gui_set_sc.v && UI["BtnBase"].Enabled && UI["BtnBase"].Visible {
        OpenForm(0)
    } else if name == CONF.gui_set_hold_sc.v && UI["BtnHold"].Enabled && UI["BtnHold"].Visible {
        OpenForm(1)
    } else if temp_chord {
        str_sc := String(sc)
        btn := UI.buttons[sc]
        if !btn.Enabled {
            return
        }
        if temp_chord.Has(str_sc) {
            temp_chord.Delete(str_sc)
            FillOneButton(sc, btn, sc)
        } else {
            temp_chord[str_sc] := true
            btn.Opt("+Background" . CONF.selected_chord_color.v)
            btn.Text := btn.Text
        }
    } else if sc == 0x038 || sc == 0x138 {
        SetTimer(AltHelp, 8)
    } else if SubStr(sc, 1, 5) == "Wheel" {
        ButtonLMB(sc)
    } else {
        bnode := _GetFirst(gui_entries.ubase.GetBaseHoldMod(sc, gui_mod_val).ubase)
        is_hold := KeyWait(SC_STR[sc],
            (bnode && bnode.custom_lp_time ? "T" . bnode.custom_lp_time / 1000 : CONF.T))
        if active_hwnd == UI.Hwnd {  ; with postcheck
            is_hold ? ButtonLMB(sc) : ButtonRMB(sc)
        }
    }
}


_GetFirst(node, certain_layer:="", ctx_id:=0) {
    if !node {
        return false
    }

    if !ctx_id {
        ctx_id := gui_proc_ctx
    }

    if buffer_view && node.layers.map.Has("buffer") && node.layers["buffer"][0] {
        return node.layers["buffer"][0]
    }

    if layer_editing || certain_layer {
        layer := certain_layer || selected_layer
        if node.layers[layer] && node.layers[layer][0] {
            return node.layers[layer][0]
        }
        return false
    }

    def := false
    for layer in ActiveLayers.order {
        if node.layers.map.Has(layer) && node.layers[layer][0] {
            n := node.layers[layer][0]

            if !IsNodeAllowedForCtx(n, ctx_id) {
                continue
            }

            if n.down_type == TYPES.Default {
                if !def {
                    def := n
                }
            } else {
                return n
            }
        }
    }
    return def
}


_GetUnholdEntries() {
    path := buffer_view ? buffer_path : current_path
    if path.Length && path[-1][2] & 1 {
        _gui_entries := {
            ubase: ROOTS[buffer_view ? (buffer_view == 1 ? "buffer" : "buffer_h") : gui_lang],
        }
        for arr in path {
            if A_Index !== path.Length {
                _gui_entries := _gui_entries.ubase.GetBaseHoldMod(arr*)
            } else {
                _gui_entries := _gui_entries.ubase.GetBaseHoldMod(
                    arr[1], arr[2] & ~1, arr[3], arr[4]
                )
            }
        }
    } else {
        _gui_entries := gui_entries
    }
    return _gui_entries
}


GetLayerScancodes(unode, layer) {
    return _GetLayerChildren(unode, layer, 0)
}


GetLayerChords(unode, layer) {
    return _GetLayerChildren(unode, layer, 1)
}


GetLayerGestures(unode, layer) {
    return _GetLayerChildren(unode, layer, 2)
}


_GetLayerChildren(unode, layer, field) {
    ; 0 scs, 1 chs, 2 gests
    if !unode || !layer {
        return Map()
    }

    src := !field ? unode.scancodes : field == 1 ? unode.chords : unode.gestures
    res := Map()

    for sc, mods in src {
        for md, child_unode in mods {
            if child_unode.layers.Has(layer) {
                if !res.Has(sc) {
                    res[sc] := Map()
                }
                res[sc][md] := child_unode
            }
        }
    }

    return res
}


CreateOverlay() {
    global overlay

    if overlay {
        _CleanOverlay()
        return
    }

    if CONF.overlay_type.v == 1 {
        return
    }

    overlay := Gui("+AlwaysOnTop +E0x20 -Caption +ToolWindow +Parent" . UI.Hwnd)
    overlay.elems := []
    overlay.Opt("-DPIScale")
    overlay.BackColor := "FFFFFF"
    overlay.SetFont("s" . 6 * CONF.font_scale.v . " cGreen")
    WinSetTransColor("FFFFFF", overlay.Hwnd)
    DllCall("SetWindowLongPtr", "Ptr", overlay.Hwnd, "Int", -8, "Ptr", UI.Hwnd)
    WinGetPos(,, &w, &h, "ahk_id " . UI.Hwnd)
    overlay.Show("x0 y0 w" . w . " h" . h)
}


_CleanOverlay() {
    for elem in overlay.elems {
        try elem.Visible := false
    }
    overlay.elems := []
}


_AddOverlayItem(x, y, colour, txt:="") {
    if !overlay || CONF.overlay_type.v == 1 {
        return false
    }

    if !txt {
        elem := overlay.AddText("x" . x . " y" . y . " " . Scale(,, 3, 3) . " Background" . colour)
    } else {
        elem := overlay.AddText("x" . x . " y" . y . " c" . colour, txt)
    }
    overlay.elems.Push(elem)
    return elem
}


FirstMessage() {
    global welcome

    start := A_TickCount
    welcome_txt := "
    (
    The project is built around event chains – a system where each event can have an assignment and lead to more events.
    Events can be tap, hold, chord, modifier, or gesture, in various combinations and sequences.

    To get started, explore the prebuilt layers in the bottom-left corner.
    Double-click a layer to view it, or enable its checkbox to try it immediately (in another window).

    Most assignments are global, but some are tied to specific keyboard layouts.
    You can switch between them using the dropdown on the right.
    In the GUI they are shown separately, but at runtime global assignments are applied to each layout where not overridden.

    Navigation mirrors the system's structure.
    Left click on keys follows tap events. Right click follows hold events and toggles modifiers.
    You can also navigate using taps and holds on your physical keyboard.
    Double-click follows chords and gestures in their lists.
    The current navigation path is displayed at the top.

    Almost all elements in the main GUI have additional hints. Hold Alt and hover over anything to learn more.

    Feel free to modify existing assignments or add your own using the buttons in the top-right (at non-root levels).
    Gestures (under trigger keys) and chords can be added using the corresponding controls in their lists.

    Before moving on to assignments, take a moment to review the settings.
    Set your keyboard format (ANSI/ISO), choose whether extra key rows are present, and adjust GUI and font scale to your liking.

    Please report any bugs you find, unclear behavior, or suggestions for improvement on GitHub.
    And if you just want to say you enjoyed it, I’d be happy to hear that.
    )"

    welcome := Gui("+AlwaysOnTop -SysMenu", "Welcome")
    welcome.SetFont("s9", "Segoe UI")
    welcome.Add("Text", "x20 y20", welcome_txt)
    welcome.Add("Button", "Center w100 x+-100 y+-20 Default", "Start")
        .OnEvent("Click", _CloseFirstMessage.Bind(start))
    welcome.Show("AutoSize Center")
}


_CloseFirstMessage(timer, *) {
    welcome.Destroy()
    if A_TickCount - timer < 10000 {
        MsgBox("Too fast... Okay`n`nLMB – tap event`nRMB – hold / toggle modifiers"
            . "`nAlt and hover – hints", "._.")
    }
    SetTimer(ShowSettings, -111)
}