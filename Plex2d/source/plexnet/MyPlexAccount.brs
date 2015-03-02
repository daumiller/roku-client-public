function MyPlexAccount() as object
    if m.MyPlexAccount = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Strings
        obj.id = invalid
        obj.title = invalid
        obj.username = invalid
        obj.email = invalid
        obj.authToken = invalid

        ' Booleans
        obj.isAuthenticated = AppSettings().GetBoolPreference("auto_signin")
        obj.isSignedIn = false
        obj.isOffline = false
        obj.isExpired = false
        obj.isPlexPass = false
        obj.isEntitled = false
        obj.isManaged = false
        obj.hasQueue = false

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
        obj.SwitchHomeUser = mpaSwitchHomeUser

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
        isManaged: m.isManaged,
        isAdmin: m.isAdmin,
    }

    AppSettings().SetRegistry("MyPlexAccount", FormatJson(obj), "myplex")
end sub

sub mpaLoadState()
    ' Look for the new JSON serialization. If it's not there, look for the
    ' old token and Plex Pass values.

    Application().AddInitializer("myplex")
    settings = AppSettings()

    json = settings.GetRegistry("MyPlexAccount", invalid, "myplex")

    if json <> invalid then
        obj = ParseJson(json)
        if obj <> invalid then
            if obj.id <> invalid then m.id = obj.id
            if obj.title <> invalid then m.title = obj.title
            if obj.username <> invalid then m.username = obj.username
            if obj.email <> invalid then m.email = obj.email
            if obj.authToken <> invalid then m.authToken = obj.authToken
            if obj.pin <> invalid then m.pin = obj.pin
            if obj.isPlexPass <> invalid then m.isPlexPass = obj.isPlexPass
            if obj.isEntitled <> invalid then m.isEntitled = obj.isEntitled
            if obj.isManaged <> invalid then m.isManaged = obj.isManaged
            if obj.isAdmin <> invalid then m.isAdmin = obj.isAdmin
            m.isProtected = (obj.pin <> invalid)
        end if
    else
        ' TODO(rob): this is only for the transition from the official right?
        m.authToken = settings.GetRegistry("AuthToken", invalid, "myplex")
        m.isPlexPass = (settings.GetRegistry("IsPlexPass", "0") = "1")
    end if

    if m.authToken <> invalid then
        request = createMyPlexRequest("/users/account")
        context = request.CreateRequestContext("account", createCallable("OnAccountResponse", m))
        context.timeout = 10000
        Application().StartRequest(request, context)
    else
        Application().ClearInitializer("myplex")
    end if
end sub

sub mpaOnAccountResponse(request as object, response as object, context as object)
    oldId = m.id

    if response.IsSuccess() then
        xml = response.GetBodyXml()

        ' The user is signed in
        m.isSignedIn = true
        m.isOffline = false
        m.id = xml@id
        m.title = xml@title
        m.username = xml@username
        m.email = xml@email
        m.authToken = xml@authenticationToken
        m.isSignedIn = true
        m.isPlexPass = (xml.subscription <> invalid and xml.subscription@active = "1")
        m.isManaged = (xml@restricted = "1")
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
        m.isAdmin = false
        if m.homeUsers.count() > 0 then
            for each user in m.homeUsers
                if m.id = user.id then
                    m.isAdmin = (tostr(user.admin) = "1")
                    exit for
                end if
            end for
        end if

        ' consider a single, unprotected user authenticated
        if m.isAuthenticated = false and m.isProtected = false and m.homeUsers.Count() <= 1 then
            m.isAuthenticated = true
        end if

        Info("Authenticated as " + tostr(m.Id) + ":" + tostr(m.Title))
        Info("SignedIn: " + tostr(m.isSignedIn))
        Info("Offline: " + tostr(m.isOffline))
        Info("Authenticated: " + tostr(m.isAuthenticated))
        Info("PlexPass: " + tostr(m.isPlexPass))
        Info("Entitlement: " + tostr(m.isEntitled))
        Info("Managed: " + tostr(m.isManaged))
        Info("Protected: " + tostr(m.isProtected))
        Info("Admin: " + tostr(m.isAdmin))

        m.SaveState()
        MyPlexManager().Publish()
        MyPlexManager().RefreshResources()
        GDMDiscovery().Discover()
    else if response.GetStatus() >= 400 and response.GetStatus() < 500 then
        ' The user is specifically unauthorized, clear everything
        Warn("Sign Out: User is unauthorized")
        m.SignOut(true)
    else
        ' Unexpected error, keep using whatever we read from the registry
        Warn("Unexpected response from plex.tv (" + tostr(response.GetStatus()) + "), switching to offline mode")
        m.isOffline = true
        ' consider a single, unprotected user authenticated
        if m.isAuthenticated = false and m.isProtected = false then
            m.isAuthenticated = true
        end if
    end if

    Application().ClearInitializer("myplex")
    AppManager().ResetState()
    Logger().UpdateSyslogHeader()

    if oldId <> m.id or m.switchUser = true then
        m.switchUser = invalid
        Application().Trigger("change:user", [m, (oldId <> m.id)])
    end if
