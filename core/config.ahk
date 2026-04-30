CoordMode "Mouse", "Screen"

proj_name := "Cadans"
A_HotkeyInterval := 0
version := 0
s_gui := false
is_updating := false

active_hwnd := WinActive("A")
active_proc := ""
try active_proc := WinGetProcessName("ahk_id " . active_hwnd)

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
ReadLayers()
FillRoots()
UpdLayers()

DllCall("SetWinEventHook", "UInt", 0x0003, "UInt", 0x0003,  ; EVENT_SYSTEM_FOREGROUND
    "Ptr", 0, "Ptr", CallbackCreate(WinEventProc), "UInt", 0, "UInt", 0, "UInt", 0, "Ptr")

WinEventProc(hWinEventHook, event, hwnd, *) {
    global active_proc, active_hwnd

    fg := WinExist("A")
    if !fg || active_hwnd == fg {
        return
    }
    active_hwnd := fg
    active_proc := WinGetProcessName("ahk_id " . fg)
    try SetCurrentProcessContext(active_proc)
    CheckLayout()
    ToRoot()
}


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
        sect, ini_name, form_type, val_type, descr, default_val,
        is_num:=false, double_height:=false, extra:=false
    ) {
        this.ini_name := ini_name
        this.form_type := form_type
        this.val_type := val_type
        this.default := default_val
        this.descr := descr
        this.is_num := is_num
        this.double_height := double_height
        this.extra_params := extra || []

        this.v := IniRead("config.ini", sect, ini_name, default_val)

        if val_type == "int" {
            this.v := Integer(this.v)
        } else if val_type == "float" {
            this.v := Round(Float(this.v), 2)
        }
        CONF.%sect%.Push(this)
    }
}


