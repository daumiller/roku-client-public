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

function createDropDownButton(text as string, font as object, screen as object, useIndicator=true as boolean) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(DropDownButtonClass())

    obj.screen = screen

    obj.Init(text, font)

    obj.useIndicator = useIndicator

    return obj
end function

sub ddbuttonInit(text as string, font as object)
    ApplyFunc(ButtonClass().Init, m, [text, font])

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

sub ddbuttonSetDropDownPosition(direction as string, dropdownSpacing=invalid as dynamic)
    ' Supported: bottom, right and left. "up" is used dynamically
    ' (for now) when we reset the position to fit on the screen.
    '
    m.dropDownPosition = direction
    m.scrollbarPosition = iif(direction = "left", direction, "right")
    if dropdownSpacing <> invalid then
        m.dropdownSpacing = dropdownSpacing
    end if
end sub

function ddbuttonGetOptions() as object
    return m.options
end function
