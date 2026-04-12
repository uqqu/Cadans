class Logger {
    static file := A_ScriptDir . "\app.log"
    static level := 3

    static buf := []
    static buf_chars := 0
    static flush_every_lines := 1000
    static flush_every_ms := 10000
    static timer_on := false

    static Start() {
        if this.timer_on {
            return
        }
        this.timer_on := true
        SetTimer(this._FlushTimer.Bind(this), this.flush_every_ms)
        OnExit(this._OnExit.Bind(this))
    }

    static Debug(msg) => this._Log(3, "DEBUG", msg)
    static Info(msg)  => this._Log(2, "INFO",  msg)
    static Error(msg) => this._Log(1, "ERROR", msg)

    static _Log(lvl, tag, msg) {
        if lvl > this.level {
            return
        }

        _time := Format("{:s}.{:03d}", FormatTime(A_Now, "HH:mm:ss"), Mod(A_TickCount, 1000))
        line := _time . " [" . tag . "] " . msg . "`r`n"

        this.buf.Push(line)
        this.buf_chars += StrLen(line)

        if this.buf.Length >= this.flush_every_lines
            this.Flush()
    }

    static Flush() {
        if !this.buf.Length {
            return
        }
        block := ""
        for s in this.buf {
            block .= s
        }
        this.buf := []
        this.buf_chars := 0
        FileAppend(block, this.file, "UTF-8")
    }

    static _FlushTimer(*) {
        this.Flush()
    }

    static _OnExit(*) {
        this.Flush()
    }
}