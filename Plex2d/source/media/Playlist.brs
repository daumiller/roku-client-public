function PlaylistClass() as object
    if m.PlaylistClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(EventsMixin())
        obj.Append(PlexObjectClass())
        obj.ClassName = "Playlist"

        obj.id = invalid

        obj.Refresh = plRefresh
        obj.OnResponse = plOnResponse
        obj.OnChildResponse = plOnChildResponse

        obj.MoveItemUp = plMoveItemUp
        obj.MoveItemDown = plMoveItemDown
        obj.MoveItem = plMoveItem
        obj.RemoveItem = plRemoveItem

        m.PlaylistClass = obj
    end if

    return m.PlaylistClass
end function

function createPlaylist(container as object, xml as object) as object
    obj = CreateObject("roAssociativeArray")

    obj.Append(PlaylistClass())

    obj.Init(container, xml)

    obj.id = obj.GetInt("ratingKey")
    obj.server = obj.GetServer()

    obj.items = CreateObject("roList")

    ' Make request for items?

    return obj
end function

sub plRefresh(refreshMetadata as boolean, refreshItems as boolean)
    if refreshMetadata then
        request = createPlexRequest(m.server, "/playlists/" + tostr(m.id) + "?includeRelated=1")
        context = request.CreateRequestContext("refresh", createCallable("OnResponse", m))
        Application().StartRequest(request, context)
    end if

    if refreshItems then
        request = createPlexRequest(m.server, m.GetAbsolutePath("key"))
        request.AddParam("includeRelated", "1")
        context = request.CreateRequestContext("refreshItems", createCallable("OnChildResponse", m))
        Application().StartRequest(request, context)
    end if
end sub

function plMoveItemUp(item as object) as boolean
    for index = 1 to m.items.Count() - 1
        if m.items[index].Get("playlistItemID") = item.Get("playlistItemID") then
            if index > 1 then
                after = m.items[index - 2]
            else
                after = invalid
            end if

            m.MoveItem(item, after)
            return true
        end if
    end for

    return false
end function

function plMoveItemDown(item as object) as boolean
    for index = 0 to m.items.Count() - 2
        if m.items[index].Get("playlistItemID") = item.Get("playlistItemID") then
            after = m.items[index + 1]
            m.MoveItem(item, after)
            return true
        end if
    end for

    return false
end function

sub plMoveItem(item as object, after as dynamic)
    request = createPlexRequest(m.server, "/playlists/" + tostr(m.id) + "/items/" + item.Get("playlistItemID", "-1") + "/move", "PUT")
    if after <> invalid then request.AddParam("after", after.Get("playlistItemID", "-1"))
    request.AddParam("includeRelated", "1")

    ' Since the move response only includes playlist metadata, which shouldn't
    ' have changed, we don't even bother listening for the response.
    context = request.CreateRequestContext("move", invalid)
    Application().StartRequest(request, context, "")
end sub

sub plRemoveItem(item as object)
    indexToDelete = invalid
    for index = 0 to m.items.Count() - 1
        if m.items[index].Get("playlistItemID") = item.Get("playlistItemID") then
            indexToDelete = index
            exit for
        end if
    end for

    if indexToDelete <> invalid then
        request = createPlexRequest(m.server, "/playlists/" + tostr(m.id) + "/items/" + item.Get("playlistItemID", "-1"), "DELETE")
        request.AddParam("includeRelated", "1")
        context = request.CreateRequestContext("delete", createCallable("OnResponse", m))
        Application().StartRequest(request, context, "")

        m.items.Delete(indexToDelete)
        m.Trigger("change:items", [m])
    end if
end sub

sub plOnResponse(request as object, response as object, context as object)
    if response.ParseResponse() and response.items.Count() = 1 then
        ' There's not much we care about here, but if the attributes are any
        ' different than the new ones are correct, so we replace them wholesale.
        m.attrs.Append(response.items[0].attrs)

        m.Trigger("change:metadata", [m])
    end if
end sub

sub plOnChildResponse(request as object, response as object, context as object)
    Error(response.GetBodyString())
    if response.ParseResponse() then
        m.items = response.items
        m.Trigger("change:items", [m])
    end if
end sub
