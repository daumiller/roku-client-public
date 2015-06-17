function MyPlexManager()
    if m.MyPlexManager = invalid then
        obj = CreateObject("roAssociativeArray")

        ' We need a screenID property in order to use certain Application feature
        obj.screenID = Application().SCREEN_MYPLEX

        obj.Publish = mpPublish
        obj.RefreshResources = mpRefreshResources

        ' HTTP response handlers
        obj.OnResourcesResponse = mpOnResourcesResponse

        m.MyPlexManager = obj
    end if

    return m.MyPlexManager
end function

sub mpPublish()
    request = createMyPlexRequest("/devices/" + AppSettings().GetGlobal("clientIdentifier"))
    context = request.CreateRequestContext("publish")

    addrs = AppSettings().GetGlobal("roDeviceInfo").GetIPAddrs()
    first = true

    for each iface in addrs
        request.AddParam(UrlEscape("Connection[][uri]"), "http://" + addrs[iface] + ":8324")
    next

    Application().StartRequest(request, context, "_method=PUT")
end sub

sub mpRefreshResources(force=false as boolean)
    if force then PlexServerManager().ResetLastTest()

    request = createMyPlexRequest("/pms/resources")
    context = request.CreateRequestContext("resources", createCallable("OnResourcesResponse", m))
    context.timeout = iif(MyPlexAccount().isOffline, 1000, 10000)

    if MyPlexAccount().isSecure = true then
        request.AddParam("includeHttps", "1")
    end if

    Application().StartRequest(request, context)
end sub

sub mpOnResourcesResponse(request as object, response as object, context as object)
    servers = CreateObject("roList")

    response.ParseResponse()

    ' Save the last successful response to cache
    if response.IsSuccess() and response.event <> invalid then
        AppSettings().SetRegistry("mpaResources", response.event.GetString(), "xml_cache")
        Debug("Saved resources response to registry")
    ' Load the last successful response from cache
    else if AppSettings().GetRegistry("mpaResources", invalid, "xml_cache") <> invalid then
        xml = CreateObject("roXMLElement")
        xml.Parse(AppSettings().GetRegistry("mpaResources", invalid, "xml_cache"))
        response.ParseFakeXMLResponse(xml)
        Debug("Using cached resources")
    end if

    for each resource in response.items
        Debug("Parsed resource from plex.tv: nodeName:" + resource.name + " type:" + resource.type + " clientIdentifier:" + resource.Get("clientIdentifier") + " name:" + resource.Get("name") + " product:" + resource.Get("product") + " provides:" + resource.Get("provides"))
        for each conn in resource.connections
            Debug(conn.ToString())
        next

        if instr(1, resource.Get("provides", ""), "server") > 0 then
            server = createPlexServerForResource(resource)
            Debug(server.ToString())
            servers.AddTail(server)
        end if
    next

    PlexServerManager().UpdateFromConnectionType(servers, PlexConnectionClass().SOURCE_MYPLEX)
end sub
