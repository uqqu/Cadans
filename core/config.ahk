CoordMode "Mouse", "Screen"

proj_name := "Cadans"
A_HotkeyInterval := 0
version := 0
s_gui := false
is_updating := false
pending_event := false

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
            . "ActiveLayers=Personal`r`n"
            . "UserLayouts=`r`n"
            . "ChosenTags=Active, Inactive`r`n"
            . "`r`n[GUI]`r`n"
            . "`r`n[Gestures]`r`n"
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
        "Color &mode:", "HSV", , , [["RGB", "Gamma-correct", "HSV"], true])

    CONF.gest_center_mode := ConfValue("GestureZones", "CenterMode", "ddl", "str",
        "Center zone &mode:", "Single", , ,
        [["Single", "Grid", "Diagonal"], true])
    CONF.gest_zone_t := ConfValue("GestureZones", "Top", "str", "int",
        "&Top edge size (px):", 128, true)
    CONF.gest_zone_r := ConfValue("GestureZones", "Right", "str", "int",
        "&Right edge size (px):", 128, true)
    CONF.gest_zone_b := ConfValue("GestureZones", "Bottom", "str", "int",
        "&Bottom edge size (px):", 128, true)
    CONF.gest_zone_l := ConfValue("GestureZones", "Left", "str", "int",
        "&Left edge size (px):", 128, true)
    CONF.gest_zone_tl := ConfValue("GestureZones", "TopLeft", "str", "int",
        "Top-&left corner size (px):", 128, true)
    CONF.gest_zone_tr := ConfValue("GestureZones", "TopRight", "str", "int",
        "Top-&right corner size (px):", 128, true)
    CONF.gest_zone_br := ConfValue("GestureZones", "BottomRight", "str", "int",
        "Bottom-r&ight corner size (px):", 128, true)
    CONF.gest_zone_bl := ConfValue("GestureZones", "BottomLeft", "str", "int",
        "Bottom-l&eft corner size (px):", 128, true)
    CONF.gest_zone_preview_color := ConfValue("GestureZones", "PreviewColor", "color", "str",
        "Zone preview color:", "00F4FF")

    CONF.min_gesture_len := ConfValue("Gestures", "MinGestureLen", "str", "int",
        "Minimum gesture &length (px):", 150, true)
    CONF.min_cos_similarity := ConfValue("Gestures", "MinCosSimilarity", "str", "float",
        "Minimum gesture &similarity:", 0.90)
    CONF.overlay_opacity := ConfValue("Gestures", "OverlayOpacity", "str", "int",
        "Overlay &opacity (up to 255):", 200, true)
    CONF.font_size_lh := ConfValue("Gestures", "LHSize", "str", "int",
        "Live &hint font size:", 32, true)
    CONF.gest_thumbnail_color := ConfValue("Gestures", "ThumbnailColor", "color", "str",
        "Gesture list &thumbnail color:", "")
    CONF.gest_pool_marker_color := ConfValue("Gestures", "PoolMarkerColor", "color", "str",
        "Pool &marker color:", "2EAD64")
    CONF.live_hint_extended := ConfValue("Gestures", "LiveHintExtended", "checkbox", "int",
        "Show &unrecognized gestures in the live hint", 1)
    CONF.show_unavailable_gestures := ConfValue("Gestures", "ShowUnavailableGestures", "checkbox", "int",
        "Show gestures from unavailable &pools", 1)

    CONF.gest_rotate := ConfValue("GestureDefaults", "Rotate", "ddl", "int",
        "&Rotation:", 1, , , [["None", "Reduce orientation noise", "Rotation invariant"], false])
    CONF.scale_impact := ConfValue("GestureDefaults", "Scaling", "str", "float",
        "&Scale impact:", 0)
    CONF.gest_live_hint := ConfValue("GestureDefaults", "LiveHint", "ddl", "int",
        "&Live recognition hint position:", 1, , ,
        [["Top", "Center", "Bottom", "Disabled"], false])

    CONF.gest_zone_colors := Map()
    CONF.gest_zone_grad_len := Map()
    CONF.gest_zone_grad_loop := Map()
    for zone in GestureColorZones {
        if zone[1] == 5 || zone[1] ~= "^[a-d]$" {
            defaults := {colors: "random(3)", grad_len: 1000, grad_loop: 1}
        } else if zone[1] == 2 || zone[1] == 4 || zone[1] == 6 || zone[1] == 8 {
            defaults := {colors: "4FC3F7,9575CD,F06292", grad_len: 1000, grad_loop: 1}
        } else {
            defaults := {colors: "66BB6A,26C6DA,FBC02D", grad_len: 1000, grad_loop: 1}
        }
        CONF.gest_zone_colors[zone[2]] := ConfValue("GestureDefaults",
            "GestureColorsPool" . zone[2], "m_color", "str",
            "Ges&ture colors`n(more than one for gradient):",
            defaults.colors, , true)
        CONF.gest_zone_grad_len[zone[2]] := ConfValue("GestureDefaults",
            "GradientLengthPool" . zone[2], "str", "int",
            "&Full gradient cycle length (px):", defaults.grad_len, true)
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
    s_gui.GestureDefaults := []
    s_gui.GestureColors := []
    s_gui.GestureColorFixed := []
    s_gui.GestureColorMapButtons := []
    s_gui.GestureZones := []
    s_gui.GestureColorGroups := Map()
    s_gui.SelectedGestureColorZone := "C"
    s_gui.GestureColorMapMode := ""
    s_gui.ZonePreviewMode := "Blink"
    s_gui.CurrentGroup := false

    s_gui.Add("Button", "Center x299 y0 w60 h18 vCancel", "❌ Cancel")
        .OnEvent("Click", CloseSettingsEvent)
    s_gui.Add("Button", "Center x358 y0 w60 h18 Default vApply", "✔ Apply")
        .OnEvent("Click", SaveConfig)

    tabs := s_gui.Add("Tab3", "x0 y0 w422 h666",
        ["Main", "GUI", "Gestures", "Colors", "User"])

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

    s_gui.Add("Text", "x361 y484 BackgroundTrans CGray", "v0.82")
        .OnEvent("Click", (*) => Run("https://github.com/uqqu/Cadans/releases"))
    s_gui.Add("Picture", "x388 y474 BackgroundTrans", "ico/github.png")
        .OnEvent("Click", (*) => Run("https://github.com/uqqu/Cadans"))

    tabs.UseTab("GUI")
    for c in CONF.GUI {
        _AddElems(c.form_type, A_Index == 1 ? 40 : "", , [
            c.double_height, c.ini_name . (c.is_num ? " Number" : ""),
            c.descr, c.v, c.extra_params*
        ])
    }

    tabs.UseTab("Gestures")
    s_gui.Add("Button", "vToggleGestureGeneral x15 y34 h20 w97 Disabled", "&General")
        .OnEvent("Click", ToggleGestureSettingsSubtab.Bind(1))
    s_gui.Add("Button", "vToggleGestureDefaults x112 yp0 h20 w97", "&Defaults")
        .OnEvent("Click", ToggleGestureSettingsSubtab.Bind(2))
    s_gui.Add("Button", "vToggleGestureColors x209 yp0 h20 w98", "&Colors")
        .OnEvent("Click", ToggleGestureSettingsSubtab.Bind(3))
    s_gui.Add("Button", "vToggleGestureZones x307 yp0 h20 w98", "&Zones")
        .OnEvent("Click", ToggleGestureSettingsSubtab.Bind(4))

    s_gui.CurrentGroup := s_gui.GestureGeneral
    b := true
    for c in CONF.Gestures {
        if c.ini_name == CONF.gest_color_mode.ini_name {
            continue
        }
        _AddElems(c.form_type, b ? 75 : "", , [
            c.double_height, c.ini_name . (c.is_num ? " Number" : ""),
            c.descr, c.v, c.extra_params*
        ])
        b := false
    }
    SendMessage(0x1501, true, StrPtr("Empty – own gesture color"), s_gui["ThumbnailColor"].Hwnd)

    s_gui.CurrentGroup := s_gui.GestureDefaults
    RegisterSettingsCtrl(s_gui.Add("Text", "x20 w380 y68 h34 Center",
        "Default gesture matching and color settings`n(can be overridden for each assignment)"))
    RegisterSettingsCtrl(s_gui.Add("Text", "x20 w380 y+8 h1 0x10"))

    for c in CONF.GestureDefaults {
        if A_Index == 4 {
            break
        }
        _AddElems(c.form_type, A_Index == 1 ? 124 : "", , [
            c.double_height, c.ini_name . (c.is_num ? " Number" : ""),
            c.descr, c.v, c.extra_params*
        ])
    }
    SendMessage(0x1501, true, StrPtr("0–0.99 (0 – size-independent)"), s_gui["Scaling"].Hwnd)

    s_gui.CurrentGroup := s_gui.GestureColors
    _RegisterGestureColorFixed(s_gui.Add("Text", "x20 w380 y68 h34 Center",
        "Default gesture colors`n(can be overridden for each assignment)"))
    _RegisterGestureColorFixed(s_gui.Add("Text", "x20 w380 y+8 h1 0x10"))
    c := CONF.gest_color_mode
    _RegisterGestureColorFixed(s_gui.Add("Text", "x15 y124 h20 w185", c.descr))
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
    RegisterSettingsCtrl(s_gui.Add("Button", "x210 y284 w65 h20 vZonePreviewOff", "Off"))
        .OnEvent("Click", ShowSettingsGestureZonePreview.Bind("Off"))
    RegisterSettingsCtrl(s_gui.Add("Button", "x+0 yp+0 w65 h20 vZonePreviewBlink Disabled", "Blink"))
        .OnEvent("Click", ShowSettingsGestureZonePreview.Bind("Blink"))
    RegisterSettingsCtrl(s_gui.Add("Button", "x+0 yp+0 w65 h20 vZonePreviewOn", "On"))
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
        _AddElems(c.form_type, A_Index == 1 ? 55 : "", , [
            c.double_height, c.ini_name . (c.is_num ? " Number" : ""),
            c.descr, c.v, c.extra_params*
        ])
    }
    s_gui.Add("Text", "x20 w380 y+8 h1 0x10")
    s_gui.Add("Text", "x20 w380 y+10 h34 Center", "Button indicator colors:")
    loop 8 {
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

    tabs.OnEvent("Change", SettingsTabChanged)
    SettingsTabChanged(tabs)

    s_gui.Show("w420 h505")
}


