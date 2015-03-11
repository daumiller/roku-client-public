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

        ' Methods to refresh screen info
        obj.Refresh = nowplayingRefresh
        obj.UpdateTracks = nowplayingUpdateTracks
        obj.SetTitle = nowplayingSetTitle
        obj.SetProgress = nowplayingSetProgress
        obj.SetImage = nowplayingSetImage
        obj.GetNextTrack = nowplayingGetNextTrack
        obj.OnFocusTimer = nowplayingOnFocusTimer
        obj.OnToggleTimer = nowplayingOnToggleTimer
        obj.AddToggleTimer = nowplayingAddToggleTimer

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

    NowPlayingManager().location = "fullScreenMusic"

    return obj
end function

sub nowplayingInit()
    ApplyFunc(ComponentsScreen().Init, m)

    ' Intialize custom fonts for this screen
    m.customFonts = {
        glyphs: FontRegistry().GetIconFont(32)
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

    parentSpacing = 30
    childSpacing = 10
    buttonSpacing = 100

    progressHeight = 6
    albumLarge = 504
    albumSmall = 400

    ' *** Background Artwork *** '
    m.background = createBackgroundImage(m.item)
    m.background.thumbAttr = ["art", "parentThumb", "grandparentThumb", "thumb"]
    m.components.Push(m.background)

    ' *** image *** '
    border = cint(albumLarge * .02)
    imageBorder = createBlock(&hffffff60)
    imageBorder.SetFrame(xOffset - border, yOffset - border, albumLarge + border*2, albumLarge + border*2)
    m.image = createImage(m.item, albumLarge, albumLarge)
    m.image.SetFrame(xOffset, yOffset, albumLarge, albumLarge)
    m.image.SetOrientation(m.image.ORIENTATION_SQUARE)
    m.image.cache = true
    m.image.fade = true
    m.components.push(imageBorder)
    m.components.push(m.image)
    m.nowplayingView.Push(imageBorder)
    m.nowplayingView.Push(m.image)

    ' *** image *** '
    border = cint(albumSmall * .02)
    queueImageBorder = createBlock(&hffffff60)
    queueImageBorder.SetFrame(xOffset - border, yOffset - border, albumSmall + border*2, albumSmall + border*2)
    queueImageBorder.zOrderInit = -1
    m.queueImage = createImage(m.item, albumSmall, albumSmall)
    m.queueImage.SetFrame(xOffset, yOffset, albumSmall, albumSmall)
    m.queueImage.SetOrientation(m.queueImage.ORIENTATION_SQUARE)
    m.queueImage.zOrderInit = -1
    m.queueImage.cache = true
    m.queueImage.fade = true
    m.components.push(queueImageBorder)
    m.components.push(m.queueImage)
    m.queueView.Push(queueImageBorder)
    m.queueView.Push(m.QueueImage)

    ' *** Current track info: grandparentTitle/parentTitle/Title and track progress/duration *** '
    xOffset = xOffset + albumLarge + parentSpacing
    vbox = createVBox(false, false, false, 0)
    vbox.SetFrame(xOffset, yOffset, 1230 - xOffset, albumLarge)

    m.grandparentTitle = createLabel(m.item.Get("grandparentTitle"), m.customFonts.title)
    m.grandparentTitle.width = vbox.width
    m.grandparentTitle.SetColor(Colors().TextLight)
    m.parentTitle = createLabel(m.item.Get("parentTitle"), m.customFonts.title)
    m.parentTitle.width = vbox.width
    m.parentTitle.SetColor(Colors().TextLight)
    m.title = createLabel(m.item.Get("title"), m.customFonts.titleStrong)
    m.title.width = vbox.width

    timeString = "0:00 / " + m.item.GetDuration()
    m.time = createLabel(timeString, m.customFonts.title)
    m.time.SetColor(Colors().TextLight)
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
    vbox.SetFrame(xOffset, yOffset + albumLarge - height, 1230 - xOffset, height)

    nextTrack = m.GetNextTrack()
    m.nextGrandparentTitle = createLabel(firstOf(nextTrack.grandparentTitle, ""), m.customFonts.title)
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
    yOffset = yOffset + albumLarge + border*2 + parentSpacing
    m.Progress = createBlock(Colors().OverlayDark)
    m.Progress.SetFrame(0, yOffset, 1280, progressHeight)
    m.components.push(m.Progress)

    ' *** Buttons *** '
    hbButtons = createHBox(false, false, false, buttonSpacing)
    yOffset = m.Progress.y + m.Progress.height + parentSpacing
    hbButtons.SetFrame(0, yOffset, 1280, 720 - yOffset)

    components = m.GetButtons()
    for each key in components.keys
        hbButtonGroup = createHBox(false, false, false, 0)
        for each comp in components[key]
            hbButtonGroup.AddComponent(comp)
        end for
        hbButtons.AddComponent(hbButtonGroup)
    end for

    ' Align the buttons in the middle of the screen
    hbButtons.PerformLayout()
    width = hbButtons.spacing * (hbButtons.components.Count()-1)
    for each group in hbButtons.components
        width = width + group.GetPreferredWidth()
    end for
    hbButtons.SetFrame(int(1280/2 - width/2), yOffset, width, height)

    m.components.Push(hbButtons)
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
    if m.player.playQueue <> invalid and m.player.playQueue.supportsShuffle = true then
        buttons["left"].push({text: Glyphs().SHUFFLE, command: "shuffle", componentKey: "shuffleButton", statusColor: iif(m.player.isShuffled, Colors().Orange, invalid) })
    end if
    buttons["left"].push({text: Glyphs().REPEAT, command: "repeat", componentKey: "repeatButton", statusColor: iif(m.player.repeat <> m.player.REPEAT_NONE, Colors().Orange, invalid) })

    buttons["middle"] = createObject("roList")
    buttons["middle"].push({text: Glyphs().STEP_REV, command: "prev_track", componentKey: "prevTrackButton"})
    buttons["middle"].push({text: iif(m.player.isPlaying, Glyphs().PAUSE, Glyphs().PLAY), command: "playToggle", componentKey: "playButton", defaultFocus: true})
    buttons["middle"].push({text: Glyphs().STEP_FWD, command: "next_track", componentKey: "nextTrackButton"})

    buttons["right"] = createObject("roList")
    buttons["right"].push({text: Glyphs().STOP, command: "stop", componentKey: "stopButton"})
    buttons["right"].push({text: Glyphs().LIST, command: "queue", componentKey: "queueButton"})

    for each key in components.keys
        for each button in buttons[key]
            if components[key] = invalid then components[key] = createObject("roList")
            btn = createButton(button.text, m.customFonts.glyphs, button.command)
            btn.SetColor(firstOf(button.statusColor, Colors().TextDim))
            btn.width = 50
            btn.height = 50
            btn.focusBorder = false
            if m.focusedItem = invalid or button.defaultFocus = true then m.focusedItem = btn
            components[key].push(btn)
            m[button.componentKey] = btn
        end for
    end for

    return components
end function

sub nowplayingOnFocusIn(toFocus as object, lastFocus=invalid as dynamic)
    ApplyFunc(ComponentsScreen().OnFocusIn, m, [toFocus, lastFocus])

    if m.hiddenFocusedItem <> invalid then
        m.focusedItem = m.hiddenFocusedItem
        m.hiddenFocusedItem = invalid
        toFocus = m.focusedItem
    end if
    toFocus.SetColor(Colors().OrangeLight)
    toFocus.Draw(true)

    if lastFocus <> invalid and not lastFocus.Equals(toFocus) then
        lastFocus.SetColor(firstOf(lastFocus.statusColor, Colors().TextDim))
        lastFocus.Draw(true)
    end if

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
        obj.grandparentTitle = nextTrack.Get("grandparentTitle")
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
        toggleTimer.SetDuration(800)
        toggleTimer.component = component
        Application().AddTimer(toggleTimer, createCallable("OnToggleTimer", m))
    end if
end sub

sub nowplayingOnToggleTimer(timer as object)
    if timer.component.Equals(m.focusedItem) then
        if m.focusTimer <> invalid then m.focusTimer.mark()
        timer.component = timer.component
        timer.component.SetColor(Colors().OrangeLight)
        timer.component.Draw(true)
        m.Refresh()
    end if
end sub

sub nowplayingUpdateTracks(item as object)
    m.SetTitle(item.Get("grandparentTitle", ""), m.grandparentTitle)
    m.SetTitle(item.Get("parentTitle", ""), m.parentTitle)
    m.SetTitle(item.Get("title", ""), m.title)

    nextTrack = m.GetNextTrack()
    m.SetTitle(firstOf(nextTrack.grandparentTitle, ""), m.nextGrandparentTitle)
    m.SetTitle(firstOf(nextTrack.title, ""), m.nextTitle)
end sub

sub nowplayingSetTitle(text as string, component as object)
    if component.sprite = invalid then return

    component.text = text
    component.Draw(true)
end sub

sub nowplayingSetImage(item as object, component as object)
    if item.Get("key") = m.item.Get("key") then return
    component.Replace(item)
end sub

function nowplayingSetProgress(time as integer, duration as integer) as boolean
    if m.Progress.sprite = invalid or duration = 0 then return false

    region = m.Progress.sprite.GetRegion()
    region.Clear(m.Progress.bgColor)
    progressPercent = int(time/1000) / int(duration/1000)
    region.DrawRect(0, 0, cint(m.Progress.width * progressPercent), m.Progress.height, Colors().OrangeLight)

    m.time.text = GetTimeString(time/1000) +" / " + GetTimeString(duration/1000)
    m.time.Draw(true)

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
    m.SetTitle(Glyphs().PAUSE, m.playButton)
    m.UpdateTracks(item)

    m.item = item
    m.Refresh()

    ' Clear any unused cache
    if m.overlayScreen.Count() = 0 then
        TextureManager().ClearCache()
    end if
end sub

sub nowplayingOnStop(player as object, item as object)
    Application().popScreen(m)
end sub

sub nowplayingOnPause(player as object, item as object)
    m.SetTitle(Glyphs().PLAY, m.playButton)
    m.Refresh()
end sub

sub nowplayingOnResume(player as object, item as object)
    m.SetTitle(Glyphs().PAUSE, m.playButton)
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
    if m.shuffleButton = invalid then return

    if shuffle then
        m.shuffleButton.statusColor = Colors().Orange
    else
        m.shuffleButton.statusColor = Colors().TextDim
    end if
    m.shuffleButton.SetColor(m.shuffleButton.statusColor)
    m.shuffleButton.Draw(true)

    m.UpdateTracks(item)

    m.AddToggleTimer(m.shuffleButton)
end sub

sub nowplayingOnRepeat(player as object, item as object, repeat as integer)
    m.repeatButton.text = iif(player.repeat = player.REPEAT_ONE, Glyphs().REPEAT_ONE, Glyphs().REPEAT)
    m.repeatButton.statusColor = iif(player.repeat = player.REPEAT_NONE, Colors().TextDim, Colors().Orange)
    m.repeatButton.SetColor(m.repeatButton.statusColor)
    m.repeatButton.Draw(true)

    m.UpdateTracks(item)

    m.AddToggleTimer(m.repeatButton)
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
    m.showQueue = not m.showQueue = true

    showNowPlaying = m.showQueue = false
    for each component in m.nowplayingView
        component.focusable = showNowPlaying
        component.SetVisible(showNowPlaying)
    end for

    for each component in m.queueView
        component.focusable = m.showQueue
        component.SetVisible(m.showQueue)
    end for

    if m.showQueue then
        if m.focusTimer <> invalid then
            m.focusTimer.active = false
            m.focusTimer = invalid
        end if
        queueOverlay = createNowPlayingQueueOverlay(m)
        queueOverlay.Show()
        queueOverlay.On("close", createCallable("OnOverlayClose", m))
    else
        m.screen.DrawAll()
    end if
end sub

sub nowplayingOnOverlayClose(overlay as object, backButton as boolean)
    m.ToggleQueue()
end sub
