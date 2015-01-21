function VideoPlayer() as object
    if m.VideoPlayer = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(BasePlayerClass())

        ' This is both an implementation of our player API (Pause, Resume, etc.)
        ' and responsible for the actual screen playing the video. So we
        ' inherit from BaseScreen even though we're a long-lived singleton.
        ' Both BasePlayerClass and BaseScreen have important Init methods. The
        ' former should be called once, and the latter is called once for each
        ' "screen" lifecycle. So we call the player's Init now and don't mind
        ' that we lose the reference to it when appending BaseScreen.

        obj.timelineType = "video"
        obj.Init()

        obj.timelineTimer.SetDuration(15000, true)

        obj.Append(BaseScreen())

        ' Screen functions
        obj.Show = vpShow
        obj.HandleMessage = vpHandleMessage
        obj.Init = vpInit
        obj.Cleanup = vpCleanup

        ' Required player methods
        obj.Stop = vpStop
        obj.SeekPlayer = vpSeekPlayer
        obj.PlayItemAtIndex = vpPlayItemAtIndex
        obj.SetContentList = vpSetContentList
        obj.IsPlayable = vpIsPlayable
        obj.CreateContentMetadata = vpCreateContentMetadata
        obj.GetPlaybackPosition = vpGetPlaybackPosition

        ' Player overrides
        obj.Play = vpPlay

        obj.OnPingTimer = vpOnPingTimer
        obj.SendTranscoderCommand = vpSendTranscoderCommand

        obj.RequestTranscodeSessionInfo = vpRequestTranscodeSessionInfo
        obj.OnTranscodeInfoResponse = vpOnTranscodeInfoResponse

        m.VideoPlayer = obj
    end if

    return m.VideoPlayer
end function

sub vpInit()
    m.screenID = invalid
    ApplyFunc(BaseScreen().Init, m)

    ' variables
    m.lastPosition = 0
    m.playBackError = false
    m.isPlayed = false
    m.SetPlayState(m.STATE_BUFFERING)

    m.bufferingTimer = createTimer("buffering")
    m.playbackTimer = createTimer("playback")
    m.pingTimer = invalid

    ' Reset the timeline timer
    m.timelineTimer.active = true
    Application().AddTimer(m.timelineTimer, m.timelineTimer.callback)

    ' TODO(rob): multi-parts offset (curPartOffset)
    m.curPartOffset = 0

    videoItem = m.GetCurrentMetadata()

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

    ' Always add X-Plex headers, but not a token. It's possible that the
    ' transcode server and original media server (with subtitles, BIFs, etc.)
    ' will be different. Anything that needs a token will have it added to the
    ' URL.
    '
    AddPlexHeaders(screen)

    screen.SetContent(videoItem)

    m.IsTranscoded = videoItem.IsTranscoded

    ' TODO(schuyler): Extra headers for direct play of indirect items

    ' We're pretending to be a player and a screen, so we need to store the
    ' player in two places.
    '
    m.screen = screen
    m.player = screen
end sub

sub vpCleanup()
    ' We're cleaning up after our screen, not anything long-lived.

    timers = ["pingTimer", "playbackTimer", "bufferingTimer"]
    for each name in timers
        if m[name] <> invalid then
            m[name].active = false
            m[name] = invalid
        end if
    next

    m.timelineTimer.active = false

    m.SetPlayState(m.STATE_STOPPED)
    m.screen = invalid
    m.player = invalid
    m.context = invalid
    m.curIndex = invalid
    m.playQueue = invalid
    m.metadataById.Clear()
end sub

sub vpShow()
    if m.screen <> invalid then
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

        m.ignoreTimelines = false
        m.timelineTimer.Mark()
        m.playbackTimer.Mark()
        m.bufferingTimer.Mark()
        AudioPlayer().Stop()
        m.screen.Show()
        NowPlayingManager().location = "fullScreenVideo"
        m.UpdateNowPlaying()
        m.Trigger("playing", [m, m.GetCurrentItem()])
    else
        NowPlayingManager().location = "navigation"
        Application().PopScreen(m)
    end if
end sub

