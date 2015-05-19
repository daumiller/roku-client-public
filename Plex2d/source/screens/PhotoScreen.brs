function PhotoScreen() as object
    if m.PhotoScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentsScreen())

        obj.screenName = "Photo Screen"

        ' Methods
        obj.Init = photoInit
        obj.Show = photoShow
        obj.Refresh = photoRefresh
        obj.Deactivate = photoDeactivate
        obj.GetComponents = photoGetComponents
        obj.OnSlideShowTimer = photoOnSlideShowTimer
        obj.SetImage = photoSetImage

        obj.OnKeyPress = photoOnKeyPress
        obj.OnFwdButton = photoOnFwdButton
        obj.OnRevButton = photoOnRevButton
        obj.OnPlayButton = photoOnPlayButton

        ' Standard Roku player methods
        obj.Play = photoPlay
        obj.Stop = photoStop
        obj.Pause = photoPause
        obj.Resume = photoResume
        obj.SetNext = photoSetNext
        obj.SetContentList = photoSetContentList
        obj.SetDuration = photoSetDuration

        ' Overlay methods (controls and queue)
        obj.ToggleOverlay = photoToggleOverlay
        obj.OnOverlayClose = photoOnOverlayClose

        m.PhotoScreen = obj
    end if

    return m.PhotoScreen
end function

