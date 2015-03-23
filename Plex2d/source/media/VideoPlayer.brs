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
        obj.screenName = "Video Player"

        ' Screen functions
        obj.Show = vpShow
        obj.HandleMessage = vpHandleMessage
        obj.Init = vpInit
        obj.Cleanup = vpCleanup
        obj.ClearMemory = vpClearMemory
        obj.ShowPlaybackError = vpShowPlaybackError
        obj.Activate = vpActivate

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

    videoItem = m.GetCurrentMetadata()

    ' TODO(rob): better UX error handling
    if videoItem = invalid then
        m.screenError = "invalid video item"
        return
    end if

    m.curPartOffset = validint(videoItem.startOffset)

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
    screen.AddHeader("X-Plex-Chunked", "1")
    screen.AddHeader("X-Plex-Strict-Ranges", "0")

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

        ' Workaround to clear memory before playback for Roku 2 XS, Roku HD(2500)
        ' and other models possibly affected by this bug.
        m.ClearMemory()
        m.screen.Show()

        NowPlayingManager().SetLocation(NowPlayingManager().FULLSCREEN_VIDEO)
        m.UpdateNowPlaying()
        m.Trigger("playing", [m, m.GetCurrentItem()])
    else
        NowPlayingManager().SetLocation(NowPlayingManager().NAVIGATION)
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
                Info("Sending analytics event, appear to have watched video for " + tostr(amountPlayed) + " seconds")
                Analytics().TrackEvent("Playback", item.Get("type", "clip"), tostr(item.GetIdentifier()), amountPlayed)
            end if

            Debug("vsHandleMessage::isScreenClosed: position -> " + tostr(m.lastPosition))

            ' If we were specifically told to move to another item, do so now
            if m.playIndexAfterClose <> invalid then
                m.ignoreTimelines = false
                m.curIndex = m.playIndexAfterClose
                m.playIndexAfterClose = invalid
                m.player = invalid
                m.screen = invalid
                m.Play()
                return handled
            end if

            ' Fallback transcode with resume support
            if m.playbackError and m.IsTranscoded = false then
                Warn("Direct Play failed: falling back to transcode")
                lastPosition = m.GetPlaybackPosition(true)
                videoItem = m.CreateContentMetadata(m.GetCurrentItem(), true, iif(lastPosition > m.seekValue, lastPosition, m.seekValue))
                if videoItem.playbackSupported <> false then
                    m.context[m.curIndex] = videoItem
                    m.player = invalid
                    m.screen = invalid
                    m.Play()
                    return handled
                end if
            end if

            if m.playbackError <> true and m.isPlayed then
                videoItem = m.context[m.curIndex]

                if videoItem.HasMoreParts() then
                    Info("Going to try to play the next part")
                    videoItem.GoToNextPart()
                    m.player = invalid
                    m.screen = invalid
                    m.Play()
                    return handled
                else if m.curIndex < m.context.Count() - 1 or m.repeat <> m.REPEAT_NONE then
                    Info("Going to try to play the next item")
                    m.player = invalid
                    m.screen = invalid
                    m.Next()
                    return handled
                end if
            end if

            Info("Done with entire play queue, going to pop screen")
            m.SetPlayState(m.STATE_STOPPED)
            NowPlayingManager().SetLocation(NowPlayingManager().NAVIGATION)
            m.UpdateNowPlaying()
            m.Trigger("stopped", [m, item])
            Application().PopScreen(m)
            if m.playbackError then m.ShowPlaybackError()
            m.Cleanup()
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
            Warn("vsHandleMessage::isRequestFailed - message = " + tostr(msg.GetMessage()))
            Warn("vsHandleMessage::isRequestFailed - data = " + tostr(msg.GetData()))
            Warn("vsHandleMessage::isRequestFailed - index = " + tostr(msg.GetIndex()))
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
            Warn("vsHandleMessage::isPartialResult: position -> " + tostr(m.lastPosition))
            m.SendTranscoderCommand("stop")
        else if msg.isFullResult() then
            Info("vsHandleMessage::isFullResult: position -> " + tostr(m.lastPosition))
            m.isPlayed = true
            m.SendTranscoderCommand("stop")
        else if msg.isStreamStarted() then
            Info("vsHandleMessage::isStreamStarted: position -> " + tostr(m.lastPosition))
            Debug("Message data -> " + tostr(msg.GetInfo()))

            m.RequestTranscodeSessionInfo()

            ' Don't spoil trailers (plexinc/roku-client-issues#10)
            videoItem = m.GetCurrentMetadata()
            if videoItem.hudTitle <> invalid then
                videoItem.title = videoItem.hudTitle
                videoItem.hudTitle = invalid
                m.Screen.SetContent(videoItem)
            end if

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
            Warn("Unknown event: " + tostr(msg.GetType()) + " msg: " + tostr(msg.GetMessage()))
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
        m.SetCurrentIndex(index)
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

function vpCreateContentMetadata(item as object, forceTranscode=false as boolean, resumeOffset=invalid as dynamic) as object
    ' TODO(schuyler): Is this the best way to handle resuming?
    if resumeOffset <> invalid then
        m.seekValue = validint(resumeOffset)
    else if m.shouldResume = true and item.GetInt("playQueueItemID") = m.playQueue.selectedID then
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

    if forceTranscode then
        directPlay = false
        if allowDirectStream = false and allowTranscode = false then
            Warn("Forced transcode requested: allowDirectStream and allowTranscode not enabled")
            obj.playbackSupported = false
            return obj
        end if
    else
        directPlay = iif(allowDirectPlay, iif(allowDirectStream or allowTranscode, invalid, true), false)
    end if

    obj.Build(directPlay, allowDirectStream)
    return obj
end function

function vpGetPlaybackPosition(millis=false as boolean) as integer
    seconds = validint(m.lastPosition)

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

sub vpClearMemory()
    ' This seems to work better than creating an roGridScreen, as it doesn't cause any
    ' screen flashing. If we need to go the roGridScreen route, then we'll probably
    ' want to set the roAppManager bkg to black, to match the video loading screen.
    m.facade = CreateObject("roScreen", false)

    ' Just to be safe.
    Application().CloseLoadingModal()

    ' Deactivate all screens (clear 2d components)
    for each deactScreen in Application().screens
        deactScreen.Deactivate()
    end for

    ' roScreen and compositor must die
    CompositorScreen().Destroy()

    ' This doesn't seem needed for all platforms, but the Roku HD (2500) will randomly
    ' fail without this. I can't even start to describe what you'll see on the screen
    ' when it fails.
    GetGlobalAA().delete("texturemanager")
end sub

sub vpShowPlaybackError()
    video = m.context[m.curIndex]
    curMedia = video.media
    server = video.item.GetServer()

    ' HACK to get accessible/available as blocking request. The playQueue
    ' doesn't support checkFiles, so we'll need to add the correct support
    ' for that.
    request = createPlexRequest(server, video.item.GetItemPath(true))
    response = request.DoRequestWithTimeout(10)
    if response.items.Count() > 0 and response.items[0].mediaitems <> invalid then
        for each media in response.items[0].mediaitems
            if media.Equals(curMedia) then
                curMedia = media
                exit for
            end if
        next
    end if
    ' End Hack

    if video.media.IsIndirect() then
        title = "Video Unavailable"
        text = "Sorry, but we can't play this video. The original video may no longer be available, or it may be in a format that isn't supported."
    else if curMedia <> invalid and curMedia.IsAvailable() = false then
        title = "Video Unavailable"
        text = "Please check that this file exists and the necessary drive is mounted."
    else if curMedia <> invalid and curMedia.IsAccessible() = false then
        title = "Video Unavailable"
        text = "Please check that this file exists and has appropriate permissions."
    else if m.IsTranscoded = false then
        title = "Direct Play Unavailable"
        text = "This video isn't supported for Direct Play."
    else if server <> invalid and server.supportsVideoTranscoding = false then
        title = "Transcoding Unavailable"
        text = "Your Plex Media Server doesn't support video transcoding."
    else
        title = "Video Unavailable"
        text = "We're unable to play this video, make sure the server is running and has access to this video."
    end if

    ' we have to create a dialog screen until we have a custom video player.
    dialogScreen = createDialogScreen(title, text, video.item)
    Application().PushScreen(dialogScreen)
end sub

sub vpActivate()
    ' We cannot allow activation (at least not with the roVideoScreen)
    Application().PopScreen(m)
end sub
