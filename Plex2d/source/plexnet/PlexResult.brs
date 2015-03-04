function PlexResultClass() as object
    if m.PlexResultClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(HttpResponseClass())
        obj.ClassName = "PlexResult"

        obj.container = invalid
        obj.parsed = invalid

        obj.SetResponse = pnrSetResponse
        obj.ParseResponse = pnrParseResponse
        obj.ParseFakeXMLResponse = pnrParseFakeXMLResponse

        m.PlexResultClass = obj
    end if

    return m.PlexResultClass
end function

function createPlexResult(server as object, address as string) as object
    obj = CreateObject("roAssociativeArray")

    obj.Append(PlexResultClass())

    obj.server = server
    obj.address = address
    obj.items = CreateObject("roList")

    return obj
end function

sub pnrSetResponse(event as dynamic)
    m.event = event
end sub

function pnrParseResponse() as boolean
    if m.parsed = true then return m.parsed
    m.parsed = false

    if m.IsSuccess() then
        xml = m.GetBodyXml()
        if xml <> invalid then
            m.container = createPlexContainer(m.server, m.address, xml)

            children = xml.GetChildElements()
            if children <> invalid then
                for each node in children
                    item = createPlexObjectFromElement(m.container, node)
                    m.items.Push(item)
                next
            end if

            m.parsed = true
        end if
    end if

    return m.parsed
end function

function pnrParseFakeXMLResponse(xml as object) as boolean
    if m.parsed = true then return m.parsed
    m.parsed = false

    if xml <> invalid then
        m.container = createPlexContainer(m.server, m.address, xml)

        children = xml.GetChildElements()
        for each node in children
            item = createPlexObjectFromElement(m.container, node)
            m.items.Push(item)
        next

        m.parsed = true
    end if

    return m.parsed
end function
