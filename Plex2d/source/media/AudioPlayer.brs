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
        obj.playQueue = invalid
        obj.isPlaying = false
        obj.isPaused = false
        obj.ignoreTimelines = false

        obj.audioObjectsById = {}

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
        obj.Cleanup = apCleanup

        obj.SetPlayQueue = apSetPlayQueue
        obj.OnPlayQueueUpdate = apOnPlayQueueUpdate

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
        obj.GetCurTrack = apGetCurTrack

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
        m.isPlaying = false
        m.isPaused = false
        Application().Trigger("audio:stop", [m, m.context[m.curIndex].item])
        m.curIndex = 0
        m.player.SetNext(m.curIndex)
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
    m.player.Stop()
    m.curIndex = newIndex
    m.player.SetNext(newIndex)
    m.Play()
end sub

sub apNext()
    if m.context = invalid then return

    newIndex = m.AdvanceIndex()

    m.ignoreTimelines = true
    m.player.Stop()
    m.curIndex = newIndex
    m.player.SetNext(newIndex)
    m.Play()
end sub

function apAdvanceIndex(delta=1 as integer) as integer
    newIndex = (m.curIndex + delta) mod m.context.Count()
    return iif(newIndex < 0, newIndex + m.context.Count(), newIndex)
end function

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
            amountPlayed = m.GetPlaybackProgress()
            Debug("Sending analytics event, appear to have listened to audio for " + tostr(amountPlayed) + " seconds")
            Analytics().TrackEvent("Playback", item.Get("type", "track"), tostr(item.GetIdentifier()), amountPlayed)

            if m.repeat <> m.REPEAT_ONE then
                m.curIndex = m.AdvanceIndex()
            end if
        else if msg.isRequestFailed() then
            Error("Audio: Playback of track failed (" + tostr(msg.GetIndex()) + "): " + tostr(msg.GetMessage()))
            Application().Trigger("audio:stop", [m, item])
            m.ignoreTimelines = false
            m.curIndex = m.AdvanceIndex()
        else if msg.isListItemSelected() then
            Debug("Audio: Starting to play track: " + tostr(item.Url))
            m.ignoreTimelines = false
            m.isPlaying = true
            m.isPaused = false
            m.playbackOffset = 0
            m.playbackTimer.Mark()
            Application().Trigger("audio:play", [m, item])

            if m.repeat = m.REPEAT_ONE then
                m.player.SetNext(m.curIndex)
            else
                ' We started a new track, so refresh the PQ if necessary
                m.playQueue.Refresh(false)
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
            Application().Trigger("audio:pause", [m, item])
        else if msg.isResumed() then
            Debug("Audio: Playback resumed")
            m.isPlaying = true
            m.isPaused = false
            m.playbackTimer.Mark()
            Application().Trigger("audio:resume", [m, item])
        else if msg.isStatusMessage() then
            Debug("Audio: Status - " + tostr(msg.GetMessage()))
        else if msg.isFullResult() then
            Info("Audio: Playback of entire list finished")
            m.Stop()
            ' TODO(schuyler): Do we ever need to show an error?
        else if msg.isPartialResult() then
            Debug("Audio: isPartialResult")
            Application().Trigger("audio:stop", [m, item])
        end if

        ' Whatever it was, it was probably worthy of updating now playing
        m.UpdateNowPlaying()
    end if

    return handled
end function

sub apSetPlayQueue(playQueue as object, startPlayer=true as boolean)
    if startPlayer then
        m.ignoreTimelines = true
        m.Stop()
    end if

    ' TODO(schuyler): If we have an old PQ, clean things up

    m.playQueue = playQueue

    m.OnPlayQueueUpdate(playQueue)

    playQueue.On("change", createCallable("OnPlayQueueUpdate", m))

    if m.context.Count() > 0 and startPlayer then
        m.isPlaying = false
        m.isPaused = false
        m.Play()
    end if
end sub

sub apOnPlayQueueUpdate(playQueue as object)
    ' Usually when our play queue updates almost all of the items will be the
    ' same as the previous window. So keep track of our computed audio objects
    ' by PQ item ID and reuse them if we can.

    if m.context <> invalid then
        oldSize = m.context.Count()
    else
        oldSize = 0
    end if

    objectsById = {}
    metadata = CreateObject("roList")
    m.context = CreateObject("roList")
    m.curIndex = 0

    ' Create a list of objects with appropriate content metadata based on the
    ' current play queue window. We'll skip anything that isn't a music item or
    ' isn't playable.
    '
    for each item in playQueue.items
        if item.IsMusicItem() then
            itemId = item.Get("playQueueItemID", "")

            if m.audioObjectsById.DoesExist(itemId) then
                obj = m.audioObjectsById[itemId]
            else
                obj = createAudioObject(item)
                obj.Build()
            end if

            objectsById[itemId] = obj

            if obj.audioItem <> invalid then
                m.context.AddTail(obj)
                metadata.AddTail(obj.audioItem)
                if item.GetInt("playQueueItemID") = playQueue.selectedID then
                    m.curIndex = m.context.Count() - 1
                end if
            end if
        end if
    next

    m.audioObjectsById = objectsById

    ' If we're already playing something, we want the next index instead of
    ' the matching index.
    if m.isPlaying or m.isPaused then
        nextIndex = m.AdvanceIndex()
    else
        nextIndex = m.curIndex
    end if

    m.player.SetContentList(metadata)
    m.player.SetNext(nextIndex)
    m.player.SetLoop(playQueue.isRepeat)

    NowPlayingManager().SetControllable("music", "skipPrevious", (m.curIndex > 0 or m.repeat = m.REPEAT_ALL))
    NowPlayingManager().SetControllable("music", "skipNext", (m.curIndex < m.context.Count() - 1 or m.repeat = m.REPEAT_ALL))

    if m.context.Count() > 0 and oldSize = 0 then
        m.isPlaying = false
        m.isPaused = false
        m.Play()
    end if
end sub

sub apCleanup()
    m.Stop()
    m.timelineTimer.active = false
    m.playbackTimer.active = false
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

    item = m.context[m.curIndex].item

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

    ' TODO(rob): not sure about the ramifications of updating the progress
    ' every second... that means we call DrawAll().
    Application().Trigger("audio:progress", [m, item, time])
    NowPlayingManager().UpdatePlaybackState("music", item, state, time, m.playQueue)
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

function apGetCurTrack() as dynamic
    if m.curIndex = invalid or m.context = invalid then return invalid

    return m.context[m.curIndex].item
end function
