'*
'* An implementation of the remote client/player interface that allows the Roku
'* to be controlled by other Plex clients, like the remote built into the
'* iOS/Android apps.
'*
'* Note that all handlers are evaluated in the context of a Reply object.
'*

function ValidateRemoteControlRequest(reply as object) as boolean
    settings = AppSettings()

    if not settings.GetBoolPreference("remotecontrol") then
        SendErrorResponse(reply, 404, "Remote control is disabled for this device")
        return false
    else if reply.request.fields["X-Plex-Target-Client-Identifier"] <> invalid and reply.request.fields["X-Plex-Target-Client-Identifier"] <> settings.GetGlobal("clientIdentifier") then
        SendErrorResponse(reply, 400, "Incorrect value for X-Plex-Target-Client-Identifer")
        return false
    else
        return true
    end if
end function

sub ProcessCommandID(request as object)
    deviceID = request.fields["X-Plex-Client-Identifier"]
    commandID = request.query["commandID"]

    if deviceID <> invalid and commandID <> invalid then
        NowPlayingManager().UpdateCommandID(deviceID, commandID.toint())
    end if
end sub

sub SendErrorResponse(reply as object, code as integer, message as string)
    xml = CreateObject("roXMLElement")
    xml.SetName("Response")
    xml.AddAttribute("code", tostr(code))
    xml.AddAttribute("status", message)
    xmlStr = xml.GenXML(false)

    reply.mimetype = MimeType("xml")
    reply.buf.fromasciistring(xmlStr)
    reply.length = reply.buf.count()
    reply.http_code = code
    reply.genHdr(true)
    reply.source = reply.GENERATED
end sub

function ProcessResourcesRequest() as boolean
    if not ValidateRemoteControlRequest(m) then return true

    mc = CreateObject("roXMLElement")
    mc.SetName("MediaContainer")

    settings = AppSettings()

    player = mc.AddElement("Player")
    player.AddAttribute("protocolCapabilities", "timeline,playback,navigation")
    player.AddAttribute("product", "Plex for Roku")
    player.AddAttribute("version", settings.GetGlobal("appVersionStr"))
    player.AddAttribute("platformVersion", settings.GetGlobal("rokuVersionStr"))
    player.AddAttribute("platform", "Roku")
    player.AddAttribute("machineIdentifier", settings.GetGlobal("clientIdentifier"))
    player.AddAttribute("title", settings.GetGlobal("friendlyName"))
    player.AddAttribute("protocolVersion", "1")
    player.AddAttribute("deviceClass", "stb")

    m.mimetype = MimeType("xml")
    m.simpleOK(mc.GenXML(false))

    return true
end function

function ProcessTimelineSubscribe() as boolean
    if not ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    protocol = firstOf(m.request.query["protocol"], "http")
    port = firstOf(m.request.query["port"], "32400")
    host = m.request.remote_addr
    deviceID = m.request.fields["X-Plex-Client-Identifier"]
    commandID = firstOf(m.request.query["commandID"], "0").toint()

    connectionUrl = protocol + "://" + tostr(host) + ":" + port

    if NowPlayingManager().AddSubscriber(deviceID, connectionUrl, commandID) then
        m.simpleOK("")
    else
        SendErrorResponse(m, 400, "Invalid subscribe request")
    end if

    return true
end function

function ProcessTimelineUnsubscribe() as boolean
    if not ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    deviceID = m.request.fields["X-Plex-Client-Identifier"]
    NowPlayingManager().RemoveSubscriber(deviceID)

    m.simpleOK("")
    return true
end function

function ProcessTimelinePoll() as boolean
    if not ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    m.headers["X-Plex-Client-Identifier"] = AppSettings().GetGlobal("clientIdentifier")
    m.headers["Access-Control-Expose-Headers"] = "X-Plex-Client-Identifier"

    deviceID = m.request.fields["X-Plex-Client-Identifier"]
    commandID = firstOf(m.request.query["commandID"], "0").toint()

    NowPlayingManager().AddPollSubscriber(deviceID, commandID)

    if firstOf(m.request.query["wait"], "0") = "0" then
        xml = NowPlayingManager().TimelineDataXmlForSubscriber(deviceID)
        m.mimetype = MimeType("xml")
        m.simpleOK(xml)
    else
        NowPlayingManager().WaitForNextTimeline(deviceID, m)
    end if

    return true
