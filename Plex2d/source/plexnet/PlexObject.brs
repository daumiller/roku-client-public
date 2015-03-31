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
        obj.IsMusicOrDirectoryItem = pnoIsMusicOrDirectoryItem
        obj.IsPhotoOrDirectoryItem = pnoIsPhotoOrDirectoryItem
        obj.IsDirectory = pnoIsDirectory
        obj.IsLibrarySection = pnoIsLibrarySection
        obj.IsPersonalLibrarySection = pnoIsPersonalLibrarySection
        obj.IsLibraryItem = pnoIsLibraryItem
        obj.IsITunes = pnoIsITunes
        obj.IsHomeVideo = pnoIsHomeVideo
        obj.IsContainer = pnoIsContainer
        obj.IsDateBased = pnoIsDateBased

        ' TODO(schuyler): There are a hundred more helper methods on here, but
        ' perhaps we can start adding them only when we're using them.

        obj.GetSingleLineTitle = pnoGetSingleLineTitle
        obj.GetLongerTitle = pnoGetLongerTitle
        obj.GetOverlayTitle = pnoGetOverlayTitle
        obj.GetDuration = pnoGetDuration
        obj.GetViewOffset = pnoGetViewOffset
        obj.GetAddedAt = pnoGetAddedAt
        obj.GetOriginallyAvailableAt = pnoGetOriginallyAvailableAt
        obj.GetViewOffsetPercentage = pnoGetViewOffsetPercentage
        obj.GetUnwatchedCount = pnoGetUnwatchedCount
        obj.GetUnwatchedCountString = pnoGetUnwatchedCountString
        obj.GetChildCountString = pnoGetChildCountString
        obj.GetLimitedTagValues = pnoGetLimitedTagValues
        obj.IsUnwatched = pnoIsUnwatched
        obj.InProgress = pnoInProgress
        obj.GetIdentifier = pnoGetIdentifier
        obj.GetLibrarySectionId = pnoGetLibrarySectionId
        obj.GetLibrarySectionUuid = pnoGetLibrarySectionUuid
        obj.GetItemUri = pnoGetItemUri

        obj.GetPrimaryExtra = pnoGetPrimaryExtra
        obj.GetRelatedItem = pnoGetRelatedItem

        obj.GetAbsolutePath = pnoGetAbsolutePath
        obj.GetItemPath = pnoGetItemPath
        obj.GetContextPath = pnoGetContextPath
        obj.GetServer = pnoGetServer
        obj.GetPosterTranscodeURL = pnoGetPosterTranscodeURL
        obj.GetImageTranscodeURL = pnoGetImageTranscodeURL
        obj.GetTranscodeServer = pnoGetTranscodeServer
        obj.DeleteItem = pnoDeleteItem
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
    m.playlistType = m.Get("playlistType", "")
    m.container = container

    ' Hack for photo albums
    if m.type = "photo" and m.IsDirectory() then
        m.type = "photoalbum"
    end if

    if m.type = "directory" and instr(1, m.Get("key", ""), "services/gracenote/similarPlaylist") > 0 then
        m.type = "plexmix"
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
        end for

        if xml.OnDeck.GetChildElements() <> invalid then
            if m.onDeck = invalid then m.onDeck = CreateObject("roList")
            for each node in xml.OnDeck.GetChildElements()
                m.onDeck.push(createPlexObjectFromElement(container, node))
            end for
        end if
        if xml.Related.GetChildElements() <> invalid then
            if m.relatedItems = invalid then m.relatedItems = CreateObject("roList")
            for each node in xml.Related.GetChildElements()
                m.relatedItems.push(createPlexObjectFromElement(container, node))
            end for
        end if
        if xml.Extras.GetChildElements() <> invalid then
            if m.extraItems = invalid then m.extraItems = CreateObject("roList")
            for each node in xml.Extras.GetChildElements()
                m.extraItems.push(createPlexObjectFromElement(container, node))
            end for
        end if
    end if

    ' Copy some attributes from the container to the object
    m.TryCopy(container, "thumb")
    m.TryCopy(container, "art")
end sub

sub pnoInitSynthetic(container as object, name as string)
    m.name = name
    m.type = LCase(name)
    m.container = container
    m.attrs = CreateObject("roAssociativeArray")
end sub

function pnoIsVideoItem() as boolean
    return (m.type = "movie" or m.type = "episode" or m.type = "clip" or m.type = "video" or m.playlistType = "video")
end function

function pnoIsMusicItem() as boolean
    return (m.type = "track" or m.type = "album" or m.playlistType = "audio")
end function

function pnoIsPhotoItem() as boolean
    return (m.type = "photo")
end function

function pnoIsVideoOrDirectoryItem() as boolean
    return (m.IsVideoItem() or m.type = "season" or m.type = "show")
end function

