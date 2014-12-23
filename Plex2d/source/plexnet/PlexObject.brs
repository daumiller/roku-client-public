function PlexObjectClass() as object
    if m.PlexObjectClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(PlexAttributeCollectionClass())
        obj.ClassName = "PlexObject"

        ' Constants
        obj.CONTAINER_TYPES = {
            directory: true,
            show: true,
            season: true,
            artist: true,
            album: true,
            photoalbum: true,
            playlist: true,
            podcast: true
        }

        obj.type = invalid
        obj.container = invalid

        obj.Init = pnoInit
        obj.InitSynthetic = pnoInitSynthetic

        ' Helper methods
        obj.IsVideoItem = pnoIsVideoItem
        obj.IsMusicItem = pnoIsMusicItem
        obj.IsPhotoItem = pnoIsPhotoItem
        obj.IsVideoOrDirectoryItem = pnoIsVideoOrDirectoryItem
        obj.IsPhotoOrDirectoryItem = pnoIsPhotoOrDirectoryItem
        obj.IsDirectory = pnoIsDirectory
        obj.IsLibrarySection = pnoIsLibrarySection
        obj.IsPersonalLibrarySection = pnoIsPersonalLibrarySection
        obj.IsLibraryItem = pnoIsLibraryItem
        obj.IsITunes = pnoIsITunes
        obj.IsHomeVideo = pnoIsHomeVideo
        obj.IsContainer = pnoIsContainer

        ' TODO(schuyler): There are a hundred more helper methods on here, but
        ' perhaps we can start adding them only when we're using them.

        obj.GetSingleLineTitle = pnoGetSingleLineTitle
        obj.GetLongerTitle = pnoGetLongerTitle
        obj.GetOverlayTitle = pnoGetOverlayTitle
        obj.GetDuration = pnoGetDuration
        obj.GetAddedAt = pnoGetAddedAt
        obj.GetOriginallyAvailableAt = pnoGetOriginallyAvailableAt
        obj.GetViewOffsetPercentage = pnoGetViewOffsetPercentage
        obj.GetUnwatchedCount = pnoGetUnwatchedCount
        obj.GetUnwatchedCountString = pnoGetUnwatchedCountString
        obj.GetLimitedTagValues = pnoGetLimitedTagValues
        obj.IsUnwatched = pnoIsUnwatched
        obj.InProgress = pnoInProgress

        obj.GetAbsolutePath = pnoGetAbsolutePath
        obj.GetItemPath = pnoGetItemPath
        obj.GetServer = pnoGetServer
        obj.GetPosterTranscodeURL = pnoGetPosterTranscodeURL
        obj.GetImageTranscodeURL = pnoGetImageTranscodeURL
        obj.GetTranscodeServer = pnoGetTranscodeServer
        obj.Scrobble = pnoScrobble
        obj.Unscrobble = pnoUnscrobble

        obj.ToString = pnoToString

        m.PlexObjectClass = obj
    end if

    return m.PlexObjectClass
end function

sub pnoInit(container as object, xml as object)
    ApplyFunc(PlexAttributeCollectionClass().Init, m, [xml])

    m.type = firstOf(m.Get("type"), LCase(m.name))
    m.container = container

    ' Hack for photo albums
    if m.type = "photo" and m.IsDirectory() then
        m.type = "photoalbum"
    end if

    ' Allow any PlexObject to have tags so that things like series don't
    ' have to be full PlexItems.
    '
    m.tags = invalid

    children = xml.GetChildElements()
    if children <> invalid then
        for each elem in xml.GetChildElements()
            if elem.HasAttribute("tag") then
                if m.tags = invalid then m.tags = CreateObject("roAssociativeArray")
                if not m.tags.DoesExist(elem.GetName()) then
                    m.tags[elem.GetName()] = CreateObject("roList")
                end if

                m.tags[elem.GetName()].Push(createPlexTag(elem))
            end if
        next
    end if
end sub

sub pnoInitSynthetic(container as object, name as string)
    m.name = name
    m.type = LCase(name)
    m.container = container
    m.attrs = CreateObject("roAssociativeArray")
end sub

function pnoIsVideoItem() as boolean
    return (m.type = "movie" or m.type = "episode" or m.type = "clip" or m.type = "video")
end function

function pnoIsMusicItem() as boolean
    return (m.type = "track" or m.type = "album")
end function

function pnoIsPhotoItem() as boolean
    return (m.type = "photo")
end function

