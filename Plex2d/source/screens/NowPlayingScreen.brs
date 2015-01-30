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
end sub

sub nowplayingGetComponents()
    m.DestroyComponents()
    m.focusedItem = invalid

    yOffset = 50
    xOffset = 50
    parentSpacing = 30
    parentHeight = 504
    childSpacing = 10
    buttonSpacing = 100
    progressHeight = 6

    ' *** Background Artwork *** '
    ' TODO(rob): do we add a dimmer to the background artwork, or opacity/background options right?
    m.background = createImage(m.item, 1280, 720, { blur: 15, opacity: 60, background: Colors().ToHexString("Background") })
    m.background.zOrderInit = 0
    m.background.thumbAttr = ["art", "parentThumb", "grandparentThumb", "thumb"]
    m.background.SetOrientation(m.background.ORIENTATION_LANDSCAPE)
    m.components.Push(m.background)

    ' *** image *** '
    border = cint(parentHeight * .02)
    nowplayingBg = createBlock(&hffffff60)
    nowplayingBg.SetFrame(xOffset - border, yOffset - border, parentHeight + border*2, parentHeight + border*2)
    m.image = createImage(m.item, parentHeight, parentHeight)
    m.image.SetFrame(xOffset, yOffset, parentHeight, parentHeight)
    m.components.push(nowplayingBg)
    m.components.push(m.image)

    ' *** Current track info: grandparentTitle/parentTitle/Title and track progress/duration *** '
    xOffset = xOffset + parentHeight + parentSpacing
    vbox = createVBox(false, false, false, 0)
    vbox.SetFrame(xOffset, yOffset, 1230 - xOffset, parentHeight)

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

    ' *** Next track info: grandparentTitle and Title *** '
    height = m.customFonts.title.GetOneLineHeight()*2

    vbox = createVBox(false, false, false, 0)
    vbox.SetFrame(xOffset, yOffset + parentHeight - height, 1230 - xOffset, height)

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

    ' *** Progress bar ****
    yOffset = yOffset + parentHeight + border*2 + parentSpacing
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
    buttons["left"].push({text: Glyphs().SHUFFLE, command: "shuffle", componentKey: "shuffleButton", statusColor: iif(m.player.isShuffled, Colors().Orange, invalid) })
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

    toFocus.SetColor(Colors().OrangeLight)
    toFocus.Draw(true)
    if lastFocus <> invalid then
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

        ' set the last focus (to refocus) and invalidate the current.
        m.lastFocusedItem = m.focusedItem
        m.focusedItem = invalid

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

    m.SetImage(item, m.image)
    m.SetImage(item, m.background)
end sub

sub nowplayingSetTitle(text as string, component as object)
    if component.sprite = invalid then return

    component.text = text
    component.Draw(true)
end sub

sub nowplayingSetImage(item as object, component as object)
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
'    ' TODO(rob): remote location is only needed since we do not close
'    ' the screen on a stop.
'    NowPlayingManager().location = "fullScreenMusic"
    m.OnRepeat(player, item, player.repeat)
    m.OnShuffle(player, item, player.isShuffled)
    m.SetProgress(0, item.GetInt("duration"))
    m.SetTitle(Glyphs().PAUSE, m.playButton)
    m.UpdateTracks(item)
    m.Refresh()
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

