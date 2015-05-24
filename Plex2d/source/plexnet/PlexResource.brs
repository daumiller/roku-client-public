function PlexResourceClass() as object
    if m.PlexResourceClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(PlexObjectClass())
        obj.ClassName = "PlexResource"

        m.PlexResourceClass = obj
    end if

    return m.PlexResourceClass
end function

function createPlexResource(container as object, xml as object) as object
    obj = CreateObject("roAssociativeArray")

    obj.Append(PlexResourceClass())

    obj.Init(container, xml)

    obj.connections = CreateObject("roList")
    for each conn in xml.Connection
        obj.connections.Push(createPlexConnection(PlexConnectionClass().SOURCE_MYPLEX, conn@uri, (conn@local = "1"), obj.Get("accessToken")))

        ' If the connection is one of our plex.direct secure connections, add
        ' the nonsecure variant as well.
        '
        if conn@protocol = "https" and instr(1, conn@uri, conn@address) = 0 then
            obj.connections.Push(createPlexConnection(PlexConnectionClass().SOURCE_MYPLEX, "http://" + conn@address + ":" + conn@port, (conn@local = "1"), obj.Get("accessToken")))
        end if
    next

    return obj
end function
