class ActiveVariant {
    __New(fin:=false, next_priors:=false) {
        this.fin := fin
        this.next_priors := next_priors || []

        this.scancodes := Map()
        this.chords := Map()
        this.gestures := Map()
    }

    HasAny() {
        return this.fin || this.scancodes.Count || this.chords.Count || this.gestures.Count
    }
}


class CombNode {
    __New() {
        this.global_obj := false
        this.specific_obj := false
    }

    __Item[field] {
        get => (!field ? this.global_obj
            : (field == 1 || this.specific_obj ? this.specific_obj
            : this.global_obj))
    }

    Add(data, is_global:=false) {
        if is_global {
            this.global_obj := data
        } else {
            this.specific_obj := data
        }
    }
}


class UnifiedNode {
    __New() {
        this.layers := OrderedMap()

        this.scancodes := Map()
        this.chords := Map()
        this.gestures := Map()

        this.proc_variants := Map()
        this.proc_ctx_to_variant := Map()
        this._build_stamp := 0
    }

    GetActiveVariant(ctx_id:=0) {
        if !ctx_id {
            ctx_id := current_ctx
        }

        if !this.proc_ctx_to_variant.Has(ctx_id) {
            return ActiveVariant()
        }

        return this.proc_variants[this.proc_ctx_to_variant[ctx_id]]
    }

    GetActiveFin(ctx_id:=0) {
        return this.GetActiveVariant(ctx_id).fin
    }

    GetNode(schex, md:=0, is_chord:=false, is_gesture:=false, is_active:=false, ctx_id:=0) {
        if !is_active {
            mp := is_chord
                ? this.chords
                : is_gesture
                    ? this.gestures
                    : this.scancodes
            return mp.Has(schex) ? mp[schex].Get(md, false) : false
        }

        view := this.GetActiveVariant(ctx_id)
        mp := is_chord
            ? view.chords
            : is_gesture
                ? view.gestures
                : view.scancodes

        return mp.Has(schex) ? mp[schex].Get(md, false) : false
    }

    GetRawFin() {
        if !this.layers.Length {
            return false
        }

        c_node := this.layers.GetAll()[1]
        return c_node[0] || c_node[1]
    }

    GetBaseHoldMod(
        schex, md:=0, is_chord:=false, is_gesture:=false, is_active:=false, is_fin:=true, ctx_id:=0
    ) {
        res := {}

        if !is_chord && !is_gesture && !is_active {
            if !this.scancodes.Has(schex) {
                this.scancodes[schex] := Map()
            }
            if !this.scancodes[schex].Has(md) {
                this.scancodes[schex][md] := UnifiedNode()
            }
        }

        res.ubase := this.GetNode(schex, md, is_chord, is_gesture, is_active, ctx_id)
        res.uhold := this.GetNode(schex, md+1, is_chord, is_gesture, is_active, ctx_id)

        mod_unode := md
            ? this.GetNode(schex, 1, is_chord, is_gesture, is_active, ctx_id)
            : res.uhold

        if is_fin {
            fin := is_active
                ? (mod_unode ? mod_unode.GetActiveFin(ctx_id) : false)
                : (mod_unode ? mod_unode.GetRawFin() : false)

            res.umod := fin && fin.down_type == TYPES.Modifier ? mod_unode : false
        } else {
            res.umod := false
            try res.umod := _GetFirst(mod_unode).down_type == TYPES.Modifier ? mod_unode : false
        }

        return res
    }

    GetModFin(sc, is_active:=false, ctx_id:=0) {
        md_unode := this.GetNode(sc, 1, false, false, is_active, ctx_id)
        if !md_unode {
            return false
        }

        fin := is_active ? md_unode.GetActiveFin(ctx_id) : md_unode.GetRawFin()
        return fin && fin.down_type == TYPES.Modifier ? fin : false
    }