function vpHandleMessage(msg) as boolean
    handled = false

    if type(msg) = "roVideoScreenEvent" then
        handled = true

        item = m.GetCurrentItem()

        if msg.isScreenClosed() then
            m.SendTranscoderCommand("stop")

            ' Send an analytics event.
            startOffset = int(m.seekValue/1000)
            amountPlayed = m.lastPosition - startOffset
            if amountPlayed > m.playbackTimer.GetElapsedSeconds() then amountPlayed = m.playbackTimer.GetElapsedSeconds()

            if amountPlayed > 0 then
                Debug("Sending analytics event, appear to have watched video for " + tostr(amountPlayed) + " seconds")
                Analytics().TrackEvent("Playback", item.Get("type", "clip"), tostr(item.GetIdentifier()), amountPlayed)
            end if

            Debug("vsHandleMessage::isScreenClosed: position -> " + tostr(m.lastPosition))

            ' TODO(rob): multi-parts

            ' TODO(schuyler): Make sure this is working after the play queue changes
            ' Fallback transcode
            if m.playbackError and m.IsTranscoded = false and not m.forceTranscode = true then
                Debug("Direct Play failed: falling back to transcode")
                m.forceTranscode = true
                m.Cleanup()
                m.Init()
                m.Show()
            else if m.isPlayed and (m.curIndex < m.context.Count() - 1 or m.repeat <> m.REPEAT_NONE) then
                Debug("Going to try to play the next item")
                m.player = invalid
                m.screen = invalid
                m.Next()
            else
                Debug("Done with entire play queue, going to pop screen")
                m.SetPlayState(m.STATE_STOPPED)
                NowPlayingManager().location = "navigation"
                m.UpdateNowPlaying()
                m.Trigger("stopped", [m, item])
                Application().PopScreen(m)
                m.Cleanup()
            end if
        else if msg.isPlaybackPosition() then
            m.lastPosition = m.curPartOffset + msg.GetIndex()
            Debug("vsHandleMessage::isPlaybackPosition: set progress -> " + tostr(1000*m.lastPosition))

            duration = m.GetCurrentMetadata().duration
            if duration > 0 then
                playedFraction = (m.lastPosition * 1000)/duration
                if playedFraction > 0.90 then
                    m.isPlayed = true
                end if
            end if

            if msg.GetIndex() > 0 then
                if m.bufferingTimer <> invalid then
                    Analytics().TrackTiming(m.bufferingTimer.GetElapsedMillis(), "buffering", tostr(m.IsTranscoded), tostr(item.GetIdentifier()))
                    m.bufferingTimer = invalid
                end if

                m.SetPlayState(m.STATE_PLAYING)
                m.UpdateNowPlaying(true)
            end if
        else if msg.isRequestFailed() then
            Debug("vsHandleMessage::isRequestFailed - message = " + tostr(msg.GetMessage()))
            Debug("vsHandleMessage::isRequestFailed - data = " + tostr(msg.GetData()))
            Debug("vsHandleMessage::isRequestFailed - index = " + tostr(msg.GetIndex()))
            m.playbackError = true
        else if msg.isPaused() then
            Debug("vsHandleMessage::isPaused: position -> " + tostr(m.lastPosition))
            m.SetPlayState(m.STATE_PAUSED)
            m.Trigger("paused", [m, item])
            m.UpdateNowPlaying()
        else if msg.isResumed() then
            Debug("vsHandleMessage::isResumed")
            m.SetPlayState(m.STATE_PLAYING)
            m.Trigger("resumed", [m, item])
            m.UpdateNowPlaying()
        else if msg.isPartialResult() then
            Debug("vsHandleMessage::isPartialResult: position -> " + tostr(m.lastPosition))
            m.SendTranscoderCommand("stop")
        else if msg.isFullResult() then
            Debug("vsHandleMessage::isFullResult: position -> " + tostr(m.lastPosition))
            m.isPlayed = true
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

sub vpPlay()
    ' If we're currently playing something, then we'll have to close the current
    ' player (and wait for it to fully close) before we can play something new.

    if m.player <> invalid then
        Info("Can't start video until previous player closes")
        return
    end if

    ' We start playback by creating an actual video player object. And to
    ' the extent that we're pretending to be a typical screen instance, that
    ' means we want to create a new screen. So go ahead and call Init, get a
    ' new screen ID, etc.
    '
    m.Init()

    ' Show the existing video player if it's the screen on top, otherwise
    ' push the video player to the stack.
    if Application().IsActiveScreen(m) then
        m.screen.Show()
    else
        Application().PushScreen(m)
    end if
