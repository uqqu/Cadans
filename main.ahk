#Requires AutoHotkey v2.0
#SingleInstance Force
OnError((*) => Suspend(true))
TraySetIcon("ico\icon.ico")

await_hold := false
await_nest := false
await_gest := false
await_mod := false
await_chord_part := false
await_chord_full := false

prev_unode := false
child_behavior := false
catched_entries := false
catched_gui_func := false
is_key_processing := false
current_ctx := 1
current_mod := 0

current_presses := Map()
chord_presses := OrderedMap()
up_actions := Map()
stack := []  ; queue of overlapping presses

;#Include "core\logger.ahk"
#Include "core\_utils.ahk"
#Include "core\serializing.ahk"
#Include "core\structs.ahk"
#Include "core\processes.ahk"
#Include "core\config.ahk"
#Include "core\gesture_processing.ahk"
#Include "core\gestures.ahk"
#Include "core\user_functions.ahk"
#Include "gui\gui.ahk"
#Include "core\keys.ahk"

SetSysModHotkeys()

;Logger.Start()
;Logger.level := 3


PreCheck(sc, *) {
    global catched_entries

    if current_presses.Has(sc) || current_mod || is_key_processing
        || await_hold || await_nest || await_gest || chord_presses.Length
        || is_drawing || GuiCheck(sc) {
        return true
    }

    CheckLayout()

    catched_entries := GetEntries(sc)
    if !catched_entries && curr_unode !== ROOTS[CONF.LayoutAliases[current_layout]] {
        ToRoot()
        catched_entries := GetEntries(sc)
    }
    return catched_entries
}


CheckLayout() {
    global current_layout

    layout := CONF.LayoutAliases[GetCurrentLayout()]
    if layout == current_layout || !ROOTS.Has(layout) && !current_layout {
        return
    }

    current_layout := ROOTS.Has(layout) ? layout : 0
    ToRoot()
}


GetEntries(sc) {
    static cache:=Map(), mem_version:=0

    if version !== mem_version {
        cache := Map()
        mem_version := version
    }

    t := ObjPtr(curr_unode) . "|" . sc . "|" . current_mod . "|" . current_ctx
    try {
        entries := cache[t]
    } catch {
        cache[t] := curr_unode.GetBaseHoldMod(sc, current_mod, false, false, true)
        entries := cache[t]
    }

    if !entries.ubase && !entries.uhold && !entries.umod {
        return false
    } else if entries.umod || entries.uhold || entries.ubase && (
        (fin := _GetFin(entries.ubase)) && (
            fin.down_type != TYPES.Default
            || fin.up_type != TYPES.Disabled
            || _GetScancodes(entries.ubase).Count
            || _GetChords(entries.ubase).Count
        )
    ) {
        return entries
    } else {
        gests := _GetGestures(entries.ubase)
        CollectPool(gests)
        if pool_gestures.Length {
            return entries
        }
        return false
    }
}


TimerSendCurrent() {
    SetTimer(TimerSendCurrent, 0)

    if await_nest {
        fin := _GetFin(await_nest[1])
        t := fin && fin.is_irrevocable
        SendAwaiting("n")
        if !t {
            ToRoot()
        }
    }
}


SendAwaiting(order, sc:=0) {
    global await_hold, await_nest, await_gest, await_mod, await_chord_part

    b := false

    for symb in StrSplit(order) {
        if symb == "h" && await_hold {
            fin := _GetFin(await_hold[1])
            t := await_hold
            if !sc || t[2] == sc {
                await_hold := false
                if !b {
                    TransitionProcessing(t[1], t[2])
                    b := true
                }
            }
        }
        if symb == "p" && await_hold {
            fin := _GetFin(await_hold[3])
            t := await_hold
            if !sc || t[2] == sc {
                await_hold := false
                if !b {
                    TransitionProcessing(t[3], t[2])
                    b := true
                }
            }
        }
        if symb == "n" && await_nest {
            fin := _GetFin(await_nest[1])
            t := [await_nest[1], await_nest[2]]
            await_nest := false
            if !b {
                if t[2] !== -1 && fin {
                    SendKbd(fin.down_type, fin.down_val)
                    if up_actions.Has(t[2]) {
                        SendKbd(up_actions[t[2]].up_type, up_actions[t[2]].up_val)
                        up_actions.Delete(t[2])
                    }
                }
            }
        }
        if symb == "g" && await_gest {
            fin := _GetFin(await_gest[1])
            t := await_gest
            if !sc || t[2] == sc {
                await_gest := false
                if !b {
                    res := EndDraw()
                    if res !== -1 {
                        if res == false || res[1] < CONF.min_cos_similarity.v || res[2] == "" {
                            if !chord_presses.Has(t[2]) && (!current_mod || sc == t[2]) {
                                TransitionProcessing(t*)
                            }
                        } else {
                            TimerResetChord(t[2])
                            TransitionProcessing(res[2])
                        }
                    }
                    DestroyGestOverlay()
                    b := true
                }
            }
        }
        if symb == "m" && await_mod {
            fin := _GetFin(await_mod[1])
            t := await_mod
            await_mod := false
            if !b && t[2] == sc {
                TransitionProcessing(t*)
                b := true
            }
        }
    }
}


