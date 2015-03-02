function CompositeDropDownButtonClass() as object
    if m.CompositeDropDownButtonClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(DropDownButtonClass())
        obj.Append(CompositeClass())

        obj.ClassName = "CompositeDropDownButton"

        ' Method overrides
        obj.Init = cddbuttonInit

        ' Methods shared between DropDown/Button composities
        obj.PerformLayout = cbuttonPerformLayout
        obj.GetPreferredWidth = cbuttonGetPreferredWidth

        m.CompositeDropDownButtonClass = obj
    end if

    return m.CompositeDropDownButtonClass
end function

sub cddbuttonInit(text as string, font as object, maxHeight as integer)
    ApplyFunc(DropDownButtonClass().Init, m, [text, font, maxHeight])
    ApplyFunc(CompositeClass().Init, m)

    ' Set default padding
    m.SetPadding(0)
end sub