CheckConfig() {
    if !FileExist("config.ini") {
        FileAppend(
            "[Main]`r`n"
            . "ActiveLayers=`r`n"
            . "UserLayouts=`r`n"
            . "ChosenTags=Active, Inactive`r`n"
            . "`r`n[GUI]`r`n"
            . "`r`n[Gestures]`r`n"
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


    CONF.MS_LP := ConfValue("Main", "LongPressDuration", "str", "int",
        "&Hold threshold (ms):", 150, true)
    CONF.MS_NK := ConfValue("Main", "NextKeyWaitDuration", "str", "int",
        "&Nested event timeout (ms):", 300, true)

    CONF.T := "T" . CONF.MS_LP.v / 1000

    CONF.layout_format := ConfValue("Main", "LayoutFormat", "ddl", "str",
        "&Layout format:", "ANSI", , , [["ANSI", "ISO"], true])
    CONF.interruption_behavior := ConfValue("Main", "InterruptionBehavior", "ddl", "int",
        "Tap/hold &interruption behavior:", 1, , ,
        [["Ordered / await result", "Send tap", "Send hold"], false])
    CONF.dual_numpad := ConfValue("Main", "DualNumpad", "checkbox", "int",
        "Split Num&Pad keys", 0)
    CONF.extra_f_row := ConfValue("Main", "ExtraFRow", "checkbox", "int",
        "Use extra &f-row (F13-F24)", 0)
    CONF.extra_k_row := ConfValue("Main", "ExtraKRow", "checkbox", "int",
        "Use &special keys (media, browser, app keys)", 0)
    CONF.unfam_layouts := ConfValue("Main", "CollectUnfamiliarLayouts", "checkbox", "int",
        "&Collect unknown keyboard layouts from layers", 1)
    CONF.sendtext_output := ConfValue("Main", "UseSendTextOutput", "h_checkbox", "int",
        "Use Send&Text mode", 0, , ,
        ["Temporary test option."
            . "`nTo minimize bugs with sticking and inputting unwanted characters "
            . "when over-holding a hotkey with long text assignment, the SendInput {Raw} is "
            . "currently in test use. If this leads to undesirable consequences, turn on this "
            . "option to return to usual SendText and report to Issues.`n"
            . "Don't turn it on unless you're sure you need it.", "Use SendText mode"
        ])
    CONF.ignore_inactive := ConfValue("Main", "IgnoreInactiveLayers", "h_checkbox", "int",
        "I&gnore inactive layers", 0, , ,
        ["With this option enabled, inactive layers are not parsed`ninto the core data structure."
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
        [["Always use keynames", "Always use scancodes", "Scancodes on empty keys"], false])
    CONF.overlay_type := ConfValue("GUI", "OverlayType", "ddl", "int",
        "&Overlay indicator type:", 3, , ,
        [["Disabled", "Indicators only", "With counters"], false])
    CONF.gui_scale := ConfValue("GUI", "GuiScale", "str", "float",
        "&Gui scale:", A_ScreenWidth * 0.8 / 1294)
    CONF.font_scale := ConfValue("GUI", "FontScale", "str", "float",
        "&Font scale:", CONF.gui_scale.v / 2 + 0.5)
    CONF.font_name := ConfValue("GUI", "FontName", "str", "str",
        "Font &name:", "Segoe UI")
    CONF.ref_height := ConfValue("GUI", "ReferenceHeight", "str", "int",
        "&Reference height:", 314, true)
    CONF.gui_back_sc := ConfValue("GUI", "GuiBackEdit", "str", "str",
        "GUI hotkey for '&Back':", "nSub")
    CONF.gui_set_sc := ConfValue("GUI", "GuiSetEdit", "str", "str",
        "GUI hotkey for 'Set &tap':", "nAdd")
    CONF.gui_set_hold_sc := ConfValue("GUI", "GuiSetHoldEdit", "str", "str",
        "GUI hotkey for 'Set &hold':", "nEnter")
    CONF.hide_alias_warnings := ConfValue("GUI", "HideAliasWarnings", "checkbox", "int",
        "Hide warnings about changes in &aliased layouts", 0)

    CONF.gest_color_mode := ConfValue("Gestures", "ColorMode", "ddl", "str",
        "&Color mode:", "HSV", , , [["RGB", "Gamma-correct", "HSV"], true])
    CONF.edge_gestures := ConfValue("Gestures", "EdgeGestures", "ddl", "int",
        "Enable &edge gestures:", 4, , ,
        [["No", "With edges", "With corners", "With edges and corners"], false])
    CONF.edge_size := ConfValue("Gestures", "EdgeSize", "str", "int",
        "Edge detection &width (px):", 128, true)
    CONF.min_gesture_len := ConfValue("Gestures", "MinGestureLen", "str", "int",
        "Minimum gesture &length (px):", 150, true)
    CONF.min_cos_similarity := ConfValue("Gestures", "MinCosSimilarity", "str", "float",
        "Minimum gesture &similarity:", 0.90)
    CONF.overlay_opacity := ConfValue("Gestures", "OverlayOpacity", "str", "int",
        "Overlay &opacity (up to 255):", 200, true)
    CONF.font_size_lh := ConfValue("Gestures", "LHSize", "str", "int",
        "Live &hint font size:", 32, true)
    CONF.live_hint_extended := ConfValue("Gestures", "LiveHintExtended", "checkbox", "int",
        "Show &unrecognized gestures in the live hint", 1)

    CONF.gest_rotate := ConfValue("GestureDefaults", "Rotate", "ddl", "int",
        "&Rotation:", 1, , , [["None", "Reduce orientation noise", "Rotation invariant"], false])
    CONF.scale_impact := ConfValue("GestureDefaults", "Scaling", "str", "float",
        "&Scale impact:", 0)
    CONF.gest_live_hint := ConfValue("GestureDefaults", "LiveHint", "ddl", "int",
        "&Live recognition hint position:", 1, , ,
        [["Top", "Center", "Bottom", "Disabled"], false])

    CONF.gest_colors := [
        ConfValue("GestureDefaults", "GestureColors", "color", "str",
            "Ges&ture colors`n(use multiple values for a gradient):",
            "random(3)", , true),
        ConfValue("GestureDefaults", "GestureColorsEdges", "color", "str",
            "Ges&ture colors`n(use multiple values for a gradient):",
            "4FC3F7,9575CD,F06292", , true),
        ConfValue("GestureDefaults", "GestureColorsCorners", "color", "str",
            "Ges&ture colors`n(use multiple values for a gradient):",
            "66BB6A,26C6DA,FBC02D", , true),
    ]
    CONF.grad_len := [
        ConfValue("GestureDefaults", "GradientLength", "str", "int",
            "&Full gradient cycle length (px):", 1000, true),
        ConfValue("GestureDefaults", "GradientLengthEdges", "str", "int",
            "&Full gradient cycle length (px):", 1000, true),
        ConfValue("GestureDefaults", "GradientLengthCorners", "str", "int",
            "&Full gradient cycle length (px):", 1000, true),
    ]
    CONF.grad_loop := [
        ConfValue("GestureDefaults", "GradientLoop", "checkbox", "int",
            "Gra&dient cycling", 1),
        ConfValue("GestureDefaults", "GradientLoopEdges", "checkbox", "int",
            "Gra&dient cycling", 1),
        ConfValue("GestureDefaults", "GradientLoopCorners", "checkbox", "int",
            "Gra&dient cycling", 1),
    ]

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

    s_gui.Add("Button", "Center x299 y0 w60 h18 vCancel", "❌ Cancel")
        .OnEvent("Click", CloseSettingsEvent)
    s_gui.Add("Button", "Center x358 y0 w60 h18 Default vApply", "✔ Apply")
        .OnEvent("Click", SaveConfig)

    tabs := s_gui.Add("Tab3", "x0 y0 w422 h666",
        ["Main", "GUI", "Gestures", "Gesture defaults", "Colors", "User"])

    tabs.UseTab("Main")
    for c in CONF.Main {
        _AddElems(c.form_type, A_Index == 1 ? 40 : "", , [
            c.double_height, c.ini_name . (c.is_num ? " Number" : ""),
            c.descr, c.v, c.extra_params*
        ])
    }
    is_startup := IsInStartup()
    s_gui["Autostart"].Value := is_startup
    IniWrite(is_startup, "config.ini", "Main", "Autostart")
    CONF.autostart.v := is_startup

    s_gui.Add("Text", "x361 y461 BackgroundTrans CGray", "v0.80")
        .OnEvent("Click", (*) => Run("https://github.com/uqqu/Cadans/releases"))
    s_gui.Add("Picture", "x388 y451 BackgroundTrans", "ico/github.png")
        .OnEvent("Click", (*) => Run("https://github.com/uqqu/Cadans"))

    tabs.UseTab("GUI")
    for c in CONF.GUI {
        _AddElems(c.form_type, A_Index == 1 ? 40 : "", , [
            c.double_height, c.ini_name . (c.is_num ? " Number" : ""),
            c.descr, c.v, c.extra_params*
        ])
    }

    tabs.UseTab("Gestures")
    for c in CONF.Gestures {
        _AddElems(c.form_type, A_Index == 1 ? 40 : "", , [
            c.double_height, c.ini_name . (c.is_num ? " Number" : ""),
            c.descr, c.v, c.extra_params*
        ])
    }

    tabs.UseTab("Gesture defaults")
    s_gui.Add("Text", "x20 w380 y34 h34 Center",
        "Default gesture matching and color settings`n(can be overridden for each assignment)")
    s_gui.Add("Text", "x20 w380 y+8 h1 0x10")

    for c in CONF.GestureDefaults {
        if A_Index == 4 {
            break
        }
        _AddElems(c.form_type, A_Index == 1 ? 90 : "", , [
            c.double_height, c.ini_name . (c.is_num ? " Number" : ""),
            c.descr, c.v, c.extra_params*
        ])
    }
    SendMessage(0x1501, true, StrPtr("0–0.99 (0 – size-independent)"), s_gui["Scaling"].Hwnd)

    s_gui.Add("Text", "x85 w250 y+10 h1 0x10")

    s_gui.Add("Button", "vToggleColors x15 y+10 h20 w130 Disabled", "&General")
        .OnEvent("Click", _ToggleColors.Bind(1))
    s_gui.Add("Button", "vToggleColorsEdges x145 yp0 h20 w131", "&Edges")
        .OnEvent("Click", _ToggleColors.Bind(2))
    s_gui.Add("Button", "vToggleColorsCorners x275 yp0 h20 w130", "&Corners")
        .OnEvent("Click", _ToggleColors.Bind(3))

    for i, name in ["", "Edges", "Corners"] {
        _AddElems("m_color", 215, , [
            1, "GestureColors" . name,
            "Ges&ture colors`n(more than one for gradient):", CONF.gest_colors[i].v
        ])
        _AddElems("str", , , [
            0, "GradientLength" . name . " Number",
            "&Full gradient cycle length (px):", CONF.grad_len[i].v
        ])
        _AddElems("checkbox", , , [
            0, "GradientLoop" . name, "Gra&dient cycling", CONF.grad_loop[i].v
        ])
        if i > 1 {
            s_gui["GestureColors" . name].Visible := false
            s_gui["GradientLength" . name].Visible := false
            s_gui["GradientLoop" . name].Visible := false
        }
    }

    tabs.UseTab("Colors")
    s_gui.Add("Text", "x20 w380 y30 h34 Center", "Button border colors:")
    loop 7 {
        c := CONF.Colors[A_Index]
        _AddElems(c.form_type, A_Index == 1 ? 55 : "", , [
            c.double_height, c.ini_name . (c.is_num ? " Number" : ""),
            c.descr, c.v, c.extra_params*
        ])
    }
    s_gui.Add("Text", "x20 w380 y+8 h1 0x10")
    s_gui.Add("Text", "x20 w380 y+10 h34 Center", "Button indicator colors:")
    loop 7 {
        c := CONF.Colors[A_Index + 7]
        _AddElems(c.form_type, A_Index == 1 ? 285 : "", , [
            c.double_height, c.ini_name . (c.is_num ? " Number" : ""),
            c.descr, c.v, c.extra_params*
        ])
    }

    tabs.UseTab("User")

    s_gui.Add("Button", "vToggleUserDefined x15 y+10 h20 w130 Disabled", "&User defined")
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

    tabs.OnEvent("Change", (*) => DllCall("SetFocus", "ptr", s_gui.Hwnd))


    s_gui.Show("w420 h480")
}


_ToggleColors(trg, *) {
    for i, name in ["", "Edges", "Corners"] {
        t := i == trg
        s_gui["GestureColors" . name].Visible := t
        s_gui["GestureColors" . name . "Pick"].Visible := t
        s_gui["GradientLength" . name].Visible := t
        s_gui["GradientLoop" . name].Visible := t
        s_gui["ToggleColors" . name].Enabled := !t
    }
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
        switch elem_type {
            case "ddl":
                s_gui.Add("Text", "x15 y" . cur_h . " h" . h . " w190", arr[3])
                elem := s_gui.Add("DropDownList", "x+10 yp" . ysh . " w190 v" . name, arr[5])
                if arr[6] {
                    elem.Text := arr[4]
                } else {
                    elem.Value := arr[4]
                }
            case "str":
                s_gui.Add("Text", "x15 y" . cur_h . " h" . h . " w200", arr[3])
                s_gui.Add("Edit", "Center x+0 yp" . ysh . " h20 w190 v" . name, arr[4])
            case "checkbox":
                s_gui.Add("CheckBox", "x15 y" . cur_h . " h" . h . " w380 v" . name, arr[3])
                    .Value := arr[4]
            case "h_checkbox":
                fn := MsgBox.Bind(arr[5], arr[6], "IconI")
                s_gui.Add("Button", "x11 y" . cur_h . " h20 w20", "?")
                    .OnEvent("Click", (*) => fn.Call())
                s_gui.Add("CheckBox", "x+3 w350 yp+0 h20 v" . name, arr[3]).Value := arr[4]
            case "color":
                s_gui.Add("Text", "x15 y" . cur_h . " h" . h . " w200", arr[3])
                s_gui.Add("Edit", "Center x+0 yp" . ysh . " h20 w170 v" . name, arr[4])
                s_gui.Add("Button", "x+1 yp+0 h20 w20 v" . name . "Pick", "🎨")
                    .OnEvent("Click", PasteColorFromPick.Bind(s_gui.Hwnd, s_gui[name], false))
            case "m_color":
                s_gui.Add("Text", "x15 y" . cur_h . " h" . h . " w200", arr[3])
                s_gui.Add("Edit", "Center x+0 yp" . ysh . " h20 w170 v" . name, arr[4])
                s_gui.Add("Button", "x+1 yp+0 h20 w20 v" . name . "Pick", "🎨")
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


SaveConfig(*) {
    global s_gui, overlay

    CancelChordEditing(0, true)

    proc := CheckChanges(, Map("ProcessGroups", 0))
    b := CheckChanges(true)
    if b == -1 {
        return
    } else if b {
        if s_gui["DualNumpad"].Value != CONF.dual_numpad.v
            || s_gui["ExtraFRow"].Value != CONF.extra_f_row.v
            || s_gui["ExtraKRow"].Value != CONF.extra_k_row.v
            || s_gui["UseSendTextOutput"].Value != CONF.sendtext_output.v {
            b := 2
        }

        if s_gui["IgnoreInactiveLayers"].Value != CONF.ignore_inactive.v {
            for layer in ActiveLayers.map {
                raw_roots := DeserializeMap(layer)
                AllLayers.map[layer] := CountLangMappings(raw_roots)
            }
        }

        if s_gui["Autostart"].Value != CONF.autostart.v {
            ToggleStartup(s_gui["Autostart"].Value)
        }

        for name in ["Main", "GUI", "Gestures", "GestureDefaults", "Colors"] {
            for elem in CONF.%name% {
                val := elem.form_type == "color" || elem.form_type == "m_color"
                    || elem.form_type == "str"
                    || elem.form_type == "ddl" && elem.val_type == "str"
                        ? s_gui[elem.ini_name].Text : s_gui[elem.ini_name].Value
                IniWrite(val, "config.ini", name, elem.ini_name)
                elem.v := elem.val_type == "int" ? Integer(val)
                    : elem.val_type == "float" ? Round(Float(val), 2) : val
            }
        }
        for name in ["UserDefined", "ProcessGroups", "LayoutAliases"] {
            IniDelete("config.ini", name)
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

    s_gui.Destroy()
    s_gui := false
    if b == 2 {
        Run(A_ScriptFullPath)  ; rerun with new keys
    } else {
        CollectUserValues()
        if proc {
            ReadLayers()
            FillRoots()
            UpdLayers()
        }
        if b {
            CONF.T := "T" . CONF.MS_LP.v / 1000
            A_TrayMenu.Rename("1&", "+10ms hold threshold (to " . CONF.MS_LP.v + 10 . "ms)")
            A_TrayMenu.Rename("2&", "-10ms hold threshold (to " . CONF.MS_LP.v - 10 . "ms)")
            try overlay.Destroy()
            overlay := false
            DrawLayout()
        }
    }
}


CheckChanges(strict:=false, selected:=false, *) {
    for name in ["Main", "GUI", "Gestures", "GestureDefaults", "Colors"] {
        if selected && !selected.Has(name) {
            continue
        }
        for elem in CONF.%name% {
            val := elem.form_type == "color" || elem.form_type == "m_color"
                || elem.form_type == "str"
                || elem.form_type == "ddl" && elem.val_type == "str"
                    ? s_gui[elem.ini_name].Text : s_gui[elem.ini_name].Value
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


EscSettingsEvent(*) {
    t := s_gui.FocusedCtrl.Type
    if t == "Edit" || t == "DDL" || t == "CheckBox" {
        DllCall("SetFocus", "ptr", s_gui.Hwnd)
    } else {
        CloseSettingsEvent()
    }
}


CloseSettingsEvent(*) {
    global s_gui

    if CheckChanges() && MsgBox(
        "You have unsaved changes. Do you really want to close the window?",
        "Confirmation", "YesNo Icon?") == "No" {
        return true
    }
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