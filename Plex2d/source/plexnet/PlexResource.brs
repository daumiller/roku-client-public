function PlexResourceClass()
    if m.PlexResourceClass = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.Append(PlexObjectClass())

        m.PlexResourceClass = obj
    end if

    return m.PlexResourceClass
end function

function createPlexResource(xml)
    obj = CreateObject("roAssociativeArray")

    obj.Append(PlexResourceClass())

    obj.Init(xml)

    return obj
end function
