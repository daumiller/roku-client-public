function MyPlexAccount()
    if m.MyPlexAccount = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.isSignedIn = false
        obj.username = invalid
        obj.email = invalid
        obj.isPlexPass = false
        obj.authToken = invalid

        ' NOTE: We can't format an roList JSON, because... because. So if
        ' we decide that we want things like features or entitlements, we'll
        ' probably have to use roArray. We probably don't need to store those
        ' though.

        obj.SaveState = mpaSaveState
        obj.LoadState = mpaLoadState
        obj.SignOut = mpaSignOut
        obj.ValidateToken = mpaValidateToken

        obj.OnAccountResponse = mpaOnAccountResponse

        m.MyPlexAccount = obj

        obj.LoadState()
    end if

    return m.MyPlexAccount
end function

sub mpaSaveState()
    obj = {
        username: m.username,
        email: m.email,
        isPlexPass: m.isPlexPass,
        authToken: m.authToken
    }

    AppSettings().SetPreference("MyPlexAccount", FormatJson(obj), "myplex")
end sub

sub mpaLoadState()
    ' Look for the new JSON serialization. If it's not there, look for the
    ' old token and Plex Pass values.

    Application().AddInitializer("myplex")
    settings = AppSettings()

    json = settings.GetPreference("MyPlexAccount", invalid, "myplex")

    if json <> invalid then
        obj = ParseJson(json)
        if obj <> invalid then
            m.username = obj.username
            m.email = obj.email
            m.isPlexPass = obj.isPlexPass
            m.authToken = obj.authToken
        end if
    else
        m.authToken = settings.GetPreference("AuthToken", invalid, "myplex")
        m.isPlexPass = (settings.GetPreference("IsPlexPass", "0", "misc") = "1")
    end if

    if m.authToken <> invalid then
        m.isSignedIn = true

        request = createMyPlexRequest("/users/account")
        context = request.CreateRequestContext("account", createCallable("OnAccountResponse", m))
        Application().StartRequest(request, context)
    else
        m.isSignedIn = false
        Application().ClearInitializer("myplex")
    end if
end sub

sub mpaOnAccountResponse(request as object, response as object, context as object)
    oldUsername = m.username

    if response.IsSuccess() then
        xml = response.GetBodyXml()

        ' The user is signed in
        m.username = xml@username
        m.email = xml@email
        m.isSignedIn = true
        m.isPlexPass = (xml.subscription <> invalid and xml.subscription@active = "1")
        m.authToken = xml@authenticationToken

        Info("Authenticated as " + tostr(m.username))

        m.SaveState()
        MyPlexManager().Publish()
        MyPlexManager().RefreshResources()
    else if response.GetStatus() = 401 then
        ' The user is specifically unauthorized, clear everything
        Warn("User is unauthorized")

        m.SignOut()
    else
        ' Unexpected error, keep using whatever we read from the registry
        Warn("Unexpected response from plex.tv (" + tostr(response.GetStatus()) + "), reusing sign in status of " + tostr(m.isSignedIn))
    end if

    Application().ClearInitializer("myplex")
    AppManager().ResetState()

    if oldUsername <> m.username then
        Application().Trigger("change:user", [m])
    end if
end sub

sub mpaSignOut()
    if not m.isSignedIn then return

    m.username = invalid
    m.email = invalid
    m.isSignedIn = false
    m.isPlexPass = false
    m.authToken = invalid

    Application().Trigger("change:user", [m])

    m.SaveState()
end sub

sub mpaValidateToken(token as string)
    m.authToken = token
    m.isSignedIn = true

    request = createMyPlexRequest("/users/sign_in.xml")
    context = request.CreateRequestContext("sign_in", createCallable("OnAccountResponse", m))
    Application().StartRequest(request, context, "")
end sub
