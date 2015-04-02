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
    parent = computeRect(m.button)
    ddProp = { width: 0, height: 0, x: parent.left, y: parent.up }

    safeArea = {
        down: 685,
        up: HeaderClass().height,
        left: 50,
        right: 1230,
    }

    ' Assumes all dropdown components height are homogeneous
    compHeight = vbox.components[0].height

    ' Calculate the required height and width for the homogeneous buttons
    for each component in vbox.components
        if component.getPreferredWidth() > ddProp.width then
            ddProp.width = component.getPreferredWidth()
        end if
        ddProp.height = ddProp.height + component.getPreferredHeight() + vbox.spacing
    end for

    ' Reset the buttons width based on the max width
    for each component in vbox.components
        component.width = ddProp.width
    end for

    ' Calculate the initial position of the dropdown. Supported: bottom, right and
    ' left. "up" is used dynamically (for now) when we reset the position to fit
    ' on the screen vertically. We do not support "up" as a specified option, so
    ' we'll have to add support for it later if it's ever preferred.
    '
    spacing = iif(m.button.parent.spacing > 0, m.button.parent.spacing, CompositorScreen().focusPixels)
    if m.button.dropDownPosition = "right" then
        ddProp.x = parent.right + spacing
    else if m.button.dropDownPosition = "left" then
        ddProp.x = parent.left - ddProp.width - spacing
    else
        ddProp.x = parent.right - ddProp.width
        ddProp.y = parent.down + spacing
    end if

    ' Handle dynamic horizontal placement
    if ddProp.x < safeArea.left then
        ddProp.x = parent.right + spacing
        if m.button.dropDownPosition = "left" then
            m.button.SetDropDownPosition("right")
        end if
    else if ddProp.x + ddProp.width > safeArea.right then
        ddProp.x = safeArea.right - ddProp.width
    end if

    ' Handle dynamic vertical placement
    if ddProp.y + ddProp.height > safeArea.down then
        override = { up: {}, down: {} }

        ' Placement above button
        override.up.y = iif(m.button.dropDownPosition = "down" or m.button.dropDownPosition = "up", parent.up - spacing, parent.down)
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
            if m.button.dropDownPosition = "down" then
                m.button.SetDropDownPosition("up")
            end if
        else
            ddProp.Append(override.down)
            if m.button.dropDownPosition = "up" then
                m.button.SetDropDownPosition("down")
            end if
        end if
    end if

    vbox.SetFrame(ddProp.x, ddProp.y, ddProp.width, ddProp.height)

    ' Always set the scroll in the middle
    vbox.SetScrollable(ddProp.height / 2 + compHeight, false, false, m.button.scrollBarPosition)
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
            comp = createButton(option.text, option.font, option.command)
            comp.focusInside = true
            if option.padding <> invalid then
                comp.setPadding(option.padding.top, option.padding.right, option.padding.bottom, option.padding.left)
            else
                comp.setPadding(10 + CompositorScreen().focusPixels)
            end if
            if option.halign <> invalid then comp.halign = m[option.halign]
            if option.width  <> invalid then comp.width  = option.width
            if option.height <> invalid then comp.height = option.height
            comp.setColor(Colors().Text, Colors().Button)
            comp.zOrder = ZOrders().DROPDOWN
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
