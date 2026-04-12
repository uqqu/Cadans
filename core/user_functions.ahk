; TODO all :(
outs := Map(
    "Output: SendText", (txt, _) => SendInput("{Raw}" . txt),
    "Output: Clipboard", (txt, _) => (A_Clipboard := txt, 0),
    "Ouptut: Tooltip", (txt, t) => (Tooltip(txt), SetTimer(() => Tooltip(), -t || -3000)),
    "Output: MessageBox", (txt, _) => MsgBox(txt, "Result")
)

inps := Map(
    "Input: Clipboard", () => A_Clipboard,
    "Input: InputBox", () => InputBox("Write text to processing").Value,
    "Input: Selected", () => _FromSelected()
)

_FromSelected() {
    saved := ClipboardAll()
    A_Clipboard := ""
    SendInput("^{SC02E}")

    ClipWait(1)
    if A_Clipboard == "" {
        return
    }
    res := A_Clipboard
    A_Clipboard := saved
    return res
}


SetActiveLayers(layers*) {
    global ActiveLayers

    ActiveLayers := OrderedMap()
    for layer in layers {
        ActiveLayers.Add(layer)
    }
    _WriteActiveLayersToConfig()
}


ToggleLayers(layers*) {
    global ActiveLayers

    for layer in layers {
        layer_pos := layer[1]
        layer_name := layer[2]
        if ActiveLayers.map.Has(layer_name) {
            ActiveLayers.Remove(layer_name)
        } else {
            ActiveLayers.Add(layer_name, , layer_pos)
            if AllLayers.map[layer_name] is Integer {
                MergeLayer(layer_name)
            }
        }
    }
    _WriteActiveLayersToConfig()
}


ActivateApp(path, process_name:="") {
    try {
        name := "ahk_exe " . process_name
        WinActive(name) ? WinMinimize(name) : WinActivate(name)
    } catch {
        if path {
            Run(path)
        }
    }
}


ToggleMod(md) {
    global current_mod

    current_mod ^= 1 << md
}


GetDateTime(val, out:="Ouptut: Tooltip", t:=false) {
    outs[out](FormatTime(, val), t)
}


GetCustomDateTime(val, out:="Ouptut: Tooltip", t:=false) {
    outs[out](FormatTime(, val), t)
}


GetWeather(city_name, out:="Ouptut: Tooltip", t:=false) {
    static weather_key:=RegRead("HKEY_CURRENT_USER\Environment", "OpenWeatherMapApi", 0)

    if !weather_key {
        if !CONF.HasOwnProp("user_OpenWeatherMapApi") {
            MsgBox("The api key was not found in the environment variables or in the config.",
                "OpenWeatherMapApi", "IconX")
            return
        } else {
            weather_key := CONF.user_OpenWeatherMapApi.v
        }
    }

    if !city_name {
        city_name := InputBox("City name", "Get weather", "h100 w170").Value
    }

    web_request := ComObject("WinHttp.WinHttpRequest.5.1")
    web_request.Open("GET",
        "https://api.openweathermap.org/data/2.5/weather?q=" . city_name
        . "&appid=" . weather_key . "&units=metric"
    )
    web_request.Send()

    stat := StrTitle(RegExReplace(web_request.ResponseText, '.+"main":"(\w+)".+', "$1"))
    temp := RegExReplace(web_request.ResponseText, '.+"temp":(-?\d+\.\d+).+', "$1")
    feel := RegExReplace(web_request.ResponseText, '.+"feels_like":(-?\d+\.\d+).+', "$1")
    wind := RegExReplace(web_request.ResponseText, '.+"speed":(\d+\.\d+|\d+).+', "$1")

    outs[out](city_name . ":`n" . stat . "`n" . temp . "° (" . feel . "°)`n" . wind . "m/s", t)
}


ExchRates(from_currency, to_currency, out:="Ouptut: Tooltip", t:=false) {
    static currency_key:=RegRead("HKEY_CURRENT_USER\Environment", "GetGeoApi", 0)

    if !currency_key {
        if !CONF.HasOwnProp("user_GetGeoApi") {
            MsgBox("The api key was not found in the environment variables or in the config.",
                "GetGeoApi", "IconX")
            return
        } else {
            currency_key := CONF.user_GetGeoApi.v
        }
    }

    web_request := ComObject("WinHttp.WinHttpRequest.5.1")
    web_request.Open("GET",
        "https://api.getgeoapi.com/api/v2/currency/convert?api_key="
        . currency_key . "&from=" . from_currency . "&to=" . to_currency . "&amount=1&format=json"
    )
    web_request.Send()

    res := RegExMatch(web_request.ResponseText, '"rate_for_amount":"(\d+\.\d+)"', &m) ? m[1] : 0
    outs[out](from_currency . "–" . to_currency . ": " . Round(res, 2), t)
}


WikiSummary(lang:="en", inp:="Input: InputBox", out:="Ouptut: Tooltip", t:=false) {
    url := "https://" . lang . ".wikipedia.org/api/rest_v1/page/summary/" . inps[inp]()
    web_request := ComObject("WinHttp.WinHttpRequest.5.1")
    web_request.Open("GET", url)
    web_request.Send()
    bin := web_request.ResponseBody

    stream := ComObject("ADODB.Stream")
    stream.Type := 1
    stream.Open()
    stream.Write(bin)
    stream.Position := 0
    stream.Type := 2
    stream.Charset := "utf-8"
    txt := stream.ReadText()
    stream.Close()

    if RegExMatch(txt, '"extract"\s*:\s*"([^"]+)"', &m) {
        outs[out](StrReplace(m[1], "\n", "`n"), t)
    }
}


Reminder(given_minutes:=0) {
    if given_minutes {
        SetTimer(_Alarma, -given_minutes * 60000)
        return
    }
    res := InputBox("Remind me in ... minutes", "Reminder", "h100 w250")
    if res.Result == "OK" {
        try {
            delay := res.Value * 60000
            SetTimer(_Alarma, -delay)
        } catch {
            if MsgBox("The input must be a number!", "Incorrect value", 53) == "Retry" {
                Reminder()
            }
        }
    }
}

_Alarma() {
    MsgBox("Reminder", "Reminder", 48)
}


DelayedMediaPlayPause(given_minutes:=0) {
    if given_minutes {
        SetTimer(_MPPTimer, -given_minutes * 60000)
        return
    }
    res := InputBox("Trigger the play/pause after ... minutes", "", "h100 w250")
    if res.Result == "OK" {
        try {
            delay := res.Value * 60000
            SetTimer(_MPPTimer, -delay)
        } catch {
            if MsgBox("The input must be a number!", "Incorrect value", 53) == "Retry" {
                DelayedMediaPlayPause()
            }
        }
    }
}

_MPPTimer() {
    SendInput("{Media_Play_Pause}")
}


ChangeTextCase(change_name, inp:="Input: InputBox", out:="Ouptut: Tooltip", t:=false) {
    txt := inps[inp]()
    switch change_name {
        case "Normalize":
            result := Trim(RegExReplace(StrLower(txt), "[ \t]+", " "))
            result := RegExReplace(result, " ?([.,!?;]+) ?", "$1 ")
            result := RegExReplace(result, "((^|[.!?]\s|^[–—]\s)([a-zа-яё]))", "$U1")
            changed_txt := RegExReplace(result, "\bi(['’])\b", "I$1")
        case "Title":
            changed_txt := StrTitle(txt)
        case "Lower":
            changed_txt := StrLower(txt)
        case "Upper":
            changed_txt := StrUpper(txt)
        case "Invert":
            result := ""
            for char in StrSplit(txt) {
                is_upper := char ~= "^[A-ZА-ЯЁ]$"
                is_lower := char ~= "^[a-zа-яё]$"

                if is_upper {
                    result .= StrLower(char)
                } else if is_lower {
                    result .= StrUpper(char)
                } else {
                    result .= char
                }
            }
            changed_txt := result
    }
    outs[out](changed_txt, t)
}


SmartTranslit(inp:="Input: InputBox", out:="Ouptut: Tooltip", t:=false) {
    static to_cyr:=Map(
        "shch", "щ", "yo", "ё", "zh", "ж", "kh", "х", "ts", "ц", "ch", "ч", "sh", "ш", "yu", "ю",
        "ya", "я", "a", "а", "b", "б", "v", "в", "g", "г", "d", "д", "e", "е", "z", "з", "i", "и",
        "y", "й", "k", "к", "l", "л", "m", "м", "n", "н", "o", "о", "p", "п", "r", "р", "s", "с",
        "t", "т", "u", "у", "f", "ф", "h", "х", "c", "ц", "'", "ь", "``", "ъ"
    )
    static to_lat:=Map()
    for k, v in to_cyr {
        if !to_lat.Has(v) {
            to_lat[v] := k
        }
    }

    txt := inps[inp]()

    reverse := !RegExMatch(txt, "[а-яА-ЯёЁ]")
    keys := []

    table := reverse ? to_cyr : to_lat
    for k in table {
        keys.Push(k)
    }
    _SortByLengthDesc(keys)

    result := ""
    i := 1

    while i <= StrLen(txt) {
        matched := false
        for k in keys {
            len := StrLen(k)
            chunk := SubStr(txt, i, len)
            if StrLower(chunk) == k {
                repl := table[k]
                result .= _PreserveCase(chunk, repl)
                i += len
                matched := true
                break
            }
        }
        if !matched {
            result .= SubStr(txt, i, 1)
            i++
        }
    }

    outs[out](result, t)
}


_PreserveCase(from, to) {
    if from == "" || to == ""
        return to
    if RegExMatch(from, "^[A-ZА-ЯЁ]+$") {
        return StrUpper(to)
    } else if RegExMatch(from, "^[a-zа-яё]+$") {
        return StrLower(to)
    } else if RegExMatch(from, "^[A-ZА-ЯЁ][a-zа-яё]+$") {
        return StrUpper(SubStr(to, 1, 1)) . SubStr(to, 2)
    } else {
        return to
    }
}

_SortByLengthDesc(arr) {
    loop arr.Length {
        loop arr.Length - 1 {
            if StrLen(arr[A_Index]) < StrLen(arr[A_Index + 1]) {
                tmp := arr[A_Index]
                arr[A_Index] := arr[A_Index + 1]
                arr[A_Index + 1] := tmp
            }
        }
    }
}


IncrDecr(n:=1, inp:="Input: Selected", out:="Output: SendText") {
    val := inps[inp]()
    start := 1
    last_pos := false

    while (p := RegExMatch(val, "(-?\d+(?:\.\d+)?)", &m, start)) {
        last_pos := p
        last_text := m[0]
        last_len := StrLen(last_text)
        start := p + last_len
    }

    if last_pos {
        num := last_text

        if InStr(num, ".") {
            dec_places := 0
            dot_pos := InStr(num, ".")
            if dot_pos {
                dec_places := StrLen(num) - dot_pos
            }
            num_val := Round(num + 1*n, dec_places)
            new_num := num_val
        } else {
            num_val := num + 1*n
            new_num := num_val
        }

        new_text := SubStr(val, 1, last_pos - 1) . new_num . SubStr(val, last_pos + last_len)
    } else {
        order := Ord(SubStr(val, -1)) + 1*n
        if order == 31 {
            order := 32
        } else if order < 31 {
            return
        }

        while RegExMatch(Chr(order), "\p{M}|\p{C}") || order == 6277 || order == 6278 {
            order := order + 1*n
        }
        new_text := SubStr(val, 1, -1) . Chr(order)
    }

    outs[out](new_text, 0)
    if out == "Output: SendText" {
        all_len := StrLen(new_text)
        Send("{Left " . all_len . "}+{Right " . all_len . "}")
    }
}


PasteWithIncrDecr(n:=1) {
    IncrDecr(n, "Input: Clipboard", "Output: Clipboard")
    SendInput("^{SC02F}")
}


CustomString(txt, out:="Ouptut: Tooltip", t:=false) {
    outs[out](txt, t)
}


RemoveTextFormatting(inp:="Input: InputBox", out:="Ouptut: Tooltip", t:=false) {
    str := inps[inp]()
    outs[out](str, t)
}


ShortenURL(inp:="Input: InputBox", out:="Ouptut: Tooltip", t:=false) {
    url := inps[inp]()
    if !RegExMatch(url, "^https?://[^\s`"']+$") {
        outs[out](url, t)
        return
    }

    try {
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("GET", "https://tinyurl.com/api-create.php?url=" . url, true)
        http.Send()
        http.WaitForResponse()
        if http.ResponseText == "Error" {
            throw
        }
        outs[out](http.ResponseText, t)
    } catch {
        outs[out](url, t)
    }
}


ClipboardSwap() {
    new_text := _FromSelected()
    Sleep(50)
    outs["Output: SendText"](A_Clipboard, 0)
    Sleep(50)
    A_Clipboard := new_text
}


MinimizeWindows() {
    if WinGetTitle("A") !== "Program Manager" {
        WinMinimizeAll
    }
}


GenerateRandomPass(len:=12, extra_symbs:="", out:="Ouptut: Tooltip", t:=false) {
    chars := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" . extra_symbs
    pass := ""
    loop len {
        pass .= SubStr(chars, Random(1, StrLen(chars)), 1)
    }
    outs[out](pass, t)
}


ChangeDefaultHoldTime(new_val:=5) {
    CONF.MS_LP.v += Integer(new_val)
    CONF.T := "T" . CONF.MS_LP.v / 1000
    A_TrayMenu.Rename("1&", "+10ms hold threshold (to " . CONF.MS_LP.v + 10 . "ms)")
    A_TrayMenu.Rename("2&", "-10ms hold threshold (to " . CONF.MS_LP.v - 10 . "ms)")
    IniWrite(CONF.MS_LP.v, "config.ini", "Main", "LongPressDuration")
}


g_autoscroll := {active: false}

AutoScrollStart(direction:="down", speed:=100, target:="cursor", accel:=0, stop_on_any_press:=true) {
    AutoScrollStop()

    dir := (direction == "down") ? [1, 0]
        : (direction == "up") ? [1, 1]
        : (direction == "right") ? [0, 1]
        : (direction == "left") ? [0, 0]
        : false

    if !dir {
        return false
    }

    if target == "cursor" {
        MouseGetPos &x, &y, &win, &ctl, 3
        hwnd := ctl ? ctl : win
    } else {
        hwnd := WinGetID("A")
    }
    if !hwnd {
        return false
    }

    tick_ms := 10
    px_per_tick := Integer(speed) * (tick_ms/1000.0)
    wheel_delta_per_px := 120.0 / 40.0
    base_delta := Round(px_per_tick * wheel_delta_per_px)
    if base_delta < 1 {
        base_delta := 1
    }

    g_autoscroll.active := true
    g_autoscroll.hwnd := hwnd
    g_autoscroll.tick_ms := tick_ms
    g_autoscroll.dir := dir
    g_autoscroll.base_delta := base_delta
    g_autoscroll.accel := Integer(accel)
    g_autoscroll.t0 := A_TickCount

    if Integer(stop_on_any_press) {
        _AS_InstallStopHooks()
    }

    SetTimer(_AS_Tick, -g_autoscroll.tick_ms)
    return true
}

AutoScrollStop(*) {
    if g_autoscroll.active {
        g_autoscroll.active := false
        _AS_RemoveStopHooks()
    }
}

_AS_Tick() {
    if !g_autoscroll.active {
        return
    }

    if !DllCall("IsWindow", "ptr", g_autoscroll.hwnd, "int") {
        AutoScrollStop()
        return
    }

    delta := g_autoscroll.base_delta
    if g_autoscroll.accel > 0 {
        elapsed := (A_TickCount - g_autoscroll.t0) / 1000.0
        factor := 1 + (g_autoscroll.accel == 1 ? 0.5 : 1.2) * elapsed
        delta := Round(delta * (factor > 4 ? 4 : factor))
    }

    signed_delta := delta * (g_autoscroll.dir[2] ? 1 : -1)

    MouseGetPos &mx, &my
    PostMessage (g_autoscroll.dir[1] ? 0x20A : 0x20E),
        (signed_delta & 0xFFFF) << 16,
        (my & 0xFFFF) << 16 | (mx & 0xFFFF),
        , g_autoscroll.hwnd
    SetTimer(_AS_Tick, -g_autoscroll.tick_ms)
}


_AS_InstallStopHooks() {
    for sc in ALL_SCANCODES {
        Hotkey "~*" . (sc is Number ? SC_STR[sc] : sc), AutoScrollStop, "On"
    }
}

_AS_RemoveStopHooks() {
    for sc in ALL_SCANCODES {
        Hotkey "~*" . (sc is Number ? SC_STR[sc] : sc), "Off"
    }
}



; don't look here
custom_funcs := Map(
    "SetActiveLayers", ["Set specified layers as current active layers. Multifield.",
        ["Layer name"]
    ],
    "ToggleLayers", ["Toggle the activity of specified layers. Multifield.",
        ["Priority", "Layer name"]],
    "TreatAsOtherNode", [
        "Go to assignment by given path (both in terms of value and transitions). "
        . "Set path step by step (multifield) from root node. You can use shortnames "
        . "%sc% and %md% for autocomplete.",
        ["Scancode (integer) or chord string. '%sc%' is short for current one.",
        "Modifier value. 0/1/…, or '%md%' for autocomplete with current.",
        "Is chord? false/true / 0/1"]
    ],
    "ActivateApp", ["Run app by given path or switch to it process, if specified.",
        "Path to app", "Process name (can be ommited)"
    ],
    "ToggleMod", ["Toggle specified mod value (in script terms, not system modifiers).",
        "Mod value"
    ],
    "GetDateTime", ["Get the current date(time) with selected format.", 3, 2],
    "GetCustomDateTime", ["Get the current datetime with your own format. Without commas!",
        "i.e. 'dddd d MMMM yyyy HH:mm'", 2
    ],
    "GetWeather", ["Get the current weather in specified city "
        . "(requires API key OPENWEATHERMAP in the environment variables).",
        "City name", 2
    ],
    "ExchRates", ["Get the current currency rate for specified pair "
        . "(requires API key GETGEOAPI in the environment variables).",
        "From currency", "To currency", 2
    ],
    "WikiSummary", ["Get the first paragraph from wiki article", "Language code (en/ru/es) [en]", 1, 2],
    "Reminder", ["Set a reminder after a specified number of minutes. "
        . "If value is ommited you will be asked for input when you call the function",
        "Number of minutes"
    ],
    "DelayedMediaPlayPause", ["Start or stop music after a specified number of minutes. "
        . "If value is ommited you will be asked for input when you call the function",
        "Number of minutes"
    ],
    "ChangeTextCase", ["Align the case and spaces of the specified text.", 4, 1, 2],
    "SmartTranslit", ["Транслэйт фром зэ вронг скрипт. `nРаугли, бат андерстэндэйбл."
        . "`nI naoborot, konechno.", 1, 2
    ],
    "IncrDecr", ["Increase/decrease string with number or last symbol (by unicode table)",
        "Increase/decrease value (int). 1, -1, 42, … [1]", 1, 2],
    "PasteWithIncrDecr", ["Increase value in clipboard and paste it.",
        "Increase/decrease value (int). 1, -1, 42, … [1]"],
    "CustomString", ["Just return custom text to chosen output.", "Text", 2],
    "RemoveTextFormatting", ["Removing formatting (italic, bold, etc.) from a given text", 1, 2],
    "ShortenURL", ["Get short url with tinyurl api", 1, 2],
    "ClipboardSwap", ["Paste clipboard and save selected as a new clipboard value"],
    "MinimizeWindows", ["Carefully minimize all windows"],
    "GenerateRandomPass", ["Generate new password with alphanumerical range and your own extra "
        . "symbols", "Password length [12]", "Extra symbols", 2],
    "ChangeDefaultHoldTime", ["Increase/decrease the hold time value from the config on fly.",
        "+5 / -20 / … [+5]"],
    "AutoScrollStart", ["Start smooth scrolling.",
        "Direction ('up'/'down'/'right'/'left') [down]",
        "Speed of scrolling [100]", "Target ('active' window or under 'cursor') [cursor]",
        "Acceleration (0-2) [0]",
        "Stop on any press (0/1) [1]"],
    "AutoScrollStop", ["Pair to the previous function, in case you want to manually stop scrolling."],
)

custom_func_keys := ["SetActiveLayers", "ToggleLayers", "TreatAsOtherNode", "ActivateApp",
    "ToggleMod", "GetDateTime", "GetCustomDateTime", "GetWeather", "ExchRates", "WikiSummary",
    "Reminder", "DelayedMediaPlayPause", "ChangeTextCase", "SmartTranslit", "IncrDecr",
    "PasteWithIncrDecr", "ClipboardSwap", "CustomString", "RemoveTextFormatting", "ShortenURL",
    "MinimizeWindows", "GenerateRandomPass", "ChangeDefaultHoldTime",
    "AutoScrollStart", "AutoScrollStop"
]

custom_func_ddls := [
    ["Input: Selected", "Input: Clipboard", "Input: InputBox"],
    ["Output: SendText", "Output: Clipboard", "Ouptut: Tooltip", "Output: MessageBox"],
    ["dddd d MMMM yyyy HH:mm", "dd.MM.yyyy HH:mm", "dd.MM.yyyy HH:mm:ss", "MM/dd/yyyy h:mm tt",
    "yyyy-MM-ddTHH:mm:ss", "yyyy-MM-dd_HH-mm-ss", "HH:mm:ss", "d MMMM yyyy",
    "dd MMMM yyyy", "dd.MM.yy"],
    ["Normalize", "Title", "Lower", "Upper", "Invert"]
]


_ParseFuncArgs(s) {
    args := []
    buffer := ""
    in_array := false
    arr_buf := []

    skip := false
    i := 1
    len := StrLen(s)

    while i <= len {
        ch := SubStr(s, i, 1)

        if skip {
            buffer .= ch
            skip := false
        } else if ch == "\" {
            skip := true
        } else if ch == "[" {
            if in_array {
                buffer .= ch
            } else {
                in_array := true
                arr_buf := []
                buffer := ""
            }
        } else if ch == "]" {
            if in_array {
                if Trim(buffer) !== "" {
                    arr_buf.Push(Trim(buffer))
                }
                args.Push(arr_buf)
                in_array := false
                buffer := ""
            } else {
                buffer .= ch
            }
        } else if ch == "," && SubStr(s, i+1, 1) == " " {
            if in_array {
                arr_buf.Push(Trim(buffer))
            } else {
                args.Push(Trim(buffer))
            }
            buffer := ""
            i += 1
        } else {
            buffer .= ch
        }

        i += 1
    }

    if Trim(buffer) !== "" {
        in_array ? arr_buf.Push(Trim(buffer)) : args.Push(Trim(buffer))
    }

    return args
}