SerializeMap(mp, filename, conv:=false) {
    for lang, values in mp {
        _CleanMap(values)
    }
    m := LayersMeta[filename]

    try FileDelete("layers/" . filename . ".json")
    FileAppend(
        "// 0.81`r`n// " . m["rtags"] . "`r`n// "
        . m["rdescription"] . "`r`n// " . m["rprocesses"] . "`r`n" . Dump(mp, "", conv),
        "layers/" . filename . ".json", "UTF-8"
    )
}


_CleanMap(mp, parent_md:=0) {
    for opt in [mp[-3], mp[-2], mp[-1]] {
        to_del_sc := []
        for schex, mods in opt {
            to_del_md := []
            for md, val in mods {
                if !_CleanMap(val, md) {
                    to_del_md.Push(md)
                }
            }
            for md in to_del_md {
                mods.Delete(md)
            }
            if !mods.Count {
                to_del_sc.Push(schex)
            }
        }
        for schex in to_del_sc {
            opt.Delete(schex)
        }
    }
    ref := parent_md ? TYPES.Disabled : TYPES.Default
    if mp.Length > 2 && !mp[-3].Count && !mp[-2].Count && !mp[-1].Count && mp[1] == ref && !mp[2]
        && mp[3] == TYPES.Disabled && !mp[4] && !mp[5] && !mp[6] && !mp[7] && !mp[8] {
        return false
    }
    return true
}


DeserializeMap(filename) {
    data := FileRead("layers/" . filename . ".json")
    ver := LayersMeta[filename]["version"]
    struct := Load(StripLineComments(data))
    if ver < 0.71 {
        UpdateLayerVersion(struct, ver)
    }
    return struct
}


_GetMetaInfo(data) {
    res := Map("version", 0.6, "rtags", "", "rdescription", "", "rprocesses", "",
        "tags", [], "processes", Map("*", true))
    lns := StrSplit(data, "`n", "`r`n`t ", 5)

    if RegExMatch(lns[1], "^//\s*([0-9]+(?:\.[0-9]+)?)", &m) {
        res["version"] := Number(m[1])
    }

    for i, name in ["rtags", "rdescription", "rprocesses"] {
        if StrLen(lns[i+1]) > 3 && SubStr(lns[i+1], 1, 2) == "//" {
            res[name] := Trim(SubStr(lns[i+1], 3), "`r`n`t ")
        }
    }

    if StrLen(res["rtags"]) {
        for tag in StrSplit(res["rtags"], ",", "`r`n`t ") {
            if StrLen(tag) {
                res["tags"].Push(tag)
                AllTags[tag] := true
            }
        }
    }
    if !res["tags"].Length {
        res["tags"].Push("<untagged>")
        AllTags["<untagged>"] := true
    }

    if StrLen(res["rprocesses"]) {
        res["processes"] := ParseProcessesRule(res["rprocesses"])
    }

    return res
}


ParseProcessesRule(rule_str) {
    ops := OrderedMap()
    rule_str := Trim(rule_str)

    if !rule_str {
        return Map("*", true)
    }

    current_sign := ""
    first_sign := ""

    for part in StrSplit(rule_str, ",", " `t`r`n") {
        part := Trim(part)
        if !part {
            continue
        }

        sign := SubStr(part, 1, 1)
        if sign == "+" || sign == "-" {
            current_sign := sign
            if !first_sign {
                first_sign := sign
            }
            name := NormName(SubStr(part, 2))
        } else {
            if !current_sign {
                continue
            }
            sign := current_sign
            name := NormName(part)
        }

        if !name {
            continue
        }

        ops.Set(name, sign == "+")
    }

    if !first_sign {
        return Map("*", true)
    }

    res := Map("*", first_sign == "-")
    for name in ops.order {
        res[name] := ops[name]
    }

    return res
}


UpdateLayerVersion(data, from) {
    stack := []
    for lang, vals in data {
        if vals.Length {
            stack.Push(vals)
        }
    }

    while stack.Length {
        p := stack.RemoveAt(1)

        if from < 0.7 {
            for t in [p[-1], p[-2]] {
                for _, schex_val in t {
                    for _, md_val in schex_val {
                        stack.Push(md_val)
                    }
                }
            }
            p.Push(Map())  ; gestures map
            if p.Length !== 4 {
                p.InsertAt(9, (p[1] == TYPES.Modifier ? 5 : 4))  ; unassigned child behavior
                p.InsertAt(11, "")  ; gesture options
            }
        } else if from == 0.7 {  ; fix wrong 0.7 gesture_options position
            for t in [p[-2], p[-3], p[-4]] {
                for _, schex_val in t {
                    for _, md_val in schex_val {
                        stack.Push(md_val)
                    }
                }
            }
            if p.Length !== 4 {
                p.InsertAt(11, p.Pop())
            } else {
                p.InsertAt(1, p.Pop())
            }
            p[-4] := "5;0;0.00;0;0;1"
        }
    }
}


StripLineComments(s) {
    out := ""
    inStr := false
    esc := false
    i := 1
    len := StrLen(s)
    while (i <= len) {
        ch := SubStr(s, i, 1)
        if (!inStr) {
            if (ch == "`"") {
                inStr := true
                out .= ch
                i++
                continue
            }
            if (ch == "/" && SubStr(s, i+1, 1) == "/") {
                j := i + 2
                while (j <= len) {
                    ch2 := SubStr(s, j, 1)
                    if (ch2 == "`n") {
                        break
                    }
                    j++
                }
                i := j
                continue
            }
            out .= ch
            i++
            continue
        } else {
            if (esc) {
                esc := false
                out .= ch
                i++
                continue
            }
            if (ch == "\") {
                esc := true
                out .= ch
                i++
                continue
            }
            if (ch == "`"") {
                inStr := false
                out .= ch
                i++
                continue
            }
            out .= ch
            i++
            continue
        }
    }
    return out
}