end function

function ProcessPlaybackPlayMedia() as boolean
    if not ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    machineID = m.request.query["machineIdentifier"]

    if machineID = "node" then
        server = PlexServerManager().GetSelectedServer()
    else
        server = PlexServerManager().GetServer(machineID)
    end if

    if server = invalid then
        port = firstOf(m.request.query["port"], "32400")
        protocol = firstOf(m.request.query["protocol"], "http")
        address = m.request.query["address"]
        token = m.request.query["token"]
        if address = invalid then
            SendErrorResponse(m, 400, "address must be specified")
            return true
        end if

        conn = createPlexConnection(PlexConnectionClass().SOURCE_MANUAL, protocol + "://" + address + ":" + port, true, token)
        server = createPlexServerForConnection(conn)
    end if

    offset = firstOf(m.request.query["offset"], "0").toint()
    key = m.request.query["key"]
    containerKey = firstOf(m.request.query["containerKey"], key)

    ' If we have a container key, fetch the container and look for the matching
    ' item. Otherwise, just fetch the key and use the first result.

    if containerKey = invalid then
        SendErrorResponse(m, 400, "at least one of key or containerKey must be specified")
        return true
    end if

    m.OnMetadataResponse = remoteOnMetadataResponse
    request = createPlexRequest(server, containerKey)
    context = request.CreateRequestContext("metadata", CreateCallable("OnMetadataResponse", m))
    context.offset = offset
    context.key = key
    Application().StartRequest(request, context)

    m.source = m.WAITING
    return true
end function

sub remoteOnMetadataResponse(request as object, response as object, context as object)
    response.ParseResponse()
    children = response.items
    matchIndex = invalid
    success = false
    message = ""

    for i = 0 to children.Count() - 1
        if context.key = children[i].Get("key") then
            matchIndex = i
            item = children[i]
            exit for
        end if
    end for

    ' Be slightly forgiving of mismatched keys if there's only one item.
    if matchIndex = invalid AND children.Count() = 1 then matchIndex = 0

    if matchIndex <> invalid then
        ' If we currently have a video playing, things are tricky. We can't
        ' play anything on top of video or Bad Things happen. But we also
        ' can't quickly close the screen and throw up a new video player
        ' because the new video screen will see the isScreenClosed event
        ' meant for the old video player. So we have to register a callback,
        ' which is always awkward.

        if VideoPlayer().IsActive() then
            ' TODO(schuyler): Handle this case!
            message = "Unable to play media, video player is already active"
            Error(message)
            ' callback = CreateObject("roAssociativeArray")
            ' callback.context = children
            ' callback.contextIndex = matchIndex
            ' callback.seekValue = offset
            ' callback.OnAfterClose = createPlayerAfterClose
            ' GetViewController().CloseScreenWithCallback(callback)
        else
            ' TODO(schuyler): Genericize this for other media types
            ' TODO(schuyler): Handle context in addition to matched item
            if item.IsVideoItem() then
                screen = VideoPlayer().CreateVideoScreen(item, (validint(context.offset) > 0))
                if screen.screenError = invalid then
                    success = true
                    Application().PushScreen(screen)
                else
                    message = screen.screenError
                end if
            else
                message = "Only video is supported at this time"
                Error(message)
            end if

            ' If the screensaver is on, which we can't reliably know, then the
            ' video won't start until the user wakes the Roku up. We can do that
            ' for them by sending a harmless keystroke. Down is harmless, as long
            ' as they started a video or slideshow.
            if success then SendEcpCommand("Down")
        end if
    else
        message = "unable to find media for key"
    end if

    if success then
        m.simpleOK(message)
    else
        SendErrorResponse(m, 400, message)
    end if
end sub

function ProcessPlaybackSeekTo() as boolean
    if not ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    player = GetPlayerForType(m.request.query["type"])
    offset = m.request.query["offset"]

    if player <> invalid and offset <> invalid then
        player.Seek(int(val(offset)))
    end if

    m.simpleOK("")
    return true
end function

