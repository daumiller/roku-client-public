function PhotoControlOverlayClass() as object
    if m.PhotoControlOverlayClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(OverlayClass())

        obj.ClassName = "Photo Overlay"

        ' Methods
        obj.Init = pcoInit
        obj.Show = pcoShow
        obj.Refresh = pcoRefresh
        obj.Close = pcoClose
        obj.GetComponents = pcoGetComponents
        obj.GetItemComponent = pcoGetItemComponent
        obj.GetButtons = pcoGetButtons
        obj.SetNowPlaying = pcoSetNowPlaying
        obj.UpdatePlayState = pcoUpdatePlayState
        obj.OnFocusIn = pcoOnFocusIn

        ' Timer Methods
        obj.DeferSelected = pcoDeferSelected
        obj.OnSelectedTimer = pcoOnSelectedTimer
        obj.OnOverlayTimer = pcoOnOverlayTimer

        ' Listener Methods
        obj.OnPlay = pcoOnPlay
        obj.OnPause = pcoOnPause
        obj.OnResume = pcoOnResume
        obj.OnChange = pcoOnChange

        ' Message handling overrides
        obj.OnKeyPress = pcoOnKeyPress
        obj.OnKeyRelease = pcoOnKeyRelease
        obj.OnFwdButton = pcoOnFwdButton
        obj.OnRevButton = pcoOnRevButton
        obj.OnPlayButton = pcoOnPlayButton
        obj.OnSelected = pcoOnSelected

        m.PhotoControlOverlayClass = obj
    end if

    return m.PhotoControlOverlayClass
end function

