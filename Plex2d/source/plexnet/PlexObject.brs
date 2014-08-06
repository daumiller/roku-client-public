function PlexObjectClass()
    if m.PlexObjectClass = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.Append(PlexAttributeCollectionClass())

        obj.type = invalid

        obj.Init = pnoInit

        m.PlexObjectClass = obj
    end if

    return m.PlexObjectClass
end function

sub pnoInit(xml)
    ApplyFunc(PlexAttributeCollectionClass().Init, m, [xml])

    m.type = firstOf(m.Get("type"), LCase(m.name))
end sub
