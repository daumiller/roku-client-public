function PlexServerManager()
    if m.PlexServerManager = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.serversByUuid = {}
        obj.selectedServer = invalid

        obj.StartSelectedServerSearch = psmStartSelectedServerSearch
        obj.CheckSelectedServerSearch = psmCheckSelectedServerSearch
        obj.GetSelectedServer = psmGetSelectedServer
        obj.SetSelectedServer = psmSetSelectedServer
        obj.GetServer = psmGetServer
        obj.GetServers = psmGetServers
        obj.RemoveServer = psmRemoveServer
        obj.MergeServer = psmMergeServer
        obj.CompareServers = psmCompareServers

        obj.UpdateFromConnectionType = psmUpdateFromConnectionType
        obj.UpdateFromDiscovery = psmUpdateFromDiscovery
        obj.MarkDevicesAsRefreshing = psmMarkDevicesAsRefreshing
        obj.DeviceRefreshComplete = psmDeviceRefreshComplete

        obj.UpdateReachability = psmUpdateReachability
        obj.UpdateReachabilityResult = psmUpdateReachabilityResult

        obj.IsValidForTranscoding = psmIsValidForTranscoding
        obj.GetTranscodeServer = psmGetTranscodeServer

        obj.OnAccountChange = psmOnAccountChange

        obj.SaveState = psmSaveState
        obj.LoadState = psmLoadState

        m.PlexServerManager = obj

        obj.StartSelectedServerSearch()
        obj.LoadState()

        Application().On("change:user", createCallable("OnAccountChange", obj))
    end if

    return m.PlexServerManager
end function

function psmGetSelectedServer() as dynamic
    return m.selectedServer
end function

function psmSetSelectedServer(server as dynamic, force as boolean) as boolean
    ' Don't do anything if the server is already selected.
    if m.selectedServer <> invalid and m.selectedServer.Equals(server) then return false

    if server <> invalid then
        ' Don't select servers that don't have connections.
        if server.activeConnection = invalid then return false

        ' Don't select synced servers.
        if server.synced then return false
    end if

    if m.selectedServer = invalid or force then
        Info("Setting selected server to " + tostr(server))
        m.selectedServer = server

        ' Update our saved state.
        m.SaveState()

        ' Notify anyone who might care.
        Application().Trigger("change:selectedServer", [server])

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
        ' TODO(schuyler): Figure out how to handle synced servers. For now,
        ' we're pretending like they don't exist.
        if uuid <> "myplex" and not m.serversByUuid[uuid].synced then
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

    if m.searchContext <> invalid and source = PlexConnectionClass().SOURCE_MYPLEX then
        m.searchContext.waitingForResources = false
    end if

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
    searching = (m.selectedServer = invalid and m.searchContext <> invalid and not server.synced)

    if reachable
        ' If we're in the middle of a search for our selected server, see if
        ' this is a candidate.
        '
        if searching then
            ' If this is what we were hoping for, select it
            if server.uuid = m.searchContext.preferredServer then
                m.SetSelectedServer(server, true)
            else if m.CompareServers(m.searchContext.bestServer, server) < 0 then
                m.searchContext.bestServer = server
            end if
        end if
    else
        ' If this is what we were hoping for, see if there are any more pending
        ' requests to hope for.
        '
        if searching and server.uuid = m.searchContext.preferredServer and server.pendingReachabilityRequests <= 0 then
            m.searchContext.preferredServer = invalid
        end if

        if server.Equals(m.selectedServer) then
            Debug("Selected server is not reachable")
            m.SetSelectedServer(invalid, true)
        end if
    end if

    ' See if we should settle for the best we've found so far.
    m.CheckSelectedServerSearch()
end sub

