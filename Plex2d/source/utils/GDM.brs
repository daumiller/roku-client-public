function GDMAdvertiser() as object
    if m.GDMAdvertiser = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.OnSocketEvent = gdmAdvertiserOnSocketEvent

        obj.responseString = invalid
        obj.GetResponseString = gdmAdvertiserGetResponseString

        obj.CreateSocket = gdmAdvertiserCreateSocket
        obj.Close = gdmAdvertiserClose
        obj.Refresh = gdmAdvertiserRefresh
        obj.Cleanup = gdmAdvertiserCleanup

        m.GDMAdvertiser = obj

        obj.Refresh()
    end if

    return m.GDMAdvertiser
end function

sub gdmAdvertiserCreateSocket()
    listenAddr = CreateObject("roSocketAddress")
    listenAddr.setPort(32412)
    listenAddr.setAddress("0.0.0.0")

    udp = CreateObject("roDatagramSocket")

    if not udp.setAddress(listenAddr) then
        Error("Failed to set address on GDM advertiser socket")
        return
    end if

    if not udp.setBroadcast(true) then
        Error("Failed to set broadcast on GDM advertiser socket")
        return
    end if

    udp.notifyReadable(true)
    udp.setMessagePort(Application().port)

    m.socket = udp

    Application().AddSocketCallback(udp, createCallable("OnSocketEvent", m))

    Debug("Created GDM player advertiser")
end sub

sub gdmAdvertiserClose()
    if m.socket <> invalid then
        m.socket.Close()
        m.socket = invalid
    end if
end sub

sub gdmAdvertiserRefresh()
    ' Always regenerate our response, even if it might not have changed, it's
    ' just not that expensive.
    m.responseString = invalid

    enabled = (AppSettings().GetPreference("remotecontrol", "1") = "1")
    if enabled AND m.socket = invalid then
        m.CreateSocket()
    else if not enabled AND m.socket <> invalid then
        m.Close()
    end if
end sub

sub gdmAdvertiserCleanup()
    m.Close()
    fn = function() :m.GDMAdvertiser = invalid :end function
    fn()
end sub

sub gdmAdvertiserOnSocketEvent(msg as object)
    ' PMS polls every five seconds, so this is chatty when not debugging.
    ' Debug("Got a GDM advertiser socket event, is readable: " + tostr(m.socket.isReadable()))

    if m.socket.isReadable() then
        message = m.socket.receiveStr(4096)
        endIndex = instr(1, message, chr(13)) - 1
        if endIndex <= 0 then endIndex = message.Len()
        line = Mid(message, 1, endIndex)

        if line = "M-SEARCH * HTTP/1.1" then
            response = m.GetResponseString()

            ' Respond directly to whoever sent the search message.
            sock = CreateObject("roDatagramSocket")
            sock.setSendToAddress(m.socket.getReceivedFromAddress())
            bytesSent = sock.sendStr(response)
            sock.Close()
            if bytesSent <> Len(response) then
                Error("GDM player response only sent " + tostr(bytesSent) + " bytes out of " + tostr(Len(response)))
            end if
        else
            Error("Received unexpected message on GDM advertiser socket: " + tostr(line) + ";")
        end if
    end if
end sub

function gdmAdvertiserGetResponseString() as string
    if m.responseString = invalid then
        buf = box("HTTP/1.0 200 OK" + WinNL())

        settings = AppSettings()

        appendNameValue(buf, "Name", settings.GetPreference("player_name", settings.GetGlobal("rokuModel")))
        appendNameValue(buf, "Port", WebServer().port.tostr())
        appendNameValue(buf, "Product", "Plex for Roku")
        appendNameValue(buf, "Content-Type", "plex/media-player")
        appendNameValue(buf, "Protocol", "plex")
        appendNameValue(buf, "Protocol-Version", "1")
        appendNameValue(buf, "Protocol-Capabilities", "timeline,playback,navigation")
        appendNameValue(buf, "Version", settings.GetGlobal("appVersionStr"))
        appendNameValue(buf, "Resource-Identifier", settings.GetGlobal("clientIdentifier"))
        appendNameValue(buf, "Device-Class", "stb")

        m.responseString = buf

        Debug("Built GDM player response:" + m.responseString)
    end if

    return m.responseString
end function

sub appendNameValue(buf, name, value)
    line = name + ": " + value + WinNL()
    buf.AppendString(line, Len(line))
end sub