function createPhotoScreen(controller as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(PhotoScreen())

    obj.Init(controller)

    return obj
end function

sub photoInit(controller as object)
    ApplyFunc(ComponentsScreen().Init, m)

    m.controller = controller
    m.curIndex = 0
    m.nextIndex = invalid
    m.context = invalid
    m.isPlaying = true

    m.SetDuration(5000)
end sub

sub photoShow()
    ApplyFunc(ComponentsScreen().Show, m)

    ' Add a an active, but paused timer.
    if m.slideShowTimer = invalid then
        Debug("Add slideshow timer")
        m.slideShowTimer = createTimer("slideShowTimer")
        m.slideShowTimer.SetDuration(m.duration, true)
        m.slideShowTimer.paused = true
        Application().AddTimer(m.slideShowTimer, createCallable("OnSlideShowTimer", m))
    end if

    NowPlayingManager().SetLocation(NowPlayingManager().FULLSCREEN_PHOTO)
end sub

sub photoRefresh()
    if m.overlayScreen.Count() = 0 then
        TextureManager().DeleteCache()
    end if

    m.InitRefreshCache()

    ' Cancel request and clean memory
    m.CancelRequests()

    ' TODO(rob): holding the left/right button down on the harmony remote causes
    ' memory leak. The harmony remote logic is broken, but we should be able to
    ' handle their lame sauce.
    '
    TextureManager().Reset()

    TextureManager().RemoveTextureByScreenId(m.screenID)
    RunGC()

    m.SetImage(4, true)

    if m.overlayScreen.Count() = 0 then
        TextureManager().ClearCache()
    end if
end sub

sub photoDeactivate(screen=invalid as dynamic)
    m.slideShowTimer.Pause()
    m.Delete("slideShowTimer")
    m.controller.Stop()
    m.refreshCache.Clear()
    m.image = invalid
    ApplyFunc(ComponentsScreen().Deactivate, m, [screen])
end sub

sub photoGetComponents()
    m.DestroyComponents()
    m.components.Push(m.SetImage())
end sub

sub photoPlay()
    m.curIndex = firstOf(m.nextIndex, m.curIndex, 0)
    m.item = m.context[m.curIndex]

    ' Show or refresh the screen
    if not Application().IsActiveScreen(m) then
        Application().PushScreen(m)
        if m.controller.startPaused = true then
            m.ToggleOverlay()
        end if
    else
        m.Refresh()
    end if

    ' Keep the player active
    SendEcpCommand("Lit_a")

    ' Ignore modifying playback status when overlay is enabled
    if m.overlayScreen.Count() > 0 then return

    ' Let the controller know our current state
    if m.isPlaying then
        m.controller.Resume()
    else
        m.controller.Pause()
    end if
end sub

sub photoStop()
    if not Application().IsActiveScreen(m) then return
    Application().PopScreen(m)
end sub

sub photoPause()
    Debug("Pause slideshow")
    m.slideShowTimer.Pause()
    m.isPlaying = false
end sub

sub photoResume()
    Debug("Resume slideshow")
    m.slideShowTimer.Resume()
    m.isPlaying = true
end sub

sub photoSetNext(index as integer)
    m.nextIndex = index
end sub

sub photoSetContentList(context as object)
    m.context = context
end sub

sub photoOnKeyPress(keyCode as integer, repeat as boolean)
    ' We'll probably override this anyways once we have an overlay. There is no overlay
    ' yet, but I'd imagine it would contain player controls and some sort of horizontal
    ' grid on the bottom of the screen
    '
    if m.overlayScreen.Count() = 0 then
        ' For now, lets just enable moving between the photos via left/right.
        if keyCode = m.kp_UP or keyCode = m.kp_DN or keyCode = m.kp_OK then
            m.ToggleOverlay()
        else if keyCode = m.kp_RT then
            m.controller.Next()
        else if keyCode = m.kp_LT then
            m.controller.Prev()
        else
            ApplyFunc(ComponentsScreen().OnKeyPress, m, [keyCode, repeat])
        end if
    end if
end sub

sub photoOnFwdButton(item=invalid as dynamic)
    m.controller.Next()
end sub

sub photoOnRevButton(item=invalid as dynamic)
    m.controller.Prev()
end sub

sub photoOnPlayButton(item=invalid as dynamic)
    ' Toggle playback based on our state
    if m.isPlaying then
        m.controller.Pause()
    else
        m.controller.Resume()
    end if
end sub

sub photoOnSlideShowTimer(timer as object)
    ' Pause the timer until we refresh the screen
    m.slideShowTimer.Pause()

    m.controller.Next()
end sub

sub photoSetDuration(duration=5000 as integer, mark=false as boolean)
    m.duration = duration
    if m.slideShowTimer <> invalid then
        m.slideShowTimer.SetDuation(duration, true)
        if mark then m.slideShowTimer.Mark()
    end if
end sub

sub photoToggleOverlay()
    if m.showQueue = true and m.overlayScreen.Count() > 0 then
        m.overlayScreen.Peek().Close()
        return
    end if

    m.showQueue = not (m.showQueue = true)

    if m.showQueue then
        NowPlayingManager().SetLocation(NowPlayingManager().NAVIGATION)
        m.wasPlaying = (m.isPlaying = true)
        m.controller.Pause(m.wasPlaying)

        queueOverlay = createPhotoControlOverlay(m)
        queueOverlay.enableOverlay = true
        queueOverlay.Show()
        queueOverlay.On("close", createCallable("OnOverlayClose", m))
    else
        NowPlayingManager().SetLocation(NowPlayingManager().FULLSCREEN_PHOTO)
        ' Resume the slide show if it was playing
        if m.wasPlaying = true then
            m.controller.Resume()
        end if
        m.Delete("wasPlaying")
        m.screen.DrawAll()
    end if
end sub

sub photoOnOverlayClose(overlay as object, backButton as boolean)
    if m.playOnClose = true then
        m.controller.Resume()
        m.Delete("playOnClose")
    end if

    m.ToggleOverlay()
end sub

function photoSetImage(fadeSpeed=4 as integer, redraw=false as boolean) as object
    if m.image = invalid then
        m.image = createLayeredImage()
        m.image.setFrame(0, 0, 1280, 720)
    else
        m.image.DestroyComponents()
    end if

    m.image.SetFade(true, fadeSpeed)
    m.SetRefreshCache("image", m.image)

    ' Add layers
    m.image.AddComponent(createBackgroundImage(m.item, false, false, invalid))
    m.image.AddComponent(createImage(m.item, m.image.width, m.image.height, invalid, "scale-to-fit"))

    if redraw then
        m.image.Draw()
    end if

    return m.image
end function
