USER_DPI := DllCall("user32\GetDpiForSystem", "uint") / 96

AHK_COLORS := Map("Black", "000000", "Silver", "C0C0C0", "Gray", "808080", "White", "FFFFFF",
    "Maroon", "800000", "Red", "FF0000", "Purple", "800080", "Fuchsia", "FF00FF",
    "Green", "008000", "Lime", "00FF00", "Olive", "808000", "Yellow", "FFFF00",
    "Navy", "000080", "Blue", "0000FF", "Teal", "008080", "Aqua", "00FFFF",
)


Scale(x?, y?, w?, h?) {
    return (IsSet(x) ? " x" . Round(x * CONF.gui_scale.v) : "")
         . (IsSet(y) ? " y" . Round(y * CONF.gui_scale.v) : "")
         . (IsSet(w) ? " w" . Round(w * CONF.gui_scale.v) : "")
         . (IsSet(h) ? " h" . Round(h * CONF.gui_scale.v) : "")
}


DrawLayout(init:=false) {
    global UI

    try UI.Destroy()

    UI := Gui(, proj_name)
    UI.Opt("-DPIScale")
    UI.Add("Edit", "x-999 y-999 w0 h0 vHidden")
    UI.path := []
    UI.current_values := []
    UI.main_tags := []  ; active, inactive, sep, first_line_tags*
    UI.extra_tags := []  ; expand?, other_tags*
    UI.buttons := Map()
    UI.SetFont("Norm s" . Round(8 * CONF.font_scale.v))

    DrawOther()
    DrawKeys()
    DrawLayersLV()
    DrawGesturesLV()
    DrawChordsLV()
    DrawCurrentValues()

    uncat := [UI["BtnAddNewLayer"], UI["BtnBackToRoot"]]
    for arr in [
        UI.layer_ctrl_btns, UI.layer_move_btns, UI.chs_back, UI.chs_front,
        UI.gest_btns, UI.drag_btns, UI.buffer, uncat
    ] {
        for btn in arr {
            f := SubStr(btn.Name, 4)
            btn.OnEvent("Click", %f%)
        }
    }

    ToggleVisibility(0, UI.chs_back)
    ToggleVisibility(root_text !== "root", UI["BtnBackToRoot"])
    ToggleVisibility(
        root_text == "root", UI.layer_move_btns, UI.layer_ctrl_btns, UI["BtnAddNewLayer"]
    )

    UI.SetFont("Norm")

    if !init || !CONF.start_minimized.v {
        UI.Show(Scale(,, 1294))
        ChangePath(-1, false)
    }
}


DrawKeys() {
    global ALL_SCANCODES
    static keyboard_layouts:=Map("ANSI", _BuildLayout("ANSI"), "ISO", _BuildLayout("ISO"))

    ALL_SCANCODES := []
    len := keyboard_layouts[CONF.layout_format.v].Length
    x_offset := 10
    y_offset := 50 * CONF.gui_scale.v
    spacing := 5
    height := (CONF.ref_height.v * CONF.gui_scale.v - (spacing * (len - 1)) - y_offset)
        / (CONF.extra_k_row.v ? len - 0.3 : len)

    for row_idx, row in keyboard_layouts[CONF.layout_format.v] {
        y := y_offset
            + (row_idx - (row_idx > 1 && CONF.extra_k_row.v ? 1.3 : 1)) * (height + spacing)
        x := x_offset * 1.0

        for data in row {
            logical_w := data[1]
            w := logical_w * CONF.gui_scale.v

            if data.Length > 1 {
                sc := data[2]
                if sc !== "CurrMod" {
                    ALL_SCANCODES.Push(sc)
                }
                if sc == 0x11D {
                    UI[CONF.layout_format.v == "ISO" ? "54" : "310"].GetPos(&shx, , &shw)
                    w := shx + shw - x * CONF.gui_scale.v + 1
                }

                h := height + (
                    sc == 0x11C || sc == 0x4E || sc == 0x1C && CONF.layout_format.v == "ISO"
                    ? height + spacing : 0
                )
                if row_idx == 1 && CONF.extra_k_row.v {
                    h /= 1.5
                }

                btn := UI.Add("Button",
                    "v" . sc . " x" . x * CONF.gui_scale.v . " y" . y . " w" . w . " h" . h
                    . " +0x8000"
                )
                btn.indicators := []
                UI.buttons[sc] := btn
                if sc !== "CurrMod" {
                    btn.OnEvent("Click", ButtonLMB.Bind(sc))
                    btn.OnEvent("ContextMenu", ButtonRMB.Bind(sc))
                } else {
                    btn.OnEvent("Click", ChangePath.Bind(-1))
                    btn.OnEvent("ContextMenu", ChangePath.Bind(-1))
                }
            }

            x += logical_w + spacing
        }
    }
}


