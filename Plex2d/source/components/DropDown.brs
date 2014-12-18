function DropDownClass() as object
    if m.DropDownClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(LabelClass())
        obj.ClassName = "DropDown"

        obj.Init = dropdownInit
        obj.Hide = dropdownHide
        obj.Show = dropdownShow
        obj.Toggle = dropdownToggle
        obj.Destroy = dropdownDestroy
        obj.SetDropDownPosition = dropdownSetDropDownPosition
        obj.OnKeyRelease = dropdownOnKeyRelease
        obj.GetComponents = dropdownGetComponents
        obj.GetOptions = dropdownGetOptions

        m.DropDownClass = obj
    end if

    return m.DropDownClass
end function

function createDropDown(text as string, font as object, maxHeight as integer, screen as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(DropDownClass())

    obj.screen = screen
    obj.Init(text, font, maxHeight)

    return obj
end function

sub dropdownInit(text as string, font as object, maxHeight as integer)
    ApplyFunc(LabelClass().Init, m, [text, font])

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

sub dropdownHide()
    m.expanded = false
    m.DestroyComponents()

    ' reset screen OnKeyRelease to original (keep super referenced)
    if m.screen.DropDownOnKeyRelease <> invalid then
        m.screen.OnKeyRelease = m.screen.DropDownOnKeyRelease
    end if

    ' reset the focus to this object
    m.screen.focusedItem = m
    m.screen.lastFocusedItem = invalid
    CompositorScreen().DrawFocus(m, true)
end sub

sub dropdownShow()
    m.expanded = true
    m.DestroyComponents()
    m.screen.focusedItem = invalid

    ' override the OnKeyRelease to handle the back button. Use a unique name to hold
    ' the original reference as other overlay types may use their own super
    m.screen.DropDownOnKeyRelease = m.screen.OnKeyRelease
    m.screen.OnKeyRelease = m.OnKeyRelease

    m.GetComponents()

    for each comp in m.components
        CompositorScreen().DrawComponent(comp)
    end for

    CompositorScreen().DrawFocus(m.screen.focusedItem, true)
end sub

sub dropdownGetComponents()
    vbox = createVBox(true, true, true, 0)
    vbox.SetScrollable(m.maxHeight)

    ddProp = { width: m.width, height: 0, x: m.x, y: m.y }
    for each option in m.GetOptions()
        btn = createButton(option.text, option.font, option.command)
        btn.focusNonSiblings = false
        if option.padding <> invalid then
            btn.setPadding(option.padding.top, option.padding.right, option.padding.bottom, option.padding.left)
        else
            btn.setPadding(5)
        end if
        if option.halign <> invalid then btn.halign = m[option.halign]
        if option.width  <> invalid then btn.width  = option.width
        if option.height <> invalid then btn.height = option.height
        ' TODO(rob): allow colors to be modified
        btn.setColor(Colors().TextClr, Colors().BtnBkgClr)
        btn.zOrder = 50
        btn.dropDown = m
        btn.fixed = (option.fixed = true)
        ' TODO(rob): option to set the plexObject
        btn.SetMetadata(option.metadata)
        if m.screen.focusedItem = invalid then m.screen.focusedItem = btn
        vbox.AddComponent(btn)

        ' calculate the required height and width for the homogeneous buttons
        if btn.getPreferredWidth() > ddProp.width then
            ddProp.width = btn.getPreferredWidth()
        end if
        ddProp.height = ddProp.height + btn.getPreferredHeight() + vbox.spacing
    end for
    m.components.push(vbox)

    ' set the position of the drop down (supported: bottom [default], and right)
    if m.dropDownPosition = "right" then
        ddProp.x = m.x + m.width + m.parent.spacing
    else
        ddProp.y = m.y + m.height + m.parent.spacing
    end if
    vbox.SetFrame(ddProp.x, ddProp.y, ddProp.width, ddProp.height)
end sub

sub dropdownToggle()
    if m.expanded then
        m.Hide()
    else
        m.Show()
    end if
end sub

sub dropdownDestroy()
    ' destroy any font references
    for each option in m.options
        option.font = invalid
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
        m.DropDownOnKeyRelease(keyCode)
    end if
end sub

function dropdownGetOptions() as object
    return m.options
end function
