function NowPlayingScreen() as object
    if m.NowPlayingScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentsScreen())

        obj.screenName = "Now Playing Screen"

        ' Methods
        obj.Init = nowplayingInit
        obj.GetComponents = nowplayingGetComponents
        obj.HandleCommand = nowplayingHandleCommand
        obj.GetButtons = nowplayingGetButtons
        obj.OnFocusIn = nowplayingOnFocusIn
        obj.OnOverlayClose = nowplayingOnOverlayClose

        ' Listener Methods
        obj.OnPlay = nowplayingOnPlay
        obj.OnStop = nowplayingOnStop
        obj.OnPause = nowplayingOnPause
        obj.OnResume = nowplayingOnResume
        obj.OnProgress = nowplayingOnProgress
        obj.OnRepeat = nowplayingOnRepeat
        obj.OnShuffle = nowplayingOnShuffle
        obj.OnFailedFocus = nowplayingOnFailedFocus

        ' Methods to refresh screen info
        obj.Refresh = nowplayingRefresh
        obj.UpdateTracks = nowplayingUpdateTracks
        obj.UpdatePlayButton = nowplayingUpdatePlayButton
        obj.SetTitle = nowplayingSetTitle
        obj.SetProgress = nowplayingSetProgress
        obj.SetImage = nowplayingSetImage
        obj.GetNextTrack = nowplayingGetNextTrack
        obj.OnFocusTimer = nowplayingOnFocusTimer
        obj.OnToggleTimer = nowplayingOnToggleTimer
        obj.AddToggleTimer = nowplayingAddToggleTimer
        obj.ToggleShuffleVisibility = nowplayingToggleShuffleVisibility

        ' Queue methods
        obj.ToggleQueue = nowplayingToggleQueue

        ' Remote button methods
        obj.OnPlayButton = nowplayingOnPlayButton
        obj.OnFwdButton = nowplayingOnFwdButton
        obj.OnRevButton = nowplayingOnRevButton

        m.NowPlayingScreen = obj
    end if

    return m.NowPlayingScreen
end function

function createNowPlayingScreen(plexItem=invalid as dynamic) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(NowPlayingScreen())

    ' TODO(rob): handle plexItem=invalid (nothing playing, pending playQueue, other reasons?)
    obj.item = plexItem

    obj.Init()

    NowPlayingManager().SetLocation(NowPlayingManager().FULLSCREEN_MUSIC)

    return obj
end function

sub nowplayingInit()
    ApplyFunc(ComponentsScreen().Init, m)

    ' Intialize custom fonts for this screen
    m.customFonts = {
        glyphs: FontRegistry().GetIconFont(28)
        title: FontRegistry().GetTextFont(32)
        titleStrong: FontRegistry().GetTextFont(32, True)
    }

    ' Set up audio player listeners
    m.DisableListeners()
    m.player = AudioPlayer()
    m.AddListener(m.player, "playing", CreateCallable("OnPlay", m))
    m.AddListener(m.player, "stopped", CreateCallable("OnStop", m))
    m.AddListener(m.player, "paused", CreateCallable("OnPause", m))
    m.AddListener(m.player, "resumed", CreateCallable("OnResume", m))
    m.AddListener(m.player, "progress", CreateCallable("OnProgress", m))
    m.AddListener(m.player, "shuffle", CreateCallable("OnShuffle", m))
    m.AddListener(m.player, "repeat", CreateCallable("OnRepeat", m))

    ' Setup screen listeners
    m.AddListener(m, "OnFailedFocus", CreateCallable("OnFailedFocus", m))

    ' Make sure our item is set to the player's current item. This is normally
    ' set elsewhere, but it's possible for it to fall out of sync if another
    ' screen is pushed on top of us (e.g. Lock screen).
    '
    m.item = firstOf(m.player.GetCurrentItem(), m.item)

    ' Container to toggle
    m.nowPlayingView = CreateObject("roList")
    m.queueView = CreateObject("roList")
end sub

