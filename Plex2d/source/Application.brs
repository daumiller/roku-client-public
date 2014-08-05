function Application()
    obj = m.Application

    if obj = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.port = CreateObject("roMessagePort")
        obj.nextScreenID = 1
        obj.screens = []

        obj.nextTimerID = 1
        obj.timers = {}
        obj.timersByScreen = {}

        obj.AssignScreenID = appAssignScreenID
        obj.PushScreen = appPushScreen
        obj.PopScreen = appPopScreen

        obj.AddTimer = appAddTimer

        obj.Run = appRun
        obj.ProcessOneMessage = appProcessOneMessage

        obj.reset()
        m.Application = obj
    end if

    return obj
end function

sub appAssignScreenID(screen)
    if screen.screenID = invalid then
        screen.screenID = m.nextScreenID
        m.nextScreenID = m.nextScreenID + 1
    end if
end sub

sub appPushScreen(screen)
    if m.screens.Count() > 0 then
        oldScreen = m.screens.Peek()
    else
        oldScreen = invalid
    end if

    m.AssignScreenID(screen)
    m.screens.Push(screen)

    if oldScreen <> invalid then
        oldScreen.Deactivate()
    end if

    screen.Show(invalid)
end sub

sub appPopScreen(screen)
    ' TODO(schuyler): There's much more logic and paranoia in the old version of
    ' this method. Is any warranted here?

    callActivate = true
    screenID = screen.ScreenID.toStr()

    if screen.screenID <> m.screens.Peek().screenID then
        ' TODO(schuyler): Is this much of a concern now that we're not using
        ' standard dialogs? Presumably not...
        callActivate = false
    else
        screen.Destroy()
        m.screens.Pop()
    end if

    ' Clean up any timers initiated by this screen
    timers = m.timersByScreen[screenID]
    if timers <> invalid then
        for each timerID in timers
            timer = m.timers[timerID]
            timer.active = false
            timer.listener = invalid
            m.timers.Delete(timerID)
        next
        m.timersByScreen.Delete(screenID)
    end if

    if m.screens.Count() > 0 and callActivate then
        m.screens.Peek().Activate(invalid)
    end if
end sub

sub appRun()
    Info("Starting global message loop")

    ' TODO(schuyler): Not the best place for this presumably, but you get the idea...
    if m.screens.Count() = 0 then
        m.PushScreen(createWelcomeScreen())
    end if

    timeout = 0
    while m.screens.Count() > 0
        timeout = m.ProcessOneMessage(timeout)
    end while

    Info("Finished global message loop")
end sub

function appProcessOneMessage(timeout)
    WebServer().PreWait()

    msg = wait(timeout, m.port)

    if msg <> invalid then
        Debug("Processing " + type(msg))
        m.screens.Peek().HandleMessage(msg)

        if type(msg) = "roSocketEvent" then
            ' Assume it was for the web server (it won't hurt if it wasn't)
            WebServer().PostWait()
        end if
    end if

    ' Check for any expired timers
    timeout = 0
    for each timerID in m.timers
        timer = m.timers[timerID]
        if timer.IsExpired() then
            timer.listener.OnTimerExpired(timer)
        end if

        ' Make sure we set a timeout on the wait so we'll catch the next timer
        remaining = timer.RemainingMillis()
        if remaining > 0 and (timeout = 0 or remaining < timeout) then
            timeout = remaining
        end if
    next

    return timeout
end function

sub appAddTimer(timer, listener)
    timer.ID = m.nextTimerID.toStr()
    m.nextTimerID = m.nextTimerID + 1
    timer.listener = listener
    m.timers[timer.ID] = timer

    screenID = listener.screenID.toStr()
    if not m.timersByScreen.DoesExist(screenID) then
        m.timersByScreen[screenID] = []
    end if
    m.timersByScreen[screenID].Push(timer.ID)
end sub
