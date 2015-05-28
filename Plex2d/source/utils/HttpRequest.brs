function HttpRequestClass() as object
    if m.HttpRequestClass = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.StartAsync = httpStartAsync
        obj.GetToStringWithTimeout = httpGetToStringWithTimeout
        obj.PostToStringWithTimeout = httpPostToStringWithTimeout
        obj.GetIdentity = httpGetIdentity
        obj.GetUrl = httpGetUrl
        obj.Cancel = httpCancel
        obj.AddParam = httpAddParam
        obj.AddHeader = httpAddHeader
        obj.CreateRequestContext = httpCreateRequestContext
        obj.OnResponse = httpOnResponse

        m.HttpRequestClass = obj
    end if

    return m.HttpRequestClass
end function

function createHttpRequest(url as string, method=invalid as dynamic) as object
    obj = CreateObject("roAssociativeArray")

    obj.append(HttpRequestClass())
    obj.reset()

    obj.hasParams = (Instr(1, url, "?") > 0)

    ' Initialize the actual transfer object
    obj.request = CreateObject("roUrlTransfer")

    ' Change the request method if requested
    if method <> invalid then obj.request.setRequest(method)

    ' the roku does not allow ">" || "<"  in the string during setUrl()
    if instr(1, url, ">") > 0 then
        r_gt = CreateObject("roRegex", ">", "" )
        url = r_gt.replaceAll(url, obj.request.escape(">"))
    end if
    if instr(1, url, "<") > 0 then
        r_lt = CreateObject("roRegex", "<", "" )
        url = r_lt.replaceAll(url, obj.request.escape("<"))
    end if
    obj.url = url

    obj.request.SetUrl(url)
    obj.request.EnableEncodings(true)

    ' Use our specific plex.direct CA cert if applicable to improve performance
    if left(url, 5) = "https" then
        if url.instr("plex.direct") > -1 then
            obj.request.SetCertificatesFile("pkg:/certs/plex-bundle.crt")
        else
            obj.request.SetCertificatesFile("common:/certs/ca-bundle.crt")
        end if
    end if

    return obj
end function

function httpStartAsync(body=invalid as dynamic, contentType=invalid as dynamic) as boolean
    ' This is an async request, so make sure it's using the global message port
    m.request.SetPort(Application().port)

    if body = invalid then
        Info("Starting request: GET " + m.request.GetUrl())
        started = m.request.AsyncGetToString()
    else
        if contentType = invalid then
            m.request.AddHeader("Content-Type", "application/x-www-form-urlencoded")
        else
            m.request.AddHeader("Content-Type", MimeType(contentType))
        end if

        Info("Starting request: POST " + m.request.GetUrl())
        started = m.request.AsyncPostFromString(body)
    end if

    if not started then
        Error("Unable to start request to " + m.url)
    end if

    return started
end function

function httpGetToStringWithTimeout(seconds as integer) as string
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


function httpPostToStringWithTimeout(body="" as string, seconds=10 as integer) as string
    timeout = 1000 * seconds

    response = ""
    m.request.EnableFreshConnection(true)

    ' This is a blocking request, so make sure it uses a unique message port
    port = CreateObject("roMessagePort")
    m.request.SetPort(port)

    if m.request.AsyncPostFromString(body) then
        msg = wait(timeout, port)
        if type(msg) = "roUrlEvent" then
            m.responseCode = msg.GetResponseCode()
            m.failureReason = msg.GetFailureReason()
            response = msg.GetString()
        else if msg = invalid then
            Warn("Request to " + m.url + " timed out after " + tostr(seconds) + " seconds")
            m.request.AsyncCancel()
        else
            Error("AsyncPostFromString unknown event: " + type(msg))
        end if
    else
        Error("Failed to start request to " + url)
    end if

    return response
end function

function httpGetIdentity() as string
    return m.request.GetIdentity().toStr()
end function

function httpGetUrl() as string
    return m.request.GetUrl()
end function

sub httpCancel()
    m.request.AsyncCancel()
end sub

sub httpAddParam(encodedName as string, value as string)
    if m.hasParams then
        m.url = m.url + "&" + encodedName + "=" + UrlEscape(value)
    else
        m.hasParams = true
        m.url = m.url + "?" + encodedName + "=" + UrlEscape(value)
    end if

    m.request.SetUrl(m.url)
end sub

sub httpAddHeader(name as string, value as string)
    m.request.AddHeader(name, value)
end sub

function httpCreateRequestContext(requestType as string, callback=invalid as dynamic) as object
    obj = CreateObject("roAssociativeArray")
    obj.requestType = requestType

    if callback <> invalid then
        obj.callback = createCallable(m.OnResponse, m)
        obj.completionCallback = callback
        obj.callbackCtx = callback.context
    end if

    return obj
end function

sub httpOnResponse(event as object, context as object)
    if context.completionCallback <> invalid then
        response = createHttpResponse(event)
        context.completionCallback.Call([m, response, context])
    end if
end sub

function ResolveRedirect(url as string) as string
    http = CreateObject("roUrlTransfer")
    http.SetUrl(url)
    headers = http.Head().GetResponseHeaders()

    if headers.location <> invalid and headers.location <> url then
        return headers.location
    end if

    return url
end function

function AddUrlParam(url as string, param as string) as string
    return url + iif(instr(1, url, "?") = 0, "?", "&") + param
end function
