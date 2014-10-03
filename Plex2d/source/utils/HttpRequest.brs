function HttpRequestClass() as object
    if m.HttpRequestClass = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.StartAsync = httpStartAsync
        obj.GetToStringWithTimeout = httpGetToStringWithTimeout
        obj.GetIdentity = httpGetIdentity
        obj.Cancel = httpCancel
        obj.AddParam = httpAddParam
        obj.AddHeader = httpAddHeader
        obj.CreateRequestContext = httpCreateRequestContext
        obj.OnResponse = httpOnResponse

        m.HttpRequestClass = obj
    end if

    return m.HttpRequestClass
end function

function createHttpRequest(url as string) as object
    obj = CreateObject("roAssociativeArray")

    obj.append(HttpRequestClass())
    obj.reset()

    obj.url = url
    obj.hasParams = (Instr(1, url, "?") > 0)

    ' Initialize the actual transfer object
    obj.request = CreateObject("roUrlTransfer")
    obj.request.SetUrl(url)
    obj.request.EnableEncodings(true)
    obj.request.SetCertificatesFile("common:/certs/ca-bundle.crt")

    return obj
end function

function httpStartAsync(body=invalid as dynamic, contentType=invalid as dynamic) as boolean
    ' This is an async request, so make sure it's using the global message port
    m.request.SetPort(Application().port)

    if body = invalid then
        Debug("Starting request: GET " + m.request.GetUrl())
        started = m.request.AsyncGetToString()
    else
        if contentType = invalid then
            m.request.AddHeader("Content-Type", "application/x-www-form-urlencoded")
        else
            m.request.AddHeader("Content-Type", MimeType(contentType))
        end if

        Debug("Starting request: POST " + m.request.GetUrl())
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

function httpGetIdentity() as string
    return m.request.GetIdentity().toStr()
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
