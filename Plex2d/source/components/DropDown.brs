function DropDownClass() as object
    if m.DropDownClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(LabelClass())
        obj.ClassName = "DropDown"

        obj.Init = dropdownInit
        obj.Hide = dropdownHide
        obj.Show = dropdownShow
        obj.Destroy = dropdownDestroy

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

    ' components (buttons) container
    m.components = createObject("roList")

    ' options roList of AA to build components
    m.options = createObject("roList")
end sub

function dropdownHide(drawAllNow=true as boolean) as boolean
    if m.components.count() = 0 then return false
    EnableBackButton()

    m.DestroyComponents()

    if drawAllNow then CompositorScreen().drawAll()

    return true
end function

sub dropdownShow(screen as object)
    m.hide(false)
    DisableBackButton()

    screen.focusedItem = invalid

    ' TODO(rob): remove hard coded variables (position, dimensions, etc)
    vbox = createVBox(false, false, false, 0)
    vbox.SetFrame(m.x, m.y + m.height + 10, m.width, int((m.options.count() * 66) + (m.options.count() * vbox.spacing)))
    ' override the default shifting methods
    vbox.ShiftComponents = dropdownShiftComponents
    vbox.CalculateShift = dropdownCalculateShift

    for each option in m.options
        btn = createButton(option.text, option.font, option.command)
        btn.SetMetadata(option.metadata)
        btn.width = 128
        btn.height = 66
        btn.setColor(Colors().TextClr, Colors().BtnBkgClr)
        btn.zOrder = 500
        btn.dropDown = m
        btn.fixed = (option.fixed = true)
        if screen.focusedItem = invalid then screen.focusedItem = btn
        vbox.AddComponent(btn)
    end for
    m.components.push(vbox)

    for each comp in m.components
        CompositorScreen().DrawComponent(comp)
    end for

    ' set the visibility based on the constraints
    for each comp in vbox.components
        comp.SetVisibility(invalid, invalid, vbox.y, m.maxHeight)
    end for

    CompositorScreen().DrawFocus(screen.focusedItem, true)
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
