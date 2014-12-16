function PlexPartClass() as object
    if m.PlexPartClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(PlexObjectClass())
        obj.ClassName = "PlexPart"

        obj.GetAddress = pnpGetAddress
        obj.IsAccessible = pnpIsAccessible
        obj.GetStreamsOfType = pnpGetStreamsOfType
        obj.GetSelectedStreamOfType = pnpGetSelectedStreamOfType
        obj.IsIndexed = pnpIsIndexed
        obj.GetIndexUrl = pnpGetIndexUrl
        obj.HasStreams = pnpHasStreams

        obj.ToString = pnpToString
        obj.Equals = pnpEquals

        m.PlexPartClass = obj
    end if

    return m.PlexPartClass
end function

function createPlexPart(container as object, xml as dynamic) as object
    obj = CreateObject("roAssociativeArray")

    obj.Append(PlexPartClass())

    obj.streams = CreateObject("roList")

    ' If we weren't given any XML, this is a synthetic part
    if xml <> invalid then
        obj.Init(container, xml)

        for each stream in xml.Stream
            obj.streams.Push(createPlexStream(stream))
        next

        if obj.Has("indexes") then
            obj.indexes = CreateObject("roAssociativeArray")
            indexKeys = obj.Get("indexes", "").Tokenize(",")
            for each indexKey in indexKeys
                obj.indexes[indexKey] = true
            next
        end if
    else
        obj.InitSynthetic(container, "Part")
    end if

    return obj
end function

function pnpGetAddress() as string
    address = firstOf(m.Get("key", ""))

    if address <> "" then
        ' TODO(schuyler): Do we need to add a token? Or will it be taken care of via header elsewhere?
        address = m.container.GetAbsolutePath(address)
    end if

    return address
end function

function pnpIsAccessible() as boolean
    ' If we haven't fetched accessibility info, assume it's accessible.
    return (not m.Has("accessible")) or (m.Get("accessible") = "1")
end function

function pnpGetStreamsOfType(streamType as integer) as object
    streams = CreateObject("roList")

    foundSelected = false

    for each stream in m.streams
        if stream.GetInt("streamType") = streamType then
            streams.Push(stream)

            if stream.IsSelected() then foundSelected = true
        end if
    next

    ' If this is subtitles, add the none option
    if streamType = PlexStreamClass().TYPE_SUBTITLE then
        none = NoneStream()
        streams.AddHead(none)
        ' none.SetSelected(not foundSelected)
    end if

    return streams
end function

function pnpGetSelectedStreamOfType(streamType as integer) as dynamic
    ' Video streams, in particular, may not be selected. Pretend like the
    ' first one was selected.
    '
    default = invalid

    for each stream in m.streams
        if stream.GetInt("streamType") = streamType then
            if stream.IsSelected() then
                return stream
            else if default = invalid and streamType <> stream.TYPE_SUBTITLE then
                default = stream
            end if
        end if
    next

    return default
end function

function pnpIsIndexed() as boolean
    return m.Has("indexes")
end function

function pnpGetIndexUrl(indexKey as string) as dynamic
    if m.indexes <> invalid and m.indexes.DoesExist(indexKey) then
        return m.container.server.BuildUrl("/library/parts/" + m.Get("id") + "/indexes/" + indexKey + "?interval=10000", true)
    else
        return invalid
    end if
end function

function pnpHasStreams() as boolean
    return (m.streams.Count() > 0)
end function

function pnpToString() as string
    return "Part " + m.Get("id", "NaN") + " " + m.Get("key", "")
end function

function pnpEquals(other as dynamic) as boolean
    if other = invalid then return false
    if m.ClassName <> other.ClassName then return false
    return (m.Get("id") = other.Get("id"))
end function

' TODO(schuyler): getStreams, getIndexThumbUrl
