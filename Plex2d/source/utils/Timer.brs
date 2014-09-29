function TimerClass()
    if m.TimerClass = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Properties
        obj.active = true
        obj.repeat = false
        obj.durationMillis = 0
        obj.name = ""

        ' Methods
        obj.LogElapsedTime = timerLogElapsedTime
        obj.GetElapsedMillis = timerGetElapsedMillis
        obj.GetElapsedSeconds = timerGetElapsedSeconds
        obj.Mark = timerMark
        obj.SetDuration = timerSetDuration
        obj.IsExpired = timerIsExpired
        obj.RemainingMillis = timerRemainingMillis

        m.TimerClass = obj
    end if

    return m.TimerClass
end function

function createTimer(name)
    obj = CreateObject("roAssociativeArray")

    obj.append(TimerClass())
    obj.reset()

    obj.name = name
    obj.timer = CreateObject("roTimespan")
    obj.timer.Mark()

    return obj
end function

sub timerLogElapsedTime(msg, mark=true)
    elapsed = m.timer.TotalMilliseconds()
    Debug(msg + " took: " + tostr(elapsed) + "ms")
    if mark then m.timer.Mark()
end sub

function timerGetElapsedMillis()
    return m.timer.TotalMilliseconds()
end function

function timerGetElapsedSeconds()
    return m.timer.TotalSeconds()
end function

sub timerMark()
    m.timer.Mark()
end sub

sub timerSetDuration(millis, repeat=false)
    m.durationMillis = millis
    m.repeat = repeat
end sub

function timerIsExpired()
    if m.active then
        if m.timer.TotalMilliseconds() > m.durationMillis then
            if m.repeat then
                m.Mark()
            else
                m.active = false
            end if
            return true
        end if
    end if

    return false
end function

function timerRemainingMillis()
    if m.active then
        remaining = m.durationMillis - m.timer.TotalMilliseconds()
        if remaining <= 0 then remaining = 1
        return remaining
    end if

    return 0
end function

function PerfTimer() as object
    if m.PerfTimer = invalid then
        obj = createTimer("perfTimer")

        obj.Log = perfTimerLog

        m.PerfTimer = obj
    end if

    return m.PerfTimer
end function

sub perfTimerLog(msg = "" as string)
    if m.active = true then
        m.LogElapsedTime("++++++++++ PERFORMANCE: " + tostr(msg))
    end if
end sub
