function DropDownButtonClass() as object
    if m.DropDownButtonClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ButtonClass())
        obj.Append(GenericDropDownButtonClass())

        obj.ClassName = "DropDownButton"

        ' Methods
        obj.Init = ddbInit

        m.DropDownButtonClass = obj
    end if

    return m.DropDownButtonClass
end function

function createDropDownButton(text as string, font as object, screen as object, useIndicator=true as boolean) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(DropDownButtonClass())

    obj.screen = screen

    obj.Init(text, font)

    obj.useIndicator = useIndicator

    return obj
end function

sub ddbInit(text as string, font as object)
    ApplyFunc(ButtonClass().Init, m, [text, font])
    ApplyFunc(GenericDropDownButtonClass().Init, m)
end sub
