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
        obj.SetBorder = vboxSetBorder

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

    overlayZOrder = 2
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
            if m.scrollInfo = invalid then m.scrollInfo = CreateObject("roAssociativeArray")
            if m.origScrollTriggerDown = invalid then m.origScrollTriggerDown = m.scrollTriggerDown

            ' Calculate the spacing from the xOffset for the scrollbar
            if m.scrollInfo.spacing = invalid then
                if component.focusMethod <> invalid and component.focusMethod <> ButtonClass().FOCUS_BORDER then
                    m.scrollInfo.spacing = 2
                else if component.focusInside = true then
                    m.scrollInfo.spacing = cint(CompositorScreen().focusPixels/2)
                else
                    m.scrollInfo.spacing = CompositorScreen().focusPixels * 2
                end if
            end if

            ' height of all components in the container
            m.containerHeight = offset + height
            if m.contentHeight = invalid then
                m.contentHeight = m.containerHeight
            end if
            m.lastShift = m.containerHeight

            ' calculate the exact content height that fits within m.scrollTriggerDown
            if m.containerHeight <= m.origScrollTriggerDown then
                m.scrollTriggerDown = m.containerHeight
            end if

            ' calculate the content height that fits in wanted container height
            if m.containerHeight <= offsets[0] + m.height then
                m.contentHeight = m.containerHeight
            end if
        end if

        ' determine the zOrder required for any additional components (scrollbar/opacity blocks)
        if component.zOrder <> invalid and component.zOrder > overlayZOrder then
            overlayZOrder = component.zOrder + 1
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
            m.DisableNonParentExit("down")
        end if

        ' add a semi-transparent block above and below the contentHeight. This
        ' will allow the components outside of the scroll area stay visible,
        ' by chaning their opacity.
        if m.scrollVisible = true and m.scrollOverflow <> true then
            color = firstOf(m.scrollOverflowColor, Colors().Background and &hffffffe0)
            opacityTop = createBlock(color)
            opacityTop.setFrame(xOffset, 0, m.width, offsets[0])
            opacityTop.zOrder = overlayZOrder
            opacityTop.fixed = false
            opacityTop.fixedVertical = true

            opacityBot = createBlock(color)
            opacityBot.zOrder = overlayZOrder
            opacityBot.fixed = false
            opacityBot.fixedVertical = true
            opacityBot.setFrame(xOffset, m.contentHeight, m.width, 720 - m.contentHeight)

            m.components.push(opacityTop)
            m.components.push(opacityBot)
        end if

        ' add a scrollbar
        if m.scrollbarPosition <> invalid and m.containerHeight > m.contentHeight then
            m.scrollbar = createScrollbar(offsets[0], m.contentHeight, m.containerHeight, overlayZOrder, m.scrollInfo.offsetContainer)
            if m.scrollbar <> invalid
                width = int(CompositorScreen().focusPixels * 1.5)
                spacing = firstOf(m.scrollInfo.spacing, CompositorScreen().focusPixels * 2)
                if m.border <> invalid then
                    spacing = spacing + m.border.px
                end if
                if m.scrollbarPosition = "right" then
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
        m.Delete("scrollInfo")

        ' Calculate and append the border if set. Make sure there is no
        ' overlap in case we use an alpha color.
        '
        if m.border <> invalid then
            ' We can use the current vbox rect, but we must resize our
            ' calculations based on the content height.
            '
            rect = computeRect(m)
            rect.down = m.contentHeight
            rect.height = rect.down - rect.up

            borderTop = createBlock(m.border.color)
            borderTop.SetFrame(rect.left, rect.up - m.border.px, rect.width, m.border.px)
            borderTop.zOrder = overlayZOrder
            m.AddComponent(borderTop)

            borderBottom = createBlock(m.border.color)
            borderBottom.SetFrame(rect.left, rect.down, rect.width, m.border.px)
            borderBottom.zOrder = overlayZOrder
            m.AddComponent(borderBottom)

            ' Shared dimensions between the left/right border
            yOffset = rect.up - m.border.px
            height = rect.height + m.border.px*2

            borderLeft = createBlock(m.border.color)
            borderLeft.SetFrame(rect.left - m.border.px, yOffset, m.border.px, height)
            borderLeft.zOrder = overlayZOrder
            m.AddComponent(borderLeft)

            borderRight = createBlock(m.border.color)
            borderRight.SetFrame(rect.right, yOffset, m.border.px, height)
            borderRight.zOrder = overlayZOrder
            m.AddComponent(borderRight)
        end if
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
    forceLoad = not toFocus.SpriteIsLoaded()
    if not forceLoad and (toFocus.fixed = true or m.scrolltriggerdown >= m.containerHeight) then return

    m.screen = screen

    shift = {
        x: 0
        y: 0
        hideUp: m.y
        hideDown: m.contentHeight
        triggerUp: m.scrollTriggerDown - toFocus.height
        triggerDown: m.scrollTriggerDown
        shiftAmount: toFocus.height + m.spacing
        toFocus: toFocus
    }

    ' handle shifting groups (settings menu box)
    if toFocus.scrollGroupTop <> invalid then
        first = m.components[1]
        if toFocus.scrollGroupTop.y < shift.hideUp and toFocus.y - toFocus.scrollGroupTop.y < m.contentHeight - m.y then
            toFocus = toFocus.scrollGroupTop
        end if
    else
        first = m.components[0]
    end if

    focusRect = computeRect(toFocus)
    ' reuse the last position on refocus
    if refocus <> invalid and focusRect.up > refocus.up then
        shift.y = refocus.up - focusRect.up
    ' keep shifting on keypress up until the first item is in view
    else if focusRect.up < shift.triggerUp and first.y < shift.hideUp then
        shift.y = shift.shiftAmount
        if first.y + shift.y > shift.hideUp then
            shift.y = shift.hideUp - first.y
        end if
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
        isFirst = (toFocus.origY = m.y or toFocus.Equals(first))
        isLast = (toFocus.origY + toFocus.height >= lastShift)
        m.scrollbar.Move(toFocus, isFirst, isLast)
    end if

    if forceLoad or shift.y <> 0 then
        ' Hide the focus sprite before shift if destination differs
        sourceRect = m.screen.screen.GetFocusData("rect")
        if sourceRect <> invalid and (focusRect.left <> sourceRect.left or focusRect.right <> sourceRect.right) then
            m.screen.screen.hideFocus()
        end if
        m.shiftComponents(shift, refocus, forceLoad)
    end if
