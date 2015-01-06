function CompositorScreen() as object
    if m.CompositorScreen = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.Reset = compositorReset
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
        obj.compositor.SetDrawTo(obj.screen, Colors().Background)

        ' TODO(schuyler): Initialize displayable width/height/offsets

        m.CompositorScreen = obj
    end if

    return m.CompositorScreen
end function

' we really shouldn't have to every call this if we destroy sprites correctly
sub compositorReset()
    m.compositor = CreateObject("roCompositor")
    m.compositor.SetDrawTo(m.screen, Colors().Background)

    m.HideFocus(true)
end sub

sub compositorDrawAll()
    m.compositor.DrawAll()
    m.screen.SwapBuffers()
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
        Debug("******** Drawing " + tostr(comp) + " zOrder:" + tostr(zOrder))
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

    ' pad the cards focus border for cards (watched status visibility)
    if tostr(component.ClassName) = "Card" then
        padding = 1
    else
        padding = 0
    end if

    if component.focusInside = true then
        focus = {
            x: component.x
            y: component.y
            w: component.width
            h: component.height
        }
    else
        focus = {
            x: component.x - numPixels - padding,
            y: component.y - numPixels - padding,
            w: component.width + (numPixels * 2) + (padding * 2),
            h: component.height + (numPixels * 2) + (padding * 2),
        }
    end if
    focus.append({
        color: Colors().OrangeLight,
        z: 995,
    })

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
    m.debugSprites.Push(m.compositor.NewSprite(x - int(width/2), y - int(height / 2), region, 999))
    if drawNow then m.DrawAll()
end sub
