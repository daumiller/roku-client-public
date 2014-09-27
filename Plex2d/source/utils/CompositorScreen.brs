function CompositorScreen() as object
    if m.CompositorScreen = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.Reset = compositorReset
        obj.DrawAll = compositorDrawAll
        obj.DrawComponent = compositorDrawComponent
        obj.Destroy = compositorDestroy

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
        m.compositor.NewSprite(region.x, region.y, region.region)
    next
end sub

sub compositorDestroy()
    m.screen = invalid
    m.compositor = invalid
    GetGlobalAA().Delete("CompositorScreen")
end sub
