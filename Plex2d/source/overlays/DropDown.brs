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
    if m.button.dropDownPosition = "down" then
        allowed.append(["left", "right"])
    else if m.button.dropDownPosition = "right" then
        allowed.append(["up", "right"])
    end if

    if instr(1, joinArray(allowed, " "), direction) then
        m.Close(true)
    end if
end sub

sub ddoverlayCalculatePosition(vbox as object)
    parent = computeRect(m.button)
    ddProp = { width: 0, height: 0, x: parent.left, y: parent.up }

    ' calculate the required height and width for the homogeneous buttons
    for each component in vbox.components
        if component.getPreferredWidth() > ddProp.width then
            ddProp.width = component.getPreferredWidth()
        end if
        ddProp.height = ddProp.height + component.getPreferredHeight() + vbox.spacing
    end for

    ' we cannot set the VBox homogeneous due to arbitary heights, but
    ' we do need the widths to all be consistent.
    for each component in vbox.components
        component.width = ddProp.width
    end for
    m.components.push(vbox)

    ' set the position of the drop down (supported: bottom [default], and right)
    if m.button.dropDownPosition = "right" then
        ddProp.x = parent.right + m.button.parent.spacing
    else
        ddProp.x = ddProp.x - (computeRect(ddProp).right - parent.right)
        ddProp.y = parent.down + m.button.parent.spacing
    end if

    ' verify the xOffset+width is not off the screen (safe area)
    if ddProp.x + ddProp.width > 1230 then
        ddProp.x = 1230 - ddProp.width
    end if

    ' verify the yOffset+height is not off the screen (safe area)
    if ddProp.y + ddProp.height > 670 then
        ddProp.height = 670 - ddProp.y
    end if

    vbox.SetFrame(ddProp.x, ddProp.y, ddProp.width, ddProp.height)

    ' make sure that our scrolling starts within the safe area
    maxScrollHeight = ddProp.height - parent.height
    if maxScrollHeight < m.button.maxHeight then
        vbox.SetScrollable(maxScrollHeight)
    end if
end sub

sub ddoverlayGetComponents()
    vbox = createVBox(false, false, false, 0)
    vbox.SetScrollable(m.button.maxHeight)
    vbox.stopShiftIfInView = true

    for each option in m.button.GetOptions()
        if option.component <> invalid then
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
            if m.screen.focusedItem = invalid then m.screen.focusedItem = comp
        end if

        vbox.AddComponent(comp)
    end for

    m.CalculatePosition(vbox)
end sub
