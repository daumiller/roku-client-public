' GDM Advertising

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

    enabled = AppSettings().GetBoolPreference("remotecontrol")
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

        appendNameValue(buf, "Name", settings.GetGlobal("friendlyName"))
        appendNameValue(buf, "Port", WebServer().port.tostr())
        appendNameValue(buf, "Product", "Plex for Roku")
        appendNameValue(buf, "Content-Type", "plex/media-player")
        appendNameValue(buf, "Protocol", "plex")
        appendNameValue(buf, "Protocol-Version", "1")
        appendNameValue(buf, "Protocol-Capabilities", "timeline,playback,navigation,playqueues")
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


' GDM Discovery

function GDMDiscovery() as object
    if m.GDMDiscovery = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.Discover = gdmDiscoveryDiscover
        obj.OnSocketEvent = gdmDiscoveryOnSocketEvent
        obj.OnTimer = gdmDiscoveryOnTimer

        obj.Close = gdmDiscoveryClose
        obj.Cleanup = gdmDiscoveryCleanup

        m.GDMDiscovery = obj
    end if

    return m.GDMDiscovery
end function

sub gdmDiscoveryDiscover()
    ' Only if enabled and not currently running
    if not AppSettings().GetBoolPreference("gdm_discovery") or m.socket <> invalid then return

    message = "M-SEARCH * HTTP/1.1" + WinNL() + WinNL()

    ' Broadcasting to 255.255.255.255 only works on some Rokus, but we
    ' can't reliably determine the broadcast address for our current
    ' interface. Try assuming a /24 network, and then fall back to the
    ' multicast address if that doesn't work.

    multicast = "239.0.0.250"
    ip = multicast
    subnetRegex = CreateObject("roRegex", "((\d+)\.(\d+)\.(\d+)\.)(\d+)", "")
    addr = GetFirstIPAddress()
    if addr <> invalid then
        match = subnetRegex.Match(addr)
        if match.Count() > 0 then
            ip = match[1] + "255"
            Debug("Using broadcast address " + ip)
        end if
    end if

    ' Socket things sometimes fail for no good reason, so try a few times.
    try = 0
    success = false

    while try < 5 and not success
        udp = CreateObject("roDatagramSocket")
        udp.setMessagePort(Application().port)
        udp.setBroadcast(true)

        ' More things that have been observed to be flaky.
        for i = 0 to 5
            addr = CreateObject("roSocketAddress")
            addr.setHostName(ip)
            addr.setPort(32414)
            udp.setSendToAddress(addr)

            sendTo = udp.getSendToAddress()
            if sendTo <> invalid then
                sendToStr = tostr(sendTo.getAddress())
                addrStr = tostr(addr.getAddress())
                Debug("GDM sendto address: " + sendToStr + " / " + addrStr)
                if sendToStr = addrStr then exit for
            end if

            Error("Failed to set GDM sendto address")
        next

        udp.notifyReadable(true)
        bytesSent = udp.sendStr(message)
        Debug("Sent " + tostr(bytesSent) + " bytes")
        if bytesSent > 0 then
            success = udp.eOK()
        else
            success = false
            if bytesSent = 0 and ip <> multicast then
                Info("Falling back to multicast address")
                ip = multicast
                try = 0
            end if
        end if

        if success then
            exit while
        else if try = 4 and ip <> multicast then
            Info("Falling back to multicast address")
            ip = multicast
            try = 0
        else
            sleep(500)
            Warn("Retrying GDM, errno=" + tostr(udp.status()))
            try = try + 1
        end if
    end while

    if success then
        Debug("Successfully sent GDM discovery message, waiting for servers")
        m.servers = CreateObject("roList")
        m.timer = createTimer("gdm")
        m.timer.SetDuration(5000)
        m.socket = udp
        Application().AddSocketCallback(udp, createCallable("OnSocketEvent", m))
        Application().AddTimer(m.timer, createCallable("OnTimer", m))
    else
        Error("Failed to send GDM discovery message")
        PlexServerManager().UpdateFromConnectionType([], PlexConnectionClass().SOURCE_DISCOVERED)
    end if
end sub

sub gdmDiscoveryOnSocketEvent(msg as object)
    if msg.getSocketID() <> m.socket.getID() or not m.socket.isReadable() then return

    message = m.socket.receiveStr(4096)

    Debug("Received GDM message: '" + tostr(message) + "'")

    addr = m.socket.getReceivedFromAddress()
    hostname = addr.getHostName()

    name = parseFieldValue(message, "Name: ")
    port = firstOf(parseFieldValue(message, "Port: "), "32400")
    machineID = parseFieldValue(message, "Resource-Identifier: ")
    secureHost = parseFieldValue(message, "Host: ")

    Debug("Received GDM response for " + tostr(name) + " at http://" + hostname + ":" + port)

    if name = invalid or machineID = invalid then return

    conn = createPlexConnection(PlexConnectionClass().SOURCE_DISCOVERED, "http://" + hostname + ":" + port, true, invalid)
    server = createPlexServerForConnection(conn)
    server.uuid = machineID
    server.name = name

    ' If the server advertised a secure hostname, add a secure connection as well
    if secureHost <> invalid then
        server.connections.Push(createPlexConnection(PlexConnectionClass().SOURCE_DISCOVERED, "https://" + hostname.Replace(".", "-") + "." + secureHost + ":" + port, true, invalid))
    end if

    m.servers.AddTail(server)
end sub

sub gdmDiscoveryOnTimer(timer as object)
    ' Time's up, report whatever we found

    m.Close()

    Debug("Finished GDM discovery, found " + m.servers.Count().tostr() + " server(s)")

    PlexServerManager().UpdateFromConnectionType(m.servers, PlexConnectionClass().SOURCE_DISCOVERED)

    m.servers.Clear()
    m.servers = invalid
    m.timer = invalid
end sub

sub gdmDiscoveryClose()
    if m.socket <> invalid then
        m.socket.Close()
        m.socket = invalid
    end if
end sub

sub gdmDiscoveryCleanup()
    m.Close()
    fn = function() :m.GDMDiscovery = invalid :end function
    fn()
end sub

function parseFieldValue(message as string, label as string) as dynamic
    startPos = instr(1, message, label)
    if startPos <= 0 then return invalid
    startPos = startPos + Len(label)
    endPos = instr(startPos, message, chr(13))
    return Mid(message, startPos, endPos - startPos)
end function
