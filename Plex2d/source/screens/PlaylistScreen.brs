function PlaylistScreen() as object
    if m.PlaylistScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ContextListScreen())

        obj.screenName = "Playlist Screen"

        ' Methods
        obj.InitItem = playlistInitItem
        obj.GetComponents = playlistGetComponents
        obj.HandleCommand = playlistHandleCommand

        ' Methods for playlists
        obj.GetListComponent = playlistGetListComponent
        obj.SetNowPlaying = playlistSetNowPlaying

        ' Listener Methods
        obj.OnPlay = playlistOnPlay
        obj.OnStop = playlistOnStop
        obj.OnPause = playlistOnPause
        obj.OnResume = playlistOnResume
        obj.OnRefreshMetadata = playlistOnRefreshMetadata
        obj.OnRefreshItems = playlistOnRefreshItems

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

    ' Initialize our track actions and save room for them
    if m.playlistType = "audio" then
        m.trackActions = createButtonGrid(2, 2, 36)
    else
        m.trackActions = createButtonGrid(4, 1, 30)
    end if

    m.listPrefs.width = m.listPrefs.width - m.trackActions.GetPreferredWidth()

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

    ' *** Track actions ***
    actions = CreateObject("roList")

    if m.playlistType = "audio" then
        moreOptions = CreateObject("roList")

        moreOptions.Push({text: "Play Music Video", command: "play_music_video", visibleCallable: createCallable(ItemHasMusicVideo, invalid)})
        moreOptions.Push({text: "Plex Mix", command: "play_plex_mix", visibleCallable: createCallable(ItemHasPlexMix, invalid)})
        moreOptions.Push({text: "Go to Artist", command: "go_to_artist"})
        moreOptions.Push({text: "Go to Album", command: "go_to_album"})

        actions.Push({text: Glyphs().ELLIPSIS, type: "dropDown", position: "down", options: moreOptions, font: m.customFonts.trackActions})
        actions.Push({text: Glyphs().ARROW_UP, command: "move_item_up", font: m.customFonts.trackActions})
        actions.Push({text: Glyphs().CIR_X, command: "remove_item", font: m.customFonts.trackActions})
        actions.Push({text: Glyphs().ARROW_DOWN, command: "move_item_down", font: m.customFonts.trackActions})
    else
        actions.Push({text: Glyphs().ARROW_UP, command: "move_item_up", font: m.customFonts.trackActions})
        actions.Push({text: Glyphs().EYE, command: "toggle_watched", font: m.customFonts.trackActions, commandCallback: createCallable("Refresh", m.item, invalid, [false, true])})
        actions.Push({text: Glyphs().CIR_X, command: "remove_item", font: m.customFonts.trackActions})
        actions.Push({text: Glyphs().ARROW_DOWN, command: "move_item_down", font: m.customFonts.trackActions})
    end if

    buttonFields = {trackAction: true}
    m.trackActions.AddButtons(actions, buttonFields, m)
    m.components.Push(m.trackActions)

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

    ' Description box
    m.descBox = createStaticDescriptionBox(m.item.GetChildCountString(), m.item.GetDuration())
    m.descBox.setFrame(50, 630, 1280-50, 100)
    m.components.Push(m.descBox)
end sub

sub playlistInitItem()
    ApplyFunc(ContextListScreen().InitItem, m)

    m.item.items = m.children

    m.AddListener(m.item, "change:metadata", CreateCallable("OnRefreshMetadata", m))
    m.AddListener(m.item, "change:items", CreateCallable("OnRefreshItems", m))

    m.playlistType = m.item.Get("playlistType", "video")

    if m.playlistType = "audio" then
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

function playlistHandleCommand(command as string, item as dynamic) as boolean
    handled = true

    ' If it was a track action, make sure it has the last focused track set as its item
    if item <> invalid and item.trackAction = true then
        item.plexObject = m.focusedListItem.plexObject
        overlay = m.overlayScreen.Peek()
        if overlay <> invalid then overlay.Close()
    end if

    swapIndex = invalid
    focusItem = invalid
    refreshMetadata = false
    refreshItems = false

    if command = "move_item_down" then
        if m.item.MoveItemDown(m.focusedListItem.plexObject) then
            swapIndex = m.focusedListItem.trackIndex
            focusItem = m.focusedListItem
        end if
    else if command = "move_item_up" then
        if m.item.MoveItemUp(m.focusedListItem.plexObject) then
            swapIndex = m.focusedListItem.trackIndex - 1
            focusItem = m.focusedListItem
        end if
    else if command = "remove_item" then
        m.item.RemoveItem(m.focusedListItem.plexObject)
    else
        handled = ApplyFunc(ContextListScreen().HandleCommand, m, [command, item])
    end if

    if swapIndex <> invalid and swapIndex >= 0 then
        firstComponent = m.itemList.components[swapIndex]
        secondComponent = m.itemList.components[swapIndex + 1]

        firstX = firstComponent.x
        firstY = firstComponent.y

        firstComponent.SetPosition(secondComponent.x, secondComponent.y)
        secondComponent.SetPosition(firstX, firstY)

        m.itemList.components[swapIndex] = secondComponent
        m.itemList.components[swapIndex + 1] = firstComponent

        firstComponent.trackIndex = firstComponent.trackIndex + 1
        secondComponent.trackIndex = secondComponent.trackIndex - 1

        firstComponent.SetFocusSibling("down", secondComponent.GetFocusSibling("down"), true)
        secondComponent.SetFocusSibling("up", firstComponent.GetFocusSibling("up"), true)
        secondComponent.SetFocusSibling("down", firstComponent, true)
    end if

    if focusItem <> invalid then
        m.OnFocus(focusItem, focusItem, "up")
        m.OnFocus(item, focusItem, "right")
    end if

    m.item.Refresh(refreshMetadata, refreshItems)

    return true
end function

sub playlistOnRefreshMetadata(playlist as object)
    m.item = playlist
    m.descBox.SetText(m.item.GetChildCountString(), m.item.GetDuration())
end sub

sub playlistOnRefreshItems(playlist as object)
    m.children = playlist.items
    m.Show()

    ' TODO(schuyler): Find a reasonable way to refocus whatever we used to be on.
end sub
