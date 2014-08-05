function HttpRequestClass()
    if m.HttpRequestClass = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.StartAsync = httpStartAsync
        obj.GetToStringWithTimeout = httpGetToStringWithTimeout
        obj.GetIdentity = httpGetIdentity
        obj.Cancel = httpCancel

        m.HttpRequestClass = obj
    end if

    return m.HttpRequestClass
end function

function createHttpRequest(url, plexHeaders=true)
    obj = CreateObject("roAssociativeArray")

    obj.append(HttpRequestClass())
    obj.reset()

    obj.url = url

    ' Initialize the actual transfer object
    obj.request = CreateObject("roUrlTransfer")
    obj.request.SetUrl(url)
    obj.request.EnableEncodings(true)
    obj.request.SetCertificatesFile("common:/certs/ca-bundle.crt")

    if plexHeaders then AddPlexHeaders(obj.request)

    return obj
end function

function httpStartAsync(body=invalid, contentType=invalid)
    ' This is an async request, so make sure it's using the global message port
    m.request.SetPort(Application().port)

    if body = invalid then
        started = m.request.AsyncGetToString()
    else
        if contentType = invalid then
            m.request.AddHeader("Content-Type", "application/x-www-form-urlencoded")
        else
            m.request.AddHeader("Content-Type", MimeType(contentType))
        end if

        started = m.request.AsyncPostFromString(body)
    end if

    if not started then
        Error("Unable to start request to " + m.url)
    end if

    return started
end function

function httpGetToStringWithTimeout(seconds)
    timeout = 1000 * seconds

    response = ""
    m.request.EnableFreshConnection(true)

    ' This is a blocking request, so make sure it uses a unique message port
    port = CreateObject("roMessagePort")
    m.request.SetPort(port)

    if m.request.AsyncGetToString() then
        msg = wait(timeout, port)
        if type(msg) = "roUrlEvent" then
            m.responseCode = msg.GetResponseCode()
            m.failureReason = msg.GetFailureReason()
            response = msg.GetString()
        else if msg = invalid then
            Warn("Request to " + m.url + " timed out after " + tostr(seconds) + " seconds")
            m.request.AsyncCancel()
        else
            Error("AsyncGetToString unknown event: " + type(msg))
        end if
    else
        Error("Failed to start request to " + url)
    end if

    return response
end function

function httpGetIdentity()
    return m.request.GetIdentity().toStr()
end function

sub httpCancel()
    m.request.AsyncCancel()
end sub

' Helper functions that operate on ifHttpAgent objects

sub AddPlexHeaders(transferObj, token=invalid)
    settings = AppSettings()

    transferObj.AddHeader("X-Plex-Platform", "Roku")
    transferObj.AddHeader("X-Plex-Version", settings.GetGlobal("appVersionStr"))
    transferObj.AddHeader("X-Plex-Client-Identifier", settings.GetGlobal("clientIdentifier"))
    transferObj.AddHeader("X-Plex-Platform-Version", settings.GetGlobal("rokuVersionStr", "unknown"))
    transferObj.AddHeader("X-Plex-Product", "Plex for Roku")
    transferObj.AddHeader("X-Plex-Device", settings.GetGlobal("rokuModel"))
    transferObj.AddHeader("X-Plex-Device-Name", settings.GetPreference("player_name", settings.GetGlobal("rokuModel")))

    AddAccountHeaders(transferObj, token)
end sub

sub AddAccountHeaders(transferObj, token=invalid)
    if token <> invalid then
        transferObj.AddHeader("X-Plex-Token", token)
    end if

    ' TODO(schuyler): Add username?
end sub
