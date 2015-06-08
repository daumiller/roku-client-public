function CompositeClass() as object
    if m.CompositeClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ContainerClass())

        ' Methods
        obj.Draw = compositeDraw
        obj.OnComponentRedraw = compositeOnComponentRedraw
        obj.PerformChildLayout = compositePerformChildLayout
        obj.HasPendingTextures = compositeHasPendingTextures

        ' Either the composite itself is focusable or its not, the children
        ' don't matter. So we can use the base component definition instead
        ' of the Container definition.
        '
        obj.GetFocusableItems = compGetFocusableItems
        obj.GetShiftableItems = compGetShiftableItems

        ' Since we're going to draw to a single sprite, we want to use the
        ' regular Component SetPosition instead of the Container version.
        '
        obj.SetPosition = compSetPosition

        obj.multiBitmap = false
        obj.copyFadeRegion = false
        obj.waitForTextures = false

        m.CompositeClass = obj
    end if

    return m.CompositeClass
end function

function compositeDraw() as object
    ' A Composite is a container that draws all of its children to its own
    ' region instead of letting them draw to their own regions. So we need
    ' to create a bitmap for ourselves and then render everything there.

    if m.needsLayout then m.PerformLayout()

    ' Init the region (it will be cleared and reused if not invalid). This
    ' provides basic support to fade image components, nothing else.
    '
    if m.fade = true and m.region <> invalid then
        if m.fadeRegion = invalid then
            if m.copyFadeRegion then
                m.fadeRegion = CopyRegion(m.region)
            else
                m.fadeRegion = m.region
            end if
        end if
        bgColor = Colors().Transparent
    else
        bgColor = m.bgColor
        m.InitRegion()
    end if
    m.region.setAlphaEnable(m.alphaEnable)

    drawables = CreateObject("roList")
    for each comp in m.components
        childDrawables = comp.Draw()
        for each drawable in childDrawables
            drawables.Push(drawable)
        next
    next

    drawComposite = not (m.waitForTextures and m.HasPendingTextures())
    if drawComposite then
        compositor = CreateObject("roCompositor")
        compositor.SetDrawTo(m.region, bgColor)
    end if

    for each comp in drawables
        if comp.needsLayout = true then m.PerformChildLayout(comp)
        ' Wait to draw any drawables until pending textures have completed
        if drawComposite then
            compositor.NewSprite(comp.x, comp.y, comp.region)
        end if
        comp.On("redraw", createCallable("OnComponentRedraw", m, "comp" + tostr(m.id) + "_redraw"))
        ' performance vs memory: keep all regions, except for a URL source. Optional key `multiBitmap`
        ' is needed if we are compositing multiple downloaded textures, otherwise we keep redrawing.
        if m.multiBitmap = false then
            if comp.source <> invalid and left(comp.source, 4) = "http" and m.cache = false then
                comp.region = invalid
            end if
            ' do not keep any bitmaps ( we already have the region )
            if comp.bitmap <> invalid then comp.bitmap = invalid
        end if
    next

    if drawComposite then
        compositor.DrawAll()
    end if

    return [m]
end function

sub compositeOnComponentRedraw(component as object)
    ' We're not trying to be clever about which component wants to be redrawn.
    ' If a particular composite thinks that it can be more efficient based on
    ' that information then it can override this method. We just draw everything
    ' again and fire an event for ourselves.

    m.Draw()

    m.Trigger("redraw", [m])
end sub

sub compositePerformChildLayout(child as object)
    child.needsLayout = false
end sub

sub compositeHasPendingTextures() as boolean
    for each comp in m.components
        if IsFunction(comp.IsPendingTexture) and comp.IsPendingTexture() then
            return true
        end if
    end for

    return false
end sub
