function PlexHubClass() as object
    if m.PlexHubClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(PlexObjectClass())
        obj.ClassName = "PlexHub"

        obj.ToString = pnhToString

        m.PlexHubClass = obj
    end if

    return m.PlexHubClass
end function

function createPlexHub(container as object, xml as object) as object
    obj = CreateObject("roAssociativeArray")

    obj.Append(PlexHubClass())

    obj.Init(container, xml)

    ' TODO(rob): chat with Elan about adding the type for all photo hubs. This
    ' was initially set to only fix the "photo.recent" hub, but I don't see any
    ' harm in adding the type to all photo hubs.
    '
    if obj.Get("type") = "photo" then
        obj.Set("key", AddUrlParam(obj.Get("key"), "type=13"))
    end if

    obj.items = CreateObject("roList")

    children = xml.GetChildElements()
    if children <> invalid then
        syntheticContainer = createPlexHubContainer(container, obj)

        for each elem in children
            obj.items.Push(createPlexItem(syntheticContainer, elem))
        next
    end if

    return obj
end function

function pnhToString() as string
    return "Hub: " + m.Get("title", "") + " " + tostr(m.items.Count()) + " item(s) more: " + m.Get("more", "")
end function
