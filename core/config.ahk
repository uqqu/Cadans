CoordMode "Mouse", "Screen"

proj_name := "Cadans"
A_HotkeyInterval := 0
version := 0
s_gui := false
is_updating := false
pending_event := false
settings_int_stepper_vals := Map()
settings_int_stepper_guards := Map()

static_lang_names := Map(
    67699721, "qwerty en",
    68748313, "йцукен ru",
    -255851511, "qPhyx en",
    -255785959, "юПхыя ru"
)

saved_level := false
buffer_view := 0

CONF := {
    Main: [],
    GUI: [],
    Gestures: [],
    GestureGeneral: [],
    GestureIdle: [],
    GestureLiveHint: [],
    GestureColorSettings: [],
    GestureZones: [],
    GestureDefaults: [],
    Colors: [],
    UserDefined: Map(),
    ProcessGroups: Map(),
    LayoutAliases: DefaultKeyMap()
}

SYS_MODIFIERS := Map(
    0x02A, "<+",
    0x036, ">+",  ; ANSI
    0x136, ">+",  ; ISO
    0x01D, "<^",
    0x11D, ">^",
    0x038, "<!",
    0x138, ">!",
    0x15B, "<#",
    0x15C, ">#"
)

AWMods := Map(56, 0, 312, 0, 347, 0, 348, 0)

NUM_VK := Map(
    0x047, ["vk67", "vk24"],  ; 7 / Home
    0x048, ["vk68", "vk26"],  ; 8 / Up
    0x049, ["vk69", "vk21"],  ; 9 / PgUp
    0x04B, ["vk64", "vk25"],  ; 4 / Left
    0x04C, ["vk65", "vk0C"],  ; 5 / Clear
    0x04D, ["vk66", "vk27"],  ; 6 / Right
    0x04F, ["vk61", "vk23"],  ; 1 / End
    0x050, ["vk62", "vk28"],  ; 2 / Down
    0x051, ["vk63", "vk22"],  ; 3 / PgDn
    0x052, ["vk60", "vk2D"],  ; 0 / Insert
    0x053, ["vk6E", "vk2E"]   ; . / Delete
)

ONLY_BASE_SCS := Map()
SC_STR := Map()
unstable_sc := Map()
manual_hold := Map()

GestureColorZones := [
    [1, "TL"], [2, "T"], [3, "TR"], [4, "L"], [5, "C"], [6, "R"], [7, "BL"],
    [8, "B"], [9, "BR"], ["a", "CA"], ["b", "CB"], ["c", "CC"], ["d", "CD"]
]
LiveHintPositionChoices := [
    "Top left", "Top", "Top right", "Left", "Center", "Right", "Bottom left", "Bottom", "Bottom right"
]
IdleFeedbackModeChoices := ["Off", "Ring", "Pie", "Shrink", "Bar"]

for name in ["Volume_Mute", "Volume_Down", "Volume_Up", "Media_Next", "Media_Prev", "Media_Stop",
    "Media_Play_Pause", "Browser_Back", "Browser_Forward", "Browser_Refresh", "Browser_Stop",
    "Browser_Search", "Browser_Favorites", "Browser_Home", "Launch_Mail", "Launch_Media",
    "Launch_App1", "Launch_App2"] {
    SC_STR[name] := name
    unstable_sc[GetKeySC(name)] := true
    manual_hold[name] := true
}

for name in ["WheelLeft", "WheelDown", "WheelUp", "WheelRight"] {
    ONLY_BASE_SCS[name] := true
}

TYPES := {}
TYPES_R := ["Disabled", "Default", "Text", "KeySimulation", "Function", "Modifier", "Chord"]
for i, v in TYPES_R {
    TYPES.%v% := i
}

for vk in [
    "vk24", "vk67", "vk26", "vk68", "vk21", "vk69", "vk25", "vk64", "vk0C", "vk65", "vk27",
    "vk66", "vk23", "vk61", "vk28", "vk62", "vk22", "vk63", "vk2D", "vk60", "vk2E", "vk6E"] {
    SC_STR[vk] := vk
}


SC_STR_BR := []
loop 511 {
    if unstable_sc.Has(A_Index) {
        continue
    }
    curr := Format("SC{:03X}", A_Index)
    SC_STR[A_Index] := curr
    SC_STR_BR.Push("{" . curr . "}")
}

for key in [
    "LButton", "RButton", "MButton", "XButton1", "XButton2",
    "WheelUp", "WheelDown", "WheelLeft", "WheelRight"
] {
    SC_STR[key] := key
    unstable_sc[GetKeySC(key)] := true
}

LANGS := OrderedMap()
LANGS.Add(0, "Global assignments")

first_start := CheckConfig()
current_layout := CONF.LayoutAliases[GetCurrentLayout()]
Refresh()

ErrorHandler(err, mode) {
    Suspend true
    FileAppend(
        Format("{1}`n{2}`n`n", err.Message, err.Stack),
        A_ScriptDir . "\error_log.txt"
    )
    return false
}


class ConfValue {
    __New(
        sect, ini_name, form_type, val_type, descr, default_val, placeholder:=false,
        is_num:=false, double_height:=false, extra:=false, ui_group:=false, empty_policy:="default"
    ) {
        this.ini_name := ini_name
        this.form_type := form_type
        this.val_type := val_type
        this.default := default_val
        this.descr := descr
        this.placeholder := placeholder || ""
        this.is_num := is_num
        this.double_height := double_height
        this.extra_params := extra || []
        this.empty_policy := empty_policy

        this.v := IniRead("config.ini", sect, ini_name, default_val)

        if val_type == "int" {
            this.v := Integer(this.v)
        } else if val_type == "float" {
            this.v := Round(Float(this.v), 2)
        }
        CONF.%sect%.Push(this)
        if ui_group {
            CONF.%ui_group%.Push(this)
        }
    }
}


