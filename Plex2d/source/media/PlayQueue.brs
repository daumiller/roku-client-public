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
        obj.OnRefreshTimer = pqOnRefreshTimer
        obj.OnResponse = pqOnResponse
        obj.IsWindowed = pqIsWindowed

        obj.SetShuffle = pqSetShuffle
        obj.SetRepeat = pqSetRepeat
        obj.MoveItemUp = pqMoveItemUp
        obj.MoveItemDown = pqMoveItemDown
        obj.MoveItem = pqMoveItem
        obj.SwapItem = pqSwapItem
        obj.RemoveItem = pqRemoveItem
        obj.AddItem = pqAddItem

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
    request.AddParam("includeRelated", "1")

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

    if item.IsLibraryItem()
        path = "/library/metadata/" + item.Get("ratingKey", "")
    else
        path = item.GetAbsolutePath("key")
    end if

    if options.context = options.CONTEXT_SELF then
        ' If the context is specifically for just this item, then just use the
        ' item's key and get out.
    else if item.type = "playlist" then
        path = invalid
        uri = item.Get("ratingKey")
        options.isPlaylist = true
    else if item.type = "track" then
        path = "/library/metadata/" + item.Get("parentRatingKey", "")
        itemType = "directory"
    else if item.type = "photo" then
        path = "/library/sections/" + item.GetLibrarySectionId() + "/all?type=13&parent=" + UrlEscape(item.Get("parentRatingKey", "-1"))
    else if item.type = "photoalbum" then
        path = "/library/sections/" + item.GetLibrarySectionId() + "/all?type=13&parent=" + UrlEscape(item.Get("ratingKey", "-1"))
    else if item.type = "episode" then
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
    end if

    if path <> invalid then
        uri = uri + itemType + "/" + UrlEscape(path)
    end if

    if options.shuffle = true then options.key = invalid

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
    request.AddParam("includeRelated", "1")

    context = request.CreateRequestContext("own", createCallable("OnResponse", obj))
    Application().StartRequest(request, context)

    return obj
end function

function addItemToPlayQueue(item as object, addNext as boolean) as dynamic
    ' See if we have an active play queue for this media type or if we need to
    ' create one.

    if item.IsMusicOrDirectoryItem() then
        player = AudioPlayer()
    else if item.IsVideoOrDirectoryItem() then
        player = VideoPlayer()
    else if item.IsPhotoOrDirectoryItem() then
        ' player = PhotoPlayer()
        player = invalid
    else
        player = invalid
    end if

    if player = invalid then
        Error("Don't know how to add item to play queue: " + tostr(item))
        return invalid
    end if

    if player.playQueue <> invalid then
        playQueue = player.playQueue
        playQueue.AddItem(item, addNext)
    else
        options = createPlayOptions()
        options.context = options.CONTEXT_SELF
        playQueue = createPlayQueueForItem(item, options)
        player.SetPlayQueue(playQueue, false)
    end if

    return playQueue
end function

sub pqOnRefreshTimer(timer as object)
    m.Refresh(true, false)
end sub

sub pqRefresh(force=true as boolean, delay=false as boolean)
    ' We refresh our play queue if the caller insists or if we only have a
    ' portion of our play queue loaded. In particular, this means that we don't
    ' refresh the play queue if we're asked to refresh because a new track is
    ' being played but we have the entire album loaded already.
    '
    if force or m.IsWindowed() then
        if delay then
            ' We occasionally want to refresh the PQ in response to moving to a
            ' new item and starting playback, but if we refresh immediately then
            ' we probably end up refreshing before PMS realizes we've moved on.
            ' There's no great solution, but delaying our refresh by just a few
            ' seconds makes us much more likely to get an accurate window (and
            ' accurate selected IDs) from PMS.

            if m.refreshTimer = invalid then
                m.refreshTimer = createTimer("refresh")
                m.refreshTimer.SetDuration(5000, false)
                m.refreshTimer.callback = createCallable("OnRefreshTimer", m)
            end if

            m.refreshTimer.active = true
            Application().AddTimer(m.refreshTimer, m.refreshTimer.callback)
        else
            request = createPlexRequest(m.server, "/playQueues/" + tostr(m.id) + "?includeRelated=1")
            context = request.CreateRequestContext("refresh", createCallable("OnResponse", m))
            Application().StartRequest(request, context)
        end if
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

    request = createPlexRequest(m.server, "/playQueues/" + tostr(m.id) + command + "?includeRelated=1", "PUT")
    context = request.CreateRequestContext("shuffle", createCallable("OnResponse", m))
    Application().StartRequest(request, context, "")
end sub

sub pqSetRepeat(repeat as boolean)
    if m.isRepeat = repeat then return

    ' TODO(schuyler): Flesh this out once PMS supports it

    m.isRepeat = repeat
