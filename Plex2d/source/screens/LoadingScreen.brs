function LoadingScreen() as object
    if m.LoadingScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentsScreen())

        obj.screenName = "Loading Screen"

        obj.Show = loadingShow
        obj.GetComponents = loadingGetComponents
        obj.FindServer = loadingFindServer
        obj.OnServerSelected = loadingOnServerSelected
        obj.OnWaitTimer = loadingOnWaitTimer
        obj.ShowFailureDialog = loadingShowFailureDialog

        m.LoadingScreen = obj
    end if

    return m.LoadingScreen
end function

function createLoadingScreen() as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(LoadingScreen())

    obj.Init()

    Application().clearScreens()

    return obj
end function

sub loadingGetComponents()
    m.DestroyComponents()

    if appSettings().GetGlobal("IsHD") = true then
        image = "pkg:/images/Splash_HD.png"
    else
        image = "pkg:/images/splash_SD32.png"
    end if

    background = createImage(image, 1280, 720)
    background.setFrame(0, 0, background.width, background.height)
    m.components.Push(background)
end sub

sub loadingOnServerSelected(server=invalid as dynamic)
    if m.callback <> invalid then
        Application().Off("change:selectedServer", m.callback)
        m.callback = invalid
    end if

    if m.waitTimer <> invalid then
        m.waitTimer.active = false
        m.waitTimer = invalid
    end if

    ' TODO(rob): logic will need to be modified when we allow IAP
    if (MyPlexAccount().isOffline = false and MyPlexAccount().isSignedIn = false) or MyPlexAccount().isEntitled = false then
        Application().PushScreen(createPinScreen())
    else if server <> invalid then
        Application().pushScreen(createHomeScreen(server))
    else
        m.ShowFailureDialog()
    end if
end sub

sub loadingFindServer()
    server = PlexServerManager().GetSelectedServer()

    if server = invalid then
        GDMDiscovery().Discover()
        MyPlexManager().RefreshResources()

        m.waitTimer = createTimer("waitTimer")
        m.waitTimer.SetDuration(17000)
        Application().AddTimer(m.waitTimer, createCallable("OnWaitTimer", m))

        m.callback = CreateCallable("OnServerSelected", m, Rnd(256))
        Application().On("change:selectedServer", m.callback)
    else
        m.OnServerSelected(server)
    end if
end sub

sub loadingShow()
    ApplyFunc(ComponentsScreen().Show, m)
    m.FindServer()
end sub

sub loadingOnWaitTimer(timer as object)
    m.ShowFailureDialog()
end sub

sub loadingShowFailureDialog()
    if m.waitTimer <> invalid then
        m.waitTimer.active = false
        m.waitTimer = invalid
    end if
    Application().PushScreen(createServersUnavailableScreen())
end sub
