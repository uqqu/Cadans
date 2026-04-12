GuiProcCtxChanged(_ctrl, *) {
    global gui_proc_ctx

    gui_proc_ctx := GetGuiProcessCtxByText(_ctrl.Text)
    ChangePath()
}


GetGuiProcessItems() {
    items := []
    for ctx_id in PROC_CTX.all_ids {
        names := PROC_CTX.id_to_names[ctx_id]

        if ArrayHasValue(names, "__other__") {
            items.Push("*")
        } else {
            items.Push(CompressProcessNamesForGui(names))
        }
    }
    return items
}


GetGuiProcessTextByCtx(ctx_id) {
    if !ctx_id || !PROC_CTX.id_to_names.Has(ctx_id) {
        return "*"
    }

    names := PROC_CTX.id_to_names[ctx_id]

    if ArrayHasValue(names, "__other__") {
        return "*"
    }

    return CompressProcessNamesForGui(names)
}


GetGuiProcessCtxByText(txt) {
    for ctx_id in PROC_CTX.all_ids {
        if GetGuiProcessTextByCtx(ctx_id) == txt {
            return ctx_id
        }
    }

    return PROC_CTX.other_id
}


IsNodeAllowedForCtx(node, ctx_id) {
    if !node {
        return false
    }

    if !ctx_id {
        ctx_id := gui_proc_ctx
    }

    return LayerAllowedInCtx(node.layer_name, ctx_id)
}


GetExpandedGroupMembers(group_name) {
    members := []
    seen := Map()

    for proc in ExpandProcessToken(group_name) {
        if !seen.Has(proc) {
            seen[proc] := true
            members.Push(proc)
        }
    }

    return members
}


CompressProcessNamesForGui(proc_names) {
    remaining := Map()
    order_map := Map()

    for i, name in proc_names {
        remaining[name] := true
        if !order_map.Has(name) {
            order_map[name] := i
        }
    }

    alias_candidates := []

    for alias, _ in CONF.ProcessGroups {
        members := GetExpandedGroupMembers(alias)
        if members.Length < 2 {
            continue
        }

        b := true
        first_pos := 10**9

        for _, member in members {
            if !remaining.Has(member) {
                b := false
                break
            }
            if order_map.Has(member) && order_map[member] < first_pos {
                first_pos := order_map[member]
            }
        }

        if b {
            alias_candidates.Push({
                alias: alias,
                members: members,
                first_pos: first_pos,
                size: members.Length
            })
        }
    }

    if alias_candidates.Length {
        ArraySort(alias_candidates, (a, b) => (
            a.first_pos != b.first_pos
                ? a.first_pos - b.first_pos
                : b.size - a.size
        ))
    }

    used := Map()
    result_items := []

    for _, cand in alias_candidates {
        can_take := true
        for _, member in cand.members {
            if used.Has(member) {
                can_take := false
                break
            }
        }

        if can_take {
            result_items.Push({
                p: cand.first_pos,
                txt: cand.alias
            })
            for _, member in cand.members {
                used[member] := true
            }
        }
    }

    for i, name in proc_names {
        if !used.Has(name) {
            result_items.Push({
                p: i,
                txt: name
            })
        }
    }

    if result_items.Length {
        ArraySort(result_items, (a, b) => a.p - b.p)
    }

    parts := []
    for _, item in result_items {
        parts.Push(item.txt)
    }

    return JoinArr(parts, ", ")
}


GetLayersDifferFromOther(ctx_id:=0) {
    res := []
    for layer in ActiveLayers.order {
        a := LayerAllowedInCtx(layer, ctx_id)
        b := LayerAllowedInCtx(layer, PROC_CTX.other_id)
        if a != b {
            res.Push(layer)
        }
    }
    return res
}