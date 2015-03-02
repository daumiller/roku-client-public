function CompositeDropDownButtonClass() as object
    if m.CompositeDropDownButtonClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(DropDownButtonClass())
        obj.Append(CompositeClass())

        obj.ClassName = "CompositeDropDownButton"

        ' Method overrides
        obj.Init = cddbuttonInit
        obj.PerformLayout = cddbuttonPerformLayout
        obj.GetPreferredWidth = cddbuttonGetPreferredWidth

        m.CompositeDropDownButtonClass = obj
    end if

    return m.CompositeDropDownButtonClass
end function

sub cddbuttonInit(text as string, font as object,  maxHeight as integer)
    ApplyFunc(CompositeClass().Init, m)
    ApplyFunc(DropDownButtonClass().Init, m, [text, font, maxHeight])

    ' Set default padding
    m.SetPadding(0)
end sub

sub cddbuttonPerformLayout()
    m.needsLayout = false
end sub

function cddbuttonGetPreferredWidth() as integer
    width = m.padding.left
    for each comp in m.components
        width = width + comp.GetPreferredWidth() + m.padding.right
    end for

    return width
end function
