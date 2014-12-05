function PlexContainerClass() as object
    if m.PlexContainerClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(PlexAttributeCollectionClass())
        obj.ClassName = "PlexContainer"

        obj.server = invalid
        obj.address = invalid

        obj.GetAbsolutePath = pncGetAbsolutePath

        m.PlexContainerClass = obj
    end if

    return m.PlexContainerClass
end function

function createPlexContainer(server as object, address as string, xml as object) as object
    obj = CreateObject("roAssociativeArray")

    obj.Append(PlexContainerClass())

    obj.Init(xml)
    obj.server = server

    if right(address, 1) = "/" then
        obj.address = mid(address, 0, address.Len() - 1)
    else
        obj.address = address
    end if

    ' TODO(schuyler): Do we need to make sure that we only hang onto the path here and not a full URL?
    if left(obj.address, 1) <> "/" then
        Fatal("Container address is not an expected path")
    end if

    return obj
end function

function pncGetAbsolutePath(path as string) as string
    if left(path, 1) = "/" then
        return path
    else if instr(1, path, "://") > 0 then
        return path
    else
        return m.address + "/" + path
    end if
end function
