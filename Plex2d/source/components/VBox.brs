function VBoxClass() as object
    if m.VBoxClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(BoxClass())
        obj.ClassName = "VBox"

        obj.FocusDirections = ["up", "down"]

        ' Methods
        obj.PerformLayout = vboxPerformLayout
        obj.GetPreferredWidth = vboxGetPreferredWidth
        obj.GetPreferredHeight = vboxGetPreferredHeight
        obj.AddSpacer = vboxAddSpacer
        obj.SetScrollable = vboxSetScrollable
        obj.SetVisible = vboxSetVisible

        m.VBoxClass = obj
    end if

    return m.VBoxClass
end function

function createVBox(homogeneous as boolean, expand as boolean, fill as boolean, spacing=0 as integer) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(VBoxClass())

    obj.Init()

    obj.homogeneous = homogeneous
    obj.expand = expand
    obj.fill = fill
    obj.spacing = spacing

    return obj
end function

sub vboxAddSpacer(delta as integer)
    m.AddComponent(createSpacer(0, delta))
end sub

sub vboxPerformLayout()
    m.needsLayout = false
    numChildren = m.components.Count()

    ' Strange, but let's not even bother with the complicated stuff if we don't need to.
    if numChildren = 0 then return

    if m.scrollTriggerHeight <> invalid then
        m.scrollTriggerDown = m.scrollTriggerHeight + m.y
    end if

    offsets = m.CalculateOffsets(m.height, m.y, "GetPreferredHeight", m.valign)

    ' Now that we have all the offsets, setting each child's frame is simple.

    offsets.Reset()
    m.components.Reset()
    nextOffset = offsets.Next()

    while offsets.IsNext() and m.components.IsNext()
        offset = nextOffset
        nextOffset = offsets.Next()
        component = m.components.Next()
        maxHeight = nextOffset - offset - m.spacing

        if m.fill then
            height = maxHeight
            width = m.width
        else
            height = component.GetPreferredHeight()
            if height > maxHeight then height = maxHeight
            offset = offset + int((maxHeight - height) / 2)

            width = component.GetPreferredWidth()
            if width = 0 or width > m.width then width = m.width
        end if

        xOffset = m.GetXOffsetAlignment(m.x, m.width, width, firstOf(component.phalign, component.halign))
        component.SetFrame(xOffset, offset, width, height)

        ' calculate the container height, content height and other data about the scrollable area
        if m.scrollTriggerDown <> invalid then
            if m.scrollInfo = invalid then m.scrollInfo = { zOrder: 2 }
            if m.origScrollTriggerDown = invalid then m.origScrollTriggerDown = m.scrollTriggerDown
            if component.focusInside = true then m.scrollInfo.focusInside = true

            ' height of all components in the container
            m.containerHeight = offset + height
            m.lastShift = m.containerHeight

            ' calculate the exact content height that fits within m.scrollTriggerDown
            if m.containerHeight <= m.origScrollTriggerDown then
                m.scrollTriggerDown = m.containerHeight
            end if

            ' calculate the content height that fits in wanted container height
            if m.containerHeight <= offsets[0] + m.height then
                m.contentHeight = m.containerHeight
            end if

            ' determine the zOrder required for any additional components (scrollbar/opacity blocks)
            if component.zOrder <> invalid and component.zOrder > m.scrollInfo.zOrder then
                m.scrollInfo.zOrder = component.zOrder + 1
            end if
        end if
    end while

    ' scrolling helpers: scrollbar, opacity blocks, stop shifting, stop focusing, etc..
    if m.scrollInfo <> invalid then
        ' disable any further shift if we want to stop when the last components
        ' are in view. We might want to make this a default.
        if m.stopShiftIfInView = true then
            m.lastShiftInView = m.containerHeight - m.contentHeight + offsets[0]

            ' we have to account for the scrollDownTrigger
            offset = m.contentHeight - m.scrollTriggerDown
            if offset > 0 then
                m.lastShiftInView = m.containerheight - offset
            end if

            m.scrollInfo.offsetContainer = m.containerHeight - m.lastShiftInView
        end if

        ' disallow manual focus DOWN for scrolling containers
        if m.containerHeight > m.contentHeight then
            m.disallowExit = { down: true }
        end if

        ' add a semi-transparent block above and below the contentHeight. This
        ' will allow the components outside of the scroll area stay visible,
        ' by chaning their opacity.
        if m.scrollVisible = true and m.scrollOverflow <> true then
            color = firstOf(m.scrollOverflowColor, Colors().Background and &hffffffe0)
            opacityTop = createBlock(color)
            opacityTop.setFrame(xOffset, 0, m.width, offsets[0])
            opacityTop.zOrder = m.scrollInfo.zOrder
            opacityTop.fixed = false
            opacityTop.fixedVertical = true

            opacityBot = createBlock(color)
            opacityBot.zOrder = m.scrollInfo.zOrder
            opacityBot.fixed = false
            opacityBot.fixedVertical = true
            opacityBot.setFrame(xOffset, m.contentHeight, m.width, 720 - m.contentHeight)

            m.components.push(opacityTop)
            m.components.push(opacityBot)
        end if

        ' add a scrollbar
        if m.scrollbarPos <> invalid and m.containerHeight > m.contentHeight then
            m.scrollbar = createScrollbar(offsets[0], m.contentHeight, m.containerHeight, m.scrollInfo.zOrder, m.scrollInfo.offsetContainer)
            if m.scrollbar <> invalid
                width = int(CompositorScreen().focusPixels * 1.5)
                spacing = iif(m.scrollInfo.focusInside = true, CompositorScreen().focusPixels, CompositorScreen().focusPixels*2)
                if m.scrollbarPos = "right" then
                    xOffset = xOffset + m.width + spacing
                else
                    xOffset = xOffset - width - spacing
                end if
                m.scrollbar.setFrame(xOffset, offsets[0], width, m.scrollbar.height)
                if m.fixedHorizontal = false then
                    m.scrollbar.fixedHorizontal = false
                    m.scrollbar.fixed = false
                end if

                m.AddComponent(m.scrollbar)
            end if
        end if

        m.scrollInfo = invalid
    end if
