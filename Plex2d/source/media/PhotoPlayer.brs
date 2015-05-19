function PhotoPlayer() as object
    if m.PhotoPlayer = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(BasePlayerClass())

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

    ' Our own custom PhotoScreen (roSlideShow). This will be destroyed
    ' when we stop the photo player.
    if m.PhotoPlayer.player = invalid then
        m.PhotoPlayer.player = createPhotoScreen(m.PhotoPlayer)
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
        m.player.SetContentList([])
        m.player.SetNext(m.curIndex)
        m.timelineTimer.active = false
        m.Delete("player")
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
    ' We don't need a custom object since we control our own photo
    ' player, but we'll return the expected structure, as the base
    ' player expects it.
    '
    return {item: item, metadata: item}
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
