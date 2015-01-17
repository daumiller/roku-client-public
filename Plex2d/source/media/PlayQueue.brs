function PlayQueueClass() as object
    if m.PlayQueueClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(EventsMixin())
        obj.ClassName = "PlayQueue"

        obj.id = invalid
        obj.selectedId = invalid
        obj.isShuffled = false
        obj.isRepeat = false
        obj.totalSize = 0
        obj.windowSize = 0

        obj.Refresh = pqRefresh
        obj.OnResponse = pqOnResponse
        obj.IsWindowed = pqIsWindowed

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

    if contentType = "audio" then
        AudioPlayer().SetPlayQueue(obj, true)
    end if

    return obj
end function

sub pqRefresh()
    request = createPlexRequest(server, "/playQueues/" + tostr(m.id))
    context = request.CreateRequestContext("refresh", createCallable("OnResponse", m))
    Application().StartRequest(request, context)
end sub

sub pqOnResponse(request as object, response as object, context as object)
    if response.ParseResponse() then
        m.id = response.container.GetInt("playQueueID")
        m.isShuffled = response.container.GetBool("playQueueShuffled")
        m.selectedId = response.container.GetInt("playQueueSelectedItemID")
        m.totalSize = response.container.GetInt("playQueueTotalCount")
        m.windowSize = response.items.Count()
        m.items = response.items

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