end sub

sub vpStop()
    if m.player <> invalid then
        m.player.Close()
        m.SetPlayState(m.STATE_STOPPED)
        m.Trigger("stopped", [m, m.GetCurrentItem()])
        m.curIndex = 0
        m.timelineTimer.active = false
    end if
end sub

sub vpSeekPlayer(offset)
    if m.isPaused then m.player.Resume()

    m.player.Seek(offset)
end sub

sub vpPlayItemAtIndex(index as integer)
    ' If we're currently playing something, then we'll have to close the current
    ' player (and wait for it to fully close) before we can play something new.

    if m.player = invalid then
        m.curIndex = index
        m.Play()
    else
        m.playIndexAfterClose = index
        ' TODO(schuyler): Is this even right? Don't we want to send something about our final progress?
        m.ignoreTimelines = true
        m.player.Close()
    end if
end sub

sub vpSetContentList(metadata as object, nextIndex as integer)
    ' Nothing to do here since the video player doesn't have a content list
end sub

function vpIsPlayable(item as object) as boolean
    return item.IsVideoItem()
end function

function vpCreateContentMetadata(item as object) as object
    ' TODO(schuyler): Is this the best way to handle resuming?
    if m.shouldResume = true then
        m.seekValue = item.GetInt("viewOffset")
        m.shouldResume = false
    else
        m.seekValue = 0
    end if

    obj = createVideoObject(item, m.seekValue)

    settings = AppSettings()
    allowDirectPlay = settings.GetBoolPreference("playback_direct")
    allowDirectStream = settings.GetBoolPreference("playback_remux")
    allowTranscode = settings.GetBoolPreference("playback_transcode")

    if m.forceTranscode = true then
        directPlay = false
        if allowDirectStream = false and allowTranscode = false then
            Debug("Forced transcode requested: allowDirectStream and allowTranscode not enabled")
            m.screenError = "Transcode required: not enabled"
            return obj
        end if
    else
        directPlay = iif(allowDirectPlay, iif(allowDirectStream or allowTranscode, invalid, true), false)
    end if

    obj.Build(directPlay, allowDirectStream)
    return obj
end function

function vpGetPlaybackPosition(millis=false as boolean) as integer
    seconds = m.lastPosition

    if millis then
        return (seconds * 1000)
    else
        return seconds
    end if
end function

sub vpOnPingTimer(timer as object)
    m.SendTranscoderCommand("ping")
    m.RequestTranscodeSessionInfo()
end sub

sub vpSendTranscoderCommand(command as string)
    videoItem = m.GetCurrentMetadata()

    if videoItem <> invalid and videoItem.transcodeServer <> invalid then
        path = "/video/:/transcode/universal/" + command + "?session=" + AppSettings().GetGlobal("clientIdentifier")
        request = createPlexRequest(videoItem.transcodeServer, path)
        context = request.CreateRequestContext(command)
        Application().StartRequest(request, context)
    end if
end sub

sub vpRequestTranscodeSessionInfo()
    videoItem = m.GetCurrentMetadata()

    if videoItem <> invalid and videoItem.transcodeServer <> invalid then
        path = "/transcode/sessions/" + AppSettings().GetGlobal("clientIdentifier")
        request = createPlexRequest(videoItem.transcodeServer, path)
        context = request.CreateRequestContext("session", CreateCallable("OnTranscodeInfoResponse", m))
        Application().StartRequest(request, context)
    end if
end sub

sub vpOnTranscodeInfoResponse(request as object, response as object, context as object)
    videoItem = m.GetCurrentMetadata()

    if videoItem <> invalid and m.screen <> invalid and response.ParseResponse() then
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

            videoItem.ReleaseDate = videoItem.OrigReleaseDate + "   video: " + video + " audio: " + audio + curState
            m.Screen.SetContent(videoItem)
        end if
    end if
end sub
