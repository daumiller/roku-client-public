function PlayQueueClass() as object
    if m.PlayQueueClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(EventsMixin())
        obj.ClassName = "PlayQueue"

        obj.id = invalid
        obj.selectedId = invalid
        obj.version = -1
        obj.isShuffled = false
        obj.isRepeat = false
        obj.supportsShuffle = false
        obj.totalSize = 0
        obj.windowSize = 0

        obj.Refresh = pqRefresh
        obj.OnResponse = pqOnResponse
        obj.IsWindowed = pqIsWindowed

        obj.SetShuffle = pqSetShuffle
        obj.SetRepeat = pqSetRepeat

        obj.Equals = pqEquals

        m.PlayQueueClass = obj
    end if

    return m.PlayQueueClass
end function

function createPlayQueue(server as object, contentType as string, uri as string, options as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(PlayQueueClass())

    obj.server = server
    obj.type = contentType
    obj.items = CreateObject("roList")

    request = createPlexRequest(server, "/playQueues")
    request.AddParam(iif(options.isPlaylist = invalid, "uri", "playlistID"), uri)
    request.AddParam("type", contentType)

    if options.key <> invalid then
        request.AddParam("key", options.key)
    end if

    if options.shuffle = true then
        request.AddParam("shuffle", "1")
    end if

    if options.extrasPrefixCount <> invalid then
        request.AddParam("extrasPrefixCount", tostr(options.extrasPrefixCount))
    end if

    context = request.CreateRequestContext("create", createCallable("OnResponse", obj))
    Application().StartRequest(request, context, "")

    return obj
end function

function createPlayQueueForItem(item as object, options=invalid as dynamic) as object
    if item.IsMusicOrDirectoryItem() then
        contentType = "audio"
    else if item.IsVideoOrDirectoryItem() then
        contentType = "video"
    else if item.IsPhotoOrDirectoryItem() then
        contentType = "photo"
    else
        ' TODO(schuyler): We may need to try harder, but I'm not sure yet. For
        ' example, what if we're shuffling an entire library?
        Fatal("Don't know how to create play queue for item")
    end if

    if options = invalid then options = createPlayOptions()

    if options.key = invalid and not item.IsDirectory() then
        options.key = item.Get("key")
    end if

    ' If we're asked to play unwatched, ignore the option unless we are unwatched.
    options.unwatched = (options.unwatched = true) and item.IsUnwatched()

    ' The item's URI is made up of the library section UUID, a descriptor of
    ' the item type (item or directory), and the item's path, URL-encoded.

    uri = "library://" + item.GetLibrarySectionUuid() + "/"

    ' TODO(schuyler): Until we build postplay, we're not allowed to queue containers for episodes.
    if item.type = "episode" then
        options.context = options.CONTEXT_SELF
    else if item.type = "movie" then
        if options.extrasPrefixCount = invalid and options.resume <> true then
            options.extrasPrefixCount = AppSettings().GetIntPreference("cinema_trailers")
        end if
    end if

    itemType = iif(item.IsDirectory(), "directory", "item")
    path = invalid

    ' How exactly to construct the item URI depends on the metadata type, though
    ' whenever possible we simply use /library/metadata/:id.
    '
    if item.type = "playlist" then
        uri = item.Get("ratingKey")
        options.isPlaylist = true
    else if item.type = "track" then
        path = "/library/metadata/" + item.Get("parentRatingKey", "")
        itemType = "directory"
    else if item.type = "photo" then
        path = "/library/sections/" + item.GetLibrarySectionId() + "/all?type=13&parent=" + UrlEscape(item.Get("parentRatingKey", "-1"))
    else if item.type = "photoalbum" then
        path = "/library/sections/" + item.GetLibrarySectionId() + "/all?type=13&parent=" + UrlEscape(item.Get("ratingKey", "-1"))
    else if item.type = "episode" and options.context <> options.CONTEXT_SELF then
        path = "/library/metadata/" + item.Get("grandparentRatingKey", "")
        itemType = "directory"
        options.key = item.GetAbsolutePath("key")
    else if item.type = "show" then
        path = "/library/metadata/" + item.Get("ratingKey", "")

        ' TODO(schuyler): We may need to fetch the show's metadata to determine
        ' the on deck item. For example, shows that are returned inside hubs.
        '
        if item.onDeck <> invalid and item.onDeck.Count() > 0 then
            options.key = item.onDeck[0].GetAbsolutePath("key")
        end if
    else if item.IsLibraryItem()
        path = "/library/metadata/" + item.Get("ratingKey", "")
    else
        path = item.GetAbsolutePath("key")
    end if

    if path <> invalid then
        uri = uri + itemType + "/" + UrlEscape(path)
    end if

    return createPlayQueue(item.GetServer(), contentType, uri, options)
end function

function createPlayQueueForId(server as object, contentType as string, id as integer) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(PlayQueueClass())

    obj.server = server
    obj.type = contentType
    obj.items = CreateObject("roList")
    obj.id = id

    request = createPlexRequest(server, "/playQueues/" + tostr(id))
    request.AddParam("own", "1")

    context = request.CreateRequestContext("own", createCallable("OnResponse", obj))
    Application().StartRequest(request, context)

    return obj
end function

sub pqRefresh(force=true as boolean)
    ' We refresh our play queue if the caller insists or if we only have a
    ' portion of our play queue loaded. In particular, this means that we don't
    ' refresh the play queue if we're asked to refresh because a new track is
    ' being played but we have the entire album loaded already.
    '
    if force or m.IsWindowed() then
        request = createPlexRequest(m.server, "/playQueues/" + tostr(m.id))
        context = request.CreateRequestContext("refresh", createCallable("OnResponse", m))
        Application().StartRequest(request, context)
    end if
end sub

sub pqSetShuffle(shuffle as boolean)
    if m.isShuffled = shuffle then return

    if shuffle then
        command = "/shuffle"
    else
        command = "/unshuffle"
    end if

    ' Don't change m.isShuffled, it'll be set in OnResponse if all goes well

    request = createPlexRequest(m.server, "/playQueues/" + tostr(m.id) + command, "PUT")
    context = request.CreateRequestContext("shuffle", createCallable("OnResponse", m))
    Application().StartRequest(request, context, "")
end sub

sub pqSetRepeat(repeat as boolean)
    if m.isRepeat = repeat then return

    ' TODO(schuyler): Flesh this out once PMS supports it

    m.isRepeat = repeat
end sub

sub pqOnResponse(request as object, response as object, context as object)
    if response.ParseResponse() then
        m.id = response.container.GetInt("playQueueID")
        m.isShuffled = response.container.GetBool("playQueueShuffled")
        m.supportsShuffle = not response.container.Has("playQueueLastAddedItemID")
        m.totalSize = response.container.GetInt("playQueueTotalCount")
        m.windowSize = response.items.Count()
        m.items = response.items

        ' Calculate the current track index
        m.playQueueItemOffset = response.container.GetInt("playQueueSelectedItemOffset")
        m.playQueueSelectedMetadataItemID = response.container.Get("playQueueSelectedMetadataItemID", "")
        playQueueOffset = 0
        for index = 0 to m.items.Count() - 1
            if m.items[index].Get("ratingKey", "") = m.playQueueSelectedMetadataItemID then
                playQueueOffset = m.playQueueItemOffset - index + 1
                exit for
            end if
        end for

        ' Determine if we have mixed parents
        lastItem = invalid
        m.isMixed = false
        for index = 0 to m.items.Count() - 1
            i = m.items[index]
            i.Set("playQueueIndex", tostr(playQueueOffset + index))

            if m.IsMixed <> true then
                if i.Get("parentKey") = invalid then
                    m.isMixed = true
                else if lastItem <> invalid and i.Get("parentKey") <> lastItem.Get("parentKey") then
                    m.isMixed = true
                end if
            end if
            lastItem = i
        end for

        newVersion = response.container.GetInt("playQueueVersion")

        ' We may have changed the selected ID ourselves as we advanced to the
        ' next item, and we may have refreshed before the first timeline
        ' convinced PMS that we've moved on. We should never need to get this
        ' info from PMS once we've started playing, so don't bother. The one
        ' important exception is that if the version changed then our item IDs
        ' probably changed along with it.
        '
        if m.selectedId = invalid or newVersion <> m.version then
            m.selectedId = response.container.GetInt("playQueueSelectedItemID")
            m.version = newVersion
        end if

        ' TODO(schuyler): Set repeat as soon as PMS starts returning it

        ' Fix up the container for all our items
        response.container.address = "/playQueues/" + tostr(m.id)

        m.Trigger("change", [m])
    end if
end sub

function pqIsWindowed() as boolean
    return (m.totalSize > m.windowSize)
end function

function pqEquals(other as dynamic) as boolean
    if other = invalid then return false
    if m.ClassName <> other.ClassName then return false
    return (m.id = other.id and m.type = other.type)
end function
