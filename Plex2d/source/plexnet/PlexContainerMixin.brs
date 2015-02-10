function PlexContainerMixin() as object
    if m.PlexContainerMixin = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.SetAddress = pncmSetAddress
        obj.GetAbsolutePath = pncmGetAbsolutePath
        obj.GetHubIdentifier = pncmGetHubIdentifier
        obj.IsContinuous = pncmIsContinuous

        m.PlexContainerMixin = obj
    end if

    return m.PlexContainerMixin
end function

sub pncmSetAddress(server as object, address as string)
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

function pncmGetAbsolutePath(path as string) as string
    if left(path, 1) = "/" then
        return path
    else if instr(1, path, "://") > 0 then
        return path
    else
        return m.address + "/" + path
    end if
end function

function pncmGetHubIdentifier() as dynamic
    ' Only relevant for containers that are also hubs, but we can safely
    ' just look for the attribute and let it return invalid if we don't
    ' have it.

    return m.Get("hubIdentifier")
end function

function pncmIsContinuous() as boolean
    ' Only relevant for containers that are also hubs, leave the implementation
    ' up to them.

    return false
end function