DrawLayersLV() {
    icons := IL_Create(4, 1, false)
    IL_Add(icons, A_ScriptDir . "\ico\cb_blank.ico")
    IL_Add(icons, A_ScriptDir . "\ico\cb_checked.ico")
    IL_Add(icons, A_ScriptDir . "\ico\folder.ico")
    IL_Add(icons, A_ScriptDir . "\ico\back.ico")

    p := Scale(10, CONF.ref_height.v + 29, 425, CONF.ref_height.v)
    UI.AddListView("vLV_layers " . p, ["", "P", "Layer", "Base", "→", "Hold", "→"])
    UI["LV_layers"].OnEvent("DoubleClick", LVLayerDoubleClick)
    UI["LV_layers"].OnEvent("Click", LVLayerClick)
    UI["LV_layers"].OnEvent("ContextMenu", LVLayerClick)
    UI["LV_layers"].SetImageList(icons)

    for i, w in [20, 20, 110, 95, 30, 95, 30] {
        UI["LV_layers"].ModifyCol(i, Max(w * CONF.gui_scale.v, 16 * USER_DPI))
    }
    btns_wh := "w" . (428 * CONF.gui_scale.v / 6) . " h" . (20 * CONF.gui_scale.v)

    for i, arr in [
        ["vBtnAddNewLayer", "✨ New"],
        ["vBtnViewSelectedLayer", "🔍 View"],
        ["vBtnEditSelectedLayer", "✏️ Meta"],
        ["vBtnDeleteSelectedLayer", "🗑️ Delete"],
        ["vBtnMoveUpSelectedLayer", "🔼 Move up"],
        ["vBtnMoveDownSelectedLayer", "🔽 Move dn"]]
    {
        UI.Add("Button", arr[1] . (i == 1 ? " xp0 y+0 " : " x+-1 yp0 ") . btns_wh, arr[2])
    }
    UI.Add("Button", "vBtnBackToRoot " . ("x" . (10 * CONF.gui_scale.v) . " yp0"
        . " w" . (425 * CONF.gui_scale.v)
        . " h" . (20 * CONF.gui_scale.v)
        ), "🔙 Back to all active layers"
    )

    UI["BtnMoveUpSelectedLayer"].OnEvent("ContextMenu", _MoveSelectedLayer.Bind(-1, true))
    UI["BtnMoveDownSelectedLayer"].OnEvent("ContextMenu", _MoveSelectedLayer.Bind(1, true))

    UI.layer_move_btns := [UI["BtnMoveUpSelectedLayer"], UI["BtnMoveDownSelectedLayer"]]
    UI.layer_ctrl_btns := [
        UI["BtnViewSelectedLayer"], UI["BtnEditSelectedLayer"], UI["BtnDeleteSelectedLayer"]
    ]
}


DrawGesturesLV() {
    p := Scale(434, CONF.ref_height.v + 29, 425, CONF.ref_height.v)
    UI.AddListView("vLV_gestures " . p,
        ["Gesture name", "Value", "Options", "→", "Layer", "roll it back"])
    UI["LV_gestures"].OnEvent("DoubleClick", LVGestureDoubleClick)
    UI["LV_gestures"].OnEvent("Click", LVGestureClick)
    for i, w in [110, 110, 95, 30, 65, 0] {
        UI["LV_gestures"].ModifyCol(i, w * CONF.gui_scale.v)
    }

    btns_wh := "w" . (426 * CONF.gui_scale.v / 4) . " h" . (20 * CONF.gui_scale.v)
    UI.gest_btns := []
    UI.gest_btns.Push(
        UI.Add("Button", "vBtnAddNewGesture xp0 y+0 " . btns_wh, "✨ New"),
        UI.Add("Button", "vBtnShowSelectedGesture x+-1 yp0 " . btns_wh, "👀 Show"),
        UI.Add("Button", "vBtnChangeSelectedGesture x+-1 yp0 " . btns_wh, "✏️ Change"),
        UI.Add("Button", "vBtnDeleteSelectedGesture x+-1 yp0 " . btns_wh, "🗑️ Delete")
    )
    UI.gest_toggles := [
        UI["BtnShowSelectedGesture"],
        UI["BtnChangeSelectedGesture"],
        UI["BtnDeleteSelectedGesture"]
    ]
    ToggleEnabled(0, UI.gest_toggles)
}