ToRoot(extra_mod:=0) {
    global curr_unode, prev_unode

    curr_unode := ROOTS[current_layout]
    prev_unode := false
    TransferModifiers(extra_mod)
}


StepBack(extra_mod:=0) {
    global curr_unode, prev_unode

    if prev_unode {
        curr_unode := prev_unode
        prev_unode := false
        TransferModifiers(extra_mod)
    } else {
        ToRoot(extra_mod)
    }
}


TreatMod(entries, sc) {
    global current_mod, child_behavior, await_mod, await_gest

    if !entries.umod {
        return false
    }

    fin := _GetFin(entries.umod)
    if !fin {
        return false
    }

    val := fin.down_val
    child_behavior := fin.child_behavior

    await_mod := entries.ubase ? [entries.ubase, sc] : GetDefaultSim(sc, true)
    current_mod |= 1 << val

    mfin := _GetFin(await_mod[1])
    SetTimer(TimerResetMod, -((mfin && mfin.custom_lp_time) || CONF.MS_LP.v))
    return true
}


TimerResetMod() {
    global prev_unode, await_mod

    try up_actions.Delete(await_mod[2])
    await_mod := false
    prev_unode := false
}


TimerResetChord(sc) {
    global prev_node, await_chord_part

    if chord_presses.Has(sc) {
        try up_actions.Delete(sc)
        chord_presses.Set(sc, false)
    }
    prev_unode := false  ;?
}


TransitionProcessing(checked_unode, sc:=0) {
    global curr_unode, prev_unode, current_presses, up_actions, await_nest, await_gest

    if is_drawing {
        return
    }

    fin := _GetFin(checked_unode)
    if !checked_unode || !fin {
        return
    }

    scs := _GetScancodes(checked_unode)
    chs := _GetChords(checked_unode)

    TreatUpAction(checked_unode, sc)

    if !scs.Count && !chs.Count {
        SendKbd(fin.down_type, fin.down_val)
        if !fin.is_irrevocable && curr_unode !== ROOTS[current_layout] && !chord_presses.Length {
            ToRoot()
        } else if sc && !chord_presses.Has(sc) {
            try current_presses.Delete(sc)
        }
        return
    }

    if fin.is_instant {
        SendKbd(fin.down_type, fin.down_val)
        await_nest := [checked_unode, -1]
    } else {
        await_nest := [checked_unode, sc]
    }

    if !fin.is_irrevocable {
        SetTimer(TimerSendCurrent, -((fin.custom_nk_time) || CONF.MS_NK.v))
    }
    if curr_unode !== checked_unode {
        prev_unode := curr_unode
        curr_unode := checked_unode
    }

    TransferModifiers()
}


TransferModifiers(extra_mod:=0) {
    global current_mod

    if !current_mod {
        current_mod := extra_mod
        return
    }

    current_mod := extra_mod
    for sc in current_presses {
        res_md := curr_unode.GetModFin(sc, true)
        if res_md {
            current_mod |= 1 << res_md.down_val
        }
    }
}


TreatGest(entries, sc) {
    global await_gest

    gests := _GetGestures(entries.ubase)
    if entries.ubase && gests.Count {
        CollectPool(gests)
        if pool_gestures.Length {
            await_gest := [entries.ubase, sc]
            StartDraw()
        }
    }
}


TreatChord(entries, sc) {
    global await_chord_full, await_chord_part, chord_presses

    SetTimer(SendChord, 0)
    if !chord_presses.Has(sc) {
        chord_presses.Set(sc, true)
    }

    res := curr_unode.GetNode(ChordToStr(chord_presses.map), current_mod, true, false, true)
    if res {
        fin := _GetFin(res)
        if fin && fin.custom_lp_time {
            await_chord_full := res
            SetTimer(SendChord, -fin.custom_lp_time)
        } else {
            await_chord_full := false
            for ch_sc in chord_presses.map {
                TimerResetChord(ch_sc)
            }
            TransitionProcessing(res)
        }
        return true
    }
    return false
}


