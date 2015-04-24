function DropDownOverlayClass() as object
    if m.DropDownOverlayClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(OverlayClass())

        obj.ClassName = "DropDownOverlayClass"

        ' Methods
        obj.Init = ddoverlayInit
        obj.CalculatePosition = ddoverlayCalculatePosition

        ' Listener Methods
        obj.OnFailedFocus = ddoverlayOnFailedFocus

        m.DropDownOverlayClass = obj
    end if

    return m.DropDownOverlayClass
end function

function ddoverlayCreateOverlay(screen as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(DropDownOverlayClass())

    ' Overrides for different drop downs
    obj.GetComponents = m.GetComponents

    obj.button = m
    obj.screen = screen

    obj.Init()

    return obj
end function

sub ddoverlayInit()
    ApplyFunc(OverlayClass().Init, m)
    m.enableOverlay = true
end sub

sub ddoverlayOnFailedFocus(direction as string, focusedItem=invalid as dynamic)
    if not m.IsActive() then return
    allowed = [OppositeDirection(m.button.dropDownPosition)]
    if m.button.dropDownPosition = "down" or m.button.dropDownPosition = "up" then
        allowed.append(["left", "right"])
    else
        allowed.append([m.button.dropDownPosition])
    end if

    if instr(1, joinArray(allowed, " "), direction) then
        m.Close(true)
    end if
end sub

sub ddoverlayCalculatePosition(vbox as object)
    ' Reference the dropdown in the vBox for easier access,
    ' when handling multi-level dropdowns.
    vbox.dropdown = m

    button = m.button
    buttonRect = computeRect(button)
    position = m.button.dropDownPosition
    dynamicPosition = (m.button.dropDownDynamicPosition = true)

    ddProp = {width: 0, height: 0, x: buttonRect.left, y: buttonRect.up}

    safeArea = {
        down: 685,
        up: HeaderClass().height,
        left: 50,
        right: 1230,
    }

    ' Optional border for the dropdown, set by the dropdown button
    if button.dropdownBorder <> invalid then
        vbox.border = button.dropdownBorder
    end if

    ' Calculate the spacing between the dropdown button and dropdown. We will prefer
    ' to specified spacing, parents spacing if it exists or fallback to the focus
    ' border pixels.
    '
    if button.dropdownSpacing <> invalid then
        spacing = button.dropdownSpacing
    else if button.parent <> invalid and button.parent.spacing > 0 then
        spacing = button.parent.spacing
    else
        spacing = CompositorScreen().focusPixels
    end if

    ' Calculate the available width for the dropdown. Prefer maxWidth if set and if
    ' it's not greater than our available width
    '
    availableRight = int(safeArea.right - (buttonRect.right + spacing))
    availableLeft = buttonRect.left - spacing - safeArea.left
    if not dynamicPosition then
        if position = "right" then
            availableLeft = availableRight
        else if position = "left" then
            availableRight = availableLeft
        end if
    end if
    minWidth = button.dropdownMinWidth
    maxWidth = button.dropdownMaxWidth
    if maxWidth = invalid or maxWidth > availableRight and maxWidth > availableLeft then
        maxWidth = iif(availableRight > availableLeft, availableRight, availableLeft)
    end if

    ' Assumes all dropdown components height are homogeneous
    compHeight = vbox.components[0].height

    ' Calculate the required height and width for the homogeneous buttons
    for each component in vbox.components
        if component.getPreferredWidth() > ddProp.width then
            ddProp.width = component.getPreferredWidth()
        end if
        ddProp.height = ddProp.height + component.getPreferredHeight() + vbox.spacing
    end for

    ' Reset the homogeneous width (maxWidth or minWidth if applicable)
    if ddProp.width > maxWidth then
        ddProp.width = maxWidth
    else if minWidth <> invalid and ddProp.width < minWidth then
        ddProp.width = minWidth
    end if

    ' Reset the buttons width based on the max width
    for each component in vbox.components
        component.width = ddProp.width
    end for

    ' Multi-level flyout: reposition the flyout 10px below the parent dropdown, if
    ' the content is greater than the parents height. Account for dynamic positions
    ' e.g. rightLeft/leftRight
    '
    if instr(1, lcase(position), "left") > 0 or instr(1, lcase(position), "right") > 0 then
        if button.parent <> invalid and button.parent.dropdown <> invalid and button.parent.height < ddProp.height then
            ddProp.y = button.parent.y + HDtoSDheight(10)
        end if
    end if

    ' Calculate the initial position of the dropdown. Supported: bottom, right and
    ' left. "up" is used dynamically (for now) when we reset the position to fit
    ' on the screen vertically. We do not support "up" as a specified option, so
    ' we'll have to add support for it later if it's ever preferred.
    '
    if position = "right" then
        ddProp.x = buttonRect.right + spacing
    else if position = "left" then
        ddProp.x = buttonRect.left - ddProp.width - spacing
    else
        ddProp.x = buttonRect.right - ddProp.width
        ddProp.y = buttonRect.down + spacing
    end if

    ' Handle dynamic horizontal placement
    if ddProp.x < safeArea.left then
        if position = "left" then
            ddProp.x = buttonRect.right + spacing
            button.SetDropDownPosition("right")
        else
            ddProp.x = safeArea.left
        end if
    else if ddProp.x + ddProp.width > safeArea.right then
        if position = "right" then
            ddProp.x = buttonRect.left - spacing - ddProp.width
            button.SetDropDownPosition("left")
        else
            ddProp.x = safeArea.right - ddProp.width
        end if
    end if

    ' Handle dynamic vertical placement
    if ddProp.y + ddProp.height > safeArea.down then
        override = { up: {}, down: {} }

        ' Placement above button. Handle multi-level dropdowns by placing the
        ' dropdown at the bottom of the parent, if it all fits.
        '
        if button.parent <> invalid and button.parent.dropdown <> invalid then
            override.up.y = computeRect(button.parent).down
        else
            override.up.y = iif(position = "down" or position = "up", buttonRect.up - spacing, buttonRect.down)
        end if

        if override.up.y - ddProp.height < safeArea.up then
            override.up.height = compHeight * int( (override.up.y - safeArea.up) / compHeight)
            override.up.y = override.up.y - override.up.height
        else
            override.up.y = override.up.y - ddProp.height
            override.up.height = ddProp.height
        end if

        ' Placement below button
        override.down.y = ddProp.y
        override.down.height = safeArea.down - ddProp.y

        ' Use the direction allowing the most items (height)
        if override.up.height > override.down.height then
            ddProp.Append(override.up)
            if position = "down" then
                button.SetDropDownPosition("up")
            end if
        else
            ddProp.Append(override.down)
            if position = "up" then
                button.SetDropDownPosition("down")
            end if
        end if
    end if

    vbox.SetFrame(ddProp.x, ddProp.y, ddProp.width, ddProp.height)

    ' Always set the scroll in the middle
    vbox.SetScrollable(ddProp.height / 2 + compHeight, false, false, button.scrollBarPosition)
    vbox.stopShiftIfInView = true

    m.components.Push(vbox)
end sub

sub ddoverlayGetComponents()
    vbox = createVBox(false, false, false, 0)

    for each option in m.button.GetOptions()
        if option.visibleCallable <> invalid and option.visibleCallable.Call([firstOf(option.plexObject, m.plexObject)]) = false then
            comp = invalid
        else if option.component <> invalid then
            comp = option.component
        else
            if option.callableButton <> invalid then
                comp = option.callableButton.Call()
            else
                comp = createButton(option.text, option.font, option.command)
            end if
            comp.setColor(firstOf(option.fgColor, Colors().Text), firstOf(option.bgColor, Colors().Button), option.fgColorFocus)
            if option.dropdownPosition <> invalid and IsFunction(comp.SetDropDownPosition) then
                comp.SetDropDownPosition(option.dropdownPosition, option.dropdownSpacing)
            end if
            if option.focusMethod <> invalid then
                comp.SetFocusMethod(option.focusMethod, option.focusMethodColor)
            else
                comp.focusInside = true
            end if
            if option.padding <> invalid then
                comp.setPadding(option.padding.top, option.padding.right, option.padding.bottom, option.padding.left)
            else
                comp.setPadding(10 + CompositorScreen().focusPixels)
            end if
            if option.halign <> invalid then comp.halign = m[option.halign]
            if option.width  <> invalid then comp.width  = option.width
            if option.height <> invalid then comp.height = option.height
            comp.zOrder = m.zOrderOverlay
            comp.fixed = (option.fixed = true)
            comp.SetMetadata(option.metadata)
            comp.plexObject = option.plexObject
            comp.closeOverlay = option.closeOverlay
            if option.fields <> invalid then
                comp.Append(option.fields)
            end if
            if m.screen.focusedItem = invalid then m.screen.focusedItem = comp
        end if

        if comp <> invalid then
            vbox.AddComponent(comp)
        end if
    end for

    m.CalculatePosition(vbox)
end sub
