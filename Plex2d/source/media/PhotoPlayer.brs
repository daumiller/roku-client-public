function PhotoPlayer() as object
    if m.PhotoPlayer = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(BasePlayerClass())

        ' Our own custom PhotoScreen (roSlideShow)
        obj.player = createPhotoScreen(obj)

        obj.timelineType = "photo"

        ' Required methods for BasePlayer
        obj.PlayItemAtIndex = ppPlayItemAtIndex
        obj.SetContentList = ppSetContentList
        obj.IsPlayable = ppIsPlayable
        obj.CreateContentMetadata = ppCreateContentMetadata
        obj.GetPlaybackPosition = ppGetPlaybackPosition

        ' Method overrides
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

sub ppPause()
    m.ignoreTimelines = false
    m.SetPlayState(m.STATE_PAUSED)
    m.UpdateNowPlaying(true, false)

    ApplyFunc(BasePlayerClass().Pause, m)
end sub

sub ppResume()
    m.ignoreTimelines = false
    m.SetPlayState(m.STATE_PLAYING)
    m.UpdateNowPlaying(true, false)

    ApplyFunc(BasePlayerClass().Resume, m)
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
    end if
end sub

sub ppPlayItemAtIndex(index as integer)
    m.ignoreTimelines = true
    m.SetCurrentIndex(index)
    m.player.SetNext(index)
    m.Play()
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