function ProcessPlaybackPlay() as boolean
    if not ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    player = GetPlayerForType(m.request.query["type"])

    ' Try to deal with the command directly, falling back to ECP.
    if player <> invalid then
        player.Resume()
    else
        SendEcpCommand("Play")
    end if

    m.simpleOK("")
    return true
end function

function ProcessPlaybackPause() as boolean
    if not ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    player = GetPlayerForType(m.request.query["type"])

    ' Try to deal with the command directly, falling back to ECP.
    if player <> invalid then
        player.Pause()
    else
        SendEcpCommand("Play")
    end if

    m.simpleOK("")
    return true
end function

function ProcessPlaybackStop() as boolean
    if not ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    player = GetPlayerForType(m.request.query["type"])

    ' Try to deal with the command directly, falling back to ECP.
    if player <> invalid then
        player.Stop()
    else
        SendEcpCommand("Back")
    end if

    m.simpleOK("")
    return true
end function

function ProcessPlaybackSkipNext() as boolean
    if not ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    player = GetPlayerForType(m.request.query["type"])

    ' Try to deal with the command directly, falling back to ECP.
    if player <> invalid then
        player.Next()
    else
        SendEcpCommand("Fwd")
    end if

    m.simpleOK("")
    return true
end function

function ProcessPlaybackSkipPrevious() as boolean
    if not ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    player = GetPlayerForType(m.request.query["type"])

    ' Try to deal with the command directly, falling back to ECP.
    if player <> invalid then
        player.Prev()
    else
        SendEcpCommand("Rev")
    end if

    m.simpleOK("")
    return true
end function

function ProcessPlaybackStepBack() as boolean
    if not ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    player = GetPlayerForType(m.request.query["type"])

    ' TODO(schuyler): Should we respect the platform convention for video?

    ' Try to deal with the command directly, falling back to ECP.
    if player <> invalid then
        player.Seek(-15000, true)
    else 
        SendEcpCommand("InstantReplay")
    end if

    m.simpleOK("")
    return true
end function

function ProcessPlaybackStepForward() as boolean
    if not ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    player = GetPlayerForType(m.request.query["type"])

    if player <> invalid then
        player.Seek(30000, true)
    end if

    m.simpleOK("")
    return true
end function

function ProcessPlaybackSetParameters() as boolean
    if not ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    mediaType = m.request.query["type"]

    ' TODO(schuyler): Music and photo playback
    ' if mediaType = "music" then
    '     if m.request.query["shuffle"] <> invalid then
    '         AudioPlayer().SetShuffle(m.request.query["shuffle"].toint())
    '     end if

    '     if m.request.query["repeat"] <> invalid then
    '         AudioPlayer().SetRepeat(m.request.query["repeat"].toint())
    '     end if
    ' else if mediaType = "photo" then
    '     player = PhotoPlayer()
    '     if player <> invalid AND m.request.query["shuffle"] <> invalid then
    '         player.SetShuffle(m.request.query["shuffle"].toint())
    '     end if
    ' end if

    m.simpleOK("")
    return true
end function

function ProcessNavigationMoveRight() as boolean
    if not ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    ' Just use ECP, trying to figure out how to refocus whatever is currently
    ' visible is a mess.
    SendEcpCommand("Right")

    m.simpleOK("")
    return true
end function

function ProcessNavigationMoveLeft() as boolean
    if not ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    ' Just use ECP, trying to figure out how to refocus whatever is currently
    ' visible is a mess.
    SendEcpCommand("Left")

    m.simpleOK("")
    return true
end function

function ProcessNavigationMoveDown() as boolean
    if not ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    ' Just use ECP, trying to figure out how to refocus whatever is currently
    ' visible is a mess.
    SendEcpCommand("Down")

    m.simpleOK("")
    return true
end function

function ProcessNavigationMoveUp() as boolean
    if not ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    ' Just use ECP, trying to figure out how to refocus whatever is currently
    ' visible is a mess.
    SendEcpCommand("Up")

    m.simpleOK("")
    return true
end function

function ProcessNavigationSelect() as boolean
    if not ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    SendEcpCommand("Select")

    m.simpleOK("")
    return true
end function

