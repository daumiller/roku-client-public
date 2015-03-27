function NowPlayingQueueOverlayClass() as object
    if m.NowPlayingQueueOverlayClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(OverlayClass())

        obj.ClassName = "NowPlaying Overlay"

        ' Methods
        obj.Init = npqoInit
        obj.GetComponents = npqoGetComponents
        obj.GetTrackComponent = npqoGetTrackComponent
        obj.SetNowPlaying = npqoSetNowPlaying
        obj.Refresh = npqoRefresh

        ' Listener Methods
        obj.OnPlay = npqoOnPlay
        obj.OnStop = npqoOnStop
        obj.OnPause = npqoOnPause
        obj.OnResume = npqoOnResume
        obj.OnChange = npqoOnChange
        obj.OnFailedFocus = npqoOnFailedFocus

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

    m.customFonts = {
        glyphs: FontRegistry().GetIconFont(32)
        trackStatus: FontRegistry().GetIconFont(20)
    }

    ' Set up audio player listeners
    m.DisableListeners()
    m.player = AudioPlayer()
    m.AddListener(m.player, "playing", CreateCallable("OnPlay", m))
    m.AddListener(m.player, "stopped", CreateCallable("OnStop", m))
    m.AddListener(m.player, "paused", CreateCallable("OnPause", m))
    m.AddListener(m.player, "resumed", CreateCallable("OnResume", m))
    m.AddListener(m.player, "change", CreateCallable("OnChange", m))

    ' Setup the screen listener
    m.AddListener(m.screen, "OnFailedFocus", CreateCallable("OnFailedFocus", m))
end sub

sub npqoGetComponents()
    isMixed = (m.player.playQueue.isMixed = true)
    ' TODO(schuyler): Padding of 40 exposes a sort of worst case scenario when
    ' scrolling a mixed now playing area. A space just about the size of a single
    ' track ends up vacant and never used at the bottom of the trackBG area. It's
    ' not really a problem with the padding though, I suspect the scrollable vbox
    ' needs to be more sophisticated.

    padding = 40
    spacing = 40
    yOffset = 0
    xOffset = computeRect(m.screen.queueImage).right + spacing
    height = m.screen.progress.y

    m.trackActions = createButtonGrid(2, 2)

    trackPrefs = {
        background: Colors().GetAlpha(&hffffffff, 10),
        width: 1230 - xOffset - spacing - m.trackActions.GetPreferredWidth(),
        height: iif(isMixed, 80, 60),
        fixed: false,
        focusBG: true,
        disallowExit: { down: true },
        zOrder: m.zOrderOverlay
    }

    m.trackBG = createBlock(trackPrefs.background)
    m.trackBG.zOrder = trackPrefs.zOrder
    m.trackBG.setFrame(xOffset, yOffset, 1280 - xOffset, height)
    m.components.Push(m.trackBG)

    m.trackList = createVBox(false, false, false, 0)
    m.trackList.SetFrame(xOffset + padding, padding, trackPrefs.width + m.trackActions.GetPreferredWidth(), height - padding)
    m.trackList.SetScrollable(AppSettings().GetHeight() / 2, false, false, "right")
    m.trackList.stopShiftIfInView = true

    ' *** Tracks *** '
    items = m.player.context
    trackCount = items.Count()
    ' create a shared region for the separator (conserve memory)
    sepRegion = CreateRegion(trackPrefs.width, 1, Colors().Separator)
    for index = 0 to trackCount - 1
        item = items.[index].item
        track = createTrack(item, FontRegistry().NORMAL, FontRegistry().MEDIUM, m.customFonts.trackStatus, m.player.playQueue.totalSize, isMixed)
        track.Append(trackPrefs)
        track.plexObject = item
        track.trackIndex = index
        track.SetFocusable("play")
        track.OnSelected = npqoOnSelected
        track.overlay = m
        m.trackList.AddComponent(track)

        ' not very intuitive to use m.screen.focuseditem here.. maybe we should make the
        ' overlay component more friendly and handle m.focusedItem.
        if m.screen.focusedItem = invalid then m.screen.focusedItem = track

        if index < trackCount - 1 then
            track.AddSeparator(sepRegion)
        end if
    end for
    m.components.Push(m.trackList)

    ' Track actions
    actions = createObject("roList")
    actions.Push({text: ".", command: "todo_more"})
    actions.Push({text: "^", command: "move_item_up"})
    actions.Push({text: "x", command: "remove_item"})
    actions.Push({text: "v", command: "move_item_down"})
    buttonColor = Colors().GetAlpha("Black", 30)

    for each action in actions
        btn = createButton(action.text, FontRegistry().NORMAL, action.command)
        btn.bgColor = buttonColor
        btn.SetFocusMethod(btn.FOCUS_BACKGROUND, Colors().OrangeLight)
        m.trackActions.AddComponent(btn)
    next
    m.components.Push(m.trackActions)

    ' Set the focus to the current AudioPlayer track, if applicable.
    component = m.GetTrackComponent(m.player.GetCurrentItem())
    if component <> invalid then
        m.screen.focusedItem = component

        if m.player.isPlaying then
            m.OnPlay(m.player, component.plexObject)
        else if m.player.isPaused then
            m.OnPause(m.player, component.plexObject)
        end if
    end if

    ' Background of focused item. We have to use a separate background
    ' component due to the aliasing issue.
    m.focusBG = createBlock(Colors().GetAlpha("Black", 40))
    m.focusBG.setFrame(0, 0, trackPrefs.width, trackPrefs.height)
    m.focusBG.fixed = false
    m.focusBG.zOrderInit = -1
    m.components.Push(m.focusBG)
end sub

sub npqoOnSelected()
    ' Pause, Resume or Play the selected track
    player = AudioPlayer()
    if m.Equals(m.overlay.playing) then
        player.Pause()
    else if m.Equals(m.overlay.paused) then
        player.Resume()
    else
        player.PlayItemAtPQIID(m.plexObject.GetInt("playQueueItemID"))
    end if
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

    ' TODO(schuyler): Figure out how to actually handle focus. When we focus
    ' the button grid we want the track to continue to appear focused.

    if toFocus = invalid or toFocus.ClassName <> "Track" then return

    overlay = m.overlayScreen[0]
    if toFocus <> invalid and toFocus.focusBG = true and overlay.focusBG <> invalid then
        overlay.focusBG.sprite.MoveTo(toFocus.x, toFocus.y)
        overlay.focusBG.sprite.SetZ(overlay.zOrderOverlay - 1)
    else
        overlay.focusBG.sprite.SetZ(-1)
    end if

    if toFocus <> invalid then
        rect = computeRect(toFocus)
        overlay.trackActions.SetPosition(rect.right + 1, rect.up + int((rect.height - overlay.trackActions.GetPreferredHeight()) / 2))
        m.focusedTrack = toFocus.plexObject
    else
        overlay.trackActions.SetVisibility(false)
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
    if component <> invalid then
        component.SetPlaying(status)
        m.playing = iif(status, component, invalid)
    end if
end sub

sub npqoOnPlay(player as object, item as object)
    m.SetNowPlaying(item, true)
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
    TextureManager().DeleteCache()

    m.DestroyComponents()
    m.Show()

    TextureManager().ClearCache()
end sub

sub npqoOnFailedFocus(direction as string, focusedItem=invalid as dynamic)
    if not m.IsActive() then return
    if direction = "right" or direction = "left" then
        m.Close(true)
    end if
end sub
