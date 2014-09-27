function Application()
    if m.Application = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.Append(EventsMixin())

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

        obj.socketCallbacks = {}

        obj.initializers = {}

        obj.AssignScreenID = appAssignScreenID
        obj.PushScreen = appPushScreen
        obj.PopScreen = appPopScreen
        obj.IsActiveScreen = appIsActiveScreen

        obj.AddTimer = appAddTimer

        obj.StartRequest = appStartRequest
        obj.StartRequestIgnoringResponse = appStartRequestIgnoringResponse
        obj.CancelRequests = appCancelRequests
        obj.OnRequestTimeout = appOnRequestTimeout

        obj.AddSocketCallback = appAddSocketCallback

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
    Debug("Pushing screenID " + tostr(screen.screenID) + " onto stack - " + screen.screenName + ", total screens:" + tostr(m.screens.Count()))

    if oldScreen <> invalid then
        oldScreen.Deactivate()
    end if

    screen.Show()
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
            if timer <> invalid then
                timer.active = false
                timer.listener = invalid
                m.timers.Delete(timerID)
            end if
        next
        m.timersByScreen.Delete(screenID)
    end if

    if m.screens.Count() > 0 and callActivate then
        newScreen = m.screens.Peek()
        newScreen.Activate()
        Analytics().TrackScreen(newScreen.screenName)
    end if
end sub

function appIsActiveScreen(screen as object) as boolean
    return (screen.screenID = m.screens.Peek().screenID)
end function

sub appRun()
    Info("Starting global message loop")

    ' Make sure we initialize anything that needs to run in the background
    Analytics()
    MyPlexAccount()
    AppManager()
    WebServer()
    GDMAdvertiser()
    GDMDiscovery().Discover()
    m.ClearInitializer("application")

    timeout = 0
    while m.screens.Count() > 0 or not m.IsInitialized()
        timeout = m.ProcessOneMessage(timeout)
    end while

    ' Clean up
    Analytics().Cleanup()
    GDMAdvertiser().Cleanup()
    GDMDiscovery().Cleanup()
    m.pendingRequests.Clear()
    m.timers.Clear()
    m.socketCallbacks.Clear()

    Info("Finished global message loop")
end sub

function appProcessOneMessage(timeout)
    WebServer().PreWait()

    msg = wait(timeout, m.port)

    if msg <> invalid then
        ' Socket events are chatty (every 5 seconds per PMS) and URL events
        ' almost always log immediately, so this is just noise.
        '
        if type(msg) <> "roSocketEvent" and type(msg) <> "roUrlEvent" and type(msg) <> "roTextureRequestEvent" and type(msg) <> "roUniversalControlEvent" then
            Debug("Processing " + type(msg))
        end if

        for i = m.screens.Count() - 1 to 0 step -1
            if m.screens[i].HandleMessage(msg) then exit for
        end for

        if type(msg) = "roSocketEvent" then
            callback = m.socketCallbacks[msg.getSocketID().tostr()]
            if callback <> invalid then
                callback.Call([msg])
            else
                ' Assume it was for the web server (it won't hurt if it wasn't)
                WebServer().PostWait()
            end if
        else if type(msg) = "roUrlEvent" and msg.GetInt() = 1 then
            id = msg.GetSourceIdentity().tostr()
            requestContext = m.pendingRequests[id]
            if requestContext <> invalid then
                Debug("Got a " + tostr(msg.GetResponseCode()) + " from " + requestContext.request.url)
                m.pendingRequests.Delete(id)

                ' Clear our timeout timer
                if requestContext.timer <> invalid then
                    requestContext.timer.active = false
                    requestContext.timer.requestContext = invalid
                    requestContext.timer = invalid
                end if

                if requestContext.callback <> invalid then
                    requestContext.callback.Call([msg, requestContext])
                end if
            end if
        else if type(msg) = "roChannelStoreEvent" then
            AppManager().HandleChannelStoreEvent(msg)
        end if
    end if

    ' Check for any expired timers
    timeout = 0
    timersToRemove = CreateObject("roList")
    for each timerID in m.timers
        timer = m.timers[timerID]
        if timer.IsExpired() and timer.callback <> invalid then
            timer.callback.Call([timer])
        end if

        ' Make sure we set a timeout on the wait so we'll catch the next timer
        remaining = timer.RemainingMillis()
        if remaining > 0 and (timeout = 0 or remaining < timeout) then
            timeout = remaining
        end if

        ' Clear references to dead timers
        if not timer.active then
            timersToRemove.AddTail(timerID)
        end if
    next

    for each timerID in timersToRemove
        m.timers.Delete(timerID)
    next

    return timeout
end function

sub appOnInitialized()
    m.Trigger("init", [])

    ' Make sure we have a current app state
    AppManager().ResetState()

    ' TODO(schuyler): This is clearly bogus, but we need to show some sort of screen
    if m.screens.Count() = 0 then
        ' TODO(schuyler): Temporarily forcing PIN screen
        m.pushScreen(createPinScreen())
    end if
end sub

sub appAddTimer(timer as object, callback as object, screenID=invalid as dynamic)
    timer.ID = m.nextTimerID.toStr()
    m.nextTimerID = m.nextTimerID + 1
    timer.callback = callback
    m.timers[timer.ID] = timer

    if screenID = invalid and callback <> invalid and callback.context <> invalid then
        screenID = callback.context.screenID
    end if
    if screenID <> invalid then
        if not m.timersByScreen.DoesExist(tostr(screenID)) then
            m.timersByScreen[tostr(screenID)] = []
        end if
        m.timersByScreen[tostr(screenID)].Push(timer.ID)
    end if
end sub

function appStartRequest(request as object, context as object, body=invalid as dynamic, contentType=invalid as dynamic) as boolean
    context.request = request

    started = request.StartAsync(body, contentType)

    if started then
        id = request.GetIdentity()
        m.pendingRequests[id] = context

        ' Screen IDs less than 0 are fake screens that won't be popped until
        ' the app is cleaned up, so no need to waste the bytes tracking them
        ' here.

        listener = context.callbackCtx
        if listener <> invalid and listener.screenID >= 0 then
            screenID = listener.screenID.toStr()

            if not m.requestsByScreen.DoesExist(screenID) then
                m.requestsByScreen[screenID] = []
            end if

            m.requestsByScreen[screenID].Push(id)
        end if

        if context.timeout <> invalid then
            timer = createTimer("request_timeout")
            timer.SetDuration(context.timeout)
            timer.requestContext = context
            context.timer = timer
            m.AddTimer(timer, createCallable("OnRequestTimeout", m))
        end if
    else if context.callback <> invalid then
        context.callback.Call([invalid, context])
    end if

    return started
end function

function appStartRequestIgnoringResponse(url as string, body=invalid as dynamic, contentType=invalid as dynamic) as boolean
    request = createHttpRequest(url)
    context = request.CreateRequestContext("ignored")

    return m.StartRequest(request, context, body, contentType)
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

sub appOnRequestTimeout(timer)
    requestContext = timer.requestContext
    request = requestContext.request
    requestID = request.GetIdentity()

    request.Cancel()
    m.pendingRequests.Delete(requestID)

    Warn("Request to " + request.url + " timed out after " + tostr(timer.GetElapsedSeconds()) + " seconds")

    if requestContext.callback <> invalid then
        requestContext.callback.Call([invalid, requestContext])
    end if

    ' Clear circular references
    timer.requestContext.timer = invalid
    timer.requestContext = invalid
end sub

sub appAddSocketCallback(socket, callback)
    m.socketCallbacks[socket.GetID().tostr()] = callback
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
