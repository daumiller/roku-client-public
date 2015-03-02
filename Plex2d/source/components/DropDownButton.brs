function DropDownButtonClass() as object
    if m.DropDownButtonClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ButtonClass())
        obj.ClassName = "DropDownButton"

        ' Methods
        obj.Init = ddbuttonInit
        obj.Show = ddbuttonShow
        obj.SetDropDownPosition = ddbuttonSetDropDownPosition
        obj.GetOptions = ddbuttonGetOptions

        ' ddbutton overlay
        obj.CreateOverlay = ddoverlayCreateOverlay
        obj.GetComponents = ddoverlayGetComponents

        m.DropDownButtonClass = obj
    end if

    return m.DropDownButtonClass
end function

function createDropDownButton(text as string, font as object, maxHeight as integer, screen as object, useIndicator=true as boolean) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(DropDownButtonClass())

    obj.screen = screen

    obj.Init(text, font, maxHeight)

    obj.useIndicator = useIndicator

    return obj
end function

sub ddbuttonInit(text as string, font as object, maxHeight as integer)
    ApplyFunc(ButtonClass().Init, m, [text, font])

    m.maxHeight = maxHeight
    m.command = "show_dropdown"

    ' options roList of AA to build components
    m.options = createObject("roList")

    m.SetDropDownPosition("down")
    m.SetIndicator(m.ALIGN_BOTTOM, m.JUSTIFY_RIGHT)
end sub

sub ddbuttonShow()
    m.overlay = m.CreateOverlay(m.screen)
    m.overlay.Show()
    m.overlay.AddListener(m.screen, "OnFailedFocus", CreateCallable("OnFailedFocus", m.overlay))
end sub

sub ddbuttonSetDropDownPosition(direction as string)
    m.dropDownPosition = direction
end sub

function ddbuttonGetOptions() as object
    return m.options
end function
