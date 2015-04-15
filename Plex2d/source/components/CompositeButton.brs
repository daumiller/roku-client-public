function CompositeButtonClass() as object
    if m.CompositeButtonClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ButtonClass())
        obj.Append(CompositeClass())

        obj.ClassName = "CompositeButton"

        ' Override a few methods we need to function as a button that were
        ' reset by inheriting CompositeClass after ButtonClass. This is
        ' why inheriting from two classes classes isn't optimal.
        '
        obj.SetFocusMethod = ButtonClass().SetFocusMethod
        obj.OnFocus = ButtonClass().OnFocus
        obj.OnBlur = ButtonClass().OnBlur

        ' Method overrides
        obj.Init = cbuttonInit
        obj.PerformLayout = cbuttonPerformLayout
        obj.GetPreferredWidth = cbuttonGetPreferredWidth

        m.CompositeButtonClass = obj
    end if

    return m.CompositeButtonClass
end function

sub cbuttonInit(text as string, font as object)
    ApplyFunc(ButtonClass().Init, m, [text, font])
    ApplyFunc(CompositeClass().Init, m)

    ' Set default padding
    m.SetPadding(0)
end sub

sub cbuttonPerformLayout()
    m.needsLayout = false
end sub

function cbuttonGetPreferredWidth() as integer
    ' If someone specifically set our width, then prefer that.
    if validint(m.width) > 0 then return m.width

    width = m.padding.left
    for each comp in m.components
        width = width + comp.GetPreferredWidth() + m.padding.right
    end for

    return width
end function
