active_hwnd := DllCall("GetForegroundWindow", "Ptr")
active_proc := ""
active_class := ""
active_title := ""

try active_proc := WinGetProcessName(active_hwnd)
try active_class := WinGetClass(active_hwnd)
try active_title := WinGetTitle(active_hwnd)


ExpandProcessToken(token, seen:=0) {
    token := NormName(token)
    if !token {
        return []
    }

    seen := seen || Map()
    if seen.Has(token) {
        return []
    }
    seen[token] := true

    if CONF.ProcessGroups.Has(token) {
        res := []
        for part in StrSplit(CONF.ProcessGroups[token], ",", " `t`r`n") {
            for expanded in ExpandProcessToken(part, seen) {
                res.Push(expanded)
            }
        }
        return res
    }

    return [token]
}


LayerAllowedInCtx(layer_name, ctx_id) {
    if !LayersMeta.Has(layer_name) {
        return true
    }

    meta := LayersMeta[layer_name]
    return meta.Has("ctx_rule") ? meta["ctx_rule"].Has(ctx_id) : true
}


MakeCtxSample(key, proc:="*", cls:="", title := "") {
    return {
        key: key,
        proc: proc == "*" ? "*" : NormName(proc),
        class: cls,
        title: title
    }
}


_PrepareWindowRulesAndSamples(relevant_layers) {
    raw_samples := Map()
    raw_samples["__other__"] := MakeCtxSample("__other__")

    for layer_name in relevant_layers {
        for _, rule in LayersMeta[layer_name]["processes"] {
            AddSamplesFromRule(rule, raw_samples)
        }
    }

    return raw_samples
}


AddSamplesFromRule(rule, raw_samples, base:=false, parent_rule:=false) {
    current := base ? {
        proc: base.proc,
        class: base.class,
        title: base.title,
        key: base.key
    } : {
        proc: "*",
        class: "",
        title: "",
        key: ""
    }

    switch rule.kind {
        case "p":
            current.proc := rule.val
        case "c":
            current.class := rule.val
        case "t":
            current.title := {
                is_title_sample: true,
                pattern: rule.val
            }
    }

    create_sample := rule.kind !== "*" && RuleShouldCreateSample(parent_rule, rule)

    if create_sample {
        atom_key := RuleAtomKey(rule)
        key := AppendRuleAtomKey(current.key, atom_key)

        current.key := key
        display_key := key . GetDirectInvertedChildrenKey(rule)

        if !raw_samples.Has(display_key) {
            raw_samples[display_key] := MakeCtxSample(
                display_key,
                current.proc,
                current.class,
                current.title
            )
        }
    }

    for child in rule.children {
        AddSamplesFromRule(child, raw_samples, current, rule)
    }
}


AppendRuleAtomKey(parent_key, atom_key) {
    if !parent_key {
        return atom_key
    }

    return parent_key . "[" . atom_key . "]"
}


RuleAtomKey(rule) {
    sign := rule.invert ? "-" : ""

    switch rule.kind {
        case "p":
            return sign . "p:" . rule.val
        case "c":
            return sign . "c:" . rule.val
        case "t":
            return sign . "t:" . rule.val
    }

    return ""
}


_BuildWindowSignatures(relevant_layers, raw_samples) {
    sig_to_samples := Map()
    sample_to_sig := Map()

    for sample_key, sample in raw_samples {
        if sample_key == "__other__" {
            sig := "__other__"
        } else {
            sig := ""

            for _, layer_name in relevant_layers {
                meta := LayersMeta[layer_name]
                allowed := _WindowRulesAllow(
                    meta["processes"],
                    sample.proc,
                    sample.class,
                    sample.title
                )
                sig .= allowed ? "1" : "0"
            }
        }

        sample_to_sig[sample_key] := sig

        if !sig_to_samples.Has(sig) {
            sig_to_samples[sig] := []
        }

        sig_to_samples[sig].Push(sample)
    }

    return {sample_to_sig: sample_to_sig, sig_to_samples: sig_to_samples}
}


