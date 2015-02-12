function PlexContainerClass() as object
    if m.PlexContainerClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(PlexAttributeCollectionClass())
        obj.ClassName = "PlexContainer"

        obj.server = invalid
        obj.address = invalid

        obj.SetAddress = pncSetAddress
        obj.GetAbsolutePath = pncGetAbsolutePath

        m.PlexContainerClass = obj
    end if

    return m.PlexContainerClass
end function

function createPlexContainer(server as object, address as string, xml as object) as object
    obj = CreateObject("roAssociativeArray")

    obj.Append(PlexContainerClass())

    obj.Init(xml)
    obj.SetAddress(server, address)

    return obj
end function

' Hubs are a special case. If we have a PlexContainer that contains PlexHubs
' that in turn container actual PlexObjects, then we probably want those objects
' to consider the Hub their container, rather than whatever was requested. But
' we can't always make PlexHub a subclass of PlexContainer, since sometimes it's
' more like a PlexObject itself. So we allow a sort of synthetic PlexContainer
' to be created out of a PlexHub.
'
function createPlexHubContainer(container as object, hub as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(PlexContainerClass())

    obj.attrs = {}
    obj.attrs.Append(container.attrs)
    obj.attrs.Append(hub.attrs)

    obj.name = hub.name

    obj.SetAddress(container.server, obj.Get("key", container.address))

    return obj
end function

sub pncSetAddress(server as object, address as string)
    m.server = server

    if right(address, 1) = "/" then
        m.address = mid(address, 0, address.Len() - 1)
    else
        m.address = address
    end if

    ' TODO(schuyler): Do we need to make sure that we only hang onto the path here and not a full URL?
    if left(m.address, 1) <> "/" then
        Fatal("Container address is not an expected path")
    end if
end sub

function pncGetAbsolutePath(path as string) as string
    if left(path, 1) = "/" then
        return path
    else if instr(1, path, "://") > 0 then
        return path
    else
        return m.address + "/" + path
    end if
end function
