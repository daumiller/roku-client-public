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
        obj.ToggleQueue = photoToggleQueue
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

    ' TODO(rob): should we not start the slideshow automatically? I'm assuming
    ' we should only start automatically if requested by the "play" button on
    ' the remote.
    '
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
    m.InitRefreshCache()

    m.CancelRequests()
    TextureManager().RemoveTextureByScreenId(m.screenID)

    ' Encourage some extra memory cleanup
    RunGC()

    m.Show()
end sub

sub photoDeactivate(screen=invalid as dynamic)
    m.slideShowTimer.Pause()
    m.Delete("slideShowTimer")
    m.controller.Stop()
    ApplyFunc(ComponentsScreen().Deactivate, m, [screen])
end sub

sub photoGetComponents()
    m.DestroyComponents()

    ' How quickly should we fade the image (1 - 100). It might be nice to slow
    ' this down when we are in a slideshow, and fade quickly when manually
    ' advancing
    '
    fadeSpeed = 5

    ' Use a layered image. A blurred background and a photo centered on top. This is
    ' essentially a more efficient (memory and performance) composite. It will wait
    ' for all texture requests to complete before drawing to the screen.
    m.image = createLayeredImage()
    m.image.SetFade(true, fadeSpeed)
    m.image.setFrame(0, 0, 1280, 720)
    m.SetRefreshCache("image", m.image)

    ' Add layers
    m.image.AddComponent(createBackgroundImage(m.item, false, false, invalid))
    m.image.AddComponent(createImage(m.item, m.image.width, m.image.height, invalid, "scale-to-fit"))

    m.components.Push(m.image)
end sub

sub photoPlay()
    m.curIndex = firstOf(m.nextIndex, m.curIndex, 0)
    m.item = m.context[m.curIndex]

    ' Show or refresh the screen
    if not Application().IsActiveScreen(m) then
        Application().PushScreen(m)
    else
        m.Refresh()
    end if

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
        if keyCode = m.kp_UP or keyCode = m.kp_DN then
            m.ToggleQueue()
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

sub photoToggleQueue()
    if m.showQueue = true and m.overlayScreen.Count() > 0 then
        m.overlayScreen.Peek().Close()
        return
    end if

    m.showQueue = not (m.showQueue = true)

    if m.showQueue then
        m.wasPlaying = (m.isPlaying = true)
        if m.wasPlaying then
            m.controller.Pause()
        end if

        ' Clear any traces of a focusedItem. We shouldn't have any.
        m.focusedItem = invalid

        queueOverlay = createPhotoControlOverlay(m)
        queueOverlay.enableOverlay = true
        queueOverlay.Show()
        queueOverlay.On("close", createCallable("OnOverlayClose", m))
    else
        ' Resume the slide show if it was playing
        if m.wasPlaying = true then
            m.controller.Resume()
        end if
        m.Delete("wasPlaying")
        m.screen.DrawAll()
    end if
end sub

sub photoOnOverlayClose(overlay as object, backButton as boolean)
    m.ToggleQueue()
end sub
