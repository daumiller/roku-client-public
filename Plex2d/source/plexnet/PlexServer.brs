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
        obj.activeConnection = invalid

        obj.BuildUrl = pnsBuildUrl
        obj.GetToken = pnsGetToken
        obj.CollectDataFromRoot = pnsCollectDataFromRoot
        obj.UpdateReachability = pnsUpdateReachability
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
    for each conn in m.connections
        if conn.token <> invalid then return conn.token
    next

    return invalid
end function

function pnsCollectDataFromRoot() as boolean
    ' TODO(schuyler): This will probably be based on a PlexResult?
    return true
end function

sub pnsUpdateReachability()
    ' TODO(schuyler): Probably using the yet-to-be defined PlexRequest
end sub

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
