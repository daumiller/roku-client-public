function VideoPlayer() as object
    if m.VideoPlayer = invalid then
        obj = CreateObject("roAssociativeArray")

        ' This is both an implementation of our player API (Pause, Resume, etc.)
        ' and responsible for the actual screen playing the video. So we
        ' inherit from BaseScreen even though we're a long-lived singleton.
        '
        obj.Append(BaseScreen())

        ' Screen functions
        obj.Show = vpShow
        obj.HandleMessage = vpHandleMessage
        obj.Init = vpInit
        obj.Cleanup = vpCleanup

        ' Player API functions
        obj.IsActive = vpIsActive
        obj.Pause = vpPause
        obj.Resume = vpResume
        obj.Stop = vpStop
        obj.Seek = vpSeek
        obj.Prev = vpPrev
        obj.Next = vpNext

        obj.CreateVideoScreen = vpCreateVideoScreen

        obj.UpdateNowPlaying = vpUpdateNowPlaying
        obj.OnTimelineTimer = vpOnTimelineTimer
        obj.OnPingTimer = vpOnPingTimer
        obj.SendTranscoderCommand = vpSendTranscoderCommand

        obj.RequestTranscodeSessionInfo = vpRequestTranscodeSessionInfo
        obj.OnTranscodeInfoResponse = vpOnTranscodeInfoResponse

        m.VideoPlayer = obj
    end if

    return m.VideoPlayer
end function

function vpCreateVideoScreen(item as object, resume=false as boolean) as object
    ' We're supposed to create a video screen for a new item, we better not have
    ' an old screen still.
    '
    if m.screen <> invalid then
        Fatal("Can't create video screen on top of existing screen!")
    end if

    m.item = item
    m.seekValue = iif(resume, item.GetInt("viewOffset"), 0)

    ' To the extent that we're pretending to be a simple screen instance, we
    ' were just created. So go ahead and call Init, get a new screen ID, etc.
    '
    m.Init()

    return m
end function

sub vpInit()
    m.screenID = invalid
    ApplyFunc(BaseScreen().Init, m)
    Debug("init videoscreen: " + tostr(m.item.GetLongerTitle()))

    ' variables
    m.lastPosition = 0
    m.playBackError = false
    m.isPlayed = false
    m.playState = "buffering"

    m.bufferingTimer = createTimer("buffering")
    m.playbackTimer = createTimer("playback")
    m.timelineTimer = invalid
    m.pingTimer = invalid

    ' TODO(rob): multi-parts offset (curPartOffset)
    m.curPartOffset = 0

    settings = AppSettings()
    allowDirectPlay = settings.GetBoolPreference("playback_direct")
    allowDirectStream = settings.GetBoolPreference("playback_remux")
    allowTranscode = settings.GetBoolPreference("playback_transcode")

    directPlay = iif(allowDirectPlay, iif(allowDirectStream or allowTranscode, invalid, true), false)

    videoItem = CreateVideoObject(m.item, m.seekValue).Build(directPlay, allowDirectStream)

    ' TODO(rob): better UX error handling
    if videoItem = invalid then
        m.screenError = "invalid video item"
        return
    end if

    screen = CreateObject("roVideoScreen")
    screen.SetMessagePort(Application().port)
    screen.SetPositionNotificationPeriod(1)
    screen.SetCertificatesFile("common:/certs/ca-bundle.crt")
    screen.SetCertificatesDepth(5)
    screen.EnableCookies()

    ' Add appropriate X-Plex header if it's a reqeust to the server
    ' Always add X-Plex headers, but not a token. It's possible that the
    ' transcode server and original media server (with subtitles, BIFs, etc.)
    ' will be different. Anything that needs a token will have it added to the
    ' URL.
    '
    AddPlexHeaders(screen)

    screen.SetContent(videoItem)

    m.IsTranscoded = videoItem.IsTranscoded

    ' TODO(schuyler): Extra headers for direct play of indirect items

    m.screen = screen
    m.videoItem = videoItem
end sub

sub vpCleanup()
    ' We're cleaning up after our screen, not anything long-lived.

    timers = ["pingTimer", "timelineTimer", "playbackTimer", "bufferingTimer"]
    for each name in timers
        if m[name] <> invalid then
            m[name].active = false
            m[name] = invalid
        end if
    next

    m.playState = "stopped"
    m.screen = invalid
end sub

sub vpShow()
    if m.Screen <> invalid then
        if m.IsTranscoded then
            ' TODO(rob): log to pms
            'Debug("Starting to play transcoded video", m.item.GetServer())

            m.pingTimer = createTimer("ping")
            m.pingTimer.SetDuration(60005, true)
            Application().AddTimer(m.pingTimer, createCallable("OnPingTimer", m))
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