sub nowplayingGetComponents()
    m.DestroyComponents()
    m.focusedItem = invalid
    m.hiddenFocusedItem = invalid

    yOffset = 50
    xOffset = 50

    parentSpacing = 23
    childSpacing = 10
    buttonSpacing = 100

    progressHeight = 6
    albumLarge = 503
    albumSmall = 373

    ' *** Background Artwork *** '
    m.background = createBackgroundImage(m.item)
    m.background.thumbAttr = ["art", "parentThumb", "grandparentThumb", "thumb"]
    m.components.Push(m.background)

    ' *** image *** '
    border = cint(albumLarge * .02)
    m.imageBorder = createBlock(&hffffff60)
    m.imageBorder.SetFrame(xOffset, yOffset, albumLarge + border*2, albumLarge + border*2)
    m.image = createImage(m.item, albumLarge, albumLarge)
    m.image.SetFrame(xOffset + border, yOffset + border, albumLarge, albumLarge)
    m.image.SetOrientation(m.image.ORIENTATION_SQUARE)
    m.image.cache = true
    m.image.fade = true
    m.components.push(m.imageBorder)
    m.components.push(m.image)
    m.nowplayingView.Push(m.imageBorder)
    m.nowplayingView.Push(m.image)

    ' *** image *** '
    border = cint(albumSmall * .02)
    m.queueImageBorder = createBlock(&hffffff60)
    m.queueImageBorder.SetFrame(xOffset, yOffset, albumSmall + border*2, albumSmall + border*2)
    m.queueImageBorder.zOrderInit = -1
    m.queueImage = createImage(m.item, albumSmall, albumSmall)
    m.queueImage.SetFrame(xOffset + border, yOffset + border, albumSmall, albumSmall)
    m.queueImage.SetOrientation(m.queueImage.ORIENTATION_SQUARE)
    m.queueImage.zOrderInit = -1
    m.queueImage.cache = true
    m.queueImage.fade = true
    m.components.push(m.queueImageBorder)
    m.components.push(m.queueImage)
    m.queueView.Push(m.queueImageBorder)
    m.queueView.Push(m.queueImage)

    ' Compute image rects for variable sizing
    queueImageRect = computeRect(m.queueImageBorder)
    imageRect = computeRect(m.imageBorder)

    ' *** Current track info while queue overlay is shown *** '
    vbox = createVBox(false, false, false, 0)
    vbox.SetFrame(queueImageRect.left, queueImageRect.down + parentSpacing, queueImageRect.width, albumLarge - albumSmall)

    font = FontRegistry().LARGE
    fontBold = FontRegistry().LARGE_BOLD
    m.queueGrandparentTitle = createLabel(m.item.Get("trackArtist", ""), font)
    m.queueGrandparentTitle.width = vbox.width
    m.queueGrandparentTitle.SetColor(Colors().TextLht)
    m.queueGrandparentTitle.zOrderInit = -1
    m.queueParentTitle = createLabel(m.item.Get("parentTitle", ""), font)
    m.queueParentTitle.width = vbox.width
    m.queueParentTitle.SetColor(Colors().TextLht)
    m.queueParentTitle.zOrderInit = -1
    m.queueTitle = createLabel(m.item.Get("title", ""), fontBold)
    m.queueTitle.width = vbox.width
    m.queueTitle.zOrderInit = -1

    timeString = "0:00 / " + m.item.GetDuration()
    m.queueTime = createLabel(timeString, font)
    m.queueTime.SetColor(Colors().TextLht)
    m.queueTime.width = vbox.width
    m.queueTime.zOrderInit = -1

    vbox.AddComponent(m.queueGrandparentTitle)
    vbox.AddComponent(m.queueParentTitle)
    vbox.AddSpacer(vbox.height - 4 * font.GetOneLineheight())
    vbox.AddComponent(m.queueTitle)
    vbox.AddComponent(m.queueTime)

    m.components.Push(vbox)
    m.queueView.Push(vbox)

    ' *** Current track info: grandparentTitle/parentTitle/Title and track progress/duration *** '
    xOffset = xOffset + imageRect.height + parentSpacing
    vbox = createVBox(false, false, false, 0)
    vbox.SetFrame(xOffset, yOffset, 1230 - xOffset, imageRect.height)

    m.grandparentTitle = createLabel(m.item.Get("trackArtist", ""), m.customFonts.title)
    m.grandparentTitle.width = vbox.width
    m.grandparentTitle.SetColor(Colors().TextLht)
    m.parentTitle = createLabel(m.item.Get("parentTitle", ""), m.customFonts.title)
    m.parentTitle.width = vbox.width
    m.parentTitle.SetColor(Colors().TextLht)
    m.title = createLabel(m.item.Get("title", ""), m.customFonts.titleStrong)
    m.title.width = vbox.width

    timeString = "0:00 / " + m.item.GetDuration()
    m.time = createLabel(timeString, m.customFonts.title)
    m.time.SetColor(Colors().TextLht)
    m.time.width = vbox.width

    vbox.AddComponent(m.grandparentTitle)
    vbox.AddComponent(m.parentTitle)
    vbox.AddSpacer(m.customFonts.title.GetOneLineheight())
    vbox.AddComponent(m.title)
    vbox.AddComponent(m.time)

    m.components.push(vbox)

    ' add reference to this container to toggle view
    m.nowplayingView.Push(vbox)

    ' *** Next track info: grandparentTitle and Title *** '
    height = m.customFonts.title.GetOneLineHeight()*2

    vbox = createVBox(false, false, false, 0)
    vbox.SetFrame(xOffset, yOffset + imageRect.height - height, 1230 - xOffset, height)

    nextTrack = m.GetNextTrack()
    m.nextGrandparentTitle = createLabel(firstOf(nextTrack.trackArtist, ""), m.customFonts.title)
    m.nextGrandparentTitle.width = vbox.width
    m.nextGrandparentTitle.halign = m.nextGrandparentTitle.JUSTIFY_RIGHT
    m.nextGrandparentTitle.SetColor(Colors().TextDim)

    m.nextTitle = createLabel(firstOf(nextTrack.title, ""), m.customFonts.titleStrong)
    m.nextTitle.width = vbox.width
    m.nextTitle.halign = m.nextTitle.JUSTIFY_RIGHT
    m.nextTitle.SetColor(Colors().TextDim)

    vbox.AddComponent(m.nextGrandparentTitle)
    vbox.AddComponent(m.nextTitle)
    m.components.push(vbox)

    ' add reference to this container to toggle view
    m.nowplayingView.Push(vbox)

    ' *** Progress bar ****
    yOffset = imageRect.down + 50
    m.Progress = createBlock(Colors().OverlayDark)
    m.Progress.SetFrame(0, yOffset, 1280, progressHeight)
    m.components.push(m.Progress)
    m.nowplayingView.Push(m.Progress)

    ' *** Queue Progress bar ****
    queueProgressWidth = queueImageRect.right + 50
    m.queueProgress = createBlock(Colors().OverlayDark)
    m.queueProgress.SetFrame(0, yOffset, queueProgressWidth, progressHeight)
    m.queueProgress.zOrderInit = -1
    m.components.push(m.queueProgress)
    m.queueView.Push(m.queueProgress)

    ' *** Buttons *** '
    m.controlButtons = createHBox(false, false, false, buttonSpacing)
    yOffset = m.Progress.y + m.Progress.height + parentSpacing
    m.controlButtons.SetFrame(0, yOffset, 1280, 720 - yOffset)

    components = m.GetButtons()
    for each key in components.keys
        controlsGroup = createHBox(false, false, false, 0)
        for each comp in components[key]
            controlsGroup.AddComponent(comp)
        end for
        m.controlButtons.AddComponent(controlsGroup)
    end for

    ' Align the buttons in the middle of the screen
    m.controlButtons.PerformLayout()
    width = m.controlButtons.spacing * (m.controlButtons.components.Count()-1)
    for each group in m.controlButtons.components
        width = width + group.GetPreferredWidth()
    end for
    m.controlButtons.SetFrame(int(1280/2 - width/2), yOffset, width, height)

    m.components.Push(m.controlButtons)
    m.nowplayingView.Push(m.controlButtons)
