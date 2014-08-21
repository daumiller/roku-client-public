function PlexTagClass() as object
    if m.PlexTagClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(PlexAttributeCollectionClass())
        obj.ClassName = "PlexTag"

        m.PlexTagClass = obj
    end if

    return m.PlexTagClass
end function

function createPlexTag(xml as object) as object
    obj = CreateObject("roAssociativeArray")

    obj.Append(PlexTagClass())

    obj.Init(xml)

    return obj
end function
