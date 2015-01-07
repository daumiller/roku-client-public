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
    end while
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
        shift.y = shift.shiftAmount * -1
        if focusRect.down + shift.y > shift.triggerDown then
            for each i in tofocus.parent.components
                if i.y+i.height > shift.triggerDown then exit for
                wanted = i.y+i.height
            end for
            shift.y = (focusRect.down - wanted) * -1
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

    ' set the visibility based on the constraints
    for each comp in m.components
        comp.SetVisibility(invalid, invalid, shift.hideUp, shift.hideDown)
    end for
end sub

sub vboxSetScrollable(scrollHeight as integer, scrollTriggerDown=invalid as dynamic, scrollAnimate=false as boolean)
    m.scrollHeight = scrollHeight
    m.scrollTriggerDown = firstOf(scrollTriggerDown, scrollHeight)
    m.scrollAnimate = scrollAnimate
    m.ShiftComponents = vboxShiftComponents
    m.CalculateShift = vboxCalculateShift
end sub