function pnoIsMusicOrDirectoryItem() as boolean
    return (m.IsMusicItem() or m.type = "artist" or m.type = "plexmix")
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
    return (instr(1, m.Get("key", ""), "/library/metadata") > 0 or (instr(1, m.Get("key", ""), "/playlists/") > 0 and m.Get("type", "") = "playlist"))
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
    if m.IsDateBased() then
        if m.type = "season" then
            return m.Get("index")
        else if m.Has("originallyAvailableAt") then
            r = CreateObject("roRegex", "-", "")
            return r.ReplaceAll(m.Get("originallyAvailableAt"), "/")
        end if
    else if m.type = "episode" and m.Has("parentIndex") and m.Has("index") then
        return "S" + m.Get("parentIndex") + " • E" + m.Get("index")
    end if

    return m.Get("title", "")
end function

function pnoGetLongerTitle(sep=" - " as string) as string
    parentTitle = invalid
    childTitle = invalid

    if m.type = "clip" and m.Get("extraType") <> invalid then
        parentTitle = m.Get("extraTitle")
        childTitle = m.GetSingleLineTitle()
    else if m.type = "episode" then
        parentTitle = firstOf(m.Get("grandparentTitle"), m.container.Get("grandparentTitle"))
        childTitle = m.GetSingleLineTitle()
    else if m.type = "season" then
        parentTitle = firstOf(m.Get("parentTitle"), m.container.Get("parentTitle"))
        childTitle = m.Get("title")
    else if m.type = "album" then
        parentTitle = firstOf(m.Get("parentTitle"), m.container.Get("parentTitle"))
        childTitle = m.Get("title")
    else if m.type = "track" then
        parentTitle = firstOf(m.Get("grandparentTitle"), m.container.Get("grandparentTitle"))
        childTitle = m.Get("title")
    end if

    if parentTitle <> invalid and childTitle <> invalid then
        return parentTitle + sep + childTitle
    else
        return firstOf(parentTitle, childTitle, m.Get("title", ""))
    end if
end function

function pnoGetOverlayTitle(preferParent=false as boolean, forced=false as boolean) as dynamic
    if preferParent and m.type = "episode" then
        return m.GetFirst(["grandparentTitle", "parentTitle"])
    else if not forced and (m.type = "movie" or m.type = "show" or m.type = "album") then
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
        if m.type = "track" then
            return GetTimeString(int(duration.toInt()/1000))
        else
            return GetDurationString(int(duration.toInt()/1000))
        end if
    end if
    return ""
end function

function pnoGetViewOffset() as string
    viewOffset = m.Get("viewOffset")
    if viewOffset <> invalid then
        return GetTimeString(int(viewOffset.toInt()/1000))
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
    else if xml.GetName() = "Playlist" then
        return createPlaylist(container, xml)
    else if xml.GetNamedElements("Media").Count() > 0 or container.Get("identifier") = "com.plexapp.plugins.itunes" then
        return createPlexItem(container, xml)
    end if

    Verbose("Don't know what to do with " + xml.GetName() + ", creating generic PlexObject")

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

function pnoGetIdentifier() as dynamic
    identifier = m.Get("identifier")

    if identifier = invalid then
        identifier = m.container.Get("identifier")
    end if

    ' HACK
    ' PMS doesn't return an identifier for playlist items. If we haven't found
    ' an identifier and the key looks like a library item, then we pretend like
    ' the identifier was set.
    '
    if identifier = invalid and instr(1, m.Get("key", ""), "/library/metadata") = 1 then
        identifier = "com.plexapp.plugins.library"
    end if

    return identifier
end function

function pnoGetLibrarySectionId() as string
    id = m.Get("librarySectionID")

    if id = invalid then
        id = m.container.Get("librarySectionID", "")
    end if

    return id
end function

function pnoGetLibrarySectionUuid() as string
    uuid = m.GetFirst(["uuid", "librarySectionUUID"])

    if uuid = invalid then
        uuid = m.container.Get("librarySectionUUID", "")
    end if

    return uuid
end function

function pnoGetItemUri() as string
    ' Note that this will always return a URI for this specific item. Play Queue
    ' creation code may do additional conversions to do things like create a URI
    ' that represents a parent or grandparent instead of an individual item.

    uri = "library://" + m.GetLibrarySectionUuid() + "/"
    itemType = iif(m.IsDirectory(), "directory", "item")

    if m.IsLibraryItem()
        path = "/library/metadata/" + m.Get("ratingKey", "")
    else
        path = m.GetAbsolutePath("key")
    end if

    return uri + itemType + "/" + UrlEscape(path)
end function

function pnoGetUnwatchedCountString() as string
    count = m.GetUnwatchedCount()
    if count > 0 then
        suffix = "unwatched episode"
        return tostr(count) + " " + iif(count > 1, suffix + "s", suffix)
    end if

    return ""
end function

function pnoGetChildCountString() as string
    count = m.GetFirst(["childCount", "leafCount"], "0").toInt()
    if count > 0 then
        if m.type = "album" then
            suffix = "Track"
        else if m.type = "season" then
            suffix = "Episode"
        else if m.type = "show" then
            suffix = "Season"
        else
            suffix = "Item"
        end if
        return tostr(count) + " " + iif(count > 1, suffix + "s", suffix)
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

