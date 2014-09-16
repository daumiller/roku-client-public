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

        ' Set up an roScreen one time, with double buffering and alpha enabled
        obj.screen = CreateObject("roScreen", true)
        obj.screen.SetAlphaEnable(true)
        obj.screen.SetPort(Application().port)

        ' TODO(schuyler): Initialize displayable width/height/offsets

        m.CompositorScreen = obj
    end if

    return m.CompositorScreen
end function

sub compositorReset()
    m.compositor = CreateObject("roCompositor")
    m.compositor.SetDrawTo(m.screen, Colors().ScrBkgClr)

    m.focusSprite = invalid

    ' Encourage some extra memory cleanup
    RunGarbageCollector()
end sub

sub compositorDrawAll()
    m.compositor.DrawAll()
    m.screen.SwapBuffers()
end sub

sub compositorDrawComponent(component)
    ' Let the component draw itself to its own regions
    regions = component.Draw()

    ' Then convert those regions to sprites on our screen
    for each region in regions
        Debug("******** Creating " + tostr(region.ClassName) + " sprite " + tostr(region.width) + "x" + tostr(region.height) + " at (" + tostr(region.x) + ", " + tostr(region.y) + ")")
        m.compositor.NewSprite(region.x + region.offsetX, region.y + region.offsetY, region.region)
    next
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
        m.HideFocus()

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