_BuildCollapsedWinCtx(sample_to_sig, sig_to_samples) {
    win_ctx := {
        other_key: "__other__",
        other_id: 0,

        key_to_id: Map(),
        id_to_key: Map(),
        id_to_samples: Map(),

        all_ids: [],
        sig_to_id: Map(),
        relevant_layers: []
    }

    next_id := 1
    other_sig := sample_to_sig["__other__"]
    ordered_sigs := []

    if sig_to_samples.Has(other_sig) {
        ordered_sigs.Push(other_sig)
    }

    for sig, _ in sig_to_samples {
        if sig !== other_sig {
            ordered_sigs.Push(sig)
        }
    }

    for _, sig in ordered_sigs {
        samples := sig_to_samples[sig]
        ctx_id := next_id
        next_id += 1

        win_ctx.all_ids.Push(ctx_id)
        win_ctx.sig_to_id[sig] := ctx_id
        win_ctx.id_to_samples[ctx_id] := samples

        display_keys := []

        for _, sample in samples {
            if sample.key !== "__other__" {
                display_keys.Push(sample.key)
            }
        }

        if samples.Length == 1 && samples[1].key == "__other__" {
            win_ctx.id_to_key[ctx_id] := "__other__"
            win_ctx.other_id := ctx_id
        } else {
            has_other := false

            for _, sample in samples {
                if sample.key == "__other__" {
                    has_other := true
                    break
                }
            }

            if has_other {
                win_ctx.other_id := ctx_id
                display := "*"

                if display_keys.Length {
                    display .= ", " . JoinArr(display_keys, ", ")
                }

                win_ctx.id_to_key[ctx_id] := display
            } else {
                win_ctx.id_to_key[ctx_id] := JoinArr(display_keys, ", ")
            }
        }

        for _, sample in samples {
            win_ctx.key_to_id[sample.key] := ctx_id
        }
    }

    return win_ctx
}


_AssignCollapsedContextRules(relevant_layers, win_ctx) {
    for _, layer_name in relevant_layers {
        meta := LayersMeta[layer_name]
        meta["ctx_rule"] := _BuildCollapsedContextRuleFromRules(meta["processes"], win_ctx)
    }

    for layer_name, meta in LayersMeta {
        if !ArrayHasValue(relevant_layers, layer_name) {
            if meta.Has("ctx_rule") {
                meta.Delete("ctx_rule")
            }
        }
    }
}


_BuildCollapsedContextRuleFromRules(window_rules, win_ctx) {
    rule := Map()

    for ctx_id in win_ctx.all_ids {
        samples := win_ctx.id_to_samples[ctx_id]

        fst := ""
        consistent := true

        for _, sample in samples {
            allowed := _WindowRulesAllow(window_rules, sample.proc, sample.class, sample.title)

            if fst == "" {
                fst := allowed
            } else if fst !== allowed {
                consistent := false
                break
            }
        }

        if consistent && fst {
            rule[ctx_id] := true
        }
    }

    return rule
}


FinalizeContextRules() {
    global WIN_CTX

    relevant_layers := ActiveLayers.order.Clone()
    raw_samples := _PrepareWindowRulesAndSamples(relevant_layers)

    sigs := _BuildWindowSignatures(relevant_layers, raw_samples)
    WIN_CTX := _BuildCollapsedWinCtx(sigs.sample_to_sig, sigs.sig_to_samples)

    WIN_CTX.relevant_layers := relevant_layers
    WIN_CTX.has_rules := false
    WIN_CTX.uses_title := false

    for _, layer_name in relevant_layers {
        if !LayerHasWindowRules(layer_name) {
            continue
        }

        WIN_CTX.has_rules := true

        if WindowRulesUseTitle(LayersMeta[layer_name]["processes"]) {
            WIN_CTX.uses_title := true
        }
    }

    _AssignCollapsedContextRules(relevant_layers, WIN_CTX)
    UpdateWindowContextHooks()
}


GetWindowContextId(proc, cls:="", title:="") {
    if !WIN_CTX.has_rules {
        return WIN_CTX.other_id
    }

    proc := NormName(proc)
    sig := ""

    for _, layer_name in WIN_CTX.relevant_layers {
        allowed := _WindowRulesAllow(LayersMeta[layer_name]["processes"], proc, cls, title)
        sig .= allowed ? "1" : "0"
    }

    return WIN_CTX.sig_to_id.Get(sig, WIN_CTX.other_id)
}


SetCurrentWindowContext(proc, cls:="", title:="") {
    global current_ctx

    current_ctx := GetWindowContextId(NormProc(proc), NormClass(cls), NormTitle(title))
}


WindowAtomMatches(rule, proc, cls:="", title:="") {
    switch rule.kind {
        case "*":
            return true
        case "p":
            return NormProc(proc) == rule.val
        case "c":
            return NormClass(cls) == rule.val
        case "t":
            if IsObject(title) {
                try {
                    return title.pattern == rule.val
                } catch {
                    return false
                }
            }

            try {
                return RegExMatch(title, rule.val)
            } catch {
                return false
            }
    }

    return false
}


GetDirectInvertedChildrenKey(rule) {
    parts := []

    for child in rule.children {
        if !child.invert
            || rule.kind == "p" && child.kind == "p"
            || rule.kind == "c" && child.kind == "c" {
            continue
        }

        parts.Push("[" . RuleAtomKey(child) . "]")
    }

    return JoinArr(parts, "")
}


WindowRuleUsesTitle(rule) {
    if rule.kind == "t" {
        return true
    }

    for child in rule.children {
        if WindowRuleUsesTitle(child) {
            return true
        }
    }

    return false
}


