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
        "tags", [], "processes", [{invert: false, kind: "*", val: "*", children: []}])
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
        res["processes"] := ParseProcessesString(res["rprocesses"])
    }

    return res
}


ParseProcessesString(s) {
    rules := []

    for part in SplitTopLevelComma(s) {
        for rule in ParseWindowRuleExpanded(part) {
            rules.Push(rule)
        }
    }

    return rules
}


ParseWindowRuleExpanded(s, seen:=false) {
    rule := ParseWindowRule(s)
    return ExpandWindowRule(rule, seen)
}


ExpandWindowRule(rule, seen:=false) {
    seen := seen || Map()

    if rule.kind != "p" || !CONF.ProcessGroups.Has(rule.val) {
        return [rule]
    }

    group_name := rule.val

    if seen.Has(group_name) {
        return []
    }

    seen[group_name] := true

    res := []

    for group_part in SplitTopLevelComma(CONF.ProcessGroups[group_name]) {
        for group_rule in ParseWindowRuleExpanded(group_part, seen) {
            group_rule.invert := rule.invert ? !group_rule.invert : group_rule.invert

            for child in rule.children {
                group_rule.children.Push(CloneWindowRule(child))
            }

            res.Push(group_rule)
        }
    }

    seen.Delete(group_name)
    return res
}


WindowRulePredicate(rule, proc, cls:="", title:="", is_root:=true) {
    matched := WindowAtomMatches(rule, proc, cls, title)

    for child in rule.children {
        if !WindowRulePredicate(child, proc, cls, title, false) {
            matched := false
            break
        }
    }

    return (!is_root && rule.invert) ? !matched : matched
}


_WindowRulesAllow(rules, proc, cls:="", title:="") {
    if !rules || !rules.Length {
        return true
    }

    has_positive := false

    for i, rule in rules {
        if !rule.invert {
            has_positive := true
            break
        }
    }

    allowed := !has_positive

    for rule in rules {
        if !WindowRulePredicate(rule, proc, cls, title, true) {
            continue
        }

        allowed := !rule.invert
    }

    return allowed
}


CloneWindowRule(rule) {
    children := []

    for child in rule.children {
        children.Push(CloneWindowRule(child))
    }

    return {
        invert: rule.invert,
        kind: rule.kind,
        val: rule.val,
        children: children
    }
}


ParseWindowRule(s) {
    invert := ParseRuleInvert(&s)
    parts := SplitRuleHeadChildren(s)
    atom := ParseRuleAtom(parts.head)

    rule := {
        invert: invert,
        kind: atom.kind,
        val: atom.val,
        children: []
    }

    if parts.children {
        for child_s in SplitTopLevelComma(parts.children) {
            rule.children.Push(ParseWindowRule(child_s))
        }
    }

    return rule
}


ParseRuleInvert(&s) {
    s := Trim(s)

    if SubStr(s, 1, 1) == '-' {
        s := Trim(SubStr(s, 2))
        return true
    }

    if SubStr(s, 1, 1) == '+' {
        s := Trim(SubStr(s, 2))
    }

    return false
}


ParseRuleAtom(s) {
    s := Trim(s)

    if RegExMatch(s, "i)^(p|proc|process):(.+)$", &m) {
        return {kind: "p", val: NormName(m[2])}
    } else if RegExMatch(s, "i)^(c|class):(.+)$", &m) {
        return {kind: "c", val: Trim(m[2])}
    } else if RegExMatch(s, "i)^(t|title):(.+)$", &m) {
        return {kind: "t", val: Trim(m[2])}
    }

    ; default = process
    return {kind: "p", val: NormName(s)}
}


FindTopBracket(s) {
    in_quote := false
    is_esc := false

    loop Parse s {
        ch := A_LoopField

        if is_esc {
            is_esc := false
        } else if ch == "\" {
            is_esc := true
        } else if ch == '"' {
            in_quote := !in_quote
        } else if !in_quote && ch == "[" {
            return A_Index
        }
    }

    return 0
}


SplitRuleHeadChildren(s) {
    s := Trim(s)
    _pos := FindTopBracket(s)

    if !_pos {
        return {head: s, children: ""}
    }

    head := Trim(SubStr(s, 1, _pos - 1))
    rest := Trim(SubStr(s, _pos))

    if SubStr(rest, 1, 1) != "[" || SubStr(rest, -1) != "]" {
        throw Error("Invalid window rule brackets: " . s)
    }

    return {
        head: head,
        children: SubStr(rest, 2, StrLen(rest) - 2)
    }
}


SplitTopLevelComma(s) {
    res := []
    start := 1
    depth := 0
    in_quote := false
    is_esc := false

    loop Parse s {
        ch := A_LoopField

        if is_esc {
            is_esc := false
        } else if ch == "\" {
            is_esc := true
        } else if ch == '"' {
            in_quote := !in_quote
        } else if in_quote {
            continue
        } else if ch == "[" {
            depth += 1
        } else if ch == "]" {
            depth -= 1
        } else if ch == "," && depth == 0 {
            part := Trim(SubStr(s, start, A_Index - start))
            if part {
                res.Push(part)
            }
            start := A_Index + 1
        }
    }

    part := Trim(SubStr(s, start))
    if part {
        res.Push(part)
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