end sub

function nowplayingHandleCommand(command as string, item=invalid as dynamic) as boolean
    handled = true

    if m.focusTimer <> invalid then m.focusTimer.Mark()

    if m.hiddenFocusedItem <> invalid then
        m.OnFocusIn(m.hiddenFocusedItem)
    end if

    if command = "playToggle" then
        if m.player.IsPlaying then
            m.player.Pause()
        else if m.player.IsPaused
            m.player.Resume()
        else
            m.player.Play()
        end if
    else if command = "stop" then
        m.player.Stop()
    else if command = "repeat" then
        m.player.SetRepeat(iif(m.player.repeat >= 2, 0, m.player.repeat + 1))
    else if command = "shuffle" then
        m.player.SetShuffle(not(m.player.isShuffled))
    else if command = "prev_track" then
        m.player.Prev()
    else if command = "next_track" then
        m.player.Next()
    else if command = "queue" then
        m.toggleQueue()
    else
        return ApplyFunc(ComponentsScreen().HandleCommand, m, [command, item])
    end if

    return handled
end function

sub nowplayingRefresh()
    if not Application().IsActiveScreen(m) then return

    m.screen.DrawAll()
end sub

function nowplayingGetButtons() as object
    components = createObject("roAssociativeArray")
    components.keys = ["left", "middle", "right"]

    buttons = createObject("roAssociativeArray")

    buttons["left"] = createObject("roList")
    shuffleColor = iif(m.player.isShuffled, Colors().Orange, invalid)
    shuffleZOrder = iif(m.player.playQueue.supportsShuffle, invalid, -1)
    buttons["left"].push({text: Glyphs().SHUFFLE, command: "shuffle", componentKey: "shuffleButton", statusColor: shuffleColor, zOrderInit: shuffleZOrder })
    repeatGlyph = iif(m.player.repeat = m.player.REPEAT_ONE, Glyphs().REPEAT_ONE, Glyphs().REPEAT)
    repeatColor = iif(m.player.repeat <> m.player.REPEAT_NONE, Colors().Orange, invalid)
    buttons["left"].push({text: repeatGlyph, command: "repeat", componentKey: "repeatButton", statusColor: repeatColor})

    buttons["middle"] = createObject("roList")
    buttons["middle"].push({text: Glyphs().STEP_REV, command: "prev_track", componentKey: "prevTrackButton"})
    buttons["middle"].push({text: iif(m.player.isPlaying, Glyphs().PAUSE, Glyphs().PLAY), command: "playToggle", componentKey: "playButton", defaultFocus: true})
    buttons["middle"].push({text: Glyphs().STEP_FWD, command: "next_track", componentKey: "nextTrackButton"})

    buttons["right"] = createObject("roList")
    buttons["right"].push({text: Glyphs().STOP, command: "stop", componentKey: "stopButton"})
    buttons["right"].push({text: Glyphs().LIST, command: "queue", componentKey: "queueButton"})

    padding = cint(m.customFonts.glyphs.GetOneLineHeight() / 3)
    for each key in components.keys
        for each button in buttons[key]
            if components[key] = invalid then components[key] = createObject("roList")
            btn = createButton(button.text, m.customFonts.glyphs, button.command)
            btn.SetColor(firstOf(button.statusColor, Colors().TextDim))
            btn.SetFocusMethod(btn.FOCUS_FOREGROUND, Colors().OrangeLight)
            btn.SetPadding(0, 0, 0, padding)
            btn.zOrderInit = button.zOrderInit
            if m.focusedItem = invalid or button.defaultFocus = true then m.focusedItem = btn
            components[key].push(btn)
            ' use unique key reference for the screen and overlay
            componentKey = iif(m.showQueue = true, "queue" + button.componentKey, button.componentKey)
            m[componentKey] = btn
        end for
    end for

    return components