Load(json) {
    p := 1
    return ParseValue(&p, json)
}


ParseValue(&p, s) {
    SkipWhitespace(&p, s)
    ch := SubStr(s, p, 1)

    if ch == "{" {
        return ParseObject(&p, s)
    }
    if ch == "[" {
        return ParseArray(&p, s)
    }
    if ch == "`"" {
        return ParseString(&p, s)
    }
    if ch ~= "[-\d]" {
        return ParseNumber(&p, s)
    }
    if SubStr(s, p, 4) == "null" {
        p += 4
        return ""
    }
    throw Error("Unexpected value at position " . p)
}


ParseObject(&p, s) {
    obj := Map()
    p++
    SkipWhitespace(&p, s)
    if SubStr(s, p, 1) == "}" {
        p++
        return obj
    }

    loop {
        SkipWhitespace(&p, s)
        key := ParseString(&p, s)
        SkipWhitespace(&p, s)
        if SubStr(s, p, 1) !== ":" {
            throw Error("Expected ':' at " . p)
        }
        p++
        value := ParseValue(&p, s)
        if StrLen(key) !== 96 {
            try key := Integer(key)
        }
        obj[key] := value
        SkipWhitespace(&p, s)
        ch := SubStr(s, p, 1)
        if ch == "}" {
            p++
            return obj
        }
        if ch !== "," {
            throw Error("Expected ',' or '}' at " . p)
        }
        p++
    }
}


ParseArray(&p, s) {
    arr := []
    p++
    SkipWhitespace(&p, s)
    if SubStr(s, p, 1) == "]" {
        p++
        return arr
    }

    loop {
        arr.Push(ParseValue(&p, s))
        SkipWhitespace(&p, s)
        ch := SubStr(s, p, 1)
        if ch == "]" {
            p++
            return arr
        }
        if ch !== "," {
            throw Error("Expected ',' or ']' at " . p)
        }
        p++
    }
}


ParseString(&p, s) {
    if SubStr(s, p, 1) !== "`"" {
        throw Error("Expected string at " . p)
    }
    p++
    str := ""
    while p <= StrLen(s) {
        ch := SubStr(s, p, 1)
        if ch == "`"" {
            p++
            return str
        }
        if ch == "\" {
            p++
            esc := SubStr(s, p, 1)
            p++
            str .= esc = "n" ? "`n"
                 : esc = "r" ? "`r"
                 : esc = "t" ? "`t"
                 : esc = '"' ? '"'
                 : esc = "\" ? "\"
                 : esc = "b" ? "`b"
                 : esc = "f" ? "`f"
                 : esc = "/" ? "/"
                 : esc = "u" ? ParseUnicode(&p, s)
                 : esc
            continue
        }
        str .= ch
        p++
    }
    throw Error("Unterminated string at " . p)
}


ParseUnicode(&p, s) {
    hex := SubStr(s, p, 4)
    p += 4
    return Chr("0x" . hex)
}


ParseNumber(&p, s) {
    start := p
    if SubStr(s, p, 1) == "-" {
        p++
    }
    while SubStr(s, p, 1) ~= "\d" {
        p++
    }
    if SubStr(s, p, 1) == "." {
        p++
        while SubStr(s, p, 1) ~= "\d" {
            p++
        }
    }
    if SubStr(s, p, 1) ~= "[eE]" {
        p++
        if SubStr(s, p, 1) ~= "[-+]" {
            p++
        }
        while SubStr(s, p, 1) ~= "\d" {
            p++
        }
    }
    return Number(SubStr(s, start, p - start))
}


SkipWhitespace(&p, s) {
    while SubStr(s, p, 1) ~= "\s" {
        p++
    }
}


Dump(obj, indent:="", conv:=false) {
    if obj is Map {
        out := "{"
        for k, v in obj {
            out .= "`n" . indent . "  " . "`"" . EscapeStr(k, conv) . "`": "
                . Dump(v, indent . "  ", conv) . ","
        }
        return out ~= ",$" ? SubStr(out, 1, -1) . "`n" . indent . "}" : out . "}"
    }

    if obj is Array {
        out := "["
        for v in obj {
            out .= "`n" . indent . "  " . Dump(v, indent . "  ", conv) . ","
        }
        return out ~= ",$" ? SubStr(out, 1, -1) . "`n" . indent . "]" : out . "]"
    }

    if IsObject(obj) {
        out := "{"
        for k, v in obj.OwnProps() {
            out .= "`n" . indent . "  " . "`"" . EscapeStr(k, conv) . "`": "
                . Dump(v, indent . "  ", conv) . ","
        }
        return out ~= ",$" ? SubStr(out, 1, -1) . "`n" . indent . "}" : out . "}"
    }

    if obj is Number {
        return obj
    }

    if obj == "" {
        return "null"
    }

    return "`"" . EscapeStr(obj, conv) . "`""
}


EscapeStr(str, conv:=false) {
    if conv {
        pref := SubStr(str, 1, 6)
        str := pref == "{Text}" ? SubStr(str, 7) : pref == "{Blind" ? SubStr(str, 8) : str
        if RegExMatch(str, "^([\^+!#]*)\{(.+)\}$", &m) {
            sc := GetKeySC(m[2])
            if sc {
                return m[1] . sc
            }
        }
    }
    str .= ""
    str := StrReplace(str, "\", "\\")
    str := StrReplace(str, '"', '\"')
    str := StrReplace(str, "`r", "\r")
    str := StrReplace(str, "`n", "\n")
    str := StrReplace(str, "`t", "\t")
    return str
}