CheckConfig() {
    if !FileExist("config.ini") {
        FileAppend(
            "[Main]`r`n"
            . "ActiveLayers=Personal`r`n"
            . "UserLayouts=`r`n"
            . "ChosenTags=Active, Inactive`r`n"
            . "`r`n[GUI]`r`n"
            . "`r`n[Gestures]`r`n"
            . "`r`n[GestureLiveHint]`r`n"
            . "`r`n[GestureZones]`r`n"
            . "`r`n[GestureDefaults]`r`n"
            . "`r`n[Colors]`r`n"
            . "`r`n[UserDefined]`r`n"
            . "OpenWeatherMapApi=`r`n"
            . "GetGeoApi=`r`n"
            . "`r`n[ProcessGroups]`r`n"
            . "browsers=firefox.exe, chrome.exe, msedge.exe, opera.exe, brave.exe, vivaldi.exe`r`n"
            . "editors=notepad.exe, notepad++.exe, sublime_text.exe, code.exe, atom.exe`r`n"
            . "ide=idea64.exe, pycharm64.exe, webstorm64.exe, clion64.exe, devenv.exe`r`n"
            . "terminals=cmd.exe, powershell.exe, wt.exe, WindowsTerminal.exe, alacritty.exe`r`n"
            . "messengers=telegram.exe, discord.exe, slack.exe, whatsapp.exe`r`n"
            . "design=photoshop.exe, illustrator.exe, figma.exe, blender.exe`r`n"
            . "media=vlc.exe, mpc-hc.exe, mpv.exe, spotify.exe, aimp.exe`r`n"
            . "files=totalcmd.exe, doublecmd.exe`r`n"
            . "games=h3hota hd.exe, mewgenics.exe`r`n"
            . "`r`n[LayoutAliases]`r`n"
            , "config.ini"
        )
    }
    DirCreate("layers")


    CONF.MS_LP := ConfValue("Main", "LongPressDuration", "num_step", "int",
        "&Hold threshold (ms):", 150, , true, , [0, 9999, 1, 5])
    CONF.MS_NK := ConfValue("Main", "NextKeyWaitDuration", "num_step", "int",
        "&Nested event timeout (ms):", 300, , true, , [0, 9999, 1, 5])

    CONF.T := "T" . CONF.MS_LP.v / 1000

    CONF.layout_format := ConfValue("Main", "LayoutFormat", "ddl", "str",
        "&Layout format:", "ANSI", , , , [["ANSI", "ISO"], true])
    CONF.interruption_behavior := ConfValue("Main", "InterruptionBehavior", "ddl", "int",
        "&Tap/hold interruption behavior:", 1, , ,
        , [["Ordered / await result", "Send tap", "Send hold"], false])
    CONF.dual_numpad := ConfValue("Main", "DualNumpad", "checkbox", "int",
        "&Split NumPad keys", 0)
    CONF.extra_f_row := ConfValue("Main", "ExtraFRow", "checkbox", "int",
        "Use extra &f-row (F13-F24)", 0)
    CONF.extra_k_row := ConfValue("Main", "ExtraKRow", "checkbox", "int",
        "&Use special keys (media, browser, app keys)", 0)
    CONF.unfam_layouts := ConfValue("Main", "CollectUnfamiliarLayouts", "checkbox", "int",
        "&Collect unknown keyboard layouts from layers", 1)
    CONF.sendtext_output := ConfValue("Main", "UseSendTextOutput", "h_checkbox", "int",
        "Use S&endText mode", 0, , ,
        , ["Temporary test option."
            . "`nTo minimize bugs with sticking and inputting unwanted characters "
            . "when over-holding a hotkey with long text assignment, the SendInput {Raw} is "
            . "currently in test use. If this leads to undesirable consequences, turn on this "
            . "option to return to usual SendText and report to Issues.`n"
            . "Don't turn it on unless you're sure you need it.", "Use SendText mode"
        ])
    CONF.ignore_inactive := ConfValue("Main", "IgnoreInactiveLayers", "h_checkbox", "int",
        "&Ignore inactive layers", 0, , ,
        , ["With this option enabled, inactive layers are not parsed`ninto the core data structure."
            . "`nDisable it temporarily when using the GUI to view assignments`nacross all layers."
            . "`nRe-enable it after adjusting the layers, to speed up the tree recalculation,"
            . " if you have a lot of layers.", "Ignore inactive layers"
        ])
    CONF.start_minimized := ConfValue("Main", "StartMinimized", "checkbox", "int",
        "Start &minimized", 0)
    CONF.autostart := ConfValue("Main", "Autostart", "checkbox", "int",
        "Start with &Windows", 0)

    CONF.keyname_type := ConfValue("GUI", "KeynameType", "ddl", "int",
        "&Keyname type:", 1, , ,
        , [["Always use keynames", "Always use scancodes", "Scancodes on empty keys"], false])
    CONF.overlay_type := ConfValue("GUI", "OverlayType", "ddl", "int",
        "&Overlay indicator type:", 3, , ,
        , [["Disabled", "Indicators only", "With counters"], false])
    CONF.font_name := ConfValue("GUI", "FontName", "str", "str",
        "Font &name:", "Segoe UI")
    CONF.ref_height := ConfValue("GUI", "ReferenceHeight", "num_step", "int",
        "&Reference height:", 314, , true, , [0, 9999, 1])
    CONF.gui_scale := ConfValue("GUI", "GuiScale", "num_step", "float",
        "&Gui scale:", A_ScreenWidth * 0.8 / 1294, , , , [0, 999, 100])
    CONF.font_scale := ConfValue("GUI", "FontScale", "num_step", "float",
        "&Font scale:", CONF.gui_scale.v / 2 + 0.5, , , , [0, 999, 100])
    CONF.gui_back_sc := ConfValue("GUI", "GuiBackEdit", "str", "str",
        "GUI hotkey for '&Back':", "nSub", , , , , , "allow")
    CONF.gui_set_sc := ConfValue("GUI", "GuiSetEdit", "str", "str",
        "GUI hotkey for 'Set &tap':", "nAdd", , , , , , "allow")
    CONF.gui_set_hold_sc := ConfValue("GUI", "GuiSetHoldEdit", "str", "str",
        "GUI hotkey for 'Set &hold':", "nEnter", , , , , , "allow")
    CONF.hide_alias_warnings := ConfValue("GUI", "HideAliasWarnings", "checkbox", "int",
        "Hide &warnings about changes in aliased layouts", 0)

    CONF.gest_color_mode := ConfValue("Gestures", "ColorMode", "ddl", "str",
        "Color &mode:", "HSV", , , , [["RGB", "Gamma-correct", "HSV"], true], "GestureColorSettings")

    CONF.gest_center_mode := ConfValue("GestureZones", "CenterMode", "ddl", "str",
        "Center zone &mode:", "Single", , ,
        , [["Single", "Grid", "Diagonal"], true])
    CONF.gest_zone_t := ConfValue("GestureZones", "Top", "str", "int",
        "&Top edge size (px):", 100, , true)
    CONF.gest_zone_r := ConfValue("GestureZones", "Right", "str", "int",
        "&Right edge size (px):", 100, , true)
    CONF.gest_zone_b := ConfValue("GestureZones", "Bottom", "str", "int",
        "&Bottom edge size (px):", 128, , true)
    CONF.gest_zone_l := ConfValue("GestureZones", "Left", "str", "int",
        "&Left edge size (px):", 100, , true)
    CONF.gest_zone_tl := ConfValue("GestureZones", "TopLeft", "str", "int",
        "Top-&left corner size (px):", 150, , true)
    CONF.gest_zone_tr := ConfValue("GestureZones", "TopRight", "str", "int",
        "Top-&right corner size (px):", 150, , true)
    CONF.gest_zone_br := ConfValue("GestureZones", "BottomRight", "str", "int",
        "Bottom-r&ight corner size (px):", 150, , true)
    CONF.gest_zone_bl := ConfValue("GestureZones", "BottomLeft", "str", "int",
        "Bottom-l&eft corner size (px):", 150, , true)
    CONF.gest_zone_preview_color := ConfValue("GestureZones", "PreviewColor", "color", "str",
        "Zone preview color:", "00F4AA")

    CONF.min_gesture_len := ConfValue("Gestures", "MinGestureLen", "num_step", "int",
        "Mi&nimum gesture length (px):", 150, , true, , [0, 9999, 1], "GestureGeneral")
    CONF.min_cos_similarity := ConfValue("Gestures", "MinCosSimilarity", "num_step", "float",
        "Minimum gesture &similarity:", 0.90, , , , [0, 100, 100], "GestureGeneral")
    CONF.gest_opacity := ConfValue("Gestures", "GestureOpacity", "num_step", "int",
        "Gesture &opacity (cumulative):", 42, , true, , [0, 9999, 1], "GestureGeneral")
    CONF.gesture_idle_cancel_ms := ConfValue("Gestures", "GestureIdleCancel", "num_step", "int",
        "&Unrecognized pause cancel (ms):", 1000, "0 - disabled", true, , [0, 9999, 1], "GestureIdle")
    CONF.gesture_idle_confirm_ms := ConfValue("Gestures", "GestureIdleConfirm", "num_step", "int",
        "&Recognized child pause confirm (ms):", 600, "0 - disabled", true, , [0, 9999, 1], "GestureIdle")
    CONF.gesture_idle_cancel_mode := ConfValue("Gestures", "GestureIdleCancelMode", "ddl", "int",
        "C&ancel pause feedback:", 2, , , , [IdleFeedbackModeChoices, false], "GestureIdle")
    CONF.gesture_idle_confirm_mode := ConfValue("Gestures", "GestureIdleConfirmMode", "ddl", "int",
        "C&onfirm pause feedback:", 3, , , , [IdleFeedbackModeChoices, false], "GestureIdle")
    CONF.gesture_idle_cancel_color := ConfValue("Gestures", "GestureIdleCancelColor", "color", "str",
        "Ca&ncel feedback color:", "C40000", , , , , "GestureIdle")
    CONF.gesture_idle_confirm_color := ConfValue("Gestures", "GestureIdleConfirmColor", "color", "str",
        "Con&firm feedback color:", "Green", , , , , "GestureIdle")
    CONF.gesture_idle_feedback_size := ConfValue("Gestures", "GestureIdleFeedbackSize", "num_step", "int",
        "Feedback &box size (px):", 72, , true, , [24, 240, 1], "GestureIdle")
    CONF.live_hint_enabled := ConfValue("GestureLiveHint", "LiveHintEnabled", "checkbox", "int",
        "&Enable live hint", 1)
    CONF.gest_live_hint := ConfValue("GestureLiveHint", "LiveHint", "ddl", "int",
        "Live recognition hint &position:", 5, , ,
        , [LiveHintPositionChoices, false])
    CONF.live_hint_alt := ConfValue("GestureLiveHint", "LiveHintAlt", "ddl", "int",
        "&Alternative live hint position:", 9, , , , [LiveHintPositionChoices, false])
    CONF.font_size_lh := ConfValue("GestureLiveHint", "LHSize", "num_step", "int",
        "Live hint &font size:", 32, , true, , [0, 999, 1])
    CONF.live_hint_start_count := ConfValue("GestureLiveHint", "LiveHintStartCount", "num_step", "int",
        "&Start hint items:", 9, "0 – hide start hints", true, , [0, 999, 1])
    CONF.live_hint_start_move := ConfValue("GestureLiveHint", "LiveHintStartMove", "num_step", "int",
        "Start hint minimum &movement (px):", 1, "0 – show immediately", true, , [0, 999, 1])
    CONF.live_hint_move_count := ConfValue("GestureLiveHint", "LiveHintMoveCount", "num_step", "int",
        "Moving hint max i&tems:", 6, "0 – hide moving hints", true, , [0, 999, 1])
    CONF.live_hint_min_score := ConfValue("GestureLiveHint", "LiveHintMinScore", "num_step", "float",
        "Mo&ving hint minimum match:", 0.50, "0–1", , , [0, 100, 100])
    CONF.live_hint_opacity := ConfValue("GestureLiveHint", "LiveHintOpacity", "num_step", "int",
        "Live hint background &opacity:", 222, , true, , [0, 255, 1])
    CONF.live_hint_box_width := ConfValue("GestureLiveHint", "LiveHintBoxWidth", "num_step", "str",
        "Live hint box &width (px):", "", "Empty – adaptive width", true, , [0, 999, 1], , "allow")
    CONF.live_hint_margin := ConfValue("GestureLiveHint", "LiveHintMargin", "num_step", "int",
        "Live hint edge ma&rgin (px):", 0, , true, , [0, 999, 1])
    CONF.live_hint_bg_color := ConfValue("GestureLiveHint", "LiveHintBgColor", "color", "str",
        "Live hint &background:", "222222", "Empty – no background", , , , , "allow")
    CONF.live_hint_text_color := ConfValue("GestureLiveHint", "LiveHintTextColor", "color", "str",
        "Live hint te&xt color:", "D8D8D8")
    CONF.live_hint_thumbnail_color := ConfValue("GestureLiveHint", "LiveHintThumbnailColor", "m_color", "str",
        "Live hint t&humbnail color:", "", "Empty – own gesture color", , , , , "allow")
    CONF.gest_thumbnail_color := ConfValue("Gestures", "ThumbnailColor", "m_color", "str",
        "Gesture list &thumbnail color:", "", "Empty – own gesture color", , , , "GestureGeneral", "allow")
    CONF.gest_pool_marker_color := ConfValue("Gestures", "PoolMarkerColor", "color", "str",
        "Pool &marker color in the list:", "47CD7C", , , , , "GestureGeneral")
    CONF.shake_cancel_samples := ConfValue("Gestures", "ShakeCancelSamples", "num_step", "int",
        "S&hake cancel samples:", 32, , true, , [4, 999, 1], "GestureGeneral")
    CONF.shake_cancel_box := ConfValue("Gestures", "ShakeCancelBox", "num_step", "int",
        "Sh&ake cancel max box (px):", 256, , true, , [1, 999, 1], "GestureGeneral")
    CONF.shake_cancel_len := ConfValue("Gestures", "ShakeCancelLength", "num_step", "int",
        "Sha&ke cancel path length (px):", 192, , true, , [1, 9999, 1], "GestureGeneral")
    CONF.shake_cancel_turns := ConfValue("Gestures", "ShakeCancelTurns", "num_step", "int",
        "Shak&e cancel turns:", 4, , true, , [1, 99, 1], "GestureGeneral")
    CONF.shake_cancel_enabled := ConfValue("Gestures", "ShakeCancelEnabled", "checkbox", "int",
        "Cancel &gesture by shaking", 1, , , , , "GestureGeneral")
    CONF.show_unavailable_gestures := ConfValue("Gestures", "ShowUnavailableGestures", "checkbox", "int",
        "Show gestures from unavailable &pools in the list", 1, , , , , "GestureGeneral")

    CONF.gest_zone_colors := Map()
    CONF.gest_zone_grad_len := Map()
    CONF.gest_zone_grad_loop := Map()
    gesture_color_defaults := Map(
        1, {colors: "7B1FA2,00E5FF", grad_len: 640, grad_loop: 1},
        2, {colors: "00BCD4,8BC34A,FFEB3B", grad_len: 820, grad_loop: 1},
        3, {colors: "D500F9,FFEA00", grad_len: 640, grad_loop: 1},
        4, {colors: "651FFF,00E5FF,00C853", grad_len: 820, grad_loop: 1},
        5, {colors: "random(3)", grad_len: 950, grad_loop: 0},
        6, {colors: "FFEA00,FF6D00,D50000", grad_len: 820, grad_loop: 1},
        7, {colors: "304FFE,FF1744", grad_len: 640, grad_loop: 1},
        8, {colors: "3F51B5,9C27B0,F44336", grad_len: 820, grad_loop: 1},
        9, {colors: "00C853,FF1744", grad_len: 640, grad_loop: 1},
        "a", {colors: "00ACC1", grad_len: 600, grad_loop: 0},
        "b", {colors: "FDD835", grad_len: 600, grad_loop: 0},
        "c", {colors: "E53935", grad_len: 600, grad_loop: 0},
        "d", {colors: "5E35B1", grad_len: 600, grad_loop: 0},
    )
    for zone in GestureColorZones {
        defaults := gesture_color_defaults[zone[1]]
        CONF.gest_zone_colors[zone[2]] := ConfValue("GestureDefaults",
            "GestureColorsPool" . zone[2], "m_color", "str",
            "Ges&ture colors`n(more than one for gradient):",
            defaults.colors, , , true)
        CONF.gest_zone_grad_len[zone[2]] := ConfValue("GestureDefaults",
            "GradientLengthPool" . zone[2], "str", "int",
            "&Full gradient cycle length (px):", defaults.grad_len, , true)
        CONF.gest_zone_grad_loop[zone[2]] := ConfValue("GestureDefaults",
            "GradientLoopPool" . zone[2], "checkbox", "int",
            "G&radient cycling", defaults.grad_loop)
    }

    CONF.default_assigned_color := ConfValue("Colors", "DefaultAssigned", "color", "str",
        "Default &assigned:", "Silver")
    CONF.default_unassigned_color := ConfValue("Colors", "DefaultUnssigned", "color", "str",
        "Default &unassigned (empty):", "White")
    CONF.chord_part_color := ConfValue("Colors", "ChordPart", "color", "str",
        "&Part of chord:", "BBBB22")
    CONF.selected_chord_color := ConfValue("Colors", "SelectedChord", "color", "str",
        "Selected/editing &chord:", "4D47B8")
    CONF.has_gestures_color := ConfValue("Colors", "HasNestedGestures", "color", "str",
        "Has nested &gestures:", "Red")
    CONF.modifier_color := ConfValue("Colors", "Modifier", "color", "str",
        "&Modifier:", "7777AA")
    CONF.active_modifier_color := ConfValue("Colors", "ActiveModifier", "color", "str",
        "Active mo&difier:", "Black")

    CONF.changed_name_ind_color := ConfValue("Colors", "ChangedName", "color", "str",
        "Custom GUI &name:", "Silver")
    CONF.irrevocable_ind_color := ConfValue("Colors", "Irrevocable", "color", "str",
        "&Irrevocable:", "E1E1E1")
    CONF.instant_ind_color := ConfValue("Colors", "Instant", "color", "str",
        "Ins&tant:", "Teal")
    CONF.additional_up_ind_color := ConfValue("Colors", "AdditionalUp", "color", "str",
        "Additional &key-up action:", "Blue")
    CONF.custom_hold_time_ind_color := ConfValue("Colors", "CustomHold", "color", "str",
        "Custom &hold threshold:", "Purple")
    CONF.custom_child_time_ind_color := ConfValue("Colors", "CustomNested", "color", "str",
        "Custom nested e&vent timeout:", "Fuchsia")
    CONF.node_window_rule_ind_color := ConfValue("Colors", "NodeWindowRule", "color", "str",
        "Custom &window rule:", "Aqua")
    CONF.nested_counter_ind_color := ConfValue("Colors", "NestedCounter", "color", "str",
        "N&ested assignment counter:", "Green")

    CONF.tags := Map()
    for tag in StrSplit(IniRead("config.ini", "Main", "ChosenTags", "Active, Inactive"), ",") {
        tag := Trim(tag)
        if SubStr(tag, 1, 1) == "-" {
            CONF.tags[SubStr(tag, 2)] := false
        } else {
            CONF.tags[tag] := true
        }
    }

    CollectUserValues()

    if !IniRead("config.ini", "Main", "UserLayouts", "") {
        GetActiveHKLs()
        return true
    }
    GetActiveHKLs()

    for lang in StrSplit(IniRead("config.ini", "Main", "UserLayouts"), ",") {
        lang := Integer(Trim(lang))
        if CONF.LayoutAliases.Has(lang) {
            l := CONF.LayoutAliases[lang]
            if !LANGS.Has(l) {
                LANGS.Add(l, GetLayoutNameFromHKL(l))
            }
        }
        if !LANGS.Has(lang) {
            LANGS.Add(lang, GetLayoutNameFromHKL(lang))
        }
    }
}


