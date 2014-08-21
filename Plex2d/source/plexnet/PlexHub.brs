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

    obj.items = CreateObject("roList")

    children = xml.GetChildElements()
    if children <> invalid then
        for each elem in xml.GetChildElements()
            obj.items.Push(createPlexItem(container, elem))
        next
    end if

    return obj
end function

function pnhToString() as string
    return "Hub: " + m.Get("title", "") + " " + tostr(m.items.Count()) + " item(s) more: " + m.Get("more", "")
end function
