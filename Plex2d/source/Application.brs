function Application()
    if m.Application = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Fake screen IDs used for HTTP requests
        obj.SCREEN_ANALYTICS = -2
        obj.SCREEN_MYPLEX = -5

        obj.port = CreateObject("roMessagePort")
        obj.nextScreenID = 1
        obj.screens = []

        obj.nextTimerID = 1
        obj.timers = {}
        obj.timersByScreen = {}

        obj.pendingRequests = {}
        obj.requestsByScreen = {}

        obj.initializers = {}

        obj.AssignScreenID = appAssignScreenID
        obj.PushScreen = appPushScreen
        obj.PopScreen = appPopScreen

        obj.AddTimer = appAddTimer

        obj.StartRequest = appStartRequest
        obj.StartRequestIgnoringResponse = appStartRequestIgnoringResponse
        obj.CancelRequests = appCancelRequests

        obj.Run = appRun
        obj.ProcessOneMessage = appProcessOneMessage
        obj.OnInitialized = appOnInitialized

        ' Track anything that needs to be initialized before the app can start
        ' and an initial screen can be shown. These need to be important,
        ' generally related to whether the app is unlocked or not.
        obj.AddInitializer = appAddInitializer
        obj.ClearInitializer = appClearInitializer
        obj.IsInitialized = appIsInitialized

        obj.reset()
        m.Application = obj

        obj.AddInitializer("application")
    end if

    return m.Application
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

    Analytics().TrackScreen(screen.screenName)
    Debug("Pushing screen " + tostr(screen.screenID) + " onto stack - " + screen.screenName)

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

    ' Clean up any requests initiated by this screen
    m.CancelRequests(screenID)

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
        newScreen = m.screens.Peek()
        newScreen.Activate(invalid)
        Analytics().TrackScreen(newScreen.screenName)
    end if
end sub

sub appRun()
    Info("Starting global message loop")

    ' Make sure we initialize anything that needs to run in the background
    MyPlexAccount()
    AppManager()
    WebServer()
    m.ClearInitializer("application")

    timeout = 0
    while m.screens.Count() > 0 or not m.IsInitialized()
        timeout = m.ProcessOneMessage(timeout)
    end while

    ' Clean up
    Analytics().Cleanup()
    m.pendingRequests.Clear()
    m.timers.Clear()

    Info("Finished global message loop")
end sub

function appProcessOneMessage(timeout)
    WebServer().PreWait()

    msg = wait(timeout, m.port)

    if msg <> invalid then
        Debug("Processing " + type(msg))

        for i = m.screens.Count() - 1 to 0 step -1
            if m.screens[i].HandleMessage(msg) then exit for
        end for

        if type(msg) = "roSocketEvent" then
            ' Assume it was for the web server (it won't hurt if it wasn't)
            WebServer().PostWait()
        else if type(msg) = "roUrlEvent" and msg.GetInt() = 1 then
            id = msg.GetSourceIdentity().tostr()
            requestContext = m.pendingRequests[id]
            if requestContext <> invalid then
                Debug("Got a " + tostr(msg.GetResponseCode()) + " from " + requestContext.request.url)
                m.pendingRequests.Delete(id)
                if requestContext.listener <> invalid then
                    requestContext.listener.OnUrlEvent(msg, requestContext)
                end if
                requestContext = invalid
            end if
        else if type(msg) = "roChannelStoreEvent" then
            AppManager().HandleChannelStoreEvent(msg)
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

sub appOnInitialized()
    ' As good a place as any, tell analytics that we've started.
    Analytics().OnStartup(false)

    ' Make sure we have a current app state
    AppManager().ResetState()

    ' TODO(schuyler): This is clearly bogus, but we need to show some sort of screen
    if m.screens.Count() = 0 then
        m.PushScreen(createWelcomeScreen())
    end if
end sub

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

function appStartRequest(request, listener, context, body=invalid, contentType=invalid)
    context.listener = listener
    context.request = request

    started = request.StartAsync(body, contentType)

    if started then
        id = request.GetIdentity()
        m.pendingRequests[id] = context

        ' Screen IDs less than 0 are fake screens that won't be popped until
        ' the app is cleaned up, so no need to waste the bytes tracking them
        ' here.

        if listener <> invalid and listener.screenID >= 0 then
            screenID = listener.screenID.toStr()

            if not m.requestsByScreen.DoesExist(screenID) then
                m.requestsByScreen[screenID] = []
            end if

            m.requestsByScreen[screenID].Push(id)
        end if
    end if

    return started
end function

function appStartRequestIgnoringResponse(url, body=invalid, contentType=invalid)
    request = createHttpRequest(url)

    context = CreateObject("roAssociativeArray")
    context.requestType = "ignored"

    m.StartRequest(request, invalid, context, body, contentType)
end function

sub appCancelRequests(screenID)
    requests = m.requestsByScreen[screenID]
    if requests <> invalid then
        for each requestID in requests
            request = m.pendingRequests[requestID]
            if request <> invalid then request.Cancel()
            m.pendingRequests.Delete(requestID)
        next
        m.requestsByScreen.Delete(screenID)
    end if
end sub

sub appAddInitializer(name)
    m.initializers[name] = true
end sub

sub appClearInitializer(name)
    if m.initializers.Delete(name) AND m.IsInitialized() then
        m.OnInitialized()
    end if
end sub

function appIsInitialized()
    m.initializers.Reset()
    return m.initializers.IsEmpty()
end function
