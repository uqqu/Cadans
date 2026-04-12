class OrderedMap {
    __New() {
        this.map := Map()
        this.order := []
        this.Length := 0
    }

    __Item[name] {
        get => this.map.Get(name, false)
    }

    Add(name, data?, pos_?) {
        if !this.map.Has(name) {
            this.Length += 1
            this.map[name] := data ?? this.Length
            IsSet(pos_) ? this.order.InsertAt(pos_, name) : this.order.Push(name)
        }
    }

    Set(name, data) {
        if this.map.Has(name) {
            this.map[name] := data
        } else {
            this.Add(name, data)
        }
    }

    GetAll() {
        result := []
        for name in this.order {
            result.Push(this.map[name])
        }
        return result
    }

    Has(name) {
        return this.map.Has(name)
    }

    Remove(name) {
        if this.map.Has(name) {
            this.Length -= 1
            this.map.Delete(name)
            for i, existing in this.order {
                if existing == name {
                    this.order.RemoveAt(i)
                    break
                }
            }
        }
    }

    Any() {
        for _, v in this.map {
            if v {
                return true
            }
        }
        return false
    }

    All() {
        for _, v in this.map {
            if !v {
                return false
            }
        }
        return true
    }
}


class DefaultKeyMap extends Map {
    __Item[key] {
        get => this.Get(key, key)
        set => super[key] := value
    }
}


ArraySort(arr, cmp) {
    n := arr.Length
    if n < 2 {
        return arr
    }

    loop n - 1 {
        i := A_Index
        loop n - i {
            j := A_Index
            if cmp(arr[j], arr[j+1]) > 0 {
                tmp := arr[j]
                arr[j] := arr[j+1]
                arr[j+1] := tmp
            }
        }
    }
    return arr
}


JoinArr(arr, sep:=",") {
    res := ""
    for v in arr {
        res .= (res == "" ? "" : sep) . v
    }
    return res
}


ArrayHasValue(arr, value) {
    for v in arr {
        if v == value {
            return true
        }
    }
    return false
}


ClearEquals(mp) {
    ; delete pairs from map where key==value
    to_del := []
    for k in mp {
        if k == mp[k] {
            to_del.Push(k)
        }
    }
    for k in to_del {
        mp.Delete(k)
    }
}


DeepClone(val) {
    if val is Map {
        m := Map()
        for k, v in val {
            m[k] := DeepClone(v)
        }
        return m
    } else if val is Array {
        a := []
        for v in val {
            a.Push(DeepClone(v))
        }
        return a
    } else {
        return val
    }
}


MapUnion(a, b) {
    res := Map()

    for k, v in a {
        res[k] := v
    }
    for k, v in b {
        res[k] := v
    }

    return res
}


NormName(name) {
    return Trim(StrLower(name))
}


GetCurrentLayout() {
    return Integer(DllCall("GetKeyboardLayout", "UInt",
        DllCall("GetWindowThreadProcessId", "Ptr", active_hwnd, "Ptr", 0), "UPtr"))
}


GetLayoutLangFromHKL(hkl) {
    if static_lang_names.Has(hkl) {
        return static_lang_names[hkl]
    }

    buf := Buffer(9)
    DllCall("GetLocaleInfoW", "UInt", hkl & 0xFFFF, "UInt", 0x59, "Ptr", buf, "Int", 9)
    return StrGet(buf)
}


GetLayoutNameFromHKL(hkl) {
    if static_lang_names.Has(hkl) {
        return static_lang_names[hkl]
    }

    klid := GetKLIDFromHKL(hkl)
    if !klid {
        return ""
    }

    name := GetLayoutDisplayNameFromKLID(klid)
    return name || klid
}


GetKLIDFromHKL(hkl) {
    cur := DllCall("GetKeyboardLayout", "uint", 0, "ptr")
    DllCall("ActivateKeyboardLayout", "ptr", hkl, "uint", 0)
    buf := Buffer(9 * 2, 0)
    res := DllCall("GetKeyboardLayoutNameW", "ptr", buf, "int")
    DllCall("ActivateKeyboardLayout", "ptr", cur, "uint", 0)
    if !res {
        return ""
    }

    return StrGet(buf, "UTF-16")
}


GetLayoutDisplayNameFromKLID(klid) {
    base := "HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\" . klid

    disp := ""
    try disp := RegRead(base, "Layout Display Name")

    if disp {
        resolved := ResolveIndirectString(disp)
        if resolved {
            return resolved
        }
    }

    txt := ""
    try txt := RegRead(base, "Layout Text")

    return txt
}


ResolveIndirectString(s) {
    buf := Buffer(2048 * 2, 0)
    hr := DllCall(
        "shlwapi\SHLoadIndirectString", "wstr", s, "ptr", buf, "uint", 2048, "ptr", 0, "int"
    )
    return !hr ? StrGet(buf, "UTF-16") : ""
}