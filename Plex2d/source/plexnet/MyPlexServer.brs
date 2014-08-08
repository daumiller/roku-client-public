function MyPlexServer() as object
    if m.MyPlexServer = invalid then
        obj = createPlexServerForName("myplex", "plex.tv")

        obj.GetToken = mpGetToken

        conn = createPlexConnection(PlexConnectionClass().SOURCE_MYPLEX, "https://plex.tv", false, invalid)
        obj.connections.Push(conn)
        obj.activeConnection = conn

        m.MyPlexServer = obj
    end if

    return m.MyPlexServer
end function

function mpGetToken() as dynamic
    return MyPlexAccount().authToken
end function