CollectUserValues() {
    for name in ["UserDefined", "ProcessGroups", "LayoutAliases"] {
        i := A_Index
        CONF.%name% := i == 3 ? DefaultKeyMap() : Map()

        user_values := IniRead("config.ini", name, , false)
        if user_values {
            for line in StrSplit(user_values, "`n", "`r") {
                if !line {
                    continue
                }

                p := InStr(line, "=")
                if !p {
                    continue
                }

                key := SubStr(line, 1, p - 1)
                val := SubStr(line, p + 1)
                if i == 3 {
                    CONF.%name%[Integer(key)] := Integer(val)
                } else {
                    CONF.%name%[key] := val
                }
            }
        }
    }
}


GetActiveHKLs(*) {
    global LANGS

    n := DllCall("GetKeyboardLayoutList", "int", 0, "ptr", 0, "int")
    if n <= 0 {
        return []
    }

    buf := Buffer(A_PtrSize * n, 0)
    DllCall("GetKeyboardLayoutList", "int", n, "ptr", buf.Ptr, "int")

    LANGS := OrderedMap()
    LANGS.Add(0, "Global assignments")

    loop n {
        hkl := NumGet(buf, (A_Index - 1) * A_PtrSize, "uptr")
        LANGS.Add(hkl, GetLayoutNameFromHKL(hkl))
    }
    str_value := ""
    for lang in LANGS.map {
        if lang {
            str_value .= lang . ", "
        }
    }
    IniWrite(SubStr(str_value, 1, -2), "config.ini", "Main", "UserLayouts")
}