TreatTapHold(entries, sc) {
    global await_hold

    await_hold := [(entries.ubase ? entries.ubase : GetDefaultSim(sc)[1]), sc, entries.uhold]

    fin := _GetFin(await_hold[1])
    is_hold := KeyWait(
        SC_STR[sc],
        ((fin && fin.custom_lp_time) ? ("T" . fin.custom_lp_time / 1000) : CONF.T)
    )

    if is_hold && await_hold {
        SendAwaiting("h", sc)
    } else if !is_hold && await_hold {
        TreatUpAction(catched_entries.uhold, sc)
        if is_drawing {
            await_gest := [catched_entries.uhold, sc]
        } else {
            TransitionProcessing(catched_entries.uhold)
        }
    }
    await_hold := false
}


TreatUpAction(unode, sc) {
    try up_actions[sc].Delete(sc)
    fin := _GetFin(unode)
    if fin && fin.up_type != TYPES.Disabled {
        up_actions[sc] := fin
    }
}


OnKeyDown(sc, extra_mod:=0, rec:=false, forced:=false) {
    global catched_entries, catched_gui_func, is_key_processing, current_mod, await_nest

    if init_drawing && sc == "RButton" {
        StartDraw()
        return
    } else if is_drag_mode && active_hwnd == UI.Hwnd && (sc == "LButton" || sc == "RButton") {
        return
    }

    wh := !(sc is Number) && SubStr(sc, 1, 5) == "Wheel"
    if is_key_processing {
        if !current_presses.Has(sc) {
            if !wh {
                current_presses[sc] := true
            }
            stack.Push([sc, extra_mod])
            if await_hold && CONF.interruption_behavior.v > 1 {
                SendAwaiting(CONF.interruption_behavior.v == 3 ? "gp" : "gh")
                OnKeyDownRec()
            }
        }
        return
    }

    if !rec && current_presses.Has(sc) {
        return
    }

    is_key_processing := true

    if catched_gui_func {
        if !wh {
            current_presses[sc] := true
        }
        catched_gui_func := false
        HandleKeyPress(sc)
        OnKeyDownRec()
        return
    }

    current_mod |= extra_mod
    if !catched_entries {
        CheckLayout()
        SendAwaiting("g")
        catched_entries := GetEntries(sc)
    }

    if !catched_entries {
        cfin := _GetFin(curr_unode)
        ch_bh := child_behavior || (cfin ? cfin.child_behavior : 0)

        if curr_unode !== ROOTS[current_layout] {
            if ch_bh == 5 {
                OnKeyDownRec()
                return
            } else if ch_bh == 2 || ch_bh == 4 {
                SendAwaiting("n")
            }
            if ch_bh < 3 && prev_unode {
                StepBack(extra_mod)
            } else {
                ToRoot(extra_mod)
            }
            catched_entries := GetEntries(sc)
        }
    }

    SetTimer(TimerResetMod, 0)
    TimerResetMod()
    if await_nest && up_actions.Has(await_nest[2]) {
        up_actions.Delete(await_nest[2])
    }
    await_nest := false

    if forced {
        if catched_entries && catched_entries.ubase {
            TransitionProcessing(catched_entries.ubase, sc)
        } else {
            TransitionProcessing(GetDefaultSim(sc, true)[1], sc)
        }
        OnKeyDownRec()
        return
    }

    if !catched_entries {
        if current_mod && ch_bh == 5 {
            OnKeyDownRec()
            return
        }
        if chord_presses.Length {
            is_key_processing := false
            catched_entries := false
            InterruptChord(extra_mod)
        }
        sim := GetDefaultNode(sc, current_mod)
        if !rec {
            stack.Push([sc, extra_mod])
        } else {
            SendKbd(sim.down_type, sim.down_val)
        }
        OnKeyDownRec()
        return
    }

    if !wh {
        current_presses[sc] := true
    }

    uhold_fin := _GetFin(catched_entries.uhold)
    uhold_scs := _GetScancodes(catched_entries.uhold)
    uhold_chs := _GetChords(catched_entries.uhold)

    if catched_entries.uhold && uhold_fin && uhold_fin.down_type == TYPES.Chord {
        TreatChord(catched_entries, sc)
        TreatGest(catched_entries, sc)
    } else if chord_presses.Length && chord_presses.Any() {
        is_key_processing := false
        catched_entries := false
        InterruptChord(extra_mod)
        stack.Push([sc, extra_mod])
    } else {
        TreatGest(catched_entries, sc)
        if catched_entries.umod {
            TreatMod(catched_entries, sc)
        } else if !catched_entries.uhold || (
            uhold_fin
            && uhold_fin.down_type == TYPES.Disabled
            && uhold_fin.up_type == TYPES.Disabled
            && !uhold_scs.Count
            && !uhold_chs.Count
        ) {
            TransitionProcessing(catched_entries.ubase, sc)
        } else {
            TreatTapHold(catched_entries, sc)
        }
    }
    OnKeyDownRec()
}


