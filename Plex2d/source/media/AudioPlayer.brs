function AudioPlayer() as object
    if m.AudioPlayer = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Constants
        obj.REPEAT_NONE = 0
        obj.REPEAT_ONE = 1
        obj.REPEAT_ALL = 2

        ' We're responsible for the actual global audio player, using our
        ' global message port.
        '
        obj.player = CreateObject("roAudioPlayer")
        obj.player.SetMessagePort(Application().port)
        AddPlexHeaders(obj.player)

        obj.context = invalid
        obj.curIndex = invalid
        obj.isPlaying = false
        obj.isPaused = false
        obj.ignoreTimelines = false

        ' Player API functions
        obj.IsActive = apIsActive
        obj.Play = apPlay
        obj.Pause = apPause
        obj.Resume = apResume
        obj.Stop = apStop
        obj.Seek = apSeek
        obj.Prev = apPrev
        obj.Next = apNext

        obj.HandleMessage = apHandleMessage
        obj.SetContext = apSetContext
        obj.Cleanup = apCleanup

        ' Playback offset and timer
        obj.playbackOffset = 0
        obj.playbackTimer = createTimer("playback")
        obj.GetPlaybackProgress = apGetPlaybackProgress

        ' Timelines and now playing
        obj.OnTimelineTimer = apOnTimelineTimer
        obj.UpdateNowPlaying = apUpdateNowPlaying

        obj.ignoreTimelines = false
        obj.timelineTimer = createTimer("timeline")
        obj.timelineTimer.SetDuration(1000, true)
        obj.timelineTimer.active = false
        obj.timelineTimer.callback = createCallable("OnTimelineTimer", obj)

        ' Repeat
        obj.Repeat = obj.REPEAT_NONE
        obj.SetRepeat = apSetRepeat
        NowPlayingManager().timelines["music"].attrs["repeat"] = "0"

        ' Shuffle
        obj.isShuffled = false
        obj.SetShuffle = apSetShuffle
        NowPlayingManager().timelines["music"].attrs["shuffle"] = "0"

        obj.AdvanceIndex = apAdvanceIndex

        ' TODO(schuyler): Add support for theme music

        m.AudioPlayer = obj
    end if

    return m.AudioPlayer
end function

function apIsActive() as boolean
    ' TODO(schuyler): Is this the right definition?
    ' return (m.context <> invalid)
    return (m.isPlaying or m.isPaused)
end function

sub apPlay()
    if m.context <> invalid then
        m.player.Play()
        m.timelineTimer.active = true
        Application().AddTimer(m.timelineTimer, m.timelineTimer.callback)
    end if
end sub

sub apPause()
    if m.context <> invalid then
        m.player.Pause()
    end if
end sub

sub apResume()
    if m.context <> invalid then
        m.player.Resume()
    end if
end sub

sub apStop()
    if m.context <> invalid then
        m.player.Stop()
        m.player.SetNext(m.curIndex)
        m.isPlaying = false
        m.isPaused = false
    end if
end sub

sub apSeek(offset, relative=false as boolean)
    if not (m.isPlaying or m.isPaused) then return

    if relative then
        if m.isPlaying then
            offset = offset + (1000 * m.GetPlaybackProgress())
        else if m.isPaused then
            offset = offset + (1000 * m.playbackOffset)
        end if

        if offset < 0 then offset = 0
    end if

    m.playbackOffset = int(offset / 1000)
    m.playbackTimer.Mark()

    ' If we just call Seek while paused, we don't get a resumed event. This
    ' way the UI is always correct, but it's possible for a blip of audio.
    if m.isPaused then m.player.Resume()

    m.player.Seek(offset)
end sub

sub apPrev()
    if m.context = invalid then return

    newIndex = m.AdvanceIndex(-1)

    m.ignoreTimelines = true
    m.Stop()
    m.curIndex = newIndex
    m.player.SetNext(newIndex)
    m.Play()
end sub

sub apNext()
    if m.context = invalid then return

    newIndex = m.AdvanceIndex()

    m.ignoreTimelines = true
    m.Stop()
    m.curIndex = newIndex
    m.player.SetNext(newIndex)
    m.Play()
end sub

function apAdvanceIndex(delta=1 as integer) as integer
    maxIndex = m.context.Count() - 1
    newIndex = m.curIndex + delta

    if newIndex < 0 then
        newIndex = maxIndex
    else if newIndex > maxIndex then
        newIndex = 0
    end if

    return newIndex
end function

