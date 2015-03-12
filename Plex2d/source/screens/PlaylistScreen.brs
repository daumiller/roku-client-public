function PlaylistScreen() as object
    if m.PlaylistScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ContextListScreen())

        obj.screenName = "Playlist Screen"

        ' Methods
        obj.InitItem = playlistInitItem
        obj.GetComponents = playlistGetComponents

        ' Methods for playlists
        obj.GetListComponent = playlistGetListComponent
        obj.SetNowPlaying = playlistSetNowPlaying

        ' Listener Methods
        obj.OnPlay = playlistOnPlay
        obj.OnStop = playlistOnStop
        obj.OnPause = playlistOnPause
        obj.OnResume = playlistOnResume

        m.PlaylistScreen = obj
    end if

    return m.PlaylistScreen
end function

function createPlaylistScreen(item as object, path=invalid as dynamic) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(PlaylistScreen())

    obj.requestItem = item
    obj.path = path

    obj.Init()

    return obj
end function

sub playlistGetComponents()
    m.DestroyComponents()
    m.focusedItem = invalid

    ' set the duration, unless the PMS supplies it.
    if m.item.Get("duration") = invalid and m.duration > 0 then
        m.item.Set("duration", m.duration.toStr())
    end if

    ' *** Background Artwork *** '
    m.background = createBackgroundImage(m.item)
    m.background.thumbAttr = ["composite", "art", "parentThumb", "thumb"]
    m.components.Push(m.background)
    m.SetRefreshCache("background", m.background)

    ' *** HEADER *** '
    m.header = createHeader(m)
    m.components.Push(m.header)

    ' *** Buttons *** '
    vbButtons = createVBox(false, false, false, m.specs.childSpacing)
    vbButtons.SetFrame(m.specs.xOffset, m.specs.yOffset, 100, 720 - m.specs.yOffset)
    vbButtons.ignoreFirstLast = true
    for each comp in m.GetButtons()
        vbButtons.AddComponent(comp)
    end for
    m.components.Push(vbButtons)
    m.specs.xOffset = m.specs.xOffset + m.specs.parentSpacing + vbButtons.width

    ' *** playlist title ***
    lineHeight = FontRegistry().NORMAL.GetOneLineHeight()
    playlistTitle = createLabel("PLAYLISTS / " + ucase(m.item.Get("title")), FontRegistry().NORMAL)
    playlistTitle.SetFrame(m.specs.xOffset, m.specs.yOffset - m.specs.childSpacing - lineHeight, m.specs.parentWidth, lineHeight)
    m.components.Push(playlistTitle)

    ' *** playlist image ***
    m.image = createImage(m.item, m.specs.parentWidth, m.specs.parentHeight)
    m.image.fade = true
    m.image.cache = true
    m.image.SetOrientation(m.image.ORIENTATION_SQUARE)
    m.image.SetFrame(m.specs.xOffset, m.specs.yOffset, m.specs.parentWidth, m.specs.parentHeight)
    m.components.Push(m.image)
    m.SetRefreshCache("image", m.image)

    ' xOffset share with Summary and Track list
    m.specs.xOffset = m.specs.xOffset + m.specs.parentSpacing + m.specs.parentWidth
    m.trackBG = createBlock(m.listPrefs.background)
    m.trackBG.zOrder = m.listPrefs.zOrder
    m.trackBG.setFrame(m.specs.xOffset, m.header.GetPreferredHeight(), 1280 - m.specs.xOffset, 720 - m.header.GetPreferredHeight())
    m.components.Push(m.trackBG)

    ' TODO(rob): HD/SD note. We need to set some contstants for safe viewable areas of the
    ' screen. We have arbitrarily picked 50px. e.g. x=50, w=1230, so we'll assume the same
    ' for y and height, e.g. y=50, h=670.

    itemListY = m.header.GetPreferredHeight() + m.specs.childSpacing
    itemListH = AppSettings().GetHeight() - itemListY
    m.itemList = createVBox(false, false, false, 0)
    m.itemList.SetFrame(m.specs.xOffset + m.specs.parentSpacing, itemListY, m.listPrefs.width, itemListH)
    m.itemList.SetScrollable(AppSettings().GetHeight() / 2, true, true, invalid)
    m.itemList.stopShiftIfInView = true
    m.itemList.scrollOverflow = true

    ' *** Playlist Items *** '
    trackCount = m.children.Count()
    ' create a shared region for the separator
    sepRegion = CreateRegion(m.listPrefs.width, 1, Colors().Separator)
    for index = 0 to trackCount - 1
        item = m.children[index]
        track = createTrack(item, FontRegistry().NORMAL, FontRegistry().NORMAL, m.customFonts.trackStatus, trackCount, true)
        track.Append(m.listPrefs)
        track.plexObject = item
        track.trackIndex = index
        track.SetIndex(index + 1)
        track.SetFocusable("play")
        m.itemList.AddComponent(track)
        if m.focusedItem = invalid then m.focusedItem = track

        if index < trackCount - 1 then
            track.AddSeparator(sepRegion)
        end if
    end for
    m.components.Push(m.itemList)

    ' Set the focus to the current AudioPlayer track, if applicable.
    component = m.GetListComponent(m.player.GetCurrentItem())
    if component <> invalid then
        m.focusedItem = component
        if m.player.isPlaying then
            m.OnPlay(m.player, component.plexObject)
        else if m.player.isPaused then
            m.OnPause(m.player, component.plexObject)
        end if
    end if

    ' Background of focused item. We cannot just change the background
    ' of the track composite due to the aliasing issues.
    m.focusBG = createBlock(Colors().GetAlpha("Black", 60))
    m.focusBG.setFrame(0, 0, m.listPrefs.width, m.listPrefs.height)
    m.focusBG.fixed = false
    m.focusBG.zOrderInit = -1
    m.components.Push(m.focusBG)

    ' Static description box
    descBox = createStaticDescriptionBox(m.item.GetChildCountString(), m.item.GetDuration())
    descBox.setFrame(50, 630, 1280-50, 100)
    m.components.Push(descBox)
