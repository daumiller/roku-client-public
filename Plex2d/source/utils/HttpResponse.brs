function HttpResponseClass() as object
    if m.HttpResponseClass = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.event = invalid

        obj.IsSuccess = httpIsSuccess
        obj.IsError = httpIsError
        obj.GetStatus = httpGetStatus
        obj.GetBodyString = httpGetBodyString
        obj.GetBodyXml = httpGetBodyXml
        obj.GetResponseHeader = httpGetResponseHeader

        m.HttpResponseClass = obj
    end if

    return m.HttpResponseClass
end function

function createHttpResponse(event as dynamic) as object
    obj = CreateObject("roAssociativeArray")

    obj.Append(HttpResponseClass())

    obj.event = event

    return obj
end function

function httpIsSuccess() as boolean
    if m.event <> invalid then
        return (m.event.GetResponseCode() >= 200 and m.event.GetResponseCode() < 300)
    else
        return false
    end if
end function

function httpIsError() as boolean
    return (not m.IsSuccess())
end function

function httpGetStatus() as integer
    if m.event <> invalid then
        return m.event.GetResponseCode()
    else
        return 0
    end if
end function

function httpGetBodyString() as string
    if m.event <> invalid then
        return m.event.GetString()
    else
        return ""
    end if
end function

function httpGetBodyXml() as dynamic
    xml = CreateObject("roXMLElement")
    if xml.Parse(m.event.GetString()) then
        return xml
    else
        return invalid
    end if
end function

function httpGetResponseHeader(name as string) as dynamic
    return m.event.GetResponseHeaders()[name]
end function
