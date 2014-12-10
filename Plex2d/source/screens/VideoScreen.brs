function VideoScreen() as object
    if m.VideoScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(BaseScreen())

        obj.Show = vsShow
        obj.HandleMessage = vsHandleMessage
        obj.Cleanup = vsCleanup
        obj.Init = vsInit

        obj.Pause = vsPause
        obj.Resume = vsResume
        obj.Next = vsNext
        obj.Prev = vsPrev
        obj.Stop = vsStop
        obj.Seek = vsSeek

        m.VideoScreen = obj
    end if

    return m.VideoScreen
end function

function createVideoScreen(item as object, seekValue=invalid as dynamic) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(VideoScreen())

    obj.Init(item, seekValue)

    return obj
end function

sub vsInit(item as object, seekValue=invalid as dynamic)
    ApplyFunc(BaseScreen().Init, m)
    Debug("MediaPlayer::playVideo: Displaying video: " + tostr(item.GetLongerTitle()))

    m.playBackError = false
    m.item = item
    m.seekValue = firstOf(seekValue, 0)


    ' TODO(rob): videoItem = server.ConstructVideoItem (plexnet)
    m.videoObject = CreateVideoObject(m.item, m.seekValue)
    videoItem = m.videoObject.videoItem
    if videoItem = invalid then
        Fatal("invalid video item")
    end if

    screen = CreateObject("roVideoScreen")
    screen.SetMessagePort(Application().port)
    screen.SetPositionNotificationPeriod(1)
    screen.EnableCookies()

    ' TODO(rob): helper required to add token with appropriate
    'if server.IsRequestToServer(videoItem.StreamUrls[0]) then
    AddPlexHeaders(screen, m.item.GetServer().GetToken())
    'end if

    screen.SetCertificatesFile("common:/certs/ca-bundle.crt")
    screen.SetCertificatesDepth(5)

    screen.SetContent(videoItem)

    ' TODO(rob): other headers (non direct play)
    m.IsTranscoded = videoItem.IsTranscoded
    'if m.IsTranscoded then
    '    cookie = server.StartTranscode(videoItem.StreamUrls[0])
    '    if cookie <> invalid then
    '        screen.AddHeader("Cookie", cookie)
    '    end if
    'else
    '    for each header in videoItem.IndirectHttpHeaders
    '        for each name in header
    '            screen.AddHeader(name, header[name])
    '        next
    '    next
    'end if

    m.screen = screen
end sub

sub vsShow()
    if m.Screen <> invalid then
        if m.IsTranscoded then
            ' TODO(rob): log to pms
            'Debug("Starting to play transcoded video", m.item.GetServer())

            ' TODO(rob): pingTimer
            'if m.pingTimer = invalid then
            '    m.pingTimer = createTimer()
            '    m.pingTimer.Name = "ping"
            '    m.pingTimer.SetDuration(60005, true)
            '    m.ViewController.AddTimer(m.pingTimer, m)
            'end if
            'm.pingTimer.Active = true
            'm.pingTimer.Mark()
        else
            ' TODO(rob): log to pms
            'Debug("Starting to direct play video", m.item.GetServer())
        end if

        ' TODO(rob): timers: timeline & playback, nowPlayingManager.location=fullScreenVideo
        m.Screen.Show()
    else
       ' TODO(rob): nowPlayingManager.location=navigation
        Application().PopScreen(m)
    end if
end sub

sub vsCleanup()
    Debug("vsCleanup::no-op")
end sub

sub vsShowPlaybackError()
    Debug("vsShowPlaybackError::no-op")
end sub