end sub

sub mpaSignOut(expired=false as boolean)
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
    m.isManaged = false
    m.isExpired = expired

    Application().Trigger("change:user", [m, true])

    m.SaveState()
end sub

sub mpaValidateToken(token as string, switchUser=false as boolean)
    m.authToken = token
    m.switchUser = switchUser

    request = createMyPlexRequest("/users/sign_in.xml")
    context = request.CreateRequestContext("sign_in", createCallable("OnAccountResponse", m))
    context.timeout = iif(m.isOffline, 1000, 10000)
    Application().StartRequest(request, context, "")
end sub

sub mpaUpdateHomeUsers()
    ' ignore request and clear any home users we are not signed in
    if m.isSignedIn = false then
        m.homeUsers.clear()
        if m.isOffline then
            m.homeUsers.push(MyPlexAccount())
        end if
        return
    end if

    req = createMyPlexRequest("/api/home/users")
    xml = CreateObject("roXMLElement")
    xml.Parse(req.GetToStringWithTimeout(10))
    if firstOf(xml@size, "0").toInt() and xml.user <> invalid then
        m.homeUsers.clear()
        for each user in xml.user
            ' Roku doesn't handle 302 (on firmware < 6.1) so we'll have to resolve the redirect manually.
            ' TODO(rob): we should cache this and only update on change or when stale.
            if user@thumb <> invalid and not CheckMinimumVersion([6, 1]) and instr(1, user@thumb, "http://www.gravatar.com") > 0 then
                user.AddAttribute("thumb", ResolveRedirect(user@thumb))
            end if
            ' update the current users avatar (after ResolveRedirect)
            if m.id = user@id then m.thumb = user@thumb
            homeUser = user.GetAttributes()
            homeUser.isAdmin = (homeUser.admin = "1")
            homeUser.isManaged = (homeUser.restricted = "1")
            homeUser.isProtected = (homeUser.protected = "1")
            m.homeUsers.Push(homeUser)
        end for
    end if

    Info("home users: " + tostr(m.homeUsers.count()))
end sub

function mpaSwitchHomeUser(userId as string, pin="" as dynamic) as boolean
    if userId = m.id and m.isAuthenticated = true then return true

    ' Offline support
    if m.IsOffline then
        if m.isProtected = false or MyPlexAccount().isAuthenticated or createDigest(pin + m.AuthToken, "sha256") = firstOf(m.pin, "") then
            Debug("Offline access granted")
            m.isAuthenticated = true
            m.ValidateToken(m.AuthToken, true)
            return true
        end if
    else
        ' build path and post to myplex to swith the user
        path = "/api/home/users/" + userid + "/switch"
        req = createMyPlexRequest(path)
        xml = CreateObject("roXMLElement")
        xml.Parse(req.PostToStringWithTimeout("pin=" + pin, 10))

        if xml@authenticationToken <> invalid then
            m.isAuthenticated = true
            ' validate the token (trigger change:user) on user change or channel startup
            if userId <> m.id or not GetGlobalAA()["screenIsLocked"] = true then
                m.ValidateToken(xml@authenticationToken, true)
            end if
            return true
        end if
    end if

    return false
end function