end sub

sub vboxShiftComponents(shift as object, refocus=invalid as dynamic, forceLoad=false as boolean)
    Debug("shift vbox by: " + tostr(shift.x) + "," + tostr(shift.y))

    ' Disable animation for forground/background focus methods, key repeats,
    ' on refocus, or if the shift is greater than the vbox height. This fixes
    ' any possible memory issue, unnecessary scrolling animation, and improves
    ' performance.
    '
    enableAnimation = (m.scrollAnimate = true)
    if enableAnimation then
        ' This ensures we don't allow animation for foreground or background
        ' focus, otherwise it will flicker. We will have to modify these focus
        ' methods if we need/want to animate.
        '
        focusMethod = shift.toFocus.focusMethod
        if focusMethod <> invalid and (focusMethod = ButtonClass().FOCUS_FOREGROUND or focusMethod = ButtonClass().FOCUS_BACKGROUND) then
            enableAnimation = false
        else if m.screen.isKeyRepeat = true or refocus <> invalid or abs(shift.y) > m.height then
            enableAnimation = false
        end if
    end if

    if m.screen.lazyLoadTimer <> invalid then
        m.screen.lazyLoadTimer.active = false
        m.screen.lazyLoadTimer.components = invalid
    end if

    partShift = CreateObject("roList")
    fullShift = CreateObject("roList")
    lazyLoad = Createobject("roList")

    ' This assumes all vbox components are the same height
    if m.vShift = invalid then
        displayHeight = AppSettings().GetGlobal("displaySize").h
        offset = m.components.Peek().height
        m.vShift = {
            onScreenY: offset * -2
            onScreenH: displayHeight + offset,
            triggerY: ComponentsScreen().ll_triggerY * -1,
            triggerH: displayHeight + ComponentsScreen().ll_triggerY,
            loadY: ComponentsScreen().ll_loadY * -1,
            loadH: displayHeight + ComponentsScreen().ll_loadY,
        }
    end if

    triggerLazyLoad = false
    for each component in m.components
        compY = component.y + shift.y
        if component.y > m.vShift.onScreenY and component.y < m.vShift.onScreenH then
            partShift.push(component)
        else if compY > m.vShift.onScreenY and compY < m.vShift.onScreenH then
            partShift.push(component)
        else if not triggerLazyLoad and compY > m.vShift.triggerY and compY < m.vShift.triggerH and component.SpriteIsLoaded() = false then
            triggerLazyLoad = true
            fullShift.push(component)
            lazyLoad.push(component)
        else if triggerLazyLoad and compY > m.vShift.loadY and compY < m.vShift.loadH and component.SpriteIsLoaded() = false then
            lazyLoad.push(component)
            fullShift.push(component)
        else
            fullShift.push(component)
        end if
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
    if enableAnimation then
        AnimateShift(shift, partShift, m.screen.screen)
    else
        for each component in partShift
            component.ShiftPosition(shift.x, shift.y, true)
        end for
    end if

    ' shift all the off screen components (ignore shifting the sprite)
    for each comp in fullShift
        comp.ShiftPosition(shift.x, shift.y, false)
    end for

    ' Set the visibility after shifting (special case for vbox)
    m.SetVisible()

    ' Normally we would just set onScreenComponents=partShift, however we are executing
    ' this in the containers context, so we must make one more pass to get a list of all
    ' the on screen components after the shift.
    ' This logic has been optimized instead of using the generic methods
    ' We can safely ignore this step if an overlay is active.
    if m.screen.overlayScreen.Count() = 0 then
        onScreenReplacment = CreateObject("roList")
        for each component in m.screen.onScreenComponents
            exclude = false
            for each comp in partShift
                if component.Equals(comp) then
                    exclude = true
                    exit for
                end if
            end for

            if not exclude then
               component.GetFocusableItems(onScreenReplacment)
            end if
        next
        for each component in partShift
            component.GetFocusableItems(onScreenReplacment)
        end for
        m.screen.onScreenComponents = onScreenReplacment
    end if

    ' lazyload off screen components within our range. Remember we need to execute the
    ' lazyload routines in the screens context.
    if lazyLoad.Count() > 0 then
        Debug("lazy load components (off screen): total=" + tostr(lazyLoad.Count()))
        m.screen.lazyLoadTimer.active = true
        m.screen.lazyLoadTimer.components = lazyLoad
        Application().AddTimer(m.screen.lazyLoadTimer, createCallable("LazyLoadOnTimer", m.screen))
        m.screen.lazyLoadTimer.mark()
    else
        m.screen.lazyLoadTimer.active = false
        m.screen.lazyLoadTimer.components = invalid
    end if