end sub

function vboxGetPreferredWidth() as integer
    maxWidth = 0
    for each component in m.components
        width = component.GetPreferredWidth()
        if width > maxWidth then maxWidth = width
    next
    return maxWidth
end function

function vboxGetPreferredHeight() as integer
    totalHeight = m.spacing * (m.components.Count() - 1)
    for each component in m.components
        totalHeight = totalHeight + component.GetPreferredHeight()
    next
    return totalHeight
end function

sub vboxCalculateShift(toFocus as object, refocus=invalid as dynamic, screen=invalid as object)
    if toFocus.fixed = true or m.scrolltriggerdown >= m.containerHeight then return
    m.screen = screen

    shift = {
        x: 0
        y: 0
        hideUp: m.y
        hideDown: m.contentHeight
        triggerDown: m.scrollTriggerDown
        shiftAmount: toFocus.height + m.spacing
    }

    ' handle shifting groups (settings menu box)
    if toFocus.scrollGroupTop <> invalid and toFocus.scrollGroupTop.y < shift.hideUp then
        if toFocus.y - toFocus.scrollGroupTop.y < m.contentHeight - m.y then
            toFocus = toFocus.scrollGroupTop
        end if
    end if

    focusRect = computeRect(toFocus)
    ' reuse the last position on refocus
    if refocus <> invalid and focusRect.up > refocus.up then
        shift.y = refocus.up - focusRect.up
    ' locate the last item to fit, and shift based on it.
    else if focusRect.down > shift.triggerDown
        candidates = firstOf(tofocus.shiftableParent, tofocus.parent)
        if focusRect.down + shift.y > shift.triggerDown then
            wanted = 0
            for each i in candidates.components
                if i.y + i.height > shift.triggerDown then exit for
                wanted = i.y + i.height
            end for
            shift.y = (focusRect.down - wanted) * -1
        else
            shift.y = shift.shiftAmount * -1
        end if
    else if focusRect.up < shift.hideUp then
        shift.y = shift.shiftAmount
    end if

    ' Verify we have shifted enough. We may have other non-focuseable components
    ' between the scrollable list
    if focusRect.down + shift.y > shift.hideDown
        shift.y = shift.hideDown - focusRect.down
    else if focusRect.up + shift.y < shift.hideUp then
        shift.y = shift.hideUp - focusRect.up
    end if

    lastShift = firstOf(m.lastShiftInView, m.lastShift)
    ' Ignore shifting if we have reached the end.
    if m.lastShiftInView <> invalid then
        toFocusY = toFocus.origY + toFocus.height
        if toFocusY > lastShift then
            shift.y = 0
            ' Handle refocusing on items below our last shift point
            if toFocus.origY = toFocus.y then
                shift.y = m.scrollTriggerDown - focusRect.down
                offset = m.contentHeight - (m.containerHeight + shift.y)
                if offset > 0 then shift.y = shift.y + offset
            end if
        end if
    end if

    ' shift the scrollbar if applicable
    if m.scrollbar <> invalid then
        isFirst = (toFocus.origY = m.y)
        isLast = (toFocus.origY + toFocus.height >= lastShift)
        m.scrollbar.Move(toFocus, isFirst, isLast)
    end if

    if shift.y <> 0 then
        m.shiftComponents(shift)
    end if
