function CompositorScreen() as object
    if m.CompositorScreen = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.Reset = compositorReset
        obj.DrawAll = compositorDrawAll
        obj.DrawComponent = compositorDrawComponent
        obj.Destroy = compositorDestroy

        obj.HideFocus = compositorHideFocus
        obj.DrawFocus = compositorDrawFocus
        obj.GetFocusData = compositorGetFocusData
        obj.focusSprite = invalid

        obj.drawLockTimer = createTimer("drawLock")
        obj.AddDrawLockTimer = compositorAddDrawLockTimer
        obj.OnDrawLockTimer = compositorOnDrawLockTimer

        obj.DrawLock = compositorDrawLock
        obj.DrawLockOnce = compositorDrawLockOnce
        obj.DrawUnlock = compositorDrawUnlock

        obj.DrawDebugRect = compositorDrawDebugRect
        obj.ClearDebugSprites = compositorClearDebugSprites
        obj.debugSprites = CreateObject("roList")

        obj.OnComponentRedraw = compositorOnComponentRedraw

        ' Set up an roScreen one time, with double buffering and alpha enabled
        obj.Reset()

        ' TODO(schuyler): Initialize displayable width/height/offsets
        obj.focusPixels = iif(AppSettings().GetGlobal("IsHD") = true, 4, 2)

        ' Device specific overrides
        if AppSettings().GetGlobal("rokuModelCode") = "3100X" then
            obj.DrawAll = compositorLegacyDrawAll
        end if

        m.CompositorScreen = obj
    end if

    ' Recreate the roScreen and compositor if invalid (we may destroy them for specific reasons)
    if m.CompositorScreen.screen = invalid or m.CompositorScreen.compositor = invalid then
        m.CompositorScreen.Reset()
    end if

    return m.CompositorScreen
end function

sub compositorReset()
    ' we cannot create/reset an roScreen if a standard screen is active
    if Application().IsActiveScreen(VideoPlayer()) then
        Warn("Cannot create an roScreen while video is active.")
    else
        m.screen = CreateObject("roScreen", true)
        m.screen.SetAlphaEnable(true)
        m.screen.SetPort(Application().port)
        ' Set up the compositor to draw to the screen
        m.compositor = CreateObject("roCompositor")
        m.compositor.SetDrawTo(m.screen, Colors().Background)
        m.HideFocus(true)
    end if
end sub

sub compositorDrawAll(shift=false as boolean)
    if Locks().IsLocked("DrawAll") then return
    m.compositor.DrawAll()
    m.screen.SwapBuffers()
end sub

' Older units (Roku 2 XS specifically) screen may flicker without a finish
' call, which is not suppossed to be needed for double buffered screens.
sub compositorLegacyDrawAll(shift=false as boolean)
    if Locks().IsLocked("DrawAll") then return
    m.compositor.DrawAll()
    m.screen.SwapBuffers()
    if shift then m.screen.finish()
end sub

sub compositorDrawComponent(component as object, screen=invalid as dynamic)
    ' Let the component draw itself to its own regions
    drawableComponents = component.Draw()

    ' Then convert those regions to sprites on our screen
    for each comp in drawableComponents
        if comp.zOrderInit <> invalid then
            zOrder = comp.zOrderInit
            comp.zOrderInit = invalid
        else if comp.IsOnScreen() then
            zOrder = firstOf(comp.zOrder, 1)
        else
            zOrder = -1
        end if
        Verbose("Drawing " + tostr(comp) + " zOrder:" + tostr(zOrder))
        comp.sprite = m.compositor.NewSprite(comp.x, comp.y, comp.region, zOrder)
        comp.On("redraw", createCallable("OnComponentRedraw", m, "compositorRedraw"))
        if screen <> invalid and comp.IsAnimated = true then
            screen.animatedComponents.push(comp)
        end if
    next
end sub

sub compositorOnComponentRedraw(component as object)
    ' We only listen to redraw requests for components that we drew to
    ' their own sprite. Those components know how to redraw themselves
    ' to that sprite.
    component.Redraw()
end sub

sub compositorDestroy()
    m.HideFocus(true)
    m.screen = invalid
    m.compositor = invalid
    GetGlobalAA().Delete("CompositorScreen")
    MiniPlayer().Destroy(true)
end sub

sub compositorHideFocus(unload=false as boolean, drawAllNow=false as boolean)
    if m.focusSprite = invalid then return

    if unload then
        m.focusSprite.Remove()
        m.focusSprite = invalid
    else if m.focusSprite.GetZ() > -1 then
        ' Just hide it
        m.focusSprite.SetZ(-1)
    end if

    if drawAllNow then m.DrawAll()
end sub

