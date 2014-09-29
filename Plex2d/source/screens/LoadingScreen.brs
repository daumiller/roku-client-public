function LoadingScreen() as object
    if m.LoadingScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.screenName = "Loading Screen"

        obj.show = loadingScreenShow
        obj.activate = loadingActivate
        obj.deactivate = loadingDeactivate
        obj.handleMessage = loadingHandleMessage
        obj.onWaitTimer = loadingOnWaitTimer
        obj.createBackground = loadingCreateBackground

        obj.reset()
        m.LoadingScreen = obj
    end if

    return m.LoadingScreen
end function

sub loadingDeactivate(screen as dynamic)
    m.screen.close()
end sub

Function createLoadingScreen() As Object
    obj = CreateObject("roAssociativeArray")
    obj.append(BaseScreen())
    obj.append(LoadingScreen())

    obj.screen = CreateObject("roImageCanvas")
    obj.screen.SetRequireAllImagesToDraw(false)
    obj.screen.SetMessagePort(m.port)
    obj.canvasrect = obj.screen.GetCanvasRect()

    obj.createBackground()

    ' Application().clearScreens()

    return obj
End Function

sub loadingCreateBackground()
    ' show the Plex Logo while loading..
    m.screen.setLayer(0, {Color:"#111111", CompositionMode:"Source"})
    if appSettings().GetGlobal("IsHD") = true then
        image = "file://pkg:/images/Splash_HD.png"
    else
        image = "file://pkg:/images/splash_SD32.png"
    end if
    layer = {
            Url: image,
            TargetRect: {x:0, y:0, w:int(m.canvasrect.w), h:int(m.canvasrect.h)}
            }
    m.screen.SetLayer(1, layer)
end sub

sub loadingScreenShow(arg = invalid)
    m.screen.show()

    ' wait for a valid server before we show the home screen
    ' or fallback to show the pinScreen?
    timer = createTimer("waitForServer")
    timer.Attempts = 0
    timer.maxPrimaryAttempts = 2 ' wait for selectedServer (this really shouldn't take any time)
    timer.maxAttempts = 15       ' max attempts to try and find a server before giving up
    timer.SetDuration(1000, true)
    Application().AddTimer(timer, createCallable("OnWaitTimer", m))
end sub

function loadingHandleMessage(msg)
    ' no-op - user cannot use keys during the loading screen
    return true
end function

sub loadingActivate(arg = invalid)
    Application().pushScreen(createLoadingScreen())
end sub

sub loadingOnWaitTimer(timer as object)

    ' Here we are waiting for a valid server to come online.
    '  1. try to use the best server (primary & owned)
    '  2. query the server for the data needed before we create the home screen
    '  3. create home screen when pending ALL request complete
    if timer.Name = "waitForServer" then

        timer.Attempts = timer.Attempts+1
        foundServer = invalid

        selectedServer = giveMeAServerPlease()
        if selectedServer <> invalid then
            Debug("using selected server"+tostr(selectedServer.name))
            foundServer = selectedServer
        else if timer.Attempts > timer.maxPrimaryAttempts then
            if timer.Attempts = timer.maxPrimaryAttempts+1 then Debug("fallback to a secondary/shared server")
            ' TODO(rob) this needs to be updated to use the right logic
            ' and will probably be a method in PlexServerManager()
            foundServer = giveMeAServerPlease()
        end if

        ' we have a server. We can now fire off the api events for the
        ' required data before we create the home screen
        if foundServer <> invalid then
            timer.Active = false

            ' create the home screen now
            Application().pushScreen(createHomeTestScreen(foundServer))
        else if timer.Attempts >= timer.maxAttempts then
            ' SHOW pin screen if no servers and not signed in.
            if MyPlexAccount().IsSignedIn = false
                Application().PushScreen(createPinScreen())
            else
                dialog = createBaseDialog()
                dialog.Title = "Plex Media Server not found"
                dialog.Text = "We could not locate or contact the Plex Media Server. Please make sure the sever is running and is accessible. TODO: add signout button"
                dialog.SetButton("reload", "Try again")
                dialog.SetButton("signin", "Sign In")
                Application().pushScreen(dialog)
            end if
            Debug("TODO:loadingOnTimerExpired::show a help screen, we can't find any servers!")
            timer.Active = false
        else if timer.Attempts >= timer.maxPrimaryAttempts then
            Debug("waiting for primary/owned or shared server: " + tostr(timer.maxAttempts-timer.attempts) + " attempts left until we fallback to shared server")
        else
            Debug("waiting for primary/owned server: " + tostr(timer.maxPrimaryAttempts-timer.attempts) + " attempts left until we fallback to shared server")
        end if

    end if
End Sub

' temporary until we have the right function to use
function giveMeAServerPlease(ignoreServer = invalid as object)
    servers = PlexServerManager().getServers()

    foundServer = invalid
    for each server in servers
        if server.isReachable() = true and (ignoreServer = invalid or NOT(server.Equals(ignoreServer))) then
            ' try owned and local first (exit if found)
            if server.owned = true and server.activeConnection.isLocal then
                foundServer = server
                Debug("found owned and locaal server:"+tostr(foundServer.name))
                exit for
            end if

            ' any owned server will be used next
            if server.owned = true then
                foundServer = server
                Debug("(possible fallback): Did not find primary, but found owned:"+tostr(foundServer.name))
            end if

            ' not owned/local - fallback server
            if foundServer = invalid then
                foundServer = server
                Debug("(possible fallback): Did not find primary/owned, but found shared:"+tostr(foundServer.name))
            end if
        end if
    end for

    return foundServer
end function
