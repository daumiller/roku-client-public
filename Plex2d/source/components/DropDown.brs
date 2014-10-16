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

function createDropDown(text as string, font as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(DropDownClass())

    obj.Init(text, font)

    return obj
end function

sub dropdownInit(text as string, font as object)
    ApplyFunc(LabelClass().Init, m, [text, font])

    m.focusable = true
    m.selectable = true
    m.halign = m.JUSTIFY_CENTER
    m.valign = m.ALIGN_MIDDLE

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
    vbox.SetFrame(m.x, m.y+m.height, m.width, 720)
    for each option in m.options
        btn = createButton(option.text, option.font, option.command)
        btn.SetMetadata(option.metadata)
        btn.width = 128
        btn.height = 66
        btn.setColor(Colors().TextClr, Colors().BtnBkgClr)
        btn.zOrder = 500
        btn.dropDown = m
        if screen.focusedItem = invalid then screen.focusedItem = btn
        vbox.AddComponent(btn)
    end for
    m.components.push(vbox)

    for each comp in m.components
        CompositorScreen().DrawComponent(comp)
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