ShowSettings(*) {
    global s_gui

    try s_gui.Destroy()

    s_gui := Gui("-SysMenu", "Settings")
    s_gui.OnEvent("Close", CloseSettingsEvent)
    s_gui.OnEvent("Escape", EscSettingsEvent)
    s_gui.SetFont("s9")

    s_gui.UserDefined := []
    s_gui.ProcessGroups := []
    s_gui.LayoutAliases := []
    s_gui.GestureGeneral := []
    s_gui.GestureIdle := []
    s_gui.GestureLiveHint := []
    s_gui.GestureColors := []
    s_gui.GestureColorFixed := []
    s_gui.GestureColorMapButtons := []
    s_gui.GestureZones := []
    s_gui.GestureColorGroups := Map()
    s_gui.SelectedGestureColorZone := "C"
    s_gui.GestureColorMapMode := ""
    s_gui.ZonePreviewMode := "Blink"
    s_gui.CurrentGroup := false
    s_gui.ApplyRestartWarningShown := false

    s_gui.Add("Button", "Center x238 y0 w60 h18 vCancel", "❌ Cancel")
        .OnEvent("Click", CloseSettingsEvent)
    s_gui.Add("Button", "Center x298 y0 w60 h18 Default vSave", "💾 Save")
        .OnEvent("Click", SaveConfig.Bind(true))
    s_gui.Add("Button", "Center x358 y0 w60 h18 vApply", "✔ Apply")
        .OnEvent("Click", SaveConfig.Bind(false))

    tabs := s_gui.Add("Tab3", "x0 y0 w422 h666",
        ["Main", "GUI", "Gestures", "Colors", "User"])

    tabs.UseTab("Main")
    for c in CONF.Main {
        _AddConfElem(c, A_Index == 1 ? 40 : "")
    }
    is_startup := IsInStartup()
    s_gui["Autostart"].Value := is_startup
    IniWrite(is_startup, "config.ini", "Main", "Autostart")
    CONF.autostart.v := is_startup

    s_gui.Add("Text", "x361 y484 BackgroundTrans CGray", "v0.82")
        .OnEvent("Click", (*) => Run("https://github.com/uqqu/Cadans/releases"))
    s_gui.Add("Picture", "x388 y474 BackgroundTrans", "ico/github.png")
        .OnEvent("Click", (*) => Run("https://github.com/uqqu/Cadans"))

    tabs.UseTab("GUI")
    for c in CONF.GUI {
        _AddConfElem(c, A_Index == 1 ? 40 : "")
    }

    tabs.UseTab("Gestures")
    s_gui.Add("Button", "vToggleGestureGeneral x15 y34 h20 w78 Disabled", "&General")
        .OnEvent("Click", ToggleGestureSettingsSubtab.Bind(1))
    s_gui.Add("Button", "vToggleGestureIdle x93 yp0 h20 w78", "&Idle")
        .OnEvent("Click", ToggleGestureSettingsSubtab.Bind(2))
    s_gui.Add("Button", "vToggleGestureLiveHint x171 yp0 h20 w78", "&Live hint")
        .OnEvent("Click", ToggleGestureSettingsSubtab.Bind(3))
    s_gui.Add("Button", "vToggleGestureColors x249 yp0 h20 w78", "&Colors")
        .OnEvent("Click", ToggleGestureSettingsSubtab.Bind(4))
    s_gui.Add("Button", "vToggleGestureZones x327 yp0 h20 w78", "&Zones")
        .OnEvent("Click", ToggleGestureSettingsSubtab.Bind(5))

    s_gui.CurrentGroup := s_gui.GestureGeneral
    b := true
    for c in CONF.GestureGeneral {
        _AddConfElem(c, b ? 75 : "")
        b := false
    }
    s_gui["ShakeCancelEnabled"].OnEvent("Click", ToggleSettingsShakeCancelFields)
    ToggleSettingsShakeCancelFields()
    s_gui.CurrentGroup := s_gui.GestureIdle
    for c in CONF.GestureIdle {
        _AddConfElem(c, A_Index == 1 ? 75 : "")
    }
    s_gui.CurrentGroup := s_gui.GestureLiveHint
    for c in CONF.GestureLiveHint {
        _AddConfElem(c, A_Index == 1 ? 75 : "")
    }
    s_gui["LiveHintEnabled"].OnEvent("Click", ToggleSettingsLiveHintFields)
    ToggleSettingsLiveHintFields()

    s_gui.CurrentGroup := s_gui.GestureColors
    c := CONF.GestureColorSettings[1]
    _RegisterGestureColorFixed(s_gui.Add("Text", "x15 y76 h20 w185", c.descr))
    elem := _RegisterGestureColorFixed(
        s_gui.Add("DropDownList", "x210 yp-2 w195 v" . c.ini_name, c.extra_params[1])
    )
    elem.Text := c.v
    _AddGestureColorMap()
    for zone in GestureColorZones {
        key := zone[2]
        s_gui.GestureColorGroups[key] := []
        _AddGestureColorEditor(key, zone[1],
            CONF.gest_zone_colors[key],
            CONF.gest_zone_grad_len[key],
            CONF.gest_zone_grad_loop[key])
    }
    ToggleGestureColorZone("C")

    s_gui.CurrentGroup := s_gui.GestureZones
    RegisterSettingsCtrl(s_gui.Add("Text", "x20 w380 y60 h28 Center",
        "Gesture zones are resolved from corners through edges to the remaining center."))
    c := CONF.gest_center_mode
    RegisterSettingsCtrl(s_gui.Add("Text", "x15 y96 h20 w185", c.descr))
    elem := RegisterSettingsCtrl(
        s_gui.Add("DropDownList", "x210 yp-2 w195 v" . c.ini_name, c.extra_params[1])
    )
    elem.Text := c.v
    s_gui["CenterMode"].OnEvent("Change", RefreshSettingsGestureZonePreview)
    s_gui["CenterMode"].OnEvent("Change", RefreshSettingsGestureColorMap)
    _AddGestureZoneGroup("Edges", 15, 128, 196, [
        ["Top", CONF.gest_zone_t],
        ["Right", CONF.gest_zone_r],
        ["Bottom", CONF.gest_zone_b],
        ["Left", CONF.gest_zone_l],
    ])
    _AddGestureZoneGroup("Corners", 210, 128, 195, [
        ["Top left", CONF.gest_zone_tl],
        ["Top right", CONF.gest_zone_tr],
        ["Bottom right", CONF.gest_zone_br],
        ["Bottom left", CONF.gest_zone_bl],
    ])
    RegisterSettingsCtrl(s_gui.Add("Text", "x15 y286 w195 h48 0x200", "Zone preview:"))
    RegisterSettingsCtrl(s_gui.Add("Button", "x210 y284 w65 h20 vZonePreviewOff", "O&ff"))
        .OnEvent("Click", ShowSettingsGestureZonePreview.Bind("Off"))
    RegisterSettingsCtrl(s_gui.Add("Button", "x+0 yp+0 w65 h20 vZonePreviewBlink Disabled", "&Blink"))
        .OnEvent("Click", ShowSettingsGestureZonePreview.Bind("Blink"))
    RegisterSettingsCtrl(s_gui.Add("Button", "x+0 yp+0 w65 h20 vZonePreviewOn", "O&n"))
        .OnEvent("Click", ShowSettingsGestureZonePreview.Bind("On"))
    c := CONF.gest_zone_preview_color
    elem := RegisterSettingsCtrl(s_gui.Add("Edit", "Center x210 y310 h20 w174 v" . c.ini_name, c.v))
    elem.OnEvent("Change", RefreshSettingsGestureZonePreview)
    RegisterSettingsCtrl(s_gui.Add("Button", "x+1 yp+0 h20 w20 v" . c.ini_name . "Pick", "🎨"))
        .OnEvent("Click", PickSettingsGestureZonePreviewColor)

    s_gui.CurrentGroup := false
    ToggleGestureSettingsSubtab(1)
    tabs.UseTab("Colors")
    s_gui.Add("Text", "x20 w380 y30 h34 Center", "Button border colors:")
    loop 7 {
        c := CONF.Colors[A_Index]
        _AddConfElem(c, A_Index == 1 ? 55 : "")
    }
    s_gui.Add("Text", "x20 w380 y+8 h1 0x10")
    s_gui.Add("Text", "x20 w380 y+10 h34 Center", "Button indicator colors:")
    loop 8 {
        c := CONF.Colors[A_Index + 7]
        _AddConfElem(c, A_Index == 1 ? 285 : "")
    }

    tabs.UseTab("User")

    s_gui.Add("Button", "vToggleUserDefined x15 y34 h20 w130 Disabled", "&User defined")
        .OnEvent("Click", _ToggleUserValues.Bind(1))
    s_gui.Add("Button", "vToggleProcessGroups x145 yp0 h20 w131", "&Process groups")
        .OnEvent("Click", _ToggleUserValues.Bind(2))
    s_gui.Add("Button", "vToggleLayoutAliases x275 yp0 h20 w130", "&Layout aliases")
        .OnEvent("Click", _ToggleUserValues.Bind(3))

    s_gui.Add("Text", "x30 w360 y65 h40 vUserDescription Center",
        "Store values for your user functions here, such as API keys.")
    s_gui.Add("Button", "x+7 yp-4 w20 h20 Center", "&+").OnEvent("Click", _AddUserLine)
    s_gui.Add("Text", "x15 w390 y+13 h1 0x10")
    for name in ["UserDefined", "ProcessGroups", "LayoutAliases"] {
        for key, val in CONF.%name% {
            _AddElems("user", A_Index == 1 ? 100 : "", name, [false, key, key, val])
        }
        _AddElems("user", CONF.%name%.Count ? "" : 100, name, [false, "", "", ""])
    }
    _ToggleUserValues(1)

    tabs.OnEvent("Change", SettingsTabChanged)
    SettingsTabChanged(tabs)

    s_gui.Show("w420 h505")
}