end function

sub nowplayingOnFocusIn(toFocus as object, lastFocus=invalid as dynamic)
    if m.hiddenFocusedItem <> invalid then
        m.focusedItem = m.hiddenFocusedItem
        m.hiddenFocusedItem = invalid
        toFocus = m.focusedItem
    end if

    ApplyFunc(ComponentsScreen().OnFocusIn, m, [toFocus, lastFocus])

    m.Refresh()

    ' Add a timer to dim the focus when not actively pressing buttons
    if m.focusTimer = invalid then
        m.focusTimer = createTimer("focusTimer")
        m.focusTimer.SetDuration(10000)
        Application().AddTimer(m.focusTimer, createCallable("OnFocusTimer", m))
    else
        m.focusTimer.Mark()
    end if
end sub

function nowplayingGetNextTrack() as object
    obj = CreateObject("roAssociativeArray")

    nextTrack = m.player.GetNextItem()
    if nextTrack <> invalid then
        obj.trackArtist = nextTrack.Get("trackArtist")
        obj.parentTitle = nextTrack.Get("parentTitle")
        obj.title = nextTrack.Get("title")
    end if

    return obj
end function

sub nowplayingOnFocusTimer(timer as object)
    m.focusTimer = invalid
    if m.focusedItem <> invalid then
        m.focusedItem.SetColor(firstOf(m.focusedItem.statusColor, Colors().TextDim))
        m.focusedItem.Draw(true)
        m.hiddenFocusedItem = m.focusedItem
        m.Refresh()
    end if