DrawChordsLV() {
    p := Scale(858.5, CONF.ref_height.v + 29, 425, CONF.ref_height.v)
    UI.AddListView("vLV_chords " . p, ["Chord", "Value", "→", "Layer"])
    UI["LV_chords"].OnEvent("DoubleClick", LVChordDoubleClick)
    UI["LV_chords"].OnEvent("Click", LVChordClick)
    for i, w in [120, 170, 30, 100] {
        UI["LV_chords"].ModifyCol(i, w * CONF.gui_scale.v)
    }

    btns_wh := "w" . (426 * CONF.gui_scale.v / 3) . " h" . (20 * CONF.gui_scale.v)
    UI.Add("Button", "vBtnAddNewChord xp0 y+0 " . btns_wh, "✨ New")
    UI.Add("Button", "vBtnSaveEditedChord xp0 yp0 " . btns_wh, "✔ Save")
    UI.Add("Button", "vBtnChangeSelectedChord x+-1 yp0 " . btns_wh, "✏️ Change")
    UI.Add("Button", "vBtnDiscardChordEditing xp0 yp0 " . btns_wh, "↩ Discard")
    UI.Add("Button", "vBtnDeleteSelectedChord x+-1 yp0 " . btns_wh, "🗑️ Delete")
    UI.Add("Button", "vBtnCancelChordEditing xp0 yp0 " . btns_wh, "❌ Cancel")
    UI.chs_front := [
        UI["BtnAddNewChord"], UI["BtnChangeSelectedChord"], UI["BtnDeleteSelectedChord"]
    ]
    UI.chs_back := [
        UI["BtnSaveEditedChord"], UI["BtnDiscardChordEditing"], UI["BtnCancelChordEditing"]
    ]
    UI.chs_toggles := [UI["BtnChangeSelectedChord"], UI["BtnDeleteSelectedChord"]]
    ToggleEnabled(0, UI.chs_toggles)
}


DrawCurrentValues() {
    UI.SetFont("Norm")
    sh := 255
    UI.current_values.Push(
        UI.Add("Text", Scale(1270 - sh, 0, 50, 23) . " +0x200 Center vTextBase"),
        UI.Add("Text", Scale(1270 - sh, 23, 50, 23) . " +0x200 Center vTextHold"),
        UI.Add("Button", Scale(1325 - sh, 0, 160, 23) . " vBtnBase"),
        UI.Add("Button", Scale(1325 - sh, 23, 160, 23) . " vBtnHold"),
        UI.Add("Button", Scale(1490 - sh, 0, 25, 23) . " vBtnBaseClear", "✕"),
        UI.Add("Button", Scale(1490 - sh, 23, 25, 23) . " vBtnHoldClear", "✕"),
        UI.Add("Button", Scale(1515 - sh, 0, 25, 23) . " vBtnBaseClearNest", "🕳"),
        UI.Add("Button", Scale(1515 - sh, 23, 25, 23) . " vBtnHoldClearNest", "🕳")
    )
    UI["BtnBase"].OnEvent("Click", OpenForm.Bind(0))
    UI["BtnHold"].OnEvent("Click", OpenForm.Bind(1))
    UI["BtnBaseClear"].OnEvent("Click", ClearCurrentValue.Bind(0))
    UI["BtnHoldClear"].OnEvent("Click", ClearCurrentValue.Bind(1))
    UI["BtnBaseClearNest"].OnEvent("Click", ClearNested.Bind(0))
    UI["BtnHoldClearNest"].OnEvent("Click", ClearNested.Bind(1))
    UI["BtnBase"].indicators := []
    UI["BtnHold"].indicators := []

    UI.Add("Button", Scale(1490 - sh, 0, 25, 46) . " vSwapBufferView", "⇕").Visible := false
    UI["SwapBufferView"].OnEvent("Click", SwapBufferView)

    ToggleVisibility(0, UI.current_values)
}


