function PlexContainerClass() as object
    if m.PlexContainerClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(PlexAttributeCollectionClass())
        obj.Append(PlexContainerMixin())
        obj.ClassName = "PlexContainer"

        obj.server = invalid
        obj.address = invalid

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
