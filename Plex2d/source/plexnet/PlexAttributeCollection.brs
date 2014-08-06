function PlexAttributeCollectionClass()
    if m.PlexAttributeCollectionClass = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.name = invalid
        obj.attrs = invalid

        obj.Init = pnacInit
        obj.Has = pnacHas
        obj.Get = pnacGet
        obj.GetInt = pnacGetInt

        ' Note: The "real" PlexNet version has quite a bit more, especially
        ' around setting attributes and emitting XML. We'll only implement
        ' that if we find that we need it.

        m.PlexAttributeCollectionClass = obj
    end if

    return m.PlexAttributeCollectionClass
end function

' This is an abstract class, no need for createPlexAttributeCollection

sub pnacInit(xml)
    ' TODO(schuyler): Is there any value in something more complicated than
    ' this? Like whitelisted keys? This is almost too easy.

    m.name = xml.GetName()
    m.attrs = xml.GetAttributes()
end sub

function pnacHas(attrName)
    return m.attrs.DoesExist(attrName)
end function

function pnacGet(attrName, defaultValue=invalid)
    return firstOf(m.attrs[attrName], defaultValue)
end function

function pnacGetInt(attrName, defaultValue=0)
    value = m.Get(attrName)
    if value <> invalid then
        return value.toInt()
    else
        return defaultValue
    end if
end function