SettingsTabChanged(obj, *) {
    show_gestures := obj.Text == "Gestures"
    if !show_gestures {
        HideGestureZonePreview()
    } else {
        RestoreSettingsGestureZonePreview()
    }
    DllCall("SetFocus", "ptr", s_gui.Hwnd)
}


ToggleGestureSettingsSubtab(trg, *) {
    for i, group in [
        ["General", s_gui.GestureGeneral],
        ["Idle", s_gui.GestureIdle],
        ["LiveHint", s_gui.GestureLiveHint],
        ["Colors", s_gui.GestureColors],
        ["Zones", s_gui.GestureZones],
    ] {
        t := i == trg
        if group[1] == "Colors" && t {
            for obj in group[2] {
                obj.Visible := false
            }
            s_gui["ToggleGesture" . group[1]].Enabled := false
            continue
        }
        for obj in group[2] {
            obj.Visible := t
        }
        s_gui["ToggleGesture" . group[1]].Enabled := !t
    }

    if trg !== 5 {
        HideGestureZonePreview()
    }
    if trg == 4 {
        mode := GetSettingsCenterMode()
        if s_gui.GestureColorMapMode !== mode {
            b := 0
            s_gui.GestureColorMapMode := mode
            if mode == "Single" {
                s_gui["GestureColorMapC"].Move(110, 204, 200, 85)
                b := 1
            } else if mode == "Grid" {
                s_gui["GestureColorMapCA"].Move(110, 204, 100, 42)
                s_gui["GestureColorMapCB"].Move(210, 204, 100, 42)
                s_gui["GestureColorMapCD"].Move(110, 246, 100, 42)
                s_gui["GestureColorMapCC"].Move(210, 246, 100, 42)
            } else {
                s_gui["GestureColorMapCA"].Move(167, 204, 86, 26)
                s_gui["GestureColorMapCD"].Move(110, 234, 100, 26)
                s_gui["GestureColorMapCB"].Move(210, 234, 100, 26)
                s_gui["GestureColorMapCC"].Move(167, 263, 86, 26)
            }
            ToggleVisibility(b, s_gui["GestureColorMapC"])
            ToggleVisibility(!b, s_gui["GestureColorMapCA"], s_gui["GestureColorMapCB"],
                s_gui["GestureColorMapCC"], s_gui["GestureColorMapCD"])
        }
        for obj in s_gui.GestureColorFixed {
            obj.Visible := true
        }
        for zone in GestureColorZones {
            key := zone[2]
            s_gui["GestureColorMap" . key].Visible := SubStr(key, 1, 1) !== "C"
                || GestureColorMapKeyVisible(key)
        }
        ToggleGestureColorZone(s_gui.SelectedGestureColorZone)
    } else if trg == 5 {
        ToggleSettingsZonePreviewMode(s_gui.ZonePreviewMode)
        if s_gui.ZonePreviewMode == "On" {
            ShowGestureZonePreview(GetSettingsGestureZoneOpts(), "On")
        }
    }
}


ToggleSettingsLiveHintFields(*) {
    enabled := s_gui["LiveHintEnabled"].Value
    for name in [
        "LiveHint", "LiveHintAlt", "LHSize", "LiveHintStartCount", "LiveHintStartMove", "LiveHintMoveCount",
        "LiveHintMinScore", "LiveHintBgColor", "LiveHintBgColorPick", "LiveHintOpacity",
        "LiveHintTextColor",
        "LiveHintTextColorPick", "LiveHintThumbnailColor", "LiveHintThumbnailColorPick",
        "LiveHintBoxWidth", "LiveHintMargin",
        "LHSizeStep", "LiveHintStartCountStep", "LiveHintStartMoveStep", "LiveHintMoveCountStep",
        "LiveHintMinScoreStep", "LiveHintOpacityStep", "LiveHintBoxWidthStep", "LiveHintMarginStep"
    ] {
        try s_gui[name].Enabled := enabled
    }
}


ToggleSettingsShakeCancelFields(*) {
    enabled := s_gui["ShakeCancelEnabled"].Value
    for name in [
        "ShakeCancelSamples", "ShakeCancelBox", "ShakeCancelLength", "ShakeCancelTurns",
        "ShakeCancelSamplesStep", "ShakeCancelBoxStep", "ShakeCancelLengthStep", "ShakeCancelTurnsStep"
    ] {
        try s_gui[name].Enabled := enabled
    }
}


GetGestureColorKey(pool) {
    for zone in GestureColorZones {
        if zone[1] == pool {
            return zone[2]
        }
    }

    return "C"
}


_AddGestureColorMap() {
    _RegisterGestureColorFixed(s_gui.Add("Text", "x20 y120 w380 h40 Center",
        "Default colors by gesture pool`n(can be overridden for each assignment)"))

    x := 60
    y := 162
    w := 300
    h := 169
    bw := 50
    th := 42
    cw := w - bw * 2
    ch := h - th * 2
    hw := cw // 2
    hh := ch // 2

    _AddGestureColorMapBtn("TL", "TL", x, y, bw, th)
    _AddGestureColorMapBtn("T", "T", x + bw, y, cw, th)
    _AddGestureColorMapBtn("TR", "TR", x + bw + cw, y, bw, th)
    _AddGestureColorMapBtn("L", "L", x, y + th, bw, ch)
    _AddGestureColorMapBtn("R", "R", x + bw + cw, y + th, bw, ch)
    _AddGestureColorMapBtn("BL", "BL", x, y + th + ch, bw, th)
    _AddGestureColorMapBtn("B", "B", x + bw, y + th + ch, cw, th)
    _AddGestureColorMapBtn("BR", "BR", x + bw + cw, y + th + ch, bw, th)

    _AddGestureColorMapBtn("CA", "a", x + bw, y + th, hw, hh)
    _AddGestureColorMapBtn("CB", "b", x + bw + hw, y + th, cw - hw, hh)
    _AddGestureColorMapBtn("CD", "d", x + bw, y + th + hh, hw, ch - hh)
    _AddGestureColorMapBtn("CC", "c", x + bw + hw, y + th + hh, cw - hw, ch - hh)
    _AddGestureColorMapBtn("C", "C", x + bw, y + th, cw, ch)
}