function vpHandleMessage(msg) as boolean
    handled = false
    server = m.item.GetServer()

    if type(msg) = "roVideoScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            m.SendTranscoderCommand("stop")

            ' Send an analytics event.
            startOffset = int(m.SeekValue/1000)
            amountPlayed = m.lastPosition - startOffset
            if amountPlayed > m.playbackTimer.GetElapsedSeconds() then amountPlayed = m.playbackTimer.GetElapsedSeconds()

            if amountPlayed > 0 then
                Debug("Sending analytics event, appear to have watched video for " + tostr(amountPlayed) + " seconds")
                Analytics().TrackEvent("Playback", m.item.Get("type", "clip"), tostr(m.item.container.Get("identifier")), amountPlayed)
            end if

            m.playState = "stopped"
            Debug("vsHandleMessage::isScreenClosed: position -> " + tostr(m.lastPosition))
            NowPlayingManager().location = "navigation"
            m.UpdateNowPlaying()

            ' TODO(rob): multi-parts and fallback transcode
            Application().PopScreen(m)

            m.Cleanup()
        else if msg.isPlaybackPosition() then
            m.lastPosition = m.curPartOffset + msg.GetIndex()
            Debug("vsHandleMessage::isPlaybackPosition: set progress -> " + tostr(1000*m.lastPosition))

            duration = m.videoItem.duration
            if duration > 0 then
                playedFraction = (m.lastPosition * 1000)/duration
                if playedFraction > 0.90 then
                    m.isPlayed = true
                end if
            end if

            if msg.GetIndex() > 0 then
                if m.bufferingTimer <> invalid then
                    Analytics().TrackTiming(m.bufferingTimer.GetElapsedMillis(), "buffering", tostr(m.IsTranscoded), tostr(m.item.GetIdentifier()))
                    m.bufferingTimer = invalid
                end if

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
            m.SendTranscoderCommand("stop")
        else if msg.isFullResult() then
            Debug("vsHandleMessage::isFullResult: position -> " + tostr(m.lastPosition))
            m.isPlayed = true
            m.playState = "stopped"
            m.UpdateNowPlaying()
            m.SendTranscoderCommand("stop")
        else if msg.isStreamStarted() then
            Debug("vsHandleMessage::isStreamStarted: position -> " + tostr(m.lastPosition))
            Debug("Message data -> " + tostr(msg.GetInfo()))

            m.RequestTranscodeSessionInfo()

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

function vpIsActive() as boolean
    return (m.screen <> invalid)
end function

sub vpPause()
    if m.screen <> invalid then
        m.screen.Pause()
    end if
end sub

sub vpResume()
    if m.screen <> invalid then
        m.screen.Resume()
    end if
end sub

sub vpStop()
    if m.screen <> invalid then
        m.screen.Close()
    end if
end sub

sub vpSeek(offset, relative=false as boolean)
    if m.screen = invalid then return

    if relative then
        offset = offset + (1000 * m.lastPosition)
        if offset < 0 then offset = 0
    end if

    if m.playState = "paused" then
        m.screen.Resume()
    end if

    m.screen.Seek(offset)
end sub

sub vpPrev()
    ' This is currently just a stub to provide a consistent player API (e.g. for remote control)
end sub

sub vpNext()
    ' This is currently just a stub to provide a consistent player API (e.g. for remote control)
end sub

sub vpUpdateNowPlaying(force=false as boolean)
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

sub vpOnTimelineTimer(timer as object)
    ' From the timeline timer, we need to force an update. This ensures
    ' everything works correctly if you, say, leave a video paused for a while.
    '
    m.UpdateNowPlaying(true)
end sub

sub vpOnPingTimer(timer as object)
    m.SendTranscoderCommand("ping")
    m.RequestTranscodeSessionInfo()
end sub

sub vpSendTranscoderCommand(command as string)
    if m.videoItem <> invalid and m.videoItem.transcodeServer <> invalid then
        path = "/video/:/transcode/universal/" + command + "?session=" + AppSettings().GetGlobal("clientIdentifier")
        request = createPlexRequest(m.videoItem.transcodeServer, path)
        context = request.CreateRequestContext(command)
        Application().StartRequest(request, context)
    end if
end sub

sub vpRequestTranscodeSessionInfo()
    if m.videoItem <> invalid and m.videoItem.transcodeServer <> invalid then
        path = "/transcode/sessions/" + AppSettings().GetGlobal("clientIdentifier")
        request = createPlexRequest(m.videoItem.transcodeServer, path)
        context = request.CreateRequestContext("session", CreateCallable("OnTranscodeInfoResponse", m))
        Application().StartRequest(request, context)
    end if
end sub

sub vpOnTranscodeInfoResponse(request as object, response as object, context as object)
    if m.videoItem <> invalid and m.screen <> invalid and response.ParseResponse() then
        session = response.items.Peek()
        if session <> invalid then
            ' Dump the interesting info into the logs
            Debug("--- Transcode Session Info ---")
            Debug("Throttled: " + session.Get("throttled", ""))
            Debug("Progress: " + session.Get("progress", ""))
            Debug("Speed: " + session.Get("speed", ""))
            Debug("Video Decision: " + session.Get("videoDecision"))
            Debug("Audio Decision: " + session.Get("audioDecision"))

            ' Update the most interesting bits in the overlay
            if session.GetInt("progress") >= 100 then
                curState = " (done)"
            else if session.Get("throttled") = "1" then
                curState = " (> 1x)"
            else
                curState = " (" + left(session.Get("speed", "?"), 3) + "x)"
            end if

            video = iif(session.Get("videoDecision") = "transcode", "convert", "copy")
            audio = iif(session.Get("audioDecision") = "transcode", "convert", "copy")

            m.videoItem.ReleaseDate = m.VideoItem.OrigReleaseDate + "   video: " + video + " audio: " + audio + curState
            m.Screen.SetContent(m.videoItem)
        end if
    end if
end sub