    MergeNodeRecursive(raw_node, sc, md, layer_name, is_g:=false) {
        if !raw_node {
            return
        }

        node_obj := BuildNode(raw_node, sc, md)
        node_obj.layer_name := layer_name

        if this.layers.Has(layer_name) {
            this.layers[layer_name].Add(_RepairValue(node_obj), !is_g)
        } else {
            c_node := CombNode()
            c_node.Add(_RepairValue(node_obj), !is_g)
            this.layers.Add(layer_name, c_node)
        }

        for i, mp in [this.gestures, this.chords, this.scancodes] {
            for c_sc, mods in raw_node[-i] {
                if !mp.Has(c_sc) {
                    mp[c_sc] := Map()
                }
                for c_md, child in mods {
                    if !mp[c_sc].Has(c_md) {
                        mp[c_sc][c_md] := UnifiedNode()
                    }
                    mp[c_sc][c_md].MergeNodeRecursive(child, c_sc, c_md, layer_name, is_g)
                }
            }
        }
    }

    ResolveForCtx(prior_layers, ctx_id) {
        fin := false
        next_priors := []

        for layer in prior_layers {
            if !LayerAllowedInCtx(layer, ctx_id) || !this.layers.Has(layer) {
                continue
            }

            node := this.layers[layer][0] || this.layers[layer][1]
            if !fin {
                fin := node
                next_priors.Push(layer)
                continue
            }

            n_def := (node.down_type == TYPES.Default)
            t_def := (fin.down_type == TYPES.Default)

            if t_def && !n_def {
                fin := node
                next_priors.Push(layer)
            } else if (!t_def && n_def) || EqualNodes(fin, node) {
                next_priors.Push(layer)
            }
        }

        return {fin: fin, next_priors: next_priors}
    }

    BuildVariantChildren(variant, ctx_ids) {
        next_priors := variant.next_priors
        if !next_priors.Length {
            return
        }

        for arr in [
            [this.scancodes, variant.scancodes],
            [this.chords, variant.chords],
            [this.gestures, variant.gestures]
        ] {
            src := arr[1]
            trg := arr[2]

            for schex, mods in src {
                for md, next_unode in mods {
                    has_candidate := false

                    for layer in next_priors {
                        if next_unode.layers.Has(layer) {
                            has_candidate := true
                            break
                        }
                    }

                    if !has_candidate {
                        continue
                    }

                    if next_unode.BuildActives(next_priors, schex, md, ctx_ids) {
                        if !trg.Has(schex) {
                            trg[schex] := Map()
                        }
                        trg[schex][md] := next_unode
                    }
                }
            }
        }
    }

    BuildActives(prior_layers, sc:=0, md:=0, ctx_ids:=0) {
        if !ctx_ids {
            ctx_ids := PROC_CTX.all_ids
        }

        if this._build_stamp !== version {
            this.proc_variants := Map()
            this.proc_ctx_to_variant := Map()
            this._build_stamp := version
        }

        groups := Map()
        order := []

        for ctx_id in ctx_ids {
            res := this.ResolveForCtx(prior_layers, ctx_id)
            sig_key := NodeSig(res.fin) . "||" . JoinArr(res.next_priors, "|")

            if !groups.Has(sig_key) {
                groups[sig_key] := {
                    key: sig_key,
                    ctx_ids: [],
                    fin: res.fin,
                    next_priors: res.next_priors
                }
                order.Push(sig_key)
            }
            groups[sig_key].ctx_ids.Push(ctx_id)
        }

        if !order.Length {
            return false
        }

        default_key := ""
        for key in order {
            if ArrayHasValue(groups[key].ctx_ids, PROC_CTX.other_id) {
                default_key := key
                break
            }
        }

        if !default_key {
            max_len := -1
            for key in order {
                len := groups[key].ctx_ids.Length
                if len > max_len {
                    max_len := len
                    default_key := key
                }
            }
        }

        default_group := groups[default_key]

        if this.proc_variants.Has(default_key) {
            default_variant := this.proc_variants[default_key]
        } else {
            default_variant := ActiveVariant(default_group.fin, default_group.next_priors)
            this.proc_variants[default_key] := default_variant
        }

        this.BuildVariantChildren(default_variant, default_group.ctx_ids)

        for ctx_id in default_group.ctx_ids {
            this.proc_ctx_to_variant[ctx_id] := default_key
        }

        for key in order {
            if key == default_key {
                continue
            }

            grp := groups[key]

            if this.proc_variants.Has(key) {
                variant := this.proc_variants[key]
            } else {
                variant := ActiveVariant(grp.fin, grp.next_priors)
                this.proc_variants[key] := variant
            }

            this.BuildVariantChildren(variant, grp.ctx_ids)

            for ctx_id in grp.ctx_ids {
                this.proc_ctx_to_variant[ctx_id] := key
            }
        }

        for _, variant in this.proc_variants {
            if variant.HasAny() {
                return true
            }
        }

        return false
    }
}


