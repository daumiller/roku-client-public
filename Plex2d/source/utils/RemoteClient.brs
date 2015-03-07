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
    player.AddAttribute("protocolCapabilities", "timeline,playback,navigation,playqueues")
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

    ' If we were sent a play queue, then assume ownership and use the play queue
    ' instead of fetching the container key ourselves.

    tokens = containerKey.Tokenize("/?")
    contentType = m.request.query["type"]
    if contentType = "music" then contentType = "audio"

    if tokens.Count() >= 2 and tokens[0] = "playQueues" then
        playQueueId = tokens[1].toint()
        requestKey = firstOf(key, containerKey)
    else
        playQueueId = invalid
        requestKey = containerKey
    end if

    m.OnMetadataResponse = remoteOnMetadataResponse
    request = createPlexRequest(server, requestKey)
    context = request.CreateRequestContext("metadata", CreateCallable("OnMetadataResponse", m))
    context.offset = offset
    context.key = key
    context.playQueueId = playQueueId
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
            if item.IsVideoItem() then
                player = VideoPlayer()
                pqType = "video"
                player.shouldResume = (validint(context.offset) > 0)
            else if item.IsMusicItem() then
                player = AudioPlayer()
                pqType = "audio"
            else
                player = invalid
                pqType = invalid
            end if

            if player <> invalid then
                if context.playQueueId <> invalid then
                    pq = createPlayQueueForId(request.server, pqType, context.playQueueId)
                else
                    pq = createPlayQueueForItem(item)
                end if
                player.SetPlayQueue(pq, true)
                success = true
            else
                message = "Only music and video are supported at this time"
                Error(message)
            end if

            ' If the screensaver is on, which we can't reliably know, then the
            ' video won't start until the user wakes the Roku up. We can do that
            ' for them by sending a harmless keystroke. Down is harmless, as long
            ' as they started a video or slideshow.
            ' TODO(schuyler): Should we do this conditionally based on idle time?
            if success then SendEcpCommand("Lit_a")
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
    player = GetPlayerForType(m.request.query["type"])

    if player <> invalid then
        if m.request.query["shuffle"] <> invalid and (mediaType = "music" or mediaType = "photo") then
            player.SetShuffle(m.request.query["shuffle"] = "1")
        end if

        if m.request.query["repeat"] <> invalid and mediaType = "music" then
            player.SetRepeat(m.request.query["repeat"].toint())
        end if
    end if

    m.simpleOK("")
    return true
end function

function ProcessPlaybackRefreshPlayQueue() as boolean
    if not ValidateRemoteControlRequest(m) then return true
    ProcessCommandID(m.request)

    playQueue = invalid

    ' TODO(schuyler): Support more than audio. Make it easy to look up a PQ by ID?
    if AudioPlayer().playQueue <> invalid and tostr(AudioPlayer().playQueue.id) = m.request.query["playQueueID"] then
        playQueue = AudioPlayer().playQueue
    end if

    if playQueue <> invalid then
        playQueue.Refresh(true)
        m.simpleOK("")
    else
        SendErrorResponse(m, 400, "Invalid Play Queue ID")
    end if

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

    Application().PushScreen(createNowPlayingScreen(AudioPlayer().GetCurrentItem()))

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
    router = ClassReply()

    ' Advertising
    router.AddHandler("/resources", ProcessResourcesRequest)

    ' Timeline
    router.AddHandler("/player/timeline/subscribe", ProcessTimelineSubscribe)
    router.AddHandler("/player/timeline/unsubscribe", ProcessTimelineUnsubscribe)
    router.AddHandler("/player/timeline/poll", ProcessTimelinePoll)

    ' Playback
    router.AddHandler("/player/playback/playMedia", ProcessPlaybackPlayMedia)
    router.AddHandler("/player/playback/seekTo", ProcessPlaybackSeekTo)
    router.AddHandler("/player/playback/play", ProcessPlaybackPlay)
    router.AddHandler("/player/playback/pause", ProcessPlaybackPause)
    router.AddHandler("/player/playback/stop", ProcessPlaybackStop)
    router.AddHandler("/player/playback/skipNext", ProcessPlaybackSkipNext)
    router.AddHandler("/player/playback/skipPrevious", ProcessPlaybackSkipPrevious)
    router.AddHandler("/player/playback/stepBack", ProcessPlaybackStepBack)
    router.AddHandler("/player/playback/stepForward", ProcessPlaybackStepForward)
    router.AddHandler("/player/playback/setParameters", ProcessPlaybackSetParameters)
    router.AddHandler("/player/playback/refreshPlayQueue", ProcessPlaybackRefreshPlayQueue)

    ' Navigation
    router.AddHandler("/player/navigation/moveRight", ProcessNavigationMoveRight)
    router.AddHandler("/player/navigation/moveLeft", ProcessNavigationMoveLeft)
    router.AddHandler("/player/navigation/moveDown", ProcessNavigationMoveDown)
    router.AddHandler("/player/navigation/moveUp", ProcessNavigationMoveUp)
    router.AddHandler("/player/navigation/select", ProcessNavigationSelect)
    router.AddHandler("/player/navigation/back", ProcessNavigationBack)
    router.AddHandler("/player/navigation/music", ProcessNavigationMusic)
    router.AddHandler("/player/navigation/home", ProcessNavigationHome)

    ' Application
    router.AddHandler("/player/application/setText", ProcessApplicationSetText)
end sub

sub SendEcpCommand(command as string)
    Application().StartRequestIgnoringResponse("http://127.0.0.1:8060/keypress/" + command, "", "txt")
end sub
