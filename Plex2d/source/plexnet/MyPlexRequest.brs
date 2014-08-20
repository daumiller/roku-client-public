' We don't particularly need a class definition here (yet?), it's just a
' PlexRequest where the server is fixed.

function createMyPlexRequest(path as string) as object
    request = createPlexRequest(MyPlexServer(), path)

    ' Make sure we're always getting XML
    request.AddHeader("Accept", "application/xml")

    return request
end function
