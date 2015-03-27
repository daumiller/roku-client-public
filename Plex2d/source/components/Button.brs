function ButtonClass() as object
    if m.ButtonClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(LabelClass())
        obj.ClassName = "Button"

        ' Constants
        obj.FOCUS_BORDER = "border"
        obj.FOCUS_FOREGROUND = "foreground"
        obj.FOCUS_BACKGROUND = "background"
        obj.FOCUS_NONE = "none"

        obj.focusMethod = obj.FOCUS_BORDER

        obj.Init = buttonInit
        obj.SetFocusMethod = buttonSetFocusMethod
        obj.OnFocus = buttonOnFocus
        obj.OnBlur = buttonOnBlur

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

sub buttonSetFocusMethod(focusMethod as string, color=invalid as dynamic)
    m.focusMethod = focusMethod

    if focusMethod = m.FOCUS_BORDER then
        m.focusBorder = true
    else if focusMethod = m.FOCUS_FOREGROUND then
        m.focusBorder = false
        m.focusColor = color
        m.blurColor = m.fgColor
    else if focusMethod = m.FOCUS_BACKGROUND then
        m.focusBorder = false
        m.focusColor = color
        m.blurColor = m.bgColor
    else
        m.focusBorder = false
    end if
end sub

sub buttonOnFocus()
    ApplyFunc(LabelClass().OnFocus, m)

    if m.focusMethod = m.FOCUS_FOREGROUND then
        m.fgColor = m.focusColor
        m.Draw(true)
        m.Redraw()
    else if m.focusMethod = m.FOCUS_BACKGROUND then
        m.bgColor = m.focusColor
        m.Draw(true)
        m.Redraw()
    end if
end sub

sub buttonOnBlur(toFocus=invalid as dynamic)
    ApplyFunc(LabelClass().OnBlur, m, [toFocus])

    if m.focusMethod = m.FOCUS_FOREGROUND then
        m.fgColor = m.blurColor
        m.Draw(true)
        m.Redraw()
    else if m.focusMethod = m.FOCUS_BACKGROUND then
        m.bgColor = m.blurColor
        m.Draw(true)
        m.Redraw()
    end if
end sub
