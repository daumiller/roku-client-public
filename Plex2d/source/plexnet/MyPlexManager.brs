' TODO(schuyler): There's much still to do here, but this may end
' up inheriting from a Server object that doesn't exist yet. So
' things are generally a bit hardcoded.

function MyPlexManager()
    if m.MyPlexManager = invalid then
        obj = CreateObject("roAssociativeArray")

        ' We need a screenID property in order to use certain Application feature
        obj.screenID = Application().SCREEN_MYPLEX

        obj.RefreshAccount = mpRefreshAccount
        obj.Publish = mpPublish
        obj.RefreshResources = mpRefreshResources

        ' HTTP response handlers
        obj.OnAccountResponse = mpOnAccountResponse
        obj.OnResourcesResponse = mpOnResourcesResponse

        m.MyPlexManager = obj
    end if

    return m.MyPlexManager
end function

sub mpRefreshAccount()
    request = createMyPlexRequest("/users/account")
    context = request.CreateRequestContext("account", createCallable("OnAccountResponse", m))

    Application().StartRequest(request, context)
end sub

sub mpPublish()
    request = createMyPlexRequest("/devices/" + AppSettings().GetGlobal("clientIdentifier"))
    context = request.CreateRequestContext("publish")

    device = CreateObject("roDeviceInfo")
    addrs = device.GetIPAddrs()
    first = true

    for each iface in addrs
        request.AddParam(UrlEscape("Connection[][uri]"), "http://" + addrs[iface] + ":8324")
    next

    Application().StartRequest(request, context, "_method=PUT")
end sub

sub mpRefreshResources()
    ' TODO(schuyler): This is just a demonstration that things are working, much more to do...
    request = createMyPlexRequest("/pms/resources")
    context = request.CreateRequestContext("resources", createCallable("OnResourcesResponse", m))

    Application().StartRequest(request, context)
end sub

sub mpOnAccountResponse(request as object, response as object, context as object)
    MyPlexAccount().UpdateAccount(response.GetBodyXml(), response.GetStatus())
end sub

sub mpOnResourcesResponse(request as object, response as object, context as object)
    response.ParseResponse()
    for each resource in response.items
        Debug("Parsed resource from plex.tv: nodeName:" + resource.name + " type:" + resource.type + " clientIdentifier:" + resource.Get("clientIdentifier") + " name:" + resource.Get("name") + " product:" + resource.Get("product") + " provides:" + resource.Get("provides"))
        for each conn in resource.connections
            Debug(conn.ToString())
        next

        if instr(1, resource.Get("provides", ""), "server") > 0 then
            server = createPlexServerForResource(resource)
            Debug(server.ToString())
        end if
    next
end sub
