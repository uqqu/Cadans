GuiWindowCtxChanged(obj, *) {
    global gui_proc_ctx

    gui_proc_ctx := GetGuiWindowCtxByText(obj.Text)
    ChangePath()
}


GetGuiWindowCtxItems() {
    global GUI_CTX_BY_TEXT

    GUI_CTX_BY_TEXT := Map()
    seen := Map()
    items := []

    for ctx_id in WIN_CTX.all_ids {
        txt := GetGuiWindowCtxText(ctx_id)

        if ctx_id != WIN_CTX.other_id && !WindowCtxDiffersFromOther(ctx_id) {
            continue
        }

        if !seen.Has(txt) {
            seen[txt] := true
            GUI_CTX_BY_TEXT[txt] := ctx_id
            items.Push(txt)
        }
    }

    ArraySort(items, (a, b) => StrCompare(a, b))

    return items
}


GetGuiWindowCtxText(ctx_id, with_compress:=true) {
    if !ctx_id || !WIN_CTX.id_to_key.Has(ctx_id) {
        return "*"
    }

    key := WIN_CTX.id_to_key[ctx_id]

    if key == "__other__" {
        return "*"
    }

    proc_items := []
    other_tokens := []

    for token in SplitTopLevelComma(key) {
        token := Trim(token)
        if !token {
            continue
        }

        if IsGuiProcToken(token) {
            proc_items.Push(ParseGuiProcToken(token))
        } else {
            other_tokens.Push(GuiWindowCtxToken(token))
        }
    }

    ArraySort(proc_items, (a, b) => StrCompare(a.txt, b.txt))
    ArraySort(other_tokens, (a, b) => StrCompare(a, b))

    parts := []

    if proc_items.Length {
        if with_compress {
            parts.Push(CompressProcessItemsForGui(proc_items))
        } else {
            for _, item in proc_items {
                parts.Push(item.txt)
            }
        }
    }

    for _, token in other_tokens {
        parts.Push(token)
    }

    return parts.Length ? JoinArr(parts, ", ") : "*"
}


GuiProcBaseName(token) {
    token := GuiWindowCtxToken(token)

    p := InStr(token, "[")
    return p ? SubStr(token, 1, p - 1) : token
}


GetGuiWindowCtxByText(txt) {
    global GUI_CTX_BY_TEXT

    if IsSet(GUI_CTX_BY_TEXT) && GUI_CTX_BY_TEXT.Has(txt) {
        return GUI_CTX_BY_TEXT[txt]
    }

    return WIN_CTX.other_id
}


GuiWindowCtxToken(token) {
    token := Trim(token)

    sign := ""
    if SubStr(token, 1, 1) == "-" {
        sign := "-"
        token := SubStr(token, 2)
    }

    if SubStr(token, 1, 2) == "p:" {
        token := SubStr(token, 3)
    }

    return sign . token
}


IsNodeAllowedForCtx(node, ctx_id) {
    if !node {
        return false
    }

    if !ctx_id {
        ctx_id := gui_proc_ctx
    }

    return AssignmentAllowedInCtx(node.layer_name, node, ctx_id)
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


CompressProcessItemsForGui(proc_items) {
    items_by_base := Map()

    for i, item in proc_items {
        if !items_by_base.Has(item.base_name) {
            items_by_base[item.base_name] := []
        }
        items_by_base[item.base_name].Push(i)
    }

    alias_candidates := []

    for alias, _ in CONF.ProcessGroups {
        members := GetExpandedGroupMembers(alias)
        norm_members := []

        for _, member in members {
            norm_members.Push(GuiProcBaseName(member))
        }

        if norm_members.Length < 2 {
            continue
        }

        b := true
        first_pos := 10**9
        member_indices := []

        for _, member in norm_members {
            if !items_by_base.Has(member) {
                b := false
                break
            }

            indices := items_by_base[member]

            chosen_index := 0
            for _, idx in indices {
                item := proc_items[idx]

                if item.suffix {
                    chosen_index := idx
                    break
                }
            }

            if !chosen_index {
                chosen_index := indices[1]
            }

            member_indices.Push(chosen_index)

            if chosen_index < first_pos {
                first_pos := chosen_index
            }
        }

        if b {
            common_suffix := ""
            common_set := false

            for _, idx in member_indices {
                item := proc_items[idx]

                if !common_set {
                    common_suffix := item.suffix
                    common_set := true
                } else if common_suffix != item.suffix {
                    common_suffix := ""
                    break
                }
            }

            alias_candidates.Push({
                alias: alias,
                alias_txt: alias . common_suffix,
                members: norm_members,
                member_indices: member_indices,
                first_pos: first_pos,
                size: norm_members.Length
            })
        }
    }

    ArraySort(alias_candidates, (a, b) => (
        a.first_pos != b.first_pos
            ? a.first_pos - b.first_pos
            : b.size - a.size
    ))

    used_indices := Map()
    result_items := []

    for _, cand in alias_candidates {
        can_take := true

        for _, idx in cand.member_indices {
            if used_indices.Has(idx) {
                can_take := false
                break
            }
        }

        if can_take {
            result_items.Push({
                p: cand.first_pos,
                txt: cand.alias_txt
            })

            for _, idx in cand.member_indices {
                used_indices[idx] := true
            }
        }
    }

    for i, item in proc_items {
        if !used_indices.Has(i) {
            result_items.Push({
                p: i,
                txt: item.txt
            })
        }
    }

    ArraySort(result_items, (a, b) => a.p - b.p)

    parts := []
    for _, item in result_items {
        parts.Push(item.txt)
    }

    return JoinArr(parts, ", ")
}


GetLayersDifferFromOther(ctx_id:=0) {
    if !ctx_id {
        ctx_id := gui_proc_ctx
    }

    res := []
    for layer in ActiveLayers.order {
        a := LayerAllowedInCtx(layer, ctx_id)
        b := LayerAllowedInCtx(layer, WIN_CTX.other_id)
        if a != b {
            res.Push(layer)
        }
    }
    return res
}


WindowCtxDiffersFromOther(ctx_id) {
    if GetLayersDifferFromOther(ctx_id).Length {
        return true
    }

    for _, rule_set in WIN_CTX.node_rule_sets {
        if NodeRuleSetAllowedInCtx(rule_set, ctx_id)
            != NodeRuleSetAllowedInCtx(rule_set, WIN_CTX.other_id) {
            return true
        }
    }

    return false
}


NodeRuleSetAllowedInCtx(rule_set, ctx_id) {
    sample := WIN_CTX.id_to_samples[ctx_id][1]
    return NodeRuleSetAllows(rule_set, sample.proc, sample.class, sample.title)
}


IsGuiProcToken(token) {
    token := Trim(token)

    if SubStr(token, 1, 1) == "-" {
        token := SubStr(token, 2)
    }

    return SubStr(token, 1, 2) == "p:"
}


ParseGuiProcToken(token) {
    token := Trim(token)

    if SubStr(token, 1, 1) == "-" {
        token := SubStr(token, 2)
    }

    if SubStr(token, 1, 2) == "p:" {
        token := SubStr(token, 3)
    }

    p := InStr(token, "[")
    base_name := p ? SubStr(token, 1, p - 1) : token
    suffix := p ? SubStr(token, p) : ""

    return {
        base_name: base_name,
        suffix: suffix,
        txt: base_name . suffix
    }
}