function ProcessNavigationBack() as boolean
    if not ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    SendEcpCommand("Back")

    m.simpleOK("")
    return true
end function

function ProcessNavigationMusic() as boolean
    if not ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    ' TODO(schuyler): Music
    ' dummyItem = CreateObject("roAssociativeArray")
    ' dummyItem.ContentType = "audio"
    ' dummyItem.Key = "nowplaying"
    ' GetViewController().CreateScreenForItem(dummyItem, invalid, ["Now Playing"])

    m.simpleOK("")
    return true
end function

function ProcessNavigationHome() as boolean
    if not ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    Application().GoHome()

    m.simpleOK("")
    return true
end function

function ProcessApplicationSetText() as boolean
    if not ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    ' TODO(schuyler): Set text?
    ' screen = GetViewController().screens.Peek()

    ' if type(screen.SetText) = "roFunction" AND m.request.query["field"] = NowPlayingManager().textFieldName then
    '     value = firstOf(m.request.query["text"], "")
    '     NowPlayingManager().textFieldContent = value
    '     screen.SetText(value, (m.request.query["complete"] = "1"))
    '     m.simpleOK("")
    ' else
    '     Debug("Illegal remote setText call: " + tostr(m.request.query["field"]) + "/" + tostr(NowPlayingManager().textFieldName))
    '     SendErrorResponse(m, 400, "Invalid setText request")
    ' end if

    m.simpleOK("")
    return true
end function

sub InitRemoteControlHandlers()
    ' Advertising
    ClassReply().AddHandler("/resources", ProcessResourcesRequest)

    ' Timeline
    ClassReply().AddHandler("/player/timeline/subscribe", ProcessTimelineSubscribe)
    ClassReply().AddHandler("/player/timeline/unsubscribe", ProcessTimelineUnsubscribe)
    ClassReply().AddHandler("/player/timeline/poll", ProcessTimelinePoll)

    ' Playback
    ClassReply().AddHandler("/player/playback/playMedia", ProcessPlaybackPlayMedia)
    ClassReply().AddHandler("/player/playback/seekTo", ProcessPlaybackSeekTo)
    ClassReply().AddHandler("/player/playback/play", ProcessPlaybackPlay)
    ClassReply().AddHandler("/player/playback/pause", ProcessPlaybackPause)
    ClassReply().AddHandler("/player/playback/stop", ProcessPlaybackStop)
    ClassReply().AddHandler("/player/playback/skipNext", ProcessPlaybackSkipNext)
    ClassReply().AddHandler("/player/playback/skipPrevious", ProcessPlaybackSkipPrevious)
    ClassReply().AddHandler("/player/playback/stepBack", ProcessPlaybackStepBack)
    ClassReply().AddHandler("/player/playback/stepForward", ProcessPlaybackStepForward)
    ClassReply().AddHandler("/player/playback/setParameters", ProcessPlaybackSetParameters)

    ' Navigation
    ClassReply().AddHandler("/player/navigation/moveRight", ProcessNavigationMoveRight)
    ClassReply().AddHandler("/player/navigation/moveLeft", ProcessNavigationMoveLeft)
    ClassReply().AddHandler("/player/navigation/moveDown", ProcessNavigationMoveDown)
    ClassReply().AddHandler("/player/navigation/moveUp", ProcessNavigationMoveUp)
    ClassReply().AddHandler("/player/navigation/select", ProcessNavigationSelect)
    ClassReply().AddHandler("/player/navigation/back", ProcessNavigationBack)
    ClassReply().AddHandler("/player/navigation/music", ProcessNavigationMusic)
    ClassReply().AddHandler("/player/navigation/home", ProcessNavigationHome)

    ' Application
    ClassReply().AddHandler("/player/application/setText", ProcessApplicationSetText)
end sub

sub SendEcpCommand(command as string)
    Application().StartRequestIgnoringResponse("http://127.0.0.1:8060/keypress/" + command, "", "txt")
end sub

function GetPlayerForType(mediaType as dynamic) as dynamic
    if mediaType = "music" then
        ' return AudioPlayer()
    else if mediaType = "photo" then
        ' return PhotoPlayer()
    else if mediaType = "video" then
        return VideoPlayer()
    end if

    return invalid
end function
