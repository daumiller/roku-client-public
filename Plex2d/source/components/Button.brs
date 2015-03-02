function ButtonClass() as object
    if m.ButtonClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(LabelClass())
        obj.ClassName = "Button"

        obj.Init = buttonInit

        m.ButtonClass = obj
    end if

    return m.ButtonClass
end function

function createButton(text as string, font as object, command as dynamic, useIndicator=false as boolean) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(ButtonClass())

    obj.Init(text, font)

    obj.useIndicator = useIndicator
    obj.command = command

    return obj
end function

sub buttonInit(text as string, font as object)
    ApplyFunc(LabelClass().Init, m, [text, font])

    m.focusable = true
    m.selectable = true
    m.halign = m.JUSTIFY_CENTER
    m.valign = m.ALIGN_MIDDLE

    m.SetIndicator(m.ALIGN_BOTTOM, m.JUSTIFY_RIGHT)
end sub