end sub

sub vboxSetScrollable(scrollTriggerHeight=invalid as dynamic, scrollAnimate=false as boolean, scrollVisible=false as boolean, scrollbarPosition="right" as dynamic)
    m.resizable = false
    m.isVScrollable = true
    m.scrollTriggerHeight = firstOf(scrollTriggerHeight, m.height)
    m.scrollAnimate = scrollAnimate
    m.scrollVisible = scrollVisible
    m.scrollbarPosition = scrollbarPosition

    ' methods
    m.ShiftComponents = vboxShiftComponents
    m.CalculateShift = vboxCalculateShift
end sub

' Note: refer to contDraw() for initial visibility
sub vboxSetVisible(visible=true as boolean)
    if visible = false then
        ApplyFunc(BoxClass().SetVisible, m, [false])
    else if m.scrollVisible = true then
        ApplyFunc(BoxClass().SetVisible, m, [true])
    else
        hide = {up: m.y, down: m.contentHeight}

        ' Set the visibility based on the constraints, however,
        ' fixed components are always visible.
        for each comp in m.components
            if comp.fixed then
                comp.SetVisible(true)
            else
                comp.SetVisibility(invalid, invalid, hide.up, hide.down)
            end if
        end for
    end if
end sub

sub vboxSetBorder(px=1 as integer, color=Colors().Border as integer)
    m.border = {px: px, color: color}
end sub
