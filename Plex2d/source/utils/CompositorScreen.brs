function CompositorScreen() as object
    if m.CompositorScreen = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.Reset = compositorReset
        obj.Clear = compositorClear
        obj.DrawAll = compositorDrawAll
        obj.DrawComponent = compositorDrawComponent
        obj.Destroy = compositorDestroy

        obj.HideFocus = compositorHideFocus
        obj.DrawFocus = compositorDrawFocus
        obj.focusSprite = invalid

        obj.DrawDebugRect = compositorDrawDebugRect
        obj.ClearDebugSprites = compositorClearDebugSprites
        obj.debugSprites = CreateObject("roList")

        obj.OnComponentRedraw = compositorOnComponentRedraw

        ' Set up an roScreen one time, with double buffering and alpha enabled
        obj.screen = CreateObject("roScreen", true)
        obj.screen.SetAlphaEnable(true)
        obj.screen.SetPort(Application().port)

        ' Set up the compositor to draw to the screen
        obj.compositor = CreateObject("roCompositor")
        obj.compositor.SetDrawTo(obj.screen, Colors().ScrBkgClr)

        ' TODO(schuyler): Initialize displayable width/height/offsets

        m.CompositorScreen = obj
    end if

    return m.CompositorScreen
end function

' we really shouldn't have to every call this if we destroy sprites correctly
sub compositorReset()
    m.compositor = CreateObject("roCompositor")
    m.compositor.SetDrawTo(m.screen, Colors().ScrBkgClr)

    m.HideFocus(true)
end sub

sub compositorClear(color=invalid as dynamic)
    m.screen.clear(firstOf(color, Colors().ScrBkgClr))
    m.HideFocus(true)
end sub

sub compositorDrawAll()
    m.compositor.DrawAll()
    m.screen.SwapBuffers()
end sub

sub compositorDrawComponent(component as object)
    ' Let the component draw itself to its own regions
    drawableComponents = component.Draw()

    ' Then convert those regions to sprites on our screen
    for each comp in drawableComponents
        if comp.IsOnScreen() then
            zOrder = firstOf(comp.zOrder, 1)
        else
            zOrder = -1
        end if
        Debug("******** Drawing " + tostr(comp) + " zOrder:" + tostr(zOrder))
        comp.sprite = m.compositor.NewSprite(comp.x, comp.y, comp.region, zOrder)
        comp.On("redraw", createCallable("OnComponentRedraw", m, "compositorRedraw"))
    next
end sub

sub compositorOnComponentRedraw(component as object)
    ' We only listen to redraw requests for components that we drew to
    ' their own sprite. Those components know how to redraw themselves
    ' to that sprite.
    component.Redraw()
end sub

sub compositorDestroy()
    m.screen = invalid
    m.compositor = invalid
    GetGlobalAA().Delete("CompositorScreen")
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
    if AppSettings().GetGlobal("IsHD") = true then
        numPixels = 3
    else
        numPixels = 2
    end if

    focus = {
        color: &hff8a00ff,
        x: component.x - numPixels,
        y: component.y - numPixels,
        z: 995,
        w: component.width + (numPixels * 2),
        h: component.height + (numPixels * 2)
    }

    ' If we've already focused something of the same size, we can simply
    ' move the focus box instead of destroying it and creating it again.
    reuseFocus = false

    if m.focusSprite <> invalid then
        reuseFocus = (focus.w = m.focusSprite.GetRegion().GetWidth()) and (focus.h = m.focusSprite.GetRegion().GetHeight())
    end if

    if reuseFocus then
        Debug("Reusing existing focus sprite")
        m.focusSprite.MoveTo(focus.x, focus.y)
        m.focusSprite.SetZ(focus.z)
    else
        m.HideFocus(true)

        bmp = CreateObject("roBitmap", {width: focus.w, height: focus.h, alphaEnable: false})
        bmp.DrawRect(0, 0, focus.w, numPixels, focus.color)
        bmp.DrawRect(0, 0, numPixels, focus.h, focus.color)
        bmp.DrawRect(focus.w - numPixels, 0, numPixels, focus.h, focus.color)
        bmp.DrawRect(0, focus.h - numPixels, focus.w, numPixels, focus.color)

        region = CreateObject("roRegion", bmp, 0, 0, focus.w, focus.h)
        m.focusSprite = m.compositor.NewSprite(focus.x, focus.y, region, focus.z)
    end if

    if drawAllNow then m.DrawAll()
end sub

sub compositorClearDebugSprites()
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
    m.debugSprites.Push(m.compositor.NewSprite(x - int(width/2), y - int(height / 2), region))
    if drawNow then m.DrawAll()
end sub
