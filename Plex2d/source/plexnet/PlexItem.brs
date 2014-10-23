function PlexItemClass() as object
    if m.PlexItemClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(PlexObjectClass())
        obj.ClassName = "PlexItem"

        obj.isMediaSynthesized = false

        obj.IsAccessible = pniIsAccessible
        obj.GetLimitedTagValues = pniGetLimitedTagValues
        obj.GetSeasonString = pniGetSeasonString
        obj.GetEpisodeString = pniGetEpisodeString
        obj.getMediaFlagTranscodeURL = pniGetMediaFlagTranscodeURL

        m.PlexItemClass = obj
    end if

    return m.PlexItemClass
end function

function createPlexItem(container as object, xml as object) as object
    obj = CreateObject("roAssociativeArray")

    obj.Append(PlexItemClass())

    obj.Init(container, xml)

    obj.mediaItems = CreateObject("roList")
    obj.tags = CreateObject("roAssociativeArray")

    for each elem in xml.GetChildElements()
        if elem.GetName() = "Media" then
            obj.mediaItems.Push(createPlexMedia(container, elem))
        else
            ' Assume everything else is a tag
            if not obj.tags.DoesExist(elem.GetName()) then
                obj.tags[elem.GetName()] = CreateObject("roList")
            end if

            obj.tags[elem.GetName()].Push(createPlexTag(elem))
        end if
    next

    ' Normalize some old XML
    if obj.type = "track" then
        if obj.Has("artist") then
            obj.Set("grandparentTitle", obj.Get("artist"))
        end if

        if obj.Has("album") then
            obj.Set("parentTitle", obj.Get("album"))
        end if

        if obj.Has("track") then
            obj.Set("title", obj.Get("track"))
        end if

        if obj.Has("totalTime") then
            obj.Set("duration", obj.Get("totalTime"))
        end if
    end if

    ' Synthesize media and do further iTunes normalization if necessary
    if obj.mediaItems.Count() = 0 and (obj.type = "track" or obj.type = "video" or obj.type = "photo") then
        obj.isMediaSynthesized = true

        synthesizedMedia = createPlexMedia(container, invalid)
        synthesizedPart = createPlexPart(container, invalid)

        synthesizedPart.Set("key", obj.Get("key"))
        synthesizedMedia.parts.Push(synthesizedPart)

        obj.mediaItems.Push(synthesizedMedia)

        if obj.isITunes() and (obj.type = "track" or obj.type = "video") then
            ' Try to guess the container/codec from the file extension on the key
            extension = obj.Get("key", "").Tokenize(".").Peek()
            derivedContainer = invalid
            derivedAudioCodec = invalid
            derivedVideoCodec = invalid

            if extension = "mp3" then
                derivedContainer = "mp3"
                derivedAudioCodec = "mp3"
            else if extension = "m4a" or extension = "m4b" then
                ' This could easily be aac or alac. We're only interested in aac,
                ' and we can make a decent guess based on the bitrate.
                size = val(obj.Get("size", "0"))
                totalTime = val(obj.Get("totalTime", "0"))
                if size > 0 and totalTime > 0 and (size / totalTime <= 75) then
                    drivedContainer = "mp4"
                    derivedAudioCodec = "aac"
                end if
            else if extension = "mp4" then
                derivedContainer = "mp4"
                derivedAudioCodec = "aac"
                derivedVideoCodec = "h264"
            end if

            if derivedContainer <> invalid then
                synthesizedMedia.Set("container", derivedContainer)
                synthesizedPart.Set("container", derivedContainer)
            end if

            if derivedAudioCodec <> invalid then
                synthesizedMedia.Set("audioCodec", derivedAudioCodec)
                synthesizedPart.Set("audioCodec", derivedAudioCodec)
            end if

            if derivedVideoCodec <> invalid then
                synthesizedMedia.Set("videoCodec", derivedVideoCodec)
                synthesizedPart.Set("videoCodec", derivedVideoCodec)
            end if
        end if
    end if

    ' Yet more iTunes fixups for things that aren't actually media
    if obj.isItunes() then
        if obj.type = "album" then
            obj.Set("title", obj.Get("album"))
            obj.Set("grandparentTitle", obj.Get("artist"))
            obj.Set("parentTitle", obj.Get("artist"))
        else if obj.type = "artist" then
            obj.Set("title", obj.Get("artist"))
        end if
    end if

    ' Copy some attributes from the container to the item
    obj.TryCopy(container, "grandparentContentRating")
    obj.TryCopy(container, "grandparentTitle")
    obj.TryCopy(container, "parentTitle")
    obj.TryCopy(container, "thumb")
    obj.TryCopy(container, "art")

    if container.Has("theme")
        obj.Set("parentTheme", container.Get("theme"))
    end if

    if container.Has("banner") and obj.type = "season" then
        obj.Set("parentBanner", container.Get("banner"))
    end if

    return obj
end function

function pniIsAccessible() as boolean
    if not m.IsLibraryItem() then return true

    for each item in m.mediaItems
        ' As long as we have one accessible item, we're accessible
        if item.IsAccessible() then return true
    next

    ' If we have no media items, consider ourselves accessible
    return (m.mediaItems.Count() = 0)
end function

function pniGetLimitedTagValues(tagClass as string, limit as integer, sep=", " as string) as string
    result = ""
    numFound = 0
    tags = m.tags[tagClass]

    if tags <> invalid then
        for each tag in tags
            if numFound > 0 then
                result = result + sep
            end if

            result = result + tag.Get("tag")
            numFound = numFound + 1
            if numFound >= limit then exit for
        next
    end if

    return result
end function

function pniGetSeasonString() as string
    value = firstOf(m.Get("parentIndex"), m.Get("year"))

    if value <> invalid then
        return "Season " + value
    else
        return ""
    end if
end function

function pniGetEpisodeString() as string
    if m.Has("index") then
        return "E" + Right("0" + m.Get("index"), 2)
    else
        return ""
    end if
end function

' TODO(schuyler): Everything to do with resolutions, media choices, transcoding, and playback URLs
' TODO(schuyler): getMediaFlagTranscodeURL

function pniGetMediaFlagTranscodeURL(flag as string, width as integer, height as integer) as dynamic
    flagValue = invalid
    if m.Has(flag) then
        flagValue = m.Get(flag)
    else if (m.mediaitems <> invalid and m.mediaitems.count() > 0 and m.mediaitems[0].Has(flag)) then
        flagValue = m.mediaitems[0].Get(flag)
    end if

    if flagValue = invalid then return invalid

    params = "&width=" + tostr(width) + "&height=" + tostr(height)
    url = m.container.get("mediaTagPrefix") + flag + "/" + flagValue + "?t=" + m.container.get("mediaTagVersion")

    ' TODO(rob): determine the local port, not sure about this one. I believe it may have to deal with the fact
    ' other clients may also be a server, which the Roku is not.
    server = m.container.server
    port = "32400"

    return server.BuildUrl("/photo/:/transcode?url=http%3A%2F%2F127.0.0.1:" + port + UrlEscape(url) + params)
end function
