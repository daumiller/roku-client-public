function BasePlayerClass() as object
    if m.BasePlayerClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(EventsMixin())

        ' Constants
        obj.REPEAT_NONE = 0
        obj.REPEAT_ONE = 1
        obj.REPEAT_ALL = 2
        obj.STATE_STOPPED = "stopped"
        obj.STATE_PLAYING = "playing"
        obj.STATE_PAUSED = "paused"
        obj.STATE_BUFFERING = "buffering"

        obj.Init = bpInit

        ' Player API functions
        obj.IsActive = bpIsActive
        obj.Play = bpPlay
        obj.Pause = bpPause
        obj.Resume = bpResume
        obj.Seek = bpSeek
        obj.Prev = bpPrev
        obj.Next = bpNext

        ' Remote buttons
        obj.OnPlayButton = bpOnPlayButton
        obj.OnFwdButton = bpOnFwdButton
        obj.OnRevButton = bpOnRevButton

        obj.SetPlayQueue = bpSetPlayQueue
        obj.OnPlayQueueUpdate = bpOnPlayQueueUpdate

        obj.isPlaying = false
        obj.isPaused = false
        obj.playState = m.STATE_STOPPED
        obj.lastTimelineState = invalid

        ' Timelines and now playing
        obj.OnTimelineTimer = bpOnTimelineTimer
        obj.UpdateNowPlaying = bpUpdateNowPlaying
        obj.ShouldSendTimeline = bpShouldSendTimeline

        ' Repeat
        obj.repeat = obj.REPEAT_NONE
        obj.SetRepeat = bpSetRepeat

        ' Shuffle
        obj.isShuffled = false
        obj.SetShuffle = bpSetShuffle

        obj.SetPlayState = bpSetPlayState
        obj.AdvanceIndex = bpAdvanceIndex
        obj.GetCurrentItem = bpGetCurrentItem
        obj.GetNextItem = bpGetNextItem
        obj.GetCurrentMetadata = bpGetCurrentMetadata

        m.BasePlayerClass = obj
    end if

    return m.BasePlayerClass
end function

sub bpInit()
        ' context is a list of Content Meta-Data objects, with curIndex
        ' tracking the current item. The actual PlexObjects are backed by
        ' playQueue.
        '
        m.context = invalid
        m.curIndex = invalid
        m.playQueue = invalid
        m.metadataById = {}

        m.ignoreTimelines = false
        m.timelineTimer = createTimer("timeline")
        m.timelineTimer.SetDuration(1000, true)
        m.timelineTimer.active = false
        m.timelineTimer.callback = createCallable("OnTimelineTimer", m)

        m.SetPlayState(m.STATE_STOPPED)

        NowPlayingManager().timelines[m.timelineType].attrs["repeat"] = "0"
        NowPlayingManager().timelines[m.timelineType].attrs["shuffle"] = "0"
end sub

function bpIsActive() as boolean
    return (m.isPlaying or m.isPaused)
end function

sub bpPlay()
    ' This will probably have to be specific to each type, but we'll take a stab
    if m.context <> invalid then
        m.player.Play()
        m.timelineTimer.active = true
        Application().AddTimer(m.timelineTimer, m.timelineTimer.callback)
    end if
end sub

sub bpPause()
    if m.context <> invalid then
        m.player.Pause()
    end if
end sub

sub bpResume()
    if m.context <> invalid then
        m.player.Resume()
    end if
end sub

sub bpSeek(offset, relative=false as boolean)
    if not (m.isPlaying or m.isPaused) then return

    if relative then
        offset = offset + m.GetPlaybackPosition(true)

        if offset < 0 then offset = 0
    end if

    m.SeekPlayer(offset)
end sub

sub bpPrev()
    if m.context = invalid then return

    m.PlayItemAtIndex(m.AdvanceIndex(-1))
end sub

sub bpNext()
    if m.context = invalid then return

    m.PlayItemAtIndex(m.AdvanceIndex())
end sub