end sub

sub nowplayingAddToggleTimer(component as object)
    if component.Equals(m.focusedItem) then
        toggleTimer = createTimer("toggleTimer")
        toggleTimer.SetDuration(2000)
        toggleTimer.component = component
        Application().AddTimer(toggleTimer, createCallable("OnToggleTimer", m))
    end if
end sub

sub nowplayingOnToggleTimer(timer as object)
    if timer.component.Equals(m.focusedItem) then
        if m.focusTimer <> invalid then m.focusTimer.mark()
        timer.component.SetColor(Colors().OrangeLight)
        timer.component.Draw(true)
        m.Refresh()
    end if
end sub

sub nowplayingUpdateTracks(item as object)
    m.SetTitle(item.Get("trackArtist", ""), m.grandparentTitle)
    m.SetTitle(item.Get("parentTitle", ""), m.parentTitle)
    m.SetTitle(item.Get("title", ""), m.title)

    m.SetTitle(item.Get("trackArtist", ""), m.queueGrandparentTitle)
    m.SetTitle(item.Get("parentTitle", ""), m.queueParentTitle)
    m.SetTitle(item.Get("title", ""), m.queueTitle)

    nextTrack = m.GetNextTrack()
    m.SetTitle(firstOf(nextTrack.trackArtist, ""), m.nextGrandparentTitle)
    m.SetTitle(firstOf(nextTrack.title, ""), m.nextTitle)
end sub

sub nowplayingSetTitle(text as string, component as object)
    component.SetText(text, true)
end sub

sub nowplayingSetImage(item as object, component as object)
    if item.Get("key") = m.item.Get("key") then return
    component.Replace(item)
end sub

function nowplayingSetProgress(time as integer, duration as integer) as boolean
    if m.showQueue = true then
        progressComp = m.queueProgress
        timeComp = m.queueTime
    else
        progressComp = m.progress
        timeComp = m.time
    end if

    if progressComp.sprite = invalid or duration = 0 then return false

    region = progressComp.sprite.GetRegion()
    region.Clear(progressComp.bgColor)
    progressPercent = int(time/1000) / int(duration/1000)
    region.DrawRect(0, 0, cint(progressComp.width * progressPercent), progressComp.height, Colors().OrangeLight)

    m.time.text = GetTimeString(time/1000) +" / " + GetTimeString(duration/1000)
    m.queueTime.text = m.time.text
    timeComp.Draw(true)

    return true
end function

sub nowplayingOnPlay(player as object, item as object)
    if m.overlayScreen.Count() = 0 then
        TextureManager().DeleteCache()
    end if

    m.SetImage(item, m.image)
    m.SetImage(item, m.queueImage)
    m.SetImage(item, m.background)

    m.OnRepeat(player, item, player.repeat)
    m.OnShuffle(player, item, player.isShuffled)
    m.SetProgress(0, item.GetInt("duration"))
    m.UpdatePlayButton(Glyphs().PAUSE)
    m.UpdateTracks(item)

    m.item = item
    m.Refresh()

    ' Clear any unused cache
    if m.overlayScreen.Count() = 0 then
        TextureManager().ClearCache()
    end if
end sub

sub nowplayingUpdatePlayButton(text as string)
    m.SetTitle(text, m.playButton)
    if m.showQueue = true then
        m.SetTitle(text, m.queuePlayButton)
    end if
end sub

sub nowplayingOnStop(player as object, item as object)
    Application().popScreen(m)
end sub

sub nowplayingOnPause(player as object, item as object)
    m.UpdatePlayButton(Glyphs().PLAY)
    m.Refresh()
