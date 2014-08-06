function MyPlexAccount()
    if m.MyPlexAccount = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.isSignedIn = false
        obj.username = invalid
        obj.email = invalid
        obj.isPlexPass = false
        obj.authToken = invalid
        obj.features = CreateObject("roList")

        obj.SaveState = mpaSaveState
        obj.LoadState = mpaLoadState
        obj.UpdateAccount = mpaUpdateAccount

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
        authToken: m.authToken,
        features: m.features
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
            m.features.Clear()
            for each feature in obj.features
                m.features.AddTail(feature)
            next
        end if
    else
        m.authToken = settings.GetPreference("AuthToken", invalid, "myplex")
        m.isPlexPass = (settings.GetPreference("IsPlexPass", "0", "misc") = "1")
    end if

    if m.authToken <> invalid then
        m.isSignedIn = true
        MyPlexManager().RefreshAccount()
    else
        m.isSignedIn = false
        Application().ClearInitializer("myplex")
    end if
end sub

sub mpaUpdateAccount(xml, status)
    if xml <> invalid and (status = 200 or status = 201) then
        ' The user is signed in
        m.username = xml@username
        m.email = xml@email
        m.isSignedIn = true
        m.isPlexPass = (xml.subscription <> invalid and xml.subscription@active = "1")
        m.authToken = xml@authenticationToken
        m.features.Clear()

        if xml.subscription <> invalid then
            for each feature in xml.subscription.feature
                m.features.Push(feature@id)
            next
        end if

        Info("Authenticated as " + tostr(m.username))

        m.SaveState()
        MyPlexManager().Publish()

        ' TODO(schuyler): Just screwing around, remove this...
        MyPlexManager().RefreshResources()
    else if status = 401 then
        ' The user is specifically unauthorized, clear everything
        m.username = invalid
        m.email = invalid
        m.isSignedIn = false
        m.isPlexPass = false
        m.authToken = invalid
        m.features.Clear()

        Warn("User is unauthorized")

        m.SaveState()
    else
        ' Unexpected error, keep using whatever we read from the registry
        Warn("Unexpected response from plex.tv (" + tostr(status) + "), reusing sign in status of " + tostr(m.isSignedIn))
    end if

    Application().ClearInitializer("myplex")
    AppManager().ResetState()
end sub
