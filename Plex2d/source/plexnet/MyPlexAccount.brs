function MyPlexAccount()
    if m.MyPlexAccount = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Strings
        obj.id = invalid
        obj.title = invalid
        obj.username = invalid
        obj.email = invalid
        obj.authToken = invalid

        ' Booleans
        obj.isSignedIn = false
        obj.isOffline = false
        obj.isPlexPass = false
        obj.isEntitled = false
        obj.isRestricted = false
        obj.hasQueue = false
        ' TODO(rob): pinAuth
        ' obj.pinAuthenticated = false

        obj.homeUsers = createObject("roList")

        ' NOTE: We can't format an roList JSON, because... because. So if
        ' we decide that we want things like features or entitlements, we'll
        ' probably have to use roArray. We probably don't need to store those
        ' though.

        obj.SaveState = mpaSaveState
        obj.LoadState = mpaLoadState
        obj.SignOut = mpaSignOut
        obj.ValidateToken = mpaValidateToken
        obj.UpdateHomeUsers = mpaUpdateHomeUsers
        ' TODO(rob): Switch users
        ' obj.SwitchHomeUser = mpaSwitchHomeUser

        obj.OnAccountResponse = mpaOnAccountResponse

        m.MyPlexAccount = obj

        obj.LoadState()
    end if

    return m.MyPlexAccount
end function

sub mpaSaveState()
    obj = {
        id: m.id,
        title: m.title,
        username: m.username,
        email: m.email,
        authToken: m.authToken,
        pin: m.pin,
        isPlexPass: m.isPlexPass,
        isEntitled: m.isEntitled,
        isRestricted: m.isRestricted
        isAdmin: m.isAdmin
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
            m.id = obj.id
            m.title = obj.title
            m.username = obj.username
            m.email = obj.email
            m.authToken = obj.authToken
            m.pin = obj.pin
            m.isPlexPass = obj.isPlexPass
            m.isEntitled = obj.isEntitled
            m.isRestricted = obj.isRestricted
            m.isProtected = (obj.pin <> invalid)
            m.isAdmin = obj.isAdmin
        end if
    else
        ' TODO(rob): this is only for the transition from the official right?
        m.authToken = settings.GetPreference("AuthToken", invalid, "myplex")
        m.isPlexPass = (settings.GetPreference("IsPlexPass", "0", "misc") = "1")
    end if

    if m.authToken <> invalid then
        request = createMyPlexRequest("/users/account")
        context = request.CreateRequestContext("account", createCallable("OnAccountResponse", m))
        Application().StartRequest(request, context)
    else
        Application().ClearInitializer("myplex")
    end if
end sub

sub mpaOnAccountResponse(request as object, response as object, context as object)
    oldTitle = m.title

    if response.IsSuccess() then
        xml = response.GetBodyXml()

        ' The user is signed in
        m.id = xml@id
        m.title = xml@title
        m.username = xml@username
        m.email = xml@email
        m.authToken = xml@authenticationToken
        m.isSignedIn = true
        m.isPlexPass = (xml.subscription <> invalid and xml.subscription@active = "1")
        m.isRestricted = (xml@restricted = "1")
        m.hasQueue = (xml@queueEmail <> invalid and xml@queueEmail <> "" and xml@queueEmail <> invalid and xml@queueEmail <> "")

        ' PIN
        if xml@pin <> invalid and xml@pin <> "" then
            m.pin = xml@pin
        else
            m.pin = invalid
        end if
        m.isProtected = (m.pin <> invalid)

        ' Entitlement
        m.IsEntitled = false
        if xml.entitlements <> invalid then
            if tostr(xml.entitlements@all) = "1" then
                m.isEntitled = true
            else
                for each entitlement in xml.entitlements.GetChildElements()
                    if ucase(tostr(entitlement@id)) = "ROKU" then
                        m.isEntitled = true
                        exit for
                    end if
                end for
            end if
        end if

        ' update the list of users in the home
        m.UpdateHomeUsers()

        ' set admin attribute for the user
        ' TODO(rob): The only real use for this in the official channel is to display
        ' the logged in user is the admin (Plex2d hopefully gets a crown)
        m.isAdmin = false
        if m.homeUsers.count() > 0 then
            for each user in m.homeUsers
                if m.id = user.id then
                    m.isAdmin = (tostr(user.admin) = "1")
                    exit for
                end if
            end for
        end if

        Info("Authenticated as " + tostr(m.Id) + ":" + tostr(m.Title))
        Info("PlexPass: " + tostr(m.isPlexPass))
        Info("Entitlement: " + tostr(m.isEntitled))
        Info("Restricted: " + tostr(m.isRestricted))
        Info("Protected: " + tostr(m.isProtected))
        Info("Admin: " + tostr(m.isAdmin))

        m.SaveState()
        MyPlexManager().Publish()
        MyPlexManager().RefreshResources()
    else if response.GetStatus() = 401 then
        ' The user is specifically unauthorized, clear everything
        Warn("User is unauthorized")

        m.SignOut()
    else
        ' Unexpected error, keep using whatever we read from the registry
        Warn("Unexpected response from plex.tv (" + tostr(response.GetStatus()) + "), switching to offline mode")
        m.IsOffline = true
    end if

    Application().ClearInitializer("myplex")
    AppManager().ResetState()

    if oldTitle <> m.title then
        Application().Trigger("change:user", [m])
    end if
end sub

sub mpaSignOut()
    if not m.isSignedIn then return

    ' Strings
    m.id = invalid
    m.title = invalid
    m.username = invalid
    m.email = invalid
    m.authToken = invalid
    m.pin = invalid

    ' Booleans
    m.isSignedIn = false
    m.isPlexPass = false
    m.isEntitled = false
    m.isRestricted = false

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

sub mpaUpdateHomeUsers()
    ' ignore request and clear any home users we are not signed in
    if m.isSignedIn = false then
        m.homeUsers.clear()
        if m.isOffline then
            m.homeUsers.push(MyPlexManager())
        end if
        return
    end if

    req = createMyPlexRequest("/api/home/users")
    xml = CreateObject("roXMLElement")
    xml.Parse(req.GetToStringWithTimeout(10))
    if firstOf(xml@size, "0").toInt() and xml.user <> invalid then
        m.homeUsers.clear()
        for each user in xml.user
            m.homeUsers.push(user.GetAttributes())
        end for
    end if

    Info("home users: " + tostr(m.homeUsers.count()))
end sub