end sub

sub playlistInitItem()
    ApplyFunc(ContextListScreen().InitItem, m)

    if m.item.Get("playlistType") = "audio" then
        m.player = AudioPlayer()

        m.listPrefs.width = 635
        m.listPrefs.height = 73

        m.AddListener(m.player, "playing", CreateCallable("OnPlay", m))
        m.AddListener(m.player, "stopped", CreateCallable("OnStop", m))
        m.AddListener(m.player, "paused", CreateCallable("OnPause", m))
        m.AddListener(m.player, "resumed", CreateCallable("OnResume", m))
    else
        m.player = VideoPlayer()

        m.listPrefs.width = 677
        m.listPrefs.height = 120
    end if
end sub

sub playlistOnPlay(player as object, item as object)
    m.SetNowPlaying(item, true)
end sub

sub playlistOnStop(player as object, item as object)
    m.SetNowPlaying(item, false)
end sub

sub playlistOnPause(player as object, item as object)
    m.paused = m.GetListComponent(item)
    m.SetNowPlaying(item, false)
end sub

sub playlistOnResume(player as object, item as object)
    m.paused = invalid
    m.SetNowPlaying(item, true)
end sub

sub playlistSetNowPlaying(plexObject as object, status=true as boolean)
    if not Application().IsActiveScreen(m) then return

    if m.paused <> invalid and m.paused.plexObject.Get("key") <> plexObject.Get("key") then
        m.paused.SetPlaying(false)
        m.paused = invalid
    end if

    if m.playing <> invalid and m.playing.plexObject.Get("key") <> plexObject.Get("key") then
        m.playing.SetPlaying(false)
        m.playing = invalid
    end if

    component = m.GetListComponent(plexObject)
    if component <> invalid then
        component.SetPlaying(status)
        m.playing = iif(status, component, invalid)
    end if
end sub

function playlistGetListComponent(plexObject as dynamic) as dynamic
    if plexObject = invalid or m.item = invalid then return invalid

    ' locate the component by the plexObect and return
    for each track in m.itemList.components
        if track.plexObject <> invalid and plexObject.Get("key") = track.plexObject.Get("key") then
            return track
        end if
    end for

    return invalid
end function