_AddGestureColorMapBtn(key, txt, x, y, w, h) {
    btn := RegisterSettingsCtrl(s_gui.Add("Button", "x" . x . " y" . y . " w" . w . " h" . h
        . " vGestureColorMap" . key, txt))
    s_gui.GestureColorMapButtons.Push(btn)
    btn.OnEvent("Click", ToggleGestureColorZone.Bind(key))
}


_AddGestureColorEditor(key, label, color_conf, len_conf, loop_conf) {
    group := s_gui.GestureColorGroups[key]
    group.Push(RegisterSettingsCtrl(s_gui.Add("Text", "x15 y346 h40 w200",
        color_conf.descr)))
    group.Push(RegisterSettingsCtrl(s_gui.Add("Edit", "Center x+0 yp+8 h20 w170 v"
        . color_conf.ini_name, color_conf.v)))
    group.Push(RegisterSettingsCtrl(s_gui.Add("Button", "x+1 yp+0 h20 w20 v"
        . color_conf.ini_name . "Pick", "🎨")))
    group[-1].OnEvent("Click", PasteColorFromPick.Bind(s_gui.Hwnd, s_gui[color_conf.ini_name], true))
    group.Push(RegisterSettingsCtrl(s_gui.Add("Text", "x15 y388 h20 w200",
        len_conf.descr)))
    group.Push(RegisterSettingsCtrl(s_gui.Add("Edit", "Center x+0 yp-2 h20 w190 Number v"
        . len_conf.ini_name, len_conf.v)))
    group.Push(RegisterSettingsCtrl(s_gui.Add("UpDown", "v" . len_conf.ini_name . "Step Range0-99999",
        len_conf.v)))
    group.Push(RegisterSettingsCtrl(s_gui.Add("CheckBox", "x15 y414 h20 w380 v"
        . loop_conf.ini_name, loop_conf.descr)))
    group[-1].Value := loop_conf.v
}


ToggleGestureColorZone(key, *) {
    if !GestureColorMapKeyVisible(key) {
        key := GetSettingsCenterMode() == "Single" ? "C" : "CA"
    }
    s_gui.SelectedGestureColorZone := key
    for zone in GestureColorZones {
        t := zone[2] == key
        for obj in s_gui.GestureColorGroups[zone[2]] {
            obj.Visible := t
        }
        s_gui["GestureColorMap" . zone[2]].Enabled := !t
    }
}


_RegisterGestureColorFixed(obj) {
    RegisterSettingsCtrl(obj)
    s_gui.GestureColorFixed.Push(obj)
    return obj
}


GestureColorMapKeyVisible(key) {
    if SubStr(key, 1, 1) !== "C" {
        return true
    }
    return GetSettingsCenterMode() == "Single" ? key == "C" : key !== "C"
}


GetSettingsCenterMode() {
    try return s_gui["CenterMode"].Text
    return CONF.gest_center_mode.v
}


_ToggleUserValues(trg, *) {
    for i, name in ["UserDefined", "ProcessGroups", "LayoutAliases"] {
        t := i == trg
        for arr in s_gui.%name% {
            ToggleVisibility(t, arr)
        }
        s_gui["Toggle" . name].Enabled := !t
    }
    s_gui["UserDescription"].Text := [
        "Store values for your user functions here, such as API keys.",
        "Combine several processes under a single keyword to use in layer rules.",
        "Rules for sharing assignments across layouts."
            . "`ne.g. -255851511=67699721 redirects the qPhyx layout to qwerty assignments."
        ][trg]
    s_gui["UserDescription"].Move(, trg == 3 ? 60 : 65)
    s_gui["UserDescription"].Redraw()
}


_AddGestureZoneGroup(title, x, y, w, zones) {
    RegisterSettingsCtrl(s_gui.Add("GroupBox", "x" . x . " y" . y . " w" . w . " h140", title))
    y += 26
    inner_x := x + Round((w - 177) / 2)

    for zone in zones {
        name := zone[2].ini_name
        en := RegisterSettingsCtrl(s_gui.Add("CheckBox", "x" . inner_x . " y" . y
            . " w94 h20 vZoneEnabled" . name, zone[1]))
        en.Value := zone[2].v > 0

        field := RegisterSettingsCtrl(s_gui.Add("Edit", "Center x+8 yp-2 w48 h20 Number v" . name,
            zone[2].v ? zone[2].v : 128))
        stepper := RegisterSettingsCtrl(s_gui.Add("UpDown", "Range0-999", zone[2].v ? zone[2].v : 128))
        field.Enabled := en.Value
        stepper.Enabled := en.Value
        field.OnEvent("Change", RefreshSettingsGestureZonePreview)
        stepper.OnEvent("Change", RefreshSettingsGestureZonePreview)
        RegisterSettingsCtrl(s_gui.Add("Text", "x+4 yp+3 w18 h20", "px"))
        en.OnEvent("Click", ToggleGestureZoneEdit.Bind(field, stepper))
        y += 28
    }
}


ToggleGestureZoneEdit(field, stepper, obj, *) {
    field.Enabled := obj.Value
    stepper.Enabled := obj.Value
    RefreshSettingsGestureZonePreview()
}


ShowSettingsGestureZonePreview(mode, *) {
    s_gui.ZonePreviewMode := mode
    ToggleSettingsZonePreviewMode(mode)
    ShowGestureZonePreview(GetSettingsGestureZoneOpts(), mode)
}


PickSettingsGestureZonePreviewColor(*) {
    PasteColorFromPick(s_gui.Hwnd, s_gui["PreviewColor"], false)
    RefreshSettingsGestureZonePreview()
}


RefreshSettingsGestureZonePreview(*) {
    if s_gui.ZonePreviewMode !== "Off" {
        ShowGestureZonePreview(GetSettingsGestureZoneOpts(), s_gui.ZonePreviewMode)
    }
}


RestoreSettingsGestureZonePreview(*) {
    try {
        if s_gui && s_gui.ZonePreviewMode == "On" && !s_gui["ToggleGestureZones"].Enabled {
            ShowGestureZonePreview(GetSettingsGestureZoneOpts(), "On")
        }
    }
}


ToggleSettingsZonePreviewMode(mode) {
    for name in ["Off", "Blink", "On"] {
        try s_gui["ZonePreview" . name].Enabled := name !== mode
    }
}


RefreshSettingsGestureColorMap(*) {
    try {
        if !s_gui["ToggleGestureColors"].Enabled {
            ToggleGestureColorZone(s_gui.SelectedGestureColorZone)
        }
    }
}


GetSettingsGestureZoneOpts() {
    return {
        center_mode: s_gui["CenterMode"].Text,
        t: GetSettingsGestureZoneSize("Top"),
        r: GetSettingsGestureZoneSize("Right"),
        b: GetSettingsGestureZoneSize("Bottom"),
        l: GetSettingsGestureZoneSize("Left"),
        tl: GetSettingsGestureZoneSize("TopLeft"),
        tr: GetSettingsGestureZoneSize("TopRight"),
        br: GetSettingsGestureZoneSize("BottomRight"),
        bl: GetSettingsGestureZoneSize("BottomLeft"),
        color: GetSettingsGestureZonePreviewColor(),
    }
}


GetSettingsGestureZoneSize(name) {
    if !s_gui["ZoneEnabled" . name].Value {
        return 0
    }

    try return Integer(s_gui[name].Text)
    return 0
}


GetSettingsGestureZonePreviewColor() {
    try return ParseAhkColor(s_gui["PreviewColor"].Text)
    return ParseAhkColor(CONF.gest_zone_preview_color.v)
}


_AddUserLine(*) {
    for name in ["UserDefined", "ProcessGroups", "LayoutAliases"] {
        if !s_gui["Toggle" . name].Enabled {
            _group := name
            break
        }
    }
    s_gui.%_group%[-1][-1].GetPos(, &y)
    _AddElems("user", y + 28, _group, [false, "", "", ""])

}


RegisterSettingsCtrl(obj) {
    if s_gui.CurrentGroup {
        s_gui.CurrentGroup.Push(obj)
    }

    return obj
}


_AddConfElem(conf, y:=false, group:=false) {
    name := conf.ini_name . (conf.form_type != "num_step" && conf.is_num ? " Number" : "")
    _AddElems(conf.form_type, y, group, [
        conf.double_height, name, conf.descr, conf.v, conf.placeholder, conf.val_type, conf.extra_params*
    ])
}


_SetSettingsPlaceholder(input, placeholder) {
    if placeholder {
        SendMessage(0x1501, true, StrPtr(placeholder), input.Hwnd)
    }
    return input
}


_SyncSettingsFloatStepper(input, stepper, scale, range_min, range_max, *) {
    try stepper.Value := Max(range_min, Min(range_max, Round(Float(input.Text) * scale)))
}


_ApplySettingsFloatStepper(input, stepper, scale, *) {
    input.Text := Format("{:.2f}", stepper.Value / scale)
}