sub compositorDrawFocus(component as object, drawAllNow=false as boolean)
    if component.focusBorder = false then
        if m.focusSprite <> invalid then m.HideFocus(true)
        if drawAllNow then m.DrawAll()
        return
    end if

    numPixels = m.focusPixels
    innerBorder = invalid

    if component.focusInside = true then
        focus = {
            x: component.x
            y: component.y
            w: component.width
            h: component.height
        }
    else
        ' Cards focus box includes 1px black inner border
        if component.innerBorderFocus = true then
            innerPixels = 1
        else
            innerPixels = 0
        end if

        if component.focusSeparator = invalid then
            component.focusSeparator = 0
        end if

        focus = {
            x: component.x - numPixels - innerPixels,
            y: component.y - numPixels - innerPixels,
            w: component.width + (numPixels * 2) + (innerPixels * 2),
            h: component.height + (numPixels * 2) + (innerPixels * 2) - component.focusSeparator,
        }
        if innerPixels > 0 then
            innerBorder = {
                x: numPixels
                y: numPixels
                w: component.width + innerPixels
                h: component.height + innerPixels*2 - component.focusSeparator
            }
        end if
    end if

    focus.append({
        color: Colors().OrangeLight,
        zOrder: ZOrders().FOCUS,
    })

    ' If we've already focused something of the same size, we can simply
    ' move the focus box instead of destroying it and creating it again.
    reuseFocus = false

    if m.focusSprite <> invalid then
        reuseFocus = (focus.w = m.focusSprite.GetRegion().GetWidth()) and (focus.h = m.focusSprite.GetRegion().GetHeight())
    end if

    if reuseFocus then
        Verbose("Reusing existing focus sprite")
        m.focusSprite.MoveTo(focus.x, focus.y)
        m.focusSprite.SetZ(focus.zOrder)
    else
        m.HideFocus(true)

        ' Borders drawn in order: top, right, bottom, left
        bmp = CreateObject("roBitmap", {width: focus.w, height: focus.h, alphaEnable: false})
        bmp.DrawRect(0, 0, focus.w, numPixels, focus.color)
        bmp.DrawRect(focus.w - numPixels, 0, numPixels, focus.h, focus.color)
        bmp.DrawRect(0, focus.h - numPixels, focus.w, numPixels, focus.color)
        bmp.DrawRect(0, 0, numPixels, focus.h, focus.color)

        if innerBorder <> invalid then
            bmp.DrawRect(innerBorder.x, innerBorder.y, innerBorder.w, innerPixels, Colors().Black)
            bmp.DrawRect(innerBorder.x + innerBorder.w, innerBorder.y, innerPixels, innerBorder.h, Colors().Black)
            bmp.DrawRect(innerBorder.x, innerBorder.y + innerBorder.h - innerPixels, innerBorder.w, innerPixels, Colors().Black)
            bmp.DrawRect(innerBorder.x, innerBorder.x, innerPixels, innerBorder.h, Colors().Orange and Colors().Black)
        end if

        region = CreateObject("roRegion", bmp, 0, 0, focus.w, focus.h)
        m.focusSprite = m.compositor.NewSprite(focus.x, focus.y, region, focus.zOrder)
    end if

    ' Save data to the current focus sprite
    m.focusSprite.SetData({rect: computeRect(component)})

    if drawAllNow then m.DrawAll()
end sub

sub compositorGetFocusData(key=invalid as string) as dynamic
    if m.focusSprite = invalid then return invalid

    data = m.focusSprite.GetData()
    if data = invalid or key = invalid then
        return data
    end if

    return data[key]
end sub

sub compositorClearDebugSprites()
    if m.debugSprites.Count() = 0 then return
    for each sprite in m.debugSprites
        sprite.Remove()
    next
    m.debugSprites.Clear()
end sub

sub compositorDrawDebugRect(x, y, width, height, color, drawNow=false)
    ' disabled draw debug points for focus
    return
    bmp = CreateObject("roBitmap", {width: width, height: height, alphaEnable: false})
    bmp.Clear(color)
    region = CreateObject("roRegion", bmp, 0, 0, width, height)
    m.debugSprites.Push(m.compositor.NewSprite(x - int(width/2), y - int(height / 2), region, 999))
    if drawNow then m.DrawAll()
end sub

sub compositorDrawLock(timeout=60000 as integer)
    m.AddDrawLockTimer(timeout)
    Locks().Lock("DrawAll")
end sub

sub compositorDrawLockOnce(timeout=60000 as integer)
    m.AddDrawLockTimer(timeout)
    Locks().LockOnce("DrawAll")
end sub

sub compositorDrawUnlock(drawAll=true as boolean)
    if Locks().Unlock("DrawAll") and drawAll then
        m.DrawAll()
    end if
    m.drawLockTimer.active = false
end sub

sub compositorOnDrawLockTimer(timer as object)
    WARN("DrawLock timer expired")
    m.DrawUnlock()
end sub

sub compositorAddDrawLockTimer(timeout as integer)
    ' Add a fail-safe delay to unlock DrawAll
    m.drawLockTimer.SetDuration(timeout)
    m.drawLockTimer.active = true
    m.drawLockTimer.Mark()
    Application().AddTimer(m.drawLockTimer, createCallable("OnDrawLockTimer", m))
end sub