function bpAdvanceIndex(delta=1 as integer, updatePlayQueue=true as boolean) as integer
    newIndex = (m.curIndex + delta) mod m.context.Count()
    newIndex = iif(newIndex < 0, newIndex + m.context.Count(), newIndex)

    if updatePlayQueue then
        m.playQueue.selectedId = m.context[newIndex].item.GetInt("playQueueItemID")
        m.playQueue.Refresh(false, true)
    end if

    return newIndex
end function

sub bpSetPlayQueue(playQueue as object, startPlayer=true as boolean)
    ' TODO(schuyler): startPlayer is never false. If it ever is, then
    ' we probably need to reconsider how playback is started in
    ' OnPlayQueueUpdate.

    if startPlayer then
        m.ignoreTimelines = true
        m.Stop()
    end if

    ' TODO(schuyler): If we have an old PQ, clean things up
    m.metadataById = {}
    m.playQueue = playQueue
    m.repeat = m.REPEAT_NONE

    m.OnPlayQueueUpdate(playQueue)

    playQueue.On("change", createCallable("OnPlayQueueUpdate", m))

    if m.context.Count() > 0 and startPlayer then
        m.Play()
    end if
end sub

sub bpOnPlayQueueUpdate(playQueue as object)
    ' Usually when our play queue updates almost all of the items will be the
    ' same as the previous window. So keep track of our computed CMD objects
    ' by PQ item ID and reuse them if we can.

    if m.context <> invalid and m.context.Count() > 0 then
        oldSize = m.context.Count()
        changes = {
            origFirst: m.context[0].item.GetInt("playQueueItemID"),
            origLast: m.context.Peek().item.GetInt("playQueueItemID")
        }
    else
        oldSize = 0
        changes = CreateObject("roAssociativeArray")
    end if

    objectsById = {}
    metadata = CreateObject("roList")
    m.context = CreateObject("roList")
    m.curIndex = 0

    ' Create a list of objects with appropriate content metadata based on the
    ' current play queue window. We'll skip anything that isn't playable for
    ' this player type.
    '
    for each item in playQueue.items
        if m.IsPlayable(item) then
            itemId = item.Get("playQueueItemID", "")

            if m.metadataById.DoesExist(itemId) then
                obj = m.metadataById[itemId]
            else
                obj = m.CreateContentMetaData(item)
            end if

            objectsById[itemId] = obj

            if obj.metadata <> invalid then
                m.context.AddTail(obj)
                metadata.AddTail(obj.metadata)
                if item.GetInt("playQueueItemID") = playQueue.selectedID then
                    m.curIndex = m.context.Count() - 1
                end if
            end if
        end if
    next

    m.metadataById = objectsById

    ' If we're already playing something, then we want the next index
    ' instead of the matching index.
    '
    if m.isPlaying or m.isPaused then
        nextIndex = m.AdvanceIndex(1, false)
    else
        nextIndex = m.curIndex
    end if

    m.SetContentList(metadata, nextIndex)

    ' Update our controllable items based on the PQ size
    NowPlayingManager().SetControllable(m.timelineType, "skipPrevious", (m.curIndex > 0 or m.repeat = m.REPEAT_ALL))
    NowPlayingManager().SetControllable(m.timelineType, "skipNext", (m.curIndex < m.context.Count() - 1 or m.repeat = m.REPEAT_ALL))

    ' Update shuffle and repeat according to the PQ
    m.isShuffled = playQueue.isShuffled
    m.Trigger("shuffle", [m, m.GetCurrentItem(), m.isShuffled])
    NowPlayingManager().timelines[m.timelineType].attrs["shuffle"] = iif(m.isShuffled, "1", "0")

    if m.repeat <> m.REPEAT_ONE then
        m.repeat = iif(playQueue.isRepeat, m.REPEAT_ALL, m.REPEAT_NONE)
    end if
    NowPlayingManager().timelines[m.timelineType].attrs["repeat"] = tostr(m.repeat)

    if m.context.Count() > 0 and oldSize = 0 then
        m.Play()
        m.Trigger("playbackStarted", [m, m.GetCurrentItem()])
    end if

    ' Verify the contents of the playQueue have changed before we fire off an event.
    if m.context.count() > 0 then
        changes.first = m.context[0].item.GetInt("playQueueItemID")
        changes.last = m.context.Peek().item.GetInt("playQueueItemID")
        if (changes.first <> changes.origFirst or changes.last <> changes.origLast) then
            m.Trigger("change", [m, m.GetCurrentItem()])
        end if
    end if
