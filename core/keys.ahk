for sc in ALL_SCANCODES {
    if sc == "LButton" || sc == "RButton" || sc == "WheelUp" || sc == "WheelDown" {
        HotIf CheckMouse.Bind(sc)
            Hotkey("*" . sc, OnKeyDown.Bind(sc, false, false))
        HotIf UpCheck.Bind(sc)
            Hotkey("*" . sc . " up", OnKeyUp.Bind(sc))
    } else if !SYS_MODIFIERS.Has(sc) {
        HotIf PreCheck.Bind(sc)
            Hotkey("*" . SC_STR[sc], OnKeyDown.Bind(sc, false, false))
        HotIf UpCheck.Bind(sc)
            Hotkey("*" . SC_STR[sc] . " up", OnKeyUp.Bind(sc))
    } else {
        HotIf PreCheck.Bind(sc)
            Hotkey("~*" . SC_STR[sc], OnKeyDown.Bind(sc, false, false))
        HotIf UpCheck.Bind(sc)
            Hotkey("~*" . SC_STR[sc] . " up", OnKeyUp.Bind(sc))
    }
}
HotIf


UpCheck(sc, *) {
    if sysmod_state.Get(sc, false) {
        return true
    }
    if init_drawing && sc == "RButton" {
        EndDraw()
        return true
    }
    if init_obj && sc == "LButton" && active_hwnd == UI.Hwnd {
        StopDragButtons()
        return true
    }
    if current_presses.Has(sc) || up_actions.Has(sc) {
        return true
    }
    return false
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