function pnoIsVideoOrDirectoryItem() as boolean
    return (m.IsVideoItem() or m.type = "season" or m.type = "show")
end function

function pnoIsPhotoOrDirectoryItem() as boolean
    return (m.IsPhotoItem() or m.type = "photoalbum")
end function

function pnoIsDirectory() as boolean
    return (m.name = "Directory" or m.name = "Playlist")
end function

function pnoIsLibrarySection() as boolean
    return (isnonemptystr(m.Get("agent")) or isnonemptystr(m.Get("serverName")))
end function

function pnoIsLibraryItem() as boolean
    return (instr(1, m.Get("key", ""), "/library/metadata") > 0)
end function

function pnoIsPersonalLibrarySection() as boolean
    return (m.IsLibrarySection() and m.Get("agent", "") = "com.plexapp.agents.none")
end function

function pnoIsITunes() as boolean
    return (m.Get("identifier", "") = "com.plexapp.plugins.itunes")
end function

function pnoIsHomeVideo() as boolean
    return (instr(1, m.Get("guid", ""), "com.plexapp.agents.none://") > 0)
end function

function pnoIsContainer() as boolean
    return m.CONTAINER_TYPES.DoesExist(m.type)
end function

function pnoGetSingleLineTitle() as string
    if m.type = "episode" and m.Has("parentIndex") and m.Has("index") then
        return "S" + right("0" + m.Get("parentIndex"), 2) + " E" + right("0" + m.Get("index"), 2)
    end if

    return m.Get("title", "")
end function

function pnoGetLongerTitle() as string
    parentTitle = invalid
    childTitle = invalid

    if m.type = "episode" then
        parentTitle = m.Get("grandparentTitle")
        childTitle = m.GetSingleLineTitle()
    else if m.type = "season" then
        parentTitle = m.Get("parentTitle")
        childTitle = m.Get("title")
    else if m.type = "album" then
        parentTitle = m.Get("parentTitle")
        childTitle = m.Get("title")
    else if m.type = "track" then
        parentTitle = m.Get("grandparentTitle")
        childTitle = m.Get("title")
    end if

    if parentTitle <> invalid and childTitle <> invalid then
        return parentTitle + " - " + childTitle
    else
        return firstOf(parentTitle, childTitle, m.Get("title", ""))
    end if
end function

function pnoGetOverlayTitle(preferParent=false as boolean, forced=false as boolean) as dynamic
    if preferParent and m.type = "episode" then
        return m.GetFirst(["grandparentTitle", "parentTitle"])
    else if not forced and (m.type = "movie" or m.type = "show") then
        ' Movies and shows should have identifying posters, so they get no
        ' overlay title. (unless forced, e.g. landscape artwork)
        return invalid
    else
        return m.GetSingleLineTitle()
    end if
end function

function pnoToString() as string
    return m.name + ": " + m.GetSingleLineTitle()
end function

function pnoGetDuration() as string
    duration = m.Get("duration")
    if duration <> invalid then
        return GetDurationString(int(duration.toInt()/1000))
    end if
    return ""
end function

function pnoGetAddedAt() as string
    date = m.Get("addedAt")
    if date <> invalid then
        datetime = CreateObject( "roDateTime" )
        datetime.ToLocalTime()
        datetime.FromSeconds( date.toInt() )
        return datetime.AsDateString("no-weekday")
    end if
    return ""
end function

function pnoGetOriginallyAvailableAt() as string
    date = m.Get("originallyAvailableAt")
    if date <> invalid then
        return convertDateToString(date)
    end if
    return ""
end function

function createPlexObjectFromElement(container as object, xml as object) as object
    if xml.GetName() = "Device" then
        return createPlexResource(container, xml)
    else if xml.GetName() = "Hub" then
        return createPlexHub(container, xml)
    else if xml.GetNamedElements("Media").Count() > 0 or container.Get("identifier") = "com.plexapp.plugins.itunes" then
        return createPlexItem(container, xml)
    end if

    Info("Don't know what to do with " + xml.GetName() + ", creating generic PlexObject")

    obj = CreateObject("roAssociativeArray")
    obj.Append(PlexObjectClass())
    obj.Init(container, xml)
    return obj
end function

function pnoGetViewOffsetPercentage() as float
    if m.has("viewOffset") and m.has("duration") then
        viewOffsetInMillis = m.GetInt("viewOffset")
        durationInMillis = m.GetInt("duration")
        return viewOffsetInMillis / durationInMillis
    end if

    return 0
end function

