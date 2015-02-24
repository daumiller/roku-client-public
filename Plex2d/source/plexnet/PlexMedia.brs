function PlexMediaClass() as object
    if m.PlexMediaClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(PlexObjectClass())
        obj.ClassName = "PlexMedia"

        obj.HasStreams = pnmHasStreams
        obj.IsIndirect = pnmIsIndirect
        obj.IsAccessible = pnmIsAccessible
        obj.IsAvailable= pnmIsAvailable
        obj.GetVideoResolution = pnmGetVideoResolution
        obj.IsSelected = pnmIsSelected

        obj.ResolveIndirect = pnmResolveIndirect

        obj.ToString = pnmToString
        obj.Equals = pnmEquals

        m.PlexMediaClass = obj
    end if

    return m.PlexMediaClass
end function

function createPlexMedia(container as object, xml as dynamic) as object
    obj = CreateObject("roAssociativeArray")

    obj.Append(PlexMediaClass())

    obj.parts = CreateObject("roList")

    ' If we weren't given any XML, this is a synthetic media
    if xml <> invalid then
        obj.Init(container, xml)

        for each part in xml.Part
            obj.parts.Push(createPlexPart(container, part))
        next
    else
        obj.InitSynthetic(container, "Media")
    end if

    return obj
end function

function pnmHasStreams() as boolean
    return (m.parts.Count() > 0 and m.parts[0].HasStreams())
end function

function pnmIsIndirect() as boolean
    return (m.Get("indirect") = "1")
end function

function pnmIsAccessible() as boolean
    for each part in m.parts
        if not part.IsAccessible() then return false
    next

    return true
end function

function pnmIsAvailable() as boolean
    for each part in m.parts
        if not part.IsAvailable() then return false
    next

    return true
end function

function pnmResolveIndirect() as object
    if not m.IsIndirect() then return m

    ' TODO(schuyler): Actually resolve the indirect
    Fatal("Indirect resolution isn't supported yet")
end function

function pnmToString() as string
    resolution = UCase(m.Get("videoResolution", ""))

    if resolution = "" or resolution = "SD" then
        return resolution
    else
        return resolution + "p"
    end if
end function

function pnmEquals(other as dynamic) as boolean
    if other = invalid then return false
    if m.ClassName <> other.ClassName then return false
    return (m.Get("id") = other.Get("id"))
end function

function pnmGetVideoResolution() as integer
    videoResolution = m.Get("videoResolution")
    if videoResolution <> invalid then
        StandardDefinitionHeight = 480
        if(ucase(videoResolution) = "SD") then
            return iif(m.GetInt("height") > StandardDefinitionHeight, m.GetInt("height"), StandardDefinitionHeight)
        else
            return m.GetInt("videoResolution", StandardDefinitionHeight)
        end if
    end if

    return m.GetInt("height")
end function

function pnmIsSelected() as boolean
    return (m.selected = true or m.Get("id") = AppSettings().GetPreference("local_mediaId"))
end function

' TODO(schuyler): getParts
