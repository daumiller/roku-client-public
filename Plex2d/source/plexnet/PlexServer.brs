' Note: In "real" PlexNet, PlexServer extends PlexDevice, and related
' things like PlexServerManager extend PlexDeviceManager. We don't really
' need that layer, because we don't care about PlexPlayer. If that ever
' changes, we can pull some of this into a PlexDevice class.

function PlexServerClass() as object
    if m.PlexServerClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.ClassName = "PlexServer"

        obj.name = invalid
        obj.uuid = invalid
        obj.versionArr = invalid
        obj.owned = true
        obj.owner = invalid
        obj.multiuser = false
        obj.synced = false
        obj.supportsAudioTranscoding = false
        obj.supportsVideoTranscoding = false
        obj.supportsPhotoTranscoding = false
        obj.allowsMediaDeletion = false
        obj.activeConnection = invalid

        obj.BuildUrl = pnsBuildUrl
        obj.GetToken = pnsGetToken
        obj.CollectDataFromRoot = pnsCollectDataFromRoot
        obj.UpdateReachability = pnsUpdateReachability
        obj.MarkAsRefreshing = pnsMarkAsRefreshing
        obj.MarkUpdateFinished = pnsMarkUpdateFinished
        obj.Merge = pnsMerge
        obj.Equals = pnsEquals
        obj.ToString = pnsToString

        m.PlexServerClass = obj
    end if

    return m.PlexServerClass
end function

function createPlexServer() as object
    obj = CreateObject("roAssociativeArray")

    obj.Append(PlexServerClass())

    obj.connections = CreateObject("roList")

    return obj
end function

function createPlexServerForConnection(conn as object) as object
    obj = createPlexServer()
    obj.connections.Push(conn)
    obj.activeConnection = conn
    return obj
end function

function createPlexServerForName(uuid as string, name as string) as object
    obj = createPlexServer()
    obj.uuid = uuid
    obj.name = name
    return obj
end function

function createPlexServerForResource(resource as object) as object
    obj = createPlexServer()

    obj.owner = resource.Get("sourceTitle")
    obj.owned = (resource.Get("owned") = "1")
    obj.synced = (resource.Get("synced") = "1")
    obj.uuid = resource.Get("clientIdentifier")
    obj.name = resource.Get("name")
    obj.version = ParseVersion(resource.Get("productVersion", ""))
    obj.connections = resource.connections

    return obj
end function

function pnsBuildUrl(path as string, includeToken=false as boolean) as dynamic
    if m.activeConnection <> invalid then
        return m.activeConnection.BuildUrl(m, path, includeToken)
    else
        return invalid
    end if
end function

function pnsGetToken() as dynamic
    ' It's dangerous to use for each here, because it may reset the index
    ' on m.connections when something else was in the middle of an iteration.

    for i = 0 to m.connections.Count() - 1
        conn = m.connections[i]
        if conn.token <> invalid then return conn.token
    next

    return invalid
end function

function pnsCollectDataFromRoot(xml as object) as boolean
    ' Make sure we're processing data for our server, and not some other
    ' server that happened to be at the same IP.
    if m.uuid <> xml@machineIdentifier then
        Info("Got a reachability response, but from a different server")
        return false
    end if

    m.supportsAudioTranscoding = (xml@transcoderAudio = "1")
    m.supportsVideoTranscoding = (xml@transcoderVideoQualities <> invalid)
    m.supportsPhotoTranscoding = NOT m.synced
    m.allowsMediaDeletion = (m.owned and (xml@allowMediaDeletion = "1"))
    m.multiuser = (xml@multiuser = "1")
    m.name = firstOf(xml@friendlyName, m.name)

    ' TODO(schuyler): Process transcoder qualities
    ' TODO(schuyler): Version

    Debug("Server information updated from reachability check: " + tostr(m))

    return true
end function

sub pnsUpdateReachability(force=true as boolean)
    if not force and m.activeConnection <> invalid then return

    Debug("Updating reachability for " + tostr(m.name) + ", will test " + tostr(m.connections.Count()) + " connections")
    for each conn in m.connections
        conn.TestReachability(m)
    next
end sub

sub pnsMarkAsRefreshing()
    for each conn in m.connections
        conn.refreshed = false
    next
end sub

function pnsMarkUpdateFinished(source as integer) as boolean
    ' Any connections for the given source which haven't been refreshed should
    ' be removed. Since removing from a list is hard, we'll make a new list.
    toKeep = CreateObject("roList")

    for each conn in m.connections
        if not conn.refreshed then
            conn.sources = (conn.sources and (not source))
        end if

        if conn.sources > 0 then
            toKeep.AddTail(conn)
        else
            Debug("Removed connection for " + tostr(m.name) + " after updating connections for " + tostr(source))
            if m.activeConnection = conn then
                Debug("Active connection lost")
                m.activeConnection = invalid
            end if
        end if
    next

    m.connections = toKeep

    return (m.connections.Count() > 0)
end function

sub pnsMerge(other as object)
    ' Wherever this other server came from, assume its information is better
    m.name = other.name
    m.versionArr = other.versionArr

    ' Merge connections
    for each otherConn in other.connections
        merged = false
        for each myConn in m.connections
            if myConn.Equals(otherConn) then
                myConn.Merge(otherConn)
                merged = true
                exit for
            end if
        next

        if not merged then
            m.connections.Push(otherConn)
        end if
    next

    ' If the other server has a token, then it came from plex.tv, which
    ' means that its ownership information is better than ours. But if
    ' it was discovered, then it may incorrectly claim to be owned, so
    ' we stick with whatever we already had.

    if isnonemptystr(other.GetToken()) then
        m.owned = other.owned
        m.owner = other.owner
    end if
end sub

function pnsEquals(other as object) as boolean
    if m.ClassName <> other.ClassName then return false
    return ((m.uuid = other.uuid) and (m.owner = other.owner))
end function

function pnsToString() as string
    return "Server " + m.name + " owned: " + tostr(m.owned) + " uuid: " + tostr(m.uuid)
end function
