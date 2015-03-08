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

        obj.queuedMessages = CreateObject("roList")

        obj.AssignScreenID = appAssignScreenID
        obj.ClearScreens = appClearScreens
        obj.PushScreen = appPushScreen
        obj.PopScreen = appPopScreen
        obj.IsActiveScreen = appIsActiveScreen
        obj.GoHome = appGoHome
        obj.CreateLockScreen = appCreateLockScreen
        obj.CheckExclusions = appCheckExclusions
        obj.ShowSplash = appShowSplash

        obj.AddTimer = appAddTimer

        obj.StartRequest = appStartRequest
        obj.StartRequestIgnoringResponse = appStartRequestIgnoringResponse
        obj.CancelRequests = appCancelRequests
        obj.OnRequestTimeout = appOnRequestTimeout

        obj.AddSocketCallback = appAddSocketCallback

        obj.Run = appRun
        obj.ProcessOneMessage = appProcessOneMessage
        obj.ProcessNonBlocking = appProcessNonBlocking
        obj.ProcessUrlEvent = appProcessUrlEvent
        obj.ProcessTextureEvent = appProcessTextureEvent
        obj.HasQueuedMessage = appHasQueuedMessage
        obj.OnInitialized = appOnInitialized

        obj.OnAccountChange = appOnAccountChange
        obj.ShowInitialScreen = appShowInitialScreen

        ' Track anything that needs to be initialized before the app can start
        ' and an initial screen can be shown. These need to be important,
        ' generally related to whether the app is unlocked or not.
        obj.AddInitializer = appAddInitializer
        obj.ClearInitializer = appClearInitializer
        obj.IsInitialized = appIsInitialized


        ' Modals. It seems to be a better fit to place the loading modals
        ' within the application singleton. We can adapt and show different
        ' models based on the current screen type.
        obj.ShowLoadingModal = appShowLoadingModal
        obj.CloseLoadingModal = appCloseLoadingModal
        obj.CheckLoadingModal = appCheckLoadingModal
        obj.OnLoadingModalTimeout = appOnLoadingModalTimeout

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
    if Application().IsActiveScreen(VideoPlayer()) then
        Warn("Cannot push a new screen while video is active.")
        return
    end if

    if m.screens.Count() > 0 then
        oldScreen = m.screens.Peek()

        ' close any overlay screen (resets focusedItem)
        if IsFunction(oldScreen.closeOverlays) then
            oldScreen.closeOverlays(false)
        end if

        ' Remember the last focus ID and position to refocus
        if oldScreen.focusedItem <> invalid then
            oldScreen.refocus = computeRect(oldScreen.focusedItem)
            oldScreen.refocus.id = oldScreen.focusedItem.id
        end if

        ' Clean up any requests initiated by this screen
        m.CancelRequests(tostr(oldScreen.screenID))

        m.ShowLoadingModal(oldScreen, oldScreen.Deactivate)
    else
        oldScreen = invalid
    end if

    m.AssignScreenID(screen)
    m.screens.Push(screen)

    Analytics().TrackScreen(screen.screenName)
    Debug("Pushing screenID " + tostr(screen.screenID) + " onto stack - " + screen.screenName + ", total screens:" + tostr(m.screens.Count()))

    screen.Show()
end sub

sub appPopScreen(screen as object, callActivate=true as boolean)
    m.ShowLoadingModal(screen, screen.Destroy)
    screenID = screen.ScreenID.toStr()

    ' It's possible we may push a screen before we have successfully popped it, or in
    ' reality, it's possible the roku may close a screen from underneath us. The
    ' latter is real as VideoPlayer will be closed if we show a screen over the top
    ' (lock screen). In this case, lets just delete the screen and cleanup.
    if m.screens.Count() > 0 and screen.screenID <> m.screens.Peek().screenID then
        for index = 0 to m.screens.count() - 1
            if screen.screenID = m.screens[index].screenID then
                m.screens.Delete(index)
                exit for
            end if
        end for
        ' Do not activate current screen since we are not the current one
        callActivate = false
    else
        m.screens.Pop()
    end if

    ' Clean up any requests initiated by this screen
    m.CancelRequests(screenID)

    ' Disable any listeners immediately
    if IsFunction(screen.DisableListeners) then
        screen.DisableListeners()
    end if

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

    ' Set the remote back to navigation (default for all screens)
    NowPlayingManager().location = "navigation"

    ' close any overlay screen (resets focusedItem)
    if IsFunction(screen.closeOverlays) then
        screen.closeOverlays(false)
    end if

    if m.screens.Count() > 0 and callActivate then
        newScreen = m.screens.Peek()
        Debug("Activate previous screen: " + tostr(newScreen.screenName))
        newScreen.Activate()
        Analytics().TrackScreen(newScreen.screenName)
    end if
