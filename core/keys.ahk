SYSMOD_HK_REGISTRY := Map()

for sc in ALL_SCANCODES {
    if !(sc is Number) {
        if sc == "LButton" || sc == "RButton" || sc == "WheelUp" || sc == "WheelDown" {
            HotIf CheckMouse.Bind(sc)
                Hotkey(sc, ((sc) => (*) => OnKeyDown(sc))(sc))
            HotIf UpCheck.Bind(sc)
                Hotkey(sc . " up", ((sc) => (*) => OnKeyUp(sc))(sc))
        } else {
            HotIf PreCheck.Bind(sc)
                Hotkey(sc, ((sc) => (*) => OnKeyDown(sc))(sc))
            HotIf UpCheck.Bind(sc)
                Hotkey(sc . " up", ((sc) => (*) => OnKeyUp(sc))(sc))
        }
    } else if !SYS_MODIFIERS.Has(sc) {
        HotIf PreCheck.Bind(sc)
            Hotkey(SC_STR[sc], ((sc) => (*) => OnKeyDown(sc))(sc))
        HotIf UpCheck.Bind(sc)
            Hotkey(SC_STR[sc] . " up", ((sc) => (*) => OnKeyUp(sc))(sc))
    } else {
        HotIf GuiCheck.Bind(sc)
            Hotkey("~" . SC_STR[sc], ((sc) => (*) => OnKeyDown(sc))(sc))
        HotIf UpCheck.Bind(sc)
            Hotkey("~" . SC_STR[sc] . " up", ((sc) => (*) => OnKeyUp(sc))(sc))
    }
}
HotIf


UpCheck(sc, *) {
    if init_drawing && sc == "RButton" {
        EndDraw()
        return true
    }
    if init_obj && sc == "LButton" && active_hwnd == UI.Hwnd {
        StopDragButtons()
        return true
    }
    return current_presses.Has(sc) || up_actions.Has(sc)
}


GuiCheck(sc, *) {
    global catched_gui_func

    if current_presses.Has(sc) {
        return false
    }

    ; if the focus is on the our GUI – process separately
    if active_hwnd == UI.Hwnd {
        catched_gui_func := true  ; memorize for main func; cannot be performed now due to keywait
        return true
    } else if s_gui && s_gui.Hwnd && active_hwnd == s_gui.Hwnd && PasteSCToInput(sc) {
        catched_gui_func := true
        return true
    }
    return false
}


CheckMouse(sc, *) {
    if init_drawing && sc == "RButton" {
        return true
    } else if is_drag_mode && active_hwnd == UI.Hwnd {
        if sc == "LButton" {
            MouseGetPos(,, &win_id, &ctrl_hwnd, 2)
            if win_id == UI.Hwnd && ctrl_hwnd {
                obj := GuiCtrlFromHwnd(ctrl_hwnd)
                if obj {
                    is_btn := UI.buttons.Has(obj.Name)
                    try is_btn := UI.buttons.Has(Integer(obj.Name))
                    if is_btn {
                        StartDragButtons(obj)
                        return true
                    }
                }
            }
        } else if sc == "RButton" {
            return true
        }
    }

    if active_hwnd == UI.Hwnd || s_gui && s_gui.Hwnd && active_hwnd == s_gui.Hwnd {
        if gest_overlay {  ;NTT
            DestroyGestOverlay()
        }
        return false
    }

    return PreCheck(sc)
}


_MakeSysModPredKey(unode, ctx_id) {
    return ObjPtr(unode) . "|" . ctx_id
}


_AddSysModRegEntry(reg, pred_key, pred_func, hk, sc, extra_mod) {
    if !reg.Has(pred_key) {
        reg[pred_key] := {
            pred: pred_func,
            hotkeys: Map()
        }
    }

    reg[pred_key].hotkeys[hk] := {
        sc: sc,
        extra_mod: extra_mod
    }
}


