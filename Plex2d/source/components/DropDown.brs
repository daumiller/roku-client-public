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

        m.DropDownClass = obj
    end if

    return m.DropDownClass
end function

function createDropDown(text as string, font as object, maxHeight as integer) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(DropDownClass())

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

function dropdownHide(drawAllNow=true as boolean) as boolean
    m.expanded = false
    if m.components.count() = 0 then return false
    EnableBackButton()

    m.DestroyComponents()

    if drawAllNow then CompositorScreen().drawAll()

    return true
end function

sub dropdownShow(screen as object)
    m.hide(false)
    DisableBackButton()
    m.expanded = true

    screen.focusedItem = invalid

    ' TODO(rob): remove hard coded variables (position, dimensions, etc)
    vbox = createVBox(true, true, true, 0)
    ' override the default shifting methods
    vbox.ShiftComponents = dropdownShiftComponents
    vbox.CalculateShift = dropdownCalculateShift

    dropDownWidth = m.width
    dropDownHeight = 0

    for each option in m.options
        btn = createButton(option.text, option.font, option.command)
        if option.padding <> invalid then
            btn.setPadding(option.padding.top, option.padding.right, option.padding.bottom, option.left)
        else
            btn.setPadding(5)
        end if
        if option.halign <> invalid then btn.halign = m[option.halign]
        if option.width <> invalid then btn.width = option.width
        if option.height <> invalid then btn.height = option.height
        ' TODO(rob): allow colors to be modified
        btn.setColor(Colors().TextClr, Colors().BtnBkgClr)
        btn.zOrder = 500
        btn.dropDown = m
        btn.fixed = (option.fixed = true)
        ' TODO(rob): option to set the plexObject
        btn.SetMetadata(option.metadata)
        if screen.focusedItem = invalid then screen.focusedItem = btn
        vbox.AddComponent(btn)

        ' calculate the required height and width for the homogeneous buttons
        if btn.getPreferredWidth() > dropDownWidth then
            dropDownWidth = btn.getPreferredWidth()
        end if
        dropDownHeight = dropDownHeight + btn.getPreferredHeight() + vbox.spacing
    end for
    m.components.push(vbox)

    ' set the position of the drop down (supported: bottom [default]) and right)
    if m.dropDownPosition = "right" then
        vbox.SetFrame(m.x + m.width + m.parent.spacing, m.y, dropDownWidth, dropDownHeight)
    else
        vbox.SetFrame(m.x, m.y + m.height + m.parent.spacing, dropDownWidth, dropDownHeight)
    end if

    for each comp in m.components
        CompositorScreen().DrawComponent(comp)
    end for

    ' set the visibility based on the constraints
    for each comp in vbox.components
        comp.SetVisibility(invalid, invalid, vbox.y, m.maxHeight)
    end for

    CompositorScreen().DrawFocus(screen.focusedItem, true)
end sub

sub dropdownToggle(screen)
    if m.expanded then
        m.Hide()
    else
        m.Show(screen)
    end if
end sub

sub dropdownDestroy()
    ' destroy any font references
    for each option in m.options
        option.font = invalid
    end for
    ApplyFunc(ComponentClass().Destroy, m)
    EnableBackButton()
end sub

sub dropdownCalculateShift(toFocus as object)
    ' this isn't really needed, but we'll include it for standards
    if toFocus.fixed = true then return

    shift = {
        x: 0
        y: 0
        safeUp: m.y
        safeDown: toFocus.dropDown.maxHeight
        shiftAmount: toFocus.height + m.spacing
    }

    focusRect = computeRect(toFocus)
    if focusRect.down > shift.safeDown
        shift.y = shift.shiftAmount * -1
    else if focusRect.up < shift.safeUp then
        shift.y = shift.shiftAmount
    end if

    if shift.y <> 0 then
        m.shiftComponents(shift)
    end if
end sub

sub dropdownShiftComponents(shift)
    Debug("shift drop down by: " + tostr(shift.x) + "," + tostr(shift.y))

    ' This is pretty simplistic compared to the default screen shifting. We
    ' already have a list of components, and we are forgoing animation. All
    ' we have to do is shift the position and set the sprites visbility.
    ' TODO(rob): verify: do we ned animation? It seems smooth enough.
    for each component in m.components
        component.ShiftPosition(shift.x, shift.y, true)
        ' set the visibility based on the constraints
        component.SetVisibility(invalid, invalid, shift.safeUp, shift.safeDown)
    end for
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
