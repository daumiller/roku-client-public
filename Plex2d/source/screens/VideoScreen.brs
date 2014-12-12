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

        obj.UpdateNowPlaying = vcUpdateNowPlaying
        obj.OnTimelineTimer = vcOnTimelineTimer

        m.VideoScreen = obj
    end if

    return m.VideoScreen
end function

function createVideoScreen(item as object, resume=false as boolean) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(VideoScreen())

    obj.item = item
    obj.seekValue = iif(resume, item.GetInt("viewOffset"), 0)

    obj.Init()

    return obj
end function

sub vsInit()
    ApplyFunc(BaseScreen().Init, m)
    Debug("init videoscreen: " + tostr(m.item.GetLongerTitle()))

    ' variables
    m.lastPosition = 0
    m.playBackError = false
    m.isPlayed = false
    m.playState = "buffering"

    ' TODO(rob): timers
    m.bufferingTimer = createTimer("buffering")
    m.playbackTimer = createTimer("playback")
    m.timelineTimer = invalid

    ' TODO(rob): multi-parts offset (curPartOffset)
    m.curPartOffset = 0

    m.videoObject = CreateVideoObject(m.item, m.seekValue)
    videoItem = m.videoObject.videoItem
    ' TODO(rob): better UX error handling
    if videoItem = invalid then
        m.screenError = "invalid video item"
        return
    end if

    screen = CreateObject("roVideoScreen")
    screen.SetMessagePort(Application().port)
    screen.SetPositionNotificationPeriod(1)
    screen.EnableCookies()

    ' Add appropriate X-Plex header if it's a reqeust to the server
    if videoItem.server <> invalid and videoItem.server.IsRequestToServer(videoItem.StreamUrls[0]) then
        AddPlexHeaders(screen, videoItem.server.GetToken())
    end if

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

        m.timelineTimer = createTimer("timeline")
        m.timelineTimer.SetDuration(15000, true)
        Application().AddTimer(m.timelineTimer, createCallable("OnTimelineTimer", m))

        m.playbackTimer.Mark()
        m.bufferingTimer.Mark()
        m.Screen.Show()
        NowPlayingManager().location = "fullScreenVideo"
    else
        NowPlayingManager().location = "navigation"
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
            ' if m.IsTranscoded then server.StopVideo()

            ' Send an analytics event.
            startOffset = int(m.SeekValue/1000)
            amountPlayed = m.lastPosition - startOffset
            if amountPlayed > m.playbackTimer.GetElapsedSeconds() then amountPlayed = m.playbackTimer.GetElapsedSeconds()

            if amountPlayed > 0 then
                Debug("Sending analytics event, appear to have watched video for " + tostr(amountPlayed) + " seconds")
                Analytics().TrackEvent("Playback", m.item.Get("type", "clip"), tostr(m.item.container.Get("identifier")), amountPlayed)
            end if

            m.timelineTimer.active = false
            m.playState = "stopped"
            Debug("vsHandleMessage::isScreenClosed: position -> " + tostr(m.lastPosition))
            NowPlayingManager().location = "navigation"
            m.UpdateNowPlaying()

            ' TODO(rob): multi-parts and fallback transcode
            Application().PopScreen(m)
        else if msg.isPlaybackPosition() then
            m.lastPosition = m.curPartOffset + msg.GetIndex()
            Debug("vsHandleMessage::isPlaybackPosition: set progress -> " + tostr(1000*m.lastPosition))

            duration = int(val(m.videoObject.media.Get("duration","0")))
            if duration > 0 then
                playedFraction = (m.lastPosition * 1000)/duration
                if playedFraction > 0.90 then
                    m.isPlayed = true
                end if
            end if

            if m.bufferingTimer <> invalid AND msg.GetIndex() > 0 then
                ' TODO(rob): should the identifier be accessible from the item (plexnet?) -- m.item.container.Get("identifier")
                Analytics().TrackTiming(m.bufferingTimer.GetElapsedMillis(), "buffering", tostr(m.IsTranscoded), tostr(m.item.container.Get("identifier")))
                m.bufferingTimer = invalid
            else
                m.playState = "playing"
                m.UpdateNowPlaying(true)
            end if
        else if msg.isRequestFailed() then
            Debug("vsHandleMessage::isRequestFailed - message = " + tostr(msg.GetMessage()))
            Debug("vsHandleMessage::isRequestFailed - data = " + tostr(msg.GetData()))
            Debug("vsHandleMessage::isRequestFailed - index = " + tostr(msg.GetIndex()))
            m.playbackError = true
        else if msg.isPaused() then
            Debug("vsHandleMessage::isPaused: position -> " + tostr(m.lastPosition))
            m.playState = "paused"
            m.UpdateNowPlaying()
        else if msg.isResumed() then
            Debug("vsHandleMessage::isResumed")
            m.playState = "playing"
            m.UpdateNowPlaying()
        else if msg.isPartialResult() then
            Debug("vsHandleMessage::isPartialResult: position -> " + tostr(m.lastPosition))
            m.playState = "stopped"
            m.UpdateNowPlaying()
            'if m.IsTranscoded then server.StopVideo()
        else if msg.isFullResult() then
            Debug("vsHandleMessage::isFullResult: position -> " + tostr(m.lastPosition))
            m.isPlayed = true
            m.playState = "stopped"
            m.UpdateNowPlaying()
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

sub vcUpdateNowPlaying(force=false as boolean)
    ' We can only send the event if we have some basic info about the item
    if m.item.Get("ratingKey") = invalid or m.item.Get("duration") = invalid or m.item.GetServer() = invalid then
        m.timelineTimer.Active = false
        return
    end if

    ' Avoid duplicates
    if m.playState = m.lastTimelineState and not force then return

    m.lastTimelineState = m.playState
    m.timelineTimer.Mark()

    NowPlayingManager().UpdatePlaybackState("video", m.item, m.playState, 1000 * m.lastPosition)
    Debug("vcUpdateNowPlaying:: " + m.playState + " " + tostr(1000 * m.lastPosition))
end sub

sub vcOnTimelineTimer(timer as dynamic)
    Debug("vcOnTimelineTimer::expired " + tostr(timer.name))
    m.UpdateNowPlaying()
end sub