sub psmCheckSelectedServerSearch()
    if m.selectedServer = invalid and m.searchContext <> invalid then
        waitingForPreferred = false
        waitingForOwned = false
        waitingForAnything = (m.searchContext.waitingForResources and MyPlexAccount().isSignedIn)

        ' Iterate over all our servers and see if we're waiting on any results
        servers = m.GetServers()
        for each server in servers
            if server.pendingReachabilityRequests > 0 then
                if server.uuid = m.searchContext.preferredServer then
                    waitingForPreferred = true
                else if server.owned then
                    waitingForOwned = true
                else
                    waitingForAnything = true
                end if
            end if
        next

        if waitingForPreferred then
            Debug("Still waiting for preferred server")
        else if waitingForOwned and (m.searchContext.bestServer = invalid or m.searchContext.bestServer.owned <> true) then
            Debug("Still waiting for an owned server")
        else if waitingForAnything and m.searchContext.bestServer = invalid then
            Debug("Still waiting for any server")
        else
            ' No hope for anything better, let's select what we found
            m.SetSelectedServer(m.searchContext.bestServer, true)
        end if
    end if
end sub

function psmCompareServers(first as dynamic, second as dynamic) as integer
    if first = invalid then
        return iif(second = invalid, 0, -1)
    else if second = invalid then
        return 1
    else if first.owned <> second.owned then
        return iif(first.owned, 1, -1)
    else if first.IsLocalConnection() <> second.IsLocalConnection() then
        return iif(first.IsLocalConnection(), 1, -1)
    else
        return 0
    end if
end function

sub psmLoadState()
    json = AppSettings().GetPreference("PlexServerManager", invalid, "misc")
    if json = invalid then return

    obj = ParseJson(json)
    if obj = invalid then
        Error("Failed to parse PlexServerManager JSON")
        return
    end if

    m.searchContext.preferredServer = obj.lastServerId

    for each serverObj in obj.servers
        server = createPlexServerForName(serverObj.uuid, serverObj.name)
        server.owned = serverObj.owned

        for each conn in serverObj.connections
            server.connections.Push(createPlexConnection(conn.sources, conn.address, conn.isLocal, conn.token))
        next

        m.serversByUuid[server.uuid] = server
    next

    Debug("Loaded " + tostr(obj.servers.Count()) + " servers from registry")
    m.UpdateReachability(false)
end sub

sub psmSaveState()
    ' Serialize our important information to JSON and save it to the registry.
    ' We'll always update server info upon connecting, so we don't need much
    ' info here. We do have to use roArray instead of roList, because Brightscript.

    obj = CreateObject("roAssociativeArray")

    servers = m.GetServers()
    obj.servers = CreateObject("roArray", servers.Count(), false)

    for each server in servers
        serverObj = {
            name: server.name,
            uuid: server.uuid,
            owned: server.owned,
            connections: CreateObject("roArray", server.connections.Count(), false)
        }

        for each conn in server.connections
            serverObj.connections.Push({
                sources: conn.sources,
                address: conn.address,
                isLocal: conn.isLocal,
                token: conn.token
            })
        next

        obj.servers.Push(serverObj)
    next

    if m.selectedServer <> invalid then
        obj.lastServerId = m.selectedServer.uuid
    else
        obj.lastServerId = invalid
    end if

    AppSettings().SetPreference("PlexServerManager", FormatJson(obj), "misc")
end sub

function psmIsValidForTranscoding(server as dynamic) as boolean
    return (server <> invalid and server.activeConnection <> invalid and server.owned and not server.synced)
end function

function psmGetTranscodeServer() as dynamic
    ' TODO(schuyler): Is there more to this?
    return m.selectedServer
end function

sub psmStartSelectedServerSearch(reset=false as boolean)
    if reset then
        m.selectedServer = invalid
    end if

    ' Keep track of some information during our search
    m.searchContext = {
        bestServer: invalid,
        preferredServer: invalid,
        waitingForResources: true
    }
end sub

sub psmOnAccountChange(account)
    if account.isSignedIn then
        ' TODO(schuyler): We need to do more here. This means that the user has
        ' changed. We should probably clear all existing MYPLEX connections,
        ' and then refresh resources. We need to choose a new selected server,
        ' just like startup, so we should reuse StartSelectedServerSearch in
        ' some fashion.

        m.StartSelectedServerSearch(true)
    else
        ' Clear servers/connections from plex.tv
        m.UpdateFromConnectionType([], PlexConnectionClass().SOURCE_MYPLEX)
    end if
end sub

' TODO(schuyler): Notifications
' TODO(schuyler): Transcode (and primary) server selection
