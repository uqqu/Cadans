; Place your own functions here.
; You can call them directly from assignments using the "function" type,
; specifying the function name and parameters as the assignment action.
; Parameters are parsed and passed without quotes.
;
; Note: functions added here are not included in the compiled (.exe) version.
; Use the uncompiled .ahk version if you want to define your own functions.


Hello() {
    ToolTip("Hello")
    SetTimer(ToolTip, -1000)
}