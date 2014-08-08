function PlexObjectClass() as object
    if m.PlexObjectClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(PlexAttributeCollectionClass())
        obj.ClassName = "PlexObject"

        obj.type = invalid
        obj.container = invalid

        obj.Init = pnoInit

        m.PlexObjectClass = obj
    end if

    return m.PlexObjectClass
end function

sub pnoInit(container as object, xml as object)
    ApplyFunc(PlexAttributeCollectionClass().Init, m, [xml])

    m.type = firstOf(m.Get("type"), LCase(m.name))
    m.container = container
end sub

function createPlexObjectFromElement(container as object, xml as object) as object
    if xml.GetName() = "Device" then
        return createPlexResource(container, xml)
    end if

    Error("Don't know how to create PlexObject for " + xml.GetName())
    stop
end function
