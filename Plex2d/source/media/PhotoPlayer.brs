function PhotoPlayer() as object
    if m.PhotoPlayer = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(BasePlayerClass())

        obj.player = createPhotoScreen(obj)

        obj.timelineType = "photo"

        ' Required methods for BasePlayer
        obj.PlayItemAtIndex = ppPlayItemAtIndex
        obj.SetContentList = ppSetContentList
        obj.IsPlayable = ppIsPlayable
        obj.CreateContentMetadata = ppCreateContentMetadata
        obj.GetPlaybackPosition = ppGetPlaybackPosition

        ' Method overrides
        obj.Play = ppPlay
        obj.Stop = ppStop
        obj.Pause = ppPause
        obj.Resume = ppResume

        obj.Cleanup = ppCleanup

        ' TODO(rob): playback analytics?

        obj.Init()

        m.PhotoPlayer = obj
    end if

    return m.PhotoPlayer
end function

sub ppPlay()
    ApplyFunc(BasePlayerClass().Play, m)

    ' Handle starting the player paused and sending timelines for either
    if m.startPaused = true then
        m.Pause()
        m.Delete("startPaused")
    else
        m.ignoreTimelines = false
        m.UpdateNowPlaying(true, false)
    end if
end sub

sub ppPause(playing=false as boolean)
    ' Handle pausing player, but overriding the timeline statue
    m.ignoreTimelines = false
    m.SetPlayState(iif(playing, m.STATE_PLAYING, m.STATE_PAUSED))
    m.UpdateNowPlaying(true, false)

    ApplyFunc(BasePlayerClass().Pause, m)
    m.Trigger("paused", [m, m.GetCurrentItem()])
end sub

sub ppResume()
    m.ignoreTimelines = false
    m.SetPlayState(m.STATE_PLAYING)
    m.UpdateNowPlaying(true, false)

    ApplyFunc(BasePlayerClass().Resume, m)
    m.Trigger("resumed", [m, m.GetCurrentItem()])
end sub

sub ppStop()
    if m.context <> invalid then
        m.ClearPlayQueue()
        m.player.Stop()
        m.SetPlayState(m.STATE_STOPPED)
        m.UpdateNowPlaying()
        m.Trigger("stopped", [m, m.GetCurrentItem()])
        m.curIndex = 0
        m.context = invalid
        m.timelineTimer.active = false

        ' Reinstantiate the player
        m.Delete("player")
        m.player = createPhotoScreen(m)
    end if
end sub

sub ppPlayItemAtIndex(index as integer)
    m.ignoreTimelines = true
    m.SetCurrentIndex(index)
    m.player.SetNext(index)
    m.Play()
    m.Trigger("playing", [m, m.GetCurrentItem()])
end sub

sub ppSetContentList(metadata as object, nextIndex as integer)
    m.player.SetContentList(metadata)
    m.player.SetNext(nextIndex)
end sub

function ppIsPlayable(item as object) as boolean
    return item.IsPhotoItem()
end function

function ppCreateContentMetadata(item as object) as object
    obj = createPhotoObject(item)
    obj.Build()
    return obj
end function

sub ppCleanup()
    m.Stop()
    m.timelineTimer.active = false
    m.context = invalid
    m.curIndex = invalid
    m.playQueue = invalid
    m.metadataById.Clear()
end sub

function ppGetPlaybackPosition(millis=false as boolean) as integer
    return 0
end function
