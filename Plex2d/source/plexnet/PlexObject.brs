function PlexObjectClass() as object
    if m.PlexObjectClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.ClassName = "PlexObject"

        obj.Append(PlexAttributeCollectionClass())

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
