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


ExpandProcessMap(proc_map) {
    res := Map()

    if proc_map.Has("*") {
        res["*"] := proc_map["*"]
    }

    for token, val in proc_map {
        if token == "*" {
            continue
        }

        for exe_name in ExpandProcessToken(token) {
            res[exe_name] := val
        }
    }

    return res
}


LayerAllowedInCtx(layer_name, ctx_id) {
    if !LayersMeta.Has(layer_name) {
        return true
    }

    meta := LayersMeta[layer_name]
    return meta.Has("proc_rule") ? meta["proc_rule"].Has(ctx_id) : true
}


_GetRelevantLayersForContexts() {
    layers := []

    for layer in ActiveLayers.order {
        if LayersMeta.Has(layer) {
            layers.Push(layer)
        }
    }

    return layers
}


_PrepareExpandedProcesses(relevant_layers) {
    raw_names := Map()
    raw_names["__other__"] := true

    for _, layer_name in relevant_layers {
        meta := LayersMeta[layer_name]

        if !meta.Has("processes") {
            meta["processes"] := Map("*", true)
        }

        meta["expanded_processes"] := ExpandProcessMap(meta["processes"])

        for exe_name, _ in meta["expanded_processes"] {
            if exe_name !== "*" {
                exe_name := NormName(exe_name)
                if exe_name {
                    raw_names[exe_name] := true
                }
            }
        }
    }

    return raw_names
}


_BuildProcessSignatures(relevant_layers, raw_names) {
    sig_to_names := Map()
    proc_to_sig := Map()

    for proc_name, _ in raw_names {
        sig := ""

        for _, layer_name in relevant_layers {
            meta := LayersMeta[layer_name]
            proc_map := meta["expanded_processes"]
            allowed := _ProcMapAllows(proc_map, proc_name)
            sig .= allowed ? "1" : "0"
        }

        proc_to_sig[proc_name] := sig

        if !sig_to_names.Has(sig) {
            sig_to_names[sig] := []
        }
        sig_to_names[sig].Push(proc_name)
    }

    return {proc_to_sig: proc_to_sig, sig_to_names: sig_to_names}
}


_BuildCollapsedProcCtx(proc_to_sig, sig_to_names) {
    proc_ctx := {
        other_name: "__other__",
        other_id: 0,
        name_to_id: Map(),
        id_to_name: Map(),
        id_to_names: Map(),
        all_ids: []
    }

    next_id := 1
    other_sig := proc_to_sig["__other__"]
    ordered_sigs := []

    if sig_to_names.Has(other_sig) {
        ordered_sigs.Push(other_sig)
    }
    for sig, _ in sig_to_names {
        if sig !== other_sig {
            ordered_sigs.Push(sig)
        }
    }

    for _, sig in ordered_sigs {
        names := sig_to_names[sig]
        ctx_id := next_id
        next_id += 1

        proc_ctx.all_ids.Push(ctx_id)
        proc_ctx.id_to_names[ctx_id] := names

        display_names := []
        for _, name in names {
            if name !== "__other__" {
                display_names.Push(name)
            }
        }

        if names.Length == 1 && names[1] == "__other__" {
            proc_ctx.id_to_name[ctx_id] := "__other__"
            proc_ctx.other_id := ctx_id
        } else {
            if ArrayHasValue(names, "__other__") {
                proc_ctx.other_id := ctx_id
                display := "*"
                if display_names.Length {
                    display .= ", " . JoinArr(display_names, ", ")
                }
                proc_ctx.id_to_name[ctx_id] := display
            } else {
                proc_ctx.id_to_name[ctx_id] := JoinArr(display_names, ", ")
            }
        }

        for _, name in names {
            proc_ctx.name_to_id[name] := ctx_id
        }
    }

    return proc_ctx
}


_AssignCollapsedProcRules(relevant_layers, proc_ctx) {
    for _, layer_name in relevant_layers {
        meta := LayersMeta[layer_name]
        proc_map := meta["expanded_processes"]
        meta["proc_rule"] := _BuildCollapsedProcessRuleFromMap(proc_map, proc_ctx)
    }

    for layer_name, meta in LayersMeta {
        if !ArrayHasValue(relevant_layers, layer_name) {
            if meta.Has("proc_rule") {
                meta.Delete("proc_rule")
            }
        }
    }
}


_BuildCollapsedProcessRuleFromMap(proc_map, proc_ctx) {
    rule := Map()

    for ctx_id in proc_ctx.all_ids {
        names := proc_ctx.id_to_names[ctx_id]

        fst := ""
        consistent := true

        for _, proc_name in names {
            allowed := _ProcMapAllows(proc_map, proc_name)

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


FinalizeProcessRules() {
    global PROC_CTX

    relevant_layers := _GetRelevantLayersForContexts()
    raw_names := _PrepareExpandedProcesses(relevant_layers)

    sigs := _BuildProcessSignatures(relevant_layers, raw_names)
    PROC_CTX := _BuildCollapsedProcCtx(sigs.proc_to_sig, sigs.sig_to_names)

    _AssignCollapsedProcRules(relevant_layers, PROC_CTX)
}


_ProcMapAllows(proc_map, proc_name) {
    if !proc_map {
        return true
    } else if proc_name !== "__other__" && proc_map.Has(proc_name) {
        return proc_map[proc_name]
    } else if proc_map.Has("*") {
        return proc_map["*"]
    }

    return true
}


GetProcessContextId(exe_name) {
    return PROC_CTX.name_to_id.Get(NormName(exe_name), PROC_CTX.other_id)
}


SetCurrentProcessContext(exe_name) {
    global current_ctx
    current_ctx := GetProcessContextId(exe_name)
}