end sub

function appIsActiveScreen(screen as object) as boolean
    return (m.screens.Peek() <> invalid and screen.screenID = m.screens.Peek().screenID)
end function

sub appRun()
    Info("Starting global message loop")
    ' Show the splash screen immediately
    m.ShowSplash()

    ' Make sure we initialize anything that needs to run in the background
    Analytics()
    MyPlexAccount()
    AppManager()
    WebServer()
    GDMAdvertiser()
    GDMDiscovery().Discover()
    InitRemoteControlHandlers()
    m.ClearInitializer("application")

    timeout = 1000
    while m.screens.Count() > 0 or not m.IsInitialized()
        ' process any audio request immediately
        msg = m.port.PeekMessage()
        if type(msg) = "roUniversalControlEvent" then
            keyCode = msg.GetInt()
            AudioEvents().OnKeyPress(keyCode)
            ignoreAudio = true
        else
            ignoreAudio = false
        end if
        timeout = m.ProcessOneMessage(timeout, ignoreAudio)
    end while

    ' Clean up
    AudioPlayer().Cleanup()
    Analytics().Cleanup()
    GDMAdvertiser().Cleanup()
    GDMDiscovery().Cleanup()
    m.pendingRequests.Clear()
    m.timers.Clear()
    m.socketCallbacks.Clear()

    Info("Finished global message loop")
end sub

function appProcessOneMessage(timeout as integer, ignoreAudio=false as boolean)
    if AppSettings().GetGlobal("roDeviceInfo").TimeSinceLastKeyPress() > AppSettings().GetGlobal("idleLockTimeout") then
         m.CreateLockScreen()
    end if

    WebServer().PreWait()

    if m.queuedMessages.Count() > 0 then
        msg = m.queuedMessages.Shift()
    else
        msg = wait(timeout, m.port)
    end if

    if msg <> invalid then
        ' Socket events are chatty (every 5 seconds per PMS) and URL events
        ' almost always log immediately, so this is just noise.
        '
        ' Process any audio event immediately
        if type(msg) = "roUniversalControlEvent" then
            keyCode = msg.GetInt()
            if (keyCode = ComponentsScreen().kp_BK or keyCode - 100 = ComponentsScreen().kp_BK) and Locks().IsLocked("BackButton") then
                Debug(KeyCodeToString(keyCode) + " is disabled")
                return timeout
            end if
            if not ignoreAudio then AudioEvents().OnKeyPress(keyCode)
        else if type(msg) <> "roSocketEvent" and type(msg) <> "roUrlEvent" and type(msg) <> "roTextureRequestEvent" then
            Debug("Processing " + type(msg))
        end if

        for i = m.screens.Count() - 1 to 0 step -1
            if m.screens[i].HandleMessage(msg) then exit for
        end for

        if type(msg) = "roTextureRequestEvent" then
            m.ProcessTextureEvent(msg)
        else if type(msg) = "roSocketEvent" then
            callback = m.socketCallbacks[msg.getSocketID().tostr()]
            if callback <> invalid then
                callback.Call([msg])
            else
                ' Assume it was for the web server (it won't hurt if it wasn't)
                WebServer().PostWait()
            end if
        else if type(msg) = "roUrlEvent" and msg.GetInt() = 1 then
            m.ProcessUrlEvent(msg)
        else if type(msg) = "roChannelStoreEvent" then
            AppManager().HandleChannelStoreEvent(msg)
        else if type(msg) = "roAudioPlayerEvent" then
            AudioPlayer().HandleMessage(msg)
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