WindowRulesUseTitle(rules) {
    for _, rule in rules {
        if WindowRuleUsesTitle(rule) {
            return true
        }
    }

    return false
}


LayerHasWindowRules(layer_name) {
    return LayersMeta.Has(layer_name)
        && LayersMeta[layer_name].Has("processes")
        && LayersMeta[layer_name]["processes"].Length
}


RuleShouldCreateSample(parent_rule, rule) {
    if !parent_rule {
        return true
    }

    if parent_rule.kind == "p" && rule.kind == "p"
        || parent_rule.kind == "c" && rule.kind == "c" {
        return false
    }

    return true
}


UpdateWindowContextHooks() {
    static hook_foreground := 0, hook_title := 0, hook_shell := 0,
        cb_foreground := 0, cb_title := 0, cb_shell := 0

    need_base := WIN_CTX.has_rules
    need_title := WIN_CTX.has_rules && WIN_CTX.uses_title

    if need_base && !hook_foreground && !hook_shell {
        cb_foreground := CallbackCreate(OnForegroundChanged)
        hook_foreground := DllCall("SetWinEventHook", "UInt", 0x0003, "UInt", 0x0003
            , "Ptr", 0, "Ptr", cb_foreground, "UInt", 0, "UInt", 0, "UInt", 0, "Ptr")

        cb_shell := CallbackCreate(OnHideChanged)
        hook_shell := DllCall("SetWinEventHook", "UInt", 0x8003, "UInt", 0x8018
            , "Ptr", 0, "Ptr", cb_shell, "UInt", 0, "UInt", 0, "UInt", 0, "Ptr")
    } else if !need_base && hook_foreground && hook_shell {
        DllCall("UnhookWinEvent", "Ptr", hook_foreground)
        CallbackFree(cb_foreground)
        hook_foreground := 0
        cb_foreground := 0

        DllCall("UnhookWinEvent", "Ptr", hook_shell)
        CallbackFree(cb_shell)
        hook_shell := 0
        cb_shell := 0
    }

    if need_title && !hook_title {
        cb_title := CallbackCreate(OnTitleChanged)
        hook_title := DllCall("SetWinEventHook", "UInt", 0x800C, "UInt", 0x800C
            , "Ptr", 0, "Ptr", cb_title, "UInt", 0, "UInt", 0, "UInt", 0, "Ptr")
    } else if !need_title && hook_title {
        DllCall("UnhookWinEvent", "Ptr", hook_title)
        CallbackFree(cb_title)
        hook_title := 0
        cb_title := 0
    }
}


OnForegroundChanged(hWinEventHook, event, hwnd, *) {
    global active_hwnd, active_proc, active_class, active_title, pending_event

    if is_updating {
        pending_event := true
        return
    }

    if !hwnd || hwnd == active_hwnd || !WinExist(hwnd) {
        return
    }

    active_hwnd := hwnd
    active_proc := WinGetProcessName(hwnd)
    active_class := WinGetClass(hwnd)
    active_title := WinGetTitle(hwnd)
    if active_title == "Task Switching" {
        ApplyForegroundWindow(true)
    } else {
        SetCurrentWindowContext(active_proc, active_class, active_title)
        CheckLayout()
        ToRoot()
    }
}


OnTitleChanged(hWinEventHook, event, hwnd, *) {
    global active_hwnd, active_proc, active_class, active_title, pending_event

    if is_updating {
        pending_event := true
        return
    }

    if !hwnd || hwnd !== active_hwnd || !WinExist(hwnd) {
        return
    }

    try {
        proc := WinGetProcessName(hwnd)
        cls := WinGetClass(hwnd)
        title := WinGetTitle(hwnd)
    } catch {
        return
    }
    if hwnd == active_hwnd && title == active_title && cls == active_class && proc == active_proc {
        return
    }

    active_hwnd := hwnd
    active_proc := proc
    active_class := cls
    active_title := title

    if active_title == "Task Switching" {
        ApplyForegroundWindow(false)
    } else {
        SetCurrentWindowContext(active_proc, active_class, active_title)
    }
}


OnHideChanged(hWinEventHook, event, hwnd, *) {
    if active_proc == "explorer.exe" {
        ApplyForegroundWindow(true)
    }
}


ApplyForegroundWindow(with_reset:=false) {
    global active_hwnd, active_proc, active_class, active_title

    hwnd := DllCall("GetForegroundWindow", "Ptr")

    if !hwnd || !WinExist(hwnd) {
        return
    }

    active_hwnd := hwnd
    active_class := WinGetClass(hwnd)
    active_proc := WinGetProcessName(hwnd)
    active_title := WinGetTitle(hwnd)

    SetCurrentWindowContext(active_proc, active_class, active_title)

    if with_reset {
        CheckLayout()
        ToRoot()
    }
}