end sub

function pqMoveItemUp(item as object) as boolean
    for index = 1 to m.items.Count() - 1
        if m.items[index].Get("playQueueItemID") = item.Get("playQueueItemID") then
            if index > 1 then
                after = m.items[index - 2]
            else
                after = invalid
            end if

            m.SwapItem(index, -1)
            m.MoveItem(item, after)
            return true
        end if
    end for

    return false
end function

function pqMoveItemDown(item as object) as boolean
    for index = 0 to m.items.Count() - 2
        if m.items[index].Get("playQueueItemID") = item.Get("playQueueItemID") then
            after = m.items[index + 1]
            m.SwapItem(index)
            m.MoveItem(item, after)
            return true
        end if
    end for

    return false
end function

sub pqMoveItem(item as object, after as object)
    if after <> invalid then
        query = "?after=" + after.Get("playQueueItemID", "-1")
    else
        query = ""
    end if

    request = createPlexRequest(m.server, "/playQueues/" + tostr(m.id) + "/items/" + item.Get("playQueueItemID", "-1") + "/move" + query, "PUT")
    request.AddParam("includeRelated", "1")
    context = request.CreateRequestContext("move", createCallable("OnResponse", m))
    Application().StartRequest(request, context, "")
end sub

sub pqSwapItem(index as integer, delta=1 as integer)
    before = m.items[index]
    after = m.items[index + delta]

    m.items[index] = after
    m.items[index + delta] = before
end sub

sub pqRemoveItem(item as object)
    request = createPlexRequest(m.server, "/playQueues/" + tostr(m.id) + "/items/" + item.Get("playQueueItemID", "-1"), "DELETE")
    request.AddParam("includeRelated", "1")
    context = request.CreateRequestContext("delete", createCallable("OnResponse", m))
    Application().StartRequest(request, context, "")
end sub

sub pqAddItem(item as object, addNext as boolean)
    request = createPlexRequest(m.server, "/playQueues/" + tostr(m.id), "PUT")
    request.AddParam("uri", item.GetItemUri())
    request.AddParam("next", iif(addNext, "1", "0"))
    request.AddParam("includeRelated", "1")
    context = request.CreateRequestContext("add", createCallable("OnResponse", m))
    Application().StartRequest(request, context, "")
end sub

sub pqOnResponse(request as object, response as object, context as object)
    if response.ParseResponse() then
        m.id = response.container.GetInt("playQueueID")
        m.isShuffled = response.container.GetBool("playQueueShuffled")
        m.supportsShuffle = not response.container.Has("playQueueLastAddedItemID")
        m.totalSize = response.container.GetInt("playQueueTotalCount")
        m.windowSize = response.items.Count()
        m.version = response.container.GetInt("playQueueVersion")
        m.items = response.items

        ' Figure out the selected track index and offset. PMS tries to make some
        ' of this easy, but it might not realize that we've advanced to a new
        ' track, so we can't blindly trust it. On the other hand, it's possible
        ' that PMS completely changed the PQ item IDs (e.g. upon shuffling), so
        ' we might need to use its values. We iterate through the items and try
        ' to find the item that we believe is selected, only settling for what
        ' PMS says if we fail.

        playQueueOffset = invalid
        selectedId = invalid
        pmsSelectedId = response.container.GetInt("playQueueSelectedItemID")
        lastItem = invalid
        m.isMixed = false

        for index = 0 to m.items.Count() - 1
            item = m.items[index]

            if playQueueOffset = invalid and item.GetInt("playQueueItemID") = pmsSelectedId then
                playQueueOffset = response.container.GetInt("playQueueSelectedItemOffset") - index + 1

                ' Update the index of everything we've already past.
                for i = 0 to index - 1
                    m.items[i].Set("playQueueIndex", tostr(playQueueOffset + i))
                end for
            end if

            if playQueueOffset <> invalid then
                item.Set("playQueueIndex", tostr(playQueueOffset + index))
            end if

            ' If we found the item that we believe is selected then we should
            ' continue to treat it as selected.
            ' TODO(schuyler): Should we be checking the metadata ID (rating key)
            ' instead? I don't think it matters in practice, but it may be
            ' more correct.
            '
            if selectedId = invalid and item.GetInt("playQueueItemID") = m.selectedId then
                selectedId = m.selectedId
            end if

            if not m.isMixed then
                if item.Get("parentKey") = invalid then
                    m.isMixed = true
                else
                    m.isMixed = (lastItem <> invalid and item.Get("parentKey") <> lastItem.Get("parentKey"))
                end if
                lastItem = item
            end if
        end for

        if selectedId = invalid then m.selectedId = pmsSelectedId

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
