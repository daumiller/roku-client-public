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

function createPlayQueue(server as object, contentType as string, uri as string, options={} as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(PlayQueueClass())

    obj.server = server
    obj.type = contentType
    obj.items = CreateObject("roList")

    request = createPlexRequest(server, "/playQueues")
    request.AddParam("uri", uri)
    request.AddParam("type", contentType)

    for each name in options
        request.AddParam(name, options[name])
    next

    context = request.CreateRequestContext("create", createCallable("OnResponse", obj))
    Application().StartRequest(request, context, "")

    return obj
end function

function createPlayQueueForItem(item as object, options={} as object) as object
    if item.IsMusicItem() then
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

    if options["key"] = invalid then options["key"] = item.Get("key")

    return createPlayQueue(item.GetServer(), contentType, item.GetItemUri(), options)
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

    request = createPlexRequest(m.server, "/playQueues/" + tostr(m.id) + command + "?_method=PUT")
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
        m.totalSize = response.container.GetInt("playQueueTotalCount")
        m.windowSize = response.items.Count()
        m.items = response.items

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
