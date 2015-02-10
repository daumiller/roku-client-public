function PlexHubClass() as object
    if m.PlexHubClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(PlexObjectClass())
        obj.Append(PlexContainerMixin())
        obj.ClassName = "PlexHub"

        obj.ToString = pnhToString
        obj.IsContinuous = pnhIsContinuous

        ' TODO(schuyler): This is all a bit suspect right now, but I'm waiting
        ' for clarification.
        obj.CONTINUOUS_IDENTIFIERS = {}
        obj.CONTINUOUS_IDENTIFIERS["home.continue"] = true
        obj.CONTINUOUS_IDENTIFIERS["home.ondeck"] = true
        obj.CONTINUOUS_IDENTIFIERS["home.television.recent"] = true
        obj.CONTINUOUS_IDENTIFIERS["tv.recentlyaired"] = true

        obj.CONTINUOUS_TYPES = {}
        obj.CONTINUOUS_TYPES["episode"] = true
        obj.CONTINUOUS_TYPES["mixed"] = true

        m.PlexHubClass = obj
    end if

    return m.PlexHubClass
end function

function createPlexHub(container as object, xml as object) as object
    obj = CreateObject("roAssociativeArray")

    obj.Append(PlexHubClass())

    obj.Init(container, xml)
    obj.SetAddress(container.server, obj.Get("key", container.address))

    obj.items = CreateObject("roList")

    children = xml.GetChildElements()
    if children <> invalid then
        for each elem in xml.GetChildElements()
            obj.items.Push(createPlexItem(obj, elem))
        next
    end if

    return obj
end function

function pnhIsContinuous() as boolean
    ' The On Deck and Recently Added hubs are continuous.
    return (m.CONTINUOUS_IDENTIFIERS.DoesExist(m.Get("hubIdentifier", "")) and m.CONTINUOUS_TYPES.DoesExist(m.Get("type", "")))
end function

function pnhToString() as string
    return "Hub: " + m.Get("title", "") + " " + tostr(m.items.Count()) + " item(s) more: " + m.Get("more", "")
end function