SettingsTabChanged(obj, *) {
    show_gestures := obj.Text == "Gestures"
    if !show_gestures {
        HideGestureZonePreview()
    }
    DllCall("SetFocus", "ptr", s_gui.Hwnd)
}


ToggleGestureSettingsSubtab(trg, *) {
    for i, group in [
        ["General", s_gui.GestureGeneral],
        ["Defaults", s_gui.GestureDefaults],
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

    if trg !== 4 {
        HideGestureZonePreview()
    }
    if trg == 3 {
        mode := GetSettingsCenterMode()
        if s_gui.GestureColorMapMode !== mode {
            b := 0
            s_gui.GestureColorMapMode := mode
            if mode == "Single" {
                s_gui["GestureColorMapC"].Move(110, 230, 200, 85)
                b := 1
            } else if mode == "Grid" {
                s_gui["GestureColorMapCA"].Move(110, 230, 100, 42)
                s_gui["GestureColorMapCB"].Move(210, 230, 100, 42)
                s_gui["GestureColorMapCD"].Move(110, 272, 100, 42)
                s_gui["GestureColorMapCC"].Move(210, 272, 100, 42)
            } else {
                s_gui["GestureColorMapCA"].Move(167, 230, 86, 26)
                s_gui["GestureColorMapCD"].Move(110, 260, 100, 26)
                s_gui["GestureColorMapCB"].Move(210, 260, 100, 26)
                s_gui["GestureColorMapCC"].Move(167, 289, 86, 26)
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
    } else if trg == 4 {
        ToggleSettingsZonePreviewMode(s_gui.ZonePreviewMode)
        if s_gui.ZonePreviewMode == "On" {
            ShowGestureZonePreview(GetSettingsGestureZoneOpts(), "On")
        }
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
    _RegisterGestureColorFixed(s_gui.Add("Text", "x20 y167 w380 h20 Center",
        "Default colors by gesture pool:"))

    x := 60
    y := 188
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
    group.Push(RegisterSettingsCtrl(s_gui.Add("Text", "x15 y366 h40 w200",
        color_conf.descr)))
    group.Push(RegisterSettingsCtrl(s_gui.Add("Edit", "Center x+0 yp+8 h20 w170 v"
        . color_conf.ini_name, color_conf.v)))
    group.Push(RegisterSettingsCtrl(s_gui.Add("Button", "x+1 yp+0 h20 w20 v"
        . color_conf.ini_name . "Pick", "🎨")))
    group[-1].OnEvent("Click", PasteColorFromPick.Bind(s_gui.Hwnd, s_gui[color_conf.ini_name], true))
    group.Push(RegisterSettingsCtrl(s_gui.Add("Text", "x15 y408 h20 w200",
        len_conf.descr)))
    group.Push(RegisterSettingsCtrl(s_gui.Add("Edit", "Center x+0 yp-2 h20 w190 Number v"
        . len_conf.ini_name, len_conf.v)))
    group.Push(RegisterSettingsCtrl(s_gui.Add("CheckBox", "x15 y434 h20 w380 v"
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
        field.Enabled := en.Value
        field.OnEvent("Change", RefreshSettingsGestureZonePreview)
        RegisterSettingsCtrl(s_gui.Add("Text", "x+4 yp+3 w18 h20", "px"))
        en.OnEvent("Click", ToggleGestureZoneEdit.Bind(field))
        y += 28
    }
}


ToggleGestureZoneEdit(field, obj, *) {
    field.Enabled := obj.Value
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
                RegisterSettingsCtrl(s_gui.Add("Text", "x15 y" . cur_h . " h" . h . " w190", arr[3]))
                elem := RegisterSettingsCtrl(
                    s_gui.Add("DropDownList", "x+10 yp" . ysh . " w190 v" . name, arr[5])
                )
                if arr[6] {
                    elem.Text := arr[4]
                } else {
                    elem.Value := arr[4]
                }
            case "str":
                RegisterSettingsCtrl(s_gui.Add("Text", "x15 y" . cur_h . " h" . h . " w200", arr[3]))
                RegisterSettingsCtrl(
                    s_gui.Add("Edit", "Center x+0 yp" . ysh . " h20 w190 v" . name, arr[4])
                )
            case "checkbox":
                RegisterSettingsCtrl(
                    s_gui.Add("CheckBox", "x15 y" . cur_h . " h" . h . " w380 v" . name, arr[3])
                ).Value := arr[4]
            case "h_checkbox":
                fn := MsgBox.Bind(arr[5], arr[6], "IconI")
                RegisterSettingsCtrl(s_gui.Add("Button", "x11 y" . cur_h . " h20 w20", "?"))
                    .OnEvent("Click", (*) => fn.Call())
                RegisterSettingsCtrl(
                    s_gui.Add("CheckBox", "x+3 w350 yp+0 h20 v" . name, arr[3])
                ).Value := arr[4]
            case "color":
                RegisterSettingsCtrl(s_gui.Add("Text", "x15 y" . cur_h . " h" . h . " w200", arr[3]))
                RegisterSettingsCtrl(
                    s_gui.Add("Edit", "Center x+0 yp" . ysh . " h20 w170 v" . name, arr[4])
                )
                RegisterSettingsCtrl(s_gui.Add("Button", "x+1 yp+0 h20 w20 v" . name . "Pick", "🎨"))
                    .OnEvent("Click", PasteColorFromPick.Bind(s_gui.Hwnd, s_gui[name], false))
            case "m_color":
                RegisterSettingsCtrl(s_gui.Add("Text", "x15 y" . cur_h . " h" . h . " w200", arr[3]))
                RegisterSettingsCtrl(
                    s_gui.Add("Edit", "Center x+0 yp" . ysh . " h20 w170 v" . name, arr[4])
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

        for name in ["Main", "GUI", "Gestures", "GestureDefaults", "GestureZones", "Colors"] {
            for elem in CONF.%name% {
                val := GetSettingsValue(name, elem)
                IniWrite(val, "config.ini", name, elem.ini_name)
                elem.v := elem.val_type == "int" ? Integer(val)
                    : elem.val_type == "float" ? Round(Float(val), 2) : val
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
            try overlay.Destroy()
            overlay := false
            DrawLayout()
        }
        CloseSettingsEvent(false)
    }
}


CheckChanges(strict:=false, selected:=false, *) {
    for name in ["Main", "GUI", "Gestures", "GestureDefaults", "GestureZones", "Colors"] {
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

    return elem.form_type == "color" || elem.form_type == "m_color" || elem.form_type == "str"
        || elem.form_type == "ddl" && elem.val_type == "str"
            ? s_gui[elem.ini_name].Text : s_gui[elem.ini_name].Value
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
