function PlexAttributeCollectionClass()
    if m.PlexAttributeCollectionClass = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.name = invalid
        obj.attrs = invalid

        obj.Init = pnacInit
        obj.Has = pnacHas
        obj.Get = pnacGet
        obj.GetInt = pnacGetInt
        obj.GetBool = pnacGetBool
        obj.GetFirst = pnacGetFirst
        obj.Set = pnacSet
        obj.TryCopy = pnacTryCopy

        obj.AttributesMatch = pnacAttributesMatch

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

function pnacGetBool(attrName, defaultValue=false)
    value = m.Get(attrName)
    if value <> invalid then
        return (value = "1")
    else
        return defaultValue
    end if
end function

function pnacGetFirst(attrNames) as dynamic
    for each attr in attrNames
        if m.attrs[attr] <> invalid and m.attrs[attr] <> "" then return m.attrs[attr]
    end for

    return invalid
end function

sub pnacSet(attrName as string, attrValue as string)
    m.attrs[attrName] = attrValue
end sub

sub pnacTryCopy(other as object, attrName as string)
    if other.Has(attrName) and not m.Has(attrName) then
        m.Set(attrName, other.Get(attrName))
    end if
end sub

function pnacAttributesMatch(other as object, attributes as object) as boolean
    for each attr in attributes
        if (m.Has(attr) <> other.Has(attr)) then return false
        if (m.Get(attr) <> other.Get(attr)) then return false
    next

    return true
end function