end sub

sub nowplayingOnResume(player as object, item as object)
    m.UpdatePlayButton(Glyphs().PAUSE)
    m.Refresh()
end sub

sub nowplayingOnProgress(player as object, item as object, time as integer, force=false as boolean)
    ' limit gratuitous screen updates as they are expensive.
    if player.IsActive() and not player.IsPlaying or not Application().IsActiveScreen(m) then return
    time = iif(time > item.GetInt("duration"), item.GetInt("duration"), time)
    if m.SetProgress(time, item.GetInt("duration")) then
        m.Refresh()
    end if
end sub

sub nowplayingOnShuffle(player as object, item as object, shuffle as boolean)
    if not m.ToggleShuffleVisibility() then return

    ' Update shuffle button, including the underlying screen if applicable
    buttons = CreateObject("roList")
    buttons.Push(m.shuffleButton)
    if m.showQueue = true then
        buttons.Push(m.queueShuffleButton)
    end if

    for each button in buttons
        if shuffle then
            button.statusColor = Colors().Orange
        else
            button.statusColor = Colors().TextDim
        end if
        button.SetColor(button.statusColor)
        button.Draw(true)
    end for

    m.UpdateTracks(item)

    m.AddToggleTimer(buttons.Peek())
end sub

sub nowplayingOnRepeat(player as object, item as object, repeat as integer)
    ' Update repeat button, including the underlying screen if applicable
    buttons = CreateObject("roList")
    buttons.Push(m.repeatButton)
    if m.showQueue = true then
        buttons.Push(m.queueRepeatButton)
    end if

    for each button in buttons
        button.text = iif(player.repeat = player.REPEAT_ONE, Glyphs().REPEAT_ONE, Glyphs().REPEAT)
        button.statusColor = iif(player.repeat = player.REPEAT_NONE, Colors().TextDim, Colors().Orange)
        button.SetColor(button.statusColor)
        button.Draw(true)
    end for

    m.UpdateTracks(item)

    m.AddToggleTimer(buttons.Peek())
end sub

sub nowplayingOnPlayButton(item=invalid as dynamic)
    m.player.OnPlayButton()
end sub

sub nowplayingOnFwdButton(item=invalid as dynamic)
    m.player.OnFwdButton()
end sub

sub nowplayingOnRevButton(item=invalid as dynamic)
    m.player.OnRevButton()
end sub

sub nowplayingToggleQueue()
    if m.showQueue = true and m.overlayScreen.Count() > 0 then
        m.overlayScreen.Peek().Close()
        return
    end if

    m.showQueue = not (m.showQueue = true)

    showNowPlaying = not m.showQueue
    for each component in m.nowplayingView
        component.focusable = showNowPlaying
        component.SetVisible(showNowPlaying)
    end for

    for each component in m.queueView
        component.focusable = m.showQueue
        component.SetVisible(m.showQueue)
    end for

    m.focusedTrack = invalid

    if m.showQueue then
        if m.focusTimer <> invalid then
            m.focusTimer.active = false
            m.focusTimer = invalid
        end if
        queueOverlay = createNowPlayingQueueOverlay(m)
        queueOverlay.enableOverlay = true
        queueOverlay.Show()
        queueOverlay.On("close", createCallable("OnOverlayClose", m))
    else
        m.ToggleShuffleVisibility()
        m.screen.DrawAll()
    end if
end sub

sub nowplayingOnOverlayClose(overlay as object, backButton as boolean)
    m.ToggleQueue()
end sub

sub nowplayingOnFailedFocus(direction as string, focusedItem=invalid as dynamic)
    if m.hiddenFocusedItem = invalid then return
    m.OnFocusIn(m.hiddenFocusedItem)
end sub

function nowplayingToggleShuffleVisibility() as boolean
    shuffleSupport = m.player.playQueue.supportsShuffle

    if m.showQueue = true then
        m.queueShuffleButton.SetVisible(shuffleSupport)
        m.queueShuffleButton.ToggleFocusable(shuffleSupport)
    else
        m.shuffleButton.SetVisible(shuffleSupport)
        m.shuffleButton.ToggleFocusable(shuffleSupport)
    end if

    return shuffleSupport
end function