end sub

sub bpOnTimelineTimer(timer as object)
    m.UpdateNowPlaying(true)
end sub

function bpShouldSendTimeline(item as object) as boolean
    return (item.Get("ratingKey") <> invalid and item.GetServer() <> invalid)
end function

sub bpUpdateNowPlaying(force=false as boolean, refreshQueue=false as boolean)
    if m.ignoreTimelines then return

    item = m.GetCurrentItem()

    if not m.ShouldSendTimeline(item) then return

    ' Avoid duplicates
    if m.playState = m.lastTimelineState and not force then return

    m.lastTimelineState = m.playState
    m.timelineTimer.Mark()

    time = m.GetPlaybackPosition(true)

    m.Trigger("progress", [m, item, time])

    if refreshQueue and m.playQueue <> invalid then
        m.playQueue.refreshOnTimeline = true
    end if
    NowPlayingManager().UpdatePlaybackState(m.timelineType, item, m.playState, time, m.playQueue)
end sub

sub bpSetRepeat(mode as integer)
    if m.repeat = mode then return

    ' Tell the Play Queue to set this repeat mode
    m.playQueue.SetRepeat(mode)

    m.repeat = mode

    m.Trigger("repeat", [m, m.GetCurrentItem(), m.repeat])
    NowPlayingManager().timelines[m.timelineType].attrs["repeat"] = tostr(mode)
end sub

sub bpSetShuffle(shuffle as boolean)
    if shuffle = m.isShuffled then return

    ' Tell the Play Queue to (un)shuffle itself
    m.playQueue.SetShuffle(shuffle)

    m.isShuffled = shuffle

    m.Trigger("shuffle", [m, m.GetCurrentItem(), m.isShuffled])
    NowPlayingManager().timelines[m.timelineType].attrs["shuffle"] = iif(shuffle, "1", "0")
end sub

sub bpSetPlayState(state as string)
    if state = m.STATE_STOPPED then
        m.isPlaying = false
        m.isPaused = false
    else if state = m.STATE_PAUSED then
        m.isPlaying = false
        m.isPaused = true
    else
        m.isPlaying = true
        m.isPaused = false
    end if

    m.playState = state
end sub

function bpGetCurrentItem() as dynamic
    if m.context = invalid or m.curIndex = invalid or m.curIndex >= m.context.Count() then return invalid

    return m.context[m.curIndex].item
end function

function bpGetNextItem() as dynamic
    if m.context = invalid or m.curIndex = invalid then return invalid

    if m.repeat = m.REPEAT_ONE then
        index = m.curIndex
    else
        index = m.curIndex + 1
        if m.repeat = m.REPEAT_ALL and index >= m.context.Count() then
            index = 0
        end if
    end if

    if index >= m.context.Count() then return invalid

    return m.context[index].item
end function

function bpGetCurrentMetadata() as dynamic
    if m.context = invalid or m.curIndex = invalid or m.curIndex >= m.context.Count() then return invalid

    return m.context[m.curIndex].metadata
end function

sub bpOnPlayButton()
    if m.isPaused then
        m.Resume()
    else if m.isPlaying then
        m.Pause()
    else if m.GetCurrentItem() <> invalid then
        m.Play()
    end if
end sub

sub bpOnFwdButton()
    ' no-op
end sub

sub bpOnRevButton()
    ' no-op
end sub

function GetPlayerForType(mediaType as dynamic) as dynamic
    if mediaType = "music" or mediaType = "audio" then
        return AudioPlayer()
    else if mediaType = "photo" then
        ' return PhotoPlayer()
    else if mediaType = "video" then
        return VideoPlayer()
    end if

    return invalid
end function
