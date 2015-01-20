function AudioPlayer() as object
    if m.AudioPlayer = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(BasePlayerClass())

        ' We're responsible for the actual global audio player, using our
        ' global message port.
        '
        obj.player = CreateObject("roAudioPlayer")
        obj.player.SetMessagePort(Application().port)
        AddPlexHeaders(obj.player)

        obj.timelineType = "music"

        ' Required methods for BasePlayer
        obj.Stop = apStop
        obj.SeekPlayer = apSeekPlayer
        obj.PlayItemAtIndex = apPlayItemAtIndex
        obj.SetContentList = apSetContentList
        obj.IsPlayable = apIsPlayable
        obj.CreateContentMetadata = apCreateContentMetadata
        obj.GetPlaybackPosition = apGetPlaybackPosition

        ' BasePlayer overrides
        obj.SetRepeat = apSetRepeat

        obj.HandleMessage = apHandleMessage
        obj.Cleanup = apCleanup

        ' Playback offset and timer
        obj.playbackOffset = 0
        obj.playbackTimer = createTimer("playback")

        obj.GetCurTrack = apGetCurTrack

        ' TODO(schuyler): Add support for theme music

        obj.Init()

        m.AudioPlayer = obj
    end if

    return m.AudioPlayer
end function

sub apStop()
    if m.context <> invalid then
        m.player.Stop()
        m.isPlaying = false
        m.isPaused = false
        m.playState = m.STATE_STOPPED
        m.Trigger("stopped", [m, m.context[m.curIndex].item])
        m.curIndex = 0
        m.player.SetNext(m.curIndex)
    end if
end sub

sub apSeekPlayer(offset)
    m.playbackOffset = int(offset / 1000)
    m.playbackTimer.Mark()

    ' If we just call Seek while paused, we don't get a resumed event. This
    ' way the UI is always correct, but it's possible for a blip of audio.
    if m.isPaused then m.player.Resume()

    m.player.Seek(offset)
end sub

sub apPlayItemAtIndex(index as integer)
    m.ignoreTimelines = true
    m.player.Stop()
    m.curIndex = index
    m.player.SetNext(index)
    m.Play()
end sub

sub apSetContentList(metadata as object, nextIndex as integer)
    m.player.SetContentList(metadata)
    m.player.SetNext(nextIndex)
    m.player.SetLoop(m.playQueue.isRepeat)
end sub

function apHandleMessage(msg as object) as boolean
    handled = false

    if type(msg) = "roAudioPlayerEvent" then
        handled = true
        ' This is possible when executing AudioPlayer().Cleanup()  (switching users)
        if m.context = invalid or m.curIndex = invalid or m.curIndex >= m.context.Count() then return handled
        item = m.context[m.curIndex].item

        if msg.isRequestSucceeded() then
            Info("Audio: Playback of single track completed")

            ' Send an analytics event for anything but theme music
            amountPlayed = m.GetPlaybackPosition()
            Debug("Sending analytics event, appear to have listened to audio for " + tostr(amountPlayed) + " seconds")
            Analytics().TrackEvent("Playback", item.Get("type", "track"), tostr(item.GetIdentifier()), amountPlayed)

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
            m.playState = m.STATE_PLAYING
            m.playbackOffset = 0
            m.playbackTimer.Mark()
            m.Trigger("playing", [m, item])

            if m.repeat = m.REPEAT_ONE then
                m.player.SetNext(m.curIndex)
            else
                ' We started a new track, so refresh the PQ if necessary
                m.playQueue.Refresh(false)
            end if

            if m.context.Count() > 1 then
                NowPlayingManager().SetControllable(m.timelineType, "skipPrevious", (m.curIndex > 0 or m.repeat = m.REPEAT_ALL))
                NowPlayingManager().SetControllable(m.timelineType, "skipNext", (m.curIndex < m.context.Count() - 1 or m.repeat = m.REPEAT_ALL))
            end if
        else if msg.isPaused() then
            Debug("Audio: Playback paused")
            m.isPlaying = false
            m.isPaused = true
            m.playState = m.STATE_PAUSED
            m.playbackOffset = m.GetPlaybackPosition()
            m.playbackTimer.Mark()
            m.Trigger("paused", [m, item])
        else if msg.isResumed() then
            Debug("Audio: Playback resumed")
            m.isPlaying = true
            m.isPaused = false
            m.playState = m.STATE_PLAYING
            m.playbackTimer.Mark()
            m.Trigger("resumed", [m, item])
        else if msg.isStatusMessage() then
            Debug("Audio: Status - " + tostr(msg.GetMessage()))
        else if msg.isFullResult() then
            Info("Audio: Playback of entire list finished")
            m.Stop()
            ' TODO(schuyler): Do we ever need to show an error?
        else if msg.isPartialResult() then
            Debug("Audio: isPartialResult")
            ' TODO(schuyler): Do we need to do anything here?
        end if

        ' Whatever it was, it was probably worthy of updating now playing
        m.UpdateNowPlaying()
    end if

    return handled
end function

function apIsPlayable(item as object) as boolean
    return item.IsMusicItem()
end function

function apCreateContentMetadata(item as object) as object
    obj = createAudioObject(item)
    obj.Build()
    return obj
end function

sub apCleanup()
    m.Stop()
    m.timelineTimer.active = false
    m.playbackTimer.active = false
end sub

function apGetPlaybackPosition(millis=false as boolean) as integer
    if m.isPlaying then
        seconds = m.playbackOffset + m.playbackTimer.GetElapsedSeconds()
    else
        seconds = m.playbackOffset
    end if

    if millis then
        return (seconds * 1000)
    else
        return seconds
    end if
end function

sub apSetRepeat(mode as integer)
    ApplyFunc(BasePlayerClass().SetRepeat, m, [mode])

    m.player.SetLoop(mode = m.REPEAT_ALL)

    if mode = m.REPEAT_ONE then
        m.player.SetNext(m.curIndex)
    end if
end sub

function apGetCurTrack() as dynamic
    if m.curIndex = invalid or m.context = invalid then return invalid

    return m.context[m.curIndex].item
end function
