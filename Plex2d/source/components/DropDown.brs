function DropDownClass() as object
    if m.DropDownClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(LabelClass())
        obj.ClassName = "DropDown"

        obj.Init = dropdownInit
        obj.Draw = dropdownDraw
        obj.Hide = dropdownHide
        obj.Show = dropdownShow
        obj.Toggle = dropdownToggle
        obj.Destroy = dropdownDestroy
        obj.SetDropDownPosition = dropdownSetDropDownPosition
        obj.OnKeyRelease = dropdownOnKeyRelease
        obj.GetComponents = dropdownGetComponents
        obj.GetOptions = dropdownGetOptions
        obj.CalculatePosition = dropdownCalculatePosition

        m.DropDownClass = obj
    end if

    return m.DropDownClass
end function

function createDropDown(text as string, font as object, maxHeight as integer, screen as object, useIndicator=true as boolean) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(DropDownClass())

    obj.screen = screen
    obj.useIndicator = useIndicator

    obj.Init(text, font, maxHeight)

    return obj
end function

sub dropdownInit(text as string, font as object, maxHeight as integer)
    ApplyFunc(LabelClass().Init, m, [text, font])

    m.OrigScreenFunctions = {
        OnKeyRelease: m.screen.OnKeyRelease,
        OrigOnKeyRelease: m.screen.OrigOnKeyRelease
    }

    m.focusable = true
    m.selectable = true
    m.halign = m.JUSTIFY_CENTER
    m.valign = m.ALIGN_MIDDLE
    m.maxHeight = maxHeight
    m.expanded = false
    m.command = "toggle_control"

    ' components (buttons) container
    m.components = createObject("roList")

    ' options roList of AA to build components
    m.options = createObject("roList")

    m.SetDropDownPosition("down")
end sub

function dropdownDraw(redraw=false as boolean) as object
    ApplyFunc(LabelClass().Draw, m)
    m.DrawIndicator(m.ALIGN_BOTTOM, m.JUSTIFY_RIGHT)

    return [m]
end function

sub dropdownHide()
    m.expanded = false
    m.DestroyComponents()

    ' reset screen OnKeyRelease to original
    m.screen.Append(m.OrigScreenFunctions)

    ' reset the focus to this object
    m.screen.FocusItemManually(m)
end sub

sub dropdownShow()
    ' override the OnKeyRelease to handle the back button.
    m.screen.OrigOnKeyRelease = firstOf(m.screen.OrigOnKeyRelease, m.screen.OnKeyRelease)
    m.screen.OnKeyRelease = m.OnKeyRelease

    m.expanded = true
    m.DestroyComponents()
    m.screen.focusedItem = invalid

    m.GetComponents()

    for each comp in m.components
        CompositorScreen().DrawComponent(comp)
    end for

    m.screen.FocusItemManually(m.screen.focusedItem)
end sub

sub dropdownGetComponents()
    vbox = createVBox(false, false, false, 0)
    vbox.SetScrollable(m.maxHeight)
    vbox.stopShiftIfInView = true

    for each option in m.GetOptions()
        if option.component <> invalid then
            comp = option.component
        else
            comp = createButton(option.text, option.font, option.command)
            comp.focusInside = true
            comp.focusNonSiblings = false
            if option.padding <> invalid then
                comp.setPadding(option.padding.top, option.padding.right, option.padding.bottom, option.padding.left)
            else
                comp.setPadding(5)
            end if
            if option.halign <> invalid then comp.halign = m[option.halign]
            if option.width  <> invalid then comp.width  = option.width
            if option.height <> invalid then comp.height = option.height
            comp.setColor(Colors().Text, Colors().Button)
            comp.zOrder = ZOrders().DROPDOWN
            comp.dropDown = m
            comp.focusParent = m
            comp.fixed = (option.fixed = true)
            comp.SetMetadata(option.metadata)
            comp.plexObject = option.plexObject
            if m.screen.focusedItem = invalid then m.screen.focusedItem = comp
        end if

        vbox.AddComponent(comp)
    end for

    m.CalculatePosition(vbox)
end sub

sub dropdownToggle()
    if m.expanded then
        m.Hide()
    else
        m.Show()
    end if
end sub

sub dropdownDestroy()
    ' reset screen OnKeyRelease to original
    m.screen.Append(m.OrigScreenFunctions)

    ' destroy any font references
    for each option in m.options
        if option.component <> invalid then
            option.component.Destroy()
        else
            option.font = invalid
        end if
    end for
    ApplyFunc(ComponentClass().Destroy, m)
end sub

sub dropdownSetDropDownPosition(direction as string)
    m.dropDownPosition = direction

    ' allowed direction to close the drop down when
    ' there are no focus siblings left
    allowed = [OppositeDirection(direction)]
    if direction = "down" then
        allowed.append(["left","right"])
    else if direction = "right" then
        allowed.append(["up","right"])
    end if

    m.closeDirection = joinArray(allowed, " ")
end sub

sub dropdownOnKeyRelease(keyCode as integer)
    if keyCode = m.kp_BK then
        m.focusedItem.dropDown.Hide()
    else
        m.OrigOnKeyRelease(keyCode)
    end if
end sub

function dropdownGetOptions() as object
    return m.options
end function

sub dropdownCalculatePosition(vbox as object)
    ddProp = { width: m.width, height: 0, x: m.x, y: m.y }

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
    if m.dropDownPosition = "right" then
        ddProp.x = m.x + m.width + m.parent.spacing
    else
        ddProp.y = m.y + m.height + m.parent.spacing
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
    maxScrollHeight = ddProp.height - m.height
    if maxScrollHeight < m.maxHeight then
        vbox.SetScrollable(maxScrollHeight)
    end if
end sub