function appHasQueuedMessage(predicate as function) as boolean
    for each msg in m.queuedMessages
        if predicate(msg) then return true
    next

    while m.port.PeekMessage() <> invalid
        msg = wait(1, m.port)
        m.queuedMessages.Push(msg)
        if predicate(msg) then return true
    end while

    return false
end function

sub appOnInitialized()
    ' Check for any exclusions and redirect to the official client
    if m.CheckExclusions() then return

    ' Wire up a few of our own listeners
    PlexServerManager()
    m.On("change:user", createCallable("OnAccountChange", m))

    m.Trigger("init", [])

    ' Make sure we have a current app state
    AppManager().ResetState()

    if m.screens.Count() = 0 then
        m.ShowInitialScreen()
    end if
end sub

sub appOnAccountChange(account as dynamic, reallyChanged as boolean)
    Debug("Account changed to " + tostr(account.title))
    ' Clear any AudioPlayer data
    AudioPlayer().Cleanup()
    m.ShowInitialScreen()
end sub

sub appShowInitialScreen()
    m.ClearScreens()
    if MyPlexAccount().isEntitled = false then
        m.pushScreen(createPinScreen())
    else if MyPlexAccount().isAuthenticated = true then
        m.pushScreen(createLoadingScreen())
    else
        m.pushScreen(createUsersScreen())
    end if
end sub

sub appAddTimer(timer as object, callback as object, screenID=invalid as dynamic)
    if timer.ID = invalid then
        timer.ID = m.nextTimerID.toStr()
        m.nextTimerID = m.nextTimerID + 1
    end if

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

        screen = context.callbackCtx
        if screen <> invalid and screen.screenID <> invalid and screen.screenID >= 0 then
            screenID = screen.screenID.toStr()
        else if context.screenID <> invalid and context.screenID >= 0 then
            screenID = context.screenID.toStr()
        else
            screenID = invalid
        end if

        if screenID <> invalid then
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

function appStartRequestIgnoringResponse(url as string, body=invalid as dynamic, contentType=invalid as dynamic, addHeaders=false as boolean) as boolean
    request = createHttpRequest(url)
    context = request.CreateRequestContext("ignored")

    if addHeaders then AddPlexHeaders(request)

    return m.StartRequest(request, context, body, contentType)
end function

sub appCancelRequests(screenID)
    requests = m.requestsByScreen[screenID]
    if requests <> invalid then
        for each requestID in requests
            context = m.pendingRequests[requestID]
            if context <> invalid and context.request <> invalid then context.request.Cancel()
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

sub appShowLoadingModal(screen as object, screenCallBack=invalid as dynamic)
    timer = m.LoadingModalTimer
    if timer = invalid then
        timer = createTimer("LoadingModal")
        timer.SetDuration(500)
        m.LoadingModalTimer = timer
    else if timer.screenCallBack <> invalid then
        ApplyFunc(timer.screenCallBack, timer.screen)
    end if

    timer.screenCallBack = screenCallBack
    timer.screen = screen
    timer.active = true
    timer.Mark()

    m.AddTimer(timer, createCallable("OnLoadingModalTimeout", m))
end sub

sub appOnLoadingModalTimeout(timer as object)
    screen = timer.screen

    ' Loading Modal for roScreens
    if type(screen.screen) = "roAssociativeArray" and type(screen.screen.screen) = "roScreen" then
        loadingModal = createLoadingModal(screen)
        loadingModal.show()
    end if

    ' Modals for other screen types?

    if timer.screenCallBack <> invalid then
        ApplyFunc(timer.screenCallBack, timer.screen)
    end if

    m.LoadingModalTimer = invalid
end sub

sub appCheckLoadingModal()
    if m.LoadingModalTimer <> invalid and m.LoadingModalTimer.isExpired() then
        m.OnLoadingModalTimeout(m.LoadingModalTimer)
    end if
end sub

sub appCloseLoadingModal()
    if m.LoadingModalTimer = invalid then return

    if m.LoadingModalTimer.screenCallBack <> invalid then
        ApplyFunc(m.LoadingModalTimer.screenCallBack, m.LoadingModalTimer.screen)
    end if

    m.LoadingModalTimer.active = false
    m.LoadingModalTimer = invalid
end sub

