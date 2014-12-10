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

    m.playBackError = false
    m.item = item
    m.seekValue = firstOf(seekValue, 0)

    Debug("MediaPlayer::playVideo: Displaying video: " + tostr(item.GetLongerTitle()))

    ' TODO(rob): videoItem = server.ConstructVideoItem (plexnet)
    m.videoItem = tempConstructVideoItem(m.Item, m.seekValue)
    if m.videoItem = invalid then
        Fatal("invalid video item")
    end if

    screen = CreateObject("roVideoScreen")
    screen.SetMessagePort(Application().port)
    screen.SetPositionNotificationPeriod(1)
    screen.EnableCookies()

    ' TODO(rob): helper required to add token with appropriate
    'if server.IsRequestToServer(videoItem.StreamUrls[0]) then
    AddPlexHeaders(screen, m.videoItem.server.GetToken())
    'end if

    screen.SetCertificatesFile("common:/certs/ca-bundle.crt")
    screen.SetCertificatesDepth(5)

    screen.SetContent(m.videoItem)

    ' TODO(rob): other headers (non direct play)
    'if m.videoItem.IsTranscoded then
    '    cookie = server.StartTranscode(m.videoItem.StreamUrls[0])
    '    if cookie <> invalid then
    '        screen.AddHeader("Cookie", cookie)
    '    end if
    'else
    '    for each header in m.videoItem.IndirectHttpHeaders
    '        for each name in header
    '            screen.AddHeader(name, header[name])
    '        next
    '    next
    'end if

    m.screen = screen
end sub

sub vsShow()
    if m.Screen <> invalid then
        Debug("Starting to direct play video")

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
    server = m.Item.GetServer()

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
            Debug("MediaPlayer::playVideo::VideoScreenEvent::isRequestFailed - message = " + tostr(msg.GetMessage()))
            Debug("MediaPlayer::playVideo::VideoScreenEvent::isRequestFailed - data = " + tostr(msg.GetData()))
            Debug("MediaPlayer::playVideo::VideoScreenEvent::isRequestFailed - index = " + tostr(msg.GetIndex()))
            m.playbackError = true
        else if msg.isPaused() then
            Debug("MediaPlayer::playVideo::VideoScreenEvent::isPaused: position -> " + tostr(m.lastPosition))
            m.playState = "paused"
            'm.UpdateNowPlaying()
        else if msg.isResumed() then
            Debug("MediaPlayer::playVideo::VideoScreenEvent::isResumed")
            m.playState = "playing"
            'm.UpdateNowPlaying()
        else if msg.isPartialResult() then
            Debug("MediaPlayer::playVideo::VideoScreenEvent::isPartialResult: position -> " + tostr(m.lastPosition))
            m.playState = "stopped"
            'm.UpdateNowPlaying()
            'if m.IsTranscoded then server.StopVideo()
        else if msg.isFullResult() then
            Debug("MediaPlayer::playVideo::VideoScreenEvent::isFullResult: position -> " + tostr(m.lastPosition))
            m.isPlayed = true
            m.playState = "stopped"
            'm.UpdateNowPlaying()
            if m.IsTranscoded then server.StopVideo()
        else if msg.isStreamStarted() then
            Debug("MediaPlayer::playVideo::VideoScreenEvent::isStreamStarted: position -> " + tostr(m.lastPosition))
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

function tempConstructVideoItem(item as object, seekValue as integer) as object
    ' this is mainly bogus for now. We'll add logic when we have the MDE
    ' for things like isAvailable, transocoding, etc...

    media = item.mediaitems[0]
    part = media.parts[0]

    ' TODO(rob): add logic of other media types
    if item.islibraryitem() then
        mediaKey = media.parts[0].Get("key")
        videoRes = media.Get("videoResolution")
    else
        Fatal("cannot play non library video")
    end if

    video = CreateObject("roAssociativeArray")
    video.PlayStart = seekValue
    video.Server = item.GetServer()

    video.Title = item.GetLongerTitle()
    video.ReleaseDate = item.Get("originallyAvailableAt")

    video.StreamQualities = iif(appSettings().GetGlobal("DisplayType") = "HDTV", ["HD"], ["SD"])
    video.HDBranded = val(videoRes) >= 720
    video.fullHD = iif(videoRes = "1080", true, false)

    video.StreamUrls = [item.GetServer().BuildUrl(mediaKey)]
    video.StreamBitrates = [media.Get("bitrate")]
    video.StreamFormat = media.Get("container", "mp4")
    if video.StreamFormat = "hls" then video.SwitchingStrategy = "full-adaptation"
    video.IsTranscoded = false

    frameRate = media.Get("frameRate", "24p")
    if frameRate = "24p" then
        video.FrameRate = 24
    else if frameRate = "NTSC"
        video.FrameRate = 30
    end if

    ' TODO(rob): indexes (sd only) we can get fancy later...
    if part.Get("indexes") <> invalid then
        video.SDBifUrl = item.GetServer().BuildUrl("/library/parts/" + part.Get("id") + "/indexes/sd?interval=10000")
    end if

    ' TODO(rob): subtitles
    'if part <> invalid AND part.subtitles <> invalid AND part.subtitles.Codec = "srt" AND part.subtitles.key <> invalid then
    '    video.SubtitleUrl = FullUrl(m.serverUrl, "", part.subtitles.key) + "?encoding=utf-8"
    '    ' this forces showing the subtitle regardless of the Roku setting
    '    video.SubtitleConfig = { ShowSubtitle: 1 }
    'end if

    ' TODO(rob): language
    'if part <> invalid AND part.audioStream <> invalid AND part.audioStream.languageCode <> invalid then
    '    video.AudioLanguageSelected = part.audioStream.languageCode
    'end if

    Debug("Setting stream quality: " + tostr(video.StreamQualities[0]))
    Debug("Will try to direct play " + tostr(video.StreamUrls[0]))

    return video
end function