_ApplySettingsIntStepper(input, stepper, step, range_min, range_max, *) {
    global settings_int_stepper_vals, settings_int_stepper_guards

    hwnd := stepper.Hwnd
    if settings_int_stepper_guards.Has(hwnd) {
        return
    }
    try {
        prev_val := settings_int_stepper_vals.Has(hwnd) ? settings_int_stepper_vals[hwnd] : Integer(input.Text)
    } catch {
        prev_val := stepper.Value
    }

    new_val := stepper.Value
    if Abs(new_val - prev_val) == 1 {
        new_val := Max(range_min, Min(range_max, prev_val + (new_val > prev_val ? step : -step)))
    }

    if new_val != stepper.Value {
        settings_int_stepper_guards[hwnd] := true
        stepper.Value := new_val
        input.Text := new_val
        settings_int_stepper_guards.Delete(hwnd)
    }
    settings_int_stepper_vals[hwnd] := new_val
}


_AddElems(elem_type, y:=false, _group:=false, data*) {
    static cur_h:=0, _shift:=8

    cur_h := y || cur_h

    for arr in data {
        if type(arr) !== "Array" {
            continue
        }
        h := arr[1] ? 40 : 20
        ysh := arr[1] ? 8 : -2
        name := arr[2]
        placeholder := arr.Length >= 5 ? arr[5] : ""
        switch elem_type {
            case "ddl":
                RegisterSettingsCtrl(s_gui.Add("Text", "x15 y" . cur_h . " h" . h . " w190", arr[3]))
                elem := RegisterSettingsCtrl(
                    s_gui.Add("DropDownList", "x+10 yp" . ysh . " w190 v" . name, arr[7])
                )
                if arr[8] {
                    elem.Text := arr[4]
                } else {
                    elem.Value := arr[4]
                }
            case "str":
                RegisterSettingsCtrl(s_gui.Add("Text", "x15 y" . cur_h . " h" . h . " w200", arr[3]))
                _SetSettingsPlaceholder(
                    RegisterSettingsCtrl(
                        s_gui.Add("Edit", "Center x+0 yp" . ysh . " h20 w190 v" . name, arr[4])
                    ),
                    placeholder
                )
            case "num_step":
                val_type := arr[6]
                range_min := arr[7], range_max := arr[8], scale := arr[9]
                step := arr.Length >= 10 ? arr[10] : 1
                try {
                    step_val := scale == 1 ? Integer(arr[4]) : Round(Float(arr[4]) * scale)
                } catch {
                    step_val := 0
                }
                val := val_type == "str" && !Trim(arr[4]) ? ""
                    : scale == 1 ? step_val : Format("{:.2f}", step_val / scale)
                RegisterSettingsCtrl(s_gui.Add("Text", "x15 y" . cur_h . " h" . h . " w200", arr[3]))
                input := _SetSettingsPlaceholder(
                    RegisterSettingsCtrl(s_gui.Add("Edit", "Center x+0 yp" . ysh . " h20 w190"
                        . (scale == 1 ? " Number" : "") . " v" . name, val)),
                    placeholder
                )
                stepper_opts := "v" . name . "Step Range" . range_min . "-" . range_max
                    . (scale == 1 ? "" : " -0x2")
                stepper := RegisterSettingsCtrl(s_gui.Add("UpDown", stepper_opts, step_val))
                if val_type == "str" && !Trim(arr[4]) {
                    input.Text := ""
                }
                if scale != 1 {
                    input.OnEvent("Change", _SyncSettingsFloatStepper.Bind(input, stepper, scale,
                        range_min, range_max))
                    stepper.OnEvent("Change", _ApplySettingsFloatStepper.Bind(input, stepper, scale))
                } else if step != 1 {
                    settings_int_stepper_vals[stepper.Hwnd] := step_val
                    stepper.OnEvent("Change", _ApplySettingsIntStepper.Bind(input, stepper, step,
                        range_min, range_max))
                }
            case "checkbox":
                RegisterSettingsCtrl(
                    s_gui.Add("CheckBox", "x15 y" . cur_h . " h" . h . " w380 v" . name, arr[3])
                ).Value := arr[4]
            case "h_checkbox":
                fn := MsgBox.Bind(arr[7], arr[8], "IconI")
                RegisterSettingsCtrl(s_gui.Add("Button", "x11 y" . cur_h . " h20 w20", "?"))
                    .OnEvent("Click", (*) => fn.Call())
                RegisterSettingsCtrl(
                    s_gui.Add("CheckBox", "x+3 w350 yp+0 h20 v" . name, arr[3])
                ).Value := arr[4]
            case "color":
                RegisterSettingsCtrl(s_gui.Add("Text", "x15 y" . cur_h . " h" . h . " w200", arr[3]))
                _SetSettingsPlaceholder(
                    RegisterSettingsCtrl(
                        s_gui.Add("Edit", "Center x+0 yp" . ysh . " h20 w170 v" . name, arr[4])
                    ),
                    placeholder
                )
                RegisterSettingsCtrl(s_gui.Add("Button", "x+1 yp+0 h20 w20 v" . name . "Pick", "🎨"))
                    .OnEvent("Click", PasteColorFromPick.Bind(s_gui.Hwnd, s_gui[name], false))
            case "m_color":
                RegisterSettingsCtrl(s_gui.Add("Text", "x15 y" . cur_h . " h" . h . " w200", arr[3]))
                _SetSettingsPlaceholder(
                    RegisterSettingsCtrl(
                        s_gui.Add("Edit", "Center x+0 yp" . ysh . " h20 w170 v" . name, arr[4])
                    ),
                    placeholder
                )
                RegisterSettingsCtrl(s_gui.Add("Button", "x+1 yp+0 h20 w20 v" . name . "Pick", "🎨"))
                    .OnEvent("Click", PasteColorFromPick.Bind(s_gui.Hwnd, s_gui[name], true))
            case "user":
                k := s_gui.Add("Edit", "Center x15 y" . cur_h . " h" . h . " w190", arr[3])
                e := s_gui.Add("Text", "Center x+0 yp+3 h20 w10", "=")
                v := s_gui.Add("Edit", "Center x+0 yp-3 h20 w190", arr[4])
                s_gui.%_group%.Push([k, e, v])

        }
        cur_h += h + _shift
    }
}


PasteSCToInput(sc) {
    switch ControlGetFocus("A") {
        case s_gui["GuiBackEdit"].Hwnd:
            s_gui["GuiBackEdit"].Text := _GetKeyName(sc)
        case s_gui["GuiSetEdit"].Hwnd:
            s_gui["GuiSetEdit"].Text := _GetKeyName(sc)
        case s_gui["GuiSetHoldEdit"].Hwnd:
            s_gui["GuiSetHoldEdit"].Text := _GetKeyName(sc)
        default:
            return false
    }
    return true
}


SaveConfig(close_after:=true, *) {
    global s_gui, overlay

    CancelChordEditing(0, true)
    if !close_after {
        SyncSettingsEmptyDefaults()
    }

    proc := CheckChanges(, Map("ProcessGroups", 0))
    b := CheckChanges(true)
    restart_changed := SettingsRestartRequiredChanged()
    draw_changed := SettingsDrawLayoutChanged()
    if b == -1 {
        return
    } else if b {
        if restart_changed && close_after {
            b := 2
        }

        if !s_gui["IgnoreInactiveLayers"].Value && CONF.ignore_inactive.v {
            for layer in AllLayers.order {
                if !ActiveLayers.Has(layer) && AllLayers[layer] is Integer {
                    MergeLayer(layer)
                }
            }
        }

        if s_gui["Autostart"].Value != CONF.autostart.v {
            ToggleStartup(s_gui["Autostart"].Value)
        }

        if restart_changed && !close_after {
            ShowSettingsRestartWarningOnce()
        }

        for name in ["Main", "GUI", "Gestures", "GestureLiveHint", "GestureDefaults", "GestureZones", "Colors"] {
            for elem in CONF.%name% {
                if !close_after && IsRestartRequiredSetting(elem) {
                    continue
                }
                val := GetSettingsValue(name, elem)
                IniWrite(val, "config.ini", name, elem.ini_name)
                elem.v := elem.val_type == "int" ? Integer(val)
                    : elem.val_type == "float" ? Round(Float(val), 2) : val
                if !close_after {
                    SetSettingsControlValue(elem, elem.v)
                }
            }
        }
        for name in ["UserDefined", "ProcessGroups", "LayoutAliases"] {
            for key, _ in CONF.%name% {
                IniDelete("config.ini", name, key)
            }
            for arr in s_gui.%name% {
                key := arr[1].Text
                value := arr[3].Text
                if key {
                    IniWrite(value, "config.ini", name, key)
                }
            }
        }
        IniWrite(IsInStartup(), "config.ini", "Main", "Autostart")
    }
    MarkSettingsRestartPending()

    if b == 2 {
        Run(A_ScriptFullPath)  ; rerun with new keys
    } else {
        CollectUserValues()
        if proc {
            Refresh()
        }
        if b {
            CONF.T := "T" . CONF.MS_LP.v / 1000
            A_TrayMenu.Rename("1&", "+10ms hold threshold (to " . CONF.MS_LP.v + 10 . "ms)")
            A_TrayMenu.Rename("2&", "-10ms hold threshold (to " . CONF.MS_LP.v - 10 . "ms)")
            if draw_changed {
                try overlay.Destroy()
                overlay := false
                DrawLayout()
                if !close_after {
                    try WinActivate("ahk_id " . s_gui.Hwnd)
                }
            }
        }
        if close_after {
            CloseSettingsEvent(false)
        }
    }
}


