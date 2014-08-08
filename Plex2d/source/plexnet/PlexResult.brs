function PlexResultClass() as object
    if m.PlexResultClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(HttpResponseClass())
        obj.ClassName = "PlexResult"

        obj.container = invalid

        obj.SetResponse = pnrSetResponse
        obj.ParseResponse = pnrParseResponse

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

sub pnrSetResponse(event as object)
    m.event = event
end sub

sub pnrParseResponse()
    if m.IsSuccess() then
        xml = m.GetBodyXml()
        if xml <> invalid then
            m.container = createPlexContainer(m.server, m.address, xml)

            children = xml.GetChildElements()
            for each node in children
                item = createPlexObjectFromElement(m.container, node)
                m.items.Push(item)
            next
        end if
    end if
end sub
