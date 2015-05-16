function PhotoControlOverlayClass() as object
    if m.PhotoControlOverlayClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(OverlayClass())

        obj.ClassName = "NowPlaying Overlay"

        ' Methods
        obj.Show = pcoShow
        obj.Init = pcoInit
        obj.GetComponents = pcoGetComponents
        obj.GetItemComponent = pcoGetItemComponent
        obj.SetNowPlaying = pcoSetNowPlaying
        obj.Refresh = pcoRefresh
        obj.DeferRefresh = pcoDeferRefresh
        obj.OnRefreshTimer = pcoOnRefreshTimer
        obj.GetButtons = pcoGetButtons
        obj.OnKeyPress = pcoOnKeyPress

        ' Listener Methods
        obj.OnPlay = pcoOnPlay
        obj.OnStop = pcoOnStop
        obj.OnPause = pcoOnPause
        obj.OnResume = pcoOnResume
        obj.OnChange = pcoOnChange

        obj.OnKeyPress = pcoOnKeyPress
        obj.OnFwdButton = pcoOnFwdButton
        obj.OnRevButton = pcoOnRevButton
        obj.OnPlayButton = pcoOnPlayButton

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

    ' TODO(rob): why are we setting this here? instead of the class
    m.screen.OnFocusIn = pcoOnFocusIn

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
    m.AddListener(m.player, "stopped", CreateCallable("OnStop", m))
    m.AddListener(m.player, "paused", CreateCallable("OnPause", m))
    m.AddListener(m.player, "resumed", CreateCallable("OnResume", m))
    m.AddListener(m.player, "change", CreateCallable("OnChange", m))
end sub

sub pcoShow(refocusCommand=invalid as dynamic)
    ' Lock the screen updates
    m.screen.screen.DrawLock()

    ApplyFunc(OverlayClass().Show, m)

    ' Update the item component and shift the item list based on the item playing
    toFocus = firstOf(m.GetitemComponent(m.player.GetCurrentItem()), m.screen.focusedItem)

    ' Focus the current item or screens focused item if we didn't override
    m.screen.FocusItemManually(toFocus)

    ' Unlock the screen and draw the updates
    m.screen.screen.DrawUnlock()
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

    context = m.player.context
    for index = 0 to context.Count() - 1
        item = context[index].item
        card = createCard(item, item.GetOverlayTitle())
        card.SetOrientation(ComponentClass().ORIENTATION_SQUARE)
        card.thumbAttrs = ["thumb"]
        card.width = card.GetWidthForOrientation(card.orientation, gridHeight)
        card.fixed = false
        card.plexObject = item
        card.SetFocusable("show_item")

        if index = 0 then
            m.itemList.SetFocusManual(card)
            m.screen.focusedItem = card
        end if
        m.itemList.AddComponent(card)
    end for
    m.itemList.SetFrame(gridXOffset, gridYOffset, displayWidth, gridHeight)

    m.components.Push(m.itemList)
end sub

function pcoGetItemComponent(plexObject as dynamic) as dynamic
    if plexObject = invalid then return invalid

    ' locate and return the component by the plexObject key
    for each item in m.itemList.components
        if item.plexObject <> invalid and plexObject.Get("key") = item.plexObject.Get("key") then
            return item
        end if
    end for

    return invalid
end function

sub pcoOnFocusIn(toFocus as object, lastFocus=invalid as dynamic)
    ApplyFunc(ComponentsScreen().OnFocusIn, m, [toFocus, lastFocus])
end sub

sub pcoSetNowPlaying(plexObject as object, status=true as boolean)
    ' move focus if we are focused on the grid?
stop
end sub

sub pcoOnPlay(player as object, item as object)
    m.screen.screen.DrawLock()

    currentItem = m.GetItemComponent(item)
    m.screen.CalculateShift(currentItem, computeRect(currentItem))
    m.SetNowPlaying(item, true)

    m.screen.screen.DrawUnlock()
