function NowPlayingQueueOverlayClass() as object
    if m.NowPlayingQueueOverlayClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(OverlayClass())

        obj.ClassName = "NowPlaying Overlay"

        ' Methods
        obj.Show = npqoShow
        obj.Init = npqoInit
        obj.GetComponents = npqoGetComponents
        obj.GetTrackComponent = npqoGetTrackComponent
        obj.SetNowPlaying = npqoSetNowPlaying
        obj.Refresh = npqoRefresh
        obj.DeferRefresh = npqoDeferRefresh
        obj.OnRefreshTimer = npqoOnRefreshTimer
        obj.SetControlSiblings = npqoSetControlSiblings

        ' Listener Methods
        obj.OnPlay = npqoOnPlay
        obj.OnStop = npqoOnStop
        obj.OnPause = npqoOnPause
        obj.OnResume = npqoOnResume
        obj.OnChange = npqoOnChange

        ' Import a few now playing screen methods
        obj.OnPlayButton = nowplayingOnPlayButton
        obj.OnFwdButton = nowplayingOnFwdButton
        obj.OnRevButton = nowplayingOnRevButton

        m.NowPlayingQueueOverlayClass = obj
    end if

    return m.NowPlayingQueueOverlayClass
end function

function createNowPlayingQueueOverlay(screen as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(NowPlayingQueueOverlayClass())

    obj.screen = screen

    obj.Init()

    return obj
end function

sub npqoInit()
    ApplyFunc(OverlayClass().Init, m)
    m.screen.OnFocusIn = npqoOnFocusIn
    m.enableOverlay = false

    m.customFonts = CreateObject("roAssociativeArray")
    m.customFonts.Append(m.screen.customFonts)
    m.customFonts.Append({
        trackStatus: FontRegistry().GetIconFont(20),
        trackActions: FontRegistry().GetIconFont(18)
    })

    ' Set up audio player listeners
    m.DisableListeners()
    m.player = AudioPlayer()
    m.AddListener(m.player, "playing", CreateCallable("OnPlay", m))
    m.AddListener(m.player, "stopped", CreateCallable("OnStop", m))
    m.AddListener(m.player, "paused", CreateCallable("OnPause", m))
    m.AddListener(m.player, "resumed", CreateCallable("OnResume", m))
    m.AddListener(m.player, "change", CreateCallable("OnChange", m))
end sub

sub npqoShow(refocusCommand=invalid as dynamic)
    ' Lock the screen updates
    m.screen.screen.DrawLock()

    ApplyFunc(OverlayClass().Show, m)

    ' Update the track component and shift the track list based on the item playing
    trackComp = m.GetTrackComponent(m.player.GetCurrentItem())
    if trackComp <> invalid then
        m.screen.CalculateShift(trackComp)

        if m.player.isPlaying then
            m.SetNowPlaying(trackComp.plexObject, true)
        else if m.player.isPaused then
            m.OnPause(m.player, trackComp.plexObject)
        end if
    end if

    ' Refocus the last control button if applicable
    toFocus = invalid
    if refocusCommand <> invalid then
        candidates = CreateObject("roList")
        m.controls.GetFocusableItems(candidates)
        for each candidate in candidates
            if refocusCommand = candidate.command then
                toFocus = candidate
                exit for
            end if
        end for
    end if

    ' TODO(rob): how do we want to handle queue updates when a user has scrolled
    ' away from the current playing item. As of now, we just move the focus to the
    ' current playing track, if focus is on the track list.

    ' Focus the current track or screens focused item if we didn't overrride
    m.screen.FocusItemManually(firstOf(toFocus, trackComp, m.screen.focusedItem))

    ' Unlock the screen and draw the updates
    m.screen.screen.DrawUnlock()
end sub

sub npqoGetComponents()
    isMixed = (m.player.playQueue.isMixed = true)

    ' *** Buttons *** '
    yOffset = m.screen.controlButtons.y
    buttonSpacing = 40
    buttonWidth = m.screen.queueProgress.width
    buttonHeight = AppSettings().GetHeight() - yOffset

    m.controls = createHBox(false, false, false, buttonSpacing)
    m.controls.SetFrame(0, yOffset, buttonWidth, buttonHeight)
    components = m.screen.GetButtons()
    for each key in components.keys
        controlsGroup = createHBox(false, false, false, 0)
        for each comp in components[key]
            controlsGroup.AddComponent(comp)
        end for
        m.controls.AddComponent(controlsGroup)
    end for

    ' Align the buttons in the middle of the content area
    m.controls.PerformLayout()
    width = m.controls.spacing * (m.controls.components.Count()-1)
    for each group in m.controls.components
        width = width + group.GetPreferredWidth()
    end for
    m.controls.SetFrame(int(buttonWidth/2 - width/2), yOffset, width, m.controls.GetPreferredHeight())
    m.components.Push(m.controls)

    ' Now Playing list
    padding = 20
    spacing = 0
    yOffset = 0
    xOffset = computeRect(m.screen.queueProgress).right
    height = AppSettings().GetHeight()

    m.trackActions = createButtonGrid(2, 2)

    trackPrefs = {
        background: Colors().GetAlpha(&hffffffff, 10),
        width: 1230 - xOffset - spacing - m.trackActions.GetPreferredWidth(),
        height: 80,
        fixed: false,
        focusBG: true,
        zOrder: m.zOrderOverlay,
        hasTrackActions: true
    }

    m.trackBG = createBlock(trackPrefs.background)
    m.trackBG.zOrder = trackPrefs.zOrder
    m.trackBG.setFrame(xOffset, yOffset, 1280 - xOffset, height)
    m.components.Push(m.trackBG)

    m.trackList = createVBox(false, false, false, 0)
    m.trackList.SetFrame(xOffset + padding, padding, trackPrefs.width + m.trackActions.GetPreferredWidth(), height - padding)
    m.trackList.SetScrollable(height / 2, true, true, invalid)
    m.trackList.stopShiftIfInView = true
    m.trackList.scrollOverflow = true

    ' *** Tracks *** '
    items = m.player.context
    trackCount = items.Count()
    ' create a shared region for the separator (conserve memory)
    sepRegion = CreateRegion(trackPrefs.width, 1, Colors().Separator)
    for index = 0 to trackCount - 1
        item = items.[index].item
        track = createTrack(item, FontRegistry().NORMAL, FontRegistry().MEDIUM, m.customFonts.trackStatus, m.player.playQueue.totalSize, isMixed)
        track.Append(trackPrefs)
        track.DisableNonParentExit("down")
        track.plexObject = item
        track.trackIndex = index
        track.SetFocusable("play")
        track.OnSelected = npqoTrackOnSelected
        track.overlay = m
        m.trackList.AddComponent(track)

        if m.screen.focusedItem = invalid then m.screen.focusedItem = track

        if index < trackCount - 1 then
            track.AddSeparator(sepRegion)
        end if
    end for
    m.components.Push(m.trackList)

    ' Track actions
    actions = createObject("roList")
    moreOptions = createObject("roList")

    moreOptions.Push({text: "Play Music Video", command: "play_music_video", visibleCallable: createCallable(ItemHasMusicVideo, invalid)})
    moreOptions.Push({text: "Plex Mix", command: "play_plex_mix", visibleCallable: createCallable(ItemHasPlexMix, invalid)})
    moreOptions.Push({text: "Go to Artist", command: "go_to_artist"})
    moreOptions.Push({text: "Go to Album", command: "go_to_album"})

    actions.Push({text: Glyphs().ELLIPSIS, type: "dropDown", position: "down", options: moreOptions})
    actions.Push({text: Glyphs().ARROW_UP, command: "move_item_up"})
    actions.Push({text: Glyphs().CIR_X, command: "remove_item"})
    actions.Push({text: Glyphs().ARROW_DOWN, command: "move_item_down"})

    for each action in actions
        action.Append({font: m.customFonts.trackActions, zOrderInit: -1})
    end for

    buttonFields = {
        ' A little unorthodox, but we want our overlay to be able to handle
        ' the button commands instead of the screen.
        overlay: m,
        OnSelected: npqoActionOnSelected
    }

    m.trackActions.AddButtons(actions, buttonFields, m.screen, m.zOrderOverlay)
    m.components.Push(m.trackActions)

    ' Background of focused item. We have to use a separate background
    ' component due to the aliasing issue.
    m.focusBG = createBlock(Colors().GetAlpha("Black", 40))
    m.focusBG.setFrame(0, 0, trackPrefs.width, trackPrefs.height)
    m.focusBG.fixed = false
    m.focusBG.zOrderInit = -1
    m.components.Push(m.focusBG)
end sub

sub npqoTrackOnSelected(screen as object)
    AudioPlayer().PlayItemAtPQIID(m.plexObject.GetInt("playQueueItemID"))
end sub

function npqoGetTrackComponent(plexObject as dynamic) as dynamic
    if plexObject = invalid then return invalid

    ' locate and return the component by the plexObject key
    for each track in m.trackList.components
        if track.plexObject <> invalid and plexObject.Get("key") = track.plexObject.Get("key") then
            return track
        end if
    end for

    return invalid
end function

sub npqoOnFocusIn(toFocus as object, lastFocus=invalid as dynamic)
    ApplyFunc(ComponentsScreen().OnFocusIn, m, [toFocus, lastFocus])

    ' Ignore further processing if we are focused on a track action
    if toFocus <> invalid and toFocus.parent <> invalid and toFocus.parent.ClassName = "ButtonGrid" then return

    ' Focus background (anti-alias workaround)
    overlay = m.overlayScreen[0]
    if toFocus <> invalid and toFocus.focusBG = true and overlay.focusBG <> invalid then
        overlay.focusBG.sprite.MoveTo(toFocus.x, toFocus.y)
        overlay.focusBG.sprite.SetZ(overlay.zOrderOverlay - 1)
    else
        overlay.focusBG.sprite.SetZ(-1)
    end if

    ' Track Actions visibility
    if toFocus <> invalid and toFocus.hasTrackActions = true then
        rect = computeRect(toFocus)
        overlay.trackActions.SetPosition(rect.right + 1, rect.up + int((rect.height - overlay.trackActions.GetPreferredHeight()) / 2))
        overlay.trackActions.SetVisible(true)
        overlay.focusedTrack = toFocus
        overlay.SetControlSiblings(toFocus)

        ' Toggle some of our track actions based on the current track
        overlay.trackActions.SetPlexObject(toFocus.plexObject)
    else
        overlay.trackActions.SetVisible(false)
    end if
end sub

sub npqoSetNowPlaying(plexObject as object, status=true as boolean)
    if m.paused <> invalid and m.paused.plexObject.Get("key") <> plexObject.Get("key") then
        m.paused.SetPlaying(false)
        m.paused = invalid
    end if

    if m.playing <> invalid and m.playing.plexObject.Get("key") <> plexObject.Get("key") then
        m.playing.SetPlaying(false)
        m.playing = invalid
    end if

    component = m.GetTrackComponent(plexObject)
    if component <> invalid and not component.Equals(m.playing) then
        component.SetPlaying(status)
        m.playing = iif(status, component, invalid)
    end if

    ' Set the now playing track as the controls focus sibling. We'll also update this
    ' if the user scrolls the list during playback.
    '
    if m.playing <> invalid then
        m.SetControlSiblings(m.playing)
    end if
end sub

sub npqoOnPlay(player as object, item as object)
    m.screen.screen.DrawLock()

    currentTrack = m.GetTrackComponent(item)
    m.screen.CalculateShift(currentTrack, computeRect(currentTrack))
    m.SetNowPlaying(item, true)

    m.screen.screen.DrawUnlock()
end sub

sub npqoOnStop(player as object, item as object)
    m.SetNowPlaying(item, false)
end sub

sub npqoOnPause(player as object, item as object)
    m.paused = m.GetTrackComponent(item)
    m.SetNowPlaying(item, false)
end sub

sub npqoOnResume(player as object, item as object)
    m.paused = invalid
    m.SetNowPlaying(item, true)
end sub

sub npqoOnChange(player as object, item as object)
    m.Refresh()
end sub

sub npqoRefresh()
    if not m.IsActive() or m.refreshTimer <> invalid then return

    TextureManager().DeleteCache()

    m.DestroyComponents()
    m.Show(m.screen.focusedItem.command)

    TextureManager().ClearCache()
end sub

sub npqoDeferRefresh()
    if m.refreshTimer = invalid then
        m.refreshTimer = createTimer("refresh")
        m.refreshTimer.SetDuration(5000)
        Application().AddTimer(m.refreshTimer, createCallable("OnRefreshTimer", m))
    end if

    m.refreshTimer.Mark()
end sub

sub npqoOnRefreshTimer(timer)
    m.refreshTimer = invalid
    m.Refresh()
end sub

sub npqoActionOnSelected(screen as object)
    ' We're evaluated in the context of the button, which has a reference to the
    ' overlay, which has a reference to the screen. But we'll just avoid using
    ' m to reduce confusion.

    btn = m
    overlay = btn.overlay
    player = screen.player
    command = btn.command
    focusedComponent = overlay.focusedTrack
    focusedTrack = focusedComponent.plexObject

    swapIndex = invalid
    focusItem = invalid

    if command = "move_item_up" then
        if player.playQueue.MoveItemUp(focusedTrack) then
            ' Move the items in the UI now, and then allow the PQ to refresh
            ' a few seconds after the user stops moving things around.
            '
            swapIndex = focusedComponent.trackIndex - 1
            focusItem = focusedComponent
            overlay.DeferRefresh()
        end if
    else if command = "move_item_down" then
        if player.playQueue.MoveItemDown(focusedTrack) then
            ' Move the items in the UI now, and then allow the PQ to refresh
            ' a few seconds after the user stops moving things around.
            '
            swapIndex = focusedComponent.trackIndex
            focusItem = focusedComponent
            overlay.DeferRefresh()
        end if
    else if command = "remove_item" then
        if focusedTrack.Equals(player.GetCurrentItem()) then
            player.Next()
        end if

        ' TODO(schuyler): This is maybe possible, but definitely trickier than
        ' the straight swap above.
        '
        ' if focusedComponent.trackIndex < overlay.trackList.components.Count() - 1 then
        '     focusItem = overlay.trackList.components[focusedComponent.trackIndex + 1]
        ' else
        '     focusItem = overlay.trackList.components[focusedComponent.trackIndex - 1]
        ' end if

        player.playQueue.RemoveItem(focusedTrack)
    else if command = "play_music_video" or command = "play_plex_mix" or command = "go_to_artist" or command = "go_to_album" then
        screen.overlayScreen.Peek().Close()

        ' We'll let the usual command handling do these, but we need to make
        ' sure our plexObject is set to the current track.

        btn.plexObject = focusedTrack
        screen.HandleCommand(command, btn)
    end if

    if swapIndex <> invalid and swapIndex >= 0 then
        firstComponent = overlay.trackList.components[swapIndex]
        secondComponent = overlay.trackList.components[swapIndex + 1]

        firstX = firstComponent.x
        firstY = firstComponent.y

        firstComponent.SetPosition(secondComponent.x, secondComponent.y)
        secondComponent.SetPosition(firstX, firstY)

        overlay.trackList.components[swapIndex] = secondComponent
        overlay.trackList.components[swapIndex + 1] = firstComponent

        firstComponent.trackIndex = firstComponent.trackIndex + 1
        secondComponent.trackIndex = secondComponent.trackIndex - 1

        firstComponent.SetFocusSibling("down", secondComponent.GetFocusSibling("down"), true)
        secondComponent.SetFocusSibling("up", firstComponent.GetFocusSibling("up"), true)
        secondComponent.SetFocusSibling("down", firstComponent, true)
    end if

    if focusItem <> invalid then
        screen.screen.DrawLock()

        screen.OnItemFocus(focusItem, focusItem, "up")
        screen.OnItemFocus(btn, focusItem, "right")

        screen.screen.DrawUnlock()
    end if
end sub

sub npqoSetControlSiblings(component as object)
    candidates = CreateObject("roList")
    m.controls.GetFocusableItems(candidates)
    for each comp in candidates
        comp.SetFocusSibling("up", component)
    end for
    candidates.Peek().SetFocusSibling("right", component)
end sub

function ItemHasMusicVideo(item as dynamic) as boolean
    if item = invalid then return false
    musicVideo = item.GetPrimaryExtra()
    return (musicVideo <> invalid)
end function

function ItemHasPlexMix(item as dynamic) as boolean
    if item = invalid then return false
    plexMix = item.GetRelatedItem("plexmix")
    return (plexMix <> invalid)
end function
