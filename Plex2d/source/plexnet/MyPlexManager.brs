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

        obj.OnUrlEvent = mpOnUrlEvent

        m.MyPlexManager = obj
    end if

    return m.MyPlexManager
end function

sub mpRefreshAccount()
    request = createHttpRequest("https://plex.tv/users/account", true, MyPlexAccount().authToken)
    context = {requestType: "account"}

    Application().StartRequest(request, m, context)
end sub

sub mpPublish()
    url = "https://plex.tv/devices/" + AppSettings().GetGlobal("clientIdentifier")
    request = createHttpRequest(url, true, MyPlexAccount().authToken)
    context = {requestType: "publish"}

    device = CreateObject("roDeviceInfo")
    addrs = device.GetIPAddrs()
    first = true

    for each iface in addrs
        request.AddParam(UrlEscape("Connection[][uri]"), "http://" + addrs[iface] + ":8324")
    next

    Application().StartRequest(request, m, context, "_method=PUT")
end sub

sub mpRefreshResources()
    ' TODO(schuyler): This is just a demonstration that things are working, much more to do...
    request = createHttpRequest("https://plex.tv/pms/resources", true, MyPlexAccount().authToken)
    context = {requestType: "resources"}

    Application().StartRequest(request, m, context)
end sub

sub mpOnUrlEvent(msg, requestContext)
    if requestContext.requestType = "account" then
        status = msg.GetResponseCode()
        if status = 200 or status = 201 then
            xml = CreateObject("roXMLElement")
            if not xml.Parse(msg.GetString()) then xml = invalid
        else
            xml = invalid
        end if
        MyPlexAccount().UpdateAccount(xml, status)
    else if requestContext.requestType = "resources" then
        if msg.GetResponseCode() = 200 then
            xml = CreateObject("roXMLElement")
            if not xml.Parse(msg.GetString()) then xml = invalid
        else
            xml = invalid
        end if

        if xml <> invalid then
            for each device in xml.Device
                resource = createPlexResource(device)
                Debug("Parsed resource from plex.tv: nodeName:" + resource.name + " type:" + resource.type + " clientIdentifier:" + resource.Get("clientIdentifier") + " name:" + resource.Get("name") + " product:" + resource.Get("product") + " provides:" + resource.Get("provides"))
            next
        end if
    end if
end sub
