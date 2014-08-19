function PlexConnectionClass() as object
    if m.PlexConnectionClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.ClassName = "PlexConnection"

        ' Constants
        obj.STATE_UNKNOWN = "unknown"
        obj.STATE_UNREACHABLE = "unreachable"
        obj.STATE_REACHABLE = "reachable"
        obj.STATE_UNAUTHORIZED = "unauthorized"

        obj.SOURCE_MANUAL = 1
        obj.SOURCE_DISCOVERED = 2
        obj.SOURCE_MYPLEX = 4

        ' Properties
        obj.state = obj.STATE_UNKNOWN
        obj.sources = 0
        obj.address = invalid
        obj.isLocal = false
        obj.token = invalid
        obj.refreshed = true

        ' Methods
        obj.Merge = pncMerge
        obj.TestReachability = pncTestReachability
        obj.OnReachabilityResponse = pncOnReachabilityResponse
        obj.BuildUrl = pncBuildUrl
        obj.Equals = pncEquals
        obj.ToString = pncToString

        m.PlexConnectionClass = obj
    end if

    return m.PlexConnectionClass
end function

function createPlexConnection(source as integer, address as string, isLocal as boolean, token as dynamic) as object
    obj = CreateObject("roAssociativeArray")

    obj.Append(PlexConnectionClass())

    obj.sources = source
    obj.address = address
    obj.isLocal = isLocal
    obj.token = token

    return obj
end function

sub pncMerge(other as object)
    ' plex.tv trumps all, otherwise assume newer is better

    if (other.sources and m.SOURCE_MYPLEX) <> 0 then
        m.token = other.token
    else
        m.token = firstOf(m.token, other.token)
    end if

    m.address = other.address
    m.sources = (m.sources or other.sources)
    m.isLocal = (m.isLocal or other.isLocal)
    m.refreshed = true
end sub

sub pncTestReachability(server as object)
    request = createHttpRequest(m.BuildUrl(server, "/"))
    context = request.CreateRequestContext("reachability", CreateCallable("OnReachabilityResponse", m))
    context.server = server
    AddPlexHeaders(request.request, server.GetToken())

    Application().StartRequest(request, context)
end sub

sub pncOnReachabilityResponse(request as object, response as object, context as object)
    if response.IsSuccess() then
        xml = response.GetBodyXml()
        if xml <> invalid AND context.server.CollectDataFromRoot(xml) then
            m.state = m.STATE_REACHABLE
        else
            ' This is unexpected, but treat it as unreachable
            Error("Unable to parse root response from " + tostr(context.server))
            m.state = m.STATE_UNREACHABLE
        end if
    else if response.GetStatus() = 401 then
        m.state = m.STATE_UNAUTHORIZED
    else
        m.state = m.STATE_UNREACHABLE
    end if
end sub

function pncBuildUrl(server as object, path as string, includeToken=false as boolean) as string
    url = m.address + path

    if includeToken then
        ' If we have a token, use it. Otherwise see if any other connections
        ' for this server have one. That will let us use a plex.tv token for
        ' something like a manually configured connection.

        if isnonemptystr(m.token) then
            token = m.token
        else
            token = server.GetToken()
        end if

        if token <> invalid then
            url = url + "?X-Plex-Token=" + token
        end if
    end if

    return url
end function

function pncEquals(other as object) as boolean
    if m.ClassName <> other.ClassName then return false
    return (m.address = other.address)
end function

function pncToString() as string
    return "Connection: " + m.address + " local: " + tostr(m.isLocal) + " token: " + tostr(isnonemptystr(m.token)) + " sources: " + tostr(m.sources) + " state: " + m.state
end function
