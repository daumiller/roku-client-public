function HttpResponseClass() as object
    if m.HttpResponseClass = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.IsSuccess = httpIsSuccess
        obj.IsError = httpIsError
        obj.GetStatus = httpGetStatus
        obj.GetBodyString = httpGetBodyString
        obj.GetBodyXml = httpGetBodyXml

        m.HttpResponseClass = obj
    end if

    return m.HttpResponseClass
end function

function createHttpResponse(event as object) as object
    obj = CreateObject("roAssociativeArray")

    obj.Append(HttpResponseClass())

    obj.event = event

    return obj
end function

function httpIsSuccess() as boolean
    return (m.event.GetResponseCode() >= 200 and m.event.GetResponseCode() < 300)
end function

function httpIsError() as boolean
    return (not m.IsSuccess())
end function

function httpGetStatus() as integer
    return m.event.GetResponseCode()
end function

function httpGetBodyString() as string
    return m.event.GetString()
end function

function httpGetBodyXml() as dynamic
    xml = CreateObject("roXMLElement")
    if xml.Parse(m.event.GetString()) then
        return xml
    else
        return invalid
    end if
end function