_ApplySysModRegistry(new_reg) {
    global SYSMOD_HK_REGISTRY

    for pred_key, old_group in SYSMOD_HK_REGISTRY {
        new_group := new_reg.Get(pred_key, false)

        HotIf(old_group.pred)

        for hk, old_item in old_group.hotkeys {
            need_remove := false

            if !new_group || !new_group.hotkeys.Has(hk) {
                need_remove := true
            } else {
                new_item := new_group.hotkeys[hk]
                if old_item.extra_mod !== new_item.extra_mod {
                    need_remove := true
                }
            }

            if need_remove {
                try Hotkey(hk, "Off")
                try Hotkey(hk . " up", "Off")
            }
        }

        HotIf()
    }

    for pred_key, new_group in new_reg {
        old_group := SYSMOD_HK_REGISTRY.Get(pred_key, false)

        HotIf(new_group.pred)

        for hk, new_item in new_group.hotkeys {
            need_add := false

            if !old_group || !old_group.hotkeys.Has(hk) {
                need_add := true
            } else {
                old_item := old_group.hotkeys[hk]
                if old_item.extra_mod !== new_item.extra_mod {
                    need_add := true
                }
            }

            if need_add {
                down_handler := ((sc, extra_mod) =>
                    (*) => OnKeyDown(sc, extra_mod))(new_item.sc, new_item.extra_mod)
                up_handler := ((sc, extra_mod) =>
                    (*) => OnKeyUp(sc, extra_mod))(new_item.sc, new_item.extra_mod)

                Hotkey(hk, down_handler)
                Hotkey(hk . " up", up_handler)
            }
        }

        HotIf()
    }

    HotIf()
    SYSMOD_HK_REGISTRY := new_reg
}


SetSysModHotkeys() {
    global SYSMOD_HK_REGISTRY
    static first_start := true

    if first_start {
        first_start := false
        return
    }

    new_reg := Map()

    stack := []
    for lang, root in ROOTS {
        if lang {
            for ctx_id in PROC_CTX.all_ids {
                stack.Push([root, ctx_id])
            }
        }
    }

    while stack.Length {
        item := stack.Pop()
        unode := item[1]
        ctx_id := item[2]

        pred_key := _MakeSysModPredKey(unode, ctx_id)
        pred_func := _CompareGlob.Bind(unode, ctx_id)

        bit_modifiers := Map()
        modifiers := []

        for key in ALL_SCANCODES {
            m_node := unode.GetModFin(key, true, ctx_id)
            if m_node {
                if SYS_MODIFIERS.Has(key) {
                    bit := Integer(m_node.down_val)
                    if !bit_modifiers.Has(bit) {
                        bit_modifiers[bit] := []
                    }
                    bit_modifiers[bit].Push(SYS_MODIFIERS[key])
                } else {
                    modifiers.Push(key)
                }
            }
        }

        for sc, mods in _GetScancodes(unode, ctx_id) {
            for md, next_unode in mods {
                chs := []
                bt := 0
                seen_ch := Map()

                for bit, ch in bit_modifiers {
                    if (md & (1 << bit)) && !seen_ch.Has(ch) {
                        chs.Push(ch)
                        bt += 1 << bit
                        seen_ch[ch] := 1
                    }
                }

                if chs.Length {
                    for res in CombineGroups(chs) {
                        hk := res . SC_STR[sc]
                        _AddSysModRegEntry(new_reg, pred_key, pred_func, hk, sc, bt)
                    }
                }

                if _GetScancodes(next_unode, ctx_id).Count {
                    stack.Push([next_unode, ctx_id])
                }
            }
        }

        for md in modifiers {
            seen_groups := Map()

            for bit, chs in bit_modifiers {
                grp_key := JoinArr(chs, "|")
                if seen_groups.Has(grp_key) {
                    continue
                }
                seen_groups[grp_key] := 1

                for ch in chs {
                    hk := ch . SC_STR[md]
                    _AddSysModRegEntry(new_reg, pred_key, pred_func, hk, md, 1 << bit)
                }
            }
        }
    }

    _ApplySysModRegistry(new_reg)
}


_CompareGlob(mem_unode, mem_ctx, *) {
    CheckLayout()
    return current_ctx == mem_ctx && curr_unode == mem_unode
}


CombineGroups(groups, index:=1, pref:="") {
    result := []

    if index > groups.Length {
        result.Push(pref)
        return result
    }

    for val in groups[index] {
        result.Push(CombineGroups(groups, index+1, pref . val)*)
    }

    return result
}