DrawOther() {
    rh := CONF.ref_height.v + 3 * CONF.gui_scale.v

    UI.SetFont("s" . Round(7 * CONF.font_scale.v), CONF.font_name.v)
    UI.Add("DropDownList", "vLangs " . Scale(1125, rh + 1, 104.5), LANGS.GetAll())
    for code, val in LANGS.map {
        if code == gui_lang {
            UI["Langs"].Text := val
        }
    }
    UI["Langs"].OnEvent("Change", (*) => ChangeLang(UI["Langs"].Value))

    UI.SetFont("Norm s" . Round(8 * CONF.font_scale.v))

    UI.Add("DropDownList", Scale(840, rh, 160) " Choose1 vDdlProcCtx")
        .OnEvent("Change", GuiProcCtxChanged)

    UI.Add("Button", "vBtnEnableDragMode " . Scale(1015, rh, 26, 20), "🔀")
    UI.Add("Button", "vBtnShowBuffer " . Scale(1041, rh, 26, 20), "👁").OnEvent("Click", ShowBuffer)
    UI.Add("Button", "vBtnShowCopyMenu " . Scale(1067, rh, 26, 20), "⧉")
    UI.Add("Button", "vBtnShowPasteMenu " . Scale(1093, rh, 26, 20), "📋")
    UI.buffer := [UI["BtnShowCopyMenu"], UI["BtnShowPasteMenu"]]
    ToggleEnabled(false, UI.buffer)

    UI.Add("Button", "vBtnCancelDrag " . Scale(1015, rh, 45, 20), "Cancel").Visible := false
    UI.Add("Button", "vBtnSaveDrag " . Scale(1060, rh, 45, 20), "Save").Visible := false
    UI.Add("Button", "vBtnShowSaveOptionsMenu " . Scale(1105, rh, 15, 20), "▾").Visible := false
    UI.drag_btns := [UI["BtnEnableDragMode"], UI["BtnCancelDrag"], UI["BtnSaveDrag"],
        UI["BtnShowSaveOptionsMenu"]]

    UI.Add("Text", "Center vSettings " . Scale(1235, rh + 1, 50, 20), "🔧")
        .OnEvent("Click", ShowSettings)

    UI.save_options_menu := Menu()
    UI.save_options_menu.Add("Save for current lang and mod value (default)",
        SaveDrag.Bind(, false, false))
    UI.save_options_menu.Add("Save for all langs", SaveDrag.Bind(, false, true))
    UI.save_options_menu.Add("Save for all modifiers", SaveDrag.Bind(, true, false))
    UI.save_options_menu.Add("Save for all modifiers and all langs", SaveDrag.Bind(, true, true))
    UI.save_options_menu.Add()
    UI.save_options_menu.Add("Help", (*) => (SetTimer(MsgBox.Bind("You are in drag"
        . " and drop mode.`nTo swap two keys, drag the desired key to the new position with the "
        . "LMB and these keys will exchange assignments as well as all child elements and their "
        . "participation in chords.`nYou can also use the keys on your physical keyboard to "
        . "perform transpositions.`n`nAfter the necessary transpositions have been performed, save"
        . " the view, or cancel the transpositions and return to the original view.`nBy default, "
        . "saving is performed only for the current view (in the current language layout and with "
        . "current value of the modifier/s), but you can choose additional "
        . "saving options, extending transpositions to hidden values as well. Be careful."
        . "`n`nUntil you exit drag mode, you cannot move between assignment levels or toggle "
        . "modifiers. Finish the changes for the current view first."
        . "`n`n⚠ When dragging, you cannot swap values from keys with inappropriate types, e.g. "
        . "system modifier keys can only contain custom modifiers on hold, and mouse wheel events "
        . "and a row of “office” keys can only have tap assignments, without any hold assignments."
        . "`n`n⚠ The exchange happens exactly for the additional assignments, set in this program."
        . " The values from your basic keyboard layout (both no custom assignment and assignments "
        . "with the “Default” type) are kept unchanged.", "Drag&Drop help"), -1)))

    UI.copy_options_menu := Menu()
    UI.copy_options_menu.Add(
        "Copy the current view", CopyLevel.Bind(, 0)
    )
    UI.copy_options_menu.Add(
        "Copy the entire level (with all hidden in other mods)", CopyLevel.Bind(, 1)
    )
    UI.copy_options_menu.Add(
        "Copy the extended level (with hidden in adjacent hold)", CopyLevel.Bind(, 2)
    )

    UI.paste_options_menu := Menu()
    UI.paste_options_menu.Add(
        "Append (paste only new assignments, recursively)", PasteLevel.Bind(, 0)
    )
    UI.paste_options_menu.Add(
        "Merge (paste all assignments with replacement)", PasteLevel.Bind(, 1)
    )
    UI.paste_options_menu.Add(
        "Replace (fully replace the level/view)", PasteLevel.Bind(, 2)
    )
    UI.paste_options_menu.Add()
    UI.paste_options_menu.Add(
        "Replaced (remaining for 'append') values will be stored in the buffer", (*) => 0
    )
    UI.paste_options_menu.Disable("5&")
    UI.paste_options_menu.Check("5&")
}