end sub

sub vboxShiftComponents(shift)
    Debug("shift vbox by: " + tostr(shift.x) + "," + tostr(shift.y))

    if m.screen.lazyLoadTimer <> invalid then
        m.screen.lazyLoadTimer.active = false
        m.screen.lazyLoadTimer.components = invalid
    end if

    partShift = CreateObject("roList")
    fullShift = CreateObject("roList")
    lazyLoad = CreateObject("roAssociativeArray")
    for each component in m.components
        component.GetShiftableItems(partShift, fullShift, lazyLoad, shift.x, shift.y)
    next

    ' lazy-load any components that will be on-screen after we shift and cancel
    ' any pending texture requests. We have to only cancel only our textures and
    ' not any we have pending on the screens context. i.e. do not use the
    ' TextureManager().CancelAll(false) to cancel these.
    for each comp in m.components
        TextureManager().CancelTexture(comp.TextureRequest)
    end for
    m.screen.LazyLoadExec(partShift)

    ' Animation still needs some logic/2d code to make it work with any
    ' scrollable vbox, but this does work for the users selection screen.
    if m.scrollAnimate = true then
        AnimateShift(shift, partShift, CompositorScreen())
    else
        for each component in partShift
            component.ShiftPosition(shift.x, shift.y, true)
        end for
    end if

    ' Set the visibility after shifting (special case for vbox)
    m.SetVisible()

    ' Normally we would just set onScreenComponents=partShift, however we are executing
    ' this in the containers context, so we must make one more pass to get a list of all
    ' the on screen components after the shift.
    m.screen.onScreenComponents.Clear()
    for each component in m.screen.components
        component.GetShiftableItems(m.screen.onScreenComponents, [])
    next

    ' shift all the off screen components (ignore shifting the sprite)
    for each comp in fullShift
        comp.ShiftPosition(shift.x, shift.y, false)
    end for

    ' lazyload off screen components within our range. Remember we need to execute the
    ' lazyload routines in the screens context.
    if lazyLoad.trigger = true then
        lazyLoad.components = CreateObject("roList")

        ' add any off screen component within range
        for each candidate in fullShift
            if candidate.SpriteIsLoaded() = false and candidate.IsOnScreen(0, 0, 0, ComponentsScreen().ll_loadY) then
                lazyLoad.components.Push(candidate)
            end if
        end for

        Debug("Determined lazy load components (off screen): total=" + tostr(lazyLoad.components.count()))

        if lazyLoad.components.count() > 0 then
            m.screen.lazyLoadTimer.active = true
            m.screen.lazyLoadTimer.components = lazyLoad.components
            Application().AddTimer(m.screen.lazyLoadTimer, createCallable("LazyLoadOnTimer", m.screen))
            m.screen.lazyLoadTimer.mark()
        end if
    end if

    if lazyLoad.components = invalid then
        m.screen.lazyLoadTimer.active = false
        m.screen.lazyLoadTimer.components = invalid
    end if
end sub

sub vboxSetScrollable(scrollTriggerHeight=invalid as dynamic, scrollAnimate=false as boolean, scrollVisible=false as boolean, scrollbarPos="right" as dynamic)
    m.isVScrollable = true
    m.scrollTriggerHeight = firstOf(scrollTriggerHeight, m.height)
    m.scrollAnimate = scrollAnimate
    m.scrollVisible = scrollVisible
    m.scrollbarPos = scrollbarPos

    ' methods
    m.ShiftComponents = vboxShiftComponents
    m.CalculateShift = vboxCalculateShift
end sub

sub vboxSetVisible(visible=true as boolean)
    if visible = false then
        ApplyFunc(BoxClass().SetVisible, m, [false])
    else if m.scrollVisible = true then
        ApplyFunc(BoxClass().SetVisible, m, [true])
    else
        hide = {up: m.y, down: m.contentHeight}

        ' set the visibility based on the constraints
        for each comp in m.components
            comp.SetVisibility(invalid, invalid, hide.up, hide.down)
        end for
    end if
end sub