BuildNode(raw_node, sc, md, down_type:=false) {
    static default_opts:={
        pool: 5, rotate: CONF.gest_rotate.v, scaling: CONF.scale_impact.v,
        dirs: 0, closed: 0, len: 1
    }

    is_root := raw_node.Length == 4
    node_obj := {sc: sc, md: md}
    for i, name in [
        "down_type", "down_val", "up_type", "up_val", "is_instant", "is_irrevocable",
        "custom_lp_time", "custom_nk_time", "child_behavior", "gui_shortname", "gesture_opts",
    ] {
        node_obj.%name% := is_root ? 0 : raw_node[i]
    }

    if StrLen(sc) > 256 {  ; gesture ^^'
        node_obj.opts := {}
        vals := StrSplit(node_obj.gesture_opts, ";")
        for i, name in ["pool", "rotate", "scaling", "dirs", "closed", "len"] {
            try {
                node_obj.opts.%name% := name == "scaling" ? Float(vals[i]) : Integer(vals[i])
            } catch {
                node_obj.opts.%name% := default_opts.%name%
            }
        }
        vals := StrSplit(sc, " ")
        node_obj.vec := []
        for v in vals {
            if A_Index == 1 && StrLen(v) == 1 {
                continue
            }
            if v !== "" {
                node_obj.vec.Push(Float(v))
            }
        }
    }

    if down_type {
        node_obj.down_type := down_type
    }
    return _RepairValue(node_obj)
}


GetDefaultNode(sc, md) {
    node_obj := {
        down_type: TYPES.Default,  ; NTT?
        down_val: (sc is Number ? "{Blind}" . SC_STR_BR[sc] : "{Blind}{" . sc . "}"),
        up_type: TYPES.Disabled, up_val: "",
        is_instant: 0, is_irrevocable: 0,
        custom_lp_time: 0, custom_nk_time: 0,
        child_behavior: 4, gui_shortname: "", gesture_opts: "",
        sc: sc, md: md
    }
    return node_obj
}


GetDefaultJsonNode(mod_val:=0, given_type:=false) {
    return [
        (given_type || (mod_val ? TYPES.Disabled : TYPES.Default)),
        "", TYPES.Disabled, "", 0, 0, 0, 0, 4, "", "", Map(), Map(), Map()
    ]
}


_RepairValue(node_obj) {
    for arr in [["down_type", "down_val"], ["up_type", "up_val"]] {
        node_obj.%arr[2]% := node_obj.%arr[1]% == TYPES.Default
            ? (node_obj.sc is Number && node_obj.sc !== 0
                ? "{Blind}" . SC_STR_BR[node_obj.sc]
                : "{Blind}{" . node_obj.sc . "}")
            : StrReplace(StrReplace(node_obj.%arr[2]%, "%md%", node_obj.md), "%sc%", node_obj.sc)
    }
    return node_obj
}


EqualNodes(f_node, s_node) {
    return f_node is Object && s_node is Object && NodeSig(f_node) == NodeSig(s_node)
}


NodeSig(node) {
    if !node {
        return "__false__"
    }

    return (
        node.down_type . "|"
        . node.down_val . "|"
        . node.up_type . "|"
        . node.up_val . "|"
        . node.is_instant . "|"
        . node.is_irrevocable . "|"
        . node.custom_lp_time . "|"
        . node.custom_nk_time . "|"
        . node.child_behavior
    )
}


