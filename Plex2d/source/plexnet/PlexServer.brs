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

        obj.pendingReachabilityRequests = 0
        obj.pendingSecureRequests = 0

        obj.BuildUrl = pnsBuildUrl
        obj.GetToken = pnsGetToken
        obj.GetLocalServerPort = pnsGetLocalServerPort
        obj.GetImageTranscodeURL = pnsGetImageTranscodeURL
        obj.CollectDataFromRoot = pnsCollectDataFromRoot
        obj.UpdateReachability = pnsUpdateReachability
        obj.OnReachabilityResult = pnsOnReachabilityResult
        obj.MarkAsRefreshing = pnsMarkAsRefreshing
        obj.MarkUpdateFinished = pnsMarkUpdateFinished
        obj.IsReachable = pnsIsReachable
        obj.IsLocalConnection = pnsIsLocalConnection
        obj.IsRequestToServer = pnsIsRequestToServer
        obj.SupportsFeature = pnsSupportsFeature
        obj.Merge = pnsMerge
        obj.Equals = pnsEquals
        obj.ToString = pnsToString
        obj.GetVersion = pnsGetVersion
        obj.GetSubtitle = pnsGetSubtitle

        m.PlexServerClass = obj
    end if

    return m.PlexServerClass
end function

function createPlexServer() as object
    obj = CreateObject("roAssociativeArray")

    obj.Append(PlexServerClass())

    obj.connections = CreateObject("roList")
    obj.features = {}

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
    obj.versionArr = ParseVersion(resource.Get("productVersion", ""))
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

function pnsGetImageTranscodeURL(path as string, width as integer, height as integer, extraOpts = invalid as object) as dynamic
    ' Build up our parameters
    params = "&width=" + tostr(width) + "&height=" + tostr(height)

    if extraOpts <> invalid then
        for each key in extraOpts
            params = params + "&" + key + "=" + tostr(extraOpts[key])
        next
    end if

    if instr(1, path, "://") > 0 then
        imageUrl = path
    else
        imageUrl = "http://127.0.0.1:" + m.GetLocalServerPort() + path
    end if

    return m.BuildUrl("/photo/:/transcode?url=" + UrlEscape(imageUrl) + params, true)
end function

function pnsIsReachable(onlySupported=true as boolean) as boolean
    if onlySupported = true and m.IsSupported = false then return false

    return (m.activeConnection <> invalid and m.activeConnection.state = PlexConnectionClass().STATE_REACHABLE)
end function

function pnsIsLocalConnection() as boolean
    return (m.activeConnection <> invalid and m.activeConnection.isLocal = true)
end function

function pnsIsRequestToServer(url as string) as boolean
    if m.activeconnection = invalid then return false

    portIndex = instr(8, m.activeconnection.address, ":")
    if portIndex > 0 then
        schemeAndHost = left(m.activeconnection.address, portIndex - 1)
    else
        schemeAndHost = m.activeconnection.address
    end if

    return (left(url, len(schemeAndHost)) = schemeAndHost)
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

function pnsGetLocalServerPort() as string
    ' TODO(schuyler): The correct thing to do here is to iterate over local
    ' connections and pull out the port. For now, we're always returning 32400.

    return "32400"
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

    if isnonemptystr(xml@version) then
        m.versionArr = ParseVersion(xml@version)
    end if

    if CheckMinimumVersion([0, 9, 11, 11], m.versionArr) then
        m.features["mkv_transcode"] = true
    end if

    m.IsSupported = CheckMinimumVersion(AppSettings().GetGlobal("minServerVersionArr"), m.versionArr)

    Debug("Server information updated from reachability check: " + tostr(m))

    return true
end function

sub pnsUpdateReachability(force=true as boolean)
    if not force and m.activeConnection <> invalid and m.activeConnection.state <> PlexConnectionClass().STATE_UNKNOWN then return

    Debug("Updating reachability for " + tostr(m.name) + ", will test " + tostr(m.connections.Count()) + " connections")
    for each conn in m.connections
        m.pendingReachabilityRequests = m.pendingReachabilityRequests + 1
        if conn.isSecure then m.pendingSecureRequests = m.pendingSecureRequests + 1
        conn.TestReachability(m)
    next
end sub

sub pnsOnReachabilityResult(connection as object)
    m.pendingReachabilityRequests = m.pendingReachabilityRequests - 1
    if connection.isSecure then m.pendingSecureRequests = m.pendingSecureRequests - 1

    Debug("Reachability result for " + tostr(m.name) + ": " + connection.address + " is " + tostr(connection.state))

    ' invalidate active connection if the state is unreachable
    if m.activeConnection <> invalid and m.activeConnection.state <> PlexConnectionClass().STATE_REACHABLE then
        m.activeConnection = invalid
    end if

    ' Pick a best connection. If we already had an active connection and
    ' it's still reachable, stick with it. (replace with local if
    ' available)
    best = m.activeConnection
    for i = m.connections.Count() - 1 to 0 step -1
        conn = m.connections[i]

        if best = invalid or conn.GetScore() > best.GetScore() then
            best = conn
        end if
    next

    if best <> invalid and best.state = best.STATE_REACHABLE then
        if best.isSecure or m.pendingSecureRequests = 0 then
            m.activeConnection = best
        else
            Debug("Found a good connection for " + tostr(m.name) + ", but holding out for better")
        end if
    end if

    Info("Active connection for " + tostr(m.name) + " is " + tostr(m.activeConnection))
    PlexServerManager().UpdateReachabilityResult(m, (m.activeConnection <> invalid))
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

            ' If we lost our plex.tv connection, don't remember the token.
            if source = conn.SOURCE_MYPLEX then
                conn.token = invalid
            end if
        end if

        if conn.sources > 0 then
            toKeep.AddTail(conn)
        else
            Debug("Removed connection for " + tostr(m.name) + " after updating connections for " + tostr(source))
            if conn.Equals(m.activeConnection) then
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

function pnsSupportsFeature(feature as string) as boolean
    return m.features.DoesExist(feature)
end function

function pnsEquals(other as dynamic) as boolean
    if other = invalid then return false
    if m.ClassName <> other.ClassName then return false
    return ((m.uuid = other.uuid) and (m.owner = other.owner))
end function

function pnsToString() as string
    return "Server " + tostr(m.name) + " owned: " + tostr(m.owned) + " uuid: " + tostr(m.uuid)
end function

sub pnsGetVersion() as string
    if m.versionArr = invalid then return ""

    version = CreateObject("roList")
    for index = 0 to 3
        version.Push(m.versionArr[index])
    end for

    return JoinArray(version, ".")
end sub

function pnsGetSubtitle() as dynamic
    subtitle = CreateObject("roList")

    if m.IsSupported = false then
        subtitle.Push("Upgrade Required")
    else if m.isReachable() = false then
        subtitle.Push("Offline")
    end if

    if not m.owned then
        subtitle.Push(m.owner)
    end if

    if subtitle.Count() > 0 then return JoinArray(subtitle, " - ")

    return invalid
end function
