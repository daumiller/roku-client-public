function CompositeClass() as object
    if m.CompositeClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ContainerClass())

        ' Methods
        obj.Draw = compositeDraw
        obj.OnComponentRedraw = compositeOnComponentRedraw

        ' Either the composite itself is focusable or its not, the children
        ' don't matter. So we can use the base component definition instead
        ' of the Container definition.
        '
        obj.GetFocusableItems = compGetFocusableItems
        obj.GetShiftableItems = compGetShiftableItems

        m.CompositeClass = obj
    end if

    return m.CompositeClass
end function

function compositeDraw() as object
    ' A Composite is a container that draws all of its children to its own
    ' region instead of letting them draw to their own regions. So we need
    ' to create a bitmap for ourselves and then render everything there.

    if m.needsLayout then m.PerformLayout()

    ' init the region ( it will be cleared/reused if not invalid )
    m.InitRegion()
    m.region.setAlphaEnable(m.alphaEnable)

    compositor = CreateObject("roCompositor")
    compositor.SetDrawTo(m.region, m.bgColor)

    drawables = CreateObject("roList")

    for each comp in m.components
        childDrawables = comp.Draw()
        for each drawable in childDrawables
            drawables.Push(drawable)
        next
    next

    for each comp in drawables
        compositor.NewSprite(comp.x, comp.y, comp.region)
        comp.On("redraw", createCallable("OnComponentRedraw", m, "comp" + tostr(m.id) + "_redraw"))
        comp.region = invalid
        comp.bitmap = invalid
    next

    compositor.DrawAll()

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