SyncSettingsEmptyDefaults() {
    for name in ["Main", "GUI", "Gestures", "GestureLiveHint", "GestureDefaults", "GestureZones", "Colors"] {
        for elem in CONF.%name% {
            try {
                ctrl_text := s_gui[elem.ini_name].Text
            } catch {
                continue
            }
            if elem.empty_policy !== "allow" && Trim(ctrl_text) == "" {
                SetSettingsControlValue(elem, elem.default)
            }
        }
    }
}


SetSettingsControlValue(elem, val) {
    try {
        settings_ctrl := s_gui[elem.ini_name]
    } catch {
        return
    }

    if elem.form_type == "ddl" && elem.val_type !== "str" || elem.form_type == "checkbox"
        || elem.form_type == "h_checkbox" {
        settings_ctrl.Value := val
        return
    }

    if elem.form_type == "num_step" {
        display_val := FormatSettingsNumberText(elem, val)
        settings_ctrl.Text := display_val
        try s_gui[elem.ini_name . "Step"].Value := GetSettingsStepperValue(elem, val)
        return
    }

    settings_ctrl.Text := val
}


FormatSettingsNumberText(elem, val) {
    scale := 1
    try scale := elem.extra_params[3]

    if elem.val_type == "str" && !Trim(val) {
        return ""
    }
    return scale == 1 ? Integer(val) : Format("{:.2f}", Float(val))
}


GetSettingsStepperValue(elem, val) {
    scale := 1
    try scale := elem.extra_params[3]
    return scale == 1 ? Integer(val) : Round(Float(val) * scale)
}


SettingsDrawLayoutChanged() {
    for elem in GetDrawLayoutSettings() {
        if GetSettingsValue(elem.sect, elem.conf) != elem.conf.v {
            return true
        }
    }
    return CheckChanges(, Map("Colors", 0))
}


GetDrawLayoutSettings() {
    out := [
        {sect: "Main", conf: CONF.layout_format},
        {sect: "GUI", conf: CONF.keyname_type},
        {sect: "GUI", conf: CONF.overlay_type},
        {sect: "GUI", conf: CONF.ref_height},
        {sect: "GUI", conf: CONF.gui_scale},
        {sect: "GUI", conf: CONF.font_scale},
        {sect: "GUI", conf: CONF.font_name},
        {sect: "Gestures", conf: CONF.gest_color_mode},
        {sect: "Gestures", conf: CONF.gest_thumbnail_color},
        {sect: "Gestures", conf: CONF.gest_pool_marker_color},
        {sect: "Gestures", conf: CONF.show_unavailable_gestures},
        {sect: "GestureZones", conf: CONF.gest_center_mode},
    ]
    for elem in CONF.GestureDefaults {
        out.Push({sect: "GestureDefaults", conf: elem})
    }
    for elem in CONF.GestureZones {
        if IsGestureZoneSizeSetting(elem.ini_name) {
            out.Push({sect: "GestureZones", conf: elem})
        }
    }
    return out
}


SettingsRestartRequiredChanged() {
    for elem in GetRestartRequiredSettings() {
        if GetSettingsValue(elem.sect, elem.conf) != elem.conf.v {
            return true
        }
    }
    return false
}


GetRestartRequiredSettings() {
    return [
        {sect: "Main", conf: CONF.dual_numpad},
        {sect: "Main", conf: CONF.extra_f_row},
        {sect: "Main", conf: CONF.extra_k_row},
        {sect: "Main", conf: CONF.sendtext_output},
    ]
}


IsRestartRequiredSetting(elem) {
    for item in GetRestartRequiredSettings() {
        if item.conf == elem {
            return true
        }
    }
    return false
}


ShowSettingsRestartWarningOnce() {
    if s_gui.ApplyRestartWarningShown {
        return
    }
    s_gui.ApplyRestartWarningShown := true
    ToolTip("Some settings require restart and were not applied.")
    SetTimer((*) => ToolTip(), -2500)
}


MarkSettingsRestartPending() {
    for item in GetRestartRequiredSettings() {
        try s_gui[item.conf.ini_name].SetFont(
            GetSettingsValue(item.sect, item.conf) != item.conf.v ? "cRed Bold" : "cDefault Norm"
        )
    }
}


CheckChanges(strict:=false, selected:=false, *) {
    for name in ["Main", "GUI", "Gestures", "GestureLiveHint", "GestureDefaults", "GestureZones", "Colors"] {
        if selected && !selected.Has(name) {
            continue
        }
        for elem in CONF.%name% {
            val := GetSettingsValue(name, elem)
            if val != elem.v {
                return true
            }
        }
    }

    for name in ["UserDefined", "ProcessGroups", "LayoutAliases"] {
        if selected && !selected.Has(name) {
            continue
        }
        i := A_Index
        cnt := 0
        for arr in s_gui.%name% {
            if i == 3 {
                if !arr[1].Text && !arr[3].Text {
                    continue
                }
                try {
                    key := Integer(arr[1].Text)
                    value := Integer(arr[3].Text)
                } catch {
                    if strict {
                        MsgBox("Layout aliases must be integers", "Error")
                        return -1
                    }
                }
            } else {
                key := arr[1].Text
                value := arr[3].Text
            }
            if key || value {
                if !CONF.%name%.Has(key) || CONF.%name%[key] != value {
                    return true
                }
                cnt += 1
            }
        }
        if cnt !== CONF.%name%.Count {
            return true
        }
    }
    return false
}


GetSettingsValue(sect, elem) {
    if sect == "GestureZones" && IsGestureZoneSizeSetting(elem.ini_name)
        && !s_gui["ZoneEnabled" . elem.ini_name].Value {
        return 0
    }

    try {
        settings_ctrl := s_gui[elem.ini_name]
    } catch {
        return elem.v
    }
    val := elem.form_type == "color" || elem.form_type == "m_color" || elem.form_type == "str"
        || elem.form_type == "num_step"
        || elem.form_type == "ddl" && elem.val_type == "str"
            ? settings_ctrl.Text : settings_ctrl.Value
    if elem.empty_policy !== "allow" && Trim(val) == "" {
        val := elem.default
    }
    if elem.val_type == "int" || elem.val_type == "str" && elem.is_num {
        val := NormalizeSettingsIntegerText(val)
    }
    return val
}


NormalizeSettingsIntegerText(val) {
    val := Trim(val)
    for sep in [".", ",", " "] {
        val := StrReplace(val, sep)
    }
    return val
}


IsGestureZoneSizeSetting(name) {
    static zone_sizes:=Map(
        "Top", true, "Right", true, "Bottom", true, "Left", true,
        "TopLeft", true, "TopRight", true, "BottomRight", true, "BottomLeft", true
    )
    return zone_sizes.Has(name)
}


EscSettingsEvent(*) {
    t := s_gui.FocusedCtrl.Type
    if t == "Edit" || t == "DDL" || t == "CheckBox" {
        DllCall("SetFocus", "ptr", s_gui.Hwnd)
    } else {
        CloseSettingsEvent()
    }
}


CloseSettingsEvent(strict:=true, *) {
    global s_gui

    if strict && CheckChanges() && MsgBox(
        "You have unsaved changes. Do you really want to close the window?",
        "Confirmation", "YesNo Icon?") == "No" {
        return true
    }
    HideGestureZonePreview()
    try s_gui.Destroy()
    s_gui := false
}


IsInStartup() {
    try {
        return RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Run", proj_name) !== ""
    } catch {
        return false
    }
}


ToggleStartup(val) {
    try {
        if val {
            cmd := (A_IsCompiled ? ("`"" . A_AhkPath . "`" ") : "") . "`"" . A_ScriptFullPath . "`""
            RegWrite(cmd, "REG_SZ", "HKCU\Software\Microsoft\Windows\CurrentVersion\Run", proj_name)
        } else {
            RegDelete("HKCU\Software\Microsoft\Windows\CurrentVersion\Run", proj_name)
        }
    } catch Error as err {
        MsgBox("Failed to update startup setting.`n`n" . err.Message, "Error", "Iconx")
    }
}