function createPhotoControlOverlay(screen as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(PhotoControlOverlayClass())

    obj.screen = screen

    obj.Init()

    return obj
end function

sub pcoInit()
    ApplyFunc(OverlayClass().Init, m)
    m.enableOverlay = false

    ' Intialize custom fonts for this screen
    m.customFonts = {
        glyphs: FontRegistry().GetIconFont(28)
        title: FontRegistry().GetTextFont(32)
        titleStrong: FontRegistry().GetTextFont(32, True)
    }

    ' Set up audio player listeners
    m.DisableListeners()
    m.player = PhotoPlayer()
    m.AddListener(m.player, "playing", CreateCallable("OnPlay", m))
    m.AddListener(m.player, "paused", CreateCallable("OnPause", m))
    m.AddListener(m.player, "resumed", CreateCallable("OnResume", m))
    m.AddListener(m.player, "change", CreateCallable("OnChange", m))
end sub

sub pcoShow()
    ' Lock the screen updates
    m.screen.screen.DrawLock()

    ApplyFunc(OverlayClass().Show, m, [false, true])

    ' Default (fallback) focus to the current item
    toFocus = m.GetItemComponent(m.player.GetCurrentItem())

    ' Try to refocus on our last focused item (after refreshing)
    if m.screen.HasRefocusItem() then
        candidates = CreateObject("roList")
        for each component in m.components
            component.GetFocusableItems(candidates)
        end for
        for each candidate in candidates
            if m.screen.IsRefocusItem(candidate) then
                toFocus = candidate
                exit for
            end if
        end for
        m.screen.Delete("refocusKey")
    end if

    ' Let our overlay know the what the current item is and draw our focus
    m.SetNowPlaying(m.player.GetCurrentItem())
    m.screen.FocusItemManually(firstOf(toFocus, m.screen.focusedItem), false)

    ' Unlock the screen and draw the updates
    m.screen.screen.DrawUnlock()

    ' Add an overlay timer to close when idle
    m.overlayTimer = createTimer("overlay")
    m.overlayTimer.SetDuration(3000)
    Application().AddTimer(m.overlayTimer, createCallable("OnoverlayTimer", m))
end sub

sub pcoGetComponents()
    displayHeight = AppSettings().GetHeight()
    displayWidth = AppSettings().GetWidth()

    ' TODO(rob): clean the layout/position
    overlayHeight = 280
    gridHeight = 150

    overlayYOffset = displayHeight - overlayHeight
    buttonYOffset = overlayYOffset + 28
    gridYOffset = overlayYOffset + 90
    gridXOffset = 50

    buttonSpacing = 100
    gridSpacing = 10

    ' *** Overlay background ***
    background = createBlock(Colors().GetAlpha("Black", 70))
    background.setFrame(0, overlayYOffset, displayWidth, overlayHeight)
    m.components.Push(background)

    ' *** Controls ***
    m.controlButtons = createHBox(false, false, false, buttonSpacing, false)

    components = m.GetButtons()
    for each key in components.keys
        controlsGroup = createHBox(false, false, false, 0)
        for each comp in components[key]
            controlsGroup.AddComponent(comp)
        end for
        m.controlButtons.AddComponent(controlsGroup)
    end for

    ' Align the buttons in the middle of the screen
    buttonHeight = m.controlButtons.GetPreferredHeight()
    buttonWidth = m.controlButtons.GetPreferredWidth()
    m.controlButtons.SetFrame(int(displayWidth/2 - buttonWidth/2), buttonYOffset, buttonWidth, buttonHeight)
    m.controlButtons.SetFocusManual(m.screen.focusedItem)
    m.components.Push(m.controlButtons)

    ' *** Photo grid ***
    m.itemList = createHBox(false, false, false, gridSpacing, false)
    m.itemList.DisableNonParentExit("right")
    m.itemList.DisableNonParentExit("left")
    m.itemList.ignoreParentShift = true
    m.itemList.demandCenter = true

    listPrefs = {
        overlay: m,
        fixed: false,
        cache: true,
        bgColor: Colors().Transparent,
        zOrder: m.zOrderOverlay,
        OnSelected: pcoOnSelected
    }

    context = m.player.context
    for index = 0 to context.Count() - 1
        item = context[index].item
        image = createImage(item, gridHeight, gridHeight)
        image.Append(listPrefs)
        image.plexObject = item
        image.SetFocusable("play_item")

        if index = 0 then
            m.itemList.SetFocusManual(image)
            m.screen.focusedItem = image
        end if
        m.itemList.AddComponent(image)
    end for
    m.itemList.SetFrame(gridXOffset, gridYOffset, displayWidth, gridHeight)

    m.components.Push(m.itemList)
end sub

function pcoGetItemComponent(plexObject as dynamic) as dynamic
    if plexObject = invalid then return invalid

    ' locate the plexObject by key and return it
    for each item in m.itemList.components
        if item.plexObject <> invalid and plexObject.Get("key") = item.plexObject.Get("key") then
            return item
        end if
    end for

    return invalid
end function

sub pcoOnFocusIn(toFocus as object, lastFocus=invalid as dynamic)
    ApplyFunc(ComponentsScreen().OnFocusIn, m, [toFocus, lastFocus])

    overlay = m.overlayscreen.Peek()
    player = overlay.player
    plexObject = toFocus.plexObject

    ' Defer OnSelected for the focused item
    if plexObject <> invalid and plexObject.Has("playQueueItemID") then
        if not plexObject.Equals(player.GetCurrentItem()) then
            overlay.DeferSelected(toFocus)
        end if
    end if
end sub

sub pcoSetNowPlaying(item as object)
    currentItem = m.GetItemComponent(item)
    if currentItem <> invalid then
        m.itemList.SetFocusManual(currentItem)
        m.screen.CalculateShift(currentItem, computeRect(currentItem))
    end if
end sub

sub pcoOnPlay(player as object, item as object)
    m.SetNowPlaying(item)
end sub

sub pcoOnPause(player as object, item as object)
    m.UpdatePlayState(false)
end sub

sub pcoOnResume(player as object, item as object)
    m.UpdatePlayState(true)
end sub

sub pcoOnChange(player as object, item as object)
    m.Refresh()
end sub

sub pcoRefresh()
    if not m.IsActive() then return

    m.overlayTimer.Pause()
    TextureManager().DeleteCache()

    m.screen.SetRefocusItem(m.screen.focusedItem)
    m.DestroyComponents()
    m.Show()

    TextureManager().ClearCache()
    m.overlayTimer.Resume()
end sub

function pcoGetButtons() as object
    components = createObject("roAssociativeArray")
    components.keys = ["left", "middle", "right"]

    buttons = createObject("roAssociativeArray")

    buttons["left"] = createObject("roList")
    if m.player.playQueue <> invalid and m.player.playQueue.supportsShuffle = true then
        buttons["left"].push({text: Glyphs().SHUFFLE, command: "shuffle", componentKey: "shuffleButton", statusColor: iif(m.player.isShuffled, Colors().Orange, invalid) })
    end if

    buttons["middle"] = createObject("roList")
    buttons["middle"].push({text: Glyphs().STEP_REV, command: "prev", componentKey: "prevButton"})
    buttons["middle"].push({text: iif(m.screen.wasPlaying = true, Glyphs().PAUSE, Glyphs().PLAY), command: "play_toggle", componentKey: "playButton", defaultFocus: true})
    buttons["middle"].push({text: Glyphs().STEP_FWD, command: "next", componentKey: "nextButton"})

    buttons["right"] = createObject("roList")
    buttons["right"].push({text: Glyphs().STOP, command: "stop", componentKey: "stopButton"})

    padding = cint(m.customFonts.glyphs.GetOneLineHeight() / 3)
    for each key in components.keys
        for each button in buttons[key]
            if components[key] = invalid then components[key] = createObject("roList")
            btn = createButton(button.text, m.customFonts.glyphs, button.command)
            btn.overlay = m
            btn.isControl = true
            btn.SetColor(firstOf(button.statusColor, Colors().Subtitle))
            btn.SetFocusMethod(btn.FOCUS_FOREGROUND, Colors().OrangeLight)
            btn.SetPadding(0, 0, 0, padding)
            btn.OnSelected = pcoOnSelected

            if m.screen.focusedItem = invalid or button.defaultFocus = true then
                m.screen.focusedItem = btn
            end if

            ' use unique key reference for the screen and overlay
            componentKey = iif(m.showQueue = true, "queue" + button.componentKey, button.componentKey)
            m[componentKey] = btn
            components[key].push(btn)
        end for
    end for

    return components
end function

sub pcoOnKeyRelease(keyCode as integer)
    ' Verify our key release came from the overlay
    overlay = m.overlayScreen.Peek()
    if overlay.Delete("hadKeyPress") then
        if keyCode = m.kp_BK then
            overlay.Close()
        else
            ApplyFunc(ComponentsScreen().OnKeyRelease, m, [keyCode])
        end if
    end if
end sub

sub pcoOnKeyPress(keyCode as integer, repeat as boolean)
    overlay = m.overlayScreen.Peek()
    overlay.overlayTimer.Pause()
    overlay.hadKeyPress = true

    ' We're evaluated in the context of the base screen
    isControl = (m.focusedItem <> invalid and m.focusedItem.isControl = true)
    if (keyCode = m.kp_UP and isControl) or (keyCode = m.kp_DN and not isControl) then
        overlay.Close()
    else
        ApplyFunc(ComponentsScreen().OnKeyPress, m, [keyCode, repeat])
    end if

    if overlay.overlayTimer <> invalid then
        overlay.overlayTimer.Resume()
    end if
end sub

sub pcoOnFwdButton(item=invalid as dynamic)
    ApplyFunc(ComponentsScreen().OnFwdButton, m, [item])
end sub

sub pcoOnRevButton(item=invalid as dynamic)
    ApplyFunc(ComponentsScreen().OnRevButton, m, [item])
end sub

sub pcoOnPlayButton(item as object)
    overlay = item.overlay

    if item.isControl = true then
        overlay.UpdatePlayState()
    else
        item.OnSelected(m)
    end if
end sub

sub pcoOnSelected(screen as object, deferred=false as boolean)
    if m.command = invalid then return

    item = m
    overlay = item.overlay
    player = overlay.player
    command = item.command

    if command = "play_item" then
        player.PlayItemAtPQIID(item.plexObject.GetInt("playQueueItemID"))
        if not deferred then overlay.Close()
    else if command = "play_toggle" then
        overlay.UpdatePlayState()
    else if command = "shuffle" then
        player.SetShuffle(not (player.isShuffled))
    else if command = "next" then
        player.Next()
    else if command = "prev" then
        player.Prev()
    else if command = "stop" then
        player.Stop()
    else
        Debug("command not defined: " + tostr(command))
    end if
end sub

sub pcoUpdatePlayState(wasPlaying=invalid as dynamic)
    if wasPlaying <> invalid then
        m.screen.wasPlaying = wasPlaying
    else
        m.screen.wasPlaying = not (m.screen.wasPlaying = true)
    end if
    glyph = iif(m.screen.wasPlaying, Glyphs().PAUSE, Glyphs().PLAY)
    m.playButton.SetText(glyph, true, false)
    m.screen.screen.DrawAll()
end sub

sub pcoDeferSelected(item=invalid as dynamic)
    if m.selectedTimer = invalid then
        m.selectedTimer = createTimer("refresh")
        m.selectedTimer.SetDuration(1000)
        Application().AddTimer(m.selectedTimer, createCallable("OnSelectedTimer", m))
    end if
    m.selectedTimer.item = item
    m.selectedTimer.Mark()
end sub

sub pcoOnSelectedTimer(timer as object)
    if not m.IsActive() then return

    m.Delete("selectedTimer")
    if timer.item <> invalid then
        timer.item.OnSelected(m.screen, true)
    end if
end sub

sub pcoOnOverlayTimer(timer as object)
    if not m.IsActive() then return

    m.Close()
end sub

sub pcoClose(backButton=false as boolean, redraw=true as boolean)
    m.screen.focusedItem = invalid

    if m.overlayTimer <> invalid then
        m.overlayTimer.active = false
        m.Delete("overlayTimer")
    end if

    if m.selectedTimer <> invalid then
        m.selectedTimer.active = false
        m.Delete("selectedTimer")
    end if

    ApplyFunc(OverlayClass().Close, m, [backButton, redraw])
end sub