_BuildLayout(layout) {
    w := 42
    res := []
    if CONF.extra_k_row.v {
        res.Push(R(
            [85], [w, GetKeySC("Volume_Mute")], [w, GetKeySC("Volume_Down")],
            [w, GetKeySC("Volume_Up")], [w, GetKeySC("Media_Next")], [w, GetKeySC("Media_Prev")],
            [w, GetKeySC("Media_Stop")], [w, GetKeySC("Media_Play_Pause")],
            [25], [w, GetKeySC("Browser_Back")], [w, GetKeySC("Browser_Forward")],
            [w, GetKeySC("Browser_Refresh")], [w, GetKeySC("Browser_Stop")],
            [w, GetKeySC("Browser_Search")], [w, GetKeySC("Browser_Favorites")],
            [w, GetKeySC("Browser_Home")],
            [24], [w, GetKeySC("Launch_Mail")], [w, GetKeySC("Launch_Media")],
            [w, GetKeySC("Launch_App1")], [w, GetKeySC("Launch_App2")]
        ))
    }
    if CONF.extra_f_row.v {  ; f13-f24
        res.Push(R([85], 100, 101, 102, 103, [30], 104, 105, 106, 107, [30], 108, 109, 110, 118))
    }

    res.Push(  ; f-row, numrow
        R(1, [30], 59, 60, 61, 62, [30], 63, 64, 65, 66, [30], 67, 68, 87, 88, [5], 311, 70, 69,
            [5], "LButton", "RButton", "XButton1", "XButton2", "CurrMod"),
        R(41, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, [100, 14], [5], 338, 327, 329,
            [5], 325, 309, 55, 74, "WheelRight")
    )

    if layout == "ANSI" {  ; tab…, caps…, shift…
        res.Push(
            R([75, 15], 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, [75, 43],
                [5], 339, 335, 337,[5], 71, 72, 73, 78, "WheelUp"),
            R([90, 58], 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, [115, 28],
                [180], 75, 76, 77, [50], "MButton"),
            R([120, 42], 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, [140, 310],
                [60], 328, [60], 79, 80, 81, 284, "WheelDown")
        )
    } else {
        res.Push(
            R([75, 15], 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, [10], [60, 28],
                [5], 339, 335, 337, [5], 71, 72, 73, 78, "WheelUp"),
            R([90, 58], 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 43, [245],
                75, 76, 77, [50], "MButton"),
            R([70, 42], 86, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, [135, 54],
                [60], 328, [60], 79, 80, 81, 284, "WheelDown")
        )
    }

    res.Push(  ; ctrl…
        R([70, 29], [70, 347], [70, 56], [325, 57], [60, 312], [60, 348], [60, 349], [65, 285],
            [5], 331, 336, 333, [5], [105, 82], 83, [50], "WheelLeft")
    )

    return res
}


R(args*) {
    res := []
    for arg in args {
        res.Push(arg is Array ? arg : [50, arg])
    }
    return res
}