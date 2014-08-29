function PlexServerManager()
    if m.PlexServerManager = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.serversByUuid = {}
        obj.selectedServer = invalid

        obj.SetSelectedServer = psmSetSelectedServer
        obj.GetServer = psmGetServer
        obj.GetServers = psmGetServers
        obj.RemoveServer = psmRemoveServer
        obj.MergeServer = psmMergeServer

        obj.UpdateFromConnectionType = psmUpdateFromConnectionType
        obj.UpdateFromDiscovery = psmUpdateFromDiscovery
        obj.MarkDevicesAsRefreshing = psmMarkDevicesAsRefreshing
        obj.DeviceRefreshComplete = psmDeviceRefreshComplete

        obj.UpdateReachability = psmUpdateReachability
        obj.UpdateReachabilityResult = psmUpdateReachabilityResult

        obj.IsValidForTranscoding = psmIsValidForTranscoding

        obj.OnAccountChange = psmOnAccountChange

        obj.SaveState = psmSaveState
        obj.LoadState = psmLoadState

        m.PlexServerManager = obj

        obj.LoadState()

        Application().On("change:user", createCallable("OnAccountChange", obj))
    end if

    return m.PlexServerManager
end function

function psmSetSelectedServer(server as dynamic, force as boolean) as boolean
    ' Don't do anything if the server is already selected.
    if m.selectedServer <> invalid and m.selectedServer.Equals(server) then return false

    ' Don't select servers that don't have connections.
    if server.activeConnection = invalid then return false

    if m.selectedServer = invalid or force then
        Info("Setting selected server to " + tostr(server))
        m.selectedServer = server

        ' Update our saved state.
        m.SaveState()

        return true
    end if

    return false
end function

function psmGetServer(uuid as string) as dynamic
    if uuid = "myplex" then return MyPlexServer()

    return m.serversByUuid[uuid]
end function

function psmGetServers() as dynamic
    servers = []
    for each uuid in m.serversByUuid
        if uuid <> "myplex" then
            servers.push(m.serversByUuid[uuid])
        end if
    next

    return servers
end function

sub psmRemoveServer(server as object)
    m.serversByUuid.Delete(server.uuid)

    ' Was it the selected server?
    if server.Equals(m.selectedServer) then
        Debug("The selected server went away")
        m.SetSelectedServer(invalid, true)
    end if
end sub

sub psmUpdateFromConnectionType(servers as object, source as integer)
    m.MarkDevicesAsRefreshing()

    for each server in servers
        m.MergeServer(server)
    next

    m.DeviceRefreshComplete(source)
    m.UpdateReachability(false)
    m.SaveState()
end sub

sub psmUpdateFromDiscovery(server as object)
    merged = m.MergeServer(server)

    if merged.activeConnection = invalid then
        merged.UpdateReachability(false)
    else
        ' m.NotifyAboutDevice(merged, true)
    end if
end sub

sub psmMarkDevicesAsRefreshing()
    for each uuid in m.serversByUuid
        m.serversByUuid[uuid].MarkAsRefreshing()
    next
end sub

function psmMergeServer(server as object) as object
    if m.serversByUuid.DoesExist(server.uuid) then
        existing = m.serversByUuid[server.uuid]
        existing.Merge(server)
        Debug("Merged " + server.name)
        return existing
    else
        m.serversByUuid[server.uuid] = server
        Debug("Added new server " + server.name)
        return server
    end if
end function

sub psmDeviceRefreshComplete(source as integer)
    toRemove = CreateObject("roList")
    for each uuid in m.serversByUuid
        if not m.serversByUuid[uuid].MarkUpdateFinished(source) then
            toRemove.AddTail(uuid)
        end if
    next

    for each uuid in toRemove
        server = m.serversByUuid[uuid]

        Debug("Server " + server.name + " has no more connections")
        ' m.NotifyAboutDevice(server, false)
        m.RemoveServer(server)
    next
end sub

sub psmUpdateReachability(force as boolean)
    Debug("Updating reachability for all devices, force=" + tostr(force))

    for each uuid in m.serversByUuid
        m.serversByUuid[uuid].UpdateReachability(force)
    next
end sub

sub psmUpdateReachabilityResult(server as object, reachable as boolean)
    if reachable
        ' m.NotifyAboutDevice(server, true)

        ' TODO(schuyler): This doesn't belong here, it's just a convenient hook
        ' to make a request to test PlexNet stuff (hubs!).
        if server.owned then
            Debug("Making hubs request, just because")
            request = createPlexRequest(server, "/hubs")
            context = request.CreateRequestContext("dummy_hubs", createCallable(LogHubsResponse, invalid))
            Application().StartRequest(request, context)
        end if
    else
        if server.Equals(m.selectedServer) then
            Debug("Selected server is not reachable")
            m.SetSelectedServer(invalid, true)
        end if

        ' m.NotifyAboutDevice(server, false)
    end if
end sub

sub LogHubsResponse(request as object, response as object, context as object)
    Debug("Got hubs response with status " + tostr(response.GetStatus()))

    if response.ParseResponse() then
        for each hub in response.items
            Debug(hub.ToString())
        next
    else
        Error("Failed to parse hubs response")
    end if
end sub

sub psmLoadState()
    ' TODO(schuyler): Load from JSON
end sub

sub psmSaveState()
    ' TODO(schuyler): Serialize to registry as JSON
end sub

function psmIsValidForTranscoding(server as dynamic) as boolean
    return (server <> invalid and server.activeConnection <> invalid and server.owned and not server.synced)
end function

sub psmOnAccountChange(account)
    if account.isSignedIn then
        ' Refresh resources from plex.tv
        MyPlexManager().RefreshResources()
    else
        ' Clear servers/connections from plex.tv
        m.UpdateFromConnectionType([], PlexConnectionClass().SOURCE_MYPLEX)
    end if
end sub

' TODO(schuyler): Notifications
' TODO(schuyler): Transcode (and primary) server selection