function pnoGetUnwatchedCount() as integer
    if m.has("leafCount") and m.has("viewedLeafCount") then
        return m.GetInt("leafCount") - m.GetInt("viewedLeafCount")
    end if

    return -1
end function

function pnoIsUnwatched() as boolean
    if m.IsDirectory() then
        if m.has("leafCount") and m.has("viewedLeafCount") then
            return (m.GetInt("leafCount") <> m.GetInt("viewedLeafCount"))
        end if
        return true
    end if

    return (NOT m.has("viewCount") or m.GetInt("viewCount") = 0)
end function

function pnoInProgress() as boolean
    if m.IsDirectory() then
        return (m.GetInt("viewedLeafCount") > 0 and m.GetInt("viewedLeafCount") < m.GetInt("leafCount"))
    end if

    return (m.has("viewOffset") and m.GetInt("viewOffset") > 0)
end function

function pnoGetUnwatchedCountString() as string
    count = m.GetUnwatchedCount()
    if count > 0 then
        text = tostr(count) + " unwatched episode"
        if count > 1 then text = text + "s"
        return text
    end if

    return ""
end function

function pnoGetLimitedTagValues(tagClass as string, limit as integer, sep=", " as string) as string
    if m.tags = invalid then return ""

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

function pnoGetServer() as dynamic
    return m.container.server
end function

function pnoGetPosterTranscodeURL(width as integer, height as integer, extraOpts=invalid as dynamic) as dynamic
    if m.type = "episode" then
        attrs = ["grandparentThumb", "thumb"]
    else
        attrs = "thumb"
    end if

    return m.GetImageTranscodeURL(attrs, width, height, extraOpts)
end function

function pnoGetImageTranscodeURL(attr, width as integer, height as integer, extraOpts=invalid as dynamic) as dynamic
    ' TODO(schuyler): Do we need to force a background color often enough
    ' anymore to warrant making it a parameter?

    if isstr(attr) then
        path = m.Get(attr)
    else
        path = m.GetFirst(attr)
    end if

    ' Convert the path to an absolute path
    if path = invalid then return invalid
    path = m.container.GetAbsolutePath(path)

    server = m.GetTranscodeServer(false)
    return server.GetImageTranscodeURL(path, width, height, extraOpts)
end function

function pnoGetTranscodeServer(localServerRequired as boolean) as dynamic
    server = m.container.server

    ' If the server is myPlex, try to use a different PMS for transcoding
    if MyPlexServer().Equals(server) then
        fallbackServer = PlexServerManager().GetTranscodeServer()

        if fallbackServer <> invalid then
            server = fallbackServer
        else if localServerRequired then
            return invalid
        end if
    end if

    return server
end function

sub pnoScrobble()
    server = m.GetServer()
    ratingKey = m.Get("ratingKey")
    identifier = m.GetIdentifier()
    if server <> invalid and ratingKey <> invalid and identifier <> invalid then
        request = createPlexRequest(server, "/:/scrobble?key=" + ratingKey + "&identifier=" + identifier)
        context = request.CreateRequestContext("ignored")
        Application().StartRequest(request, context)
    end if
end sub

sub pnoUnscrobble()
    server = m.GetServer():
    ratingKey = m.Get("ratingKey")
    identifier = m.GetIdentifier()
    if server <> invalid and ratingKey <> invalid and identifier <> invalid then
        request = createPlexRequest(server, "/:/unscrobble?key=" + ratingKey + "&identifier=" + identifier)
        context = request.CreateRequestContext("ignored")
        Application().StartRequest(request, context)
    end if
end sub

function pnoGetAbsolutePath(attr) as dynamic
    path = m.Get(attr)
    if path = invalid then
        return invalid
    else
        return m.container.GetAbsolutePath(path)
    end if
end function

function pnoGetItemPath() as string
    if m.IsLibrarySection() then
        return "/library/sections/" + m.Get("key")
    else if m.IsITunes() then
        return m.GetAbsolutePath("key")
    end if

    key = m.GetAbsolutePath("key")

    if m.IsContainer() then
        suffixPos = key.Instr("/children")
        if suffixPos > 0 then
            key = key.Left(suffixPos) + key.Mid(suffixPos + 9)
        end if
    else if m.IsLibraryItem() then
        ' If we're going to request this item specifically, then we might as
        ' well get all the info.
        key = key + iif(instr(1, key, "?") = 0, "?", "&") + "checkFiles=1"

        if m.type = "movie" then
            key = key + "&includeExtras=1"
        end if
    end if

    return key
end function