sub appProcessUrlEvent(msg as object)
    id = msg.GetSourceIdentity().tostr()
    requestContext = m.pendingRequests[id]
    if requestContext <> invalid then
        Info("Got a " + tostr(msg.GetResponseCode()) + " from " + requestContext.request.url)
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
end sub

sub appProcessTextureEvent(msg as object)
    ' TODO(rob) we should be tracking roTextureRequestEvent by screenID
    ' Only one roScreen is available at a time, but we want to ignore
    ' any requests that might come in for a prevoius screen. The logic
    ' to handle that should just be added to the TextureManager
     TextureManager().ReceiveTexture(msg, m.screens.peek())
end sub

sub appProcessNonBlocking()
    msg = m.Port.PeekMessage()
    if type(msg) = "roTextureRequestEvent" then
        msg = m.Port.GetMessage()
        m.ProcessTextureEvent(msg)
    else if type(msg) = "roUrlEvent" and msg.GetInt() = 1 then
        msg = m.Port.GetMessage()
        m.ProcessUrlEvent(msg)
    end if
end sub

sub appClearScreens(keep=0 as integer, activateLastScreen=false as boolean)
    if m.screens.count() > keep then
        Debug("appClearScreens:: keep " + tostr(keep) + ", have:" + tostr(m.screens.count()))
        pushScreens = []

        ' screens to keep (push back into the screens array)
        if keep > 0 then
            for index = 0 to keep-1
                pushScreens.push(m.screens[index])
            end for
        end if

        ' destroy the screen (clean memory)
        for each screen in m.screens
            Application().popScreen(screen, false)
        end for
        m.screens.clear()

        ' push any screens we wanted to keep
        if pushScreens.count() > 0 then
            m.screens.append(pushScreens)
        end if

        if activateLastScreen then
            newScreen = m.screens.Peek()
            newScreen.Activate()
            Analytics().TrackScreen(newScreen.screenName)
        end if

        Debug("appClearScreens:: kept " + tostr(pushScreens.count()) + ", have:" + tostr(m.screens.count()))
    end if
end sub

sub appGoHome()
    m.ClearScreens(1, true)
end sub

sub appCreateLockScreen()
    ' do not lock unprotected users or if automatic sign in is enabled
    if AppSettings().GetBoolPreference("auto_signin") = true or MyPlexAccount().isProtected = false then return

    ' do not lock if already locked or user is not authenticated (startup)
    if GetGlobalAA()["screenIsLocked"] = true or MyPlexAccount().isAuthenticated = false then return

    lastKeyPress = tostr(AppSettings().GetGlobal("roDeviceInfo").TimeSinceLastKeyPress())
    idleTimeout = tostr(AppSettings().GetGlobal("idleLockTimeout"))
    Debug("Creating Lock Screen: last key press=" + lastKeyPress + ", idle timeout=" + idleTimeout)

    ' add global lock and deauthenticate
    GetGlobalAA().AddReplace("screenIsLocked", true)
    MyPlexAccount().isAuthenticated = false

    ' lock an exising users selection screen, or create one.
    screen = m.screens.Peek()
    if screen <> invalid and screen.isLockScreen <> invalid then
        screen.LockScreen(true)
    else
        m.pushScreen(createUsersScreen(false))
    end if
end sub

function appCheckExclusions() as boolean
    ' basics we'll be verifying
    resolution = not AppSettings().GetGlobal("IsHD")
    firmware = not CheckMinimumVersion([5, 6])

    if resolution then
        excluded = true
        title =  "SD resolution is not supported."
        message = "We're sorry, this application is currently not supported on SD screens."
    else if firmware then
        excluded = true
        title =  "Roku firmware version (" + appsettings().GetGlobal("rokuVersionStr") + ") is not supported."
        message = "We're sorry, this application is currently not supported on firmware versions less than 5.6."
    else
        excluded = false
    end if

    if excluded = true then
        ' We are not going to support earlier firmware.
        if not firmware then
            message = message + " Don't worry though, we're working hard to have it ready for everyone very soon."
        end if
        m.PushScreen(createRedirectScreen(title, message))
    end if

    return excluded
end function

sub appShowSplash()
    m.PushScreen(createSplashScreen())
    m.ClearScreens()
end sub