ReadLayers() {
    global AllLayers, ActiveLayers, LayersMeta, AllTags

    AllLayers := OrderedMap()
    ActiveLayers := OrderedMap()
    LayersMeta := Map()
    AllTags := Map()

    loop Files, "layers\*.json", "R" {
        name := SubStr(A_LoopFilePath, 8, -5)
        AllLayers.Add(name)
        LayersMeta[name] := _GetMetaInfo(FileRead(A_LoopFilePath))
    }
    if !AllLayers.Length {
        AllLayers.Add("default_layer")
        SerializeMap(Map(), "default_layer")
    }

    conf_layers := IniRead("config.ini", "Main", "ActiveLayers")
    str_value := ""
    for layer in StrSplit(conf_layers, ",") {
        layer := Trim(layer)
        if layer && FileExist("layers/" . layer . ".json") {
            ActiveLayers.Add(layer)
            str_value .= layer . ", "
        }
    }

    ; rewrite active layers w/o missing
    str_value := SubStr(str_value, 1, -2)
    if str_value !== conf_layers {
        IniWrite(str_value, "config.ini", "Main", "ActiveLayers")
    }
}


UpdLayers() {
    global curr_unode, version

    ToggleFreeze(1)
    FinalizeProcessRules()
    SetCurrentProcessContext(active_proc)
    version += 1
    for _, root in ROOTS {
        root.BuildActives(ActiveLayers.order)
    }
    curr_unode := ROOTS[gui_lang ?? 0]
    SetSysModHotkeys()
    ToggleFreeze(0)
}


GetLayerList() {
    return ActiveLayers.Length ? ActiveLayers.order : AllLayers.order
}


FillRoots() {
    global ROOTS  ; bloody roots

    ROOTS := Map(0, UnifiedNode())
    for lang in LANGS.map {
        ROOTS[lang] := UnifiedNode()
    }

    for arr in (CONF.ignore_inactive.v
        ? [[ActiveLayers, Map()]] : [[ActiveLayers, Map()], [AllLayers, ActiveLayers]]) {
        for layer in arr[1].map {
            if !arr[2].Has(layer) {
                MergeLayer(layer)
            }
        }
        if selected_layer ?? 0 && !ActiveLayers.Has(selected_layer)
            && AllLayers.map[selected_layer] is Integer {
            MergeLayer(selected_layer)
        }
    }

    if saved_level {
        ROOTS["buffer"] := UnifiedNode()
        ROOTS["buffer"].MergeNodeRecursive(saved_level[2], 0, 0, "buffer")
        ROOTS["buffer_h"] := UnifiedNode()
        if saved_level[1] == 2 {
            ROOTS["buffer_h"].MergeNodeRecursive(saved_level[3], 0, 0, "buffer")
        }
    }
}


MergeLayer(layer) {
    raw_roots := DeserializeMap(layer)
    AllLayers.map[layer] := CountLangMappings(raw_roots)
    for lang, root in raw_roots {
        if !LANGS.Has(lang) {
            if !CONF.unfam_layouts.v {
                continue
            }
            LANGS.Add(lang, GetLayoutLangFromHKL(lang) . " (" . lang . ")")
            ROOTS[lang] := UnifiedNode()
        }
        ROOTS[lang].MergeNodeRecursive(root, 0, 0, layer)
    }
    global_raw_root := raw_roots.Get(0, false)
    for lang in LANGS.map {
        if global_raw_root && lang {
            ROOTS[lang].MergeNodeRecursive(global_raw_root, 0, 0, layer, true)
        }
    }
}


CountLangMappings(raw_roots) {
    res := Map()
    for lang, root in raw_roots {
        stack := [root[-3], root[-2], root[-1]]
        cnt := 0
        while stack.Length {
            mp := stack.Pop()
            for sc, mods in mp {
                for md, node in mods {
                    if node[1] !== TYPES.Chord || node[3] !== TYPES.Disabled {
                        cnt += 1
                    }
                    stack.Push(node[-3], node[-2], node[-1])
                }
            }
        }
        res[lang] := cnt
    }
    return res
}