function vsHandleMessage(msg) as boolean
    handled = false
    server = m.item.GetServer()

    if type(msg) = "roVideoScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            ' TODO(rob): timelines, fallback, parts, etc.. look at original
            Application().PopScreen(m)
        else if msg.isPlaybackPosition() then
            'mediaItem = m.Item.preferredMediaItem
            'm.lastPosition = m.curPartOffset + msg.GetIndex()
            'Debug("MediaPlayer::playVideo::VideoScreenEvent::isPlaybackPosition: set progress -> " + tostr(1000*m.lastPosition))
            Debug("isPlaybackPosition: " + tostr(msg.GetIndex()))

            'if mediaItem <> invalid AND validint(mediaItem.duration) > 0 then
            '    playedFraction = (m.lastPosition * 1000)/mediaItem.duration
            '    if playedFraction > 0.90 then
            '        m.isPlayed = true
            '    end if
            'end if

            'if m.bufferingTimer <> invalid AND msg.GetIndex() > 0 then
            '    AnalyticsTracker().TrackTiming(m.bufferingTimer.GetElapsedMillis(), "buffering", tostr(m.IsTranscoded), tostr(m.Item.mediaContainerIdentifier))
            '    m.bufferingTimer = invalid
            'else
            '    m.playState = "playing"
            '    m.UpdateNowPlaying(true)
            'end if
        else if msg.isRequestFailed() then
            Debug("vsHandleMessage::isRequestFailed - message = " + tostr(msg.GetMessage()))
            Debug("vsHandleMessage::isRequestFailed - data = " + tostr(msg.GetData()))
            Debug("vsHandleMessage::isRequestFailed - index = " + tostr(msg.GetIndex()))
            m.playbackError = true
        else if msg.isPaused() then
            Debug("vsHandleMessage::isPaused: position -> " + tostr(m.lastPosition))
            m.playState = "paused"
            'm.UpdateNowPlaying()
        else if msg.isResumed() then
            Debug("vsHandleMessage::isResumed")
            m.playState = "playing"
            'm.UpdateNowPlaying()
        else if msg.isPartialResult() then
            Debug("vsHandleMessage::isPartialResult: position -> " + tostr(m.lastPosition))
            m.playState = "stopped"
            'm.UpdateNowPlaying()
            'if m.IsTranscoded then server.StopVideo()
        else if msg.isFullResult() then
            Debug("vsHandleMessage::isFullResult: position -> " + tostr(m.lastPosition))
            m.isPlayed = true
            m.playState = "stopped"
            'm.UpdateNowPlaying()
            'if m.IsTranscoded then server.StopVideo()
        else if msg.isStreamStarted() then
            Debug("vsHandleMessage::isStreamStarted: position -> " + tostr(m.lastPosition))
            Debug("Message data -> " + tostr(msg.GetInfo()))

            ' m.StartTranscodeSessionRequest()

            ' TODO(rob): handle underrun warning
            'if msg.GetInfo().IsUnderrun = true then
            '    m.underrunCount = m.underrunCount + 1
            '    if m.underrunCount = 4 and not GetGlobalAA().DoesExist("underrun_warning_shown") then
            '        GetGlobalAA().AddReplace("show_underrun_warning", "1")
            '    end if
            'end if
        else if msg.GetType() = 31 then
            ' TODO(schuyler): DownloadDuration is completely incomprehensible to me.
            ' It doesn't seem like it could be seconds or milliseconds, and I couldn't
            ' seem to do anything to artificially affect it by tweaking PMS.
            segInfo = msg.GetInfo()
            Debug("Downloaded segment " + tostr(segInfo.Sequence) + " in " + tostr(segInfo.DownloadDuration) + "?s (" + tostr(segInfo.SegSize) + " bytes, buffer is now " + tostr(segInfo.BufferLevel) + "/" + tostr(segInfo.BufferSize))
        else if msg.GetType() = 27 then
            ' This is an HLS Segment Info event. We don't really need to do
            ' anything with it. It includes info like the stream bandwidth,
            ' sequence, URL, and start time.
        else
            Debug("Unknown event: " + tostr(msg.GetType()) + " msg: " + tostr(msg.GetMessage()))
        end if
    end if

    return handled
end function

sub vsPause()
    if m.Screen <> invalid then
        m.Screen.Pause()
    end if
end sub

sub vsResume()
    if m.Screen <> invalid then
        m.Screen.Resume()
    end if
end sub

sub vsNext()
end sub

sub vsPrev()
end sub

sub vsStop()
    if m.Screen <> invalid then
        m.Screen.Close()
    end if
end sub

sub vsSeek(offset, relative=false)
    if m.Screen <> invalid then
        if relative then
            offset = offset + (1000 * m.lastPosition)
            if offset < 0 then offset = 0
        end if

        if m.playState = "paused" then
            m.Screen.Resume()
            m.Screen.Seek(offset)
        else
            m.Screen.Seek(offset)
        end if
    end if
end sub
