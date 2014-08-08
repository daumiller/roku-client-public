' We don't particularly need a class definition here (yet?), it's just a
' PlexRequest where the server is fixed.

function createMyPlexRequest(path as string) as object
    return createPlexRequest(MyPlexServer(), path)
end function