end sub

sub pcoOnStop(player as object, item as object)
    m.SetNowPlaying(item, false)
end sub

sub pcoOnPause(player as object, item as object)
    m.paused = m.GetItemComponent(item)
    m.SetNowPlaying(item, false)
end sub

sub pcoOnResume(player as object, item as object)
    m.paused = invalid
    m.SetNowPlaying(item, true)
end sub

sub pcoOnChange(player as object, item as object)
    m.Refresh()
end sub

sub pcoRefresh()
    if not m.IsActive() or m.refreshTimer <> invalid then return

    TextureManager().DeleteCache()

    m.DestroyComponents()
'    m.Show(m.screen.focusedItem.command)
    m.Show()

    TextureManager().ClearCache()
end sub

sub pcoDeferRefresh()
    if m.refreshTimer = invalid then
        m.refreshTimer = createTimer("refresh")
        m.refreshTimer.SetDuration(5000)
        Application().AddTimer(m.refreshTimer, createCallable("OnRefreshTimer", m))
    end if

    m.refreshTimer.Mark()
end sub

sub pcoOnRefreshTimer(timer)
    m.refreshTimer = invalid
    m.Refresh()
end sub

sub pcoActionOnSelected(screen as object)
    ' We're evaluated in the context of the button, which has a reference to the
    ' overlay, which has a reference to the screen. But we'll just avoid using
    ' m to reduce confusion.

    btn = m
    overlay = btn.overlay
    player = screen.player
    command = btn.command

    stop
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
    buttons["middle"].push({text: iif(m.player.isPlaying, Glyphs().PAUSE, Glyphs().PLAY), command: "playToggle", componentKey: "playButton", defaultFocus: true})
    buttons["middle"].push({text: Glyphs().STEP_FWD, command: "next", componentKey: "nextButton"})

    buttons["right"] = createObject("roList")
    buttons["right"].push({text: Glyphs().STOP, command: "stop", componentKey: "stopButton"})

    padding = cint(m.customFonts.glyphs.GetOneLineHeight() / 3)
    for each key in components.keys
        for each button in buttons[key]
            if components[key] = invalid then components[key] = createObject("roList")
            btn = createButton(button.text, m.customFonts.glyphs, button.command)
            btn.SetColor(firstOf(button.statusColor, Colors().Subtitle))
            btn.SetFocusMethod(btn.FOCUS_FOREGROUND, Colors().OrangeLight)
            btn.SetPadding(0, 0, 0, padding)
            if m.screen.focusedItem = invalid or button.defaultFocus = true then m.screen.focusedItem = btn
            components[key].push(btn)
            ' use unique key reference for the screen and overlay
            componentKey = iif(m.showQueue = true, "queue" + button.componentKey, button.componentKey)
            btn.isControl = true
            m[componentKey] = btn
        end for
    end for

    return components
end function

sub pcoOnKeyPress(keyCode as integer, repeat as boolean)
    ' We're evaluated in the context of the base screen
    isControl = (m.focusedItem <> invalid and m.focusedItem.isControl = true)
    if (keyCode = m.kp_UP and isControl) or (keyCode = m.kp_DN and not isControl) then
        m.overlayScreen.Peek().Close()
    else
        ApplyFunc(ComponentsScreen().OnKeyPress, m, [keyCode, repeat])
    end if
end sub

sub pcoOnFwdButton(item=invalid as dynamic)
    ApplyFunc(ComponentsScreen().OnFwdButton, m, [item])
end sub

sub pcoOnRevButton(item=invalid as dynamic)
    ApplyFunc(ComponentsScreen().OnRevButton, m, [item])
end sub

sub pcoOnPlayButton(item=invalid as dynamic)
    ' close the overlay and start the slideshow if we are focused on a control,
    ' or start the slideshow from the focused item.

    ' TODO(rob): temporary lookup
    if item.isControl = true then
        m.Close()
    else
        stop
    end if
end sub