OnKeyDownRec() {
    global is_key_processing, catched_entries

    catched_entries := false
    is_key_processing := false
    if stack.Length {
        t := stack.RemoveAt(1)
        OnKeyDown(t[1], t[2], true)
    }
}


InterruptChord(extra_mod, up_sc:=0) {
    global await_chord_full, chord_presses

    b := false
    for sc in chord_presses.order {
        if chord_presses[sc] {
            b := true
            OnKeyDown(sc, extra_mod, true, true)
            chord_presses.Set(sc, false)
            if sc == up_sc && up_actions.Has(sc) {
                SendKbd(up_actions[sc].up_type, up_actions[sc].up_val)
                up_actions.Delete(sc)
            }
        }
    }
    if b {
        SetTimer(SendChord, 0)
        await_chord_full := false
    }
}


SendChord() {
    global await_chord_full, chord_presses

    if !await_chord_full {
        return
    }
    res := curr_unode.GetNode(ChordToStr(chord_presses.map), current_mod, true, false, true)
    if res == await_chord_full {
        for sc in chord_presses.map {
            TimerResetChord(sc)
        }
        ;chord_presses := OrderedMap()
        TransitionProcessing(res)
    }
    await_chord_full := false
}


GetDefaultSim(sc, extended:=false) {
    view := {
        fin: GetDefaultNode(sc, current_mod),
        scancodes: Map(),
        chords: Map(),
        gestures: Map()
    }

    return [
        {
            GetActiveVariant: ((this, ctx_id:=0) => view),
            GetActiveFin: ((this, ctx_id:=0) => view.fin)
        },
        extended ? sc : false
    ]
}


OnKeyUp(sc, extra_mod:=0) {
    global current_mod, child_behavior

    if extra_mod {  ; separately count modifiers from hotkeys with system keys
        current_mod &= ~extra_mod
    }

    if chord_presses.Length && chord_presses.Any() {
        SendAwaiting("g", sc)
        InterruptChord(extra_mod, sc)
    } else {
        SendAwaiting("gmh", sc)
    }

    if up_actions.Has(sc) && !await_nest {
        SendKbd(up_actions[sc].up_type, up_actions[sc].up_val)
        up_actions.Delete(sc)
    }

    try current_presses.Delete(sc)

    b := !await_nest && chord_presses.Length == 1 && chord_presses.Has(sc) && !current_mod
    chord_presses.Remove(sc)
    md := curr_unode.GetModFin(sc, true)
    if md {  ; release mod
        current_mod &= ~(1 << md.down_val)
        child_behavior := false
        if !await_nest && !current_mod && curr_unode !== ROOTS[current_layout]
            && !md.is_irrevocable {
            b := true
        }
    }
    if b {
        ToRoot()
    }
}


SendKbd(action_type, action_val) {
    switch action_type {
        case TYPES.Text:
            if CONF.sendtext_output.v {  ; temp
                SendText(action_val)
            } else {
                SendInput("{Raw}" . action_val)
            }
        case TYPES.Default, TYPES.KeySimulation:
            SendInput(action_val)
        case TYPES.Function:
            if !RegExMatch(action_val, "^(?<name>\w+)(?:\((?<args>.*)\))?$", &m) {
                throw Error("Wrong function value: " . action_val)
            }
            args := _ParseFuncArgs(m["args"])
            SetTimer(%m["name"]%.Bind(args*), -1)
    }
}


TreatAsOtherNode(path) {  ; custom func  ; NTT
    if !path || !path.Length {
        return
    }
    if path[1] is Integer {
        path := [path]
    }

    start_unode := ROOTS[current_layout]
    for arr in path {
        len := arr.Length
        start_unode := start_unode.GetNode(arr[1], len > 1 ? arr[2] : 0, len > 2 ? arr[3] : 0)
        if !start_unode {
            return  ; wrong path
        }
    }

    TransitionProcessing(start_unode)
}


_GetActiveView(node_like, ctx_id:=0) {
    if !node_like {
        return false
    }

    try {
        return node_like.GetActiveVariant(ctx_id)
    } catch {
        return false
    }
}

_GetFin(node_like, ctx_id:=0) {
    view := _GetActiveView(node_like, ctx_id)
    return view ? view.fin : false
}

_GetScancodes(node_like, ctx_id:=0) {
    view := _GetActiveView(node_like, ctx_id)
    return view ? view.scancodes : Map()
}

_GetChords(node_like, ctx_id:=0) {
    view := _GetActiveView(node_like, ctx_id)
    return view ? view.chords : Map()
}

_GetGestures(node_like, ctx_id:=0) {
    view := _GetActiveView(node_like, ctx_id)
    return view ? view.gestures : Map()
}