function apHandleMessage(msg as object) as boolean
    handled = false

    if type(msg) = "roAudioPlayerEvent" then
        handled = true
        item = m.context[m.curIndex]

        if msg.isRequestSucceeded() then
            Info("Audio: Playback of single track completed")

            ' Send an analytics event for anything but theme music
            amountPlayed = m.GetPlaybackProgress()
            Debug("Sending analytics event, appear to have listened to audio for " + tostr(amountPlayed) + " seconds")
            AnalyticsTracker().TrackEvent("Playback", item.Get("type", "track"), tostr(item.GetIdentifier()), amountPlayed)

            if m.repeat <> m.REPEAT_ONE then
                m.curIndex = m.AdvanceIndex()
            end if
        else if msg.isRequestFailed() then
            Error("Audio: Playback of track failed (" + tostr(msg.GetIndex()) + "): " + tostr(msg.GetMessage()))
            m.ignoreTimelines = false
            m.curIndex = m.AdvanceIndex()
        else if msg.isListItemSelected() then
            Debug("Audio: Starting to play track: " + tostr(item.Url))
            m.ignoreTimelines = false
            m.isPlaying = true
            m.isPaused = false
            m.playbackOffset = 0
            m.playbackTimer.Mark()

            if m.repeat = m.REPEAT_ONE then
                m.player.SetNext(m.curIndex)
            end if

            if m.context.Count() > 1 then
                NowPlayingManager().SetControllable("music", "skipPrevious", (m.curIndex > 0 or m.repeat = m.REPEAT_ALL))
                NowPlayingManager().SetControllable("music", "skipNext", (m.curIndex < m.context.Count() - 1 or m.repeat = m.REPEAT_ALL))
            end if
        else if msg.isPaused() then
            Debug("Audio: Playback paused")
            m.isPlaying = false
            m.isPaused = true
            m.playbackOffset = m.GetPlaybackProgress()
            m.playbackTimer.Mark()
        else if msg.isResumed() then
            Debug("Audio: Playback resumed")
            m.isPlaying = true
            m.isPaused = false
            m.playbackTimer.Mark()
        else if msg.isStatusMessage() then
            Debug("Audio: Status - " + tostr(msg.GetMessage()))
        else if msg.isFullResult() then
            Info("Audio: Playback of entire list finished")
            m.Stop()
            ' TODO(schuyler): Do we ever need to show an error?
        else if msg.isPartialResult() then
            Debug("Audio: isPartialResult")
        end if

        ' Whatever it was, it was probably worthy of updating now playing
        m.UpdateNowPlaying()
    end if

    return handled
end function

sub apSetContext(context as object, contextIndex as integer, startPlayer=true as boolean)
    if startPlayer then
        m.ignoreTimelines = true
        m.Stop()
    end if

    m.context = context
    m.curIndex = contextIndex

    ' TODO(schuyler): Preferences for repeat? m.player.SetLoop(...)

    ' TODO(schuyler): Figure out how to actually prepare the content list. We
    ' definitely need to set the URL, and we may need to set Streams with
    ' bitrate for FLAC, and we may need to set StreamFormat. We should also
    ' support transcoding, and we may want to be smarter about choosing
    ' Media/Part. We need to decide where exactly to do this preparation. Is
    ' this the right place? What do we do about unplayable items?
    '
    for each item in m.context
        item.url = invalid
        server = item.GetServer()
        if server <> invalid and item.isAccessible() and item.mediaItems.Count() > 0 then
            media = item.mediaItems[0]
            if media.HasStreams() then
                item.StreamFormat = media.Get("container", "mp3")
                item.Url = server.BuildUrl(media.parts[0].GetAbsolutePath("key"), true)
                bitrate = media.GetInt("bitrate")

                if bitrate > 0 then
                    item.Streams = [{ url: item.Url, bitrate: bitrate }]
                end if
            end if
        end if
    next

    m.player.SetContentList(m.context)
    m.player.SetNext(m.curIndex)

    NowPlayingManager().SetControllable("music", "skipPrevious", (m.curIndex > 0 or m.repeat = m.REPEAT_ALL))
    NowPlayingManager().SetControllable("music", "skipNext", (m.curIndex < m.context.Count() - 1 or m.repeat = m.REPEAT_ALL))

    if startPlayer then
        m.isPlaying = false
        m.isPaused = false
        m.Play()
    end if
end sub

sub apCleanup()
    m.Stop()
    m.timelineTimer = invalid
    m.playbackTimer = invalid
    fn = function() :m.AudioPlayer = invalid :end function
    fn()
end sub

function apGetPlaybackProgress() as integer
    return m.playbackOffset + m.playbackTimer.GetElapsedSeconds()
end function

sub apOnTimelineTimer(timer)
    m.UpdateNowPlaying()
end sub

sub apUpdateNowPlaying()
    if m.ignoreTimelines then return

    item = m.context[m.curIndex]

    ' Make sure we have enough info to actually send a timeline. This would also
    ' avoid sending timelines for theme music.
    '
    if item.Get("ratingKey") = invalid or item.GetServer() = invalid then
        return
    end if

    if m.isPlaying then
        state = "playing"
        time = 1000 * m.GetPlaybackProgress()
    else if m.isPaused then
        state = "paused"
        time = 1000 * m.playbackOffset
    else
        state = "stopped"
        time = 0
    end if

    NowPlayingManager().UpdatePlaybackState("music", item, state, time)
end sub

sub apSetRepeat(mode as integer)
    if m.repeat = mode then return

    m.repeat = mode
    m.player.SetLoop(mode = m.REPEAT_ALL)

    if mode = m.REPEAT_ONE then
        m.player.SetNext(m.curIndex)
    end if

    NowPlayingManager().timelines["music"].attrs["repeat"] = tostr(mode)
end sub

sub apSetShuffle(shuffle as boolean)
    if shuffle = m.isShuffled then return

    m.isShuffled = shuffle

    ' TODO(schuyler): Actually (un)shuffle the context!

    NowPlayingManager().timelines["music"].attrs["shuffle"] = iif(shuffle, "1", "0")
end sub
