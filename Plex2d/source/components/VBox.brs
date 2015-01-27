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
    m.scrollHeight = m.height + m.y

    numChildren = m.components.Count()

    ' Strange, but let's not even bother with the complicated stuff if we don't need to.
    if numChildren = 0 then return

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
            m.scrollInfo.offsetContainer = m.containerHeight - m.lastShiftInView
        end if

        ' disallow manual focus DOWN for scrolling containers
        if m.containerHeight > m.contentHeight then
            m.disallowExit = { down: true }
        end if

        ' add a semi-transparent block above and below the contentHeight. This
        ' will allow the components outside of the scroll area stay visible,
        ' by chaning their opacity.
        if m.scrollVisible = true and not m.scrollOverflow = true then
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
            contentHeight = iif(m.stopShiftIfInView = true, m.scrollHeight, m.contentHeight)
            m.scrollbar = createScrollbar(offsets[0], contentHeight, m.containerHeight, m.scrollInfo.zOrder, m.scrollInfo.offsetContainer)
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

sub vboxCalculateShift(toFocus as object, refocus=invalid as dynamic)
    if toFocus.fixed = true then return

    shift = {
        x: 0
        y: 0
        hideUp: m.y
        hideDown: m.scrollHeight
        triggerDown: m.scrollTriggerDown
        shiftAmount: toFocus.height + m.spacing + firstOf(toFocus.scrollOffset, 0)
    }

    focusRect = computeRect(toFocus)
    ' reuse the last position on refocus
    if refocus <> invalid and focusRect.up <> refocus.up then
        shift.y = refocus.up - focusRect.up
    ' failsafe refocus: locate the last item to fit, and shift based on it.
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

    if m.isVScrollable <> invalid then
        if toFocus.origY > firstOf(m.lastShiftInView, m.lastShift) then
            shift.y = 0
        end if

        ' shift the scrollbar if applicable
        if m.scrollbar <> invalid then
            isLast = (iif(m.lastShiftInView = invalid, toFocus.origY + toFocus.height, toFocus.origY) >= m.lastShift)
            isFirst = (toFocus.origY = m.y)
            m.scrollbar.Move(toFocus, isFirst, isLast)
        end if
    end if

    if shift.y <> 0 then
        m.shiftComponents(shift)
    end if
end sub

sub vboxShiftComponents(shift)
    Debug("shift vbox by: " + tostr(shift.x) + "," + tostr(shift.y))

    ' Animation still needs some logic/2d code to make it work with any
    ' scrollable vbox, but this does work for the users selection screen.
    if m.scrollAnimate = true then
        AnimateShift(shift, m.components, CompositorScreen())
    else
        for each component in m.components
            component.ShiftPosition(shift.x, shift.y, true)
        end for
    end if

    m.SetVisible()
end sub

sub vboxSetScrollable(scrollTriggerDown=invalid as dynamic, scrollAnimate=false as boolean, scrollVisible=false as boolean, scrollbarPos="right" as dynamic)
    m.isVScrollable = true
    m.scrollTriggerDown = firstOf(scrollTriggerDown, m.height + m.y)
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
        hide = {up: m.y, down: m.scrollHeight}

        ' set the visibility based on the constraints
        for each comp in m.components
            comp.SetVisibility(invalid, invalid, hide.up, hide.down)
        end for
    end if
end sub