sub pnoDeleteItem(callback=invalid as dynamic)
    if m.GetServer() <> invalid and not m.IsContainer() and m.IsLibraryItem() then
        request = createPlexRequest(m.GetServer(), m.GetAbsolutePath("key"), "DELETE")
        context = request.CreateRequestContext("delete", callback)
        Application().StartRequest(request, context)
    end if
end sub

sub pnoScrobble(callback=invalid as dynamic)
    server = m.GetServer()
    ratingKey = m.Get("ratingKey")
    identifier = m.GetIdentifier()
    if server <> invalid and ratingKey <> invalid and identifier <> invalid then
        request = createPlexRequest(server, "/:/scrobble?key=" + ratingKey + "&identifier=" + identifier)
        context = request.CreateRequestContext("scrobble", callback)
        Application().StartRequest(request, context)
    end if
end sub

sub pnoUnscrobble(callback=invalid as dynamic)
    server = m.GetServer()
    ratingKey = m.Get("ratingKey")
    identifier = m.GetIdentifier()
    if server <> invalid and ratingKey <> invalid and identifier <> invalid then
        request = createPlexRequest(server, "/:/unscrobble?key=" + ratingKey + "&identifier=" + identifier)
        context = request.CreateRequestContext("unscrobble", callback)
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

' TODO(rob): checkFiles is now disabled by default. We should be deferring
' this call even if we need to checkFiles. e.g. on the preplay screen we
' should display it first, then make a call to checkFiles and update when
' we receive the response.
function pnoGetItemPath(checkFiles=false as boolean) as string
    if m.IsLibrarySection() then
        return "/library/sections/" + m.Get("key")
    else if m.IsITunes() then
        return m.GetAbsolutePath("key")
    end if

    key = m.GetAbsolutePath("key")

    if m.IsContainer() then
        ' Some containers have /children on its key while others (such as playlists) use /items
        suffixStrip = ["/children", "/items"]
        for each suffix in suffixStrip
            suffixPos = key.Instr(suffix)
            if suffixPos > 0 then
                key = key.Left(suffixPos) + key.Mid(suffixPos + suffix.Len())
            end if
        end for
    else if m.IsLibraryItem() then
        ' TODO(rob): checkFiles disabled by default. We should specifically
        ' request this because it can delay the UI, and it's not always
        ' required. i.e. it's normally not required for navigation, probably
        ' excluding the preplay settings screen.
        if checkFiles = true then
            hasParams = (instr(1, key, "?") > 0)
            key = key + iif(hasParams, "&", "?") + "checkFiles=1"
        end if

        if m.type = "movie" or m.type = "episode" then
            hasParams = (instr(1, key, "?") > 0)
            key = key + iif(hasParams, "&", "?") + "includeRelated=1&includeRelatedCount=0"
            key = key + "&includeExtras=1"
        else if m.type = "track" then
            hasParams = (instr(1, key, "?") > 0)
            key = key + iif(hasParams, "&", "?") + "includeRelated=1&includeRelatedCount=0"
        end if
    end if

    return key
end function

function pnoGetContextPath(allLeaves=true as boolean) as dynamic
    suffix = iif(allLeaves, "/allLeaves", "/children?excludeAllLeaves=1")
    if m.type = "episode" and m.Has("grandparentKey") then
        key = m.Get("grandparentKey") + suffix
    else if m.type = "season" and m.Has("parentKey") then
        key = m.Get("parentKey") + suffix
    else
        key = m.container.address
    end if

    return key
end function

function pnoIsDateBased() as boolean
    ' If the "season" index is greater than 1000, assume it's a year (web-client logic)
    if m.type = "episode" then
        return m.GetInt("parentIndex") > 1000
    else if m.type = "season" then
        return m.GetInt("index") > 1000
    end if

    return false
end function

function pnoGetPrimaryExtra(fetchIfNecessary=true as boolean) as dynamic
    ' We may or may not have been fetched with extras, but we should have the
    ' primary extra key regardless. So if that doesn't exist, then there's no
    ' need to fetch anything.

    extraKey = m.Get("primaryExtraKey")
    if extraKey = invalid then return invalid

    haveExtras = (m.extraItems <> invalid and m.extraItems.Count() > 0)
    extraItem = invalid

    if m.extraItems <> invalid then
        for each extra in m.extraItems
            if extraKey = extra.Get("key") then
                extraItem = extra
                exit for
            end if
        next
    end if

    if extraItem = invalid and fetchIfNecessary and not haveExtras then
        request = createPlexRequest(m.GetServer(), m.GetAbsolutePath("primaryExtraKey"))
        response = request.DoRequestWithTimeout(10)
        if response.items <> invalid then extraItem = response.items[0]
    end if

    return extraItem
end function

function pnoGetRelatedItem(itemType as string) as dynamic
    if m.relatedItems = invalid then return invalid

    for each relatedItem in m.relatedItems
        if relatedItem.type = itemType then
            return relatedItem
        end if
    next

    return invalid
end function