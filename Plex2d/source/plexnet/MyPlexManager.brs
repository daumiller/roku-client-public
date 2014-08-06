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
    request = createHttpRequest("https://plex.tv/users/account", true, MyPlexAccount().authToken)
    context = CreateRequestContext("account", m, "OnAccountResponse")

    Application().StartRequest(request, context)
end sub

sub mpPublish()
    url = "https://plex.tv/devices/" + AppSettings().GetGlobal("clientIdentifier")
    request = createHttpRequest(url, true, MyPlexAccount().authToken)
    context = CreateRequestContext("publish")

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
    request = createHttpRequest("https://plex.tv/pms/resources", true, MyPlexAccount().authToken)
    context = CreateRequestContext("resources", m, "OnResourcesResponse")

    Application().StartRequest(request, context)
end sub

sub mpOnAccountResponse(request as object, response as object, context as object)
    MyPlexAccount().UpdateAccount(response.GetBodyXml(), response.GetStatus())
end sub

sub mpOnResourcesResponse(request as object, response as object, context as object)
    if response.IsSuccess() then
        xml = response.GetBodyXml()
        for each device in xml.Device
            resource = createPlexResource(device)
            Debug("Parsed resource from plex.tv: nodeName:" + resource.name + " type:" + resource.type + " clientIdentifier:" + resource.Get("clientIdentifier") + " name:" + resource.Get("name") + " product:" + resource.Get("product") + " provides:" + resource.Get("provides"))
        next
    end if
end sub
